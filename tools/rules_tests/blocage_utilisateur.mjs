// Banc des regles Firestore pour le blocage d'un utilisateur.
//
// POURQUOI CE FICHIER EXISTE
// Le lot ecrit par `blockUser` (blocked_users_datasource.dart) touchait TROIS
// documents, dont le profil `users` de la personne bloquee. Un lot Firestore
// est atomique : UN seul refus annule les deux autres ecritures. Et le miroir
// Supabase etait appele APRES `batch.commit()` — quand le lot levait, la ligne
// `public.blocked_users` n'etait jamais posee non plus. Bloquer quelqu'un
// n'avait donc aucun effet, ni cote Firestore, ni cote Supabase, pendant que
// l'ecran affichait la personne comme bloquee.
//
// C'est la copie exacte du defaut corrige le 2026-09-14 pour l'acceptation
// d'une demande d'ami (b497991, voir tools/rules_tests/acceptation_ami.mjs) —
// meme fichier de causes, trouve en cherchant ses autres occurrences.
//
// Les deux ecritures condamnees, chacune suffisante a elle seule :
//   1. `update(users/{moi}, {'blockedUserIds': arrayUnion(cible)})`
//      Sur un document ABSENT — et plus rien ne cree les documents `users`
//      depuis la migration vers Supabase. Le bloc 3 mesure ce que ca donne
//      vraiment, et corrige au passage la supposition de depart : ce n'est pas
//      le `NOT_FOUND` attendu qui remonte, mais un PERMISSION_DENIED, la regle
//      `allow update` appelant `diff(resource.data)` sur un `resource` nul.
//      Le `NOT_FOUND` n'apparait que regles desactivees.
//   2. `set(users/{cible}, {'blockedByUserIds': …}, merge)`
//      `set(merge)` sur un document absent est une CREATION, que
//      `users/{userId}` n'autorise qu'a son proprietaire.
// Aucune retouche des regles n'aurait sauve la premiere : la seule issue etait
// de retirer les deux ecritures, ce que fait le correctif.
//
// CE QU'IL FAUT SAVOIR AVANT DE TOUCHER A CES REGLES
// `set(..., SetOptions(merge: true))` n'est PAS une methode : c'est un `create`
// quand le document est absent et un `update` quand il existe. Les deux regles
// doivent donc autoriser le meme geste, sinon le blocage marche avec certains
// comptes et pas avec d'autres — ce qui se diagnostique tres mal.
//
// USAGE
//   firebase emulators:start --only firestore --project diaspo-niger
//   cd test/rules && npm install     # une seule fois
//   node tools/rules_tests/blocage_utilisateur.mjs
//
// « Parcours nominal : INTACT » est la condition de deploiement. Les blocs 3
// et 5 ne rendent pas de verdict, ils MESURENT.
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
const {
    doc, writeBatch, setDoc, deleteDoc, getDoc, serverTimestamp,
    arrayUnion, arrayRemove,
} = require_("firebase/firestore");

const MOI = "bloqueur_M"; // celui qui bloque — c'est lui qui ecrit
const CIBLE = "bloque_C"; // celui qui est bloque

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
 * Le lot de `blockUser`, rejoue tel quel.
 *
 * @param {import("firebase/firestore").Firestore} db base authentifiee en MOI
 * @param {boolean} avecTableauxProfil ecrire aussi `blockedUserIds` sur mon
 *   profil et `blockedByUserIds` sur celui de la cible, comme le faisait le
 *   code avant le correctif.
 */
function lotBlocage(db, { avecTableauxProfil }) {
    const lot = writeBatch(db);

    lot.set(doc(db, "users", MOI, "blocked_users", CIBLE), {
        id: CIBLE, displayName: "C", photoUrl: null,
        blockedAt: serverTimestamp(),
    });

    if (avecTableauxProfil) {
        lot.update(doc(db, "users", MOI), { blockedUserIds: arrayUnion(CIBLE) });
        lot.set(
            doc(db, "users", CIBLE),
            { blockedByUserIds: arrayUnion(MOI) },
            { merge: true },
        );
    }
    return lot.commit();
}

/** Le lot de `unblockUser`, rejoue tel quel. */
function lotDeblocage(db, { avecTableauxProfil }) {
    const lot = writeBatch(db);

    lot.delete(doc(db, "users", MOI, "blocked_users", CIBLE));

    if (avecTableauxProfil) {
        lot.update(doc(db, "users", MOI), { blockedUserIds: arrayRemove(CIBLE) });
        lot.set(
            doc(db, "users", CIBLE),
            { blockedByUserIds: arrayRemove(MOI) },
            { merge: true },
        );
    }
    return lot.commit();
}

