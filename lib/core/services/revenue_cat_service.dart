import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/app_config.dart';

/// Entitlement identifiers — must match the RevenueCat dashboard exactly.
class RCEntitlement {
  RCEntitlement._();

  /// Full app premium access (optional tier)
  static const String appPremium = 'app_premium';

  /// Access to premium podcast content
  static const String podcastPremium = 'podcast_premium';

  /// Creator subscription tier (monthly support to a creator)
  static const String creatorPlus = 'creator_plus';
}

/// Offering identifiers — must match the RevenueCat dashboard.
class RCOffering {
  RCOffering._();

  static const String defaultOffering = 'default';
  static const String podcastOffering = 'podcast_premium';
  static const String creatorOffering = 'creator_plus';
}

/// Service wrapping RevenueCat (purchases_flutter).
///
/// Handles initialization, user identification, entitlement checks,
/// purchases, and restores. Stripe handles one-time payments (tips,
/// room tickets); RevenueCat handles recurring App Store / Play Store
/// subscriptions.
class RevenueCatService {
  static RevenueCatService? _instance;
  static RevenueCatService get instance {
    _instance ??= RevenueCatService._();
    return _instance!;
  }

  RevenueCatService._();

  bool _isInitialized = false;
  CustomerInfo? _cachedCustomerInfo;

  /// Initialize the RevenueCat SDK.
  /// Must be called before any other RevenueCat operation.
  /// [userId] is the Firebase Auth UID — pass null for anonymous.
  Future<void> initialize({String? userId}) async {
    if (kIsWeb) return; // RevenueCat is mobile-only

    if (!AppConfig.isRevenueCatConfigured) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ RevenueCat: Not configured. Set REVENUECAT_API_KEY_ANDROID '
          'and REVENUECAT_API_KEY_IOS in .env or via --dart-define.',
        );
      }
      return;
    }

    try {
      final apiKey = Platform.isIOS
          ? AppConfig.revenueCatApiKeyIos
          : AppConfig.revenueCatApiKeyAndroid;

      if (apiKey.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ RevenueCat: No API key for ${Platform.isIOS ? 'iOS' : 'Android'}.',
          );
        }
        return;
      }

      final configuration = PurchasesConfiguration(apiKey);
      if (userId != null) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);

      // Enable debug logs only in debug mode
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.error,
      );

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ RevenueCat initialized${userId != null ? ' for user $userId' : ' (anonymous)'}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ RevenueCat init error: $e');
    }
  }

  /// Identify the current user after Firebase login.
  /// Call this from the auth provider when a user signs in.
  Future<CustomerInfo?> logIn(String userId) async {
    if (!_isInitialized) return null;
    try {
      final result = await Purchases.logIn(userId);
      _cachedCustomerInfo = result.customerInfo;
      return _cachedCustomerInfo;
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat logIn error: $e');
      return null;
    }
  }

  /// Reset to anonymous user on sign out.
  Future<void> logOut() async {
    if (!_isInitialized) return;
    try {
      await Purchases.logOut();
      _cachedCustomerInfo = null;
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat logOut error: $e');
    }
  }

  /// Get current customer info (entitlements, expiry dates).
  Future<CustomerInfo?> getCustomerInfo({bool forceRefresh = false}) async {
    if (!_isInitialized) return null;
    try {
      if (!forceRefresh && _cachedCustomerInfo != null) {
        return _cachedCustomerInfo;
      }
      _cachedCustomerInfo = await Purchases.getCustomerInfo();
      return _cachedCustomerInfo;
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat getCustomerInfo error: $e');
      return null;
    }
  }

  /// Check if the user has an active entitlement.
  Future<bool> hasEntitlement(String entitlementId) async {
    final info = await getCustomerInfo();
    return info?.entitlements.active.containsKey(entitlementId) ?? false;
  }

  /// Check app premium access.
  Future<bool> get isAppPremium => hasEntitlement(RCEntitlement.appPremium);

  /// Check podcast premium access.
  Future<bool> get hasPodcastPremium =>
      hasEntitlement(RCEntitlement.podcastPremium);

  /// Check creator plus access.
  Future<bool> get hasCreatorPlus =>
      hasEntitlement(RCEntitlement.creatorPlus);

  /// Get all available offerings from RevenueCat.
  Future<Offerings?> getOfferings() async {
    if (!_isInitialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat getOfferings error: $e');
      return null;
    }
  }

  /// Get a specific offering by identifier.
  Future<Offering?> getOffering(String offeringId) async {
    final offerings = await getOfferings();
    return offerings?.getOffering(offeringId) ?? offerings?.current;
  }

  /// Purchase a package.
  /// Returns updated [CustomerInfo] on success, null if cancelled or failed.
  Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!_isInitialized) return null;
    try {
      // purchases_flutter 10.x : `purchasePackage` est deprecie au profit de
      // `purchase(PurchaseParams)`, qui renvoie un `PurchaseResult` enveloppant
      // le `CustomerInfo` au lieu de le renvoyer directement.
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _cachedCustomerInfo = result.customerInfo;
      return _cachedCustomerInfo;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — not an error
        return null;
      }
      if (kDebugMode) debugPrint('RevenueCat purchasePackage error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat purchasePackage error: $e');
      rethrow;
    }
  }

  /// Restore previous purchases (required by App Store guidelines).
  Future<CustomerInfo?> restorePurchases() async {
    if (!_isInitialized) return null;
    try {
      _cachedCustomerInfo = await Purchases.restorePurchases();
      return _cachedCustomerInfo;
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat restorePurchases error: $e');
      rethrow;
    }
  }

  /// Format a package price for display (e.g. "4,99 €/mois").
  String formatPackagePrice(Package package) {
    final product = package.storeProduct;
    final price = product.priceString;
    final period = _periodLabel(package.packageType);
    return period.isNotEmpty ? '$price/$period' : price;
  }

  String _periodLabel(PackageType type) => switch (type) {
        PackageType.monthly => 'mois',
        PackageType.annual => 'an',
        PackageType.weekly => 'semaine',
        PackageType.threeMonth => '3 mois',
        PackageType.sixMonth => '6 mois',
        PackageType.lifetime => '',
        _ => '',
      };

  bool get isInitialized => _isInitialized;
}
