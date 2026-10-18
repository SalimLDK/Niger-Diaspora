// Banc des règles Firestore : un réglage ne change plus sans son historique.
//
// POURQUOI CE FICHIER EXISTE
// `app_config/settings` porte les drapeaux de fonctionnalités, les frais, les
// limites de médias, le mode maintenance. Le superAdmin l'écrivait sans que
// rien ne dise ce qui avait changé, ni de quelle valeur, ni qui. Le référentiel
// (§ 13) veut « auteur, date, clé, ancienne valeur, nouvelle valeur » et la
// possibilité de revenir en arrière. Les règles obligent maintenant tout
// écrivain du document `settings` à poser, dans le MÊME lot, une entrée neuve
// de `app_config_history` que le document cite (`lastChangeId`).
//
// CIBLE, PAS ENCORE DÉPLOYÉE
// `firestore.rules` reste le reflet exact de la production (lu et comparé le
// 2026-10-19 : 0 ligne d'écart avec le jeu de règles déployé le 2026-10-14).
// Le changement vit dans `firestore.rules.cible-reglages-historique`, à
// substituer à `firestore.rules` au déploiement — ET seulement avec le panneau
// qui écrit `lastChangeId` : l'ancien panneau ne pourrait plus enregistrer un
// réglage.
//
// USAGE
//   firebase emulators:start --only firestore --project diaspo-niger
//   node tools/rules_tests/reglages_historique.mjs
//   (FIRESTORE_REGLES=<fichier> pour essayer un autre jeu de règles)
//
// Le bloc 1 est le parcours nominal du panneau (il doit passer), le bloc 2 est
// la fermeture (ce qui DOIT être refusé), le bloc 3 vérifie que le reste de
// `app_config` n'a pas bougé. Ce sont des conditions de déploiement.

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
const { doc, setDoc, getDoc, deleteDoc, updateDoc, writeBatch, serverTimestamp } =
    require_("firebase/firestore");

const env = await initializeTestEnvironment({
    projectId: "diaspo-niger",
    firestore: {
        rules: readFileSync(join(RACINE, process.env.FIRESTORE_REGLES || "firestore.rules.cible-reglages-historique"), "utf8"),
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

const SUPER = "super_admin";
const AUTRE_SUPER = "autre_super";
const CONTENT = "content_mod";
const ORDINAIRE = "ordinaire";
const avec = (uid, adminRole) =>
    env.authenticatedContext(uid, adminRole ? { adminRole } : {}).firestore();

const entree = (uid, extra = {}) => ({
    section: "fees",
    before: { a: 1 },
    after: { a: 2 },
    by: uid,
    at: serverTimestamp(),
    kind: "update",
    ...extra,
});

/** Un lot « réglage + historique », comme le panneau l'écrit. */
function lot(db, id, uid, { reglage = {}, histo = {}, sansHisto = false, sansCle = false } = {}) {
    const b = writeBatch(db);
    b.set(
        doc(db, "app_config", "settings"),
        { fees: { a: 2 }, ...(sansCle ? {} : { lastChangeId: id }), ...reglage },
        { merge: true },
    );
    if (!sansHisto) b.set(doc(db, "app_config_history", id), entree(uid, histo));
    return b.commit();
}

await env.clearFirestore();
await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "app_config", "settings"), { fees: { a: 1 }, lastChangeId: "initial" });
    await setDoc(doc(db, "app_config", "general"), { maintenance: false });
    await setDoc(doc(db, "app_config_history", "initial"), entree(SUPER));
    await setDoc(doc(db, "app_config_history", "ancien"), entree(SUPER));
});

// ---------------------------------------------------------------------------
console.log("\n1. PARCOURS NOMINAL — le panneau écrit le réglage ET son historique");
{
    const db = avec(SUPER, "superAdmin");
    await doit(true, "superAdmin : réglage + entrée neuve dans le même lot", lot(db, "c1", SUPER));
    await doit(true, "superAdmin : première modification d'une section (before nul)",
        lot(db, "c2", SUPER, { histo: { before: null } }));
    await doit(true, "superAdmin : un retour arrière est une entrée de nature « restore »",
        lot(db, "c3", SUPER, { histo: { kind: "restore", restoredFrom: "c1", reason: "Erreur de saisie" } }));
    await doit(true, "superAdmin lit l'historique", getDoc(doc(db, "app_config_history", "c1")));
    await doit(true, "un utilisateur authentifié lit toujours les réglages",
        getDoc(doc(avec(ORDINAIRE), "app_config", "settings")));
}

