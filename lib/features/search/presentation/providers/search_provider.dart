import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../friends/data/datasources/friend_remote_datasource.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../groups/data/datasources/group_supabase_datasource.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../messages/data/datasources/message_supabase_datasource.dart';
import '../../../messages/domain/entities/conversation_entity.dart';
import '../../../profile/data/datasources/profile_supabase_datasource.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../data/datasources/search_remote_datasource.dart';

part 'search_provider.g.dart';

@riverpod
class SearchNotifier extends _$SearchNotifier {
  final _searchDataSource = SearchRemoteDataSourceImpl();

  @override
  SearchState build() {
    loadRecentSearches();
    return const SearchState();
  }

  /// Recherches récentes (§12d), chargées à l'ouverture de l'écran.
  Future<void> loadRecentSearches() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final recent = await _searchDataSource.getRecentSearches(
        userId: userId,
      );
      state = state.copyWith(recentSearches: recent);
    } catch (_) {
      // Confort, pas critique : on garde la liste vide plutôt que de bloquer.
    }
  }

  /// Enregistre la requête validée (soumission du champ) dans les récentes.
  Future<void> commitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await _searchDataSource.saveRecentSearch(
        userId: userId,
        query: trimmed,
      );
      await loadRecentSearches();
    } catch (_) {
      // Idem : silencieux.
    }
  }

  Future<void> clearRecentSearches() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await _searchDataSource.clearRecentSearches(userId: userId);
      state = state.copyWith(recentSearches: const []);
    } catch (_) {
      // Idem : silencieux.
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = SearchState(recentSearches: state.recentSearches);
      return;
    }

    state = state.copyWith(isLoading: true, query: query);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Recherche de personnes : source Supabase, pas Firestore.
      //
      // Le provider principal des profils est passé à Supabase, mais ce chemin
      // instanciait encore `ProfileRemoteDataSourceImpl`, qui lit Firestore.
      // Relevé le 2026-08-06 : 10 profils dans Supabase, 2 documents dans
      // Firestore dont **un seul** avec un nom renseigné. La recherche ne
      // pouvait donc trouver qu'une personne sur dix, sans erreur ni log.
      final profileDataSource = ProfileSupabaseDataSource();
      // Supabase, comme `groupRemoteDataSourceProvider` : la collection
      // Firestore `groups` est vide depuis la migration, donc la recherche
      // ne remontait jamais aucun groupe.
      final groupDataSource = GroupSupabaseDataSource();
      final friendDataSource = FriendRemoteDataSourceImpl();
      // Source Supabase, pas Firestore : la collection Firestore `messages`
      // est à 0 document, les 51 messages vivent dans Supabase. La recherche
      // de conversations ne trouvait donc jamais rien — et une recherche
      // vide ne ressemble pas à une panne.
      final messageDataSource = MessageSupabaseDataSource();

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
    state = SearchState(recentSearches: state.recentSearches);
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
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.error,
    this.profiles = const [],
    this.groups = const [],
    this.friends = const [],
    this.conversations = const [],
    this.filter = SearchFilter.all,
    this.recentSearches = const [],
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
    List<String>? recentSearches,
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
      recentSearches: recentSearches ?? this.recentSearches,
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
