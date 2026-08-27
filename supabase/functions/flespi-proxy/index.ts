// supabase/functions/flespi-proxy/index.ts
//
// Proxy Flespi pour contourner CORS et ajouter des vérifications de sécurité
//
// Changements vs version précédente :
//   1. Vérifie que le deviceId demandé appartient bien à un véhicule du
//      showroom de l'utilisateur
//   2. Gère le rate-limit Flespi (HTTP 429) avec un retry + backoff court
//   3. Timeout explicite sur l'appel Flespi

import { createClient } from "npm:@supabase/supabase-js@2";

// ============================================================================
// CONSTANTES
// ============================================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const FLESPI_TIMEOUT_MS = 15000;
const MAX_RETRIES_429 = 2;

// ============================================================================
// TYPES
// ============================================================================

interface FlespiRequest {
  action: "telemetry" | "messages";
  deviceId: number;
  showroomId: string;
  from?: number;
  to?: number;
  count?: number;
}

// ============================================================================
// HANDLER PRINCIPAL
// ============================================================================

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    // 1. Authentification
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse(401, "Non authentifié");
    }

    // 2. Parsing du body
    const bodyText = await req.text();
    console.log("[flespi-proxy] body reçu:", bodyText.substring(0, 200));

    let bodyData: FlespiRequest;
    try {
      bodyData = JSON.parse(bodyText);
    } catch (_e) {
      return errorResponse(
        400,
        `JSON invalide — body: ${bodyText.substring(0, 100)}`
      );
    }

    const { action, deviceId, showroomId, from, to, count = 5000 } = bodyData;

    // 3. Validation des paramètres
    if (!action || !deviceId || !showroomId) {
      return errorResponse(
        400,
        `Paramètres manquants — reçu: ${JSON.stringify(bodyData)}`
      );
    }

    if (action !== "telemetry" && action !== "messages") {
      return errorResponse(400, `Action inconnue : ${action}`);
    }

    if (action === "messages" && (from === undefined || to === undefined)) {
      return errorResponse(400, "Paramètres 'from' et 'to' requis pour les messages");
    }

    // 4. Initialisation des clients Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Client avec auth de l'utilisateur
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      console.error("[flespi-proxy] Auth error:", authError);
      return errorResponse(401, "Token invalide");
    }

    // Client admin (service role) pour les vérifications
    const admin = createClient(supabaseUrl, serviceKey);

    // 5. Vérification du showroom de l'utilisateur
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("showroom_id")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      console.error("[flespi-proxy] Profile error:", profileError);
      return errorResponse(403, "Profil utilisateur introuvable");
    }

    if (profile.showroom_id !== showroomId) {
      console.error(
        "[flespi-proxy] Showroom mismatch:",
        "user.showroom_id=", profile.showroom_id,
        "request.showroomId=", showroomId
      );
      return errorResponse(403, "Accès refusé à ce showroom");
    }

    // 6. ★ Vérification que le device appartient au showroom
    const { data: vehiculeMatch, error: vehicleError } = await admin
      .from("vehicules")
      .select("id, marque, modele")
      .eq("showroom_id", showroomId)
      .eq("flespi_device_id", deviceId)
      .limit(1)
      .maybeSingle();

    if (vehicleError) {
      console.error("[flespi-proxy] Vehicle check error:", vehicleError);
      return errorResponse(500, "Erreur lors de la vérification du véhicule");
    }

    if (!vehiculeMatch) {
      console.error(
        "[flespi-proxy] Device not found:",
        `deviceId=${deviceId}, showroomId=${showroomId}`
      );
      return errorResponse(
        403,
        `Device ${deviceId} n'appartient à aucun véhicule de ce showroom`
      );
    }

    console.log(
      "[flespi-proxy] ✓ Device vérifié:",
      `vehicule=${vehiculeMatch.marque} ${vehiculeMatch.modele}`,
      `(id=${vehiculeMatch.id})`
    );

    // 7. Lecture du token Flespi du showroom
    const { data: showroom, error: showroomError } = await admin
      .from("showrooms")
      .select("flespi_token")
      .eq("id", showroomId)
      .single();

    if (showroomError || !showroom?.flespi_token) {
      console.error("[flespi-proxy] Token error:", showroomError);
      return errorResponse(404, "Token Flespi non configuré pour ce showroom");
    }

    // 8. Construction de l'URL Flespi
    let url: string;
    if (action === "telemetry") {
      url = `https://flespi.io/gw/devices/${deviceId}/telemetry/all`;
    } else {
      url = `https://flespi.io/gw/devices/${deviceId}/messages` +
            `?from=${from}&to=${to}&count=${count}`;
    }

    console.log("[flespi-proxy] → Appel Flespi:", url);

    // 9. Appel Flespi avec retry
    const flespiResp = await fetchFlespiWithRetry(url, showroom.flespi_token);

    // Si fetchFlespiWithRetry a retourné une erreur formatée
    if (flespiResp instanceof Response) {
      return flespiResp;
    }

    // 10. Lecture et parsing de la réponse
    const rawBody = await flespiResp.text();
    console.log(
      "[flespi-proxy] ← HTTP", flespiResp.status,
      "body (200 premiers car.):", rawBody.substring(0, 200)
    );

    let data: unknown;
    try {
      data = JSON.parse(rawBody);
    } catch (_parseError) {
      return errorResponse(
        502,
        `Réponse Flespi non-JSON (HTTP ${flespiResp.status}) : ${rawBody.substring(0, 300)}`
      );
    }

    // 11. Retour de la réponse
    return new Response(JSON.stringify(data), {
      status: flespiResp.status,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[flespi-proxy] Exception non capturée:", error);
    return errorResponse(500, `Erreur serveur interne: ${error}`);
  }
});

