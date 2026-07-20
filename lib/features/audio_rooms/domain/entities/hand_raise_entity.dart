import 'package:equatable/equatable.dart';

/// Entity representing a hand raise request in an audio room
class HandRaiseEntity extends Equatable {
  /// User ID of the person raising their hand
  final String userId;

  /// Display name of the user
  final String userName;

  /// Photo URL of the user
  final String? photoUrl;

  /// When the hand was raised
  final DateTime raisedAt;

  /// ID of the room where the hand was raised
  final String roomId;

  const HandRaiseEntity({
    required this.userId,
    required this.userName,
    this.photoUrl,
    required this.raisedAt,
    required this.roomId,
  });

  /// How long ago the hand was raised (formatted string)
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(raisedAt);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else {
      return 'Il y a ${difference.inHours} h';
    }
  }

  /// Copy with new values
  HandRaiseEntity copyWith({
    String? userId,
    String? userName,
    String? photoUrl,
    DateTime? raisedAt,
    String? roomId,
  }) {
    return HandRaiseEntity(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      photoUrl: photoUrl ?? this.photoUrl,
      raisedAt: raisedAt ?? this.raisedAt,
      roomId: roomId ?? this.roomId,
    );
  }

  @override
  List<Object?> get props => [userId, roomId, raisedAt];
}
