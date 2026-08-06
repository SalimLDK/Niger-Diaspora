#!/usr/bin/env node
/**
 * Reprise unique des blocages Firestore vers la table Supabase `blocked_users`.
 *
 * POURQUOI
 * --------
 * Le blocage s'écrit dans Firestore depuis toujours. Les profils, eux, viennent
 * de Supabase, où `_mapProfile` codait en dur `blockedByUserIds: []` — donc le
 * sens « qui m'a bloqué » n'a jamais fonctionné nulle part dans l'app. La
 * double écriture ajoutée le 2026-08-06 alimente Supabase à partir de
 * maintenant ; ce script rattrape ce qui existait avant. Sans lui, un blocage
 * posé hier reste invisible pour toujours.
 *
 * POURQUOI EN LOCAL PLUTÔT QU'EN CLOUD FUNCTION
 * ---------------------------------------------
 * Une fonction HTTPS aurait demandé un endpoint public de plus, garde par
 * `ADMIN_API_KEY` — qui est absente en production, donc l'endpoint aurait
 * refusé tout le monde, y compris nous. Une reprise est de toute façon un
 * geste unique : la faire en local évite d'exposer durablement une surface
 * d'attaque pour un besoin d'une fois.
 *
 * Et pourquoi pas côté client au démarrage : ça n'aurait rattrapé que les
 * comptes qui rouvrent l'app. Un compte inactif dont la personne a bloqué
 * quelqu'un serait resté sans protection.
 *
 * SÛRETÉ
 * ------
 * - Lecture seule sur Firestore.
 * - `upsert` sur la clé primaire `(blocker_id, blocked_id)` : rejouable sans
 *   créer de doublon ni écraser quoi que ce soit.
 * - **Simulation par défaut.** Il faut `--apply` pour écrire.
 * - Les paires dont l'un des deux comptes n'existe pas dans `users` côté
 *   Supabase sont écartées : les deux colonnes portent une clé étrangère, et
 *   une seule paire orpheline ferait échouer tout le lot.
 *
 * USAGE
 *   node tools/backfill_blocked_users.js            # simulation
 *   node tools/backfill_blocked_users.js --apply    # écriture
 */

const fs = require("fs");
const path = require("path");

const RACINE = path.resolve(__dirname, "..");
const APPLIQUER = process.argv.includes("--apply");
const TAILLE_LOT = 200;

function lireEnv() {
  const fichier = path.join(RACINE, "functions", ".env");
  if (!fs.existsSync(fichier)) {
    throw new Error("functions/.env introuvable");
  }
  const env = {};
  for (const ligne of fs.readFileSync(fichier, "utf8").split(/\r?\n/)) {
    const m = ligne.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) env[m[1]] = m[2].trim();
  }
  return env;
}

function trouverCompteDeService() {
  const candidats = fs
    .readdirSync(RACINE)
    .filter((f) => /-adminsdk-.*\.json$/.test(f));
  if (candidats.length === 0) {
    throw new Error(
      "Aucun fichier *-adminsdk-*.json a la racine : impossible de lire Firestore.",
    );
  }
  return path.join(RACINE, candidats[0]);
}

async function rest(env, chemin, options = {}) {
  const reponse = await fetch(`${env.SUPABASE_URL}/rest/v1/${chemin}`, {
    ...options,
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  if (!reponse.ok) {
    throw new Error(
      `${options.method || "GET"} ${chemin} -> ${reponse.status} ${await reponse.text()}`,
    );
  }
  const texte = await reponse.text();
  return texte ? JSON.parse(texte) : null;
}

async function main() {
  const env = lireEnv();
  for (const cle of ["SUPABASE_URL", "SUPABASE_SERVICE_KEY"]) {
    if (!env[cle]) throw new Error(`${cle} absente de functions/.env`);
  }

  const admin = require(path.join(RACINE, "functions", "node_modules", "firebase-admin"));
  admin.initializeApp({
    credential: admin.credential.cert(require(trouverCompteDeService())),
  });

  console.log(APPLIQUER ? "MODE ECRITURE\n" : "SIMULATION (ajouter --apply pour ecrire)\n");

  // 1. Tous les blocages Firestore, quelle que soit la personne qui bloque.
  //    Les documents vivent en `users/{bloqueur}/blocked_users/{bloque}`.
  const snap = await admin.firestore().collectionGroup("blocked_users").get();
  const paires = [];
  for (const doc of snap.docs) {
    const bloqueur = doc.ref.parent.parent?.id;
    const bloque = doc.id;
    if (bloqueur && bloque && bloqueur !== bloque) {
      paires.push({ blocker_id: bloqueur, blocked_id: bloque });
    }
  }
  console.log(`Firestore : ${paires.length} blocage(s) trouve(s)`);

  if (paires.length === 0) {
    console.log("Rien a reprendre.");
    return;
  }

  // 2. Les deux colonnes ont une cle etrangere vers `users`. Une seule paire
  //    orpheline ferait echouer tout le lot : on filtre d'abord.
  const utilisateurs = await rest(env, "users?select=id");
  const connus = new Set(utilisateurs.map((u) => u.id));
  const retenues = paires.filter(
    (p) => connus.has(p.blocker_id) && connus.has(p.blocked_id),
  );
  const ecartees = paires.length - retenues.length;
  if (ecartees > 0) {
    console.log(
      `Ecartes : ${ecartees} (un des deux comptes est absent de users cote Supabase)`,
    );
  }

  // 3. Ce qui est deja la.
  const dejaLa = await rest(env, "blocked_users?select=blocker_id,blocked_id");
  const cles = new Set(dejaLa.map((l) => `${l.blocker_id}|${l.blocked_id}`));
  const manquantes = retenues.filter(
    (p) => !cles.has(`${p.blocker_id}|${p.blocked_id}`),
  );

  console.log(`Deja dans Supabase : ${retenues.length - manquantes.length}`);
  console.log(`A inserer          : ${manquantes.length}`);

  if (manquantes.length === 0) {
    console.log("\nRien a faire.");
    return;
  }
  if (!APPLIQUER) {
    console.log("\nSimulation : aucune ecriture. Relancer avec --apply.");
    return;
  }

  let ecrits = 0;
  for (let i = 0; i < manquantes.length; i += TAILLE_LOT) {
    const lot = manquantes.slice(i, i + TAILLE_LOT);
    await rest(env, "blocked_users", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(lot),
    });
    ecrits += lot.length;
    console.log(`  ${ecrits}/${manquantes.length}`);
  }
  console.log(`\nTermine : ${ecrits} blocage(s) repris.`);
}

main().catch((e) => {
  console.error("\nECHEC :", e.message);
  process.exit(1);
});
