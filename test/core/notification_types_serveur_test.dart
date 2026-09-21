import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les types de notification que l'app émet par `create_user_notification`
/// doivent tous être acceptés par le serveur.
///
/// La fonction tient une liste FERMÉE (`c_types_permis`), et refuse le reste
/// en 23514 — refus que `NotificationService.createNotification` avale pour ne
/// pas faire échouer le geste qui l'a déclenché. Un type oublié côté serveur
/// ne se voit donc NULLE PART : l'ami est ajouté, la publication aimée, et la
/// notification n'existe pas.
///
/// C'est arrivé le 2026-09-21 : la liste disait « les douze types que `lib/`
/// émet », il y en avait quatorze. `_notifyPostAuthor` reçoit son type en
/// paramètre — `postLiked`, `postReposted` — et le relevé à la main ne l'a
/// pas vu. Ce test fait le relevé à sa place, à chaque exécution.
void main() {
  /// Types que l'app émet encore mais que le serveur a retirés EXPRÈS. Cette
  /// liste ne doit que rétrécir.
  const retiresExpres = <String, String>{
    // Chaîne de paiement fermée des deux côtés le 2026-09-21 : aucune
    // commande ne peut plus naître, ces types ne pouvaient plus servir qu'à
    // des notifications falsifiées (migration 20260921100000).
    'newOrder': 'place de marché fermée',
    'orderPaid': 'place de marché fermée',
    'orderShipped': 'place de marché fermée',
    'orderDelivered': 'place de marché fermée',
    'orderCancelled': 'place de marché fermée',
  };

  /// La liste du serveur, lue dans la DERNIÈRE migration qui la définit.
  Set<String> typesServeur() {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in migrations.reversed) {
      final s = f.readAsStringSync();
      final m = RegExp(r'c_types_permis constant text\[\] := ARRAY\[(.*?)\];',
              dotAll: true)
          .firstMatch(s);
      if (m != null) {
        return RegExp(r"'([A-Za-z_]+)'").allMatches(m[1]!).map((x) => x[1]!).toSet();
      }
    }
    fail('aucune migration ne définit c_types_permis');
  }

  /// Chaque type littéral passé par l'app : `type: '…'` aux appels de
  /// `createNotification` et `_notifyPostAuthor`, et `'p_type': '…'` aux
  /// appels directs de la RPC.
  Map<String, List<String>> typesEmis() {
    final res = <String, List<String>>{};
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      void noter(String type, int pos) {
        final ligne = '\n'.allMatches(s.substring(0, pos)).length + 1;
        res.putIfAbsent(type, () => []).add('${f.path}:$ligne');
      }

      for (final m in RegExp(r'(createNotification|_notifyPostAuthor)\(').allMatches(s)) {
        // L'appel jusqu'à sa parenthèse fermante.
        var j = m.end;
        var profondeur = 1;
        while (j < s.length && profondeur > 0) {
          if (s[j] == '(') profondeur++;
          if (s[j] == ')') profondeur--;
          j++;
        }
        final appel = s.substring(m.end, j);
        for (final t in RegExp(r"\btype:\s*'([A-Za-z_]+)'").allMatches(appel)) {
          noter(t[1]!, m.start);
        }
      }
      for (final t in RegExp(r"'p_type':\s*'([A-Za-z_]+)'").allMatches(s)) {
        noter(t[1]!, t.start);
      }
    }
    return res;
  }

  test('le relevé trouve bien des types (il ne tourne pas à vide)', () {
    final emis = typesEmis();
    expect(emis.keys, containsAll(['friendRequest', 'postLiked', 'report_resolved']));
  });

  test('chaque type émis par l\'app est accepté par le serveur', () {
    final serveur = typesServeur();
    final refuses = {
      for (final e in typesEmis().entries)
        if (!serveur.contains(e.key) && !retiresExpres.containsKey(e.key))
          e.key: e.value,
    };
    expect(refuses, isEmpty,
        reason: 'type émis par l\'app mais absent de c_types_permis : la '
            'notification serait refusée en silence. L\'ajouter à la '
            'fonction, AVEC son texte serveur.');
  });

  test('un type retiré exprès l\'est vraiment côté serveur', () {
    expect(typesServeur().intersection(retiresExpres.keys.toSet()), isEmpty);
  });
}
