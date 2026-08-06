/// Regions for grouping countries
enum Region {
  niger,
  westAfrica,
  africa,
  europe,
  northAmerica,
  middleEast,
  asia,
  other,
}

extension RegionExtension on Region {
  String get label {
    switch (this) {
      case Region.niger:
        return 'Niger';
      case Region.westAfrica:
        return 'Afrique de l\'Ouest';
      case Region.africa:
        return 'Afrique';
      case Region.europe:
        return 'Europe';
      case Region.northAmerica:
        return 'Amerique du Nord';
      case Region.middleEast:
        return 'Moyen-Orient';
      case Region.asia:
        return 'Asie';
      case Region.other:
        return 'Autres';
    }
  }

  String get flag {
    switch (this) {
      case Region.niger:
        return '🇳🇪';
      case Region.westAfrica:
        return '🌍';
      case Region.africa:
        return '🌍';
      case Region.europe:
        return '🇪🇺';
      case Region.northAmerica:
        return '🌎';
      case Region.middleEast:
        return '🌍';
      case Region.asia:
        return '🌏';
      case Region.other:
        return '🌐';
    }
  }
}

/// Countries relevant for Niger diaspora
enum Country {
  // Niger (home country)
  niger,

  // West Africa (neighbors and regional)
  benin,
  burkinaFaso,
  mali,
  nigeria,
  senegal,
  coteDIvoire,
  togo,
  ghana,
  cameroon,

  // North Africa
  algeria,
  libya,
  morocco,
  tunisia,

  // Europe (major diaspora destinations)
  france,
  belgium,
  germany,
  italy,
  spain,
  unitedKingdom,
  switzerland,
  netherlands,

  // North America
  usa,
  canada,

  // Middle East (work destinations)
  saudiArabia,
  uae,
  qatar,

  // Other
  other,
}

extension CountryExtension on Country {
  String get code {
    switch (this) {
      case Country.niger:
        return 'NE';
      case Country.benin:
        return 'BJ';
      case Country.burkinaFaso:
        return 'BF';
      case Country.mali:
        return 'ML';
      case Country.nigeria:
        return 'NG';
      case Country.senegal:
        return 'SN';
      case Country.coteDIvoire:
        return 'CI';
      case Country.togo:
        return 'TG';
      case Country.ghana:
        return 'GH';
      case Country.cameroon:
        return 'CM';
      case Country.algeria:
        return 'DZ';
      case Country.libya:
        return 'LY';
      case Country.morocco:
        return 'MA';
      case Country.tunisia:
        return 'TN';
      case Country.france:
        return 'FR';
      case Country.belgium:
        return 'BE';
      case Country.germany:
        return 'DE';
      case Country.italy:
        return 'IT';
      case Country.spain:
        return 'ES';
      case Country.unitedKingdom:
        return 'GB';
      case Country.switzerland:
        return 'CH';
      case Country.netherlands:
        return 'NL';
      case Country.usa:
        return 'US';
      case Country.canada:
        return 'CA';
      case Country.saudiArabia:
        return 'SA';
      case Country.uae:
        return 'AE';
      case Country.qatar:
        return 'QA';
      case Country.other:
        return 'XX';
    }
  }

  String get label {
    switch (this) {
      case Country.niger:
        return 'Niger';
      case Country.benin:
        return 'Benin';
      case Country.burkinaFaso:
        return 'Burkina Faso';
      case Country.mali:
        return 'Mali';
      case Country.nigeria:
        return 'Nigeria';
      case Country.senegal:
        return 'Senegal';
      case Country.coteDIvoire:
        return 'Cote d\'Ivoire';
      case Country.togo:
        return 'Togo';
      case Country.ghana:
        return 'Ghana';
      case Country.cameroon:
        return 'Cameroun';
      case Country.algeria:
        return 'Algerie';
      case Country.libya:
        return 'Libye';
      case Country.morocco:
        return 'Maroc';
      case Country.tunisia:
        return 'Tunisie';
      case Country.france:
        return 'France';
      case Country.belgium:
        return 'Belgique';
      case Country.germany:
        return 'Allemagne';
      case Country.italy:
        return 'Italie';
      case Country.spain:
        return 'Espagne';
      case Country.unitedKingdom:
        return 'Royaume-Uni';
      case Country.switzerland:
        return 'Suisse';
      case Country.netherlands:
        return 'Pays-Bas';
      case Country.usa:
        return 'Etats-Unis';
      case Country.canada:
        return 'Canada';
      case Country.saudiArabia:
        return 'Arabie Saoudite';
      case Country.uae:
        return 'Emirats Arabes Unis';
      case Country.qatar:
        return 'Qatar';
      case Country.other:
        return 'Autre';
    }
  }

