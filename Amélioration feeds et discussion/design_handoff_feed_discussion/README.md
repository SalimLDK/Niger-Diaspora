# Handoff : Fil d'actualité & Discussion — Diaspo Niger

## Vue d'ensemble

Refonte du **fil d'actualité** (feature `feed`) et de **l'écran de discussion** (feature `messages`) de l'app Flutter Diaspo Niger, plus les écrans satellites du fil (Mon espace, Mes publications, Enregistrés, Mon réseau). Objectifs traités : hiérarchie de lecture, densité, découvrabilité des actions, lisibilité des bulles (contraste AA), et adaptation au mode données réduites.

Trois tours retenus :
- **Tour 4** — direction validée : fil téléphone + tablette, discussion, composer, états d'enregistrement vocal.
- **Tour 5** — écrans « Mon espace » (hub), Mes publications, Enregistrés, Mon réseau + états vides.
- **Tour 6** — déclinaison Nocturne (thème sombre) des tours 4 et 5.

## À propos des fichiers de design

Le fichier `Feed & Discussion.dc.html` de ce bundle est une **référence de design réalisée en HTML** : un prototype qui montre l'apparence et le comportement voulus, **pas du code à copier**. Le travail consiste à **recréer ces écrans en Flutter**, dans l'architecture existante du projet (Riverpod + go_router + widgets par feature), en réutilisant les tokens et widgets déjà en place (`FeedTokens`, `AppColors`, `AdaptiveColors`, `AppIcon`).

Le document est organisé en « tours » empilés, le plus récent en haut. Chaque option porte un identifiant visible (`4a`, `5c`, `6b`…) : c'est la référence à utiliser dans les échanges.

## Fidélité

**Haute fidélité (hifi).** Couleurs, typographies, espacements et rayons sont définitifs et proviennent du code existant. Les images sont des placeholders rayés (à remplacer par les vrais médias). Les icônes sont les SVG du dépôt (`assets/icons/`), rendus en CSS `mask` dans le prototype — côté Flutter, ce sont les mêmes `AppIcon(AppIcon.xxx)`. Là où le prototype utilise un glyphe Material (`play_arrow`, `pause`, `edit`, `more_horiz`, `more_vert`, `repeat`, `bookmark`, `chevron_right`, `tag`, `mood`, `photo_camera`, `description`, `drafts`, `edit_note`, `data_saver_on`, `download`, `keyboard_arrow_up`), le code utilise déjà `Icons.*` : conserver `Icons.*`.

---

## Tokens

### Fil — `lib/features/feed/presentation/theme/feed_tokens.dart` (inchangés)

| Rôle | Organic (clair) | Nocturne (sombre) |
|---|---|---|
| `bg` | `#F5EAD8` | `#161826` |
| `surface` | `#EBDDC5` | `#232532` |
| `text` | `#201E1D` | `#E9E9ED` |
| `mutedText` | `#82796A` | `#9397AB` |
| `accent` | `#C67139` | `#9184D9` |
| `accent2` | `#7A8A5E` | `#A7A1DB` |
| `divider` | `rgba(32,30,29,.16)` | `rgba(233,233,237,.16)` |
| `avatarBg` / `avatarFg` | `#643312` / `#FFF2EB` | `#423A6A` / `#F5F4FF` |
| `hashtagColor` | `#8C491A` | `#D2CEFD` |
| `cardRadius` | 32 (28 sur les nouvelles cartes) | 8 |
| `radiusMd` | 16 | 8 |
| Typo titres | Caprasimo | Inter 500, `letterSpacing -0.4` |
| Typo corps | Figtree | Inter |

