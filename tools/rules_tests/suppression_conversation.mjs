// Banc : qui peut supprimer une conversation POUR TOUS.
//
//   node tools/rules_tests/suppression_conversation.mjs
//
// Condition : 0 cas en ÉCHEC.
//
// Ni émulateur, ni réseau, ni identifiants : `functions/autorisations.js` est
// une fonction pure. Elle garde `deleteConversationForEveryone`, qui efface
// **tout `messages/<id>/` du Storage par préfixe** — c'est-à-dire les médias
// des conversations VIVANTES (`message_supabase_datasource.dart:1558,1927`).
//
// ── L'attaque que ce banc rejoue (cas 1) ──────────────────────────────────
//
// La fonction lisait son autorisation dans un document **Firestore**
// `conversations/<id>` : `createdBy` ou `adminIds`. Or la règle déployée dit
//
//   allow create: if isAuthenticated()
//                  && request.auth.uid in request.resource.data.participantIds;
//
// et **plus rien n'alimente ces documents depuis la migration vers Supabase**.
// N'importe qui créait donc `conversations/<id de son choix>` avec lui-même
// en `participantIds` et en `createdBy`, appelait la fonction, et le serveur
// lui confirmait qu'il était le créateur — le document n'était pas une
// preuve, c'était une déclaration de l'attaquant sur lui-même.
//
// Connaître un identifiant de conversation, ce que garde n'importe quel
// ancien membre, suffisait à effacer ses photos, vidéos et notes vocales.
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// Avec l'ancien corps (autorisation lue dans Firestore, sans contrôle de
// participation), **six cas tombent** : 1 (la faille elle-même), 3 (l'ancien
// membre resté dans `adminIds`), 9, 10 et 12 (entrées dégénérées acceptées)
// et 13 (aucun motif exploitable) — mesuré le 2026-09-21.
//
// Le cas 2 passe dans les deux versions : un tiers qui n'est ni créateur ni
// admin était déjà refusé. La faille n'était pas là — elle était dans le fait
// que l'attaquant FABRIQUE le document qui le déclare créateur.
//
// ── Ce que le banc NE couvre PAS ──────────────────────────────────────────
//
// Que `index.js` passe bien la conversation de SUPABASE à cette fonction, et
// non plus le document Firestore : ça se lit dans `deleteConversationForEveryone`,
// ça ne se teste pas ici. Et la suppression elle-même n'est pas jouée.

import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const require_ = createRequire(join(RACINE, "functions", "package.json"));
const { peutSupprimerConversationPourTous } = require_(
    join(RACINE, "functions", "autorisations.js"),
);

const MOI = "uid-attaquant";
const CREATEUR = "uid-createur";
const MEMBRE = "uid-membre";

/** Une conversation telle que `getConversation` la rend depuis Supabase. */
const conv = (extra = {}) => ({
    participantIds: [CREATEUR, MEMBRE],
    createdBy: CREATEUR,
    adminIds: [],
    ...extra,
});

const resultats = [];

function cas(n, libelle, conversation, userId, attendu) {
    let obtenu;
    try {
        obtenu = peutSupprimerConversationPourTous(conversation, userId).autorise;
    } catch (e) {
        obtenu = `LEVÉE ${String(e).slice(0, 60)}`;
    }
    resultats.push({
        n,
        cas: libelle,
        attendu: attendu ? "autorisé" : "refusé",
        obtenu: obtenu === true ? "autorisé" : obtenu === false ? "refusé" : obtenu,
        verdict: obtenu === attendu ? "OK" : "ÉCHEC",
    });
}

// ═══ 1. L'attaque ══════════════════════════════════════════════════════════
// Le document Firestore que l'attaquant fabrique le dit créateur et unique
// participant. Supabase, lui, ne le connaît pas.
cas(1, "LA FAILLE — conversation inconnue de Supabase (document Firestore fabriqué)",
    null, MOI, false);

cas(2, "LA FAILLE — un tiers qui n'est pas participant",
    conv(), MOI, false);

cas(3, "un ancien membre, retiré de la conversation",
    conv({ adminIds: [MOI] }), MOI, false);

// ═══ 2. Le parcours normal ═════════════════════════════════════════════════
cas(4, "le créateur supprime sa conversation",
    conv(), CREATEUR, true);

cas(5, "un administrateur de groupe supprime la conversation",
    conv({ adminIds: [MEMBRE] }), MEMBRE, true);

cas(6, "un participant ordinaire ne supprime pas pour tous",
    conv(), MEMBRE, false);

// ═══ 3. Entrées dégénérées ═════════════════════════════════════════════════
cas(7, "appelant sans identité", conv(), "", false);
cas(8, "appelant absent", conv(), undefined, false);
cas(9, "participantIds absent", conv({ participantIds: undefined }), CREATEUR, false);
cas(10, "participantIds non tabulaire", conv({ participantIds: "tout le monde" }), CREATEUR, false);
cas(11, "adminIds non tabulaire", conv({ adminIds: "moi" }), MEMBRE, false);
cas(12, "createdBy vide, appelant vide", conv({ createdBy: "", participantIds: [""] }), "", false);

// ═══ 4. Le motif du refus est exploitable ══════════════════════════════════
{
    const v = peutSupprimerConversationPourTous(null, MOI);
    resultats.push({
        n: 13,
        cas: "le refus dit POURQUOI, sans livrer la composition",
        attendu: "motif « conversation inconnue », aucun identifiant",
        obtenu: `motif « ${v.motif} »`,
        verdict:
            v.motif === "conversation inconnue" && !v.motif.includes(MOI)
                ? "OK"
                : "ÉCHEC",
    });
}

// ═══ Rapport ═══════════════════════════════════════════════════════════════
for (const r of resultats) {
    console.log(
        `${String(r.n).padStart(2)} ${r.verdict.padEnd(6)} ${r.cas}` +
        (r.verdict === "ÉCHEC"
            ? `\n       attendu: ${r.attendu}\n       obtenu : ${r.obtenu}`
            : ""),
    );
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\nÉCHECS: ${echecs} / ${resultats.length}`);
process.exit(echecs === 0 ? 0 : 1);
