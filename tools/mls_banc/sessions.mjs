// Fabrique les sessions du banc MLS (plan MLS, phase 3).
//
// Le banc Dart (`test/banc/mls_banc_test.dart`) joue deux appareils contre
// la VRAIE base Supabase, avec le RLS réel. Il lui faut donc deux sessions
// authentifiées portant chacune un claim `firebase_uid` distinct. Ce script
// les fabrique par la même séquence que `tools/sonde_echange_auth.mjs`
// (generateLink → app_metadata → verifyOtp), avec la clé de service de
// `functions/.env` — jamais celle du `.env` racine, qui part dans l'APK.
//
// Il crée deux utilisateurs `sonde-banc-<horodatage>-{a,b}@example.com`, que
// `node tools/purge_comptes_sonde.mjs` sait lister et supprimer (même motif).
//
// Usage :
//   node tools/mls_banc/sessions.mjs > "$TEMP/sessions.json" && \n//     MLS_BANC_SESSIONS="$TEMP/sessions.json" flutter test test/banc
//
// Les jetons expirent au bout de SIX MINUTES (réglage JWT du projet) : fabriquer
// le fichier et lancer le banc dans la même commande, jamais à l'avance.

import { readFileSync } from 'node:fs';

const lire = (fichier, nom) => {
  const m = readFileSync(fichier, 'utf8').match(new RegExp('^' + nom + '=(.*)$', 'm'));
  return m ? m[1].trim().replace(/^["']|["']$/g, '') : null;
};

const url = lire('.env', 'SUPABASE_URL');
const anon = lire('.env', 'SUPABASE_ANON_KEY');
const cle = lire('functions/.env', 'SUPABASE_SERVICE_KEY');
if (!url || !anon || !cle) {
  console.error('SUPABASE_URL / SUPABASE_ANON_KEY (.env) ou SUPABASE_SERVICE_KEY (functions/.env) introuvable.');
  process.exit(2);
}

const enTetes = {
  'Content-Type': 'application/json',
  apikey: cle,
  Authorization: 'Bearer ' + cle,
};

async function session(email, firebaseUid) {
  const rLien = await fetch(url + '/auth/v1/admin/generate_link', {
    method: 'POST',
    headers: enTetes,
    body: JSON.stringify({ type: 'magiclink', email }),
  });
  const lien = await rLien.json();
  if (!rLien.ok) throw new Error('generate_link : ' + JSON.stringify(lien).slice(0, 200));

  const rMaj = await fetch(url + '/auth/v1/admin/users/' + lien.id, {
    method: 'PUT',
    headers: enTetes,
    body: JSON.stringify({ app_metadata: { firebase_uid: firebaseUid } }),
  });
  if (!rMaj.ok) throw new Error('app_metadata : HTTP ' + rMaj.status);

  const rVerif = await fetch(url + '/auth/v1/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: cle },
    body: JSON.stringify({ type: lien.verification_type, token_hash: lien.hashed_token }),
  });
  const verif = await rVerif.json();
  if (!rVerif.ok || !verif.access_token) {
    throw new Error('verify : ' + (verif.msg ?? verif.error_description ?? JSON.stringify(verif)).slice(0, 200));
  }
  const claim = JSON.parse(
    Buffer.from(verif.access_token.split('.')[1], 'base64url').toString('utf8'),
  ).app_metadata?.firebase_uid;
  if (claim !== firebaseUid) throw new Error('claim firebase_uid absent de la session de ' + email);
  return { email, supabaseId: lien.id, uid: firebaseUid, accessToken: verif.access_token };
}

const horodatage = Date.now();
const a = await session(`sonde-banc-${horodatage}-a@example.com`, `banc_a_${horodatage}`);
const b = await session(`sonde-banc-${horodatage}-b@example.com`, `banc_b_${horodatage}`);
const c = await session(`sonde-banc-${horodatage}-c@example.com`, `banc_c_${horodatage}`);

process.stdout.write(JSON.stringify({ url, anonKey: anon, a, b, c, creeLe: new Date().toISOString() }, null, 2));
