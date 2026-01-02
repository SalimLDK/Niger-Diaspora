import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../messages/domain/entities/conversation_entity.dart';
import '../entities/search_result.dart';
import '../repositories/search_repository.dart';

/// Use case pour effectuer une recherche globale
class SearchAll {
  final SearchRepository repository;

  SearchAll(this.repository);

  Future<Either<Failure, SearchResult>> call({
    required String query,
    required String? userId,
    int limit = 20,
  }) {
    return repository.searchAll(
      query: query,
      userId: userId,
      limit: limit,
    );
  }
}

/// Use case pour rechercher des profils
class SearchProfiles {
  final SearchRepository repository;

  SearchProfiles(this.repository);

  Future<Either<Failure, List<ProfileModel>>> call({
    required String query,
    int limit = 20,
  }) {
    return repository.searchProfiles(query: query, limit: limit);
  }
}

/// Use case pour rechercher des groupes
class SearchGroups {
  final SearchRepository repository;

  SearchGroups(this.repository);

  Future<Either<Failure, List<GroupEntity>>> call({
    required String query,
    int limit = 20,
  }) {
    return repository.searchGroups(query: query, limit: limit);
  }
}

/// Use case pour rechercher des amis
class SearchFriends {
  final SearchRepository repository;

  SearchFriends(this.repository);

  Future<Either<Failure, List<FriendEntity>>> call({
    required String userId,
    required String query,
    int limit = 20,
  }) {
    return repository.searchFriends(
      userId: userId,
      query: query,
      limit: limit,
    );
  }
}

/// Use case pour rechercher des conversations
class SearchConversations {
  final SearchRepository repository;

  SearchConversations(this.repository);

  Future<Either<Failure, List<ConversationEntity>>> call({
    required String userId,
    required String query,
    int limit = 20,
  }) {
    return repository.searchConversations(
      userId: userId,
      query: query,
      limit: limit,
    );
  }
}

/// Use case pour gérer les recherches récentes
class ManageRecentSearches {
  final SearchRepository repository;

  ManageRecentSearches(this.repository);

  Future<Either<Failure, List<String>>> getRecent({
    required String userId,
    int limit = 10,
  }) {
    return repository.getRecentSearches(userId: userId, limit: limit);
  }

  Future<Either<Failure, void>> save({
    required String userId,
    required String query,
  }) {
    return repository.saveRecentSearch(userId: userId, query: query);
  }

  Future<Either<Failure, void>> remove({
    required String userId,
    required String query,
  }) {
    return repository.removeRecentSearch(userId: userId, query: query);
  }

  Future<Either<Failure, void>> clearAll({required String userId}) {
    return repository.clearRecentSearches(userId: userId);
  }
}
