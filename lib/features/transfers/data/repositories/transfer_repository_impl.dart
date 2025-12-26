import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/recipient_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer_remote_datasource.dart';
import '../models/transaction_model.dart';
import '../models/recipient_model.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDatasource _remoteDatasource;

  // Fee configuration (can be moved to remote config)
  static const double _feePercentage = 0.025; // 2.5%
  static const double _minimumFee = 500; // 500 XOF minimum
  static const double _maximumFee = 10000; // 10000 XOF maximum

  // Default exchange rates (should come from API in production)
  static const Map<String, double> _exchangeRates = {
    'EUR_XOF': 655.957,
    'USD_XOF': 610.0,
    'GBP_XOF': 770.0,
  };

  TransferRepositoryImpl({required TransferRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  // ============ TRANSACTIONS ============

  @override
  Future<Either<Failure, List<TransactionEntity>>> getUserTransactions(
      String userId) async {
    try {
      final transactions = await _remoteDatasource.getUserTransactions(userId);
      return Right(transactions.map((t) => t.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> getTransaction(String id) async {
    try {
      final transaction = await _remoteDatasource.getTransaction(id);
      return Right(transaction.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> createTransaction({
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
    try {
      final amountInXof = amount * exchangeRate;
      final totalCharged = amount + fee;

      final transaction = TransactionModel(
        id: '',
        senderId: senderId,
        recipientId: recipientId,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
        amount: amount,
        currency: currency,
        exchangeRate: exchangeRate,
        amountInXof: amountInXof,
        fee: fee,
        totalCharged: totalCharged,
        status: 'pending',
        provider: provider.name,
        notes: notes,
      );

      final created = await _remoteDatasource.createTransaction(transaction);

      // Update recipient last used
      await _remoteDatasource.updateLastUsed(recipientId);

      return Right(created.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> processPayment(
      String transactionId) async {
    try {
      final transaction = await _remoteDatasource.updateTransactionStatus(
        transactionId,
        'processing',
      );
      return Right(transaction.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> completeTransaction(
      String transactionId) async {
    try {
      final transaction = await _remoteDatasource.updateTransactionStatus(
        transactionId,
        'completed',
      );
      return Right(transaction.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> failTransaction(
      String transactionId, String reason) async {
    try {
      final transaction = await _remoteDatasource.updateTransactionStatus(
        transactionId,
        'failed',
        failureReason: reason,
      );
      return Right(transaction.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<TransactionEntity>> watchUserTransactions(String userId) {
    return _remoteDatasource
        .watchUserTransactions(userId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<TransactionEntity> watchTransaction(String id) {
    return _remoteDatasource
        .watchTransaction(id)
        .map((model) => model.toEntity());
  }

  // ============ RECIPIENTS ============

  @override
  Future<Either<Failure, List<RecipientEntity>>> getUserRecipients(
      String userId) async {
    try {
      final recipients = await _remoteDatasource.getUserRecipients(userId);
      return Right(recipients.map((r) => r.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RecipientEntity>> getRecipient(String id) async {
    try {
      final recipient = await _remoteDatasource.getRecipient(id);
      return Right(recipient.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RecipientEntity>> createRecipient(
      RecipientEntity recipient) async {
    try {
      final model = RecipientModel.fromEntity(recipient);
      final created = await _remoteDatasource.createRecipient(model);
      return Right(created.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RecipientEntity>> updateRecipient(
      RecipientEntity recipient) async {
    try {
      final model = RecipientModel.fromEntity(recipient);
      final updated = await _remoteDatasource.updateRecipient(model);
      return Right(updated.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecipient(String id) async {
    try {
      await _remoteDatasource.deleteRecipient(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFavorite(String id, bool isFavorite) async {
    try {
      await _remoteDatasource.toggleFavorite(id, isFavorite);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<RecipientEntity>> watchUserRecipients(String userId) {
    return _remoteDatasource
        .watchUserRecipients(userId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  // ============ EXCHANGE RATES & FEES ============

  @override
  Future<Either<Failure, double>> getExchangeRate(
      String fromCurrency, String toCurrency) async {
    try {
      final key = '${fromCurrency}_$toCurrency';
      final rate = _exchangeRates[key];
      if (rate == null) {
        return Left(ServerFailure('Taux de change non disponible'));
      }
      return Right(rate);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> calculateFee(
      double amount, String currency) async {
    try {
      // Get rate to XOF for fee calculation
      final rateResult = await getExchangeRate(currency, 'XOF');
      return rateResult.fold(
        (failure) => Left(failure),
        (rate) {
          final amountInXof = amount * rate;
          var fee = amountInXof * _feePercentage;

          // Apply min/max
          if (fee < _minimumFee) fee = _minimumFee;
          if (fee > _maximumFee) fee = _maximumFee;

          // Convert back to original currency
          final feeInCurrency = fee / rate;
          return Right(feeInCurrency);
        },
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
