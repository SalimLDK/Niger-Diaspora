import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

// Currencies where amount is NOT multiplied by 100 (XOF = Franc CFA)
const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif','clp','gnf','jpy','kmf','krw','mga','pyg',
  'rwf','ugx','vnd','vuv','xaf','xof','xpf',
])

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  // Authenticate via Supabase JWT (set by SupabaseAuthBridge in Flutter)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return errorResponse(401, 'Authorization header required')
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const userSupabase = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: authError } = await userSupabase.auth.getUser()
  if (authError || !user) {
    return errorResponse(401, 'Invalid or expired token')
  }

  // users.sender_id est un Firebase UID (TEXT), pas le UUID Supabase Auth.
  // L'Edge Function auth-firebase-exchange stocke le Firebase UID dans app_metadata.
  const firebaseUid: string = (user.app_metadata?.firebase_uid as string | undefined) ?? user.id

  try {
    const body = await req.json()
    const { transaction_id, metadata } = body

    if (!transaction_id) {
      return errorResponse(400, 'transaction_id is required')
    }

    // ── C3 Security Fix : dériver montant/devise depuis PostgreSQL ─────────
    // Ne jamais faire confiance aux valeurs envoyées par le client.
    const { data: transaction, error: txError } = await supabase
      .from('transactions')
      .select('id, sender_id, amount, currency, status, stripe_payment_intent_id')
      .eq('id', transaction_id)
      .single()

    if (txError || !transaction) {
      return errorResponse(404, `Transaction ${transaction_id} not found`)
    }

    // Vérifier que l'appelant est bien le propriétaire (Firebase UID, pas Supabase UUID)
    if (transaction.sender_id !== firebaseUid) {
      return errorResponse(403, 'User does not own this transaction')
    }

    const trustedAmount: number = transaction.amount
    const trustedCurrency: string = transaction.currency.toLowerCase()

    if (!trustedAmount || trustedAmount <= 0) {
      return errorResponse(400, 'Invalid transaction amount')
    }

    // ── C4 Idempotency : retourner le PI existant si déjà créé ────────────
    if (transaction.stripe_payment_intent_id && transaction.status !== 'pending') {
      return jsonResponse(200, {
        success: true,
        payment_intent_id: transaction.stripe_payment_intent_id,
        idempotent: true,
      })
    }

    // ── Créer le PaymentIntent Stripe ─────────────────────────────────────
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

    // XOF et autres zero-decimal : ne pas multiplier par 100
    const piAmount = ZERO_DECIMAL_CURRENCIES.has(trustedCurrency)
      ? Math.round(trustedAmount)
      : Math.round(trustedAmount * 100)

    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount: piAmount,
        currency: trustedCurrency,
        metadata: {
          user_id: firebaseUid,
          transaction_id,
          ...(metadata ?? {}),
        },
        automatic_payment_methods: { enabled: true },
      },
      { idempotencyKey: `pi_${transaction_id}` }
    )

    // Mettre à jour la transaction avec l'ID du PaymentIntent
    await supabase
      .from('transactions')
      .update({
        stripe_payment_intent_id: paymentIntent.id,
        status: 'processing',
        updated_at: new Date().toISOString(),
      })
      .eq('id', transaction_id)

    return jsonResponse(200, {
      success: true,
      payment_intent_id: paymentIntent.id,
      client_secret: paymentIntent.client_secret,
    })

  } catch (err) {
    console.error('create-payment-intent error:', err)
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
