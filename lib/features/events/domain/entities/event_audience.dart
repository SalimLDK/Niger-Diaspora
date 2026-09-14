/// Qui peut voir un événement. Miroir de `events.visibility` — la RLS applique
/// cette valeur (migration `20260912233000`), l'écran ne fait que la choisir.
///
/// Dans tous les cas l'organisateur, les inscrits et la discussion d'origine
/// le voient : sa bulle y mène.
enum EventVisibility {
  /// Les participants de la discussion, ou les membres du groupe, d'origine.
  discussion,

  /// + les membres des groupes choisis.
  groups,

  /// + les personnes choisies (elles sont notifiées).
  people,

  /// Tout le monde, dans l'écran Événements.
  public,
}

/// Audience choisie à la création d'un événement.
class EventAudience {
  final EventVisibility visibility;

  /// Groupes choisis (id -> nom, pour l'affichage) — `groups` seulement.
  final Map<String, String> groups;

  /// Personnes choisies (id -> nom affiché) — `people` seulement.
  final Map<String, String> people;

  const EventAudience({
    required this.visibility,
    this.groups = const {},
    this.people = const {},
  });

  /// Visibilité par défaut : restreinte à la discussion quand il y en a une,
  /// publique sinon — c'est ce que faisaient les deux écrans jusqu'ici.
  factory EventAudience.parDefaut({required bool depuisUneDiscussion}) =>
      EventAudience(
        visibility: depuisUneDiscussion
            ? EventVisibility.discussion
            : EventVisibility.public,
      );

  EventAudience copyWith({
    EventVisibility? visibility,
    Map<String, String>? groups,
    Map<String, String>? people,
  }) => EventAudience(
    visibility: visibility ?? this.visibility,
    groups: groups ?? this.groups,
    people: people ?? this.people,
  );

  /// Un choix « groupes » ou « personnes » sans personne dedans n'a pas de
  /// sens : on refuse de publier plutôt que de restreindre à l'organisateur.
  String? get erreur => switch (visibility) {
    EventVisibility.groups when groups.isEmpty => 'Choisissez au moins un groupe.',
    EventVisibility.people when people.isEmpty =>
      'Choisissez au moins une personne.',
    _ => null,
  };

  /// Une audience qui demande des lignes `event_audience` en plus de la
  /// colonne `visibility`.
  bool get aDesDestinataires =>
      visibility == EventVisibility.groups ||
      visibility == EventVisibility.people;
}