/** Table rase, puis (de)pose les profils demandes. */
async function miseEnPlace({ profilMoi, profilCible, dejaBloque = false }) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        if (profilMoi) await setDoc(doc(db, "users", MOI), { displayName: "M" });
        if (profilCible) await setDoc(doc(db, "users", CIBLE), { displayName: "C" });
        if (dejaBloque) {
            await setDoc(doc(db, "users", MOI, "blocked_users", CIBLE), {
                id: CIBLE, displayName: "C", blockedAt: new Date(),
            });
        }
    });
}

const commeMoi = () => env.authenticatedContext(MOI).firestore();
const etat = (profil) => (profil ? "PRESENT" : "ABSENT ");

// ---------------------------------------------------------------------------
console.log("\n1. PARCOURS NOMINAL — le lot que l'app envoie aujourd'hui");
console.log("   Condition de deploiement : les quatre lignes doivent passer.\n");

for (const profilCible of [false, true]) {
    for (const [nom, lot, dejaBloque] of [
        ["bloque  ", lotBlocage, false],
        ["debloque", lotDeblocage, true],
    ]) {
        await miseEnPlace({ profilMoi: false, profilCible, dejaBloque });
        const quoi = `M ${nom} C — profil Firestore de C ${etat(profilCible)}`;
        try {
            await assertSucceeds(lot(commeMoi(), { avecTableauxProfil: false }));
            ligne(true, quoi);
        } catch (e) {
            ligne(false, `${quoi}  → ${String(e).split("\n")[0]}`);
        }
    }
}

// ---------------------------------------------------------------------------
console.log("\n2. LA SOUS-COLLECTION EST BIEN LA SEULE SOURCE");
console.log("   Ce que l'app lit (`getBlockedUsers`) doit exister apres le lot.\n");

await miseEnPlace({ profilMoi: false, profilCible: false });
try {
    await lotBlocage(commeMoi(), { avecTableauxProfil: false });
    let vu = false;
    await env.withSecurityRulesDisabled(async (ctx) => {
        vu = (await getDoc(
            doc(ctx.firestore(), "users", MOI, "blocked_users", CIBLE),
        )).exists();
    });
    ligne(vu, "l'entree `users/M/blocked_users/C` existe, sans profil `users/M`");
} catch (e) {
    ligne(false, `le lot a leve : ${String(e).split("\n")[0]}`);
}

// ---------------------------------------------------------------------------
console.log("\n3. MESURE — le lot d'AVANT le correctif, et pourquoi aucune");
console.log("   regle ne pouvait le sauver.\n");

for (const profilMoi of [false, true]) {
    for (const profilCible of [false, true]) {
        await miseEnPlace({ profilMoi, profilCible });
        let verdict;
        try {
            await lotBlocage(commeMoi(), { avecTableauxProfil: true });
            verdict = "PASSE ";
        } catch (e) {
            const t = String(e);
            verdict = /not[-_ ]?found/i.test(t)
                ? "NOT_FOUND"
                : /permission|insufficient/i.test(t)
                  ? "REFUSE"
                  : `ERREUR ${t.split("\n")[0]}`;
        }
        console.log(
            `        ${verdict.padEnd(9)}  ancien lot — mon profil ${etat(profilMoi)},` +
            ` celui de C ${etat(profilCible)}`,
        );
    }
}
// Le meme `update` sur un document absent, REGLES DESACTIVEES : ce qui reste
// quand on retire la couche des regles.
await miseEnPlace({ profilMoi: false, profilCible: false });
let sansRegles;
await env.withSecurityRulesDisabled(async (ctx) => {
    // Une seule prise de `ctx.firestore()` : la seconde leve
    // « settings can no longer be changed ».
    const db = ctx.firestore();
    const lot = writeBatch(db);
    lot.update(doc(db, "users", MOI), { blockedUserIds: arrayUnion(CIBLE) });
    try {
        await lot.commit();
        sansRegles = "PASSE";
    } catch (e) {
        sansRegles = /not[-_ ]?found/i.test(String(e))
            ? "NOT_FOUND"
            : `${String(e).split("\n")[0]}`;
    }
});
console.log(
    `        ${sansRegles.padEnd(9)}  l'\`update\` seul sur mon profil absent,` +
    " REGLES DESACTIVEES",
);

