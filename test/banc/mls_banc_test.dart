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
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
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
  Future<String> conversation(Appareil par, List<Appareil> participants) async {
    final id = uuid.v4();
    await par.client.from('conversations').insert({
      'id': id,
      'type': participants.length > 2 ? 'group' : 'individual',
      'participant_ids': [for (final p in participants) p.uid],
      'created_by': par.uid,
      'data': {'name': 'banc MLS'},
    });
    return id;
  }

  setUpAll(() async {
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
      final chezCharlie = await c.service.catchUp(conv);
      expect(chezCharlie.map((x) => x.payload?.texte), ['émis après']);
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
      expect(m.epoch, snapA.epoch);
    });

    test('appareil révoqué : retiré au prochain reconcile, il ne lit plus', () async {
      await b.registry.revoke(c.fiche.id);
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
}
