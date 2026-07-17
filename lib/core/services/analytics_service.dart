import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service d'Analytics avancé avec tracking des parcours et funnels
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  AnalyticsService._internal();

  // ==================== Événements de base ====================

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      // Firebase Analytics only accepts String or num — convert bool to 0/1.
      final sanitized = parameters?.map(
        (k, v) => MapEntry(k, v is bool ? (v ? 1 : 0) : v),
      );
      await _analytics.logEvent(name: name, parameters: sanitized);
    } catch (e) {
      debugPrint('AnalyticsService: Error logging event: $e');
    }
  }

  Future<void> logLogin({String? method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  // ==================== Tracking Parcours Utilisateur ====================

  /// Log le début d'un parcours utilisateur
  Future<void> logJourneyStart({
    required String journeyName,
    Map<String, Object>? additionalParams,
  }) async {
    await logEvent(
      name: 'journey_start',
      parameters: {
        'journey_name': journeyName,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalParams,
      },
    );
  }

  /// Log une étape dans un parcours
  Future<void> logJourneyStep({
    required String journeyName,
    required String stepName,
    required int stepNumber,
    Map<String, Object>? additionalParams,
  }) async {
    await logEvent(
      name: 'journey_step',
      parameters: {
        'journey_name': journeyName,
        'step_name': stepName,
        'step_number': stepNumber,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalParams,
      },
    );
  }

  /// Log la fin d'un parcours
  Future<void> logJourneyComplete({
    required String journeyName,
    bool success = true,
    Map<String, Object>? additionalParams,
  }) async {
    await logEvent(
      name: 'journey_complete',
      parameters: {
        'journey_name': journeyName,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalParams,
      },
    );
  }

  /// Log l'abandon d'un parcours
  Future<void> logJourneyAbandoned({
    required String journeyName,
    required String lastStep,
    String? reason,
  }) async {
    await logEvent(
      name: 'journey_abandoned',
      parameters: {
        'journey_name': journeyName,
        'last_step': lastStep,
        if (reason != null) 'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Funnel Onboarding ====================

  /// Étapes du funnel d'onboarding
  Future<void> logOnboardingStart() async {
    await logEvent(
      name: 'onboarding_start',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logOnboardingConsentGiven() async {
    await logEvent(
      name: 'onboarding_consent',
      parameters: {
        'step': 'consent_given',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logOnboardingProfileConfigured({
    bool hasPhoto = false,
    bool hasBio = false,
    String? country,
  }) async {
    await logEvent(
      name: 'onboarding_profile_config',
      parameters: {
        'step': 'profile_configured',
        'has_photo': hasPhoto,
        'has_bio': hasBio,
        if (country != null) 'country': country,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logOnboardingIntroSeen() async {
    await logEvent(
      name: 'onboarding_intro_seen',
      parameters: {
        'step': 'intro_completed',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logOnboardingComplete({
    required Duration totalDuration,
  }) async {
    await logEvent(
      name: 'onboarding_complete',
      parameters: {
        'duration_seconds': totalDuration.inSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Funnel E-commerce ====================

  Future<void> logViewProduct({
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await _analytics.logViewItem(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          price: price,
          itemCategory: category,
        ),
      ],
    );
  }

  Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double price,
    int quantity = 1,
  }) async {
    await _analytics.logAddToCart(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          price: price,
          quantity: quantity,
        ),
      ],
      value: price * quantity,
      currency: 'XOF',
    );
  }

  Future<void> logRemoveFromCart({
    required String productId,
    required String productName,
    required double price,
    int quantity = 1,
  }) async {
    await _analytics.logRemoveFromCart(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          price: price,
          quantity: quantity,
        ),
      ],
      value: price * quantity,
      currency: 'XOF',
    );
  }

  Future<void> logBeginCheckout({
    required double totalValue,
    required int itemCount,
  }) async {
    await _analytics.logBeginCheckout(
      value: totalValue,
      currency: 'XOF',
      items: [],
    );
    await logEvent(
      name: 'checkout_begin',
      parameters: {
        'value': totalValue,
        'item_count': itemCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logPurchase({
    required String transactionId,
    required double totalValue,
    required int itemCount,
    String? paymentMethod,
  }) async {
    await _analytics.logPurchase(
      transactionId: transactionId,
      value: totalValue,
      currency: 'XOF',
      items: [],
    );
    await logEvent(
      name: 'purchase_complete',
      parameters: {
        'transaction_id': transactionId,
        'value': totalValue,
        'item_count': itemCount,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logPurchaseFailed({
    required String reason,
    double? attemptedValue,
  }) async {
    await logEvent(
      name: 'purchase_failed',
      parameters: {
        'reason': reason,
        if (attemptedValue != null) 'attempted_value': attemptedValue,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Funnel Transfer ====================

  Future<void> logTransferInitiated({
    required double amount,
    required String currency,
    String? recipientCountry,
  }) async {
    await logEvent(
      name: 'transfer_initiated',
      parameters: {
        'amount': amount,
        'currency': currency,
        if (recipientCountry != null) 'recipient_country': recipientCountry,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logTransferRecipientSelected({
    required bool isNewRecipient,
    required bool isFriend,
  }) async {
    await logEvent(
      name: 'transfer_recipient_selected',
      parameters: {
        'is_new_recipient': isNewRecipient,
        'is_friend': isFriend,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logTransferCompleted({
    required String transactionId,
    required double amount,
    required String currency,
    required String recipientCountry,
  }) async {
    await logEvent(
      name: 'transfer_completed',
      parameters: {
        'transaction_id': transactionId,
        'amount': amount,
        'currency': currency,
        'recipient_country': recipientCountry,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logTransferFailed({
    required String reason,
    double? attemptedAmount,
  }) async {
    await logEvent(
      name: 'transfer_failed',
      parameters: {
        'reason': reason,
        if (attemptedAmount != null) 'attempted_amount': attemptedAmount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Feature Usage ====================

  Future<void> logFeatureUsage({
    required String featureName,
    String? action,
    Map<String, Object>? additionalParams,
  }) async {
    await logEvent(
      name: 'feature_usage',
      parameters: {
        'feature_name': featureName,
        if (action != null) 'action': action,
        ...?additionalParams,
      },
    );
  }

  // ==================== Social Interactions ====================

  Future<void> logSocialAction({
    required SocialActionType actionType,
    required String targetType, // 'user', 'group', 'event', 'post'
    required String targetId,
  }) async {
    await logEvent(
      name: 'social_action',
      parameters: {
        'action_type': actionType.name,
        'target_type': targetType,
        'target_id': targetId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Search ====================

  Future<void> logSearch({
    required String searchTerm,
    String? category,
    int resultCount = 0,
  }) async {
    await _analytics.logSearch(
      searchTerm: searchTerm,
    );
    await logEvent(
      name: 'search_performed',
      parameters: {
        'search_term': searchTerm,
        if (category != null) 'category': category,
        'result_count': resultCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Errors & Issues ====================

  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? screenName,
    String? userId,
  }) async {
    await logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage.length > 100
            ? errorMessage.substring(0, 100)
            : errorMessage,
        if (screenName != null) 'screen_name': screenName,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Chiffrement des messages ====================

  /// Suit le niveau de chiffrement effectif de chaque message texte envoyé,
  /// pour mesurer EN CONTINU le taux de repli AES (fallback clé globale) vs
  /// Signal (E2EE).
  ///
  /// Exploitation côté Firebase Analytics (event `message_encryption`) :
  ///   taux de fallback = count(level=aes) / count(*), filtré par `scope`.
  /// `fallback_reason` (présent seulement quand level=aes) permet de séparer
  /// « destinataire sans clés » (rollout en cours) de « session échouée »
  /// (problème structurel d'établissement Signal).
  Future<void> logMessageEncryption({
    required String level, // 'e2ee' | 'aes'
    required String scope, // 'direct' | 'group'
    String? fallbackReason, // renseigné uniquement quand level == 'aes'
  }) async {
    await logEvent(
      name: 'message_encryption',
      parameters: {
        'level': level,
        'scope': scope,
        'is_fallback': level == 'aes',
        if (fallbackReason != null) 'fallback_reason': fallbackReason,
      },
    );
  }

  // ==================== User Properties ====================

  Future<void> setUserProperties({
    String? country,
    String? accountType,
    bool? hasCompletedOnboarding,
    int? groupsCount,
    int? friendsCount,
  }) async {
    if (country != null) {
      await setUserProperty(name: 'country', value: country);
    }
    if (accountType != null) {
      await setUserProperty(name: 'account_type', value: accountType);
    }
    if (hasCompletedOnboarding != null) {
      await setUserProperty(
        name: 'onboarding_complete',
        value: hasCompletedOnboarding.toString(),
      );
    }
    if (groupsCount != null) {
      await setUserProperty(
        name: 'groups_count',
        value: _bucketize(groupsCount),
      );
    }
    if (friendsCount != null) {
      await setUserProperty(
        name: 'friends_count',
        value: _bucketize(friendsCount),
      );
    }
  }

  /// Convertit un nombre en bucket pour les user properties
  String _bucketize(int count) {
    if (count == 0) return '0';
    if (count <= 5) return '1-5';
    if (count <= 10) return '6-10';
    if (count <= 25) return '11-25';
    if (count <= 50) return '26-50';
    if (count <= 100) return '51-100';
    return '100+';
  }
}

/// Types d'actions sociales
enum SocialActionType {
  follow,
  unfollow,
  friendRequest,
  friendAccept,
  friendReject,
  groupJoin,
  groupLeave,
  eventAttend,
  eventCancel,
  share,
  report,
  block,
}
