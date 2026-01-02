import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../friends/data/models/friend_model.dart';
import '../../../messages/data/models/conversation_model.dart';
import '../../domain/entities/search_result.dart';

part 'search_result_model.freezed.dart';
part 'search_result_model.g.dart';

/// Modèle de données pour les résultats de recherche
@freezed
class SearchResultModel with _$SearchResultModel {
  const SearchResultModel._();

  const factory SearchResultModel({
    required String query,
    @Default([]) List<ProfileModel> profiles,
    @Default([]) List<GroupModel> groups,
    @Default([]) List<FriendModel> friends,
    @Default([]) List<ConversationModel> conversations,
    String? searchedAt,
  }) = _SearchResultModel;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) =>
      _$SearchResultModelFromJson(json);

  /// Convertit en entité domain
  SearchResult toEntity() => SearchResult(
        query: query,
        profiles: profiles,
        groups: groups.map((g) => g.toEntity()).toList(),
        friends: friends.map((f) => f.toEntity()).toList(),
        conversations: conversations.map((c) => c.toEntity()).toList(),
        searchedAt: searchedAt != null ? DateTime.tryParse(searchedAt!) : null,
      );

  /// Vérifie si la recherche a des résultats
  bool get hasResults =>
      profiles.isNotEmpty ||
      groups.isNotEmpty ||
      friends.isNotEmpty ||
      conversations.isNotEmpty;
}
