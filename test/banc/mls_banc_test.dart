// Le banc bout en bout de la phase 3 (plan MLS § 9) : deux, puis trois
// appareils sans écran, reliés par la VRAIE base Supabase — RLS compris —
// et par le vrai moteur Rust chargé dans le processus de test.
//
// Il ne tourne que si `MLS_BANC_SESSIONS` désigne le fichier produit par
// `node tools/mls_banc/sessions.mjs` (trois sessions authentifiées). Sans lui,
// il est ignoré : `flutter test` reste utilisable hors ligne.
//
//   cd rust && cargo build && cd ..
//   node tools/mls_banc/sessions.mjs > "$TEMP/sessions.json" \
//     && MLS_BANC_SESSIONS="$TEMP/sessions.json" flutter test test/banc
//
// Les jetons de sonde expirent au bout de six minutes : fabriquer et lancer
// dans la même commande.
//
// Chaque cas est une ligne de la phase 3. Ce qui casse ici casserait en
// production, en silence : c'est la raison d'être de ce fichier, et le
// critère de sortie de la phase est qu'il ÉCHOUE quand on casse un cas
// exprès.

import 'dart:convert';
import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_source_merger.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart' as rust;
import 'package:diaspo_niger/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Un appareil du banc : sa session, sa base SQLite, ses services.
class Appareil {
  Appareil({
    required this.nom,
    required this.uid,
    required this.client,
    required this.dossier,
  });

  final String nom;
  final String uid;
  final SupabaseClient client;
  final Directory dossier;

  late final String stableId = 'banc-${nom.toLowerCase()}-${const Uuid().v4().substring(0, 8)}';
  late final MlsDelivery delivery = MlsDelivery(client: client, ensureAuth: () async => true);
  late final MlsDeviceRegistry registry = MlsDeviceRegistry(
    moteur: (_) => moteur(),
    client: client,
    stableId: (_) async => stableId,
    libelle: () async => 'Banc $nom',
    ensureAuth: () async => true,
    platforme: 'desktop',
  );
  late MlsDeviceRecord fiche;
  late final MlsConversationService service = MlsConversationService(
    userId: uid,
    moteur: moteur,
    delivery: delivery,
    appareil: () async => fiche,
  );

  Moteur? _moteur;

  String get chemin => '${dossier.path}/$nom.sqlite';

  /// Rouvre la base si le moteur a été détruit : c'est le rattrapage au
  /// point d'usage, et c'est ce que le cas « moteur recréé » vérifie.
  Future<Moteur> moteur() async =>
      _moteur ??= await Moteur.ouvrir(dbPath: chemin, userId: uid, deviceId: stableId);

  /// Le cas qui a tué Signal : le moteur disparaît entre deux envois.
  void detruireLeMoteur() {
    _moteur?.dispose();
    _moteur = null;
  }

  /// Réinstallation : plus de base du tout. Nouvelle identité au prochain
  /// `moteur()`.
  Future<void> reinstaller() async {
    detruireLeMoteur();
    for (final f in dossier.listSync()) {
      if (f.path.contains('/$nom.sqlite') || f.path.contains('\\$nom.sqlite')) {
        await f.delete();
      }
    }
  }

  Future<void> inscrire() async {
    // Profil minimal : le trigger de notification saute tout destinataire
    // sans ligne `users` (même garde que le legacy). En production chaque
    // compte en a une ; sans elle ici, le banc ne verrait aucune
    // notification et en conclurait à tort que le trigger est muet.
    await client.from('users').upsert({'id': uid, 'display_name': 'Banc $nom'});
    fiche = await registry.ensureRegistered(uid);
  }
}

String _bibliotheque() {
  if (Platform.isWindows) return 'rust/target/debug/diaspo_mls.dll';
  if (Platform.isMacOS) return 'rust/target/debug/libdiaspo_mls.dylib';
  return 'rust/target/debug/libdiaspo_mls.so';
}

