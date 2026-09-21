// Banc : ce que `onCallCreated` fait sonner (functions/appels.js).
//
//   node tools/rules_tests/appel_entrant.mjs
//
// Condition : 0 ÉCHEC sur la version courante.
//
// Ni émulateur, ni réseau : `preparerAppelEntrant` est une fonction pure. Elle
// décide du push `incoming_call` — celui qui fait sonner le téléphone et ouvre
// l'écran d'appel NATIF, même app fermée.
//
// ── L'attaque rejouée (cas 1) ─────────────────────────────────────────────
//
// La règle Firestore de `calls/<id>` n'impose que `callerId == auth.uid`. Le
// nom et la photo de l'appelant, eux, étaient lus dans le document que le
// client écrit : n'importe quel compte faisait sonner n'importe qui sous le
// nom et le visage d'un proche, ou de « Service Sécurité ». Et un compte bloqué
// sonnait quand même (cas 2).
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// L'ancienne logique vivait en ligne dans `index.js`, pas dans un module : elle
// est RETRANSCRITE ci-dessous (`ancien`), à l'identique de la version déployée
// avant le 2026-09-21, et passée sur les mêmes cas. Le banc imprime combien
// elle en échoue — c'est sa preuve qu'il sait échouer.

import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const require_ = createRequire(join(RACINE, "functions", "package.json"));
const { preparerAppelEntrant, nomAppele } = require_(join(RACINE, "functions", "appels.js"));

/** L'ANCIEN corps d'`onCallCreated`, réduit à sa décision (index.js, v4.9). */
function ancien({ callId, callData, utilisateurs }) {
  if (callData.status !== "ringing") return { rien: true, motif: "statut" };
  const calleeId = callData.calleeId;
  if (!calleeId) return { rien: true, motif: "pas d'appelé" };
  const tokens = (utilisateurs.get(calleeId) || { fcmTokens: [] }).fcmTokens;
  if (tokens.length === 0) return { rien: true, motif: "aucun jeton" };
  const callerName = callData.callerName || "Quelqu'un";
  const callType = callData.type || "audio";
  return {
    tokens,
    data: {
      type: "incoming_call", callId, callerId: callData.callerId, callerName,
      callerPhotoUrl: callData.callerPhotoUrl || "", callType,
      title: callerName,
      body: callType === "video" ? "Appel vidéo entrant..." : "Appel vocal entrant...",
      click_action: "FLUTTER_NOTIFICATION_CLICK", timestamp: String(Date.now()),
    },
    apns: {},
  };
}

const ALICE = "uidAlice";
const BOB = "uidBob";
const base = new Map([
  [ALICE, { displayName: "Alice Vraie", avatarUrl: "https://exemple.invalid/alice.png", fcmTokens: ["jA"] }],
  [BOB, { displayName: "Bob", avatarUrl: "", fcmTokens: ["jB1", "jB2"] }],
]);
const appel = (surcharge = {}) => ({
  status: "ringing", callerId: ALICE, calleeId: BOB, type: "audio",
  callerName: "Alice Vraie", callerPhotoUrl: "", ...surcharge,
});

/** [nom, entrée, vérification(résultat) → true si conforme] */
const CAS = [
  ["LA FAILLE — le nom et la photo affichés viennent de la base, pas du document",
    { callId: "c1", callData: appel({ callerName: "Service Sécurité", callerPhotoUrl: "https://piege.invalid/p.png" }), utilisateurs: base, bloque: false },
    (r) => !r.rien && r.data.callerName === "Alice Vraie" && r.data.title === "Alice Vraie"
      && r.data.callerPhotoUrl === "https://exemple.invalid/alice.png"],
  ["LA FAILLE — un appelé qui a bloqué l'appelant ne sonne pas",
    { callId: "c2", callData: appel(), utilisateurs: base, bloque: true },
    (r) => r.rien === true && r.motif === "bloqué"],
  ["un identifiant d'appelé forgé pour réécrire l'URL PostgREST est refusé",
    { callId: "c3", callData: appel({ calleeId: 'x")&id=not.is.null&y=("' }), utilisateurs: base, bloque: false },
    (r) => r.rien === true && r.motif === "identifiant invalide"],
  ["s'appeler soi-même ne sonne pas",
    { callId: "c4", callData: appel({ calleeId: ALICE }), utilisateurs: base, bloque: false },
    (r) => r.rien === true],
  ["un type d'appel inventé repart en « audio »",
    { callId: "c5", callData: appel({ type: "incoming_call" }), utilisateurs: base, bloque: false },
    (r) => !r.rien && r.data.callType === "audio" && r.data.body === "Appel vocal entrant..."],
  ["un appel vidéo reste vidéo",
    { callId: "c6", callData: appel({ type: "video" }), utilisateurs: base, bloque: false },
    (r) => !r.rien && r.data.callType === "video" && r.data.body === "Appel vidéo entrant..."],
  ["un appelant inconnu de la base sonne sous « Quelqu'un », pas sous le nom qu'il s'est donné",
    { callId: "c7", callData: appel({ callerId: "uidInconnu", callerName: "Maman" }), utilisateurs: base, bloque: false },
    (r) => !r.rien && r.data.callerName === "Quelqu'un"],
  ["un statut autre que « ringing » ne sonne pas",
    { callId: "c8", callData: appel({ status: "busy" }), utilisateurs: base, bloque: false },
    (r) => r.rien === true],
  ["un appelé sans jeton ne sonne pas",
    { callId: "c9", callData: appel({ calleeId: "uidSansJeton" }), utilisateurs: base, bloque: false },
    (r) => r.rien === true && r.motif === "aucun jeton"],
  ["non-régression — un appel normal part vers tous les jetons de l'appelé, valeurs en chaînes",
    { callId: "c10", callData: appel(), utilisateurs: base, bloque: false },
    (r) => !r.rien && r.tokens.join() === "jB1,jB2" && r.data.type === "incoming_call"
      && r.data.callId === "c10" && r.data.callerId === ALICE
      && Object.values(r.data).every((v) => typeof v === "string")],
  ["iOS reçoit la même identité, lue en base",
    { callId: "c11", callData: appel({ callerName: "Service Sécurité" }), utilisateurs: base, bloque: false },
    (r) => !r.rien && r.apns.callerName === "Alice Vraie" && r.apns.callId === "c11"],
];

let echecs = 0;
let echecsAncien = 0;
for (const [nom, entree, conforme] of CAS) {
  const ok = conforme(preparerAppelEntrant(entree));
  if (!ok) echecs++;
  let okAncien = false;
  try { okAncien = conforme(ancien(entree)); } catch { okAncien = false; }
  if (!okAncien) echecsAncien++;
  console.log(`${ok ? "OK    " : "ÉCHEC "} ${nom}${okAncien ? "" : "   [l'ancienne logique échoue]"}`);
}

// onCallUpdated : le nom de l'appelé cité à l'appelant.
{
  const ok = nomAppele(base, BOB) === "Bob" && nomAppele(base, 'x")&') === "L'utilisateur"
    && nomAppele(base, "uidInconnu") === "L'utilisateur";
  if (!ok) echecs++;
  console.log(`${ok ? "OK    " : "ÉCHEC "} onCallUpdated : le nom de l'appelé vient de la base, identifiant vérifié`);
}

console.log(`\n>>> ${echecs} ÉCHEC(S) — version courante`);
console.log(`>>> l'ancienne logique échoue ${echecsAncien} cas sur ${CAS.length}`);
process.exit(echecs ? 1 : 0);
