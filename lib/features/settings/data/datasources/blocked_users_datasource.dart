import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/blocked_user_model.dart';

abstract class BlockedUsersDataSource {
  Stream<List<BlockedUserModel>> getBlockedUsers(String userId);
  Future<void> blockUser(
    String currentUserId,
    String targetUserId,
    String targetDisplayName,
    String? targetPhotoUrl,
  );
  Future<void> unblockUser(String currentUserId, String targetUserId);
  Future<bool> checkBlockStatus(String currentUserId, String targetUserId);
}

class BlockedUsersDataSourceImpl implements BlockedUsersDataSource {
  final FirebaseFirestore _firestore;

  BlockedUsersDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<BlockedUserModel>> getBlockedUsers(String userId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .collection('blocked_users')
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['blockedAt'] is Timestamp) {
              data['blockedAt'] =
                  (data['blockedAt'] as Timestamp)
                      .toDate()
                      .toUtc()
                      .toIso8601String();
            }
            return BlockedUserModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<void> blockUser(
    String currentUserId,
    String targetUserId,
    String targetDisplayName,
    String? targetPhotoUrl,
  ) async {
    try {
      final batch = _firestore.batch();

      // Add to blocked_users subcollection
      final blockedUserRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(targetUserId);

      batch.set(blockedUserRef, {
        'id': targetUserId,
        'displayName': targetDisplayName,
        'photoUrl': targetPhotoUrl,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      // Add to blockedUserIds array for quick lookup
      final userRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(currentUserId);
      batch.update(userRef, {
        'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
      });

      // Add currentUserId to target's blockedByUserIds for reverse lookup
      final targetRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(targetUserId);
      batch.set(targetRef, {
        'blockedByUserIds': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));

      await batch.commit();
      await _refleterDansSupabase(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        bloquer: true,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du blocage');
    }
  }

  /// Miroir du blocage dans la table Supabase `blocked_users`.
  ///
  /// Firestore reste la source du sens « qui j'ai bloqué » — il fonctionne et
  /// alimente déjà `blockedUsersProvider`. Ce miroir existe pour le sens
  /// INVERSE, « qui m'a bloqué », qui n'a jamais fonctionné : `blockUser`
  /// écrivait bien `blockedByUserIds` sur la cible, mais dans Firestore, alors
  /// que les profils viennent de Supabase où `_mapProfile` code en dur une
  /// liste vide. Les dix lectures de l'app recevaient donc toujours « non ».
  ///
  /// **Best-effort assumé** : un échec ici ne fait pas échouer le blocage. Le
  /// blocage a déjà abouti côté Firestore, et c'est lui qui protège
  /// aujourd'hui la personne qui bloque. Faire remonter l'erreur reviendrait à
  /// annoncer « le blocage a échoué » alors qu'il a réussi — pire que le
  /// défaut qu'on corrige. La trace part dans la console pour le diagnostic.
  Future<void> _refleterDansSupabase({
    required String currentUserId,
    required String targetUserId,
    required bool bloquer,
  }) async {
    try {
      // Sans session Supabase, la RLS refuse silencieusement : autant ne pas
      // tenter l'écriture et le dire.
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        debugPrint(
          'blocked_users: session Supabase absente, miroir non écrit '
          '($currentUserId ${bloquer ? "bloque" : "débloque"} $targetUserId)',
        );
        return;
      }

      final supabase = Supabase.instance.client;
      if (bloquer) {
        // `upsert` plutôt qu'`insert` : la clé primaire est
        // (blocker_id, blocked_id), et rebloquer quelqu'un déjà bloqué ne doit
        // pas lever.
        await supabase.from('blocked_users').upsert({
          'blocker_id': currentUserId,
          'blocked_id': targetUserId,
        });
      } else {
        await supabase
            .from('blocked_users')
            .delete()
            .eq('blocker_id', currentUserId)
            .eq('blocked_id', targetUserId);
      }
    } catch (e) {
      debugPrint('blocked_users: miroir Supabase échoué ($e)');
    }
  }

  @override
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();

      // Remove from blocked_users subcollection
      final blockedUserRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(targetUserId);

      batch.delete(blockedUserRef);

      // Remove from blockedUserIds array
      final userRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(currentUserId);
      batch.update(userRef, {
        'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
      });

      // Remove currentUserId from target's blockedByUserIds
      final targetRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(targetUserId);
      batch.set(targetRef, {
        'blockedByUserIds': FieldValue.arrayRemove([currentUserId]),
      }, SetOptions(merge: true));

      await batch.commit();
      await _refleterDansSupabase(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        bloquer: false,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du déblocage');
    }
  }

  @override
  Future<bool> checkBlockStatus(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      final doc =
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(currentUserId)
              .collection('blocked_users')
              .doc(targetUserId)
              .get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la vérification du blocage',
      );
    }
  }
}