void main() {
  final fichier = Platform.environment['MLS_BANC_SESSIONS'];
  if (fichier == null || !File(fichier).existsSync()) {
    test(
      'banc MLS contre la vraie base',
      () {},
      skip: 'MLS_BANC_SESSIONS absent : voir tools/mls_banc/sessions.mjs',
    );
    return;
  }

  late Appareil a, b, c;
  late Directory dossier;
  const uuid = Uuid();

  /// Une conversation neuve entre les participants donnés, créée par [par].
  Future<String> conversation(
    Appareil par,
    List<Appareil> participants, {
    String? type,
  }) async {
    final id = uuid.v4();
    await par.client.from('conversations').insert({
      'id': id,
      'type': type ?? (participants.length > 2 ? 'group' : 'individual'),
      'participant_ids': [for (final p in participants) p.uid],
      'created_by': par.uid,
      'data': {'name': 'banc MLS'},
    });
    return id;
  }

  setUpAll(() async {
    // `SharedPreferences` (où le registre dépose l'identifiant d'appareil)
    // passe par un MethodChannel : sans binding, il lève.
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    await RustLib.init(externalLibrary: ExternalLibrary.open(_bibliotheque()));
    final s = jsonDecode(File(fichier).readAsStringSync()) as Map<String, dynamic>;
    dossier = await Directory.systemTemp.createTemp('mls_banc_');
    Appareil fabrique(String nom, String cle) {
      final session = s[cle] as Map<String, dynamic>;
      return Appareil(
        nom: nom,
        uid: session['uid'] as String,
        client: SupabaseClient(
          s['url'] as String,
          s['anonKey'] as String,
          headers: {'Authorization': 'Bearer ${session['accessToken']}'},
        ),
        dossier: dossier,
      );
    }

    a = fabrique('Alice', 'a');
    b = fabrique('Bob', 'b');
    c = fabrique('Charlie', 'c');
    await a.inscrire();
    await b.inscrire();
    await c.inscrire();
  });

  tearDownAll(() async {
    for (final x in [a, b, c]) {
      x.detruireLeMoteur();
    }
    try {
      await dossier.delete(recursive: true);
    } catch (_) {}
  });

  group('registre (phase 2, preuve de vie)', () {
    test('chaque appareil a sa ligne mls_devices et 51 KeyPackages', () async {
      for (final x in [a, b, c]) {
        expect(x.fiche.estCetAppareil, isTrue, reason: x.nom);
        expect(x.fiche.estRevoque, isFalse);
        final paquets = await x.client
            .from('mls_key_packages')
            .select('id, is_last_resort')
            .eq('device_id', x.fiche.id);
        expect((paquets as List).length, 51, reason: x.nom);
      }
    });

    test('réinscription : même ligne, aucun nouveau paquet', () async {
      final avant = a.fiche.id;
      await a.inscrire();
      expect(a.fiche.id, avant);
      final paquets = await a.client.from('mls_key_packages').select('id').eq('device_id', avant);
      expect((paquets as List).length, 51);
    });
  });

  group('parcours nominal 1:1', () {
    late String conv;

    test('Alice crée, ajoute Bob, écrit ; Bob rejoint par le Welcome et lit', () async {
      conv = await conversation(a, [a, b]);
      await a.service.ensureGroup(conv);
      await a.service.reconcileMembership(conv);

      final envoye = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'Salut Bob'));
      expect(envoye.epoch, 1);
      // Le serveur ne voit pas le clair.
      expect(utf8.decode(envoye.ciphertext, allowMalformed: true).contains('Salut Bob'), isFalse);

      final recus = await b.service.catchUp(conv);
      expect(recus.map((m) => m.payload?.texte), ['Salut Bob']);

      final reponse = await b.service.send(conv, MlsPayload.texte(uuid.v4(), 'Salut Alice'));
      expect(reponse.senderId, b.uid);
      final chezAlice = await a.service.catchUp(conv);
      expect(chezAlice.map((m) => m.payload?.texte), ['Salut Alice']);
    });

    test('la conversation porte mls_since, et le legacy la refuse', () async {
      final row = await a.delivery.conversation(conv);
      expect(row?['mls_since'], isNotNull);
      await expectLater(
        a.client.from('messages').insert({
          'id': uuid.v4(),
          'conversation_id': conv,
          'sender_id': a.uid,
          'type': 'text',
          'data': {'content': 'en clair'},
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('message reçu deux fois : rendu une fois, rejeu refusé par le cliquet', () async {
      final m = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'une fois'));
      final premiere = await b.service.catchUp(conv);
      expect(premiere.map((x) => x.payload?.texte), ['une fois']);
      final seconde = await b.service.catchUp(conv);
      expect(seconde, isEmpty, reason: 'le curseur ne rend pas deux fois le même id');

      // Rejeu forcé au moteur : le cliquet a consommé la clé du message.
      final moteur = await b.moteur();
      await expectLater(
        moteur.traiterEntrant(
          conversationId: conv,
          message: m.ciphertext,
          aadAttendu: MlsAad.message(
            conversationId: conv,
            messageId: m.id,
            senderDeviceId: m.senderDeviceId,
            kind: m.kind,
          ),
        ),
        throwsA(anything),
      );
    });

    test('AAD déplacé : un ciphertext présenté sous un autre id est refusé', () async {
      final m = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'secret'));
      final moteur = await b.moteur();
      await expectLater(
        moteur.traiterEntrant(
          conversationId: conv,
          message: m.ciphertext,
          aadAttendu: MlsAad.message(
            conversationId: conv,
            messageId: 'un-autre-id',
            senderDeviceId: m.senderDeviceId,
            kind: m.kind,
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('aad_mismatch'))),
      );
      // Consommer proprement le message pour la suite.
      await b.service.catchUp(conv);
    });

    test('messages hors ordre : le cliquet tolère un retard', () async {
      final m1 = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'un'));
      final m2 = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'deux'));
      final moteur = await b.moteur();
      Future<String> lire(MlsMessageRow m) async {
        final r = await moteur.traiterEntrant(
          conversationId: conv,
          message: m.ciphertext,
          aadAttendu: MlsAad.message(
            conversationId: conv,
            messageId: m.id,
            senderDeviceId: m.senderDeviceId,
            kind: m.kind,
          ),
        );
        return switch (r) {
          EntrantDto_Application(:final clair) => MlsPayload.decode(clair).texte,
          _ => '?',
        };
      }

      expect(await lire(m2), 'deux');
      expect(await lire(m1), 'un');
      // Le service les a vus par le moteur, pas par son curseur : les ignorer.
      final restes = await b.service.catchUp(conv);
      expect(restes.every((x) => !x.lisible), isTrue,
          reason: 'déjà consommés au moteur, le service ne peut que les rendre illisibles');
    });

    test('le serveur notifie sans rien lire : repli générique et ciphertext', () async {
      // Le trigger `mls_notify_recipients` remplace le déchiffrement serveur
      // du legacy. Ce qu'il écrit doit rester illisible : c'est la garantie
      // que MLS apporte, et elle se vérifie ligne par ligne en base.
      final m = await a.service.send(
        conv,
        MlsPayload.texte(uuid.v4(), 'mot de passe du wifi'),
      );

      // Filtré par identifiant de message, jamais par date : l'horloge du
      // poste et celle du serveur diffèrent de quelques secondes, et un
      // `created_at >= now()` local ramasse des notifications antérieures.
      final lignes = await b.client
          .from('notifications')
          .select()
          .eq('user_id', b.uid)
          .eq('data->>messageId', m.id);
      expect(lignes, hasLength(1), reason: 'une notification, et une seule');
      final notif = (lignes as List).cast<Map<String, dynamic>>().first;

      // Le corps est un repli générique — le serveur n'a pas pu lire le texte.
      expect(notif['body'], 'Nouveau message');
      expect(notif['body'].toString().contains('wifi'), isFalse);
      expect(jsonEncode(notif).contains('mot de passe'), isFalse);

      final data = (notif['data'] as Map).cast<String, dynamic>();
      expect(data['protocol'], 'mls');
      expect(data['isE2EE'], 'true');
      expect(data['conversationId'], conv);
      expect(data['mlsSenderDeviceId'], m.senderDeviceId);
      // Le ciphertext voyage tel quel : c'est lui que l'appareil déchiffre.
      final b64 = data['mlsCiphertext'] as String;
      // `encode(bytea,'base64')` coupe tous les 76 caractères et
      // `base64Decode` refuse les sauts : le trigger doit les retirer
      // (migration 20260915160000). Sans cette exigence, une régression du
      // SQL ne se verrait que sur le téléphone de quelqu'un, en silence.
      expect(b64.contains('\n'), isFalse, reason: 'base64 coupé par Postgres');
      expect(base64Decode(b64), m.ciphertext);

      // L'expéditeur ne se notifie pas lui-même.
      final chezAlice = await a.client
          .from('notifications')
          .select('id')
          .eq('user_id', a.uid)
          .eq('data->>messageId', m.id);
      expect(chezAlice, isEmpty);

      // Et l'aperçu se reconstruit bien depuis ce que le push transporte.
      b.detruireLeMoteur();
      final clair = await rust.apercuSansEtat(
        dbPath: b.chemin,
        userId: b.uid,
        deviceId: b.stableId,
        conversationId: conv,
        message: base64Decode(b64),
        aad: MlsAad.message(
          conversationId: conv,
          messageId: data['messageId'] as String,
          senderDeviceId: data['mlsSenderDeviceId'] as String,
          kind: data['mlsKind'] as String,
        ),
      );
      expect(
        MlsPayload.decode(Uint8List.fromList(clair)).texte,
        'mot de passe du wifi',
      );
      await b.service.catchUp(conv);
    });

    test('aperçu de notification : déchiffre sans consommer le cliquet', () async {
      // Le chemin réel d'une notification : le serveur envoie le ciphertext
      // (il ne peut plus lire le texte), l'isolate le déchiffre sur une copie
      // jetable, puis l'application traite le MÊME message. Si l'aperçu
      // faisait avancer le cliquet, cette seconde lecture échouerait — et la
      // conversation deviendrait illisible sans qu'aucune erreur ne le dise.
      final m = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'aperçu puis lecture'));
      final aad = MlsAad.message(
        conversationId: conv,
        messageId: m.id,
        senderDeviceId: m.senderDeviceId,
        kind: m.kind,
      );

      // Bob « dort » : aucun moteur ouvert, comme au réveil par un push.
      b.detruireLeMoteur();
      final clair = await rust.apercuSansEtat(
        dbPath: b.chemin,
        userId: b.uid,
        deviceId: b.stableId,
        conversationId: conv,
        message: m.ciphertext,
        aad: aad,
      );
      expect(MlsPayload.decode(Uint8List.fromList(clair)).texte, 'aperçu puis lecture');

      // Un même push peut être livré deux fois.
      final encore = await rust.apercuSansEtat(
        dbPath: b.chemin,
        userId: b.uid,
        deviceId: b.stableId,
        conversationId: conv,
        message: m.ciphertext,
        aad: aad,
      );
      expect(MlsPayload.decode(Uint8List.fromList(encore)).texte, 'aperçu puis lecture');

      // L'application se réveille et traite le message : il doit être lisible.
      // On cherche CE message, sans exiger qu'il soit seul : un cas précédent
      // peut avoir laissé du retard, et ce test-ci ne porte pas là-dessus.
      final recus = await b.service.catchUp(conv);
      expect(recus.map((x) => x.payload?.texte), contains('aperçu puis lecture'));
    });

    test('moteur détruit et recréé entre deux envois : le second part en MLS', () async {
      a.detruireLeMoteur();
      final m = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'toujours chiffré'));
      expect(utf8.decode(m.ciphertext, allowMalformed: true).contains('toujours'), isFalse);
      b.detruireLeMoteur();
      final recus = await b.service.catchUp(conv);
      expect(recus.map((x) => x.payload?.texte), ['toujours chiffré']);
    });
  });

  group('epochs et appartenance', () {
    late String conv;

    test('Charlie rejoint : le commit précède le message chez Bob', () async {
      conv = await conversation(a, [a, b, c]);
      await a.service.ensureGroup(conv);
      await a.service.reconcileMembership(conv);
      final m1 = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'avant Charlie'));
      expect(m1.epoch, 1);
      // Bob et Charlie lisent, chacun par son Welcome.
      expect((await b.service.catchUp(conv)).map((x) => x.payload?.texte), ['avant Charlie']);
      expect((await c.service.catchUp(conv)).map((x) => x.payload?.texte), ['avant Charlie']);
    });

    test('message d’un epoch passé, reçu après le commit suivant', () async {
      // Alice émet à l'epoch courant, puis retire… personne ; on force un
      // nouvel epoch en réinstallant Charlie (nouvelle identité à ajouter).
      final avant = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'émis avant'));
      await c.reinstaller();
      await c.inscrire();
      await a.service.reconcileMembership(conv); // ajoute le nouveau Charlie, retire l'ancien
      final apres = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'émis après'));
      expect(apres.epoch, greaterThan(avant.epoch));

      // Bob n'a rien traité entre-temps : commit d'abord, puis les deux.
      final recus = await b.service.catchUp(conv);
      expect(recus.map((x) => x.payload?.texte), ['émis avant', 'émis après']);

      // Le Charlie réinstallé lit ce qui suit son ajout, pas ce qui précède.
      // Le message d'avant lui parvient quand même, illisible : c'est ce qui
      // permettra à l'écran d'afficher « antérieur à votre arrivée » plutôt
      // que de le faire disparaître sans rien dire.
      final chezCharlie = await c.service.catchUp(conv);
      expect(
        chezCharlie.where((x) => x.lisible).map((x) => x.payload!.texte),
        ['émis après'],
      );
      expect(chezCharlie.where((x) => !x.lisible), hasLength(1));
    });

    test('commit concurrent : le perdant jette le sien et retombe sur ses pieds', () async {
      final conv2 = await conversation(a, [a, b]);
      await a.service.ensureGroup(conv2);
      await a.service.reconcileMembership(conv2);
      await b.service.catchUp(conv2);

      // Les deux ajoutent Charlie « en même temps » : ajouter c au
      // participant_ids, puis deux reconcile sans rattrapage entre les deux.
      await a.client.from('conversations').update({
        'participant_ids': [a.uid, b.uid, c.uid],
      }).eq('id', conv2);
      await Future.wait([
        a.service.reconcileMembership(conv2),
        b.service.reconcileMembership(conv2),
      ]);
      final snapA = await (await a.moteur()).instantane(conversationId: conv2);
      final snapB = await (await b.moteur()).instantane(conversationId: conv2);
      expect(snapA.epoch, snapB.epoch);
      expect(snapA.membres.length, 3);
      expect(snapB.membres.length, 3);
      final m = await a.service.send(conv2, MlsPayload.texte(uuid.v4(), 'à trois'));
      expect((await b.service.catchUp(conv2)).map((x) => x.payload?.texte), ['à trois']);
      expect((await c.service.catchUp(conv2)).map((x) => x.payload?.texte), ['à trois']);
      expect(m.epoch, snapA.epoch.toInt());
    });

    test('révoquer l’appareil d’autrui est refusé, et ça se voit', () async {
      await expectLater(b.registry.revoke(c.fiche.id), throwsA(isA<StateError>()));
      final ligne = await c.client
          .from('mls_devices')
          .select('revoked_at')
          .eq('id', c.fiche.id)
          .single();
      expect(ligne['revoked_at'], isNull, reason: 'rien ne doit avoir bougé');
    });

    test('appareil révoqué : retiré au prochain reconcile, il ne lit plus', () async {
      // La révocation vient d'un autre appareil du MÊME compte — ici Charlie
      // lui-même, faute d'un second appareil dans le banc.
      await c.registry.revoke(c.fiche.id);
      final ligne = await c.client
          .from('mls_devices')
          .select('revoked_at')
          .eq('id', c.fiche.id)
          .single();
      expect(ligne['revoked_at'], isNotNull);
      await a.service.reconcileMembership(conv);
      final m = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'sans Charlie'));
      final chezBob = await b.service.catchUp(conv);
      expect(chezBob.map((x) => x.payload?.texte), ['sans Charlie']);
      final chezCharlie = await c.service.catchUp(conv);
      expect(chezCharlie.where((x) => x.row.id == m.id).every((x) => !x.lisible), isTrue);
    });

    test('rattrapage après coupure : tout arrive, dans l’ordre', () async {
      final conv3 = await conversation(a, [a, b]);
      await a.service.ensureGroup(conv3);
      await a.service.reconcileMembership(conv3);
      final attendus = <String>[];
      for (var i = 1; i <= 5; i++) {
        attendus.add('message $i');
        await a.service.send(conv3, MlsPayload.texte(uuid.v4(), 'message $i'));
      }
      // Bob revient : Welcome, puis les cinq.
      final recus = await b.service.catchUp(conv3);
      expect(recus.map((x) => x.payload?.texte), attendus);
    });
  });

  group('coexistence : un historique lisible, puis le chiffrement', () {
    late String conv;

    test('le legacy s’écrit, puis la bascule le ferme définitivement', () async {
      conv = await conversation(a, [a, b]);

      // Avant la bascule : la conversation vit comme aujourd'hui.
      for (final texte in ['bonjour', 'ça va ?']) {
        await a.client.from('messages').insert({
          'id': uuid.v4(),
          'conversation_id': conv,
          'sender_id': a.uid,
          'type': 'text',
          'data': {'content': texte, 'senderName': 'Banc Alice'},
        });
      }
      final avantBascule = await a.client
          .from('messages')
          .select('id')
          .eq('conversation_id', conv);
      expect(avantBascule, hasLength(2));

      // La bascule : elle pose `mls_since`, et ne se défait jamais.
      await a.service.ensureGroup(conv);
      await a.service.reconcileMembership(conv);
      final row = await a.delivery.conversation(conv);
      expect(row?['mls_since'], isNotNull);

      // À partir de là, plus rien ne peut écrire en clair dans cette
      // conversation : c'est la garantie auditable du gel (§ 2.3).
      await expectLater(
        a.client.from('messages').insert({
          'id': uuid.v4(),
          'conversation_id': conv,
          'sender_id': a.uid,
          'type': 'text',
          'data': {'content': 'après la bascule'},
        }),
        throwsA(isA<PostgrestException>()),
      );

      // Et `mls_since` ne se remet pas à NULL, même en essayant.
      await expectLater(
        a.client.from('conversations').update({'mls_since': null}).eq('id', conv),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('le fil fusionné : historique, séparateur, puis messages chiffrés', () async {
      await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'et maintenant chiffré'));
      final recus = await b.service.catchUp(conv);
      expect(recus.map((x) => x.payload?.texte), contains('et maintenant chiffré'));

      // Côté lecture, l'écran verra une seule liste. On la construit comme le
      // repository le fera : legacy paginé + fil MLS + séparateur.
      final lignesLegacy = await b.client
          .from('messages')
          .select()
          .eq('conversation_id', conv)
          .order('created_at', ascending: true);
      final legacy = [
        for (final r in (lignesLegacy as List).cast<Map<String, dynamic>>())
          MessageEntity(
            id: r['id'] as String,
            senderId: r['sender_id'] as String,
            senderName: 'Banc Alice',
            content: (r['data'] as Map)['content'] as String? ?? '',
            type: MessageType.text,
            status: MessageStatus.sent,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
      ];
      final mls = [
        for (final x in recus)
          MlsMessageMapper.depuisEntrant(
            x,
            senderName: 'Banc Alice',
            currentUserId: b.uid,
          ),
      ];

      final conversationRow = await b.delivery.conversation(conv);
      final fusion = MlsSourceMerger.fusionner(
        legacy: legacy,
        mls: mls,
        mlsSince: DateTime.parse(conversationRow!['mls_since'] as String),
      );

      // L'historique d'abord, le séparateur ensuite, le chiffré en dernier.
      expect(legacy.map((m) => m.content), ['bonjour', 'ça va ?']);
      final iSeparateur = fusion.indexWhere(MlsMessageMapper.estSeparateur);
      expect(iSeparateur, 2);
      expect(fusion.last.content, 'et maintenant chiffré');
      expect(fusion.last.encryptionLevel, MessageEncryptionLevel.e2ee);
      // Le séparateur n'est pas un message : rien de ce qui compte ne le voit.
      expect(MlsSourceMerger.sansSeparateur(fusion), hasLength(3));
    });
  });

  group('groupe ouvert : on entre sans attendre personne', () {
    test('Charlie se joint par commit externe, puis lit et écrit', () async {
      // Le cas du groupe officiel d'une ville : on le rejoint automatiquement,
      // souvent sans qu'aucun membre ne soit en ligne pour vous ajouter. Sans
      // la jointure externe (§ 5.7), l'arrivant attendrait indéfiniment son
      // Welcome — et le groupe paraîtrait vide.
      // Un GROUPE à deux au départ : c'est le cas du groupe officiel d'une
      // ville, que des gens rejoignent ensuite sans être invités.
      final conv = await conversation(a, [a, b], type: 'group');
      await a.service.ensureGroup(conv);
      await a.service.reconcileMembership(conv);
      await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'avant Charlie'));
      await b.service.catchUp(conv);

      // Charlie devient participant côté serveur, et personne ne l'ajoute.
      await a.client.from('conversations').update({
        'participant_ids': [a.uid, b.uid, c.uid],
      }).eq('id', conv);

      // Il entre tout seul, depuis l'arbre public.
      await c.service.ensureGroup(conv);
      final snapC = await (await c.moteur()).instantane(conversationId: conv);
      expect(snapC.membres.length, 3);

      // Les membres en place traitent son commit et continuent de lui parler.
      final m = await a.service.send(conv, MlsPayload.texte(uuid.v4(), 'bienvenue'));
      expect((await c.service.catchUp(conv)).map((x) => x.payload?.texte),
          contains('bienvenue'));
      expect((await b.service.catchUp(conv)).map((x) => x.payload?.texte),
          contains('bienvenue'));

      // Et ce qu'il écrit est lu par les autres.
      final sien = await c.service.send(conv, MlsPayload.texte(uuid.v4(), 'merci'));
      expect(sien.epoch, greaterThanOrEqualTo(m.epoch));
      expect((await a.service.catchUp(conv)).map((x) => x.payload?.texte),
          contains('merci'));

      // Ce qui précède son arrivée lui reste illisible : c'est la propriété
      // du protocole, pas un défaut — et l'écran doit pouvoir le dire.
      final avant = await c.service.catchUp(conv);
      expect(avant.where((x) => x.payload?.texte == 'avant Charlie'), isEmpty);
    });

    test('un 1:1 ne se rejoint pas tout seul', () async {
      // Personne ne doit pouvoir entrer dans une conversation à deux sans y
      // être invité. Le RLS l'empêcherait de toute façon — la garde côté
      // client dit seulement l'intention.
      final prive = await conversation(a, [a, b]);
      await a.service.ensureGroup(prive);
      await a.service.reconcileMembership(prive);
      await a.service.send(prive, MlsPayload.texte(uuid.v4(), 'entre nous'));

      await a.client.from('conversations').update({
        'participant_ids': [a.uid, b.uid, c.uid],
      }).eq('id', prive);

      await expectLater(
        c.service.ensureGroup(prive),
        throwsA(isA<MlsEnAttenteDeWelcome>()),
      );
    });
  });
}
