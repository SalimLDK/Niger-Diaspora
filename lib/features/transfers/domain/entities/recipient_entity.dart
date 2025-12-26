import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_entity.freezed.dart';

@freezed
class RecipientEntity with _$RecipientEntity {
  const factory RecipientEntity({
    required String id,
    required String userId,
    required String fullName,
    required String phone,
    String? email,
    @Default(RecipientType.mobileWallet) RecipientType type,
    String? bankName,
    String? bankAccountNumber,
    String? mobileProvider,
    String? city,
    String? address,
    @Default(false) bool isFavorite,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) = _RecipientEntity;
}

enum RecipientType {
  mobileWallet,
  bankAccount,
  cashPickup,
}

extension RecipientTypeExtension on RecipientType {
  String get label {
    switch (this) {
      case RecipientType.mobileWallet:
        return 'Portefeuille mobile';
      case RecipientType.bankAccount:
        return 'Compte bancaire';
      case RecipientType.cashPickup:
        return 'Retrait especes';
    }
  }

  String get description {
    switch (this) {
      case RecipientType.mobileWallet:
        return 'Orange Money, Airtel Money, etc.';
      case RecipientType.bankAccount:
        return 'Virement bancaire direct';
      case RecipientType.cashPickup:
        return 'Retrait dans un point de service';
    }
  }
}
