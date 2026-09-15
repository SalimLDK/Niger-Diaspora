import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_request_entity.freezed.dart';

/// Les quatre valeurs que `friend_requests.status` prend reellement en base.
///
/// `cancelled` manquait, alors que `cancelFriendRequest` l'ecrit depuis
/// toujours : le `default` du parseur le rendait donc comme **`pending`**. Le
/// defaut restait latent — les flux filtrent `status == 'pending'` cote
/// serveur, donc un document annule n'atteignait jamais le parseur — mais
/// `getRequestById`, lui, lisait une demande annulee comme en attente.
enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled,
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
