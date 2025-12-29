import 'package:dartz/dartz.dart';
// import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/recipient_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer_remote_datasource.dart';
import '../models/transaction_model.dart';
import '../models/recipient_model.dart';

/// Configuration for transfer fees
class TransferFeeConfig {
  final double feePercentage;
  final double minimumFee;
  final double maximumFee;

  const TransferFeeConfig({
    this.feePercentage = 0.025,
    this.minimumFee = 500,
    this.maximumFee = 10000,
  });
}

/// Configuration for exchange rates
class ExchangeRateConfig {
  final double eurToXof;
  final double usdToXof;
  final double gbpToXof;
  final double cadToXof;
  final double chfToXof;

  const ExchangeRateConfig({
    this.eurToXof = 655.957,
    this.usdToXof = 615.0,
    this.gbpToXof = 770.0,
    this.cadToXof = 455.0,
    this.chfToXof = 690.0,
  });

  double getRate(String fromCurrency, String toCurrency) {
    if (toCurrency != 'XOF') return 1.0;

    return switch (fromCurrency.toUpperCase()) {
      'EUR' => eurToXof,
      'USD' => usdToXof,
      'GBP' => gbpToXof,
      'CAD' => cadToXof,
      'CHF' => chfToXof,
      'XOF' => 1.0,
      _ => 1.0,
    };
  }
}

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDatasource _remoteDatasource;
  final TransferFeeConfig _feeConfig;
  final ExchangeRateConfig _exchangeRateConfig;

  TransferRepositoryImpl({
    required TransferRemoteDatasource remoteDatasource,
    TransferFeeConfig? feeConfig,
    ExchangeRateConfig? exchangeRateConfig,
  }) : _remoteDatasource = remoteDatasource,
       _feeConfig = feeConfig ?? const TransferFeeConfig(),
       _exchangeRateConfig = exchangeRateConfig ?? const ExchangeRateConfig();

  /// Get current fee percentage (for display purposes)
  double get feePercentage => _feeConfig.feePercentage;

  // ============ TRANSACTIONS ============

  @override
  Future<Either<Failure, List<TransactionEntity>>> getUserTransactions(
    String userId,
  ) async {
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
      // Calculate with proper rounding (2 decimal places for currency)
      final amountInXof = ((amount * exchangeRate) * 100).round() / 100;
      final totalCharged = ((amount + fee) * 100).round() / 100;

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
    String transactionId,
  ) async {
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
    String transactionId,
  ) async {
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
    String transactionId,
    String reason,
  ) async {
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
    String userId,
  ) async {
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
    RecipientEntity recipient,
  ) async {
    // debugPrint('🟢 TransferRepository.createRecipient() called');
    try {
      // debugPrint('🟢 Converting entity to model');
      final model = RecipientModel.fromEntity(recipient);
      // debugPrint('🟢 Calling datasource.createRecipient()');
      final created = await _remoteDatasource.createRecipient(model);
      // debugPrint('🟢 Datasource returned, converting to entity');
      final entity = created.toEntity();
      // debugPrint('🟢 Returning Right(entity)');
      return Right(entity);
    } catch (e) {
      // debugPrint('🔴 Error in repository.createRecipient: $e');
      // debugPrint('🔴 Stack trace: ${StackTrace.current}');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RecipientEntity>> updateRecipient(
    RecipientEntity recipient,
  ) async {
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
  Future<Either<Failure, void>> toggleFavorite(
    String id,
    bool isFavorite,
  ) async {
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
    String fromCurrency,
    String toCurrency,
  ) async {
    try {
      final rate = _exchangeRateConfig.getRate(fromCurrency, toCurrency);
      if (rate == 1.0 &&
          fromCurrency.toUpperCase() != toCurrency.toUpperCase()) {
        return Left(ServerFailure('Taux de change non disponible'));
      }
      return Right(rate);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> calculateFee(
    double amount,
    String currency,
  ) async {
    try {
      // Get rate to XOF for fee calculation
      final rateResult = await getExchangeRate(currency, 'XOF');
      return rateResult.fold((failure) => Left(failure), (rate) {
        // Round rate to reasonable precision (4 decimal places for exchange rates)
        final roundedRate = (rate * 10000).round() / 10000;

        // Calculate amount in XOF with proper rounding
        final amountInXof = ((amount * roundedRate) * 100).round() / 100;

        // Calculate fee with proper rounding
        var fee =
            ((amountInXof * _feeConfig.feePercentage) * 100).round() / 100;

        // Apply min/max from config
        if (fee < _feeConfig.minimumFee) fee = _feeConfig.minimumFee;
        if (fee > _feeConfig.maximumFee) fee = _feeConfig.maximumFee;

        // Convert back to original currency with proper rounding
        final feeInCurrency = ((fee / roundedRate) * 100).round() / 100;
        return Right(feeInCurrency);
      });
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