// ============================================================================
// FONCTIONS UTILITAIRES
// ============================================================================

/**
 * Appelle Flespi avec timeout + retry sur 429 (rate limit).
 * Retourne soit la Response Flespi (succès ou erreur non-429),
 * soit une Response d'erreur déjà formatée.
 */
async function fetchFlespiWithRetry(
  url: string,
  token: string,
): Promise<Response> {
  let lastStatus = 0;
  let lastError: unknown;

  for (let attempt = 0; attempt <= MAX_RETRIES_429; attempt++) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FLESPI_TIMEOUT_MS);

    try {
      const t0 = Date.now();
      console.log(`[flespi-proxy] → Tentative ${attempt + 1}/${MAX_RETRIES_429 + 1} — envoi fetch à ${new Date(t0).toISOString()}`);

      const resp = await fetch(url, {
        headers: { Authorization: `FlespiToken ${token}` },
        signal: controller.signal,
      });

      console.log(`[flespi-proxy] ← fetch Flespi terminé en ${Date.now() - t0}ms, status=${resp.status}`);

      clearTimeout(timeoutId);
      lastStatus = resp.status;

      // Rate limit : on retente après un backoff
      if (resp.status === 429 && attempt < MAX_RETRIES_429) {
        const waitMs = 400 * (attempt + 1);
        console.warn(`[flespi-proxy] 429 rate-limit — backoff ${waitMs}ms`);
        await new Promise((resolve) => setTimeout(resolve, waitMs));
        continue;
      }

      // Succès ou erreur non-récupérable
      return resp;
    } catch (error) {
      clearTimeout(timeoutId);
      lastError = error;

      if ((error as Error).name === "AbortError") {
        console.error("[flespi-proxy] Timeout après", FLESPI_TIMEOUT_MS, "ms");
        return errorResponse(504, `Flespi n'a pas répondu sous ${FLESPI_TIMEOUT_MS / 1000}s`);
      }

      // Erreur réseau → on retente sauf si c'est la dernière tentative
      if (attempt < MAX_RETRIES_429) {
        const waitMs = 200 * (attempt + 1);
        console.warn(`[flespi-proxy] Erreur réseau, retente dans ${waitMs}ms:`, error);
        await new Promise((resolve) => setTimeout(resolve, waitMs));
        continue;
      }
    }
  }

  return errorResponse(
    502,
    `Erreur Flespi après ${MAX_RETRIES_429 + 1} tentatives: ${lastError}`
  );
}

/**
 * Formate une réponse d'erreur
 */
function errorResponse(status: number, message: string): Response {
  console.error("[flespi-proxy] Error", status, message);
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}