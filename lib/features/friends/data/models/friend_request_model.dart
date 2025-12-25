import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/friend_request_entity.dart';

part 'friend_request_model.freezed.dart';
part 'friend_request_model.g.dart';

@freezed
class FriendRequestModel with _$FriendRequestModel {
  const FriendRequestModel._();

  const factory FriendRequestModel({
    required String id,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
    @Default('pending') String status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _FriendRequestModel;

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestModelFromJson(json);

  FriendRequestEntity toEntity() => FriendRequestEntity(
        id: id,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
        status: _parseStatus(status),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static FriendRequestStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'declined':
        return FriendRequestStatus.declined;
      default:
        return FriendRequestStatus.pending;
    }
  }

  static FriendRequestModel fromEntity(FriendRequestEntity entity) =>
      FriendRequestModel(
        id: entity.id,
        senderId: entity.senderId,
        senderName: entity.senderName,
        senderPhotoUrl: entity.senderPhotoUrl,
        receiverId: entity.receiverId,
        receiverName: entity.receiverName,
        receiverPhotoUrl: entity.receiverPhotoUrl,
        status: entity.status.name,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
