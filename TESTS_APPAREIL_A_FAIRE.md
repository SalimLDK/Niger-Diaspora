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
- [ ] **Composer un sondage sur un post** (`create_post_screen.dart` → icône Sondage) : ouverture du sheet, saisie, publication du post d'abord puis création du sondage — vérifier que le sondage apparaît bien après coup sur le post publié.
- [ ] **Composer un lieu sur un post** : `LocationPickerModal` (permission localisation, recherche d'adresse, sélection sur carte), aperçu de la carte statique sur `post_card.dart`.
- [ ] **Vote sur un sondage de post** (`poll_card.dart` réutilisé) : sélection d'option, soumission, affichage des résultats après vote/expiration.
- [ ] **Panneau membres carte** (`map_screen.dart`) : `DraggableScrollableSheet` à 3 positions (18/45/92%), glisser pour changer de position.
- [ ] **Stepper de transfert d'argent** (`send_money_screen.dart`) : indicateur 1 ligne, montants rapides, changement de devise.
- [ ] **Contrôles d'appel** (`call_screen.dart`, `group_call_screen.dart`) : 4 boutons nommés 64px, bouton raccrocher pleine largeur, grille 2×2 en appel de groupe.
- [ ] **"Proches de vous"** (`new_conversation_screen.dart`) : n'apparaît que si permission localisation déjà accordée — vérifier l'affichage et le calcul de distance.
- [ ] **Coloration hashtags en direct** (composer post + commentaire) : `HashtagHighlightingController`, surtout pendant la composition IME (clavier téléphone).
- [ ] **Glisser-pour-répondre** sur une bulle de message : seuil 52px, translation bornée à 90px.
- [ ] **Enregistrement vocal** : 3 états (en cours / annulation armée / verrouillé), gestes de glissement.

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
