// Banc des règles Firestore : le rôle admin se lit dans le CLAIM, plus dans
// le document `users`.
//
// POURQUOI CE FICHIER EXISTE
// Jusqu'au 2026-10-14, les quatre helpers admin de firestore.rules lisaient
// `users/{uid}.adminRole` — ou le drapeau hérité `isAdmin` — et le bloc admin
// de `users/{userId}` laissait tout admin, contentMod compris, poser
// `isAdmin: true` sur n'importe quel compte, le sien aussi : escalade en une
// écriture (audit du 14/10, § 7.1). Et un admin sans document Firestore
// n'avait aucun droit, `.data` d'un document absent faisant échouer la règle
// (§ 2). Le rôle vit désormais dans le custom claim `adminRole`, posé par la
// seule Cloud Function `setAdminRole`.
//
// USAGE
//   firebase emulators:start --only firestore --project diaspo-niger
//   node tools/rules_tests/registre_role_claim.mjs
//
// Le bloc 1 est le parcours nominal du panneau avec un claim : il doit
// passer. Le bloc 2 est la fermeture : ce qui DOIT être refusé. Les deux
// sont des conditions de déploiement — ce banc ne « mesure » rien, il tranche.
//
// PIÈGE DÉJÀ PAYÉ : `request.auth.token.adminRole` sur un jeton SANS ce claim
// fait échouer la règle au lieu de rendre null — refus muet, même dans un
// `||`. Les helpers passent par `token.get('adminRole', null)` ; le cas
// « compte ordinaire, aucun claim » du bloc 2 existe pour qu'on ne revienne
// jamais à l'accès direct par accident.

import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const require_ = createRequire(join(RACINE, "test", "rules", "package.json"));

let rut;
try {
    rut = require_("@firebase/rules-unit-testing");
} catch {
    console.error("Dependance absente. Lancer d'abord :\n  cd test/rules && npm install\n");
    process.exit(2);
}
const { initializeTestEnvironment, assertFails, assertSucceeds } = rut;
const { doc, setDoc, getDoc, updateDoc } = require_("firebase/firestore");

const env = await initializeTestEnvironment({
    projectId: "diaspo-niger",
    firestore: {
        rules: readFileSync(join(RACINE, "firestore.rules"), "utf8"),
        host: "127.0.0.1",
        port: Number(process.env.FIRESTORE_EMULATEUR_PORT || 8080),
    },
});

let echecs = 0;
const ligne = (ok, texte) => {
    if (!ok) echecs++;
    console.log(`${ok ? "  OK  " : " ECHEC"}  ${texte}`);
};
async function doit(passer, texte, promesse) {
    try {
        await (passer ? assertSucceeds(promesse) : assertFails(promesse));
        ligne(true, texte);
    } catch (e) {
        ligne(false, `${texte}  → ${String(e).split("\n")[0]}`);
    }
}

// Comptes. Le claim est le second argument d'`authenticatedContext` : il
// entre dans `request.auth.token` exactement comme un custom claim posé par
// `setCustomUserClaims`.
const SUPER_SANS_DOC = "super_sans_document";  // claim, AUCUN document users
const CONTENT = "content_mod";
const BUSINESS = "business_mod";
const FINANCE = "finance_mod";
const DOC_ROLE = "doc_adminRole_sans_claim";   // document users.adminRole, pas de claim
const DOC_ISADMIN = "doc_isAdmin_sans_claim";  // document users.isAdmin: true, pas de claim
const CLAIM_INCONNU = "claim_inconnu";
const ORDINAIRE = "ordinaire";
const CIBLE = "cible";

const avec = (uid, adminRole) =>
    env.authenticatedContext(uid, adminRole ? { adminRole } : {}).firestore();

await env.clearFirestore();
await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", DOC_ROLE), { adminRole: "superAdmin", displayName: "faux" });
    await setDoc(doc(db, "users", DOC_ISADMIN), { isAdmin: true, displayName: "faux" });
    await setDoc(doc(db, "users", CONTENT), { displayName: "content" });
    await setDoc(doc(db, "users", CIBLE), { displayName: "cible", isVerified: false });
    await setDoc(doc(db, "users", ORDINAIRE), { displayName: "ordinaire" });
    await setDoc(doc(db, "admin_audit_logs", "l1"), { action: "x" });
    await setDoc(doc(db, "app_config", "general"), { maintenance: false });
    await setDoc(doc(db, "reports", "r1"), { status: "pending", reporterId: "quelqu_un" });
    await setDoc(doc(db, "businesses", "b1"), { ownerId: "proprietaire", isVerified: false });
    await setDoc(doc(db, "transactions", "t1"), { status: "pending", senderId: "quelqu_un" });
});

