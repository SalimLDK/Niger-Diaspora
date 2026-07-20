import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/revenue_cat_service.dart';

/// Provider exposing the RevenueCatService singleton.
final revenueCatServiceProvider = Provider<RevenueCatService>(
  (_) => RevenueCatService.instance,
);

/// Syncs RevenueCat user identity with Firebase Auth state changes.
/// Listens to authStateChanges directly — no dependency on authNotifierProvider.
/// Must be watched at the app root so the subscription stays alive.
final revenueCatAuthSyncProvider = StreamProvider<void>((ref) async* {
  await for (final user in FirebaseAuth.instance.authStateChanges()) {
    if (user != null) {
      await RevenueCatService.instance.logIn(user.uid);
    } else {
      await RevenueCatService.instance.logOut();
    }
    ref.invalidate(customerInfoProvider);
  }
});

/// Current customer info — refreshed on demand.
final customerInfoProvider = FutureProvider<CustomerInfo?>((ref) async {
  return RevenueCatService.instance.getCustomerInfo(forceRefresh: true);
});

/// Active entitlements map (entitlementId → EntitlementInfo).
final activeEntitlementsProvider = Provider<Map<String, EntitlementInfo>>((ref) {
  final info = ref.watch(customerInfoProvider).valueOrNull;
  return info?.entitlements.active ?? {};
});

/// Whether the user has app-wide premium access.
final isAppPremiumProvider = Provider<bool>((ref) {
  final active = ref.watch(activeEntitlementsProvider);
  return active.containsKey(RCEntitlement.appPremium);
});

/// Whether the user has access to premium podcast content.
final hasPodcastPremiumProvider = Provider<bool>((ref) {
  final active = ref.watch(activeEntitlementsProvider);
  return active.containsKey(RCEntitlement.podcastPremium);
});

/// Whether the user has creator+ access.
final hasCreatorPlusProvider = Provider<bool>((ref) {
  final active = ref.watch(activeEntitlementsProvider);
  return active.containsKey(RCEntitlement.creatorPlus);
});

/// All available offerings from RevenueCat.
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  return RevenueCatService.instance.getOfferings();
});

/// A specific offering by ID.
final offeringProvider =
    FutureProvider.family<Offering?, String>((ref, offeringId) async {
  return RevenueCatService.instance.getOffering(offeringId);
});

// ============================================================================
// PURCHASE NOTIFIER
// ============================================================================

/// State for purchase operations.
class PurchaseState {
  final bool isLoading;
  final String? error;
  final CustomerInfo? lastResult;

  const PurchaseState({
    this.isLoading = false,
    this.error,
    this.lastResult,
  });

  PurchaseState copyWith({
    bool? isLoading,
    String? error,
    CustomerInfo? lastResult,
  }) =>
      PurchaseState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        lastResult: lastResult ?? this.lastResult,
      );
}

final purchaseNotifierProvider =
    NotifierProvider<PurchaseNotifier, PurchaseState>(
  PurchaseNotifier.new,
);

class PurchaseNotifier extends Notifier<PurchaseState> {
  @override
  PurchaseState build() => const PurchaseState();

  /// Purchase a RevenueCat package (App Store / Play Store).
  /// Refreshes customerInfo and entitlement providers on success.
  Future<bool> purchase(Package package) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final info = await RevenueCatService.instance.purchasePackage(package);
      if (info != null) {
        state = state.copyWith(isLoading: false, lastResult: info);
        ref.invalidate(customerInfoProvider);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Fetch the first package of [offeringId] and purchase it.
  /// Returns true on success, false if cancelled or no offering found.
  Future<bool> purchaseOffering(String offeringId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final offering = await RevenueCatService.instance.getOffering(offeringId);
      if (offering == null || offering.availablePackages.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Offre non disponible sur cette plateforme.');
        return false;
      }
      final info = await RevenueCatService.instance
          .purchasePackage(offering.availablePackages.first);
      if (info != null) {
        state = state.copyWith(isLoading: false, lastResult: info);
        ref.invalidate(customerInfoProvider);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Returns a formatted price label for the first package of [offeringId],
  /// or null if the offering is not available (fall back to Stripe price).
  Future<String?> getOfferingPriceLabel(String offeringId) async {
    try {
      final offering = await RevenueCatService.instance.getOffering(offeringId);
      if (offering == null || offering.availablePackages.isEmpty) return null;
      return RevenueCatService.instance
          .formatPackagePrice(offering.availablePackages.first);
    } catch (_) {
      return null;
    }
  }

  /// Restore previous App Store / Play Store purchases.
  Future<bool> restore() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      state = state.copyWith(isLoading: false, lastResult: info);
      ref.invalidate(customerInfoProvider);
      return info != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}
