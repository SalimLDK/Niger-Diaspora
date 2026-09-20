import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/crypto/mls/mls_chemin_base.dart';
import 'package:diaspo_niger/core/services/effacement_local_differe.dart';
import 'package:diaspo_niger/core/services/effacement_materiel_local.dart';

/// Ni la déconnexion ni la suppression d'un compte n'effaçaient la base MLS
/// locale (un fichier par compte, EN CLAIR) ni les clés du téléphone. Le
/// matériel est conservé pendant le délai de grâce — une annulation le perdrait —
/// puis effacé À RETARDEMENT, sur confirmation du serveur que la suppression est
/// menée à terme.
///
/// Ces tests verrouillent ce que le service ne fait JAMAIS : effacer sur un
/// « non », sur une erreur réseau, sur le compte connecté, ou sur un marqueur
/// qu'il ne sait pas lire. Effacer les clés d'un compte que l'on aurait annulé
/// ailleurs est une perte définitive.

class _Banc {
  _Banc({
    this.serveurMenee = false,
    this.serveurEchoue = false,
    this.effacementEchoue = false,
    this.connecte,
  });

  String? stocke;
  bool serveurMenee;
  bool serveurEchoue;
  bool effacementEchoue;
  String? connecte;
  DateTime maintenant = DateTime.utc(2026, 10, 1, 12);

  final interroges = <String>[];
  final effaces = <String>[];

  late final service = EffacementLocalDiffere(
    lire: () async => stocke,
    ecrire: (v) async => stocke = v,
    suppressionMenee: (uid) async {
      interroges.add(uid);
      if (serveurEchoue) throw Exception('réseau coupé');
      return serveurMenee;
    },
    effacerMateriel: (uid) async {
      if (effacementEchoue) throw StateError('disque plein');
      effaces.add(uid);
    },
    uidCourant: () => connecte,
    maintenant: () => maintenant,
  );

  List<String> get marqueurs => stocke == null
      ? []
      : [for (final m in jsonDecode(stocke!) as List) (m as Map)['uid'] as String];
}

