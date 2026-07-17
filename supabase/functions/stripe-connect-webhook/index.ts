import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!
const STRIPE_CONNECT_WEBHOOK_SECRET = Deno.env.get('STRIPE_CONNECT_WEBHOOK_SECRET')!

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  const sig = req.headers.get('stripe-signature')
  if (!sig) {
    return new Response('Missing stripe-signature header', { status: 400 })
  }

  // Read body as bytes for signature verification
  const body = await req.arrayBuffer()
  const bodyText = new TextDecoder().decode(body)

  let event: Stripe.Event
  try {
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })
    event = await stripe.webhooks.constructEventAsync(bodyText, sig, STRIPE_CONNECT_WEBHOOK_SECRET)
  } catch (err) {
    console.error('stripe-connect-webhook: signature verification failed:', err)
    return new Response(`Webhook Error: ${err instanceof Error ? err.message : 'Unknown'}`, { status: 400 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    switch (event.type) {
      case 'account.updated':
        await handleAccountUpdated(supabase, event.data.object as Stripe.Account)
        break

      case 'payout.paid':
        await handlePayoutPaid(supabase, event.data.object as Stripe.Payout, event.account)
        break

      case 'payout.failed':
        await handlePayoutFailed(supabase, event.data.object as Stripe.Payout, event.account)
        break

      default:
        // Silently ignore other events
        break
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('stripe-connect-webhook: processing error:', err)
    return new Response('Webhook processing error', { status: 500 })
  }
})

/**
 * account.updated — sync account status to creator_profiles.
 * Stripe sends this whenever the connected account's capabilities or requirements change.
 */
async function handleAccountUpdated(
  supabase: ReturnType<typeof createClient>,
  account: Stripe.Account
) {
  const transfersEnabled = account.capabilities?.transfers === 'active'
  const payoutsEnabled = account.payouts_enabled ?? false
  const chargesEnabled = account.charges_enabled ?? false

  // Determine a simplified status for our app
  let status: string
  if (transfersEnabled && payoutsEnabled && chargesEnabled) {
    status = 'active'
  } else if (account.details_submitted) {
    status = 'enabled'
  } else {
    status = 'pending'
  }

  const { error } = await supabase
    .from('creator_profiles')
    .update({
      stripe_account_status: status,
      payout_enabled: payoutsEnabled,
      charges_enabled: chargesEnabled,
      details_submitted: account.details_submitted ?? false,
      updated_at: new Date().toISOString(),
    })
    .eq('stripe_account_id', account.id)

  if (error) {
    console.error(`handleAccountUpdated: failed to update account ${account.id}:`, error)
    throw error
  }

  console.log(`Account ${account.id} updated: status=${status}, payouts=${payoutsEnabled}`)
}

/**
 * payout.paid — log successful payout to activity feed.
 */
async function handlePayoutPaid(
  supabase: ReturnType<typeof createClient>,
  payout: Stripe.Payout,
  connectedAccountId: string | undefined
) {
  if (!connectedAccountId) {
    console.warn('payout.paid: no connected account ID in event')
    return
  }

  // Resolve the creator user_id from their Stripe account ID
  const { data: profile } = await supabase
    .from('creator_profiles')
    .select('user_id')
    .eq('stripe_account_id', connectedAccountId)
    .maybeSingle()

  if (!profile?.user_id) {
    console.warn(`payout.paid: no creator found for account ${connectedAccountId}`)
    return
  }

  await supabase.from('creator_activity').insert({
    user_id: profile.user_id,
    type: 'payout_paid',
    stripe_payout_id: payout.id,
    amount: payout.amount,
    currency: payout.currency,
    arrival_date: new Date(payout.arrival_date * 1000).toISOString(),
    description: payout.description ?? null,
    created_at: new Date().toISOString(),
  })

  console.log(`Payout ${payout.id} paid for account ${connectedAccountId}: ${payout.amount} ${payout.currency}`)
}

/**
 * payout.failed — log failed payout to activity feed.
 */
async function handlePayoutFailed(
  supabase: ReturnType<typeof createClient>,
  payout: Stripe.Payout,
  connectedAccountId: string | undefined
) {
  if (!connectedAccountId) {
    console.warn('payout.failed: no connected account ID in event')
    return
  }

  // Resolve the creator user_id from their Stripe account ID
  const { data: profile } = await supabase
    .from('creator_profiles')
    .select('user_id')
    .eq('stripe_account_id', connectedAccountId)
    .maybeSingle()

  if (!profile?.user_id) {
    console.warn(`payout.failed: no creator found for account ${connectedAccountId}`)
    return
  }

  const failureReason = (payout as Stripe.Payout & { failure_message?: string }).failure_message
    ?? payout.failure_code
    ?? 'Payout failed'

  await supabase.from('creator_activity').insert({
    user_id: profile.user_id,
    type: 'payout_failed',
    stripe_payout_id: payout.id,
    amount: payout.amount,
    currency: payout.currency,
    failure_reason: failureReason,
    description: payout.description ?? null,
    created_at: new Date().toISOString(),
  })

  console.log(`Payout ${payout.id} failed for account ${connectedAccountId}: ${failureReason}`)
}
