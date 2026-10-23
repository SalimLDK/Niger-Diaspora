// Amorçage (et secours) du registre admin — le SEUL chemin hors application.
//
//   node tools/amorcer_super_admin.mjs --email <email>                 # lit, n'écrit rien
//   node tools/amorcer_super_admin.mjs --email <email> --confirmer     # pose superAdmin
//   node tools/amorcer_super_admin.mjs --uid <uid> --role contentMod --confirmer
//   node tools/amorcer_super_admin.mjs --uid <uid> --retirer --confirmer
//
// Depuis la racine du dépôt. Voir docs/ops/AMORCAGE_ADMIN.md.
//
// POURQUOI CE SCRIPT
// Le rôle admin a une source, Postgres `users.admin_role`, et deux dérivés
// que la callable `setAdminRole` (functions/roles_admin.js) pose à chaque
// assignation : le custom claim Firebase `{ adminRole }` — ce que lisent
// les règles Firestore/RTDB et le panneau — et RTDB `/admins/{uid}`. Mais
// la callable exige un appelant déjà superAdmin : le PREMIER ne peut pas se
// créer par elle. Ce script écrit les mêmes trois registres, par l'Admin SDK
// et la clé de service, en appelant les MÊMES aides que la callable
// (functions/supabase.js) — pas une seconde implémentation.
//
// Il sert aussi de secours : relire les trois registres d'un compte
// (`--email` sans `--confirmer`), ou reposer un rôle quand un dérivé a été
// perdu (réinstallation, claim effacé) — l'écriture est idempotente.
//
// GARDE-FOUS
//   1. Sans `--confirmer`, lecture seule : affiche les trois registres et ce
//      que l'écriture ferait. Toujours lancer une fois sans.
//   2. Le compte doit avoir sa ligne `public.users` : elle naît à la
//      première connexion (auth-firebase-exchange). Pas de ligne, pas de
//      rôle — on ne crée pas un profil depuis ici.
//   3. `--retirer` refuse de supprimer le dernier superAdmin.
//   4. L'action est journalisée dans `admin_audit_logs` (admin_id
//      « amorcage »).
//
// CE QUI N'EST PAS INSTANTANÉ
// Le claim n'entre dans le jeton du compte qu'à son prochain
// rafraîchissement : jusqu'à une heure, ou tout de suite si l'app appelle
// `getIdToken(true)` (le panneau le fait à l'ouverture). Postgres, lui, est
// lu à chaque requête : les policies RLS voient le rôle immédiatement.
//
// N'affiche ni clé ni jeton.

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = resolve(join(dirname(fileURLToPath(import.meta.url)), ".."));
const require_ = createRequire(join(RACINE, "functions", "package.json"));

// Même URL que lib/firebase_options.dart : le script tourne hors Cloud
// Functions, donc sans FIREBASE_CONFIG pour la deviner.
const RTDB_URL = "https://diaspo-niger-default-rtdb.europe-west1.firebasedatabase.app";
const ROLES = ["superAdmin", "contentMod", "businessMod", "financeMod"];

// ─────────────────────────────────────────────────────────────── arguments

const args = process.argv.slice(2);
const valeur = (nom) => {
  const i = args.indexOf(nom);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
};
const drapeau = (nom) => args.includes(nom);

const email = valeur("--email");
const uidArg = valeur("--uid");
const retirer = drapeau("--retirer");
const confirmer = drapeau("--confirmer");
const role = retirer ? null : valeur("--role") || "superAdmin";

if (drapeau("--help") || (!email && !uidArg) || (email && uidArg)) {
  console.error(
    "Usage : node tools/amorcer_super_admin.mjs (--email <email> | --uid <uid>)" +
      " [--role superAdmin|contentMod|businessMod|financeMod] [--retirer] [--confirmer]",
  );
  process.exit(2);
}
if (role !== null && !ROLES.includes(role)) {
  console.error(`--role doit être l'un de : ${ROLES.join(", ")}`);
  process.exit(2);
}

// ────────────────────────────────────────────────────────────── configuration

const lireEnv = (fichier, nom) => {
  const chemin = join(RACINE, fichier);
  if (!existsSync(chemin)) return null;
  const ligne = readFileSync(chemin, "utf8")
    .split(/\r?\n/)
    .find((l) => l.startsWith(nom + "="));
  return ligne ? ligne.slice(nom.length + 1).trim() : null;
};

// Les aides de functions/supabase.js lisent process.env AU CHARGEMENT : à
// poser avant le require.
process.env.SUPABASE_URL = process.env.SUPABASE_URL || lireEnv("functions/.env", "SUPABASE_URL");
process.env.SUPABASE_SERVICE_KEY =
  process.env.SUPABASE_SERVICE_KEY || lireEnv("functions/.env", "SUPABASE_SERVICE_KEY");
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY) {
  console.error("SUPABASE_URL / SUPABASE_SERVICE_KEY introuvables (functions/.env). Lancer depuis la racine.");
  process.exit(1);
}

const { getAdminAccount, countSuperAdmins, setAdminFlags, insertAdminAuditLog } =
  require_(join(RACINE, "functions", "supabase.js"));

function chargerAdminSdk() {
  const admin = require_("firebase-admin");
  if (admin.apps.length) return admin;
  let credential;
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    credential = admin.credential.applicationDefault();
  } else {
    // La clé de service du projet vit dans functions/ (ignorée par git :
    // `*-adminsdk-*.json`), parfois à la racine.
    const dossier = ["functions", "."]
      .map((d) => join(RACINE, d))
      .find((d) => readdirSync(d).some((f) => /-adminsdk-.*\.json$/.test(f)));
    if (!dossier) {
      console.error(
        "Clé de service Firebase introuvable : déposer <projet>-firebase-adminsdk-<hash>.json" +
          " dans functions/, ou définir GOOGLE_APPLICATION_CREDENTIALS.",
      );
      process.exit(1);
    }
    const fichier = readdirSync(dossier).find((f) => /-adminsdk-.*\.json$/.test(f));
    credential = admin.credential.cert(require_(join(dossier, fichier)));
  }
  admin.initializeApp({ credential, databaseURL: RTDB_URL });
  return admin;
}

