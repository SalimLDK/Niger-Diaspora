import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../groups/data/datasources/group_remote_datasource.dart';
import '../../../groups/domain/entities/group_entity.dart';
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
      final profileDataSource = ProfileRemoteDataSourceImpl();
      final groupDataSource = GroupRemoteDataSourceImpl();

      // Search in parallel
      final results = await Future.wait([
        profileDataSource.searchProfiles(query),
        groupDataSource.searchGroups(query),
      ]);

      final profiles = results[0] as List<ProfileModel>;
      final groups = results[1];

      state = state.copyWith(
        isLoading: false,
        profiles: profiles,
        groups: (groups as List).map((g) => g.toEntity() as GroupEntity).toList(),
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
  final SearchFilter filter;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.error,
    this.profiles = const [],
    this.groups = const [],
    this.filter = SearchFilter.all,
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    String? error,
    List<ProfileModel>? profiles,
    List<GroupEntity>? groups,
    SearchFilter? filter,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      profiles: profiles ?? this.profiles,
      groups: groups ?? this.groups,
      filter: filter ?? this.filter,
    );
  }

  bool get hasResults => profiles.isNotEmpty || groups.isNotEmpty;

  List<ProfileModel> get filteredProfiles {
    if (filter == SearchFilter.groups) return [];
    return profiles;
  }

  List<GroupEntity> get filteredGroups {
    if (filter == SearchFilter.members) return [];
    return groups;
  }
}

enum SearchFilter {
  all,
  members,
  groups,
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
    }
  }
}
