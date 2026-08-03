import '../../domain/entities/app_settings_entity.dart';

/// Sérialisation des réglages « salons audio ».
///
/// `AppSettingsModel` ne portait aucun champ `audioRooms` : l'entité était
/// bien lue par l'app (montants de pourboire proposés, bornes min/max,
/// limites de retrait, langues du patrimoine…) mais jamais chargée depuis le
/// backend — elle retombait donc toujours sur ses valeurs par défaut, et
/// aucun réglage fait en back-office ne pouvait atteindre l'app.
///
/// Les valeurs de repli sont lues sur `AudioRoomsSettingsEntity` elle-même
/// plutôt que recopiées ici : une seule source pour les défauts.
class AudioRoomsSettingsModel {
  const AudioRoomsSettingsModel._();

  static const AudioRoomsSettingsEntity _d = AudioRoomsSettingsEntity();

  static AudioRoomsSettingsEntity fromJson(Map<String, dynamic> json) {
    return AudioRoomsSettingsEntity(
      isEnabled: json['isEnabled'] as bool? ?? _d.isEnabled,
      allowPaidRooms: json['allowPaidRooms'] as bool? ?? _d.allowPaidRooms,
      allowTips: json['allowTips'] as bool? ?? _d.allowTips,
      allowReplays: json['allowReplays'] as bool? ?? _d.allowReplays,
      allowSubscriptions: json['allowSubscriptions'] as bool? ?? _d.allowSubscriptions,
      allowRecording: json['allowRecording'] as bool? ?? _d.allowRecording,
      allowVideoRooms: json['allowVideoRooms'] as bool? ?? _d.allowVideoRooms,
      allowCollections: json['allowCollections'] as bool? ?? _d.allowCollections,
      allowHeritageContent: json['allowHeritageContent'] as bool? ?? _d.allowHeritageContent,
      allowLinkedEvents: json['allowLinkedEvents'] as bool? ?? _d.allowLinkedEvents,
      allowLinkedGroups: json['allowLinkedGroups'] as bool? ?? _d.allowLinkedGroups,
      allowLinkedEmbassies: json['allowLinkedEmbassies'] as bool? ?? _d.allowLinkedEmbassies,
      showMultipleTimezones: json['showMultipleTimezones'] as bool? ?? _d.showMultipleTimezones,
      requireHeritageModeration: json['requireHeritageModeration'] as bool? ?? _d.requireHeritageModeration,
      requireStripeConnect: json['requireStripeConnect'] as bool? ?? _d.requireStripeConnect,
      collectionCommissionPercent: (json['collectionCommissionPercent'] as num?)?.toInt() ?? _d.collectionCommissionPercent,
      minCollectionGoal: (json['minCollectionGoal'] as num?)?.toInt() ?? _d.minCollectionGoal,
      maxCollectionGoal: (json['maxCollectionGoal'] as num?)?.toInt() ?? _d.maxCollectionGoal,
      ticketCommissionPercent: (json['ticketCommissionPercent'] as num?)?.toInt() ?? _d.ticketCommissionPercent,
      tipCommissionPercent: (json['tipCommissionPercent'] as num?)?.toInt() ?? _d.tipCommissionPercent,
      replayCommissionPercent: (json['replayCommissionPercent'] as num?)?.toInt() ?? _d.replayCommissionPercent,
      subscriptionCommissionPercent: (json['subscriptionCommissionPercent'] as num?)?.toInt() ?? _d.subscriptionCommissionPercent,
      minTicketPrice: (json['minTicketPrice'] as num?)?.toInt() ?? _d.minTicketPrice,
      minTipAmount: (json['minTipAmount'] as num?)?.toInt() ?? _d.minTipAmount,
      minReplayPrice: (json['minReplayPrice'] as num?)?.toInt() ?? _d.minReplayPrice,
      minSubscriptionPrice: (json['minSubscriptionPrice'] as num?)?.toInt() ?? _d.minSubscriptionPrice,
      maxTicketPrice: (json['maxTicketPrice'] as num?)?.toInt() ?? _d.maxTicketPrice,
      maxTipAmount: (json['maxTipAmount'] as num?)?.toInt() ?? _d.maxTipAmount,
      maxReplayPrice: (json['maxReplayPrice'] as num?)?.toInt() ?? _d.maxReplayPrice,
      maxSubscriptionPrice: (json['maxSubscriptionPrice'] as num?)?.toInt() ?? _d.maxSubscriptionPrice,
      maxSpeakers: (json['maxSpeakers'] as num?)?.toInt() ?? _d.maxSpeakers,
      maxListeners: (json['maxListeners'] as num?)?.toInt() ?? _d.maxListeners,
      maxRoomDurationMinutes: (json['maxRoomDurationMinutes'] as num?)?.toInt() ?? _d.maxRoomDurationMinutes,
      maxRecordingDurationMinutes: (json['maxRecordingDurationMinutes'] as num?)?.toInt() ?? _d.maxRecordingDurationMinutes,
      maxRecordingFileSizeMb: (json['maxRecordingFileSizeMb'] as num?)?.toInt() ?? _d.maxRecordingFileSizeMb,
      minPayoutXOF: (json['minPayoutXOF'] as num?)?.toInt() ?? _d.minPayoutXOF,
      minPayoutEUR: (json['minPayoutEUR'] as num?)?.toInt() ?? _d.minPayoutEUR,
      minPayoutUSD: (json['minPayoutUSD'] as num?)?.toInt() ?? _d.minPayoutUSD,
      minPayoutGBP: (json['minPayoutGBP'] as num?)?.toInt() ?? _d.minPayoutGBP,
      minPayoutCAD: (json['minPayoutCAD'] as num?)?.toInt() ?? _d.minPayoutCAD,
      minPayoutCHF: (json['minPayoutCHF'] as num?)?.toInt() ?? _d.minPayoutCHF,
      maxPayoutXOF: (json['maxPayoutXOF'] as num?)?.toInt() ?? _d.maxPayoutXOF,
      maxPayoutEUR: (json['maxPayoutEUR'] as num?)?.toInt() ?? _d.maxPayoutEUR,
      maxPayoutUSD: (json['maxPayoutUSD'] as num?)?.toInt() ?? _d.maxPayoutUSD,
      maxPayoutGBP: (json['maxPayoutGBP'] as num?)?.toInt() ?? _d.maxPayoutGBP,
      maxPayoutCAD: (json['maxPayoutCAD'] as num?)?.toInt() ?? _d.maxPayoutCAD,
      maxPayoutCHF: (json['maxPayoutCHF'] as num?)?.toInt() ?? _d.maxPayoutCHF,
      defaultCurrency: json['defaultCurrency'] as String? ?? _d.defaultCurrency,
      defaultPayoutCurrency: json['defaultPayoutCurrency'] as String? ?? _d.defaultPayoutCurrency,
      defaultDisplayTimezones: _stringList(json['defaultDisplayTimezones']) ?? _d.defaultDisplayTimezones,
      heritageLanguages: _stringList(json['heritageLanguages']) ?? _d.heritageLanguages,
      heritageRegions: _stringList(json['heritageRegions']) ?? _d.heritageRegions,
      supportedCurrencies: _stringList(json['supportedCurrencies']) ?? _d.supportedCurrencies,
      supportedPayoutCurrencies: _stringList(json['supportedPayoutCurrencies']) ?? _d.supportedPayoutCurrencies,
      predefinedTipAmountsUSD: _intList(json['predefinedTipAmountsUSD']) ?? _d.predefinedTipAmountsUSD,
      predefinedTipAmountsEUR: _intList(json['predefinedTipAmountsEUR']) ?? _d.predefinedTipAmountsEUR,
      predefinedTipAmountsGBP: _intList(json['predefinedTipAmountsGBP']) ?? _d.predefinedTipAmountsGBP,
      predefinedTipAmountsCAD: _intList(json['predefinedTipAmountsCAD']) ?? _d.predefinedTipAmountsCAD,
      predefinedTipAmountsCHF: _intList(json['predefinedTipAmountsCHF']) ?? _d.predefinedTipAmountsCHF,
      predefinedTipAmountsXOF: _intList(json['predefinedTipAmountsXOF']) ?? _d.predefinedTipAmountsXOF,
    );
  }

