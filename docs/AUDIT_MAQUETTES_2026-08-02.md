# Audit maquettes vs code — 2026-08-02

Comparaison composant par composant entre les maquettes fournies (3 PDF) et
l'implémentation Flutter actuelle. Réalisé par 4 agents en parallèle, chacun
ayant lu les images des maquettes et le code source correspondant.

**Périmètre couvert** :
- `Salons audio - Podcasts.pdf` (21 maquettes, cover : "Salons, patrimoine oral, podcasts, revenus")
- `1.pdf` = "États vides et erreurs" (11 maquettes, cover : "Fil, carte, transferts, boutique, groupes")

**Périmètre NON couvert** : `Feed - Discussion.pdf` était vide (0 octet) au
moment de l'audit — le fichier source a échoué à l'export/téléchargement. À
re-générer et auditer séparément si besoin.

**Verdict global** : aucune des 32 maquettes vérifiées n'est strictement
conforme au pixel/texte près. Les écarts vont de simples différences de
libellé à des fonctionnalités entièrement absentes ou non câblées.

---

## État au 2026-08-03 (mise à jour après remédiation)

Les 9 écarts critiques sont **tous traités**, ainsi que les écarts qui
étaient de vrais défauts fonctionnels. Détail par commit dans `git log`.

| Écart critique | État |
|---|---|
| #1 Bibliothèque du patrimoine orpheline | ✅ route `/audio-rooms/heritage` + 2 points d'entrée |
| #2 Modération fantôme non fonctionnelle | ✅ sélecteur de participant + bypass `canModerate` + clause admin RTDB |
| #3 Statistiques podcast absentes | ✅ écran + route (sans série temporelle : aucune donnée datée n'est stockée) |
| #4 Pas d'enregistrement en direct | ✅ enregistrement micro (waveform et chapitrage en direct non faits) |
| #5 Fil sans cache hors-ligne | ✅ cache Hive + bandeau daté |
| #6 4 échecs réseau non distingués | ✅ les 4 cas, dont la publication non envoyée |
| #7 État vide de la Carte minimal | ✅ Dézoomer / Voir les ambassades (« Inviter un proche » non fait) |
| #8 Écran de reconnexion absent | ✅ bilan de reprise (Envoyé en priorité / Reçu pendant votre absence) |
| #9 Transferts, 2 états manquants | ✅ taxonomie complète — **mais inatteignable** : rien ne remplit `failureReason` |

**Écarté volontairement**, faute de backend : le bouton « M'alerter » de la
recherche boutique (3c) — aucune table d'alertes ni déclencheur de
notification, le bouton ne pourrait jamais se déclencher.

**Polish visuel : fait le 2026-08-03** (commits `polish(...)`). Couvre 3c
(textes fantôme, 3 cartes, « Avertir l'hôte »), 2a (en-tête + ✕, ordre des
sections, sous-titres d'interrupteurs, « Programmer »), 2b (introduction,
« HEURE LOCALE DES MEMBRES », qualificatifs de créneau, rappel local), 1a/2g
(durée et sous-titre patrimoine sur les cartes, CTA en pilule large), 1b
(bandeau ★ + archivage, « Voir tout »), 1c (compteur, bandeau
téléchargement, pastille de langue), 1e (pastilles de chapitres), 3b (tri),
2c (note patrimoine), 1d (sous-titre), 1a accueil (placeholder au singulier,
« Voir les événements en ligne »).

**Reste ouvert, et pourquoi** :
- **Comptages de ville** (« Rouen compte 4 membres », « les 4 membres de
  Rouen seront prévenus ») : demande un décompte des membres d'une ville
  indépendant du partage de position. Cette requête n'existe pas — la liste
  « autour de vous » ne contient que ceux qui partagent leur position. Un
  chiffre inventé serait pire que son absence.
- **Structure onglets vs page unique** (1c/1d/2e) : refonte de navigation,
  pas du polish. À décider séparément.
