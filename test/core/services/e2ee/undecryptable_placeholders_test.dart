import 'package:diaspo_niger/core/services/e2ee/undecryptable_placeholders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le premier message envoyé dans un groupe devenait illisible **par son
/// propre auteur** : la bulle optimiste affichait le texte clair, puis l'écho
/// temps réel arrivait avec `[🔐 E2EE — session requise]` et l'écrasait, parce
/// que le filtre ne connaissait que l'autre placeholder.
void main() {
  group('isUndecryptableContent', () {
    test('reconnaît les DEUX placeholders', () {
      // Celui des groupes — c'est lui qui manquait au filtre de l'écho.
      expect(isUndecryptableContent(kE2EESessionRequiredPlaceholder), isTrue);
      expect(isUndecryptableContent(kEncryptedMessagePlaceholder), isTrue);
    });

    test('le vide compte comme illisible', () {
      expect(isUndecryptableContent(''), isTrue);
    });

    test('un vrai message ne l\'est pas', () {
      expect(isUndecryptableContent('Bonjour @SalimL'), isFalse);
      // Un message qui PARLE du chiffrement n'est pas un placeholder.
      expect(isUndecryptableContent('regarde ce message chiffré'), isFalse);
    });
  });

  group('reconcileEchoContent', () {
    const local = 'Bonjour @SalimL test mention';

    test("garde le texte local quand l'écho est illisible", () {
      expect(
        reconcileEchoContent(
          local: local,
          incoming: kE2EESessionRequiredPlaceholder,
        ),
        local,
      );
      expect(
        reconcileEchoContent(
          local: local,
          incoming: kEncryptedMessagePlaceholder,
        ),
        local,
      );
      expect(reconcileEchoContent(local: local, incoming: ''), local);
    });

    test("adopte l'écho quand il porte un vrai contenu", () {
      // Un message reçu, ou notre message édité ailleurs : le serveur fait foi.
      expect(
        reconcileEchoContent(local: local, incoming: 'texte du serveur'),
        'texte du serveur',
      );
    });

    test("n'invente rien quand le local est vide lui aussi", () {
      // Une image sans légende : `content` est vide des deux côtés, et le
      // placeholder reste la seule chose à afficher.
      expect(
        reconcileEchoContent(
          local: '',
          incoming: kE2EESessionRequiredPlaceholder,
        ),
        kE2EESessionRequiredPlaceholder,
      );
    });
  });
}
