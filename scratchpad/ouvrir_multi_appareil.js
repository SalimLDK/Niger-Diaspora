#!/usr/bin/env node
//
// Ouvre « plusieurs appareils a la fois » pour un ou plusieurs comptes.
//
// Ecrit `featureFlags.multiAppareilComptes` dans Firestore `app_config/settings`.
// C'est la seule liste que `SessionService.doitEjecter` consulte : tant qu'un
// uid y figure, l'appareil deja connecte n'est plus ejecte quand le meme compte
// se connecte ailleurs (« Connecte ailleurs »).
//
// Liste vide = regle d'avant, une seule session par compte, pour tout le monde.
//
// Pourquoi un script et pas l'ecran admin : `multiAppareilComptes` n'a aucune
// interface (l'ecran Feature Flags ne montre que les bascules booleennes), et
// l'ecriture de ce drapeau est refusee au classificateur de Claude Code
// (motif « Feature Flag Writes »). C'est donc Salim qui le lance.
//
// Usage, depuis la racine du depot, en PowerShell :
//
//   $env:NODE_PATH = "$PWD\functions\node_modules"
//   node scratchpad/ouvrir_multi_appareil.js <uid> [<uid>...]
//
//   node scratchpad/ouvrir_multi_appareil.js --retirer <uid>   # refermer
//   node scratchpad/ouvrir_multi_appareil.js --lire            # etat seul
//
// `firebase-admin` n'est installe que dans `functions/` du depot principal,
// d'ou le NODE_PATH.
//
// ⚠️ Effet immediat, sans redemarrage de l'app : la decision est relue a chaque
// instantane Firestore (`SessionService.multiAppareilAutorise`).

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COLLECTION = 'app_config';
const DOCUMENT = 'settings';
const CHAMP = 'featureFlags.multiAppareilComptes';

/// Chemin du compte de service, par ordre de preference : la variable
/// d'environnement, la ligne GOOGLE_APPLICATION_CREDENTIALS du .env, puis le
/// premier *-adminsdk-*.json trouve a la racine. Tous ignores par git.
/// Meme resolution que `scripts/creer_compte_test.js`.
function trouverCle() {
  const candidats = [process.env.GOOGLE_APPLICATION_CREDENTIALS];

  const env = path.join(process.cwd(), '.env');
  if (fs.existsSync(env)) {
    const ligne = fs
      .readFileSync(env, 'utf8')
      .split(/\r?\n/)
      .find((l) => l.startsWith('GOOGLE_APPLICATION_CREDENTIALS='));
    if (ligne) candidats.push(ligne.split('=').slice(1).join('=').trim());
  }

  const racine = fs.readdirSync(process.cwd());
  const adminsdk = racine.find((f) => /-adminsdk-.*\.json$/.test(f));
  if (adminsdk) candidats.push(path.join(process.cwd(), adminsdk));

  return candidats.find((c) => c && fs.existsSync(c));
}

async function main() {
  const args = process.argv.slice(2);
  const lireSeul = args.includes('--lire');
  const retirer = args.includes('--retirer');
  const uids = args.filter((a) => !a.startsWith('--'));

  if (!lireSeul && uids.length === 0) {
    console.error(
      'Aucun uid.\n' +
        '  node scratchpad/ouvrir_multi_appareil.js <uid> [<uid>...]\n' +
        '  node scratchpad/ouvrir_multi_appareil.js --retirer <uid>\n' +
        '  node scratchpad/ouvrir_multi_appareil.js --lire',
    );
    process.exit(1);
  }

  const cle = trouverCle();
  if (!cle) {
    console.error(
      'Compte de service introuvable. Lancer depuis la racine du depot, ou\n' +
        'definir GOOGLE_APPLICATION_CREDENTIALS.',
    );
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(cle))),
  });

  const doc = admin.firestore().collection(COLLECTION).doc(DOCUMENT);
  const avant = await doc.get();
  if (!avant.exists) {
    console.error(`${COLLECTION}/${DOCUMENT} n'existe pas. Rien touche.`);
    process.exit(1);
  }

  const drapeaux = avant.data().featureFlags || {};
  const liste = drapeaux.multiAppareilComptes || [];
  console.log('Avant :', liste.length ? liste.join(', ') : '(vide)');
  // Repere utile : ce sont deux listes distinctes, on les confond vite.
  console.log(
    'Pour memoire, mlsMessagesComptes :',
    (drapeaux.mlsMessagesComptes || []).join(', ') || '(vide)',
  );

  if (lireSeul) return;

  // `update` avec un chemin pointe, et non `set(merge)` sur la map entiere :
  // ecrire `featureFlags` en entier ecraserait toute cle que ce script ignore
  // (c'est exactement ce que fait l'ecran admin, et ce qui a deja coute
  // audioRooms/podcasts/feed). arrayUnion/arrayRemove ne touchent que la liste.
  const operation = retirer
    ? admin.firestore.FieldValue.arrayRemove(...uids)
    : admin.firestore.FieldValue.arrayUnion(...uids);
  await doc.update({ [CHAMP]: operation });

  const apres = await doc.get();
  const nouvelle =
    (apres.data().featureFlags || {}).multiAppareilComptes || [];
  console.log('Apres :', nouvelle.length ? nouvelle.join(', ') : '(vide)');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
