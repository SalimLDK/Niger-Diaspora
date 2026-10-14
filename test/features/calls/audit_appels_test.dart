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

  test('appel de groupe : l\'hôte pose la liste des invités avant de s\'inscrire', () {
    final source = lire('lib/core/services/group_call_service.dart');
    for (final signature in [
      'Future<void> joinCall({',
      'Future<void> joinCallWithExistingStream({',
    ]) {
      final c = corps(source, signature);
      final pose = c.indexOf('_poserHoteEtInvites(');
      expect(pose, isNot(-1), reason: signature);
      expect(pose, lessThan(c.indexOf('await _registerParticipant(')),
          reason: signature);
    }
    expect(source, contains("for (final id in {...participantIds, hostId}) 'allowed/\$id': true"));
  });

  test('appel de groupe : un départ ne supprime plus l\'appel de tous', () {
    final c = corps(
      lire('lib/features/group_calls/presentation/providers/group_call_provider.dart'),
      'Future<void> leaveCall(',
    );
    final suppression = c.indexOf("_database.ref('group_calls/\$callId').remove()");
    expect(suppression, isNot(-1));
    final garde = c.lastIndexOf('isHost(currentUser.id)', suppression);
    expect(garde, isNot(-1), reason: 'suppression réservée à l\'hôte');
    final termine = c.indexOf("== 'ended'", garde);
    expect(termine, isNot(-1), reason: 'et à un appel terminé');
    expect(termine, lessThan(suppression));
  });

  test('la couche de chiffrement de groupe cassée est éteinte', () {
    final source = lire(
      'lib/features/group_calls/presentation/providers/group_call_provider.dart',
    );
    expect(source, contains('const bool chiffrementDeGroupeDisponible = false;'));
    expect(source, isNot(contains('isE2EEEnabled: true')));
    expect(source, isNot(contains('enableE2EE: true')));
  });

  test('app ouverte : pas de sonnerie d\'une personne bloquée, nom du profil', () {
    final c = corps(lire(provider), 'Future<void> _sonnerSiLegitime(CallEntity call) async {');
    final blocage = c.indexOf('checkBlockStatus(moi.id, call.callerId)');
    final profil = c.indexOf('userStreamProvider(call.callerId)');
    final sonnerie = c.indexOf('_showNativeCallUI(');
    expect(blocage, isNot(-1));
    expect(profil, isNot(-1));
    expect(blocage, lessThan(sonnerie));
    expect(profil, lessThan(sonnerie));
    expect(c, contains('callerName: nom,'));
  });
}
