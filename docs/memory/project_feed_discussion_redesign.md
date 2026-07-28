---
name: project_feed_discussion_redesign
description: Refonte design Fil & Discussion + tours 7-28 — quasi tout l'ordre d'implémentation fait sur branche wip-jules (23 commits) ; reste = données/modèles absents + WIP user
metadata: 
  node_type: memory
  type: project
  originSessionId: b201b14c-940d-4e6c-b370-eef29b2bdbff
  modified: 2026-07-28T17:33:54.054Z
---

Refonte UI du fil (`feed`) et de la discussion (`messages`) d'après le handoff
`Amélioration feeds et discussion/design_handoff_feed_discussion/README.md`
(prototype HTML `Feed & Discussion.dc.html` = référence qui fait foi ; tour 4 =
direction retenue, tour 5 = écrans satellites, tour 6 = Nocturne sombre).

**Fait (2026-07-28, étapes 1-3 de l'ordre d'implémentation) :**
1. `FeedTokens` : ajout `textStrong` (= text), `actionLabel`, `actionMuted`, `hairline` (clair + sombre).
2. `post_card.dart` : nom auteur 15/w600, sous-ligne 12.5 mutedText, corps 15.5/height 1.6/textStrong, média rayon 20(clair)/8(sombre) h≈205, barre d'actions avec filet `hairline` + couleurs actionLabel (gauche : cœur/commentaire/repartage) / actionMuted (droite : signet/partage) + accent quand actif, icônes 19px. « Suivre » = variant texte accent (`FollowButtonVariant.text` ajouté à `follow_button.dart`, défaut `filled` inchangé pour follows_screen/reposters_screen).
3. `message_bubble.dart` : bulles opaques (retrait `BackdropFilter`+dégradés+bordure blanche, import `dart:ui` retiré) via `_bubbleDecoration()` — envoyée `#1B5E32`/`#2D7D46`, reçue `#FFFFFF`+bord `#EFE7DB` / `#252119`+bord `#3D352C` ; rayons 18 coin queue 6 ; horodatage unique sous le dernier du groupe (`_isLastInGroup`) ; **fix contraste** : time/status reçu passe de blanc 0.7 (invisible sur bulle claire) à `textTertiaryColor` (`metaColor`) ; glisser-répondre borné 90px, seuil 52px.

**Fait (2026-07-28, étapes 4-10) :**
4. `message_input.dart` : « + » hors du champ → panneau ancré grille 3×2 (`_buildAttachPanel` : Caméra/Galerie/Document/Position/Sondage/Événement ; ancien `showModalBottomSheet` conservé en repli sur appui long du « + » pour garder audio/vidéo dédiés) ; champ pilule avec emoji **à l'intérieur** ; composer opaque (retrait `BackdropFilter` blur 56 + import `dart:ui`/`AppShadows`) fond #FFFFFF/#1A1714 ; bouton vocal = pilule verte « MAINTENIR » (`_isVoicePill`, `_kVoiceGreen`) → rond d'envoi dès qu'il y a du texte ; `_buildRecordingBanner` colore le bandeau des 3 états. **Gestes d'enregistrement inchangés** (le `_buildPersistentActionButton` reste un seul GestureDetector).
5. `audio_message_bubble.dart` : `_WaveformPainter` (18 barres 4px gap 3.5, ~132×36), tête de lecture filet 2px + pastille 8px cerclée bulle, seek au clic, pilule vitesse en ligne, `pos / total` + point vert « non écouté » (`_hasBeenPlayed`). Play 44px vert(reçu)/blanc(envoyé).
6. `feed_screen.dart` : `_FeedHeader` (date `MaterialLocalizations.formatFullDate` maj + « Le fil. » point accent + recherche→`/search` + avatar `_MySpaceAvatar`→`/feed/space`), segments pleine largeur (`FeedSegmentedControl.fullWidth` ajouté), réserve basse 100px. **Filtres villes + rail d'actus non faits** (pas de source de données : ville auteur + stories).
7. `conversation_screen.dart` : sous-barre `_buildQuickSubBar` (tuiles `_SubBarTile`) = Médias→`/messages/:id/media` + bascule ÉCO liée à `PreferencesService.dataSaverMode` (feature réelle). Pastille épinglé = déjà couverte par `GroupPinnedBanner`. En-tête 58/38px non retouché (app bar existante conservée).
8. Nouveau `mon_espace_screen.dart` route `/feed/space` (déclarée AVANT `/feed/:postId`) : avatar 64, nom/@handle, 2 cartes stats (`followersCountProvider`/`followingCountProvider`), tuiles → `/profile/my-posts`, `/profile/reposts`, `/profile/saved-posts`, `/profile/follows`. Écrans tour 5 existants réutilisés tels quels (restyle segments/chips/états-vides non fait).
9. Tablette : colonne centrale bornée `maxWidth 640` centrée (largeur ≥700). Rail nav 86px + colonne droite 330px **non faits** (dupliquerait le shell + panneaux sans données).
10. Nocturne : géré par construction (tokens + `context.isDarkMode` partout) ; FAB contour indigo déjà via `fabBorder` nocturne.

