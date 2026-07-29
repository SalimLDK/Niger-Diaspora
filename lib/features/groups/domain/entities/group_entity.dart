import 'package:equatable/equatable.dart';
import 'group_permissions_entity.dart';

/// Entite representant un groupe
class GroupEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String creatorId;
  final String? creatorName;
  final List<String> adminIds;
  final List<String> moderatorIds;
  final List<String> memberIds;
  final GroupCategory category;
  final bool isPrivate;
  final String? location;
  final List<String> tags;
  final Map<String, DateTime> memberJoinedAt;
  final DateTime? createdAt;
  // Filtres geographiques pour la diaspora
  final String? country; // Pays d'accueil (France, USA, Canada...)
  final String? originRegion; // Region d'origine au Niger (Niamey, Zinder...)
  final GroupPermissionsEntity permissions;
  final bool isOfficial;

  const GroupEntity({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.creatorId,
    this.creatorName,
    this.adminIds = const [],
    this.moderatorIds = const [],
    this.memberIds = const [],
    this.category = GroupCategory.other,
    this.isPrivate = false,
    this.location,
    this.tags = const [],
    this.memberJoinedAt = const {},
    this.createdAt,
    this.country,
    this.originRegion,
    this.permissions = const GroupPermissionsEntity(),
    this.isOfficial = false,
  });

  /// Nombre de membres
  int get memberCount => memberIds.length;

  /// Verifier si un utilisateur est admin
  bool isAdmin(String userId) => adminIds.contains(userId) || userId == creatorId;

  /// Verifier si un utilisateur est moderateur (role dedie, distinct d'admin).
  bool isModerator(String userId) => moderatorIds.contains(userId);

  /// Verifier si un utilisateur est membre
  bool isMember(String userId) => memberIds.contains(userId);

  GroupEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? creatorId,
    String? creatorName,
    List<String>? adminIds,
    List<String>? moderatorIds,
    List<String>? memberIds,
    GroupCategory? category,
    bool? isPrivate,
    String? location,
    List<String>? tags,
    Map<String, DateTime>? memberJoinedAt,
    DateTime? createdAt,
    String? country,
    String? originRegion,
    GroupPermissionsEntity? permissions,
    bool? isOfficial,
  }) {
    return GroupEntity(
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
      memberJoinedAt: memberJoinedAt ?? this.memberJoinedAt,
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
        memberJoinedAt,
        createdAt,
        country,
        originRegion,
        permissions,
        isOfficial,
      ];

  @override
  String toString() => 'GroupEntity(id: $id, name: $name)';
}

enum GroupCategory {
  professional,
  cultural,
  sports,
  students,
  entrepreneurs,
  women,
  youth,
  regional,
  other,
}

extension GroupCategoryExtension on GroupCategory {
  String get label {
    switch (this) {
      case GroupCategory.professional:
        return 'Professionnel';
      case GroupCategory.cultural:
        return 'Culturel';
      case GroupCategory.sports:
        return 'Sports';
      case GroupCategory.students:
        return 'Etudiants';
      case GroupCategory.entrepreneurs:
        return 'Entrepreneurs';
      case GroupCategory.women:
        return 'Femmes';
      case GroupCategory.youth:
        return 'Jeunes';
      case GroupCategory.regional:
        return 'Regional';
      case GroupCategory.other:
        return 'Autre';
    }
  }
}
