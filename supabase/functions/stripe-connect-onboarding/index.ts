import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!
// Le secret pose s'appelle DEEP_LINK_BASE_URL -- meme nom que cote client.
// Cette ligne lisait APP_DEEP_LINK_BASE, qui n'existait nulle part : le repli
// en dur s'appliquait toujours, en silence, sur un hote different de celui
// reellement configure.
// ⚠️ Trou distinct, non corrige ici : aucune route de l'app ne traite
// /stripe/return ni /stripe/refresh.
const APP_DEEP_LINK_BASE = Deno.env.get('DEEP_LINK_BASE_URL') ?? 'https://diasponiger.web.app'

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
    const body = await req.json().catch(() => ({}))
    const { country = 'FR', business_type = 'individual', email } = body

    const serviceSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

    // Check for an existing Stripe Connect account
    const { data: profile } = await serviceSupabase
      .from('creator_profiles')
      .select('stripe_account_id')
      .eq('user_id', user.id)
      .maybeSingle()

    let accountId: string = profile?.stripe_account_id ?? ''

    if (!accountId) {
      // Create a new Stripe Express account
      const accountParams: Stripe.AccountCreateParams = {
        type: 'express',
        country,
        business_type: business_type as Stripe.AccountCreateParams.BusinessType,
        capabilities: { transfers: { requested: true } },
      }
      if (email) {
        accountParams.email = email
      }

      const account = await stripe.accounts.create(accountParams)
      accountId = account.id

      // Upsert creator profile with the new account ID
      const { error: upsertError } = await serviceSupabase
        .from('creator_profiles')
        .upsert({
          user_id: user.id,
          stripe_account_id: accountId,
          stripe_account_status: 'pending',
          updated_at: new Date().toISOString(),
        }, { onConflict: 'user_id' })

      if (upsertError) {
        console.error('stripe-connect-onboarding: upsert error:', upsertError)
        return errorResponse(500, 'Failed to store Stripe account')
      }
    }

    // Create an account link for onboarding
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${APP_DEEP_LINK_BASE}/stripe/refresh`,
      return_url: `${APP_DEEP_LINK_BASE}/stripe/return`,
      type: 'account_onboarding',
    })

    return jsonResponse(200, {
      success: true,
      url: accountLink.url,
      account_id: accountId,
    })
  } catch (err) {
    console.error('stripe-connect-onboarding error:', err)
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
