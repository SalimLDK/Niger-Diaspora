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

# 1. Refonte Fil & Discussion (28 tours + salons/podcasts)

## Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser)

- [ ] **Viewer de stories** (`story_viewer_screen.dart`) : barre de progression segmentée, auto-avance 5s, tap gauche/droite (précédent/suivant), swipe vers le bas pour fermer, enchaînement automatique sur l'auteur suivant du rail.
- [ ] **Création de story** (`story_rail.dart`) : permission caméra (première demande), permission galerie, upload, apparition dans le rail avec l'anneau correct.
- [ ] **Rail de stories** : anneau dégradé (non vues) vs anneau gris (tout vu), avatar "+" quand pas de story active, défilement horizontal.
- [ ] **Repli du rail au défilement** (`feed_screen.dart`/`story_rail.dart`, ajouté 2026-07-31) : `AnimatedCrossFade` déclenché à `scrollOffset > 24`, bascule vers la barre compacte (3 avatars superposés + « N récits aujourd'hui » + « Afficher »), tap sur « Afficher » qui scrolle en haut et redéplie.
- [ ] **Story vidéo** (ajouté 2026-07-31) : sélection galerie (max 30s), upload + compression + génération de miniature, lecture avec `video_player` dans le viewer (autoplay, barre de progression synchronisée sur la position réelle au lieu du minuteur fixe 5s, passage automatique à la story suivante en fin de lecture).
- [ ] **« Qui a vu » ma story** (ajouté 2026-07-31) : le tap « N vues » (visible seulement pour l'auteur) met la lecture en pause, ouvre la feuille avec la liste (avatar/nom/heure + emoji de réaction le cas échéant), la reprise de lecture à la fermeture de la feuille.
- [ ] **Réactions sur une story** (ajouté 2026-07-31) : barre de 6 emojis en bas du viewer (stories des autres uniquement), tap = pose la réaction, retaper le même emoji la retire (toggle), l'emoji actif doit rester visuellement mis en évidence.
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
- [ ] **`font_scale` élevé** (accessibilité système) : plusieurs `SizedBox` à hauteur fixe ont déjà débordé par le passé (ex. `BOTTOM OVERFLOWED BY 4px` à `font_scale=1.1`) — revérifier sur les écrans récents (checklist pièces à joindre, puces sondage/lieu, carte "plus proche" ambassade).
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

- [ ] **⚠ Faille distincte : n'importe qui peut supprimer les prékeys d'autrui** (policy `e2ee_one_time_prekeys: authenticated delete`, repérée 2026-08-03, **non corrigée**) : sa condition est littéralement `true` pour tout compte authentifié, sans clause de propriété — contrairement à l'INSERT qui, lui, est bien restreint au propriétaire. Un compte quelconque peut donc vider le vivier de n'importe quel utilisateur. L'effet n'est pas une panne : les sessions suivantes s'établissent sans DH4 (cf. audit du repli X3DH), donc **sans la protection du message initial**. C'est un moyen simple et silencieux de dégrader le chiffrement d'une cible choisie. À restreindre au propriétaire, comme l'INSERT — l'app ne supprime jamais que ses propres clés (`_publishOneTimePreKeysToSupabase` filtre sur `user_id` + `device_id`), donc le resserrement ne devrait rien casser.

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
- [ ] **Feuille de don — deux lignes de montant** (`send_tip_bottom_sheet.dart`, 2026-08-03) : « Vous envoyez » puis « <nom> reçoit … (95 %) ». Le sous-titre du destinataire affiche désormais le titre du salon : vérifier l'ellipse sur un titre long.
- [ ] **Bouton Stripe Connect des moyens de paiement** (`add_payment_account_screen.dart`, 2026-08-03) : pointait sur `/audio-rooms/monetization`, route inexistante qui ouvrait un salon vide nommé « monetization ». Doit maintenant ouvrir l'écran des revenus créateur.

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
