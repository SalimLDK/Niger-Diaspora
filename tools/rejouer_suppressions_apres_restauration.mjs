// Rejoue les suppressions de compte après une restauration de sauvegarde Supabase.
//
// POURQUOI
// Une restauration ramène la base à un instant passé : les comptes supprimés
// depuis y réapparaissent (profil, messages, amitiés, appartenances) alors que
// leur compte Firebase n'existe plus. `account_deletion_requests` est restaurée
// avec le reste et ne peut pas s'en souvenir. La mémoire est donc ailleurs :
// `deleted_accounts/<uid>` dans Firestore, écrit par `finalizeAccountDeletions`
// (functions/index.js) juste AVANT chaque purge. Ce script la relit et rejoue
// les purges (`replay_account_deletion`, idempotente).
//
// À LANCER À LA MAIN APRÈS TOUTE RESTAURATION — c'est une étape de la procédure,
// pas un mécanisme automatique. Tant qu'il n'a pas tourné, les comptes supprimés
// sont visibles des autres.
//
// USAGE
//   cd functions && npm install && cd ..        # une seule fois : firebase-admin
//   export GOOGLE_APPLICATION_CREDENTIALS=<compte de service, accès Firestore et Auth en lecture>
//   node tools/rejouer_suppressions_apres_restauration.mjs            # SIMULATION
//   node tools/rejouer_suppressions_apres_restauration.mjs --apply    # rejoue
//
//   SUPABASE_URL et SUPABASE_SERVICE_KEY sont lus dans l'environnement, à défaut
//   dans functions/.env (mêmes noms que les Cloud Functions).
//
// Options : --apply  rejoue vraiment (sans elle, rien n'est modifié)
//           --max=N  plafond de comptes rejoués d'un coup (défaut 200) : une
//                    restauration en ramène rarement plus, et un chiffre qui
//                    dépasse est un signal à regarder avant d'appuyer.
//
// GARDE-FOUS
//   · Un uid dont le compte Firebase EXISTE encore n'est jamais purgé, quoi que
//     dise Firestore : la pierre tombale se trompe alors, pas Firebase.
//   · Une lecture Firebase qui échoue (autre chose que « introuvable ») saute
//     l'uid : on ne purge pas sur un doute.
//   · Simulation par défaut. Le code de sortie est 1 si un rejeu a échoué.
//   · Un uid n'est rejoué que si la base en montre des restes
//     (`account_deletion_residue`) : un compte déjà propre n'est pas touché.
//
// Ne journalise que des uid opaques et des comptages — jamais un e-mail ni un
// nom.

import { readFileSync, existsSync } from "node:fs";
import { createRequire } from "node:module";

const apply = process.argv.includes("--apply");
const maxArg = process.argv.find((a) => a.startsWith("--max="));
const MAX = maxArg ? Number(maxArg.slice("--max=".length)) : 200;
if (!Number.isInteger(MAX) || MAX < 1) {
    console.error("--max doit être un entier positif.");
    process.exit(2);
}

// ── Configuration : environnement d'abord, functions/.env ensuite.
function lireEnvFichier(chemin) {
    const sortie = {};
    if (!existsSync(chemin)) return sortie;
    for (const ligne of readFileSync(chemin, "utf8").split(/\r?\n/)) {
        const m = ligne.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
        if (!m) continue;
        sortie[m[1]] = m[2].replace(/^(['"])(.*)\1$/, "$2");
    }
    return sortie;
}
const fichier = lireEnvFichier("functions/.env");
const SUPABASE_URL = process.env.SUPABASE_URL || fichier.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || fichier.SUPABASE_SERVICE_KEY;
if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.error("SUPABASE_URL et SUPABASE_SERVICE_KEY sont requis (environnement ou functions/.env).");
    process.exit(2);
}

// ── firebase-admin vit dans functions/node_modules.
let admin;
try {
    admin = createRequire(import.meta.url)("../functions/node_modules/firebase-admin");
} catch {
    console.error("firebase-admin est introuvable : cd functions && npm install");
    process.exit(2);
}
admin.initializeApp({ projectId: "diaspo-niger" });

async function rpc(nom, corps) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nom}`, {
        method: "POST",
        headers: {
            apikey: SUPABASE_SERVICE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify(corps),
    });
    if (!res.ok) throw new Error(`${nom} ${res.status}: ${await res.text()}`);
    return res.json();
}

// ── 1. Les pierres tombales.
const snapshot = await admin.firestore().collection("deleted_accounts").get();
const uids = snapshot.docs.map((d) => d.id);
console.log(`${uids.length} pierre(s) tombale(s) dans Firestore (deleted_accounts).`);
console.log(apply ? "MODE : rejeu (--apply)\n" : "MODE : simulation — rien n'est modifié (ajouter --apply)\n");

// ── 2. Pour chacune : le compte Firebase existe-t-il ? Reste-t-il des données ?
const aRejouer = [];
const ecartes = { firebasePresent: 0, doute: 0, propre: 0 };
for (const uid of uids) {
    try {
        await admin.auth().getUser(uid);
        // Le compte existe : la pierre tombale se trompe, ou l'uid a été réutilisé.
        // Dans les deux cas on ne purge PAS.
        console.warn(`  ${uid}  ÉCARTÉ  le compte Firebase existe encore`);
        ecartes.firebasePresent++;
        continue;
    } catch (e) {
        if (e.code !== "auth/user-not-found") {
            console.warn(`  ${uid}  ÉCARTÉ  lecture Firebase en échec (${e.code}) : on ne purge pas sur un doute`);
            ecartes.doute++;
            continue;
        }
    }

    let residu;
    try {
        residu = await rpc("account_deletion_residue", { p_uid: uid });
    } catch (e) {
        console.warn(`  ${uid}  ÉCARTÉ  ${e.message}`);
        ecartes.doute++;
        continue;
    }
    const total = Object.values(residu).reduce((a, n) => a + Number(n || 0), 0);
    if (total === 0) {
        ecartes.propre++;
        continue;
    }
    console.log(`  ${uid}  À REJOUER  ${JSON.stringify(residu)}`);
    aRejouer.push(uid);
}

console.log(
    `\n${aRejouer.length} à rejouer, ${ecartes.propre} déjà propre(s), ` +
        `${ecartes.firebasePresent} écarté(s) (compte Firebase présent), ${ecartes.doute} écarté(s) sur un doute.`,
);

if (aRejouer.length > MAX) {
    console.error(
        `\n${aRejouer.length} comptes dépassent le plafond de ${MAX} : à regarder avant de rejouer.` +
            ` Relancer avec --max=${aRejouer.length} une fois la liste comprise.`,
    );
    process.exit(3);
}
if (!apply || aRejouer.length === 0) process.exit(0);

// ── 3. Le rejeu.
let echecs = 0;
for (const uid of aRejouer) {
    try {
        const res = await rpc("replay_account_deletion", { p_uid: uid });
        if (res.ok) {
            console.log(`  ${uid}  REJOUÉ  ${JSON.stringify(res.summary || {})}`);
        } else {
            echecs++;
            console.error(`  ${uid}  ÉCHEC  ${JSON.stringify(res)}`);
        }
    } catch (e) {
        echecs++;
        console.error(`  ${uid}  ÉCHEC  ${e.message}`);
    }
}
console.log(echecs === 0 ? "\nRejeu terminé." : `\n${echecs} échec(s) — relancer après lecture des messages.`);
process.exit(echecs === 0 ? 0 : 1);
