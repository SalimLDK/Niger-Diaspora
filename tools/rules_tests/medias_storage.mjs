// Banc des règles Firebase Storage : on dépose, on ne réécrit pas.
//
//   firebase emulators:start --only storage --project diaspo-niger
//   cd test/rules && npm install     # une seule fois par worktree
//   node tools/rules_tests/medias_storage.mjs
//
// Condition : 0 cas en ÉCHEC.
//
// Le banc tourne contre l'ÉMULATEUR, jamais contre le bucket de production :
// il dépose des fichiers, tente de les réécrire, de les supprimer. Il lit
// `storage.rules` du dépôt — le fichier même que `firebase deploy --only
// storage` enverrait.
//
// ── Ce que ce banc a trouvé, et qui justifie son existence ─────────────────
//
// `allow create` NE refuse PAS la réécriture, contrairement à ce que son nom
// laisse croire. Mesuré ici le 2026-09-21, par une sonde à règles en ligne :
// avec `allow create: if true` — et même en ajoutant `allow update: if false`
// — un second dépôt sur le MÊME chemin est accepté. Seul `resource == null`
// le refuse (`resource` est l'objet déjà en place ; `request.resource` celui
// qu'on dépose). La première version de ces règles utilisait `create` et
// n'aurait rien fermé du tout : les cas 3 à 6 l'ont dit tout de suite.
//
// ── Isolation entre deux passages ─────────────────────────────────────────
//
// L'émulateur GARDE son contenu d'un lancement à l'autre, et `clearStorage()`
// ne l'a pas vidé ici. Sans isolation, le deuxième passage voyait les chemins
// du premier déjà occupés : les dépôts neufs devenaient des réécritures, donc
// refusés — ce qui ressemble à une régression alors que c'est le banc qui
// n'est pas rejouable. D'où l'empreinte `RUN` dans chaque chemin.
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// Avec les règles d'avant (`allow write: if isAuthenticated() && …`,
// `allow read: if true`, `isImage()` en `image/.*`), **six cas tombent** :
// 4, 5, 6 et 7 (la réécriture passait), 10 (le SVG passait) et 12
// (l'énumération d'une publication passait) — mesuré le 2026-09-21 en
// rejouant le banc sur la version sauvegardée, puis en la restaurant.
//
// Le 13 (énumérer une conversation) passait déjà : `list: if false` était
// posé sur `/messages` seul. C'est une non-régression, pas un acquis du jour.
//
// ── Ce que le banc NE couvre PAS ──────────────────────────────────────────
//
// Le ménage côté serveur. `deleteMessageForEveryone` supprime en Admin SDK,
// qui ignore ces règles, et dérive son chemin d'une URL fournie par le client :
// trou distinct, toujours ouvert. Voir
// docs/deploiement/AUDIT_PRE_PROD_2026-09-20.md, §1.4.
//
// PIÈGE DÉJÀ PAYÉ : `@firebase/rules-unit-testing` vit dans
// `test/rules/node_modules`, hors du dépôt (voir test/rules/package.json), et
// un import ESM n'honore pas `NODE_PATH`. Même détour que
// `acceptation_ami.mjs` : un `require` ancré sur ce package.json.

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
        "Dépendance absente. Lancer d'abord :\n  cd test/rules && npm install\n",
    );
    process.exit(2);
}
const { initializeTestEnvironment, assertSucceeds, assertFails } = rut;
const { ref, uploadBytes, getBytes, deleteObject, listAll } =
    require_("firebase/storage");

const PROJET = "diaspo-niger";
const HOTE = "127.0.0.1";
const PORT = 9199;

const ALICE = "alice-banc-storage";
const MALLORY = "mallory-banc-storage";

/// Empreinte de ce passage : voir « Isolation » en tête.
const RUN = Date.now().toString(36);

const CONV = `messages/conv-${RUN}`;
const POST = `posts/post-${RUN}`;
const COMMERCE = `businesses/b-${RUN}`;
const PROFIL = `profiles/${ALICE}`;
const SAUVEGARDE = `key_backups/${ALICE}`;

const octets = (n = 32) => new Uint8Array(n).fill(65);
const jpeg = { contentType: "image/jpeg" };

const resultats = [];

/** Joue une attente et la note. `attendu` vaut "accepté" ou "refusé". */
async function cas(n, libelle, attendu, action) {
    try {
        await (attendu === "accepté"
            ? assertSucceeds(action())
            : assertFails(action()));
        resultats.push({ n, cas: libelle, verdict: "OK", detail: attendu });
    } catch (e) {
        resultats.push({
            n,
            cas: libelle,
            verdict: "ÉCHEC",
            detail: `attendu ${attendu} — ${String(e).slice(0, 120)}`,
        });
    }
}

const env = await initializeTestEnvironment({
    projectId: PROJET,
    storage: {
        rules: readFileSync(join(RACINE, "storage.rules"), "utf8"),
        host: HOTE,
        port: PORT,
    },
});

const alice = env.authenticatedContext(ALICE).storage();
const mallory = env.authenticatedContext(MALLORY).storage();
const anonyme = env.unauthenticatedContext().storage();

// ═══ 1. Le parcours normal : déposer un média ══════════════════════════════
await cas(1, "déposer une image dans une conversation", "accepté", () =>
    uploadBytes(ref(alice, `${CONV}/image_111.jpg`), octets(), jpeg));

