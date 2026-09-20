import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart' show routerProvider;
import '../router/emplacement_affiche.dart';
import '../services/lecture_a_l_arrivee.dart';
import '../services/supabase_auth_bridge.dart';
import 'uid_firebase_provider.dart';

/// Branche [LectureALArrivee] au temps réel : chaque notification insérée pour
/// le compte connecté est confrontée à l'écran affiché.
///
/// **Permanent** : surveillé à la racine (`app.dart`), pas par un widget. La
/// liste des notifications a son propre canal, mais son provider ne vit que
/// tant qu'un écran l'écoute (la cloche, l'écran Notifications) — sur une page
/// ouverte par lien profond, rien ne garantit qu'il soit là.
///
/// Dépend de [uidFirebaseProvider] : à la connexion ou à la déconnexion, le
/// provider est reconstruit, l'ancien canal fermé et un nouveau ouvert. Lire
/// l'uid ici, à la construction, l'aurait figé à `null` au démarrage à froid
/// (cf. le commentaire de [uidFirebaseProvider]).
///
/// Best-effort de bout en bout : un canal qui ne s'ouvre pas, ou un événement
/// manqué, laisse la notification non lue jusqu'à la prochaine ouverture de son
/// écran — c'est ce qui se passait avant.
final lectureALArriveeProvider = Provider<void>((ref) {
  final uid = ref.watch(uidFirebaseProvider);
  if (uid == null) return;

  final lecteur = LectureALArrivee(
    // Relu à chaque arrivée : le routeur peut avoir été reconstruit.
    emplacement: () => emplacementAffiche(ref.read(routerProvider)),
    // Strictement `resumed` : `inactive` (volet système, boîte de dialogue de
    // permission) et `paused` (écran éteint) ne sont PAS un regard.
    auPremierPlan: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
  );
  final abonnement = _AbonnementAuxArrivees(
    uid: uid,
    surInsertion: lecteur.surInsertion,
  );
  unawaited(abonnement.demarrer());
  ref.onDispose(abonnement.arreter);
});

/// Le canal `INSERT` sur `notifications` d'un compte, rouvert quand il tombe.
class _AbonnementAuxArrivees {
  _AbonnementAuxArrivees({required this.uid, required this.surInsertion});

  final String uid;
  final Future<bool> Function(Map<String, dynamic> ligne) surInsertion;

  RealtimeChannel? _canal;
  Timer? _reprise;
  bool _arrete = false;
  int _echecs = 0;

  Future<void> demarrer() async {
    if (_arrete) return;
    try {
      // Une session lisible AVANT de s'abonner : abonné en `anon`, le canal ne
      // livrerait rien (RLS `notifications_own`) et ne dirait pas pourquoi. La
      // liste des notifications a eu cette course à l'ouverture.
      //
      // Et si elle ne l'est pas — l'échange Firebase → Supabase d'un compte
      // neuf échoue une première fois —, on ne s'abonne PAS quand même : le
      // canal se dirait `subscribed`, ne livrerait jamais rien, et aucune
      // nouvelle tentative ne serait planifiée.
      final prete = await SupabaseAuthBridge.instance.ensureReadableSession();
      if (_arrete) return;
      if (!prete) {
        debugPrint('LectureALArrivee: pas de session Supabase lisible — on réessaie');
        _reessayerPlusTard();
        return;
      }

      _canal = Supabase.instance.client
          .channel(
            'notifications-arrivees:$uid:'
            '${DateTime.now().microsecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (payload) {
              if (_arrete) return;
              unawaited(surInsertion(payload.newRecord));
            },
          )
          .subscribe((statut, [erreur]) {
            if (_arrete) return;
            switch (statut) {
              case RealtimeSubscribeStatus.subscribed:
                _echecs = 0;
              case RealtimeSubscribeStatus.closed:
              case RealtimeSubscribeStatus.timedOut:
              case RealtimeSubscribeStatus.channelError:
                _reessayerPlusTard();
            }
          });
    } catch (e) {
      debugPrint('LectureALArrivee: abonnement impossible ($e)');
      _reessayerPlusTard();
    }
  }

  /// Sans plafond de tentatives — un mobile passe des heures hors réseau et il
  /// faut être là au retour —, mais l'attente plafonne à une minute.
  void _reessayerPlusTard() {
    if (_arrete || _reprise != null) return;
    final attente = Duration(seconds: math.min(60, 2 << math.min(_echecs, 5)));
    _echecs++;
    _reprise = Timer(attente, () async {
      _reprise = null;
      if (_arrete) return;
      await _fermerCanal();
      await demarrer();
    });
  }

  Future<void> _fermerCanal() async {
    final canal = _canal;
    _canal = null;
    if (canal == null) return;
    try {
      await Supabase.instance.client.removeChannel(canal);
    } catch (e) {
      debugPrint('LectureALArrivee: fermeture du canal ($e)');
    }
  }

  void arreter() {
    _arrete = true;
    _reprise?.cancel();
    unawaited(_fermerCanal());
  }
}
