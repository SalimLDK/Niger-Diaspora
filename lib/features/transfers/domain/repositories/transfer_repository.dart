import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/transaction_entity.dart';
import '../entities/recipient_entity.dart';

abstract class TransferRepository {
  // Transactions
  Future<Either<Failure, List<TransactionEntity>>> getUserTransactions(String userId);
  Future<Either<Failure, TransactionEntity>> getTransaction(String id);
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
  });
  Future<Either<Failure, TransactionEntity>> processPayment(String transactionId);
  Future<Either<Failure, TransactionEntity>> completeTransaction(String transactionId);
  Future<Either<Failure, TransactionEntity>> failTransaction(String transactionId, String reason);
  Stream<List<TransactionEntity>> watchUserTransactions(String userId);
  Stream<TransactionEntity> watchTransaction(String id);

  // Recipients
  Future<Either<Failure, List<RecipientEntity>>> getUserRecipients(String userId);
  Future<Either<Failure, RecipientEntity>> getRecipient(String id);
  Future<Either<Failure, RecipientEntity>> createRecipient(RecipientEntity recipient);
  Future<Either<Failure, RecipientEntity>> updateRecipient(RecipientEntity recipient);
  Future<Either<Failure, void>> deleteRecipient(String id);
  Future<Either<Failure, void>> toggleFavorite(String id, bool isFavorite);
  Stream<List<RecipientEntity>> watchUserRecipients(String userId);

  // Exchange rates & fees
  Future<Either<Failure, double>> getExchangeRate(String fromCurrency, String toCurrency);
  Future<Either<Failure, double>> calculateFee(double amount, String currency);
}
