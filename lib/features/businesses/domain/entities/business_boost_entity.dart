import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_boost_entity.freezed.dart';

@freezed
class BusinessBoostEntity with _$BusinessBoostEntity {
  const factory BusinessBoostEntity({
    required String id,
    required String businessId,
    required String userId,
    @Default(BoostType.standard) BoostType type,
    @Default(BoostDuration.days7) BoostDuration duration,
    required double amount,
    @Default('XOF') String currency,
    required DateTime startDate,
    required DateTime endDate,
    @Default(BoostStatus.active) BoostStatus status,
    String? paymentReference,
    DateTime? createdAt,
  }) = _BusinessBoostEntity;
}

enum BoostType {
  standard,
  featured,
  premium,
}

enum BoostDuration {
  days7,
  days30,
  days90,
}

enum BoostStatus {
  pending,
  active,
  expired,
  cancelled,
}

extension BoostTypeExtension on BoostType {
  String get label {
    switch (this) {
      case BoostType.standard:
        return 'Standard';
      case BoostType.featured:
        return 'Mise en avant';
      case BoostType.premium:
        return 'Premium';
    }
  }

  String get description {
    switch (this) {
      case BoostType.standard:
        return 'Apparaitre plus haut dans les resultats';
      case BoostType.featured:
        return 'Badge special + meilleure visibilite';
      case BoostType.premium:
        return 'Position top + badge + section dediee';
    }
  }

  /// Base price in XOF for 7 days
  double get basePrice {
    switch (this) {
      case BoostType.standard:
        return 5000;
      case BoostType.featured:
        return 10000;
      case BoostType.premium:
        return 25000;
    }
  }

  /// Calculate price based on duration
  double getPrice(BoostDuration duration) {
    return basePrice * duration.multiplier;
  }
}

extension BoostDurationExtension on BoostDuration {
  String get label {
    switch (this) {
      case BoostDuration.days7:
        return '7 jours';
      case BoostDuration.days30:
        return '30 jours';
      case BoostDuration.days90:
        return '90 jours';
    }
  }

  int get days {
    switch (this) {
      case BoostDuration.days7:
        return 7;
      case BoostDuration.days30:
        return 30;
      case BoostDuration.days90:
        return 90;
    }
  }

  /// Price multiplier compared to 7 days
  double get multiplier {
    switch (this) {
      case BoostDuration.days7:
        return 1.0;
      case BoostDuration.days30:
        return 3.0; // ~25% discount
      case BoostDuration.days90:
        return 7.0; // ~42% discount
    }
  }
}

extension BoostStatusExtension on BoostStatus {
  String get label {
    switch (this) {
      case BoostStatus.pending:
        return 'En attente';
      case BoostStatus.active:
        return 'Actif';
      case BoostStatus.expired:
        return 'Expire';
      case BoostStatus.cancelled:
        return 'Annule';
    }
  }
}
