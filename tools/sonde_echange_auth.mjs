// Banc de l'échange Firebase -> Supabase (`auth-firebase-exchange`).
//
//   node tools/sonde_echange_auth.mjs
//
// Rejoue, depuis le poste et contre le gotrue réel, la séquence des étapes
// 2 -> 3 -> 5 de la fonction sur un utilisateur NEUF, deux fois :
//
//   TÉMOIN    verifyOtp avec le type écrit en dur (`magiclink`) — l'ancien code
//   CORRECTIF verifyOtp avec le type réellement émis par generateLink
//
// Sortie attendue : le témoin échoue (« Email link is invalid or has expired »),
// le correctif rend une session portant le claim `firebase_uid`. Si le témoin
// se met à passer, c'est que gotrue a changé de comportement — et que le
// commentaire de `typeEmis()` dans la fonction est devenu faux.
//
// Une TROISIÈME mesure suit, sur le compte du correctif (qui existe alors) :
// deux `generateLink` coup sur coup, le second invalidant le jeton du premier.
// C'est la seconde cause du même message — celle qui frappe deux échanges
// concurrents — et elle vérifie la reprise ajoutée à l'étape 5. Elle ne crée
// aucun compte de plus.
//
// ⚠️ Ce banc a besoin d'utilisateurs NEUFS pour reproduire quoi que ce soit :
// il en crée donc deux à chaque exécution, dans le projet Supabase de
// PRODUCTION, et il ne les supprime pas. Leurs adresses sont affichées à la
// fin — à supprimer depuis le dashboard (Authentication > Users) quand elles
// s'accumulent. Elles sont toutes en `example.com` et préfixées `sonde-`.
//
// N'affiche ni clé ni jeton.

import { readFileSync } from 'node:fs';

const lire = (fichier, nom) => {
  const ligne = readFileSync(fichier, 'utf8')
    .split(/\r?\n/)
    .find((l) => l.startsWith(nom + '='));
  return ligne ? ligne.slice(nom.length + 1).trim() : null;
};

const url = lire('.env', 'SUPABASE_URL');
// La clé de service ne vit que dans functions/.env — jamais dans le .env
// racine, qui part dans l'APK (cf. project_env_three_files_apk_leak).
const cle = lire('functions/.env', 'SUPABASE_SERVICE_KEY');

if (!url || !cle) {
  console.error(
    'SUPABASE_URL (.env) ou SUPABASE_SERVICE_KEY (functions/.env) introuvable.\n' +
      'Lancer depuis la racine du dépôt.',
  );
  process.exit(1);
}

const enTetes = {
  'Content-Type': 'application/json',
  apikey: cle,
  Authorization: 'Bearer ' + cle,
};

const claimDe = (accessToken) =>
  JSON.parse(Buffer.from(accessToken.split('.')[1], 'base64url').toString('utf8'))
    .app_metadata?.firebase_uid;

async function sequence(email, typeFige) {
  // Étape 2 : generateLink — crée l'utilisateur s'il n'existe pas.
  const rLien = await fetch(url + '/auth/v1/admin/generate_link', {
    method: 'POST',
    headers: enTetes,
    body: JSON.stringify({ type: 'magiclink', email }),
  });
  const lien = await rLien.json();
  if (!rLien.ok) return { ok: false, detail: 'étape 2 : ' + JSON.stringify(lien).slice(0, 200) };

  // Étape 3 : updateUserById, pour poser app_metadata.firebase_uid.
  const rMaj = await fetch(url + '/auth/v1/admin/users/' + lien.id, {
    method: 'PUT',
    headers: enTetes,
    body: JSON.stringify({ app_metadata: { firebase_uid: 'sonde_' + Date.now() } }),
  });
  if (!rMaj.ok) return { ok: false, detail: 'étape 3 : HTTP ' + rMaj.status };

  // Étape 5 : verifyOtp.
  const type = typeFige ?? lien.verification_type;
  const rVerif = await fetch(url + '/auth/v1/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: cle },
    body: JSON.stringify({ type, token_hash: lien.hashed_token }),
  });
  const verif = await rVerif.json();

  return {
    ok: rVerif.ok && Boolean(verif.access_token),
    lienEmis: lien.verification_type,
    typeVerifie: type,
    claim: verif.access_token ? Boolean(claimDe(verif.access_token)) : false,
    detail: verif.msg ?? verif.error_description ?? verif.error ?? '',
  };
}

/**
 * Deux liens émis coup sur coup sur un compte EXISTANT : le jeton du premier
 * survit-il, et la reprise de l'étape 5 rattrape-t-elle son refus ?
 *
 * Mesure, pas assertion : si le premier jeton se met à passer, c'est que
 * gotrue ne fait plus expirer le précédent — la reprise devient alors du
 * filet inutile, et c'est ce résultat qui le dira.
 */
async function echangeConcurrent(email) {
  const emettre = async () =>
    (await fetch(url + '/auth/v1/admin/generate_link', {
      method: 'POST',
      headers: enTetes,
      body: JSON.stringify({ type: 'magiclink', email }),
    })).json();

  const verifier = async (lien) => {
    const r = await fetch(url + '/auth/v1/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: cle },
      body: JSON.stringify({ type: lien.verification_type, token_hash: lien.hashed_token }),
    });
    const j = await r.json();
    return { ok: r.ok && Boolean(j.access_token), detail: j.error_code ?? j.msg ?? '' };
  };

  const notre = await emettre();
  await emettre(); // l'échange concurrent passe par là et réémet
  const premier = await verifier(notre);
  const reprise = premier.ok ? null : await verifier(await emettre());
  return { premier, reprise };
}

const suffixe = Date.now();
const adresses = {
  temoin: `sonde-temoin-${suffixe}@example.com`,
  correctif: `sonde-correctif-${suffixe}@example.com`,
};

const temoin = await sequence(adresses.temoin, 'magiclink');
const correctif = await sequence(adresses.correctif, null);
const concurrence = await echangeConcurrent(adresses.correctif);

const rendu = (nom, r) =>
  `${nom.padEnd(10)} lien émis: ${String(r.lienEmis).padEnd(9)} | vérifié comme: ${String(
    r.typeVerifie,
  ).padEnd(9)} | ${r.ok ? `SESSION OK (claim firebase_uid ${r.claim ? 'présent' : 'ABSENT'})` : 'ÉCHEC — ' + r.detail}`;

console.log('');
console.log(rendu('TÉMOIN', temoin));
console.log(rendu('CORRECTIF', correctif));
console.log(
  'CONCURRENCE'.padEnd(10) +
    ' 1er jeton après réémission: ' +
    (concurrence.premier.ok
      ? "ACCEPTÉ (gotrue ne l'invalide plus — la reprise ne sert plus)"
      : 'refusé (' + concurrence.premier.detail + ')') +
    (concurrence.reprise
      ? ' | reprise: ' + (concurrence.reprise.ok ? 'SESSION OK' : 'ÉCHEC — ' + concurrence.reprise.detail)
      : ''),
);
console.log('');

const repriseOk = concurrence.premier.ok || Boolean(concurrence.reprise?.ok);
const attendu = !temoin.ok && correctif.ok && correctif.claim && repriseOk;
console.log(
  attendu
    ? 'Conforme : le type figé échoue, le type émis passe, la reprise rattrape.'
    : "INATTENDU : relire l'étape 5 de supabase/functions/auth-firebase-exchange/index.ts.",
);
console.log('Utilisateurs laissés en base : ' + adresses.temoin + ', ' + adresses.correctif);
process.exit(attendu ? 0 : 1);
