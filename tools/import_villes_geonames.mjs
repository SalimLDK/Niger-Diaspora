// Référentiel des villes : import depuis GeoNames.
//
//   node tools/import_villes_geonames.mjs            # écrit en base
//   node tools/import_villes_geonames.mjs --essai    # n'écrit rien, dit tout
//   node tools/import_villes_geonames.mjs --sql villes.sql   # écrit le SQL
//
// Peuple `public.villes` (migration 20260913090000). Ce n'est pas une
// migration : 25 000 lignes font ~3 Mo de SQL, que le dépôt n'a pas à porter.
// Relançable à volonté — tout passe par `ON CONFLICT (geonames_id)`, et rien
// n'est jamais supprimé (une ville qui disparaît de la source reste en base :
// un profil pourrait la désigner).
//
// DEUX SOURCES, PARCE QU'UNE NE SUFFIT PAS
//
//   1. `cities15000` : le monde à partir de 15 000 habitants, plus les
//      capitales. ~25 000 villes, coordonnées et population comprises.
//   2. `NE` (toutes les localités du Niger) filtré sur les 48 villes de
//      `ProfileOptions.nigerRegions`. Parce que `cities15000` ne connaît pas
//      Bouza (~11 000 habitants), qu'un profil existant porte déjà, ni la
//      plupart des chefs-lieux de département. La liste de l'app est lue
//      dans le fichier Dart, jamais recopiée ici : les deux ne peuvent pas
//      diverger.
//
// Licence : GeoNames est en CC-BY. La mention est due dans « À propos ».
//
// LE CODE PAYS NE SERT QU'ICI
// GeoNames désigne le pays par son code ISO-2. Il sert une fois, à trouver
// le nom du pays dans `pays.code_iso_herite`, et n'est pas stocké : la
// colonne `villes.pays` porte le nom en toutes lettres, et sa clé étrangère
// interdit à la base de rattacher une ville à un pays qui n'existe pas. Une
// ville dont le code n'est pas dans `pays` est écartée, et comptée.
//
// CE QUE LE SCRIPT NE SAIT PAS FAIRE
// GeoNames ne dit pas quelle graphie est française. « Londres » est noyé dans
// les 200 noms alternatifs de London, sans étiquette de langue (les langues
// ne sont que dans `alternateNamesV2.zip`, 200 Mo, pour ~70 villes qui nous
// concernent). Les exonymes français sont donc une liste tenue à la main
// ci-dessous, et le script AVERTIT pour chaque entrée qui n'a rien trouvé :
// une liste qui pourrit se voit au lieu de se taire.

import { spawnSync } from 'node:child_process';
import { createWriteStream } from 'node:fs';
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const BASE = 'https://download.geonames.org/export/dump';
const CACHE = join(tmpdir(), 'diaspo-geonames');
const LISTE_DART = 'lib/core/constants/profile_options.dart';

// Décision Salim, 2026-09-13 : une petite ville se rattache à la grande ville
// la plus proche à moins de 40 km. Deux garde-fous avec, mesurés sur les
// 33 866 villes de la source :
//
//   * le FACTEUR empêche deux vraies villes voisines de se manger l'une
//     l'autre — sans lui, La Haye (474 000) devenait une banlieue de
//     Rotterdam (598 000), à 22 km ;
//   * le PLANCHER dit ce qu'est une agglomération. Sans lui, 19 765 villes
//     sur 33 866 — 58 % — étaient rattachées : un bourg de 20 000 habitants
//     à 30 km d'une ville de 60 000 perdait son groupe au profit de sa
//     voisine, ce qui n'est pas une banlieue mais un voisinage. Le plancher
//     réserve le rattachement aux vraies métropoles (Montréal, Paris,
//     Toronto), qui sont le cas que la décision visait.
//
// Ces trois nombres sont des réglages, pas des vérités : `pole_id` est une
// colonne, retouchable ville par ville, et relancer l'import la recalcule.
const RAYON_POLE_KM = 40;
const FACTEUR_POLE = 3;
const POPULATION_POLE_MIN = 200000;

// Les villes de la liste de l'app que le rapprochement par le nom ne trouve
// pas, faute d'une graphie commune. Relevé dans NE.txt le 2026-09-13.
//   Balleyara : GeoNames écrit « Baléyara » (2447223, 21 740 habitants) ;
//               « Balleyara » n'y est que la commune, classe A, population 0.
// « Boboye » n'y figure pas : c'est un département, dont le chef-lieu est
// Birnin Gaouré. Comme « Arewa », qu'un profil porte déjà, la liste de l'app
// mélange départements et villes — à trancher à part, pas ici.
const NIGER_PAR_ID = {
  Balleyara: 2447223,
};

