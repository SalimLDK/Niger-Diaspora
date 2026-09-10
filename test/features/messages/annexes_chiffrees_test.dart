import 'dart:convert';
import 'dart:io';

import 'package:diaspo_niger/core/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Trois choses écrivaient du contenu utilisateur **en clair** dans
/// `messages.data`, à côté d'un `content` chiffré :
///
/// 1. les cartes de partage (post, événement, annonce, aperçu de lien) — titre,
///    extrait, nom, image et URL cible de ce qui était partagé ;
/// 2. la citation d'un message auquel on répond, qui recopie son texte **déjà
///    déchiffré** : la plus coûteuse des trois, une conversation active en
///    laissant une trace lisible message après message ;
/// 3. la modification d'un message, qui réécrivait `content` en clair — donc
///    annulait le chiffrement — tout en laissant `encryptionLevel` annoncer
///    'e2ee', et gardait le texte d'avant dans un historique que rien
///    n'affiche.
///
/// Les deux premières voyagent maintenant dans un blob unique chiffré au repos
/// avec la clé dérivée de la conversation ; la troisième repasse par le chemin
/// de l'envoi.
///
/// Les tests de structure qui suivent valent surtout par ce qu'ils empêchent :
/// aucune de ces fuites ne produit d'erreur, ni à l'écran ni dans les logs.

/// Lit un fichier du dépôt en normalisant ses fins de ligne.
///
/// Selon qu'il vient d'être écrit ici ou d'un `checkout`, le même fichier
/// arrive en LF ou en CRLF : un motif qui contient un saut de ligne n'y
/// trouverait son compte qu'une fois sur deux. Un garde-fou qui ne tient qu'à
/// ça finit par échouer chez quelqu'un d'autre, et par être désactivé.
String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

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
      // La citation recopie le texte DÉJÀ DÉCHIFFRÉ du message cité : c'était
      // la plus coûteuse des cinq charges, une conversation active en laissant
      // une trace lisible message après message.
      'replyToMessageData': {
        'id': 'm-3',
        'senderName': 'Boubacar',
        'content': 'On se retrouve où exactement ?',
        'type': 'text',
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
        'Boubacar',
        'exactement',
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

  group('les chemins qui rouvriraient la fuite en silence', () {
    // Limite assumée : ces tests lisent la source. Monter la source de
    // données demanderait un `MessageCryptoService` complet — cinq
    // collaborateurs, dont Signal et un magasin de clés distant — pour
    // verrouiller deux lignes de structure.

    test('aucune des insertions ne porte de charge en clair', () {
      final source = _source(
        'lib/features/messages/data/datasources/message_supabase_datasource.dart',
      );

      // Cinq méthodes construisent un `msgData` : texte, média, note vocale,
      // localisation, sticker. Toutes acceptent une citation, et il a suffi
      // jusqu'ici d'en oublier une pour que la fuite subsiste.
      var debut = source.indexOf('final msgData = <String, dynamic>{');
      expect(debut, greaterThan(-1), reason: 'aucun msgData trouvé');

      var portantUneCitation = 0;
      while (debut != -1) {
        final fin = source.indexOf('\n      };', debut);
        expect(fin, greaterThan(debut), reason: 'fin de msgData introuvable');
        final insere = source.substring(debut, fin);

        for (final champ in [
          'postData',
          'eventData',
          'productData',
          'linkPreviewData',
          'replyToMessageData',
        ]) {
          expect(
            insere.contains("'$champ':"),
            isFalse,
            reason: '$champ repart en clair dans messages.data',
          );
        }

        if (insere.contains('...annexes,')) portantUneCitation++;
        debut = source.indexOf('final msgData = <String, dynamic>{', fin);
      }

      expect(
        portantUneCitation,
        5,
        reason:
            'les cinq envois doivent étaler la charge chiffrée ; '
            'un site sans `...annexes` est un site qui perd la citation',
      );
    });

    test('modifier un message ne le réécrit pas en clair', () {
      final source = _source(
        'lib/features/messages/data/datasources/message_supabase_datasource.dart',
      );

      final debut = source.indexOf('Future<void> editMessage({');
      expect(debut, greaterThan(-1));
      // `\n  }` seul s'arrêterait sur le `}) async {` de la liste de
      // paramètres, donc avant le corps — le test passerait à vide.
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));

      expect(
        corps.contains("data['content'] = newContent"),
        isFalse,
        reason: 'le texte modifié repart en clair',
      );
      expect(
        corps.contains('_encryptContent('),
        isTrue,
        reason: 'le texte modifié doit repasser par le chemin de l\'envoi',
      );
      // Un format périmé laissé à côté du neuf serait lu en premier par
      // `decrypt` : le message deviendrait illisible sans rien signaler.
      for (final perime in [
        "data.remove('e2eePayloads')",
        "data.remove('e2eePayload')",
        "data.remove('senderKeyPayload')",
      ]) {
        expect(corps.contains(perime), isTrue, reason: '$perime manquant');
      }
      expect(
        corps.contains("'content': oldContent"),
        isFalse,
        reason: 'l\'historique garde le texte d\'avant en clair',
      );
    });

    test('une modification est réécrite dans le cache local', () {
      final source = _source(
        'lib/features/messages/data/repositories/message_repository_impl.dart',
      );

      final debut = source.indexOf('Future<Either<Failure, void>> editMessage(');
      expect(debut, greaterThan(-1));
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));

      // L'expéditeur ne sait pas relire son propre message chiffré : les
      // charges Signal d'un 1:1 visent les appareils du destinataire. Sa bulle
      // vient du cache, et sans réécriture le soin depuis le cache faisait
      // revenir le texte d'avant à la réouverture de la conversation.
      expect(
        corps.contains('cacheService.cacheMessages('),
        isTrue,
        reason:
            'sans mise à jour du cache, la modification revient en arrière '
            'à la réouverture, sans erreur nulle part',
      );
    });

    test('le flux de mises à jour conserve la carte déjà déchiffrée', () {
      final source = _source(
        'lib/features/messages/presentation/providers/message_provider.dart',
      );

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
        'replyToMessageData: existing.replyToMessageData',
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
