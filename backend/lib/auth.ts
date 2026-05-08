import { NextRequest } from 'next/server';

/** Vérifie la clé API interne pour les routes backend-to-backend */
export function verifyApiKey(req: NextRequest): boolean {
  const key = req.headers.get('x-api-key');
  return key === process.env.API_SECRET_KEY;
}

/** Vérifie le token JWT Supabase passé dans Authorization: Bearer <token> */
export async function verifySupabaseToken(req: NextRequest): Promise<string | null> {
  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const token = authHeader.replace('Bearer ', '').trim();
    if (!token) return null;

    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return null;
    return user.id;
  } catch {
    return null;
  }
}
