// Banc des regles Firestore pour l'acceptation d'une demande d'ami.
//
// POURQUOI CE FICHIER EXISTE
// Le lot ecrit par `acceptFriendRequest` (friend_remote_datasource.dart) touche
// CINQ documents d'un coup, dont deux qui n'appartiennent pas a celui qui
// accepte. Un lot Firestore est atomique : UN seul refus annule les quatre
// autres ecritures. Le mode d'echec est donc « tout ou rien », et l'usager ne
// voit qu'un « Erreur de chargement » qui ne dit pas lequel des cinq a parle.
//
// Ce chemin a deja casse deux fois :
//   - 2026-08-05 : la regle `users/{userId}` couvrait create+update+delete dans
//     un seul `allow write` appelant `diff(resource.data)` sans garde. Sur une
//     CREATION `resource` est nul : la regle plantait au lieu de renvoyer
//     false. Separee en create/update/delete (4bbc208).
//   - ensuite : `allow create: if isOwner(userId)` refusait toujours le
//     `set(merge)` sur le profil de L'AUTRE quand ce document n'existait pas.
//     Or plus rien ne cree les documents `users` Firestore depuis la migration
//     vers Supabase — ils sont absents pour la quasi-totalite des comptes.
//
// CE QU'IL FAUT SAVOIR AVANT DE TOUCHER A CES REGLES
// `set(..., SetOptions(merge: true))` n'est PAS une methode : c'est un `create`
// quand le document est absent et un `update` quand il existe. Les deux regles
// doivent donc autoriser le meme geste, sinon l'acceptation marche avec
// certains comptes et pas avec d'autres — ce qui se diagnostique tres mal.
//
// USAGE
//   firebase emulators:start --only firestore --project diaspo-niger
//   node tools/rules_tests/acceptation_ami.mjs
//
// « Parcours nominal : INTACT » est la condition de deploiement. Le bloc 3 ne
// rend pas de verdict, il MESURE ce que la regle laisse passer a cote.
//
// PIEGE DEJA PAYE : `@firebase/rules-unit-testing` vit dans
// `test/rules/node_modules`, hors du depot (voir test/rules/package.json).
// Sans `npm install` prealable dans ce dossier, le banc ne demarre pas.

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
        "Dependance absente. Lancer d'abord :\n" +
        "  cd test/rules && npm install\n",
    );
    process.exit(2);
}
const { initializeTestEnvironment, assertFails, assertSucceeds } = rut;
const { doc, writeBatch, setDoc, serverTimestamp, arrayUnion, arrayRemove } =
    require_("firebase/firestore");

const A = "expediteur_A"; // a envoye la demande
const B = "destinataire_B"; // accepte la demande — c'est lui qui ecrit
const DEMANDE = "demande_1";

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

/**
 * Le lot exact de `acceptFriendRequest`, rejoue tel quel.
 *
 * @param {import("firebase/firestore").Firestore} db base authentifiee en B
 * @param {boolean} avecFriendIds ecrire aussi le tableau `friendIds` des deux
 *   profils, comme le faisait le code avant le correctif.
 */
function lotAcceptation(db, { avecFriendIds }) {
    const lot = writeBatch(db);

    lot.update(doc(db, "friend_requests", DEMANDE), {
        status: "accepted",
        updatedAt: serverTimestamp(),
    });
    lot.set(doc(db, "users", A, "friends", B), {
        id: B, displayName: "B", photoUrl: null, addedAt: serverTimestamp(),
    });
    lot.set(doc(db, "users", B, "friends", A), {
        id: A, displayName: "A", photoUrl: null, addedAt: serverTimestamp(),
    });

    if (avecFriendIds) {
        lot.set(doc(db, "users", A), { friendIds: arrayUnion(B) }, { merge: true });
        lot.set(doc(db, "users", B), { friendIds: arrayUnion(A) }, { merge: true });
    }
    return lot.commit();
}

/** Remet la demande en attente, et (dé)pose les profils demandes. */
async function miseEnPlace({ profilA, profilB }) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, "friend_requests", DEMANDE), {
            senderId: A, senderName: "A", senderPhotoUrl: null,
            receiverId: B, receiverName: "B", receiverPhotoUrl: null,
            status: "pending", createdAt: new Date(), updatedAt: new Date(),
        });
        if (profilA) await setDoc(doc(db, "users", A), { displayName: "A" });
        if (profilB) await setDoc(doc(db, "users", B), { displayName: "B" });
    });
}

