import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/recipient_entity.dart';

part 'recipient_model.freezed.dart';
part 'recipient_model.g.dart';

@freezed
class RecipientModel with _$RecipientModel {
  const RecipientModel._();

  const factory RecipientModel({
    required String id,
    required String userId,
    required String fullName,
    required String phone,
    String? email,
    @Default('mobileWallet') String type,
    String? bankName,
    String? bankAccountNumber,
    String? mobileProvider,
    String? city,
    String? address,
    @Default(false) bool isFavorite,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastUsedAt,
  }) = _RecipientModel;

  factory RecipientModel.fromJson(Map<String, dynamic> json) =>
      _$RecipientModelFromJson(json);

  factory RecipientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecipientModel.fromJson({
      'id': doc.id,
      ...data,
    });
  }

  factory RecipientModel.fromEntity(RecipientEntity entity) {
    return RecipientModel(
      id: entity.id,
      userId: entity.userId,
      fullName: entity.fullName,
      phone: entity.phone,
      email: entity.email,
      type: entity.type.name,
      bankName: entity.bankName,
      bankAccountNumber: entity.bankAccountNumber,
      mobileProvider: entity.mobileProvider,
      city: entity.city,
      address: entity.address,
      isFavorite: entity.isFavorite,
      createdAt: entity.createdAt,
      lastUsedAt: entity.lastUsedAt,
    );
  }

  RecipientEntity toEntity() {
    return RecipientEntity(
      id: id,
      userId: userId,
      fullName: fullName,
      phone: phone,
      email: email,
      type: RecipientType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => RecipientType.mobileWallet,
      ),
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      mobileProvider: mobileProvider,
      city: city,
      address: address,
      isFavorite: isFavorite,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
