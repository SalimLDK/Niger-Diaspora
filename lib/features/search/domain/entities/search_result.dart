import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../messages/domain/entities/conversation_entity.dart';

part 'search_result.freezed.dart';

/// Entité représentant les résultats de recherche
@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required String query,
    @Default([]) List<ProfileModel> profiles,
    @Default([]) List<GroupEntity> groups,
    @Default([]) List<FriendEntity> friends,
    @Default([]) List<ConversationEntity> conversations,
    DateTime? searchedAt,
  }) = _SearchResult;

  const SearchResult._();

  /// Vérifie si la recherche a des résultats
  bool get hasResults =>
      profiles.isNotEmpty ||
      groups.isNotEmpty ||
      friends.isNotEmpty ||
      conversations.isNotEmpty;

  /// Nombre total de résultats
  int get totalCount =>
      profiles.length + groups.length + friends.length + conversations.length;
}

/// Types de recherche disponibles
enum SearchType {
  all,
  profiles,
  groups,
  friends,
  conversations,
}

/// Paramètres de recherche
@freezed
class SearchParams with _$SearchParams {
  const factory SearchParams({
    required String query,
    @Default(SearchType.all) SearchType type,
    @Default(20) int limit,
    String? cursor,
  }) = _SearchParams;
}

/// Résultat de recherche pour un type spécifique
@freezed
class TypedSearchResult<T> with _$TypedSearchResult<T> {
  const factory TypedSearchResult({
    required List<T> items,
    String? nextCursor,
    @Default(false) bool hasMore,
  }) = _TypedSearchResult<T>;
}