**Nouvelles valeurs introduites par la refonte** (à ajouter aux tokens si vous voulez les centraliser) :
- `textStrong` = `text` (le corps de post passe de `#4A443C` à `#201E1D` en clair, de `#C4BDB3` à `#E9E9ED` en sombre) ;
- `actionLabel` clair `#5E564A`, sombre `#C3C6D4` (icônes + libellés d'action) ;
- `actionMuted` clair `#9c9384`, sombre `#9397AB` (actions secondaires : signet, partage) ;
- `hairline` clair `rgba(32,30,29,.10)`, sombre `rgba(233,233,237,.12)` (filet au-dessus de la barre d'actions).

### Discussion — `lib/core/constants/app_colors.dart` (inchangés)

| Rôle | Clair | Sombre |
|---|---|---|
| Fond conversation | `#FAF7F2` | `#0F0D0A` |
| En-tête / composer | `#FFFFFF` | `#1A1714` |
| Bordure en-tête | `#EFE7DB` | `#2A241E` |
| Bulle reçue | `#FFFFFF` + bordure `#EFE7DB` | `#252119` + bordure `#3D352C` |
| Bulle envoyée | `#1B5E32` (`secondaryDark`) | `#2D7D46` (`secondary`) |
| Texte bulle envoyée | `#FFFFFF` | `#FFFFFF` |
| Texte principal | `#1C1815` | `#F5F2EE` |
| Texte secondaire | `#4A443C` | `#C4BDB3` |
| Horodatage / tertiaire | `#A79C8E` | `#7C7367` |
| Champ de saisie | `#F5F0E8` | `#2D2820` |
| Accusé « lu » | `#2D7D46` | `#5BA674` |
| Repères (épinglé, réponse, éco) | `#B85E24` | `#F4A574` |
| Erreur / annulation | `#C23E2D` | `#F87171` |

> ⚠️ Rappel : le thème sombre par défaut est `AppTheme.darkTheme` = `_buildDarkTheme(useGreenPrimary: true)`, donc `colorScheme.primary` = `#5BA674` (vert) et `colorScheme.secondary` = `#F4A574` (orange) — les rôles s'inversent par rapport au clair. Les valeurs du tableau sont volontairement explicites pour ne pas dépendre de cette inversion.

### Espacements, rayons, cibles

- Carte de post : padding `16`, rayon `28` (clair) / `8` (sombre), marge verticale `12`.
- Barre d'actions : filet 1 px, `padding-top: 12`, `gap: 14`, icônes 19 px.
- Bulles : padding `10 / 14`, rayons `18` avec coin de queue `6`, groupage `gap: 3`.
- Cibles tactiles : jamais < 40 px (44 px pour lecture audio, micro/envoi).
- Réserve basse des listes du fil : **100 px** (le FAB flotte au-dessus) — cohérent avec `main_shell.dart` qui gonfle déjà `MediaQuery.padding.bottom` de 110.

---

## Tour 4 — direction retenue

### 4g / 4b — Fil (`feed_screen.dart`, `post_card.dart`)

**En-tête** (remplace l'`AppBar` centrée actuelle) :
- Sur-titre monospace 10.5 px, `letterSpacing .1em`, majuscules, `#9A6A3A` (clair) / `#8E86C4` (sombre) : date du jour.
- Titre « Le fil. » Caprasimo 26 px (clair) / Inter 500 24 px (sombre), le point en couleur d'accent.
- Actions à droite : recherche (40 px, fond `surface`), **avatar « Mon espace »** 40 px (anneau 1.5 px accent + liseré fond, pastille de notification `#C23E2D`) → route `/profile/follows`-like, cf. tour 5.
- **Le bouton de publication est un FAB** (56 px, `accent` plein en clair, contour accent en sombre, ombre `0 14px 34px rgba(46,43,37,.28)`), en bas à droite, comme aujourd'hui.

**Sélecteur de mode** : trois segments de largeur égale (`Expanded`), rayon 14/8, actif = rempli accent (clair) / contour accent (sombre). Remplace `FeedSegmentedControl` groupé à gauche.

**Filtres villes** (nouveau) : rangée scrollable de chips ; actif = `#201E1D` plein avec icône `icon_location`, inactifs = contour `rgba(32,30,29,.18)`. Source de données : ville du profil auteur (`ProfileEntity`), à confirmer côté back.

**Rail d'actus** (nouveau) : cercles 56 px, anneau accent pour les non-vus, libellé 10.5 px. **Se replie au défilement** (`scrollOffset > 24`) en une barre de 38 px : trois avatars superposés + « 5 récits aujourd'hui » + action « Afficher ». Implémentation : `SliverAppBar`/`AnimatedCrossFade` piloté par le `ScrollController` déjà présent dans `_FeedScreenState`.

**Carte de post** :
- Avatar 42 px, nom **`#201E1D` / 15 px / w600**, seconde ligne « Ville · il y a 12 min » 12.5 px `mutedText`.
- « Suivre » devient un **libellé texte accent** (plus de bouton plein) ; `FollowButton` doit accepter un variant `text`.
- Corps du post : 15.5 px, `height 1.6`, couleur `text` pleine, `textWidthBasis` + `text-wrap: pretty` (Flutter : `softWrap` + `TextAlign.start`).
- Média : rayon 20 (clair) / 8 (sombre), hauteur 200–210 pour une image unique.
- Barre d'actions : filet séparateur, puis `[cœur + compteur] [bulle + « N commentaires »] [repeat + N]` à gauche en `actionLabel`, `[signet] [partage]` à droite en `actionMuted`. Les compteurs actifs prennent la couleur d'accent.

**Tablette (4b)** : rail de navigation gauche 86 px (Accueil, Carte, Groupes, Messages, Profil — mêmes items que `bottom_navigation.dart`, badge non lus inclus), colonne centrale fluide (posts) + colonne droite 330 px (filtres villes, hashtags du moment, à suivre). Le rail d'actus se replie de la même façon. FAB 64 px en bas à droite. Breakpoint : utiliser `ResponsiveBuilder` (`lib/core/responsive/`).

### 4a — Discussion (`conversation_screen.dart`, `message_bubble.dart`, `message_input.dart`)

**En-tête** : hauteur 58, avatar 38 px rayon 13 avec pastille de présence (11 px, bordure 2 px de la couleur de l'en-tête), nom 15.5 w600, statut 12 px + cadenas `icon_lock` si E2EE. Actions : appel, vidéo, menu (icônes 21 px, plus de conteneur gris).

**Sous-barre** : pastille « épinglé » (icône `icon_pinned_message` + texte tronqué), compteur médias (`icon_image` + N), bascule **ÉCO** (mode données réduites) — le tout en tuiles 12 px de rayon sur fond `#F5F0E8` / `#252119`.

**Bulles** — remplacer `BackdropFilter` + dégradés + bordure blanche par des **surfaces opaques** :
- reçue : `#FFFFFF` bordure `#EFE7DB` (clair) / `#252119` bordure `#3D352C` (sombre), texte principal ;
- envoyée : `#1B5E32` (clair) / `#2D7D46` (sombre), texte blanc ;
- rayons 18 avec coin de queue 6 ; groupage : un seul horodatage sous le dernier message du groupe ;
- citation de réponse : filet blanc 2 px + nom + extrait tronqué ;
- réactions : pastille surface bordée sous la bulle, `white-space: nowrap` (en Flutter : pas de retour à la ligne, `Chip` compact).

Gain attendu : suppression du blur par bulle (coûteux sur entrée de gamme) et contraste texte ≥ 4,5:1.

**Glisser-pour-répondre** : translation horizontale de la bulle bornée à 90 px, icône `reply` révélée derrière ; au-delà de **52 px** au relâchement → la citation s'installe au-dessus du champ (bandeau annulable). Le clic est ignoré si le doigt a bougé > 4 px.

**Bulle audio reçue** (`audio_message_bubble.dart`) : largeur 250, lecture 44 px (fond `#1B5E32` / `#2D7D46`, ombre douce), **waveform 132 × 36 px, 18 barres de 4 px (gap 3,5)**, barres non lues `#DDD3C4` / `#4A423A`, lues en vert, **tête de lecture** 2 px + pastille 8 px cerclée de la couleur de bulle ; clic sur la waveform = déplacement dans la piste. Pastille de vitesse (1× → 1,5× → 2×) **sur la même ligne**. Sous la waveform : `0:12 / 0:34`, point vert « non écouté », téléchargement à droite.

**Composer** (`message_input.dart`) :
- « + » **hors du champ**, cible 40 px, ouvre un **panneau ancré en grille 3 × 2** (Caméra, Galerie, Document, Position, Sondage, Événement) — plus de `showModalBottomSheet` ;
- champ pilule avec **emoji à l'intérieur** (32 px) ;
- bouton vocal libellé « MAINTENIR » (pilule verte) qui **se transforme en bouton d'envoi rond** dès qu'il y a du texte ;
- panneau emoji : onglets Emojis / GIF / Stickers + rangée **RÉCENTS** avant la grille 8 colonnes.

**Enregistrement vocal (4d / 4e / 4f)** :
1. *En cours* : bandeau `#FDF3EF` bordé `#F0D9CE` — point rouge, chrono, waveform, « ‹ ANNULER », bouton micro avec halo ; indice « GLISSER ← POUR ANNULER · ↑ POUR VERROUILLER » ; puce de verrouillage flottante au-dessus.
2. *Annulation armée* (glissé < −70 px) : bandeau `#FBE9E5`, corbeille pleine `#C23E2D` (asset `icon_delete.svg`), « RELÂCHER POUR ANNULER », waveform à 35 % d'opacité.
3. *Verrouillé* (glissé < −50 px verticalement) : corbeille à gauche, chrono, waveform, badge « VERROUILLÉ » (`icon_lock`), envoi 40 px à droite, légende « MAINS LIBRES ».

---

## Tour 5 — écrans satellites

| Écran | Fichier cible | Points clés |
|---|---|---|
| **5a Mon espace** (nouveau) | nouvel écran, route `/feed/space` | Avatar 64, nom + `@handle · Niamey → Paris`, trois cartes de stats (42 / 318 / 127), liste : Mes publications, Mes repartages, Enregistrés, Abonnés et abonnements, Hashtags suivis, puis Brouillons en carte séparée. Point d'entrée = avatar de l'en-tête du fil. |
| **5b Mes publications** | `my_posts_screen.dart` + `reposts_screen.dart` | Deux segments « Publications · 42 » / « Repartages · 9 ». Chaque ligne : date + portée (Public/Abonnés), extrait, vignette 56 px, stats compactes, « Modifier », menu. Carte Brouillon avec Reprendre / Supprimer. |
| **5c Enregistrés** | `saved_posts_screen.dart` | Chips Tout / Photos / Vidéos / Textes, regroupement par période (Cette semaine / Plus ancien), ligne = vignette 72 px + auteur + extrait 2 lignes + « Retirer » / « Partager ». |
| **5d Mon réseau** | `follows_screen.dart` | Onglets « Abonnés · 318 » / « Abonnements · 127 » (segments pleins, pas de `TabBar` souligné), recherche, lignes 44 px avec bouton Suivre / Suivi, hashtags suivis dans l'onglet Abonnements, section Suggestions. |
| **5e / 5g / 5h États vides** | idem | Cercle 104 px + icône accent, titre Caprasimo 21 px sur deux lignes, texte 14.5 px, amorces d'action, CTA plein. Mention « Vos enregistrements ne sont visibles que par vous » pour 5e ; suggestions + « Inviter des proches » pour 5h. |

---

## Tour 6 — Nocturne

Mêmes écrans, tokens sombres du tableau ci-dessus. Points d'attention :
- surfaces `#232532` **sans ombre** (les ombres portées ne se voient pas sur fond sombre : utiliser les rayons et les filets `rgba(233,233,237,.12)`) ;
- FAB en **contour indigo** sur fond `#161826` (le plein indigo vibre trop sur fond sombre) ;
- boutons accent sombres : texte `#161826` sur `#9184D9` (jamais blanc) ;
- discussion sombre : bulle envoyée `#2D7D46` pleine, jamais `#F4A574` en fond de texte blanc (contraste ~1,9:1 — c'est le défaut actuel de `message_bubble.dart`).

---

## Comportements & états

- **Envoi de message** : optimiste, statut `envoyé` → `lu` (double coche verte) ; le brouillon persistant existant (`PreferencesService.saveMessageDraft`) est conservé.
- **Réactions** : appui long (ou clic dans le prototype) ouvre une barre de 6 emojis `❤️ 👍 😂 😮 😢 🙏` en surface flottante ; la sélection pose une pastille sous la bulle.
- **Lecture audio** : progression continue, vitesse cyclique, seek au clic ; point « non écouté » disparaît après première lecture.
- **Rail d'actus** : replié dès `scrollOffset > 24` (téléphone) / `> 30` (tablette), déplié au retour en haut ou via « Afficher ».
- **Mode éco** : médias non téléchargés automatiquement — aperçu flouté + poids + bouton « Télécharger » (branche sur `AutoDownloadService` / `auto_download_service.dart`).
- **États vides** : toujours une action d'amorce, jamais un simple texte gris.

## Assets

Icônes SVG copiées telles quelles depuis `assets/icons/` du dépôt : `icon_heart`, `icon_favorite_border`, `icon_chat_bubble`, `icon_send`, `icon_arrow_back`, `icon_people`, `icon_person`, `icon_clock`, `icon_call`, `icon_video`, `icon_mic`, `icon_image`, `icon_add`, `icon_close`, `icon_done_all`, `icon_check`, `icon_search`, `icon_star`, `icon_pin`, `icon_pinned_message`, `icon_poll`, `icon_location`, `icon_groups`, `icon_public`, `icon_lock`, `icon_share`, `icon_event`, `icon_delete`. Aucune nouvelle icône n'a été dessinée. Les images sont des placeholders : à remplacer par les médias réels.

## Ordre d'implémentation conseillé

1. **Tokens** : ajouter `textStrong` / `actionLabel` / `actionMuted` / `hairline` à `FeedTokens` (clair + sombre).
2. **`post_card.dart`** : hiérarchie, barre d'actions nommée, filet, « Suivre » en texte. Effet immédiat sur tout le fil.
3. **`message_bubble.dart`** : bulles opaques (retirer `BackdropFilter` et les dégradés), groupage, réactions, glisser-pour-répondre.
4. **`message_input.dart`** : composer (grille ancrée, emoji dans le champ, bouton vocal libellé) puis les trois états d'enregistrement.
5. **`audio_message_bubble.dart`** : waveform seekable + tête de lecture + vitesse en ligne.
6. **`feed_screen.dart`** : en-tête, segments pleine largeur, filtres villes, rail repliable, réserve basse de 100 px.
7. **`conversation_screen.dart`** : sous-barre épinglés / médias / éco.
8. **Écrans du tour 5** : hub « Mon espace » (nouvelle route) puis reprise de `my_posts_screen`, `saved_posts_screen`, `follows_screen` + états vides.
9. **Tablette** : `ResponsiveBuilder` deux colonnes + rail de navigation.
10. **Nocturne** : vérifier chaque écran en `Brightness.dark` (les tokens font l'essentiel du travail).

## Fichiers de ce bundle

- `Feed & Discussion.dc.html` — le prototype complet (tours 1 à 6). Le tour 4 est marqué « ✓ VERSION RETENUE ». **Ouvrez-le dans un navigateur** : c'est la référence qui fait foi (les interactions du tour 4 y sont jouables : envoi, réactions, lecture vocale, enregistrement, rail repliable).
- `screenshots/tour-4-direction-retenue.png`, `screenshots/tour-5-mon-espace.png`, `screenshots/tour-6-nocturne.png` — captures des trois tours.
  > ⚠️ Les captures sont produites par un moteur qui ne rend pas les icônes en `mask-image` : elles apparaissent en **carrés pleins**. Les icônes réelles sont les SVG de `assets/icons/` (voir la section Assets) et s'affichent correctement dans le fichier HTML. Les captures servent à la mise en page, pas aux icônes.
- `assets/icons/*.svg` — les icônes du dépôt utilisées par le prototype (identiques aux vôtres).
- `support.js` — runtime nécessaire à l'ouverture locale du prototype (à garder à côté du fichier HTML).
