import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/group_entity.dart';

part 'group_model.freezed.dart';
part 'group_model.g.dart';

@freezed
class GroupModel with _$GroupModel {
  const GroupModel._();

  const factory GroupModel({
    required String id,
    required String name,
    required String description,
    String? imageUrl,
    required String creatorId,
    String? creatorName,
    @Default([]) List<String> adminIds,
    @Default([]) List<String> memberIds,
    @Default('other') String category,
    @Default(false) bool isPrivate,
    String? location,
    @Default([]) List<String> tags,
    DateTime? createdAt,
  }) = _GroupModel;

  factory GroupModel.fromJson(Map<String, dynamic> json) =>
      _$GroupModelFromJson(json);

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel.fromJson({...data, 'id': doc.id});
  }

  GroupEntity toEntity() => GroupEntity(
    id: id,
    name: name,
    description: description,
    imageUrl: imageUrl,
    creatorId: creatorId,
    creatorName: creatorName,
    adminIds: adminIds,
    memberIds: memberIds,
    category: _parseCategory(category),
    isPrivate: isPrivate,
    location: location,
    tags: tags,
    createdAt: createdAt,
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
    memberIds: entity.memberIds,
    category: entity.category.name,
    isPrivate: entity.isPrivate,
    location: entity.location,
    tags: entity.tags,
    createdAt: entity.createdAt,
  );
}
