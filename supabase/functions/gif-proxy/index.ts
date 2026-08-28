import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

// Les clés des fournisseurs ne quittent jamais ce fichier : l'app envoie une
// requête métier (« tendances », « recherche »), pas une clé. C'est la seule
// conception qui les sort réellement de l'APK — leur faire télécharger la clé
// au démarrage la rendrait extractible par quiconque possède l'application.
const GIPHY_API_KEY = Deno.env.get('GIPHY_API_KEY') ?? ''
const TENOR_API_KEY = Deno.env.get('TENOR_API_KEY') ?? ''

const GIPHY_BASE = 'https://api.giphy.com/v1'
const TENOR_BASE = 'https://tenor.googleapis.com/v2'

/// Classification Giphy : `g` = tout public. Filtre Tenor : `high` = le plus strict.
const GIPHY_RATING = 'g'
const TENOR_CONTENT_FILTER = 'high'

const PROVIDERS = ['giphy', 'tenor'] as const
const ENDPOINTS = ['trending', 'search'] as const
const TYPES = ['gif', 'sticker'] as const

const MAX_LIMIT = 50
const MAX_QUERY_LENGTH = 100

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method Not Allowed')
  }

  // Quota et facturation sont attachés à ces clés : réservé aux comptes
  // authentifiés, sinon n'importe qui peut vider le quota via l'endpoint.
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

  const body = await req.json().catch(() => null)
  if (!body || typeof body !== 'object') {
    return errorResponse(400, 'Body JSON attendu')
  }

  // Listes blanches : aucune valeur venue du client n'atteint une URL sans
  // avoir été comparée à un ensemble fermé.
  const provider = pickFrom(body.provider, PROVIDERS)
  if (!provider) return errorResponse(400, `provider doit valoir ${PROVIDERS.join(' ou ')}`)

  const endpoint = pickFrom(body.endpoint, ENDPOINTS)
  if (!endpoint) return errorResponse(400, `endpoint doit valoir ${ENDPOINTS.join(' ou ')}`)

  const type = pickFrom(body.type, TYPES) ?? 'gif'

  const limit = clampLimit(body.limit)

  let query = ''
  if (endpoint === 'search') {
    if (typeof body.q !== 'string' || body.q.trim().length === 0) {
      return errorResponse(400, 'q requis pour une recherche')
    }
    query = body.q.trim().slice(0, MAX_QUERY_LENGTH)
  }

  const apiKey = provider === 'giphy' ? GIPHY_API_KEY : TENOR_API_KEY
  if (!apiKey) {
    // 503 et non 500 : le client bascule sur l'autre fournisseur au lieu de
    // présenter une erreur à l'utilisateur.
    return errorResponse(503, `Fournisseur ${provider} non configuré`)
  }

  const url = provider === 'giphy'
    ? giphyUrl(endpoint, type, limit, query, apiKey)
    : tenorUrl(endpoint, type, limit, query, apiKey)

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(10_000) })
    if (!res.ok) {
      // Le corps de l'erreur du fournisseur peut contenir la clé en clair
      // (elle est dans l'URL) : on ne le relaie jamais tel quel.
      console.error(`gif-proxy: ${provider} a répondu ${res.status}`)
      return errorResponse(502, `${provider} indisponible`)
    }

    // Charge utile renvoyée verbatim : le parsing Dart existant
    // (`data[]` pour Giphy, `results[]` pour Tenor) reste inchangé.
    const payload = await res.json()
    return jsonResponse(200, payload)
  } catch (err) {
    console.error(`gif-proxy: appel ${provider} en échec:`, err instanceof Error ? err.message : err)
    return errorResponse(502, `${provider} indisponible`)
  }
})

function giphyUrl(
  endpoint: string,
  type: string,
  limit: number,
  query: string,
  apiKey: string,
): string {
  // Giphy expose les stickers sur un chemin distinct de celui des GIFs.
  const segment = type === 'sticker' ? 'stickers' : 'gifs'
  const params = new URLSearchParams({
    api_key: apiKey,
    limit: String(limit),
    rating: GIPHY_RATING,
  })
  if (endpoint === 'search') params.set('q', query)
  return `${GIPHY_BASE}/${segment}/${endpoint}?${params}`
}

function tenorUrl(
  endpoint: string,
  type: string,
  limit: number,
  query: string,
  apiKey: string,
): string {
  // Tenor nomme « featured » ce que Giphy appelle « trending ».
  const path = endpoint === 'trending' ? 'featured' : 'search'
  const params = new URLSearchParams({
    key: apiKey,
    limit: String(limit),
    contentfilter: TENOR_CONTENT_FILTER,
    media_filter: 'gif,tinygif',
  })
  if (type === 'sticker') params.set('searchfilter', 'sticker')
  if (endpoint === 'search') params.set('q', query)
  return `${TENOR_BASE}/${path}?${params}`
}

function pickFrom<T extends readonly string[]>(
  value: unknown,
  allowed: T,
): T[number] | null {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value)
    ? (value as T[number])
    : null
}

function clampLimit(value: unknown): number {
  const n = typeof value === 'number' ? Math.trunc(value) : Number.parseInt(String(value ?? ''), 10)
  if (!Number.isFinite(n) || n < 1) return 30
  return Math.min(n, MAX_LIMIT)
}

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
