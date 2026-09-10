import 'dart:convert';
import 'dart:io';

import 'package:diaspo_niger/core/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Une carte de partage (post, événement, annonce, aperçu de lien) ne transite
/// pas par `content` : elle ne passait donc pas par Signal, et partait **en
/// clair** dans `messages.data` — titre, extrait, nom, image et URL cible de ce
/// qui était partagé, lisibles dans un export de base ou par une règle RLS trop
/// large. Elle voyage désormais dans un blob unique, chiffré au repos avec la
/// clé dérivée de la conversation.
///
/// Deux propriétés à tenir, et la seconde est la plus traître.
void main() {
  group('la charge chiffrée ne laisse rien filtrer', () {
    // 32 octets : la taille attendue d'une clé dérivée. La valeur n'a pas
    // d'importance, seul le format en a.
    final cle = base64Encode(List<int>.filled(32, 7));
    final autreCle = base64Encode(List<int>.filled(32, 9));

    final charge = <String, dynamic>{
      'linkPreviewData': {
        'url': 'https://diasponiger.web.app/groups/g-42',
        'title': 'Diaspora Niamey — Montréal',
        'description': 'Groupe',
        'imageUrl': 'https://exemple.test/photo.jpg',
        'siteName': 'Diaspo Niger',
      },
      'postData': {
        'postId': 'p-7',
        'authorName': 'Amina Issoufou',
        'content': 'Rendez-vous samedi à la Maison du Niger — apportez le thé',
      },
    };

    test('le chiffré ne contient plus rien de lisible', () {
      final chiffre = EncryptionService.instance.encryptWithDerivedKey(
        jsonEncode(charge),
        keyBase64: cle,
        version: 3,
      );

      expect(EncryptionService.estFormatVersionne(chiffre), isTrue);
      expect(EncryptionService.versionDe(chiffre), 3);
      for (final fuite in [
        'Amina',
        'Niamey',
        'diasponiger.web.app',
        'g-42',
        'thé',
      ]) {
        expect(
          chiffre.contains(fuite),
          isFalse,
          reason: '« $fuite » se lit encore dans la charge chiffrée',
        );
      }
    });

    test('la charge se relit à l\'identique, structure comprise', () {
      final chiffre = EncryptionService.instance.encryptWithDerivedKey(
        jsonEncode(charge),
        keyBase64: cle,
        version: 3,
      );

      final clair = EncryptionService.instance.decryptWithDerivedKey(
        chiffre,
        keyBase64: cle,
      );

      expect(jsonDecode(clair), equals(charge));
    });

    test('avec la mauvaise clé, la lecture échoue en fermé', () {
      final chiffre = EncryptionService.instance.encryptWithDerivedKey(
        jsonEncode(charge),
        keyBase64: cle,
        version: 3,
      );

      final rate = EncryptionService.instance.decryptWithDerivedKey(
        chiffre,
        keyBase64: autreCle,
      );

      // `decryptWithDerivedKey` rend un marqueur plutôt que de lever. C'est ce
      // marqueur qui doit faire échouer la lecture de la carte : s'il était du
      // JSON valide, une carte vide s'afficherait à la place de rien.
      expect(() => jsonDecode(rate), throwsA(isA<FormatException>()));
    });
  });

  group('les deux chemins qui perdraient la carte en silence', () {
    // Limite assumée : ces deux tests lisent la source. Monter la source de
    // données demanderait un `MessageCryptoService` complet — cinq
    // collaborateurs, dont Signal et un magasin de clés distant — pour
    // verrouiller deux lignes de structure.

    test('la source de données n\'insère plus les charges en clair', () {
      final source =
          File(
            'lib/features/messages/data/datasources/message_supabase_datasource.dart',
          ).readAsStringSync();

      // La map réellement insérée, pas le modèle rendu à l'expéditeur : celui-ci
      // porte légitimement les charges en clair, il ne quitte pas l'appareil.
      final debut = source.indexOf('final msgData = <String, dynamic>{');
      expect(debut, greaterThan(-1), reason: 'msgData introuvable');
      final fin = source.indexOf('\n      };', debut);
      expect(fin, greaterThan(debut), reason: 'fin de msgData introuvable');
      final insere = source.substring(debut, fin);

      expect(
        insere.contains('...annexesChiffrees'),
        isTrue,
        reason: 'la charge chiffrée n\'est plus insérée',
      );
      for (final champ in [
        'postData',
        'eventData',
        'productData',
        'linkPreviewData',
      ]) {
        expect(
          insere.contains("'$champ':"),
          isFalse,
          reason: '$champ repart en clair dans messages.data',
        );
      }
    });

    test('le flux de mises à jour conserve la carte déjà déchiffrée', () {
      final source =
          File(
            'lib/features/messages/presentation/providers/message_provider.dart',
          ).readAsStringSync();

      final debut = source.indexOf('void _listenForMessageUpdates()');
      expect(debut, greaterThan(-1));
      final bloc = source.substring(debut, debut + 3000);

      // La ligne brute de l'update ne porte que le blob chiffré, que ce chemin
      // ne déchiffre pas : sans ce report, le premier accusé de lecture faisait
      // disparaître la carte de la bulle, sans erreur nulle part.
      for (final champ in [
        'postData: existing.postData',
        'eventData: existing.eventData',
        'productData: existing.productData',
        'linkPreviewData: existing.linkPreviewData',
      ]) {
        expect(
          bloc.contains(champ),
          isTrue,
          reason: 'l\'update écrase la carte : $champ manquant',
        );
      }
    });
  });
}
