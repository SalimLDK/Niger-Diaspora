// Banc : une amitié n'entre dans `public.friends` que si elle a été consentie.
//
//   node tools/rules_tests/amitie_consentie.mjs
//
// Condition : 0 cas en ÉCHEC.
//
// Ce que ce banc couvre — la décision des deux déclencheurs de
// `functions/index.js` :
//
//   · `onFriendRequestAccepted` : n'écrit QUE sur la transition
//     `pending → accepted`, et écrit les DEUX sens.
//   · `mirrorFriendToSupabase` : reflète toujours un retrait ; ne reflète un
//     ajout que si le sens inverse existe déjà côté Supabase — la seule
//     preuve de consentement qui survive, puisque le client supprime la
//     demande d'ami juste après l'avoir acceptée.
//
// Deux parties, deux natures :
//
//   A. `friendshipExists` contre la PRODUCTION, en LECTURE SEULE. Aucune
//      écriture, aucune donnée personnelle affichée — des booléens.
//   B. la décision des déclencheurs, avec `functions/supabase.js` BOUCHONNÉ :
//      rien ne sort de la machine, et on lit ce que le code AURAIT écrit.
//
// Un banc qui ne sait pas échouer ne prouve rien : en retirant la garde du
// miroir, **B3 seul** tombe — mesuré le 2026-09-21, garde retirée puis
// remise. B4 et B5 passent dans les deux cas : ce sont les non-régressions
// (une amitié consentie est toujours reflétée, un retrait toujours suivi).
//
// PRÉALABLE : `cd functions && npm install`, une seule fois par worktree.
// Sans ce dossier `node_modules` à lui, Node remonte l'arborescence — le
// worktree vit DANS le dépôt principal — et charge le `firebase-functions` de
// la racine (v7, API v2) au lieu du 4.9 de `functions/`. L'erreur ment alors
// complètement : « functions.firestore.document is not a function », sur une
// ligne qu'on n'a pas touchée. Même piège que `.dart_tool` pour Flutter.
//
// Le banc ne déploie rien et ne prouve pas que le déclencheur est en ligne :
// il juge le code du dépôt. Le passage sur appareil reste à faire.

import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const cheminFonctions = path.join(racine, "functions");

const resultats = [];
const noter = (n, cas, attendu, obtenu) =>
    resultats.push({ n, cas, attendu, obtenu, verdict: attendu === obtenu ? "OK" : "ÉCHEC" });

// ── .env des fonctions (clé de service) ────────────────────────────────────
for (const ligne of readFileSync(path.join(cheminFonctions, ".env"), "utf8").split(/\r?\n/)) {
    const m = /^([A-Z0-9_]+)=(.*)$/.exec(ligne.trim());
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}

// ═══ A. La sonde de consentement, contre la production (lecture seule) ═════
const vraiSupabase = require(path.join(cheminFonctions, "supabase.js"));

const url = process.env.SUPABASE_URL;
const cle = process.env.SUPABASE_SERVICE_KEY;
const entetes = { apikey: cle, Authorization: `Bearer ${cle}` };

const reponse = await fetch(`${url}/rest/v1/friends?select=user_id,friend_id&limit=1`, {
    headers: entetes,
});
const paires = reponse.ok ? await reponse.json() : [];

if (paires.length === 0) {
    noter("A1", "une paire réelle à sonder", "trouvée", "AUCUNE (banc sans objet)");
} else {
    const { user_id: a, friend_id: b } = paires[0];
    noter("A1", "une paire réelle à sonder", "trouvée", "trouvée");
    noter("A2", "sonde : la paire existante, dans son sens", true,
        await vraiSupabase.friendshipExists(a, b));
    noter("A3", "sonde : la même paire, sens inverse (les deux sont écrits)", true,
        await vraiSupabase.friendshipExists(b, a));
    noter("A4", "sonde : une paire fabriquée n'existe pas", false,
        await vraiSupabase.friendshipExists(a, "banc-1.2-compte-qui-n-existe-pas"));
    noter("A5", "sonde : deux comptes inconnus", false,
        await vraiSupabase.friendshipExists("banc-1.2-x", "banc-1.2-y"));
}

// ═══ B. La décision des déclencheurs, Supabase bouchonné ═══════════════════
// Le bouchon remplace le module AVANT que `index.js` ne le lise : rien
// n'atteint le réseau, et `ecritures` dit ce que le code aurait écrit.
const ecritures = [];
let inverseExistant = false;

const cheminModule = require.resolve(path.join(cheminFonctions, "supabase.js"));
require.cache[cheminModule] = {
    id: cheminModule,
    filename: cheminModule,
    loaded: true,
    exports: {
        ...vraiSupabase,
        setFriendship: async (userId, friendId, present) => {
            ecritures.push({ userId, friendId, present });
            return true;
        },
        friendshipExists: async () => inverseExistant,
    },
};

process.env.GOOGLE_APPLICATION_CREDENTIALS ??= "";
const index = require(path.join(cheminFonctions, "index.js"));

const evenementDemande = (statutAvant, statutApres) => ({
    before: { data: () => ({ status: statutAvant, senderId: "A", receiverId: "B" }) },
    after: { data: () => ({ status: statutApres, senderId: "A", receiverId: "B" }) },
});
const contexteDemande = { params: { requestId: "r1" } };

const lancer = async (fonction, change, contexte) => {
    ecritures.length = 0;
    await (fonction.run ? fonction.run(change, contexte) : fonction(change, contexte));
    return ecritures.map((e) => `${e.userId}->${e.friendId}:${e.present}`).sort().join(" ");
};

noter("B1", "demande acceptée : les DEUX sens sont écrits",
    "A->B:true B->A:true",
    await lancer(index.onFriendRequestAccepted, evenementDemande("pending", "accepted"), contexteDemande));

noter("B2", "demande refusée : rien n'est écrit", "",
    await lancer(index.onFriendRequestAccepted, evenementDemande("pending", "declined"), contexteDemande));

noter("B2b", "demande déjà acceptée, retouchée : rien n'est écrit", "",
    await lancer(index.onFriendRequestAccepted, evenementDemande("accepted", "accepted"), contexteDemande));

const evenementAmi = (present) => ({
    before: { exists: !present },
    after: { exists: present },
});
const contexteAmi = { params: { userId: "victime", friendId: "attaquant" } };

inverseExistant = false;
noter("B3", "AMITIÉ FORCÉE : ajout sans demande acceptée — ignoré", "",
    await lancer(index.mirrorFriendToSupabase, evenementAmi(true), contexteAmi));

inverseExistant = true;
noter("B4", "ajout adossé à une demande acceptée — reflété",
    "victime->attaquant:true",
    await lancer(index.mirrorFriendToSupabase, evenementAmi(true), contexteAmi));

inverseExistant = false;
noter("B5", "retrait : toujours reflété, sans rien exiger",
    "victime->attaquant:false",
    await lancer(index.mirrorFriendToSupabase, evenementAmi(false), contexteAmi));

// ═══ Rapport ═══════════════════════════════════════════════════════════════
for (const r of resultats) {
    console.log(
        `${String(r.n).padEnd(4)} ${r.verdict.padEnd(6)} ${r.cas}` +
        `\n       attendu: ${JSON.stringify(r.attendu)} | obtenu: ${JSON.stringify(r.obtenu)}`,
    );
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\nÉCHECS: ${echecs} / ${resultats.length}`);
process.exit(echecs === 0 ? 0 : 1);
