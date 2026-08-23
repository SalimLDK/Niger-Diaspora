import 'dart:convert';
import 'dart:typed_data';

import 'package:diaspo_niger/core/services/e2ee/models/e2ee_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chiffrer avec une Sender Key **non distribuée** produit un message que
/// personne ne peut lire — pas même son auteur, le ratchet ayant avancé à
/// l'émission — et ce n'est pas rattrapable : `decryptWithSenderKey` refuse un
/// index de chaîne passé, donc distribuer ensuite arrive toujours trop tard
/// d'un cran.
///
/// `isDistributed` est le garde-fou. Ces tests fixent son comportement, y
/// compris pour les clés déjà en stockage.
void main() {
  E2EESenderKey key({bool? distributed}) => E2EESenderKey(
    groupId: 'g1',
    senderId: 'u1',
    senderDeviceId: 1,
    keyId: 42,
    chainKey: Uint8List.fromList(List.filled(32, 7)),
    signatureKeyPublic: Uint8List.fromList(List.filled(32, 9)),
    signatureKeyPrivate: Uint8List.fromList(List.filled(32, 3)),
    chainIndex: 0,
    isDistributed: distributed ?? false,
  );

  group('isDistributed', () {
    test('le défaut est faux', () {
      expect(key().isDistributed, isFalse);
    });

    test('survit à un aller-retour JSON', () {
      final distributed = key(distributed: true);
      final revenue = E2EESenderKey.fromJson(
        jsonDecode(jsonEncode(distributed.toJson())) as Map<String, dynamic>,
      );
      expect(revenue.isDistributed, isTrue);
      expect(revenue.chainIndex, distributed.chainIndex);
      expect(revenue.keyId, distributed.keyId);
    });

    test(
      'une clé déjà en stockage, écrite AVANT le correctif, revient non distribuée',
      () {
        // C'est le cas qui compte : ces clés ont été fabriquées à l'émission
        // par l'ancien chemin, sans jamais être remises à personne. Les relire
        // comme « distribuées » ferait produire de nouveaux messages illisibles.
        final ancien = key().toJson()..remove('isDistributed');
        expect(E2EESenderKey.fromJson(ancien).isDistributed, isFalse);
      },
    );

    test('copyWith la pose sans toucher au reste', () {
      final avant = key();
      final apres = avant.copyWith(isDistributed: true);
      expect(apres.isDistributed, isTrue);
      expect(apres.keyId, avant.keyId);
      expect(apres.chainIndex, avant.chainIndex);
      expect(apres.chainKey, avant.chainKey);
      expect(apres.signatureKeyPrivate, avant.signatureKeyPrivate);
    });

    test('copyWith du ratchet ne perd pas le drapeau', () {
      // `encryptWithSenderKey` fait avancer la chaîne par copyWith après chaque
      // message : si le drapeau se perdait là, le groupe retomberait en AES au
      // deuxième message.
      final distribuee = key(distributed: true);
      final ratchetee = distribuee.copyWith(
        chainKey: Uint8List.fromList(List.filled(32, 8)),
        chainIndex: distribuee.chainIndex + 1,
      );
      expect(ratchetee.isDistributed, isTrue);
      expect(ratchetee.chainIndex, 1);
    });
  });
}
