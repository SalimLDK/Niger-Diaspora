import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/features/events/domain/entities/event_audience.dart';

/// L'audience d'un événement doit rester **relisible et modifiable**.
///
/// Jusqu'au 2026-09-14 elle ne l'était pas : `EventAudiencePicker` ne vivait
/// que dans l'écran de création, aucune ligne de l'app ne lisait
/// `event_audience`, et `EventEntity` ne porte toujours pas `visibility`. Une
/// audience se choisissait donc une fois, à la création, et plus jamais —
/// pas même par son organisateur.
///
/// Ce que ça a coûté : un événement `visibility = 'people'` sans aucune ligne
/// d'audience, trouvé en production, que **personne** ne pouvait réparer
/// depuis l'app. Ni son auteur, ni nous sans toucher la base.
///
/// Les deux règles figées ici sont celles dont dépendent l'écran de
/// modification et le bandeau d'avertissement de la fiche.
void main() {
  group('une audience restreinte sans destinataire est refusée', () {
    test('« personnes » sans personne', () {
      const audience = EventAudience(visibility: EventVisibility.people);
      expect(audience.erreur, 'Choisissez au moins une personne.');
    });

    test('« groupes » sans groupe', () {
      const audience = EventAudience(visibility: EventVisibility.groups);
      expect(audience.erreur, 'Choisissez au moins un groupe.');
    });

    test('« personnes » avec quelqu\'un : rien à signaler', () {
      const audience = EventAudience(
        visibility: EventVisibility.people,
        people: {'uid': 'Amadou'},
      );
      expect(audience.erreur, isNull);
    });

    test('« public » et « discussion » n\'attendent aucun destinataire', () {
      for (final v in [EventVisibility.public, EventVisibility.discussion]) {
        expect(EventAudience(visibility: v).erreur, isNull, reason: v.name);
      }
    });
  });

  group('aDesDestinataires — qui demande des lignes `event_audience`', () {
    test('groupes et personnes, oui', () {
      for (final v in [EventVisibility.groups, EventVisibility.people]) {
        expect(
          const EventAudience(visibility: EventVisibility.public)
              .copyWith(visibility: v)
              .aDesDestinataires,
          isTrue,
          reason: v.name,
        );
      }
    });

    test('public et discussion, non — la colonne `visibility` suffit', () {
      for (final v in [EventVisibility.public, EventVisibility.discussion]) {
        expect(
          EventAudience(visibility: v).aDesDestinataires,
          isFalse,
          reason: v.name,
        );
      }
    });
  });

  group('copyWith garde ce qu\'on ne lui donne pas', () {
    // Le sélecteur de l'écran de modification est pré-rempli puis modifié par
    // `copyWith` : une liste perdue en route re-créerait, en silence, l'état
    // exact qu'on cherche à empêcher — une audience vide.
    const initiale = EventAudience(
      visibility: EventVisibility.people,
      people: {'uid1': 'Amadou', 'uid2': 'Fatima'},
    );

    test('changer la visibilité ne vide pas les personnes', () {
      final apres = initiale.copyWith(visibility: EventVisibility.groups);
      expect(apres.people, initiale.people);
    });

    test('changer les personnes ne touche pas la visibilité', () {
      final apres = initiale.copyWith(people: const {'uid3': 'Ibrahim'});
      expect(apres.visibility, EventVisibility.people);
      expect(apres.people, {'uid3': 'Ibrahim'});
      expect(apres.erreur, isNull);
    });
  });
}
