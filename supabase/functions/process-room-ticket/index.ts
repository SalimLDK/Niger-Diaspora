import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

// Platform commission rate: 15%
const PLATFORM_COMMISSION_RATE = 0.15

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
    const { room_id, room_title, seller_id, price_amount, currency } = body

    // Input validation
    if (!room_id) return errorResponse(400, 'room_id is required')
    if (!seller_id) return errorResponse(400, 'seller_id is required')
    // `price_amount` est en UNITÉ MINEURE (centimes pour EUR, francs entiers
    // pour XOF) — convention Stripe et convention des entités Dart. La
    // fonction attendait des unités majeures et multipliait par 100 : le
    // client envoyant déjà des centimes, le billet aurait été facturé 100
    // fois trop cher.
    if (!Number.isInteger(price_amount) || price_amount <= 0) {
      return errorResponse(400, 'price_amount must be a positive integer in minor units')
    }
    if (!currency) return errorResponse(400, 'currency is required')
    if (seller_id === user.id) {
      return errorResponse(400, 'Cannot buy a ticket to your own room')
    }

    const serviceSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })
    const normalizedCurrency = currency.toLowerCase()

    // Idempotency: check if buyer already has a valid ticket for this room
    const { data: existingTicket } = await serviceSupabase
      .from('room_tickets')
      .select('id, stripe_payment_intent_id, status')
      .eq('room_id', room_id)
      .eq('user_id', user.id)
      .in('status', ['pending', 'completed', 'active'])
      .maybeSingle()

    if (existingTicket) {
      // Return existing ticket if already completed
      if (existingTicket.status === 'completed' || existingTicket.status === 'active') {
        return jsonResponse(200, {
          success: true,
          ticket_id: existingTicket.id,
          payment_intent_id: existingTicket.stripe_payment_intent_id,
          status: existingTicket.status,
          idempotent: true,
        })
      }
      // Return existing pending ticket so the client can confirm it
      if (existingTicket.status === 'pending' && existingTicket.stripe_payment_intent_id) {
        return jsonResponse(200, {
          success: true,
          ticket_id: existingTicket.id,
          payment_intent_id: existingTicket.stripe_payment_intent_id,
          status: 'pending',
          idempotent: true,
        })
      }
    }

    // Verify the seller has a Stripe Connect account
    const { data: sellerProfile, error: sellerError } = await serviceSupabase
      .from('creator_profiles')
      .select('stripe_account_id, stripe_account_status')
      .eq('user_id', seller_id)
      .maybeSingle()

    if (sellerError || !sellerProfile?.stripe_account_id) {
      return errorResponse(404, 'Seller does not have a payment account set up')
    }
    if (sellerProfile.stripe_account_status !== 'active' && sellerProfile.stripe_account_status !== 'enabled') {
      return errorResponse(400, 'Seller payment account is not active')
    }

    // Commission en unité mineure elle aussi : le montant reste entier, ce que
    // le client relit en `int`. L'ancien calcul produisait un décimal que le
    // cast Dart `as int?` faisait retomber à 0.
    const commissionAmount = Math.round(price_amount * PLATFORM_COMMISSION_RATE)
    const sellerAmount = price_amount - commissionAmount

    // Stripe attend déjà l'unité mineure : plus aucune conversion ici.
    const stripeAmount = price_amount
    const stripeSellerAmount = sellerAmount

    // Insert ticket record (pending)
    const { data: ticket, error: ticketInsertError } = await serviceSupabase
      .from('room_tickets')
      .insert({
        room_id,
        user_id: user.id,
        seller_id,
        amount: price_amount,
        currency: normalizedCurrency,
        commission_amount: commissionAmount,
        seller_amount: sellerAmount,
        status: 'pending',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select('id')
      .single()

    if (ticketInsertError || !ticket) {
      console.error('process-room-ticket: insert error:', ticketInsertError)
      return errorResponse(500, 'Failed to create ticket record')
    }

    // Create Stripe PaymentIntent with transfer_data to seller's account
    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount: stripeAmount,
        currency: normalizedCurrency,
        transfer_data: {
          destination: sellerProfile.stripe_account_id,
          amount: stripeSellerAmount,
        },
        metadata: {
          ticket_id: ticket.id,
          room_id,
          room_title: room_title ?? '',
          buyer_id: user.id,
          seller_id,
        },
        automatic_payment_methods: { enabled: true },
      },
      { idempotencyKey: `ticket_${ticket.id}` }
    )

    // Update ticket with PaymentIntent ID
    await serviceSupabase
      .from('room_tickets')
      .update({
        stripe_payment_intent_id: paymentIntent.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', ticket.id)

    return jsonResponse(200, {
      success: true,
      ticket_id: ticket.id,
      payment_intent_id: paymentIntent.client_secret,
      status: 'pending',
    })
  } catch (err) {
    console.error('process-room-ticket error:', err)
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