- **Thème sombre forcé du lecteur d'épisode** (1e/4b) : l'app suit le thème
  système ; forcer le sombre sur un seul écran irait contre ce choix.
- **Invités d'un épisode** et **cloche de notification par podcast** :
  demandent un champ de données et un backend qui n'existent pas.

---

## 🔴 Écarts critiques (bugs ou trous fonctionnels)

Ce qui mérite un traitement prioritaire, au-delà du polish visuel :

1. **Bibliothèque du patrimoine orpheline** — `heritage_library_screen.dart`
   n'est référencé dans **aucune route** de `audio_rooms_routes.dart`. Le
   lien "Patrimoine oral" affiché dans l'état vide des salons (2e) ne mène
   nulle part dans l'app actuelle.
2. **Modération fantôme non fonctionnelle** — dans `ghost_moderator_screen.dart`,
   3 des 4 boutons d'action ("Muet en silence", "Exclure", "Bloquer partout")
   ont `onTap: () {}` (lignes 144, 149, 154) : ils ne font rien. Aucune
   sélection de participant n'existe non plus, alors que ce pattern est déjà
   implémenté côté hôte dans `audio_room_screen.dart` (`_ModerationPanel`,
   lignes 656-864) et n'a simplement pas été porté sur l'écran admin.
3. **Statistiques podcast absentes** (maquette 4a) — aucun écran, et le
   modèle de données (`PodcastEntity`, `PodcastEpisodeEntity`) ne porte ni
   série temporelle ("écoutes par semaine") ni ventilation géographique.
4. **Pas d'enregistrement audio/vidéo en direct** (maquette 2d,
   `record_episode_screen.dart`) — l'écran n'est qu'un formulaire d'import
   de fichier existant (`FilePicker`/`VideoUploadService`). Pas de waveform,
   pas de minuteur d'enregistrement, pas de marquage de chapitre en direct.
5. **Fil sans cache hors-ligne** (maquette 2a) — aucune référence à
   "offline"/"cache" dans `lib/features/feed/`. Hors connexion, le fil
   affiche l'erreur générique plutôt que les publications déjà en cache.
6. **3 des 4 cas d'erreur réseau non distingués dans le Fil** (maquette 2b)
   — seul "message non envoyé" existe, mais dans `message_bubble.dart`
   (Messages), pas dans le Fil. "Pas de connexion", "panne serveur" (avec
   countdown) et "réseau lent" (mode données réduites) n'ont aucune UI dédiée.
7. **État vide de la Carte minimal** (maquette 2c) — réduit à un texte
   "Aucun membre à proximité" ; aucun des boutons de la maquette (Dézoomer,
   Voir les N ambassades, Inviter un proche) n'existe.
8. **Écran de reconnexion après coupure absent** (maquette 3b) — seule une
   bannière minimale (`OfflineBanner`/`NetworkStatusBanner`) existe, sans
   détail par élément ni sections "Envoyé en priorité"/"Reçu pendant votre
   absence".
9. **Transferts — 2 des 4 états manquants** (maquette 3a) — le modèle
   `TransactionStatus` (`transaction_entity.dart:31-38`) n'a que 6 statuts
   génériques (`pending, processing, completed, failed, refunded, cancelled`).
   "État incertain" et "bloqué chez l'opérateur mobile money" n'ont ni statut
   ni UI dédiée.

---

## Partie 1 — Salons audio & Podcasts

### Salons audio

#### 3c — Modération fantôme (admin)
**Fichier** : `lib/features/audio_rooms/presentation/screens/ghost_moderator_screen.dart`
**Verdict : Écarts significatifs**

- Bandeau d'invisibilité : maquette "Vous êtes invisible : ni l'hôte ni les
  participants ne voient votre présence." vs code `l10n.ghostInvisibleNotice`
  = "Vous êtes invisible. Actions loggées." (texte différent, plus court).
- En-tête : maquette = texte "MODÉRATION · 42:18". Code = badge pilule
  "GHOST · SuperAdmin" (`l10n.ghostSuperAdminBadge`, ligne 50) — libellé et
  forme différents, pas de durée dans l'en-tête.
