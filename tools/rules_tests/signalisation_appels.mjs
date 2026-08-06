// Test de non-regression des regles RTDB de signalisation d'appel.
//
// POURQUOI CE FICHIER EXISTE
// Le 2026-08-06, un durcissement des regles `calls`/`group_calls` a ete
// deploye en production. Il a casse tous les appels, en silence. Cause :
// les regles testaient `data.child('callerId').val() === auth.uid` sur le
// noeud RTDB, alors que `callerId`/`calleeId` n'existent QUE dans Firestore.
// Le noeud RTDB `calls/<id>` ne recoit que des enfants de signalisation
// (offer, answer, callerCandidates, calleeCandidates, videoUpgrade,
// renegotiate_*, ice_restart_*, heartbeat, e2ee_key). Le predicat etait donc
// toujours faux : plus personne ne pouvait lire l'offre, donc plus rien ne
// sonnait — sans une seule erreur nulle part.
//
// Ce test rejoue le parcours reel d'un appel contre l'emulateur. Toute
// modification des regles `calls` doit le faire passer AVANT d'etre deployee.
//
// USAGE
//   firebase emulators:start --only database --project diaspo-niger
//   node tools/rules_tests/signalisation_appels.mjs
//
// PIEGES DEJA PAYES, ne pas les repayer :
//   - `?auth=owner` ne donne PAS les droits admin sur l'emulateur (401).
//     Seul l'en-tete `Authorization: Bearer owner` les donne. Avec le mauvais
//     mode la mise en place echoue en silence et le banc mesure un arbre vide.
//   - Les candidats ICE ont un `.validate` : candidate + sdpMid + sdpMLineIndex.
//     Une charge utile partielle est refusee par la VALIDATION, pas par le
//     droit d'acces — ne pas confondre les deux en lisant un 401.

const HOST = process.env.RTDB_EMULATEUR || "http://127.0.0.1:9102";
const NS = "diaspo-niger-default-rtdb";

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");

/** Jeton d'identite. L'emulateur ne verifie pas la signature. */
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

function requete(chemin, auth, init = {}) {
    const entetes = { ...(init.headers || {}) };
    let u = `${HOST}/${chemin}.json?ns=${NS}`;
    if (auth === ADMIN) entetes.Authorization = "Bearer owner";
    else u += `&auth=${encodeURIComponent(auth)}`;
    return fetch(u, { ...init, headers: entetes });
}

const lire = async (c, a) => {
    const r = await requete(c, a);
    return { ok: r.ok, code: r.status };
};
const ecrire = async (c, a, corps, m = "PUT") => {
    const r = await requete(c, a, {
        method: m,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(corps),
    });
    return { ok: r.ok, code: r.status };
};

const A = jeton("userA");   // appelant
const B = jeton("userB");   // appele
const C = jeton("userC");   // tiers

let echecs = 0;
function verifier(intitule, obtenu, attendu) {
    const ok = obtenu.ok === attendu;
    if (!ok) echecs++;
    console.log(
        `  [${ok ? "OK  " : "ECHEC"}] ${intitule}\n` +
        `           attendu: ${attendu ? "autorise" : "refuse"} | ` +
        `obtenu: ${obtenu.ok ? "autorise" : `refuse (${obtenu.code})`}`,
    );
}

const CANDIDAT = { candidate: "candidate:0 1 UDP", sdpMid: "0", sdpMLineIndex: 0 };

(async () => {
    const sonde = await requete("", ADMIN).catch(() => null);
    if (!sonde || !sonde.ok) {
        console.error(`Emulateur injoignable sur ${HOST}. Lancer :\n` +
            "  firebase emulators:start --only database --project diaspo-niger");
        process.exit(2);
    }
    await ecrire("", ADMIN, null);

    console.log("\n=== Parcours reel d'un appel 1:1 ===");
    console.log("    (le noeud RTDB n'a NI callerId NI calleeId : ils sont dans Firestore)\n");

    verifier("l'appelant pose son offre (1re ecriture, noeud vide)",
        await ecrire("calls/REEL/offer", A, { type: "offer", sdp: "v=0" }), true);
    verifier("l'appelant ajoute un candidat ICE",
        await ecrire("calls/REEL/callerCandidates/c1", A, CANDIDAT), true);
    verifier("l'appele LIT l'offre — c'est ca, sonner",
        await lire("calls/REEL/offer", B), true);
    verifier("l'appele ecrit sa reponse",
        await ecrire("calls/REEL/answer", B, { type: "answer", sdp: "v=0" }), true);
    verifier("l'appele ajoute son candidat ICE",
        await ecrire("calls/REEL/calleeCandidates/c1", B, CANDIDAT), true);
    verifier("l'appelant LIT la reponse",
        await lire("calls/REEL/answer", A), true);
    verifier("l'appelant lit les candidats de l'appele",
        await lire("calls/REEL/calleeCandidates", A), true);
    verifier("passage en video",
        await ecrire("calls/REEL/videoUpgrade", A,
            { requestedBy: "userA", status: "pending" }), true);

    console.log("\n=== Etat connu et NON satisfaisant de l'etancheite ===");
    console.log("    Les regles en ligne sont a `auth != null` : tout compte connecte");
    console.log("    peut lire et ecrire la signalisation de n'importe quel appel dont");
    console.log("    il connait l'identifiant. Ces deux lignes ECHOUERONT le jour ou");
    console.log("    l'etancheite sera enfin fermee — c'est voulu, ce sera le signal.\n");
    verifier("un tiers lit l'offre (trou connu)",
        await lire("calls/REEL/offer", C), true);
    verifier("un tiers ecrit dans l'appel (trou connu)",
        await ecrire("calls/REEL/videoUpgrade", C,
            { requestedBy: "userC", status: "pending" }), true);

    console.log(
        "\nPour fermer ce trou sans casser les appels, il faut D'ABORD que l'app\n" +
        "ecrive `callerId`/`calleeId` dans le noeud RTDB. Sans ca, tout predicat\n" +
        "qui s'appuie dessus est toujours faux, et plus rien ne sonne.\n",
    );

    console.log(echecs === 0 ? "TOUT PASSE" : `${echecs} ECHEC(S)`);
    process.exit(echecs === 0 ? 0 : 1);
})();
