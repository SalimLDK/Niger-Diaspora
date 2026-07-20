enum PaymentAccountType { stripeConnect, mobileMoney, bankAccount }

enum MobileProvider { orangeMoney, moovMoney, airtelMoney, mynita, wave }

class PaymentAccountEntity {
  final String id;
  final String userId;
  final PaymentAccountType type;
  final String label;
  final bool isDefault;

  // Mobile Money
  final MobileProvider? mobileProvider;
  final String? mobileNumber; // stored encrypted

  // Bank Account
  final String? bankName;
  final String? accountHolderName;
  final String? iban; // stored encrypted
  final String? bic; // stored encrypted

  // Stripe Connect
  final String? stripeAccountId;
  final String? stripeAccountStatus;

  // Display only (never encrypted)
  final String? maskedNumber; // e.g. "•••• 1234"

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentAccountEntity({
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

  PaymentAccountEntity copyWith({
    String? id,
    String? userId,
    PaymentAccountType? type,
    String? label,
    bool? isDefault,
    MobileProvider? mobileProvider,
    String? mobileNumber,
    String? bankName,
    String? accountHolderName,
    String? iban,
    String? bic,
    String? stripeAccountId,
    String? stripeAccountStatus,
    String? maskedNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentAccountEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      mobileProvider: mobileProvider ?? this.mobileProvider,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      stripeAccountStatus: stripeAccountStatus ?? this.stripeAccountStatus,
      maskedNumber: maskedNumber ?? this.maskedNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generates a masked version of the sensitive number for display
  static String maskNumber(String number) {
    if (number.length <= 4) return number;
    final last4 = number.substring(number.length - 4);
    return '•••• $last4';
  }

  String get displayType {
    return switch (type) {
      PaymentAccountType.stripeConnect => 'Stripe Connect',
      PaymentAccountType.mobileMoney => _mobileProviderLabel,
      PaymentAccountType.bankAccount => 'Compte bancaire',
    };
  }

  String get _mobileProviderLabel {
    return switch (mobileProvider) {
      MobileProvider.orangeMoney => 'Orange Money',
      MobileProvider.moovMoney => 'Moov Money',
      MobileProvider.airtelMoney => 'Airtel Money',
      MobileProvider.mynita => 'Mynita',
      MobileProvider.wave => 'Wave',
      null => 'Mobile Money',
    };
  }
}
