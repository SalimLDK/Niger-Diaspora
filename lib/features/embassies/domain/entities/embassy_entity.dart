import 'package:equatable/equatable.dart';
import 'embassy_activity.dart';
import 'embassy_news.dart';

/// Les natures de poste, telles que l'écran d'administration les nomme déjà
/// (`embassyTypeMission` / `embassyTypeDelegation` côté traductions).
///
/// La distinction n'est pas cosmétique : une mission permanente (Genève,
/// New York) ou une délégation permanente (Paris/UNESCO) représente le Niger
/// auprès d'une organisation, pas auprès d'un État. Elle ne délivre pas d'acte
/// consulaire, et l'annoncer comme une ambassade envoie l'usager au mauvais
/// guichet.
abstract final class EmbassyPostType {
  static const String embassy = 'embassy';
  static const String consulate = 'consulate';
  static const String mission = 'mission';
  static const String delegation = 'delegation';

  static const Set<String> values = {embassy, consulate, mission, delegation};

  static bool isValid(String value) => values.contains(value);
}

class EmbassyEntity extends Equatable {
  final String id;
  final String name;
  final String country;
  final String city;
  final String address;
  final String? phone; // Renamed from phoneNumber for consistency

  /// Lignes supplémentaires publiées par le poste.
  ///
  /// Plusieurs missions en annoncent deux ou trois (Le Caire en a trois) ; le
  /// modèle n'en gardait qu'une et perdait les autres à l'import.
  final List<String> additionalPhones;

  final String? fax;
  final String? email;
  final String? website;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;

  /// L'une des valeurs de [EmbassyPostType].
  final String type;

  final List<String> services;
  final Map<String, String> openingHours;
  final bool isVerified;
  final bool isSuspended;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final List<String> jurisdictionCountries;
  final List<EmbassyActivity> activities;
  final List<EmbassyNews> news;

  // Availability fields
  final bool isTemporarilyClosed;
  final String? closureMessage;
  final DateTime? reopenDate;
  final List<String> upcomingServices; // Services coming soon

  // --- Traçabilité de la fiche ---------------------------------------------
  // D'où vient la donnée, quand elle a été confrontée à sa source, et ce qu'on
  // sait de faux dedans. L'annuaire officiel est fautif par endroits : sans ces
  // trois champs, l'app présente une coordonnée périmée comme une certitude.

  /// Origine de la fiche, p. ex. `diplomatie.gouv.ne`.
  final String? source;

  /// Page exacte d'où la fiche a été relevée.
  final String? sourceUrl;

  /// Date du dernier rapprochement avec la source.
  final DateTime? sourceCheckedAt;

  /// Réserve en clair sur la fiche, destinée à être affichée à l'usager
  /// (« fax non repris : le numéro publié est amputé de deux chiffres »).
  final String? dataNotes;

  /// Vrai quand la position est connue mais qu'on ne s'y fie pas.
  ///
  /// « On a une position » et « on lui fait confiance » sont deux choses
  /// différentes : Copenhague porte des coordonnées à 5 km d'une autre source.
  /// Sans ce drapeau, le bouton « Y aller » s'affichait actif, en orange,
  /// exactement comme sur une fiche sûre — pendant que la réserve juste
  /// au-dessus prévenait du contraire.
  final bool isPositionUncertain;

  const EmbassyEntity({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.address,
    this.phone,
    this.additionalPhones = const [],
    this.fax,
    this.email,
    this.website,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.type = EmbassyPostType.embassy,
    this.services = const [],
    this.openingHours = const {},
    this.isVerified = false,
    this.isSuspended = false,
    this.verifiedAt,
    this.rejectionReason,
    this.jurisdictionCountries = const [],
    this.activities = const [],
    this.news = const [],
    this.isTemporarilyClosed = false,
    this.closureMessage,
    this.reopenDate,
    this.upcomingServices = const [],
    this.source,
    this.sourceUrl,
    this.sourceCheckedAt,
    this.dataNotes,
    this.isPositionUncertain = false,
  });

  /// Vrai quand la fiche porte une réserve connue, à signaler à l'usager.
  bool get hasDataNotes => dataNotes != null && dataNotes!.trim().isNotEmpty;

  /// Vrai quand le poste porte des coordonnées.
  ///
  /// Ne dit rien de leur fiabilité : voir [canNavigate] pour décider d'ouvrir
  /// une carte.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Vrai quand on peut envoyer l'usager à cette position sans réserve.
  ///
  /// C'est ce que doit tester tout bouton « Y aller » / « Itinéraire » —
  /// jamais `latitude != null` seul, qui ouvrait la carte sur une position
  /// dont on sait qu'elle est peut-être fausse.
  bool get canNavigate => hasCoordinates && !isPositionUncertain;

  /// Toutes les lignes téléphoniques du poste, principale en tête.
  List<String> get allPhones => [
    if (phone != null && phone!.isNotEmpty) phone!,
    ...additionalPhones.where((p) => p.isNotEmpty),
  ];

  @override
  List<Object?> get props => [
    id,
    name,
    country,
    city,
    address,
    phone,
    additionalPhones,
    fax,
    email,
    website,
    latitude,
    longitude,
    imageUrl,
    type,
    services,
    openingHours,
    isVerified,
    isSuspended,
    verifiedAt,
    rejectionReason,
    jurisdictionCountries,
    activities,
    news,
    isTemporarilyClosed,
    closureMessage,
    reopenDate,
    upcomingServices,
    source,
    sourceUrl,
    sourceCheckedAt,
    dataNotes,
    isPositionUncertain,
  ];
}
