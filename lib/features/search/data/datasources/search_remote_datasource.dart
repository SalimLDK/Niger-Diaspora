import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../groups/data/datasources/group_remote_datasource.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../friends/data/datasources/friend_remote_datasource.dart';
import '../../../friends/data/models/friend_model.dart';
import '../../../messages/data/datasources/message_remote_datasource.dart';
import '../../../messages/data/models/conversation_model.dart';
import '../models/search_result_model.dart';

/// Source de données distante pour la recherche
abstract class SearchRemoteDataSource {
  Future<SearchResultModel> searchAll({
    required String query,
    String? userId,
    int limit = 20,
  });

  Future<List<ProfileModel>> searchProfiles({
    required String query,
    int limit = 20,
  });

  Future<List<GroupModel>> searchGroups({
    required String query,
    int limit = 20,
  });

  Future<List<FriendModel>> searchFriends({
    required String userId,
    required String query,
    int limit = 20,
  });

  Future<List<ConversationModel>> searchConversations({
    required String userId,
    required String query,
    int limit = 20,
  });

  Future<List<String>> getRecentSearches({
    required String userId,
    int limit = 10,
  });

  Future<void> saveRecentSearch({
    required String userId,
    required String query,
  });

  Future<void> removeRecentSearch({
    required String userId,
    required String query,
  });

  Future<void> clearRecentSearches({required String userId});
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final FirebaseFirestore _firestore;
  final ProfileRemoteDataSource _profileDataSource;
  final GroupRemoteDataSource _groupDataSource;
  final FriendRemoteDataSource _friendDataSource;
  final MessageRemoteDataSource _messageDataSource;

  SearchRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    ProfileRemoteDataSource? profileDataSource,
    GroupRemoteDataSource? groupDataSource,
    FriendRemoteDataSource? friendDataSource,
    MessageRemoteDataSource? messageDataSource,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileDataSource = profileDataSource ?? ProfileRemoteDataSourceImpl(),
        _groupDataSource = groupDataSource ?? GroupRemoteDataSourceImpl(),
        _friendDataSource = friendDataSource ?? FriendRemoteDataSourceImpl(),
        _messageDataSource = messageDataSource ?? MessageRemoteDataSourceImpl();

  @override
  Future<SearchResultModel> searchAll({
    required String query,
    String? userId,
    int limit = 20,
  }) async {
    try {
      // Exécuter les recherches en parallèle
      final results = await Future.wait([
        searchProfiles(query: query, limit: limit),
        searchGroups(query: query, limit: limit),
        if (userId != null)
          searchFriends(userId: userId, query: query, limit: limit)
        else
          Future.value(<FriendModel>[]),
        if (userId != null)
          searchConversations(userId: userId, query: query, limit: limit)
        else
          Future.value(<ConversationModel>[]),
      ]);

      return SearchResultModel(
        query: query,
        profiles: results[0] as List<ProfileModel>,
        groups: results[1] as List<GroupModel>,
        friends: results[2] as List<FriendModel>,
        conversations: results[3] as List<ConversationModel>,
        searchedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error searching all: $e');
      throw ServerException('Failed to perform search');
    }
  }

  @override
  Future<List<ProfileModel>> searchProfiles({
    required String query,
    int limit = 20,
  }) async {
    try {
      return await _profileDataSource.searchProfiles(query);
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error searching profiles: $e');
      return [];
    }
  }

  @override
  Future<List<GroupModel>> searchGroups({
    required String query,
    int limit = 20,
  }) async {
    try {
      return await _groupDataSource.searchGroups(query);
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error searching groups: $e');
      return [];
    }
  }

  @override
  Future<List<FriendModel>> searchFriends({
    required String userId,
    required String query,
    int limit = 20,
  }) async {
    try {
      return await _friendDataSource.searchFriends(userId, query);
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error searching friends: $e');
      return [];
    }
  }

  @override
  Future<List<ConversationModel>> searchConversations({
    required String userId,
    required String query,
    int limit = 20,
  }) async {
    try {
      return await _messageDataSource.searchConversations(userId, query);
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error searching conversations: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getRecentSearches({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('recentSearches')
          .get();

      if (!doc.exists) return [];

      final data = doc.data();
      final searches = data?['searches'] as List<dynamic>? ?? [];

      return searches.take(limit).map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error getting recent searches: $e');
      return [];
    }
  }

  @override
  Future<void> saveRecentSearch({
    required String userId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('recentSearches');

      final doc = await docRef.get();
      List<String> searches = [];

      if (doc.exists) {
        final data = doc.data();
        searches = (data?['searches'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
      }

      // Supprimer si existe déjà
      searches.remove(query.trim());

      // Ajouter en premier
      searches.insert(0, query.trim());

      // Limiter à 20 recherches
      if (searches.length > 20) {
        searches = searches.take(20).toList();
      }

      await docRef.set({
        'searches': searches,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error saving recent search: $e');
    }
  }

  @override
  Future<void> removeRecentSearch({
    required String userId,
    required String query,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('recentSearches');

      await docRef.update({
        'searches': FieldValue.arrayRemove([query]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error removing recent search: $e');
    }
  }

  @override
  Future<void> clearRecentSearches({required String userId}) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('recentSearches')
          .delete();
    } catch (e) {
      debugPrint('SearchRemoteDataSource: Error clearing recent searches: $e');
    }
  }
}
