import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/payment_account_supabase_datasource.dart';
import '../../domain/entities/payment_account_entity.dart';

final paymentAccountDatasourceProvider = Provider<PaymentAccountSupabaseDatasource>((ref) {
  return PaymentAccountSupabaseDatasource();
});

/// Stream of all payment accounts for a user
final paymentAccountsProvider =
    StreamProvider.family<List<PaymentAccountEntity>, String>((ref, userId) {
  final datasource = ref.watch(paymentAccountDatasourceProvider);
  return datasource.watchAccounts(userId);
});

/// Default payment account for a user
final defaultPaymentAccountProvider =
    FutureProvider.family<PaymentAccountEntity?, String>((ref, userId) async {
  final datasource = ref.watch(paymentAccountDatasourceProvider);
  return datasource.getDefaultAccount(userId);
});

/// Notifier for payment account CRUD operations
final paymentAccountNotifierProvider =
    AsyncNotifierProvider<PaymentAccountNotifier, void>(
  PaymentAccountNotifier.new,
);

class PaymentAccountNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<PaymentAccountEntity?> addAccount(PaymentAccountEntity account) async {
    state = const AsyncLoading();
    try {
      final datasource = ref.read(paymentAccountDatasourceProvider);
      final created = await datasource.addAccount(account);
      // Invalidate the list to refresh
      ref.invalidate(paymentAccountsProvider(account.userId));
      ref.invalidate(defaultPaymentAccountProvider(account.userId));
      state = const AsyncData(null);
      return created;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> updateAccount(PaymentAccountEntity account) async {
    state = const AsyncLoading();
    try {
      final datasource = ref.read(paymentAccountDatasourceProvider);
      await datasource.updateAccount(account);
      ref.invalidate(paymentAccountsProvider(account.userId));
      ref.invalidate(defaultPaymentAccountProvider(account.userId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteAccount(String userId, String accountId) async {
    state = const AsyncLoading();
    try {
      final datasource = ref.read(paymentAccountDatasourceProvider);
      await datasource.deleteAccount(userId, accountId);
      ref.invalidate(paymentAccountsProvider(userId));
      ref.invalidate(defaultPaymentAccountProvider(userId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> setDefault(String userId, String accountId) async {
    state = const AsyncLoading();
    try {
      final datasource = ref.read(paymentAccountDatasourceProvider);
      await datasource.setDefault(userId, accountId);
      ref.invalidate(paymentAccountsProvider(userId));
      ref.invalidate(defaultPaymentAccountProvider(userId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
