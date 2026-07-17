import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID')!
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN')!
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER')!

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

function generateOtp(): string {
  return String(Math.floor(100000 + Math.random() * 900000))
}

async function sendSms(to: string, body: string): Promise<void> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`
  const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${credentials}`,
    },
    body: new URLSearchParams({ To: to, From: TWILIO_PHONE_NUMBER, Body: body }).toString(),
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Twilio: ${err}`)
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
    if (!phoneNumber || !/^\+[1-9]\d{7,14}$/.test(phoneNumber)) {
      return err(400, 'Numéro invalide — format E.164 requis (ex: +22799123456)')
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Rate limit : max 3 envois par utilisateur/numéro par heure
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count } = await supabase
      .from('phone_verifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', firebaseUid)
      .eq('phone_number', phoneNumber)
      .gte('created_at', oneHourAgo)

    if ((count ?? 0) >= 3) {
      return err(429, 'Trop de tentatives. Réessayez dans une heure.')
    }

    const code = generateOtp()
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString()

    const { error: insertErr } = await supabase.from('phone_verifications').insert({
      user_id: firebaseUid,
      phone_number: phoneNumber,
      code,
      expires_at: expiresAt,
    })
    if (insertErr) throw insertErr

    await sendSms(phoneNumber, `Diaspo Niger – Code de vérification : ${code}. Valable 10 min.`)

    return ok({ success: true })
  } catch (e) {
    console.error('send-phone-otp:', e)
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
