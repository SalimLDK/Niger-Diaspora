import 'package:equatable/equatable.dart';
import 'embassy_activity.dart';
import 'embassy_news.dart';

class EmbassyEntity extends Equatable {
  final String id;
  final String name;
  final String country;
  final String city;
  final String address;
  final String? phone; // Renamed from phoneNumber for consistency
  final String? email;
  final String? website;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String type; // Ambassade, Consulat, etc.

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

  const EmbassyEntity({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.address,
    this.phone,
    this.email,
    this.website,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.type = 'embassy',
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
  });

  @override
  List<Object?> get props => [
    id,
    name,
    country,
    city,
    address,
    phone,
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
  ];
}
