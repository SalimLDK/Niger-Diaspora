import 'package:equatable/equatable.dart';

/// Qui, dans le groupe, peut effectuer une action donnee.
enum GroupMemberScope { allMembers, adminsOnly }

extension GroupMemberScopeExtension on GroupMemberScope {
  String get value =>
      this == GroupMemberScope.allMembers ? 'all_members' : 'admins_only';

  static GroupMemberScope fromValue(String? value) {
    return value == 'admins_only'
        ? GroupMemberScope.adminsOnly
        : GroupMemberScope.allMembers;
  }
}

/// Permissions configurables d'un groupe (extensible sans migration de schema
/// puisque stockees en JSONB cote Supabase).
class GroupPermissionsEntity extends Equatable {
  final GroupMemberScope whoCanPostEvents;
  final GroupMemberScope whoCanPostPolls;
  final GroupMemberScope whoCanPin;

  const GroupPermissionsEntity({
    this.whoCanPostEvents = GroupMemberScope.allMembers,
    this.whoCanPostPolls = GroupMemberScope.allMembers,
    this.whoCanPin = GroupMemberScope.adminsOnly,
  });

  bool canPostEvents({required bool isAdmin}) =>
      isAdmin || whoCanPostEvents == GroupMemberScope.allMembers;

  bool canPostPolls({required bool isAdmin}) =>
      isAdmin || whoCanPostPolls == GroupMemberScope.allMembers;

  bool canPin({required bool isAdmin}) =>
      isAdmin || whoCanPin == GroupMemberScope.allMembers;

  GroupPermissionsEntity copyWith({
    GroupMemberScope? whoCanPostEvents,
    GroupMemberScope? whoCanPostPolls,
    GroupMemberScope? whoCanPin,
  }) {
    return GroupPermissionsEntity(
      whoCanPostEvents: whoCanPostEvents ?? this.whoCanPostEvents,
      whoCanPostPolls: whoCanPostPolls ?? this.whoCanPostPolls,
      whoCanPin: whoCanPin ?? this.whoCanPin,
    );
  }

  @override
  List<Object?> get props => [whoCanPostEvents, whoCanPostPolls, whoCanPin];
}
