import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/encryption_service.dart';
import '../../domain/entities/payment_account_entity.dart';
import '../models/payment_account_model.dart';

class PaymentAccountSupabaseDatasource {
  final EncryptionService _encryption;

  PaymentAccountSupabaseDatasource({
    EncryptionService? encryption,
  }) : _encryption = encryption ?? EncryptionService.instance;

  SupabaseClient get _supabase => Supabase.instance.client;

  PaymentAccountEntity _fromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );

    // Decrypt sensitive fields stored in the JSONB data blob
    final mobileNumber = _decryptField(data['mobileNumber']);
    final iban = _decryptField(data['iban']);
    final bic = _decryptField(data['bic']);

    return PaymentAccountEntity(
      id: row['id'].toString(),
      userId: row['user_id'] as String? ?? '',
      type: PaymentAccountType.values.firstWhere(
        (e) => e.name == (row['type'] as String? ?? ''),
        orElse: () => PaymentAccountType.bankAccount,
      ),
      label: row['label'] as String? ?? '',
      isDefault: row['is_default'] as bool? ?? false,
      mobileProvider: data['mobileProvider'] != null
          ? MobileProvider.values.firstWhere(
              (e) => e.name == data['mobileProvider'],
              orElse: () => MobileProvider.orangeMoney,
            )
          : null,
      mobileNumber: mobileNumber,
      bankName: data['bankName'] as String?,
      accountHolderName: data['accountHolderName'] as String?,
      iban: iban,
      bic: bic,
      stripeAccountId: data['stripeAccountId'] as String?,
      stripeAccountStatus: data['stripeAccountStatus'] as String?,
      maskedNumber: data['maskedNumber'] as String?,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }

  Map<String, dynamic> _toData(PaymentAccountEntity account) {
    final model = PaymentAccountModel.fromEntity(account);
    return {
      if (model.mobileProvider != null) 'mobileProvider': model.mobileProvider,
      if (model.mobileNumber != null)
        'mobileNumber': _encryption.encryptText(model.mobileNumber!),
      if (model.bankName != null) 'bankName': model.bankName,
      if (model.accountHolderName != null)
        'accountHolderName': model.accountHolderName,
      if (model.iban != null) 'iban': _encryption.encryptText(model.iban!),
      if (model.bic != null) 'bic': _encryption.encryptText(model.bic!),
      if (model.stripeAccountId != null)
        'stripeAccountId': model.stripeAccountId,
      if (model.stripeAccountStatus != null)
        'stripeAccountStatus': model.stripeAccountStatus,
      if (model.maskedNumber != null) 'maskedNumber': model.maskedNumber,
    };
  }

  String? _decryptField(dynamic value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    return _encryption.decryptText(value);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  /// Stream all payment accounts for a user (real-time)
  Stream<List<PaymentAccountEntity>> watchAccounts(String userId) {
    return _supabase
        .from('payment_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_fromRow).toList());
  }

  /// Get all payment accounts for a user (one-time)
  Future<List<PaymentAccountEntity>> getAccounts(String userId) async {
    final rows = await _supabase
        .from('payment_accounts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  /// Get default payment account
  Future<PaymentAccountEntity?> getDefaultAccount(String userId) async {
    final row = await _supabase
        .from('payment_accounts')
        .select()
        .eq('user_id', userId)
        .eq('is_default', true)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Add a new payment account
  Future<PaymentAccountEntity> addAccount(PaymentAccountEntity account) async {
    if (account.isDefault) {
      await _clearDefaultFlag(account.userId);
    } else {
      // Auto-set as default if it's the first account
      final existing = await _supabase
          .from('payment_accounts')
          .select('id')
          .eq('user_id', account.userId)
          .limit(1);
      if ((existing as List).isEmpty) {
        // Will be set as default below
      }
    }

    final isDefault = account.isDefault ||
        (await _supabase
                .from('payment_accounts')
                .select('id')
                .eq('user_id', account.userId)
                .limit(1) as List)
            .isEmpty;

    final row = await _supabase
        .from('payment_accounts')
        .insert({
          'user_id': account.userId,
          'type': account.type.name,
          'label': account.label,
          'is_default': isDefault,
          'data': _toData(account),
        })
        .select()
        .single();

    return _fromRow(row);
  }

  /// Update an existing payment account
  Future<void> updateAccount(PaymentAccountEntity account) async {
    if (account.isDefault) {
      await _clearDefaultFlag(account.userId);
    }

    await _supabase.from('payment_accounts').update({
      'type': account.type.name,
      'label': account.label,
      'is_default': account.isDefault,
      'data': _toData(account),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', account.id);
  }

  /// Delete a payment account
  Future<void> deleteAccount(String userId, String accountId) async {
    await _supabase
        .from('payment_accounts')
        .delete()
        .eq('id', accountId)
        .eq('user_id', userId);
  }

  /// Set a specific account as default
  Future<void> setDefault(String userId, String accountId) async {
    await _clearDefaultFlag(userId);
    await _supabase
        .from('payment_accounts')
        .update({'is_default': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', accountId)
        .eq('user_id', userId);
  }

  /// Clear the default flag on all accounts for a user
  Future<void> _clearDefaultFlag(String userId) async {
    await _supabase
        .from('payment_accounts')
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_default', true);
  }
}
