import 'dart:io';
import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Les messages éphémères étaient **morts en silence** sur le chemin de
/// production. Trois pièces existaient — l'écran de réglage, l'écriture de
/// `conversations.data->>'autoDeleteAfterSeconds'`, et `MessageModel.
/// expiresAt` qui savait se sérialiser — et rien ne les reliait :
///
/// 1. `MessageSupabaseDataSource`, le seul datasource branché, ne lisait
///    jamais le minuteur à l'envoi et ne posait jamais `expiresAt`. Seul
///    l'ancien datasource Firestore le faisait, dans **cinq copies** du même
///    calcul — dont aucune n'a survécu au portage ;
/// 2. aucun balayage serveur ne faisait rien expirer ;
/// 3. côté MLS, `mls_messages.expires_at` existait sans que personne ne
///    l'écrive, et le payload ne portait aucune durée.
///
/// Activer le minuteur n'avait donc **aucun effet observable**, et rien nulle
/// part ne le disait — ni erreur, ni journal, ni indice à l'écran. C'est cette
/// classe de panne que les tests de structure ci-dessous visent : ils ne
/// vérifient pas qu'un calcul est juste, ils vérifient qu'il n'a pas disparu.

/// Lit un fichier du dépôt en normalisant ses fins de ligne : selon qu'il
/// vient d'être écrit ici ou d'un `checkout`, le même fichier arrive en LF ou
/// en CRLF.
String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

