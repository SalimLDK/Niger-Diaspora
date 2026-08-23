import 'package:diaspo_niger/core/services/e2ee/models/e2ee_models.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/group_encryption_status_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un groupe pouvait rester en repli AES **indéfiniment, sans que rien ne le
/// signale** : la distribution de Sender Key échoue en silence pour un membre
/// avec qui aucune session Signal n'existe. On ne pouvait le découvrir qu'en
/// lisant `encryptionLevel` en base, message par message.
void main() {
  group('SenderKeyDistribution', () {
    test('complète quand tout le monde a reçu la clé', () {
      const d = SenderKeyDistribution(delivered: 2, missingMemberIds: []);
      expect(d.total, 2);
      expect(d.isComplete, isTrue);
    });

    test('incomplète dès qu\'un seul membre manque', () {
      const d = SenderKeyDistribution(
        delivered: 2,
        missingMemberIds: ['u3'],
      );
      expect(d.total, 3);
      expect(d.isComplete, isFalse);
    });

    test('un groupe sans autre membre n\'est pas « complet »', () {
      // Rien n'a été distribué à personne : rien ne garantit que la clé serve.
      // Sans cette garde, `missingMemberIds` vide suffirait à déclarer le
      // chiffrement de groupe actif.
      const d = SenderKeyDistribution(delivered: 0, missingMemberIds: []);
      expect(d.isComplete, isFalse);
    });
  });

  group('GroupEncryptionStatus.fromDistribution', () {
    test('distribution complète → chiffrement de groupe, sans noms à montrer', () {
      final status = GroupEncryptionStatus.fromDistribution(
        const SenderKeyDistribution(delivered: 2, missingMemberIds: []),
      );
      expect(status.level, GroupEncryptionLevel.senderKey);
      expect(status.membersWithoutKey, isEmpty);
    });

    test('distribution partielle → repli AES, et QUI manque', () {
      // C'est cette liste que l'utilisateur voit dans la feuille explicative :
      // un cadenas ouvert sans nom inquiète sans informer.
      final status = GroupEncryptionStatus.fromDistribution(
        const SenderKeyDistribution(
          delivered: 1,
          missingMemberIds: ['u2', 'u3'],
        ),
      );
      expect(status.level, GroupEncryptionLevel.aesFallback);
      expect(status.membersWithoutKey, ['u2', 'u3']);
    });

    test('aucun destinataire → repli AES aussi', () {
      final status = GroupEncryptionStatus.fromDistribution(
        const SenderKeyDistribution(delivered: 0, missingMemberIds: []),
      );
      expect(status.level, GroupEncryptionLevel.aesFallback);
    });
  });

  test('l\'état par défaut est « inconnu », pas « chiffré »', () {
    // Tant que la distribution n'a pas répondu, on n'affirme rien : afficher un
    // cadenas fermé par défaut est précisément ce qui masquait le problème.
    const status = GroupEncryptionStatus();
    expect(status.level, GroupEncryptionLevel.unknown);
    expect(status.membersWithoutKey, isEmpty);
  });

  test('clés locales absentes → repli AES, et une cause distincte', () {
    // Ce cas-là ne passe pas par `fromDistribution` : rien n'a pu être tenté,
    // donc aucun membre n'est en cause. Le message montré doit être différent,
    // sinon on accuse à tort quelqu'un du groupe.
    const status = GroupEncryptionStatus.keysUnavailable();
    expect(status.level, GroupEncryptionLevel.aesFallback);
    expect(status.localKeysUnavailable, isTrue);
    expect(status.membersWithoutKey, isEmpty);
  });

  test("une distribution partielle n'accuse PAS l'appareil local", () {
    final status = GroupEncryptionStatus.fromDistribution(
      const SenderKeyDistribution(delivered: 1, missingMemberIds: ['u2']),
    );
    expect(status.localKeysUnavailable, isFalse);
  });
}
