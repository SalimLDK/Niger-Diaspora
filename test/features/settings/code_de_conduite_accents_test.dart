import 'package:diaspo_niger/core/services/support_service.dart';
import 'package:diaspo_niger/features/legal/presentation/providers/legal_provider.dart';
import 'package:diaspo_niger/features/settings/presentation/screens/code_of_conduct_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le texte de secours du code de conduite (affiché quand le document
/// Firestore ne se charge pas, hors ligne par exemple) était écrit sans un
/// seul accent : « diaspora nigerienne », « vous vous engagez a »,
/// « moderation »… Relevé le 2026-09-22.
void main() {
  // Formes fautives relevées dans l'ancien texte : aucune ne doit revenir.
  const sansAccent = [
    'nigerienne',
    'communaute',
    'engagez a ',
    'dignite',
    'evenement',
    'moderation',
    'regles',
    'privee',
    'donnees',
    'necessaire',
    'equipe',
    'probleme',
    'systeme',
    'identite',
    'qualite',
    'a caractere',
    'a des fins',
  ];

  testWidgets('le texte de secours français est accentué', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          codeOfConductProvider.overrideWith(
            (ref) => Future.error(Exception('hors ligne')),
          ),
          supportServiceProvider.overrideWith((ref) => SupportService()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CodeOfConductScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Le ListView est paresseux : on le fait défiler jusqu'au bout pour
    // construire chaque section.
    final textes = <String>{};
    for (var i = 0; i < 40; i++) {
      textes.addAll(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((d) => d.isNotEmpty),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    // Les adresses (« moderation@… ») ne sont pas du français à accentuer.
    final tout = textes.join('\n').replaceAll(RegExp(r'\S+@\S+'), '');

    expect(tout, contains('diaspora nigérienne'));
    expect(tout, contains('11. Contact'), reason: 'toutes les sections lues');
    for (final forme in sansAccent) {
      expect(tout.toLowerCase(), isNot(contains(forme)), reason: forme);
    }
  });
}
