import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../friends/data/datasources/friend_remote_datasource.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../groups/data/datasources/group_remote_datasource.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../messages/data/datasources/message_remote_datasource.dart';
import '../../../messages/domain/entities/conversation_entity.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/models/profile_model.dart';

part 'search_provider.g.dart';

@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  SearchState build() {
    return const SearchState();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(isLoading: true, query: query);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      final profileDataSource = ProfileRemoteDataSourceImpl();
      final groupDataSource = GroupRemoteDataSourceImpl();
      final friendDataSource = FriendRemoteDataSourceImpl();
      final messageDataSource = MessageRemoteDataSourceImpl();

      // Search in parallel
      final results = await Future.wait([
        profileDataSource.searchProfiles(query),
        groupDataSource.searchGroups(query),
        if (currentUserId != null)
          friendDataSource.searchFriends(currentUserId, query)
        else
          Future.value(<dynamic>[]),
        if (currentUserId != null)
          messageDataSource.searchConversations(currentUserId, query)
        else
          Future.value(<dynamic>[]),
      ]);

      final profiles = results[0] as List<ProfileModel>;
      final groups = results[1];

      // Process friend results
      final friends = <FriendEntity>[];
      if (currentUserId != null) {
        for (final f in results[2]) {
          friends.add(f.toEntity());
        }
      }

      // Process conversation results
      final conversations = <ConversationEntity>[];
      if (currentUserId != null) {
        for (final c in results[3]) {
          conversations.add(c.toEntity());
        }
      }

      state = state.copyWith(
        isLoading: false,
        profiles: profiles,
        groups: groups.map((g) => g.toEntity()).cast<GroupEntity>().toList(),
        friends: friends,
        conversations: conversations,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearSearch() {
    state = const SearchState();
  }

  void setFilter(SearchFilter filter) {
    state = state.copyWith(filter: filter);
  }
}

class SearchState {
  final String query;
  final bool isLoading;
  final String? error;
  final List<ProfileModel> profiles;
  final List<GroupEntity> groups;
  final List<FriendEntity> friends;
  final List<ConversationEntity> conversations;
  final SearchFilter filter;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.error,
    this.profiles = const [],
    this.groups = const [],
    this.friends = const [],
    this.conversations = const [],
    this.filter = SearchFilter.all,
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    String? error,
    List<ProfileModel>? profiles,
    List<GroupEntity>? groups,
    List<FriendEntity>? friends,
    List<ConversationEntity>? conversations,
    SearchFilter? filter,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      profiles: profiles ?? this.profiles,
      groups: groups ?? this.groups,
      friends: friends ?? this.friends,
      conversations: conversations ?? this.conversations,
      filter: filter ?? this.filter,
    );
  }

  bool get hasResults =>
      filteredProfiles.isNotEmpty ||
      filteredGroups.isNotEmpty ||
      filteredFriends.isNotEmpty ||
      filteredConversations.isNotEmpty;

  List<ProfileModel> get filteredProfiles {
    if (filter == SearchFilter.groups ||
        filter == SearchFilter.friends ||
        filter == SearchFilter.conversations) {
      return [];
    }
    return profiles;
  }

  List<GroupEntity> get filteredGroups {
    if (filter == SearchFilter.members ||
        filter == SearchFilter.friends ||
        filter == SearchFilter.conversations) {
      return [];
    }
    return groups;
  }

  List<FriendEntity> get filteredFriends {
    if (filter == SearchFilter.members ||
        filter == SearchFilter.groups ||
        filter == SearchFilter.conversations) {
      return [];
    }
    return friends;
  }

  List<ConversationEntity> get filteredConversations {
    if (filter == SearchFilter.members ||
        filter == SearchFilter.groups ||
        filter == SearchFilter.friends) {
      return [];
    }
    return conversations;
  }
}

enum SearchFilter {
  all,
  members,
  groups,
  friends,
  conversations,
}

extension SearchFilterExtension on SearchFilter {
  String get label {
    switch (this) {
      case SearchFilter.all:
        return 'Tous';
      case SearchFilter.members:
        return 'Membres';
      case SearchFilter.groups:
        return 'Groupes';
      case SearchFilter.friends:
        return 'Amis';
      case SearchFilter.conversations:
        return 'Discussions';
    }
  }
}
