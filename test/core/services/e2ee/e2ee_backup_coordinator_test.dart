import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/e2ee/e2ee_backup_coordinator.dart';
import 'package:diaspo_niger/core/services/e2ee/key_backup_service.dart';
import 'package:diaspo_niger/core/services/e2ee/key_manager_service.dart';
import 'package:diaspo_niger/core/services/e2ee/messaging_e2ee_service.dart';
import 'package:diaspo_niger/core/services/e2ee/secure_key_storage.dart';

/// Mise en veille des rappels de sauvegarde / restauration des clés.
///
/// Deux bandeaux répètent le même message : celui de `MainShell` et celui posé
/// en tête de conversation. Le second n'avait aucune veille — écarter le
/// premier ne le faisait pas taire. Les deux lisent désormais le même état,
/// [e2eeRestoreNudgeMutedProvider], que ce test tient avec l'état proposé.
///
/// Le test tient les DEUX bords : ce qui doit se taire, et ce qui doit
/// continuer à parler. Se taire trop large laisserait un appareil sans clés
/// sur le repli AES sans que personne ne le sache jamais.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'utilisateur-1';
  const cleRestore = 'e2ee_prompt_snoozed_needsRestore_$uid';

  /// Valeur sentinelle de « plus jamais » écrite par `dismissForever`.
  const muetAVie = -1;

  ProviderContainer conteneur({
    bool clesLocales = false,
    BackupPresence presence = BackupPresence.present,
  }) {
    final c = ProviderContainer(
      overrides: [
        secureKeyStorageProvider.overrideWithValue(_StockageFake()),
        keyManagerServiceProvider.overrideWithValue(
          _GestionnaireFake(clesLocales),
        ),
        messagingE2EEServiceProvider.overrideWithValue(_MessagerieFake()),
        keyBackupServiceProvider.overrideWithValue(_SauvegardeFake(presence)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// `acknowledge` et `dismissForever` persistent en `unawaited` pour ne pas
  /// retarder l'interface : laisser l'écriture se terminer avant de relire.
  Future<void> laisserEcrire() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('sans veille, la restauration est proposée et les bandeaux parlent',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = conteneur();

    await c.read(e2eeBackupCoordinatorProvider.notifier).bootstrap(uid);

    expect(c.read(e2eeBackupCoordinatorProvider), E2EEBackupPrompt.needsRestore);
    expect(c.read(e2eeRestoreNudgeMutedProvider), isFalse);
  });

  test('« Ne plus me le rappeler » tient après un redémarrage à froid',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = conteneur();
    final coordinateur = c.read(e2eeBackupCoordinatorProvider.notifier);
    await coordinateur.bootstrap(uid);

    coordinateur.dismissForever();

    expect(c.read(e2eeBackupCoordinatorProvider), E2EEBackupPrompt.none);
    expect(
      c.read(e2eeRestoreNudgeMutedProvider),
      isTrue,
      reason: 'le bandeau de conversation ne lit que ce drapeau',
    );
    await laisserEcrire();

    // Relance à froid : nouveau conteneur, mêmes préférences.
    final c2 = conteneur();
    await c2.read(e2eeBackupCoordinatorProvider.notifier).bootstrap(uid);

    expect(c2.read(e2eeBackupCoordinatorProvider), E2EEBackupPrompt.none);
    expect(c2.read(e2eeRestoreNudgeMutedProvider), isTrue);
  });

  test('« Pas maintenant » ne tait les deux bandeaux que sept jours', () async {
    SharedPreferences.setMockInitialValues({
      cleRestore:
          DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
    });
    final recent = conteneur();
    await recent.read(e2eeBackupCoordinatorProvider.notifier).bootstrap(uid);

    expect(recent.read(e2eeBackupCoordinatorProvider), E2EEBackupPrompt.none);
    expect(recent.read(e2eeRestoreNudgeMutedProvider), isTrue);

    SharedPreferences.setMockInitialValues({
      cleRestore:
          DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
    });
    final perime = conteneur();
    await perime.read(e2eeBackupCoordinatorProvider.notifier).bootstrap(uid);

    expect(
      perime.read(e2eeBackupCoordinatorProvider),
      E2EEBackupPrompt.needsRestore,
      reason: 'une veille de sept jours doit finir par expirer',
    );
    expect(perime.read(e2eeRestoreNudgeMutedProvider), isFalse);
  });

  test('une sauvegarde ou une restauration réelle rend la parole aux bandeaux',
      () async {
    SharedPreferences.setMockInitialValues({cleRestore: muetAVie});
    final c = conteneur();
    final coordinateur = c.read(e2eeBackupCoordinatorProvider.notifier);
    await coordinateur.bootstrap(uid);
    expect(c.read(e2eeRestoreNudgeMutedProvider), isTrue);

    await coordinateur.clearSnooze(uid);

    expect(c.read(e2eeRestoreNudgeMutedProvider), isFalse);

    final c2 = conteneur();
    await c2.read(e2eeBackupCoordinatorProvider.notifier).bootstrap(uid);
    expect(
      c2.read(e2eeBackupCoordinatorProvider),
      E2EEBackupPrompt.needsRestore,
      reason: 'la veille effacée, une situation neuve se represente',
    );
  });

  test('taire l\'invitation à sauvegarder ne tait pas le rappel de restauration',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = conteneur(presence: BackupPresence.absent);
    final coordinateur = c.read(e2eeBackupCoordinatorProvider.notifier);
    await coordinateur.bootstrap(uid);
    expect(c.read(e2eeBackupCoordinatorProvider), E2EEBackupPrompt.needsBackup);

    coordinateur.dismissForever();

    expect(
      c.read(e2eeRestoreNudgeMutedProvider),
      isFalse,
      reason: 'deux rappels distincts, deux veilles distinctes',
    );
    await laisserEcrire();

    // Plus tard, appareil neuf : la sauvegarde existe et doit être restaurée.
    final c2 = conteneur(presence: BackupPresence.present);
    await c2.read(e2eeBackupCoordinatorProvider.notifier).bootstrap(uid);

    expect(
      c2.read(e2eeBackupCoordinatorProvider),
      E2EEBackupPrompt.needsRestore,
    );
    expect(c2.read(e2eeRestoreNudgeMutedProvider), isFalse);
  });
}

/// Doublures : seul ce que le coordinateur appelle est implémenté, le reste
/// part en `noSuchMethod` plutôt que d'obliger à recopier des interfaces
/// entières (Firebase Storage, Signal, stockage sécurisé).
class _Doublure {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non doublée');
}

class _StockageFake extends _Doublure implements SecureKeyStorage {
  @override
  Future<void> initialize() async {}
}

class _GestionnaireFake extends _Doublure implements KeyManagerService {
  _GestionnaireFake(this._clesLocales);

  final bool _clesLocales;

  @override
  Future<bool> hasKeys(String userId) async => _clesLocales;
}

class _MessagerieFake extends _Doublure implements MessagingE2EEService {
  @override
  Future<void> initialize(String userId) async {}
}

class _SauvegardeFake extends _Doublure implements KeyBackupService {
  _SauvegardeFake(this._presence);

  final BackupPresence _presence;

  @override
  Future<BackupPresence> checkBackupPresence(String userId) async => _presence;
}
