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

## Bascule vers la production — famille 1 : onboarding + auth (2026-08-03)

**Faite.** Première des familles prévues. La trousse `design_kit.dart` rejoint
`lib/core/theme/` : elle n'appartient à aucune feature, et la laisser sous
`design_v2/` aurait fait dépendre la production du bac à sable.

| Fichier | Contenu perdu par la production | Verdict |
|---|---|---|
| `auth/…/login_screen.dart` | 0 | copie = superset |
| `auth/…/register_screen.dart` | 0 | copie = superset |
| `auth/…/widgets/auth_button.dart` | 0 | copie = superset |
| `auth/…/widgets/auth_scaffold.dart` | 82 | ancienne implémentation inline d'`AuthTitle`, remplacée par la délégation au kit |
| `onboarding/…/onboarding_intro_screen.dart` | 121 | ancienne copie sans accents (« nigerienne ») et `AppColors` figés |
| `onboarding/…/widgets/onboarding_page.dart` | 70 | ancien `OnboardingPageData` (icône + couleur) |

**Les trois écarts ont été lus avant écrasement**, pas supposés : dans les
trois cas les lignes perdues sont bien le code que la refonte remplace, pas
un correctif fait en production depuis la copie. C'est la seule vérification
qui compte, et aucune mesure automatique ne la remplace — `diff` ne
distingue pas « remplacé » de « perdu ».

Imports remis en relatif court (`../providers/`), kit pointé sur
`../../../../core/theme/design_kit.dart`. `flutter analyze` propre sur tout
le dépôt.

⚠️ **`lib/design_v2/kit/` reste en place** : les autres copies non encore
basculées en dépendent. À supprimer quand la dernière famille sera passée,
sinon la trousse existera en double.

⚠️ **Rien n'est vérifié sur appareil.** C'est la première fois que la refonte
est réellement affichable dans l'app — `TESTS_APPAREIL_A_FAIRE.md` liste quoi
regarder, en tête le thème sombre et `font_scale = 1.1`.

## Bascule — la carte des risques, à consulter avant chaque famille

Le danger de la bascule n'est pas technique, il est chronologique : la copie
a été prise en `8f8db62`, et **la production a continué d'avancer depuis**.
Écraser un fichier dont la production a bougé après la copie fait perdre ce
travail-là, silencieusement.

La liste se recalcule en une commande — ne pas la recopier de mémoire, elle
change à chaque commit :

```bash
git log --oneline 8f8db62..HEAD --name-only | grep '^lib/features/' | sort -u
```

Au 2026-08-03, les copies dont la production a bougé depuis, donc **à ne pas
écraser sans lire le diff ligne à ligne** :

`call_screen`, `home_screen`, `home_screen_widgets`, `map_screen`,
`message_bubble`, `notification_settings_screen`, `edit_profile_screen`,
`devices_screen`, `security_backup_screen`, `settings_screen`,
`send_money_screen`.

Tous les autres sont sûrs au sens strict : leur production est restée à
l'identique depuis la copie, donc la copie est la production **plus** la
refonte.

⚠️ `map_screen` est le cas le plus délicat : la copie porte le §7e (bascule
Carte/Liste) que la production n'a pas, et la production porte deux passes
de couleur que la copie n'a pas. Ce fichier se **fusionne**, il ne se copie
pas.

## Bascule vers la production — famille 2 : les services (2026-08-03)

**Faite.** Onze écrans : annuaire Business (5), ambassades (4),
événements (2). Choisis parce qu'ils sont hors de la carte des risques
ci-dessus — aucun de leurs fichiers de production n'avait bougé depuis la
copie — et parce qu'une session parallèle travaillait au même moment sur la
famille du profil.

Vérification avant écrasement, la même qu'en famille 1 mais outillée :
comparaison des **membres déclarés** de chaque côté (méthodes, widgets,
getters). Un membre présent en production et absent de la copie est le
signe d'un correctif fait depuis la copie ; il y en a eu **zéro sur les
onze fichiers**. Les copies sont des supersets.

Imports remis à l'idiome de production — `../providers/`, `../../domain/`,
`../../../<autre feature>/`, kit sur `../../../../core/theme/design_kit.dart`.
`flutter analyze` sur les trois features : **No issues found**.

⚠️ **Ce que cette vérification ne couvre pas.** Comparer les membres attrape
une méthode supprimée, pas une ligne changée à l'intérieur d'une méthode. Sur
ces onze fichiers c'est suffisant parce que la production n'a reçu **aucun
commit** depuis la copie — c'est cette condition qui fait la sûreté, pas la
comparaison. Sur un fichier de la carte des risques, elle ne suffirait pas.

## Bascule vers la production — famille 3 : boutique, support, transferts, appels (2026-08-03)

**Faite.** Onze écrans de plus, choisis au même critère : boutique (3),
support (4 maquettes sur 3 fichiers), transferts hors envoi (2), historique
d'appels, appel de groupe, création de podcast. Zéro membre perdu, zéro
commit de production depuis la copie.

`send_money_screen` est **volontairement laissé de côté** alors qu'il est de
la même feature : sa production a reçu deux commits depuis la copie
(`f833a07`, l'accent du compte dans le tunnel d'envoi). Il se fusionne, il
ne se copie pas.

`group_call_screen` ne figure pas dans le commit : une fois les imports
réécrits il est redevenu identique à la production — son seul écart était le
chemin des imports. Même cas qu'`embassy_detail_screen` en famille 2.

`flutter analyze` sur les six features : **No issues found**.

## Bascule vers la production — famille 4 : messagerie, groupes, recherche, profil (2026-08-03)

**Faite.** Onze fichiers : messagerie (liste, discussion, tuile, composer,
bulle de message, bulle audio), groupes (2), recherche, notifications, mon
profil. `flutter analyze` : **No issues found**.

### Trois membres présents en production et absents des copies

Contrairement aux familles 2 et 3, la comparaison des membres a **remonté
quelque chose**. Les trois cas ont été lus, et les trois sont des
suppressions voulues par la refonte, pas des correctifs perdus :

| Fichier | Membre | Ce que c'était |
|---|---|---|
| `messages_screen` | `_buildGradientHeader`, `_buildHeaderDecorations`, `circle`, `sectionHeader` | l'en-tête dégradé et ses cercles décoratifs. La copie n'a **ni `SliverAppBar` ni `LinearGradient`** — §9a supprime l'en-tête |
| `profile_screen` | `_buildCollapsedHeaderTitle` | le titre (avatar + nom) qui apparaissait dans la barre repliée. La copie n'a plus de `SliverAppBar` du tout : §10a est un écran plat, le membre n'aurait plus rien à servir |
| `search_screen` | `_getTitle` | le titre d'écran de l'`AppBar`. §12d fait du **champ de recherche l'en-tête** ; la spécialisation contextuelle (« Rechercher un groupe ») n'est pas perdue, elle vit dans `_getHintText`, localisée |

C'est le cas que la comparaison automatique est faite pour attraper, et il
montre aussi sa limite : elle signale, elle ne tranche pas. Les trois
verdicts viennent de la lecture du code.

### `message_bubble` sort de la carte des risques

Il y figurait — deux commits de production depuis la copie — mais
l'inspection montre que **la copie porte déjà les deux** :

- `2e7890d` (mode données réduites à la réception) : `DataSaverGate` présent
  des deux côtés, comme la section « Mode données réduites » l'annonçait ;
- `e3e47a3` (bordure de bulle reçue passée au jeton) : zéro `_kRecvBorder`
  dans la copie, `context.borderColor` à la place.

Ce sont les deux seuls commits de production depuis la copie, donc la copie
est bien un superset. Basculé avec les autres — laisser les bulles en
production pendant que l'écran et le composer passent en v2 aurait donné une
discussion à moitié refaite.

**La leçon vaut pour les fichiers restants** : la carte des risques dit
« à vérifier », pas « à ne pas toucher ». Un fichier peut y figurer et être
sûr, si les commits de production ont été reportés dans la copie au fil de
l'eau.

## Bascule — famille 2 : profil et configuration (2026-08-03)

**4 fichiers sur 5.** `profile_config_screen`, `profile_view_screen`,
`edit_profile_screen` et `handle_field` sont passés en production.

