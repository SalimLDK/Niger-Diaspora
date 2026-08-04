import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/utils/date_parsing.dart';
import 'package:diaspo_niger/features/feed/data/models/post_model.dart';

/// Régression : une publication créée à 02:01 heure locale (Toronto, UTC-4)
/// s'affichait « 06:01 ». `PostModel.parseDate` faisait `DateTime.parse` sur
/// un `created_at` Supabase terminé par `Z`, ce qui donne un `DateTime` en
/// UTC dont `DateFormat` imprime les composantes telles quelles.
///
/// Ces tests sont indépendants du fuseau de la machine qui les exécute : ils
/// comparent au `toLocal()` attendu plutôt qu'à une heure écrite en dur.
void main() {
  group('tryParseLocalDate', () {
    test('une chaîne ISO en Z ressort en heure locale', () {
      final parsed = tryParseLocalDate('2026-08-04T06:01:00Z');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed, DateTime.utc(2026, 8, 4, 6, 1).toLocal());
      // C'est bien l'affichage qui changeait : mêmes instants, composantes
      // différentes dès que le fuseau n'est pas UTC.
      expect(parsed.millisecondsSinceEpoch,
          DateTime.utc(2026, 8, 4, 6, 1).millisecondsSinceEpoch);
    });

    test('un décalage explicite est ramené au fuseau local', () {
      final parsed = tryParseLocalDate('2026-08-04T08:01:00+02:00');

      expect(parsed!.isUtc, isFalse);
      expect(parsed, DateTime.utc(2026, 8, 4, 6, 1).toLocal());
    });

    test('une chaîne sans fuseau est déjà locale : toLocal() est un no-op', () {
      final parsed = tryParseLocalDate('2026-08-04T02:01:00');

      expect(parsed!.isUtc, isFalse);
      expect(parsed, DateTime(2026, 8, 4, 2, 1));
    });

    test('accepte un DateTime UTC déjà construit (chemin Firestore)', () {
      final parsed = tryParseLocalDate(DateTime.utc(2026, 8, 4, 6, 1));

      expect(parsed!.isUtc, isFalse);
      expect(parsed, DateTime.utc(2026, 8, 4, 6, 1).toLocal());
    });

    test('renvoie null sur une valeur absente ou illisible', () {
      expect(tryParseLocalDate(null), isNull);
      expect(tryParseLocalDate(''), isNull);
      expect(tryParseLocalDate('pas une date'), isNull);
      expect(tryParseLocalDate(const {}), isNull);
    });
  });

  group('toIsoUtc', () {
    test('réencode une date locale avec un suffixe Z explicite', () {
      final local = DateTime.utc(2026, 8, 4, 6, 1).toLocal();

      // Le piège corrigé : sans toUtc(), une date locale sérialise sans
      // suffixe de fuseau et le serveur la relit comme de l'UTC.
      expect(local.toIso8601String(), isNot(endsWith('Z')));
      expect(toIsoUtc(local), '2026-08-04T06:01:00.000Z');
    });

    test('aller-retour neutre : parse -> réencode conserve l\'instant', () {
      const source = '2026-08-04T06:01:00.000Z';

      expect(toIsoUtc(tryParseLocalDate(source)!), source);
    });

    test('toIsoUtcOrNull propage null', () {
      expect(toIsoUtcOrNull(null), isNull);
      expect(toIsoUtcOrNull(DateTime.utc(2026, 8, 4, 6, 1)),
          '2026-08-04T06:01:00.000Z');
    });
  });

  group('PostModel', () {
    Map<String, dynamic> postJson(String createdAt) => {
          'id': 'p1',
          'authorId': 'u1',
          'authorName': 'Salim',
          'content': 'bonjour',
          'createdAt': createdAt,
          'updatedAt': createdAt,
        };

    test('createdAt issu d\'un ISO en Z est local', () {
      final post = PostModel.fromJson(postJson('2026-08-04T06:01:00Z'));

      expect(post.createdAt.isUtc, isFalse);
      expect(post.createdAt, DateTime.utc(2026, 8, 4, 6, 1).toLocal());
      expect(post.updatedAt.isUtc, isFalse);
    });

    test('toJson réémet de l\'UTC explicite (cache et serveur non ambigus)',
        () {
      final post = PostModel.fromJson(postJson('2026-08-04T06:01:00Z'));

      expect(post.toJson()['createdAt'], '2026-08-04T06:01:00.000Z');
    });

    test('l\'aller-retour par le cache conserve l\'instant', () {
      final post = PostModel.fromJson(postJson('2026-08-04T06:01:00Z'));
      final relu = PostModel.fromJson(post.toJson());

      expect(relu.createdAt, post.createdAt);
      expect(relu.createdAt.isUtc, isFalse);
    });

    test('une date absente ne fait pas échouer la désérialisation', () {
      final post = PostModel.fromJson(postJson('')..remove('createdAt'));

      expect(post.createdAt.isUtc, isFalse);
    });
  });
}
