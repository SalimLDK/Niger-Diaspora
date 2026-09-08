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
//   3. La Geocoding API de Google, si — et seulement si — une clé est fournie
//      dans le fichier désigné par la variable d'environnement
//      `CLE_GEOCODAGE_FICHIER`. Elle sert à deux choses : situer les postes
//      qu'OSM ignore, et recouper ceux qu'il connaît. Sans clé, le script
//      tourne à l'identique, cette passe en moins.
//
//      La clé du `.env` ne convient pas : les clés Maps du projet sont
//      restreintes aux SDK Android/iOS et à la géolocalisation. Il faut une
//      clé restreinte au seul `geocoding-backend.googleapis.com`, créée pour
//      l'occasion et supprimée ensuite — celle de l'app part dans l'APK, on
//      ne lui ouvre pas un service de plus.
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
const if_ = (condition, valeur) => (condition ? valeur : null);

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
  // Overpass répond parfois une page XML d'erreur (file d'attente pleine).
  // Retenter plutôt que de continuer : une liste OSM vide ne ferait pas
  // échouer le script, elle rendrait juste 19 postes « introuvables ».
  let data;
  for (let essai = 1; ; essai++) {
    const res = await fetch('https://overpass-api.de/api/interpreter', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': UA,
      },
      body: 'data=' + encodeURIComponent(q),
    });
    const corps = await res.text();
    if (corps.startsWith('{')) {
      data = JSON.parse(corps);
      break;
    }
    if (essai >= 3) {
      throw new Error(
        `Overpass n'a pas répondu en JSON après ${essai} essais : ` +
          corps.replace(/\s+/g, ' ').slice(0, 200),
      );
    }
    console.error(`Overpass indisponible (essai ${essai}), nouvelle tentative…`);
    await sleep(10000);
  }
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

const CLE_GOOGLE = (() => {
  const fichier = process.env.CLE_GEOCODAGE_FICHIER;
  if (!fichier) return null;
  try {
    return readFileSync(fichier, 'utf8').trim() || null;
  } catch {
    return null;
  }
})();

/// Types de résultat qui ne désignent qu'une ville ou un pays : Google les
/// renvoie quand il n'a rien compris à la requête. Les accepter reviendrait à
/// écrire un centre-ville en se croyant précis — c'est ce que rend « Embassy
/// of Niger, Khartoum » faute de connaître ce consulat.
const _typesTropVagues = new Set([
  'locality',
  'political',
  'country',
  'administrative_area_level_1',
  'administrative_area_level_2',
  'postal_code',
]);

/// Le nom du poste dans les langues où Google l'a indexé.
///
/// Ce n'est pas un raffinement : c'est ce qui fait la différence entre trouver
/// un poste et ne pas le trouver. Le Caire ne répond qu'à l'arabe
/// (« سفارة النيجر ») — et rend alors l'adresse officielle, 101 Al Haram,
/// c'est-à-dire l'avenue des Pyramides. La Havane ne répond qu'à l'espagnol.
/// L'anglais couvre le reste ; le français, presque rien.
function _requetesNom(poste) {
  const consulat = poste.type === 'consulate';
  const lieu = `${poste.city}, ${poste.country}`;
  return [
    `${consulat ? 'Consulate General of Niger' : 'Embassy of Niger'}, ${lieu}`,
    `${consulat ? 'قنصلية النيجر' : 'سفارة النيجر'}, ${lieu}`,
    `${consulat ? 'Consulado de Níger' : 'Embajada de Níger'}, ${lieu}`,
    `${consulat ? 'Consulat du Niger' : 'Ambassade du Niger'}, ${lieu}`,
  ];
}

