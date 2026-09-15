// Nettoie les données laissées en production par le banc MLS.
//
// Le banc (`test/banc/mls_banc_test.dart`) travaille contre la VRAIE base :
// il y crée des conversations, des appareils, des KeyPackages, des commits,
// des Welcome et des messages chiffrés, tous rattachés aux comptes
// `banc_{a,b,c}_<horodatage>` fabriqués par `sessions.mjs`. Sans ce script,
// chaque exécution en laisse une couche de plus.
//
// Ce qui part, et dans cet ordre :
//   1. conversations créées par un compte de banc — la cascade emporte
//      `mls_messages`, `mls_commits`, `mls_welcomes`, `conversation_devices` ;
//   2. `mls_devices` de ces comptes — la cascade emporte `mls_key_packages` ;
//   3. `mls_diagnostics` de ces comptes.
//
// Les comptes d'authentification eux-mêmes se suppriment à part, avec
// `node tools/purge_comptes_sonde.mjs --confirmer` (motif `sonde-banc-…`).
//
// Usage :
//   node tools/mls_banc/purge.mjs              # compte seulement, n'écrit rien
//   node tools/mls_banc/purge.mjs --confirmer  # supprime

import { readFileSync } from 'node:fs';

const lire = (fichier, nom) => {
  const m = readFileSync(fichier, 'utf8').match(new RegExp('^' + nom + '=(.*)$', 'm'));
  return m ? m[1].trim().replace(/^["']|["']$/g, '') : null;
};

const url = lire('.env', 'SUPABASE_URL');
const cle = lire('functions/.env', 'SUPABASE_SERVICE_KEY');
if (!url || !cle) {
  console.error('SUPABASE_URL (.env) ou SUPABASE_SERVICE_KEY (functions/.env) introuvable.');
  process.exit(2);
}

const confirmer = process.argv.includes('--confirmer');
const enTetes = {
  'Content-Type': 'application/json',
  apikey: cle,
  Authorization: 'Bearer ' + cle,
  Prefer: 'return=representation',
};

// `banc_a_…`, `banc_b_…`, `banc_c_…` : le motif est ancré, il ne peut pas
// attraper un compte réel (les uid Firebase font 28 caractères alphanumériques).
//
// Encodé pour l'URL : sans ça, le `%` du LIKE et l'antislash d'échappement
// sortent tels quels et le CDN rend une page d'erreur HTML en 500 — ce qui
// ressemble à une panne de base alors que c'est la requête qui est malformée.
const MOTIF = encodeURIComponent('banc\\_%');

async function rest(chemin, methode = 'GET') {
  const r = await fetch(url + '/rest/v1/' + chemin, { method: methode, headers: enTetes });
  const corps = await r.text();
  if (!r.ok) throw new Error(`${methode} ${chemin} → HTTP ${r.status} ${corps.slice(0, 200)}`);
  return corps ? JSON.parse(corps) : [];
}

const cibles = [
  ['conversations', `conversations?created_by=like.${MOTIF}`],
  ['mls_devices', `mls_devices?user_id=like.${MOTIF}`],
  ['mls_diagnostics', `mls_diagnostics?user_id=like.${MOTIF}`],
];

let total = 0;
for (const [nom, requete] of cibles) {
  const lignes = await rest(requete + '&select=id');
  console.log(`${nom.padEnd(16)} ${String(lignes.length).padStart(4)} ligne(s)`);
  total += lignes.length;
  if (confirmer && lignes.length > 0) {
    const supprimees = await rest(requete, 'DELETE');
    console.log(`${' '.repeat(16)} ${String(supprimees.length).padStart(4)} supprimée(s)`);
  }
}

if (!confirmer) {
  console.log(`\n${total} ligne(s) au total. Relancer avec --confirmer pour supprimer.`);
  console.log('Les comptes d\'authentification : node tools/purge_comptes_sonde.mjs --confirmer');
}
