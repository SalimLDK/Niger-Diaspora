// Ménage des comptes jetables laissés par les bancs de test.
//
//   node tools/purge_comptes_sonde.mjs              # liste seulement, ne supprime rien
//   node tools/purge_comptes_sonde.mjs --confirmer  # supprime pour de bon
//
// `tools/sonde_echange_auth.mjs` crée deux utilisateurs Supabase à chaque
// exécution et ne les supprime pas ; les vérifications de bout en bout en
// créent d'autres, côté Firebase ET Supabase. Ils s'accumulent. Ce script les
// retrouve et les supprime — mais seulement eux.
//
// ⚠️ La suppression est DÉFINITIVE et porte sur la base de PRODUCTION. D'où
// les trois garde-fous :
//
//   1. Sans `--confirmer`, le script ne fait que lire et afficher. Toujours
//      lancer une fois sans, et relire la liste avant de la relancer avec.
//   2. Le filtre est un motif exact et fermé (`^(sonde|verif)-…@example.com$`),
//      pas un « contient ». Un compte qui n'y répond pas n'est jamais touché,
//      et n'est même jamais affiché.
//   3. `test.diaspo@example.com` — le vrai compte de test, cf.
//      `scripts/creer_compte_test.js` — ne correspond pas au motif, et est en
//      plus exclu nommément.
//
// N'affiche ni clé ni jeton.

import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const CONFIRME = process.argv.includes('--confirmer');

/// Seules ces adresses sont candidates. Motif ancré des deux côtés : rien
/// d'autre ne peut y répondre par accident.
const MOTIF = /^(sonde|verif)-[a-z0-9-]+@example\.com$/;

/// Ceinture et bretelles : même si le motif venait à s'élargir un jour.
const A_GARDER = new Set(['test.diaspo@example.com']);

const estJetable = (email) => Boolean(email) && MOTIF.test(email) && !A_GARDER.has(email);

const lire = (fichier, nom) => {
  const ligne = readFileSync(fichier, 'utf8')
    .split(/\r?\n/)
    .find((l) => l.startsWith(nom + '='));
  return ligne ? ligne.slice(nom.length + 1).trim() : null;
};

const url = lire('.env', 'SUPABASE_URL');
const cle = lire('functions/.env', 'SUPABASE_SERVICE_KEY');
if (!url || !cle) {
  console.error('SUPABASE_URL (.env) ou SUPABASE_SERVICE_KEY (functions/.env) introuvable.');
  console.error('Lancer depuis la racine du dépôt.');
  process.exit(1);
}
const enTetes = { apikey: cle, Authorization: 'Bearer ' + cle };

// ---------------------------------------------------------------- Supabase

async function sondesSupabase() {
  const trouves = [];
  for (let page = 1; page <= 50; page += 1) {
    const r = await fetch(url + `/auth/v1/admin/users?page=${page}&per_page=200`, {
      headers: enTetes,
    });
    if (!r.ok) throw new Error('liste Supabase : HTTP ' + r.status);
    const { users } = await r.json();
    if (!users?.length) break;
    for (const u of users) if (estJetable(u.email)) trouves.push({ id: u.id, email: u.email });
    if (users.length < 200) break;
  }
  return trouves;
}

async function supprimerSupabase({ id, email }) {
  // La ligne `users` publique part avec, si elle existe : elle est clé sur
  // l'uid Firebase, pas sur l'id gotrue, d'où les deux appels.
  const r = await fetch(url + '/auth/v1/admin/users/' + id, { method: 'DELETE', headers: enTetes });
  return r.ok ? 'supprimé' : 'ÉCHEC HTTP ' + r.status + ' (' + email + ')';
}

// ---------------------------------------------------------------- Firebase

/// La clé de service n'est chargée que si elle est là : le ménage Supabase
/// doit pouvoir tourner sans elle.
function firebaseAdmin() {
  const require = createRequire(import.meta.url);
  const fs = require('node:fs');
  const chemin = fs.readdirSync(process.cwd()).find((f) => /-adminsdk-.*\.json$/.test(f));
  if (!chemin) return null;
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(require(process.cwd() + '/' + chemin)) });
  }
  return admin;
}

async function sondesFirebase(admin) {
  const trouves = [];
  let pageToken;
  do {
    const res = await admin.auth().listUsers(1000, pageToken);
    for (const u of res.users) if (estJetable(u.email)) trouves.push({ uid: u.uid, email: u.email });
    pageToken = res.pageToken;
  } while (pageToken);
  return trouves;
}

// -------------------------------------------------------------------- Main

const supabase = await sondesSupabase();
const admin = firebaseAdmin();
const firebase = admin ? await sondesFirebase(admin) : null;

console.log('');
console.log(`Supabase : ${supabase.length} compte(s) jetable(s)`);
for (const u of supabase) console.log('  ' + u.email);
if (firebase) {
  console.log(`Firebase : ${firebase.length} compte(s) jetable(s)`);
  for (const u of firebase) console.log('  ' + u.email);
} else {
  console.log('Firebase : clé de service absente de la racine — non inspecté.');
}
console.log('');

if (!CONFIRME) {
  console.log('Rien supprimé. Relire la liste ci-dessus, puis relancer avec --confirmer.');
  process.exit(0);
}

for (const u of supabase) console.log('Supabase ' + u.email + ' : ' + (await supprimerSupabase(u)));
for (const u of firebase ?? []) {
  await admin.auth().deleteUser(u.uid);
  console.log('Firebase ' + u.email + ' : supprimé');
}
console.log('');
console.log('Terminé.');
process.exit(0);
