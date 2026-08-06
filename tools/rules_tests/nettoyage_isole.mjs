// Garde-fou structurel : chaque etape de `cleanupUserData` doit rester isolee.
//
// POURQUOI
// `cleanupUserData` supprime les donnees d'un compte efface. Ses etapes etaient
// dans un `try` UNIQUE : la premiere qui levait sautait au `catch` final et
// TOUTES les suivantes etaient ignorees, en silence. Le 2026-08-05, une valeur
// `undefined` dans le journal d'audit — ecrit en tete — faisait echouer la
// fonction avant la moindre suppression : supprimer un compte ne supprimait
// rien du tout (8d769d3). Chaque etape passe depuis par le helper
// `etape(nom, travail)` (d07d533).
//
// CE QUE CE FICHIER VERIFIE
// Que personne n'ajoute une etape `// 1.N` hors de son enveloppe. C'est le
// risque reel : le comportement d'un try/catch n'est pas en doute, la
// COUVERTURE l'est. Un test de comportement du helper prouverait dix lignes
// evidentes ; celui-ci prouve que les 17 etapes sont bien dedans.
//
// USAGE
//   node tools/rules_tests/nettoyage_isole.mjs

import { readFileSync } from "node:fs";

// Argument optionnel : permet de pointer une autre version du fichier, ce qui
// sert surtout a verifier que ce banc SAIT ECHOUER. Contre-epreuve :
//   git show 8d769d3:functions/index.js > /tmp/avant.js
//   node tools/rules_tests/nettoyage_isole.mjs /tmp/avant.js   # doit sortir 1
const SOURCE = process.argv[2] || "functions/index.js";
const src = readFileSync(SOURCE, "utf8");

// Bornes de la fonction : de sa declaration au debut de la section RTDB.
const debut = src.indexOf("exports.cleanupUserData");
const finSection = src.indexOf("2. REALTIME DATABASE CLEANUP", debut);
if (debut === -1 || finSection === -1) {
    console.error(`Impossible de delimiter cleanupUserData dans ${SOURCE}.`);
    console.error("Si la fonction a ete renommee ou deplacee, corriger ce banc —");
    console.error("ne pas le supprimer : c'est lui qui garde les 17 etapes isolees.");
    process.exit(2);
}
const corps = src.slice(debut, finSection);

// Chaque etape est annoncee par un commentaire `// 1.N <titre>` et doit etre
// suivie, avant toute autre instruction, d'un `await etape(`.
const etapes = [...corps.matchAll(/^\s*\/\/ (1\.\d+)[^\n]*\n([\s\S]{0,200}?)(?=\n)/gm)];

let manquantes = [];
for (const [, numero, suite] of etapes) {
    if (!/await etape\(/.test(suite)) manquantes.push(numero);
}

const trouvees = etapes.map(([, n]) => n);
const enveloppes = [...corps.matchAll(/await etape\(/g)].length;

console.log(`\ncleanupUserData — ${SOURCE}\n`);
console.log(`  etapes annoncees  : ${trouvees.length} (${trouvees.join(", ")})`);
console.log(`  appels a etape()  : ${enveloppes}`);

if (trouvees.length === 0) {
    console.error("\n  Aucune etape reconnue — le banc ne prouve rien. Le corriger.");
    process.exit(2);
}

if (manquantes.length > 0) {
    console.error(`\n  🔴 HORS ENVELOPPE : ${manquantes.join(", ")}`);
    console.error("     Une etape non isolee peut annuler toutes les suivantes.");
    console.error("     L'entourer de `await etape(\"<nom>\", async () => { … });`.");
    process.exit(1);
}

if (enveloppes < trouvees.length) {
    console.error(`\n  🔴 ${trouvees.length} etapes annoncees mais ${enveloppes} enveloppes.`);
    process.exit(1);
}

console.log("\n  Toutes les etapes sont isolees.\n");
process.exit(0);
