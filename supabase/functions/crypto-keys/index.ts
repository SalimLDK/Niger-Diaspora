// Distribution des clés dérivées du repli AES.
//
// Ce que cet endpoint corrige
// ---------------------------
// Le repli AES utilisait UNE clé globale, constante du binaire
// (`EncryptionService._sharedKeyString`). Deux conséquences :
//   - aucune confidentialité entre utilisateurs : qui extrait la clé de l'APK
//     déchiffre le trafic AES de TOUT LE MONDE ;
//   - aucune rotation possible sans republier une version de l'app.
//
// Ici la racine (`AES_ROOT_KEY_V<n>`) ne quitte JAMAIS le serveur. On en dérive
// des clés de portée réduite, et c'est cette portée — pas le lieu de stockage —
// qui fait la confidentialité : un utilisateur qui extrait ses clés ne lit que
// SES conversations.
//
// Ce que ça n'est pas
// -------------------
// Ce n'est PAS du bout-en-bout : le serveur détient la racine, donc il peut
// déchiffrer. C'est du chiffrement au repos à clés gérées. Le vrai E2EE reste
// Signal (`e2eePayloads` / `senderKeyPayload`) ; ceci ne durcit que le repli,
// emprunté quand aucune session Signal n'est établie.
//
// Ce que ça achète quand même, et qui est réel :
//   - un dump de la base seule ne donne plus rien (aujourd'hui il suffit, la
//     clé étant dans l'APK) ;
//   - un utilisateur ne peut plus lire les conversations des autres ;
//   - la rotation ne demande plus de republier l'app.
//
// Pourquoi distribuer une clé ici, alors que `gif-proxy` refuse justement de le
// faire pour Giphy/Tenor ? Parce que le travail n'est pas le même. Une requête
// GIF peut être faite PAR le serveur. Le chiffrement d'un message, non : le
// faire côté serveur lui livrerait le texte clair en transit — strictement pire
// que ce qu'on cherche à corriger. Le client doit donc chiffrer lui-même, donc
// détenir une clé. Tout ce qu'on peut faire, c'est réduire sa portée.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

// Version de racine à utiliser POUR CHIFFRER. Les versions antérieures restent
// servies pour déchiffrer l'existant : c'est ce qui rend la rotation possible
// sans réécrire toute la base d'un coup.
const VERSION_COURANTE = Number(Deno.env.get('AES_KEY_VERSION') ?? '1')

// Sel du HKDF. Fixe et public par construction (RFC 5869) : le secret est la
// racine, pas le sel. Il ne doit jamais changer — le changer change toutes les
// clés dérivées, donc revient à une rotation silencieuse.
const SEL_HKDF = 'diaspo-niger-repli-aes'

