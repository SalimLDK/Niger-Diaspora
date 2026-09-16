import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le code garde le nom de l’erreur OpenMLS', () {
    expect(
      MlsConversationService.codeDiagnostic(Exception('AnyhowException(openmls:CreateCommitError)')),
      'openmls:CreateCommitError',
    );
  });

  test('un code simple reste inchangé', () {
    expect(MlsConversationService.codeDiagnostic(Exception('AnyhowException(aad_mismatch)')), 'aad_mismatch');
  });

  test('rien de lisible : inconnue', () {
    expect(MlsConversationService.codeDiagnostic(Exception('(42)')), 'inconnue');
  });
}
