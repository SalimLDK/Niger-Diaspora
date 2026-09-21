import 'dart:io';

import 'package:diaspo_niger/core/services/e2ee/media_dechiffre_cache.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS, C4 tranche 1)
/// ----------------------------------------------------
/// Un média chiffré n'est lisible qu'avec la clé de fichier qui voyage dans
/// le message. Trois choses ne doivent jamais se produire, et aucune ne
/// produirait d'erreur visible :
///
/// 1. la clé écrite **en clair** dans `messages.data` (elle ne doit exister
///    que sous `encMedia`, chiffrée avec la clé dérivée de la conversation) ;
/// 2. la clé scellée avec la clé **globale** de l'APK, lisible par tout
///    porteur de l'app — le repli que `chiffrerAnnexe` accepte pour une carte
///    de partage, et qu'il faut refuser ici ;
/// 3. la clé **perdue** en cours de route : sur le flux de mises à jour (ligne
///    brute), au premier accusé de lecture, la photo deviendrait illisible.
///
/// Les tests de structure lisent le code source : c'est grossier, mais c'est
/// ce qui a manqué à chaque câblage mort de ce dépôt.

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('MediaChiffre', () {
    const media = MediaChiffre(
      storagePath: 'encrypted_media/c1/u1/image_1_000001.enc',
      encryptedUrl: 'https://exemple.test/blob',
      fileKeyBase64: 'AAAA',
      ivBase64: 'BBBB',
      fileName: 'vacances.jpg',
      mimeType: 'image/jpeg',
      size: 1234,
    );

    test('aller-retour JSON sans perte', () {
      expect(MediaChiffre.fromJson(media.toJson()), media);
    });

    test('incomplet sans clé, sans IV ou sans chemin', () {
      expect(media.estComplet, isTrue);
      expect(
        MediaChiffre.fromJson({...media.toJson(), 'fileKey': ''}).estComplet,
        isFalse,
      );
      expect(
        MediaChiffre.fromJson({...media.toJson(), 'iv': null}).estComplet,
        isFalse,
      );
      expect(
        MediaChiffre.fromJson({...media.toJson()}..remove('storagePath'))
            .estComplet,
        isFalse,
      );
    });

    test('traverse modèle → entité → modèle → JSON (cache Hive)', () {
      final modele = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Amina',
        'type': 'image',
        'fileUrl': 'https://exemple.test/blob',
        'fileName': 'vacances.jpg',
        'mediaChiffre': media.toJson(),
      });
      final entite = modele.toEntity();
      expect(entite.mediaChiffre, media);
      expect(entite.fileName, 'vacances.jpg');

      final retour = MessageModel.fromEntity(entite).toJson();
      expect(retour['mediaChiffre'], media.toJson());
    });

    test('copyWith conserve le média quand on ne le touche pas', () {
      final entite = MessageEntity(
        id: 'm1',
        senderId: 'u1',
        senderName: 'Amina',
        content: '',
        type: MessageType.image,
        status: MessageStatus.sent,
        createdAt: DateTime(2026, 9, 14),
        mediaChiffre: media,
      );
      expect(entite.copyWith(fileUrl: 'file:///tmp/x.jpg').mediaChiffre, media);
    });
  });

  group('MediaDechiffreCache', () {
    test("nom de fichier : l'id du message et l'extension du MIME, rien d'autre",
        () {
      expect(
        MediaDechiffreCache.nomDeFichier('abc-123', 'image/jpeg'),
        'abc-123.jpg',
      );
      expect(
        MediaDechiffreCache.nomDeFichier('../../etc/passwd', 'audio/mp4'),
        '______etc_passwd.m4a',
      );
      expect(
        MediaDechiffreCache.extensionPour('application/x-inconnu'),
        '.bin',
      );
    });
  });

  group('datasource', () {
    final source = _source(
      'lib/features/messages/data/datasources/message_supabase_datasource.dart',
    );

    test('le nom générique remplace le nom d’origine en base', () {
      expect(MessageSupabaseDataSource.nomGeneriquePour('image'), 'photo');
      expect(
        MessageSupabaseDataSource.nomGeneriquePour('voiceNote'),
        'note-vocale',
      );
      expect(MessageSupabaseDataSource.nomGeneriquePour('file'), 'document');
    });

    test('la clé de fichier ne part jamais en clair dans msgData', () {
      // Aucun littéral `'fileKey':` ni `'mediaChiffre':` dans une map
      // envoyée à Supabase : la seule écriture est le blob scellé.
      final envois = RegExp(r"await _supabase\.from\('messages'\)\.insert\(");
      expect(envois.hasMatch(source), isTrue);
      expect(source.contains("'fileKey':"), isFalse);
      expect(
        'if (mediaChiffre != null) _kChampMediaChiffre: mediaChiffre,'
            .allMatches(source)
            .length,
        2,
        reason: 'la forme en clair ne vit que dans le modèle rendu à '
            "l'expéditeur (média et note vocale)",
      );
    });

    test('le scellement refuse le repli sur la clé globale', () {
      expect(source, contains("scelle.split(':').length < 3"));
      expect(
        source,
        contains("'Clé de conversation indisponible : média non envoyé'"),
      );
    });

    test('la lecture fusionne le média après les annexes', () {
      expect(
        source,
        contains(
          "await _fusionnerAnnexes(data, row['conversation_id'] as String?);\n"
          "      await _fusionnerMedia(data, row['conversation_id'] as String?);",
        ),
      );
    });

    test('« supprimer pour tous » emporte la clé', () {
      expect(source, contains('data.remove(_kMediaChiffre);'));
    });
  });

  group('présentation', () {
    test('le flux de mises à jour rappelle le média déjà déchiffré', () {
      // La fusion vit dans `fusionnerLigneBrute`, que le fournisseur appelle.
      expect(
        _source(
          'lib/features/messages/presentation/providers/message_provider.dart',
        ),
        contains('fusionnerLigneBrute('),
      );
      final source = _source(
        'lib/features/messages/presentation/providers/modification_recue.dart',
      );
      expect(source, contains('mediaChiffre: affiche.mediaChiffre,'));
      expect(source, contains('fileName: affiche.fileName,'));
    });

    test('chaque bulle média passe par la barrière', () {
      final source = _source(
        'lib/features/messages/presentation/widgets/message_bubble.dart',
      );
      // Chaque type apparaît deux fois : la branche « média local, envoi en
      // cours » (pas de barrière, le fichier est déjà sur disque) et la
      // branche réseau, qui doit passer par la barrière.
      for (final cas in ['image', 'file', 'audio', 'voiceNote']) {
        final blocs = 'case MessageType.$cas:'.allMatches(source).toList();
        expect(blocs, isNotEmpty, reason: cas);
        final unePasseParLaBarriere = blocs.any(
          (b) => source.substring(b.end, b.end + 200).contains('MediaChiffreGate('),
        );
        expect(unePasseParLaBarriere, isTrue, reason: cas);
      }
    });

    test('la galerie lit un média local ou distant sans distinction', () {
      final source = _source(
        'lib/features/messages/presentation/widgets/media_gallery_grid.dart',
      );
      expect(source.contains('CachedNetworkImage('), isFalse);
      expect('ImageLocaleOuReseau('.allMatches(source).length, 2);
      expect('MediaChiffreGate('.allMatches(source).length, 2);
    });
  });
}
