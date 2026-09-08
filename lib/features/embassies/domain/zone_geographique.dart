/// Zone d'affichage de l'annuaire des postes diplomatiques.
///
/// Extrait de `embassies_screen.dart` pour la même raison que
/// [CityFallback] : la règle se teste à froid, alors qu'un écran ne se teste
/// qu'en le rendant. Les trois défauts corrigés ici étaient invisibles à la
/// relecture et ne se voyaient qu'avec de vraies coordonnées en base — ce qui
/// n'est arrivé que le 2026-09-08.
abstract final class ZoneGeographique {
  static const String presDeVous = 'Près de vous';
  static const String europe = 'Europe';
  static const String afrique = 'Afrique';
  static const String ameriqueDuNord = 'Amérique du Nord';
  static const String ameriqueDuSud = 'Amérique du Sud';
  static const String asie = 'Asie';
  static const String oceanie = 'Océanie';

  /// Le poste dont on ignore la position.
  ///
  /// **Une chaîne fixe, jamais une traduction.** L'écran n'affiche que les
  /// zones présentes dans [ordre] (`_zoneOrder.where(grouped.containsKey)`) :
  /// la valeur retournée ici doit donc être *identiquement* celle de la liste.
  /// Elle venait de `l10n.otherConversations`, qui vaut « Autres » en français
  /// mais « Others » en anglais — en anglais, aucun poste sans coordonnées
  /// n'apparaissait dans l'annuaire, et le compteur « 32 ambassade(s)
  /// trouvée(s) » continuait de les compter.
  static const String autres = 'Autres';

  /// Ordre d'affichage des sections.
  static const List<String> ordre = [
    presDeVous,
    europe,
    afrique,
    ameriqueDuNord,
    ameriqueDuSud,
    asie,
    oceanie,
    autres,
  ];

  /// Limite est de l'Afrique à une latitude donnée.
  ///
  /// Sous le 12e parallèle, la corne de l'Afrique s'étend jusqu'au 52e
  /// méridien (Mogadiscio). Au-dessus, la limite suit la mer Rouge, qui court
  /// en diagonale de Bab el-Mandeb (12° N, 43° E) à Suez (30° N, 32,5° E),
  /// puis reste au 32,5e méridien.
  ///
  /// La version précédente prenait 52 à toutes les latitudes : Riyad (24,7° N,
  /// 46,7° E) et Djeddah tombaient donc en Afrique. Une simple coupure
  /// verticale aurait fait l'inverse — Port-Soudan et Asmara en Asie.
  static double _limiteEstAfrique(double lat) {
    if (lat <= 12) return 52;
    if (lat >= 30) return 32.5;
    return 43 - (lat - 12) * (43 - 32.5) / (30 - 12);
  }

  static bool _estAfrique(double lat, double lng) =>
      lat >= -35 && lat < 38 && lng >= -18 && lng <= _limiteEstAfrique(lat);

  /// La zone d'un point. L'ordre des tests est significatif.
  static String pourCoordonnees(double lat, double lng) {
    if (lat >= 5 && lat <= 84 && lng >= -170 && lng <= -50) {
      return ameriqueDuNord;
    }
    if (lat >= -56 && lat < 13 && lng >= -82 && lng <= -34) return ameriqueDuSud;
    // L'Afrique passe AVANT l'Europe : les deux boîtes se chevauchent entre
    // 34° N et 38° N, et l'Europe l'emportait — Alger s'affichait en Europe,
    // et Rabat (34,02° N) l'aurait rejoint dès qu'il aura ses coordonnées.
    if (_estAfrique(lat, lng)) return afrique;
    if (lat >= 34 && lat <= 72 && lng >= -25 && lng < 45) return europe;
    if (lat <= 10 && lng >= 95) return oceanie;
    // Tout ce qui est à l'est de la mer Rouge sans être africain ni européen :
    // la péninsule arabique (Djeddah, Riyad, Koweït, Doha, Dubaï) comme
    // l'Asie proprement dite.
    if (lng >= 32.5) return asie;
    return autres;
  }
}
