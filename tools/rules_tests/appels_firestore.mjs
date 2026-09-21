// Banc : les règles Firestore de `calls/{callId}`.
//
//   firebase emulators:start --only firestore --project diaspo-niger
//   node tools/rules_tests/appels_firestore.mjs
//   # contre d'autres règles (preuve qu'il sait échouer) :
//   FICHIER_REGLES=<chemin> node tools/rules_tests/appels_firestore.mjs
//
// Condition : 0 cas en ÉCHEC contre `firestore.rules`.
//
// Créer un document `calls/<id>` fait SONNER l'appelé (`onCallCreated`, push
// `incoming_call`) ; le mettre à jour fait prévenir l'appelant
// (`onCallUpdated`). La règle n'exigeait que `callerId == auth.uid` à la
// création, et laissait un participant réécrire N'IMPORTE QUEL champ à la mise
// à jour — `callerId` compris, et `onCallUpdated` prévenait alors un tiers.
//
// Le parcours NOMINAL (cas 1-3 et 9-11) est rejoué tel que l'app l'écrit
// (call_repository_impl.dart:37, call_remote_datasource.dart:148, :224,
// :273-282, :296, :311) : c'est la condition de déploiement, un appel qui ne
// se crée plus ou ne se raccroche plus serait pire que le trou.

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
const { doc, setDoc, updateDoc, addDoc, collection, serverTimestamp } =
    require_("firebase/firestore");

const FICHIER = process.env.FICHIER_REGLES || join(RACINE, "firestore.rules");
const MOI = "appelantBanc";
const AUTRE = "appeleBanc";
const TIERS = "tiersBanc";
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
const autre = env.authenticatedContext(AUTRE).firestore();
const tiers = env.authenticatedContext(TIERS).firestore();

/** Un appel tel que `CallModel.toFirestore()` l'écrit. */
const appel = (surcharge = {}) => ({
    callerId: MOI, callerName: "Moi", callerPhotoUrl: "",
    calleeId: AUTRE, calleeName: "Autre", calleePhotoUrl: "",
    type: "audio", status: "ringing", createdAt: serverTimestamp(), ...surcharge,
});

// ── Création ───────────────────────────────────────────────────────────────
await cas(1, "NOMINAL — appel vocal qui sonne", "accepté",
    () => addDoc(collection(moi, "calls"), appel()));
await cas(2, "NOMINAL — appelé occupé (busy)", "accepté",
    () => addDoc(collection(moi, "calls"), appel({ status: "busy", endReason: "callee_busy" })));
await cas(3, "NOMINAL — appel vidéo", "accepté",
    () => addDoc(collection(moi, "calls"), appel({ type: "video" })));
await cas(4, "se faire passer pour un autre appelant", "refusé",
    () => addDoc(collection(moi, "calls"), appel({ callerId: TIERS })));
await cas(5, "type d'appel inventé", "refusé",
    () => addDoc(collection(moi, "calls"), appel({ type: "incoming_call" })));
await cas(6, "créer un appel directement « terminé »", "refusé",
    () => addDoc(collection(moi, "calls"), appel({ status: "ended" })));
await cas(7, "appelé forgé pour réécrire l'URL PostgREST", "refusé",
    () => addDoc(collection(moi, "calls"), appel({ calleeId: 'x")&id=not.is.null' })));
await cas(8, "s'appeler soi-même", "refusé",
    () => addDoc(collection(moi, "calls"), appel({ calleeId: MOI })));

// ── Mise à jour d'un appel existant (MOI appelle AUTRE) ────────────────────
const posé = async (id, surcharge = {}) => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), "calls", id), {
        callerId: MOI, callerName: "Moi", calleeId: AUTRE, calleeName: "Autre",
        type: "audio", status: "ringing", ...surcharge,
    }));

await posé(`a-${RUN}`);
await cas(9, "NOMINAL — l'appelé décroche", "accepté",
    () => updateDoc(doc(autre, "calls", `a-${RUN}`), { status: "connecting", answeredAt: serverTimestamp() }));

await posé(`b-${RUN}`);
await cas(10, "NOMINAL — l'appelé refuse", "accepté",
    () => updateDoc(doc(autre, "calls", `b-${RUN}`), { status: "declined", endedAt: serverTimestamp(), endReason: "declined" }));

await posé(`c-${RUN}`, { status: "connected" });
await cas(11, "NOMINAL — l'appelant raccroche (durée comprise)", "accepté",
    () => updateDoc(doc(moi, "calls", `c-${RUN}`), {
        status: "ended", endedAt: serverTimestamp(), endReason: "hangup", durationSeconds: 42 }));

await posé(`d-${RUN}`);
await cas(12, "LA FAILLE — l'appelé réécrit callerId (onCallUpdated préviendrait un tiers)", "refusé",
    () => updateDoc(doc(autre, "calls", `d-${RUN}`), { status: "declined", callerId: TIERS }));

await posé(`e-${RUN}`);
await cas(13, "réécrire les noms affichés après coup", "refusé",
    () => updateDoc(doc(moi, "calls", `e-${RUN}`), { callerName: "Service Sécurité" }));

await posé(`f-${RUN}`);
await cas(14, "un tiers change le statut", "refusé",
    () => updateDoc(doc(tiers, "calls", `f-${RUN}`), { status: "ended" }));

await env.cleanup();

console.log(`Règles : ${FICHIER}\n`);
for (const r of resultats.sort((a, b) => a.n - b.n)) {
    console.log(`${String(r.n).padStart(3)} ${r.verdict.padEnd(6)} ${r.libelle}  — ${r.detail}`);
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\n>>> ${echecs} ÉCHEC(S) sur ${resultats.length}`);
process.exit(echecs ? 1 : 0);
