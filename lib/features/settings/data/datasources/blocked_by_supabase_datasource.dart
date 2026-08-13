import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_auth_bridge.dart';

/// Qui m'a bloqué — le sens INVERSE du blocage.
///
/// Ce sens n'a jamais fonctionné. `blockUser` écrit pourtant bien l'auteur du
/// blocage dans le `blockedByUserIds` de sa cible, « for reverse lookup », mais
/// il l'écrit dans Firestore alors que les profils viennent de Supabase, où
/// `profile_supabase_datasource._mapProfile` code en dur une liste vide. Les
/// dix endroits de l'app qui demandent « cette personne m'a-t-elle bloqué ? »
/// recevaient donc toujours non — carte, accueil, statut en ligne,
/// notifications, et le composeur de l'écran de conversation.
///
/// La lecture se fait sur `blocked_users`, dont la politique RLS autorise
/// depuis la migration `20260806120000` les deux sens : `blocker_id = moi` ou
/// `blocked_id = moi`. Avant elle, cette requête réussissait en ne renvoyant
/// jamais rien — un refus silencieux, le pire mode d'échec pour un garde de
/// confidentialité.
class BlockedBySupabaseDataSource {
  BlockedBySupabaseDataSource({
    SupabaseClient? supabase,
    Future<bool> Function()? ensureReadableAuth,
  }) : _clientOverride = supabase,
       _ensureReadableAuth =
           ensureReadableAuth ?? SupabaseAuthBridge.instance.ensureReadableSession;

  final SupabaseClient? _clientOverride;
  SupabaseClient get _supabase => _clientOverride ?? Supabase.instance.client;

  /// Garde bornée avant de s'abonner — voir
  /// [SupabaseAuthBridge.ensureReadableSession]. Injectable pour les tests.
  final Future<bool> Function() _ensureReadableAuth;

  /// Flux des identifiants qui ont bloqué [userId].
  ///
  /// `.stream()` demande la table dans la publication realtime — c'est fait
  /// par la même migration, avec `REPLICA IDENTITY FULL` pour que les
  /// suppressions (déblocages) portent l'ancienne ligne et passent la RLS.
  /// Sans ça, un déblocage ne serait visible qu'au prochain lancement.
  Stream<Set<String>> watchBlockedBy(String userId) async* {
    // Session non confirmée (fenêtre `_startFromLocalSession`,
    // auth_provider.dart) : attendre brièvement avant de s'abonner, pour ne
    // pas partir en anon. Contrairement à `getConversations`, `.stream()`
    // gère lui-même sa reconnexion — un simple délai avant l'abonnement
    // suffit, pas besoin d'un nouvel essai manuel. Best-effort : au-delà du
    // délai, on s'abonne quand même (comportement actuel inchangé), le repli
    // `.handleError` de `usersWhoBlockedMeProvider` couvre le reste.
    await _ensureReadableAuth();
    yield* _supabase
        .from('blocked_users')
        .stream(primaryKey: ['blocker_id', 'blocked_id'])
        .eq('blocked_id', userId)
        .map(
          (lignes) =>
              lignes
                  .map((l) => l['blocker_id'] as String?)
                  .whereType<String>()
                  .toSet(),
        );
  }

  /// Lecture ponctuelle, pour les chemins qui ne peuvent pas écouter un flux.
  Future<Set<String>> fetchBlockedBy(String userId) async {
    final lignes = await _supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocked_id', userId);
    return (lignes as List)
        .map((l) => l['blocker_id'] as String?)
        .whereType<String>()
        .toSet();
  }
}