void main() {
  final echeance = DateTime.utc(2026, 10, 18, 9);
  DateTime apres(Duration d) => echeance.add(d);

  group('poser et retirer un marqueur', () {
    test('la demande pose un marqueur, la seconde du même compte le remplace', () async {
      final b = _Banc();
      await b.service.programmer('uid-a', echeance);
      await b.service.programmer('uid-a', echeance.add(const Duration(days: 5)));

      expect(b.marqueurs, ['uid-a'], reason: 'un compte, un marqueur');
      final m = (jsonDecode(b.stocke!) as List).single as Map;
      expect(DateTime.parse(m['echeance'] as String),
          echeance.add(const Duration(days: 5)));
    });

    test('deux comptes du même téléphone ont chacun le leur', () async {
      final b = _Banc();
      await b.service.programmer('uid-a', echeance);
      await b.service.programmer('uid-b', echeance);
      expect(b.marqueurs.toSet(), {'uid-a', 'uid-b'});
    });

    test('annuler retire le marqueur du compte, et de lui seul', () async {
      final b = _Banc();
      await b.service.programmer('uid-a', echeance);
      await b.service.programmer('uid-b', echeance);

      await b.service.annuler('uid-a');

      expect(b.marqueurs, ['uid-b']);
    });

    test('annuler un compte sans marqueur ne fait rien et n\'écrit rien', () async {
      final b = _Banc();
      await b.service.annuler('uid-inconnu');
      expect(b.stocke, isNull);
    });

    test('au-delà de dix marqueurs, le plus ancien est écarté', () async {
      final b = _Banc();
      for (var i = 0; i < 12; i++) {
        await b.service.programmer('uid-$i', echeance.add(Duration(days: i)));
      }
      expect(b.marqueurs.length, EffacementLocalDiffere.maxMarqueurs);
      expect(b.marqueurs, isNot(contains('uid-0')));
      expect(b.marqueurs, contains('uid-11'));
    });

    test('une écriture qui échoue ne fait JAMAIS échouer la demande de suppression', () async {
      final service = EffacementLocalDiffere(
        lire: () async => null,
        ecrire: (_) async => throw Exception('stockage indisponible'),
        suppressionMenee: (_) async => true,
        effacerMateriel: (_) async {},
      );
      await expectLater(service.programmer('uid-a', echeance), completes);
    });
  });

  group('quand effacer : jamais avant l\'échéance + 1 jour, jamais sans le serveur', () {
    test('avant l\'échéance : rien, et le serveur n\'est même pas interrogé', () async {
      final b = _Banc(serveurMenee: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: -3));

      final r = await b.service.executerSiEchu();

      expect(b.interroges, isEmpty);
      expect(b.effaces, isEmpty);
      expect(r.enAttente, 1);
    });

    test('à l\'échéance mais dans la marge d\'un jour : rien encore', () async {
      final b = _Banc(serveurMenee: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(hours: 23));

      await b.service.executerSiEchu();

      expect(b.interroges, isEmpty,
          reason: 'la fonction planifiée tourne toutes les heures, et une purge '
              'en échec est reprise après 30 minutes');
      expect(b.effaces, isEmpty);
    });

    test('échu, le serveur dit NON : rien n\'est effacé, le marqueur reste', () async {
      // Annulée sur un autre appareil, ou fonction planifiée en retard : dans les
      // deux cas les clés de ce téléphone servent peut-être encore.
      final b = _Banc(serveurMenee: false);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 2));

      final r = await b.service.executerSiEchu();

      expect(b.interroges, ['uid-a']);
      expect(b.effaces, isEmpty);
      expect(b.marqueurs, ['uid-a']);
      expect(r.effaces, isEmpty);
    });

    test('échu, le serveur dit OUI : le matériel est effacé et le marqueur retiré', () async {
      final b = _Banc(serveurMenee: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 2));

      final r = await b.service.executerSiEchu();

      expect(b.effaces, ['uid-a']);
      expect(b.marqueurs, isEmpty);
      expect(r.effaces, ['uid-a']);
      expect(r.enAttente, 0);
    });

    test('le serveur est injoignable : rien n\'est effacé, le marqueur reste', () async {
      final b = _Banc(serveurEchoue: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 2));

      await expectLater(b.service.executerSiEchu(), completes);

      expect(b.effaces, isEmpty, reason: 'une erreur n\'est pas un « oui »');
      expect(b.marqueurs, ['uid-a']);
    });

    test('un effacement qui échoue garde le marqueur : on retentera au démarrage suivant', () async {
      final b = _Banc(serveurMenee: true, effacementEchoue: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 2));

      final r = await b.service.executerSiEchu();

      expect(b.marqueurs, ['uid-a']);
      expect(r.effaces, isEmpty);

      // Le disque est libéré : le passage suivant aboutit.
      b.effacementEchoue = false;
      await b.service.executerSiEchu();
      expect(b.effaces, ['uid-a']);
      expect(b.marqueurs, isEmpty);
    });

    test('jamais le compte actuellement connecté, quoi que dise le serveur', () async {
      final b = _Banc(serveurMenee: true, connecte: 'uid-a');
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 2));

      await b.service.executerSiEchu();

      expect(b.effaces, isEmpty);
      expect(b.interroges, isEmpty);
      expect(b.marqueurs, ['uid-a']);
    });

    test('deux comptes : chacun est jugé séparément', () async {
      final b = _Banc();
      await b.service.programmer('uid-a', echeance);
      await b.service.programmer('uid-b', echeance);
      b.maintenant = apres(const Duration(days: 2));

      final service = EffacementLocalDiffere(
        lire: () async => b.stocke,
        ecrire: (v) async => b.stocke = v,
        // Le serveur confirme A seulement.
        suppressionMenee: (uid) async => uid == 'uid-a',
        effacerMateriel: (uid) async => b.effaces.add(uid),
        maintenant: () => b.maintenant,
      );
      await service.executerSiEchu();

      expect(b.effaces, ['uid-a']);
      expect(b.marqueurs, ['uid-b']);
    });

    test('un an après l\'échéance, on cesse d\'interroger', () async {
      final b = _Banc(serveurMenee: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 400));

      await b.service.executerSiEchu();

      expect(b.interroges, isEmpty);
      expect(b.effaces, isEmpty);
      expect(b.marqueurs, isEmpty, reason: 'le marqueur est abandonné');
    });

    test('deux appels simultanés partagent le même passage : le serveur n\'est interrogé qu\'une fois', () async {
      final b = _Banc(serveurMenee: true);
      await b.service.programmer('uid-a', echeance);
      b.maintenant = apres(const Duration(days: 2));

      await Future.wait([b.service.executerSiEchu(), b.service.executerSiEchu()]);

      expect(b.interroges, ['uid-a']);
      expect(b.effaces, ['uid-a']);
    });
  });

  group('un marqueur qu\'on ne sait pas lire n\'efface JAMAIS rien', () {
    for (final (nom, brut) in <(String, String)>[
      ('du JSON cassé', '{pas du json'),
      ('un objet au lieu d\'une liste', '{"uid":"uid-a","echeance":"2026-10-18T09:00:00Z"}'),
      ('un uid vide', '[{"uid":"","echeance":"2026-10-18T09:00:00Z"}]'),
      ('une échéance illisible', '[{"uid":"uid-a","echeance":"demain"}]'),
      ('un uid qui n\'est pas une chaîne', '[{"uid":42,"echeance":"2026-10-18T09:00:00Z"}]'),
      ('une liste de bruit', '[1, "x", null, []]'),
    ]) {
      test(nom, () async {
        final b = _Banc(serveurMenee: true)..stocke = brut;
        b.maintenant = apres(const Duration(days: 5));

        await expectLater(b.service.executerSiEchu(), completes);

        expect(b.interroges, isEmpty);
        expect(b.effaces, isEmpty);
      });
    }

    test('un marqueur valide voisin d\'un marqueur cassé reste utilisable', () async {
      final b = _Banc(serveurMenee: true)
        ..stocke = '[{"uid":42},{"uid":"uid-ok","echeance":"2026-10-18T09:00:00Z"}]';
      b.maintenant = apres(const Duration(days: 5));

      await b.service.executerSiEchu();

      expect(b.effaces, ['uid-ok']);
    });

    test('rien de stocké : rien à faire, et aucune écriture', () async {
      final b = _Banc(serveurMenee: true);
      final r = await b.service.executerSiEchu();
      expect(r.enAttente, 0);
      expect(b.stocke, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Ce qui est réellement effacé, et pour qui
  // ═══════════════════════════════════════════════════════════════════════
  group('MaterielLocal : la base MLS, les clés et les préférences DE CE COMPTE', () {
    late Directory dossier;

    setUp(() {
      dossier = Directory.systemTemp.createTempSync('mls_effacement_');
      addTearDown(() {
        if (dossier.existsSync()) dossier.deleteSync(recursive: true);
      });
    });

    void poser(String nom) => File('${dossier.path}/$nom').writeAsStringSync('x');

    test('les quatre fichiers SQLite du compte partent, ceux d\'un autre compte restent', () async {
      const uid = 'uidSupprime123';
      const autre = 'autreCompte456';
      for (final suf in ['', '-wal', '-shm', '-journal']) {
        poser('${nomFichierBaseMls(uid)}$suf');
        poser('${nomFichierBaseMls(autre)}$suf');
      }
      SharedPreferences.setMockInitialValues({});
      final materiel = MaterielLocal(
        dossierMls: () async => dossier,
        preferences: SharedPreferences.getInstance,
        effacerSignal: (_) async {},
        viderClesDerivees: () async {},
      );

      final r = await materiel.effacer(uid);

      expect(r.fichiers, 4);
      for (final suf in ['', '-wal', '-shm', '-journal']) {
        expect(File('${dossier.path}/${nomFichierBaseMls(uid)}$suf').existsSync(), isFalse);
        expect(File('${dossier.path}/${nomFichierBaseMls(autre)}$suf').existsSync(), isTrue,
            reason: 'la base d\'un AUTRE compte du même téléphone ne se touche pas');
      }
    });

    test('vérifications et curseurs de CE compte partent ; ceux des autres, et le reste, restent', () async {
      SharedPreferences.setMockInitialValues({
        'mls_verif_uidA_appareil1': 'v',
        'mls_verif_uidA_appareil2': 'v',
        'mls_curseur_uidA_conv1': '12',
        'mls_verif_uidB_appareil1': 'v',
        'mls_curseur_uidB_conv1': '7',
        'theme': 'sombre',
        // Préfixe voisin : `uidA_x` n'est pas `uidA`.
        'mls_verif_uidAA_appareil1': 'v',
      });
      final materiel = MaterielLocal(
        dossierMls: () async => dossier,
        preferences: SharedPreferences.getInstance,
        effacerSignal: (_) async {},
        viderClesDerivees: () async {},
      );

      final r = await materiel.effacer('uidA');

      expect(r.preferences, 3);
      final p = await SharedPreferences.getInstance();
      expect(p.getKeys(), {
        'mls_verif_uidB_appareil1',
        'mls_curseur_uidB_conv1',
        'theme',
        'mls_verif_uidAA_appareil1',
      });
    });

    test('les clés Signal et les clés dérivées sont effacées, une fois chacune', () async {
      SharedPreferences.setMockInitialValues({});
      final signal = <String>[];
      var derivees = 0;
      final materiel = MaterielLocal(
        dossierMls: () async => dossier,
        preferences: SharedPreferences.getInstance,
        effacerSignal: (uid) async => signal.add(uid),
        viderClesDerivees: () async => derivees++,
      );

      await materiel.effacer('uidA');

      expect(signal, ['uidA']);
      expect(derivees, 1);
    });

    test('un uid VIDE est refusé : son préfixe effacerait les clés de TOUS les comptes', () async {
      SharedPreferences.setMockInitialValues({'mls_verif__x': 'v'});
      final materiel = MaterielLocal(
        dossierMls: () async => dossier,
        preferences: SharedPreferences.getInstance,
        effacerSignal: (_) async {},
        viderClesDerivees: () async {},
      );

      await expectLater(materiel.effacer(''), throwsArgumentError);
    });

    test('une étape qui échoue n\'empêche pas les autres, mais l\'ensemble LÈVE', () async {
      SharedPreferences.setMockInitialValues({'mls_verif_uidA_x': 'v'});
      poser(nomFichierBaseMls('uidA'));
      var derivees = 0;
      final materiel = MaterielLocal(
        dossierMls: () async => dossier,
        preferences: SharedPreferences.getInstance,
        effacerSignal: (_) async => throw StateError('keystore verrouillé'),
        viderClesDerivees: () async => derivees++,
      );

      await expectLater(materiel.effacer('uidA'), throwsStateError);

      // Les autres étapes ont bien eu lieu : rien ne reste « à moitié » par
      // prudence — et le marqueur, lui, restera pour retenter.
      expect(File('${dossier.path}/${nomFichierBaseMls('uidA')}').existsSync(), isFalse);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(derivees, 1);
    });

    test('un compte sans aucun fichier : ni erreur ni faux compte', () async {
      SharedPreferences.setMockInitialValues({});
      final materiel = MaterielLocal(
        dossierMls: () async => dossier,
        preferences: SharedPreferences.getInstance,
        effacerSignal: (_) async {},
        viderClesDerivees: () async {},
      );

      final r = await materiel.effacer('uidJamaisVu');

      expect(r.fichiers, 0);
      expect(r.preferences, 0);
    });
  });
}
