import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/events/domain/entities/event_audience.dart';
import 'package:diaspo_niger/features/events/presentation/widgets/event_audience_picker.dart';

/// « Les events créés dans une discussion, je ne peux pas choisir qui peut le
/// voir » (2026-09-12). Le seul choix était un interrupteur caché sous la
/// catégorie — et la base ne l'appliquait pas. La RLS est vérifiée en base
/// (migration 20260912233000, transaction annulée) ; ici, l'écran.
void main() {
  group('EventAudience', () {
    test('par défaut : la discussion quand il y en a une, public sinon', () {
      expect(
        EventAudience.parDefaut(depuisUneDiscussion: true).visibility,
        EventVisibility.discussion,
      );
      expect(
        EventAudience.parDefaut(depuisUneDiscussion: false).visibility,
        EventVisibility.public,
      );
    });

    test('groupes ou personnes sans destinataire : refusé', () {
      expect(
        const EventAudience(visibility: EventVisibility.groups).erreur,
        isNotNull,
      );
      expect(
        const EventAudience(visibility: EventVisibility.people).erreur,
        isNotNull,
      );
      expect(
        const EventAudience(
          visibility: EventVisibility.people,
          people: {'u1': 'Sim'},
        ).erreur,
        isNull,
      );
      expect(
        const EventAudience(visibility: EventVisibility.public).erreur,
        isNull,
      );
    });

    test('les noms envoyés à la base sont ceux de la contrainte SQL', () {
      // CHECK (visibility IN ('public','discussion','groups','people'))
      expect(
        EventVisibility.values.map((v) => v.name).toSet(),
        {'public', 'discussion', 'groups', 'people'},
      );
    });
  });

  Future<List<EventAudience>> pump(
    WidgetTester tester, {
    required bool depuisUneDiscussion,
    EventAudience? audience,
  }) async {
    final changements = <EventAudience>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventAudiencePicker(
              audience: audience ??
                  EventAudience.parDefaut(
                    depuisUneDiscussion: depuisUneDiscussion,
                  ),
              depuisUneDiscussion: depuisUneDiscussion,
              onChanged: changements.add,
            ),
          ),
        ),
      ),
    );
    return changements;
  }

  testWidgets('depuis une discussion : les quatre choix, visibles', (
    tester,
  ) async {
    await pump(tester, depuisUneDiscussion: true);
    expect(find.text('Cette discussion'), findsOneWidget);
    expect(find.text('Mes groupes'), findsOneWidget);
    expect(find.text('Personnes choisies'), findsOneWidget);
    expect(find.text('Tout le monde'), findsOneWidget);
  });

  testWidgets('hors discussion : pas de « Cette discussion »', (tester) async {
    await pump(tester, depuisUneDiscussion: false);
    expect(find.text('Cette discussion'), findsNothing);
    expect(find.text('Tout le monde'), findsOneWidget);
  });

  testWidgets('choisir « Tout le monde » rend public', (tester) async {
    final changements = await pump(tester, depuisUneDiscussion: true);
    await tester.tap(find.text('Tout le monde'));
    await tester.pump();
    expect(changements.single.visibility, EventVisibility.public);
  });

  testWidgets('les personnes choisies sont résumées sous le choix', (
    tester,
  ) async {
    await pump(
      tester,
      depuisUneDiscussion: true,
      audience: const EventAudience(
        visibility: EventVisibility.people,
        people: {'a': 'Sim', 'b': 'Aïcha', 'c': 'Moussa', 'd': 'Fati'},
      ),
    );
    expect(find.text('Sim, Aïcha et 2 autres'), findsOneWidget);
  });
}
