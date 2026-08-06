// Test de non-regression des regles RTDB de signalisation d'appel.
//
// POURQUOI CE FICHIER EXISTE
// Le 2026-08-06, un durcissement des regles `calls`/`group_calls` a ete
// deploye puis annule le jour meme, sur un diagnostic FAUX. Ce fichier existe
// pour qu'on ne rejoue plus jamais ce debat sans mesure.
//
// CE QU'IL FAUT SAVOIR AVANT DE TOUCHER AUX REGLES `calls`
// La signalisation vit en Realtime Database, les participants dans Firestore,
// et les regles RTDB ne savent pas interroger Firestore. C'est pourquoi
// `createCall` (call_remote_datasource.dart) ecrit `callerId`/`calleeId` DANS
// le noeud RTDB, avant toute signalisation. Cette ecriture et les regles
// strictes ont ete livrees par le MEME commit (135ae92, 2026-08-03) : elles
// vont ensemble.
//
// Consequence : une regle stricte qui s'appuie sur `data.child('callerId')`
// fonctionne avec le code actuel, mais refuse tout a un client qui n'ecrit pas
// ces champs — un APK anterieur au 2026-08-03. Le mode d'echec est SILENCIEUX :
// l'appele ne voit jamais l'offre, aucune erreur nulle part.
//
// USAGE
//   firebase emulators:start --only database --project diaspo-niger
//   node tools/rules_tests/signalisation_appels.mjs
//
// Le bloc 1 doit passer avec N'IMPORTE QUEL jeu de regles : c'est le parcours
// nominal d'un appel, il n'a pas le droit de casser. Les blocs 2 et 3 ne sont
// pas des verdicts, ils MESURENT — l'etancheite est-elle fermee, et un client
// perime peut-il encore appeler.
//
// PIEGES DEJA PAYES, ne pas les repayer :
//   - `?auth=owner` ne donne PAS les droits admin sur l'emulateur (401).
//     Seul l'en-tete `Authorization: Bearer owner` les donne. Avec le mauvais
//     mode, la mise en place echoue en silence et le banc mesure un arbre vide.
//   - Les candidats ICE ont un `.validate` : candidate + sdpMid + sdpMLineIndex.
//     Une charge utile partielle est refusee par la VALIDATION, pas par le
//     droit d'acces — un 401 ne dit pas lequel des deux a parle.

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
const CAND = { candidate: "candidate:0 1 UDP", sdpMid: "0", sdpMLineIndex: 0 };

let echecs = 0;
function exiger(intitule, obtenu, attendu) {
    const ok = obtenu.ok === attendu;
    if (!ok) echecs++;
    console.log(
        `  [${ok ? "OK  " : "ECHEC"}] ${intitule}\n` +
        `           attendu: ${attendu ? "autorise" : "refuse"} | ` +
        `obtenu: ${obtenu.ok ? "autorise" : `refuse (${obtenu.code})`}`,
    );
}
function constater(intitule, obtenu) {
    console.log(`  [ .  ] ${intitule} : ${obtenu.ok ? "AUTORISE" : `refuse (${obtenu.code})`}`);
    return obtenu.ok;
}

