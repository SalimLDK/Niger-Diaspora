# Tests à faire sur appareil physique

Récapitulatif de **tout le projet**, toutes sessions confondues, jamais
vérifié sur un vrai téléphone — les sessions ont quasi toujours tourné sans
émulateur ni appareil détecté de façon fiable (`adb devices` vide, ou
téléphone déconnecté en cours de route). `flutter analyze` et `flutter test`
sont propres partout, mais ça ne couvre ni le rendu visuel, ni les gestes,
ni les permissions runtime (caméra, localisation), ni le comportement réseau
réel (TURN/WebRTC, E2EE bout-en-bout).

Coché = vérifié sur appareil. Non coché = jamais testé. La partie 1 couvre la
refonte design Fil & Discussion (28 tours + salons/podcasts) ; la partie 2
couvre tout le reste du projet (E2EE, appels, admin, sécurité...).

---

## Session du 2026-08-03 — SM A515F, build de `118b61e`

Ce qui a été réellement exercé sur l'appareil, et ce que ça a révélé.

**Défauts trouvés, corrigés et vérifiés**

- **Aucun média ne pouvait être envoyé sur Storage** — `storage.rules` ne
  déclarait aucun bloc pour `stories/`, `posts/` ni `encrypted_media/` : les
  trois tombaient dans le `deny all` final. Donc **création de story
  impossible, média de publication impossible, pièce jointe E2EE impossible**,
  tous en `unauthorized`. Les trois blocs ont été ajoutés et déployés
  (`firebase deploy --only storage`), après quoi la story part et s'affiche.
- **Débordement de 6 px du rail de stories** à `font_scale = 1.1` (le libellé
  « Ajouter » était coupé) : hauteur figée à 96 px, désormais calculée depuis
  le `textScaler`.
- **Écran de connexion illisible quand le système est en thème sombre** — il
  n'y avait pas deux sources de vérité sur la luminosité, mais un fond figé.
  Le `Scaffold` prenait `AppColors.surfaceVariant` (crème, valeur claire
  codée en dur) pendant que les textes et les champs suivaient normalement le
  thème sombre : titre et libellés clairs posés sur un fond clair, donc
  invisibles. Même schéma sur 15 fichiers, 48 occurrences de jetons clairs
  (`textPrimary`, `textSecondary`, `textTertiary`, `background`,
  `surfaceVariant`, `border`) remplacées par les accesseurs de
  `adaptive_colors.dart`. `AuthButton` figeait en plus son fond sur blanc :
  fond et texte passent au thème par défaut. **Vérifié sur le SM A515F en
  mode nuit** : capture après correction, écran entièrement sombre,
  « Bienvenue », « Email » et le bouton Google tous lisibles.

**Défauts trouvés, non corrigés**

- **L'échec d'upload est totalement silencieux** : `_createPhotoStory`
  (`story_rail.dart`) n'attrape rien autour de `uploadImage`. La feuille se
  referme, aucun message, l'exception ne ressort que dans Crashlytics —
  l'utilisateur croit avoir publié.
- **Le compteur de vues d'une story ne bouge pas** : la feuille « qui a vu »
  liste bien la vue enregistrée, mais la pastille du viewer continue
  d'afficher « Aucune vue ». Deux sources qui ne concordent pas. Accessoirement
  la vue de l'auteur lui-même est comptée.
- **Le nom d'auteur vient de Firebase Auth, pas du profil** : story et écran
  d'accueil affichent « Sim A » (`user.displayName`) alors que le profil
  applicatif est « Salim L. ». Même inversion de priorité dans
  `profile_config_screen.dart:90` — relancer l'assistant renomme donc le profil
  avec la valeur Firebase Auth.
- **Les drapeaux d'onboarding ne survivent pas à une réinstallation** :
  `hasGivenConsent` / `profileConfigComplete` sont lus dans Firestore
  `users/{uid}`, où ils n'existent pas pour ce compte. Toute réinstallation
  (ou tout nouvel appareil) repasse donc par consentement **et** assistant de
  profil complet.
- **Accents manquants dans les coach marks** : « Appuyez ici pour acceder a
  votre profil et le completer ».
- L'écran d'introduction (`onboarding_intro_screen`) est en orange quel que
  soit le thème choisi à l'étape précédente de l'assistant.

**Interrompu** — la session Firebase du compte de test s'est invalidée en cours
de route (le routeur redirige vers `/auth/login`). Tout ce qui suit la partie
Stories n'a donc **pas** pu être exercé cette session : salons, podcasts,
messagerie, hors-ligne, écrans divers.

---

# 1. Refonte Fil & Discussion (28 tours + salons/podcasts)

## Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser)