const commeB = () => env.authenticatedContext(B).firestore();

// ---------------------------------------------------------------------------
console.log("\n1. PARCOURS NOMINAL — le lot que l'app envoie aujourd'hui");
console.log("   Condition de deploiement : les deux lignes doivent passer.\n");

for (const profilA of [false, true]) {
    await miseEnPlace({ profilA, profilB: false });
    const quoi =
        `B accepte la demande de A — profil Firestore de A ${profilA ? "PRESENT" : "ABSENT "}`;
    try {
        await assertSucceeds(lotAcceptation(commeB(), { avecFriendIds: false }));
        ligne(true, quoi);
    } catch (e) {
        ligne(false, `${quoi}  → ${String(e).split("\n")[0]}`);
    }
}

// ---------------------------------------------------------------------------
console.log("\n2. PARCOURS NOMINAL — le lot des APK deja installes");
console.log("   (avec les ecritures `friendIds` que le client ne fait plus)");
console.log("   Condition de deploiement : les deux lignes doivent passer.\n");

for (const profilA of [false, true]) {
    await miseEnPlace({ profilA, profilB: false });
    const quoi =
        `ancien APK : profil Firestore de A ${profilA ? "PRESENT" : "ABSENT "}`;
    try {
        await assertSucceeds(lotAcceptation(commeB(), { avecFriendIds: true }));
        ligne(true, quoi);
    } catch (e) {
        ligne(
            false,
            `${quoi}  → ${String(e).split("\n")[0]}` +
            (profilA ? "" : "   ← la panne vue par l'usager"),
        );
    }
}

// ---------------------------------------------------------------------------
console.log("\n3. MESURE — etancheite des sous-collections `friends`\n");

await miseEnPlace({ profilA: true, profilB: true });
const tiers = env.authenticatedContext("tiers_C").firestore();
for (const [quoi, geste] of [
    [
        "un tiers s'ajoute a la liste d'amis de A (friendId == son uid)",
        () => setDoc(doc(tiers, "users", A, "friends", "tiers_C"), { id: "tiers_C" }),
    ],
    [
        "un tiers ajoute B a la liste d'amis de A (friendId != son uid)",
        () => setDoc(doc(tiers, "users", A, "friends", B), { id: B }),
    ],
    [
        "un tiers retire B de la liste d'amis de A",
        () => setDoc(doc(tiers, "users", A, "friends", B), { id: B }, { merge: true }),
    ],
    [
        "un tiers pose friendIds sur le profil de A (sans y etre)",
        () => setDoc(doc(tiers, "users", A), { friendIds: arrayUnion(B) }, { merge: true }),
    ],
    [
        "un tiers retire son propre uid du profil de A",
        () => setDoc(doc(tiers, "users", A), { friendIds: arrayRemove("tiers_C") }, { merge: true }),
    ],
]) {
    let verdict;
    try {
        await geste();
        verdict = "PASSE";
    } catch (e) {
        verdict = /permission|insufficient/i.test(String(e)) ? "REFUSE" : `ERREUR ${e}`;
    }
    console.log(`        ${verdict.padEnd(6)}  ${quoi}`);
}

// ---------------------------------------------------------------------------
console.log("\n4. GARDE-FOUS — ce qui doit rester refuse\n");

