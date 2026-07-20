import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/domain/entities/app_settings_entity.dart';
import '../../../admin/presentation/providers/app_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/monetization_remote_datasource.dart';
import '../../data/datasources/monetization_supabase_datasource.dart';
import '../../domain/entities/creator_profile_entity.dart';
import '../../domain/entities/payout_entity.dart';
import '../../domain/entities/room_ticket_entity.dart';
import '../../domain/entities/tip_entity.dart';

/// Provider for MonetizationRemoteDataSource
final monetizationRemoteDataSourceProvider =
    Provider<MonetizationRemoteDataSource>((ref) {
  return MonetizationSupabaseDataSource();
});

/// Stream of user's tickets
final userTicketsProvider =
    StreamProvider.family<List<RoomTicketEntity>, String>((ref, userId) {
  return ref
      .watch(monetizationRemoteDataSourceProvider)
      .getUserTickets(userId)
      .map(
        (tickets) => tickets.map((t) => t.toEntity()).toList(),
      );
});

/// Stream of tips for a room
final roomTipsProvider =
    StreamProvider.family<List<TipEntity>, String>((ref, roomId) {
  return ref
      .watch(monetizationRemoteDataSourceProvider)
      .getRoomTips(roomId)
      .map(
        (tips) => tips.map((t) => t.toEntity()).toList(),
      );
});

/// Stream of tips received by a user
final userReceivedTipsProvider =
    StreamProvider.family<List<TipEntity>, String>((ref, userId) {
  return ref
      .watch(monetizationRemoteDataSourceProvider)
      .getUserReceivedTips(userId)
      .map(
        (tips) => tips.map((t) => t.toEntity()).toList(),
      );
});

/// Stream of tips sent by a user
final userSentTipsProvider =
    StreamProvider.family<List<TipEntity>, String>((ref, userId) {
  return ref
      .watch(monetizationRemoteDataSourceProvider)
      .getUserSentTips(userId)
      .map(
        (tips) => tips.map((t) => t.toEntity()).toList(),
      );
});

/// Check if user has valid ticket for a room
final hasValidTicketProvider = FutureProvider.family<bool, ({String roomId, String userId})>(
    (ref, params) {
  return ref
      .watch(monetizationRemoteDataSourceProvider)
      .hasValidTicket(params.roomId, params.userId);
});

/// State for monetization operations
class MonetizationState {
  final bool isLoading;
  final bool isPurchasing;
  final bool isSendingTip;
  final String? error;
  final CreatorProfileEntity? creatorProfile;
  final Map<String, int>? earnings;

  const MonetizationState({
    this.isLoading = false,
    this.isPurchasing = false,
    this.isSendingTip = false,
    this.error,
    this.creatorProfile,
    this.earnings,
  });

  MonetizationState copyWith({
    bool? isLoading,
    bool? isPurchasing,
    bool? isSendingTip,
    String? error,
    CreatorProfileEntity? creatorProfile,
    Map<String, int>? earnings,
  }) {
    return MonetizationState(
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isSendingTip: isSendingTip ?? this.isSendingTip,
      error: error,
      creatorProfile: creatorProfile ?? this.creatorProfile,
      earnings: earnings ?? this.earnings,
    );
  }
}

/// Notifier for monetization operations
final monetizationNotifierProvider =
    NotifierProvider<MonetizationNotifier, MonetizationState>(
  MonetizationNotifier.new,
);

class MonetizationNotifier extends Notifier<MonetizationState> {
  @override
  MonetizationState build() {
    return const MonetizationState();
  }

