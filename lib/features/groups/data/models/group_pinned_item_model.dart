import 'package:equatable/equatable.dart';
import '../../domain/entities/group_pinned_item_entity.dart';

class GroupPinnedItemModel extends Equatable {
  final String id;
  final String? groupId;
  final String? conversationId;
  final String itemType;
  final String itemId;
  final String pinnedBy;
  final DateTime pinnedAt;
  final int sortOrder;

  const GroupPinnedItemModel({
    required this.id,
    this.groupId,
    this.conversationId,
    required this.itemType,
    required this.itemId,
    required this.pinnedBy,
    required this.pinnedAt,
    this.sortOrder = 0,
  });

  factory GroupPinnedItemModel.fromJson(Map<String, dynamic> row) {
    return GroupPinnedItemModel(
      id: row['id'] as String,
      groupId: row['group_id'] as String?,
      conversationId: row['conversation_id'] as String?,
      itemType: row['item_type'] as String,
      itemId: row['item_id'] as String,
      pinnedBy: row['pinned_by'] as String,
      pinnedAt: DateTime.parse(row['pinned_at'] as String),
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  GroupPinnedItemEntity toEntity() => GroupPinnedItemEntity(
        id: id,
        groupId: groupId,
        conversationId: conversationId,
        itemType: GroupPinnedItemTypeExtension.fromValue(itemType),
        itemId: itemId,
        pinnedBy: pinnedBy,
        pinnedAt: pinnedAt,
        sortOrder: sortOrder,
      );

  @override
  List<Object?> get props => [
        id,
        groupId,
        conversationId,
        itemType,
        itemId,
        pinnedBy,
        pinnedAt,
        sortOrder,
      ];
}
