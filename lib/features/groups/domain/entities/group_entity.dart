import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_entity.freezed.dart';

@freezed
class GroupEntity with _$GroupEntity {
  const factory GroupEntity({
    required String id,
    required String name,
    required String description,
    String? imageUrl,
    required String creatorId,
    String? creatorName,
    @Default([]) List<String> adminIds,
    @Default([]) List<String> memberIds,
    @Default(GroupCategory.other) GroupCategory category,
    @Default(false) bool isPrivate,
    String? location,
    @Default([]) List<String> tags,
    @Default({}) Map<String, DateTime> memberJoinedAt,
    DateTime? createdAt,
  }) = _GroupEntity;
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
