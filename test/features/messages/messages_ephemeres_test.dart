import 'dart:io';
import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/utils/message_copy_text.dart';
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

/// La dernière migration (ordre lexicographique = chronologique, les noms
/// commencent par 14 chiffres) qui contient [motif].
///
/// Une fonction PostgreSQL n'a pas de « fichier source » : elle a un dernier
/// `CREATE OR REPLACE` gagnant. Un test qui vise le fichier de CRÉATION
/// continue de passer longtemps après que le corps a changé ailleurs.
String _derniereMigrationDefinissant(String motif) {
  final fichiers = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((f) => f.endsWith('.sql'))
      .toList()
    ..sort();
  final trouves = fichiers.where((f) => _source(f).contains(motif)).toList();
  if (trouves.isEmpty) {
    throw StateError('aucune migration ne definit « $motif »');
  }
  return trouves.last;
}

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
      final maintenant = DateTime.now().toUtc();
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
        row: _ligne(
          creeLe: maintenant,
          expireLe: DateTime.utc(2036, 1, 1),
        ),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(entite.expiresAt, maintenant.add(const Duration(days: 1)).toLocal());
    });

    test('payload illisible : on se rabat sur la colonne', () {
      // Sans ce repli, une bulle « 🔐 Message chiffré » resterait à l'écran
      // pour toujours, alors même que le serveur l'a déjà balayée.
      //
      // Échéance **relative à maintenant**, pas une date en dur : écrite en
      // dur, elle finit par tomber dans le passé et le test se met à mesurer
      // l'expiration au lieu du repli — rouge un matin, sans que rien n'ait
      // changé dans le code.
      final dans2h = DateTime.now().toUtc().add(const Duration(hours: 2));
      final entite = MlsMessageMapper.depuisEntrant(
        MlsIncoming(_ligne(expireLe: dans2h)),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(entite.content, MlsMessageMapper.placeholderIllisible);
      expect(entite.expiresAt, dans2h.toLocal());
    });

    test('payload illisible ET expiré : la bulle se vide quand même', () {
      final entite = MlsMessageMapper.depuisEntrant(
        MlsIncoming(_ligne(
          expireLe: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        )),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(entite.content, '');
      expect(entite.deletedForEveryone, isTrue);
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
  // Le contenu ne survit pas à l'échéance, même avant le balayage
  // ═══════════════════════════════════════════════════════════════════════
  group('un message expiré ne rend plus son contenu', () {
    // Le balayage serveur ne passe qu'au quart d'heure, et un appareil hors
    // ligne ne le voit pas passer du tout. Entre les deux, le message est
    // entier dans le modèle local — et masquer la bulle ne suffit pas : le
    // texte repart par « Copier », par l'export de la conversation (qui
    // l'écrit dans un FICHIER), par la recherche.
    MessageModel modele({required bool expire}) => MessageModel.fromJson({
          'id': 'm1',
          'senderId': 'u1',
          'senderName': 'Amina',
          'content': 'le secret',
          'type': 'text',
          'createdAt': '2026-09-15T12:00:00.000Z',
          'fileUrl': 'https://exemple.test/blob',
          'postData': {'authorName': 'quelqu’un'},
          'replyToMessageData': {'content': 'la citation'},
          'expiresAt': DateTime.now()
              .add(Duration(days: expire ? -1 : 1))
              .toUtc()
              .toIso8601String(),
        });

    test('toEntity vide la bulle sans attendre le serveur', () {
      final e = modele(expire: true).toEntity();
      expect(e.content, '');
      expect(e.deletedForEveryone, isTrue);
      expect(e.fileUrl, isNull);
      expect(e.postData, isNull);
      expect(e.replyToMessageData, isNull);
      // Mais l'échéance survit : c'est elle qui fait dire « expiré » plutôt
      // que « supprimé ».
      expect(e.isExpired, isTrue);
      // Et l'identité aussi : le fil garde sa forme, on sait de qui et quand.
      expect(e.senderName, 'Amina');
      expect(e.createdAt, isNotNull);
    });

    test('un message pas encore expiré passe intact', () {
      final e = modele(expire: false).toEntity();
      expect(e.content, 'le secret');
      expect(e.deletedForEveryone, isFalse);
      expect(e.fileUrl, 'https://exemple.test/blob');
    });

    test('« Copier » ne rend rien d’un message expiré', () {
      expect(messageCopyText(modele(expire: true).toEntity()), isNull);
      expect(messageCopyText(modele(expire: false).toEntity()), 'le secret');
    });

    test('l’export écrit « supprimé » au lieu du texte', () {
      // L'export ne regarde que `deletedForEveryone` — c'est précisément
      // pourquoi le garde se pose là plutôt que dans chaque écran : quinze
      // chemins savaient déjà taire un message supprimé, aucun ne pensait à
      // un message expiré.
      expect(modele(expire: true).toEntity().deletedForEveryone, isTrue);
    });

    test('côté MLS, le clair déchiffré ne sort pas non plus', () {
      // Ici ça compte double : le clair sort du déchiffrement, il n'existe
      // nulle part ailleurs que dans cette entité.
      final e = MlsMessageMapper.depuisPayload(
        MlsPayload(
          id: 'm1',
          type: 'text',
          sentAt: 0,
          body: const {'content': 'le secret'},
          ttl: 60,
        ),
        row: _ligne(creeLe: DateTime.now().toUtc().subtract(
              const Duration(hours: 2),
            )),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(e.content, '');
      expect(e.deletedForEveryone, isTrue);
      expect(e.isExpired, isTrue);
    });

    test('côté MLS, un message encore vivant garde son clair', () {
      final e = MlsMessageMapper.depuisPayload(
        MlsPayload(
          id: 'm1',
          type: 'text',
          sentAt: 0,
          body: const {'content': 'le secret'},
          ttl: 86400,
        ),
        row: _ligne(creeLe: DateTime.now().toUtc()),
        senderName: 'Amina',
        currentUserId: 'u2',
      );
      expect(e.content, 'le secret');
      expect(e.deletedForEveryone, isFalse);
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

    test('l’écran passe le vrai minuteur au menu d’options', () {
      // Le paramètre est optionnel : omis, il vaut `null` pour toujours. Le
      // menu annonçait alors « Désactivé » quelle que soit la base, la feuille
      // s'ouvrait sur « Désactivé » déjà coché, et son garde « rien n'a
      // changé » sortait sans écrire — le minuteur s'allumait et ne
      // s'éteignait PLUS JAMAIS. Mesuré sur appareil le 2026-09-15.
      final src = _source(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(
        src.contains(
          'autoDeleteAfterSeconds: conversation?.autoDeleteAfterSeconds,',
        ),
        isTrue,
        reason: 'ConversationOptionsModal doit recevoir la vraie valeur',
      );
    });

    test('« Enregistrer » écrit toujours, sans raccourci', () {
      // Le raccourci comparait à une valeur que personne n'alimentait. Un
      // geste explicite de l'utilisateur ne doit pas pouvoir être avalé par
      // une comparaison avec un état supposé.
      final src = _source(
        'lib/features/messages/presentation/widgets/auto_delete_settings_sheet.dart',
      );
      expect(
        src.contains('_selectedDuration == widget.currentDurationSeconds'),
        isFalse,
        reason: 'le raccourci « rien n’a changé » rendait le geste muet',
      );
    });

    test('TOUS les envois optimistes portent l’échéance', () {
      // Le signe « éphémère » (icône minuteur de `_buildMetaRow`) se lit sur
      // `expiresAt`. Sans lui sur l'entité optimiste, il n'apparaissait pas à
      // l'envoi — le seul moment où il dit quelque chose. Côté MLS c'était
      // définitif tant qu'on restait dans la conversation : `catchUp` saute
      // nos propres messages, donc aucun écho ne remplace l'optimiste.
      // Mesuré sur SM A515F le 2026-09-15 : échéance correcte en base, aucune
      // icône à l'écran jusqu'à ressortir de la conversation.
      final src = _source(
        'lib/features/messages/presentation/providers/message_provider.dart',
      );
      final poses = 'expiresAt: _echeanceOptimiste(_ref, conversationId),'
          .allMatches(src)
          .length;
      final optimistes = 'final optimisticMessage = MessageEntity('
          .allMatches(src)
          .length;
      expect(
        poses,
        optimistes,
        reason: 'chaque chemin d’envoi doit la porter — un seul oubli et ce '
            'type de message n’a pas de signe éphémère',
      );
      expect(optimistes, 6,
          reason: 'texte, audio, position, sondage, sticker, et la copie '
              'mise en file hors ligne');
    });

    test('la liste ne masque QUE ce que j’ai supprimé pour moi', () {
      // `isDeletedFor` vaut `deletedForEveryone || deletedFor.contains(moi)`.
      // L'écran filtrait dessus : tout message supprimé pour tous — y compris
      // un éphémère arrivé à échéance, que `videeParExpiration` marque
      // exactement ainsi — était retiré AVANT d'atteindre la bulle, rendant
      // le rendu de pierre tombale inatteignable. Le message disparaissait
      // sans laisser de trace. Mesuré sur SM A515F le 2026-09-15.
      final src = _source(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(
        src.contains('!m.deletedFor.contains(currentUserId) &&'),
        isTrue,
        reason: 'le filtre de liste doit viser deletedFor, pas isDeletedFor',
      );
      expect(
        src.contains('!m.isDeletedFor(currentUserId) &&'),
        isFalse,
        reason: 'isDeletedFor ici emporte les pierres tombales',
      );
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
    // **Pas le fichier qui l'a créée : celui qui la définit aujourd'hui.**
    // `purger_messages_expires()` se réécrit par `CREATE OR REPLACE`, et
    // 20260915235900 l'a déjà fait une fois — pour poser `lastMessageExpired`,
    // la marque qui distingue « a expiré » de « a été supprimé » dans l'aperçu
    // de la liste. Continuer de pointer 20260915234500 revenait à garder un
    // fossile : le corps réellement déployé pouvait perdre le garde ISO ou
    // cesser d'effacer la clé du média sans qu'un seul de ces tests ne
    // bronche. Le prochain remplacement est couvert d'office.
    final chemin = _derniereMigrationDefinissant(
      'FUNCTION public.purger_messages_expires',
    );

    test('la purge balaie les deux tables, et personne ne peut l\'appeler',
        () {
      final sql = _source(chemin);
      expect(sql.contains('public.purger_messages_expires()'), isTrue);
      // Les deux tables : le legacy lit son échéance dans le JSONB (il n'a
      // pas de colonne `expires_at`), MLS dans sa colonne.
      expect(sql.contains("data->>'expiresAt'"), isTrue);
      expect(sql.contains('public.mls_messages'), isTrue);
      // Personne ne l'appelle depuis l'application : l'exposer donnerait à
      // n'importe quel client le moyen de faire expirer les messages des
      // autres en boucle.
      expect(sql.contains('REVOKE ALL ON FUNCTION'), isTrue);
    });

    test('le balayage est programmé quelque part', () {
      // Séparé du corps, parce que ce n'en est pas : `cron.schedule` est un
      // upsert par nom (pg_cron ≥ 1.4), posé UNE fois par la migration qui
      // crée la purge. Un `CREATE OR REPLACE` ultérieur n'a aucune raison de
      // le reposer — le chercher dans le fichier qui définit le corps
      // aujourd'hui ne pourrait que le rater à tort.
      final planifiantes = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((f) => f.endsWith('.sql'))
          .where((f) => _source(f).contains("'purger-messages-expires'"))
          .toList();
      expect(planifiantes, isNotEmpty,
          reason: 'sans job cron, rien n\'expire jamais côté serveur');
      expect(
        // .last et non .single : re-programmer le meme nom est un upsert
        // legitime (pg_cron >= 1.4), pas une anomalie a faire echouer.
        _source(planifiantes.last).contains('cron.schedule('),
        isTrue,
      );
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
      //
      // Deux faits, et non la mise en forme d'un `jsonb_build_object` : elle a
      // déjà changé une fois, en accueillant `lastMessageExpired` à côté de
      // `lastMessage`. Un test collé à la ponctuation d'un appel se casse sur
      // des ajouts légitimes et finit par être « réparé » sans être lu.
      final sql = _source(chemin);
      expect(sql.contains("'lastMessage', ''"), isTrue);
      expect(sql.contains('public.conversations c'), isTrue);
      // Et l'aperçu dit POURQUOI il est vide — sinon le client ne peut que
      // deviner, et il devinait « expiré » pour les deux causes.
      expect(sql.contains("'lastMessageExpired', true"), isTrue);
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