⛔ **`profile_screen.dart` est exclu, et il ne faut pas le basculer en
l'état.** La production porte un repli d'en-tête au défilement —
`_headerCollapsed`, un `NotificationListener<ScrollNotification>` et
`_buildCollapsedHeaderTitle`, soit 7 occurrences. La copie n'en a **aucune** :
elle est plus ancienne que ce travail. L'écraser supprimerait une
fonctionnalité qui marche.

Méthode qui l'a détecté, à réutiliser pour les familles suivantes : extraire
les identifiants des lignes que la production perdrait, puis vérifier s'ils
existent **ailleurs** dans la copie. Un identifiant présent ailleurs = du
code réécrit, sans risque. Un identifiant absent partout = du travail fait en
production depuis la copie, qui serait supprimé. C'est ce test, et non `diff`,
qui distingue « remplacé » de « perdu ».

Résultat du test sur cette famille :

| Fichier | Identifiants absents | Lecture |
|---|---|---|
| `profile_config_screen` | `_ThemeModeOption`, `_ThemeColorOption`, `_buildNotificationsStep`, 3 dropdowns | l'ancienne version en 4 étapes, remplacée par la refonte — voulu |
| `profile_view_screen` | `_buildLocationString`, `_buildOriginString`, 2 clés | anciens helpers de localisation, remplacés par les puces §10c — voulu |
| `edit_profile_screen` | `l10n.editProfile` | titre changé — voulu |
| `handle_field` | aucun | réécriture pure |
| `profile_screen` | **`_headerCollapsed`, `NotificationListener`, `_buildCollapsedHeaderTitle`** | ⛔ **régression** |

Pour débloquer `profile_screen` : reporter le repli d'en-tête dans la copie,
refaire le test, puis basculer.

## Bascule — famille 5 et solde de la carte des risques (2026-08-03)

En appliquant la leçon de `message_bubble` aux neuf fichiers restants de la
carte des risques, il apparaît qu'ils ne sont pas du tout dans la même
situation. Le critère n'est pas « la production a bougé » mais **dans quel
sens** :

| Fichier | Commit(s) de production depuis la copie | Appliqué à la copie aussi ? | Verdict |
|---|---|---|---|
| `home_screen`, `home_screen_widgets` | `e6172b3` squelette à l'élargissement | oui (le correctif est né dans la copie) | **basculés** |
| `send_money_screen` | `f833a07`, `e3e47a3` | oui, les deux | **basculé** |
| `call_screen` | `0ce170a` — **§23a fait en production** | non | ⛔ **ne pas basculer** |
| `notification_settings_screen` | `642761f` — **§20d fait en production** | non | ⛔ **ne pas basculer** |
| `devices_screen`, `security_backup_screen` | `13861b7` — **§20b/§20c faits en production** | non | ⛔ **ne pas basculer** |
| `settings_screen` | `0d90246` entrée debug vers `/design-v2` | non | ⏸ **à la fin** — voir ci-dessous |
| `map_screen` | `94d721c` (copie aussi), `bdcd795` (prod seule) | partiellement | ⚠ **fusion** |

### Quatre copies sont périmées, pas en attente

`call_screen`, `notification_settings_screen`, `devices_screen` et
`security_backup_screen` portent des maquettes qui ont ensuite été
implémentées **directement en production** (§23a, §20d, §20b, §20c). Leur
copie est antérieure à ce travail : la basculer serait une régression pure.

Elles ne se basculent pas — elles se **suppriment** avec le reste de
`design_v2`. À ne pas confondre avec « reste à faire » dans un futur
inventaire : le travail est fait, il est en production.

### `settings_screen` attend la fin, exprès

Sa copie est antérieure à `0d90246`, qui a ajouté l'entrée debug
« Réglages → Refonte → Galerie design v2 ». La basculer maintenant
supprimerait l'accès à la galerie **alors qu'on en a encore besoin** pour
regarder ce qui n'est pas basculé (carte, profil). Elle passe en dernier,
quand `design_v2/` disparaît et que l'entrée n'a plus d'objet.

### `map_screen` reste le seul vrai cas bidirectionnel

La copie a le §7e (bascule Carte/Liste, badge tuiles allégées, plein écran,
tri) que la production n'a pas. La production a `bdcd795` (second jeu de
blancs figés, dégradé de la légende) que la copie n'a pas. Aucune des deux
n'est un superset : ce fichier se fusionne à la main, hunk par hunk.

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
| 3a, 4g, 6a | Le fil | `feed/…/feed_screen.dart` | 966 l. | **prod** — fuites de fonte corrigées |
| 5a, 5f | Mon espace | `feed/…/mon_espace_screen.dart` | 363 l. | **prod** — fuites de fonte corrigées |
| 5b, 5g, 6d | Mes publications | `feed/…/my_posts_screen.dart` | 180 l. | **prod** — système propre |
| 5c, 5e, 6e | Enregistrés | `feed/…/saved_posts_screen.dart` | 336 l. | **prod** — système propre |
| 5d, 5h, 6f | Mon réseau | `feed/…/follows_screen.dart` | 190 l. | **prod** — système propre |
| 3b, 3c, 4a, 6b | Discussion | `messages/…/conversation_screen.dart` | 3444 l. | fait (en-tête) — bulles à part, voir ci-dessous |
| 4c→4f, 6c | Composer et enregistrement vocal | `messages/…/widgets/message_input.dart` | 2188 l. | fait |
| 7d | Carte : calques | `map/…/map_screen.dart` | 3549 l. | fait |
| 7e | Carte : bascule Carte/Liste | idem | — | fait dans `design_v2/map/` — **à reporter en prod**, voir « Carte — §7d faite, §7e à faire » |
| 12a, 16c, 16i | Transferts : envoi, accueil, historique | `transfers/…` (3 écrans) | 1975 l. | fait (partiel — voir ci-dessous) |
| 12b, 16a, 16b, 16h | Boutique, détail produit, panier | `marketplace/…` (3 écrans) | 1741 l. | fait |
| 13a, 16e | Événements, création | `events/…` (2 écrans) | 2136 l. | **basculé** (famille 2) |
| 13b, 16d, 17a, 17b | Ambassades, fiche, demande, contact | `embassies/…` (4 écrans) | 2420 l. | **basculé** (famille 2) |
| 13c | Appels | `calls/…/call_history_screen.dart` | 748 l. | fait |
| 17c, 17d, 18a→18d | Annuaire, fiche, création, avis, mise en avant | `businesses/…` (5 écrans) | 3018 l. | **basculé** (famille 2) |

### Discussion et composer — ce qui est fait, ce qui ne l'est pas

Les deux fichiers sont copiés dans `design_v2` et **purgés de leurs
dégradés** : 7 dans la discussion, 6 dans le composer, tous à zéro.

| Ce qui a changé | Avant | Après |
|---|---|---|
| Séparateur de jour | filet en fondu + pastille dégradée + bordure + ombre portée | filet plein, pastille plate — un repère de date n'a pas à se détacher comme un bouton |
| Séparateur « non lus » | même empilement, en terracotta | même gabarit, aplat terracotta — c'est le seul repère du fil qui doit accrocher l'œil |
| Illustration d'état vide | cercle dégradé primaire → secondaire | aplat teinté |
| Bouton d'envoi | 4 dégradés selon l'état | 4 aplats, **couleurs signifiantes conservées** : rouge annulation/limite, terracotta enregistrement, bleu E2EE envoi, vert vocal |

Les deux séparateurs étaient deux copies du même empilement : ils passent par
un gabarit commun, `_buildThreadSeparator`.

⚠️ **Ce n'est pas « la maquette appliquée ».** Je n'avais pas les visuels
3b, 3c, 4a, 6b, 4c→4f et 6c sous les yeux en faisant ce passage : ce qui est
fait, c'est le **langage visuel** que le suivi identifiait comme manquant
(« des dégradés qui subsistent dans la discussion, le composer »). Tout ce
qui relève de la mise en page propre à ces maquettes — disposition des
bulles, états d'enregistrement vocal — reste à faire et demande de
reprendre les images.

#### Les images sont arrivées : ce qu'elles ont confirmé et corrigé

