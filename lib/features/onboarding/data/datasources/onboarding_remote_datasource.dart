import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';

/// Les lectures rendent `bool?`, et le `null` compte autant que les deux
/// autres valeurs : il veut dire **indéterminé** — la session n'était pas
/// lisible, la ligne n'a pas pu être atteinte. À ne jamais confondre avec
/// `false`, qui veut dire « la base a répondu, et la personne ne l'a pas
/// fait ». Confondre les deux rejoue tout l'onboarding d'un compte qui l'a
/// terminé ; voir `OnboardingNotifier`.
abstract class OnboardingRemoteDataSource {
  Future<bool?> hasSeenOnboarding();
  Future<void> setOnboardingComplete();
  Future<bool?> hasSeenCoachMarks();
  Future<void> setCoachMarksComplete();
  Future<bool?> hasGivenConsent();
  Future<void> setConsentGiven();
  Future<bool?> hasCompletedProfileConfig();
  Future<void> setProfileConfigComplete();
}

/// Persiste les drapeaux d'onboarding sur `public.users` (Supabase).
///
/// Lisait auparavant `users/{uid}` sur Cloud Firestore — un reliquat de
/// l'architecture pré-Supabase que plus rien d'autre dans l'app n'écrit ni ne
/// lit. L'étage « serveur » de l'onboarding ne servait donc à rien en
/// pratique : seul le drapeau local (`OnboardingLocalDataSourceImpl`, effacé
/// à chaque réinstallation) faisait foi, alors que la table `users` réelle —
/// celle qui porte `share_location`, `is_visible`, etc. — vit sur Supabase
/// depuis la bascule.
class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  final SupabaseClient _supabase;
  final FirebaseAuth _auth;

  /// Garde d'authentification, injectable pour les tests — même contrat que
  /// [SupabaseAuthBridge] utilisé par `ProfileSupabaseDataSource`.
  final Future<bool> Function() _ensureAuth;
  final Future<bool> Function() _ensureReadableAuth;

  OnboardingRemoteDataSourceImpl({
    required FirebaseAuth auth,
    SupabaseClient? supabase,
    Future<bool> Function()? ensureAuth,
    Future<bool> Function()? ensureReadableAuth,
  }) : _auth = auth,
       _supabase = supabase ?? Supabase.instance.client,
       _ensureAuth = ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated,
       _ensureReadableAuth =
           ensureReadableAuth ?? SupabaseAuthBridge.instance.ensureReadableSession;

  /// Lit un drapeau, ou rend `null` si la lecture n'a rien pu établir.
  ///
  /// Les deux replis rendaient `false`, c'est-à-dire « jamais vu », et c'est
  /// exactement ce qu'ils ne savent pas. `ensureReadableSession` en
  /// particulier abandonne au bout de 3 s **sans** session et laisse la
  /// synchronisation finir en tâche de fond (voir sa docstring : « mieux vaut
  /// dégrader que geler l'écran ») — un démarrage à froid sur réseau lent
  /// dépasse ce budget, et les quatre drapeaux tombaient alors à `false` d'un
  /// coup, consentement compris.
  Future<bool?> _readFlag(String column) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    if (!await _ensureReadableAuth()) return null;

    try {
      final row = await _supabase
          .from('users')
          .select(column)
          .eq('id', user.uid)
          .maybeSingle();
      // Session valide et ligne absente : RLS laisse chacun voir sa propre
      // ligne (vérifié en base le 2026-09-10), donc l'absence est réelle et
      // signe un compte tout neuf. Ici `false` est une réponse, pas un repli.
      if (row == null) return false;
      return row[column] as bool?;
    } catch (e) {
      throw ServerException('Erreur lors de la lecture de $column');
    }
  }

  Future<void> _writeFlag(String column) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw ServerException('Utilisateur non connecte');
      }
      if (!await _ensureAuth()) {
        throw ServerException('Session Supabase non etablie');
      }

      await _supabase.from('users').update({column: true}).eq('id', user.uid);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Erreur lors de la mise a jour de $column');
    }
  }

  @override
  Future<bool?> hasSeenOnboarding() => _readFlag('has_seen_onboarding');

  @override
  Future<void> setOnboardingComplete() => _writeFlag('has_seen_onboarding');

  @override
  Future<bool?> hasSeenCoachMarks() => _readFlag('has_seen_coach_marks');

  @override
  Future<void> setCoachMarksComplete() => _writeFlag('has_seen_coach_marks');

  @override
  Future<bool?> hasGivenConsent() => _readFlag('has_given_consent');

  @override
  Future<void> setConsentGiven() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw ServerException('Utilisateur non connecte');
      }
      if (!await _ensureAuth()) {
        throw ServerException('Session Supabase non etablie');
      }

      await _supabase.from('users').update({
        'has_given_consent': true,
        'consent_date': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.uid);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Erreur lors de la mise a jour du consentement');
    }
  }

  @override
  Future<bool?> hasCompletedProfileConfig() =>
      _readFlag('profile_config_complete');

  @override
  Future<void> setProfileConfigComplete() =>
      _writeFlag('profile_config_complete');
}