// Garde-fou de taille de réponse. Au-delà, le client pagine par `conversationIds`.
const MAX_CONVERSATIONS = 200

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  if (req.method !== 'POST') {
    return erreur(405, 'Method Not Allowed')
  }

  // Authentification obligatoire, sans exception possible. Un `anon` qui
  // obtiendrait une clé dérivée annulerait tout l'intérêt de la manœuvre.
  //
  // Volontairement PAS de `if (secret) { verifier }` : dans ce dépôt, ce motif
  // a déjà ouvert quatre endpoints en production, parce que le garde saute
  // quand le secret manque. Ici l'absence de configuration doit FERMER.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return erreur(401, 'Authorization header required')
  }

  const userSupabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error: authError } = await userSupabase.auth.getUser()
  if (authError || !user) {
    return erreur(401, 'Invalid or expired token')
  }

  const corps = await req.json().catch(() => null)
  const versionsDemandees = normaliserVersions(corps?.versions)
  const filtreConversations = normaliserIds(corps?.conversationIds)

  // Les racines demandées doivent toutes exister, sinon le client croirait
  // avoir de quoi déchiffrer alors qu'il lui manque une version.
  const racines = new Map<number, ArrayBuffer>()
  for (const v of versionsDemandees) {
    const brute = Deno.env.get(`AES_ROOT_KEY_V${v}`)
    if (!brute) {
      return erreur(503, `racine de version ${v} absente de la configuration`)
    }
    racines.set(v, new TextEncoder().encode(brute).buffer as ArrayBuffer)
  }

  // Participation vérifiée EN BASE, jamais sur déclaration du client : sans ça,
  // demander la clé d'une conversation dont on n'est pas membre suffirait à la
  // lire. C'est le seul contrôle qui fait tenir tout le modèle.
  let requete = userSupabase
    .from('conversations')
    .select('id')
    .contains('participant_ids', [user.id])
    .limit(MAX_CONVERSATIONS)

  if (filtreConversations.length > 0) {
    requete = requete.in('id', filtreConversations)
  }

  const { data: conversations, error: erreurLecture } = await requete
  if (erreurLecture) {
    console.error('crypto-keys: lecture des conversations impossible', erreurLecture.message)
    return erreur(500, 'Lecture des conversations impossible')
  }

  const parVersion: Record<string, unknown> = {}
  for (const [version, racine] of racines) {
    const clesConversations: Record<string, string> = {}
    for (const conversation of conversations ?? []) {
      clesConversations[conversation.id] = await deriver(racine, `conv:${conversation.id}`)
    }
    parVersion[String(version)] = {
      userKey: await deriver(racine, `user:${user.id}`),
      conversationKeys: clesConversations,
    }
  }

  return json(200, {
    success: true,
    keyVersion: VERSION_COURANTE,
    keys: parVersion,
    truncated: (conversations?.length ?? 0) >= MAX_CONVERSATIONS,
  })
})

/// HKDF-SHA256 → 32 octets, encodés en base64.
///
/// Le schéma n'est écrit qu'à DEUX endroits : ici, et dans
/// `decrypt_aes_fallback()` côté Postgres (pour les aperçus push). Le client
/// Dart ne dérive rien — il reçoit ces clés toutes faites, ce qui retire un
/// troisième endroit où diverger.
///
/// Les deux qui restent doivent rester d'accord, et rien ne les compare à
/// l'exécution : un désaccord ne lève aucune erreur, le déchiffrement rend
/// simplement le texte chiffré tel quel. C'est ce qui a laissé la clé AES
/// globale diverger pendant des mois dans ce dépôt. D'où le banc
/// `tools/crypto_tests/derivation_croisee.mjs`, qui fige des vecteurs — le
/// lancer après toute modification ici.
async function deriver(racine: ArrayBuffer, info: string): Promise<string> {
  const cle = await crypto.subtle.importKey('raw', racine, 'HKDF', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode(SEL_HKDF),
      info: new TextEncoder().encode(info),
    },
    cle,
    256,
  )
  return base64(new Uint8Array(bits))
}

function base64(octets: Uint8Array): string {
  let binaire = ''
  for (const octet of octets) binaire += String.fromCharCode(octet)
  return btoa(binaire)
}

/// Versions de racine demandées. Par défaut la seule version courante : un
/// client qui ne demande rien n'a pas besoin de déchiffrer d'ancien contenu.
function normaliserVersions(brut: unknown): number[] {
  if (!Array.isArray(brut)) return [VERSION_COURANTE]
  const versions = brut
    .map((v) => Number(v))
    .filter((v) => Number.isInteger(v) && v >= 1 && v <= VERSION_COURANTE)
  return versions.length > 0 ? [...new Set(versions)] : [VERSION_COURANTE]
}

function normaliserIds(brut: unknown): string[] {
  if (!Array.isArray(brut)) return []
  return brut
    .filter((v): v is string => typeof v === 'string' && v.length > 0 && v.length <= 128)
    .slice(0, MAX_CONVERSATIONS)
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, content-type',
  }
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  })
}

function erreur(status: number, message: string) {
  return json(status, { success: false, error: message })
}
