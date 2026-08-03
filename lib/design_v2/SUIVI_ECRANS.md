# Suivi des écrans — reprise du design

Un écran par ligne. À tenir à jour **dans le même commit** que le changement,
comme `TESTS_APPAREIL_A_FAIRE.md`.

Légende de l'état :

- **fait** — le nouveau design est appliqué sur la copie et `flutter analyze
  lib/design_v2` passe
- **copié** — le fichier est dans `design_v2` mais porte encore l'ancien
  habillage
- **prod** — le nouveau design est déjà dans `lib/features`, aucune copie
  n'a été faite (la copier n'apporterait rien)
- **à basculer** — validé sur la copie, prêt à écraser l'original

## Onboarding et entrée dans l'app

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 14a→14e | Onboarding 1/5 → 5/5 | `onboarding/…/onboarding_intro_screen.dart` | fait |
| — | Gabarit de page d'onboarding | `onboarding/…/widgets/onboarding_page.dart` | fait |
| 15a | Connexion | `auth/…/login_screen.dart` | fait |
| 15b | Inscription | `auth/…/register_screen.dart` | fait |
| — | Gabarit auth + boutons | `auth/…/widgets/auth_scaffold.dart`, `auth_button.dart` | fait |

## Configuration du profil

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 16f | Étape 1/4 — Faisons connaissance | `profile/…/profile_config_screen.dart` | fait |
| 15c | Étape 2/4 — Votre localisation | idem | fait |
| 15d | Étape 3/4 — Centres d'intérêt | idem | fait |
| 16g | Étape 4/4 — Thème | idem | fait |
| — | Champ `@handle` | `profile/…/widgets/handle_field.dart` | fait |

## Onglets principaux

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 8a | Accueil | `home/…/home_screen.dart` | fait |
| 8b, 8c | Carte (+ sans localisation) | — | prod (`map_screen.dart:2642`) |
| 9a | Messagerie — liste | `messages/…/messages_screen.dart` | fait |
| 9e | Messagerie — état vide | idem | fait |
| — | Tuile de conversation | `messages/…/widgets/conversation_item.dart` | fait |
| 9c | Groupes — mes groupes / découvrir | `groups/…/groups_screen.dart` | fait |
| 9f | Groupes — état vide | idem | fait |
| 9d | Fiche de groupe | `groups/…/group_detail_screen.dart` | fait |

## Profil, réglages et transverses

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 10a | Mon profil | `profile/…/profile_screen.dart` | fait |
| 10c | Profil d'un membre (vue publique) | `profile/…/profile_view_screen.dart` | fait |
| 10b | Réglages | `settings/…/settings_screen.dart` | fait |
| 12c | Notifications | `notifications/…/notifications_screen.dart` | fait |
| 12d | Recherche | `search/…/search_screen.dart` | fait |
| 11f | Profil incomplet — invitation à compléter | `profile/…/profile_screen.dart` | fait (bandeau `_buildCompletionBanner`) |

## Variantes nocturnes

Les maquettes 11a→11f sont les versions sombres des écrans ci-dessus, pas des
écrans distincts. Rien à implémenter séparément : la trousse passe par
`adaptive_colors.dart`, donc chaque écran fait a déjà sa version sombre.
Ce qui reste à faire est de **les regarder sur un vrai téléphone** — c'est
suivi dans `TESTS_APPAREIL_A_FAIRE.md`, pas ici.

## Localisation

Terminée. 140 clés ajoutées à `app_fr.arb` (template) et `app_en.arb`,
métadonnées `@clé` à parité des deux côtés — contrôlé automatiquement :
**0 écart de clé, 0 écart de `@clé`**.

Il reste 17 littéraux dans `design_v2`, tous délibérés :

| Ce que c'est | Où | Pourquoi ça reste |
|---|---|---|
| Séparateurs `' · '` et `' → '` | partout | ponctuation, pas du texte |
| Compositions `'$date · ${e.location}'` | accueil, groupes, profil, recherche | assemblage de valeurs déjà localisées |
| Sentinelles `_kProfileMissing`, `_kNotSignedIn` | config profil | servent à **reconnaître** le cas dans `e.toString()` : les traduire casserait la détection |
| Valeurs de centres d'intérêt (`'Santé'`…) | config profil | c'est ce que le profil **enregistre en base** ; seul le libellé affiché passe par `_interestLabel` |

