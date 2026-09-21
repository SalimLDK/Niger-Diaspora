// Banc : un chemin Storage tiré d'une URL du client ne sort pas de sa boîte.
//
//   node tools/rules_tests/chemin_storage.mjs
//
// Condition : 0 cas en ÉCHEC.
//
// Ni émulateur, ni réseau, ni identifiants : `functions/chemins_storage.js`
// est une fonction pure. Elle garde les cinq endroits de `functions/index.js`
// qui suppriment un objet Storage en **Admin SDK**, lequel ignore
// `storage.rules` — le durcissement des règles du 2026-09-21 n'y pouvait donc
// rien.
//
// ── L'attaque que ce banc rejoue (cas 1) ──────────────────────────────────
//
//   1. `conversations/<uuid neuf>/participants/<mon uid>` : la règle RTDB
//      l'autorise dès que le nœud n'existe pas (`!data.exists()`) ;
//   2. `messages/<ce uuid>/<msg>` avec `senderId` = soi, `type`, `createdAt`,
//      et `fileUrl` pointant sur la sauvegarde de clés d'AUTRUI — `fileUrl`
//      n'est contraint par aucun `.validate`, et les champs inconnus passent
//      (vérifié dans `database.rules.json` le 2026-09-21) ;
//   3. `deleteMessageForEveryone` : l'appelant EST l'expéditeur, le délai
//      d'une heure EST respecté, donc tous les contrôles passent.
//
// Le serveur effaçait alors l'identité Signal sauvegardée de la victime.
// N'importe quel objet du bucket était atteignable ainsi.
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// Avec l'ancien corps (`decodeURIComponent(url.match(/o\/(.+?)\?/)[1])` rendu
// tel quel, sans contrôle de préfixe), **neuf cas tombent** : 1 à 4 (la
// faille), 9 et 10 (confusion de préfixe), 11 (`..`), 12 (encodage tronqué,
// qui levait au lieu de refuser) et 18 (aucun journal) — mesuré le
// 2026-09-21 en remettant ce corps dans le module, puis en le retirant.
//
// Les cas 5 à 8 passent dans les deux versions : ce sont les
// non-régressions, c'est-à-dire que le ménage légitime marche toujours.
//
// ── Ce que le banc NE couvre PAS ──────────────────────────────────────────
//
// Que les cinq appelants passent les BONS préfixes : ça se lit dans
// `index.js`, ça ne se teste pas ici. Et `deleteConversationForEveryone`,
// qui n'a pas ce défaut-ci mais s'autorise sur un document Firestore que
// l'attaquant peut créer — trou distinct, toujours ouvert.

import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const require_ = createRequire(join(RACINE, "functions", "package.json"));
const { cheminStorageSur } = require_(join(RACINE, "functions", "chemins_storage.js"));

const CONV = "conv-abc";
const VICTIME = "uid-de-la-victime";
const BASE = "https://firebasestorage.googleapis.com/v0/b/diaspo-niger.appspot.com";

/** Les préfixes que passe `deleteMessageForEveryone` pour cette conversation. */
const PREFIXES = [`messages/${CONV}/`, `encrypted_media/${CONV}/`];

/** URL de téléchargement telle que Firebase la fabrique. */
const url = (chemin) => `${BASE}/o/${encodeURIComponent(chemin)}?alt=media&token=x`;

const resultats = [];
const journalMuet = { error: () => {} };

function cas(n, libelle, urlEntree, attendu, prefixes = PREFIXES) {
    let obtenu;
    try {
        obtenu = cheminStorageSur(urlEntree, prefixes, "banc", journalMuet);
    } catch (e) {
        obtenu = `LEVÉE ${String(e).slice(0, 60)}`;
    }
    resultats.push({
        n,
        cas: libelle,
        attendu: attendu === null ? "refusé" : attendu,
        obtenu: obtenu === null ? "refusé" : obtenu,
        verdict: obtenu === attendu ? "OK" : "ÉCHEC",
    });
}

// ═══ 1. L'attaque ══════════════════════════════════════════════════════════
cas(1, "LA FAILLE — la sauvegarde de clés d'autrui",
    url(`key_backups/${VICTIME}/backup.enc`), null);

cas(2, "LA FAILLE — la photo de profil d'autrui",
    url(`profiles/${VICTIME}/photo_1.jpg`), null);

cas(3, "LA FAILLE — le média d'une AUTRE conversation",
    url("messages/conv-de-quelqu-un-dautre/image_1.jpg"), null);

cas(4, "LA FAILLE — le média chiffré d'une autre conversation",
    url("encrypted_media/autre-conv/expediteur/x.enc"), null);

// ═══ 2. Le parcours normal ═════════════════════════════════════════════════
cas(5, "le média de SA conversation",
    url(`messages/${CONV}/image_1758412345678.jpg`), `messages/${CONV}/image_1758412345678.jpg`);

cas(6, "la vignette de SA conversation",
    url(`messages/${CONV}/thumbnail_1.jpg`), `messages/${CONV}/thumbnail_1.jpg`);

cas(7, "le média chiffré de SA conversation",
    url(`encrypted_media/${CONV}/moi/image_1_000001.enc`),
    `encrypted_media/${CONV}/moi/image_1_000001.enc`);

cas(8, "l'image d'un groupe, avec le préfixe de deleteGroup",
    url("groups/g1/image_1.jpg"), "groups/g1/image_1.jpg", ["groups/g1/"]);

// ═══ 3. Confusion de préfixe ═══════════════════════════════════════════════
cas(9, "une conversation dont l'identifiant COMMENCE comme la sienne",
    url(`messages/${CONV}-bis/image_1.jpg`), null);

cas(10, "le même identifiant, sans la barre",
    url(`messages/${CONV}x/image_1.jpg`), null);

// ═══ 4. Entrées malformées ═════════════════════════════════════════════════
cas(11, "remontée par `..`",
    `${BASE}/o/messages%2F${CONV}%2F..%2F..%2Fkey_backups%2F${VICTIME}%2Fbackup.enc?alt=media`, null);

cas(12, "encodage pourcent tronqué", `${BASE}/o/messages%2F%?alt=media`, null);
cas(13, "URL sans marqueur /o/", `${BASE}/messages/${CONV}/x.jpg`, null);
cas(14, "chaîne vide", "", null);
cas(15, "valeur absente", undefined, null);
cas(16, "valeur non textuelle", { chemin: `messages/${CONV}/x.jpg` }, null);
cas(17, "chemin vide après le marqueur", `${BASE}/o/?alt=media`, null);

// ═══ 5. Le journal nomme la cible sans livrer la victime ═══════════════════
{
    const lignes = [];
    cheminStorageSur(
        url(`key_backups/${VICTIME}/backup.enc`),
        PREFIXES,
        "deleteMessageForEveryone",
        { error: (m) => lignes.push(m) },
    );
    const ligne = lignes.join(" ");
    const nomme = ligne.includes("key_backups");
    const discret = !ligne.includes(VICTIME);
    resultats.push({
        n: 18,
        cas: "le refus est journalisé, la cible nommée, la victime non",
        attendu: "key_backups cité, uid absent",
        obtenu: `${nomme ? "cité" : "NON cité"}, uid ${discret ? "absent" : "PRÉSENT"}`,
        verdict: nomme && discret ? "OK" : "ÉCHEC",
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
