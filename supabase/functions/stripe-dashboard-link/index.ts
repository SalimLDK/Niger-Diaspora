import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

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
    const serviceSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Retrieve the creator's Stripe Connect account ID
    const { data: profile, error: profileError } = await serviceSupabase
      .from('creator_profiles')
      .select('stripe_account_id, stripe_account_status')
      .eq('user_id', user.id)
      .maybeSingle()

    if (profileError || !profile?.stripe_account_id) {
      return errorResponse(404, 'No Stripe Connect account found for this user')
    }

    // Only allow dashboard access for accounts that have completed onboarding
    if (profile.stripe_account_status !== 'active' && profile.stripe_account_status !== 'enabled') {
      return errorResponse(400, 'Stripe Connect account is not yet active. Complete onboarding first.')
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

    const loginLink = await stripe.accounts.createLoginLink(profile.stripe_account_id)

    return jsonResponse(200, {
      success: true,
      url: loginLink.url,
    })
  } catch (err) {
    console.error('stripe-dashboard-link error:', err)
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
