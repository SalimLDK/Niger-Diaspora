import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../messages/domain/entities/conversation_entity.dart';
import '../entities/search_result.dart';

/// Interface du repository de recherche
abstract class SearchRepository {
  /// Effectue une recherche globale sur tous les types
  Future<Either<Failure, SearchResult>> searchAll({
    required String query,
    required String? userId,
    int limit = 20,
  });

  /// Recherche uniquement les profils/membres
  Future<Either<Failure, List<ProfileModel>>> searchProfiles({
    required String query,
    int limit = 20,
  });

  /// Recherche uniquement les groupes
  Future<Either<Failure, List<GroupEntity>>> searchGroups({
    required String query,
    int limit = 20,
  });

  /// Recherche uniquement les amis d'un utilisateur
  Future<Either<Failure, List<FriendEntity>>> searchFriends({
    required String userId,
    required String query,
    int limit = 20,
  });

  /// Recherche uniquement les conversations
  Future<Either<Failure, List<ConversationEntity>>> searchConversations({
    required String userId,
    required String query,
    int limit = 20,
  });

  /// Récupère les recherches récentes
  Future<Either<Failure, List<String>>> getRecentSearches({
    required String userId,
    int limit = 10,
  });

  /// Sauvegarde une recherche récente
  Future<Either<Failure, void>> saveRecentSearch({
    required String userId,
    required String query,
  });

  /// Supprime une recherche récente
  Future<Either<Failure, void>> removeRecentSearch({
    required String userId,
    required String query,
  });

  /// Efface toutes les recherches récentes
  Future<Either<Failure, void>> clearRecentSearches({
    required String userId,
  });
}
