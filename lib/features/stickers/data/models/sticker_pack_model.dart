
import '../../domain/entities/sticker_pack_entity.dart';
import 'sticker_model.dart';

/// Data model for a sticker pack
class StickerPackModel {
  final String id;
  final String name;
  final String? description;
  final String thumbnailUrl;
  final String creatorId;
  final String? creatorName;
  final List<StickerModel> stickers;
  final bool isOfficial;
  final bool isPremium;
  final bool isPublic;
  final String status; // 'pending', 'approved', 'rejected'
  final String? moderationNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int downloadCount;

  const StickerPackModel({
    required this.id,
    required this.name,
    this.description,
    required this.thumbnailUrl,
    required this.creatorId,
    this.creatorName,
    this.stickers = const [],
    this.isOfficial = false,
    this.isPremium = false,
    this.isPublic = true,
    this.status = 'approved',
    this.moderationNotes,
    this.createdAt,
    this.updatedAt,
    this.downloadCount = 0,
  });

  /// Create from JSON
  factory StickerPackModel.fromJson(Map<String, dynamic> json) {
    return StickerPackModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String?,
      stickers: _parseStickers(json['stickers']),
      isOfficial: json['isOfficial'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? false,
      isPublic: json['isPublic'] as bool? ?? true,
      status: json['status'] as String? ?? 'approved',
      moderationNotes: json['moderationNotes'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      downloadCount: json['downloadCount'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'thumbnailUrl': thumbnailUrl,
      'creatorId': creatorId,
      if (creatorName != null) 'creatorName': creatorName,
      'stickers': stickers.map((s) => s.toJson()).toList(),
      'isOfficial': isOfficial,
      'isPremium': isPremium,
      'isPublic': isPublic,
      'status': status,
      if (moderationNotes != null) 'moderationNotes': moderationNotes,
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      'downloadCount': downloadCount,
    };
  }

  /// Create from Firestore document
  /// Convert for Firestore
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = DateTime.now().toUtc().toIso8601String();
    json['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    return json;
  }

  /// Convert to domain entity
  StickerPackEntity toEntity() => StickerPackEntity(
        id: id,
        name: name,
        description: description,
        thumbnailUrl: thumbnailUrl,
        creatorId: creatorId,
        creatorName: creatorName,
        stickers: stickers.map((s) => s.toEntity()).toList(),
        isOfficial: isOfficial,
        isPremium: isPremium,
        isPublic: isPublic,
        status: _parseStatus(status),
        moderationNotes: moderationNotes,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt,
        downloadCount: downloadCount,
      );

  /// Create from domain entity
  factory StickerPackModel.fromEntity(StickerPackEntity entity) =>
      StickerPackModel(
        id: entity.id,
        name: entity.name,
        description: entity.description,
        thumbnailUrl: entity.thumbnailUrl,
        creatorId: entity.creatorId,
        creatorName: entity.creatorName,
        stickers: entity.stickers.map((s) => StickerModel.fromEntity(s)).toList(),
        isOfficial: entity.isOfficial,
        isPremium: entity.isPremium,
        isPublic: entity.isPublic,
        status: entity.status.name,
        moderationNotes: entity.moderationNotes,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
        downloadCount: entity.downloadCount,
      );

  StickerPackModel copyWith({
    String? id,
    String? name,
    String? description,
    String? thumbnailUrl,
    String? creatorId,
    String? creatorName,
    List<StickerModel>? stickers,
    bool? isOfficial,
    bool? isPremium,
    bool? isPublic,
    String? status,
    String? moderationNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? downloadCount,
  }) {
    return StickerPackModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      stickers: stickers ?? this.stickers,
      isOfficial: isOfficial ?? this.isOfficial,
      isPremium: isPremium ?? this.isPremium,
      isPublic: isPublic ?? this.isPublic,
      status: status ?? this.status,
      moderationNotes: moderationNotes ?? this.moderationNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }

  // ============ Helpers ============

  static List<StickerModel> _parseStickers(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data
          .map((e) => StickerModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic data) {
    if (data == null) return null;
    if (data is DateTime) return data.toLocal();
    if (data is String) {
      return DateTime.tryParse(data)?.toLocal();
    }
    return null;
  }
  static StickerPackStatus _parseStatus(String value) {
    return StickerPackStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StickerPackStatus.approved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickerPackModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StickerPackModel(id: $id, name: $name, stickers: ${stickers.length})';
}
