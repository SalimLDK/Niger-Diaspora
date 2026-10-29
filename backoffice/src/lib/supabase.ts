import { createClient } from '@supabase/supabase-js'
import { env } from './env'

export const supabase = createClient(env.supabaseUrl, env.supabaseAnonKey, {
  auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: false },
})

/** Échange un jeton Firebase contre une session Supabase (pont existant). */
export async function echangerJeton(firebaseToken: string): Promise<void> {
  const res = await fetch(`${env.supabaseUrl}/functions/v1/auth-firebase-exchange`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: env.supabaseAnonKey },
    body: JSON.stringify({ firebase_token: firebaseToken }),
  })
  if (!res.ok) throw new Error(`Pont d'authentification refusé (${res.status})`)
  const s = (await res.json()) as { access_token?: string; refresh_token?: string }
  if (!s.access_token || !s.refresh_token) throw new Error('Pont d\'authentification : réponse incomplète')
  const { error } = await supabase.auth.setSession({
    access_token: s.access_token,
    refresh_token: s.refresh_token,
  })
  if (error) throw error
}

export { messageErreur } from './erreurs'
