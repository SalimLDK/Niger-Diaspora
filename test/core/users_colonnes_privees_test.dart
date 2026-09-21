import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/constants/colonnes_users.dart';

/// Garde de la fermeture 1.1b de l'audit pré-production : un compte connecté
/// ne doit plus lire, chez autrui, e-mail, téléphone, position, jetons push ni
/// session.
///
/// La fermeture est un `REVOKE SELECT` + `GRANT SELECT (colonnes publiques)`
/// sur `public.users` (`supabase/users-colonnes-privees-cible.sql`). Sous
/// droits par colonnes, PostgREST refuse la requête ENTIÈRE dès qu'elle touche
/// une colonne non accordée — `select()` nu, filtre, tri. Ce test fait en
/// sorte que l'app n'en touche plus aucune, et qu'elle reste d'accord avec la
/// cible :
///
/// - la liste Dart `colonnesPubliquesUsers` est identique au `GRANT` ;
/// - aucune chaîne `from('users')` de `lib/` ne lit `*` ni ne cite une colonne
///   révoquée hors d'une écriture ;
/// - les abonnements temps réel sur `users` sont nommés : le temps réel RETIRE
///   une colonne révoquée sans erreur, un nouvel abonnement doit donc être
///   écrit en le sachant.
void main() {
  /// Les 14 colonnes retirées par la cible. Sa liste fait foi ; le premier
  /// test vérifie qu'on parle de la même.
  const revoquees = <String>{
    'email', 'phone_number', 'latitude', 'longitude', 'location_updated_at',
    'fcm_tokens', 'voip_token', 'last_token_update', 'session_id', 'cart_data',
    'ban_reason', 'banned_at', 'banned_by', 'admin_role',
  };

  // Fins de ligne normalisées : un checkout Windows peut rendre ce fichier en
  // CRLF (voir « Checkout CRLF » dans la mémoire du projet), et les motifs
  // ci-dessous cherchent des `\n`.
  final cible = File('supabase/users-colonnes-privees-cible.sql')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  group('la liste Dart et la cible disent la même chose', () {
    test('colonnesPubliquesUsers est exactement le GRANT de la cible', () {
      final grant = RegExp(r'GRANT SELECT \((.*?)\) ON public\.users', dotAll: true)
          .firstMatch(cible);
      expect(grant, isNotNull, reason: 'GRANT introuvable dans la cible');
      final accordees = grant!
          .group(1)!
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toSet();

      expect(colonnesPubliquesUsers.toSet(), accordees);
      expect(colonnesPubliquesUsers.length, accordees.length,
          reason: 'doublon dans colonnesPubliquesUsers');
    });

    test('les 14 colonnes révoquées sont celles que la cible annonce', () {
      final annonce = RegExp(r'-- Tout sauf : (.*?)\.\n', dotAll: true)
          .firstMatch(cible);
      expect(annonce, isNotNull, reason: '« Tout sauf » introuvable');
      final listees = annonce!
          .group(1)!
          .replaceAll('--', '')
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toSet();
      expect(listees, revoquees);
    });

    test('aucune colonne révoquée n\'est accordée', () {
      expect(colonnesPubliquesUsers.toSet().intersection(revoquees), isEmpty);
    });

    test('id et is_admin restent accordés', () {
      // Deux policies d'AUTRES tables (content_reports, mls_diagnostics) les
      // lisent sous le rôle de l'appelant : les retirer ferait tomber ces
      // tables en 42501, loin d'ici.
      expect(colonnesPubliquesUsers, containsAll(['id', 'is_admin']));
    });
  });

  group('aucune lecture de users ne sort de la liste', () {
    final fichiers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'))
        .toList();

    /// Le source sans ses commentaires, lignes préservées.
    ///
    /// Un commentaire glissé au milieu d'une chaîne d'appel porte des
    /// apostrophes, des parenthèses et des points-virgules : la première
    /// version de ce test s'y est trompée deux fois — un `;` de commentaire
    /// coupait la chaîne en plein upsert, et une apostrophe faisait passer un
    /// nom de colonne cité en prose pour une chaîne littérale.
    String sansCommentaires(String s) => s
        .replaceAllMapped(RegExp(r'/\*.*?\*/', dotAll: true),
            (m) => '\n' * '\n'.allMatches(m[0]!).length)
        .replaceAll(RegExp(r'//[^\n]*'), '');

    /// Chaque chaîne `from('users')…;`, contenu des écritures retiré — une
    /// écriture peut nommer une colonne révoquée, la cible ne retire que la
    /// LECTURE.
    List<({String ou, String lecture})> chaines() {
      final res = <({String ou, String lecture})>[];
      for (final f in fichiers) {
        final s = sansCommentaires(f.readAsStringSync());
        for (final m in RegExp(r"from\(\s*'users'\s*\)").allMatches(s)) {
          final fin = s.indexOf(';', m.end);
          var chaine = s.substring(m.end, fin < 0 ? s.length : fin);
          for (final verbe in ['insert', 'update', 'upsert']) {
            while (true) {
              final k = chaine.indexOf('.$verbe(');
              if (k < 0) break;
              var j = k + verbe.length + 2;
              var profondeur = 1;
              while (j < chaine.length && profondeur > 0) {
                if (chaine[j] == '(') profondeur++;
                if (chaine[j] == ')') profondeur--;
                j++;
              }
              chaine = '${chaine.substring(0, k)}.ECRITURE()${chaine.substring(j)}';
            }
          }
          final ligne = '\n'.allMatches(s.substring(0, m.start)).length + 1;
          res.add((ou: '${f.path}:$ligne', lecture: chaine));
        }
      }
      return res;
    }

    test('le balayage trouve bien des lectures (il ne tourne pas à vide)', () {
      expect(chaines().length, greaterThan(10));
    });

    test('ni select() nu, ni select(\'*\'), ni .stream()', () {
      final fautes = [
        for (final c in chaines())
          if (RegExp(r"\.select\(\s*(\)|'\*')").hasMatch(c.lecture) ||
              c.lecture.contains('.stream('))
            c.ou,
      ];
      expect(fautes, isEmpty,
          reason: 'lecture de `*` sur users — refusée entière sous la cible');
    });

    test('aucune colonne révoquée lue, filtrée ou triée', () {
      final fautes = <String>[];
      for (final c in chaines()) {
        for (final col in revoquees) {
          if (RegExp("['\"][^'\"]*\\b$col\\b[^'\"]*['\"]").hasMatch(c.lecture)) {
            fautes.add('${c.ou} → $col');
          }
        }
      }
      expect(fautes, isEmpty,
          reason: 'passer par mon_profil_prive(), positions_partagees*() ou '
              'profils_admin() — voir lib/core/constants/colonnes_users.dart');
    });

    test('aucun upsert n\'écrit une colonne révoquée', () {
      // PostgREST traduit un upsert en `ON CONFLICT DO UPDATE SET col =
      // EXCLUDED.col`, et évaluer `EXCLUDED.col` exige le droit de LIRE la
      // colonne. Mesuré sous la cible (banc users_colonnes_privees_cible.sql,
      // cas D5/D6) : 42501, alors qu'un UPDATE ciblé ou un INSERT simple
      // passent. Écrire sa ligne par `ecrireSaLigneUsers`.
      final fautes = <String>[];
      for (final f in fichiers) {
        final s = sansCommentaires(f.readAsStringSync());
        for (final m in RegExp(r"from\(\s*'users'\s*\)").allMatches(s)) {
          final fin = s.indexOf(';', m.end);
          final chaine = s.substring(m.end, fin < 0 ? s.length : fin);
          final k = chaine.indexOf('.upsert(');
          if (k < 0) continue;
          final cles = RegExp(r"'([a-z_]+)'\s*:")
              .allMatches(chaine.substring(k))
              .map((c) => c[1]!)
              .toSet();
          final ecrites = cles.intersection(revoquees);
          if (ecrites.isNotEmpty) {
            final ligne = '\n'.allMatches(s.substring(0, m.start)).length + 1;
            fautes.add('${f.path}:$ligne → ${ecrites.join(',')}');
          }
        }
      }
      expect(fautes, isEmpty);
    });

    test('aucune jointure PostgREST en étoile vers users', () {
      final fautes = <String>[];
      for (final f in fichiers) {
        final s = sansCommentaires(f.readAsStringSync());
        for (final m in RegExp(r'users(![a-z_]+)*\(\s*\*').allMatches(s)) {
          fautes.add('${f.path}:${'\n'.allMatches(s.substring(0, m.start)).length + 1}');
        }
      }
      expect(fautes, isEmpty);
    });

    test('les abonnements temps réel sur users sont ceux qu\'on connaît', () {
      // Le temps réel RETIRE du message une colonne révoquée, sans erreur :
      // un rappel qui la lit reçoit `null` et se tait. Chacun de ceux-ci a
      // été écrit en le sachant — voir le commentaire de son rappel. Un
      // nouvel abonnement doit l'être aussi avant d'entrer dans cette liste.
      const connus = <String, int>{
        // getUserStream (superpose le message à la dernière ligne connue) et
        // watchProfileLocationUpdates (le message n'est qu'un signal).
        'lib/features/profile/data/datasources/profile_supabase_datasource.dart': 2,
        // Décision d'administration : relit par mon_profil_prive() quand
        // `session_id` manque au message.
        'lib/core/services/session_service.dart': 1,
      };
      final trouves = <String, int>{};
      for (final f in fichiers) {
        final n = RegExp(r"table:\s*'users'")
            .allMatches(sansCommentaires(f.readAsStringSync()))
            .length;
        if (n > 0) trouves[f.path.replaceAll(r'\', '/')] = n;
      }
      expect(trouves, connus);
    });
  });
}