- Grille de stats : maquette montre 3 cartes (auditeurs visibles, intervenants
  visibles, durée). Le code (lignes 100-123) affiche 4 cartes en grille 2×2,
  avec une carte "Signalements" absente de la maquette. Libellés anglicisés
  ("Auditeurs"/"Speakers") au lieu de "auditeurs visibles"/"intervenants
  visibles".
- **Écart fonctionnel majeur** : la maquette montre "PARTICIPANT SÉLECTIONNÉ"
  et "AUTRES PARTICIPANTS" permettant de choisir la cible des actions — rien
  de tout cela n'existe. Les 4 boutons sont génériques, non liés à un
  participant.
- 3 des 4 actions (Muet en silence, Exclure, Bloquer partout) ont
  `onTap: () {}` (lignes 144, 149, 154) : elles ne font littéralement rien.
  Seul "Avertir" appelle `warnHost(...)` avec un message fixe.
- "Avertir" affiche "Avertir" vs maquette "Avertir l'hôte".
- "Fermer le salon de force" est présent et fonctionnel, avec une boîte de
  confirmation supplémentaire (amélioration non prévue en maquette).

#### 2a — Ouvrir un salon
**Fichier** : `lib/features/audio_rooms/presentation/screens/create_audio_room_screen.dart`
**Verdict : Écarts**

- En-tête : maquette = "Ouvrir un salon" + "✕". Code = AppBar "Créer un salon"
  (`l10n.audioRoomCreateRoom`) + sous-titre "configuration complète" (absent
  de la maquette), pas de bouton "✕".
- Ordre des sections différent : maquette place "Contenu patrimoine" avant
  "Salon payant" ; le code fait l'inverse (§8 puis §10, ligne 291).
- Champs additionnels absents de la maquette : Description, "Salon privé",
  "Vidéo activée", "Enregistrement activé" (lignes 196-201), section "Lié à"
  (Événement/Groupe/Ambassade), note règles admin.
- Les switches (`_SwitchRow`, ligne 442) n'affichent qu'une ligne de texte —
  pas de sous-titre explicatif comme en maquette.
- Bloc capacité codé en dur en anglais : `'10 speakers · 1 000 listeners'`
  (ligne 335) — non localisé, incohérent avec le reste en français.
- Bouton bas : code = `l10n.later` = "Plus tard" vs maquette "Programmer"
  (comportement correct, seul le libellé diffère).
- Le titre saisi n'est pas transmis à l'écran "Programmer" au clic
  (`context.push('/audio-rooms/schedule')`, ligne 360, sans `extra`).

#### 2b — Programmer un salon — multi-fuseaux
**Fichier** : `lib/features/audio_rooms/presentation/screens/schedule_room_screen.dart`
**Verdict : Écarts**

- Paragraphe d'intro de la maquette absent du code.
- Sélecteur d'heure : maquette a heure + ville de référence modifiable
  ("Paris ⌄"). Code (`_HourPicker`, ligne 278) n'affiche qu'un libellé
  statique `l10n.niamieyTimezoneLabel` = "GMT+1 · Niamey" — pas de dropdown,
  ville par défaut différente de la maquette.
- Titre de section : code "FUSEAUX HORAIRES" vs maquette "HEURE LOCALE DES
  MEMBRES".
- Qualificatifs par ligne ("Bonne heure · soirée", "Midi · en journée")
  absents du code (`_TimezoneRow`, ligne 315).
- Le code ajoute un `Switch.adaptive` par fuseau, absent de la maquette.
- Toggle "Prévenir mes abonnés" (avec sous-texte rappel 15 min) absent — le
  code affiche une note statique non interactive (`scheduleRoomCaveat`,
  lignes 140-144).
- Bouton final statique "📅 Programmer ce salon" (ligne 385) au lieu du texte
  dynamique "Programmer le 2 août à 18:30" de la maquette.
- Titre du salon créé codé en dur : `l10n.scheduleNewRoomLabel` = "Nouveau
  salon" (ligne 151).

