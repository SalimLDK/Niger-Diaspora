// Banc : ce que le client ne peut plus écrire dans Firestore pour faire
// pousser une notification (audit des notifications, 2026-10-14).
//
//   firebase emulators:start --only firestore --project diaspo-niger
//   node tools/rules_tests/notifications_firestore.mjs
//   # contre d'autres règles (preuve qu'il sait échouer) :
//   FICHIER_REGLES=<chemin> node tools/rules_tests/notifications_firestore.mjs
//
// Condition : 0 cas en ÉCHEC contre `firestore.rules`.
//
// Trois portes, trois poussées à texte libre :
// - `notifications/{id}` créé par le client → `sendNotificationOnCreate`
//   poussait titre, corps et `data` choisis vers les `fcmTokens` du document
//   `users` ;
// - `users/{moi}.fcmTokens` écrit par le client → il suffisait d'y copier le
//   jeton lu sur le profil d'autrui pour que ces poussées arrivent chez lui ;
// - `events/{id}` créé par le client → `notifyLocalEventCreated` poussait le
//   titre à tout un rayon de 50 km.
//
// Contre les règles d'avant, les cas 1 à 4 tombent. Les cas 5 à 9 sont les
// témoins : ce que l'application fait encore (lire et effacer ses
// notifications, modifier son profil, s'inscrire à un événement).

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
    console.error("Dépendance absente. Lancer d'abord :\n  cd test/rules && npm install\n");
    process.exit(2);
}
const { initializeTestEnvironment, assertSucceeds, assertFails } = rut;
const { doc, setDoc, updateDoc, deleteDoc, getDoc, arrayUnion } =
    require_("firebase/firestore");

const FICHIER = process.env.FICHIER_REGLES || join(RACINE, "firestore.rules");
const MOI = "attaquantBanc";
const AUTRE = "organisateurBanc";
const RUN = Date.now().toString(36);

const resultats = [];
async function cas(n, libelle, attendu, action) {
    try {
        await (attendu === "accepté" ? assertSucceeds(action()) : assertFails(action()));
        resultats.push({ n, libelle, verdict: "OK", detail: attendu });
    } catch (e) {
        resultats.push({ n, libelle, verdict: "ÉCHEC", detail: `attendu ${attendu}` });
    }
}

const env = await initializeTestEnvironment({
    projectId: "diaspo-niger",
    firestore: { rules: readFileSync(FICHIER, "utf8"), host: "127.0.0.1", port: 8080 },
});
await env.clearFirestore();

const moi = env.authenticatedContext(MOI).firestore();

await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", MOI), { displayName: "Moi" });
    await setDoc(doc(db, "notifications", `n-${RUN}`), { userId: MOI, title: "t", body: "b" });
    await setDoc(doc(db, "events", `e-${RUN}`), {
        organizerId: AUTRE, title: "Fête", attendeeIds: [] });
});

// ── Ce qui faisait pousser ─────────────────────────────────────────────────
await cas(1, "créer une notification Firestore pour soi (faux appel entrant)", "refusé",
    () => setDoc(doc(moi, "notifications", `x-${RUN}`), {
        userId: MOI, type: "incoming_call", title: "Banque", body: "Appel",
        data: { type: "incoming_call", callerName: "Votre banque" } }));
await cas(2, "s'attribuer un jeton push (fcmTokens) sur son profil", "refusé",
    () => updateDoc(doc(moi, "users", MOI), { fcmTokens: ["jeton-de-la-victime"] }));
await cas(3, "créer son profil avec un jeton push d'autrui", "refusé",
    () => setDoc(doc(env.authenticatedContext("neufBanc").firestore(), "users", "neufBanc"), {
        displayName: "Neuf", fcmTokens: ["jeton-de-la-victime"] }));
await cas(4, "créer un événement Firestore (poussé à 50 km)", "refusé",
    () => setDoc(doc(moi, "events", `y-${RUN}`), {
        organizerId: MOI, title: "Vérifiez votre compte sur evil.tld",
        latitude: 13.5, longitude: 2.1 }));

// ── Témoins ───────────────────────────────────────────────────────────────
await cas(5, "NOMINAL — lire sa notification", "accepté",
    () => getDoc(doc(moi, "notifications", `n-${RUN}`)));
await cas(6, "NOMINAL — modifier son profil", "accepté",
    () => updateDoc(doc(moi, "users", MOI), { displayName: "Moi bis" }));
await cas(7, "NOMINAL — s'inscrire à un événement", "accepté",
    () => updateDoc(doc(moi, "events", `e-${RUN}`), { attendeeIds: arrayUnion(MOI) }));
await cas(8, "NOMINAL — effacer sa notification", "accepté",
    () => deleteDoc(doc(moi, "notifications", `n-${RUN}`)));
await cas(9, "NOMINAL — créer son profil sans jeton", "accepté",
    () => setDoc(doc(env.authenticatedContext("autreNeufBanc").firestore(), "users", "autreNeufBanc"), {
        displayName: "Neuf" }));

await env.cleanup();

console.log(`Règles : ${FICHIER}\n`);
for (const r of resultats.sort((a, b) => a.n - b.n)) {
    console.log(`${String(r.n).padStart(3)} ${r.verdict.padEnd(6)} ${r.libelle}  — ${r.detail}`);
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\n>>> ${echecs} ÉCHEC(S) sur ${resultats.length}`);
process.exit(echecs ? 1 : 0);
