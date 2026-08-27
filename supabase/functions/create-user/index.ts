// supabase/functions/create-user/index.ts
//
// Crée un compte Supabase Auth + la ligne profiles correspondante.
// Appelée par le gérant depuis l'app Flutter (jamais la clé service_role
// côté client). Vérifie que l'appelant est bien 'gerant' avant d'agir.
//
// Déploiement :
//   supabase functions deploy create-user
//
// Variables d'env déjà fournies automatiquement par Supabase :
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Non authentifié' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Client "appelant" : sert uniquement à identifier qui fait la requête
    // (respecte le RLS, ne peut rien faire de privilégié).
    const supabaseCaller = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user: caller },
      error: callerErr,
    } = await supabaseCaller.auth.getUser();

    if (callerErr || !caller) {
      return new Response(JSON.stringify({ error: 'Non authentifié' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Client admin : seul ce client peut créer des comptes / ignorer le RLS.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Vérifie que l'appelant est bien gérant, et récupère son showroom.
    const { data: callerProfile, error: profileErr } = await supabaseAdmin
      .from('profiles')
      .select('role, showroom_id')
      .eq('id', caller.id)
      .single();

    if (profileErr || !callerProfile || callerProfile.role !== 'gerant') {
      return new Response(
        JSON.stringify({ error: 'Action réservée au gérant du showroom' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const { email, password, nom, prenom, telephone, role } = await req.json();

    if (!email || !password || !nom || !prenom || !role) {
      return new Response(
        JSON.stringify({ error: 'Champs requis manquants' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }
    if (!['gerant', 'externe'].includes(role)) {
      return new Response(JSON.stringify({ error: 'Rôle invalide' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (String(password).length < 6) {
      return new Response(
        JSON.stringify({ error: 'Mot de passe trop court (6 caractères min.)' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // 1. Création du compte auth
    const { data: created, error: createErr } =
      await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });

    if (createErr || !created.user) {
      return new Response(
        JSON.stringify({ error: createErr?.message ?? 'Création du compte échouée' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // 2. Création du profil, rattaché au MÊME showroom que le gérant appelant
    // (jamais celui envoyé par le client — évite qu'un gérant crée un
    // utilisateur dans un autre showroom en trafiquant la requête).
    const { error: insertErr } = await supabaseAdmin.from('profiles').insert({
      id: created.user.id,
      nom,
      prenom,
      telephone: telephone || null,
      role,
      showroom_id: callerProfile.showroom_id,
    });

    if (insertErr) {
      // Rollback : on supprime le compte auth orphelin créé juste avant.
      await supabaseAdmin.auth.admin.deleteUser(created.user.id);
      return new Response(JSON.stringify({ error: insertErr.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ success: true, id: created.user.id }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});