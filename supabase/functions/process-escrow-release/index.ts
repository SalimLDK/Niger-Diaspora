import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif','clp','gnf','jpy','kmf','krw','mga','pyg',
  'rwf','ugx','vnd','vuv','xaf','xof','xpf',
])

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return errorResponse(401, 'Authorization header required')

  // Identifier l'appelant via son JWT Supabase
  const userSupabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: authError } = await userSupabase.auth.getUser()
  if (authError || !user) return errorResponse(401, 'Invalid token')

  // orders.buyer_id est un Firebase UID (TEXT), pas le UUID Supabase Auth.
  const firebaseUid: string = (user.app_metadata?.firebase_uid as string | undefined) ?? user.id

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    const body = await req.json()
    const { order_id } = body
    if (!order_id) return errorResponse(400, 'order_id is required')

    // ── Étape 1 : Lire et verrouiller l'escrow atomiquement ─────────────────
    // On utilise une transaction PostgreSQL (via RPC) pour éviter les races.
    // L'order passe de escrow_status='held' → 'releasing' de façon atomique.
    const { data: lockResult, error: lockError } = await supabase.rpc(
      'lock_escrow_for_release',
      { p_order_id: order_id, p_caller_id: firebaseUid }
    )

    if (lockError) {
      console.error('lock_escrow_for_release error:', lockError)
      return errorResponse(400, lockError.message)
    }

    if (!lockResult?.success) {
      return errorResponse(400, lockResult?.error ?? 'Cannot release escrow')
    }

    const order = lockResult.order as {
      id: string
      seller_id: string
      total_amount: number
      currency: string
      stripe_payment_intent_id: string | null
    }

    // ── Étape 2 : Résoudre le compte Stripe Connect du vendeur ───────────────
    const { data: creatorProfile } = await supabase
      .from('creator_profiles')
      .select('stripe_account_id, payout_enabled')
      .eq('user_id', order.seller_id)
      .single()

    if (!creatorProfile?.stripe_account_id || !creatorProfile.payout_enabled) {
      // Restaurer le statut escrow
      await supabase
        .from('orders')
        .update({ escrow_status: 'held' })
        .eq('id', order_id)
      return errorResponse(400, 'Seller has no Stripe Connect account configured')
    }

    // ── Étape 3 : Créer le Stripe Transfer ───────────────────────────────────
    const currency = order.currency.toLowerCase()
    // Commissions : 10% plateforme, 90% vendeur
    const sellerAmount = Math.round(order.total_amount * 0.9)
    const amountInCents = ZERO_DECIMAL_CURRENCIES.has(currency)
      ? Math.round(sellerAmount)
      : Math.round(sellerAmount * 100)

    if (amountInCents <= 0) {
      await supabase.from('orders').update({ escrow_status: 'held' }).eq('id', order_id)
      return errorResponse(400, 'Invalid seller amount')
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

    const transferParams: Stripe.TransferCreateParams = {
      amount: amountInCents,
      currency,
      destination: creatorProfile.stripe_account_id,
      metadata: { order_id, seller_id: order.seller_id },
    }
    if (order.stripe_payment_intent_id) {
      transferParams.transfer_group = order.stripe_payment_intent_id
    }

    let transfer: Stripe.Transfer
    try {
      transfer = await stripe.transfers.create(transferParams)
    } catch (stripeErr) {
      // Restaurer le statut escrow pour permettre une nouvelle tentative
      await supabase.from('orders').update({ escrow_status: 'held' }).eq('id', order_id)
      throw stripeErr
    }

    // ── Étape 4 : Finaliser dans PostgreSQL ──────────────────────────────────
    await supabase
      .from('orders')
      .update({
        status: 'completed',
        escrow_status: 'released',
        updated_at: new Date().toISOString(),
      })
      .eq('id', order_id)

    // Mettre à jour l'escrow_transactions si elle existe
    await supabase
      .from('escrow_transactions')
      .update({
        status: 'released',
        stripe_transfer_id: transfer.id,
        released_at: new Date().toISOString(),
      })
      .eq('order_id', order_id)

    console.log(`Escrow released: transfer ${transfer.id} for order ${order_id}`)

    return jsonResponse(200, {
      success: true,
      transfer_id: transfer.id,
    })

  } catch (err) {
    console.error('process-escrow-release error:', err)
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
