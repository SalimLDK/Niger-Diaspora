// Harnais jetable du spike MLS (phase 1). Activé par
// `--dart-define=SPIKE_MLS=true`, il remplace l'app entière par un écran qui
// joue le parcours nominal et chronomètre une réouverture à froid — les deux
// mesures que le plan (§ 12) attend de l'appareil.
//
// Rien ici n'est du code de production, et rien n'est journalisé : les
// chiffres s'affichent à l'écran, où `adb exec-out screencap` les lit.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/mls.dart';

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Spike MLS')),
        body: FutureBuilder<List<String>>(
          future: _jouer(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('ÉCHEC : ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final l in snap.data!) Text(l)],
            );
          },
        ),
      ),
    );
  }
}

List<int> _aad(String conv, String msg, String sender) =>
    utf8.encode('dn-mls/1|$conv|$msg|$sender|content');

Future<List<String>> _jouer() async {
  final lignes = <String>[];
  final dir = await getApplicationSupportDirectory();
  final base = Directory('${dir.path}/spike_mls');
  if (await base.exists()) await base.delete(recursive: true);
  await base.create(recursive: true);
  final cheminAlice = '${base.path}/alice.sqlite';
  final cheminBob = '${base.path}/bob.sqlite';
  const conv = 'spike';

  // ── 1. Parcours nominal, moteurs neufs ────────────────────────────────────
  final t0 = Stopwatch()..start();
  final alice = await Moteur.ouvrir(
    dbPath: cheminAlice,
    userId: 'alice',
    deviceId: 'a1',
  );
  final bob = await Moteur.ouvrir(dbPath: cheminBob, userId: 'bob', deviceId: 'b1');
  lignes.add('ouverture de 2 moteurs neufs : ${t0.elapsedMilliseconds} ms');

  final t1 = Stopwatch()..start();
  await alice.creerGroupe(conversationId: conv);
  final kp = (await bob.creerKeyPackages(n: 1, dernierRecours: false)).first;
  final out = await alice.ajouterMembres(conversationId: conv, keyPackages: [kp]);
  await alice.fusionnerCommitEnAttente(conversationId: conv);
  final snap = await bob.traiterWelcome(conversationId: conv, welcome: out.welcome!);
  lignes.add(
    'création + ajout + welcome : ${t1.elapsedMilliseconds} ms '
    '(epoch ${snap.epoch}, ${snap.membres.length} membres)',
  );

  final t2 = Stopwatch()..start();
  final ct = await alice.chiffrer(
    conversationId: conv,
    clair: utf8.encode('Salut Bob'),
    aad: _aad(conv, 'm1', 'a1'),
  );
  final entrant = await bob.traiterEntrant(
    conversationId: conv,
    message: ct,
    aadAttendu: _aad(conv, 'm1', 'a1'),
  );
  final clair = switch (entrant) {
    EntrantDto_Application(:final clair) => utf8.decode(clair),
    _ => '<pas un message applicatif>',
  };
  lignes.add('chiffrer + déchiffrer : ${t2.elapsedMilliseconds} ms → « $clair »');

  // ── 2. Réouverture à froid : le chemin « notification en arrière-plan » ──
  final ct2 = await alice.chiffrer(
    conversationId: conv,
    clair: utf8.encode('après réouverture'),
    aad: _aad(conv, 'm2', 'a1'),
  );
  bob.dispose();

  final t3 = Stopwatch()..start();
  final bob2 = await Moteur.ouvrir(dbPath: cheminBob, userId: 'bob', deviceId: 'b1');
  final ouverture = t3.elapsedMilliseconds;
  final entrant2 = await bob2.traiterEntrant(
    conversationId: conv,
    message: ct2,
    aadAttendu: _aad(conv, 'm2', 'a1'),
  );
  final total = t3.elapsedMilliseconds;
  final clair2 = switch (entrant2) {
    EntrantDto_Application(:final clair) => utf8.decode(clair),
    _ => '<pas un message applicatif>',
  };
  lignes.add(
    'RÉOUVERTURE À FROID : ouverture $ouverture ms, '
    'ouverture + déchiffrement $total ms → « $clair2 »',
  );
  lignes.add('identité Bob : ${bob2.identite()}');

  // ── 3. AAD déplacé : doit échouer ─────────────────────────────────────────
  final ct3 = await alice.chiffrer(
    conversationId: conv,
    clair: utf8.encode('secret'),
    aad: _aad(conv, 'm3', 'a1'),
  );
  try {
    await bob2.traiterEntrant(
      conversationId: conv,
      message: ct3,
      aadAttendu: _aad(conv, 'AUTRE', 'a1'),
    );
    lignes.add('AAD déplacé : ACCEPTÉ — ANORMAL');
  } catch (e) {
    lignes.add('AAD déplacé : refusé ($e)');
  }

  lignes.add('taille base Bob : ${await File(cheminBob).length()} octets');
  return lignes;
}
