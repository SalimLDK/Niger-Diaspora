import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/app_settings_provider.dart';

part 'feature_flag_service.g.dart';

/// Feature flag keys - kept for backward compatibility
class FeatureFlags {
  FeatureFlags._();

  static const String moneyTransfer = 'feature_money_transfer';
  static const String marketplace = 'feature_marketplace';
  static const String businessDirectory = 'feature_business_directory';
  static const String events = 'feature_events';
  static const String groups = 'feature_groups';
  static const String embassies = 'feature_embassies';
  static const String feed = 'feature_feed';
  static const String maintenanceMode = 'feature_maintenance_mode';
}

// ============ FEATURE FLAG PROVIDERS ============
// All feature flags now come from admin settings (Firestore)
// This provides a unified configuration system managed by administrators

/// Provider to check if money transfer feature is enabled
@riverpod
bool isMoneyTransferEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).moneyTransfer;
}

/// Provider to check if marketplace feature is enabled
@riverpod
bool isMarketplaceEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).marketplace;
}

/// Provider to check if business directory feature is enabled
@riverpod
bool isBusinessDirectoryEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).businessDirectory;
}

/// Provider to check if events feature is enabled
@riverpod
bool isEventsEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).events;
}

/// Provider to check if groups feature is enabled
@riverpod
bool isGroupsEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).groups;
}

/// Provider to check if embassies feature is enabled
@riverpod
bool isEmbassiesEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).embassies;
}

/// Provider to check if social feed feature is enabled
@riverpod
bool isFeedEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).feed;
}

/// Provider to check if app is in maintenance mode
@riverpod
bool isMaintenanceMode(Ref ref) {
  return ref.watch(featureFlagsProvider).maintenanceMode;
}

/// Provider to check if audio rooms feature is enabled
@riverpod
bool isAudioRoomsEnabled(Ref ref) {
  return ref.watch(featureFlagsProvider).audioRooms;
}

/// Provider for maintenance message
@riverpod
String? maintenanceMessage(Ref ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.maintenanceMode ? flags.maintenanceMessage : null;
}

/// Flags tels qu'ils ont *réellement* été chargés depuis `app_config/settings`.
///
/// Vaut `null` tant que le chargement distant n'a pas abouti. Les appelants
/// qui bloquent un accès (le routeur) doivent laisser passer dans ce cas :
/// au démarrage à froid, `featureFlagsProvider` renvoie les valeurs par
/// défaut de [FeatureFlagsEntity], où plusieurs modules sont à `false`.
final loadedFeatureFlagsProvider = Provider<FeatureFlagsEntity?>((ref) {
  return ref.watch(appSettingsNotifierProvider).valueOrNull?.featureFlags;
});

/// Feature flag helper utilisable hors du cycle Riverpod (ex. GoRouter).
class FeatureFlagService {
  FeatureFlagService._();

  /// Résout un [AppFeature] sur des flags déjà lus.
  ///
  /// Ne lit *pas* les flags lui-même : une version antérieure instanciait un
  /// `ProviderContainer()` neuf à chaque appel, qui ne contenait évidemment
  /// pas les réglages chargés par l'app — elle renvoyait donc toujours les
  /// valeurs par défaut (salons audio et podcasts désactivés), et le routeur
  /// renvoyait ces écrans sur /home quoi qu'en dise le back-office.
  static bool isFeatureEnabled(FeatureFlagsEntity flags, AppFeature feature) {
    return switch (feature) {
      AppFeature.moneyTransfer => flags.moneyTransfer,
      AppFeature.marketplace => flags.marketplace,
      AppFeature.businessDirectory => flags.businessDirectory,
      AppFeature.podcasts => flags.podcasts,
      AppFeature.audioRooms => flags.audioRooms,
      AppFeature.events => flags.events,
      AppFeature.groups => flags.groups,
      AppFeature.embassies => flags.embassies,
      AppFeature.feed => flags.feed,
    };
  }
}

/// Application features that can be gated by remote configuration.
enum AppFeature {
  moneyTransfer,
  marketplace,
  businessDirectory,
  podcasts,
  audioRooms,
  events,
  groups,
  embassies,
  feed,
}