  String get flag {
    switch (this) {
      case Country.niger:
        return '🇳🇪';
      case Country.benin:
        return '🇧🇯';
      case Country.burkinaFaso:
        return '🇧🇫';
      case Country.mali:
        return '🇲🇱';
      case Country.nigeria:
        return '🇳🇬';
      case Country.senegal:
        return '🇸🇳';
      case Country.coteDIvoire:
        return '🇨🇮';
      case Country.togo:
        return '🇹🇬';
      case Country.ghana:
        return '🇬🇭';
      case Country.cameroon:
        return '🇨🇲';
      case Country.algeria:
        return '🇩🇿';
      case Country.libya:
        return '🇱🇾';
      case Country.morocco:
        return '🇲🇦';
      case Country.tunisia:
        return '🇹🇳';
      case Country.france:
        return '🇫🇷';
      case Country.belgium:
        return '🇧🇪';
      case Country.germany:
        return '🇩🇪';
      case Country.italy:
        return '🇮🇹';
      case Country.spain:
        return '🇪🇸';
      case Country.unitedKingdom:
        return '🇬🇧';
      case Country.switzerland:
        return '🇨🇭';
      case Country.netherlands:
        return '🇳🇱';
      case Country.usa:
        return '🇺🇸';
      case Country.canada:
        return '🇨🇦';
      case Country.saudiArabia:
        return '🇸🇦';
      case Country.uae:
        return '🇦🇪';
      case Country.qatar:
        return '🇶🇦';
      case Country.other:
        return '🌐';
    }
  }

  Region get region {
    switch (this) {
      case Country.niger:
        return Region.niger;
      case Country.benin:
      case Country.burkinaFaso:
      case Country.mali:
      case Country.nigeria:
      case Country.senegal:
      case Country.coteDIvoire:
      case Country.togo:
      case Country.ghana:
        return Region.westAfrica;
      case Country.cameroon:
      case Country.algeria:
      case Country.libya:
      case Country.morocco:
      case Country.tunisia:
        return Region.africa;
      case Country.france:
      case Country.belgium:
      case Country.germany:
      case Country.italy:
      case Country.spain:
      case Country.unitedKingdom:
      case Country.switzerland:
      case Country.netherlands:
        return Region.europe;
      case Country.usa:
      case Country.canada:
        return Region.northAmerica;
      case Country.saudiArabia:
      case Country.uae:
      case Country.qatar:
        return Region.middleEast;
      case Country.other:
        return Region.other;
    }
  }

  /// Get display string with flag
  String get displayName => '$flag $label';

  /// Rabat une écriture de pays sur une forme comparable : minuscules, sans
  /// accents, tirets et apostrophes ramenés à des espaces.
  ///
  /// Indispensable, et pas cosmétique : la liste de `create_group_screen`
  /// propose « États-Unis » quand [label] rend « Etats-Unis », et « Côte
  /// d'Ivoire » s'écrit des deux façons selon la source. Une comparaison
  /// stricte échouait donc en silence sur ces pays-là — sans erreur, juste un
  /// pays non reconnu et une valeur brute qui repart en base.
  static String _fold(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp('[àáâãä]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp("[’'`\\-]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Parse country from string (code ISO, nom d'énumération, ou libellé).
  static Country? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final v = _fold(value);

    // Try by code first
    for (final country in Country.values) {
      if (_fold(country.code) == v) {
        return country;
      }
    }

    // Try by name
    for (final country in Country.values) {
      if (_fold(country.name) == v) {
        return country;
      }
    }

    // Try by label : `name` est l'identifiant Dart (`burkinaFaso`), il ne
    // reconnaît donc aucun nom composé tel qu'il s'écrit (« Burkina Faso »,
    // « Côte d'Ivoire »). Or c'est sous cette forme que les pays arrivent du
    // géocodage inverse et des écrans qui listent des libellés en dur.
    for (final country in Country.values) {
      if (_fold(country.label) == v) {
        return country;
      }
    }

    return null;
  }

  /// Code ISO-2 pour une valeur écrite dans n'importe laquelle des trois
  /// formes ci-dessus ; `null` si le pays n'est pas reconnu.
  ///
  /// À utiliser avant toute écriture dans une colonne `country_code` : elles
  /// contenaient un mélange de codes et de libellés (`CA` à côté de `Canada`,
  /// `NE` à côté de `Niger`), si bien que les comparaisons d'égalité
  /// échouaient silencieusement — le filtre par pays de la liste des groupes
  /// ne retenait alors qu'une partie des groupes du pays visé.
  static String? toIsoCode(String? value) => fromString(value)?.code;
}

/// Helper to get countries by region
List<Country> getCountriesByRegion(Region region) {
  return Country.values.where((c) => c.region == region).toList();
}

/// Get all regions that have countries
List<Region> get availableRegions => Region.values;

/// Priority countries shown first in dropdowns
const priorityCountries = [
  Country.niger,
  Country.france,
  Country.usa,
  Country.canada,
  Country.benin,
  Country.coteDIvoire,
  Country.senegal,
  Country.mali,
  Country.burkinaFaso,
];