await miseEnPlace({ profilA: true, profilB: true });
for (const [quoi, geste] of [
    [
        "A (l'expediteur) accepte sa propre demande",
        () =>
            setDoc(
                doc(env.authenticatedContext(A).firestore(), "friend_requests", DEMANDE),
                { status: "accepted" },
                { merge: true },
            ),
    ],
    [
        "un tiers accepte la demande a la place de B",
        () => setDoc(doc(tiers, "friend_requests", DEMANDE), { status: "accepted" }, { merge: true }),
    ],
    [
        "B se donne isAdmin en acceptant",
        () =>
            setDoc(
                doc(commeB(), "users", B),
                { friendIds: arrayUnion(A), isAdmin: true },
                { merge: true },
            ),
    ],
    // L'exception de CREATION ouverte pour les anciens APK doit rester
    // etroite : rien d'autre que `friendIds`, et rien d'autre que son uid.
    [
        "un tiers CREE le profil de A avec un champ en plus",
        () =>
            setDoc(doc(tiers, "users", "profil_neuf_1"), {
                friendIds: ["tiers_C"], displayName: "pirate",
            }),
    ],
    [
        "un tiers CREE le profil de A en y mettant l'uid de quelqu'un d'autre",
        () => setDoc(doc(tiers, "users", "profil_neuf_2"), { friendIds: [B] }),
    ],
    [
        "un tiers CREE un profil en se donnant isAdmin",
        () =>
            setDoc(doc(tiers, "users", "profil_neuf_3"), {
                friendIds: ["tiers_C"], isAdmin: true,
            }),
    ],
]) {
    try {
        await assertFails(geste());
        ligne(true, `refuse : ${quoi}`);
    } catch {
        ligne(false, `AUTORISE (ne devrait pas) : ${quoi}`);
    }
}

// ---------------------------------------------------------------------------
console.log("\n5. CYCLE DE VIE — une demande ne se traite qu'une fois\n");

/** Pose une demande dans l'etat voulu, regles desactivees. */
async function demandeAvecStatut(statut) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "friend_requests", DEMANDE), {
            senderId: A, senderName: "A", receiverId: B, receiverName: "B",
            status: statut, createdAt: new Date(), updatedAt: new Date(),
        });
    });
}

const repondre = (statut) =>
    setDoc(doc(commeB(), "friend_requests", DEMANDE),
        { status: statut, updatedAt: serverTimestamp() }, { merge: true });

for (const [statut, attendu] of [
    ["pending", "PASSE"],
    ["accepted", "REFUSE"],
    ["declined", "REFUSE"],
    ["cancelled", "REFUSE"],
]) {
    await demandeAvecStatut(statut);
    let verdict;
    try {
        await repondre("accepted");
        verdict = "PASSE";
    } catch (e) {
        verdict = /permission|insufficient/i.test(String(e)) ? "REFUSE" : `ERREUR ${e}`;
    }
    ligne(verdict === attendu,
        `B accepte une demande « ${statut} » -> ${verdict} (attendu ${attendu})`);
}

await demandeAvecStatut("pending");
try {
    await assertFails(repondre("cancelled"));
    ligne(true, "refuse : le destinataire ne peut pas ANNULER a la place de l'expediteur");
} catch {
    ligne(false, "AUTORISE : le destinataire peut annuler a la place de l'expediteur");
}

// ---------------------------------------------------------------------------
console.log("\n6. CREATION — on n'envoie une demande QUE de sa part\n");

const creer = (qui, donnees) =>
    setDoc(doc(env.authenticatedContext(qui).firestore(),
        "friend_requests", "demande_neuve"), donnees);

await env.clearFirestore();
const base = { senderName: "A", receiverName: "B", status: "pending" };

try {
    await assertSucceeds(creer(A, { ...base, senderId: A, receiverId: B }));
    ligne(true, "A envoie une demande a B");
} catch (e) {
    ligne(false, `A ne peut plus envoyer de demande — ${String(e).split("\n")[0]}`);
}

for (const [quoi, qui, donnees] of [
    ["une demande AU NOM d'un autre", "tiers_C", { ...base, senderId: A, receiverId: B }],
    ["une demande a soi-meme", A, { ...base, senderId: A, receiverId: A }],
    ["une demande deja « accepted »", A, { ...base, senderId: A, receiverId: B, status: "accepted" }],
]) {
    await env.clearFirestore();
    try {
        await assertFails(creer(qui, donnees));
        ligne(true, `refuse : ${quoi}`);
    } catch {
        ligne(false, `AUTORISE (ne devrait pas) : ${quoi}`);
    }
}

await env.cleanup();

console.log(
    `\n${echecs === 0 ? "Parcours nominal : INTACT" : `Parcours nominal : ${echecs} ECHEC(S)`}\n`,
);
process.exit(echecs === 0 ? 0 : 1);
