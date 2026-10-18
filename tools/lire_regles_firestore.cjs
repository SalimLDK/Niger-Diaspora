// Lit les règles Firestore RÉELLEMENT déployées (API firebaserules, GET seul :
// rien n'est écrit, rien n'est déployé) et les écrit sur la sortie standard.
// Le jeu de règles et sa date vont sur la sortie d'erreur.
//
//   node tools/lire_regles_firestore.cjs > deployees.rules
//   diff <(sed 's/\r$//' deployees.rules) <(sed 's/\r$//' firestore.rules)
//
// À faire AVANT tout `firebase deploy --only firestore:rules` : le fichier du
// dépôt a déjà été la copie périmée de la production (666 lignes contre 1501,
// le 2026-08-05) ; déployer depuis lui aurait été une régression de sécurité.
//
// Identifiants : l'ADC de gcloud (%APPDATA%/gcloud/application_default_
// credentials.json). Module : `google-auth-library`, résolu depuis
// `functions/node_modules` — celui du worktree, à défaut celui du dépôt
// principal (un worktree vit DANS le dépôt principal, voir CLAUDE.md).
const { createRequire } = require('node:module');
const { existsSync } = require('node:fs');
const { join, resolve } = require('node:path');

const racine = resolve(__dirname, '..');
const candidats = [
  join(racine, 'functions'),
  // .claude/worktrees/<nom> → dépôt principal
  resolve(racine, '..', '..', '..', 'functions'),
];
const dossier = candidats.find((d) => existsSync(join(d, 'node_modules', 'google-auth-library')));
if (!dossier) {
  process.stderr.write(
    'google-auth-library introuvable : lancer `cd functions && npm install` (voir CLAUDE.md).\n',
  );
  process.exit(2);
}
const { GoogleAuth } = createRequire(join(dossier, 'package.json'))('google-auth-library');

const PROJET = process.env.FIREBASE_PROJECT || 'diaspo-niger';

(async () => {
  const client = await new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  }).getClient();
  const release = await client.request({
    url: `https://firebaserules.googleapis.com/v1/projects/${PROJET}/releases/cloud.firestore`,
  });
  const jeu = await client.request({
    url: `https://firebaserules.googleapis.com/v1/${release.data.rulesetName}`,
  });
  process.stderr.write(`jeu de règles : ${release.data.rulesetName}\nmis en ligne : ${release.data.updateTime}\n`);
  process.stdout.write(jeu.data.source.files[0].content);
})().catch((e) => {
  process.stderr.write(`ERREUR : ${e.message}\n`);
  process.exit(1);
});
