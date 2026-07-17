import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!

function getFirebaseUid(authHeader: string): string | null {
  const token = authHeader.replace('Bearer ', '').trim()
  const parts = token.split('.')
  if (parts.length !== 3) return null
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    return (payload?.app_metadata?.firebase_uid as string | undefined) ?? null
  } catch {
    return null
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' },
    })
  }

  try {
    const firebaseUid = getFirebaseUid(req.headers.get('Authorization') ?? '')
    if (!firebaseUid) return err(401, 'Non authentifié')

    const body = await req.json()
    const phoneNumber: string = body?.phone_number ?? ''
    const code: string = body?.code ?? ''

    if (!phoneNumber || !code) return err(400, 'phone_number et code requis')

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Chercher la vérification active (non expirée, non utilisée)
    const now = new Date().toISOString()
    const { data: verification, error: fetchErr } = await supabase
      .from('phone_verifications')
      .select('*')
      .eq('user_id', firebaseUid)
      .eq('phone_number', phoneNumber)
      .is('verified_at', null)
      .gt('expires_at', now)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (fetchErr) throw fetchErr
    if (!verification) return err(400, 'Code invalide ou expiré')

    const attempts: number = verification.attempts ?? 0
    if (attempts >= 5) return err(429, 'Trop de tentatives incorrectes. Demandez un nouveau code.')

    // Incrémenter les tentatives
    await supabase
      .from('phone_verifications')
      .update({ attempts: attempts + 1 })
      .eq('id', verification.id)

    if (verification.code !== code) {
      const remaining = 4 - attempts
      return err(400, `Code incorrect. ${remaining} tentative(s) restante(s).`)
    }

    // Marquer comme vérifié
    await supabase
      .from('phone_verifications')
      .update({ verified_at: new Date().toISOString() })
      .eq('id', verification.id)

    // Mettre à jour le profil utilisateur
    const { error: updateErr } = await supabase
      .from('users')
      .update({ phone_number: phoneNumber, is_verified: true })
      .eq('id', firebaseUid)

    if (updateErr) throw updateErr

    return ok({ success: true })
  } catch (e) {
    console.error('verify-phone-otp:', e)
    return err(500, e instanceof Error ? e.message : 'Erreur interne')
  }
})

function ok(data: unknown) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  })
}

function err(status: number, message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  })
}
