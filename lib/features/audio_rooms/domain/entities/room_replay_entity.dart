import 'package:equatable/equatable.dart';

/// Status of a room replay
enum RoomReplayStatus {
  /// Recording in progress
  recording,

  /// Processing/encoding
  processing,

  /// Available for playback
  available,

  /// Processing failed
  failed,

  /// Deleted by host
  deleted,
}

/// Entity representing a recorded audio room replay
class RoomReplayEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// ID of the original audio room
  final String roomId;

  /// Title of the room
  final String roomTitle;

  /// Description of the room
  final String? roomDescription;

  /// ID of the host/creator
  final String hostId;

  /// Name of the host
  final String hostName;

  /// Photo URL of the host
  final String? hostPhotoUrl;

  /// URL to the audio file (Firebase Storage)
  final String? audioUrl;

  /// Duration in seconds
  final int durationSeconds;

  /// Status of the replay
  final RoomReplayStatus status;

  /// When the room was recorded
  final DateTime recordedAt;

  /// When processing completed
  final DateTime? processedAt;

  /// Price in cents (0 = free)
  final int price;

  /// Currency code
  final String currency;

  /// List of user IDs who purchased the replay
  final List<String> purchasedByUserIds;

  /// Number of plays
  final int playCount;

  /// Tags for discoverability
  final List<String> tags;

  /// Cover image URL
  final String? coverImageUrl;

  /// Total revenue in cents
  final int totalRevenue;

  /// Media type: 'audio' or 'video'
  final String mediaType;

  /// Video file URL (Firebase Storage), set when isVideoEnabled was true
  final String? videoUrl;

  /// Video thumbnail URL
  final String? videoThumbnailUrl;

  const RoomReplayEntity({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    this.roomDescription,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    this.audioUrl,
    required this.durationSeconds,
    required this.status,
    required this.recordedAt,
    this.processedAt,
    this.price = 0,
    this.currency = 'XOF',
    this.purchasedByUserIds = const [],
    this.playCount = 0,
    this.tags = const [],
    this.coverImageUrl,
    this.totalRevenue = 0,
    this.mediaType = 'audio',
    this.videoUrl,
    this.videoThumbnailUrl,
  });

  /// Calculate commission (15%)
  static int calculateCommission(int amount) => (amount * 0.15).round();

  /// Calculate host amount (85%)
  static int calculateHostAmount(int amount) => amount - calculateCommission(amount);

  /// Whether the replay is free
  bool get isFree => price == 0;

  /// Whether the replay is available
  bool get isAvailable => status == RoomReplayStatus.available;

  /// Whether a user has purchased this replay
  bool hasPurchased(String userId) => purchasedByUserIds.contains(userId);

  /// Whether a user can access this replay (host or purchased)
  bool canAccess(String userId) => hostId == userId || hasPurchased(userId) || isFree;

  /// Format price for display
  String get formattedPrice => isFree ? 'Gratuit' : '${(price / 100).toStringAsFixed(0)} $currency';

  /// Format duration for display (HH:MM:SS or MM:SS)
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Number of purchases
  int get purchaseCount => purchasedByUserIds.length;

  /// Whether this replay has video content
  bool get isVideoReplay => mediaType == 'video' && videoUrl != null;

  RoomReplayEntity copyWith({
    String? id,
    String? roomId,
    String? roomTitle,
    String? roomDescription,
    String? hostId,
    String? hostName,
    String? hostPhotoUrl,
    String? audioUrl,
    int? durationSeconds,
    RoomReplayStatus? status,
    DateTime? recordedAt,
    DateTime? processedAt,
    int? price,
    String? currency,
    List<String>? purchasedByUserIds,
    int? playCount,
    List<String>? tags,
    String? coverImageUrl,
    int? totalRevenue,
    String? mediaType,
    String? videoUrl,
    String? videoThumbnailUrl,
  }) {
    return RoomReplayEntity(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      roomDescription: roomDescription ?? this.roomDescription,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      recordedAt: recordedAt ?? this.recordedAt,
      processedAt: processedAt ?? this.processedAt,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      purchasedByUserIds: purchasedByUserIds ?? this.purchasedByUserIds,
      playCount: playCount ?? this.playCount,
      tags: tags ?? this.tags,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      mediaType: mediaType ?? this.mediaType,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        hostId,
        status,
        price,
        recordedAt,
      ];
}