#### 2e — Aucun salon en direct (état vide)
**Fichier** : `lib/features/audio_rooms/presentation/screens/audio_rooms_list_screen.dart` (`_EmptyState`, ligne 624)
**Verdict : Écarts significatifs**

- Maquette : illustration + titre + paragraphe + 2 cartes d'action ("Ouvrir
  un salon" / "Patrimoine oral") + section "Programmés cette semaine" sur le
  même écran.
- Code : emoji 🎙 + `l10n.audioRoomsNoLiveRooms` = "Aucun salon live" +
  `l10n.audioRoomsNoLiveSubtitle` = "Soyez le premier à démarrer" — texte
  court, aucune carte d'action.
- **Écart structurel transversal** (concerne aussi 2g/1a) : la maquette
  combine "En direct" et "Programmés" sur un seul écran scrollable. Le code
  sépare en deux onglets (`DnTabBar`) — il faut changer d'onglet pour voir
  les salons programmés.
- Le lien "Patrimoine oral" n'a nulle part où pointer (cf. écart critique #1).

#### 2g / 1a — Salons — liste (Nocturne / clair)
**Fichier** : `lib/features/audio_rooms/presentation/screens/audio_rooms_list_screen.dart`
**Verdict : Écarts**

- Sous-titre header : maquette "6 en direct · 2 programmés". Code :
  `l10n.audioRoomsAvailableCount` = "{count} salons disponibles" (total
  combiné, pas de répartition).
- Filtres : maquette = 4 onglets catégorie sans séparation Live/Programmés.
  Code superpose le `DnTabBar` Live/Programmés **et** 11 catégories
  (`_categories`, lignes 39-42) — plus chargé.
- Carte de salon (`_LiveCard`, ligne 242) : pas de badge durée ("42 min"),
  pas de sous-titre "Patrimoine · Zarma · Tillabéri". Le bouton affiche
  toujours `l10n.join` ("Rejoindre"), jamais "Billet" même pour un salon
  payant — la logique d'achat existe (`_handleTap`, ligne 254), seul le
  libellé ne change pas.
- CTA principal : maquette = large bouton pilule "Ouvrir un salon". Code =
  petit FAB circulaire icône seule (52×52px, `_CreateFab`, ligne 523) + un
  second petit bouton "📅 Programmer" — moins proéminent.
- Couleurs pilotées par `context.dn` (thème dynamique) dans tout l'écran —
  le mode Nocturne est probablement supporté au niveau des couleurs, mais
  non vérifié visuellement (pas de rendu réel disponible).

#### 1b — Salon en direct
**Fichier** : `lib/features/audio_rooms/presentation/screens/audio_room_screen.dart`
**Verdict : Écarts**

- En-tête (`_RoomHeader`, ligne 325) : maquette combine "EN DIRECT · 42 MIN ·
  128 AUDITEURS". Le code n'affiche que le nombre d'auditeurs — **la durée
  écoulée n'apparaît pas**. L'icône de partage (en haut en maquette) est
  reléguée dans le footer.
- Bannière patrimoine (`_ModeBanner`, lignes 127-133) : icône 📚 au lieu de
  ★, texte sans "— ce salon sera archivé".
