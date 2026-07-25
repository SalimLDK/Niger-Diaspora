import 'package:equatable/equatable.dart';

enum GroupPinnedItemType { event, poll, message }

extension GroupPinnedItemTypeExtension on GroupPinnedItemType {
  String get value => name;

  static GroupPinnedItemType fromValue(String value) {
    return GroupPinnedItemType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GroupPinnedItemType.message,
    );
  }
}

/// Un element epingle en tete d'un groupe OU d'une conversation 1-a-1
/// (event, poll ou message simple). Exactement un des deux ids est renseigne.
class GroupPinnedItemEntity extends Equatable {
  final String id;
  final String? groupId;
  final String? conversationId;
  final GroupPinnedItemType itemType;
  final String itemId;
  final String pinnedBy;
  final DateTime pinnedAt;
  final int sortOrder;

  const GroupPinnedItemEntity({
    required this.id,
    this.groupId,
    this.conversationId,
    required this.itemType,
    required this.itemId,
    required this.pinnedBy,
    required this.pinnedAt,
    this.sortOrder = 0,
  });

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
