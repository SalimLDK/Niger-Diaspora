import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

// Platform commission rate: 15%
const PLATFORM_COMMISSION_RATE = 0.15

// Currencies where amount is NOT multiplied by 100 (XOF = Franc CFA)
const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif', 'clp', 'gnf', 'jpy', 'kmf', 'krw', 'mga', 'pyg',
  'rwf', 'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf',
])

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method Not Allowed')
  }

  // Authenticate via Supabase JWT
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return errorResponse(401, 'Authorization header required')
  }

  const userSupabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: authError } = await userSupabase.auth.getUser()
  if (authError || !user) {
    return errorResponse(401, 'Invalid or expired token')
  }

  try {
    const body = await req.json()
    const { room_id, recipient_id, amount, currency, message } = body

    // Input validation
    if (!room_id) return errorResponse(400, 'room_id is required')
    if (!recipient_id) return errorResponse(400, 'recipient_id is required')
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return errorResponse(400, 'amount must be a positive number')
    }
    if (!currency) return errorResponse(400, 'currency is required')
    if (recipient_id === user.id) {
      return errorResponse(400, 'Cannot tip yourself')
    }

    const serviceSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

    // Verify the room exists and is active
    const { data: room, error: roomError } = await serviceSupabase
      .from('audio_rooms')
      .select('id, status')
      .eq('id', room_id)
      .maybeSingle()

    if (roomError || !room) {
      return errorResponse(404, `Room ${room_id} not found`)
    }
    if (room.status !== 'active' && room.status !== 'live') {
      return errorResponse(400, 'Room is not currently active')
    }

    // Verify the recipient exists and has a Stripe Connect account
    const { data: recipientProfile, error: recipientError } = await serviceSupabase
      .from('creator_profiles')
      .select('stripe_account_id, stripe_account_status')
      .eq('user_id', recipient_id)
      .maybeSingle()

    if (recipientError || !recipientProfile?.stripe_account_id) {
      return errorResponse(404, 'Recipient does not have a payment account set up')
    }
    if (recipientProfile.stripe_account_status !== 'active' && recipientProfile.stripe_account_status !== 'enabled') {
      return errorResponse(400, 'Recipient payment account is not active')
    }

    // Calculate commission amounts
    const normalizedCurrency = currency.toLowerCase()
    const commissionAmount = Math.round(amount * PLATFORM_COMMISSION_RATE * 100) / 100
    const recipientAmount = Math.round((amount - commissionAmount) * 100) / 100

    // Convert to Stripe amount units
    const isZeroDecimal = ZERO_DECIMAL_CURRENCIES.has(normalizedCurrency)
    const stripeAmount = isZeroDecimal ? Math.round(amount) : Math.round(amount * 100)
    const stripeRecipientAmount = isZeroDecimal
      ? Math.round(recipientAmount)
      : Math.round(recipientAmount * 100)

    // Create a tip record first (pending) so we have the ID for idempotency
    const { data: tip, error: tipInsertError } = await serviceSupabase
      .from('tips')
      .insert({
        room_id,
        sender_id: user.id,
        recipient_id,
        amount,
        currency: normalizedCurrency,
        commission_amount: commissionAmount,
        recipient_amount: recipientAmount,
        message: message ?? null,
        status: 'pending',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select('id')
      .single()

    if (tipInsertError || !tip) {
      console.error('process-tip: insert error:', tipInsertError)
      return errorResponse(500, 'Failed to create tip record')
    }

    // Create Stripe PaymentIntent with transfer_data to recipient's account
    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount: stripeAmount,
        currency: normalizedCurrency,
        transfer_data: {
          destination: recipientProfile.stripe_account_id,
          amount: stripeRecipientAmount,
        },
        metadata: {
          tip_id: tip.id,
          room_id,
          sender_id: user.id,
          recipient_id,
        },
        automatic_payment_methods: { enabled: true },
      },
      { idempotencyKey: `tip_${tip.id}` }
    )

    // Update tip with PaymentIntent ID
    await serviceSupabase
      .from('tips')
      .update({
        stripe_payment_intent_id: paymentIntent.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', tip.id)

    return jsonResponse(200, {
      success: true,
      tip_id: tip.id,
      payment_intent_id: paymentIntent.client_secret,
      status: 'pending',
    })
  } catch (err) {
    console.error('process-tip error:', err)
    return errorResponse(500, err instanceof Error ? err.message : 'Internal error')
  }
})

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, content-type',
  }
}

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  })
}

function errorResponse(status: number, message: string) {
  return jsonResponse(status, { success: false, error: message })
}
