import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

/**
 * Verifies a Stripe PaymentIntent server-side before marking an order as paid.
 *
 * Security model:
 *   1. Authenticate the caller via Supabase JWT (Firebase UID from app_metadata).
 *   2. Retrieve the PaymentIntent from Stripe — never trust the client's claim.
 *   3. Only update the order if PI status == 'succeeded' AND the caller owns it.
 *   4. Use .eq('status', 'pending') as an idempotence guard.
 *
 * This replaces the previous client-side direct DB update which allowed any
 * authenticated user to mark any order as paid without proof of payment.
 */
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return errorResponse(401, 'Authorization header required')

  const userSupabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: authError } = await userSupabase.auth.getUser()
  if (authError || !user) return errorResponse(401, 'Invalid token')

  const firebaseUid: string =
    (user.app_metadata?.firebase_uid as string | undefined) ?? user.id

  try {
    const body = await req.json()
    const { order_id, payment_intent_id } = body as {
      order_id?: string
      payment_intent_id?: string
    }

    if (!order_id || !payment_intent_id) {
      return errorResponse(400, 'order_id and payment_intent_id are required')
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

    // ── 1. Verify the PaymentIntent with Stripe ──────────────────────────────
    let paymentIntent: Stripe.PaymentIntent
    try {
      paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id)
    } catch (stripeErr) {
      console.error('verify-order-payment: Stripe retrieve error', stripeErr)
      return errorResponse(400, 'Invalid payment_intent_id')
    }

    if (paymentIntent.status !== 'succeeded') {
      return errorResponse(400, `Payment not completed — status: ${paymentIntent.status}`)
    }

    // ── 2. Verify ownership ──────────────────────────────────────────────────
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('id, buyer_id, status')
      .eq('id', order_id)
      .single()

    if (orderError || !order) return errorResponse(404, 'Order not found')
    if (order.buyer_id !== firebaseUid) {
      return errorResponse(403, 'Order does not belong to this user')
    }

    // ── 3. Idempotent update — only transitions from 'pending' ────────────────
    if (order.status !== 'pending') {
      // Already processed (webhook or previous call) — return success silently
      return jsonResponse(200, { success: true, order_id, idempotent: true })
    }

    const { error: updateError } = await supabase
      .from('orders')
      .update({
        status: 'paid',
        escrow_status: 'held',
        stripe_payment_intent_id: payment_intent_id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', order_id)
      .eq('status', 'pending')   // guard: no double-processing

    if (updateError) throw updateError

    console.log(`verify-order-payment: order ${order_id} marked as paid`)

    return jsonResponse(200, { success: true, order_id })
  } catch (err) {
    console.error('verify-order-payment error:', err)
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
