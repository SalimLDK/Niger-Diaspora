// Banc de dérivation croisée des clés du repli AES.
//
// Pourquoi ce fichier existe
// --------------------------
// Le schéma HKDF qui dérive les clés de repli est écrit TROIS FOIS : en
// TypeScript (supabase/functions/crypto-keys), en Dart (le client, qui chiffre)
// et en SQL (decrypt_aes_fallback, qui fabrique les aperçus push). Trois copies
// d'une même règle, sans rien qui les compare, c'est exactement la
// configuration qui a laissé la clé AES globale diverger pendant des mois :
// aucune erreur ne remonte quand deux implémentations ne sont plus d'accord,
// le déchiffrement rend simplement le texte chiffré tel quel.
//
// Ce banc fige donc des VECTEURS (racine connue → clé attendue) que les trois
// implémentations doivent reproduire. Le vecteur est la référence ; le code qui
// s'en écarte a tort, quel qu'il soit.
//
//   node tools/crypto_tests/derivation_croisee.mjs           # vérifie
//   node tools/crypto_tests/derivation_croisee.mjs --ecrire   # (re)génère
//
// La régénération ne doit servir qu'à ÉTENDRE la liste. Regénérer pour faire
// passer un test qui échoue revient à effacer la seule alarme disponible.

import { hkdfSync, webcrypto } from 'node:crypto'
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ICI = dirname(fileURLToPath(import.meta.url))
const FICHIER_VECTEURS = join(ICI, 'vecteurs_derivation.json')

// Doit rester identique à SEL_HKDF dans supabase/functions/crypto-keys/index.ts.
const SEL_HKDF = 'diaspo-niger-repli-aes'

// Racine FACTICE, réservée aux vecteurs. Ce n'est pas la racine de production
// et elle ne doit jamais l'être : ce fichier est versionné.
const RACINE_TEST = 'racine-de-test-jamais-en-production--'

/// Implémentation 1 : WebCrypto, copie exacte de celle de l'Edge Function.
/// `crypto.subtle` se comporte de façon identique sous Deno et sous Node.
async function deriverWebCrypto(racine, info) {
  const cle = await webcrypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(racine),
    'HKDF',
    false,
    ['deriveBits'],
  )
  const bits = await webcrypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode(SEL_HKDF),
      info: new TextEncoder().encode(info),
    },
    cle,
    256,
  )
  return Buffer.from(bits).toString('base64')
}

/// Implémentation 2 : HKDF de node:crypto, indépendante de la précédente.
/// Deux chemins qui tombent d'accord prouvent qu'on fait bien du HKDF RFC 5869
/// standard -- donc que Dart (`cryptography`) et Postgres (`pgcrypto`) peuvent
/// le reproduire, au lieu d'un schéma maison qu'eux seuls sauraient relire.
function deriverNode(racine, info) {
  const bits = hkdfSync('sha256', Buffer.from(racine), Buffer.from(SEL_HKDF), Buffer.from(info), 32)
  return Buffer.from(bits).toString('base64')
}

const CAS = [
  { nom: 'utilisateur', info: 'user:11111111-1111-4111-8111-111111111111' },
  { nom: 'utilisateur bis', info: 'user:22222222-2222-4222-8222-222222222222' },
  { nom: 'conversation uuid', info: 'conv:33333333-3333-4333-8333-333333333333' },
  // Id hérité de Firestore : 20 caractères, pas un uuid. La dérivation ne doit
  // faire aucune hypothèse de format -- ces conversations existent encore.
  { nom: 'conversation heritee Firestore', info: 'conv:AbCdEfGhIjKlMnOpQrSt' },
  // Non-ASCII : le client encode en UTF-8, les trois implémentations doivent
  // s'accorder sur les octets, pas sur les caractères.
  { nom: 'accents et emoji', info: 'conv:Maïdaoua-Niamey-🔐' },
]

async function main() {
  const ecrire = process.argv.includes('--ecrire')

  const calcules = {}
  let desaccords = 0

  for (const cas of CAS) {
    const parWebCrypto = await deriverWebCrypto(RACINE_TEST, cas.info)
    const parNode = deriverNode(RACINE_TEST, cas.info)

    if (parWebCrypto !== parNode) {
      console.error(`DESACCORD INTERNE sur « ${cas.nom} » : WebCrypto et node:crypto divergent`)
      desaccords++
      continue
    }
    calcules[cas.info] = parWebCrypto
  }

  if (desaccords > 0) {
    console.error('\nLe schema n_est pas du HKDF standard : Dart et SQL ne pourront pas le reproduire.')
    process.exit(1)
  }

  if (ecrire) {
    mkdirSync(ICI, { recursive: true })
    writeFileSync(
      FICHIER_VECTEURS,
      JSON.stringify({ sel: SEL_HKDF, racine: RACINE_TEST, longueur: 32, vecteurs: calcules }, null, 2) + '\n',
      'utf8',
    )
    console.log(`Vecteurs ecrits : ${Object.keys(calcules).length} cas -> ${FICHIER_VECTEURS}`)
    return
  }

  let attendus
  try {
    attendus = JSON.parse(readFileSync(FICHIER_VECTEURS, 'utf8'))
  } catch {
    console.error(`Vecteurs absents. Les generer une premiere fois :\n  node ${process.argv[1]} --ecrire`)
    process.exit(1)
  }

  if (attendus.sel !== SEL_HKDF || attendus.racine !== RACINE_TEST) {
    console.error('Le sel ou la racine de test a change : toutes les cles derivees changent avec.')
    console.error('Si c_est voulu, regenerer avec --ecrire ET verifier Dart et SQL dans la foulee.')
    process.exit(1)
  }

  let echecs = 0
  for (const [info, attendu] of Object.entries(attendus.vecteurs)) {
    const obtenu = calcules[info]
    if (obtenu === undefined) {
      console.error(`MANQUANT  ${info} — present dans les vecteurs, absent des cas`)
      echecs++
    } else if (obtenu !== attendu) {
      console.error(`ECART     ${info}\n  attendu ${attendu}\n  obtenu  ${obtenu}`)
      echecs++
    } else {
      console.log(`ok        ${info}`)
    }
  }

  for (const info of Object.keys(calcules)) {
    if (!(info in attendus.vecteurs)) {
      console.error(`NOUVEAU   ${info} — cas ajoute sans regenerer les vecteurs (--ecrire)`)
      echecs++
    }
  }

  console.log(
    echecs === 0
      ? `\nDERIVATION : CONFORME (${Object.keys(attendus.vecteurs).length} vecteurs)`
      : `\nDERIVATION : ${echecs} ecart(s)`,
  )
  process.exit(echecs === 0 ? 0 : 1)
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