await cas(2, "déposer l'image d'une publication", "accepté", () =>
    uploadBytes(ref(alice, `${POST}/image_111.jpg`), octets(), jpeg));

await cas(3, "déposer une vidéo dans une publication", "accepté", () =>
    uploadBytes(ref(alice, `${POST}/video_1.mp4`), octets(), {
        contentType: "video/mp4",
    }));

// ═══ 2. LA FAILLE : remplacer le fichier d'un autre ════════════════════════
await cas(4, "LA FAILLE — un tiers réécrit le média d'une conversation", "refusé", () =>
    uploadBytes(ref(mallory, `${CONV}/image_111.jpg`), octets(), jpeg));

await cas(5, "LA FAILLE — un tiers réécrit l'image d'une publication", "refusé", () =>
    uploadBytes(ref(mallory, `${POST}/image_111.jpg`), octets(), jpeg));

await cas(6, "LA FAILLE — un tiers réécrit la photo d'un commerce", "refusé", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
        uploadBytes(ref(ctx.storage(), `${COMMERCE}/image_1.jpg`), octets(), jpeg));
    return uploadBytes(ref(mallory, `${COMMERCE}/image_1.jpg`), octets(), jpeg);
});

await cas(7, "même l'auteur ne réécrit pas son propre dépôt", "refusé", () =>
    uploadBytes(ref(alice, `${CONV}/image_111.jpg`), octets(), jpeg));

// ═══ 3. Suppression : refusée à tout le monde ══════════════════════════════
await cas(8, "un tiers supprime un média", "refusé", () =>
    deleteObject(ref(mallory, `${CONV}/image_111.jpg`)));

await cas(9, "l'auteur supprime son propre média", "refusé", () =>
    deleteObject(ref(alice, `${CONV}/image_111.jpg`)));

// ═══ 4. Type de fichier ════════════════════════════════════════════════════
await cas(10, "déposer un SVG (document exécutable)", "refusé", () =>
    uploadBytes(ref(alice, `${POST}/piege.svg`), octets(), {
        contentType: "image/svg+xml",
    }));

await cas(11, "déposer un exécutable déguisé en image", "refusé", () =>
    uploadBytes(ref(alice, `${POST}/piege.jpg`), octets(), {
        contentType: "application/x-msdownload",
    }));

// ═══ 5. Énumération ════════════════════════════════════════════════════════
await cas(12, "énumérer le dossier d'une publication", "refusé", () =>
    listAll(ref(anonyme, POST)));

await cas(13, "énumérer le dossier d'une conversation", "refusé", () =>
    listAll(ref(alice, CONV)));

await cas(14, "lire un média public par son chemin exact", "accepté", () =>
    getBytes(ref(anonyme, `${POST}/image_111.jpg`)));

// ═══ 6. Chemins réservés au propriétaire ═══════════════════════════════════
await cas(15, "un tiers écrit dans le dossier profil d'un autre", "refusé", () =>
    uploadBytes(ref(mallory, `${PROFIL}/photo_${RUN}.jpg`), octets(), jpeg));

await cas(16, "l'intéressée écrit dans son dossier profil", "accepté", () =>
    uploadBytes(ref(alice, `${PROFIL}/photo_${RUN}.jpg`), octets(), jpeg));

await cas(17, "un tiers LIT la sauvegarde de clés d'un autre", "refusé", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
        uploadBytes(ref(ctx.storage(), `${SAUVEGARDE}/backup-${RUN}.enc`), octets(), {
            contentType: "application/json",
        }));
    return getBytes(ref(mallory, `${SAUVEGARDE}/backup-${RUN}.enc`));
});

await cas(18, "un tiers SUPPRIME la sauvegarde de clés d'un autre", "refusé", () =>
    deleteObject(ref(mallory, `${SAUVEGARDE}/backup-${RUN}.enc`)));

await cas(19, "l'intéressée relit sa sauvegarde de clés", "accepté", () =>
    getBytes(ref(alice, `${SAUVEGARDE}/backup-${RUN}.enc`)));

await cas(20, "l'intéressée remplace sa sauvegarde de clés", "accepté", () =>
    uploadBytes(ref(alice, `${SAUVEGARDE}/backup-${RUN}.enc`), octets(), {
        contentType: "application/json",
    }));

// ═══ 7. Le refus par défaut ════════════════════════════════════════════════
await cas(21, "déposer dans un chemin non prévu", "refusé", () =>
    uploadBytes(ref(alice, `chemin/inconnu-${RUN}/fichier.jpg`), octets(), jpeg));

await cas(22, "un anonyme dépose un média", "refusé", () =>
    uploadBytes(ref(anonyme, `${POST}/anonyme.jpg`), octets(), jpeg));

// ═══ Rapport ═══════════════════════════════════════════════════════════════
await env.cleanup();

for (const r of resultats) {
    console.log(
        `${String(r.n).padStart(2)} ${r.verdict.padEnd(6)} ${r.cas}` +
        (r.verdict === "ÉCHEC" ? `\n       ${r.detail}` : ` (${r.detail})`),
    );
}
const echecs = resultats.filter((r) => r.verdict === "ÉCHEC").length;
console.log(`\nÉCHECS: ${echecs} / ${resultats.length}`);
process.exit(echecs === 0 ? 0 : 1);
