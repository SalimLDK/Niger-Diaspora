/// Options pour les champs du profil utilisateur
library;

class ProfileOptions {
  ProfileOptions._();

  /// Liste des professions disponibles
  static const List<String> professions = [
    'Entrepreneur',
    'Ingenieur',
    'Medecin',
    'Avocat',
    'Enseignant',
    'Etudiant',
    'Commercant',
    'Artiste',
    'Journaliste',
    'Informaticien',
    'Comptable',
    'Banquier',
    'Consultant',
    'Fonctionnaire',
    'Agriculteur',
    'Artisan',
    'Chercheur',
    'Diplomate',
    'Humanitaire',
    'Autre',
  ];

  /// Options de visibilité du numéro de téléphone
  static const String phoneVisibilityEveryone = 'everyone';
  static const String phoneVisibilityFriends = 'friends';
  static const String phoneVisibilityNone = 'none';

  static const Map<String, String> phoneVisibilityOptions = {
    phoneVisibilityEveryone: 'Tout le monde',
    phoneVisibilityFriends: 'Amis uniquement',
    phoneVisibilityNone: 'Personne',
  };

  /// Liste de tous les pays avec leurs drapeaux (emoji)
  static const List<CountryOption> countries = [
    // Pays prioritaires pour la diaspora nigérienne
    CountryOption('Niger', 'NE', '🇳🇪'),
    CountryOption('France', 'FR', '🇫🇷'),
    CountryOption('États-Unis', 'US', '🇺🇸'),
    CountryOption('Canada', 'CA', '🇨🇦'),
    CountryOption('Belgique', 'BE', '🇧🇪'),
    CountryOption('Allemagne', 'DE', '🇩🇪'),
    CountryOption('Royaume-Uni', 'GB', '🇬🇧'),
    CountryOption('Italie', 'IT', '🇮🇹'),
    CountryOption('Espagne', 'ES', '🇪🇸'),
    CountryOption('Suisse', 'CH', '🇨🇭'),
    CountryOption('Maroc', 'MA', '🇲🇦'),
    CountryOption('Sénégal', 'SN', '🇸🇳'),
    CountryOption('Côte d\'Ivoire', 'CI', '🇨🇮'),
    CountryOption('Bénin', 'BJ', '🇧🇯'),
    CountryOption('Togo', 'TG', '🇹🇬'),
    CountryOption('Burkina Faso', 'BF', '🇧🇫'),
    CountryOption('Mali', 'ML', '🇲🇱'),
    CountryOption('Cameroun', 'CM', '🇨🇲'),
    CountryOption('Gabon', 'GA', '🇬🇦'),
    CountryOption('Nigeria', 'NG', '🇳🇬'),

    // Afrique
    CountryOption('Afrique du Sud', 'ZA', '🇿🇦'),
    CountryOption('Algérie', 'DZ', '🇩🇿'),
    CountryOption('Angola', 'AO', '🇦🇴'),
    CountryOption('Botswana', 'BW', '🇧🇼'),
    CountryOption('Burundi', 'BI', '🇧🇮'),
    CountryOption('Cap-Vert', 'CV', '🇨🇻'),
    CountryOption('Centrafrique', 'CF', '🇨🇫'),
    CountryOption('Comores', 'KM', '🇰🇲'),
    CountryOption('Congo', 'CG', '🇨🇬'),
    CountryOption('RD Congo', 'CD', '🇨🇩'),
    CountryOption('Djibouti', 'DJ', '🇩🇯'),
    CountryOption('Égypte', 'EG', '🇪🇬'),
    CountryOption('Érythrée', 'ER', '🇪🇷'),
    CountryOption('Eswatini', 'SZ', '🇸🇿'),
    CountryOption('Éthiopie', 'ET', '🇪🇹'),
    CountryOption('Gambie', 'GM', '🇬🇲'),
    CountryOption('Ghana', 'GH', '🇬🇭'),
    CountryOption('Guinée', 'GN', '🇬🇳'),
    CountryOption('Guinée-Bissau', 'GW', '🇬🇼'),
    CountryOption('Guinée équatoriale', 'GQ', '🇬🇶'),
    CountryOption('Kenya', 'KE', '🇰🇪'),
    CountryOption('Lesotho', 'LS', '🇱🇸'),
    CountryOption('Liberia', 'LR', '🇱🇷'),
    CountryOption('Libye', 'LY', '🇱🇾'),
    CountryOption('Madagascar', 'MG', '🇲🇬'),
    CountryOption('Malawi', 'MW', '🇲🇼'),
    CountryOption('Maurice', 'MU', '🇲🇺'),
    CountryOption('Mauritanie', 'MR', '🇲🇷'),
    CountryOption('Mozambique', 'MZ', '🇲🇿'),
    CountryOption('Namibie', 'NA', '🇳🇦'),
    CountryOption('Ouganda', 'UG', '🇺🇬'),
    CountryOption('Rwanda', 'RW', '🇷🇼'),
    CountryOption('Sao Tomé-et-Principe', 'ST', '🇸🇹'),
    CountryOption('Seychelles', 'SC', '🇸🇨'),
    CountryOption('Sierra Leone', 'SL', '🇸🇱'),
    CountryOption('Somalie', 'SO', '🇸🇴'),
    CountryOption('Soudan', 'SD', '🇸🇩'),
    CountryOption('Soudan du Sud', 'SS', '🇸🇸'),
    CountryOption('Tanzanie', 'TZ', '🇹🇿'),
    CountryOption('Tchad', 'TD', '🇹🇩'),
    CountryOption('Tunisie', 'TN', '🇹🇳'),
    CountryOption('Zambie', 'ZM', '🇿🇲'),
    CountryOption('Zimbabwe', 'ZW', '🇿🇼'),

    // Europe
    CountryOption('Albanie', 'AL', '🇦🇱'),
    CountryOption('Andorre', 'AD', '🇦🇩'),
    CountryOption('Autriche', 'AT', '🇦🇹'),
    CountryOption('Biélorussie', 'BY', '🇧🇾'),
    CountryOption('Bosnie-Herzégovine', 'BA', '🇧🇦'),
    CountryOption('Bulgarie', 'BG', '🇧🇬'),
    CountryOption('Chypre', 'CY', '🇨🇾'),
    CountryOption('Croatie', 'HR', '🇭🇷'),
    CountryOption('Danemark', 'DK', '🇩🇰'),
    CountryOption('Estonie', 'EE', '🇪🇪'),
    CountryOption('Finlande', 'FI', '🇫🇮'),
    CountryOption('Grèce', 'GR', '🇬🇷'),
    CountryOption('Hongrie', 'HU', '🇭🇺'),
    CountryOption('Irlande', 'IE', '🇮🇪'),
    CountryOption('Islande', 'IS', '🇮🇸'),
    CountryOption('Kosovo', 'XK', '🇽🇰'),
    CountryOption('Lettonie', 'LV', '🇱🇻'),
    CountryOption('Liechtenstein', 'LI', '🇱🇮'),
    CountryOption('Lituanie', 'LT', '🇱🇹'),
    CountryOption('Luxembourg', 'LU', '🇱🇺'),
    CountryOption('Macédoine du Nord', 'MK', '🇲🇰'),
    CountryOption('Malte', 'MT', '🇲🇹'),
    CountryOption('Moldavie', 'MD', '🇲🇩'),
    CountryOption('Monaco', 'MC', '🇲🇨'),
    CountryOption('Monténégro', 'ME', '🇲🇪'),
    CountryOption('Norvège', 'NO', '🇳🇴'),
    CountryOption('Pays-Bas', 'NL', '🇳🇱'),
    CountryOption('Pologne', 'PL', '🇵🇱'),
    CountryOption('Portugal', 'PT', '🇵🇹'),
    CountryOption('République tchèque', 'CZ', '🇨🇿'),
    CountryOption('Roumanie', 'RO', '🇷🇴'),
    CountryOption('Russie', 'RU', '🇷🇺'),
    CountryOption('Saint-Marin', 'SM', '🇸🇲'),
    CountryOption('Serbie', 'RS', '🇷🇸'),
    CountryOption('Slovaquie', 'SK', '🇸🇰'),
    CountryOption('Slovénie', 'SI', '🇸🇮'),
    CountryOption('Suède', 'SE', '🇸🇪'),
    CountryOption('Ukraine', 'UA', '🇺🇦'),
    CountryOption('Vatican', 'VA', '🇻🇦'),

    // Amerique du Nord
    CountryOption('Mexique', 'MX', '🇲🇽'),

    // Amerique Centrale et Caraibes
    CountryOption('Antigua-et-Barbuda', 'AG', '🇦🇬'),
    CountryOption('Bahamas', 'BS', '🇧🇸'),
    CountryOption('Barbade', 'BB', '🇧🇧'),
    CountryOption('Belize', 'BZ', '🇧🇿'),
    CountryOption('Costa Rica', 'CR', '🇨🇷'),
    CountryOption('Cuba', 'CU', '🇨🇺'),
    CountryOption('Dominique', 'DM', '🇩🇲'),
    CountryOption('El Salvador', 'SV', '🇸🇻'),
    CountryOption('Grenade', 'GD', '🇬🇩'),
    CountryOption('Guatemala', 'GT', '🇬🇹'),
    CountryOption('Haïti', 'HT', '🇭🇹'),
    CountryOption('Honduras', 'HN', '🇭🇳'),
    CountryOption('Jamaïque', 'JM', '🇯🇲'),
    CountryOption('Nicaragua', 'NI', '🇳🇮'),
    CountryOption('Panama', 'PA', '🇵🇦'),
    CountryOption('République dominicaine', 'DO', '🇩🇴'),
    CountryOption('Saint-Kitts-et-Nevis', 'KN', '🇰🇳'),
    CountryOption('Sainte-Lucie', 'LC', '🇱🇨'),
    CountryOption('Saint-Vincent-et-les-Grenadines', 'VC', '🇻🇨'),
    CountryOption('Trinité-et-Tobago', 'TT', '🇹🇹'),

    // Amerique du Sud
    CountryOption('Argentine', 'AR', '🇦🇷'),
    CountryOption('Bolivie', 'BO', '🇧🇴'),
    CountryOption('Brésil', 'BR', '🇧🇷'),
    CountryOption('Chili', 'CL', '🇨🇱'),
    CountryOption('Colombie', 'CO', '🇨🇴'),
    CountryOption('Équateur', 'EC', '🇪🇨'),
    CountryOption('Guyana', 'GY', '🇬🇾'),
    CountryOption('Paraguay', 'PY', '🇵🇾'),
    CountryOption('Pérou', 'PE', '🇵🇪'),
    CountryOption('Suriname', 'SR', '🇸🇷'),
    CountryOption('Uruguay', 'UY', '🇺🇾'),
    CountryOption('Venezuela', 'VE', '🇻🇪'),

    // Asie
    CountryOption('Afghanistan', 'AF', '🇦🇫'),
    CountryOption('Arabie saoudite', 'SA', '🇸🇦'),
    CountryOption('Arménie', 'AM', '🇦🇲'),
    CountryOption('Azerbaïdjan', 'AZ', '🇦🇿'),
    CountryOption('Bahreïn', 'BH', '🇧🇭'),
    CountryOption('Bangladesh', 'BD', '🇧🇩'),
    CountryOption('Bhoutan', 'BT', '🇧🇹'),
    CountryOption('Brunei', 'BN', '🇧🇳'),
    CountryOption('Cambodge', 'KH', '🇰🇭'),
    CountryOption('Chine', 'CN', '🇨🇳'),
    CountryOption('Corée du Nord', 'KP', '🇰🇵'),
    CountryOption('Corée du Sud', 'KR', '🇰🇷'),
    CountryOption('Émirats arabes unis', 'AE', '🇦🇪'),
    CountryOption('Géorgie', 'GE', '🇬🇪'),
    CountryOption('Inde', 'IN', '🇮🇳'),
    CountryOption('Indonésie', 'ID', '🇮🇩'),
    CountryOption('Irak', 'IQ', '🇮🇶'),
    CountryOption('Iran', 'IR', '🇮🇷'),
    CountryOption('Israël', 'IL', '🇮🇱'),
    CountryOption('Japon', 'JP', '🇯🇵'),
    CountryOption('Jordanie', 'JO', '🇯🇴'),
    CountryOption('Kazakhstan', 'KZ', '🇰🇿'),
    CountryOption('Kirghizistan', 'KG', '🇰🇬'),
    CountryOption('Koweït', 'KW', '🇰🇼'),
    CountryOption('Laos', 'LA', '🇱🇦'),
    CountryOption('Liban', 'LB', '🇱🇧'),
    CountryOption('Malaisie', 'MY', '🇲🇾'),
    CountryOption('Maldives', 'MV', '🇲🇻'),
    CountryOption('Mongolie', 'MN', '🇲🇳'),
    CountryOption('Myanmar', 'MM', '🇲🇲'),
    CountryOption('Népal', 'NP', '🇳🇵'),
    CountryOption('Oman', 'OM', '🇴🇲'),
    CountryOption('Ouzbékistan', 'UZ', '🇺🇿'),
    CountryOption('Pakistan', 'PK', '🇵🇰'),
    CountryOption('Palestine', 'PS', '🇵🇸'),
    CountryOption('Philippines', 'PH', '🇵🇭'),
    CountryOption('Qatar', 'QA', '🇶🇦'),
    CountryOption('Singapour', 'SG', '🇸🇬'),
    CountryOption('Sri Lanka', 'LK', '🇱🇰'),
    CountryOption('Syrie', 'SY', '🇸🇾'),
    CountryOption('Tadjikistan', 'TJ', '🇹🇯'),
    CountryOption('Taïwan', 'TW', '🇹🇼'),
    CountryOption('Thaïlande', 'TH', '🇹🇭'),
    CountryOption('Timor oriental', 'TL', '🇹🇱'),
    CountryOption('Turkménistan', 'TM', '🇹🇲'),
    CountryOption('Turquie', 'TR', '🇹🇷'),
    CountryOption('Vietnam', 'VN', '🇻🇳'),
    CountryOption('Yémen', 'YE', '🇾🇪'),

    // Oceanie
    CountryOption('Australie', 'AU', '🇦🇺'),
    CountryOption('Fidji', 'FJ', '🇫🇯'),
    CountryOption('Kiribati', 'KI', '🇰🇮'),
    CountryOption('Îles Marshall', 'MH', '🇲🇭'),
    CountryOption('Micronésie', 'FM', '🇫🇲'),
    CountryOption('Nauru', 'NR', '🇳🇷'),
    CountryOption('Nouvelle-Zélande', 'NZ', '🇳🇿'),
    CountryOption('Palaos', 'PW', '🇵🇼'),
    CountryOption('Papouasie-Nouvelle-Guinée', 'PG', '🇵🇬'),
    CountryOption('Îles Salomon', 'SB', '🇸🇧'),
    CountryOption('Samoa', 'WS', '🇼🇸'),
    CountryOption('Tonga', 'TO', '🇹🇴'),
    CountryOption('Tuvalu', 'TV', '🇹🇻'),
    CountryOption('Vanuatu', 'VU', '🇻🇺'),
  ];

