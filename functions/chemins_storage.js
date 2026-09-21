/**
 * Chemin Storage tiré d'une URL de téléchargement — refusé s'il sort des
 * préfixes attendus.
 *
 * **Pourquoi ce module existe.** Cinq endroits de `index.js` dérivaient le
 * chemin à supprimer d'une URL lue dans la base, avec un simple
 * `decodeURIComponent(url.match(/o\/(.+?)\?/)[1])`, puis appelaient
 * `bucket.file(chemin).delete()` en **Admin SDK — qui ignore
 * `storage.rules`**. Or ces URL viennent du client :
 *
 *   1. `conversations/$id/participants` est inscriptible dès que le nœud
 *      n'existe pas (`!data.exists()`) : on se fabrique une conversation et
 *      on s'y met ;
 *   2. `messages/$id/$msg` n'exige que `senderId`, `type` et `createdAt` —
 *      `fileUrl` n'est contraint par AUCUN `.validate`, et les champs
 *      inconnus sont acceptés ;
 *   3. on y écrit `fileUrl = ".../o/key_backups%2F<victime>%2Fbackup.enc?…"`
 *      et on appelle `deleteMessageForEveryone`.
 *
 * L'appelant est bien l'expéditeur de son propre message, le délai d'une
 * heure est respecté : tous les contrôles passaient, et le serveur effaçait
 * la sauvegarde d'identité Signal de quelqu'un d'autre. N'importe quel objet
 * du bucket était atteignable ainsi — média, photo de profil, sauvegarde.
 *
 * Le préfixe est la seule barrière possible : le nom d'un objet GCS est une
 * chaîne plate, et rien dans l'URL ne dit à qui appartient le fichier.
 *
 * Ce module est séparé de `index.js` pour être testable sans émulateur ni
 * identifiants : banc `tools/rules_tests/chemin_storage.mjs`.
 */

/**
 * @param {unknown} url l'URL lue dans la base — donnée NON fiable
 * @param {string[]} prefixesAutorises chemins permis, barre finale comprise
 * @param {string} contexte nom de l'appelant, pour le journal
 * @param {{error: Function}} [journal] injectable pour le banc
 * @returns {string|null} le chemin à supprimer, ou `null` pour ne rien faire
 */
function cheminStorageSur(url, prefixesAutorises, contexte, journal = console) {
    if (typeof url !== "string" || url === "") return null;

    const marqueur = url.match(/\/o\/([^?]+)/);
    if (!marqueur) return null;

    let chemin;
    try {
        chemin = decodeURIComponent(marqueur[1]);
    } catch (e) {
        // `%` isolé, séquence tronquée : une URL qu'on ne sait pas lire n'est
        // pas une URL dont on peut supprimer la cible.
        return null;
    }

    // Un nom d'objet GCS est une chaîne plate : `..` n'y traverse rien. On le
    // refuse quand même — la barrière ne doit pas dépendre de ce détail, qui
    // n'est vrai que tant que personne ne normalise le chemin en amont.
    if (chemin === "" || chemin.includes("..")) return null;

    if (prefixesAutorises.some((prefixe) => chemin.startsWith(prefixe))) {
        return chemin;
    }

    // Seul le premier segment est journalisé : il suffit à reconnaître la
    // cible visée (`key_backups`, `profiles`…) sans recopier l'identifiant de
    // la victime. Une seule de ces lignes signale une tentative.
    journal.error(
        `[${contexte}] chemin Storage REFUSÉ — « ${chemin.split("/")[0]}/… » ` +
        `hors des préfixes attendus (${prefixesAutorises.join(", ")})`,
    );
    return null;
}

module.exports = { cheminStorageSur };