**Les bulles étaient déjà conformes.** 3b/3c exigent « vous = vert
`#1B5E32`, reçus = surface blanche bordée » et « le terracotta ne sert plus
qu'aux repères, jamais aux bulles ». Le code portait déjà exactement ces
valeurs (`_kSentBubbleLight = 0xFF1B5E32`, `_kRecvBubbleLight = 0xFFFFFFFF`).
Rien à faire — vérifié, pas supposé.

**Les états vocaux, eux, ne l'étaient pas.** 4d demande que « les deux
gestes possibles soient écrits sous la barre au lieu d'être devinés », et
4e qu'il n'y ait « aucune suppression silencieuse — l'état est lisible
avant de lâcher ». Or les deux états affichaient le **même mot**,
« Annuler » : impossible de savoir si on informait d'un geste possible ou
si on annonçait une suppression imminente.

| État | Avant | Après (maquette) |
|---|---|---|
| Enregistrement en cours (§4d) | « Annuler » | « Glisser ‹ pour annuler · ↑ pour verrouiller » |
| Seuil franchi (§4e) | « Annuler » | « Relâcher pour annuler » + « L'enregistrement sera supprimé », corbeille au lieu de la flèche |
| Verrouillé (§4f) | badge seul | badge + « Mains libres — vous pouvez lâcher l'écran » |

Cinq clés ARB ajoutées (fr + en, `@clé` à parité). Deux `Colors.red` de
plus passent à `context.errorColor`.

#### Les trois remaniements de §4c — vérifiés un par un

Après vérification, **deux des trois étaient déjà en place**, et le
troisième ne tenait qu'à des couleurs. Le détail, parce que « c'est déjà
fait » ne se croit pas sur parole :

