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

/// Ordre de préférence quand le client demande `auto` : Tenor d'abord (quotas
/// plus généreux), Giphy en repli. Les fournisseurs sans clé sont retirés de
/// la liste **ici** : c'est le seul endroit qui sait lesquelles existent.
const PROVIDER_ORDER = ['tenor', 'giphy'] as const
type Provider = typeof PROVIDER_ORDER[number]

const ENDPOINTS = ['trending', 'search'] as const
const TYPES = ['gif', 'sticker'] as const

const MAX_LIMIT = 50
const MAX_QUERY_LENGTH = 100

/// Par appel de fournisseur, pas pour la requête entière : avec le repli, deux
/// fournisseurs injoignables plafonnent à 16 s au lieu de 20.
const PROVIDER_TIMEOUT_MS = 8_000

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Method Not Allowed')
  }

  // Quota et facturation sont attachés à ces clés : réservé aux comptes
  // authentifiés, sinon n'importe qui peut vider le quota via l'endpoint.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return errorResponse(401, 'unauthenticated', 'Authorization header required')
  }

  const userSupabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: authError } = await userSupabase.auth.getUser()
  if (authError || !user) {
    return errorResponse(401, 'unauthenticated', 'Invalid or expired token')
  }

  const body = await req.json().catch(() => null)
  if (!body || typeof body !== 'object') {
    return errorResponse(400, 'bad_request', 'Body JSON attendu')
  }

  // Listes blanches : aucune valeur venue du client n'atteint une URL sans
  // avoir été comparée à un ensemble fermé.
  //
  // `provider` absent ou `auto` = « celui qui répond » : l'app n'a plus à
  // deviner lesquelles des clés existent, donc plus d'aller-retour perdu à
  // interroger un fournisseur non configuré. Un nom explicite reste accepté
  // pour pouvoir sonder un fournisseur précis depuis un poste de dev.
  const requested = body.provider === undefined || body.provider === 'auto'
    ? 'auto'
    : pickFrom(body.provider, PROVIDER_ORDER)
  if (!requested) {
    return errorResponse(
      400,
      'bad_request',
      `provider doit valoir ${PROVIDER_ORDER.join(', ')} ou auto`,
    )
  }

  const endpoint = pickFrom(body.endpoint, ENDPOINTS)
  if (!endpoint) {
    return errorResponse(400, 'bad_request', `endpoint doit valoir ${ENDPOINTS.join(' ou ')}`)
  }

  const type = pickFrom(body.type, TYPES) ?? 'gif'

  const limit = clampLimit(body.limit)

  let query = ''
  if (endpoint === 'search') {
    if (typeof body.q !== 'string' || body.q.trim().length === 0) {
      return errorResponse(400, 'bad_request', 'q requis pour une recherche')
    }
    query = body.q.trim().slice(0, MAX_QUERY_LENGTH)
  }

  const candidates = requested === 'auto'
    ? PROVIDER_ORDER.filter(hasKey)
    : [requested].filter(hasKey)

  if (candidates.length === 0) {
    // 503 + `code` : le client distingue « aucune clé posée sur le projet »
    // (état durable, message dédié) d'une panne passagère du fournisseur.
    return errorResponse(
      503,
      'no_provider',
      requested === 'auto'
        ? 'Aucun fournisseur de GIFs configuré'
        : `Fournisseur ${requested} non configuré`,
    )
  }

  for (const provider of candidates) {
    const result = await callProvider(provider, endpoint, type, limit, query)
    if (result) {
      // Charge utile du fournisseur relayée verbatim, mais **nommée** : sur
      // `auto`, le client n'a pas choisi, et le parsing dépend de la forme
      // (`results[]` chez Tenor, `data[]` chez Giphy).
      //
      // Un client qui a nommé son fournisseur sait déjà quelle forme lire :
      // on la lui rend telle quelle. Ce n'est pas de la courtoisie, c'est ce
      // qui fait marcher les versions **déjà installées**, qui demandent
      // `tenor` puis `giphy` — les envelopper ici leur donnerait une grille
      // vide, indiscernable d'une recherche sans résultat.
      return jsonResponse(
        200,
        requested === 'auto' ? { provider, payload: result } : result,
      )
    }
  }

  return errorResponse(502, 'provider_error', 'Aucun fournisseur de GIFs disponible')
})

/// Retourne la charge utile du fournisseur, ou `null` s'il a échoué — auquel
/// cas l'appelant passe au suivant.
async function callProvider(
  provider: Provider,
  endpoint: string,
  type: string,
  limit: number,
  query: string,
): Promise<unknown | null> {
  const apiKey = provider === 'giphy' ? GIPHY_API_KEY : TENOR_API_KEY
  const url = provider === 'giphy'
    ? giphyUrl(endpoint, type, limit, query, apiKey)
    : tenorUrl(endpoint, type, limit, query, apiKey)

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS) })
    if (!res.ok) {
      // Le corps de l'erreur du fournisseur peut contenir la clé en clair
      // (elle est dans l'URL) : on ne le relaie jamais tel quel.
      console.error(`gif-proxy: ${provider} a répondu ${res.status}`)
      return null
    }
    return await res.json()
  } catch (err) {
    console.error(
      `gif-proxy: appel ${provider} en échec:`,
      err instanceof Error ? err.message : err,
    )
    return null
  }
}

function hasKey(provider: Provider): boolean {
  return provider === 'giphy' ? GIPHY_API_KEY !== '' : TENOR_API_KEY !== ''
}

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
    // `mediumgif` est demandé pour le média envoyé : le `gif` d'origine monte
    // à plusieurs Mo, que chaque destinataire paie sur sa data.
    media_filter: 'mediumgif,gif,tinygif',
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

function errorResponse(status: number, code: string, message: string) {
  return jsonResponse(status, { success: false, code, error: message })
}