  static Map<String, dynamic> toJson(AudioRoomsSettingsEntity e) => {
        'isEnabled': e.isEnabled,
        'allowPaidRooms': e.allowPaidRooms,
        'allowTips': e.allowTips,
        'allowReplays': e.allowReplays,
        'allowSubscriptions': e.allowSubscriptions,
        'allowRecording': e.allowRecording,
        'allowVideoRooms': e.allowVideoRooms,
        'allowCollections': e.allowCollections,
        'allowHeritageContent': e.allowHeritageContent,
        'allowLinkedEvents': e.allowLinkedEvents,
        'allowLinkedGroups': e.allowLinkedGroups,
        'allowLinkedEmbassies': e.allowLinkedEmbassies,
        'showMultipleTimezones': e.showMultipleTimezones,
        'requireHeritageModeration': e.requireHeritageModeration,
        'requireStripeConnect': e.requireStripeConnect,
        'collectionCommissionPercent': e.collectionCommissionPercent,
        'minCollectionGoal': e.minCollectionGoal,
        'maxCollectionGoal': e.maxCollectionGoal,
        'ticketCommissionPercent': e.ticketCommissionPercent,
        'tipCommissionPercent': e.tipCommissionPercent,
        'replayCommissionPercent': e.replayCommissionPercent,
        'subscriptionCommissionPercent': e.subscriptionCommissionPercent,
        'minTicketPrice': e.minTicketPrice,
        'minTipAmount': e.minTipAmount,
        'minReplayPrice': e.minReplayPrice,
        'minSubscriptionPrice': e.minSubscriptionPrice,
        'maxTicketPrice': e.maxTicketPrice,
        'maxTipAmount': e.maxTipAmount,
        'maxReplayPrice': e.maxReplayPrice,
        'maxSubscriptionPrice': e.maxSubscriptionPrice,
        'maxSpeakers': e.maxSpeakers,
        'maxListeners': e.maxListeners,
        'maxRoomDurationMinutes': e.maxRoomDurationMinutes,
        'maxRecordingDurationMinutes': e.maxRecordingDurationMinutes,
        'maxRecordingFileSizeMb': e.maxRecordingFileSizeMb,
        'minPayoutXOF': e.minPayoutXOF,
        'minPayoutEUR': e.minPayoutEUR,
        'minPayoutUSD': e.minPayoutUSD,
        'minPayoutGBP': e.minPayoutGBP,
        'minPayoutCAD': e.minPayoutCAD,
        'minPayoutCHF': e.minPayoutCHF,
        'maxPayoutXOF': e.maxPayoutXOF,
        'maxPayoutEUR': e.maxPayoutEUR,
        'maxPayoutUSD': e.maxPayoutUSD,
        'maxPayoutGBP': e.maxPayoutGBP,
        'maxPayoutCAD': e.maxPayoutCAD,
        'maxPayoutCHF': e.maxPayoutCHF,
        'defaultCurrency': e.defaultCurrency,
        'defaultPayoutCurrency': e.defaultPayoutCurrency,
        'defaultDisplayTimezones': e.defaultDisplayTimezones,
        'heritageLanguages': e.heritageLanguages,
        'heritageRegions': e.heritageRegions,
        'supportedCurrencies': e.supportedCurrencies,
        'supportedPayoutCurrencies': e.supportedPayoutCurrencies,
        'predefinedTipAmountsUSD': e.predefinedTipAmountsUSD,
        'predefinedTipAmountsEUR': e.predefinedTipAmountsEUR,
        'predefinedTipAmountsGBP': e.predefinedTipAmountsGBP,
        'predefinedTipAmountsCAD': e.predefinedTipAmountsCAD,
        'predefinedTipAmountsCHF': e.predefinedTipAmountsCHF,
        'predefinedTipAmountsXOF': e.predefinedTipAmountsXOF,
      };

  static List<String>? _stringList(Object? raw) =>
      raw is List ? raw.map((e) => e.toString()).toList() : null;

  static List<int>? _intList(Object? raw) =>
      raw is List ? raw.whereType<num>().map((e) => e.toInt()).toList() : null;
}
