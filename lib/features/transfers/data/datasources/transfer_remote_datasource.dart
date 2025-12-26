import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../models/transaction_model.dart';
import '../models/recipient_model.dart';

abstract class TransferRemoteDatasource {
  // Transactions
  Future<List<TransactionModel>> getUserTransactions(String userId);
  Future<TransactionModel> getTransaction(String id);
  Future<TransactionModel> createTransaction(TransactionModel transaction);
  Future<TransactionModel> updateTransactionStatus(
      String id, String status, {String? failureReason});
  Stream<List<TransactionModel>> watchUserTransactions(String userId);
  Stream<TransactionModel> watchTransaction(String id);

  // Recipients
  Future<List<RecipientModel>> getUserRecipients(String userId);
  Future<RecipientModel> getRecipient(String id);
  Future<RecipientModel> createRecipient(RecipientModel recipient);
  Future<RecipientModel> updateRecipient(RecipientModel recipient);
  Future<void> deleteRecipient(String id);
  Future<void> toggleFavorite(String id, bool isFavorite);
  Future<void> updateLastUsed(String id);
  Stream<List<RecipientModel>> watchUserRecipients(String userId);
}

class TransferRemoteDatasourceImpl implements TransferRemoteDatasource {
  final FirebaseFirestore _firestore;

  TransferRemoteDatasourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection(FirebaseCollections.transactions);

  CollectionReference<Map<String, dynamic>> get _recipientsCollection =>
      _firestore.collection(FirebaseCollections.recipients);

  // ============ TRANSACTIONS ============

  @override
  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    final snapshot = await _transactionsCollection
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
  }

  @override
  Future<TransactionModel> getTransaction(String id) async {
    final doc = await _transactionsCollection.doc(id).get();
    if (!doc.exists) {
      throw Exception('Transaction non trouvee');
    }
    return TransactionModel.fromFirestore(doc);
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    final docRef = _transactionsCollection.doc();
    final newTransaction = transaction.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
    );
    await docRef.set(newTransaction.toFirestore());
    return newTransaction;
  }

  @override
  Future<TransactionModel> updateTransactionStatus(
    String id,
    String status, {
    String? failureReason,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
    };

    if (status == 'completed') {
      updates['completedAt'] = Timestamp.fromDate(DateTime.now());
    }

    if (failureReason != null) {
      updates['failureReason'] = failureReason;
    }

    await _transactionsCollection.doc(id).update(updates);
    return await getTransaction(id);
  }

  @override
  Stream<List<TransactionModel>> watchUserTransactions(String userId) {
    return _transactionsCollection
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList());
  }

  @override
  Stream<TransactionModel> watchTransaction(String id) {
    return _transactionsCollection
        .doc(id)
        .snapshots()
        .map((doc) => TransactionModel.fromFirestore(doc));
  }

  // ============ RECIPIENTS ============

  @override
  Future<List<RecipientModel>> getUserRecipients(String userId) async {
    final snapshot = await _recipientsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('isFavorite', descending: true)
        .orderBy('lastUsedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => RecipientModel.fromFirestore(doc)).toList();
  }

  @override
  Future<RecipientModel> getRecipient(String id) async {
    final doc = await _recipientsCollection.doc(id).get();
    if (!doc.exists) {
      throw Exception('Beneficiaire non trouve');
    }
    return RecipientModel.fromFirestore(doc);
  }

  @override
  Future<RecipientModel> createRecipient(RecipientModel recipient) async {
    final docRef = _recipientsCollection.doc();
    final newRecipient = recipient.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
    );
    await docRef.set(newRecipient.toFirestore());
    return newRecipient;
  }

  @override
  Future<RecipientModel> updateRecipient(RecipientModel recipient) async {
    await _recipientsCollection.doc(recipient.id).update(recipient.toFirestore());
    return recipient;
  }

  @override
  Future<void> deleteRecipient(String id) async {
    await _recipientsCollection.doc(id).delete();
  }

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await _recipientsCollection.doc(id).update({
      'isFavorite': isFavorite,
    });
  }

  @override
  Future<void> updateLastUsed(String id) async {
    await _recipientsCollection.doc(id).update({
      'lastUsedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Stream<List<RecipientModel>> watchUserRecipients(String userId) {
    return _recipientsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('isFavorite', descending: true)
        .orderBy('lastUsedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RecipientModel.fromFirestore(doc)).toList());
  }
}
