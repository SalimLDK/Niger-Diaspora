// Banc des regles RTDB de la messagerie : conversations/participants,
// messages, typing.
//
// LE TROU
// `conversations/<id>/participants` acceptait une ecriture des que le noeud
// n'existait pas (`!data.exists()`). Depuis la migration, les conversations
// vivent dans Supabase : ce noeud RTDB n'existe pas pour la plupart d'entre
// elles. N'importe quel compte pouvait donc s'y inscrire, puis lire et ecrire
// `messages/<id>` et `typing/<id>`. Tant que `onMessageCreated` tournait,
// ecrire `messages/<id>` envoyait un push au contenu libre a tous les
// participants (audit du 2026-10-03, P1).
//
// POURQUOI FERMER PLUTOT QUE RESSERRER
// Les regles RTDB ne savent pas interroger Supabase, ou vit l'appartenance :
// aucune regle ne peut dire qui est participant. Et plus rien de vivant ne
// s'en sert : messages et frappe passent par Supabase, `onMessageCreated` est
// retiree (43cc5222), `cleanupExpiredMediaFiles` lit en administrateur, et
// l'ecriture des participants par `call_message_service` n'existait que
// « pour les permissions » de `messages/`. La cible stricte ferme les trois.
//
// USAGE
//   firebase emulators:start --only database --project diaspo-niger
//   node tools/rules_tests/conversations_rtdb_fermees.mjs [fichier-de-regles]
//
// Le fichier par defaut est la cible stricte. Avec `database.rules.json`, le
// banc mesure l'etat deploye (trous ouverts). Il charge les regles dans
// l'emulateur : relancer ensuite `signalisation_appels.mjs` sur le meme jeu,
// dont « Parcours nominal : INTACT » reste la condition de deploiement.

import { readFileSync } from "node:fs";

const HOST = process.env.RTDB_EMULATEUR || "http://127.0.0.1:9102";
const NS = "diaspo-niger-default-rtdb";
const FICHIER = process.argv[2] || "database.rules.strict-cible.json";

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
function jeton(uid) {
    const now = Math.floor(Date.now() / 1000);
    return [
        b64({ alg: "none", kid: "fakekid", typ: "JWT" }),
        b64({
            iss: "https://securetoken.google.com/diaspo-niger",
            aud: "diaspo-niger",
            sub: uid, user_id: uid,
            auth_time: now, iat: now, exp: now + 3600,
            firebase: { identities: {}, sign_in_provider: "password" },
        }),
        "fakesignature",
    ].join(".");
}

const ADMIN = Symbol("admin");
async function requete(chemin, auth, methode = "GET", corps) {
    const entetes = { "Content-Type": "application/json" };
    let u = `${HOST}/${chemin}.json?ns=${NS}`;
    // `?auth=owner` ne donne PAS les droits admin : seul l'en-tete les donne.
    if (auth === ADMIN) entetes.Authorization = "Bearer owner";
    else u += `&auth=${encodeURIComponent(auth)}`;
    const r = await fetch(u, {
        method: methode,
        headers: entetes,
        body: corps === undefined ? undefined : JSON.stringify(corps),
    });
    return r.ok;
}

// Les regles, chargees par l'API d'administration de l'emulateur.
const regles = readFileSync(FICHIER, "utf8");
const charge = await fetch(`${HOST}/.settings/rules.json?ns=${NS}`, {
    method: "PUT",
    headers: { Authorization: "Bearer owner" },
    body: regles,
});
if (!charge.ok) {
    console.error(`Chargement de ${FICHIER} refuse : ${charge.status} ${await charge.text()}`);
    process.exit(2);
}

const A = jeton("banc-rtdb-a");          // vrai participant (inscrit par l'admin)
const INTRUS = jeton("banc-rtdb-intrus");
const conv = `banc-rtdb-${Date.now()}`;
const neuve = `${conv}-jamais-vue`;

// Mise en place, en administrateur : une conversation dont A est participant.
await requete(`conversations/${conv}/participants`, ADMIN, "PUT", { "banc-rtdb-a": true });

const message = { senderId: "banc-rtdb-intrus", type: "text", createdAt: "2026-10-08T00:00:00Z", content: "faux" };
const cas = [
    ["un intrus s'inscrit dans une conversation jamais vue de RTDB",
        () => requete(`conversations/${neuve}/participants/banc-rtdb-intrus`, INTRUS, "PUT", true)],
    ["un intrus s'ajoute a une conversation existante",
        () => requete(`conversations/${conv}/participants/banc-rtdb-intrus`, INTRUS, "PUT", true)],
    ["un intrus ecrit un message (conversation jamais vue)",
        () => requete(`messages/${neuve}/m1`, INTRUS, "PUT", message)],
    ["un intrus lit les messages d'une conversation",
        () => requete(`messages/${conv}`, INTRUS)],
    ["un intrus ecrit « en train d'ecrire »",
        () => requete(`typing/${neuve}/banc-rtdb-intrus`, INTRUS, "PUT", true)],
    ["meme un participant n'ecrit plus de message RTDB (chemin mort)",
        () => requete(`messages/${conv}/m2`, A, "PUT", { ...message, senderId: "banc-rtdb-a" })],
];

console.log(`\n=== Regles : ${FICHIER} ===\n`);
let ouverts = 0;
for (const [nom, essai] of cas) {
    const accepte = await essai();
    if (accepte) ouverts++;
    console.log(`  [${accepte ? "OUVERT" : "ferme "}] ${nom}`);
}
console.log(`\n--- Verdict ---`);
console.log(ouverts === 0
    ? "  Messagerie RTDB : FERMEE."
    : `  Messagerie RTDB : ${ouverts} acces ouverts.`);
process.exit(0);
