import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/datasources/transfer_remote_datasource.dart';
import '../../data/repositories/transfer_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/recipient_entity.dart';
import '../../domain/repositories/transfer_repository.dart';

part 'transfer_provider.g.dart';

// ============ DATASOURCE & REPOSITORY ============

@riverpod
TransferRemoteDatasource transferRemoteDatasource(Ref ref) {
  return TransferRemoteDatasourceImpl();
}

@riverpod
TransferRepository transferRepository(Ref ref) {
  return TransferRepositoryImpl(
    remoteDatasource: ref.watch(transferRemoteDatasourceProvider),
  );
}

// ============ TRANSACTIONS ============

@riverpod
Future<List<TransactionEntity>> userTransactions(Ref ref, String userId) async {
  final repository = ref.watch(transferRepositoryProvider);
  final result = await repository.getUserTransactions(userId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (transactions) => transactions,
  );
}

@riverpod
Stream<List<TransactionEntity>> watchUserTransactions(Ref ref, String userId) {
  final repository = ref.watch(transferRepositoryProvider);
  return repository.watchUserTransactions(userId);
}

@riverpod
Stream<TransactionEntity> watchTransaction(Ref ref, String transactionId) {
  final repository = ref.watch(transferRepositoryProvider);
  return repository.watchTransaction(transactionId);
}

// ============ RECIPIENTS ============

@riverpod
Future<List<RecipientEntity>> userRecipients(Ref ref, String userId) async {
  final repository = ref.watch(transferRepositoryProvider);
  final result = await repository.getUserRecipients(userId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (recipients) => recipients,
  );
}

@riverpod
Stream<List<RecipientEntity>> watchUserRecipients(Ref ref, String userId) {
  final repository = ref.watch(transferRepositoryProvider);
  return repository.watchUserRecipients(userId);
}

// ============ EXCHANGE RATE ============

@riverpod
Future<double> exchangeRate(
  Ref ref,
  String fromCurrency,
  String toCurrency,
) async {
  final repository = ref.watch(transferRepositoryProvider);
  final result = await repository.getExchangeRate(fromCurrency, toCurrency);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (rate) => rate,
  );
}

@riverpod
Future<double> transferFee(Ref ref, double amount, String currency) async {
  final repository = ref.watch(transferRepositoryProvider);
  final result = await repository.calculateFee(amount, currency);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (fee) => fee,
  );
}

// ============ TRANSACTION NOTIFIER ============

@riverpod
class TransactionNotifier extends _$TransactionNotifier {
  @override
  FutureOr<void> build() {}

  Future<TransactionEntity?> createTransaction({
    required String senderId,
    required String recipientId,
    required String recipientName,
    required String recipientPhone,
    required double amount,
    required String currency,
    required double exchangeRate,
    required double fee,
    String? notes,
    PaymentProvider provider = PaymentProvider.stripe,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(transferRepositoryProvider);

    final result = await repository.createTransaction(
      senderId: senderId,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      amount: amount,
      currency: currency,
      exchangeRate: exchangeRate,
      fee: fee,
      notes: notes,
      provider: provider,
    );

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (transaction) {
        state = const AsyncData(null);
        ref.invalidate(userTransactionsProvider(senderId));
        return transaction;
      },
    );
  }

  Future<bool> processPayment(String transactionId, String userId) async {
    state = const AsyncLoading();
    final repository = ref.read(transferRepositoryProvider);

    final result = await repository.processPayment(transactionId);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(userTransactionsProvider(userId));
        return true;
      },
    );
  }

  Future<bool> completeTransaction(String transactionId, String userId) async {
    state = const AsyncLoading();
    final repository = ref.read(transferRepositoryProvider);

    final result = await repository.completeTransaction(transactionId);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(userTransactionsProvider(userId));
        return true;
      },
    );
  }
}

// ============ RECIPIENT NOTIFIER ============

@riverpod
class RecipientNotifier extends _$RecipientNotifier {
  @override
  FutureOr<void> build() {}

  Future<RecipientEntity?> createRecipient(RecipientEntity recipient) async {
    state = const AsyncLoading();
    final repository = ref.read(transferRepositoryProvider);

    final result = await repository.createRecipient(recipient);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (created) {
        state = const AsyncData(null);
        ref.invalidate(userRecipientsProvider(recipient.userId));
        return created;
      },
    );
  }

  Future<RecipientEntity?> updateRecipient(RecipientEntity recipient) async {
    state = const AsyncLoading();
    final repository = ref.read(transferRepositoryProvider);

    final result = await repository.updateRecipient(recipient);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (updated) {
        state = const AsyncData(null);
        ref.invalidate(userRecipientsProvider(recipient.userId));
        return updated;
      },
    );
  }

  Future<bool> deleteRecipient(String id, String userId) async {
    state = const AsyncLoading();
    final repository = ref.read(transferRepositoryProvider);

    final result = await repository.deleteRecipient(id);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(userRecipientsProvider(userId));
        return true;
      },
    );
  }

  Future<bool> toggleFavorite(String id, bool isFavorite, String userId) async {
    final repository = ref.read(transferRepositoryProvider);
    final result = await repository.toggleFavorite(id, isFavorite);

    return result.fold((failure) => false, (_) {
      ref.invalidate(userRecipientsProvider(userId));
      return true;
    });
  }
}

// ============ SELECTED CURRENCY ============

@riverpod
class SelectedCurrency extends _$SelectedCurrency {
  @override
  String build() => 'EUR';

  void select(String currency) {
    state = currency;
  }
}

// ============ TRANSFER STATE ============

class TransferState {
  final RecipientEntity? selectedRecipient;
  final double amount;
  final String currency;
  final double? exchangeRate;
  final double? fee;
  final String? notes;

  const TransferState({
    this.selectedRecipient,
    this.amount = 0,
    this.currency = 'EUR',
    this.exchangeRate,
    this.fee,
    this.notes,
  });

  TransferState copyWith({
    RecipientEntity? selectedRecipient,
    double? amount,
    String? currency,
    double? exchangeRate,
    double? fee,
    String? notes,
  }) {
    return TransferState(
      selectedRecipient: selectedRecipient ?? this.selectedRecipient,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      fee: fee ?? this.fee,
      notes: notes ?? this.notes,
    );
  }

  double get amountInXof => amount * (exchangeRate ?? 0);
  double get totalCharged => amount + (fee ?? 0);

  bool get isValid =>
      selectedRecipient != null &&
      amount > 0 &&
      exchangeRate != null &&
      fee != null;
}

@riverpod
class TransferStateNotifier extends _$TransferStateNotifier {
  @override
  TransferState build() => const TransferState();

  void selectRecipient(RecipientEntity recipient) {
    state = state.copyWith(selectedRecipient: recipient);
  }

  void setAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  void setCurrency(String currency) {
    state = state.copyWith(currency: currency, exchangeRate: null, fee: null);
  }

  void setExchangeRate(double rate) {
    state = state.copyWith(exchangeRate: rate);
  }

  void setFee(double fee) {
    state = state.copyWith(fee: fee);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void reset() {
    state = const TransferState();
  }
}