**Fait (2026-07-28, 2ᵉ session — dossier `Amélioration feeds et discussion2/` = re-livraison superset : ajoute tours 7-28 + `GUIDE_IMPLEMENTATION.md` ; le spec des étapes 1-3 est identique et DÉJÀ commité, commits `eea1793`/`638e2d6`) :**
- Polish : bouton **download** dans `audio_message_bubble.dart` (notes reçues, à droite des contrôles, via `FileDownloadService.downloadToAppDirectory` + `getDownloadedPath`, coche verte `download_done`). RÉCENTS emoji = **déjà fourni par le package** `emoji_picker_flutter` (`RecentTabBehavior.RECENT` par défaut, 1er onglet catégorie) → pas de rangée custom (fighterait la nav du package).
- Restyle tour 5 : nouveau widget réutilisable `feed_empty_state.dart` (cercle 104 + icône accent, titre 21 Caprasimo, corps, amorces cliquables, CTA plein, note). Appliqué à `my_posts`, `reposts`, `saved_posts`, `follows`. `saved_posts` = chips Tout/Photos/Vidéos/Textes (filtre client par `PostMediaType`) + regroupement Cette semaine/Plus ancien (`SliverMainAxisGroup`). `follows` = `FeedSegmentedControl.fullWidth` avec compteurs (remplace `TabBar` souligné) ; recherche + suggestions **omises** (liste = IDs, noms async → pas de filtre fiable, pas de provider suggestions).
- Feed (`feed_screen.dart`) : **filtre PAYS** (pas ville — `PostEntity` n'a que `authorCountry`, pas de `authorCity`) en chips scrollables sur téléphone + panneau dans le rail droit tablette ; filtre **client sur posts chargés** (pas de filtre serveur). **Rail d'actus/stories NON fait** (aucun modèle). Layout tablette (≥700) = colonne centrale bornée 640 + **rail droit 330px** (`_FeedRightRail` : filtres pays + hashtags du moment dérivés de `PostEntity.hashtags`, tap → `/feed?hashtag=`) ; **pas de rail nav gauche** (géré par le shell, éviterait la double nav) ; FAB 64px sur tablette.
- l10n : ~20 clés ajoutées dans `app_fr.arb`+`app_en.arb` (titres/corps états vides, videos/texts, older, trendingHashtags, noPostsForFilter…). `flutter analyze` = 0 issue sur tous les fichiers touchés. Pas de vérif device.

**Fait (2026-07-28, 3ᵉ session — suite de l'ordre d'implémentation, commités+poussés sur `wip-jules-2025-12-29T23-58-34-776Z`) :**
- **Étape 11 Accueil** (`home_screen.dart`, commit `6245f94`) : dégradé orange retiré → en-tête plat, tuiles QR/notif 44px, ligne de contexte « ville · N membres · M groupes » (remplace les 3 cartes stats), bloc « Aujourd'hui » (unread `totalUnreadCountProvider` + prochain event + membres proches), services en grille 4 colonnes. Coach marks/timers/flags préservés.
- **Étape 12 Carte** (`map_screen.dart`, commit `6a69f3f`, PARTIELLE) : légende → bouton « ? » (feuille modale, retire le calcul `bottom: 130/290` conditionnel). **Reste (non fait, réécritures d'un écran Google Maps 3200 lignes NON testable sans device) : panneau membres en `DraggableScrollableSheet` 3 positions, en-tête unifié search+chips, écran 8c sans localisation dédié.**
- **Étape 13 Groupes** (`groups_screen.dart`, commit `fb0c02c`, PARTIELLE) : cadenas si privé + chip ville sur `_GroupCard`. **Badge ACTIF/CALME bloqué : `GroupEntity` n'expose pas `lastMessageAt` (présent au backend `group_remote_datasource.dart:318`, non mappé) → nécessiterait ajout entity+model+mapper.**

Mur récurrent : les features visuelles à fort impact dépendent de données/modèles absents (stories, ville post, activité groupe, épinglés) ou d'écrans complexes non testables sans émulateur. `messages_screen` déjà refait en `638e2d6`.

**Fait (2026-07-28, 4ᵉ session — étapes 14-20 en passes partielles sûres, commités+poussés) :**
- **14 Profil** (`bb8ca03`) : en-tête plat, e-mail retiré, avatar 84, badge vérifié, ville/pays.
- **15 Transfert** (`4834e44`) : bouton porte le total débité.
- **16 Boutique** (`546998a`) : prix en premier sur `product_card`.
- **17 Événements** (`dede863`) : badge « Complet » (attendeeIds>=maxAttendees).
- **Déjà alignés (aucun changement) :** historique d'appels §12 (`_CallHistoryItem` : manqués en rouge, icône directionnelle, type·heure·durée), onboarding §15 (skip top-right, puce active 32×8, CTA pleine largeur), `send_tip_bottom_sheet` §17 (paliers 1/2/5/10/20/50, « 95% », handle 40, bouton « Envoyer €x ») — la feature audio_rooms a été bâtie sur la maquette.
- Ces « réécritures larges » ont **toutes été faites en 5ᵉ session** (ci-dessous).

**Fait (2026-07-28, 5ᵉ session — les réécritures larges + modales + reconcile, tout commité+poussé sur `wip-jules-2025-12-29T23-58-34-776Z`) :**
- **Notifications 6→3** (`b97ce16`) : enum `{all,unread,mentions}`, TabBar 6 onglets → 3 puces (Tout / Non lues+badge / Mentions), TabController retiré. « Mentions » = pas de `NotificationType` dédié → regroupe types perso (friendRequest, newFollower, groupInvite, eventAttendance, nearbyMember…).
- **Recherche compteurs** (`a3bf6b0`) : `_resultCountFor` sur listes brutes de `SearchState` (indépendant du filtre actif, masqué sans requête).
- **Groupes badge ACTIF/CALME** (`13e4536`) : PAS un champ mort sur `GroupEntity` — `lastMessageAt` vit sur la conversation liée (`conversations.groupId`), pas le doc groupe. Nouveau `groupLastActivityProvider` (Map<groupId,DateTime>) dérivé de `conversationsProvider` DÉJÀ chargé → live, zéro requête. `_GroupCard`→ConsumerWidget. ACTIF si <24h.
- **Transfert montant héros + stepper** (`b1230c4`) : Stepper natif → indicateur 1 ligne (rond 22px + barres accent/à-venir #B85E24/#E8DFD4) + contenu scroll + barre boutons fixe (principal porte le total). Montant 40px w700 ls -1.5 + devise en pastille (PopupMenuButton sur `_transferCurrencies`) + 4 montants rapides. Retrait `_amountValid`/`_getCurrencySymbol`/`_buildTransferCurrencyItems`.
- **Profil réglages 7→3** (`4fa4a1c`) : 5 sections → 3 ExpansionTiles repliables (`_buildSettingsGroup`) avec état en sous-titre. **Choix : grouper EN PLACE, pas naviguer vers `SettingsScreen`** (hub orphelin, route `/settings` commentée) car il ne réplique pas tout (noiseSuppression/chatBackground/keyBackup) → sinon perte d'accès. Mon espace + zone danger restent séparés.
- **Carte panneau membres** (`a144bbf`) : `Positioned+AnimatedSwitcher` → `DraggableScrollableSheet` snap 18/45/92%, liste verticale `_buildMemberSheetItem` (avatar 44, métier·ville, bouton 40px). Retrait masquer/rouvrir (`_isMembersPanelHidden`, `_buildMembersReopenChip`). Bloc ~270 lignes remplacé par script python paren-matching (trop grand pour Edit exact).
- **Carte 8c sans localisation** (`6bfdcdd`) : body → `_buildNoLocationScreen` quand `_isReciprocityRestricted` (cercle 104 + réciprocité + 3 garanties + CTA ACTIVER + repli Ambassades/Groupes). Ancien bandeau chips = branche morte laissée.
- **Ambassade bandeau** (`95e5fe9`) : bandeau unifié vert « Ouvert »+horaires du jour / rouge « Temporairement fermé »+réouverture. PAS de « ouvert maintenant » (format `openingHours` back non garanti) → `_todayHours()` best-effort clé jour FR/EN.
- **Modales §16** : suppression msg `ee2dcaa` (délai rappelé + destructif isolé sous filet), signalement `36a3841` (bascule « bloquer aussi cet auteur » via `blockUserNotifierProvider` + anonymat/48h annoncés), CTA média `bec5867` (`media_preview_screen` FAB→FAB.extended « Envoyer la photo/vidéo/document »). `_showAttachmentOptions` déjà §16-conforme. Passe complète ~43 feuilles = tail incrémental non fait.
- **Reconcile travaux d'autres sessions dans l'arbre** : `e33c6eb` épinglage photo/vidéo (onLongPress→menu complet sur OptimizedImageBubble/VideoBubble + câblage message_bubble + `_refreshPinnedBanner` conversation_screen + ciphertext-safety group_pinned_banner) ; `ecddbf1` chore dart format datasource. **Méthode d'audit avant commit : `git diff -w` pour séparer reformat de logique.**

**Reste :** `message_input.dart` = WIP user non commité (composer flottant, supprime pilule MAINTENIR) — laissé tel quel. Non faits (bloqués données/décision) : rail stories/actus, filtre par **ville**/serveur, en-tête carte unifié search+chips, passe modales complète (~43 feuilles), Salons/Podcasts restants, back-office admin. Aucune vérif device (pas d'émulateur) — les gros changements de gestes (map sheet, transfert stepper) à valider à la main. Voir [[project_feed_roadmap.md]], [[project_message_dedup_typing.md]], [[project_supabase_over_firebase.md]].
