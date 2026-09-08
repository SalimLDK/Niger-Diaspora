// Coordonnées des postes diplomatiques : rapprochement OpenStreetMap.
//
// Les 32 fiches de l'annuaire (`public.embassies`) n'ont aucune coordonnée :
// l'annuaire officiel ne publie que des adresses postales, dont huit sont de
// simples boîtes postales. Sans latitude/longitude, la carte saute la fiche
// (`map_screen.dart`, « Skip embassies without valid coordinates ») et le
// bouton « voir sur la carte » du détail reste masqué (`hasCoordinates`).
//
// Ce script ne parle à aucune API payante -- la Geocoding API de Google n'est
// pas activée sur le projet Cloud, et l'activer pour un rattrapage unique de
// 32 lignes serait disproportionné. Il croise deux sources publiques :
//
//   1. Overpass (OpenStreetMap) : les postes diplomatiques du Niger sont
//      cartographiés avec `country=NE`, au bâtiment près. C'est la source
//      la plus précise, et la seule qui situe une chancellerie dont
//      l'annuaire ne donne qu'une boîte postale.
//   2. Nominatim : centre de la ville, qui sert de garde-fou (un candidat
//      OSM à plus de 60 km de sa ville est rejeté) et de repli avoué.
//
// Il n'écrit rien en base : il produit `coordonnees_postes.json` et un tableau
// à relire, d'où la migration a été recopiée
// (`20260908120000_coordonnees_postes_diplomatiques.sql`).
//
//   node tools/geocode_postes_diplomatiques.mjs postes.json
//
// où `postes.json` est le résultat de :
//
//   supabase db query --linked "select json_agg(json_build_object(
//     'id',id,'slug',slug,'name',name,'type',type,'city',city,'country',country,
//     'address',coalesce(address,''))) from embassies;"

import { readFileSync, writeFileSync } from 'node:fs';

const UA = 'diaspo-niger/1.0 (annuaire des postes diplomatiques)';
const RAYON_KM = 60; // au-delà, le candidat n'est pas dans la bonne ville

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Distance à vol d'oiseau, en km. */
function distanceKm(a, b) {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLon = ((b.lon - a.lon) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLon / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** Les postes du Niger cartographiés dans OSM, coordonnées au bâtiment. */
async function chargerOsm() {
  const q = `[out:json][timeout:90];
    (nwr["diplomatic"]["country"="NE"];
     nwr["amenity"="embassy"]["country"="NE"];);
    out center tags;`;
  const res = await fetch('https://overpass-api.de/api/interpreter', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': UA,
    },
    body: 'data=' + encodeURIComponent(q),
  });
  const data = await res.json();
  return (data.elements ?? [])
    .map((e) => ({
      lat: e.lat ?? e.center?.lat,
      lon: e.lon ?? e.center?.lon,
      nom: e.tags?.name ?? '',
      genre: e.tags?.diplomatic ?? e.tags?.amenity ?? '',
      osm: `${e.type}/${e.id}`,
    }))
    .filter((e) => e.lat != null && e.lon != null)
    // Un poste du Nigeria à Djouba porte `country=NE` par erreur de saisie :
    // il ne correspond à aucune de nos villes, mais autant l'écarter ici.
    .filter((e) => !/nigeria/i.test(e.nom))
    // La résidence de l'ambassadeur est son domicile, pas la chancellerie :
    // Addis-Abeba n'a QUE la résidence dans OSM, et l'y envoyer serait pire
    // que de laisser le poste hors carte. Berlin cartographie les deux.
    .filter((e) => !/r[ée]siden[cz]/i.test(e.nom))
    // Un consulat honoraire est tenu par un particulier : il ne figure pas
    // dans l'annuaire officiel, et deux villes turques en ont un.
    .filter((e) => !/honorai|fahri|honorary/i.test(e.nom));
}

// Les réponses de Nominatim sont mises en cache sur disque : le service est
// gratuit et bénévole, et une mise au point du script ne doit pas lui coûter
// soixante requêtes de plus à chaque essai.
const CACHE = 'geocode_cache.json';
let cache = {};
try {
  cache = JSON.parse(readFileSync(CACHE, 'utf8'));
} catch {
  cache = {};
}

async function nominatim(requete) {
  if (requete in cache) return cache[requete];
  const url =
    'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1' +
    '&accept-language=fr&q=' +
    encodeURIComponent(requete);
  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) return null;
  const [premier] = await res.json();
  const trouve = premier
    ? {
        lat: Number(premier.lat),
        lon: Number(premier.lon),
        libelle: premier.display_name,
      }
    : null;
  cache[requete] = trouve;
  writeFileSync(CACHE, JSON.stringify(cache, null, 1));
  return trouve;
}

