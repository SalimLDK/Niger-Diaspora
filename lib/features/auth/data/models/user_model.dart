import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';
import '../../../admin/domain/enums/admin_enums.dart';

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
    @AdminRoleConverter() @Default(AdminRole.none) AdminRole adminRole,
    @Default(false) bool isBanned,
    String? banReason,
    @TimestampConverter() DateTime? bannedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper to parse dates from Timestamp or String
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value.toLocal();
      if (value is String) {
        try {
          return DateTime.parse(value).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Process data with migration support
    final processedData = <String, dynamic>{'id': doc.id};

    data.forEach((key, value) {
      if (value is Timestamp) {
        processedData[key] = value.toDate();
      } else if (key.contains('At') && value is String) {
        // Handle date fields stored as String
        processedData[key] = parseDate(value);
      } else {
        processedData[key] = value;
      }
    });

    // Migration: convert old isAdmin boolean to adminRole
    if (processedData['adminRole'] == null && data['isAdmin'] == true) {
      processedData['adminRole'] = AdminRole.superAdmin.name;
    }

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
      adminRole: adminRole,
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
    if (timestamp is DateTime) {
      return timestamp;
    }
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    return date != null ? Timestamp.fromDate(date) : null;
  }
}

class AdminRoleConverter implements JsonConverter<AdminRole, String?> {
  const AdminRoleConverter();

  @override
  AdminRole fromJson(String? json) {
    if (json == null) return AdminRole.none;
    return AdminRole.fromString(json);
  }

  @override
  String? toJson(AdminRole role) {
    return role == AdminRole.none ? null : role.name;
  }
}
