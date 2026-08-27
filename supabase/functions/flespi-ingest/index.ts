// supabase/functions/flespi-ingest/index.ts
//
// Point d'entrée du flespi HTTP Stream (push serveur-à-serveur, PAS d'auth
// utilisateur Supabase). Flespi POST un batch JSON de messages à chaque
// nouvelle donnée reçue d'un tracker, et attend une réponse 200 avant
// d'envoyer le batch suivant (stream mono-thread).
//
// Sécurité : pas de JWT (Flespi ne peut pas en fournir). On protège
// l'endpoint avec un secret partagé passé en query string, à configurer :
//   - côté Supabase : `supabase secrets set FLESPI_STREAM_SECRET=xxxxx`
//   - côté Flespi   : URI du stream = https://.../flespi-ingest?secret=xxxxx
//
// Déploiement : `supabase functions deploy flespi-ingest --no-verify-jwt`
// (verify_jwt doit être désactivé, ce n'est pas un appel utilisateur).

import { createClient } from "npm:@supabase/supabase-js@2";

interface FlespiMessage {
  "device.id"?: number;
  "ident"?: string;
  "timestamp"?: number;
  "server.timestamp"?: number;
  "position.latitude"?: number;
  "position.longitude"?: number;
  "position.speed"?: number;
  "position.altitude"?: number;
  "position.direction"?: number;
  "position.valid"?: boolean;
  "engine.ignition.status"?: boolean;
  "battery.level"?: number;
  "fuel.level.1"?: number;
  "door.open.status"?: boolean;
  "gnss.status"?: boolean;
  [key: string]: unknown;
}

Deno.serve(async (req: Request) => {
  try {
    // 1. Vérification du secret partagé
    const url = new URL(req.url);
    const secret = url.searchParams.get("secret");
    const expectedSecret = Deno.env.get("FLESPI_STREAM_SECRET");

    if (!expectedSecret || secret !== expectedSecret) {
      console.error("[flespi-ingest] Secret invalide ou manquant");
      return new Response(JSON.stringify({ error: "Non autorisé" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Parsing du batch de messages
    const bodyText = await req.text();
    let messages: FlespiMessage[];
    try {
      messages = JSON.parse(bodyText);
    } catch (_e) {
      console.error("[flespi-ingest] JSON invalide:", bodyText.substring(0, 200));
      return new Response(JSON.stringify({ error: "JSON invalide" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!Array.isArray(messages) || messages.length === 0) {
      // Rien à faire, mais on répond 200 pour ne pas bloquer le stream.
      return new Response(JSON.stringify({ inserted: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[flespi-ingest] ${messages.length} message(s) reçu(s)`);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceKey);

    // 3. Résoudre device.id → vehicule_id (un seul aller-retour DB pour
    //    tous les devices distincts présents dans ce batch).
    const deviceIds = [
      ...new Set(
        messages
          .map((m) => m["device.id"])
          .filter((id): id is number => typeof id === "number"),
      ),
    ];

    if (deviceIds.length === 0) {
      console.warn("[flespi-ingest] Aucun device.id exploitable dans le batch");
      return new Response(JSON.stringify({ inserted: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: vehicules, error: vehiculesError } = await admin
      .from("vehicules")
      .select("id, flespi_device_id")
      .in("flespi_device_id", deviceIds);

    if (vehiculesError) {
      console.error("[flespi-ingest] Erreur lookup véhicules:", vehiculesError);
      return new Response(JSON.stringify({ error: "Erreur DB véhicules" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const deviceToVehicule = new Map<number, string>();
    for (const v of vehicules ?? []) {
      if (v.flespi_device_id != null) {
        deviceToVehicule.set(v.flespi_device_id as number, v.id as string);
      }
    }

    // 4. Conversion messages Flespi → lignes gps_positions
    const rows = messages
      .map((m) => toRow(m, deviceToVehicule))
      .filter((r): r is Record<string, unknown> => r !== null);

    if (rows.length === 0) {
      console.warn(
        "[flespi-ingest] Aucun message exploitable (device inconnu ou position absente)",
      );
      return new Response(JSON.stringify({ inserted: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 5. Dédoublonnage intra-batch — Postgres refuse un upsert qui affecte
    //    deux fois la même ligne dans une seule commande ("ON CONFLICT DO
    //    UPDATE command cannot affect row a second time"). Si le device
    //    envoie deux messages avec le même (vehicule_id, fix_time) dans le
    //    même batch, tout l'upsert échouait et RIEN n'était inséré.
    //    On garde la dernière occurrence de chaque clé.
    const dedupMap = new Map<string, Record<string, unknown>>();
    for (const r of rows) {
      dedupMap.set(`${r.vehicule_id}|${r.fix_time}`, r);
    }
    const dedupedRows = [...dedupMap.values()];
    const duplicatesRemoved = rows.length - dedupedRows.length;
    if (duplicatesRemoved > 0) {
      console.warn(
        `[flespi-ingest] ${duplicatesRemoved} doublon(s) intra-batch retiré(s) avant upsert`,
      );
    }

    // 6. Upsert — même clé de dédoublonnage que le reste de l'app
    //    (vehicule_id, fix_time), pour rester cohérent avec
    //    GpsLocalSource.upsertPositions côté Flutter.
    const { error: insertError } = await admin
      .from("gps_positions")
      .upsert(dedupedRows, { onConflict: "vehicule_id,fix_time" });

    if (insertError) {
      console.error("[flespi-ingest] Erreur insertion:", insertError);
      return new Response(JSON.stringify({ error: "Erreur insertion" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[flespi-ingest] ✓ ${dedupedRows.length} position(s) insérée(s)`);
    return new Response(JSON.stringify({ inserted: dedupedRows.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[flespi-ingest] Exception non capturée:", error);
    // On répond quand même 200 pour éviter que Flespi ne bloque son buffer
    // en boucle sur un message qu'on ne saura jamais traiter ; l'erreur est
    // tracée dans les logs pour investigation.
    return new Response(JSON.stringify({ error: `${error}` }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});

/**
 * Convertit un message Flespi (format plat "position.latitude", etc.) en
 * ligne prête pour la table gps_positions. Retourne null si le device est
 * inconnu ou si la position est absente/invalide.
 */
function toRow(
  m: FlespiMessage,
  deviceToVehicule: Map<number, string>,
): Record<string, unknown> | null {
  const deviceId = m["device.id"];
  if (typeof deviceId !== "number") return null;

  const vehiculeId = deviceToVehicule.get(deviceId);
  if (!vehiculeId) return null; // device pas rattaché à un véhicule connu

  const lat = m["position.latitude"];
  const lon = m["position.longitude"];
  if (typeof lat !== "number" || typeof lon !== "number") return null;

  const fixTs = m["timestamp"];
  const serverTs = m["server.timestamp"];
  const fixTime = typeof fixTs === "number"
    ? new Date(fixTs * 1000).toISOString()
    : new Date().toISOString();
  const serverTime = typeof serverTs === "number"
    ? new Date(serverTs * 1000).toISOString()
    : fixTime;

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