MlsMessageRow _ligne({
  DateTime? creeLe,
  DateTime? expireLe,
  bool supprime = false,
}) =>
    MlsMessageRow(
      id: '11111111-1111-4111-8111-111111111111',
      conversationId: 'c1',
      senderId: 'u1',
      senderDeviceId: '22222222-2222-4222-8222-222222222222',
      epoch: 3,
      kind: 'content',
      contentType: 'text',
      ciphertext: Uint8List.fromList(const [1, 2, 3]),
      isDeleted: supprime,
      createdAt: creeLe ?? DateTime.utc(2026, 9, 15, 12),
      expiresAt: expireLe,
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // La durée voyage dans le payload chiffré
  // ═══════════════════════════════════════════════════════════════════════
  group('payload MLS : le minuteur voyage chiffré', () {
    test('un aller-retour JSON conserve le ttl', () {
      final p = MlsPayload(
        id: 'm1',
        type: 'text',
        sentAt: 1_700_000_000_000,
        body: const {'content': 'salut'},
        ttl: 86400,
      );
      expect(MlsPayload.decode(p.encode()).ttl, 86400);
    });

    test('pas de minuteur : la clé ttl est absente du JSON', () {
      final p = MlsPayload(
        id: 'm1',
        type: 'text',
        sentAt: 1_700_000_000_000,
        body: const {'content': 'salut'},
      );
      // Absente, et pas « présente à null » : un client plus ancien qui lit ce
      // JSON ne doit pas croire à un minuteur de zéro seconde.
      expect(p.toJson().containsKey('ttl'), isFalse);
      expect(MlsPayload.decode(p.encode()).ttl, isNull);
    });

    test("l'échéance se compte depuis l'horodatage SERVEUR, pas sentAt", () {
      // Le cas qui compte : un expéditeur (ou un appareil à l'heure fausse)
      // annonce un `sentAt` vieux de dix jours. Si l'échéance se comptait
      // depuis lui, le message arriverait déjà expiré chez tout le monde.
      final creeLe = DateTime.utc(2026, 9, 15, 12);
      final p = MlsPayload(
        id: 'm1',
        type: 'text',
        sentAt: DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
        body: const {'content': 'salut'},
        ttl: 86400,
      );
      expect(p.echeance(creeLe), DateTime.utc(2026, 9, 16, 12));
    });

    test('ttl nul ou négatif ne produit pas d’échéance', () {
      final creeLe = DateTime.utc(2026, 9, 15, 12);
      for (final ttl in [null, 0, -1]) {
        final p = MlsPayload(
          id: 'm1',
          type: 'text',
          sentAt: 0,
          body: const {},
          ttl: ttl,
        );
        expect(p.echeance(creeLe), isNull, reason: 'ttl = $ttl');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // La colonne sert au balayage, le payload fait foi
  // ═══════════════════════════════════════════════════════════════════════
  group('ligne MLS : expires_at est une aide, pas une autorité', () {
    test('toInsert pose expires_at quand il y en a un', () {
      final insert = _ligne(expireLe: DateTime.utc(2026, 9, 16, 12)).toInsert();
      expect(insert['expires_at'], '2026-09-16T12:00:00.000Z');
    });

    test('toInsert ne pose aucune clé quand il n’y en a pas', () {
      expect(_ligne().toInsert().containsKey('expires_at'), isFalse);
    });

    test('fromRow lit la colonne, et encaisse un null', () {
      final base = {
        'id': '11111111-1111-4111-8111-111111111111',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'sender_device_id': '22222222-2222-4222-8222-222222222222',
        'epoch': 3,
        'kind': 'content',
        'content_type': 'text',
        'ciphertext': r'\x010203',
        'is_deleted': false,
        'created_at': '2026-09-15T12:00:00.000Z',
      };
      expect(MlsMessageRow.fromRow(base).expiresAt, isNull);
      expect(
        MlsMessageRow.fromRow({...base, 'expires_at': '2026-09-16T12:00:00Z'})
            .expiresAt,
        DateTime.utc(2026, 9, 16, 12),
      );
    });

    test('un serveur qui ment sur expires_at ne décale pas l’échéance', () {
      // Le service de livraison est considéré comme hostile : il peut
      // repousser la colonne de dix ans. Le récepteur ne la regarde pas — il
      // recalcule depuis le ttl du payload, qu'aucun serveur ne peut lire.
      final entite = MlsMessageMapper.depuisPayload(
        MlsPayload(
          id: 'm1',
          type: 'text',
          sentAt: 0,
          body: const {'content': 'salut'},
          ttl: 86400,
        ),
        row: _ligne(expireLe: DateTime.utc(2036, 1, 1)),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(entite.expiresAt, DateTime.utc(2026, 9, 16, 12).toLocal());
    });

    test('payload illisible : on se rabat sur la colonne', () {
      // Sans ce repli, une bulle « 🔐 Message chiffré » resterait à l'écran
      // pour toujours, alors même que le serveur l'a déjà balayée.
      final entite = MlsMessageMapper.depuisEntrant(
        MlsIncoming(_ligne(expireLe: DateTime.utc(2026, 9, 16, 12))),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(entite.content, MlsMessageMapper.placeholderIllisible);
      expect(entite.expiresAt, DateTime.utc(2026, 9, 16, 12).toLocal());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Le modèle legacy
  // ═══════════════════════════════════════════════════════════════════════
  group('modèle legacy : expiresAt fait l’aller-retour', () {
    test('fromJson rend du local, toJson réécrit en UTC', () {
      // Convention du dépôt : le modèle rend du **local** en sortie, et
      // `toIsoUtc` à l'envoi. `isExpired` compare à `DateTime.now()`, lui
      // aussi local : les deux doivent rester du même côté, sinon l'échéance
      // se décale du fuseau et un message expire des heures trop tôt ou trop
      // tard, sans que rien ne le signale.
      final m = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Amina',
        'content': 'salut',
        'type': 'text',
        'createdAt': '2026-09-15T12:00:00.000Z',
        'expiresAt': '2026-09-16T12:00:00.000Z',
      });
      expect(m.expiresAt!.isUtc, isFalse);
      expect(m.expiresAt, DateTime.utc(2026, 9, 16, 12).toLocal());
      // Ce qui repart en base, en revanche, est bien en UTC.
      expect(m.toJson()['expiresAt'], '2026-09-16T12:00:00.000Z');
    });

    test('isExpired bascule de part et d’autre de l’échéance', () {
      MessageEntity avec(DateTime? echeance) => MessageEntity(
            id: 'm1',
            senderId: 'u1',
            senderName: 'Amina',
            content: 'salut',
            type: MessageType.text,
            status: MessageStatus.sent,
            createdAt: DateTime.now(),
            expiresAt: echeance,
          );
      expect(avec(null).isExpired, isFalse);
      expect(avec(null).isEphemeral, isFalse);
      expect(
        avec(DateTime.now().subtract(const Duration(minutes: 1))).isExpired,
        isTrue,
      );
      expect(
        avec(DateTime.now().add(const Duration(days: 1))).isExpired,
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Structure : le défaut d'origine ne peut plus se reproduire
  // ═══════════════════════════════════════════════════════════════════════
  group('structure : un seul point d’insertion porte le minuteur', () {
    const chemin =
        'lib/features/messages/data/datasources/message_supabase_datasource.dart';

    test('aucune méthode d’envoi n’insère un message en direct', () {
      final src = _source(chemin);

      // Le calcul de l'échéance vivait recopié dans cinq méthodes d'envoi du
      // datasource Firestore : cinq copies à reporter au portage, zéro
      // reportée. Il ne vit plus qu'à un endroit — et toute nouvelle méthode
      // d'envoi qui l'oublierait rendrait ce test rouge.
      final inserts = RegExp(r"from\('messages'\)\.insert\(")
          .allMatches(src)
          .length;
      expect(
        inserts,
        2,
        reason: "exactement deux inserts directs sont permis : celui du helper "
            "_insererMessageUtilisateur, et celui des messages système. Un "
            "troisième veut dire qu'une méthode d'envoi insère sans passer par "
            "le helper — donc sans poser expiresAt, donc sans minuteur.",
      );

      // Et cet unique insert direct est bien celui des messages système.
      expect(
        src.contains("'sender_id': 'system',"),
        isTrue,
        reason: "l'insert direct restant doit être celui des messages système",
      );
    });

    test('les six envois utilisateur passent par le helper', () {
      final src = _source(chemin);
      final appels = RegExp(r'_insererMessageUtilisateur\(')
          .allMatches(src)
          .length;
      // Six appels + la déclaration du helper.
      expect(appels, 7);
      // Texte, média, note vocale, position, sondage, sticker.
      for (final type in [
        "type: 'text',",
        'type: type,',
        "type: 'voiceNote',",
        "type: 'location',",
        "type: 'poll',",
        "type: 'sticker',",
      ]) {
        expect(src.contains(type), isTrue, reason: 'envoi manquant : $type');
      }
    });

    test('le helper lit le minuteur et pose expiresAt', () {
      final src = _source(chemin);
      expect(src.contains("data['expiresAt'] ="), isTrue);
      expect(src.contains('_minuteurDe(conversationId)'), isTrue);
    });

    test('la passerelle MLS lit le même réglage', () {
      // Une conversation qui bascule à MLS doit garder le minuteur qu'elle
      // avait : les deux chemins lisent `conversations.data`, pas deux
      // sources qui dériveraient l'une de l'autre.
      final src = _source('lib/core/crypto/mls/mls_gateway.dart');
      expect(src.contains("data['autoDeleteAfterSeconds']"), isTrue);
      expect(src.contains('ttl: ttl,'), isTrue);
      expect(src.contains('expiresAt:'), isTrue);
    });

    test('le rattrapage MLS ne déchiffre pas une pierre tombale', () {
      // Sans ce garde, chaque rattrapage tenterait de déchiffrer un
      // `ciphertext` vidé par la purge, échouerait, et écrirait un
      // `decrypt_failed` de plus dans les diagnostics.
      final src = _source('lib/core/crypto/mls/mls_conversation_service.dart');
      expect(src.contains('if (m.isDeleted) {'), isTrue);
      expect(src.contains("erreur: 'tombstone'"), isTrue);
    });
  });

  group('structure : la purge existe côté serveur', () {
    const chemin =
        'supabase/migrations/20260915234500_purge_messages_ephemeres.sql';

    test('la migration balaie les deux tables et se programme', () {
      final sql = _source(chemin);
      expect(sql.contains('public.purger_messages_expires()'), isTrue);
      // Les deux tables : le legacy lit son échéance dans le JSONB (il n'a
      // pas de colonne `expires_at`), MLS dans sa colonne.
      expect(sql.contains("data->>'expiresAt'"), isTrue);
      expect(sql.contains('public.mls_messages'), isTrue);
      expect(sql.contains("cron.schedule("), isTrue);
      // Personne ne l'appelle depuis l'application.
      expect(sql.contains('REVOKE ALL ON FUNCTION'), isTrue);
    });

    test('une échéance mal formée ne fait pas échouer la purge entière', () {
      // `db push` s'arrête à la première migration en échec, et une purge qui
      // lève sur UNE valeur bancale n'expire plus rien pour PERSONNE — en
      // silence côté application. Le garde ISO vaut donc son test : vérifié
      // rouge en retirant la ligne (22007 sur la table entière).
      final sql = _source(chemin);
      expect(
        sql.contains(r"~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'"),
        isTrue,
        reason: 'le garde de forme ISO protège le cast en timestamptz',
      );
    });

    test('la pierre tombale efface ce que la suppression efface', () {
      // Si la purge laissait la clé du média, le blob Storage resterait
      // ouvrable ; si elle laissait l'aperçu de partage, titre, extrait et URL
      // cible resteraient en base — ce qui a déjà survécu à une suppression
      // une fois.
      final sql = _source(chemin);
      for (final champ in [
        "- 'content'",
        "- 'fileUrl'",
        "- 'encMedia'",
        "- 'encAnnexes'",
        "- 'postData'",
        "- 'replyToMessageData'",
      ]) {
        expect(sql.contains(champ), isTrue, reason: 'champ gardé : $champ');
      }
      // Et elle distingue « a expiré » de « a été supprimé ».
      expect(sql.contains("'expiredAt'"), isTrue);
    });

    test('elle vide aussi l’aperçu de la liste de discussions', () {
      // `conversations.data->>'lastMessage'` porte le texte du dernier message
      // EN CLAIR. Vider la bulle sans le vider laisserait le message expiré
      // parfaitement lisible une ligne plus haut, dans la liste — la fonction
      // se dirait accomplie pendant que son contenu reste à l'écran.
      final sql = _source(chemin);
      expect(sql.contains("jsonb_build_object('lastMessage', '')"), isTrue);
      expect(sql.contains('public.conversations c'), isTrue);
    });

    test('un aperçu vidé ne se lit pas « nouvelle conversation »', () {
      // Le pendant client : sans ce garde, une discussion entière passerait
      // pour neuve à la seconde où son dernier message expire.
      final src = _source(
        'lib/features/messages/presentation/widgets/conversation_item.dart',
      );
      expect(src.contains('conversation.lastMessageAt == null'), isTrue);
      expect(src.contains('l10n.messageAutoDeleted'), isTrue);
    });
  });
}
