import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduit exactement ce que fait l'application : la SIGNATURE côté
/// publication (`KeyManagerService._sign`) et la VÉRIFICATION côté
/// établissement de session (`MessagingE2EEService._verifySignedPreKeySignature`).
///
/// Le journal de l'appareil accusait un « Possible MITM attack » sur le compte
/// plateforme. Ces tests montrent que la clé n'y est pour rien : les deux côtés
/// n'utilisent tout simplement pas la même clé publique.
void main() {
  final x25519 = X25519();
  final ed25519 = Ed25519();

  /// Ce que fait `KeyManagerService`: une Identity Key **X25519**…
  Future<({Uint8List publicKey, Uint8List privateKey})> identityKeyPair() async {
    final kp = await x25519.newKeyPair();
    return (
      publicKey: Uint8List.fromList((await kp.extractPublicKey()).bytes),
      privateKey: Uint8List.fromList(await kp.extractPrivateKeyBytes()),
    );
  }

  /// …dont la clé PRIVÉE sert de graine à un couple **Ed25519** pour signer.
  Future<Uint8List> signLikeKeyManager(
    Uint8List data,
    Uint8List identityPrivateKey,
  ) async {
    final kp = await ed25519.newKeyPairFromSeed(identityPrivateKey);
    final sig = await ed25519.sign(data, keyPair: kp);
    return Uint8List.fromList(sig.bytes);
  }

  test(
    "la vérification échoue TOUJOURS : elle utilise la clé publique X25519 "
    "là où la signature vient d'un couple Ed25519 dérivé de la clé privée",
    () async {
      final identity = await identityKeyPair();
      final signedPreKey = await x25519.newKeyPair();
      final signedPreKeyPublic = Uint8List.fromList(
        (await signedPreKey.extractPublicKey()).bytes,
      );

      final signature = await signLikeKeyManager(
        signedPreKeyPublic,
        identity.privateKey,
      );

      // Ce que fait `_verifySignedPreKeySignature` : vérifier avec les octets
      // de l'Identity Key **publique X25519**, réétiquetés « ed25519 ».
      final verifiedTheAppWay = await ed25519.verify(
        signedPreKeyPublic,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            identity.publicKey,
            type: KeyPairType.ed25519,
          ),
        ),
      );

      // Aucune clé n'est corrompue, il n'y a pas d'attaquant : les deux clés
      // publiques sont simplement différentes.
      expect(
        verifiedTheAppWay,
        isFalse,
        reason: 'si ceci passe au vert, le défaut est corrigé ailleurs',
      );
    },
  );

  test(
    'la même signature vérifie parfaitement avec la BONNE clé publique '
    'Ed25519 — celle dérivée de la même graine',
    () async {
      final identity = await identityKeyPair();
      final signedPreKey = await x25519.newKeyPair();
      final signedPreKeyPublic = Uint8List.fromList(
        (await signedPreKey.extractPublicKey()).bytes,
      );

      final signature = await signLikeKeyManager(
        signedPreKeyPublic,
        identity.privateKey,
      );

      // La clé publique qui correspond vraiment à la signature.
      final signingKeyPair = await ed25519.newKeyPairFromSeed(
        identity.privateKey,
      );
      final signingPublicKey = await signingKeyPair.extractPublicKey();

      final verified = await ed25519.verify(
        signedPreKeyPublic,
        signature: Signature(signature, publicKey: signingPublicKey),
      );

      expect(verified, isTrue);
    },
  );

  test(
    'et ces deux clés publiques ne sont jamais égales : X25519 et Ed25519 '
    'dérivent différemment la publique de la privée',
    () async {
      final identity = await identityKeyPair();
      final signingKeyPair = await ed25519.newKeyPairFromSeed(
        identity.privateKey,
      );
      final signingPublicKey = await signingKeyPair.extractPublicKey();

      expect(signingPublicKey.bytes, isNot(equals(identity.publicKey)));
    },
  );
}