const ALIAS_MAX = 12; // au-delà, on stocke du bruit
const LOT_SQL = 1000; // lignes par appel à `supabase db query`

// Exonymes français, par `<nom plié>|<code ISO>`. Le nom plié est celui de
// `plier_nom_de_pays` (minuscules, sans accent, apostrophes et traits d'union
// en espaces). Une entrée qui ne trouve pas sa ville est signalée en fin de
// course — c'est le seul garde-fou contre une liste qui se périme.
const EXONYMES = {
  'london|GB': 'Londres', 'edinburgh|GB': 'Édimbourg',
  'moscow|RU': 'Moscou', 'saint petersburg|RU': 'Saint-Pétersbourg',
  'beijing|CN': 'Pékin', 'guangzhou|CN': 'Canton',
  'cairo|EG': 'Le Caire', 'alexandria|EG': 'Alexandrie',
  'algiers|DZ': 'Alger', 'oran|DZ': 'Oran', 'constantine|DZ': 'Constantine',
  'brussels|BE': 'Bruxelles', 'antwerp|BE': 'Anvers', 'gent|BE': 'Gand',
  'liege|BE': 'Liège', 'brugge|BE': 'Bruges',
  'geneva|CH': 'Genève', 'basel|CH': 'Bâle', 'bern|CH': 'Berne',
  'zurich|CH': 'Zurich', 'lausanne|CH': 'Lausanne',
  'munchen|DE': 'Munich', 'munich|DE': 'Munich', 'koln|DE': 'Cologne',
  'cologne|DE': 'Cologne', 'frankfurt am main|DE': 'Francfort',
  'hamburg|DE': 'Hambourg', 'nurnberg|DE': 'Nuremberg',
  'aachen|DE': 'Aix-la-Chapelle', 'mainz|DE': 'Mayence',
  'copenhagen|DK': 'Copenhague', 'lisbon|PT': 'Lisbonne',
  'athens|GR': 'Athènes', 'thessaloniki|GR': 'Thessalonique',
  'warsaw|PL': 'Varsovie', 'krakow|PL': 'Cracovie',
  'vienna|AT': 'Vienne', 'wien|AT': 'Vienne',
  'venice|IT': 'Venise', 'venezia|IT': 'Venise', 'firenze|IT': 'Florence',
  'florence|IT': 'Florence', 'napoli|IT': 'Naples', 'naples|IT': 'Naples',
  'milano|IT': 'Milan', 'milan|IT': 'Milan', 'torino|IT': 'Turin',
  'turin|IT': 'Turin', 'genoa|IT': 'Gênes', 'roma|IT': 'Rome',
  'seville|ES': 'Séville', 'sevilla|ES': 'Séville',
  'barcelona|ES': 'Barcelone', 'cordoba|ES': 'Cordoue',
  'bucharest|RO': 'Bucarest', 'kyiv|UA': 'Kiev', 'kiev|UA': 'Kiev',
  's gravenhage|NL': 'La Haye', 'the hague|NL': 'La Haye',
  'new york city|US': 'New York', 'new orleans|US': 'La Nouvelle-Orléans',
  'montreal|CA': 'Montréal', 'quebec|CA': 'Québec', 'quebec city|CA': 'Québec',
  'mexico city|MX': 'Mexico', 'havana|CU': 'La Havane',
  'sao paulo|BR': 'São Paulo',
  'istanbul|TR': 'Istanbul', 'ankara|TR': 'Ankara',
  'makkah|SA': 'La Mecque', 'madinah|SA': 'Médine', 'riyadh|SA': 'Riyad',
  'jeddah|SA': 'Djeddah',
  'dubai|AE': 'Dubaï', 'abu dhabi|AE': 'Abou Dabi',
  'damascus|SY': 'Damas', 'baghdad|IQ': 'Bagdad', 'tehran|IR': 'Téhéran',
  'marrakesh|MA': 'Marrakech', 'fes|MA': 'Fès', 'tangier|MA': 'Tanger',
  'addis ababa|ET': 'Addis-Abeba', 'cape town|ZA': 'Le Cap',
  'tokyo|JP': 'Tokyo', 'seoul|KR': 'Séoul', 'singapore|SG': 'Singapour',
  'new delhi|IN': 'New Delhi', 'mumbai|IN': 'Bombay',
};