// ---------------------------------------------------------------------------
console.log("\n1. PARCOURS NOMINAL — un claim suffit, le document Firestore n'est plus lu");

{
    const db = avec(SUPER_SANS_DOC, "superAdmin");
    await doit(true, "superAdmin SANS document users lit admin_audit_logs",
        getDoc(doc(db, "admin_audit_logs", "l1")));
    await doit(true, "superAdmin SANS document users écrit app_config (isSuperAdmin)",
        setDoc(doc(db, "app_config", "general"), { maintenance: true }, { merge: true }));
    await doit(true, "superAdmin met à jour le profil d'un autre (champ ordinaire)",
        updateDoc(doc(db, "users", CIBLE), { isVerified: true }));
    await doit(true, "superAdmin lit un signalement (canModerateContent)",
        getDoc(doc(db, "reports", "r1")));
}
{
    const db = avec(CONTENT, "contentMod");
    await doit(true, "contentMod lit et modifie un signalement",
        updateDoc(doc(db, "reports", "r1"), { status: "resolved" }));
    await doit(true, "contentMod lit admin_audit_logs (isAdmin)",
        getDoc(doc(db, "admin_audit_logs", "l1")));
}
{
    const db = avec(BUSINESS, "businessMod");
    await doit(true, "businessMod vérifie une entreprise (canModerateBusiness)",
        updateDoc(doc(db, "businesses", "b1"), { isVerified: true }));
}
{
    const db = avec(FINANCE, "financeMod");
    await doit(true, "financeMod met à jour une transaction (canModerateFinance)",
        updateDoc(doc(db, "transactions", "t1"), { status: "completed" }));
}

// ---------------------------------------------------------------------------
console.log("\n2. FERMETURE — ce qui doit être refusé");

{
    const db = avec(DOC_ROLE, null);
    await doit(false, "document users.adminRole = superAdmin, SANS claim : admin_audit_logs refusé",
        getDoc(doc(db, "admin_audit_logs", "l1")));
    await doit(false, "… et app_config refusé",
        setDoc(doc(db, "app_config", "general"), { maintenance: true }, { merge: true }));
}
{
    const db = avec(DOC_ISADMIN, null);
    await doit(false, "document users.isAdmin = true, SANS claim : signalements refusés",
        getDoc(doc(db, "reports", "r1")));
}
{
    const db = avec(ORDINAIRE, null);
    await doit(false, "compte ordinaire, AUCUN claim : admin_audit_logs refusé (pas d'erreur de règle)",
        getDoc(doc(db, "admin_audit_logs", "l1")));
    await doit(true, "… mais il lit toujours son propre profil (règle propriétaire intacte)",
        getDoc(doc(db, "users", ORDINAIRE)));
    await doit(false, "… et ne peut pas se poser isAdmin",
        updateDoc(doc(db, "users", ORDINAIRE), { isAdmin: true }));
}
{
    const db = avec(CLAIM_INCONNU, "god");
    await doit(false, "claim adminRole = 'god' (valeur inconnue) : rien",
        getDoc(doc(db, "admin_audit_logs", "l1")));
}
{
    const db = avec(SUPER_SANS_DOC, "superAdmin");
    await doit(false, "superAdmin ne pose PAS isAdmin sur un autre compte",
        updateDoc(doc(db, "users", CIBLE), { isAdmin: true }));
    await doit(false, "superAdmin ne pose PAS adminRole sur un autre compte",
        updateDoc(doc(db, "users", CIBLE), { adminRole: "superAdmin" }));
    await doit(false, "superAdmin ne supprime PAS un adminRole existant par Firestore non plus",
        updateDoc(doc(db, "users", DOC_ROLE), { adminRole: null }));
}
{
    const db = avec(CONTENT, "contentMod");
    await doit(false, "contentMod ne se pose PAS isAdmin (son propre document)",
        updateDoc(doc(db, "users", CONTENT), { isAdmin: true }));
    await doit(false, "contentMod ne se pose PAS adminRole = superAdmin",
        updateDoc(doc(db, "users", CONTENT), { adminRole: "superAdmin" }));
    await doit(false, "contentMod ne vérifie PAS une entreprise (businessMod seulement)",
        updateDoc(doc(db, "businesses", "b1"), { isVerified: false }));
    await doit(false, "contentMod n'écrit PAS app_config (superAdmin seulement)",
        setDoc(doc(db, "app_config", "general"), { maintenance: true }, { merge: true }));
}

// ---------------------------------------------------------------------------
await env.cleanup();
console.log(`\n${echecs === 0 ? "Registre par claim : INTACT" : `${echecs} ECHEC(S)`}`);
process.exit(echecs === 0 ? 0 : 1);
