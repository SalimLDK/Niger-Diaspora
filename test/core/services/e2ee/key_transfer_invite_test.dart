import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/key_transfer_service.dart';

/// Le rendez-vous porté par le QR du transfert de clés.
///
/// C'est la seule pièce du transfert qui traverse un canal ouvert : la caméra
/// lit tout ce qui passe devant elle, y compris les QR de partage de profil de
/// l'app et ceux d'autres applications. `tryParse` doit donc rendre `null` sans
/// broncher sur tout ce qui n'est pas une invitation de cette version — un
/// throw ferait planter le scanner à chaque code étranger.
void main() {
  const uid = 'utilisateur-1';
  final key = List<int>.generate(32, (i) => i);

  test('un rendez-vous se relit tel qu il a été écrit', () {
    final invite = KeyTransferInvite(id: 'abc123', userId: uid, key: key);

    final relu = KeyTransferInvite.tryParse(invite.encode());

    expect(relu, isNotNull);
    expect(relu!.id, 'abc123');
    expect(relu.userId, uid);
    expect(relu.key, key);
  });

  test('les QR étrangers sont ignorés, pas rejetés bruyamment', () {
    for (final etranger in [
      'https://diasponiger.web.app/u/sim',
      'dn-e2ee-transfer:2:abc:uid:${base64Url.encode(key)}',
      'dn-e2ee-transfer:1:abc:uid',
      '',
      'n importe quoi',
    ]) {
      expect(
        KeyTransferInvite.tryParse(etranger),
        isNull,
        reason: 'refusé sans exception : $etranger',
      );
    }
  });

  test('une clé qui n a pas la bonne taille est refusée', () {
    final courte = base64Url.encode(List<int>.filled(16, 7));

    expect(
      KeyTransferInvite.tryParse('dn-e2ee-transfer:1:abc:$uid:$courte'),
      isNull,
      reason: 'AES-256 attend 32 octets : plus court, ce n est pas notre QR',
    );
  });

  test('le compte visé voyage dans le QR', () {
    // Sans lui, l ancien téléphone livrerait ses clés au QR de n importe qui :
    // c est la seule chose qui lui permet de refuser un autre compte.
    final invite = KeyTransferInvite(id: 'x', userId: 'compte-a', key: key);

    expect(KeyTransferInvite.tryParse(invite.encode())!.userId, 'compte-a');
  });
}
