import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_entity.freezed.dart';

@freezed
class FriendEntity with _$FriendEntity {
  const factory FriendEntity({
    required String id,
    required String displayName,
    String? photoUrl,
    required DateTime addedAt,
  }) = _FriendEntity;
}
