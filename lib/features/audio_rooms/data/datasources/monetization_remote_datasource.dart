// ignore_for_file: invalid_null_aware_operator

import '../../domain/entities/payout_entity.dart';
import '../models/payout_model.dart';
import '../models/room_ticket_model.dart';
import '../models/tip_model.dart';
import '../models/creator_profile_model.dart';

/// Remote data source for audio room monetization
abstract class MonetizationRemoteDataSource {
  /// Purchase a ticket for a paid room
  Future<RoomTicketModel> purchaseRoomTicket({
    required String roomId,
    required String roomTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required int priceAmount,
    required String currency,
  });

  /// Check if user has a valid ticket for a room
  Future<bool> hasValidTicket(String roomId, String userId);

  /// Get user's tickets
  Stream<List<RoomTicketModel>> getUserTickets(String userId);

  /// Mark ticket as used
  Future<void> markTicketUsed(String ticketId);

  /// Send a tip to a speaker
  Future<TipModel> sendTip({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String recipientId,
    required String recipientName,
    required int amount,
    required String currency,
    String? message,
  });

  /// Get tips for a room (live updates for display)
  Stream<List<TipModel>> getRoomTips(String roomId);

  /// Get tips received by a user
  Stream<List<TipModel>> getUserReceivedTips(String userId);

  /// Get tips sent by a user
  Stream<List<TipModel>> getUserSentTips(String userId);

  /// Get or create creator profile
  Future<CreatorProfileModel> getOrCreateCreatorProfile(
    String userId,
    String displayName,
    String? photoUrl,
  );

  /// Update creator profile
  Future<void> updateCreatorProfile(CreatorProfileModel profile);

  /// Enable monetization for a creator
  Future<void> enableMonetization(String userId);

  /// Set subscription price
  Future<void> setSubscriptionPrice(String userId, int price, String currency);

  /// Get creator's total earnings
  Future<Map<String, int>> getCreatorEarnings(String userId);

  /// Add user to room's allowed users (for paid rooms)
  Future<void> addAllowedUser(String roomId, String oderId);

  // =========================================================================
  // STRIPE CONNECT & PAYOUTS
  // =========================================================================

  /// Start Stripe Connect onboarding for a creator
  Future<String?> startConnectOnboarding({
    required String userId,
    required String email,
    required String country,
  });

  /// Get onboarding link to continue setup
  Future<String?> getOnboardingLink(String userId);

  /// Get Stripe Express dashboard link
  Future<String?> getDashboardLink(String userId);

  /// Get creator's Stripe Connect account status
  Future<StripeConnectAccountEntity?> getConnectAccountStatus(String userId);

  /// Request a payout
  Future<PayoutModel> requestPayout({
    required String userId,
    required int amount,
    required String currency,
  });

  /// Cancel a pending payout
  Future<void> cancelPayout(String payoutId);

  /// Get payout history for a creator
  Stream<List<PayoutModel>> getCreatorPayouts(String userId);

  /// Get a single payout
  Future<PayoutModel?> getPayout(String payoutId);
}

/// Implementation of MonetizationRemoteDataSource