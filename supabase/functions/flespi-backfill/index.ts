// supabase/functions/flespi-backfill/index.ts
//
// Backfill PONCTUEL de l'historique Flespi → Supabase (gps_positions).
// À utiliser une seule fois (ou de temps en temps) pour rapatrier des
// données déjà présentes chez Flespi mais jamais poussées vers Supabase
// (ex : les 2 mois précédant la création du Stream).
//
// Ce n'est PAS un endpoint appelé par l'app Flutter — tu le déclenches
// toi-même via curl/Postman. Protégé par le même secret que flespi-ingest.
//
// Déploiement :
//   supabase functions deploy flespi-backfill --no-verify-jwt
//
// Appel type (un device, 60 derniers jours) :
//   curl -X POST \
//     "https://mkrbhyrkrajicthcqjtj.supabase.co/functions/v1/flespi-backfill?secret=TON_SECRET" \
//     -H "Content-Type: application/json" \
//     -d '{"showroomId":"...", "days":60}'
//
// Réponse : { "done": false, "results": [...], "resume": {...} }
// Si "done": false → relance EXACTEMENT le même body en ajoutant "resume": {...}
// reçu dans la réponse précédente, jusqu'à obtenir "done": true.
// (protection contre le timeout des edge functions sur de gros volumes)

import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Budget de temps par invocation — on s'arrête avant la limite de l'edge
// function et on renvoie un curseur de reprise plutôt que de timeout.
const TIME_BUDGET_MS = 50_000;
const MESSAGES_PER_CALL = 1000; // taille de page Flespi (sûr, évite les timeouts Flespi)
const UPSERT_CHUNK = 500;

interface BackfillRequest {
  showroomId?: string;
  // Backfill ciblé sur un seul device (optionnel — sinon tous les devices du showroom)
  deviceId?: number;
  vehiculeId?: string;
  days?: number; // par défaut 60
  from?: number; // epoch seconds — prioritaire sur "days" si fourni
  to?: number;   // epoch seconds — par défaut "maintenant"
  resume?: {
    deviceIndex: number; // index dans la liste des devices à traiter
    cursorFrom: number;  // epoch seconds — reprendre à partir d'ici pour ce device
  };
}

interface DeviceTarget {
  deviceId: number;
  vehiculeId: string;
  label: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const t0 = Date.now();
  const timeLeft = () => TIME_BUDGET_MS - (Date.now() - t0);

  try {
    // 1. Auth par secret partagé (même secret que le stream flespi-ingest)
    const url = new URL(req.url);
    const secret = url.searchParams.get("secret");
    const expectedSecret = Deno.env.get("FLESPI_STREAM_SECRET");
    if (!expectedSecret || secret !== expectedSecret) {
      return json(401, { error: "Non autorisé" });
    }

    const body: BackfillRequest = await req.json().catch(() => ({}));
    if (!body.showroomId) return json(400, { error: "showroomId requis" });

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceKey);

    // 2. Token Flespi du showroom
    const { data: showroom, error: showroomErr } = await admin
      .from("showrooms")
      .select("flespi_token")
      .eq("id", body.showroomId)
      .single();
    if (showroomErr || !showroom?.flespi_token) {
      return json(404, { error: "Token Flespi introuvable pour ce showroom" });
    }
    const token = showroom.flespi_token as string;

    // 3. Liste des devices à traiter
    let targets: DeviceTarget[];
    if (body.deviceId && body.vehiculeId) {
      targets = [{ deviceId: body.deviceId, vehiculeId: body.vehiculeId, label: body.vehiculeId }];
    } else {
      const { data: vehicules, error: vErr } = await admin
        .from("vehicules")
        .select("id, marque, modele, flespi_device_id")
        .eq("showroom_id", body.showroomId)
        .not("flespi_device_id", "is", null);
      if (vErr) return json(500, { error: `Erreur lecture véhicules: ${vErr.message}` });
      targets = (vehicules ?? []).map((v) => ({
        deviceId: v.flespi_device_id as number,
        vehiculeId: v.id as string,
        label: `${v.marque} ${v.modele}`,
      }));
    }
    if (targets.length === 0) return json(400, { error: "Aucun véhicule avec flespi_device_id sur ce showroom" });

    // 4. Fenêtre temporelle
    const nowSec = Math.floor(Date.now() / 1000);
    const to = body.to ?? nowSec;
    const from = body.from ?? (to - (body.days ?? 60) * 86400);

    const startDeviceIndex = body.resume?.deviceIndex ?? 0;
    const startCursor = body.resume?.cursorFrom ?? from;

