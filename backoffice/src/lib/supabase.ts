import { createClient } from '@supabase/supabase-js'
import { env } from './env'
import { demoActif } from '../demo/etat'
import { clientDemo } from '../demo/client'

const reel = createClient(env.supabaseUrl, env.supabaseAnonKey, {
  auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: false },
})

/**
 * Tout le code passe par `supabase`. En mode démo, les appels vont au faux client en mémoire (aucun réseau) ; sinon au vrai.
 * Le choix se fait à CHAQUE appel : sortir de la démo rend immédiatement le vrai client.
 */
export const supabase = new Proxy(reel, {
  get(cible, prop) {
    const c = (demoActif() ? clientDemo : cible) as unknown as Record<string | symbol, unknown>
    const v = c[prop]
    return typeof v === 'function' ? (v as (...a: unknown[]) => unknown).bind(c) : v
  },
}) as typeof reel

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
