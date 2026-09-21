import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';
import 'preferences_service.dart';
import 'supabase_auth_bridge.dart';

/// Pourquoi cet appareil se fait sortir. Décide du texte affiché : dire
/// « Connecté ailleurs » à quelqu'un que l'administration vient de suspendre
/// est un mensonge, et le support en hérite.
enum MotifDeconnexionForcee {
  /// Le compte s'est connecté sur un autre appareil (règle de session unique).
  connecteAilleurs,

  /// Un administrateur a mis fin à la session depuis la console.
  sessionFermeeParAdmin,

  /// Le compte est suspendu.
  compteSuspendu,
}

/// Enforces single concurrent session rule.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  static SessionService get instance => _instance;

  /// Sentinelles écrites dans `public.users.session_id` par la console admin
  /// (`AdminProvider.forceLogoutUser` et `banUser`). Exposées ici parce que
  /// c'est le seul endroit qui les *lit* : les garder en littéral des deux
  /// côtés, c'est laisser un renommage couper le fil sans rien casser à la
  /// compilation.
  static const String prefixeForceLogout = 'force_logout_';
  static const String prefixeBanni = 'banned_';

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  RealtimeChannel? _canalAdmin;
  String? _currentSessionId;
  bool _isListening = false;

  /// Déconnexion complète, fournie par `AuthNotifier`. Rend `true` si elle a
  /// pris la main.
  ///
  /// Sans elle, la déconnexion forcée ci-dessous ne faisait que signer la
  /// sortie de Firebase : les caches Hive, les préférences personnelles
  /// (brouillons, hashtags suivis), les pièces jointes en clair et le jeton
  /// FCM restaient en place. Le compte suivant sur ce téléphone en héritait,
  /// et l'appareil continuait de recevoir les notifications du précédent —
  /// exactement ce que le chemin normal prend soin de nettoyer.
  ///
  /// Elle laisse aussi `AuthState` sur `authenticated` alors que Firebase est
  /// sorti : le garde du routeur (« si non authentifié → /auth/login ») ne
  /// voyait rien, seule la navigation explicite du bouton OK masquait
  /// l'incohérence.
  Future<bool> Function()? onForceLogout;

  SessionService._internal();

  /// Initialize session monitoring for a user.
  /// [isNewLogin] should be true if this is a fresh login action,
  /// causing a new session ID to be generated.
  Future<void> initialize(String userId, {bool isNewLogin = false}) async {
    if (_isListening) return;

    // Verify user authentication state
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // debugPrint(
      //   'SessionService: User not authenticated. Cannot initialize session.',
      // );
      return;
    }

    if (currentUser.uid != userId) {
      // debugPrint(
      //   'SessionService: User ID mismatch. Expected: $userId, Got: ${currentUser.uid}',
      // );
      return;
    }

    // Décisions de la console admin — volontairement AVANT le bloc Firestore
    // ci-dessous, et hors de son `try`.
    //
    // Ce bloc-là sort sans rien écouter dès que `users/<uid>` n'existe pas :
    // son `update` lève `not-found`, le `catch` efface l'identifiant et
    // `return`. Or plus rien ne crée ces documents depuis la migration vers
    // Supabase — 8 comptes sur 54 en avaient un le 2026-09-16. Accrocher
    // l'expulsion administrative à ce chemin, c'est la livrer morte pour la
    // grande majorité des comptes, exactement comme elle l'était.
    await _surveillerDecisionsAdmin(userId, nouvelleConnexion: isNewLogin);

    try {
      if (isNewLogin) {
        // Generate new session ID for fresh login
        _currentSessionId = const Uuid().v4();
        await PreferencesService.instance.setSessionId(_currentSessionId!);

        // Update Firestore with new session ID
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
                'session_id': _currentSessionId,
                'last_login': FieldValue.serverTimestamp(),
              });
          // debugPrint(
          //   'SessionService: Session initialized successfully for user: $userId',
          // );
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // debugPrint(
            //   'SessionService: Permission denied when updating session for user: $userId',
            // );
            // debugPrint('SessionService: Error details: ${e.message}');
            // Don't throw - allow app to continue without session tracking
          } else if (e.code == 'not-found') {
            // debugPrint(
            //   'SessionService: User document not found for user: $userId',
            // );
            // debugPrint(
            //   'SessionService: The user document may need to be created first.',
            // );
          } else {
            // debugPrint(
            //   'SessionService: Firestore error (${e.code}): ${e.message}',
            // );
          }
          // Clear session ID on error to prevent inconsistent state
          _currentSessionId = null;
          await PreferencesService.instance.clearSessionId();
          return;
        }
      } else {
        // App restart: load existing session ID
        _currentSessionId = PreferencesService.instance.sessionId;

        // If no local session ID exists tracking is impossible/irrelevant until next login
        // or we could force a new session?
        // Strategy: If missing, assume new session to self-heal.
        if (_currentSessionId == null) {
          _currentSessionId = const Uuid().v4();
          await PreferencesService.instance.setSessionId(_currentSessionId!);

          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({'session_id': _currentSessionId});
            // debugPrint(
            //   'SessionService: Session ID regenerated for user: $userId',
            // );
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied') {
              // debugPrint(
              //   'SessionService: Permission denied when regenerating session for user: $userId',
              // );
              // debugPrint('SessionService: Error details: ${e.message}');
            } else if (e.code == 'not-found') {
              // debugPrint(
              //   'SessionService: User document not found for user: $userId',
              // );
            } else {
              // debugPrint(
              //   'SessionService: Firestore error (${e.code}): ${e.message}',
              // );
            }
            // Clear session ID on error
            _currentSessionId = null;
            await PreferencesService.instance.clearSessionId();
            return;
          }
        }
      }

      _startListening(userId);
    } catch (e) {
      // debugPrint('SessionService: Unexpected error during initialization: $e');
      // Clear session state on unexpected errors
      _currentSessionId = null;
      await PreferencesService.instance.clearSessionId();
    }
  }

  void _startListening(String userId) {
    unawaited(_sessionSubscription?.cancel());
    _isListening = true;

    _sessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) return;

            final data = snapshot.data();
            if (data != null && data.containsKey('session_id')) {
              final remoteSessionId = data['session_id'] as String?;

              if (doitEjecter(
                sessionDistante: remoteSessionId,
                sessionLocale: _currentSessionId,
                multiAppareil: multiAppareilAutorise(),
              )) {
                unawaited(_handleForceLogout(
                  motif: MotifDeconnexionForcee.connecteAilleurs,
                ));
              }
            }
          },
          onError: (e) {
            // debugPrint('Session listener error: $e');
          },
        );
  }

  /// Écoute `public.users` — la ligne de ce compte, et elle seule — pour y
  /// voir venir une décision administrative.
  ///
  /// **Pourquoi Supabase et pas Firestore.** `AdminProvider.forceLogoutUser`
  /// et `banUser` écrivent `session_id` dans `public.users` ; l'écouteur
  /// historique, lui, regarde Firestore `users/<uid>`. Les deux actions
  /// n'éjectaient donc personne, en silence, et l'audit enregistrait un
  /// succès (constaté le 2026-09-16). Faire écrire l'admin dans Firestore
  /// était l'autre issue, et elle est fermée : `firestore.rules` ne permet
  /// l'`update` d'un document `users` qu'à son propriétaire, sans branche
  /// admin — et un refus Firestore ne remonte pas au client, l'écriture
  /// « réussit » dans le cache.
  Future<void> _surveillerDecisionsAdmin(
    String userId, {
    required bool nouvelleConnexion,
  }) async {
    if (_canalAdmin != null) return;

    // Session d'abord : un abonnement créé en anon fait son fetch initial sous
    // RLS sans droits, et ne verra jamais rien. Même précaution que partout
    // ailleurs sur Supabase.
    // Ce qu'on accepte ici : le tout premier échange d'un compte neuf échoue
    // régulièrement (cycle de vie du pont Supabase). `_canalAdmin` reste nul,
    // donc le prochain appel d'`initialize` — reprise, relance de l'app —
    // réessaie. La fenêtre non surveillée est la première session d'un compte
    // qui vient d'être créé ; personne n'y est banni.
    final pret = await SupabaseAuthBridge.instance.ensureAuthenticated();
    if (!pret) {
      debugPrint(
        'SessionService: pas de session Supabase, decisions admin non surveillees',
      );
      return;
    }
    final supabase = Supabase.instance.client;

    // Effacer la sentinelle laissée par une expulsion précédente. Sans ça,
    // `force_logout_…` resterait dans la colonne pour toujours — personne ne
    // la réécrit, `unbanUser` non plus — et la lecture initiale ci-dessous
    // ressortirait le compte à CHAQUE connexion, définitivement.
    //
    // Une suspension, elle, tient : elle est portée par `is_banned`, que ceci
    // ne touche pas.
    if (nouvelleConnexion) {
      try {
        await supabase
            .from('users')
            .update({'session_id': const Uuid().v4()})
            .eq('id', userId);
      } catch (e) {
        debugPrint('SessionService: sentinelle admin non effacee: $e');
      }
    }

    // S'abonner AVANT la lecture initiale : l'ordre inverse laisse une fenêtre
    // où une décision prise entre les deux n'est ni lue ni notifiée.
    final canal = supabase.channel('session_admin_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'users',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          final ligne = payload.newRecord;
          // UNE CLÉ ABSENTE N'EST PAS UNE VALEUR NULLE. Une fois la fermeture
          // 1.1b appliquée, `session_id` n'est plus lisible par le rôle
          // `authenticated`, et le temps réel le RETIRE du message, sans
          // erreur (mesuré : tools/rls_tests/temps_reel_droits_colonnes.sql).
          // Lu tel quel, il vaudrait `null` à chaque mise à jour de la ligne,
          // et la révocation de session par un administrateur cesserait de
          // marcher, en silence. Le message devient alors un simple signal :
          // on relit la décision par `mon_profil_prive()`.
          if (!ligne.containsKey('session_id')) {
            unawaited(_relireDecisionAdmin(userId));
            return;
          }
          _examinerDecisionAdmin(
            sessionDistante: ligne['session_id'] as String?,
            banni: ligne['is_banned'] == true,
          );
        },
      );
    _canalAdmin = canal;
    canal.subscribe();

    await _relireDecisionAdmin(userId);
  }

  /// Lit la décision d'administration portée par SA ligne `users`.
  ///
  /// Par `mon_profil_prive()` et non `select('session_id, is_banned')` :
  /// nommer `session_id` fera refuser la lecture en 42501 une fois la
  /// fermeture 1.1b appliquée. La fonction rend la ligne de la session
  /// Supabase ; si ce n'est pas celle de [userId], on n'en tire rien.
  Future<void> _relireDecisionAdmin(String userId) async {
    try {
      final ligne = await Supabase.instance.client
          .rpc('mon_profil_prive')
          .select('id, session_id, is_banned')
          .maybeSingle();
      if (ligne == null || ligne['id'] != userId) return;
      _examinerDecisionAdmin(
        sessionDistante: ligne['session_id'] as String?,
        banni: ligne['is_banned'] == true,
      );
    } catch (e) {
      debugPrint('SessionService: lecture des decisions admin: $e');
    }
  }

  void _examinerDecisionAdmin({
    required String? sessionDistante,
    required bool banni,
  }) {
    if (!doitEjecterSurDecisionAdmin(
      sessionDistante: sessionDistante,
      banni: banni,
      multiAppareil: multiAppareilAutorise(),
    )) {
      return;
    }
    unawaited(_handleForceLogout(
      motif: banni
          ? MotifDeconnexionForcee.compteSuspendu
          : MotifDeconnexionForcee.sessionFermeeParAdmin,
    ));
  }

  /// Faut-il sortir cet appareil sur décision de la console admin ?
  ///
  /// Isolée pour la même raison que [doitEjecter] : c'est la décision, le
  /// reste est de la plomberie autour d'elle.
  ///
  /// L'exemption `multiAppareilComptes` couvre **tout**, suspension comprise
  /// (choix du 2026-09-16) : la liste dit « laissez ce compte tranquille »,
  /// et elle ne contient que des comptes de test. Un banni qui y figure ne
  /// sort donc qu'à sa prochaine connexion.
  @visibleForTesting
  static bool doitEjecterSurDecisionAdmin({
    required String? sessionDistante,
    required bool banni,
    required bool multiAppareil,
  }) {
    if (multiAppareil) return false;
    if (banni) return true;
    if (sessionDistante == null) return false;
    return sessionDistante.startsWith(prefixeForceLogout) ||
        sessionDistante.startsWith(prefixeBanni);
  }

  /// Ce compte peut-il tenir plusieurs sessions ? Branché depuis Riverpod
  /// (cf. `multiAppareilAutoriseProvider`) ; `false` tant que personne ne le
  /// branche, donc le comportement d'avant par défaut.
  bool Function() multiAppareilAutorise = () => false;

  /// Faut-il éjecter cet appareil ?
  ///
  /// Isolée parce que c'est **la** décision : le reste du service n'est que
  /// de la plomberie autour d'elle. Elle porte la levée de « une seule
  /// session par compte » (plan MLS, phase 7).
  ///
  /// Quand le multi-appareil est autorisé, `session_id` cesse d'être un
  /// signal d'éjection — il reste écrit, mais plus personne ne l'oppose à
  /// quiconque. Ce qui identifie un appareil à partir de là, c'est le
  /// registre `mls_devices`, pas cette colonne.
  @visibleForTesting
  static bool doitEjecter({
    required String? sessionDistante,
    required String? sessionLocale,
    required bool multiAppareil,
  }) {
    if (multiAppareil) return false;
    // Pas de session distante : rien à opposer. Éjecter ici déconnecterait
    // sur une lecture incomplète.
    if (sessionDistante == null) return false;
    return sessionDistante != sessionLocale;
  }

  /// Point d'entrée de test pour la déconnexion forcée.
  ///
  /// Le déclencheur réel est un instantané Firestore, hors de portée d'un test
  /// unitaire ; or ce qui doit être verrouillé est la décision prise ensuite —
  /// déléguer à la déconnexion complète, et retomber sur le repli si elle
  /// manque ou échoue.
  @visibleForTesting
  Future<void> forcerDeconnexionPourTest({
    MotifDeconnexionForcee motif = MotifDeconnexionForcee.connecteAilleurs,
  }) => _handleForceLogout(motif: motif);

  Future<void> _handleForceLogout({
    required MotifDeconnexionForcee motif,
  }) async {
    dispose(); // Stop listening immediately

    // La déconnexion complète est celle d'`AuthNotifier` : même purge, même
    // retrait du jeton FCM, même bascule d'état que le bouton « Déconnexion ».
    // La dupliquer ici garantissait qu'elle diverge — c'est cette duplication
    // qui avait laissé ce chemin sans nettoyage.
    var traite = false;
    final deconnexionComplete = onForceLogout;
    if (deconnexionComplete != null) {
      try {
        traite = await deconnexionComplete();
      } catch (e) {
        debugPrint('SessionService: deconnexion complete en echec: $e');
      }
    }
    // Repli : personne n'a branché la déconnexion complète (ou elle a échoué).
    // Mieux vaut une sortie incomplète que pas de sortie du tout.
    if (!traite) {
      try {
        await FirebaseAuth.instance.signOut();
        await PreferencesService.instance.clearSessionId();
      } catch (e) {
        debugPrint('SessionService: repli de deconnexion forcee en echec: $e');
      }
    }

    // Show dialog
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    // `of(context)` et non `of(context)!` comme ailleurs : on est appelé depuis
    // un écouteur de flux, où une levée ne remonterait nulle part. Sans
    // traductions, la sortie a déjà eu lieu — seule l'explication manque.
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint('SessionService: traductions indisponibles, dialogue omis');
      return;
    }

    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => PopScope(
            canPop: false, // Prevent dismissing by back button
            child: AlertDialog(
              title: Text(switch (motif) {
                MotifDeconnexionForcee.connecteAilleurs =>
                  l10n.connectedElsewhere,
                MotifDeconnexionForcee.sessionFermeeParAdmin =>
                  l10n.sessionClosedByAdmin,
                MotifDeconnexionForcee.compteSuspendu => l10n.accountSuspended,
              }),
              content: Text(switch (motif) {
                MotifDeconnexionForcee.connecteAilleurs =>
                  l10n.connectedElsewhereMessage,
                MotifDeconnexionForcee.sessionFermeeParAdmin =>
                  l10n.sessionClosedByAdminMessage,
                MotifDeconnexionForcee.compteSuspendu =>
                  l10n.accountSuspendedMessage,
              }),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Navigate explicitly to login page
                    if (context.mounted) {
                      GoRouter.of(context).go('/auth/login');
                    }
                  },
                  child: Text(l10n.ok),
                ),
              ],
            ),
          ),
    ));
  }

  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = null;
    // Le canal doit partir avec le reste : laissé en vie, il continuerait de
    // parler au nom d'un compte sorti, et `_surveillerDecisionsAdmin` se
    // croirait déjà branché au compte suivant (garde `_canalAdmin != null`).
    final canal = _canalAdmin;
    _canalAdmin = null;
    if (canal != null) {
      unawaited(Supabase.instance.client.removeChannel(canal));
    }
    _isListening = false;
    // La session est terminée : garder son identifiant ferait comparer le
    // prochain écouteur à celui d'un compte sorti.
    _currentSessionId = null;
  }
}
