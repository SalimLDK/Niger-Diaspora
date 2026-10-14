// Banc des règles RTDB des salons audio : la modération fantôme se décide
// sur le CLAIM `adminRole`, plus sur `/admins`.
//
// POURQUOI CE FICHIER EXISTE
// Six règles d'`audioRooms` accordaient la modération à qui figurait dans
// `/admins/{uid}`, nœud que seul un membre de `/superAdmins` pouvait écrire
// — et `/superAdmins` n'avait AUCUN écrivain dans le dépôt (audit du 14/10,
// § 7.4). Soit la clé avait été posée en console, soit la modération fantôme
// n'a jamais marché. Depuis le 2026-10-14 ces règles lisent
// `auth.token.adminRole`, posé par la Cloud Function `setAdminRole`.
//
// USAGE
//   firebase emulators:start --only database --project diaspo-niger
//   node tools/rules_tests/salons_audio_admin.mjs
//
// Le bloc 1 est le parcours nominal (hôte, participant, admin par claim) :
// condition de déploiement. Le bloc 2 est la fermeture : l'ancien registre
// ne donne plus rien, et personne n'écrit `/admins` ni `/superAdmins`.
//
// PIÈGES DÉJÀ PAYÉS (voir signalisation_appels.mjs) : seul l'en-tête
// `Authorization: Bearer owner` donne les droits admin à la mise en place ;
// `?auth=owner` rend 401. Et un claim se met au PREMIER NIVEAU du jeton,
// à côté de `sub` — pas sous `firebase`.

const HOST = process.env.RTDB_EMULATEUR || "http://127.0.0.1:9102";
const NS = "diaspo-niger-default-rtdb";

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");

/** Jeton d'identité, avec un claim optionnel. L'émulateur ne vérifie pas la signature. */
function jeton(uid, claims = {}) {
    const now = Math.floor(Date.now() / 1000);
    return [
        b64({ alg: "none", kid: "fakekid", typ: "JWT" }),
        b64({
            iss: "https://securetoken.google.com/diaspo-niger",
            aud: "diaspo-niger",
            sub: uid, user_id: uid,
            auth_time: now, iat: now, exp: now + 3600,
            firebase: { identities: {}, sign_in_provider: "password" },
            ...claims,
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

const HOTE = jeton("hote");
const P1 = jeton("participant1");
const TIERS = jeton("tiers");
const MOD = jeton("moderateur", { adminRole: "contentMod" });
const SUPER = jeton("superadmin", { adminRole: "superAdmin" });
const ANCIEN = jeton("ancien_admin");          // dans /admins, SANS claim
const ANCIEN_CLAIM_VIDE = jeton("ancien2", { adminRole: null });

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

const SALON = "audioRooms/R1";
const participant = (id, role) => ({ oderId: id, role, joinedAt: 1 });

async function miseEnPlace() {
    await ecrire("", ADMIN, null);
    await ecrire("admins/ancien_admin", ADMIN, true);
    await ecrire("admins/ancien2", ADMIN, true);
    await ecrire(SALON, ADMIN, {
        hostId: "hote",
        coHostIds: { cohote: true },
        participants: {
            hote: participant("hote", "host"),
            participant1: participant("participant1", "listener"),
            participant2: participant("participant2", "listener"),
        },
        raisedHands: { participant1: true },
        chat: { m1: { senderId: "participant1", content: "salut", createdAt: 1 } },
    });
}

(async () => {
    const sonde = await requete("", ADMIN).catch(() => null);
    if (!sonde || !sonde.ok) {
        console.error(`Emulateur injoignable sur ${HOST}. Lancer :\n` +
            "  firebase emulators:start --only database --project diaspo-niger");
        process.exit(2);
    }
    await miseEnPlace();

    // ------------------------------------------------------------------
    console.log("\n=== 1. Parcours nominal — DOIT passer ===\n");

    exiger("l'hôte modifie son salon",
        await ecrire(`${SALON}/topic`, HOTE, "sujet"), true);
    exiger("un participant écrit son propre nœud",
        await ecrire(`${SALON}/participants/participant1`, P1, participant("participant1", "speaker")), true);
    exiger("un participant lève la main",
        await ecrire(`${SALON}/raisedHands/participant1`, P1, true), true);

    exiger("admin (claim contentMod) retire un participant",
        await ecrire(`${SALON}/participants/participant2`, MOD, null), true);
    exiger("admin (claim contentMod) baisse une main",
        await ecrire(`${SALON}/raisedHands/participant1`, MOD, null), true);
    exiger("admin (claim contentMod) avertit",
        await ecrire(`${SALON}/warnings/w1`, MOD, { message: "calme", timestamp: 1 }), true);
    exiger("admin (claim contentMod) supprime un message du chat",
        await ecrire(`${SALON}/chat/m1`, MOD, null), true);
    exiger("admin (claim contentMod) bloque un compte dans le salon",
        await ecrire(`${SALON}/blockedUserIds/participant1`, MOD, true), true);
    exiger("admin (claim superAdmin) modifie le salon",
        await ecrire(`${SALON}/topic`, SUPER, "sujet 2"), true);

    // ------------------------------------------------------------------
    console.log("\n=== 2. Fermeture — DOIT être refusé ===\n");
    await miseEnPlace();

    exiger("un tiers sans claim n'avertit pas",
        await ecrire(`${SALON}/warnings/w2`, TIERS, { message: "x", timestamp: 1 }), false);
    exiger("un tiers sans claim ne retire pas un participant",
        await ecrire(`${SALON}/participants/participant2`, TIERS, null), false);
    exiger("un tiers sans claim ne bloque personne",
        await ecrire(`${SALON}/blockedUserIds/participant1`, TIERS, true), false);
    exiger("un tiers sans claim ne modifie pas le salon",
        await ecrire(`${SALON}/topic`, TIERS, "pirate"), false);

    exiger("ANCIEN registre : présent dans /admins, SANS claim → n'avertit pas",
        await ecrire(`${SALON}/warnings/w3`, ANCIEN, { message: "x", timestamp: 1 }), false);
    exiger("ANCIEN registre : présent dans /admins, SANS claim → ne retire personne",
        await ecrire(`${SALON}/participants/participant2`, ANCIEN, null), false);
    exiger("claim adminRole: null → rien",
        await ecrire(`${SALON}/warnings/w4`, ANCIEN_CLAIM_VIDE, { message: "x", timestamp: 1 }), false);

    exiger("personne n'écrit /admins, même avec le claim superAdmin",
        await ecrire("admins/superadmin", SUPER, true), false);
    exiger("personne n'écrit /admins pour un autre",
        await ecrire("admins/tiers", SUPER, true), false);
    exiger("un compte lit son propre nœud /admins (inchangé)",
        await lire("admins/ancien_admin", ANCIEN), true);
    exiger("un compte ne lit pas le nœud /admins d'un autre",
        await lire("admins/ancien_admin", TIERS), false);
    exiger("/superAdmins n'existe plus : lecture refusée",
        await lire("superAdmins/superadmin", SUPER), false);
    exiger("/superAdmins n'existe plus : écriture refusée",
        await ecrire("superAdmins/superadmin", SUPER, true), false);

    console.log(`\n${echecs === 0 ? "Salons audio par claim : INTACT" : `${echecs} ECHEC(S)`}`);
    process.exit(echecs === 0 ? 0 : 1);
})();