// ───────────────────────────────────────────────────────────────── lecture

const admin = chargerAdminSdk();

async function resoudreUid() {
  if (uidArg) return uidArg;
  try {
    const u = await admin.auth().getUserByEmail(email.trim().toLowerCase());
    return u.uid;
  } catch (e) {
    console.error(`Aucun compte Firebase pour ${email} (${e.code || e.message}).`);
    process.exit(1);
  }
}

async function lireRegistres(uid) {
  const [postgres, firebase, rtdb] = await Promise.all([
    getAdminAccount(uid),
    admin.auth().getUser(uid).catch(() => null),
    admin.database().ref(`admins/${uid}`).get(),
  ]);
  return {
    postgres,
    claim: firebase ? (firebase.customClaims || {}).adminRole ?? null : undefined,
    disabled: firebase ? firebase.disabled : undefined,
    emailFirebase: firebase ? firebase.email : undefined,
    rtdb: rtdb.exists() ? rtdb.val() : null,
  };
}

function afficher(titre, uid, r) {
  console.log(`\n${titre} — ${uid}`);
  if (r.emailFirebase === undefined) console.log("  Firebase Auth : COMPTE ABSENT");
  else console.log(`  Firebase Auth : ${r.emailFirebase}${r.disabled ? " (DÉSACTIVÉ)" : ""}`);
  if (!r.postgres) console.log("  Postgres      : LIGNE ABSENTE (le compte ne s'est jamais connecté)");
  else
    console.log(
      `  Postgres      : is_admin=${r.postgres.isAdmin} admin_role=${r.postgres.adminRole ?? "null"}` +
        `  (${r.postgres.email ?? "sans e-mail"})`,
    );
  console.log(`  Claim         : adminRole=${r.claim === undefined ? "—" : r.claim ?? "null"}`);
  console.log(`  RTDB /admins  : ${r.rtdb === null ? "absent" : String(r.rtdb)}`);
}

const uid = await resoudreUid();
const avant = await lireRegistres(uid);
afficher("État actuel", uid, avant);

const roleAvant = avant.postgres ? avant.postgres.adminRole : null;
const coherent =
  avant.postgres &&
  avant.postgres.isAdmin === (roleAvant !== null) &&
  avant.claim === roleAvant &&
  (avant.rtdb === true) === (roleAvant !== null);
console.log(`\n  Cohérence des trois registres : ${coherent ? "OUI" : "NON"}`);

console.log(
  `\nÉcriture demandée : ${role === null ? "RETIRER tout rôle" : `admin_role = ${role}`}` +
    " (Postgres is_admin + admin_role, claim Firebase, RTDB /admins, journal).",
);

if (!confirmer) {
  console.log("Rien écrit. Relancer avec --confirmer pour appliquer.");
  process.exit(0);
}

// ───────────────────────────────────────────────────────────────── écriture

if (avant.emailFirebase === undefined) {
  console.error("\nRefus : pas de compte Firebase Auth pour cet uid.");
  process.exit(1);
}
if (!avant.postgres) {
  console.error(
    "\nRefus : pas de ligne public.users. Le compte doit se connecter une fois à l'app" +
      " (auth-firebase-exchange crée la ligne), puis relancer.",
  );
  process.exit(1);
}
if (role === null && roleAvant === "superAdmin") {
  const n = await countSuperAdmins();
  if (n - 1 < 1) {
    console.error("\nRefus : ce compte est le dernier superAdmin. En nommer un autre d'abord.");
    process.exit(1);
  }
}

const touche = await setAdminFlags(uid, role);
if (!touche) {
  console.error("\nPostgres : aucune ligne touchée (compte disparu entre-temps ?). Rien d'autre écrit.");
  process.exit(1);
}
console.log("\n  Postgres      : écrit");

try {
  await admin.auth().setCustomUserClaims(uid, role ? { adminRole: role } : null);
  console.log("  Claim         : écrit");
} catch (e) {
  console.error(`  Claim         : ÉCHEC (${e.code || e.message}) — remise de Postgres à l'état d'avant`);
  await setAdminFlags(uid, roleAvant);
  process.exit(1);
}

const ref = admin.database().ref(`admins/${uid}`);
await (role ? ref.set(true) : ref.remove());
console.log("  RTDB /admins  : écrit");

const action = roleAvant === role ? "sync_role" : !roleAvant ? "assign_role" : !role ? "revoke_role" : "change_role";
const journalise = await insertAdminAuditLog({
  adminId: "amorcage",
  adminName: "tools/amorcer_super_admin.mjs",
  action,
  targetType: "user",
  targetId: uid,
  details: {
    previousRole: roleAvant || "none",
    newRole: role || "none",
    targetEmail: avant.postgres.email,
    targetName: avant.postgres.displayName,
  },
});
console.log(`  Journal       : ${journalise ? "écrit" : "REFUSÉ (voir ci-dessus)"}`);

afficher("État après", uid, await lireRegistres(uid));
console.log(
  "\nLe jeton du compte ne porte le claim qu'à son prochain rafraîchissement" +
    " (≤ 1 h, ou immédiat à la prochaine ouverture du panneau).",
);
process.exit(0);
