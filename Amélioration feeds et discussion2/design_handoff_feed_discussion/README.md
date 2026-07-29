# Handoff : Fil d'actualité & Discussion — Diaspo Niger

## Vue d'ensemble

Refonte du **fil d'actualité** (feature `feed`) et de **l'écran de discussion** (feature `messages`) de l'app Flutter Diaspo Niger, plus les écrans satellites du fil (Mon espace, Mes publications, Enregistrés, Mon réseau). Objectifs traités : hiérarchie de lecture, densité, découvrabilité des actions, lisibilité des bulles (contraste AA), et adaptation au mode données réduites.

Tours livrés :
- **Tour 4** — direction validée : fil téléphone + tablette, discussion, composer, états d'enregistrement vocal.
- **Tour 5** — écrans « Mon espace » (hub), Mes publications, Enregistrés, Mon réseau + états vides.
- **Tour 6** — déclinaison Nocturne (thème sombre) des tours 4 et 5.
- **Tours 7–8** — Accueil et Carte (dont carte Nocturne et état sans localisation).
- **Tour 9** — Messages (liste, recherche, états vides) et Groupes (liste, fiche, état vide).
- **Tour 10** — Profil : mon profil, réglages, profil public d'un membre.
- **Tour 11** — Nocturne des tours 8/9/10 + profil incomplet.
- **Tour 12** — Transfert d'argent, Boutique, Notifications, Recherche.
- **Tour 13** — Événements, Ambassade, Appels, Onboarding.
- **Tour 14** — Onboarding complet (5 écrans, dont « Commencer »).
- **Tour 15** — Connexion, inscription, configuration du profil (étapes 2/4 et 3/4).
- **Tour 16** — Détail produit, panier (+ vide), transferts (+ vide), demande administrative, création d'événement, configuration 1/4 et 4/4.
- **Tour 17** — Ambassades (liste, contact) et Annuaire Business (liste, fiche).
- **Tour 18** — Annuaire : état vide, création d'entreprise, avis clients, mise en avant.
- **Tour 19** — Nocturne de l'annuaire et des ambassades + écran Mes entreprises.
- **Tour 20** — Modifier le profil, appareils connectés, sauvegarde des clés, réglages de notifications.
- **Tour 21** — Partage de profil (QR), comptes bloqués + mes signalements, apparence (thème, langue, fond d'écran), aide &amp; FAQ.
- **Tour 22** — Support : nous contacter, mes demandes, suivi de ticket, état vide.
- **Tour 23** — Appel 1-à-1, appel de groupe, détail d'un post, création de publication.
- **Tour 24** — Galerie de la conversation, messages favoris, nouvelle conversation, résultats de sondage.
- **Tour 25** — Fiche d'événement, ma boutique (annonces + commandes), détail de transfert + moyens de paiement.
- **Tour 26** — Amis &amp; demandes, stickers / GIF, document légal en lecture.
- **Tours 27–28** — Modales et feuilles d'action (message, confirmation destructive, signalement, joindre un média, actions post, audience, confirmer un transfert, partager).

Et dans un **second fichier**, `Salons audio & Podcasts.dc.html` : salons audio (liste, salon en direct, patrimoine oral), podcasts (accueil, lecteur), revenus créateur, don et achat de billet.

## État d'implémentation (màj 2026-07-29)

> Branche `wip-jules-2025-12-29T23-58-34-776Z`. `flutter analyze` = **0 issue**, `flutter test` = **62/62**. **Aucune vérification sur appareil** (pas d'émulateur) : les changements de gestes/layout/permissions restent à valider à la main.

**Le handoff est implémenté au maximum du faisable.** Le socle (tours 4–28 + Salons/Podcasts) était déjà couvert ; les items qui restaient « bloqués par le modèle/backend » ont depuis été débloqués.

### ✅ Fait — déblocages récents
| Item | § | Note |
|---|---|---|
| Écran **« Mes entreprises »** multi-cartes | 19c | `getMyBusinesses()` (plus de `.limit(1)`), route `/businesses/mine` |
| **Offre en cours** sur la carte annuaire | 17c | requête paresseuse par carte |
| **Fonds d'écran nommés** Sahel / Tissage / Nuit | 21c | rendus en `CustomPainter` (aucun asset) |
| **Badge « Gratuit »** événements + champ prix | 13a/16e/25a | champ `price` sur `EventEntity` |
| **Filtre par ville** du fil | — | champ `author_city` + migration SQL |
| **Rôle modérateur** : champ + affectation + badge MODÉ | 9d | `moderatorIds`, affectation depuis l'écran membres |
| **Prochaine rencontre** sur la fiche de groupe | 9d | `EventModel` porte enfin `groupId` (était perdu) |
| **@handle public** + vérification de disponibilité | 16f/10c | champ `handle` + index UNIQUE serveur |
| **Groupes en commun** sur le profil public | 10c | dérivé des groupes déjà chargés (sans RPC) |

### 🗄️ Migrations Supabase appliquées
- `posts.author_city` (+ backfill depuis `users.city`) — filtre villes du fil ;
- `groups.moderator_ids` — rôle modérateur ;
- `users.handle` (+ index UNIQUE `lower(handle)`) — poignée publique ;
- `mark_messages_as_delivered` : suppression de la surcharge TEXT en double (bug-fix prod).

### ⛔ Reste hors périmètre (greenfield / contrainte produit)
- **Rail stories/actus** : feature volontairement écartée (aucun modèle Story) — build greenfield, pas un déblocage.
- **En-tête carte unifié (7d)** : réécriture d'un écran Google Maps de ~3200 lignes, non testable sans appareil.
- **Filmstrip multi-média (27d)** : casserait l'éditeur mono-fichier façon Signal.
- **Sondage / Lieu attachés à un post** : les sondages sont réservés aux groupes (contrainte DB).
- **Back-office admin (19 écrans)** : traité dans un document séparé (cf. « Non traité dans ce handoff »).

## Guide d'implémentation détaillé

👉 **`GUIDE_IMPLEMENTATION.md`** explique écran par écran *comment* reproduire les maquettes dans le code : fichier à ouvrir, ce qui disparaît, ce qui apparaît, valeurs exactes, pièges, et les points à trancher avant de coder. Ce README reste la référence *quoi changer* ; le guide donne le *comment*.

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

## Tours 7–8 — Accueil &amp; Carte

**Accueil** (`home_screen.dart`) — option retenue **8a** :
- l'en-tête en **dégradé orange** disparaît : fond `#FAF7F2`, avatar 52 rayon 16, « Bonjour, » 13.5 `#847A6E` + prénom 22 w700 `#1C1815`, QR et notifications en tuiles 44 px `#F5F0E8` (badge `#C23E2D`) ;
- recherche : champ plein `#FFFFFF` bordé `#EFE7DB`, rayon 16 ;
- les **trois cartes de statistiques deviennent une ligne de contexte** : `icon_location` + « Paris, France » (w600) + « · 318 membres · 12 groupes » (`#847A6E`, ellipsé) ;
- **bloc « Aujourd'hui »** (nouveau) : carte blanche, en-tête monospace, 3 lignes actionnables — messages non lus, prochain événement avec bouton « J'y vais », nouveaux membres proches ;
- Services : **grille 4 colonnes** de tuiles carrées (au lieu du carrousel horizontal qui masque la moitié des entrées) ;
- Autour de vous : avatars 58 px + prénom + distance, dernière tuile « +9 / Voir tout » en pointillés ;
- Événements : carte avec pastille de date 52×56 (`02 / AOÛT`), titre, lieu · heure · participants.

**Carte** (`map_screen.dart`) — option **7d** (+ **8b** Nocturne, **8c** sans localisation) :
- les couches empilées en absolu (`top:16` recherche, `top:76` chips, légende repositionnée à la main) sont **regroupées dans un seul bloc d'en-tête** : recherche + bouton calques sur une ligne, puis rangée de chips scrollable (`SingleChildScrollView` horizontal) — plus de masquage conditionnel des filtres ;
- la **légende passe dans un bouton « ? »** de la colonne d'actions droite (avec recentrage `my_location`), ce qui supprime le calcul `bottom: 130/290` ;
- le panneau membres devient une **feuille à trois positions** (poignée 40×4) avec liste actionnable : avatar 44, métier · distance · présence, bouton message ;
- pins : membre 44 px bordure blanche 3 px, cluster 52 px, ambassade en carré 36 px `#1976D2` ; marqueur de position = point bleu 16 px dans un halo 44 px ;
- **8c** remplace le bandeau d'avertissement par un écran assumé : explication de la réciprocité, trois garanties (position approximative, désactivable, invisible pour les bloqués), CTA « Activer la localisation », et repli « explorer par ville » avec ambassade et groupe local.

## Tour 9 — Messages (liste) &amp; Groupes

| Écran | Fichier cible | Points clés |
|---|---|---|
| **9a Liste des messages** | `messages_screen.dart`, `conversation_item.dart` | Section **Épinglées** séparée (carte blanche) puis « Cette semaine » ; avatar 50 rayon 17 + pastille de présence 13 px ; l'aperçu **dit son type** (📎 photo, `icon_mic` + « Note vocale · 0:34 », `icon_done_all` pour vos envois, `@vous` en accent pour les mentions) ; heure en `#B85E24` w600 quand non lu, sinon `#A79C8E` monospace ; badge non-lus 22 px ; filtres Tous / Non lus (badge) / Groupes / Archives. |
| **9b Recherche** | idem | Compteurs par type (Tout 14 · Messages 9 · Personnes 3 · Fichiers 2), personnes en rangée d'avatars 56, extraits avec terme surligné (`<mark>` `#F7E0CE`/`#8C491A`), fichiers avec poids + date, « Voir les 9 messages ». |
| **9c Groupes** | `groups_screen.dart` | Bandeau « 2 invitations en attente » ; carte de groupe avec **badge d'activité** ACTIF (`#E8F0EA`/`#1B5E32`) vs CALME (`#F5F0E8`/`#847A6E`), épinglé visible, avatars empilés + « 14 messages aujourd'hui », bouton Ouvrir ; découverte « Suggéré près de Paris » en deux cartes. |
| **9d Fiche de groupe** | `group_detail_screen.dart` | Identité (privé · ville · année), description, actions primaires, raccourcis Épinglés / Médias / Prochaine rencontre (« J'y vais »), membres avec badges ADMIN / MODÉ. |
| **9e / 9f États vides** | idem | Messages : rappel du chiffrement + deux amorces (membre proche, groupe de la ville). Groupes : explication de l'usage + 3 groupes populaires avec « Rejoindre » + « Créer votre groupe » en carte pointillée. |

## Tour 10 — Profil

Source lue : `profile_screen.dart`, `profile_view_screen.dart`, `profile_options.dart`, `profile_entity_extensions.dart`.

**10a Mon profil** — l'écran actuel mélange identité et réglages (en-tête dégradé + avatar 80 + **e-mail** + 4 stats + 7 sections ≈ 30 lignes). Proposition :
- identité : avatar 84 rayon 28 avec pastille appareil photo, nom 20 w700 + badge vérifié 18 px `#1976D2`, ligne « Paris, France 🇫🇷 » (`currentCity`/`currentCountry` + drapeau de `ProfileOptions.countries`), puces `originCity → currentCity` et `profession` ; **l'e-mail disparaît** ;
- bio 14/1.55 en pleine couleur de texte ;
- deux boutons pleine largeur (Modifier / Partager) ;
- une seule carte de stats en 4 colonnes séparées par des filets ;
- « Mon espace » (Mes publications, Enregistrés, Mon réseau) ;
- **les 7 sections de réglages se réduisent à 3 entrées** avec leur état en sous-titre : « Confidentialité et sécurité — Profil visible · localisation activée », « Apparence et langue — Système · Français », « Aide et à propos — Version 1.2.0 ».

**10b Réglages** (écran dédié) : « Qui vous voit » (profil visible, position sur la carte avec la réciprocité expliquée, statut en ligne — chaque interrupteur porte sa conséquence en sous-titre), Sécurité (sauvegarde des clés avec état daté en vert, appareils, comptes bloqués), Application (thème, langue, mode données réduites), puis **zone sensible isolée** bordée `#F0D9CE` pour déconnexion et suppression (« Définitif · 30 jours de délai »).

**10c Profil public d'un membre** (`profile_view_screen.dart`) : présence + distance, puces ville et profession, bio, **langues parlées** en puces (`profile.languages`), actions « Envoyer un message » + demande d'ami (`icon_person_add`) + appel, accès à la galerie de **médias partagés**, publications récentes, « Signaler ou bloquer » discret en pied.

> ⚠️ Deux éléments des maquettes **n'existent pas dans le modèle** : une **poignée publique `@handle`** et le compteur **groupes en commun**. Ils ont été retirés des écrans ; à ajouter à `ProfileEntity` seulement si vous les retenez.

**11f Profil incomplet** : barre de progression (40 %, « 2/5 »), trois champs manquants nommés avec leur bénéfice (ville actuelle → visibilité sur la carte, métier → liste fermée `ProfileOptions.professions`, langues → entraide), champs déjà remplis en `icon_check_circle` grisés, CTA « Compléter mon profil » + « Plus tard ».

## Tour 11 — Nocturne (accueil, messages, groupes, profil)

Tokens sombres **AppColors dark** appliqués partout : fond `#0F0D0A`, surfaces `#1A1714` / `#252119`, bordures `#2A241E` et `#3D352C`, texte `#F5F2EE` / `#C4BDB3` / `#8A8177`, accent orange `#F4A574` (texte `#1C1815` dessus, jamais blanc), vert `#2D7D46` / `#5BA674`, danger `#F87171`, overline monospace `#C08A5A`. Aucune ombre portée : les surfaces se distinguent par bordure et rayon.

## Tours 12–14 — transfert, boutique, notifications, recherche, événements, ambassade, appels, onboarding

| Écran | Fichier cible | Points clés |
|---|---|---|
| **12a Envoyer de l'argent** | `send_money_screen.dart` | Stepper sur une ligne (Bénéficiaire coché → Montant → 3), bénéficiaire en carte avec moyen de paiement masqué (`***4721`) et « Changer » ; **montant en 44 px** `#1C1815` + devise 22 px + sélecteur, 4 montants rapides (actif `#B85E24`) ; carte verte `#F0F4EA` « Hadiza recevra — 32 790 FCFA » + taux et durée de garantie en monospace ; récapitulatif frais / total débité **avant** le CTA, le bouton portant le total (« Continuer · 51,50 € ») ; délai 24 h avec `icon_clock`. |
| **12b Boutique** | `marketplace_screen.dart` | Grille 2 colonnes, image 118 px, **prix en premier** (15 px w700), titre, puis vendeur (avatar 20) + ville ; filtre pays fusionné dans la barre de recherche ; chips de catégories scrollables ; panier avec badge ; FAB étendu « Vendre ». |
| **12c Notifications** | `notifications_screen.dart` | Les **six onglets deviennent trois filtres** (Tout / Non lues + badge / Mentions) ; non-lues en cartes `#FBF1E9` bordées `#F0DCCB` avec **actions en ligne** (J'y vais, Accepter/Refuser) et point d'état ; lues en lignes calmes datées en monospace ; « Tout lire » en bouton d'en-tête. |
| **12d Recherche** | `search_screen.dart` | Recherches récentes en chips avec `icon_clock` + « Effacer » ; filtres **avec compteurs** (Tout 21 · Membres 12 · Groupes 4 · Discussions 5) ; résultats groupés en cartes, terme surligné (`<mark>` `#F7E0CE`/`#8C491A`), action directe par ligne (Suivre / Voir). |
| **13a Événements** | `events_screen.dart` | Onglets À venir / Passés + chips (Tout, Près de moi, En ligne, Gratuits) ; carte héro avec **pastille de date** flottante et badge Gratuit ; cartes compactes avec badges « En ligne » `#E3EDF7`/`#1976D2` ou « Complet » `#FBE9E5`/`#C23E2D` ; participants en avatars empilés ; bouton Participer sur chaque carte, « M'avertir » si complet ; regroupement Cette semaine / Plus tard. |
| **13b Ambassade** | `embassy_detail_screen.dart` | Bandeau d'état vert (ouvert / ferme à 16 h + adresse + distance) — en rouge `#FBE9E5` pour « Temporairement fermé » avec date de réouverture ; badge « Compte officiel vérifié » (`icon_check_circle` `#1976D2`) ; 4 actions (Demande plein `#1976D2`, Contacter, Appeler, Y aller) ; onglets Infos / Activités / Actualités en segments pleins ; services consulaires avec **délai annoncé** ; horaires en monospace + juridiction. |
| **13c Appels** | `call_history_screen.dart` | Manqués annoncés dès le sous-titre `#C23E2D` ; filtres Tout / Manqués (badge) / Entrants / Sortants ; chaque ligne = **type · heure · durée** avec icône directionnelle, nom en rouge si manqué, regroupement des appels répétés (« 2 appels ») ; bouton de rappel audio ou vidéo à droite (40 px) ; rappel du geste de balayage en carte pointillée. |
| **14a–14e Onboarding** | `onboarding_intro_screen.dart` | Cinq écrans en tokens **Organic** (Caprasimo 30 px + Figtree) : Bienvenue, Découvrez les membres, Rejoignez des groupes, Participez aux événements, Restez connectés ; illustration placeholder 300 px rayon 28 ; deux bénéfices cochés par écran ; indicateur de progression à puce active allongée (26×8) ; « Passer » en haut à droite ; « Suivant » en pilule 52 px, **« Commencer » pleine largeur 54 px** au 5ᵉ écran, qui demande au passage notifications et localisation (avec la réciprocité expliquée) et propose « Plus tard, sans autorisations ». |

## Tours 15–16 — entrée dans l'app et écrans transactionnels

| Écran | Fichier cible | Points clés |
|---|---|---|
| **15a Connexion** | `login_screen.dart` | Promesse avant le formulaire (Caprasimo 29 px + phrase de valeur), « Continuer avec Google » en premier puis séparateur « ou », libellés **au-dessus** des champs, « Oublié ? » sur la ligne du libellé mot de passe, aide sous le champ (« Au moins 6 caractères »), rappel du chiffrement en pied. |
| **15b Inscription** | `register_screen.dart` | Erreurs **en langage clair** (« Il manque la fin de l'adresse, par exemple .com ») avec bordure `#C23E2D` + `icon_error` ; jauge de robustesse du mot de passe en 3 segments ; confirmation validée par `icon_check_circle` ; CGU / confidentialité en 11,5 px sous le CTA. |
| **15c / 15d / 16f / 16g Configuration** | `profile_config_screen.dart` | Barre de progression 4 segments + « n/4 » ; **1/4** photo (initiales par défaut), nom, <b>nom d'utilisateur `@` avec vérification de disponibilité</b> (champ à ajouter au modèle), profession en liste fermée ; **2/4** pays + ville actuelle, origine au Niger optionnelle, partage de position avec réciprocité expliquée ; **3/4** centres d'intérêt en puces cochables + notifications utiles ; **4/4** thème clair / sombre / auto en **aperçus miniatures**, couleur d'accent, récapitulatif « profil complété à 100 % ». |
| **16a Détail produit** | `product_detail_screen.dart` | Galerie 280 px avec pagination, **prix 26 px** + compteur de vues, titre, catégorie et ancienneté, description, carte vendeur avec « Voir le profil », deux statistiques (vues / publié), barre fixe « Contacter » + « Ajouter au panier ». |
| **16b Panier** (+ **16h** vide) | `cart_screen.dart` | Titre « Panier (n) » + « Vider », articles groupés par vendeur (une commande par vendeur), sélecteur de quantité 44 px, total, CTA portant le montant. État vide : « Votre panier est vide » + « Découvrir les produits » + deux produits populaires. |
| **16c Transferts** (+ **16i** vide) | `transaction_history_screen.dart` | Filtres alignés sur `TransactionStatus` (En attente, En cours, Terminé, Échoué, Remboursé, Annulé) ; transfert en cours en carte avec **suivi en trois étapes** (proposition à valider) et arrivée estimée ; historique groupé par mois, montant en euros **et** en FCFA, échec barré + remboursé ; FAB « Envoyer ». État vide : promesse (opérateurs, frais annoncés, 24 h) + bénéficiaire enregistré + « Ajouter un bénéficiaire ». |
| **16d Demande administrative** | `administrative_request_screen.dart` | Type de démarche en radios avec délai et tarif, pièces à joindre cochées une à une, message optionnel, transmission chiffrée annoncée. **⚠️ Fichier non relu** : délais, tarifs et liste de pièces sont des propositions à confirmer. |
| **16e Créer un événement** | `create_event_screen.dart` | Affiche en zone pointillée (3:2), titre, date + heure, format Sur place / En ligne, lieu, participants max, prix, diffusion aux groupes, « Aperçu » + « Publier ». **⚠️ Fichier non relu** : participants max, prix et diffusion aux groupes sont des propositions à confirmer contre `EventEntity`. |

## Tours 17–19 — ambassades et annuaire business

| Écran | Fichier cible | Points clés |
|---|---|---|
| **17a / 19b Ambassades** | `embassies_screen.dart` | Recherche par nom, pays ou ville ; **regroupement par zone** (Près de vous, Europe, Amérique du Nord) ; la représentation la plus proche en carte avec état d'ouverture et trois actions (Demande, Contacter, Y aller) ; drapeau emoji par pays (`ProfileOptions.countries`) ; état « temporairement fermé » en rouge. |
| **17b Contacter l'ambassade** | `embassy_message_screen.dart` | Les cinq types réels en puces (Question générale, Demande de service, Réclamation, Renseignement, Suivi de dossier) ; Objet et Message marqués <b>*</b> avec leur règle sous le champ (« Au moins 5 caractères ») ; pièce jointe optionnelle ; mention « votre message sera transmis à l'ambassade » placée <b>au-dessus</b> du bouton. |
| **17c / 19a Annuaire** | `businesses_screen.dart` | Recherche + filtre ville (chip fermable) ; carte entreprise : badges Vérifié / Premium, note + nombre d'avis, état OUVERT / FERMÉ, **offre en cours** mise en avant ; FAB « Ajouter ». |
| **17d Fiche entreprise** | `business_detail_screen.dart` | Bandeau, note · vues · état sur une ligne ; actions Contacter / Appeler / Itinéraire / Partager ; offre avec **code promo** et date de validité ; horaires avec le jour courant en tête et « Fermé » ; dernier avis + « Écrire un avis » en barre fixe. |
| **18a État vide** | idem | Recherche et filtres conservés, message situé (« Aucun résultat pour “coiffure” à Montreuil »), deux échappatoires, invitation à référencer son commerce. |
| **18b Créer une entreprise** | `create_business_screen.dart` | Étape 1/2 : couverture, nom, catégorie en puces, description, adresse avec « Ma position », téléphone / e-mail ; le CTA annonce l'étape suivante. **⚠️ Fichier non relu** : catégories et découpage en deux étapes à confirmer. |
| **18c Avis clients** | `business_reviews_screen.dart` | Note moyenne 34 px, répartition par étoiles en barres, avis avec **réponse du gérant** en encart, CTA fixe « Écrire un avis ». |
| **18d Mettre en avant** | `boost_business_screen.dart` | Trois forfaits (7 / 30 / 90 jours) en radios, un marqué RECOMMANDÉ, bénéfices cochés, CTA portant le prix, « sans reconduction automatique ». **⚠️ Fichier non relu** : durées et prix sont des propositions. |
| **19c Mes entreprises** | `businesses` (écran propriétaire) | Trois compteurs (vues, avis, **à répondre**), carte publiée avec compte à rebours de mise en avant et actions Modifier / Offres / Avis, carte « en attente de vérification » avec l'action attendue, entrée « Ajouter une entreprise ». Le compteur « avis sans réponse » est une proposition. |

## Tours 20–21 — profil, sécurité, apparence, aide

| Écran | Fichier cible | Points clés |
|---|---|---|
| **20a Modifier le profil** | `edit_profile_screen.dart` | Profession en liste fermée avec l'option **Autre** qui ouvre un champ libre ; **langues** en puces (Français, Anglais, Haoussa, Zarma, Arabe, Fulfulde, Tamashek) ; région + ville d'origine ; badge Vérifié ; « Qui peut voir mon numéro ? » en trois segments (Tout le monde / Amis / Personne). |
| **20b Appareils connectés** | `devices_screen.dart` | Compteur « 3 sur 5 » avec la règle des clés expliquée ; appareil courant encadré vert avec badge CET APPAREIL ; empreinte en monospace ; Renommer / Révoquer ; avertissement « limite atteinte ». |
| **20c Sauvegarde des clés** | `security_backup_screen.dart` | État de sauvegarde daté (appareil inclus) ; passphrase + confirmation validée ; **avertissement rouge** « n'oubliez pas votre passphrase » ; détails de la sauvegarde ; Restaurer / Sauvegarder. ⚠️ Longueur minimale et compteur de clés = propositions. |
| **20d Notifications** | `notification_settings_screen.dart` | Interrupteur maître, catégories avec conséquence en sous-titre, Messages système verrouillés. ⚠️ Seuls « Événements locaux » et « Messages système » sont issus du code ; le reste (Messages, Mentions uniquement, Transferts, **Heures calmes**) est une proposition. |
| **21a Partager mon profil** | `share_profile_modal.dart` | Carte de visite : avatar, nom, métier + ville, QR 196 px avec pastille de marque, lien copiable `diaspo.ne/u/…`, scanner et partage système. |
| **21b Comptes bloqués + Mes signalements** | `blocked_users_provider`, `my_reports_screen.dart` | Conséquences du blocage écrites (plus de messages, ni position, ni statut, la personne n'est pas informée) ; liste avec date et « Débloquer » ; signalements avec statut EN EXAMEN / TRAITÉ. ⚠️ Statuts et motifs = propositions. |
| **21c Apparence** | `profile_screen.dart`, `chat_background_picker_modal.dart` | Thème en aperçus miniatures ; langue avec option Système ; **fonds d'écran** en grille 3×2 (Par défaut, Sahel, Tissage, Nuit, Photo, La mienne) ; bascule « appliquer à toutes les discussions ». |
| **21d Aide et à propos** | `settings/*`, `support/*` | Recherche dans l'aide ; FAQ en accordéon avec la première réponse dépliée ; Nous joindre (Contactez-nous, Signaler un bug, Donner votre avis) ; bloc légal (CGU, confidentialité, code de conduite, version). |

## Tours 22–26 — support, appels, fil, discussion, transactionnel, amis

| Écran | Fichier cible | Points clés |
|---|---|---|
| **22a–22d Support** | `support/*` (`create_ticket`, `support_tickets`, `ticket_detail`) | Sujet en puces ; **rattachement du transfert concerné** ; bloc « joint automatiquement » (version, OS, appareil, langue) qui évite un aller-retour ; liste avec extrait de la réponse et bouton Répondre ; le ticket est une **conversation** (bulles) plus une carte de contexte ; état vide avec trois amorces typées. ⚠️ Catégories, priorités et statuts à confirmer. |
| **23a / 23b Appels** | `call_screen`, `group_call_screen` | Fond sombre dédié ; badge de chiffrement ; chrono et qualité de ligne ; 4 contrôles **nommés** (64 px) ; Raccrocher pleine largeur 68 px. Groupe : grille 2×2, orateur actif encadré `#5BA674`, micro coupé visible par vignette, invitation à ajouter. |
| **23c Détail d'un post** | `post_detail_screen`, `comment_tile` | Post complet, compteurs **nommés** (« 24 j'aime »), commentaires avec réponses indentées à 42 px, actions J'aime / Répondre sous chaque commentaire, composer fixe. |
| **23d Créer une publication** | `create_post_screen` | Audience dans l'en-tête (chip « Public »), saisie 17 px avec hashtag coloré + suggestions, médias avec compteur 1/4, options Sondage / Lieu, rappel de visibilité. |
| **24a Galerie** | `media_gallery_screen` | Filtres avec compteurs, grille par mois, durée sur les vidéos, documents avec poids et téléchargement, rappel de conservation 15 jours. |
| **24b Favoris** | `starred_messages_screen` | Auteur + origine (conversation ou groupe), extrait typé (texte ou note vocale), date, « Aller au message ». |
| **24c Nouvelle conversation** | `new_conversation_screen` | Champ « À : », raccourcis Nouveau groupe / Mes notes, **Proches de vous** (distance + présence) puis contacts récents. |
| **24d Résultats de sondage** | `poll_results_screen` | Barres remplies proportionnelles, option gagnante encadrée avec « votre choix », pourcentage + nombre de votes, liste des votants, rappel de visibilité. |
| **25a Événement** | `event_detail_screen` | Bandeau avec badges Gratuit / Sur place, date et lieu en **lignes actionnables** (agenda, itinéraire), organisateur contactable, participants en avatars, « Je participe » en barre fixe. |
| **25b Ma boutique** | `my_products_screen`, `my_orders_screen` | Onglets avec compteurs ; annonces avec statut EN LIGNE / VENDU, vues et messages, actions Modifier / Marquer vendu ; commandes avec statut et action de suite (« Noter »). ⚠️ Statuts de commande à confirmer. |
| **25c Transfert &amp; paiements** | `transaction_detail_screen`, `payment_accounts_screen` | Montant 34 px + contre-valeur FCFA + pastille d'état ; détail frais / taux / total ; référence copiable ; Reçu PDF / Un souci ? / Renvoyer ; moyens de paiement avec « par défaut ». |
| **26a Amis** | `friends_screen` | Filtres Amis / Demandes (badge) / Envoyées ; demandes en cartes avec **contexte** (amis en commun, rôle) et Accepter / Refuser ; liste avec métier, ville, distance et accès direct à la discussion. |
| **26b Stickers &amp; GIF** | composer de `conversation_screen` | Onglets Stickers / GIF / Émojis + recherche, Récemment utilisés puis packs, note « téléchargés une fois, envoyés sans données » (mode données réduites). |
| **26c Écrans légaux** | `settings/legal/*` | Onglets entre les trois textes, version datée + durée de lecture + export PDF, encart **« L'essentiel »** en trois garanties, corps 14 px / 1,65, pied « Nous écrire ». |

## Tours 27–28 — modales &amp; feuilles d'action

Règles communes à toutes les modales : **poignée 40×4**, titre seulement s'il apporte quelque chose, **lignes de 48 px minimum**, action destructive **isolée en bas** après un filet, phrase de conséquence sous les choix irréversibles, et le bouton **nomme son action** (« Supprimer pour tous », « Envoyer 51,50 € ») plutôt qu'un « OK ».

| Modale | Points clés |
|---|---|
| **27a Actions sur un message** | Barre de réactions 46 px en haut (dont « + »), puis Répondre / Copier / Transférer / Favoris, Supprimer isolé en rouge. |
| **27b Confirmation destructive** | Icône 48 px, délai rappelé (« envoyé il y a 4 minutes »), **deux portées explicitées** (pour tous / pour moi) avec leur conséquence, Annuler en texte. |
| **27c Signaler** | Anonymat et délai d'examen annoncés, motifs en radios avec exemple, bascule « bloquer aussi cet auteur » dans la même modale. ⚠️ Motifs à confirmer. |
| **27d Joindre un média** | Pellicule horizontale avec case cochée, **poids annoncé** + bascule « qualité réduite » (mode données réduites), 4 types en grille, CTA « Envoyer 1 photo ». |
| **28a Actions sur une publication** | Enregistrer / Partager / Copier le lien / Voir le profil, puis réglages de fil (« voir moins de ce type », ne plus suivre), Signaler isolé. |
| **28b Audience** | Quatre portées avec leur volume réel (86 personnes, 318 membres proches), « un groupe précis » en sous-navigation, bascule commentaires. |
| **28c Confirmer un transfert** | Répète bénéficiaire, montant, frais, contre-valeur et **total débité** ; moyen de paiement changeable ; délai et durée de garantie du taux ; « un transfert envoyé ne peut pas être annulé ». |
| **28d Partager dans l'app** | Recherche, destinataires en avatars sélectionnables, message d'accompagnement, puis actions externes (lien, repartage, QR, autre app), CTA nominatif. |

## Salons audio &amp; Podcasts (document séparé)

Ces deux features vivent dans `Salons audio & Podcasts.dc.html`, à part pour garder le document principal fluide. Palette **DNColors** (`lib/core/theme/dn_colors.dart`) : encre #1A1410 / #3D342B / #7A6F64 / #B8AC9D, papier #FAF6EF / #F0E8D8, sable #E8DCC4, terracotta #C85A3A / #9A3A20, ocre #D9A441, teal #2D6E6A, feuille #5A7A3A, danger #C23E2D.

| Écran | Fichier cible | Points clés |
|---|---|---|
| **1a Liste des salons** | `audio_rooms_list_screen.dart`, `audio_room_card.dart` | Catégories réelles (Tous, Discussion, Actualités, Culture, Griot/Conte, Business, Mentorat, Famille, Officiel, Spiritualité, Éducation) ; carte alignée sur le widget existant : badge EN DIRECT, titre 16, sous-titre 13, hôte (avatar r14 + nom 13), tags `#tag`, « N participants », `speakerCount/maxSpeakers`, **prix du billet avec devise** ; salon programmé avec heure **multi-fuseaux** (`schedule_room_screen` : Niamey, Paris, New York, Montréal) et « Me le rappeler ». |
| **1b Salon en direct** | `audio_room_screen.dart` | Bandeau patrimoine (« Patrimoine · langue · région », archivage annoncé) ; scène séparée des auditeurs ; pastilles de rôle **SPEAKER** (feuille) et **GHOST** (terracotta) comme `_RolePill` ; état micro **muet / actif** par vignette ; main levée en badge ocre ; barre Demander la parole / don / quitter. |
| **1c Patrimoine oral** | `heritage_library_screen.dart` | Filtres **langue** et **région** en sélecteurs, enregistrements avec langue, durée, écoutes et téléchargement, rappel de l'écoute hors ligne (mode données réduites). |
| **1d Podcasts — accueil** | `podcasts_home_screen.dart` | Bandeau « Reprendre » avec progression, abonnements en pochettes, nouveaux épisodes avec durée et **épisode payant verrouillé** (cadenas + prix). |
| **1e Lecteur** | `replay_player_screen.dart` | **Chapitres réels** (Introduction, Actualités, Diaspora &amp; politique, Q&amp;R, Conclusion), co-hôtes, molette de vitesse, ±10 s / +30 s, minuteur de sommeil, téléchargement hors ligne. |
| **1f Revenus créateur** | `creator_earnings_screen.dart` | Solde et versement programmé ; **répartition selon les clés du code** (`tips`, `tickets`, `subscriptions`, `replays`, `total`) ; historique des versements avec les vrais `PayoutStatus` (en attente, en traitement, terminé, échoué, annulé), montants stockés en centimes. |
| **1g Envoyer un don** | `send_tip_bottom_sheet.dart` | Paliers exacts **1 / 2 / 5 / 10 / 20 / 50 €**, récapitulatif « le bénéficiaire reçoit **95 %** », mot d'accompagnement optionnel, bouton « 🪙 Envoyer €x ». |
| **1h Acheter un billet** | `buy_ticket_bottom_sheet.dart` | Prix, commission, reversement à l'hôte ; trois moyens réels : **Carte bancaire**, **Wave Mobile Money**, **Mynita** (avec « Code PIN demandé pour confirmer ») ; le billet ouvre aussi le replay. |

**⚠️ Non relus** — à traiter avant implémentation, aucune maquette : `create_audio_room_screen`, `save_as_podcast_screen`, `record_episode_screen`, `ghost_moderator_screen`, `episode_detail_screen`, `my_podcasts_screen`, `create_podcast_screen`, `live_podcast_screen`, et le widget `timezone_display_widget`.

## Non traité dans ce handoff

Le **back-office admin** (19 écrans) n'a pas été repris — à traiter dans un document séparé.

## Assets

Icônes SVG copiées telles quelles depuis `assets/icons/` du dépôt : `icon_heart`, `icon_favorite_border`, `icon_chat_bubble`, `icon_send`, `icon_arrow_back`, `icon_people`, `icon_person`, `icon_person_add`, `icon_clock`, `icon_call`, `icon_video`, `icon_mic`, `icon_image`, `icon_add`, `icon_close`, `icon_done_all`, `icon_check`, `icon_check_circle`, `icon_search`, `icon_star`, `icon_pin`, `icon_pinned_message`, `icon_poll`, `icon_location`, `icon_groups`, `icon_public`, `icon_lock`, `icon_share`, `icon_event`, `icon_delete`, `icon_store`, `icon_info`, `icon_flag`. Aucune nouvelle icône n'a été dessinée. Les images sont des placeholders : à remplacer par les médias réels.

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
11. **Accueil** (`home_screen.dart`) : retirer le dégradé, ligne de contexte à la place des cartes de stats, bloc « Aujourd'hui », grille de services.
12. **Carte** (`map_screen.dart`) : en-tête unifié, légende dans un bouton, feuille à trois positions, état sans localisation.
13. **Messages / Groupes** : épinglées et types d'aperçu, recherche par catégories, badges d'activité de groupe, états vides.
14. **Profil** : identité utile, réglages sortis dans leur écran, profil incomplet.
15. **Transfert** (`send_money_screen.dart`) : montant héros, frais avant confirmation, bouton portant le total.
16. **Boutique / Notifications / Recherche** : prix et vendeur, filtres au lieu d'onglets, compteurs de résultats.
17. **Événements / Ambassade / Appels** : pastille de date et statut, bandeau d'état, type · heure · durée.
18. **Onboarding** : cinq écrans Organic + demande d'autorisations sur le dernier.
19. **Modales** : appliquer les règles communes (poignée, 48 px, destructif isolé, bouton qui nomme l'action) à toutes les feuilles existantes.
20. **Salons audio & Podcasts** : réaligner la carte de salon sur `audio_room_card`, la scène sur `_RolePill`, puis les feuilles de don et de billet.

## Fichiers de ce bundle

- `Feed & Discussion.dc.html` — le prototype complet (tours 1 à 6). Le tour 4 est marqué « ✓ VERSION RETENUE ». **Ouvrez-le dans un navigateur** : c'est la référence qui fait foi (les interactions du tour 4 y sont jouables : envoi, réactions, lecture vocale, enregistrement, rail repliable).
- `screenshots/tour-4-direction-retenue.png`, `screenshots/tour-5-mon-espace.png`, `screenshots/tour-6-nocturne.png` — captures des trois tours.
  > ⚠️ Les captures sont produites par un moteur qui ne rend pas les icônes en `mask-image` : elles apparaissent en **carrés pleins**. Les icônes réelles sont les SVG de `assets/icons/` (voir la section Assets) et s'affichent correctement dans le fichier HTML. Les captures servent à la mise en page, pas aux icônes.
- `assets/icons/*.svg` — les icônes du dépôt utilisées par le prototype (identiques aux vôtres).
- `support.js` — runtime nécessaire à l'ouverture locale du prototype (à garder à côté du fichier HTML).