    const results: Array<{ vehiculeId: string; label: string; inserted: number; done: boolean }> = [];

    for (let i = startDeviceIndex; i < targets.length; i++) {
      const target = targets[i];
      let cursor = i === startDeviceIndex ? startCursor : from;
      let inserted = 0;

      while (cursor < to) {
        if (timeLeft() < 5000) {
          // Plus assez de temps : on s'arrête ici et on renvoie un curseur de reprise
          results.push({ vehiculeId: target.vehiculeId, label: target.label, inserted, done: false });
          return json(200, {
            done: false,
            results,
            resume: { deviceIndex: i, cursorFrom: cursor },
            note: "Budget de temps atteint — relance avec le même body + ce 'resume' pour continuer.",
          });
        }

        const messages = await fetchFlespiMessages(token, target.deviceId, cursor, to, MESSAGES_PER_CALL);
        if (messages.length === 0) break;

        const rows = messages
          .map((m) => toRow(m, target.vehiculeId))
          .filter((r): r is Record<string, unknown> => r !== null);

        for (let c = 0; c < rows.length; c += UPSERT_CHUNK) {
          const chunk = rows.slice(c, c + UPSERT_CHUNK);
          const { error: upsertErr } = await admin
            .from("gps_positions")
            .upsert(chunk, { onConflict: "vehicule_id,fix_time" });
          if (upsertErr) {
            return json(500, {
              error: `Upsert échoué pour ${target.label}: ${upsertErr.message}`,
              hint: "Vérifie qu'une contrainte UNIQUE existe sur gps_positions(vehicule_id, fix_time).",
              results,
            });
          }
          inserted += chunk.length;
        }

        // Avance le curseur : dernier timestamp + 1s (évite de reboucler sur le même point)
        const lastTs = messages[messages.length - 1]["timestamp"] as number | undefined;
        if (lastTs == null) break;
        const nextCursor = Math.floor(lastTs) + 1;
        if (nextCursor <= cursor) break; // sécurité anti boucle infinie
        cursor = nextCursor;

        if (messages.length < MESSAGES_PER_CALL) break; // plus de données sur cette fenêtre

        // Petite pause pour ménager le rate-limit Flespi
        await new Promise((r) => setTimeout(r, 150));
      }

      results.push({ vehiculeId: target.vehiculeId, label: target.label, inserted, done: true });
    }

    return json(200, { done: true, results });
  } catch (error) {
    console.error("[flespi-backfill] Exception:", error);
    return json(500, { error: `${error}` });
  }
});

async function fetchFlespiMessages(
  token: string,
  deviceId: number,
  from: number,
  to: number,
  count: number,
): Promise<Array<Record<string, unknown>>> {
  const url = `https://flespi.io/gw/devices/${deviceId}/messages?from=${from}&to=${to}&count=${count}`;
  const resp = await fetch(url, { headers: { Authorization: `FlespiToken ${token}` } });
  if (resp.status === 404) return [];
  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`Flespi HTTP ${resp.status} (device ${deviceId}): ${t.substring(0, 200)}`);
  }
  const body = await resp.json();
  const result = body?.result;
  if (!Array.isArray(result)) return [];
  return result as Array<Record<string, unknown>>;
}

function toRow(m: Record<string, unknown>, vehiculeId: string): Record<string, unknown> | null {
  const lat = m["position.latitude"];
  const lon = m["position.longitude"];
  if (typeof lat !== "number" || typeof lon !== "number") return null;

  const fixTs = m["timestamp"] as number | undefined;
  const serverTs = m["server.timestamp"] as number | undefined;
  const fixTime = typeof fixTs === "number" ? new Date(fixTs * 1000).toISOString() : new Date().toISOString();
  const serverTime = typeof serverTs === "number" ? new Date(serverTs * 1000).toISOString() : fixTime;

  return {
    vehicule_id: vehiculeId,
    latitude: lat,
    longitude: lon,
    speed: m["position.speed"] ?? null,
    altitude: m["position.altitude"] ?? null,
    cap: m["position.direction"] ?? null,
    fix_time: fixTime,
    server_time: serverTime,
    ignition_on: m["engine.ignition.status"] ?? null,
    battery_level: m["battery.level"] ?? null,
    fuel_level: m["fuel.level.1"] ?? null,
    door_open: m["door.open.status"] ?? null,
    gnss_valid: m["gnss.status"] ?? null,
    position_valid: m["position.valid"] ?? null,
  };
}

function json(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}