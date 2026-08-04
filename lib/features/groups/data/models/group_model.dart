import 'package:equatable/equatable.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_permissions_entity.dart';

/// Modele pour les groupes
class GroupModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String creatorId;
  final String? creatorName;
  final List<String> adminIds;
  final List<String> moderatorIds;
  final List<String> memberIds;
  final String category;
  final bool isPrivate;
  final String? location;
  final List<String> tags;
  final DateTime? createdAt;
  final String? country;
  final String? originRegion;
  final Map<String, dynamic> permissions;
  final bool isOfficial;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.creatorId,
    this.creatorName,
    this.adminIds = const [],
    this.moderatorIds = const [],
    this.memberIds = const [],
    this.category = 'other',
    this.isPrivate = false,
    this.location,
    this.tags = const [],
    this.createdAt,
    this.country,
    this.originRegion,
    this.permissions = const {},
    this.isOfficial = false,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String?,
      adminIds: (json['adminIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      moderatorIds: (json['moderatorIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      memberIds: (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      category: json['category'] as String? ?? 'other',
      isPrivate: json['isPrivate'] as bool? ?? false,
      location: json['location'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: _parseDateTime(json['createdAt']),
      country: json['country'] as String?,
      originRegion: json['originRegion'] as String?,
      permissions:
          (json['permissions'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ??
              const {},
      isOfficial: json['isOfficial'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'adminIds': adminIds,
      'moderatorIds': moderatorIds,
      'memberIds': memberIds,
      'category': category,
      'isPrivate': isPrivate,
      'location': location,
      'tags': tags,
      'createdAt': createdAt?.toIso8601String(),
      'country': country,
      'originRegion': originRegion,
      'permissions': permissions,
      'isOfficial': isOfficial,
    };
  }

  GroupPermissionsEntity _parsePermissions() {
    return GroupPermissionsEntity(
      whoCanPostEvents: GroupMemberScopeExtension.fromValue(
        permissions['who_can_post_events'] as String?,
      ),
      whoCanPostPolls: GroupMemberScopeExtension.fromValue(
        permissions['who_can_post_polls'] as String?,
      ),
      whoCanPin: GroupMemberScopeExtension.fromValue(
        permissions['who_can_pin'] as String?,
      ),
    );
  }

  static Map<String, dynamic> _permissionsToJson(GroupPermissionsEntity p) => {
        'who_can_post_events': p.whoCanPostEvents.value,
        'who_can_post_polls': p.whoCanPostPolls.value,
        'who_can_pin': p.whoCanPin.value,
      };

  GroupEntity toEntity() => GroupEntity(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        creatorId: creatorId,
        creatorName: creatorName,
        adminIds: adminIds,
        moderatorIds: moderatorIds,
        memberIds: memberIds,
        category: _parseCategory(category),
        isPrivate: isPrivate,
        location: location,
        tags: tags,
        createdAt: createdAt,
        country: country,
        originRegion: originRegion,
        permissions: _parsePermissions(),
        isOfficial: isOfficial,
      );

  static GroupCategory _parseCategory(String value) {
    return GroupCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GroupCategory.other,
    );
  }

  factory GroupModel.fromEntity(GroupEntity entity) => GroupModel(
        id: entity.id,
        name: entity.name,
        description: entity.description,
        imageUrl: entity.imageUrl,
        creatorId: entity.creatorId,
        creatorName: entity.creatorName,
        adminIds: entity.adminIds,
        moderatorIds: entity.moderatorIds,
        memberIds: entity.memberIds,
        category: entity.category.name,
        isPrivate: entity.isPrivate,
        location: entity.location,
        tags: entity.tags,
        createdAt: entity.createdAt,
        country: entity.country,
        originRegion: entity.originRegion,
        permissions: _permissionsToJson(entity.permissions),
        isOfficial: entity.isOfficial,
      );

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? creatorId,
    String? creatorName,
    List<String>? adminIds,
    List<String>? moderatorIds,
    List<String>? memberIds,
    String? category,
    bool? isPrivate,
    String? location,
    List<String>? tags,
    DateTime? createdAt,
    String? country,
    String? originRegion,
    Map<String, dynamic>? permissions,
    bool? isOfficial,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      adminIds: adminIds ?? this.adminIds,
      moderatorIds: moderatorIds ?? this.moderatorIds,
      memberIds: memberIds ?? this.memberIds,
      category: category ?? this.category,
      isPrivate: isPrivate ?? this.isPrivate,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      country: country ?? this.country,
      originRegion: originRegion ?? this.originRegion,
      permissions: permissions ?? this.permissions,
      isOfficial: isOfficial ?? this.isOfficial,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        creatorId,
        creatorName,
        adminIds,
        moderatorIds,
        memberIds,
        category,
        isPrivate,
        location,
        tags,
        createdAt,
        country,
        originRegion,
        permissions,
        isOfficial,
      ];
}
