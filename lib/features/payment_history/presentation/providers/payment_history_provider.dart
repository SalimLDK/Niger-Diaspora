import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/payment_history_item.dart';

/// Filter state for payment history
class PaymentHistoryFilter {
  final PaymentType? type;
  final PaymentStatus? status;

  const PaymentHistoryFilter({this.type, this.status});

  PaymentHistoryFilter copyWith({
    PaymentType? type,
    PaymentStatus? status,
    bool clearType = false,
    bool clearStatus = false,
  }) {
    return PaymentHistoryFilter(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

final paymentHistoryFilterProvider =
    StateProvider<PaymentHistoryFilter>((ref) => const PaymentHistoryFilter());

/// Provides paginated payment history for a user
final paymentHistoryProvider = FutureProvider.family<List<PaymentHistoryItem>, String>(
  (ref, userId) async {
    final filter = ref.watch(paymentHistoryFilterProvider);
    final supabase = Supabase.instance.client;

    // All filter (.eq) calls must come before transform (.order, .limit).
    var filterQuery = supabase
        .from('transactions')
        .select()
        .eq('sender_id', userId);

    if (filter.type != null) {
      filterQuery = filterQuery.eq('type', filter.type!.name);
    }

    if (filter.status != null) {
      filterQuery = filterQuery.eq('status', filter.status!.name);
    }

    final rows = await filterQuery
        .order('createdAt', ascending: false)
        .limit(50);

    return rows.map((row) => PaymentHistoryItem.fromMap(row)).toList();
  },
);
