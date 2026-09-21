// Banc : getUsersForPush n'injecte jamais dans son URL PostgREST.
//
//   node tools/rules_tests/get_users_for_push.mjs
//
// Condition : 0 ÉCHEC.
//
// Ni réseau, ni Supabase : `global.fetch` est remplacé par un espion qui
// CAPTURE l'URL et rend une réponse vide. On vérifie l'URL construite, jamais
// un appel réel.
//
// ── Ce qui est en jeu ─────────────────────────────────────────────────────
//
// `getUsersForPush` bâtit `id=in.("a","b")` par concaténation. Un identifiant
// contenant `"`, `)` ou `,` réécrirait le filtre. Ces identifiants viennent
// d'ordinaire de Supabase (sûrs), mais l'aide en reçoit aussi d'origine
// cliente (le document d'appel). Depuis le 2026-09-21 elle filtre sur la forme
// d'un uid AVANT de concaténer : un id malformé est ignoré, jamais inséré.
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// Le cas 1 vise l'injection qui lirait TOUTE la table. Sur la version d'avant
// (concaténation directe, sans filtre), l'id forgé apparaîtrait tel quel dans
// l'URL et le banc échouerait — c'est ce que la fonction courante empêche.

import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const require_ = createRequire(join(RACINE, "functions", "package.json"));

// Config bidon AVANT le require : le module lit process.env au chargement.
process.env.SUPABASE_URL = "https://exemple.invalid";
process.env.SUPABASE_SERVICE_KEY = "cle-bidon-de-test";

const { getUsersForPush } = require_(join(RACINE, "functions", "supabase.js"));

let urlCapturee = null;
global.fetch = async (url) => {
  urlCapturee = String(url);
  return { ok: true, json: async () => [], text: async () => "" };
};

const resultats = [];
async function cas(n, libelle, ids, verifie) {
  urlCapturee = null;
  await getUsersForPush(ids);
  let ok = false;
  try { ok = verifie(urlCapturee); } catch { ok = false; }
  resultats.push({ n, libelle, verdict: ok ? "OK" : "ÉCHEC", url: urlCapturee });
}

const ID_FORGE = 'x")&id=not.is.null&y=("';

// La partie in-list de l'URL (entre `id=in.(` et le `)` de fermeture).
function inList(url) {
  if (!url) return null;
  const m = url.match(/id=in\.\(([^)]*)\)/);
  return m ? m[1] : null;
}

await cas(1, "LA FAILLE — un id forgé pour réécrire le filtre n'apparaît jamais dans l'URL",
  ["uidAlice", ID_FORGE, "uidBob"],
  (url) => !!url && !url.includes("not.is.null") && !url.includes('x")'));

await cas(2, "les deux id valides sont bien présents",
  ["uidAlice", ID_FORGE, "uidBob"],
  (url) => { const l = inList(url); return l.includes('"uidAlice"') && l.includes('"uidBob"'); });

await cas(3, "l'id forgé est retiré de l'in-list",
  ["uidAlice", ID_FORGE],
  (url) => inList(url) === '"uidAlice"');

await cas(4, "un id vide ou espace ne passe pas",
  ["uidAlice", "", "  ", "uidBob"],
  (url) => { const l = inList(url); return l === '"uidAlice","uidBob"'; });

await cas(5, "les doublons sont dédupliqués",
  ["uidAlice", "uidAlice", "uidBob"],
  (url) => inList(url) === '"uidAlice","uidBob"');

await cas(6, "aucun id valide : pas de requête du tout",
  [ID_FORGE, ""],
  () => urlCapturee === null);

await cas(7, "un id Firestore hérité (20 alphanum) passe",
  ["aB3xY7zK9mNpQ2rS4tU6"],
  (url) => inList(url) === '"aB3xY7zK9mNpQ2rS4tU6"');

await cas(8, "un id avec `-` et `_` (forme uid) passe",
  ["a_b-C3", "d-e_F4"],
  (url) => inList(url) === '"a_b-C3","d-e_F4"');

for (const r of resultats) {
  console.log(`${String(r.n).padStart(2)} ${r.verdict.padEnd(6)} ${r.libelle}`);
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\n>>> ${echecs} ÉCHEC(S) sur ${resultats.length}`);
process.exit(echecs ? 1 : 0);