console.log(
    "\n   Lecture — et correction d'une supposition. On attendait un\n" +
    "   `NOT_FOUND` remonte par l'`update` sur MON profil absent. Ce n'est pas\n" +
    "   ce qui arrive : l'`allow update` de `users/{userId}` appelle\n" +
    "   `diff(resource.data)`, et sur un document absent `resource` est nul —\n" +
    "   « Null value error », donc PERMISSION_DENIED avant meme d'en arriver au\n" +
    "   document. Le `NOT_FOUND` n'apparait que regles desactivees (ligne\n" +
    "   ci-dessus) : il est bien la, mais l'usager ne le voit jamais.\n" +
    "   Consequence pratique : les deux causes rendent le MEME code d'erreur,\n" +
    "   et corriger les regles n'en aurait sauve aucune. Il fallait retirer les\n" +
    "   deux ecritures, ce que fait le correctif.\n" +
    "\n   Les anciens APK restent donc casses : « les deux profils PRESENTS »\n" +
    "   est la seule ligne qui passe, et elle ne decrit presque aucun compte.\n",
);

// ---------------------------------------------------------------------------
console.log("4. GARDE-FOUS — ce qui doit rester refuse\n");

await miseEnPlace({ profilMoi: true, profilCible: true, dejaBloque: true });
const tiers = env.authenticatedContext("tiers_T").firestore();
const commeCible = () => env.authenticatedContext(CIBLE).firestore();

for (const [quoi, geste] of [
    [
        "la cible lit la liste des gens que M a bloques",
        () => getDoc(doc(commeCible(), "users", MOI, "blocked_users", CIBLE)),
    ],
    [
        "la cible se retire de la liste des bloques de M",
        () => deleteDoc(doc(commeCible(), "users", MOI, "blocked_users", CIBLE)),
    ],
    [
        "un tiers bloque quelqu'un a la place de M",
        () =>
            setDoc(doc(tiers, "users", MOI, "blocked_users", "victime_V"), {
                id: "victime_V",
            }),
    ],
    [
        "un tiers pose blockedByUserIds sur le profil de la cible",
        () =>
            setDoc(
                doc(tiers, "users", CIBLE),
                { blockedByUserIds: arrayUnion(MOI) },
                { merge: true },
            ),
    ],
    [
        "M se donne isAdmin en bloquant",
        () =>
            setDoc(
                doc(commeMoi(), "users", MOI),
                { blockedUserIds: arrayUnion(CIBLE), isAdmin: true },
                { merge: true },
            ),
    ],
    // L'exception d'`update` sur `blockedByUserIds` ne doit ouvrir que le
    // retrait/ajout de SON PROPRE uid, et rien d'autre du document.
    [
        "M ecrase le displayName de la cible en la bloquant",
        () =>
            setDoc(
                doc(commeMoi(), "users", CIBLE),
                { blockedByUserIds: arrayUnion(MOI), displayName: "pirate" },
                { merge: true },
            ),
    ],
    [
        "M met l'uid d'un tiers dans le blockedByUserIds de la cible",
        () =>
            setDoc(
                doc(commeMoi(), "users", CIBLE),
                { blockedByUserIds: arrayUnion("tiers_T") },
                { merge: true },
            ),
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
console.log(
    "\n5. MESURE — l'exception d'`update` laissee pour les anciens APK\n" +
    "   (client actuel : plus personne ne l'emprunte)\n",
);

for (const [quoi, geste] of [
    [
        "M ajoute son uid au blockedByUserIds de la cible (profil PRESENT)",
        async () => {
            await miseEnPlace({ profilMoi: true, profilCible: true });
            return setDoc(
                doc(commeMoi(), "users", CIBLE),
                { blockedByUserIds: arrayUnion(MOI) },
                { merge: true },
            );
        },
    ],
    [
        "le meme, profil de la cible ABSENT (donc une creation)",
        async () => {
            await miseEnPlace({ profilMoi: true, profilCible: false });
            return setDoc(
                doc(commeMoi(), "users", CIBLE),
                { blockedByUserIds: arrayUnion(MOI) },
                { merge: true },
            );
        },
    ],
]) {
    let verdict;
    try {
        await geste();
        verdict = "PASSE";
    } catch (e) {
        verdict = /permission|insufficient/i.test(String(e))
            ? "REFUSE"
            : `ERREUR ${String(e).split("\n")[0]}`;
    }
    console.log(`        ${verdict.padEnd(6)}  ${quoi}`);
}
console.log(
    "\n   Lecture : la premiere PASSE (c'est l'exception d'`update` de\n" +
    "   `firestore.rules`), la seconde est REFUSEE — `allow create` n'ouvre\n" +
    "   que `friendIds`. L'exception ne repare donc PAS les anciens APK : leur\n" +
    "   lot bute de toute facon sur l'`update` de MON profil absent (bloc 3).\n" +
    "   Elle est laissee en place parce que la retirer ne repare rien non plus,\n" +
    "   et qu'elle reste strictement bornee (bloc 4).\n",
);

await env.cleanup();

console.log(
    `${echecs === 0 ? "Parcours nominal : INTACT" : `Parcours nominal : ${echecs} ECHEC(S)`}\n`,
);
process.exit(echecs === 0 ? 0 : 1);
