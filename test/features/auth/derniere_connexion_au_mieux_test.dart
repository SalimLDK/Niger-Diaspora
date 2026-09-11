import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : `updateLastLogin` ne doit plus partir « nu » depuis le
/// fournisseur d'authentification.
///
/// Il était appelé quatre fois sans `await` ni `catch`, juste après la
/// connexion. Hors session — hors ligne, ou premier échange d'un compte neuf —
/// `_requireAuth()` levait « Session Supabase non établie », l'exception
/// remontait au gestionnaire global et Crashlytics la comptait comme un
/// plantage FATAL (4 événements, 2 utilisateurs) alors que l'app continuait.
///
/// Limite assumée : ce test lit la source. Monter `AuthNotifier` exigerait
/// Firebase, Supabase et une dizaine de fournisseurs pour vérifier une règle
/// de structure.
void main() {
  // Fins de ligne normalisées : sous Windows, git (core.autocrlf) peut rendre
  // le fichier en CRLF, et le découpage ci-dessous ne doit pas en dépendre.
  final source = File(
    'lib/features/auth/presentation/providers/auth_provider.dart',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  test('updateLastLogin n’est appelé qu’à un seul endroit', () {
    expect(
      RegExp(r'\.updateLastLogin\(').allMatches(source).length,
      1,
      reason: 'Tout appel doit passer par _marquerDerniereConnexion, qui '
          'attrape l’échec : un appel nu repartirait en plantage fatal.',
    );
  });

  test('cet endroit attrape l’échec', () {
    final debut = source.indexOf('void _marquerDerniereConnexion(');
    expect(debut, isNonNegative, reason: 'méthode au mieux introuvable');
    // Corps de la méthode : de sa première accolade à celle qui la ferme.
    final ouvrante = source.indexOf('{', debut);
    var profondeur = 0, fin = ouvrante;
    for (; fin < source.length; fin++) {
      if (source[fin] == '{') profondeur++;
      if (source[fin] == '}' && --profondeur == 0) break;
    }
    final corps = source.substring(ouvrante, fin);
    expect(corps, contains('.updateLastLogin('));
    expect(corps, contains('.catchError('));
  });
}
