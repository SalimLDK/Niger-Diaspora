import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/blocked_user_entity.dart';

part 'blocked_user_model.freezed.dart';
part 'blocked_user_model.g.dart';

@freezed
class BlockedUserModel with _$BlockedUserModel {
  const BlockedUserModel._();

  const factory BlockedUserModel({
    required String id,
    required String displayName,
    String? photoUrl,
    required DateTime blockedAt,
  }) = _BlockedUserModel;

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) =>
      _$BlockedUserModelFromJson(json);

  BlockedUserEntity toEntity() => BlockedUserEntity(
        id: id,
        displayName: displayName,
        photoUrl: photoUrl,
        blockedAt: blockedAt,
      );

  static BlockedUserModel fromEntity(BlockedUserEntity entity) =>
      BlockedUserModel(
        id: entity.id,
        displayName: entity.displayName,
        photoUrl: entity.photoUrl,
        blockedAt: entity.blockedAt,
      );
}
