// Banc : la chaîne de paiement n'accepte plus d'ordre venu du client.
//
//   firebase emulators:start --only firestore --project diaspo-niger
//   cd test/rules && npm install     # une seule fois par worktree
//   node tools/rules_tests/paiements_fermes.mjs
//
// Condition : 0 cas en ÉCHEC.
//
// Douze collections Firestore font bouger de l'argent. Chacune sert de
// DÉCLENCHEUR à une Cloud Function qui agit en Admin SDK : créer le document,
// c'est ordonner le virement. Les règles laissaient n'importe quel compte le
// créer, pourvu qu'il s'y déclare propriétaire — elles demandaient donc à
// l'appelant s'il était autorisé.
//
// Chaque document fabriqué ici est VALIDE au sens des anciennes règles : il
// porte l'uid de l'appelant, un montant positif, les champs exigés. S'il est
// refusé, c'est bien parce que l'écriture est fermée, et non parce qu'une
// validation de forme aurait échoué. C'est ce que le banc prouve.
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// Avec les règles d'avant, les douze créations passent et le banc tombe à
// 12 échecs — mesuré le 2026-09-21 en restaurant la version sauvegardée.
//
// ── Non-régressions ───────────────────────────────────────────────────────
//
// Les cas 20+ vérifient que la fermeture n'a pas débordé : la LECTURE reste
// ouverte à qui y a droit, `orders` reste créable par son acheteur (elle a un
// vrai chemin client, `marketplace_remote_datasource.dart:49`, et demande un
// traitement par champs plutôt qu'une fermeture), et une collection sans
// rapport continue de fonctionner.
//
// PIÈGE DÉJÀ PAYÉ : `@firebase/rules-unit-testing` vit dans
// `test/rules/node_modules`, hors du dépôt. Sans `npm install` préalable dans
// ce dossier, le banc ne démarre pas.

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
    console.error(
        "Dépendance absente. Lancer d'abord :\n  cd test/rules && npm install\n",
    );
    process.exit(2);
}
const { initializeTestEnvironment, assertSucceeds, assertFails } = rut;
const { doc, setDoc, getDoc } = require_("firebase/firestore");

const MOI = "createur-banc-paiement";
const AUTRE = "autre-banc-paiement";
const RUN = Date.now().toString(36);

const resultats = [];

async function cas(n, libelle, attendu, action) {
    try {
        await (attendu === "accepté" ? assertSucceeds(action()) : assertFails(action()));
        resultats.push({ n, cas: libelle, verdict: "OK", detail: attendu });
    } catch (e) {
        resultats.push({
            n, cas: libelle, verdict: "ÉCHEC",
            detail: `attendu ${attendu} — ${String(e).slice(0, 110)}`,
        });
    }
}

const env = await initializeTestEnvironment({
    projectId: "diaspo-niger",
    firestore: {
        rules: readFileSync(join(RACINE, "firestore.rules"), "utf8"),
        host: "127.0.0.1",
        port: 8080,
    },
});
await env.clearFirestore();

const moi = env.authenticatedContext(MOI).firestore();

// Chaque charge est VALIDE au sens des anciennes règles.
const ordres = [
    ["escrow_transactions", { initiatorId: MOI, participantIds: [MOI, AUTRE], amount: 50000 }],
    ["tips", { senderId: MOI, recipientId: AUTRE, amount: 100000, roomId: "salon-1" }],
    ["roomTickets", { buyerId: MOI, sellerId: AUTRE, priceAmount: 5000, roomId: "salon-1" }],
    ["roomReplays", { hostId: MOI, roomId: "salon-1", price: 1000 }],
    ["creatorSubscriptions", { subscriberId: MOI, creatorId: AUTRE, amount: 2000 }],
    ["payouts", { creatorId: MOI, status: "pending", amount: 1000000 }],
    ["stripe_connect_requests", { userId: MOI, type: "create_login_link" }],
    ["debit_requests", { userId: MOI, amount: 500000 }],
    ["card_credit_requests", { userId: MOI, amount: 500000 }],
    ["order_payment_requests", { userId: MOI, orderId: "cmd-1", paymentIntentId: "pi_1" }],
    ["escrow_release_requests", { userId: MOI, orderId: "cmd-1" }],
];

let n = 1;
for (const [collection, charge] of ordres) {
    await cas(n, `ORDRE DE VIREMENT — créer ${collection}`, "refusé", () =>
        setDoc(doc(moi, collection, `${collection}-${RUN}`), charge));
    n += 1;
}

// `creatorProfiles` : le solde et le compte Stripe étaient posables à la
// création — le premier finançait un retrait, le second ouvrait le tableau de
// bord Stripe d'un autre. L'identifiant DOIT être celui de l'appelant, sinon
// l'ancienne règle refusait déjà et le cas ne prouverait rien.
await cas(12, "ORDRE DE VIREMENT — créer son creatorProfiles avec un solde", "refusé", () =>
    setDoc(doc(moi, "creatorProfiles", MOI), {
        userId: MOI, availableBalance: 9999999, stripeAccountId: "acct_de_la_victime",
    }));

// ═══ Non-régressions ═══════════════════════════════════════════════════════
await cas(20, "lecture : son propre profil créateur reste lisible", "accepté", () =>
    getDoc(doc(moi, "creatorProfiles", MOI)));

// La demande doit EXISTER : `allow get` de `payouts` lit
// `resource.data.creatorId`, donc sur un document absent la règle ne refuse
// pas — elle PLANTE, et le refus qui s'ensuit n'a rien à voir avec ce qu'on
// teste. Piège déjà connu du projet (cf. CLAUDE.md, « la règle plantait au
// lieu de renvoyer false »). On la sème donc règles désactivées.
await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), "payouts", `payout-existant-${RUN}`), {
        creatorId: MOI, status: "pending", amount: 1000,
    }));

await cas(21, "lecture : ses propres demandes de retrait restent lisibles", "accepté", () =>
    getDoc(doc(moi, "payouts", `payout-existant-${RUN}`)));

await cas(22, "orders : l'acheteur crée toujours sa commande", "accepté", () =>
    setDoc(doc(moi, "orders", `cmd-${RUN}`), {
        buyerId: MOI, sellerId: AUTRE, status: "pending", totalAmount: 1000,
    }));

await cas(23, "une collection sans rapport fonctionne toujours", "accepté", () =>
    setDoc(doc(moi, "friend_requests", `dem-${RUN}`), {
        senderId: MOI, receiverId: AUTRE, status: "pending",
    }));

// ═══ Rapport ═══════════════════════════════════════════════════════════════
await env.cleanup();

for (const r of resultats) {
    console.log(
        `${String(r.n).padStart(2)} ${r.verdict.padEnd(6)} ${r.cas}` +
        (r.verdict === "ÉCHEC" ? `\n       ${r.detail}` : ` (${r.detail})`),
    );
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\nÉCHECS: ${echecs} / ${resultats.length}`);
process.exit(echecs === 0 ? 0 : 1);
