// Une ligne de `public.reports` devient un ReportModel : c'est ce que lit
// l'écran « Mes signalements » depuis que les signalements vivent dans
// Supabase (migration 20261015100000).
import 'package:diaspo_niger/features/reports/data/models/report_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromSupabase lit les colonnes snake_case', () {
    final m = ReportModel.fromSupabase({
      'id': 'r1',
      'reporter_id': 'uid-1',
      'reporter_name': 'Aïcha',
      'target_type': 'message',
      'target_id': 'msg-1',
      'conversation_id': 'conv-1',
      'reason': 'spam',
      'status': 'resolved',
      'action_taken': 'content_removed',
      'reported_user_id': 'uid-2',
      'created_at': '2026-10-15T08:00:00+00:00',
      'content_snapshot': {'text': 'bonjour', 'capturedAt': '2026-10-15T08:00:00Z'},
    });
    expect(m.reporterId, 'uid-1');
    expect(m.targetType, 'message');
    expect(m.conversationId, 'conv-1');
    expect(m.resolution, 'content_removed');
    expect(m.reportedUserId, 'uid-2');
    expect(m.contentSnapshot?.text, 'bonjour');
    expect(m.createdAt, isNotNull);
  });

  test('une ligne minimale ne plante pas', () {
    final m = ReportModel.fromSupabase({'id': 'r2'});
    expect(m.status, 'pending');
    expect(m.reportedUserNotified, isFalse);
    expect(m.contentSnapshot, isNull);
  });

  test("toSupabase écrit la date en ISO, pas en Timestamp Firestore", () {
    final j = const ContentSnapshotModel(text: 't').toSupabase();
    expect(j['text'], 't');
    expect(j['capturedAt'], isA<String>());
  });
}
