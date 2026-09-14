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

/// Le miroir Supabase du blocage, rendu injectable.
///
/// Rend `null` quand la ligne a bien été posée (ou retirée), la cause sinon.
/// Une fonction plutôt qu'une méthode pour que les tests puissent l'écarter :
/// [refleterBlocageDansSupabase] touche `Supabase.instance`, absent d'un test
/// unitaire.
typedef MiroirBlocage =
    Future<Object?> Function({
      required String currentUserId,
      required String targetUserId,
      required bool bloquer,
    });

class BlockedUsersDataSourceImpl implements BlockedUsersDataSource {
  final FirebaseFirestore _firestore;
  final MiroirBlocage _miroir;

  BlockedUsersDataSourceImpl({
    FirebaseFirestore? firestore,
    MiroirBlocage? miroir,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _miroir = miroir ?? refleterBlocageDansSupabase;

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
    // Un seul document, dans SA propre sous-collection — plus de lot.
    //
    // Il y en avait trois, et les deux autres condamnaient le blocage en
    // entier, un lot Firestore étant atomique :
    //
    // - `update(users/{moi}, {'blockedUserIds': …})` sur un document ABSENT —
    //   et plus rien ne crée les documents `users` Firestore depuis la
    //   migration vers Supabase, ils manquent à la quasi-totalité des
    //   comptes. Ce qui remonte n'est pas le `NOT_FOUND` qu'on attendrait
    //   mais un `PERMISSION_DENIED` : l'`allow update` de `users/{userId}`
    //   appelle `diff(resource.data)`, nul sur un document absent, et la
    //   règle plante avant d'atteindre le document. Aucune retouche des
    //   règles n'aurait donc pu sauver cette écriture ;
    // - `set(users/{cible}, {'blockedByUserIds': …}, merge)` : `set(merge)`
    //   sur un document absent est une CRÉATION, et `users/{userId}` ne
    //   l'autorise qu'à son propriétaire — à raison.
    //
    // Ni l'un ni l'autre tableau n'était lu : la liste des bloqués vient de
    // cette sous-collection (`getBlockedUsers` → `blockedUsersProvider`), et
    // le sens inverse « qui m'a bloqué » passe par Supabase
    // (`usersWhoBlockedMe`). Seul le nettoyage de suppression de compte les
    // balaie encore, en Admin SDK, pour les données d'avant.
    //
    // Même défaut, même fichier de causes que l'acceptation d'une demande
    // d'ami, corrigée le 2026-09-14 (b497991). Mesuré par
    // `tools/rules_tests/blocage_utilisateur.mjs`.
    await _ecrireEtRefleter(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
      bloquer: true,
      ecritureFirestore:
          () => _entreeBlocage(currentUserId, targetUserId).set({
            'id': targetUserId,
            'displayName': targetDisplayName,
            'photoUrl': targetPhotoUrl,
            'blockedAt': FieldValue.serverTimestamp(),
          }),
      libelleEchec: 'Erreur lors du blocage',
    );
  }

  @override
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    // Même forme, mêmes deux écritures retirées : `arrayRemove` au lieu
    // d'`arrayUnion` ne changeait rien au refus.
    await _ecrireEtRefleter(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
      bloquer: false,
      ecritureFirestore:
          () => _entreeBlocage(currentUserId, targetUserId).delete(),
      libelleEchec: 'Erreur lors du déblocage',
    );
  }

  DocumentReference<Map<String, dynamic>> _entreeBlocage(
    String currentUserId,
    String targetUserId,
  ) => _firestore
      .collection(FirebaseCollections.users)
      .doc(currentUserId)
      .collection('blocked_users')
      .doc(targetUserId);

  /// Écrit le blocage dans les DEUX bases, sans que l'une puisse emporter
  /// l'autre.
  ///
  /// Les deux moitiés portent chacune une part du blocage, et aucune n'est
  /// accessoire :
  ///
  /// - **Firestore** tient la liste « qui j'ai bloqué » : c'est elle que
  ///   montrent les Réglages, et elle qui alimente les filtres côté client
  ///   (messages, notifications, statut en ligne) ;
  /// - **Supabase** tient ce que le SERVEUR applique. `private.peut_voir_*`
  ///   lit `public.blocked_users` : sans cette ligne, les publications de la
  ///   personne bloquée continuent d'arriver dans le fil, et le sens inverse
  ///   (`usersWhoBlockedMe`) ne voit rien.
  ///
  /// Le miroir était appelé APRÈS `batch.commit()`, donc jamais quand le lot
  /// levait — et le lot levait toujours. Le blocage n'aboutissait alors nulle
  /// part. Il est maintenant tenté quoi qu'il arrive à Firestore.
  ///
  /// Et son échec ne se perd plus dans un `debugPrint` : un blocage à moitié
  /// posé n'est pas un blocage, et le taire est exactement le défaut qu'on
  /// corrige ici. Réessayer est sûr — `set` et `upsert` sont idempotents, et
  /// `delete` sur ce qui n'existe plus ne lève pas.
  Future<void> _ecrireEtRefleter({
    required String currentUserId,
    required String targetUserId,
    required bool bloquer,
    required Future<void> Function() ecritureFirestore,
    required String libelleEchec,
  }) async {
    Object? echecFirestore;
    try {
      await ecritureFirestore();
    } on FirebaseException catch (e) {
      echecFirestore = e.message ?? e.code;
      debugPrint('blocked_users: écriture Firestore échouée ($e)');
    } catch (e) {
      // Volontairement large : AUCUNE panne de cette moitié ne doit faire
      // sauter le miroir. Elle est relancée plus bas, jamais avalée.
      echecFirestore = e;
      debugPrint('blocked_users: écriture Firestore échouée ($e)');
    }

    final echecMiroir = await _miroir(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
      bloquer: bloquer,
    );

    if (echecFirestore != null) throw ServerException('$echecFirestore');
    if (echecMiroir != null) throw ServerException(libelleEchec);
  }

  @override
  Future<bool> checkBlockStatus(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      final doc = await _entreeBlocage(currentUserId, targetUserId).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la vérification du blocage',
      );
    }
  }
}

/// Miroir du blocage dans la table Supabase `blocked_users`.
///
/// Rend `null` en cas de succès, la cause sinon — c'est l'appelant qui décide
/// quoi en faire.
///
/// Ce miroir existe d'abord pour le sens INVERSE, « qui m'a bloqué », qui n'a
/// jamais fonctionné : `blockUser` écrivait bien `blockedByUserIds` sur la
/// cible, mais dans Firestore, alors que les profils viennent de Supabase où
/// `_mapProfile` code en dur une liste vide. Les dix lectures de l'app
/// recevaient donc toujours « non ».
Future<Object?> refleterBlocageDansSupabase({
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
      return 'session Supabase absente';
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
    return null;
  } catch (e) {
    debugPrint('blocked_users: miroir Supabase échoué ($e)');
    return e;
  }
}
