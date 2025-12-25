import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_request_entity.freezed.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
}

@freezed
class FriendRequestEntity with _$FriendRequestEntity {
  const factory FriendRequestEntity({
    required String id,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
    @Default(FriendRequestStatus.pending) FriendRequestStatus status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _FriendRequestEntity;
}
