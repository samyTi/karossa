// supabase/functions/ai-daily-digest/index.ts
//
// Job quotidien (à planifier via pg_cron / Supabase Scheduled Functions) :
// pour chaque showroom ayant une clé Gemini configurée, calcule un instantané
// des données (côté serveur, pas par le LLM) et demande à Gemini de repérer
// des points d'attention à remonter au gérant. Résultat inséré dans ai_alertes.
//
// Planification (SQL, une fois la fonction déployée) :
//   select cron.schedule('ai-daily-digest', '0 6 * * *',
//     $$ select net.http_post(
//          url:='https://<project-ref>.supabase.co/functions/v1/ai-daily-digest',
//          headers:='{"Authorization": "Bearer <SERVICE_ROLE_KEY>"}'::jsonb
//        ); $$
//   );

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: showrooms, error } = await supabase
    .from('showrooms')
    .select('id, nom, gemini_api_key, gemini_model')
    .not('gemini_api_key', 'is', null);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const results: Record<string, string> = {};

  for (const showroom of showrooms ?? []) {
    try {
      const alertesGenerees = await analyserShowroom(supabase, showroom);
      results[showroom.id] = `${alertesGenerees} alerte(s) générée(s)`;
    } catch (e) {
      console.error(`Erreur showroom ${showroom.id}`, e);
      results[showroom.id] = `échec: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  return new Response(JSON.stringify({ results }), {
    headers: { 'Content-Type': 'application/json' },
  });
});

async function analyserShowroom(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  showroom: { id: string; nom: string; gemini_api_key: string; gemini_model: string | null },
): Promise<number> {
  const now = new Date();
  const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const rangeStart = new Date(now.getFullYear(), now.getMonth() - 3, 1);
  const iso = (d: Date) => d.toISOString().substring(0, 10);

  const [{ data: caisse }, { data: vehicules }, { data: locationsRetard }, { data: alertesEntretien }] =
    await Promise.all([
      supabase
        .from('caisse_operations')
        .select('categorie,type,montant,date_op')
        .eq('showroom_id', showroom.id)
        .gte('date_op', iso(rangeStart))
        .limit(1000),
      supabase.from('vehicules').select('statut').eq('showroom_id', showroom.id).limit(1000),
      supabase
        .from('locations')
        .select('id')
        .eq('showroom_id', showroom.id)
        .eq('statut', 'retard')
        .limit(200),
      supabase
        .from('alertes_entretien')
        .select('type_alerte,date_echeance')
        .eq('showroom_id', showroom.id)
        .eq('statut', 'active')
        .limit(200),
    ]);

  // Agrégation par catégorie/mois pour la détection d'anomalies.
  const currentKey = iso(currentMonthStart).substring(0, 7);
  // deno-lint-ignore no-explicit-any
  const buckets = new Map<string, Map<string, number>>();
  for (const row of caisse ?? []) {
    const key = `${row.categorie}|${row.type}`;
    const moisKey = String(row.date_op).substring(0, 7);
    if (!buckets.has(key)) buckets.set(key, new Map());
    const m = buckets.get(key)!;
    m.set(moisKey, (m.get(moisKey) ?? 0) + Number(row.montant ?? 0));
  }

  const anomalies: Array<Record<string, unknown>> = [];
  for (const [key, moisData] of buckets) {
    const [categorie, type] = key.split('|');
    const current = moisData.get(currentKey) ?? 0;
    const precedents = [...moisData.entries()].filter(([k]) => k !== currentKey).map(([, v]) => v);
    if (precedents.length === 0) continue;
    const moyenne = precedents.reduce((a, b) => a + b, 0) / precedents.length;
    const variation = moyenne === 0 ? (current > 0 ? 100 : 0) : ((current - moyenne) / moyenne) * 100;
    if (Math.abs(variation) >= 30) {
      anomalies.push({ categorie, type, montant_mois_courant: current, moyenne_3_mois: moyenne, variation_pct: Math.round(variation) });
    }
  }

  const parStatut: Record<string, number> = {};
  for (const v of vehicules ?? []) {
    parStatut[v.statut] = (parStatut[v.statut] ?? 0) + 1;
  }

  const snapshot = {
    parc_par_statut: parStatut,
    locations_en_retard: (locationsRetard ?? []).length,
    alertes_entretien_actives: (alertesEntretien ?? []).map((a: { type_alerte: string; date_echeance: string }) => a.type_alerte),
    anomalies_financieres: anomalies,
  };

  // Rien de notable : pas d'appel Gemini inutile, pas d'alerte insérée.
  const rienASignaler =
    snapshot.locations_en_retard === 0 &&
    snapshot.alertes_entretien_actives.length === 0 &&
    anomalies.length === 0;
  if (rienASignaler) return 0;

  const alertes = await demanderAGemini(showroom, snapshot);
  if (alertes.length === 0) return 0;

  const rows = alertes.map((a) => ({
    showroom_id: showroom.id,
    type: a.type ?? 'autre',
    titre: a.titre,
    message: a.message,
    severite: a.severite ?? 'info',
  }));

  const { error: insertError } = await supabase.from('ai_alertes').insert(rows);
  if (insertError) throw insertError;
  return rows.length;
}

async function demanderAGemini(
  showroom: { gemini_api_key: string; gemini_model: string | null },
  snapshot: Record<string, unknown>,
  // deno-lint-ignore no-explicit-any
): Promise<any[]> {
  const model = showroom.gemini_model || 'gemini-2.0-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${showroom.gemini_api_key}`;

  const prompt = `Tu es KarossaAI. Voici un instantané du showroom (déjà calculé, ne recalcule rien) :
${JSON.stringify(snapshot)}

Génère UNIQUEMENT un tableau JSON (aucun texte autour, pas de markdown) d'alertes pertinentes pour le gérant,
maximum 4 alertes, chacune au format :
{"type":"anomalie_financiere|entretien|rentabilite|opportunite|autre","titre":"court","message":"1-2 phrases en français, DA obligatoire pour les montants","severite":"info|attention|urgent"}
Ne génère une alerte que si la donnée le justifie réellement. Si rien de notable, retourne [].`;

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: 'application/json' },
    }),
  });

  if (!res.ok) {
    console.error('Erreur Gemini', await res.text());
    return [];
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '[]';
  try {
    const parsed = JSON.parse(text);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}