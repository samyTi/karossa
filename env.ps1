$env:SUPABASE_URL = "https://mkrbhyrkrajicthcqjtj.supabase.co"
$env:SUPABASE_ANON_KEY = "sb_publishable_UyjVexlQkh_qO0yiPoiTuA_eJfdz23w"

flutter run -d chrome `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY