import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audit du module appels (2026-10-14), côté application. Les appels sont en
/// pause dans l'interface : ces défauts auraient empêché un appel 1:1 normal
/// de tenir à leur réactivation. Tests de source : monter le notifier exige
/// Firebase, Supabase, WebRTC et CallKit.
void main() {
  String lire(String chemin) =>
      File(chemin).readAsStringSync().replaceAll('\r\n', '\n');
  String corps(String source, String signature) {
    final debut = source.indexOf(signature);
    expect(debut, isNot(-1), reason: signature);
    return source.substring(debut, source.indexOf('\n  }\n', debut));
  }

  const provider = 'lib/features/calls/presentation/providers/call_provider.dart';
  const natif = 'lib/core/services/native_call_service.dart';

  test('l\'écho d\'une fermeture demandée par l\'app ne raccroche pas', () {
    // Décrocher ferme la bannière d'arrivée ; le plugin renvoie alors
    // ACTION_CALL_ENDED pour CE même appel, qui était pris pour un
    // raccrochage de l'utilisateur.
    final source = lire(natif);
    expect(corps(source, 'Future<void> endCall() async {'),
        contains('_noterFermeture(_activeCallId)'));
    expect(corps(source, 'Future<void> endCallById(String callId) async {'),
        contains('_noterFermeture(callId)'));
    expect(source, contains('if (_fermeParLApp(callId)) return;'));
  });

  test('« terminé » depuis la bannière ne vise que l\'appel en cours', () {
    final source = lire(provider);
    final debut = source.indexOf('case NativeCallEvent.ended:');
    final bloc = source.substring(debut, source.indexOf('break;', debut));
    expect(bloc, contains('event.callId == enCours.id'));
  });

  test('refuser un autre appel ne touche pas l\'appel en cours', () {
    final c = corps(lire(provider), 'Future<bool> declineCall(String callId) async {');
    final autre = c.indexOf('enCours.id != callId');
    expect(autre, isNot(-1));
    expect(autre, lessThan(c.indexOf('    _resetState();')));
  });

  test('la fin distante passe par endCall, pas seulement WebRTC', () {
    final c = corps(
      lire('lib/features/calls/presentation/screens/call_screen.dart'),
      'void _handleRemoteEnd(String status) {',
    );
    expect(c, contains('.endCall(reason: status)'));
    expect(c, isNot(contains('webrtc.hangUp()')));
  });

  test('un seul message par appel', () {
    final c = corps(
      lire('lib/core/services/call_message_service.dart'),
      'Future<void> createCallMessage(',
    );
    expect(c, contains("'diasponiger.call-message/\$callId'"));
    expect(c, contains('ignoreDuplicates: true'));
    expect(c, isNot(contains('const Uuid().v4()')));
  });

  test('le nettoyage au démarrage épargne les appels vivants', () {
    final c = corps(
      lire('lib/features/calls/data/datasources/call_remote_datasource.dart'),
      'Future<int> cleanupUserStaleCalls(String userId) async {',
    );
    final garde = c.indexOf('_appelEncoreVivant(');
    expect(garde, isNot(-1));
    expect(garde, lessThan(c.indexOf("'app_restart_cleanup'")));
  });
}
