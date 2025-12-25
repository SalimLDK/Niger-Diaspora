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
    CountryOption('Etats-Unis', 'US', '🇺🇸'),
    CountryOption('Canada', 'CA', '🇨🇦'),
    CountryOption('Belgique', 'BE', '🇧🇪'),
    CountryOption('Allemagne', 'DE', '🇩🇪'),
    CountryOption('Royaume-Uni', 'GB', '🇬🇧'),
    CountryOption('Italie', 'IT', '🇮🇹'),
    CountryOption('Espagne', 'ES', '🇪🇸'),
    CountryOption('Suisse', 'CH', '🇨🇭'),
    CountryOption('Maroc', 'MA', '🇲🇦'),
    CountryOption('Senegal', 'SN', '🇸🇳'),
    CountryOption('Cote d\'Ivoire', 'CI', '🇨🇮'),
    CountryOption('Benin', 'BJ', '🇧🇯'),
    CountryOption('Togo', 'TG', '🇹🇬'),
    CountryOption('Burkina Faso', 'BF', '🇧🇫'),
    CountryOption('Mali', 'ML', '🇲🇱'),
    CountryOption('Cameroun', 'CM', '🇨🇲'),
    CountryOption('Gabon', 'GA', '🇬🇦'),
    CountryOption('Nigeria', 'NG', '🇳🇬'),

    // Afrique
    CountryOption('Afrique du Sud', 'ZA', '🇿🇦'),
    CountryOption('Algerie', 'DZ', '🇩🇿'),
    CountryOption('Angola', 'AO', '🇦🇴'),
    CountryOption('Botswana', 'BW', '🇧🇼'),
    CountryOption('Burundi', 'BI', '🇧🇮'),
    CountryOption('Cap-Vert', 'CV', '🇨🇻'),
    CountryOption('Centrafrique', 'CF', '🇨🇫'),
    CountryOption('Comores', 'KM', '🇰🇲'),
    CountryOption('Congo', 'CG', '🇨🇬'),
    CountryOption('RD Congo', 'CD', '🇨🇩'),
    CountryOption('Djibouti', 'DJ', '🇩🇯'),
    CountryOption('Egypte', 'EG', '🇪🇬'),
    CountryOption('Erythree', 'ER', '🇪🇷'),
    CountryOption('Eswatini', 'SZ', '🇸🇿'),
    CountryOption('Ethiopie', 'ET', '🇪🇹'),
    CountryOption('Gambie', 'GM', '🇬🇲'),
    CountryOption('Ghana', 'GH', '🇬🇭'),
    CountryOption('Guinee', 'GN', '🇬🇳'),
    CountryOption('Guinee-Bissau', 'GW', '🇬🇼'),
    CountryOption('Guinee equatoriale', 'GQ', '🇬🇶'),
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
    CountryOption('Sao Tome-et-Principe', 'ST', '🇸🇹'),
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
    CountryOption('Bielorussie', 'BY', '🇧🇾'),
    CountryOption('Bosnie-Herzegovine', 'BA', '🇧🇦'),
    CountryOption('Bulgarie', 'BG', '🇧🇬'),
    CountryOption('Chypre', 'CY', '🇨🇾'),
    CountryOption('Croatie', 'HR', '🇭🇷'),
    CountryOption('Danemark', 'DK', '🇩🇰'),
    CountryOption('Estonie', 'EE', '🇪🇪'),
    CountryOption('Finlande', 'FI', '🇫🇮'),
    CountryOption('Grece', 'GR', '🇬🇷'),
    CountryOption('Hongrie', 'HU', '🇭🇺'),
    CountryOption('Irlande', 'IE', '🇮🇪'),
    CountryOption('Islande', 'IS', '🇮🇸'),
    CountryOption('Kosovo', 'XK', '🇽🇰'),
    CountryOption('Lettonie', 'LV', '🇱🇻'),
    CountryOption('Liechtenstein', 'LI', '🇱🇮'),
    CountryOption('Lituanie', 'LT', '🇱🇹'),
    CountryOption('Luxembourg', 'LU', '🇱🇺'),
    CountryOption('Macedoine du Nord', 'MK', '🇲🇰'),
    CountryOption('Malte', 'MT', '🇲🇹'),
    CountryOption('Moldavie', 'MD', '🇲🇩'),
    CountryOption('Monaco', 'MC', '🇲🇨'),
    CountryOption('Montenegro', 'ME', '🇲🇪'),
    CountryOption('Norvege', 'NO', '🇳🇴'),
    CountryOption('Pays-Bas', 'NL', '🇳🇱'),
    CountryOption('Pologne', 'PL', '🇵🇱'),
    CountryOption('Portugal', 'PT', '🇵🇹'),
    CountryOption('Republique tcheque', 'CZ', '🇨🇿'),
    CountryOption('Roumanie', 'RO', '🇷🇴'),
    CountryOption('Russie', 'RU', '🇷🇺'),
    CountryOption('Saint-Marin', 'SM', '🇸🇲'),
    CountryOption('Serbie', 'RS', '🇷🇸'),
    CountryOption('Slovaquie', 'SK', '🇸🇰'),
    CountryOption('Slovenie', 'SI', '🇸🇮'),
    CountryOption('Suede', 'SE', '🇸🇪'),
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
    CountryOption('Haiti', 'HT', '🇭🇹'),
    CountryOption('Honduras', 'HN', '🇭🇳'),
    CountryOption('Jamaique', 'JM', '🇯🇲'),
    CountryOption('Nicaragua', 'NI', '🇳🇮'),
    CountryOption('Panama', 'PA', '🇵🇦'),
    CountryOption('Republique dominicaine', 'DO', '🇩🇴'),
    CountryOption('Saint-Kitts-et-Nevis', 'KN', '🇰🇳'),
    CountryOption('Sainte-Lucie', 'LC', '🇱🇨'),
    CountryOption('Saint-Vincent-et-les-Grenadines', 'VC', '🇻🇨'),
    CountryOption('Trinite-et-Tobago', 'TT', '🇹🇹'),

    // Amerique du Sud
    CountryOption('Argentine', 'AR', '🇦🇷'),
    CountryOption('Bolivie', 'BO', '🇧🇴'),
    CountryOption('Bresil', 'BR', '🇧🇷'),
    CountryOption('Chili', 'CL', '🇨🇱'),
    CountryOption('Colombie', 'CO', '🇨🇴'),
    CountryOption('Equateur', 'EC', '🇪🇨'),
    CountryOption('Guyana', 'GY', '🇬🇾'),
    CountryOption('Paraguay', 'PY', '🇵🇾'),
    CountryOption('Perou', 'PE', '🇵🇪'),
    CountryOption('Suriname', 'SR', '🇸🇷'),
    CountryOption('Uruguay', 'UY', '🇺🇾'),
    CountryOption('Venezuela', 'VE', '🇻🇪'),

    // Asie
    CountryOption('Afghanistan', 'AF', '🇦🇫'),
    CountryOption('Arabie saoudite', 'SA', '🇸🇦'),
    CountryOption('Armenie', 'AM', '🇦🇲'),
    CountryOption('Azerbaidjan', 'AZ', '🇦🇿'),
    CountryOption('Bahrein', 'BH', '🇧🇭'),
    CountryOption('Bangladesh', 'BD', '🇧🇩'),
    CountryOption('Bhoutan', 'BT', '🇧🇹'),
    CountryOption('Brunei', 'BN', '🇧🇳'),
    CountryOption('Cambodge', 'KH', '🇰🇭'),
    CountryOption('Chine', 'CN', '🇨🇳'),
    CountryOption('Coree du Nord', 'KP', '🇰🇵'),
    CountryOption('Coree du Sud', 'KR', '🇰🇷'),
    CountryOption('Emirats arabes unis', 'AE', '🇦🇪'),
    CountryOption('Georgie', 'GE', '🇬🇪'),
    CountryOption('Inde', 'IN', '🇮🇳'),
    CountryOption('Indonesie', 'ID', '🇮🇩'),
    CountryOption('Irak', 'IQ', '🇮🇶'),
    CountryOption('Iran', 'IR', '🇮🇷'),
    CountryOption('Israel', 'IL', '🇮🇱'),
    CountryOption('Japon', 'JP', '🇯🇵'),
    CountryOption('Jordanie', 'JO', '🇯🇴'),
    CountryOption('Kazakhstan', 'KZ', '🇰🇿'),
    CountryOption('Kirghizistan', 'KG', '🇰🇬'),
    CountryOption('Koweit', 'KW', '🇰🇼'),
    CountryOption('Laos', 'LA', '🇱🇦'),
    CountryOption('Liban', 'LB', '🇱🇧'),
    CountryOption('Malaisie', 'MY', '🇲🇾'),
    CountryOption('Maldives', 'MV', '🇲🇻'),
    CountryOption('Mongolie', 'MN', '🇲🇳'),
    CountryOption('Myanmar', 'MM', '🇲🇲'),
    CountryOption('Nepal', 'NP', '🇳🇵'),
    CountryOption('Oman', 'OM', '🇴🇲'),
    CountryOption('Ouzbekistan', 'UZ', '🇺🇿'),
    CountryOption('Pakistan', 'PK', '🇵🇰'),
    CountryOption('Palestine', 'PS', '🇵🇸'),
    CountryOption('Philippines', 'PH', '🇵🇭'),
    CountryOption('Qatar', 'QA', '🇶🇦'),
    CountryOption('Singapour', 'SG', '🇸🇬'),
    CountryOption('Sri Lanka', 'LK', '🇱🇰'),
    CountryOption('Syrie', 'SY', '🇸🇾'),
    CountryOption('Tadjikistan', 'TJ', '🇹🇯'),
    CountryOption('Taiwan', 'TW', '🇹🇼'),
    CountryOption('Thailande', 'TH', '🇹🇭'),
    CountryOption('Timor oriental', 'TL', '🇹🇱'),
    CountryOption('Turkmenistan', 'TM', '🇹🇲'),
    CountryOption('Turquie', 'TR', '🇹🇷'),
    CountryOption('Vietnam', 'VN', '🇻🇳'),
    CountryOption('Yemen', 'YE', '🇾🇪'),

    // Oceanie
    CountryOption('Australie', 'AU', '🇦🇺'),
    CountryOption('Fidji', 'FJ', '🇫🇯'),
    CountryOption('Kiribati', 'KI', '🇰🇮'),
    CountryOption('Iles Marshall', 'MH', '🇲🇭'),
    CountryOption('Micronesie', 'FM', '🇫🇲'),
    CountryOption('Nauru', 'NR', '🇳🇷'),
    CountryOption('Nouvelle-Zelande', 'NZ', '🇳🇿'),
    CountryOption('Palaos', 'PW', '🇵🇼'),
    CountryOption('Papouasie-Nouvelle-Guinee', 'PG', '🇵🇬'),
    CountryOption('Salomon', 'SB', '🇸🇧'),
    CountryOption('Samoa', 'WS', '🇼🇸'),
    CountryOption('Tonga', 'TO', '🇹🇴'),
    CountryOption('Tuvalu', 'TV', '🇹🇻'),
    CountryOption('Vanuatu', 'VU', '🇻🇺'),
  ];

  /// Obtenir un pays par son nom
  static CountryOption? getCountryByName(String name) {
    try {
      return countries.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Obtenir un pays par son code
  static CountryOption? getCountryByCode(String code) {
    try {
      return countries.firstWhere(
        (c) => c.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
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

/// Classe représentant un pays avec son drapeau
class CountryOption {
  final String name;
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