// ---------------------------------------------------------------------------
console.log("\n2. FERMETURE — ce qui doit être refusé");
{
    const db = avec(SUPER, "superAdmin");
    await doit(false, "réglage SANS lastChangeId",
        lot(db, "x1", SUPER, { sansCle: true, sansHisto: true }));
    await doit(false, "lastChangeId cité mais aucune entrée dans le lot",
        lot(db, "x2", SUPER, { sansHisto: true }));
    await doit(false, "RÉUTILISER une entrée déjà écrite pour autoriser un nouveau changement",
        lot(db, "ancien", SUPER, { histo: {} }));
    await doit(false, "lastChangeId d'une entrée qui existait avant le lot (autre chemin)",
        setDoc(doc(db, "app_config", "settings"), { fees: { a: 9 }, lastChangeId: "ancien" }, { merge: true }));
    await doit(false, "entrée au nom d'un AUTRE compte",
        lot(db, "x3", SUPER, { histo: { by: "quelquun_d_autre" } }));
    await doit(false, "entrée datée par le client (at ≠ heure du serveur)",
        lot(db, "x4", SUPER, { histo: { at: new Date("2020-01-01") } }));
    await doit(false, "entrée avec un champ inconnu",
        lot(db, "x5", SUPER, { histo: { surprise: true } }));
    await doit(false, "entrée de nature inconnue",
        lot(db, "x6", SUPER, { histo: { kind: "delete" } }));
    await doit(false, "entrée sans « after »", (() => {
        const b = writeBatch(db);
        b.set(doc(db, "app_config", "settings"), { lastChangeId: "x7" }, { merge: true });
        b.set(doc(db, "app_config_history", "x7"), { section: "fees", by: SUPER, at: serverTimestamp(), kind: "update" });
        return b.commit();
    })());
    await doit(false, "motif de plus de 500 caractères",
        lot(db, "x8", SUPER, { histo: { reason: "x".repeat(501) } }));
    await doit(false, "le superAdmin RÉÉCRIT une entrée d'historique",
        updateDoc(doc(db, "app_config_history", "c1"), { reason: "réécrit" }));
    await doit(false, "le superAdmin SUPPRIME une entrée d'historique",
        deleteDoc(doc(db, "app_config_history", "c1")));
    await doit(false, "le superAdmin SUPPRIME le document des réglages",
        deleteDoc(doc(db, "app_config", "settings")));
    await doit(false, "entrée d'historique posée seule, sans que le réglage la cite, mais au nom d'un autre",
        setDoc(doc(db, "app_config_history", "x9"), entree("quelquun_d_autre")));
}
{
    const db = avec(CONTENT, "contentMod");
    await doit(false, "contentMod écrit les réglages, même avec une entrée", lot(db, "y1", CONTENT));
    await doit(false, "contentMod crée une entrée d'historique",
        setDoc(doc(db, "app_config_history", "y2"), entree(CONTENT)));
    await doit(false, "contentMod lit l'historique", getDoc(doc(db, "app_config_history", "c1")));
}
{
    const db = avec(ORDINAIRE);
    await doit(false, "un compte ordinaire écrit les réglages, même avec une entrée", lot(db, "z1", ORDINAIRE));
    await doit(false, "un compte ordinaire lit l'historique", getDoc(doc(db, "app_config_history", "c1")));
}
{
    const db = env.unauthenticatedContext().firestore();
    await doit(false, "un visiteur sans compte lit l'historique", getDoc(doc(db, "app_config_history", "c1")));
    await doit(false, "un visiteur sans compte lit les réglages", getDoc(doc(db, "app_config", "settings")));
}

// ---------------------------------------------------------------------------
console.log("\n3. LE RESTE D'app_config N'A PAS BOUGÉ");
{
    const db = avec(SUPER, "superAdmin");
    await doit(true, "superAdmin écrit un autre document d'app_config sans historique",
        setDoc(doc(db, "app_config", "general"), { maintenance: true }, { merge: true }));
    await doit(true, "superAdmin supprime un autre document d'app_config",
        deleteDoc(doc(db, "app_config", "general")));
    const db2 = avec(AUTRE_SUPER, "superAdmin");
    await doit(true, "un second superAdmin écrit lui aussi, à son nom", lot(db2, "d1", AUTRE_SUPER));
    await doit(false, "… mais pas au nom du premier", lot(db2, "d2", SUPER));
}

await env.cleanup();
console.log(echecs === 0 ? "\nTOUT PASSE" : `\n${echecs} ECHEC(S)`);
process.exit(echecs === 0 ? 0 : 1);
