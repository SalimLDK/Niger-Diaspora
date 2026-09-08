import 'package:equatable/equatable.dart';
import 'embassy_activity.dart';
import 'embassy_news.dart';

/// Les trois natures de poste que publie le ministère.
///
/// La distinction n'est pas cosmétique : une représentation permanente
/// (Genève, New York, Paris/UNESCO) représente le Niger auprès d'une
/// organisation, pas auprès d'un État. Elle ne délivre pas d'acte consulaire,
/// et l'annoncer comme une ambassade envoie l'usager au mauvais guichet.
abstract final class EmbassyPostType {
  static const String embassy = 'embassy';
  static const String consulate = 'consulate';
  static const String permanentMission = 'permanent_mission';

  static const Set<String> values = {embassy, consulate, permanentMission};

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
  });

  /// Vrai quand la fiche porte une réserve connue, à signaler à l'usager.
  bool get hasDataNotes => dataNotes != null && dataNotes!.trim().isNotEmpty;

  /// Vrai quand le poste peut être situé sur une carte.
  ///
  /// Aucune des fiches officielles ne porte de coordonnées : sans ce garde, le
  /// bouton « voir sur la carte » s'ouvre sur le point (0, 0).
  bool get hasCoordinates => latitude != null && longitude != null;

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
  ];
}