Deux corrections de fond faites au passage :

- Les **mois abrégés** de l'accueil (`'fév'`, `'aoû'`, `'déc'`…) étaient une
  table française codée en dur. Ils passent par `DateFormat('d MMM', locale)`
  et suivent donc la langue.
- Les **énumérations** (« a, b et c ») ne concaténaient plus avec un `' et '`
  en dur : la liaison finale vient de l'ARB, elle n'est pas la même partout.

## Troisième vague de maquettes (fil, discussion, Mon espace, services)

Même constat que la deuxième vague : la **structure** de ces maquettes est
déjà en production (les fichiers citent `§5a`, `§5b`, `§4a`, `§7d`, `§12b`,
`§13a`, `§17a`, `§13c`…). Ce qui manque est le **langage visuel** — aucun
titre serif nulle part, et des dégradés qui subsistent dans la discussion,
le composer et la carte.

| Maquettes | Écran | Fichier de production | Taille | État |
|---|---|---|---|---|
| 3a, 4g, 6a | Le fil | `feed/…/feed_screen.dart` | 966 l. | **prod** — système propre |
| 5a, 5f | Mon espace | `feed/…/mon_espace_screen.dart` | 363 l. | **prod** — système propre |
| 5b, 5g, 6d | Mes publications | `feed/…/my_posts_screen.dart` | 180 l. | **prod** — système propre |
| 5c, 5e, 6e | Enregistrés | `feed/…/saved_posts_screen.dart` | 336 l. | **prod** — système propre |
| 5d, 5h, 6f | Mon réseau | `feed/…/follows_screen.dart` | 190 l. | **prod** — système propre |
| 3b, 3c, 4a, 6b | Discussion | `messages/…/conversation_screen.dart` | 3444 l. | à faire |
| 4c→4f, 6c | Composer et enregistrement vocal | `messages/…/widgets/message_input.dart` | 2188 l. | à faire |
| 7d, 7e | Carte : couches, bascule Carte/Liste | `map/…/map_screen.dart` | 3560 l. | à faire |
| 12a, 16c, 16i | Transferts | `transfers/…` (pas d'écran unique) | — | à cadrer |
| 12b, 16a, 16b, 16h | Boutique | `marketplace/…/marketplace_screen.dart` | 557 l. | à faire |
| 13a, 16e | Événements | `events/…/events_screen.dart` | 1082 l. | à faire |
| 13b, 16d, 17a, 17b | Ambassades | `embassies/…/embassies_screen.dart` | 594 l. | à faire |
| 13c | Appels | `calls/…/call_history_screen.dart` | 748 l. | à faire |
| 17c, 17d, 18a→18d | Annuaire Business | `businesses/…/businesses_screen.dart` | 407 l. | à faire |

### La famille « fil » a son propre système — ne pas lui appliquer la trousse

`lib/features/feed/presentation/theme/` définit `FeedTokens` et `FeedText`,
qui implémentent **exactement** les deux systèmes des maquettes :

- `nocturne` — sombre, accent indigo `#9184D9`, rayons serrés, titrage Inter.
  C'est littéralement ce que montrent 6a→6f.
- `organic` — clair, accent terracotta, rayons généreux, titrage **Caprasimo**.
  C'est le gros display des maquettes 3a, 5a→5h.

Ces écrans sont donc **déjà à jour**. Leur appliquer `design_kit`
(Playfair Display, jetons `adaptive_colors`) serait une régression : ça
écraserait la bascule Organic/Nocturne que les maquettes elles-mêmes
montrent. Aucune copie n'a été faite pour eux.

Ordre d'attaque retenu, la famille « fil » étant hors périmètre :
services d'abord (annuaire 407 l., boutique 557 l., ambassades 594 l.,
appels 748 l., événements 1082 l.), puis discussion, composer et carte —
les trois plus gros fichiers du dépôt, 9 200 lignes à eux seuls.

## Écrans hors maquettes

Aucune maquette fournie à ce jour pour : conversation (fil de discussion),
fil/publications, événements, transferts, boutique, ambassades, salons audio,
podcasts, back-office. Ces écrans gardent leur habillage actuel.
