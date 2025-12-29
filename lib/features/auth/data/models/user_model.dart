import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastLoginAt,
    @Default(false) bool isAdmin,
    @Default(false) bool isBanned,
    String? banReason,
    @TimestampConverter() DateTime? bannedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert Timestamps to DateTime
    final processedData = <String, dynamic>{'id': doc.id};
    data.forEach((key, value) {
      if (value is Timestamp) {
        processedData[key] = value.toDate();
      } else {
        processedData[key] = value;
      }
    });

    return UserModel.fromJson(processedData);
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      phoneNumber: phoneNumber,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isAdmin: isAdmin,
      isBanned: isBanned,
      banReason: banReason,
      bannedAt: bannedAt,
    );
  }
}

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    return date != null ? Timestamp.fromDate(date) : null;
  }
}