  /// Le pays désigné par [value], quelle que soit la façon dont il est écrit :
  /// nom avec ou sans accents (« Algerie » = « Algérie »), casse quelconque,
  /// ou **ancien code ISO-2** (« CA »).
  ///
  /// Les codes ne sont reconnus qu'en lecture, pour reprendre ce que la base
  /// et les versions précédentes de l'app ont écrit : on n'en écrit plus
  /// aucun. `null` si le pays n'est pas dans [countries].
  static CountryOption? findCountry(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final plie = foldCountryName(value);
    for (final c in countries) {
      if (foldCountryName(c.name) == plie) return c;
    }
    final code = value.trim().toUpperCase();
    for (final c in countries) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// La forme qu'on écrit en base : le nom de [countries] quand le pays est
  /// reconnu, sinon la saisie telle quelle (mieux vaut la garder que la
  /// perdre), `null` si elle est vide.
  ///
  /// Toute écriture d'une colonne `country_code` passe par ici. La base le
  /// refait de son côté (`pays_canonique`) pour les versions de l'app déjà
  /// installées, qui écrivent encore des codes.
  static String? canonicalCountry(String? value) {
    final trouve = findCountry(value);
    if (trouve != null) return trouve.name;
    final brut = value?.trim();
    return (brut == null || brut.isEmpty) ? null : brut;
  }

  /// Regions du Niger avec leurs principales villes
  static const Map<String, List<String>> nigerRegions = {
    'Agadez': [
      'Agadez',
      'Arlit',
      'Bilma',
      'Tchirozérine',
      'Ingall',
      'Autre',
    ],
    'Diffa': [
      'Diffa',
      'Maine-Soroa',
      'N\'Guigmi',
      'Bosso',
      'Goudoumaria',
      'Autre',
    ],
    'Dosso': [
      'Dosso',
      'Gaya',
      'Doutchi',
      'Loga',
      'Boboye',
      'Tibiri',
      'Falmey',
      'Autre',
    ],
    'Maradi': [
      'Maradi',
      'Tessaoua',
      'Madarounfa',
      'Mayahi',
      'Aguie',
      'Dakoro',
      'Guidan-Roumdji',
      'Gazaoua',
      'Autre',
    ],
    'Niamey': [
      'Niamey',
    ],
    'Tahoua': [
      'Tahoua',
      'Madaoua',
      'Konni',
      'Bouza',
      'Keita',
      'Illéla',
      'Bagaroua',
      'Tchintabaraden',
      'Autre',
    ],
    'Tillaberi': [
      'Tillabéri',
      'Ouallam',
      'Kollo',
      'Say',
      'Téra',
      'Filingué',
      'Balleyara',
      'Autre',
    ],
    'Zinder': [
      'Zinder',
      'Mirriah',
      'Tanout',
      'Magaria',
      'Matameye',
      'Gouré',
      'Damagaram Takaya',
      'Dungass',
      'Autre',
    ],
  };

  /// Liste des regions du Niger
  static List<String> get regions => nigerRegions.keys.toList()..add('Autre');

  /// Obtenir les villes d'une region
  static List<String> getCitiesForRegion(String region) {
    if (region == 'Autre') {
      return ['Autre'];
    }
    return nigerRegions[region] ?? ['Autre'];
  }
}

/// Rabat un nom de pays sur une forme comparable : minuscules, sans accents,
/// tirets et apostrophes ramenés à des espaces.
///
/// La base applique exactement la même règle (`plier_nom_de_pays`) : si l'une
/// change, l'autre doit suivre, sinon l'app et la base cessent de reconnaître
/// les mêmes pays.
String foldCountryName(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àáâãäå]'), 'a')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[òóôõö]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp("[’'`\\-]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Libellé affichable d'un pays : « 🇳🇪 Niger ».
///
/// `users.country_code` et `groups.country_code` portent le **nom** du pays
/// (malgré le nom de la colonne), et plus aucun code ISO depuis le
/// 2026-09-13. Le drapeau vient de [ProfileOptions.findCountry], qui reconnaît
/// aussi les anciennes valeurs. Un pays inconnu s'affiche tel quel, sans
/// drapeau, plutôt que de disparaître.
String countryDisplayLabel(String? country) =>
    ProfileOptions.findCountry(country)?.displayName ?? (country ?? '');

/// Classe représentant un pays avec son drapeau
class CountryOption {
  /// Le nom, tel qu'il s'écrit en base et à l'écran.
  final String name;

  /// Code ISO-2, **jamais écrit en base** : il ne sert qu'à reconnaître les
  /// anciennes valeurs (voir [ProfileOptions.findCountry]) et d'identité à
  /// la liste déroulante.
  final String code;
  final String flag;

  const CountryOption(this.name, this.code, this.flag);

  String get displayName => '$flag $name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryOption &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