async function google(requete) {
  if (!CLE_GOOGLE) return null;
  const cle = `google:${requete}`;
  if (cle in cache) return cache[cle];
  const url =
    'https://maps.googleapis.com/maps/api/geocode/json?language=fr&address=' +
    encodeURIComponent(requete) +
    '&key=' +
    CLE_GOOGLE;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  const premier = data.status === 'OK' ? data.results?.[0] : null;
  const retenu =
      premier &&
      premier.geometry.location_type !== 'APPROXIMATE' &&
      !premier.types.every((t) => _typesTropVagues.has(t))
          ? {
              lat: premier.geometry.location.lat,
              lon: premier.geometry.location.lng,
              libelle: premier.formatted_address,
              precision: premier.geometry.location_type,
              types: premier.types,
            }
          : null;
  cache[cle] = retenu;
  writeFileSync(CACHE, JSON.stringify(cache, null, 1));
  return retenu;
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
  etat.set(poste.id, { poste, ville, osm: null, adresse: null, google: null });
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

// ── Passe 4 : Google, pour ce qu'OSM ignore et pour recouper le reste ───────
// Toutes les requêtes sont posées, puis la meilleure réponse est retenue —
// pas la première. L'ordre naïf (adresse d'abord) plaçait l'ambassade d'Addis
// à 4 km de sa chancellerie : l'adresse officielle (« Kirkos Sub-city,
// Kebele 02/03 ») donne un point quelconque du quartier, là où le nom rend un
// POI de type `embassy`. Un résultat typé `embassy` par Google vaut mieux
// qu'un point sans nature, même « ROOFTOP ».
//
// Deux garde-fous conservés : la ville (60 km) et le type. Un `APPROXIMATE`
// ou une simple « locality » est un repli déguisé — c'est ce que Google rend
// pour Khartoum, faute de connaître ce consulat.
function _noteGoogle(candidat, estAdresse) {
  let note = 0;
  if (candidat.types?.includes('embassy')) note += 100;
  if (estAdresse) note += 40; // on sait exactement ce qu'on a demandé
  if (candidat.precision === 'ROOFTOP') note += 20;
  return note;
}

if (CLE_GOOGLE) {
  for (const e of etat.values()) {
    if (!e.ville) continue;
    const adresse = adresseSansBoitePostale(e.poste.address);
    const requeteAdresse = adresse
      ? `${adresse}, ${e.poste.city}, ${e.poste.country}`
      : null;
    const requetes = [requeteAdresse, ..._requetesNom(e.poste)].filter(Boolean);

    const candidats = [];
    for (const requete of requetes) {
      const trouve = await google(requete);
      if (!trouve) continue;
      const distance = distanceKm(e.ville, trouve);
      if (distance > RAYON_KM) continue;
      // À moins de 300 m du centre-ville : Google a rendu la ville, pas le
      // poste. Deux adresses ne peuvent pas être *aussi* proches du centroïde.
      if (distance < 0.3) continue;
      candidats.push({
        ...trouve,
        requete,
        note: _noteGoogle(trouve, requete === requeteAdresse),
      });
    }
    candidats.sort((a, b) => b.note - a.note);
    e.google = candidats[0] ?? null;
    // Deux réponses Google éloignées l'une de l'autre : la requête par nom a
    // pu tomber sur le poste d'un autre pays. À relire à la main.
    e.googleDesaccord = candidats.length > 1
        ? Number(
            Math.max(...candidats.slice(1).map((c) => distanceKm(candidats[0], c)))
              .toFixed(2),
          )
        : null;
  }
}

// ── Sortie ──────────────────────────────────────────────────────────────────
const resultats = [];
for (const e of etat.values()) {
  // OSM d'abord (relevé au sol, au bâtiment), puis l'adresse officielle
  // géocodée, puis Google.
  const retenu = e.osm ?? e.adresse ?? e.google;
  const ecart = e.osm && e.adresse ? distanceKm(e.osm, e.adresse) : null;
  const ecartGoogle =
    e.google && (e.osm ?? e.adresse)
        ? distanceKm(e.google, e.osm ?? e.adresse)
        : null;
  resultats.push({
    id: e.poste.id,
    slug: e.poste.slug,
    name: e.poste.name,
    type: e.poste.type,
    city: e.poste.city,
    country: e.poste.country,
    address: e.poste.address,
    origine: e.osm ? 'osm' : e.adresse ? 'adresse' : e.google ? 'google' : 'aucune',
    lat: retenu?.lat ?? null,
    lon: retenu?.lon ?? null,
    preuve: e.osm
        ? `${e.osm.nom} (${e.osm.genre}, ${e.osm.osm})`
        : (e.adresse?.libelle ?? e.google?.libelle ?? ''),
    precision: e.osm ? 'osm' : (e.google?.precision ?? 'nominatim'),
    ecartAdresseKm: ecart == null ? null : Number(ecart.toFixed(2)),
    ecartGoogleKm: ecartGoogle == null ? null : Number(ecartGoogle.toFixed(2)),
    googleLibelle: e.google?.libelle ?? '',
    googleTypes: e.google?.types?.slice(0, 3).join(',') ?? '',
    googleRequete: e.google?.requete ?? '',
    googlePrecision: e.google?.precision ?? '',
    googleDesaccordKm: e.googleDesaccord,
  });
}
writeFileSync('coordonnees_postes.json', JSON.stringify(resultats, null, 1));

for (const r of resultats) {
  const pos = r.lat == null ? '—' : `${r.lat.toFixed(5)}, ${r.lon.toFixed(5)}`;
  const ecart = r.ecartAdresseKm == null ? '' : ` [adresse à ${r.ecartAdresseKm} km]`;
  const eg = r.ecartGoogleKm == null ? '' : ` [google à ${r.ecartGoogleKm} km]`;
  console.error(`${r.origine.padEnd(8)} ${pos.padEnd(22)} ${r.name}${ecart}${eg}`);
}
console.error(
  `\nOSM : ${resultats.filter((r) => r.origine === 'osm').length} | ` +
    `adresse : ${resultats.filter((r) => r.origine === 'adresse').length} | ` +
    `google : ${resultats.filter((r) => r.origine === 'google').length} | ` +
    `aucune : ${resultats.filter((r) => r.origine === 'aucune').length}`,
);
