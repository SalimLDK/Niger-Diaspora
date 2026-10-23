// Lecture des signalements que l'app écrit dans Firestore. L'app les écrit sous
// TROIS formes ; le panneau doit les afficher toutes, et ne jamais lever sur un
// champ manquant (un signalement qui lève disparaît de la file).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/signalement_firestore.dart';

void main() {
  group('signalementDepuisFirestore', () {
    test('forme du dépôt de signalements (report_remote_datasource)', () {
      final r = signalementDepuisFirestore('d1', {
        'reporterId': 'u1',
        'reporterName': 'Awa',
        'targetType': 'business',
        'targetId': 'b1',
        'targetName': 'Chez Moussa',
        'reason': 'spam',
        'description': 'pub répétée',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 14, 10)),
        'contentSnapshot': {
          'text': 'achetez !',
          'capturedAt': Timestamp.fromDate(DateTime(2026, 10, 14, 9)),
        },
        'reportedUserId': 'u2',
      });
      expect(r.id, 'd1');
      expect(r.source, sourceFirestore);
      expect(r.targetType, 'business');
      expect(r.reporterName, 'Awa');
      expect(r.createdAt, DateTime(2026, 10, 14, 10));
      expect(r.contentSnapshot?.text, 'achetez !');
      expect(r.contentSnapshot?.capturedAt, DateTime(2026, 10, 14, 9));
      expect(r.reportedUserId, 'u2');
    });

    test("forme d'un message signalé : `type` et `reportedBy`", () {
      final r = signalementDepuisFirestore('d2', {
        'type': 'message',
        'targetId': 'm1',
        'conversationId': 'c1',
        'reportedBy': 'u9',
        'reason': 'harcèlement',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'status': 'pending',
      });
      expect(r.targetType, 'message');
      expect(r.reporterId, 'u9');
      expect(r.conversationId, 'c1');
      expect(r.reporterName, isNull);
    });

    test("forme d'une conversation signalée : `type` et `reporterId`", () {
      final r = signalementDepuisFirestore('d3', {
        'type': 'conversation',
        'conversationId': 'c2',
        'reporterId': 'u3',
        'reason': 'autre',
        'description': 'détail',
        'status': 'pending',
      });
      expect(r.targetType, 'conversation');
      expect(r.reporterId, 'u3');
      expect(r.createdAt, isNull, reason: 'pas de date : null, pas de levée');
    });

    test('un document presque vide ne lève pas', () {
      final r = signalementDepuisFirestore('d4', {});
      expect(r.targetType, 'unknown');
      expect(r.status, 'pending');
      expect(r.reporterId, '');
      expect(r.source, sourceFirestore);
    });
  });

  group('plusRecentDabord', () {
    ReportEntity r(DateTime? d) => ReportEntity(
          id: 'x',
          reporterId: '',
          targetType: 't',
          targetId: '',
          reason: '',
          createdAt: d,
        );

    test("le plus récent d'abord, une date inconnue en dernier", () {
      final l = [r(null), r(DateTime(2026, 1, 1)), r(DateTime(2026, 6, 1))]
        ..sort(plusRecentDabord);
      expect(
        l.map((e) => e.createdAt),
        [DateTime(2026, 6, 1), DateTime(2026, 1, 1), null],
      );
    });
  });

  group('signalementCorrespond', () {
    const r = ReportEntity(
      id: 'x',
      reporterId: '',
      targetType: 'user',
      targetId: 'ID-42',
      targetName: 'Fatou Maiga',
      reporterName: 'Awa',
      reason: 'Spam',
      description: 'pub répétée',
    );

    test('une recherche vide laisse tout passer', () {
      expect(signalementCorrespond(r, ''), isTrue);
      expect(signalementCorrespond(r, '  '), isTrue);
    });

    test('les cinq champs, sans casse', () {
      for (final q in ['fatou', 'AWA', 'spam', 'id-42', 'RÉPÉTÉE']) {
        expect(signalementCorrespond(r, q), isTrue, reason: q);
      }
      expect(signalementCorrespond(r, 'introuvable'), isFalse);
    });
  });

  test('« Traités » est tout sauf `pending`, « Tous » est les quatre', () {
    expect(statutsFirestoreTraites, isNot(contains('pending')));
    expect(
      statutsFirestoreTous.toSet(),
      {'pending', ...statutsFirestoreTraites},
    );
  });
}