| §4c | Attendu | Constat |
|---|---|---|
| 1 · Le « + » sort du champ | cible de 40 px hors du champ | déjà fait — `_buildPlusButton`, 42 px, pastille ronde, glyphe qui pivote en croix |
| 2 · Feuille « + » en grille ancrée | six tuiles, panneau ancré et non modal | déjà fait — `_showAttachPanel` + `_buildAttachPanel`, les six tuiles y sont (l'ancienne modale reste en repli sur appui long) |
| 3 · Panneau unique, récents en premier | trois onglets Emojis/GIF/Stickers | déjà fait — `EmojiStickerPicker`, et `emoji_picker_flutter` ouvre sur `Category.RECENT` avec `RecentTabBehavior.RECENT` **par défaut** : les récents sont donc bien en tête sans rien coder |

**Ce qui n'allait pas, en revanche : les couleurs des tuiles.** La maquette
impose deux familles — « terracotta pour les médias, vert pour ce qui crée
un objet partagé ». Le code en portait **six** sans rapport : vert pour la
caméra, terracotta pour la galerie, bleu pour les documents, vert pour la
position, violet `#6B5CE0` pour le sondage, teal pour l'événement.

Six couleurs ne disent rien : personne n'apprend un code à six entrées vu
une seconde. Deux familles, si — ce que j'envoie depuis mon téléphone
(caméra, galerie, document → terracotta) contre ce que je crée pour la
conversation (position, sondage, événement → vert).

Au passage, `'Sondage'` et `'Événement'` étaient codés en dur : le premier
a désormais sa clé `pollLabel`, le second réutilise `eventLabel` qui
existait déjà.

#### Feuille d'actions sur un message (§27a) — fait

La maquette 27a, elle, était disponible. Elle pose une **rangée de
réactions rapides** en tête de feuille : cinq émojis atteignables d'un
geste (👍 ❤️ 😂 🙏 😮) plus un « + » qui ouvre le sélecteur complet.
Avant, réagir demandait trois gestes — ouvrir la feuille, toucher
« Réagir », choisir dans un second écran.

Deux décisions à connaître :

- **Aucune action n'a été retirée.** 27a n'en montre que cinq (Répondre,
  Copier, Transférer, Favoris, Supprimer) là où la feuille en a treize.
  Faire disparaître épingler, signaler, modifier, télécharger et partager
  serait une régression fonctionnelle déguisée en choix de design. Si le
  raccourcissement est voulu, c'est une décision produit à prendre
  explicitement — et il faudra dire où vont les actions retirées.
- **La pastille ne prétend pas savoir quelle réaction est la vôtre.**
  `MessageEntity.reactions` est une `List<String>` d'émojis sans auteur
  (le fichier porte encore le commentaire « ready for future use when
  MessageEntity supports reactions »). La mise en avant dit donc « cette
  réaction est présente sur le message », ce qui est vrai, et non « c'est
  la mienne », ce qui serait inventé. Rattacher l'auteur demande de
  changer le modèle et la table.

Le rouge de la ligne « Supprimer » passe de `Colors.red` à
`context.errorColor` au passage.

### Carte — ce qui est fait et ce qui bloque (2026-08-03)

Passe visuelle faite directement en production, aucune copie `design_v2` :
deux avatars de repli étaient peints en dégradé avec ombre portée, et cinq
libellés posés sur l'accent étaient figés sur `AppColors.white`. En thème
sombre l'accent s'éclaircit, donc le texte dessus doit s'assombrir :
`context.onPrimaryColor` fait cette bascule, pas un blanc constant.

**Second passage (même jour).** Il restait un jeu distinct du précédent :
cinq libellés figés non pas sur `AppColors.white` mais sur `Colors.white`,
eux aussi posés sur l'accent — trois `foregroundColor` de bouton et deux
puces sélectionnées (rayon, filtre). Un `grep AppColors.white` les ratait
tous. Ils passent à `context.onPrimaryColor`.

La légende gardait par ailleurs le dernier dégradé de la feature : sa
pastille de couleur était peinte en dégradé avec ombre colorée. Elle devient
un aplat — une légende sert à rapprocher une couleur d'un libellé, la nuancer
brouille précisément ce rapprochement. Le liseré blanc reste, il détache la
pastille du fond cartographique. La feature entière est maintenant à zéro
dégradé.

Restent volontairement blancs : les remplissages de `CustomPainter` et le
texte du badge « vérifié », posés sur des fonds de couleur fixes.

Non touché volontairement : les couleurs des épingles et des cercles peints
sur le fond cartographique (`AppColors.primary`, `.secondary`, `.success`
dans les `CustomPainter`). Elles se lisent sur la carte Google, pas sur le
fond de l'application, et n'ont donc pas à suivre le thème.

**§7d est déjà implémenté** — le bouton « calques » et sa feuille de bascule
(membres / commerces / ambassades) existent depuis une session précédente,
le fichier cite `§7d` à la ligne 2512.

⚠️ **§7e est bloqué, pas oublié.** Il n'existe aucune bascule Carte/Liste
dans le fichier : ni `viewMode`, ni `_isListView`, rien. La feuille glissante
du bas affiche bien les membres proches, mais ce n'est pas la bascule que
le nom de la maquette décrit. Construire ce composant sans la maquette 7e
reviendrait à inventer une disposition — segmenté en en-tête ? plein écran ?
conservation du filtre courant ? Il faut la maquette avant d'écrire la
moindre ligne.

### Composer : la pilule « MAINTENIR » est écartée, pas oubliée

Les maquettes 3b et 4a montrent le bouton vocal sous forme de **pilule verte
portant le mot « MAINTENIR »**. Le code garde un bouton **rond sans
libellé** : c'est un choix, confirmé le 2026-08-03.

Je l'avais implémentée avant que la décision soit connue, puis annulée :
bouton rond restauré, clé ARB `composerHoldToRecord` retirée des deux
fichiers, parité vérifiée (0 écart de clé, 0 écart de `@clé`).

**Ne pas la ré-ajouter** en la prenant pour un écart au design. Si la
question revient, l'argument en sa faveur était que le libellé nomme le
geste — une icône de micro seule laisse croire à un appui simple alors qu'il
faut maintenir. Il n'a pas emporté la décision.

### Mode données réduites (« ÉCO ») — câblé pour de bon

La puce `⊙ Éco` de la sous-barre de discussion bascule
`PreferencesService.dataSaverMode`, la même préférence que l'interrupteur
des Réglages (§10b). Elle était **à moitié câblée** :

| Côté | Avant | Après |
|---|---|---|
| Envoi | respecté — `media_preview_screen` et `media_batch_preview_screen` pré-cochent « réduire la qualité » (1 280 px) | inchangé |
| Réception | **ignoré** — `optimized_image_bubble`, `video_bubble` et `blurhash_image` ne consultaient jamais la préférence | barrière `DataSaverGate` |

Le libellé des Réglages promet « Médias non téléchargés automatiquement en
discussion ». C'est exactement ce que le code ne faisait pas : seul l'envoi
était concerné, la réception téléchargeait quoi qu'il arrive. Pour quelqu'un
en 2G — le réseau qu'affichent les maquettes — c'est l'inverse de ce qui
compte : on subit ce qu'on reçoit, pas ce qu'on envoie.

`data_saver_gate.dart` tient la promesse en n'appelant son `builder` qu'une
fois le téléchargement demandé : avant, `CachedNetworkImage` n'est jamais
construit, donc aucun octet ne part. Le rendu est celui de la §4a — aperçu
flou (le vrai blurhash quand le serveur l'a renvoyé), légende
« aperçu flouté · 240 Ko », bouton « Télécharger ».

Trois choix à connaître :

- **Le média que j'envoie n'est jamais masqué.** Il est déjà local, le cacher
  ne ferait économiser aucun octet.
- **Le poids n'est affiché que s'il est connu** — pas de « 0 Ko » inventé.
- **Le dévoilement vit en mémoire**, par identifiant de message. Sans ça le
  recyclage de la liste re-masquerait le média à chaque défilement. Au
  prochain lancement, le mode reprend la main.

Câblé des deux côtés, production et copie `design_v2`.

### La famille « fil » a son propre système — ne pas lui appliquer la trousse

`lib/features/feed/presentation/theme/` définit `FeedTokens` et `FeedText`,
qui implémentent **exactement** les deux systèmes des maquettes :

- `nocturne` — sombre, accent indigo `#9184D9`, rayons serrés, titrage Inter.
  C'est littéralement ce que montrent 6a→6f.
- `organic` — clair, accent terracotta, rayons généreux, titrage **Caprasimo**.
  C'est le gros display des maquettes 3a, 5a→5h.

Ces écrans sont donc **déjà à jour** sur la structure et les couleurs.
Leur appliquer `design_kit` (Playfair Display, jetons `adaptive_colors`)
serait une régression : ça écraserait la bascule Organic/Nocturne que les
maquettes elles-mêmes montrent. Aucune copie n'a été faite pour eux — ils
se corrigent **directement en production**.

#### Ce qui restait quand même à corriger (fait le 2026-08-03)

L'audit du fil et de Mon espace a trouvé une fuite que le mot « déjà à
jour » masquait : **13 libellés utilisaient un `TextStyle(` brut**. Leurs
couleurs étaient correctes (`tokens.*`), donc rien ne se voyait en
nocturne — mais un `TextStyle` brut n'hérite pas de la fonte de
`FeedText` : il prend celle du thème global de l'app.

Conséquence : en mode **organic**, ces libellés rendaient dans la police
de l'app au lieu de **Figtree**, à côté de titres en Caprasimo. C'est-à-dire
précisément dans le mode que montrent 3a et 5a. Les 13 sites passent
maintenant par `FeedText.body(tokens, …)`.

Deux exceptions volontaires :

- `fontFamily: 'monospace'` dans `feed_screen.dart` — c'est le libellé
  mono voulu par les maquettes, il ne doit pas passer par `FeedText` ;
- `Colors.transparent`, qui n'est pas une couleur de thème.

Reste ouvert, hors périmètre demandé : `saved_posts_screen.dart` peint son
fond de balayage en `Colors.red` avec une icône `Colors.white`. C'est
lisible et l'idiome est universel, mais aucune des deux palettes ne
contient ce rouge, et `FeedTokens` n'a pas de jeton `danger`. À trancher
avant de traiter « Enregistrés ».

### Discussion et composer — état

Le **composer** était déjà refait : les quatre dégradés d'origine avaient
sauté et les trois états d'enregistrement (repos, annulation armée,
verrouillé mains libres) sont câblés — `_isRecording`, `_isCancelling`,
`_isLocked` — avec leurs gestes. Il manquait les **variantes claires** des
couleurs signifiantes, déclarées mais jamais utilisées : sur le fond nuit
du §6c, le vert `#1B5E32` du vocal et le bleu `#2F6BE0` du chiffrement sont
illisibles. Elles servent désormais en thème sombre, ombre portée comprise.

La **discussion** a son en-tête (nom en serif, pastille en aplat, barre
sans teinte Material). Restent les **bulles de message** des maquettes
3b/3c : citation à liseré, lecteur vocal avec vitesse et bouton
« TRANSCRIRE », pièce jointe floutée avec « Télécharger ». Ces briques
vivent dans `message_bubble.dart` et `audio_message_bubble.dart`, pas dans
l'écran — c'est un lot à part, non copié à ce jour.

### Bulles de message (3b, 3c) — état

`message_bubble.dart` (2908 l.) et `audio_message_bubble.dart` (587 l.) sont
copiés dans `design_v2`. Deux des trois briques des maquettes existaient
déjà :

- **Citation à liseré** — `_buildReplyPreview` a bien son filet de 4 px à
  gauche, teinté accent, avec le nom de l'auteur cité. Rien à faire.
- **Vitesse de lecture** — la pastille `1× → 1,5× → 2×` est câblée sur la
  même ligne que la waveform, comme au §3b.

Ajouté : le **poids du fichier** (« 86 Ko », « 1,2 Mo ») à côté de la durée,
depuis `MessageEntity.fileSize`. Sur un réseau 2G, savoir ce qu'on va
télécharger compte. Affiché seulement quand le serveur a renvoyé la valeur —
pas de « 0 Ko » inventé.

**Bouton « TRANSCRIRE » : écarté sur décision.** Il apparaît dans 3b et 3c,
mais la transcription n'existe nulle part pour les messages — seulement pour
les podcasts (`podcast_episode_entity`). Le poser donnerait un widget mort
au clic. Écarté explicitement, à ne pas ré-ouvrir comme un oubli.

**La bulle audio suit la §4a, pas la §3b.** Les deux diffèrent : la 3b
empile une seconde rangée `[1,5×][TRANSCRIRE][86 Ko]`, la 4a garde la
pastille de vitesse en bout de waveform et réserve la ligne du bas à la
position, l'état d'écoute et le téléchargement. Deux écarts corrigés :

- **Pastille de vitesse en contour** au lieu d'un aplat teinté. Pleine, elle
  se lisait comme un état actif alors que c'est un bouton de cycle.
- **Poids du fichier conservé sur la note vocale.** Je l'avais retiré parce
  que la 4a ne le montre pas sur l'audio — c'était une erreur de lecture :
  l'écart est assumé. Sur un réseau 2G, savoir ce qu'on va télécharger
  compte, et l'information vaut sur la note vocale comme sur la pièce
  jointe. Rétabli le 2026-08-03, affiché seulement quand le serveur a
  renvoyé la valeur.

### Salons audio & podcasts — un système propre, appliqué à moitié

`lib/core/theme/` définit un **troisième système de design**, à côté de
`adaptive_colors` et de `FeedTokens` : `DNTheme` (`context.dn`), `DNColors`
et `DNText`. Il est theme-aware — chaque jeton a sa variante sombre — et son
titrage est **Instrument Serif**. C'est exactement l'esprit des maquettes.

Leur appliquer `design_kit` (Playfair Display + `adaptive_colors`) serait la
même régression que pour la famille « fil ». **Ne pas le faire.**

Mais l'adoption est **inégale**, et c'est ça le vrai travail :

| Sur le système DN — rien à faire | Hors système — à convertir vers DN |
|---|---|
| `audio_room_screen` (64) | `creator_earnings_screen` |
| `audio_rooms_list_screen` (35) | `heritage_library_screen` |
| `schedule_room_screen` (24) | `create_podcast_screen` |
| `create_audio_room_screen` (23) | `episode_detail_screen` |
| `ghost_moderator_screen` (20) | `my_podcasts_screen` |
| `save_as_podcast_screen` (18) | `podcast_detail_screen` |
| `replay_player_screen` (16) | `podcast_stats_screen` |
| `live_podcast_screen` (5) | `podcasts_home_screen` |
| | `record_episode_screen` |

(le chiffre = nombre d'usages `DNText.` / `context.dn`)

Les salons sont convertis à 8 écrans sur 9 ; **les podcasts ne le sont
presque pas** — 1 sur 7. La cible n'est donc pas `design_kit` mais **DN**,
et le travail est une migration interne, pas une refonte visuelle.

⚠️ Correction de mon constat précédent : **`live_podcast_screen` n'est pas
un candidat**. Fond noir, surimpressions blanches sur le flux vidéo — même
cas que les écrans d'appel, le blanc y est le seul contraste tenable. Ses
5 `DNText` suffisent. Reste `replay_player_screen`, vraiment mixte.

### Migration des podcasts vers DN — motif établi

`create_podcast_screen` est migré (dans `design_v2/podcasts/`), et sert de
patron aux six autres. Trois gestes :

1. `Scaffold` + `AppBar` prennent `dn.surface`, et le titre passe en
   `DNText.serif(size: 22, color: dn.onSurface)`.
2. Les gris figés (`Colors.grey[600]`) deviennent `dn.onSurface3`.
3. `Theme.of(context).primaryColor` devient `DNColors.terra`.

Restent, par ordre de coût croissant :

| Écran | Lignes | Ce qu'il porte |
|---|---|---|
| `podcast_stats_screen` | 406 | déjà sur `adaptive_colors` (16) — unification seule |
| `my_podcasts_screen` | 525 | 7 `Theme.of` |
| `podcast_detail_screen` | 531 | 6 `Theme.of` |
| `podcasts_home_screen` | 704 | déjà sur `adaptive_colors` (7) — unification seule |
| `record_episode_screen` | 718 | 5 `Theme.of`, 5 `colorScheme` |
| `episode_detail_screen` | 996 | **29 `Theme.of`, 19 `colorScheme`** — le plus gros |

Aucun n'est *cassé* : `adaptive_colors` comme `colorScheme` sont déjà
theme-aware. Cette migration est une unification visuelle avec les salons,
pas une correction de bug.

### Appels — les blancs et les dégradés sont légitimes

Les deux écrans d'appel comptent 48 et 26 usages de blanc, et trois
dégradés. Aucun n'est un oubli :

- Le **blanc** est le seul contraste tenable : ces écrans se peignent sur
  le flux vidéo ou un fond sombre (`Colors.grey[900]`), pas sur le crème.
  C'est ce que font WhatsApp, Signal et FaceTime, pour la même raison.
- Les **dégradés** sont des *scrims* — transparent vers noir à 70 % — posés
  derrière les contrôles pour qu'ils restent lisibles quelle que soit
  l'image en dessous. Les retirer casserait la lisibilité au lieu de la
  moderniser.

Seul changement appliqué : le **nom de l'interlocuteur passe en serif**,
pour rejoindre le titrage du reste de la série. Le reste était déjà juste.

### Nocturnes — rien à implémenter

Vérifié : `app.dart:142` déclare `darkTheme: AppTheme.darkTheme`, donc chaque
écran hérite du thème sombre. Les maquettes 19a, 19b, 2g, 4b et 4c ne
décrivent **pas de nouveaux écrans** — ce sont les versions sombres de 17c,
17a, 1c et 1e.

Trois mécanismes de couleur coexistent et tous les trois adaptent :
`colorScheme` Material (annuaire, ambassades), les jetons `context.dn`
(salons), et `adaptive_colors` (le reste).

Deux couleurs figées ont été corrigées :

- `embassies_screen.dart` — le statut ouvert/fermé était codé en
  `0xFFC23E2D` / `0xFF2D7D46`, les variantes **foncées**, illisibles sur
  fond nuit. Remplacées par `context.errorColor` / `context.successColor` :
  le sens est conservé, le contraste suit le thème.
- `audio_rooms_list_screen.dart` — l'icône micro du bouton « Ouvrir un
  salon » était en `Colors.white` alors que **son propre libellé** utilise
  `DNColors.paper`. Les deux se répondent désormais sur l'aplat terra.

⚠️ Cette vérification est **statique**. Que les jetons soient adaptatifs ne
garantit pas que le contraste tienne : seul un vrai appareil le dira.

### Carte — §7d faite, §7e à faire

Vérifié sur `lib/features/map/presentation/screens/map_screen.dart` (3549 l.),
après les commits `94d721c` et `bdcd795` : **zéro dégradé**, aplats et jetons
adaptatifs partout, bouton de couches présent, panneau à trois positions
(`snapSizes: [0.18, 0.45, 0.92]`). `flutter analyze` passe. Le §7d est bon.

Le **§7e est traité dans `design_v2/map/`**. Les quatre manques :

| Manque | Maquette | Pourquoi ça compte |
|---|---|---|
| Bascule **Carte / Liste** | 7e | fait — dans l'en-tête du panneau |
| Badge **« tuiles allégées »** | 7e | fait — sur l'aplat qui remplace la carte |
| Bouton **« Plein écran »** | 7e | fait — sortie du mode liste |
| Contrôle de **tri** | 7d, 7e | fait — « Les plus proches » ⇄ « Par nom » |

Deux choix de fond :

- En mode liste, la carte **n'est pas chargée du tout** — un aplat la
  remplace. Sur un forfait compté, ne pas télécharger de tuiles vaut mieux
  que les télécharger et les cacher.
- Le mode démarre **allumé si « données réduites » est actif** dans les
  réglages. `PreferencesService.instance.dataSaverMode` existait déjà mais
  n'était jamais lu par la carte : le réglage promettait un comportement
  qu'il n'obtenait pas.

Le tri par distance ne s'applique que si la position est connue ; sinon
l'ordre d'arrivée est conservé plutôt qu'un classement inventé.

⚠️ Ces quatre points sont développés dans **`design_v2/map/`**, pas dans
`lib/features/`, parce qu'une session parallèle travaille sur le fichier de
production. Il faudra reporter, pas écraser.

### Transferts — état

- **§12a (envoi)** : déjà fait par une session précédente — montant en très
  grand, frais et total lisibles avant validation, carte verte « le
  bénéficiaire recevra », taux de change affiché.
- **§16c (historique)** : ajouté — la **frise « Débité → En route →
  Disponible »** remplace le simple badge de statut, qui ne disait pas si
  l'argent avait bougé. Les trois jalons sont les états que le domaine
  connaît déjà (`pending`, `processing`, `completed`). Un transfert échoué,
  remboursé ou annulé n'affiche pas de frise : il n'a pas de trajet à
  raconter. Les cartes passent à plat, contour au lieu d'élévation.

**Non fait, et volontairement** : la mention « **taux garanti 30 min** » du
§12a. `TransactionEntity` porte bien un `exchangeRate`, mais **aucune date
d'expiration**. Afficher une garantie que rien ne tient n'est pas un défaut
cosmétique : c'est une promesse commerciale fausse sur un écran qui déplace
de l'argent. Il faut d'abord que le backend renvoie une validité de taux.

### Réglages et compte

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 20a | Modifier mon profil | `profile/…/edit_profile_screen.dart` | 2400 l. | fait |
| 20b | Appareils connectés | `settings/…/devices_screen.dart` | 550 l. | fait |
| 20c | Sauvegarde des clés | `settings/…/security_backup_screen.dart` | 601 l. | fait |
| 20d | Réglages de notifications | `notifications/…/notification_settings_screen.dart` | 525 l. | fait |
| 21a | Partager mon profil (QR) | `profile/…/widgets/share_profile_modal.dart` | 825 l. | ✅ câblée |
| 21b | Comptes bloqués et mes signalements | `settings/…/widgets/blocked_users_modal.dart`, `reports/…/my_reports_screen.dart` | 402 l. | ✅ câblée |
| 21c | Apparence, langue, fond d'écran | `messages/…/widgets/chat_background_picker_modal.dart` | — | ✅ câblée |
| 21d | Aide et à propos (FAQ en accordéon) | `settings/…/settings_screen.dart` | 2286 l. | ✅ câblée |
| 26c | Document légal en lecture | `legal/…/legal_documents_screen.dart` + `legal_essentials_card.dart` | 75 l. | ✅ câblée |

### Support

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 22a | Nous contacter — nouveau ticket | `support/…/create_ticket_screen.dart` | 266 l. | fait |
| 22b | Mes demandes | `support/…/support_tickets_screen.dart` | 300 l. | fait |
| 22c | Suivi d'une demande | `support/…/ticket_detail_screen.dart` | 421 l. | fait |
| 22d | Aucune demande en cours | idem (état vide) | — | fait |

### Fil, discussion et appels

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 23a | Appel en cours 1-à-1 | `calls/…/call_screen.dart` | 2031 l. | fait |
| 23b | Appel de groupe | `group_calls/…/group_call_screen.dart` | 852 l. | fait |
| 23c | Détail d'un post et commentaires | `feed/…/post_detail_screen.dart` | 357 l. | famille « fil » |
| 23d | Créer une publication | `feed/…/create_post_screen.dart` | 823 l. | famille « fil » |
| 24a | Galerie de la conversation | `messages/…/media_gallery_screen.dart` | 895 l. | à faire |
| 24b | Messages favoris | `messages/…/starred_messages_screen.dart` | 313 l. | à faire |
| 24c | Nouvelle conversation | `messages/…/new_conversation_screen.dart` | 1042 l. | à faire |
| 24d | Résultats d'un sondage | `polls/…/poll_results_screen.dart` | 257 l. | à faire |
| 26b | Stickers et GIF du composer | `messages/…/widgets/gif_picker_content.dart`, `emoji_sticker_picker.dart` | 579 l. | ✅ câblée |

### Services

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 19a | Annuaire Business — nocturne (= 17c) | `businesses/…/businesses_screen.dart` | 407 l. | prod — voir « Nocturnes » |
| 19b | Ambassades — nocturne (= 17a) | `embassies/…/embassies_screen.dart` | 594 l. | prod — voir « Nocturnes » |
| 19c | Mes entreprises (propriétaire) | `businesses/…/my_businesses_screen.dart` | 487 l. | ✅ câblée |
| 25a | Fiche d'un événement | `events/…/event_detail_screen.dart` | 1084 l. | ✅ câblée |
| 25b | Ma boutique — annonces et commandes | `marketplace/…/my_products_screen.dart` (119 l.), `my_orders_screen.dart` | 745 l. | fait (`4a6ed72`) |
| 25c | Détail d'un transfert et moyens de paiement | `transfers/…/transaction_detail_screen.dart` | 797 l. | fait (`4a6ed72`) |
| 26a | Mes amis et demandes | `friends/…/friends_screen.dart` + `widgets/friend_request_item.dart` | 236 l. | ✅ câblée |

### Feuilles modales et confirmations

Ces sept maquettes ne sont pas des écrans : ce sont des feuilles posées
sur un écran existant. Elles se traitent **avec l'écran qui les ouvre**,
pas séparément.

| Maquette | Feuille | Fichier | Structure |
|---|---|---|---|
| 27a | Actions sur un message | `messages/…/conversation_screen.dart` | ✅ faite — voir « Feuille d'actions sur un message » |
| 27b | Confirmation destructive | `messages/…/widgets/delete_message_modal.dart` | ✅ câblée |
| 27c | Signaler un contenu | `reports/…/widgets/report_content_modal.dart` | ✅ câblée |
| 27d | Joindre un média | `messages/…/media_batch_preview_screen.dart` | ✅ câblée |
| 28a | Actions sur une publication | fil | famille « fil » |
| 28b | Qui peut voir cette publication | créer une publication | famille « fil » |
| 28c | Confirmer un transfert | transferts | à faire |
| 28d | Partager dans l'app | fil, discussion | à faire |

### États — la partie la plus utile de la vague

Les maquettes 2a→3d ne décrivent aucun écran neuf : elles décrivent **ce
qui s'affiche quand ça se passe mal**, et elles distinguent des cas que
l'app confond aujourd'hui. C'est là que le gain fonctionnel est le plus
fort, indépendamment du visuel.

| Maquette | Ce qu'elle exige |
|---|---|
| 2a | Le fil garde son cache hors ligne, avec la date du dernier chargement |
| 2b | **Quatre échecs distincts** : pas de réseau, panne serveur, réseau lent, action refusée — aujourd'hui traités comme un seul |
| 2c | Carte sans repère : dire que la position est active mais la zone vide |
| 3a | **Transfert en quatre états** selon où est l'argent : refusé avant débit, incertain, débité non reçu, remboursé — **câblé côté app, voir ci-dessous** |
| 3b | Reconnexion : file d'attente par ordre d'importance, et ce qui est arrivé pendant l'absence |
| 3c | Boutique : trois vides différents (rien en vente, rien commandé, recherche sans résultat) |
| 3d | Groupes : trois vides différents (aucun rejoint, rien dans ma ville, recherche vide) |

⚠️ La maquette 3a laisse trois trous explicites — « délai à définir »,
« schéma à définir », « frais remboursés en cas d'échec ? À trancher ».
Ce sont des **décisions produit**, pas du design : elles doivent être
tranchées avant d'implémenter cet écran, sinon on affichera des délais
inventés.

#### §3a — la taxonomie est écrite, mais elle est inatteignable

`transfer_failure_kind.dart` porte déjà exactement ce que la maquette
demande : `TransferDebitState` (`notCharged` / `charged` / `uncertain`) —
c'est-à-dire **où est l'argent**, ce que les six `TransactionStatus`
génériques ne disaient pas — et sept `TransferFailureKind` qui portent
chacun son état de débit et son action recommandée (réessayer, corriger le
bénéficiaire, contacter le support, ne rien faire). `transaction_detail_screen`
les consomme sur ses sept branches, et traite le remboursement à part.

⛔ **Rien ne remplit `failureReason`.** Ni les fonctions Cloud du dépôt, ni
l'intégration MyNita, qui n'existe que comme valeur d'enum côté client. Le
`transfer_remote_datasource` sait écrire le champ, personne ne l'appelle avec
un motif. Donc `fromReason(null)` renvoie toujours `unknown`, et l'écran
retombe sur le message générique — exactement le comportement d'avant.

Ce n'est **pas** un défaut de câblage à corriger dans l'app : c'est le
prestataire de paiement qui doit renvoyer un motif. La classification est
volontairement permissive (recherche de sous-chaînes, pas de codes exacts)
parce que le format réel dépendra de celui qu'on branchera.

À retenir : ne pas recompter §3a comme « à faire côté UI ». Ce qui reste est
un producteur de motif côté serveur, plus les trois décisions produit
ci-dessus.

## Cinquième vague — salons audio et podcasts

Les deux features audio, qui étaient jusqu'ici la principale zone sans
maquette. Quatre documents, 22 maquettes.

**13 des 22 sont déjà câblées** — bien plus que les 5 annoncées au premier
inventaire, qui sous-estimait. Le `grep` des citations `§` remonte
**§1a, §1c, §1d, §1e, §1g, §1h, §2a, §2e, §2f, §3a, §3b, §4a**, et §1b s'y
ajoute : l'écran du salon en direct porte déjà toutes les briques de la
maquette (`_GhostBar`, `_SpeakersSection`, `_ListenersSection`,
`_HandRaisedSection`, `_ModerationPanel`) avec leurs libellés localisés
(`audioRoomParticipantsOnStage` = « Sur scène · {count}/{max} »,
`audioRoomListenersCount`, `audioRoomLive`).

⚠️ **Piège d'inventaire à ne pas refaire.** Chercher les libellés français
en dur (« SUR SCÈNE », « Auditeurs », « Demander la parole ») renvoie zéro
sur ces fichiers — non pas parce qu'ils manquent, mais parce que **tout y
est déjà passé en ARB**. Il faut chercher les clés, pas les chaînes.

### Cette feature a son propre système — ne pas lui appliquer la trousse

`audio_rooms` et `podcasts` utilisent `DNColors` / `DNText` / `context.dn`
(18 fichiers sur 67), c'est-à-dire **exactement la palette Sahel que nomme
le document des maquettes** : encre `#1A1410`, papier `#FAF6EF`, sable
`#E8DCC4`, terracotta `#C85A3A`, ocre `#D9A441`, teal `#2D6E6A`, feuille
`#5A7A3A`. Même situation que la famille « fil » : leur appliquer
`design_kit` serait une régression. Aucun dégradé, aucun `AppColors` figé
dans `audio_rooms_list_screen` ni `audio_room_screen`.

Restent réellement à faire : §1f (revenus créateur), §2b, §2c, §2d, §2g,
§4b, §4c et le lecteur de replay.

### Audit du reste de la vague audio (2026-08-03)

Mesuré, pas supposé : nombre de clés ARB distinctes, adhérence au système
`DNColors`/`DNText`, dégradés restants, et chaînes françaises encore en dur
(litt��raux de 4+ caractères contenant un accent ou un mot-outil).

| Maquette | Fichier | Clés | DN | Dégradés | Chaînes en dur | Verdict |
|---|---|---|---|---|---|---|
| §2b | `timezone_display_widget` (536 l.) | 0 (rien à traduire) | 0 | 0 ✅ | 0 ✅ | **fait** |
| — | `replay_player_screen` (771 l.) | 5 | 32 | 0 ✅ | 0 ✅ | **fait** |
| §4c | `heritage_library_screen` (1432 l.) | 41 | 28 | **3** | 0 | dégradés seuls |
| §4b / §1e | `episode_detail_screen` (996 l.) | 17 | 0 | **3** | 1 | dégradés + système |
| §1f | `creator_earnings_screen` (545 l.) | 25 | 0 | 0 | 0 | **fait** sauf « prochain versement » |
| §2c | `save_as_podcast_screen` (366 l.) | 17 | 27 | 0 | 0 | **fait** |

⚠️ **La ligne §2b de ce tableau était fausse quand je l'ai écrite.** Les
« 25 chaînes en dur » comptées par mon heuristique sont des **noms de villes
et des drapeaux** (Montréal, Genève, 🇳🇪, 🇫🇷…) — mon filtre les retenait
parce qu'ils portent des accents. Ce ne sont pas des libellés d'interface :
Montréal s'écrit Montréal dans toutes les langues. Le fichier n'a **aucune
copie à traduire**, seulement des formats de date et des identifiants de
fuseau. « 0 clé ARB » y était donc normal, pas un manque.

Le vrai défaut était ailleurs, et l'audit le montrait aussi : **zéro jeton
adaptatif**. Le widget peignait directement sur `AppColors.secondary` et
`AppColors.primary`, c'est-à-dire les constantes du thème clair — la carte
teintée, sa bordure, l'heure en gras et un dégradé d'en-tête. C'est la
famille de défauts la plus récurrente du projet. Corrigé : 5 sites passés en
`context.adaptiveSecondaryColor`, dégradé aplati en `surfaceVariantColor`.

**Dégradés : soldés (2026-08-03).** Les 8 relevés sont traités — timezone
(1), heritage (3), episode_detail (1), replay (1) aplatis ; il en reste
**un seul, délibérément** : le voile de `episode_detail_screen`. Ce n'est
pas de la décoration mais un **voile de lisibilité**, qui assombrit le bas
de la pochette pour que le titre reste lisible quelle que soit l'image.
L'aplatir rendrait le texte illisible sur une photo claire. Commenté comme
tel dans le fichier pour qu'aucune passe future ne le supprime.

⚠️ **Les « 9 chaînes en dur » du lecteur de replay étaient un mirage,
comme les 25 de §2b.** Vérification faite ligne par ligne :

| Nature | Occurrences | Exemple |
|---|---|---|
| Fragments de **commentaires** français | 4 | `'entité tant qu'` — mon motif prend les apostrophes de « l'entité tant qu'il… » pour des guillemets |
| Préfixes emoji sur des libellés **déjà localisés** | 2 | `'😴 ${…sleepTimer}'`, `'🪙 ${…audioRoomTipLabel}'` |
| Symboles et formats numériques | 3 | `'⏮10'`, `'$speed×'`, `'😴 ${_sleepMinutes}m'` |

Zéro libellé à traduire. Le fichier est propre.

**Bilan de l'heuristique « chaînes en dur » : trois relevés, trois faux.**
Elle ne distingue pas un libellé d'un nom propre, d'un symbole, ni même d'un
commentaire — les apostrophes françaises la font dérailler. **Ne plus s'en
servir pour décider quoi faire** : elle sert tout au plus à désigner des
fichiers à ouvrir. Les colonnes « dégradés » et « jetons adaptatifs », elles,
ont été justes à chaque fois.

### §1f — revenus créateur : fait, sauf une ligne qui n'a pas de donnée

L'écran porte déjà tout : solde disponible, répartition (dons, billets,
abonnements, replays), total perçu, historique des versements avec ses cinq
statuts, et le raccordement Stripe. Tous les montants viennent de vraies
sources — `profile.availableBalance`, la liste des `payouts` — aucun chiffre
d'exemple codé en dur, contrairement à ce que la maquette laissait craindre.

⛔ **« Prochain versement le 5 août » est irréalisable en l'état.** Aucune
donnée de calendrier de versement n'existe : `PayoutEntity` porte
`requestedAt` et `processedAt`, c'est-à-dire le **passé** d'un versement,
jamais la date du **prochain**. Rien côté profil ni côté Stripe n'est exposé
à l'app.

L'afficher supposerait d'inventer une date — la ligne serait fausse dès le
premier versement décalé, sur un écran qui parle d'argent dû à quelqu'un.
Bloqué sur le backend, pas sur le design : il faut que le serveur expose la
prochaine échéance avant d'écrire cette ligne.

**Ce que ça dit, dans l'ordre d'attaque :**

⚠️ Les trois premiers points de cette liste **ont été résolus par l'audit
qui la précède** — ils sont conservés barrés plutôt que supprimés, pour que
personne ne les rouvre en croyant à un oubli.

1. ~~**§2b est le seul écran réellement pas fait.**~~ **Faux, et corrigé.**
   Les « 25 chaînes en dur » étaient des noms de villes et des drapeaux, et
   « 0 clé ARB » y est normal : ce widget n'a pas de copie à traduire. Le
   vrai défaut — aucun jeton adaptatif — est corrigé (5 sites).
2. ~~**8 dégradés subsistent**~~ — **soldés.** Il en reste un seul, délibéré :
   le voile de lisibilité de `episode_detail_screen`, commenté comme tel.
3. ~~**`replay_player_screen` traîne 9 chaînes en dur**~~ — **mirage.** Quatre
   fragments de commentaires français, deux préfixes emoji sur des libellés
   déjà localisés, trois symboles. Zéro libellé à traduire.
4. **§1f et §4b/§1e utilisent `Theme.of` et non `DNColors`.** Toujours
   ouvert. À trancher
   plutôt qu'à corriger d'office : `creator_earnings_screen` est par ailleurs
   irréprochable (0 chaîne en dur, 0 dégradé). Basculer un écran propre vers
   un autre système n'est un gain que si la cohérence visuelle le réclame —
   à regarder côte à côte sur appareil avant de décider.
5. **§2g n'a rien à faire.** C'est la variante nocturne de la liste des
   salons, dont le fichier est déjà propre (0 dégradé, système DN) : elle
   suit automatiquement, comme les autres variantes sombres.

Rappel de méthode, après m'être trompé trois fois : **chercher les clés ARB
et les noms de classes, jamais les chaînes françaises**. Sur ces fichiers,
un `grep "Sur scène"` renvoie zéro alors que l'écran est complet.

### §2d — bouton « Brouillon »

L'écran portait déjà le mode audio/vidéo, les chapitres numérotés, la durée
estimée et l'état vide. Manquait la **seconde sortie du pied de page** :
sans brouillon, un enregistrement long n'avait qu'une issue — publier ou
tout perdre.

Chaîne complète, du bouton à la base :

- `createEpisode` prend `asDraft` et écrit `status: 'draft'` ;
- `publishedAt` reste **nul** pour un brouillon, sinon il compterait dans le
  rythme de publication des statistiques (le datasource ne pose déjà
  `published_at` que sur un épisode publié) ;
- la confirmation ne dit plus « publié » pour un brouillon — c'est
  précisément ce que la personne a choisi de ne pas faire.

**Fausse alerte corrigée.** J'avais annoncé au tour précédent que « Terminer
et publier » créait des brouillons, en me fondant sur le défaut de l'entité
(`EpisodeStatus.draft`). C'était faux : l'entité n'est pas le véhicule
d'écriture. Le provider construit un `PodcastEpisodeModel` en fixant
explicitement `'published'`, et l'insert envoie toujours la colonne — le
défaut SQL n'entre jamais en jeu. **Il n'y avait pas de bug de publication.**

Reste non fait sur cette maquette : la mention « max 100 Mo » sur la
sélection vidéo.

### §3c — modération fantôme : la phrase qui manquait

L'écran portait déjà tout : bandeau d'invisibilité, les trois compteurs
(auditeurs visibles, intervenants visibles, chrono), les quatre actions et
la fermeture forcée avec sa mention de journal d'audit.

Il manquait la phrase que la maquette pose sous la grille d'actions :

> « Muet en silence » ne prévient pas la personne : son micro cesse d'être
> diffusé, sans message d'erreur.

Elle n'est pas décorative. C'est **la seule chose qui distingue cette action
d'un mute ordinaire**, et sans elle un modérateur peut croire que la personne
est avertie. Ajoutée sous la grille, en chasse fixe comme le reste des notes
de cet écran.

**Dette repérée au passage, non corrigée** :
`ghost_moderator_screen.dart:273` appelle `warnHost('Avertissement
modérateur')` avec une chaîne française en dur. Ce texte part vers l'hôte,
il devrait donc passer par l'ARB. Non touché parce que c'est une charge
utile envoyée au serveur, pas un libellé d'écran — à trancher avant de le
déplacer.

### Document 1 — écouter

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 1a | Salons audio — liste | `audio_rooms/…/audio_rooms_list_screen.dart` | 849 l. | ✅ câblée |
| 1b | Salon en direct | `audio_rooms/…/audio_room_screen.dart` | 1528 l. | ✅ câblée |
| 1c | Bibliothèque du patrimoine | `audio_rooms/…/heritage_library_screen.dart` | 1432 l. | ✅ câblée |
| 1d | Podcasts — accueil | `podcasts/…/podcasts_home_screen.dart` | 704 l. | ✅ câblée |
| 1e | Lecteur d'épisode | `podcasts/…/episode_detail_screen.dart` | 996 l. | ✅ câblée |
| — | Lecteur de replay (même gabarit que 1e) | `audio_rooms/…/replay_player_screen.dart` | 771 l. | fait — 0 dégradé, 0 chaîne en dur (voir « Audit du reste de la vague audio ») |
| 1f | Revenus créateur | `audio_rooms/…/creator_earnings_screen.dart` | 545 l. | fait, **sauf « prochain versement »** — bloqué backend, voir §1f |
| 1g | Envoyer un don | `audio_rooms/…/widgets/send_tip_bottom_sheet.dart` | 340 l. | ✅ câblée |
| 1h | Acheter un billet | `audio_rooms/…/widgets/buy_ticket_bottom_sheet.dart` | 336 l. | ✅ câblée |

### Document 2 — créer et publier

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 2a | Ouvrir un salon | `audio_rooms/…/create_audio_room_screen.dart` | 638 l. | ✅ câblée |
| 2b | Programmer — multi-fuseaux | `audio_rooms/…/widgets/timezone_display_widget.dart` | 536 l. | fait — 5 sites passés aux jetons adaptatifs, dégradé aplati (voir l'audit) |
| 2c | Publier en podcast | `audio_rooms/…/save_as_podcast_screen.dart` | 366 l. | fait |
| 2d | Enregistrer un épisode | `podcasts/…/record_episode_screen.dart` | 718 l. | ✅ câblée |
| 2e | Aucun salon en direct | `audio_rooms_list_screen.dart` (état vide) | — | ✅ câblée |
| 2f | Podcasts — aucun abonnement | `podcasts_home_screen.dart` (état vide) | — | ✅ câblée |
| 2g | Salons — nocturne | `audio_rooms_list_screen.dart` | — | prod — voir « Nocturnes » |

### Documents 3 et 4 — gérer, modérer, mesurer

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 3a | Mes podcasts (créateur) | `podcasts/…/my_podcasts_screen.dart` | 525 l. | ✅ câblée |
| 3b | Fiche d'un podcast | `podcasts/…/podcast_detail_screen.dart` | 531 l. | ✅ câblée |
| 3c | Modération fantôme (admin) | `audio_rooms/…/ghost_moderator_screen.dart` | 508 l. | ✅ câblée |
| — | Tuile d'épisode (portée par 3a et 3b) | `podcasts/…/widgets/episode_tile.dart` | 545 l. | à faire |
| 4a | Statistiques d'un podcast | `podcasts/…/podcast_stats_screen.dart` | 406 l. | ✅ câblée |
| 4b | Lecteur — nocturne | même écran que 1e | — | prod — voir « Nocturnes » |
| 4c | Patrimoine oral — nocturne | même écran que 1c | — | prod — voir « Nocturnes » |

### ⚠️ Ces maquettes reposent sur de l'argent qui ne circule pas encore

Les documents 1 à 4 affichent des prix d'entrée, des abonnements mensuels,
des dons, des replays payants et un solde créateur retirable. Deux réserves
avant de traiter ces écrans :

1. **Ne pas inventer de chiffres.** Les maquettes elles-mêmes marquent leurs
   montants « propositions à valider » : paliers de don, tarif des épisodes
   payants, montants de revenus, et surtout **le taux de commission hors
   don** — le code ne fixe explicitement que les 95 % reversés sur un don.
   Tant que ce n'est pas tranché, afficher un taux serait une invention.
2. **Vérifier l'état réel du backend** (abonnements, replays payants,
   versements) avant de dessiner un écran qui promet une opération que
   l'app ne sait pas encore exécuter. C'est le piège déjà rencontré sur ces
   mêmes écrans : une interface complète posée sur un chemin de paiement
   qui n'aboutissait pas.

## États vides et nocturne de l'accueil (1a→1c, 2d)

Cette série ne décrit pas de nouvel écran : c'est l'accueil déjà repris dans
`design_v2`, vu **en situation de vide**. Elle confirme les trois causes
distinctes qui y sont implémentées (position active mais personne autour,
position coupée, et les trois vides d'événements).

### Squelette de chargement (1b · CAS 3) — traité

⚠️ J'avais d'abord noté ici « pas de squelette de chargement ». **C'était
faux** : mon `grep` ne cherchait que `Skeleton`/`Shimmer`, alors que le code
les nomme `_NearbyAvatarLoading` et `HomeEventCardLoading`. Les deux
sections de l'accueil en avaient déjà un, et `NearbyProfilesNotifier`
démarre bien en `AsyncValue.loading()` — jamais sur une liste vide.

Il restait en revanche un **vrai** trou, dans le scénario exact que la
maquette illustre (CAS 1 → « Élargir à 200 km » → CAS 3) :

`nearbyProfiles.when(skipLoadingOnRefresh: true, …)` garde volontairement
les résultats précédents pendant un rafraîchissement de fond. Mais il
gardait aussi la carte vide « Personne à moins de 50 km » à l'écran pendant
toute la recherche à 200 km — donc un texte « vide » affiché pendant un
chargement, ce que la maquette interdit noir sur blanc.

Corrigé : `_widenRadius()` lève `_nearbySearching` le temps de la recherche,
et le squelette (`NearbyLoadingRow`) passe devant les résultats précédents
pour ce cas-là seulement. Le rafraîchissement automatique des 60 s garde son
comportement d'origine — il ne doit pas faire clignoter la liste.

Appliqué **des deux côtés** : la copie `design_v2` et la production
`lib/features/home/…` portent le même correctif, vérifié identique. Ce point
ne créera donc pas d'écart à la bascule.

## Écrans hors maquettes

Reste sans maquette à ce jour, et hors périmètre annoncé : le back-office
admin (19 écrans). Ces écrans gardent leur habillage actuel.