- [x] **Viewer de stories** (`story_viewer_screen.dart`) : barre de progression segmentée, auto-avance 5s, tap gauche/droite (précédent/suivant), swipe vers le bas pour fermer, enchaînement automatique sur l'auteur suivant du rail. *(2026-08-03, SM A515F : l'image s'affiche, l'en-tête porte avatar / nom / « il y a moins d'une minute » / croix, le minuteur de 5 s tourne et ferme le viewer en fin de rail, et le glissement vers le bas ferme immédiatement. **Tap gauche/droite et enchaînement sur l'auteur suivant restent non vérifiés** : une seule story, un seul auteur — il faut un deuxième compte publiant une story.)*
- [x] **Création de story** (`story_rail.dart`) : permission caméra (première demande), permission galerie, upload, apparition dans le rail avec l'anneau correct. *(2026-08-03, SM A515F, bout en bout depuis la galerie : sélection → upload → la story apparaît dans le rail, l'avatar « + » cède la place à l'anneau accent, et le viewer la relit. **A d'abord échoué** en `unauthorized` : `storage.rules` n'avait pas de bloc `stories/`, corrigé et déployé (voir le bloc de session en tête de fichier). Aucune permission runtime n'est demandée pour la galerie — l'app passe par le photo picker système, qui n'en exige pas. **Le chemin caméra reste non testé** (permission caméra première demande).)*
- [x] **Rail de stories** : anneau dégradé (non vues) vs anneau gris (tout vu), avatar "+" quand pas de story active, défilement horizontal. *(2026-08-03, SM A515F : avatar « + » correct sans story, remplacé par l'anneau accent dès qu'une story est active. **L'anneau gris « tout vu » n'est toujours pas distinguable** — ma propre story ne bascule pas en gris après lecture, et il n'y a aucun autre auteur ; défilement horizontal multi-avatars idem. Un débordement de 6 px à `font_scale = 1.1` a été trouvé ici et corrigé.)*
- [ ] **Repli du rail au défilement** (`feed_screen.dart`/`story_rail.dart`, ajouté 2026-07-31) : `AnimatedCrossFade` déclenché à `scrollOffset > 24`, bascule vers la barre compacte (3 avatars superposés + « N récits aujourd'hui » + « Afficher »), tap sur « Afficher » qui scrolle en haut et redéplie. *(2026-08-03 : **non atteignable en l'état, faute de données** — le fil du compte de test ne contient qu'une seule publication sur les trois onglets, donc la liste ne défile pas et `scrollOffset` ne dépasse jamais 24. Il faut un fil d'au moins un écran et demi.)*
- [ ] **Story vidéo** (ajouté 2026-07-31) : sélection galerie (max 30s), upload + compression + génération de miniature, lecture avec `video_player` dans le viewer (autoplay, barre de progression synchronisée sur la position réelle au lieu du minuteur fixe 5s, passage automatique à la story suivante en fin de lecture). *(2026-08-03 : non testé, mais le blocage Storage qui l'aurait fait échouer — `stories/…/video_*.mp4` — est levé.)*
- [x] **« Qui a vu » ma story** (ajouté 2026-07-31) : le tap « N vues » (visible seulement pour l'auteur) met la lecture en pause, ouvre la feuille avec la liste (avatar/nom/heure + emoji de réaction le cas échéant), la reprise de lecture à la fermeture de la feuille. *(2026-08-03, SM A515F : la pastille est bien réservée à l'auteur, le tap met la lecture en pause — le viewer reste ouvert bien au-delà des 5 s — la feuille liste avatar / nom / heure, et la fermeture relance le minuteur, qui va au bout et ferme le viewer. **Deux réserves** : la pastille continue d'afficher « Aucune vue » alors que la feuille liste une vue, et la vue de l'auteur lui-même est comptée. L'emoji de réaction dans la liste n'est pas vérifiable en solo.)*
- [ ] **Réactions sur une story** (ajouté 2026-07-31) : barre de 6 emojis en bas du viewer (stories des autres uniquement), tap = pose la réaction, retaper le même emoji la retire (toggle), l'emoji actif doit rester visuellement mis en évidence. *(2026-08-03 : **non testable en solo par construction** — la barre n'est rendue que sur la story d'un autre auteur. Demande un deuxième compte.)*
- [ ] **Envoi groupé de médias en message** (`media_batch_preview_screen.dart`, ajouté 2026-07-31, §27d) : sélection multiple dans la galerie → pellicule de revue avec case à cocher par média, poids total qui se recalcule au décochage, bascule « qualité réduite » qui compresse réellement à l'envoi, CTA qui nomme le nombre. Le cas 1 seul média doit toujours passer par l'éditeur mono-fichier existant (non touché) — vérifier qu'aucune régression n'est apparue là.
- [ ] **Composer un sondage sur un post** (`create_post_screen.dart` → icône Sondage) : ouverture du sheet, saisie, publication du post d'abord puis création du sondage — vérifier que le sondage apparaît bien après coup sur le post publié.
- [ ] **Composer un lieu sur un post** : `LocationPickerModal` (permission localisation, recherche d'adresse, sélection sur carte), aperçu de la carte statique sur `post_card.dart`.
- [ ] **Vote sur un sondage de post** (`poll_card.dart` réutilisé) : sélection d'option, soumission, affichage des résultats après vote/expiration.
- [ ] **Panneau membres carte** (`map_screen.dart`) : `DraggableScrollableSheet` à 3 positions (18/45/92%), glisser pour changer de position.
- [ ] **Stepper de transfert d'argent** (`send_money_screen.dart`) : indicateur 1 ligne, montants rapides, changement de devise.
- [ ] **États d'échec détaillés d'un transfert** (`transaction_detail_screen.dart` + `transfer_failure_kind.dart`, ajouté 2026-08-03, maquette 3a) : **actuellement intestable**, et pas seulement faute d'appareil — aucun producteur ne remplit `failureReason` (les fonctions Cloud du dépôt ne l'écrivent pas, et MyNita n'existe que comme valeur d'enum côté client). Tous les échecs retombent donc sur le cas générique. À revérifier quand l'intégration du prestataire de paiement écrira un motif : vérifier que le classement tombe sur le bon cas, que la phrase sur l'état du débit est juste, et surtout que « Réessayer » n'apparaît **pas** sur un doublon évité ni sur un débit incertain.
- [ ] **Contrôles d'appel** (`call_screen.dart`, `group_call_screen.dart`) : 4 boutons nommés 64px, bouton raccrocher pleine largeur, grille 2×2 en appel de groupe.
- [ ] **"Proches de vous"** (`new_conversation_screen.dart`) : n'apparaît que si permission localisation déjà accordée — vérifier l'affichage et le calcul de distance.
- [ ] **Coloration hashtags en direct** (composer post + commentaire) : `HashtagHighlightingController`, surtout pendant la composition IME (clavier téléphone).
- [ ] **Glisser-pour-répondre** sur une bulle de message : seuil 52px, translation bornée à 90px.
- [ ] **Enregistrement vocal** : 3 états (en cours / annulation armée / verrouillé), gestes de glissement.
- [ ] **Enregistrement micro d'un épisode de podcast** (`record_episode_screen.dart`, ajouté 2026-08-03) : permission micro (première demande), chrono, niveau d'entrée qui bouge vraiment, pause/reprise (le chrono doit repartir au bon endroit), « Terminer » qui produit un fichier lisible avec la bonne durée, « Annuler » qui supprime le fichier partiel, et sortie de l'écran en cours d'enregistrement qui libère bien le micro. Le service `AudioRecordingService` est partagé avec les messages vocaux : vérifier qu'enchaîner les deux ne casse rien.
- [ ] **Bilan de reprise après coupure** (`reconnection_summary.dart` + `offline_sync_service.dart`, ajouté 2026-08-03, maquette 3b) : mettre des actions en file hors ligne, couper longtemps, puis rebrancher → une feuille doit s'ouvrir avec « Envoyé en priorité » (une ligne par action, avec son sort), l'avertissement rouge si des actions ont été abandonnées après 3 tentatives, et « Reçu pendant votre absence » (messages non lus + notifications). Vérifier aussi qu'elle **ne s'ouvre pas** quand rien n'était en attente, et qu'elle ne s'empile pas si deux synchros s'enchaînent. Réserve : les lignes n'affichent que le nom de la collection Firestore, la file d'attente ne stocke pas de libellé lisible.
- [ ] **Fil hors ligne et 4 échecs distingués** (`feed_provider.dart`, `feed_error_state.dart`, ajouté 2026-08-03, maquettes 2a/2b) : couper la donnée réellement (pas le VPN) après avoir chargé le fil une fois → les publications en cache doivent réapparaître avec le bandeau « Fil hors ligne · dernière mise à jour … », et non l'écran d'erreur. Vérifier aussi les 4 cas d'échec : pas de connexion (pas de bouton Réessayer, c'est voulu), panne serveur (compte à rebours 15 s qui relance tout seul), réseau lent, et publication non envoyée (carte en tête du fil avec Réessayer/Abandonner, le texte saisi doit être conservé). Les cas « panne serveur » et « réseau lent » dépendent de la classification par sous-chaîne du message d'erreur — à confronter aux vrais messages Supabase.
- [ ] **Bandeau de reconnexion salon audio** (`audio_room_screen.dart`, ajouté 2026-08-03) : couper la donnée en plein salon doit afficher le bandeau « Reconnexion en cours… » puis « Connexion audio perdue » avec le bouton Réessayer, et le bouton doit réellement redemander un jeton LiveKit et remettre le son. Non vérifiable sans deux appareils et une vraie coupure réseau.

## Priorité moyenne — layout & responsive

- [ ] **Rail de navigation tablette 86px** (`tablet_navigation_rail.dart`, seuil 700px) : bascule téléphone/tablette, badges non lus.
- [ ] **Filtres rapides événements** (Près de moi/En ligne/Gratuits) : calcul de distance réel avec ma position.
- [ ] **En-tête carte unifié** (`map_screen.dart`, §7d) : recherche + bouton calques sur une ligne, chips profession en dessous — zone à risque de chevauchement avec l'overlay Google Maps.
- [ ] **`font_scale` élevé** (accessibilité système) : plusieurs `SizedBox` à hauteur fixe ont déjà débordé par le passé (ex. `BOTTOM OVERFLOWED BY 4px` à `font_scale=1.1`) — revérifier sur les écrans récents (checklist pièces à joindre, puces sondage/lieu, carte "plus proche" ambassade). *(2026-08-03 : l'appareil de test est en permanence à `font_scale = 1.1`, donc **toutes** les captures de cette session sont déjà à cette échelle. Un nouveau débordement trouvé et corrigé : `BOTTOM OVERFLOWED BY 6.0 PIXELS` sur le rail de stories du fil. Deux zones à surveiller, vues serrées sans bandeau d'erreur : la 3ᵉ carte de l'écran de consentement, coupée en pleine phrase par le bouton « Continuer », et les pastilles de couleur de la dernière étape de l'assistant de profil, dont seule la moitié haute est visible. Les écrans nommés ci-dessus n'ont pas été atteints.)*
- [ ] **Cinq contrôles morts recâblés** (2026-08-03) : **⚙ Réglages** du pied de salon (les 3 interrupteurs doivent écrire pour de vrai dans Supabase et revenir en arrière si l'écriture échoue — à tester en coupant la donnée), **📊 Statistiques** du pied de salon, **+ Inviter** du panneau de modération (le participant choisi doit apparaître dans la rangée des co-hôtes), **🪙 Pourboire** du replay (destinataire = hôte du replay ; vérifier que la puce disparaît si le replay n'a pas d'hôte), et le **CTA de l'encart publicitaire** du fil (chaque encart doit mener à sa section). Vérifier aussi qu'un admin qui rejoint en mode fantôme ne fait **plus** grossir la rangée de modérateurs vue par l'hôte.
- [ ] **Mini-lecteur podcast enfin affiché** (`main_shell.dart` + `podcast_mini_player.dart`, 2026-08-03) : la classe existait mais n'était montée nulle part — une lecture lancée depuis un épisode devenait invisible dès qu'on quittait l'écran. Il apparaît maintenant au-dessus de la barre de navigation, en **sombre même en thème clair**. À vérifier : qu'il apparaît bien au lancement d'une lecture et disparaît au Stop, que le tap ouvre l'épisode en cours, que la barre de progression avance, et surtout **que le dernier élément des listes reste atteignable** (la réserve basse passe de 110 à 174 px quand il est présent). Vérifier aussi le rendu tablette (il est sous la colonne centrale, à droite du rail) et que la barre sombre ne détonne pas trop sur les écrans clairs — c'est le compromis assumé.
- [ ] **Lecteur d'épisode forcé en sombre** (`episode_detail_screen.dart`, 2026-08-03, maquettes 1e/4b) : l'écran est sombre **même en thème clair**. À vérifier en mode clair : fond, cartes, curseur de progression, pastilles de chapitres, chips de statistiques, bandeau « depuis un salon live » (violet éclairci pour rester lisible), et surtout que la feuille de minuterie et celle de signalement s'ouvrent bien en sombre au lieu de flasher en clair. Vérifier aussi les icônes de la barre de statut au retour vers un écran clair, et la palette orange (le lecteur reprend `orangeDarkTheme` si ce thème est choisi).
- [ ] **Nocturne (thème sombre)** : ombres conditionnées récemment sur `map_screen.dart`, `profile_view_screen.dart`, `group_detail_screen.dart`, `groups_screen.dart` — vérifier qu'elles sont bien invisibles/neutres en sombre, pas juste "sans erreur de compilation".
- [ ] **QR code partage profil** 196px (`share_profile_modal.dart`) : vérifier qu'il tient bien dans la carte sans débordement après l'agrandissement (était 160px).
- [ ] **Regroupement des ambassades par zone géographique** (`embassies_screen.dart`, ajouté 2026-07-31) : zones calculées depuis lat/lng (pas le nom de pays, jugé trop fragile) — vérifier que les zones sont cohérentes avec de vraies données (une ambassade au Maroc doit tomber en Afrique, pas en Europe par ex.), que « Près de vous » apparaît en tête si la position du profil est connue, et que le pliage/dépliage de chaque zone + sous-section pays fonctionne.

## Priorité basse — cosmétique, faible risque

- [ ] Badge panier boutique (nombre d'articles) + badge icône commandes (commandes vendeur en attente).
- [ ] Filtre pays fusionné dans la barre de recherche boutique (bouton compact drapeau).
- [ ] Checklist de pièces à joindre + délai indicatif (demande administrative).
- [ ] Carte "ambassade la plus proche" + badge "Fermé" sur la liste.
- [ ] **Drapeau par pays sur la liste des ambassades** (ajouté 2026-07-31) : correspondance normalisée (accents/casse ignorés) sur `ProfileOptions.countries` — vérifier le taux de correspondance réel sur les données de prod (repli silencieux si aucune correspondance, donc un drapeau manquant n'est pas un bug, juste à surveiller si ça arrive trop souvent).
- [ ] Bandeau conséquences du blocage (comptes bloqués).
- [ ] Écrans légaux fusionnés en onglets (CGU/confidentialité/code de conduite).
- [ ] Mon espace : carte Brouillons (sauvegarde/reprise/suppression), tuile Hashtags suivis + bouton Suivre/Suivi sur le bandeau de filtre hashtag du fil.
- [ ] Chip "groupes en commun" sur les cartes de demande d'ami.
- [ ] Filtre "Archives" unifié dans la liste des messages (4e puce).
- [ ] En-tête de discussion 58px, avatar 38px/rayon 13, cadenas E2EE.
- [ ] Écran de réglages dédié (`/settings`) accessible depuis les 3 entrées condensées du profil.
- [ ] **Bandeau hors-ligne sur le fil** (`feed_screen.dart` + `offline_banner.dart`, ajouté 2026-08-03) : couper la donnée réellement (pas le VPN — il masque la coupure, cf. sessions précédentes) et vérifier que le bandeau apparaît en haut du fil, que le compteur d'actions en attente s'affiche, et qu'il disparaît au retour du réseau.
- [ ] **Titre d'un salon programmé** (`schedule_room_screen.dart`, corrigé 2026-08-03) : le titre était figé à « Nouveau salon » pour tous les salons programmés. Vérifier que le champ titre apparaît, qu'il arrive pré-rempli quand on vient de « Ouvrir un salon » → « Plus tard », et que le salon créé porte bien ce nom dans l'onglet Programmés. Vérifier aussi que le bouton du bas affiche la date choisie et se met à jour quand on change de jour/heure.
- [ ] **Rappel local d'un salon programmé** (`schedule_room_screen.dart`, ajouté 2026-08-03) : l'interrupteur « Me le rappeler » doit réellement programmer une notification 15 min avant. À vérifier en programmant un salon à ~20 min et en laissant le téléphone. Écart assumé avec la maquette, qui dit « Prévenir mes abonnés » : notifier d'autres utilisateurs demanderait un push serveur qui n'existe pas, l'interrupteur ne rappelle donc que l'hôte.
- [ ] **Nouveau CTA de la liste des salons** (`audio_rooms_list_screen.dart`, 2026-08-03) : le FAB rond a été remplacé par une pilule large « Ouvrir un salon » + bouton 📅 sur la même ligne, en bas. Vérifier qu'ils ne recouvrent pas la dernière carte de la liste et qu'ils tiennent à `font_scale` élevé.
- [ ] **Durée du salon en direct** (`audio_room_screen.dart`, ajouté 2026-08-03) : l'en-tête doit afficher « N MIN · N auditeurs » et la durée doit avancer toute seule (rafraîchie toutes les 30 s) — à laisser tourner quelques minutes pour le confirmer.
- [ ] **États vides complétés le 2026-08-03 (2e lot)** : « aucun salon en direct » avec les deux cartes d'action (Ouvrir un salon / Patrimoine oral), « aucun abonnement » podcasts avec les 3 populaires et leurs boutons S'abonner (vérifier que le bouton s'abonne vraiment et devient une coche), puces catégories de « Mes produits » vide (elles doivent pré-cocher la catégorie sur l'écran de création via `?category=`), note séquestre sur « aucune commande », lien « Voir les N groupes suggérés », et « Créer « X » » de la recherche groupes (le nom saisi doit arriver pré-rempli via `?name=`). La recherche boutique respecte maintenant les filtres actifs : vérifier que « Chercher partout · N » apparaît bien quand des résultats existent hors filtre, et qu'il les révèle.
- [ ] **États vides ajoutés le 2026-08-03** : « rien dans ma région » sur l'onglet Groupes (profil renseigné + aucun groupe correspondant), recherche sans résultat (boutique et groupes — pistes + boutons), carte « zone vide » (`map_screen.dart`, boutons Dézoomer / Voir les ambassades). Le cas carte demande de se placer sur une zone réellement déserte ; le bouton « Dézoomer » doit recharger des marqueurs.
- [ ] **Thème sombre bibliothèque Héritage** (`heritage_library_screen.dart`, ajouté 2026-08-03) : couleurs codées en dur remplacées par les couleurs adaptatives — vérifier l'écran entier en nocturne (fond, cartes de catégorie, tuiles, feuille lecteur), c'était totalement clair avant.
- [ ] **Écran Statistiques d'un podcast** (`podcast_stats_screen.dart`, ajouté 2026-08-03, maquette 4a) : ouvert depuis « Mes podcasts » → menu → Statistiques. Vérifier sur un podcast ayant réellement plusieurs épisodes publiés que les totaux, la moyenne par épisode, le classement des plus écoutés et l'intervalle moyen de publication sont cohérents avec les données. Un podcast sans épisode publié doit afficher le message dédié, pas des zéros.
- [ ] **Métriques d'engagement podcast réellement alimentées** (`podcast_supabase_datasource.dart` + migration `20260803160000`, 2026-08-03) : avant, « J'aime », « Partages » et « Téléchargements » affichaient 0 en permanence — les colonnes n'existaient pas, le mapper ne les lisait pas, et rien ne les incrémentait. **Exige la migration poussée.** Vérifier qu'un partage puis un téléchargement d'épisode font bien monter les compteurs dans les statistiques du créateur, qu'un « j'aime » retiré redescend le compteur (recalcul, pas incrément — retaper plusieurs fois ne doit pas gonfler), et qu'un épisode publié apparaît avec une date dans « Rythme de publication ».
- [ ] **Écoutes après définition de la RPC** (migration `20260803160000`) : `increment_podcast_play` était appelée sans être définie nulle part dans le dépôt. Vérifier qu'écouter un épisode incrémente bien à la fois `play_count` de l'épisode et `total_play_count` du podcast.
- [ ] **Pickers « Lié à » de « Ouvrir un salon »** (`create_audio_room_screen.dart`, ajouté 2026-08-03) : les trois puces Événement / Groupe / Ambassade ouvrent bien leur feuille de sélection, le nom choisi remplace le libellé de la puce, et l'ID part avec la création du salon.

---

# 2. Reste du projet (hors refonte Fil & Discussion)

Extrait de l'historique git complet (235 commits) + des fichiers mémoire du
projet. Les commits antérieurs à mi-juillet 2026 ne documentent quasiment
jamais leur statut de test device — cette liste ne peut donc pas prétendre
remonter à l'origine du projet (déc. 2025), seulement à ce qui est
explicitement tracé.

## E2EE & chiffrement (priorité haute — sécurité)

- [ ] **Initialisation de `MessagingE2EEService`** (commit `91ef606`) : elle était appelée nulle part avant ce fix ; l'init démarre (100 puis 50 paires X25519 séquentielles) mais rien ne confirme qu'elle se termine en temps raisonnable sur device réel.
- [ ] **Garde `isE2EEInitialized` retirée avant l'envoi de texte** (commit `26aeb0d`) — jamais revérifié, le téléphone s'est déconnecté avant le test final.
- [ ] **`KeyBackupService.checkBackupPresence`** (commit `19b092c`) — logique de génération de clés à la connexion changée, pas de re-test device après coup.
- [ ] **Sauvegarde/restauration de clés E2EE bout-en-bout** — nécessite DEUX appareils sur le même build (le destinataire doit republier ses clés depuis SON device) ; seule la republication des clés propres a été validée jusqu'ici.
- [ ] **Self-chat « Mes notes » : policy RLS Supabase pour l'INSERT d'une conversation à un seul participant** — jamais testée au runtime.
- [ ] **Déchiffrement réel du bandeau épinglé** (messages) — seul le repli « 🔐 Message chiffré » a été vu à l'écran (clés E2EE perdues sur un build debug réinstallé), jamais le contenu déchiffré effectif.

## Appels WebRTC

- [ ] **⚠ ORDRE DE DÉPLOIEMENT — règles de signalisation** (`database.rules.json` + `call_remote_datasource.dart`, 2026-08-03) : les règles restreignent désormais `calls/$callId` aux deux participants, en lisant `callerId`/`calleeId` **écrits par l'app** à la création. Déployer les règles **avant** que la nouvelle version de l'app soit installée couperait les appels 1:1 de tout client existant (ses lectures seraient refusées, en silence). Ordre obligatoire : livrer l'app d'abord, laisser le parc se mettre à jour, **puis** `firebase deploy --only database`.

  **Mesuré le 2026-08-03, avant tout déploiement** — la contrainte est confirmée, pas théorique : `/calls` contenait **20 nœuds** écrits par des clients, donc les règles en ligne autorisent bien l'écriture aujourd'hui, et les resserrer casserait ces clients. En regard, `/admins`, `/superAdmins`, `/audioRooms` et `/group_calls` étaient **vides** : rien d'autre dans ce fichier n'est urgent (la faille d'escalade RTDB porte sur un nœud inexistant, et la modération fantôme attend de toute façon l'amorçage manuel). Le déploiement a donc été **volontairement reporté**.

  ⚠ Contrepartie assumée pendant l'attente : les règles actuellement en ligne laissent tout compte connecté lire et écrire la signalisation de n'importe quel appel dont il connaît l'identifiant. Plus la sortie de l'app tarde, plus cette fenêtre reste ouverte.
- [ ] **Appel 1:1 après restriction** (2026-08-03) : un appel complet entre deux comptes doit fonctionner à l'identique — sonnerie, décroché, audio des deux côtés, passage en vidéo, raccrochage. C'est le test de non-régression du changement de règles ; tout échec se manifestera par une signalisation muette (l'appelé ne voit jamais l'offre) plutôt que par une erreur explicite.
- [ ] **Étanchéité de la signalisation** (2026-08-03) : avec un **troisième** compte, vérifier qu'il ne peut ni lire ni écrire le nœud d'un appel auquel il ne participe pas. Se teste depuis la console Firebase (simulateur de règles) avec l'UID du tiers sur `calls/<id>` — doit refuser lecture et écriture.
- [ ] **Appel de groupe après restriction** (2026-08-03) : entrer dans un appel de groupe écrit d'abord `participants/<uid>` (autorisé pour soi-même) puis lit le reste — vérifier que rejoindre, voir les autres arriver et repartir, et l'audio de bout en bout fonctionnent toujours. La signalisation est maintenant limitée aux couples émetteur/destinataire dont on fait partie, et `hostId`/`status`/`mode` restent lisibles avant d'avoir rejoint.
- [ ] **Relais TURN coturn en production** — à valider par un vrai appel en 4G/5G **sans wifi** (cas NAT symétrique, celui que TURN est censé résoudre) ; vérifier aussi que `grep -ci allocation` augmente dans les logs coturn pendant l'appel. Jamais confirmé depuis la rotation de secret du 16/07.

## Messagerie (hors refonte Fil & Discussion)

- [ ] **En-tête hero de la liste des messages** (dégradé + puces de filtre, commit `65c1852`) — jamais vu à l'écran, l'APK était cassé (toolchain JDK 17) au moment du commit.
- [ ] **Accusé de réception « remis »** (`mark_messages_as_delivered`, commit `da21b24`) — bug capturé dans les logs d'un appareil réel puis corrigé côté SQL, jamais revalidé en conditions réelles depuis.
- [ ] **Statut en ligne (Firestore → Supabase)** (commit `b16dc88`) — bug de confidentialité corrigé (préférence `showOnlineStatus` ignorée), jamais vérifié à l'écran.

## Groupes & événements en conversation

- [ ] **Bulle `EventMessageCard` en conversation + différenciation groupe** (commit `267d7d3`) : visibilité « publier dans le fil » DM/groupe, badge Admin sur les bulles, « Vu par N » sur messages de groupe lus, boutons appel/vidéo de groupe dans l'app bar, auto-adhésion au groupe pays au chargement du profil — aucun sous-élément vérifié sur device.

## Sécurité / Comptes connectés

- [ ] **⚠ E2EE, réactions, sondages, épinglage, patrimoine — débloqués côté base** (migration `20260803180000`, appliquée en production le 2026-08-03) : 34 policies supplémentaires, sur 17 tables absentes du dépôt, étaient restées sur l'ancienne identité. RLS y était **actif sans aucune policy saine** — donc refus total, sans recours. Le plus lourd est l'E2EE : `e2ee_devices`, `e2ee_user_keys`, `e2ee_one_time_prekeys` et `e2ee_sender_key_distributions` refusaient l'enregistrement d'appareil et la publication des clés. À vérifier en priorité sur deux appareils : qu'un **nouvel** appareil s'enregistre, publie ses clés, et qu'une conversation chiffrée s'établit des deux côtés. Puis : réagir à un post, reposter, aimer un commentaire, créer un sondage et voter, épingler un message en conversation, ouvrir la bibliothèque du patrimoine, enregistrer une préférence, mettre quelqu'un en sourdine.

  **RLS E2EE vérifié sur la base de production le 2026-08-03** (SM A515F branché, compte `vQZE49dT…`). En simulant la session applicative (`request.jwt.claims` + rôle `authenticated`), dans des transactions annulées : `firebase_uid()` résout bien vers le Firebase UID du compte ; la lecture de `e2ee_devices` et `e2ee_user_keys` fonctionne ; l'insertion d'une prékey **pour soi est acceptée**, et la même insertion **pour autrui est refusée** (`42501: new row violates row-level security policy`). Le correctif est donc concluant dans les deux sens — il autorise sans ouvrir.

- [x] **Republication des prékeys — CORRIGÉ ET VÉRIFIÉ SUR APPAREIL** (`key_manager_service.dart`, 2026-08-03, SM A515F) : `e2ee_one_time_prekeys` contenait **0 ligne** en production alors que l'appareil en avait 50 en local. `checkAndRefillOneTimePreKeys` ne comparait le seuil de 20 qu'au compteur **local** : un appareil dont la publication initiale avait échoué (RLS, session absente) ne republiait donc jamais. Le contrôle porte désormais aussi sur le compte serveur, avec `null` = « comptage impossible » pour ne pas republier sur une simple coupure réseau.

  Déroulé de la vérification, build installé sur l'appareil : premier démarrage → `KeyManagerService: 50 prékeys en local mais 0 publiées — republication`, puis **0 → 100 lignes** en base. Second démarrage → aucune republication, table **stable à 100** : idempotent, pas de régénération en boucle.

- [x] **Suppression des prékeys d'autrui — CORRIGÉ ET VÉRIFIÉ** (migration `20260803190000`, appliquée en production le 2026-08-03) : la policy `e2ee_one_time_prekeys: authenticated delete` avait pour condition littéralement `true`, sans clause de propriété, alors que l'INSERT de la même table était bien restreint au propriétaire. N'importe quel compte pouvait vider le vivier de n'importe qui — pas une panne, mais une dégradation silencieuse : les sessions suivantes s'établissent alors sans DH4 (cf. audit du repli X3DH), donc sans la protection du message initial, sur une cible choisie.

  Vérifié dans les trois sens, transactions annulées, production intacte à 100 prékeys : un **tiers** qui tente de purger le vivier supprime désormais **0 ligne** ; le **propriétaire** en supprime bien **100**, ce qui préserve la republication de `_publishOneTimePreKeysToSupabase` ; et la RPC `consume_one_time_prekey`, appelée par l'expéditeur sur les clés du destinataire, **fonctionne toujours** — elle est `SECURITY DEFINER` et contourne RLS, ce qui avait été vérifié avant d'écrire la migration, puisque c'était le seul usage légitime de suppression par un tiers.

  Les autres tables E2EE ont été revues au passage et sont correctement cloisonnées : `e2ee_devices` et `e2ee_user_keys` restreignent l'écriture au propriétaire, `e2ee_sender_key_distributions` au destinataire. Seules les lectures de clés publiques sont ouvertes, ce qui est le principe même d'un vivier de prékeys.

  **Repli X3DH audité le 2026-08-03 — ça dégrade, ça ne casse pas.** La chaîne a été vérifiée de bout en bout : la RPC `consume_one_time_prekey` existe bien en production et renvoie proprement `NULL` sur vivier vide (testé, transaction annulée) — donc pas d'exception qui ferait échouer tout `getPreKeyBundle` via son `catch … return null` ; le bundle accepte une prékey nulle (`oneTimePreKeyId`/`oneTimePreKeyPublic` optionnels) ; et `messaging_e2ee_service.dart:212` ne calcule DH4 que `if (bundle.hasOneTimePreKey)`. La session s'établit donc avec DH1+DH2+DH3, ce qui est le comportement standard de X3DH.

  Ce qu'on perd, et c'est réel : la prékey à usage unique est ce qui protège le **message initial** contre une compromission ultérieure de la signed pre-key. Sans elle, quelqu'un qui obtiendrait plus tard la clé privée signed pre-key pourrait recalculer le secret partagé des sessions ouvertes pendant cette période, et le message initial devient rejouable. Ce n'est donc pas une panne à traiter en urgence, mais un affaiblissement de la confidentialité persistante qui dure tant que le vivier reste vide.

  Correctif suggéré, non implémenté : faire comparer `checkAndRefillOneTimePreKeys` au compte **serveur** (ou publier inconditionnellement si le serveur est à zéro) plutôt qu'au seul compteur local — sinon le parc installé ne se rattrapera jamais.
- [ ] **Identité des policies RLS réparée** (migration `20260803170000`, 2026-08-03) : 48 policies comparaient `current_user_id()` (identifiant Supabase Auth) à des colonnes contenant des Firebase UID — mesuré en production, **0 correspondance sur 1247 comptes**. Tout ce qui est « à moi » était donc refusé en silence, les échecs étant avalés par des `catch { debugPrint }`. Après `supabase db push`, vérifier sur un compte réel que ces actions **fonctionnent enfin** : modifier son profil, s'abonner à un podcast, suivre quelqu'un, mettre un post en favori, publier une story et y réagir, ouvrir un ticket de support, signaler un contenu, consulter son historique de transactions. Vérifier aussi qu'un profil passé en privé redevient visible à son propriétaire.
- [ ] **Non-régression après la bascule d'identité** (même migration) : le risque miroir est d'ouvrir trop. Avec **deux** comptes, vérifier qu'on ne voit toujours pas les données de l'autre — ses favoris, ses tickets, ses transactions, son profil privé — et qu'on ne peut pas modifier son profil ni ses podcasts.
- [ ] **Appareils connectés (#10) migrés vers Supabase `e2ee_devices`** (commit `267d7d3`) — la liste « s'affiche enfin » côté code, jamais confirmé à l'écran.
- [ ] **Flux caméra/galerie/éditeur + permissions manifest** (`WRITE_EXTERNAL_STORAGE`/`READ_MEDIA_IMAGES`/`VIDEO`, réintroduites après une perte accidentelle, commit `9ea9b45`) — jamais revalidées par un flux caméra/galerie réel.

## Admin (back-office)

- [ ] **Migration des 18 écrans admin + `admin_app` vers `AdminColors`** — jamais vérifiée à l'écran ; en particulier la couleur bleu d'action (jamais orange) jamais confirmée visuellement.
- [ ] **Modérateur fantôme — Muet / Exclure / Bloquer** (`ghost_moderator_screen.dart`, ajouté 2026-08-03) : les trois boutons ouvrent une feuille de sélection de participant puis appliquent l'action. Trois choses ne peuvent être vérifiées que sur un salon réel avec deux comptes : que la feuille liste bien les participants visibles (les fantômes doivent en être exclus), que l'action passe réellement les règles RTDB (nécessite `/admins/<uid>: true` dans la Realtime Database — sinon échec silencieux côté règles), et que le SnackBar d'erreur remonte quand ça échoue.
- [ ] **Ouverture et fermeture de la session fantôme** (`ghost_moderator_screen.dart`, 2026-08-03) : l'écran appelle maintenant `joinAsGhostModerator()` à l'ouverture — auparavant il ne rejoignait jamais le salon, donc `isGhostMode` restait faux, les compteurs affichaient 0 et les trois actions ne trouvaient aucune cible. À vérifier sur un salon réel avec deux comptes : que les compteurs se remplissent, que l'admin **n'apparaît pas** dans la liste des participants côté hôte, que la durée s'incrémente (rafraîchie toutes les 30 s), et surtout qu'en quittant l'écran l'admin est bien retiré du salon (`leaveRoom` n'est appelé que si c'est cet écran qui a ouvert la session — un admin déjà présent dans le salon ne doit pas en être éjecté).
- [ ] **Point d'entrée de la vue fantôme** (`audio_rooms_list_screen.dart`, 2026-08-03) : icône œil barré sur chaque carte de salon, visible **uniquement** pour un compte admin. Vérifier qu'elle est absente pour un compte normal, et que le tap dessus n'ouvre pas le salon en même temps (elle est imbriquée dans le `GestureDetector` de la carte).
- [ ] **États d'échec de la vue fantôme** (`ghost_moderator_screen.dart`, 2026-08-03) : salon inexistant ou compte non autorisé doivent afficher l'écran d'erreur avec le motif, plus l'écran vide à zéro d'avant.
- [ ] **Garde d'accès à la vue fantôme** (`app_router.dart`, ajouté 2026-08-03) : ouvrir `/audio-rooms/<id>/ghost` avec un compte **non** admin doit rediriger vers le salon. Jamais testé avec deux comptes de rôles différents.
- [ ] **Promotion d'un admin propagée aux 3 backends** (`role_management_provider.dart`, ajouté 2026-08-03) : promouvoir un utilisateur depuis l'écran de gestion des rôles doit écrire Firestore **et** `users.is_admin`/`admin_role` dans Postgres **et** `/admins/<uid>` en RTDB. Nécessite la migration `20260803120000_admin_can_manage_admin_flags.sql` poussée, et l'amorçage manuel du premier admin en SQL. Le message d'erreur de désynchronisation n'a jamais été vu à l'écran.

## Salons audio — monétisation

- [ ] **Mention du code PIN conditionnelle** (`buy_ticket_bottom_sheet.dart`, 2026-08-03) : « Code PIN demandé pour confirmer » ne doit apparaître que sous Wave et Mynita, jamais sous Carte bancaire — elle était affichée en pied de feuille quel que soit le moyen choisi. Les lignes de paiement sont maintenant encadrées et cliquables en entier (l'ancien `RadioMenuButton` a été remplacé) : vérifier la zone de tap et le rond de sélection.
- [ ] **Prix dans la devise réelle du salon** (`buy_ticket_bottom_sheet.dart`, `send_tip_bottom_sheet.dart`, 2026-08-03) : le `€` était codé en dur. Un salon facturé en XOF doit afficher « FCFA » (symbole après le montant) partout : prix du billet, commission, part de l'hôte, montants de don, libellé du bouton.
- [ ] **Feuille de don — deux lignes de montant** (`send_tip_bottom_sheet.dart`, 2026-08-03) : « Vous envoyez » puis « <nom> reçoit … (85 %) » — la part annoncée est passée de 95 % à 85 %, le serveur prélevant 15 %. Le sous-titre du destinataire affiche désormais le titre du salon : vérifier l'ellipse sur un titre long.

### Chemin de paiement recâblé (2026-08-03) — à retester de bout en bout

Ce bloc n'est **pas** du cosmétique : l'app appelait deux Edge Functions qui
n'existent pas (`purchase-room-ticket`, `send-tip` au lieu de
`process-room-ticket`, `process-tip`), envoyait les montants dans la mauvaise
unité et relisait la commission dans le mauvais type. **Aucun achat ni
pourboire n'a jamais pu aboutir** — il n'y a donc aucun historique de
référence, tout est à vérifier pour la première fois.

- [ ] **Achat d'un billet, bout en bout** (`monetization_supabase_datasource.dart`, `process-room-ticket`) : sur un salon payant en EUR, l'achat doit créer un PaymentIntent Stripe du bon montant et une ligne `room_tickets` en `pending`. Vérifier que le montant débité correspond au prix affiché — l'ancien code aurait facturé **100 fois trop cher**.
- [ ] **Envoi d'un pourboire, bout en bout** (`process-tip`) : idem sur `tips`, avec `commission_amount` = 15 % en unité mineure, entier.
- [ ] **Le même en XOF** : c'est le cas qui casse. Le FCFA n'a pas de subdivision — un billet à 5 000 FCFA doit s'afficher « 5 000 FCFA » (et non « 50 FCFA ») et débiter 5 000 FCFA. Vérifier l'affichage **et** le montant Stripe.
- [ ] **Part de l'hôte / du destinataire** : les feuilles annonçaient 5 % de commission pour un prélèvement réel de 15 %. Confronter la ligne « commission » de la feuille au `commission_amount` réellement écrit en base.
- [ ] ⚠ **Les deux Edge Functions doivent être redéployées** avant ce test (`supabase functions deploy process-tip process-room-ticket`) : leur logique de montant a changé. Tester l'app contre les anciennes fonctions déployées donnerait un débit 100× trop faible.
- [ ] **Réglages salons audio chargés depuis le backend** (`audio_rooms_settings_model.dart`, nouveau) : `AppSettingsModel` n'avait aucun champ `audioRooms`, les réglages retombaient donc toujours sur leurs valeurs par défaut. Modifier un montant de pourboire proposé ou une borne min/max en back-office et vérifier que la feuille de don le reflète.
- [ ] **Bouton Stripe Connect des moyens de paiement** (`add_payment_account_screen.dart`, 2026-08-03) : pointait sur `/audio-rooms/monetization`, route inexistante qui ouvrait un salon vide nommé « monetization ». Doit maintenant ouvrir l'écran des revenus créateur.
- [ ] **Prix du billet dans la liste des salons** (`audio_rooms_list_screen.dart`, `_PricePill`, 2026-08-03) : la pastille ocre affichait `€` en dur alors que la feuille d'achat respectait déjà `ticketCurrency`. Sur un salon facturé en XOF, la liste et la feuille doivent maintenant annoncer le même montant dans la même devise (« FCFA » après le montant).
- [ ] **Barre de collecte — devise et contributeurs** (`collection_progress_bar.dart`, 2026-08-03) : l'objectif et le montant courant étaient suffixés « € » en dur, et le nombre de contributeurs était `0` en dur aux deux points de montage (liste des salons et salon en direct). Le compte vient maintenant de `roomTipsProvider`, en donateurs **distincts** et **paiements aboutis seulement** : envoyer deux pourboires depuis le même compte doit afficher « 1 contrib. », pas « 2 ».

## Salons audio & appels de groupe — indicateur « parle en ce moment »

Ce bloc demande **deux comptes sur deux téléphones** : l'anneau ne s'allume que
sur une voix réellement captée par le SFU.

- [ ] **Anneau vert des intervenants** (`audio_room_screen.dart`, `audio_room_provider.dart`, 2026-08-03) : les tuiles `SpeakerTile` recevaient `talking: false` en dur — l'anneau ne s'est jamais allumé depuis l'écriture de l'écran. Il est maintenant piloté par `audioRoomSpeakingProvider` (flux `ActiveSpeakersChangedEvent` de LiveKit). Vérifier **les deux dispositions** : la grille (salon vidéo, tuiles 88 px) et le `Wrap` (salon audio seul, tuiles 52 px). Contrôler aussi l'extinction : l'anneau doit retomber quand la personne se tait, pas rester allumé.
- [ ] **Bordure de participant actif en appel de groupe** (`group_call_provider.dart`, 2026-08-03) : `speakingParticipantIds` était déclaré dans l'état et lu par l'écran, mais jamais alimenté. ⚠ **Ne se voit qu'à partir de 5 participants** (`meshToSfuThreshold`) : en dessous l'appel est en mesh, LiveKit n'est pas dans la boucle et le set reste vide — c'est le comportement attendu, pas une régression. Vérifier aussi qu'après avoir quitté l'appel aucune bordure ne reste collée.

## Lecteur de replay — valeurs inventées retirées (2026-08-03)

- [ ] **Replay sans chapitres** (`replay_player_screen.dart`) : cinq chapitres fictifs (« Introduction », « Actualités », « Diaspora & politique », « Q&R », « Conclusion ») s'affichaient quand l'entité n'en portait aucun, et le tap sautait à `i/5` de la piste. Sur un replay sans chapitre, la ligne « Chapitre n/N » et la pastille « Chapitres » doivent maintenant **disparaître**, et le grand titre afficher le nom du salon. Vérifier aussi le cas inverse : un replay **avec** chapitres réels doit toujours les lister avec leurs horodatages, et le tap sauter au bon endroit.
- [ ] **Compteur de temps en vidéo** (`replay_player_screen.dart`) : le temps écoulé et la durée totale dérivaient d'un `Duration(hours: 1, minutes: 14)` codé en dur — le compteur n'avait aucun rapport avec le fichier lu. Il vient maintenant du `VideoPlayerController`. Vérifier que la durée affichée correspond à la vraie, et que le compteur **avance** pendant la lecture (un écouteur a dû être ajouté, il n'y en avait aucun).
- [ ] **Glisser sur la forme d'onde en vidéo** : le geste ne faisait que déplacer le curseur à l'écran, la lecture continuait à sa position d'origine. Il doit maintenant vraiment chercher dans le flux.

## Version de l'app et téléphone du support (2026-08-03)

- [ ] **Numéro de version** (`app_version_service.dart`, nouveau) : « 1.2.0 » était écrit en dur dans Réglages (×2) et Profil. Il est maintenant lu sur le paquet installé via `package_info_plus` (nouvelle dépendance directe, déjà présente en transitive). Vérifier les trois emplacements — Réglages > À propos, la boîte « À propos », et Profil > Aide & à propos — et qu'ils affichent bien `1.2.0 (10)`, build compris. Si la lecture échoue, seul le libellé « Version » doit rester, sans numéro.
- [ ] **Ligne « Téléphone » du support** (`transaction_detail_screen.dart`) : elle affichait le gabarit « +33 1 XX XX XX XX » et composait `+33100000000` au tap. Elle est désormais masquée tant qu'aucun `supportPhone` n'est configuré dans les réglages — donc **elle ne doit plus apparaître du tout** en l'état. À revérifier si un vrai numéro est renseigné un jour.

## Appels 1-à-1 (correctifs du 2026-08-03)

Tout ce bloc demande **deux comptes sur deux téléphones** : rien n'est vérifiable
en solo.

- [ ] **Raccrochage réseau coupé** (`call_provider.dart`, 2026-08-03) : `endCall()`
  libère maintenant WebRTC, l'UI native et l'état local **avant** d'archiver
  l'appel dans Firestore (le distant est best effort, plafonné à 10 s). Le test
  qui compte : se mettre en mode avion **pendant** un appel connecté puis
  raccrocher — l'écran d'appel doit se fermer immédiatement et un nouvel appel
  doit redevenir possible. Avant le correctif l'écran restait bloqué pour de bon.
- [ ] **Refus avec réseau dégradé** (`call_provider.dart`) : même scénario sur
  `declineCall()` — la bannière CallKit doit s'éteindre tout de suite.
- [ ] **Double acceptation** (`call_provider.dart`) : appuyer sur « Accepter »
  dans l'app pendant que la bannière CallKit est encore affichée (ou l'inverse).
  WebRTC ne doit démarrer qu'une fois — avant, le même appel pouvait être
  répondu deux fois.
- [ ] **Appel reçu app tuée** (`native_call_service.dart`, `notification_service.dart`) :
  l'UUID CallKit est désormais dérivé du `callId` (v5) des deux côtés. À vérifier :
  (a) une seule bannière, pas deux empilées, quand l'app revient au premier plan ;
  (b) si l'appelant raccroche pendant la sonnerie, la bannière s'éteint bien
  (avant, l'app ne connaissait pas l'UUID généré par l'isolate d'arrière-plan et
  la sonnerie continuait).
- [ ] **Acceptation depuis l'écran verrouillé** (`AndroidManifest.xml`) :
  `showWhenLocked` + `turnScreenOn` ajoutés à `MainActivity`. Accepter un appel
  téléphone verrouillé doit allumer l'écran et afficher l'écran d'appel
  par-dessus le keyguard, pas juste derrière.
- [ ] **Routage audio** (`AndroidManifest.xml`) : `MODIFY_AUDIO_SETTINGS` et
  `BLUETOOTH_CONNECT` ajoutés. Vérifier le basculement écouteur ↔ haut-parleur
  en cours d'appel, et un casque Bluetooth appairé.
- [ ] **Accents dans les messages d'erreur** (7 fichiers du module appels,
  2026-08-03) : les chaînes étaient doublement encodées et s'affichaient
  « Utilisateur non connecté », « Échec de la connexion », « X est déjà en
  appel ». À relire à l'écran : historique d'appels, écran d'appel, overlay
  d'appel entrant.
- [ ] **Sonnerie côté appelé (push d'appel entrant)** — *le test le plus
  important* : le trigger `onCallCreated` était **mort au chargement** depuis le
  2026-07-19 (`require("dotenv")` et `require("livekit-server-sdk")` absents des
  dépendances de `functions/package.json` — ça passait en local, pas dans le
  conteneur). Trigger enregistré, fonction jamais exécutée, donc aucun push
  d'appel entrant pendant six semaines. Corrigé et redéployé le 2026-08-03
  (commit `a82c6b5`, démarrage à froid propre). À confirmer sur appareil :
  téléphone B en arrière-plan puis app tuée, appeler depuis A → B doit sonner
  avec la bannière plein écran. Puis `firebase functions:log --only onCallCreated`
  doit montrer « Successfully sent 1/1 call notifications ».
- [ ] **Relais TURN en 4G/5G sans wifi** (report du 2026-07-16) : coturn répond
  bien sur 3478/5349 et `getTurnCredentials` est déployée et appelée avec succès,
  mais le relais n'a jamais été validé sur un NAT symétrique réel.
- [ ] **Enchaîner deux appels après un raccrochage en réseau dégradé**
  (`webrtc_service.dart`, 2026-08-03) : `hangUp()` n'avait pas de try/finally et
  posait `_isEndingCall` avant une suppression RÉSEAU en RTDB. Une exception en
  route laissait le singleton WebRTC coincé pour toute la session — plus aucun
  raccrochage, et `startCall` levant « Already in a call » sur tous les appels
  suivants. Le test qui compte : couper la donnée en plein appel, raccrocher,
  rétablir, puis **passer un second appel** — il doit partir normalement.
- [ ] **Micro refusé au moment de décrocher** (`call_provider.dart`, 2026-08-03) :
  révoquer la permission micro dans les réglages Android, puis accepter un appel.
  L'écran doit échouer **immédiatement** avec « Micro ou caméra inaccessible »
  au lieu de rester sur « Connexion… » pendant 30 s. Vérifier aussi le chemin
  inverse : accepter depuis la bannière CallKit (l'échec n'était capturé nulle
  part sur ce chemin).
- [ ] **Service de localisation en arrière-plan**
  (`background_location_service.dart`, 2026-08-03) : la classe portait ses
  `@pragma('vm:entry-point')` sur les méthodes statiques mais pas sur la classe
  elle-même, que le natif traverse pour les atteindre — le VM refusait au
  démarrage et le service ne pouvait jamais tourner. À vérifier : activer le
  partage de position, mettre l'app en arrière-plan, et confirmer que la
  notification persistante du service apparaît et que la position remonte.

## Lecture audio en arrière-plan (podcasts)

- [ ] **Câblage `audio_service`** (`MainActivity.java` + `AndroidManifest.xml`,
  2026-08-03) : `MainActivity` étendait `FlutterFragmentActivity` au lieu de
  `AudioServiceFragmentActivity`, et le manifeste ne déclarait ni le service
  `com.ryanheise.audioservice.AudioService` ni `MediaButtonReceiver` (le plugin
  ne déclare rien lui-même). `AudioService.init()` échouait donc à chaque
  démarrage — la lecture en arrière-plan n'a jamais pu fonctionner. Corrigé et
  vérifié sur le SM A515F : plus d'erreur d'init au lancement, service et
  receiver bien enregistrés dans le paquet installé. **Reste à tester en vrai** :
  lancer un épisode, quitter l'app, vérifier que le son continue et que la
  notification média apparaît avec les contrôles ; puis les boutons du casque et
  ceux de l'écran verrouillé (`MediaButtonReceiver`), et que la reprise depuis la
  notification ramène bien sur le lecteur.

## Profil & Accueil (avant la refonte design)

## Reprise du design (2026-08-03, suite) — Éco, accueil, carte, discussion

⚠️ **Distinction à faire avant de tester.** L'essentiel du travail de design
de cette session vit dans `lib/design_v2/`, **qui n'est câblé à aucune
route** : ces écrans ne s'affichent pas dans l'app et ne sont donc **pas
testables** tant que la bascule vers `lib/features/` n'a pas eu lieu. Seuls
les trois blocs ci-dessous touchent la production et sont exerçables tout de
suite.

### Testable maintenant (production)

- [ ] **Mode données réduites appliqué à la réception** (`data_saver_gate.dart`
  nouveau, `message_bubble.dart`, 2 sites image + vidéo). C'est le point le
  plus important à vérifier de la session, et le seul qui change un
  comportement réseau. À exercer :
  - activer ÉCO (puce `⊙ Éco` de la sous-barre d'une discussion, ou Réglages
    → « Mode données réduites ») puis **recevoir une image et une vidéo** :
    la bulle doit montrer l'aperçu flou, la légende « aperçu flouté · N Ko »
    et un bouton « Télécharger », **sans consommer de données** ;
  - confirmer que rien ne part avant l'appui — idéalement en coupant les
    données mobiles après réception du message : le média doit rester masqué
    sans erreur de chargement ;
  - appuyer sur « Télécharger » → le média apparaît ;
  - **défiler loin puis revenir** : le média dévoilé doit le rester (le
    dévoilement est mémorisé par identifiant de message, en mémoire) ;
  - **relancer l'app** : le média doit être **de nouveau masqué**, c'est
    voulu ;
  - vérifier qu'un média **que j'envoie** n'est jamais masqué ;
  - vérifier qu'un message sans `fileSize` affiche « aperçu flouté » **sans**
    « 0 Ko ».
  - Test le plus parlant : **en 2G réelle ou en bridant le réseau**, comparer
    la consommation avec et sans ÉCO sur une conversation riche en médias.

- [ ] **Squelette pendant l'élargissement du rayon** (`home_screen.dart`,
  `home_screen_widgets.dart`). Depuis l'accueil, état « Personne à moins de
  50 km », appuyer sur « Élargir à 200 km » : le squelette (4 avatars gris)
  doit remplacer la carte vide **pendant** la recherche. Le défaut corrigé
  était que « Personne à moins de 50 km » restait affiché tout du long.
  Vérifier aussi que le **rafraîchissement automatique des 60 s** ne fait
  **pas** clignoter la liste — il doit garder les résultats affichés.

- [ ] **Carte — libellés sur l'accent en thème sombre** (`map_screen.dart`,
  `map_legend.dart`). Cinq libellés étaient figés sur `Colors.white` alors
  qu'ils sont posés sur la couleur d'accent : trois boutons et deux puces
  sélectionnées (rayon, filtre). **À regarder en mode nuit** — le texte doit
  rester lisible sur la puce sélectionnée. Vérifier aussi la pastille de la
  légende, passée d'un dégradé à un aplat.

### Non testable tant que `design_v2` n'est pas basculé

Pour mémoire, ce qui attend la bascule : onboarding 5 écrans, configuration
du profil en 4 étapes (identité / localisation / intérêts + notifications /
thème), séparateurs plats de la discussion, bouton d'envoi du composer en
aplats (4 états, avec variantes claires en thème sombre), pastille de vitesse
en contour et poids du fichier de la note vocale.

Deux points à regarder **en priorité au moment de la bascule**, parce qu'ils
sont invisibles à `flutter analyze` :

- le **thème sombre** de tous ces écrans — c'est la famille de défauts la
  plus récurrente du projet ;
- l'onboarding à `font_scale = 1.1`, où les titres serif sur deux lignes et
  les puces de réassurance peuvent déborder.

## Refonte des maquettes d'authentification

- [x] **Connexion et inscription refaites sur les maquettes** (`auth_scaffold.dart`
  nouveau, `login_screen.dart`, `register_screen.dart`, `auth_button.dart`,
  `assets/icons/icon_google.svg`, 2026-08-03) : vérifié sur le SM A515F, les
  deux écrans rendent la structure des maquettes — pastille de marque en haut
  à gauche, titre serif terminé par un point d'accent, bouton Google avec le
  vrai logo multicolore, libellés au-dessus des champs, « Oublié ? » sur la
  ligne du libellé, texte d'aide, bouton pleine largeur, lien de bas de page,
  mention de chiffrement épinglée en bas. L'accent apparaît **vert** et non
  terracotta : c'est la couleur d'accent choisie sur ce compte, pas un défaut.
  **Piège rencontré** : un `Spacer` dans la colonne défilante d'`AuthScaffold`
  donnait un écran entièrement noir, sans aucune exception dans `logcat` — le
  pied de page est désormais hors du défilement.

- [ ] **Configuration du profil : écrite, pas encore testable.** Les 4 étapes
  des maquettes (identité « Faisons connaissance » avec photo, nom
  d'utilisateur et vérification de disponibilité, profession ; localisation ;
  centres d'intérêt fusionnés avec « Ce que vous recevrez » ; thème) sont
  implémentées — mais dans `lib/design_v2/profile/…/profile_config_screen.dart`,
  **qui n'est câblé à aucune route**. Rien n'est vérifiable sur appareil avant
  la bascule vers `lib/features/`. Restent non écrites : nouvelle demande
  d'ambassade, création d'événement, panier vide, état vide des transferts.

- [ ] **Sous-titre chiffré de l'inscription non implémenté** : la maquette
  annonce « Rejoignez la communauté : 318 membres à Paris, 12 groupes actifs ».
  Aucune source ne peut fournir ces nombres avant authentification (les
  compteurs de `home_remote_datasource` demandent une session), et les inventer
  irait contre l'audit « widgets alimentés en dur ». Le sous-titre générique est
  conservé en attendant un compteur public.

## Thème sombre — jetons clairs codés en dur

- [x] **Écrans d'authentification en thème sombre** (`login_screen.dart`,
  `register_screen.dart`, `forgot_password_screen.dart`,
  `maintenance_screen.dart`, `splash_screen.dart`, `auth_button.dart`,
  2026-08-03) : vérifié sur le SM A515F en mode nuit — voir le bloc de session
  en tête de fichier. Seul l'écran de connexion a été capturé ; les quatre
  autres partagent le même correctif mais n'ont pas été ouverts.

- [ ] **Les 9 autres fichiers de la même passe** : 4 écrans de transferts,
  3 écrans de profil, la carte et `friend_list_item` — non atteignables sans
  session, la réinstallation déconnecte l'app. À rouvrir en mode nuit une fois
  reconnecté.

- [ ] **Blancs bruts restants** : ~587 `Colors.white` / `AppColors.white` et
  184 `Colors.black*` subsistent dans `lib/features`. La grande majorité est
  légitime (texte blanc sur surface colorée, écrans immersifs comme l'appel ou
  le viewer de stories, fond blanc obligatoire des QR codes) — seuls 14 sont
  des `backgroundColor`, dont 3 méritent un examen
  (`admin_create_admin_screen.dart:41`, `transfer_screen.dart:86`,
  `share_profile_modal.dart:447`). À trancher au cas par cas, pas en masse.

## Guide de style — alignement des jetons (2026-08-03)

- [ ] **11 couleurs d'`AppColors` réalignées sur le guide de style**
  (`lib/core/constants/app_colors.dart`) : bordure `#E8DFD4`→`#EFE7DB`,
  bordure forte `#C9BBAB`→`#E0D6C6`, texte désactivé `#B8AFA3`→`#A79C8E`,
  bordure nocturne `#3D352C`→`#2A241E`, succès `#2D7D46`→`#1B5E32`, erreur
  `#C53030`→`#C23E2D`, info `#2563EB`→`#1976D2`, et les quatre fonds pastel
  réchauffés. Ces jetons irriguent **toute** l'app via `adaptive_colors.dart` :
  c'est le changement le plus large de la session. **À vérifier sur le
  téléphone** : la bordure forte s'éclaircit nettement — contrôler que les
  puces de filtre et de centres d'intérêt au repos (`DesignFilterChip`,
  `DesignSelectableChip`, accueil / messagerie / groupes) restent visibles sur
  le fond crème, et qu'en nocturne les cartes se détachent encore avec la
  bordure plus sombre.

- [ ] **Texte sur accent en nocturne** (`lib/core/theme/adaptive_colors.dart`) :
  `onPrimaryColor` rendait du noir pur en mode nuit, le guide impose l'encre
  inverse `#1C1815`. Touche tous les boutons pleins et les pastilles d'accent.
  **À vérifier** : ouvrir un écran d'onboarding et un bouton principal en mode
  nuit, confirmer que le libellé reste franc (le changement est subtil, un
  rendu délavé signalerait une erreur de jeton).

- [ ] **État désactivé des boutons du kit**
  (`lib/design_v2/kit/design_kit.dart`) : `DesignPrimaryButton` et
  `DesignPillButton` passaient l'accent à 55 % d'opacité ; ils prennent
  désormais l'aplat sable + libellé éteint du guide. Le **chargement** garde
  volontairement la couleur d'accent. **À vérifier** : sur l'inscription et la
  configuration du profil, enchaîner champ vide → bouton grisé → champ rempli →
  bouton coloré → soumission → pilule colorée avec spinner clair.

- [ ] **Bouton secondaire** (idem) : contour passé de `borderColor` à
  `borderStrongColor` et libellé de `textPrimary` à `textSecondary`, comme le
  guide. **À vérifier** : le « Précédent » de la configuration du profil ne
  doit pas s'effacer sur le fond crème.

- [ ] **`DesignBadge` — jamais rendu** (idem) : les quatre pastilles de statut
  du guide (vérifié / en examen / échoué / archivé) sont écrites mais aucun
  écran ne les appelle encore. À regarder dès le premier usage, dans les deux
  thèmes.

- [ ] **Valeurs figées désormais désalignées** : `_kStepUpcoming = #E8DFD4`
  (`transfers/…/send_money_screen.dart`, les deux copies) et
  `_kRecvBorderDark = #3D352C` (`messages/…/message_bubble.dart`, les deux
  copies) recopiaient les anciennes valeurs des jetons. Elles n'ont pas été
  touchées pour ne pas balayer en masse. À trancher au cas par cas.

## Feature flags & accès aux écrans

- [ ] **Déblocage des routes gardées par les flags** (`lib/core/router/app_router.dart`,
  `lib/core/services/feature_flag_service.dart`,
  `lib/features/admin/presentation/screens/admin_feature_flags_screen.dart`,
  2026-08-03) : `FeatureFlagService.isFeatureEnabled` lisait un
  `ProviderContainer()` neuf, donc toujours les valeurs par défaut de
  `FeatureFlagsEntity` — `/transfers`, `/marketplace`, `/podcasts`,
  `/payment-accounts`, `/payment-history` et `/audio-rooms` étaient renvoyés
  sur `/home` quoi qu'en dise le back-office. Le gating ne s'appliquait en
  plus qu'aux valeurs par défaut au démarrage à froid, et le back-office
  n'exposait aucun interrupteur pour `audioRooms`/`podcasts`. **À vérifier sur
  le téléphone** : ouvrir Salons audio et Podcasts depuis l'accueil et
  confirmer qu'on n'est plus rejeté sur l'accueil ; basculer les deux nouveaux
  interrupteurs dans Admin → Feature flags et confirmer que l'accès s'ouvre et
  se referme sans redémarrer l'app ; enfin, tuer et relancer l'app pour
  vérifier qu'on n'est pas éjecté d'un de ces écrans pendant le chargement des
  réglages.

- [ ] **Points d'entrée créés vers trois modules injoignables**
  (`lib/features/home/presentation/screens/home_screen_widgets.dart`,
  `lib/features/home/presentation/screens/services_screen.dart`,
  `lib/features/profile/presentation/screens/profile_screen.dart`,
  2026-08-03) : `/audio-rooms`, `/podcasts` et `/calls/history` n'étaient
  référencés par aucun écran de l'app — seuls des liens internes à ces modules
  pointaient vers eux. Les écrans existaient et les routes étaient déclarées,
  mais aucun chemin de navigation n'y menait. Tuiles « Salons » et
  « Podcasts » ajoutées à la grille de l'accueil et à « Tous les services »,
  entrée « Historique d'appels » ajoutée à la section Compte du profil.
  **À vérifier sur le téléphone** : les deux tuiles apparaissent bien sur
  l'accueil une fois les flags activés (et disparaissent quand on les
  désactive), la grille ne casse pas son passage 3↔4 colonnes avec deux tuiles
  de plus, et les trois destinations s'ouvrent réellement.

## Profil & Accueil (avant la refonte design)

- [ ] **Réalignement Profil/Accueil pré-refonte** (commit `7110929`) : 4ᵉ stat « posts », sections COMPTE/CONFIDENTIALITÉ/SÉCURITÉ/APPELS/PRÉFÉRENCES/AIDE réintroduites, `FollowsScreen`, bouton QR de l'accueil réactivé, service « Fil d'actualité » — aucune vérification device mentionnée.

---

## Comment tester (rappel de la config utilisée précédemment)

- Appareil de référence : Samsung SM A515F (Galaxy A51), id `R58N91XBA7B`.
- `adb` : `C:\Users\danko\AppData\Local\Android\Sdk\platform-tools\adb.exe` (pas dans le PATH).
- Après `flutter run`, l'app repasse en arrière-plan (le process se détache) : la ramener avec
  ```
  adb shell monkey -p com.diasponiger.diasponiger -c android.intent.category.LAUNCHER 1
  ```
  puis attendre ~12s (splash).
- Capture d'écran : capturer sur l'appareil puis `pull` (la redirection PowerShell `>` corrompt le PNG) :
  ```
  adb shell screencap -p /sdcard/s.png
  adb pull /sdcard/s.png <destination>
  adb shell rm /sdcard/s.png
  ```
- Piège connu : un VPN persistant sur le téléphone masque l'état hors-ligne réel (transport VPN toujours "connecté" même en mode avion).
