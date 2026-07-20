import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/payout_entity.dart';
import '../models/creator_profile_model.dart';
import '../models/payout_model.dart';
import '../models/room_ticket_model.dart';
import '../models/tip_model.dart';
import 'monetization_remote_datasource.dart';

class MonetizationSupabaseDataSource implements MonetizationRemoteDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // TICKETS
  // ---------------------------------------------------------------------------

  @override
  Future<RoomTicketModel> purchaseRoomTicket({
    required String roomId,
    required String roomTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required int priceAmount,
    required String currency,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'purchase-room-ticket',
        body: {
          'room_id': roomId,
          'room_title': roomTitle,
          'seller_id': sellerId,
          'price_amount': priceAmount,
          'currency': currency,
        },
      );

      if (response.status != 200) {
        throw Exception('purchaseRoomTicket failed: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      return RoomTicketModel(
        id: data['ticket_id'] as String? ?? '',
        roomId: roomId,
        roomTitle: roomTitle,
        buyerId: buyerId,
        buyerName: buyerName,
        sellerId: sellerId,
        priceAmount: priceAmount,
        currency: currency,
        status: data['status'] as String? ?? 'pending',
        stripePaymentIntentId: data['payment_intent_id'] as String?,
        commissionAmount: data['commission_amount'] as int? ?? 0,
        sellerAmount: data['seller_amount'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error purchasing ticket: $e');
      rethrow;
    }
  }

  @override
  Future<bool> hasValidTicket(String roomId, String userId) async {
    try {
      final result = await _supabase
          .from('room_tickets')
          .select('id')
          .eq('room_id', roomId)
          .eq('user_id', userId)
          .inFilter('status', ['completed', 'active'])
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error checking ticket: $e');
      return false;
    }
  }

  @override
  Stream<List<RoomTicketModel>> getUserTickets(String userId) {
    return _supabase
        .from('room_tickets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) {
              return RoomTicketModel(
                id: row['id'] as String? ?? '',
                roomId: row['room_id'] as String? ?? '',
                roomTitle: row['room_title'] as String? ?? '',
                buyerId: row['user_id'] as String? ?? '',
                buyerName: '',
                sellerId: row['seller_id'] as String? ?? '',
                priceAmount: (row['amount'] as num?)?.toInt() ?? 0,
                currency: row['currency'] as String? ?? 'XOF',
                status: row['status'] as String? ?? 'pending',
                purchasedAt: row['created_at'] as String?,
                stripePaymentIntentId: row['stripe_payment_intent_id'] as String?,
                commissionAmount: 0,
                sellerAmount: (row['amount'] as num?)?.toInt() ?? 0,
              );
            }).toList(),
        );
  }

  @override
  Future<void> markTicketUsed(String ticketId) async {
    try {
      await _supabase
          .from('room_tickets')
          .update({'status': 'used'}).eq('id', ticketId);
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error marking ticket used: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // TIPS
  // ---------------------------------------------------------------------------

  @override
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
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-tip',
        body: {
          'room_id': roomId,
          'recipient_id': recipientId,
          'amount': amount,
          'currency': currency,
          if (message != null) 'message': message,
        },
      );

      if (response.status != 200) {
        throw Exception('sendTip failed: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      return TipModel(
        id: data['tip_id'] as String? ?? '',
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        recipientId: recipientId,
        recipientName: recipientName,
        amount: amount,
        currency: currency,
        status: data['status'] as String? ?? 'pending',
        message: message,
        stripePaymentIntentId: data['payment_intent_id'] as String?,
        commissionAmount: data['commission_amount'] as int? ?? 0,
        recipientAmount: data['recipient_amount'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error sending tip: $e');
      rethrow;
    }
  }

  @override
  Stream<List<TipModel>> getRoomTips(String roomId) {
    return _supabase
        .from('tips')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_tipFromRow).toList());
  }

  @override
  Stream<List<TipModel>> getUserReceivedTips(String userId) {
    return _supabase
        .from('tips')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_tipFromRow).toList());
  }

  @override
  Stream<List<TipModel>> getUserSentTips(String userId) {
    return _supabase
        .from('tips')
        .stream(primaryKey: ['id'])
        .eq('sender_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_tipFromRow).toList());
  }

  TipModel _tipFromRow(Map<String, dynamic> row) {
    return TipModel(
      id: row['id'] as String? ?? '',
      roomId: row['room_id'] as String? ?? '',
      senderId: row['sender_id'] as String? ?? '',
      senderName: '',
      recipientId: row['recipient_id'] as String? ?? '',
      recipientName: '',
      amount: (row['amount'] as num?)?.toInt() ?? 0,
      currency: row['currency'] as String? ?? 'XOF',
      status: row['status'] as String? ?? 'pending',
      sentAt: row['created_at'] as String?,
      stripePaymentIntentId: row['stripe_payment_intent_id'] as String?,
      commissionAmount: 0,
      recipientAmount: (row['amount'] as num?)?.toInt() ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // CREATOR PROFILES
  // ---------------------------------------------------------------------------

  @override
  Future<CreatorProfileModel> getOrCreateCreatorProfile(
    String userId,
    String displayName,
    String? photoUrl,
  ) async {
    try {
      final existing = await _supabase
          .from('creator_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return _creatorFromRow(existing, displayName, photoUrl);
      }

      final inserted = await _supabase
          .from('creator_profiles')
          .insert({'user_id': userId})
          .select()
          .single();

      return _creatorFromRow(inserted, displayName, photoUrl);
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error getting creator profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateCreatorProfile(CreatorProfileModel profile) async {
    try {
      await _supabase.from('creator_profiles').upsert({
        'user_id': profile.userId,
        if (profile.stripeAccountId != null)
          'stripe_account_id': profile.stripeAccountId,
        'payout_enabled': profile.isStripeAccountComplete,
      });
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error updating creator profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> enableMonetization(String userId) async {
    try {
      await _supabase.from('creator_profiles').upsert({'user_id': userId});
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error enabling monetization: $e');
      rethrow;
    }
  }

  @override
  Future<void> setSubscriptionPrice(
    String userId,
    int price,
    String currency,
  ) async {
    // Subscription price is managed per-podcast; no-op here
  }

  @override
  Future<Map<String, int>> getCreatorEarnings(String userId) async {
    try {
      final row = await _supabase
          .from('creator_profiles')
          .select('total_earnings, pending_payout')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return {'total': 0, 'pending': 0, 'available': 0};

      final total = (row['total_earnings'] as num?)?.toInt() ?? 0;
      final pending = (row['pending_payout'] as num?)?.toInt() ?? 0;
      return {
        'total': total,
        'pending': pending,
        'available': total - pending,
      };
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error getting earnings: $e');
      return {'total': 0, 'pending': 0, 'available': 0};
    }
  }

  @override
  Future<void> addAllowedUser(String roomId, String userId) async {
    // Ticket-based access is checked via hasValidTicket; no separate allowlist needed
  }

  // ---------------------------------------------------------------------------
  // STRIPE CONNECT — delegate to Edge Functions
  // ---------------------------------------------------------------------------

  @override
  Future<String?> startConnectOnboarding({
    required String userId,
    required String email,
    required String country,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'stripe-connect-onboarding',
        body: {'country': country},
      );
      if (response.status != 200) return null;
      return (response.data as Map<String, dynamic>)['url'] as String?;
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error starting onboarding: $e');
      return null;
    }
  }

  @override
  Future<String?> getOnboardingLink(String userId) async {
    return startConnectOnboarding(userId: userId, email: '', country: 'FR');
  }

  @override
  Future<String?> getDashboardLink(String userId) async {
    try {
      final response = await _supabase.functions.invoke('stripe-dashboard-link');
      if (response.status != 200) return null;
      return (response.data as Map<String, dynamic>)['url'] as String?;
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error getting dashboard link: $e');
      return null;
    }
  }

  @override
  Future<StripeConnectAccountEntity?> getConnectAccountStatus(
    String userId,
  ) async {
    try {
      final row = await _supabase
          .from('creator_profiles')
          .select('stripe_account_id, stripe_account_status, payout_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null || row['stripe_account_id'] == null) return null;

      final payoutEnabled = row['payout_enabled'] as bool? ?? false;
      final statusStr = row['stripe_account_status'] as String? ?? 'pending';
      final status = payoutEnabled
          ? StripeAccountStatus.enabled
          : statusStr == 'incomplete'
              ? StripeAccountStatus.incomplete
              : StripeAccountStatus.none;

      return StripeConnectAccountEntity(
        accountId: row['stripe_account_id'] as String,
        status: status,
        payoutsEnabled: payoutEnabled,
        chargesEnabled: payoutEnabled,
        detailsSubmitted: payoutEnabled,
        currentlyDue: const [],
        eventuallyDue: const [],
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('MonetizationSupabaseDataSource: Error getting connect status: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PAYOUTS
  // ---------------------------------------------------------------------------

  @override
  Future<PayoutModel> requestPayout({
    required String userId,
    required int amount,
    required String currency,
  }) async {
    throw UnimplementedError(
      'requestPayout: needs a dedicated Edge Function for secure payout processing',
    );
  }

  @override
  Future<void> cancelPayout(String payoutId) async {
    throw UnimplementedError('cancelPayout: not yet implemented in Supabase');
  }

  @override
  Stream<List<PayoutModel>> getCreatorPayouts(String userId) {
    return const Stream.empty();
  }

  @override
  Future<PayoutModel?> getPayout(String payoutId) async {
    return null;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  CreatorProfileModel _creatorFromRow(
    Map<String, dynamic> row,
    String displayName,
    String? photoUrl,
  ) {
    return CreatorProfileModel(
      id: row['user_id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      displayName: displayName,
      photoUrl: photoUrl,
      isMonetizationEnabled: true,
      stripeAccountId: row['stripe_account_id'] as String?,
      isStripeAccountComplete: row['payout_enabled'] as bool? ?? false,
      availableBalance: (row['total_earnings'] as num?)?.toInt() ?? 0,
      createdAt: row['created_at'] as String?,
    );
  }
}
