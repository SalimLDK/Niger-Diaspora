import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un provider ne doit pas câbler un datasource Firestore quand son
/// remplaçant Supabase existe.
///
/// Ce test existe parce que ce défaut est apparu **trois fois le même jour**
/// (2026-08-06), dans trois modules sans rapport :
///
/// | Module              | Symptôme                          | Preuve            |
/// |---------------------|-----------------------------------|-------------------|
/// | recherche de gens   | 1 personne trouvable sur 10       | Supabase 10 / FS 2|
/// | notifications       | liste in-app vide du pipeline     | Supabase 44 / FS 34|
/// | demandes d'adhésion | demande impossible à approuver    | Supabase 1 / FS 0 |
///
/// Toujours la même mise en scène : le provider reste sur l'ancien
/// datasource, le remplaçant Supabase attend juste à côté, et l'échec est
/// **silencieux**. C'est ce dernier point qui rend le défaut si durable —
/// une liste vide ne ressemble pas à une panne, elle ressemble à une base
/// peu peuplée. Aucun log, aucune exception, aucun test rouge.
///
/// L'appariement se fait par **concept**, pas par module. C'est ce qui évite
/// les faux positifs que produisait la première version de ce contrôle :
/// `AudioRoomRemoteDataSourceImpl` cohabite avec `MonetizationSupabaseDataSource`
/// sans que l'un remplace l'autre, et le suffixe `Impl` ne veut pas dire
/// Firestore — cette classe-là parle déjà à Supabase et à RTDB.
void main() {
  /// `NotificationRemoteDataSourceImpl` -> `Notification`
  /// `GroupRequestSupabaseDataSource`   -> `GroupRequest`
  String concept(String classe) {
    var n = classe;
    for (final mot in ['Impl', 'Supabase', 'Firestore', 'Remote', 'DataSource']) {
      n = n.replaceAll(mot, '');
    }
    return n;
  }

  test('aucun datasource Firestore câblé quand un Supabase existe', () {
    final racine = Directory('lib/features');
    expect(racine.existsSync(), isTrue, reason: 'lancé depuis la racine du dépôt');

    final impls = <String, String>{}; // concept -> nom de classe
    final supabases = <String>{}; // concepts couverts par Supabase
    final fichiers = racine
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final f in fichiers) {
      for (final m in RegExp(
        r'^class (\w*DataSource\w*)\b',
        multiLine: true,
      ).allMatches(f.readAsStringSync())) {
        final nom = m.group(1)!;
        if (nom.contains('Supabase')) {
          supabases.add(concept(nom));
        } else if (nom.endsWith('Impl')) {
          impls[concept(nom)] = nom;
        }
      }
    }

    // Concepts servis par les deux : c'est là que le câblage peut se tromper.
    final aRisque = {
      for (final e in impls.entries)
        if (supabases.contains(e.key)) e.value: e.key,
    };
    expect(
      aRisque,
      isNotEmpty,
      reason: 'aucun couple détecté : la convention de nommage a changé, '
          'ce test ne surveille plus rien',
    );

    final fautes = <String>[];
    for (final f in fichiers) {
      // Le datasource déprécié a le droit d'exister ; ce qui compte, c'est
      // qu'aucun appelant ne l'instancie.
      if (f.path.replaceAll(r'\', '/').contains('/data/datasources/')) continue;
      final source = f.readAsStringSync().replaceAll(RegExp(r'//.*'), '');
      for (final entree in aRisque.entries) {
        if (RegExp(r'\b' + entree.key + r'\s*\(').hasMatch(source)) {
          fautes.add('  ${entree.key}() dans ${f.path.replaceAll(r'\', '/')}\n'
              '      -> utiliser le datasource Supabase du concept '
              '« ${entree.value} »');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason: 'Datasource Firestore câblé alors qu\'un remplaçant Supabase '
          'existe :\n${fautes.join('\n')}\n\n'
          'Avant de basculer, compter les deux bases — c\'est ce qui a '
          'transformé le soupçon en fait les trois fois. Une base peuplée des '
          'deux côtés est un module à moitié migré, quoi qu\'en dise le code.\n'
          'Si la cohabitation est voulue (double écriture, RTDB pour la '
          'présence), renommer la classe pour qu\'elle ne réponde plus au '
          'motif, ou documenter ici pourquoi.',
    );
  });
}