  /// Purchase a room ticket
  Future<RoomTicketEntity?> purchaseRoomTicket({
    required String roomId,
    required String roomTitle,
    required String sellerId,
    required int priceAmount,
    required String currency,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Check if monetization is enabled
    final settings = ref.read(appSettingsNotifierProvider).valueOrNull;
    if (settings != null && !settings.audioRooms.allowPaidRooms) {
      state = state.copyWith(error: 'Les salons payants sont désactivés');
      return null;
    }

    state = state.copyWith(isPurchasing: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final ticketModel = await dataSource.purchaseRoomTicket(
        roomId: roomId,
        roomTitle: roomTitle,
        buyerId: currentUser.id,
        buyerName: currentUser.displayName ?? 'Utilisateur',
        sellerId: sellerId,
        priceAmount: priceAmount,
        currency: currency,
      );

      state = state.copyWith(isPurchasing: false);
      return ticketModel.toEntity();
    } catch (e) {
      state = state.copyWith(isPurchasing: false, error: e.toString());
      return null;
    }
  }

  /// Send a tip to a speaker
  Future<TipEntity?> sendTip({
    required String roomId,
    required String recipientId,
    required String recipientName,
    required int amount,
    required String currency,
    String? message,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Check if tips are enabled
    final settings = ref.read(appSettingsNotifierProvider).valueOrNull;
    if (settings != null && !settings.audioRooms.allowTips) {
      state = state.copyWith(error: 'Les pourboires sont désactivés');
      return null;
    }

    // Check min/max amounts
    if (settings != null) {
      if (amount < settings.audioRooms.minTipAmount) {
        state = state.copyWith(
          error:
              'Montant minimum: ${settings.audioRooms.minTipAmount ~/ 100} $currency',
        );
        return null;
      }
      if (amount > settings.audioRooms.maxTipAmount) {
        state = state.copyWith(
          error:
              'Montant maximum: ${settings.audioRooms.maxTipAmount ~/ 100} $currency',
        );
        return null;
      }
    }

    state = state.copyWith(isSendingTip: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final tipModel = await dataSource.sendTip(
        roomId: roomId,
        senderId: currentUser.id,
        senderName: currentUser.displayName ?? 'Utilisateur',
        senderPhotoUrl: currentUser.photoUrl,
        recipientId: recipientId,
        recipientName: recipientName,
        amount: amount,
        currency: currency,
        message: message,
      );

      state = state.copyWith(isSendingTip: false);
      return tipModel.toEntity();
    } catch (e) {
      state = state.copyWith(isSendingTip: false, error: e.toString());
      return null;
    }
  }

  /// Get or create creator profile
  Future<CreatorProfileEntity?> getOrCreateCreatorProfile() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final profileModel = await dataSource.getOrCreateCreatorProfile(
        currentUser.id,
        currentUser.displayName ?? 'Utilisateur',
        currentUser.photoUrl,
      );

      final profile = profileModel.toEntity();
      state = state.copyWith(isLoading: false, creatorProfile: profile);
      return profile;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Enable monetization for current user
  Future<bool> enableMonetization() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      await dataSource.enableMonetization(currentUser.id);

      // Refresh creator profile
      await getOrCreateCreatorProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Set subscription price
  Future<bool> setSubscriptionPrice(int price, String currency) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return false;
    }

    // Check min/max prices
    final settings = ref.read(appSettingsNotifierProvider).valueOrNull;
    if (settings != null) {
      if (price < settings.audioRooms.minSubscriptionPrice) {
        state = state.copyWith(
          error:
              'Prix minimum: ${settings.audioRooms.minSubscriptionPrice ~/ 100} $currency',
        );
        return false;
      }
      if (price > settings.audioRooms.maxSubscriptionPrice) {
        state = state.copyWith(
          error:
              'Prix maximum: ${settings.audioRooms.maxSubscriptionPrice ~/ 100} $currency',
        );
        return false;
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      await dataSource.setSubscriptionPrice(currentUser.id, price, currency);

      // Refresh creator profile
      await getOrCreateCreatorProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Get creator earnings
  Future<Map<String, int>?> getCreatorEarnings() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final earnings = await dataSource.getCreatorEarnings(currentUser.id);

      state = state.copyWith(isLoading: false, earnings: earnings);
      return earnings;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for predefined tip amounts based on currency
final predefinedTipAmountsProvider =
    Provider.family<List<int>, String>((ref, currency) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  if (settings == null) {
    // Default amounts based on currency (USD is the reference)
    return switch (currency.toUpperCase()) {
      'USD' => [100, 200, 500, 1000, 2500],
      'EUR' => [100, 200, 500, 1000, 2300],
      'GBP' => [100, 200, 400, 800, 2000],
      'CAD' => [150, 300, 700, 1400, 3500],
      'CHF' => [100, 200, 500, 900, 2200],
      _ => [50000, 100000, 300000, 600000, 1500000], // XOF
    };
  }
  return settings.audioRooms.getPredefinedTipAmounts(currency);
});

/// Provider for audio rooms settings
final audioRoomsSettingsProvider =
    Provider<AsyncValue<AudioRoomsSettingsEntity?>>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider);
  return settings.whenData((s) => s.audioRooms);
});

/// Provider for supported payout currencies
final supportedPayoutCurrenciesProvider = Provider<List<String>>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.supportedPayoutCurrencies ??
      ['XOF', 'EUR', 'USD', 'GBP', 'CAD', 'CHF'];
});

/// Provider for default payout currency
final defaultPayoutCurrencyProvider = Provider<String>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.defaultPayoutCurrency ?? 'XOF';
});

/// Provider for minimum payout amount for a currency
final minPayoutAmountProvider =
    Provider.family<int, String>((ref, currency) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.getMinPayoutAmount(currency) ??
      PayoutLimits.getMinimum(currency);
});

/// Provider for maximum payout amount for a currency
final maxPayoutAmountProvider =
    Provider.family<int, String>((ref, currency) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.getMaxPayoutAmount(currency) ??
      PayoutLimits.getMaximum(currency);
});

// =========================================================================
// STRIPE CONNECT & PAYOUTS PROVIDERS
// =========================================================================

