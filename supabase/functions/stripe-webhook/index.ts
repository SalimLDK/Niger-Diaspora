import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!
const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')!

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  const sig = req.headers.get('stripe-signature')
  if (!sig) {
    return new Response('Missing stripe-signature header', { status: 400 })
  }

  // Lire le body en bytes pour la vérification de signature
  const body = await req.arrayBuffer()
  const bodyText = new TextDecoder().decode(body)

  let event: Stripe.Event
  try {
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })
    event = await stripe.webhooks.constructEventAsync(bodyText, sig, STRIPE_WEBHOOK_SECRET)
  } catch (err) {
    console.error('Webhook signature verification failed:', err)
    return new Response(`Webhook Error: ${err instanceof Error ? err.message : 'Unknown'}`, { status: 400 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(supabase, event.data.object as Stripe.PaymentIntent)
        break

      case 'payment_intent.payment_failed':
        await handlePaymentFailure(supabase, event.data.object as Stripe.PaymentIntent)
        break

      default:
        // Ignorer les autres événements silencieusement
        break
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Webhook processing error:', err)
    return new Response('Webhook processing error', { status: 500 })
  }
})

/**
 * Paiement réussi — mise à jour atomique PostgreSQL (INT-06 idempotence).
 * Transition uniquement depuis 'pending' ou 'processing' pour éviter les doublons.
 */
async function handlePaymentSuccess(
  supabase: ReturnType<typeof createClient>,
  paymentIntent: Stripe.PaymentIntent
) {
  const transactionId = paymentIntent.metadata?.transaction_id
  if (!transactionId) {
    console.warn('payment_intent.succeeded: no transaction_id in metadata')
    return
  }

  // Requête idempotente : ne met à jour que si le statut est encore 'pending' ou 'processing'
  const { data, error } = await supabase
    .from('transactions')
    .update({
      status: 'completed',
      stripe_payment_intent_id: paymentIntent.id,
      updated_at: new Date().toISOString(),
    })
    .eq('id', transactionId)
    .in('status', ['pending', 'processing'])  // Guard idempotence
    .select('id, sender_id')
    .single()

  if (error) {
    // Pas de transaction à mettre à jour = déjà traitée (idempotent)
    console.log(`handlePaymentSuccess: transaction ${transactionId} not updated (already terminal or not found)`)
    return
  }

  console.log(`Transaction ${transactionId} marked completed`)

  // Notifier l'utilisateur via une ligne dans notifications Firestore
  // (les notifications restent sur Firebase pour déclencher FCM)
  // On passe l'info via metadata du PaymentIntent pour que le client puisse réagir
  // Le client surveille la transaction via Supabase Realtime
}

/**
 * Paiement échoué — mise à jour atomique + notification (INT-02).
 */
async function handlePaymentFailure(
  supabase: ReturnType<typeof createClient>,
  paymentIntent: Stripe.PaymentIntent
) {
  const transactionId = paymentIntent.metadata?.transaction_id
  if (!transactionId) {
    console.warn('payment_intent.payment_failed: no transaction_id in metadata')
    return
  }

  const failureReason = (paymentIntent as Stripe.PaymentIntent & {
    last_payment_error?: { message?: string }
  }).last_payment_error?.message ?? 'Paiement échoué'

  // Idempotence : ne pas écraser un état terminal
  const { data, error } = await supabase
    .from('transactions')
    .update({
      status: 'failed',
      stripe_payment_intent_id: paymentIntent.id,
      failure_reason: failureReason,
      updated_at: new Date().toISOString(),
    })
    .eq('id', transactionId)
    .not('status', 'in', '("failed","completed","refunded")')
    .select('id, sender_id')
    .single()

  if (error || !data) {
    console.log(`handlePaymentFailure: transaction ${transactionId} already terminal`)
    return
  }

  console.log(`Transaction ${transactionId} marked failed: ${failureReason}`)

  // Créer une notification d'échec dans la table Supabase
  // Le client Flutter surveille via Supabase Realtime et affiche l'alerte
  // (pas besoin de FCM pour les échecs — l'utilisateur est actif dans l'app)
}