/** Une boîte postale ne désigne aucun bâtiment : la géocoder est un leurre. */
const estBoitePostale = (adresse) =>
  /(^|[\s,(])(b\.?\s?p\.?|p\.?\s?o\.?\s?box|boite postale)([\s.,:]|$)/i.test(
    adresse,
  );

/** Confiance qu'on accorde à un nœud OSM pour un poste donné.
 *
 * Sert à trancher quand plusieurs postes se disputent la même ville : la
 * meilleure note l'emporte, et le nœud n'est plus disponible pour les autres.
 */
function note(poste, c) {
  let s = 0;
  const nom = c.nom.toLowerCase();
  if (poste.type === 'consulate' && /consul|konsol/.test(nom)) s += 20;
  if (poste.type === 'consulate' && c.genre === 'consulate') s += 10;
  if (
    (poste.type === 'mission' || poste.type === 'delegation') &&
    /mission|permanent|unesco|nations/.test(nom)
  ) {
    s += 20;
  }
  if (poste.type === 'embassy' && /consul|konsol/.test(nom)) s -= 15;
  if (poste.type === 'embassy' && c.genre === 'embassy') s += 10;
  return s - c.distance / 10;
}

/** Retire les fragments « B.P. 352 » d'une adresse : le reste est parfois une
 *  vraie rue (« E 104/3 Independence Avenue, P.O. Box 2685 »). */
function adresseSansBoitePostale(adresse) {
  return adresse
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s && !estBoitePostale(s))
    .join(', ');
}

const postes = JSON.parse(readFileSync(process.argv[2] ?? 'postes.json', 'utf8'));
const osm = await chargerOsm();
console.error(`OSM : ${osm.length} postes du Niger cartographiés\n`);

// ── Passe 1 : ancrer chaque poste sur sa ville ──────────────────────────────
// Le centre-ville ne sert pas de coordonnée : il sert de garde-fou. Un
// candidat OSM ou une adresse géocodée à plus de 60 km n'est pas dans la
// bonne ville, quelle que soit la confiance de la source.
const etat = new Map();
for (const poste of postes) {
  const dejaEnCache = `${poste.city}, ${poste.country}` in cache;
  const ville = await nominatim(`${poste.city}, ${poste.country}`);
  if (!dejaEnCache) await sleep(1100); // politesse Nominatim : 1 requête/s
  etat.set(poste.id, { poste, ville, osm: null, adresse: null });
  if (!ville) console.error(`⚠ ville introuvable : ${poste.city}, ${poste.country}`);
}

// ── Passe 2 : attribuer les nœuds OSM, un poste par nœud ────────────────────
// Paris porte deux postes (l'ambassade et la délégation UNESCO) pour un seul
// nœud OSM. Sans exclusivité, les deux héritaient du même point : la
// délégation se retrouvait rue de Longchamp au lieu de la rue Miollis.
const paires = [];
for (const { poste, ville } of etat.values()) {
  if (!ville) continue;
  for (const c of osm) {
    const distance = distanceKm(ville, c);
    if (distance > RAYON_KM) continue;
    if (/honorai|fahri|honorary/i.test(c.nom)) continue; // tenu par un particulier
    paires.push({ poste, candidat: { ...c, distance }, note: note(poste, { ...c, distance }) });
  }
}
paires.sort((a, b) => b.note - a.note);
const noeudsPris = new Set();
for (const { poste, candidat } of paires) {
  const e = etat.get(poste.id);
  if (e.osm || noeudsPris.has(candidat.osm)) continue;
  e.osm = candidat;
  noeudsPris.add(candidat.osm);
}

// ── Passe 3 : géocoder l'adresse postale ────────────────────────────────────
// Systématiquement, pas seulement en repli : quand les deux sources existent,
// leur écart dit si l'annuaire officiel est encore à jour.
for (const e of etat.values()) {
  const adresse = adresseSansBoitePostale(e.poste.address);
  if (!adresse || !e.ville) continue;
  const requete = `${adresse}, ${e.poste.city}, ${e.poste.country}`;
  const dejaEnCache = requete in cache;
  const trouve = await nominatim(requete);
  if (!dejaEnCache) await sleep(1100);
  if (trouve && distanceKm(e.ville, trouve) <= RAYON_KM) e.adresse = trouve;
}

// ── Sortie ──────────────────────────────────────────────────────────────────
const resultats = [];
for (const e of etat.values()) {
  const retenu = e.osm ?? e.adresse;
  const ecart = e.osm && e.adresse ? distanceKm(e.osm, e.adresse) : null;
  resultats.push({
    id: e.poste.id,
    slug: e.poste.slug,
    name: e.poste.name,
    type: e.poste.type,
    city: e.poste.city,
    country: e.poste.country,
    address: e.poste.address,
    origine: e.osm ? 'osm' : e.adresse ? 'adresse' : 'aucune',
    lat: retenu?.lat ?? null,
    lon: retenu?.lon ?? null,
    preuve: e.osm ? `${e.osm.nom} (${e.osm.genre}, ${e.osm.osm})` : (e.adresse?.libelle ?? ''),
    ecartAdresseKm: ecart == null ? null : Number(ecart.toFixed(2)),
  });
}
writeFileSync('coordonnees_postes.json', JSON.stringify(resultats, null, 1));

for (const r of resultats) {
  const pos = r.lat == null ? '—' : `${r.lat.toFixed(5)}, ${r.lon.toFixed(5)}`;
  const ecart = r.ecartAdresseKm == null ? '' : ` [adresse à ${r.ecartAdresseKm} km]`;
  console.error(`${r.origine.padEnd(8)} ${pos.padEnd(22)} ${r.name}${ecart}`);
}
console.error(
  `\nOSM : ${resultats.filter((r) => r.origine === 'osm').length} | ` +
    `adresse : ${resultats.filter((r) => r.origine === 'adresse').length} | ` +
    `aucune : ${resultats.filter((r) => r.origine === 'aucune').length}`,
);