(async () => {
    const sonde = await requete("", ADMIN).catch(() => null);
    if (!sonde || !sonde.ok) {
        console.error(`Emulateur injoignable sur ${HOST}. Lancer :\n` +
            "  firebase emulators:start --only database --project diaspo-niger");
        process.exit(2);
    }
    await ecrire("", ADMIN, null);

    // ------------------------------------------------------------------
    console.log("\n=== 1. Parcours nominal — DOIT passer, quelles que soient les regles ===");
    console.log("    Sequence reelle : createCall ecrit d'abord callerId/calleeId.\n");

    exiger("createCall ecrit callerId/calleeId (noeud vide)",
        await ecrire("calls/OK", A, { callerId: "userA", calleeId: "userB" }, "PATCH"), true);
    exiger("l'appelant pose son offre",
        await ecrire("calls/OK/offer", A, { type: "offer", sdp: "v=0" }), true);
    exiger("l'appelant ajoute un candidat ICE",
        await ecrire("calls/OK/callerCandidates/c1", A, CAND), true);
    exiger("l'appele LIT l'offre — c'est ca, sonner",
        await lire("calls/OK/offer", B), true);
    exiger("l'appele ecrit sa reponse",
        await ecrire("calls/OK/answer", B, { type: "answer", sdp: "v=0" }), true);
    exiger("l'appele ajoute son candidat",
        await ecrire("calls/OK/calleeCandidates/c1", B, CAND), true);
    exiger("l'appelant LIT la reponse",
        await lire("calls/OK/answer", A), true);
    exiger("l'appelant lit les candidats de l'appele",
        await lire("calls/OK/calleeCandidates", A), true);
    exiger("passage en video",
        await ecrire("calls/OK/videoUpgrade", A,
            { requestedBy: "userA", status: "pending" }), true);

    // ------------------------------------------------------------------
    console.log("\n=== 2. Etancheite — mesure, pas verdict ===\n");
    const tiersLit = constater("un tiers lit l'offre", await lire("calls/OK/offer", C));
    const tiersEcrit = constater("un tiers ecrit dans l'appel",
        await ecrire("calls/OK/videoUpgrade", C, { requestedBy: "userC", status: "pending" }));

    // ------------------------------------------------------------------
    console.log("\n=== 3. Client perime — APK anterieur au 2026-08-03 ===");
    console.log("    Il signale sans avoir ecrit callerId/calleeId.\n");
    await ecrire("calls/VIEUX/offer", A, { type: "offer", sdp: "v=0" });
    const perimeCandidat = constater("l'appelant perime ajoute un candidat",
        await ecrire("calls/VIEUX/callerCandidates/c1", A, CAND));
    const perimeLit = constater("l'appele lit l'offre d'un appel perime",
        await lire("calls/VIEUX/offer", B));

    // ------------------------------------------------------------------
    // Les appels de GROUPE ont leur propre piege, distinct du 1:1 :
    //   - `hostId` n'est JAMAIS ecrit dans le noeud RTDB (verifie : aucune
    //     occurrence dans group_call_service.dart). Une regle qui s'appuie
    //     dessus ne peut donc jamais passer par cette branche.
    //   - `_listenForParticipants` est appele AVANT `_registerParticipant`
    //     (group_call_service.dart, lignes 145 puis 157). Le client se met
    //     donc a l'ecoute de `participants` avant d'en etre un.
    console.log("\n=== 4. Appel de groupe — ordre reel de group_call_service ===\n");

    const ecouteAvant = constater(
        "lire participants SANS y etre inscrit",
        await lire("group_calls/GC/participants", A));
    exiger("l'hote s'inscrit comme participant",
        await ecrire("group_calls/GC/participants/userA", A, { joinedAt: 1 }), true);
    exiger("l'hote lit participants apres inscription",
        await lire("group_calls/GC/participants", A), true);
    exiger("un second s'inscrit",
        await ecrire("group_calls/GC/participants/userB", B, { joinedAt: 2 }), true);
    exiger("A envoie son offre a B (signaling/A/B)",
        await ecrire("group_calls/GC/signaling/userA/userB/offer", A,
            { type: "offer", sdp: "v=0" }), true);
    exiger("B lit l'offre de A",
        await lire("group_calls/GC/signaling/userA/userB/offer", B), true);
    exiger("B repond (signaling/B/A)",
        await ecrire("group_calls/GC/signaling/userB/userA/answer", B,
            { type: "answer", sdp: "v=0" }), true);
    constater("un tiers lit la signalisation de A vers B",
        await lire("group_calls/GC/signaling/userA/userB/offer", C));

    // ------------------------------------------------------------------
    console.log("\n--- Verdict ---");
    if (!ecouteAvant) {
        console.log("  Lecture de `participants` reservee aux inscrits : c'est voulu.");
        console.log("  ⚠ Exige que l'app s'inscrive AVANT d'ecouter. Corrige le");
        console.log("    2026-08-06 dans group_call_service.dart, mais un APK");
        console.log("    anterieur ecoute d'abord — sa detection des arrivees");
        console.log("    mourrait en silence. Ne deployer qu'apres un nouveau build.");
    }
    console.log(echecs === 0
        ? "  Parcours nominal : INTACT"
        : `  Parcours nominal : ${echecs} ECHEC(S) — NE PAS DEPLOYER CES REGLES`);
    console.log(`  Etancheite       : ${tiersLit || tiersEcrit ? "OUVERTE (un tiers passe)" : "fermee"}`);
    console.log(`  Client perime    : ${perimeCandidat && perimeLit ? "encore fonctionnel" : "CASSE — verifier le parc installe avant de deployer"}`);
    console.log("");

    process.exit(echecs === 0 ? 0 : 1);
})();
