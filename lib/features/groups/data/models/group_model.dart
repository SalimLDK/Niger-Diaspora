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

  /// Date d'arrivée de chaque membre (`group_members.joined_at`).
  ///
  /// Le champ existait sur `GroupEntity` mais pas ici : `toEntity` ne pouvait
  /// donc rien lui transmettre, et le filtre des groupes privés (« un nouveau
  /// membre ne voit pas ce qui a été dit avant lui ») ne trouvait jamais de
  /// date. Seul l'ancien datasource Firestore l'alimentait.
  final Map<String, DateTime> memberJoinedAt;

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
    this.memberJoinedAt = const {},
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
      memberJoinedAt: {
        for (final e
            in ((json['memberJoinedAt'] as Map?) ?? const {}).entries)
          if (_parseDateTime(e.value) case final quand?)
            e.key.toString(): quand,
      },
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
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'country': country,
      'originRegion': originRegion,
      'permissions': permissions,
      'isOfficial': isOfficial,
      // `memberJoinedAt` n'y est volontairement pas : ce `toJson` n'a plus
      // qu'un appelant, l'ancien datasource Firestore, qui l'écrit tel quel
      // dans le document du groupe — où cette carte vit en `Timestamp`, tenue
      // champ par champ par `FieldValue.serverTimestamp()`. L'y envoyer en
      // chaînes l'écraserait.
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
        memberJoinedAt: memberJoinedAt,
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
        memberJoinedAt: entity.memberJoinedAt,
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
    Map<String, DateTime>? memberJoinedAt,
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
      memberJoinedAt: memberJoinedAt ?? this.memberJoinedAt,
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
        memberJoinedAt,
      ];
}