- Section auditeurs : pas de lien "Voir tout" (`ListenerGrid` ne propose
  qu'un pictogramme "+N").
- Pied de page (`_RoomFooter`, ligne 948) : 4 boutons (✋ Lever la main,
  🪙 Tip, ↗ Partager, Quitter) contre 3 éléments visibles en maquette.

#### 1c — Bibliothèque du patrimoine
**Fichier** : `lib/features/audio_rooms/presentation/screens/heritage_library_screen.dart`
**Verdict : Écart critique — écran non accessible + design très différent**

- **Aucune route ne mène à cet écran** (cf. écart critique #1) — le fichier
  existe et le code est fonctionnel, mais orphelin.
- Contenu très différent : maquette = 2 filtres dropdown + compteur "24
  ENREGISTREMENTS" + liste plate + bandeau info téléchargement. Code =
  `SliverAppBar` dégradé + recherche + menu filtres + 3 onglets (Découvrir/
  Catégories/Enregistrés) + carrousel vedette + grille 8 catégories + lecteur
  plein écran. Architecture entièrement différente (tabs vs liste unique),
  pas de compteur, pas de bandeau "Téléchargez avant un trajet...".
- Tag de langue : maquette = pastille colorée "ZARMA". Code = texte brut.

#### 4c — Patrimoine oral — Nocturne
Non détaillé séparément par l'agent (couvert par le mode sombre générique de
`heritage_library_screen.dart`, cf. écart 1c ci-dessus pour le contenu).

### Podcasts

#### 4a — Statistiques d'un podcast
**Verdict : Écran absent (écart majeur)** — cf. écart critique #3. Aucun
fichier stats/analytics dans `lib/features/podcasts/`, aucun champ de série
temporelle ou géographique dans les entités.

#### 4b / 1e — Lecteur — Nocturne / Lecteur d'épisode
**Fichier** : `lib/features/podcasts/presentation/screens/episode_detail_screen.dart`
**Verdict : Écarts**

- Thème sombre non forcé : seul le `SliverAppBar` est sombre (lignes
  146-201), le reste suit le thème clair par défaut — la maquette montre un
  fond quasi-noir sur tout l'écran.
- Pas de sous-titre invités ("avec Salim B. et Aïcha M.") — aucun champ
  guests/hosts dans `PodcastEpisodeEntity` (lignes 57-141).
- Chapitres en pastilles horizontales absents — le code les liste
  verticalement plus bas (`_buildChaptersList`, lignes 554-597).
- Barre d'actions basse différente : maquette = "Hors ligne"/"Partager"/liste.
  Code (lignes 313-336) = Like/Download/Share en icône+texte.
- Contrôles de lecture fonctionnellement corrects (vitesse, ±10s/30s,
  minuterie sommeil) mais dans une `Card` classique, pas la mise en page
  compacte du mock.
- Éléments en plus non prévus au mock : stat chips play/like/download,
  section transcription, bandeau "depuis un salon live".

#### 3a — Mes podcasts (créateur)
**Fichier** : `lib/features/podcasts/presentation/screens/my_podcasts_screen.dart`
**Verdict : Écarts**

- Sous-titre carte : maquette "Hebdo · 2,00 EUR/mois" (fréquence + prix).
  Code affiche statut + catégorie (lignes 189-201) — fréquence/prix absents.
- Stats en ligne icône+texte (`_buildStat`, lignes 403-411) au lieu de 3
  pavés — données correctes, style différent.
- Aperçu épisodes sans badge "PREMIUM" ni icône casque.
- Boutons manquants : la maquette a "Voir la fiche" + "Nouvel épisode" côte
  à côte ; le code n'a que "Nouvel épisode" visible (lignes 292-299).
- Pas de carte compacte dédiée pour l'état "En pause" — le code réutilise la
  carte complète standard pour tous les statuts.
- "Créer un podcast" en `FloatingActionButton.extended` (lignes 60-64) au
  lieu d'une carte dans la liste.

#### 3b — Fiche d'un podcast
**Fichier** : `lib/features/podcasts/presentation/screens/podcast_detail_screen.dart`
**Verdict : Écarts**

- Pas de bouton cloche séparé à côté de "S'abonner" (`_buildSubscribeButton`,
  lignes 282-333).
- "Déjà abonné sur un autre appareil ?" partiellement présent (bouton
  "Restaurer mes achats" seul, lignes 448-470), sans l'encart visuel, et
  uniquement dans le flux premium.
- Pas de tri "Plus récents" — le header épisodes a un bouton "Ajouter"
  (logique créateur) à la place (lignes 203-209).
- Pas de statut "déjà écouté" (coche verte) sur `EpisodeTile`.
- Description sous un titre "À propos" (ligne 170-173), absent en maquette
  (écart mineur).

#### 2c — Publier en podcast
**Fichier** : `lib/features/audio_rooms/presentation/screens/save_as_podcast_screen.dart`
**Verdict : Conforme, avec écarts mineurs**

Correspondances fortes : titre par défaut, chapitres identiques
(Introduction/Actualités Niger/Diaspora &amp; politique/Questions-Réponses/
Conclusion, lignes 39-45), sélecteur Public/Abonnés/Privé, durée+taille.

Écarts : encart "Un salon patrimoine reste aussi dans la bibliothèque..."
absent ; chapitres non éditables (badge "AUTO" au lieu du lien "Modifier",
lignes 180-192) ; éléments en plus non prévus (motif kente auto-généré,
pourboires post-publication, lignes 157-236) ; bouton "Publier" préfixé d'un
emoji littéral 📤 (ligne 280) au lieu d'une icône.

#### 2d — Enregistrer un épisode
**Verdict : Écart majeur** — cf. écart critique #4. Formulaire d'import
uniquement (`FilePicker`/`VideoUploadService`, lignes 57-94), pas
d'enregistreur en direct, pas de waveform, pas de minuteur, chapitres ajoutés
via dialogue manuel (lignes 96-169) plutôt qu'en direct. Pas de bouton
"Brouillon" distinct. Interrupteur "Épisode premium" en plus (lignes 465-470).

#### 2f — Podcasts — aucun abonnement
**Fichier** : `lib/features/podcasts/presentation/screens/podcasts_home_screen.dart` (`_buildSubscriptionsTab`, lignes 492-563)
**Verdict : Écarts**

Titre "Aucun abonnement" correct, mais absent : icône casque, titre "Des
voix de la diaspora", liste "Populaires dans la diaspora" (3 podcasts +
boutons "S'abonner"), ligne "Créer mon podcast". Le code affiche une icône
générique + un bouton qui bascule vers l'onglet Découvrir.