const args = process.argv.slice(2);
const ESSAI = args.includes('--essai');
const FICHIER_SQL = (() => {
  const i = args.indexOf('--sql');
  return i >= 0 ? args[i + 1] : null;
})();

/** Même règle que `plier_nom_de_pays` en base et `foldCountryName` dans l'app. */
function plier(texte) {
  const accents = 'ÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇàáâãäåèéêëìíîïòóôõöùúûüç';
  const plats = 'AAAAAAEEEEIIIIOOOOOUUUUCaaaaaaeeeeiiiiooooouuuuc';
  let out = '';
  for (const c of String(texte ?? '')) {
    const i = accents.indexOf(c);
    out += i >= 0 ? plats[i] : c;
  }
  return out
    .toLowerCase()
    .replace(/[’'`-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function distanceKm(aLat, aLon, bLat, bLon) {
  const R = 6371;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(bLat - aLat);
  const dLon = rad(bLon - aLon);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLon / 2) ** 2 * Math.cos(rad(aLat)) * Math.cos(rad(bLat));
  return 2 * R * Math.asin(Math.sqrt(h));
}

function citer(v) {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : 'NULL';
  return `'${String(v).replace(/'/g, "''")}'`;
}

function citerTableau(valeurs) {
  if (!valeurs.length) return "'{}'::text[]";
  return `ARRAY[${valeurs.map(citer).join(',')}]::text[]`;
}

/** `supabase db query --linked`, SQL sur l'entrée standard. */
function sql(requete, { silencieux = false } = {}) {
  const r = spawnSync('supabase', ['db', 'query', '--linked'], {
    input: requete,
    encoding: 'utf8',
    shell: process.platform === 'win32',
    maxBuffer: 64 * 1024 * 1024,
  });
  if (r.error) throw r.error;
  if (r.status !== 0) {
    throw new Error(`supabase db query a échoué (${r.status}) :\n${r.stderr || r.stdout}`);
  }
  if (silencieux) return null;
  const debut = r.stdout.indexOf('{');
  if (debut < 0) return { rows: [] };
  const fin = r.stdout.lastIndexOf('}');
  return JSON.parse(r.stdout.slice(debut, fin + 1));
}

async function existe(chemin) {
  try {
    await stat(chemin);
    return true;
  } catch {
    return false;
  }
}

async function telecharger(nom) {
  const cible = join(CACHE, nom);
  if (await existe(cible)) return cible;
  process.stderr.write(`  téléchargement ${nom}…\n`);
  const reponse = await fetch(`${BASE}/${nom}`);
  if (!reponse.ok) throw new Error(`${BASE}/${nom} : ${reponse.status}`);
  await pipeline(Readable.fromWeb(reponse.body), createWriteStream(cible));
  return cible;
}

/**
 * Extrait un .zip. `tar` lit le zip depuis Windows 10 et sur macOS (bsdtar) ;
 * le tar GNU de Linux, non — d'où le repli sur `unzip`.
 */
async function extraire(zip, attendu) {
  const cible = join(CACHE, attendu);
  if (await existe(cible)) return cible;
  const essais = [
    ['tar', ['-xf', zip, '-C', CACHE]],
    ['unzip', ['-o', '-q', zip, '-d', CACHE]],
  ];
  for (const [cmd, argv] of essais) {
    const r = spawnSync(cmd, argv, { encoding: 'utf8', shell: process.platform === 'win32' });
    if (!r.error && r.status === 0 && (await existe(cible))) return cible;
  }
  throw new Error(`impossible d'extraire ${zip} (ni tar ni unzip) — décompressez-le à la main dans ${CACHE}`);
}

/** Les 48 villes du Niger de l'app, par région, lues dans le fichier Dart. */
async function villesDuNigerSelonLApp() {
  const source = await readFile(LISTE_DART, 'utf8');
  const debut = source.indexOf('nigerRegions');
  if (debut < 0) throw new Error(`${LISTE_DART} : nigerRegions introuvable`);
  const fin = source.indexOf('\n  };', debut);
  const bloc = source.slice(debut, fin);

  const parRegion = new Map();
  let region = null;
  for (const ligne of bloc.split('\n')) {
    const titre = ligne.match(/^\s{4}'(.+?)':\s*\[/);
    if (titre) {
      region = titre[1].replace(/\\'/g, "'");
      parRegion.set(region, []);
      continue;
    }
    const ville = ligne.match(/^\s{6}'(.+?)',/);
    if (ville && region) {
      const nom = ville[1].replace(/\\'/g, "'");
      if (nom !== 'Autre') parRegion.get(region).push(nom);
    }
  }
  const total = [...parRegion.values()].reduce((n, v) => n + v.length, 0);
  if (total < 40) throw new Error(`${LISTE_DART} : ${total} villes lues, la liste en compte ~48 — le format a changé`);
  return parRegion;
}

/** Une ligne du format GeoNames (geoname table dump). */
function lireLigne(ligne) {
  const c = ligne.split('\t');
  return {
    geonamesId: Number(c[0]),
    nom: c[1],
    ascii: c[2],
    alternatifs: c[3] ? c[3].split(',') : [],
    latitude: Number(c[4]),
    longitude: Number(c[5]),
    classe: c[6],
    code: c[7],
    pays: c[8],
    admin1: c[10],
    population: Number(c[14]) || 0,
  };
}

/** Alias de recherche : formes pliées, latines, différentes du nom. */
function aliasPlies(brut, nomPlie) {
  const latin = /^[\p{Script=Latin}\p{M}0-9 ().'’-]+$/u;
  const vus = new Set([nomPlie]);
  const sortie = [];
  for (const a of brut) {
    if (!a || !latin.test(a)) continue;
    const p = plier(a);
    if (!p || p.length < 2 || vus.has(p)) continue;
    vus.add(p);
    sortie.push(p);
    if (sortie.length >= ALIAS_MAX) break;
  }
  return sortie;
}

async function main() {
  await mkdir(CACHE, { recursive: true });

  // 1. Le référentiel des pays fait autorité : la clé étrangère de `villes`
  //    y renvoie. On le lit en base plutôt que de recopier 198 lignes ici.
  process.stderr.write('Lecture de `pays`…\n');
  const pays = sql('SELECT nom, code_iso_herite FROM public.pays;');
  const paysParCode = new Map(pays.rows.map((p) => [p.code_iso_herite, p.nom]));
  process.stderr.write(`  ${paysParCode.size} pays.\n`);

  // 2. Les sources.
  process.stderr.write('Sources GeoNames…\n');
  const [zipMonde, zipNiger, fichierAdmin1] = await Promise.all([
    telecharger('cities15000.zip'),
    telecharger('NE.zip'),
    telecharger('admin1CodesASCII.txt'),
  ]);
  const monde = await extraire(zipMonde, 'cities15000.txt');
  const niger = await extraire(zipNiger, 'NE.txt');

  const regions = new Map();
  for (const ligne of (await readFile(fichierAdmin1, 'utf8')).split('\n')) {
    const c = ligne.split('\t');
    if (c.length >= 2) regions.set(c[0], c[1]);
  }

  // 3. Le monde.
  const villes = new Map(); // geonamesId -> ligne prête
  let horsReferentiel = 0;
  const paysIgnores = new Map();

  for (const ligne of (await readFile(monde, 'utf8')).split('\n')) {
    if (!ligne.trim()) continue;
    const v = lireLigne(ligne);
    const nomPays = paysParCode.get(v.pays);
    if (!nomPays) {
      horsReferentiel++;
      paysIgnores.set(v.pays, (paysIgnores.get(v.pays) ?? 0) + 1);
      continue;
    }
    const exonyme = EXONYMES[`${plier(v.nom)}|${v.pays}`] ?? EXONYMES[`${plier(v.ascii)}|${v.pays}`];
    const nom = exonyme ?? v.nom;
    const nomPlie = plier(nom);
    villes.set(v.geonamesId, {
      geonamesId: v.geonamesId,
      nom,
      nomPlie,
      pays: nomPays,
      codePays: v.pays,
      region: regions.get(`${v.pays}.${v.admin1}`) ?? null,
      latitude: v.latitude,
      longitude: v.longitude,
      population: v.population,
      alias: aliasPlies([v.nom, v.ascii, ...v.alternatifs], nomPlie),
    });
  }
  process.stderr.write(`  cities15000 : ${villes.size} villes retenues, ${horsReferentiel} hors référentiel.\n`);

  // 4. Le Niger, depuis la liste de l'app.
  const nomPaysNiger = paysParCode.get('NE');
  if (!nomPaysNiger) throw new Error('`pays` ne contient pas le code NE');

  const localites = [];
  for (const ligne of (await readFile(niger, 'utf8')).split('\n')) {
    if (!ligne.trim()) continue;
    const v = lireLigne(ligne);
    if (v.classe !== 'P') continue; // localité habitée
    localites.push(v);
  }

  const parRegion = await villesDuNigerSelonLApp();
  const introuvables = [];
  let ajoutsNiger = 0;
  let deja = 0;

  // Le pliage seul ne suffit pas : l'app écrit « Ingall » et « N'Guigmi »,
  // GeoNames « I-n-Gall » et « Nguigmi ». Comparer sans les espaces rattrape
  // les deux. Pas la troisième — d'où la table d'identifiants ci-dessus.
  const compacter = (t) => plier(t).replace(/ /g, '');

  for (const [region, noms] of parRegion) {
    for (const nomApp of noms) {
      const cible = plier(nomApp);
      const cibleCompacte = compacter(nomApp);
      const force = NIGER_PAR_ID[nomApp];
      const candidats = force
        ? localites.filter((v) => v.geonamesId === force)
        : localites.filter(
            (v) =>
              plier(v.nom) === cible ||
              plier(v.ascii) === cible ||
              compacter(v.nom) === cibleCompacte ||
              compacter(v.ascii) === cibleCompacte ||
              v.alternatifs.some((a) => compacter(a) === cibleCompacte),
          );
      if (!candidats.length) {
        introuvables.push(`${nomApp} (${region})`);
        continue;
      }
      candidats.sort((a, b) => b.population - a.population);
      const v = candidats[0];
      // Le nom affiché est celui de l'app — c'est lui que le profil connaît.
      const nomPlie = plier(nomApp);
      const existant = villes.get(v.geonamesId);
      if (existant) deja++;
      else ajoutsNiger++;
      villes.set(v.geonamesId, {
        geonamesId: v.geonamesId,
        nom: nomApp,
        nomPlie,
        pays: nomPaysNiger,
        codePays: 'NE',
        region, // la région de l'app, pas l'admin1 GeoNames
        latitude: v.latitude,
        longitude: v.longitude,
        population: v.population,
        alias: aliasPlies([v.nom, v.ascii, ...v.alternatifs], nomPlie),
      });
    }
  }
  process.stderr.write(
    `  Niger : ${ajoutsNiger} ajoutées, ${deja} déjà dans cities15000, ${introuvables.length} introuvables.\n`,
  );
  if (introuvables.length) {
    process.stderr.write(`  ⚠ sans équivalent GeoNames : ${introuvables.join(', ')}\n`);
  }

  // 5. Les pôles : grille de 0,5° pour ne comparer que les voisines.
  //    40 km valent au plus 0,36° de latitude, donc les 8 cases autour
  //    suffisent. Sans elle, 25 000² comparaisons.
  const toutes = [...villes.values()];
  const grille = new Map();
  const cle = (lat, lon) => `${Math.floor(lat * 2)}|${Math.floor(lon * 2)}`;
  for (const v of toutes) {
    const k = cle(v.latitude, v.longitude);
    if (!grille.has(k)) grille.set(k, []);
    grille.get(k).push(v);
  }

  let poles = 0;
  for (const v of toutes) {
    let meilleur = null;
    let meilleureDistance = Infinity;
    const lat = Math.floor(v.latitude * 2);
    const lon = Math.floor(v.longitude * 2);
    for (let dLat = -1; dLat <= 1; dLat++) {
      for (let dLon = -1; dLon <= 1; dLon++) {
        for (const p of grille.get(`${lat + dLat}|${lon + dLon}`) ?? []) {
          if (p.geonamesId === v.geonamesId) continue;
          if (p.codePays !== v.codePays) continue; // jamais par-dessus une frontière
          if (p.population < POPULATION_POLE_MIN) continue;
          if (p.population < v.population * FACTEUR_POLE) continue;
          const d = distanceKm(v.latitude, v.longitude, p.latitude, p.longitude);
          if (d > RAYON_POLE_KM || d >= meilleureDistance) continue;
          meilleur = p;
          meilleureDistance = d;
        }
      }
    }
    if (meilleur) {
      v.pole = meilleur.geonamesId;
      poles++;
    }
  }

  // Une banlieue de banlieue pointe vers la tête. Le facteur de population
  // interdit déjà les cycles (la population croît strictement) ; la borne
  // n'est là que pour ne jamais boucler sur une donnée retouchée à la main.
  for (const v of toutes) {
    let tete = v.pole;
    for (let i = 0; i < 5 && tete; i++) {
      const suivant = villes.get(tete)?.pole;
      if (!suivant || suivant === v.geonamesId) break;
      tete = suivant;
    }
    v.pole = tete ?? null;
  }
  process.stderr.write(
    `  pôles : ${poles} villes rattachées sur ${toutes.length}` +
      ` (rayon ${RAYON_POLE_KM} km, facteur ${FACTEUR_POLE}, plancher ${POPULATION_POLE_MIN}).\n`,
  );
  // Les plus grosses rattachées : c'est là que le réglage se relit d'un coup
  // d'œil. Si une capitale apparaît ici, c'est que quelque chose cloche.
  const echantillon = toutes
    .filter((v) => v.pole)
    .sort((a, b) => b.population - a.population)
    .slice(0, 8)
    .map((v) => `${v.nom} → ${villes.get(v.pole)?.nom}`);
  process.stderr.write(`  dont : ${echantillon.join(', ')}\n`);

  // 6. Les exonymes qui n'ont trouvé personne. Plusieurs clés visent parfois
  //    le même nom français (`munchen|DE` et `munich|DE`), faute de savoir
  //    quelle graphie GeoNames retient : on n'avertit que si AUCUNE n'a pris.
  const appliques = new Set(toutes.map((v) => `${v.nom}|${v.codePays}`));
  const parCible = new Map();
  for (const [k, fr] of Object.entries(EXONYMES)) {
    const cible = `${fr}|${k.split('|')[1]}`;
    if (!parCible.has(cible)) parCible.set(cible, []);
    parCible.get(cible).push(k);
  }
  const inutiles = [...parCible]
    .filter(([cible]) => !appliques.has(cible))
    .map(([, cles]) => cles.join(' / '));
  if (inutiles.length) {
    process.stderr.write(`  ⚠ exonymes sans ville correspondante : ${inutiles.join(', ')}\n`);
  }

  // 7. Le SQL. Deux passes : les villes, puis les pôles — `pole_id` désigne
  //    un `id` que la base attribue, donc inconnu avant l'insertion.
  const lots = [];
  for (let i = 0; i < toutes.length; i += LOT_SQL) {
    const tranche = toutes.slice(i, i + LOT_SQL);
    const valeurs = tranche
      .map((v) =>
        `(${[
          citer(v.nom),
          citer(v.nomPlie),
          citer(v.pays),
          citer(v.region),
          v.latitude,
          v.longitude,
          v.population,
          v.geonamesId,
          citerTableau(v.alias),
        ].join(',')})`,
      )
      .join(',\n  ');
    lots.push(
      `INSERT INTO public.villes (nom, nom_plie, pays, region, latitude, longitude, population, geonames_id, alias_plies)\nVALUES\n  ${valeurs}\nON CONFLICT (geonames_id) DO UPDATE SET\n  nom = EXCLUDED.nom,\n  nom_plie = EXCLUDED.nom_plie,\n  pays = EXCLUDED.pays,\n  region = EXCLUDED.region,\n  latitude = EXCLUDED.latitude,\n  longitude = EXCLUDED.longitude,\n  population = EXCLUDED.population,\n  alias_plies = EXCLUDED.alias_plies;`,
    );
  }

  const avecPole = toutes.filter((v) => v.pole);
  for (let i = 0; i < avecPole.length; i += LOT_SQL) {
    const tranche = avecPole.slice(i, i + LOT_SQL);
    const paires = tranche.map((v) => `(${v.geonamesId},${v.pole})`).join(',');
    lots.push(
      `UPDATE public.villes v SET pole_id = p.id\n  FROM (VALUES ${paires}) AS m(enfant, parent)\n  JOIN public.villes p ON p.geonames_id = m.parent\n WHERE v.geonames_id = m.enfant AND v.id <> p.id;`,
    );
  }

  process.stderr.write(`\n${toutes.length} villes, ${lots.length} lots de SQL.\n`);

  if (FICHIER_SQL) {
    await writeFile(FICHIER_SQL, lots.join('\n\n') + '\n', 'utf8');
    process.stderr.write(`SQL écrit dans ${FICHIER_SQL}.\n`);
    return;
  }
  if (ESSAI) {
    process.stderr.write('--essai : rien n\'a été écrit en base.\n');
    return;
  }

  let n = 0;
  for (const lot of lots) {
    n++;
    process.stderr.write(`  lot ${n}/${lots.length}…\r`);
    sql(lot, { silencieux: true });
  }
  process.stderr.write(`\nTerminé : ${toutes.length} villes en base.\n`);
}

main().catch((e) => {
  process.stderr.write(`\n${e.message}\n`);
  process.exit(1);
});
