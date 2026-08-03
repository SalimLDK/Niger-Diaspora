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
- [ ] **États vides complétés le 2026-08-03 (2e lot)** : « aucun salon en direct » avec les deux cartes d'action (Ouvrir un salon / Patrimoine oral), « aucun abonnement » podcasts avec les 3 populaires et leurs boutons S'abonner (vérifier que le bouton s'abonne vraiment et devient une coche), puces catégories de « Mes produits » vide (elles doivent pré-cocher la catégorie sur l'écran de création via `?category=`), note séquestre sur « aucune commande », lien « Voir les N groupes suggérés », et « Créer « X » » de la recherche groupes (le nom saisi doit arriver pré-rempli via `?name=`). La recherche boutique respecte maintenant les filtres actifs : vérifier que « Chercher partout · N » apparaît bien quand des résultats existent hors filtre, et qu'il les révèle.
- [ ] **États vides ajoutés le 2026-08-03** : « rien dans ma région » sur l'onglet Groupes (profil renseigné + aucun groupe correspondant), recherche sans résultat (boutique et groupes — pistes + boutons), carte « zone vide » (`map_screen.dart`, boutons Dézoomer / Voir les ambassades). Le cas carte demande de se placer sur une zone réellement déserte ; le bouton « Dézoomer » doit recharger des marqueurs.
- [ ] **Thème sombre bibliothèque Héritage** (`heritage_library_screen.dart`, ajouté 2026-08-03) : couleurs codées en dur remplacées par les couleurs adaptatives — vérifier l'écran entier en nocturne (fond, cartes de catégorie, tuiles, feuille lecteur), c'était totalement clair avant.
- [ ] **Écran Statistiques d'un podcast** (`podcast_stats_screen.dart`, ajouté 2026-08-03, maquette 4a) : ouvert depuis « Mes podcasts » → menu → Statistiques. Vérifier sur un podcast ayant réellement plusieurs épisodes publiés que les totaux, la moyenne par épisode, le classement des plus écoutés et l'intervalle moyen de publication sont cohérents avec les données. Un podcast sans épisode publié doit afficher le message dédié, pas des zéros.
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

- [ ] **Relais TURN coturn en production** — à valider par un vrai appel en 4G/5G **sans wifi** (cas NAT symétrique, celui que TURN est censé résoudre) ; vérifier aussi que `grep -ci allocation` augmente dans les logs coturn pendant l'appel. Jamais confirmé depuis la rotation de secret du 16/07.

## Messagerie (hors refonte Fil & Discussion)

- [ ] **En-tête hero de la liste des messages** (dégradé + puces de filtre, commit `65c1852`) — jamais vu à l'écran, l'APK était cassé (toolchain JDK 17) au moment du commit.
- [ ] **Accusé de réception « remis »** (`mark_messages_as_delivered`, commit `da21b24`) — bug capturé dans les logs d'un appareil réel puis corrigé côté SQL, jamais revalidé en conditions réelles depuis.
- [ ] **Statut en ligne (Firestore → Supabase)** (commit `b16dc88`) — bug de confidentialité corrigé (préférence `showOnlineStatus` ignorée), jamais vérifié à l'écran.

## Groupes & événements en conversation

- [ ] **Bulle `EventMessageCard` en conversation + différenciation groupe** (commit `267d7d3`) : visibilité « publier dans le fil » DM/groupe, badge Admin sur les bulles, « Vu par N » sur messages de groupe lus, boutons appel/vidéo de groupe dans l'app bar, auto-adhésion au groupe pays au chargement du profil — aucun sous-élément vérifié sur device.

## Sécurité / Comptes connectés

- [ ] **Appareils connectés (#10) migrés vers Supabase `e2ee_devices`** (commit `267d7d3`) — la liste « s'affiche enfin » côté code, jamais confirmé à l'écran.
- [ ] **Flux caméra/galerie/éditeur + permissions manifest** (`WRITE_EXTERNAL_STORAGE`/`READ_MEDIA_IMAGES`/`VIDEO`, réintroduites après une perte accidentelle, commit `9ea9b45`) — jamais revalidées par un flux caméra/galerie réel.

## Admin (back-office)

- [ ] **Migration des 18 écrans admin + `admin_app` vers `AdminColors`** — jamais vérifiée à l'écran ; en particulier la couleur bleu d'action (jamais orange) jamais confirmée visuellement.
- [ ] **Modérateur fantôme — Muet / Exclure / Bloquer** (`ghost_moderator_screen.dart`, ajouté 2026-08-03) : les trois boutons ouvrent une feuille de sélection de participant puis appliquent l'action. Trois choses ne peuvent être vérifiées que sur un salon réel avec deux comptes : que la feuille liste bien les participants visibles (les fantômes doivent en être exclus), que l'action passe réellement les règles RTDB (nécessite `/admins/<uid>: true` dans la Realtime Database — sinon échec silencieux côté règles), et que le SnackBar d'erreur remonte quand ça échoue.
- [ ] **Garde d'accès à la vue fantôme** (`app_router.dart`, ajouté 2026-08-03) : ouvrir `/audio-rooms/<id>/ghost` avec un compte **non** admin doit rediriger vers le salon. Jamais testé avec deux comptes de rôles différents.
- [ ] **Promotion d'un admin propagée aux 3 backends** (`role_management_provider.dart`, ajouté 2026-08-03) : promouvoir un utilisateur depuis l'écran de gestion des rôles doit écrire Firestore **et** `users.is_admin`/`admin_role` dans Postgres **et** `/admins/<uid>` en RTDB. Nécessite la migration `20260803120000_admin_can_manage_admin_flags.sql` poussée, et l'amorçage manuel du premier admin en SQL. Le message d'erreur de désynchronisation n'a jamais été vu à l'écran.

## Salons audio — monétisation

- [ ] **Mention du code PIN conditionnelle** (`buy_ticket_bottom_sheet.dart`, 2026-08-03) : « Code PIN demandé pour confirmer » ne doit apparaître que sous Wave et Mynita, jamais sous Carte bancaire — elle était affichée en pied de feuille quel que soit le moyen choisi. Les lignes de paiement sont maintenant encadrées et cliquables en entier (l'ancien `RadioMenuButton` a été remplacé) : vérifier la zone de tap et le rond de sélection.
- [ ] **Prix dans la devise réelle du salon** (`buy_ticket_bottom_sheet.dart`, `send_tip_bottom_sheet.dart`, 2026-08-03) : le `€` était codé en dur. Un salon facturé en XOF doit afficher « FCFA » (symbole après le montant) partout : prix du billet, commission, part de l'hôte, montants de don, libellé du bouton.
- [ ] **Feuille de don — deux lignes de montant** (`send_tip_bottom_sheet.dart`, 2026-08-03) : « Vous envoyez » puis « <nom> reçoit … (95 %) ». Le sous-titre du destinataire affiche désormais le titre du salon : vérifier l'ellipse sur un titre long.
- [ ] **Bouton Stripe Connect des moyens de paiement** (`add_payment_account_screen.dart`, 2026-08-03) : pointait sur `/audio-rooms/monetization`, route inexistante qui ouvrait un salon vide nommé « monetization ». Doit maintenant ouvrir l'écran des revenus créateur.

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
