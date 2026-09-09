import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/key_backup_service.dart';
import 'package:diaspo_niger/core/services/e2ee/secure_key_storage.dart';

/// Une sauvegarde vide est pire que pas de sauvegarde.
///
/// `exportAllKeys` ne proteste pas quand l'appareil n'a aucune identité : il
/// rend une carte de champs nuls. Sans garde, un téléphone sans clés produisait
/// donc une sauvegarde parfaitement chiffrée… et parfaitement vide. Ensuite le
/// coordinateur voit « une sauvegarde existe », refuse de générer une identité
/// neuve pour ne pas la rendre irrécupérable, et le compte reste bloqué sur le
/// repli AES avec un bandeau qui réclame une restauration impossible.
///
/// Vu en vrai le 2026-09-08 : « Cet appareil n'a pas vos clés » affiché
/// au-dessus de « Sauvegarde active — créée il y a une minute depuis cet
/// appareil ».
void main() {
  test('sauvegarder sans clés est refusé', () {
    final service = KeyBackupService(storage: _StockageSansCles());

    expect(
      () => service.createBackup('utilisateur-1', 'passphrase-assez-longue'),
      throwsA(isA<NoKeysToBackupException>()),
    );
  });

  test('la passphrase courte reste refusée avant tout le reste', () {
    // L'ordre compte : une passphrase trop courte doit être signalée pour ce
    // qu'elle est, pas maquillée en « pas de clés ».
    final service = KeyBackupService(storage: _StockageSansCles());

    expect(
      () => service.createBackup('utilisateur-1', 'court'),
      throwsA(isA<ArgumentError>()),
    );
  });
}

/// Doublure : seul ce que `createBackup` interroge est implémenté, le reste
/// part en `noSuchMethod`.
class _StockageSansCles implements SecureKeyStorage {
  @override
  Future<bool> hasE2EEKeys(String userId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non doublée');
}
