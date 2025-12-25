import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/friend_entity.dart';

part 'friend_model.freezed.dart';
part 'friend_model.g.dart';

@freezed
class FriendModel with _$FriendModel {
  const FriendModel._();

  const factory FriendModel({
    required String id,
    required String displayName,
    String? photoUrl,
    required DateTime addedAt,
  }) = _FriendModel;

  factory FriendModel.fromJson(Map<String, dynamic> json) =>
      _$FriendModelFromJson(json);

  FriendEntity toEntity() => FriendEntity(
        id: id,
        displayName: displayName,
        photoUrl: photoUrl,
        addedAt: addedAt,
      );

  static FriendModel fromEntity(FriendEntity entity) => FriendModel(
        id: entity.id,
        displayName: entity.displayName,
        photoUrl: entity.photoUrl,
        addedAt: entity.addedAt,
      );
}
