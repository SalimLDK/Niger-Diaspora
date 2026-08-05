# Instructions du projet

## Suivi des tests appareil

`TESTS_APPAREIL_A_FAIRE.md` (racine du repo) recense tout ce qui n'a jamais
été vérifié sur un vrai téléphone — le rendu visuel, les gestes, les
permissions runtime (caméra/localisation), le thème sombre, et tout ce que
`flutter analyze`/`flutter test` ne peut pas couvrir.

**Chaque session doit le tenir à jour** :
- Si le code modifié pendant la session touche à l'un de ces points, ajouter
  une entrée (courte, avec le fichier concerné).
- Si un appareil est connecté et qu'un point de la liste est effectivement
  vérifié pendant la session (pas juste `flutter run` sans device réel),
  cocher l'entrée correspondante.

Ne pas attendre la fin de la tâche pour le faire : l'ajouter au fil de
l'eau, dans le même commit que le changement concerné si possible.

## Réglages : une seule source

Une ligne de réglage n'existe qu'au singulier — **sa brique visuelle est dans
`lib/core/theme/design_kit.dart`, sa valeur dans un provider**.

Un écran ne déclare ni widget de tuile, ni carte, ni filet de réglages, ni
champ `bool _…` qui recopie une valeur de provider.

Cette règle n'est pas une préférence de style : sa violation a déjà coûté trois
défauts, dont deux invisibles à la relecture.

- Trois écrans avaient chacun réécrit `_SettingsCard` / `_SettingsTile` /
  `_SettingsSwitchTile` / `_SettingsDivider`. Comme `DesignListCard` pose déjà
  ses filets, le Profil en affichait **trois superposés** entre chaque ligne —
  ça se lisait comme un trait épais, pas comme un bug.
- Les préférences du profil vivaient en copies `bool` locales rafraîchies par
  un `ref.listen` qui ne se déclenchait jamais. **Toucher une bascule remettait
  les trois autres à `true`** par-dessus les vraies valeurs serveur.
- L'interrupteur push n'écrivait que la préférence locale, qui décide de
  l'*affichage* ; la colonne serveur, qui décide de l'*envoi*, restait à `true`.

Vérifié par `test/core/theme/reglages_sans_doublon_test.dart` (structure) et
`test/features/profile/profile_preferences_provider_test.dart` (comportement).
Le premier porte une liste d'exceptions nommées : elle ne doit que rétrécir.
