
import '../../../../core/services/encryption_service.dart';
import '../../domain/entities/payment_account_entity.dart';

class PaymentAccountModel {
  final String id;
  final String userId;
  final String type;
  final String label;
  final bool isDefault;
  final String? mobileProvider;
  final String? mobileNumber;
  final String? bankName;
  final String? accountHolderName;
  final String? iban;
  final String? bic;
  final String? stripeAccountId;
  final String? stripeAccountStatus;
  final String? maskedNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentAccountModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.label,
    this.isDefault = false,
    this.mobileProvider,
    this.mobileNumber,
    this.bankName,
    this.accountHolderName,
    this.iban,
    this.bic,
    this.stripeAccountId,
    this.stripeAccountStatus,
    this.maskedNumber,
    this.createdAt,
    this.updatedAt,
  });
  Map<String, dynamic> toFirestore(EncryptionService encryption) {
    return {
      'userId': userId,
      'type': type,
      'label': label,
      'isDefault': isDefault,
      if (mobileProvider != null) 'mobileProvider': mobileProvider,
      if (mobileNumber != null)
        'mobileNumber': encryption.encryptText(mobileNumber!),
      if (bankName != null) 'bankName': bankName,
      if (accountHolderName != null) 'accountHolderName': accountHolderName,
      if (iban != null) 'iban': encryption.encryptText(iban!),
      if (bic != null) 'bic': encryption.encryptText(bic!),
      if (stripeAccountId != null) 'stripeAccountId': stripeAccountId,
      if (stripeAccountStatus != null)
        'stripeAccountStatus': stripeAccountStatus,
      if (maskedNumber != null) 'maskedNumber': maskedNumber,
      'createdAt': createdAt != null
          ? createdAt!.toUtc().toIso8601String()
          : DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'serverEncrypted': false,
    };
  }

  factory PaymentAccountModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String) return DateTime.tryParse(v)?.toLocal();
      if (v is DateTime) return v.toLocal();
      return null;
    }
    return PaymentAccountModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'bankAccount',
      label: json['label'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
      mobileProvider: json['mobileProvider'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      bankName: json['bankName'] as String?,
      accountHolderName: json['accountHolderName'] as String?,
      iban: json['iban'] as String?,
      bic: json['bic'] as String?,
      stripeAccountId: json['stripeAccountId'] as String?,
      stripeAccountStatus: json['stripeAccountStatus'] as String?,
      maskedNumber: json['maskedNumber'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  factory PaymentAccountModel.fromEntity(PaymentAccountEntity entity) {
    return PaymentAccountModel(
      id: entity.id,
      userId: entity.userId,
      type: entity.type.name,
      label: entity.label,
      isDefault: entity.isDefault,
      mobileProvider: entity.mobileProvider?.name,
      mobileNumber: entity.mobileNumber,
      bankName: entity.bankName,
      accountHolderName: entity.accountHolderName,
      iban: entity.iban,
      bic: entity.bic,
      stripeAccountId: entity.stripeAccountId,
      stripeAccountStatus: entity.stripeAccountStatus,
      maskedNumber: entity.maskedNumber,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  PaymentAccountEntity toEntity() {
    return PaymentAccountEntity(
      id: id,
      userId: userId,
      type: PaymentAccountType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => PaymentAccountType.bankAccount,
      ),
      label: label,
      isDefault: isDefault,
      mobileProvider: mobileProvider != null
          ? MobileProvider.values.firstWhere(
              (e) => e.name == mobileProvider,
              orElse: () => MobileProvider.orangeMoney,
            )
          : null,
      mobileNumber: mobileNumber,
      bankName: bankName,
      accountHolderName: accountHolderName,
      iban: iban,
      bic: bic,
      stripeAccountId: stripeAccountId,
      stripeAccountStatus: stripeAccountStatus,
      maskedNumber: maskedNumber,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
