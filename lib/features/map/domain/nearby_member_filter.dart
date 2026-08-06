import '../../profile/data/models/profile_model.dart';

/// Décide si un membre doit figurer sur la carte « membres autour ».
///
/// Extrait de `MapScreen` pour être vérifiable. La raison est précise : le flux
/// temps réel a deux issues, garder et **retirer**, et celle qui retire ne peut
/// pas se prouver sur appareil sans tenir une scène impossible — carte ouverte
/// et immobile pendant qu'un second compte sort du rayon. Cinq tentatives ont
/// échoué non pas sur le code mais sur le téléphone (écran changé, application
/// tuée par `lmkd`). Le même verdict décidé ici se teste en une milliseconde.
///
/// Les règles sont volontairement au même endroit pour le sondage périodique et
/// pour le temps réel : dupliquées, elles divergeraient, et un membre écarté
/// d'un côté réapparaîtrait de l'autre.
///
/// [maintenant] est un paramètre plutôt qu'un `DateTime.now()` interne : sans
/// ça, les seuils de fraîcheur ne seraient pas testables.
bool membreVisibleSurCarte({
  required ProfileModel membre,
  required double? centreLatitude,
  required double? centreLongitude,
  required double rayonKm,
  required String? paysUtilisateur,
  required String? idUtilisateurCourant,
  required Set<String> idsBloques,
  required Set<String> idsQuiMOntBloque,
  required DateTime maintenant,
}) {
  // Le sondage s'appuie sur la requête SQL, qui filtre déjà `is_visible` et
  // `share_location`. Le flux temps réel, lui, reçoit la ligne brute : ces
  // deux garde-fous doivent être refaits ici, sinon quelqu'un qui vient de
  // couper le partage resterait affiché jusqu'au prochain sondage.
  if (!membre.isVisible || !membre.shareLocation) return false;

  return _dansLePerimetre(
        membre: membre,
        centreLatitude: centreLatitude,
        centreLongitude: centreLongitude,
        rayonKm: rayonKm,
        paysUtilisateur: paysUtilisateur,
      ) &&
      membreAffichable(
        membre: membre,
        idUtilisateurCourant: idUtilisateurCourant,
        idsBloques: idsBloques,
        idsQuiMOntBloque: idsQuiMOntBloque,
        maintenant: maintenant,
      );
}

/// Blocages et présence récente, sans considération de distance.
///
/// Séparé du périmètre parce que le sondage périodique s'en sert seul : la
/// requête SQL a déjà borné géographiquement, il ne reste qu'à filtrer.
bool membreAffichable({
  required ProfileModel membre,
  required String? idUtilisateurCourant,
  required Set<String> idsBloques,
  required Set<String> idsQuiMOntBloque,
  required DateTime maintenant,
}) {
  // Se retirer de ses propres « membres autour » : la requête de proximité
  // renvoie aussi l'utilisateur courant, qui se retrouvait listé à
  // « 0 m · en ligne » et dessiné une seconde fois sur la carte, par-dessus son
  // propre marqueur de position.
  if (idUtilisateurCourant != null && membre.id == idUtilisateurCourant) {
    return false;
  }

  // Utilisateurs bloqués, dans les deux sens.
  //
  // Le second test lisait `membre.blockedByUserIds.contains(moi)`, ce qui
  // signifie « J'AI bloqué ce membre » — le même sens que la ligne au-dessus,
  // pas l'inverse comme le commentaire le prétendait. Et le champ vaut de
  // toute façon toujours `[]`, `_mapProfile` le codant en dur. Deux défauts
  // empilés : mauvaise direction, et donnée absente.
  if (idsBloques.contains(membre.id)) return false;
  if (idsQuiMOntBloque.contains(membre.id)) return false;

  // Présence — STRICT : seulement les membres réellement actifs.
  // 1. En ligne depuis moins d'une heure
  // 2. OU position mise à jour depuis moins de 5 minutes
  if (membre.isOnline &&
      membre.lastSeen != null &&
      maintenant.difference(membre.lastSeen!).inHours < 1) {
    return true;
  }
  if (membre.locationUpdatedAt != null &&
      maintenant.difference(membre.locationUpdatedAt!).inMinutes < 5) {
    return true;
  }
  return false;
}

/// Le membre tombe-t-il dans le périmètre sélectionné ?
///
/// Reprend la même boîte englobante que `getNearbyProfiles`, pour que le temps
/// réel n'affiche pas quelqu'un que le prochain sondage retirerait.
bool _dansLePerimetre({
  required ProfileModel membre,
  required double? centreLatitude,
  required double? centreLongitude,
  required double rayonKm,
  required String? paysUtilisateur,
}) {
  if (centreLatitude == null || centreLongitude == null) return false;
  if (membre.latitude == null || membre.longitude == null) return false;

  if (rayonKm == -1) return true; // monde entier
  if (rayonKm == 0) {
    // « Pays entier » : c'est le pays qui borne, pas la distance.
    return paysUtilisateur == null || membre.currentCountry == paysUtilisateur;
  }

  final delta = rayonKm / 111.0;
  return (membre.latitude! - centreLatitude).abs() <= delta &&
      (membre.longitude! - centreLongitude).abs() <= delta;
}
