# design_v2 — bac à sable du nouveau design

Copie conforme des écrans d'entrée (onboarding, connexion, inscription,
configuration du profil) prise le 2026-08-03 depuis `lib/features/`.

Le but : retravailler le design sur ces copies sans risquer de casser
l'application qui tourne, puis basculer fichier par fichier quand le rendu
est bon.

## Pourquoi cette arborescence

`lib/design_v2/<feature>/presentation/{screens,widgets}` reproduit
**exactement la même profondeur** que `lib/features/<feature>/presentation/...`.
Conséquence : tous les imports `../../../../core/...`, `../../../../shared/...`
et `../widgets/...` sont identiques à l'original, et le swap se fait par
simple copie de fichier (voir plus bas).

Seule différence avec les originaux : les imports de **providers** pointent
vers les vrais providers de `lib/features/...` (ils ne sont pas dupliqués,
il n'y a donc qu'un seul état applicatif).

Les noms de classes sont volontairement **inchangés** (`LoginScreen`,
`ProfileConfigScreen`, ...) pour que la bascule soit un `cp`. Si tu veux
brancher une v2 dans le routeur en parallèle de la v1, utilise un alias
d'import (`import '...' as v2;` puis `v2.LoginScreen()`).

## Correspondance maquette → fichier

| Maquette | Écran | Fichier |
|---|---|---|
| 14a → 14e (1/5 à 5/5) | Onboarding : Bienvenue, Découvrez les membres, Rejoignez des groupes (= 13d), Participez aux événements, Restez connectés | `onboarding/presentation/screens/onboarding_intro_screen.dart` |
| — | Gabarit d'une page d'onboarding (illustration, titre, puces) | `onboarding/presentation/widgets/onboarding_page.dart` |
| 15a | Connexion — « Bon retour » | `auth/presentation/screens/login_screen.dart` |
| 15b | Inscription — « Créer un compte » | `auth/presentation/screens/register_screen.dart` |
| — | Gabarit commun auth (fond, titres, mentions bas de page) | `auth/presentation/widgets/auth_scaffold.dart` |
| — | Boutons auth, dont « Continuer avec Google » | `auth/presentation/widgets/auth_button.dart` |
| 16f | Configuration 1/4 — Faisons connaissance | `profile/presentation/screens/profile_config_screen.dart` (étape 0) |
| 15c | Configuration 2/4 — Votre localisation | idem (étape 1) |
| 15d | Configuration 3/4 — Vos centres d'intérêt | idem (étape 2) |
| 16g | Configuration 4/4 — Thème de l'application | idem (étape 3) |
| — | Champ `@handle` avec vérification de disponibilité | `profile/presentation/widgets/handle_field.dart` |

Les quatre étapes de configuration vivent dans **un seul fichier** de
~1250 lignes découpé par `_currentStep` : c'est là que se trouve l'essentiel
du travail de redesign.

## Bascule vers la production

Quand une v2 est validée, écraser l'original puis remettre les imports de
providers en relatif court :

```bash
cp lib/design_v2/auth/presentation/screens/login_screen.dart lib/features/auth/presentation/screens/login_screen.dart
```

Puis dans le fichier écrasé, remplacer
`../../../../features/auth/presentation/providers/auth_provider.dart`
par `../providers/auth_provider.dart` (même chose pour `onboarding_provider`
et `profile_provider`). Terminer par `flutter analyze`.

## Trousse commune : `kit/design_kit.dart`

Le vocabulaire visuel des maquettes vit à un seul endroit
(`lib/design_v2/kit/design_kit.dart`) : titre serif à point terracotta,
surtitre en chasse fixe, bloc d'illustration rayé, puces cochées, points
de page, barre d'étapes segmentée, bouton pilule à flèche, cartes sable à
interrupteurs, puces sélectionnables, listes déroulantes et champs.

`AuthTitle`, `AuthPrimaryButton` et `AuthSecondaryButton` ne sont plus que
des alias de leurs équivalents de la trousse : un seul endroit à toucher
pour changer un rayon ou une graisse.

Toutes les couleurs passent par `adaptive_colors.dart`. Les maquettes sont
en clair, mais les écrans restent lisibles en thème sombre — c'est
exactement le piège corrigé en `78b720e`, à ne pas réintroduire. Deux
exceptions assumées et commentées : les vignettes d'aperçu de thème
(étape 4/4), qui *représentent* le clair et le sombre et ne doivent donc
pas suivre le thème courant.

## Écarts connus avec les maquettes

- **Textes en dur.** Les écrans redessinés portent la copie française des
  maquettes directement dans le code. Les faire passer par `app_fr.arb` /
  `app_en.arb` est le dernier geste avant la bascule en production (et il
  faut la parité des métadonnées `@clé`, sinon `gen-l10n` échoue en
  silence).
- **Couleur d'accent « Teal ».** La maquette 16g propose trois pastilles,
  `AppThemeColor` n'en connaît que deux (`green`, `orange`). L'écran
  n'affiche donc que Orange et Vert ; ajouter Teal veut dire toucher
  `lib/core/theme/theme_provider.dart`, c'est-à-dire du code de
  production, hors périmètre de ce bac à sable.
- **Illustrations.** Les blocs rayés sont des emplacements, exactement
  comme dans les maquettes (« illustration — carte des membres »).
- **Découpage des étapes.** La configuration du profil passe de
  (localisation+identité / intérêts / notifications / thème) à
  (identité / localisation / intérêts + « Ce que vous recevrez » / thème),
  comme 16f → 15c → 15d → 16g. Aucune donnée sauvegardée ne change :
  `notificationsEnabled` reste vrai tant qu'une des deux catégories est
  active.
- **« Choisissez-en au moins deux »** est une invitation, pas un blocage :
  l'avancement n'est pas verrouillé sur le nombre de centres d'intérêt.

## À savoir

- Ce dossier est compilé par `flutter analyze` mais **n'est référencé par
  aucune route** : il n'a aucun effet sur l'application tant qu'on ne le
  branche pas.
- Ces copies incluent le travail en cours sur `login_screen`,
  `register_screen`, `auth_button` et le nouveau `auth_scaffold`
  (non committés au moment de la copie).
- Quand le dossier n'a plus d'utilité, il se supprime d'un bloc sans
  impact.