#### 1d — Podcasts — accueil
**Fichier** : `podcasts_home_screen.dart`
**Verdict : Écart structurel notable**

Points conformes : bandeau "Reprendre" (lignes 201-300) quasi identique au
mock (fond sombre, label REPRENDRE, barre de progression).

Écarts : navigation par 3 onglets (Découvrir/Catégories/Abonnements, lignes
108-118) au lieu d'une page unique consolidée — les sections "abonnements"
et "nouveaux épisodes" sont dispersées ; sous-titre "3 abonnements · 1 en
cours d'écoute" absent de l'AppBar ; pas de FAB micro (création reléguée à
une `IconButton` d'AppBar) ; barre de recherche pleine largeur non prévue à
cet emplacement en maquette.

---

## Partie 2 — États vides et erreurs

### Accueil / Fil / Carte

#### 1a — Accueil complet — ville calme
**Fichiers** : `lib/features/home/presentation/screens/home_screen.dart`, `home_screen_widgets.dart`
**Verdict : Conforme (écarts mineurs de libellé)**

Header, ligne contexte ("Rouen, France · 4 membres · aucun groupe") et
sections conformes structurellement. Écarts mineurs : placeholder recherche
pluriel ("Rechercher des membres, groupes...") vs singulier en maquette ;
carte "Autour de vous" sans le comptage "Rouen compte 4 membres" ; bouton
"Voir en ligne" au lieu de "Voir les événements en ligne".

#### 1b — Autour de vous — les trois causes
**Verdict : Conforme (écart mineur CAS 1)**

CAS 1 (`_NearbyEmptyCard`, lignes 468-600) : titre et boutons ("Élargir à
200 km"/"Inviter un proche") conformes ; sous-titre sans le comptage de
membres. CAS 2 (`_NoPositionCard`, lignes 604-681) : conforme à l'identique.
CAS 3 squelette (`_NearbyAvatarLoading`, lignes 1590-1631) : conforme.

#### 1c — Événements — les trois causes
**Verdict : Conforme (écarts mineurs CAS 2/3)**

CAS 1 (`_EventsOnlineOnlyCard`, lignes 1143-1251) : conforme. CAS 2
(`_EventsEmptyCard`, lignes 1030-1109) : titre/chips/bouton conformes ;
sous-titre sans la mention "les 4 membres de Rouen seront prévenus". CAS 3
(`_EventsPastCard`/`_NotifyNextToggle`, lignes 1255-1426) : conforme, sauf la
phrase "Soyez averti du prochain." absente du sous-titre (le sens est repris
par le toggle en dessous).

#### 2a — Hors ligne — le fil garde son cache
**Verdict : Non implémenté** — cf. écart critique #5. Aucune référence
offline/cache dans `lib/features/feed/`. Un `OfflineBanner` générique existe
dans `lib/shared/widgets/` mais n'est utilisé nulle part dans home/feed/map.

#### 2b — Les quatre échecs, distingués
**Verdict : Non implémenté (3/4 cas)** — cf. écart critique #6.

- CAS 1 "Pas de connexion" : non trouvé, `feed_screen.dart:280-300` affiche
  un texte générique + un seul bouton "Réessayer".
- CAS 2 "Nos serveurs ne répondent pas" (countdown) : non trouvé.
- CAS 3 "Réseau lent" : non trouvé.
- CAS 4 "Message pas envoyé" : **implémenté**, mais dans
  `lib/features/messages/presentation/widgets/message_bubble.dart:2558-2579`
  (le code cite explicitement la maquette 2d en commentaire), pas dans le Fil
  (`post_card.dart` n'a aucune gestion pending/failed).

#### 2c — Carte plein écran — aucun repère
**Verdict : Non implémenté** — cf. écart critique #7.
`map_screen.dart:3350-3374` affiche seulement "Aucun membre à proximité".
Écart structurel additionnel : pas d'onglets Membres/Commerces/Ambassades
(remplacés par des chips de filtre métier + calques superposés).

#### 2d — Nocturne — vides et erreurs
**Verdict : Écart(s) — implémentation partielle**

Le thème sombre générique (`lib/core/theme/adaptive_colors.dart`) s'applique
automatiquement aux composants déjà conformes (Autour de vous, Événements,
bandeau hors-ligne accueil, message non envoyé). Hérite en revanche des
lacunes de 2a/2b/2c pour le Fil et la Carte.

**Constat annexe** : `home_stat_card.dart`, `home_member_card.dart` et
`quick_action_card.dart` ne sont plus importés par `home_screen.dart`
(remplacés lors d'une refonte antérieure) — code potentiellement mort à
vérifier séparément.

### Transferts / Boutique / Groupes

#### 3a — Transfert — quatre états, selon où est l'argent
**Verdict : Non implémenté** — cf. écart critique #9.

1. Refus avant débit — écart (texte/bouton générique, pas de badge "solde
   intact", pas de "Changer de carte").
2. État incertain — non implémenté.
3. Bloqué chez l'opérateur — non implémenté.
4. Remboursement — le statut existe (`refunded`) mais sans le détail de la
   maquette (carte destination, référence, question frais).

#### 3b — Reconnexion après une longue coupure
**Verdict : Non implémenté** — cf. écart critique #8. Seuls
`lib/shared/widgets/offline_banner.dart` et `network_status_banner.dart`
existent, sans détail par élément ni sections dédiées.

#### 3c — Boutique — trois vides différents
1. Rien mis en vente (`my_products_screen.dart:37-63`) — écart (texte/CTA
   différents, pas de chips catégories suggérées).
2. Aucune commande (`my_orders_screen.dart:197-221`) — écart (texte
   générique, pas de mention "Séquestre à confirmer").
3. Recherche sans résultat (`marketplace_screen.dart:493-514`) — écart
   majeur : pas de "Chercher partout · N", pas de "M'alerter", aucune
   fonctionnalité d'alerte de recherche trouvée dans le module.

#### 3d — Groupes — trois vides différents
1. Aucun groupe rejoint (`groups_screen.dart:592-653`) — texte différent de
   la maquette ; les suggestions existent (`_buildSuggestedSection`,
   lignes 140-197) mais dans une section séparée, sans lien "Voir les N
   groupes suggérés" intégré à l'état vide.
2. Rien dans ma ville — non trouvé. `groups_map_screen.dart` existe mais
   c'est une carte monde par pays, **actuellement désactivée** dans l'UI
   (icône commentée dans `groups_screen.dart:270-285`).
3. Recherche sans résultat (`search_screen.dart:273-291`) — état générique
   partagé avec tous les types de recherche, sans suggestions de groupes
   proches ni bouton "Créer «X»".

---

## Synthèse par maquette

### Salons audio & Podcasts

| Maquette | Écran | Verdict |
|---|---|---|
| 1a/2g Salons — liste | audio_rooms_list_screen.dart | Écarts |
| 1b Salon en direct | audio_room_screen.dart | Écarts |
| 1c Bibliothèque du patrimoine | heritage_library_screen.dart | **Écart critique** (orphelin) |
| 1d Podcasts — accueil | podcasts_home_screen.dart | Écart structurel |
| 1e/4b Lecteur d'épisode | episode_detail_screen.dart | Écarts |
| 1f Revenus créateur | creator_earnings_screen.dart | Écarts (devise XOF vs EUR) |
| 1g Envoyer un don | send_tip_bottom_sheet.dart | Écarts |
| 1h Acheter un billet | buy_ticket_bottom_sheet.dart | Écarts |
| 2a Ouvrir un salon | create_audio_room_screen.dart | Écarts |
| 2b Programmer un salon | schedule_room_screen.dart | Écarts |
| 2c Publier en podcast | save_as_podcast_screen.dart | Conforme (écarts mineurs) |
| 2d Enregistrer un épisode | record_episode_screen.dart | **Écart majeur** (pas d'enregistrement live) |
| 2e Aucun salon en direct | audio_rooms_list_screen.dart | Écarts significatifs |
| 2f Podcasts — aucun abonnement | podcasts_home_screen.dart | Écarts |
| 3a Mes podcasts (créateur) | my_podcasts_screen.dart | Écarts |
| 3b Fiche d'un podcast | podcast_detail_screen.dart | Écarts |
| 3c Modération fantôme | ghost_moderator_screen.dart | **Écarts significatifs** (3/4 actions non câblées) |
| 4a Statistiques podcast | — | **Absent** |
| 4c Patrimoine oral — Nocturne | heritage_library_screen.dart | Cf. 1c |

### États vides et erreurs

| Maquette | Verdict |
|---|---|
| 1a Accueil complet | Conforme (libellés mineurs) |
| 1b Autour de vous (3 cas) | Conforme (libellé mineur CAS1) |
| 1c Événements (3 cas) | Conforme (libellés mineurs CAS2/CAS3) |
| 2a Fil hors ligne + cache | **Non implémenté** |
| 2b Les 4 échecs génériques | **Non implémenté (3/4)** — CAS4 fait dans Messages, absent du Fil |
| 2c Carte — aucun repère | **Non implémenté** |
| 2d Nocturne | Partiel — hérite des lacunes 2a/2b/2c |
| 3a Transfert (4 états) | **Non implémenté (2/4)** |
| 3b Reconnexion après coupure | **Non implémenté** |
| 3c Boutique (3 vides) | Écarts (recherche sans résultat = écart majeur) |
| 3d Groupes (3 vides) | Écarts ("rien dans ma ville" = non implémenté) |

---

## Méthodologie

Les maquettes ont été extraites en images PNG depuis les PDF avec `poppler`
(pdftoppm), les 3 PDF étant en réalité des exports "Imprimer en PDF" d'une
page web de spécifications (titre de métadonnée commun : "Amélioration feeds
et discussion"). 4 agents ont travaillé en parallèle, chacun lisant les
images des maquettes de son lot puis le code Dart correspondant (lecture +
grep), pour produire ce rapport comparatif.
