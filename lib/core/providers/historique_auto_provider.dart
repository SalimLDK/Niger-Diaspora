import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/messages/presentation/providers/media_dechiffre_provider.dart';
import '../services/e2ee/historique_backup_service.dart';
import 'uid_firebase_provider.dart';

/// Déclenche la sauvegarde automatique de l'historique des discussions chiffrées.
///
/// **Permanent** : surveillé à la racine (`app.dart`), comme
/// `lectureALArriveeProvider` — aucun écran n'a à être ouvert pour que la
/// sauvegarde parte.
///
/// Deux moments : quelques minutes après le lancement (le téléphone vient de
/// se réveiller, le réseau est là), et à la mise en arrière-plan. Le service
/// décide lui-même s'il y a quelque chose à faire ([HistoriqueBackupService.
/// sauvegardeAutomatique] : fonction activée, dernier envoi de plus de 24 h),
/// donc appeler trop souvent ne coûte rien.
///
/// Dépend de l'uid et du drapeau MLS : un compte qui n'est pas passé à MLS n'a
/// pas de clair local à sauvegarder, et l'uid lu à la construction serait figé
/// à `null` au démarrage à froid (cf. [uidFirebaseProvider]).
final historiqueAutoProvider = Provider<void>((ref) {
  final uid = ref.watch(uidFirebaseProvider);
  if (uid == null) return;
  if (!ref.watch(mlsMessagesActifsProvider)) return;

  final service = ref.read(historiqueBackupServiceProvider);
  void tenter() => unawaited(service.sauvegardeAutomatique(uid));

  final depart = Timer(const Duration(minutes: 3), tenter);
  final observateur = _ObservateurArrierePlan(tenter);
  WidgetsBinding.instance.addObserver(observateur);

  ref.onDispose(() {
    depart.cancel();
    WidgetsBinding.instance.removeObserver(observateur);
  });
});

class _ObservateurArrierePlan extends WidgetsBindingObserver {
  _ObservateurArrierePlan(this._surArrierePlan);

  final void Function() _surArrierePlan;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _surArrierePlan();
  }
}
