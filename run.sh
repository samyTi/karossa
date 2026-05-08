#!/bin/bash
# run.sh — Script de lancement en développement
# Copiez vos vraies valeurs ici (ce fichier est dans .gitignore)
# Ne jamais committer ce fichier avec de vraies clés !

SUPABASE_URL="https://mkrbhyrkrajicthcqjtj.supabase.co"
SUPABASE_ANON_KEY="sb_publishable_UyjVexlQkh_qO0yiPoiTuA_eJfdz23w"
GEMINI_API_KEY="VOTRE_CLE_GEMINI"          # optionnel si BACKEND_URL défini
BACKEND_URL=""                              # optionnel : URL du backend Next.js

flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY \
  --dart-define=BACKEND_URL=$BACKEND_URL