/// Stream of creator's payouts
final creatorPayoutsProvider =
    StreamProvider.family<List<PayoutEntity>, String>((ref, userId) {
  return ref
      .watch(monetizationRemoteDataSourceProvider)
      .getCreatorPayouts(userId)
      .map(
        (payouts) => payouts.map((p) => p.toEntity()).toList(),
      );
});

/// State for Stripe Connect operations
class StripeConnectState {
  final bool isLoading;
  final String? error;
  final StripeConnectAccountEntity? account;
  final String? onboardingUrl;
  final String? dashboardUrl;

  const StripeConnectState({
    this.isLoading = false,
    this.error,
    this.account,
    this.onboardingUrl,
    this.dashboardUrl,
  });

  StripeConnectState copyWith({
    bool? isLoading,
    String? error,
    StripeConnectAccountEntity? account,
    String? onboardingUrl,
    String? dashboardUrl,
  }) {
    return StripeConnectState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      account: account ?? this.account,
      onboardingUrl: onboardingUrl ?? this.onboardingUrl,
      dashboardUrl: dashboardUrl ?? this.dashboardUrl,
    );
  }
}

/// Notifier for Stripe Connect operations
final stripeConnectNotifierProvider =
    NotifierProvider<StripeConnectNotifier, StripeConnectState>(
  StripeConnectNotifier.new,
);

class StripeConnectNotifier extends Notifier<StripeConnectState> {
  @override
  StripeConnectState build() {
    return const StripeConnectState();
  }

  /// Start Stripe Connect onboarding
  Future<String?> startOnboarding() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final url = await dataSource.startConnectOnboarding(
        userId: currentUser.id,
        email: currentUser.email ?? '',
        country: 'NE', // Default to Niger
      );

      state = state.copyWith(isLoading: false, onboardingUrl: url);
      return url;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Continue onboarding (get fresh link)
  Future<String?> continueOnboarding() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final url = await dataSource.getOnboardingLink(currentUser.id);

      state = state.copyWith(isLoading: false, onboardingUrl: url);
      return url;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Get Stripe Express dashboard link
  Future<String?> getDashboardLink() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final url = await dataSource.getDashboardLink(currentUser.id);

      state = state.copyWith(isLoading: false, dashboardUrl: url);
      return url;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Refresh account status
  Future<void> refreshAccountStatus() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final account =
          await dataSource.getConnectAccountStatus(currentUser.id);

      state = state.copyWith(isLoading: false, account: account);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// State for payout operations
class PayoutState {
  final bool isLoading;
  final bool isRequesting;
  final String? error;
  final PayoutEntity? lastPayout;

  const PayoutState({
    this.isLoading = false,
    this.isRequesting = false,
    this.error,
    this.lastPayout,
  });

  PayoutState copyWith({
    bool? isLoading,
    bool? isRequesting,
    String? error,
    PayoutEntity? lastPayout,
  }) {
    return PayoutState(
      isLoading: isLoading ?? this.isLoading,
      isRequesting: isRequesting ?? this.isRequesting,
      error: error,
      lastPayout: lastPayout ?? this.lastPayout,
    );
  }
}

/// Notifier for payout operations
final payoutNotifierProvider =
    NotifierProvider<PayoutNotifier, PayoutState>(
  PayoutNotifier.new,
);

class PayoutNotifier extends Notifier<PayoutState> {
  @override
  PayoutState build() {
    return const PayoutState();
  }

  /// Request a payout
  Future<PayoutEntity?> requestPayout({
    required int amount,
    required String currency,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Get configurable limits from settings
    final settings = ref.read(appSettingsNotifierProvider).valueOrNull;
    final audioSettings =
        settings?.audioRooms ?? const AudioRoomsSettingsEntity();

    // Check if currency is supported
    if (!audioSettings.isPayoutCurrencySupported(currency)) {
      state = state.copyWith(
        error: 'Devise non supportée pour les retraits: $currency',
      );
      return null;
    }

    // Validate amount is within limits
    final minAmount = audioSettings.getMinPayoutAmount(currency);
    final maxAmount = audioSettings.getMaxPayoutAmount(currency);

    if (amount < minAmount) {
      state = state.copyWith(
        error: 'Montant minimum: ${minAmount ~/ 100} $currency',
      );
      return null;
    }

    if (amount > maxAmount) {
      state = state.copyWith(
        error: 'Montant maximum: ${maxAmount ~/ 100} $currency',
      );
      return null;
    }

    state = state.copyWith(isRequesting: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      final payoutModel = await dataSource.requestPayout(
        userId: currentUser.id,
        amount: amount,
        currency: currency,
      );

      final payout = payoutModel.toEntity();
      state = state.copyWith(isRequesting: false, lastPayout: payout);
      return payout;
    } catch (e) {
      state = state.copyWith(isRequesting: false, error: e.toString());
      return null;
    }
  }

  /// Cancel a pending payout
  Future<bool> cancelPayout(String payoutId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dataSource = ref.read(monetizationRemoteDataSourceProvider);
      await dataSource.cancelPayout(payoutId);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
