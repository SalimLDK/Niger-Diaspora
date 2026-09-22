# Tests à faire sur appareil physique

Tout ce qui n'a pas encore été vérifié sur un vrai téléphone : rendu
visuel, gestes, permissions runtime (caméra, localisation), thème sombre,
comportement réseau réel (temps réel, push, WebRTC, E2EE bout en bout) — ce
que `flutter analyze` et `flutter test` ne couvrent pas.

Coché = vérifié sur appareil. Non coché = jamais testé. Le vérifié part
dans l'archive (voir ci-dessous) ; ce qui devient sans objet — fonction
retirée, doublon, build dépassé, récit de diagnostic — est supprimé, sa
trace reste dans l'historique git (ménage du 2026-09-22 : 25 400 → 10 100
lignes).

**Rangement.** Les entrées sont classées par domaine (titres `# N.`) et, dans
un domaine, de la plus récente à la plus ancienne.

- Une nouvelle entrée se place **en tête de son domaine**, pas en tête du
  fichier.
- Sous son titre, une entrée qui a des cases ouvertes porte sa priorité :
  `**Priorité P1** · importance 4/5 — ce que subit l'utilisateur`, suivie de
  `*Bloqué : …*` si elle ne se fait pas aujourd'hui avec un seul téléphone.
  **P0** : avant toute nouvelle version — fuite de données, plantage, perte
  de données, fonction cœur cassée, publication bloquée. **P1** : fonction
  importante corrigée, jamais vérifiée. **P2** : fonction secondaire ou cas
  limite. **P3** : confort, cosmétique, fonction en pause. Le sommaire trie
  sur cette ligne ; une entrée ouverte qui ne l'a pas y apparaît « à
  classer ».
- Un renvoi vers une autre entrée la **nomme** (« voir « Titre » ») : « plus
  haut » et « plus bas » cessent d'être vrais dès que l'ordre bouge.
- Le sommaire est généré. Après avoir ajouté une entrée ou coché des cases :
  `python tools/index_tests_appareil.py` (`--check` sort en erreur s'il est
  périmé).
- Ce qui est vérifié quitte la liste : `python tools/archiver_tests_appareil.py`
  déplace les entrées entièrement cochées et les cases cochées, notes
  comprises, vers [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md). Un
  renvoi « ✔ N cases déjà vérifiées » reste à leur place. Un titre cité
  (« voir « Titre » ») introuvable ici se cherche là-bas.

<!-- sommaire:debut -->
<!-- Généré par tools/index_tests_appareil.py : ne pas éditer à la main. -->

**1295 cases à cocher, 10 cochées** — 278 entrées sur 290 ont encore des cases ouvertes.

Par priorité, puis par importance (le nombre en tête de ligne est celui des cases ouvertes) :

**P0 — avant toute nouvelle version** (46)

- 10 · [⬜ Temps réel après l'arrière-plan, et texte supprimé dans la liste (2026-09-21)](#-temps-réel-après-larrière-plan-et-texte-supprimé-dans-la-liste-2026-09-21) · *Messagerie*
- 5 · [⬜ Droits d'écriture sur `messages` resserrés : accusés et modification (2026-09-16)](#-droits-décriture-sur-messages-resserrés--accusés-et-modification-2026-09-16) · *Messagerie*
- 8 · [⬜ L'aperçu de la liste dit pourquoi il est vide (2026-09-15)](#-laperçu-de-la-liste-dit-pourquoi-il-est-vide-2026-09-15) · *Messagerie*
- 2 · [⬜ Un fil chiffré survit au redémarrage de l'application (2026-09-15)](#-un-fil-chiffré-survit-au-redémarrage-de-lapplication-2026-09-15) · *Messagerie*
- 5 · [⬜ Un message non envoyé ne disparaît plus, et repart tout seul (2026-09-14)](#-un-message-non-envoyé-ne-disparaît-plus-et-repart-tout-seul-2026-09-14) · *Messagerie*
- 6 · [⬜ Une discussion ouverte ne reste plus prisonnière de son cache (2026-09-14)](#-une-discussion-ouverte-ne-reste-plus-prisonnière-de-son-cache-2026-09-14) · *Messagerie*
- 4 · [⬜ Aucun marqueur technique dans une bulle (2026-09-09)](#-aucun-marqueur-technique-dans-une-bulle-2026-09-09) · *Messagerie*
- 4 · [⬜ Un simple membre pouvait se nommer owner de son propre groupe (2026-09-17)](#-un-simple-membre-pouvait-se-nommer-owner-de-son-propre-groupe-2026-09-17) · *Groupes*
- 1 · [⚠️ Lire les groupes SANS session échoue en production (2026-09-09)](#-lire-les-groupes-sans-session-échoue-en-production-2026-09-09) · *Groupes*
- 2 · [⬜ MLS après un démarrage à froid : lire et envoyer dans une conversation chiffrée (2026-09-16)](#-mls-après-un-démarrage-à-froid--lire-et-envoyer-dans-une-conversation-chiffrée-2026-09-16) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ La notification gardait le ciphertext que le message avait perdu (2026-09-16)](#-la-notification-gardait-le-ciphertext-que-le-message-avait-perdu-2026-09-16) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ Un média chiffré de plus de 10 Mo était illisible (2026-09-16)](#-un-média-chiffré-de-plus-de-10-mo-était-illisible-2026-09-16) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ Ouvrir une discussion ne la bascule plus (2026-09-15)](#-ouvrir-une-discussion-ne-la-bascule-plus-2026-09-15) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ Une conversation ne bascule plus sans ses participants (2026-09-15)](#-une-conversation-ne-bascule-plus-sans-ses-participants-2026-09-15) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ MLS ouvert pour un seul compte (phase 5, 2026-09-15)](#-mls-ouvert-pour-un-seul-compte-phase-5-2026-09-15) · *Chiffrement de bout en bout et clés*
- 5 · [⬜ Signal remis en service : la garde de session sur les lectures de clés (2026-09-14)](#-signal-remis-en-service--la-garde-de-session-sur-les-lectures-de-clés-2026-09-14) · *Chiffrement de bout en bout et clés* · bloqué
- 10 · [⬜ Cinq messages reçus, un seul lisible : la bannière ne s'empilait pas (2026-09-16)](#-cinq-messages-reçus-un-seul-lisible--la-bannière-ne-sempilait-pas-2026-09-16) · *Notifications et push*
- 2 · [⬜ Aperçu MLS quand l'app est OUVERTE (le même message, l'autre isolate)](#-aperçu-mls-quand-lapp-est-ouverte-le-même-message-lautre-isolate) · *Notifications et push*
- 6 · [⬜ Aperçu des notifications MLS reconstruit sur l'appareil (phase 4, Android)](#-aperçu-des-notifications-mls-reconstruit-sur-lappareil-phase-4-android) · *Notifications et push*
- 6 · [⬜ Accepter une demande d'ami : « Erreur de chargement » (2026-09-14)](#-accepter-une-demande-dami---erreur-de-chargement--2026-09-14) · *Notifications et push* · bloqué
- 21 · [⬜ Supprimer mon compte : demande, 30 jours, annulation, purge (2026-09-18)](#-supprimer-mon-compte--demande-30-jours-annulation-purge-2026-09-18) · *Comptes, session et onboarding*
- 9 · [⬜ Expulsion admin et bannissement : ils n'éjectaient personne (2026-09-16)](#-expulsion-admin-et-bannissement--ils-néjectaient-personne-2026-09-16) · *Comptes, session et onboarding*
- 6 · [⬜ Qui peut voir un événement : discussion, groupes, personnes, tout le monde (2026-09-12)](#-qui-peut-voir-un-événement--discussion-groupes-personnes-tout-le-monde-2026-09-12) · *Ambassades, démarches, carte, entreprises et événements*
- 2 · [Réglages/Carte — deux interrupteurs de partage de position désynchronisés (2026-08-13)](#réglagescarte--deux-interrupteurs-de-partage-de-position-désynchronisés-2026-08-13) · *Ambassades, démarches, carte, entreprises et événements*
- 6 · [⬜ 🔴 Bloquer un utilisateur ne bloque rien — corrigé (2026-09-14)](#--bloquer-un-utilisateur-ne-bloque-rien--corrigé-2026-09-14) · *Accueil, profil et réglages* · bloqué
- 8 · [⬜ `users` : un compte connecté lit e-mail, position et jetons d'autrui (2026-09-21)](#-users--un-compte-connecté-lit-e-mail-position-et-jetons-dautrui-2026-09-21) · *Backend, sécurité et observabilité*
- 4 · [⬜ `users` n'est plus lisible sans compte (2026-09-20)](#-users-nest-plus-lisible-sans-compte-2026-09-20) · *Backend, sécurité et observabilité*
- 4 · [⬜ Bloqueurs de publication — Play & iOS (état 2026-09-21)](#-bloqueurs-de-publication--play--ios-état-2026-09-21) · *Publication et plateformes*
- 4 · [⬜ Le serveur ne supprime plus un chemin Storage dicté par le client (2026-09-21)](#-le-serveur-ne-supprime-plus-un-chemin-storage-dicté-par-le-client-2026-09-21) · *Publication et plateformes*
- 5 · [⬜ Divulgation préalable de la localisation (refus Play du 2026-09-09)](#-divulgation-préalable-de-la-localisation-refus-play-du-2026-09-09) · *Publication et plateformes*
- 3 · [⬜ Compte de test dédié : première connexion (2026-09-09)](#-compte-de-test-dédié--première-connexion-2026-09-09) · *Appareils, comptes de test et méthode*
- 4 · [⬜ Écrire dans une conversation exige d'en être participant (2026-09-20)](#-écrire-dans-une-conversation-exige-den-être-participant-2026-09-20) · *Messagerie*
- 3 · [⬜ GIF et sticker envoyés en MLS : la bulle ne montrait rien (2026-09-16)](#-gif-et-sticker-envoyés-en-mls--la-bulle-ne-montrait-rien-2026-09-16) · *Messagerie*
- 6 · [⬜ GIFs via `gif-proxy` — clés sorties de l'APK (2026-08-27)](#-gifs-via-gif-proxy--clés-sorties-de-lapk-2026-08-27) · *Messagerie*
- 3 · [⬜ Citations et modifications : plus de texte en clair (2026-09-09)](#-citations-et-modifications--plus-de-texte-en-clair-2026-09-09) · *Chiffrement de bout en bout et clés* · bloqué
- 3 · [⚠️ La légende d'une photo/vidéo part EN CLAIR (2026-09-09, non corrigé)](#-la-légende-dune-photovidéo-part-en-clair-2026-09-09-non-corrigé) · *Chiffrement de bout en bout et clés* · bloqué
- 6 · [⬜ Clés de repli dérivées, servies par `crypto-keys` (2026-09-06)](#-clés-de-repli-dérivées-servies-par-crypto-keys-2026-09-06) · *Chiffrement de bout en bout et clés*
- 5 · [⬜ 🔴 Modifier son profil réactivait ce qu'on avait coupé (2026-09-18)](#--modifier-son-profil-réactivait-ce-quon-avait-coupé-2026-09-18) · *Accueil, profil et réglages*
- 3 · [⬜ Push arbitraire : type en liste fermée, blocage, quota (2026-09-21)](#-push-arbitraire--type-en-liste-fermée-blocage-quota-2026-09-21) · *Backend, sécurité et observabilité*
- 1 · [⛔ Un groupe dont on est le seul membre refuse TOUS les messages (2026-09-09)](#-un-groupe-dont-on-est-le-seul-membre-refuse-tous-les-messages-2026-09-09) · *Groupes*
- 4 · [🔴 Appels 1-à-1 mis en PAUSE (2026-08-14) — répondre à un appel ne faisait rigoureusement rien](#-appels-1-à-1-mis-en-pause-2026-08-14--répondre-à-un-appel-ne-faisait-rigoureusement-rien) · *Appels*
- 7 · [⬜ Déconnexion forcée « Connecté ailleurs » — trois trous refermés](#-déconnexion-forcée--connecté-ailleurs---trois-trous-refermés) · *Comptes, session et onboarding* · bloqué
- 2 · [⬜ Passage à targetSdk 36 (Android 16) — exigence Play (2026-09-08)](#-passage-à-targetsdk-36-android-16--exigence-play-2026-09-08) · *Publication et plateformes* · bloqué
- 3 · [Appels WebRTC](#appels-webrtc) · *Appels* · bloqué
- 3 · [Sécurité / Comptes connectés](#sécurité--comptes-connectés) · *Comptes, session et onboarding* · bloqué
- 6 · [Bruit dans logcat — deux traces à ne pas re-diagnostiquer (2026-08-05)](#bruit-dans-logcat--deux-traces-à-ne-pas-re-diagnostiquer-2026-08-05) · *Backend, sécurité et observabilité* · bloqué

**P1 — fonction importante, jamais vérifiée** (107)

- 6 · [⬜ Actualisation automatique après coupure ou retour d'arrière-plan (2026-09-13)](#-actualisation-automatique-après-coupure-ou-retour-darrière-plan-2026-09-13) · *Messagerie*
- 5 · [⬜ Groupes officiels de ville (2026-09-14)](#-groupes-officiels-de-ville-2026-09-14) · *Groupes*
- 15 · [⬜ Inviter des membres dans un groupe privé (2026-09-09)](#-inviter-des-membres-dans-un-groupe-privé-2026-09-09) · *Groupes* · bloqué
- 5 · [⬜ « Supprimer pour tous » efface vraiment le contenu (2026-09-16)](#--supprimer-pour-tous--efface-vraiment-le-contenu-2026-09-16) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ L'état MLS ne quitte plus l'appareil (sauvegardes, 2026-09-15)](#-létat-mls-ne-quitte-plus-lappareil-sauvegardes-2026-09-15) · *Chiffrement de bout en bout et clés*
- 2 · [⬜ Banc MLS bout en bout contre la vraie base (phase 3, 2026-09-15)](#-banc-mls-bout-en-bout-contre-la-vraie-base-phase-3-2026-09-15) · *Chiffrement de bout en bout et clés*
- 8 · [Push FCM des messages — chaîne serveur rétablie (2026-08-05)](#push-fcm-des-messages--chaîne-serveur-rétablie-2026-08-05) · *Notifications et push* · bloqué
- 8 · [⬜ Verrou de version minimale et multi-appareil (2026-09-15)](#-verrou-de-version-minimale-et-multi-appareil-2026-09-15) · *Comptes, session et onboarding*
- 6 · [⬜ Onboarding rejoué : une lecture en échec n'est plus « jamais vu » (2026-09-10)](#-onboarding-rejoué--une-lecture-en-échec-nest-plus--jamais-vu--2026-09-10) · *Comptes, session et onboarding*
- 3 · [⛔ Annuaire des ambassades : deux défauts vus sur appareil (2026-09-07)](#-annuaire-des-ambassades--deux-défauts-vus-sur-appareil-2026-09-07) · *Ambassades, démarches, carte, entreprises et événements*
- 8 · [⬜ Présence « En ligne » : elle suit enfin l'état réel (2026-09-22)](#-présence--en-ligne---elle-suit-enfin-létat-réel-2026-09-22) · *Messagerie*
- 3 · [⬜ Le clair des messages exclu des sauvegardes Google et iCloud (2026-09-21)](#-le-clair-des-messages-exclu-des-sauvegardes-google-et-icloud-2026-09-21) · *Messagerie*
- 5 · [⬜ Médias déchiffrés effacés du disque : suppression, déconnexion, compte supprimé (2026-09-21)](#-médias-déchiffrés-effacés-du-disque--suppression-déconnexion-compte-supprimé-2026-09-21) · *Messagerie*
- 4 · [⬜ Message chiffré supprimé pour tous : plus de clair en mémoire ni dans le cache (2026-09-21)](#-message-chiffré-supprimé-pour-tous--plus-de-clair-en-mémoire-ni-dans-le-cache-2026-09-21) · *Messagerie*
- 9 · [⬜ Manquements de la passe du 2026-09-21 : cinq correctifs à voir sur appareil](#-manquements-de-la-passe-du-2026-09-21--cinq-correctifs-à-voir-sur-appareil) · *Messagerie*
- 2 · [⬜ La pastille de non-lus retombe en quittant une discussion chiffrée (2026-09-21)](#-la-pastille-de-non-lus-retombe-en-quittant-une-discussion-chiffrée-2026-09-21) · *Messagerie*
- 3 · [⬜ Les premiers messages reçus restent « Message chiffré » dans la liste (2026-09-21)](#-les-premiers-messages-reçus-restent--message-chiffré--dans-la-liste-2026-09-21) · *Messagerie*
- 7 · [⬜ Ouvrir une discussion lit ce qui est à l'écran, tout de suite (2026-09-16)](#-ouvrir-une-discussion-lit-ce-qui-est-à-lécran-tout-de-suite-2026-09-16) · *Messagerie*
- 6 · [⬜ Lecture par curseur dans les discussions en clair (2026-09-16)](#-lecture-par-curseur-dans-les-discussions-en-clair-2026-09-16) · *Messagerie*
- 5 · [⬜ « Message chiffré » qui ne s'en va pas dans la liste (2026-09-16)](#--message-chiffré--qui-ne-sen-va-pas-dans-la-liste-2026-09-16) · *Messagerie*
- 4 · [✅ Curseur de lecture et séparateur « nouveaux messages » (2026-09-16)](#-curseur-de-lecture-et-séparateur--nouveaux-messages--2026-09-16) · *Messagerie*
- 1 · [⬜ Pastille de non-lus, et séparateur « nouveaux messages » (2026-09-15)](#-pastille-de-non-lus-et-séparateur--nouveaux-messages--2026-09-15) · *Messagerie*
- 3 · [⬜ « Mes notes » s'ouvre sans aller-retour réseau — vérifié SM A515F (2026-09-15)](#--mes-notes--souvre-sans-aller-retour-réseau--vérifié-sm-a515f-2026-09-15) · *Messagerie*
- 4 · [⬜ La liste n'annonce plus « Utilisateur » ni « Message chiffré » (2026-09-15)](#-la-liste-nannonce-plus--utilisateur--ni--message-chiffré--2026-09-15) · *Messagerie*
- 1 · [⬜ Modifier un message chiffré part parfois dans la mauvaise table (2026-09-15)](#-modifier-un-message-chiffré-part-parfois-dans-la-mauvaise-table-2026-09-15) · *Messagerie*
- 9 · [⬜ Messages éphémères — minuteur réparé, purge serveur (2026-09-15)](#-messages-éphémères--minuteur-réparé-purge-serveur-2026-09-15) · *Messagerie*
- 9 · [⬜ Aperçu et compteurs d'une conversation chiffrée (décision J, 2026-09-15)](#-aperçu-et-compteurs-dune-conversation-chiffrée-décision-j-2026-09-15) · *Messagerie*
- 12 · [⬜ Pièces jointes chiffrées — images, documents, audio (C4, 2026-09-14)](#-pièces-jointes-chiffrées--images-documents-audio-c4-2026-09-14) · *Messagerie*
- 8 · [⬜ Désigner quelqu'un ouvre sa discussion, plus le sélecteur (2026-09-14)](#-désigner-quelquun-ouvre-sa-discussion-plus-le-sélecteur-2026-09-14) · *Messagerie*
- 4 · [⬜ En sélection, la bulle ne fait plus que cocher (2026-09-14)](#-en-sélection-la-bulle-ne-fait-plus-que-cocher-2026-09-14) · *Messagerie*
- 2 · [⬜ Sondage : voter se voit enfin, et les votants aussi (2026-09-14)](#-sondage--voter-se-voit-enfin-et-les-votants-aussi-2026-09-14) · *Messagerie*
- 2 · [✅ Un échec de lecture en messagerie se voit, sans effacer l'écran — corrigé, vérifié SM A515F (2026-09-14)](#-un-échec-de-lecture-en-messagerie-se-voit-sans-effacer-lécran--corrigé-vérifié-sm-a515f-2026-09-14) · *Messagerie*
- 4 · [✅ L'identité du correspondant revient seule après une coupure — corrigé, vérifié SM A515F (2026-09-14)](#-lidentité-du-correspondant-revient-seule-après-une-coupure--corrigé-vérifié-sm-a515f-2026-09-14) · *Messagerie*
- 3 · [⬜ Nom et avatar du correspondant dans la liste des discussions (2026-09-13)](#-nom-et-avatar-du-correspondant-dans-la-liste-des-discussions-2026-09-13) · *Messagerie*
- 2 · [⬜ Réactions : double tap, cœur rouge, notification, mise à jour (2026-09-12)](#-réactions--double-tap-cœur-rouge-notification-mise-à-jour-2026-09-12) · *Messagerie*
- 14 · [⬜ Gérer les membres d'un groupe : notices dans le fil, et deux listes d'admins réconciliées (2026-09-17)](#-gérer-les-membres-dun-groupe--notices-dans-le-fil-et-deux-listes-dadmins-réconciliées-2026-09-17) · *Groupes*
- 5 · [⬜ Exclure un membre d'un groupe échouait toujours (2026-09-17)](#-exclure-un-membre-dun-groupe-échouait-toujours-2026-09-17) · *Groupes*
- 4 · [⬜ Noms des candidats à l'invitation et à l'ajout en appel (2026-09-14)](#-noms-des-candidats-à-linvitation-et-à-lajout-en-appel-2026-09-14) · *Groupes*
- 3 · [⛔ Un membre non-admin ne peut pas ouvrir la discussion de son groupe (2026-09-09)](#-un-membre-non-admin-ne-peut-pas-ouvrir-la-discussion-de-son-groupe-2026-09-09) · *Groupes* · bloqué
- 5 · [⬜ Pixel réinstallé : la discussion MLS avec Sim A se rouvre malgré des Welcome périmés (2026-09-21)](#-pixel-réinstallé--la-discussion-mls-avec-sim-a-se-rouvre-malgré-des-welcome-périmés-2026-09-21) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ L'app lancée sans son écran n'inscrit plus d'appareil fantôme (2026-09-16)](#-lapp-lancée-sans-son-écran-ninscrit-plus-dappareil-fantôme-2026-09-16) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ « Chiffré de bout en bout » corrigé sur 8 surfaces, dont la politique de confidentialité (2026-09-16)](#--chiffré-de-bout-en-bout--corrigé-sur-8-surfaces-dont-la-politique-de-confidentialité-2026-09-16) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ La vidéo entre dans le chiffrement (2026-09-16)](#-la-vidéo-entre-dans-le-chiffrement-2026-09-16) · *Chiffrement de bout en bout et clés*
- 7 · [⬜ Code de sécurité d'un appareil MLS (phase 7, 2026-09-15)](#-code-de-sécurité-dun-appareil-mls-phase-7-2026-09-15) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ Recherche, favoris et galerie d'une conversation chiffrée (2026-09-15)](#-recherche-favoris-et-galerie-dune-conversation-chiffrée-2026-09-15) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ Registre d'appareils MLS — inscription à la connexion, KeyPackages, écran (phase 2, 2026-09-15)](#-registre-dappareils-mls--inscription-à-la-connexion-keypackages-écran-phase-2-2026-09-15) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ Distribution des Sender Keys : la même porte, une marche plus loin (2026-09-14)](#-distribution-des-sender-keys--la-même-porte-une-marche-plus-loin-2026-09-14) · *Chiffrement de bout en bout et clés* · bloqué
- 7 · [⬜ Cartes de partage chiffrées au repos (2026-09-09)](#-cartes-de-partage-chiffrées-au-repos-2026-09-09) · *Chiffrement de bout en bout et clés* · bloqué
- 4 · [Messages de groupe qui redeviennent indéchiffrables après réouverture (2026-08-13)](#messages-de-groupe-qui-redeviennent-indéchiffrables-après-réouverture-2026-08-13) · *Chiffrement de bout en bout et clés* · bloqué
- 4 · [⬜ Appel entrant : le nom et la photo de l'appelant viennent de la base (2026-09-21)](#-appel-entrant--le-nom-et-la-photo-de-lappelant-viennent-de-la-base-2026-09-21) · *Appels*
- 4 · [⬜ Notifications entre comptes : le serveur rédige le texte et filtre les données (2026-09-21)](#-notifications-entre-comptes--le-serveur-rédige-le-texte-et-filtre-les-données-2026-09-21) · *Notifications et push*
- 1 · [⬜ Une édition corrige la bannière déjà posée (2026-09-16)](#-une-édition-corrige-la-bannière-déjà-posée-2026-09-16) · *Notifications et push*
- 10 · [⬜ Trois cas de messagerie que les notifications ne couvraient pas (2026-09-16)](#-trois-cas-de-messagerie-que-les-notifications-ne-couvraient-pas-2026-09-16) · *Notifications et push*
- 7 · [⬜ Types, libellés et bascules : trois écarts entre ce qui est écrit et ce qui est lu (2026-09-16)](#-types-libellés-et-bascules--trois-écarts-entre-ce-qui-est-écrit-et-ce-qui-est-lu-2026-09-16) · *Notifications et push*
- 9 · [⬜ Aperçu des notifications MLS sur iOS : une extension, pas un isolate (phase 4, moitié iOS)](#-aperçu-des-notifications-mls-sur-ios--une-extension-pas-un-isolate-phase-4-moitié-ios) · *Notifications et push* · bloqué
- 6 · [Page Notifications à plat + heure sur le seul dernier message d'une rafale (2026-08-23)](#page-notifications-à-plat--heure-sur-le-seul-dernier-message-dune-rafale-2026-08-23) · *Notifications et push*
- 2 · [✅ Lien `diasponiger://` au démarrage à froid — corrigé, vérifié SM A515F (2026-09-14)](#-lien-diasponiger-au-démarrage-à-froid--corrigé-vérifié-sm-a515f-2026-09-14) · *Liens profonds, navigation et QR codes*
- 4 · [⬜ Le scanner de l'accueil lit tous les QR du projet (2026-09-09)](#-le-scanner-de-laccueil-lit-tous-les-qr-du-projet-2026-09-09) · *Liens profonds, navigation et QR codes*
- 1 · [✅ Trois routes plantaient sur un cast non nullable — corrigées et vérifiées SM A515F (2026-09-08)](#-trois-routes-plantaient-sur-un-cast-non-nullable--corrigées-et-vérifiées-sm-a515f-2026-09-08) · *Liens profonds, navigation et QR codes*
- 11 · [Feuille de partage fantôme au démarrage (2026-08-04)](#feuille-de-partage-fantôme-au-démarrage-2026-08-04) · *Liens profonds, navigation et QR codes*
- 2 · [Assistant de configuration du profil](#assistant-de-configuration-du-profil) · *Comptes, session et onboarding*
- 6 · [⬜ Une image seule prend la forme de la photo, plus une bande de 205 px (2026-09-14)](#-une-image-seule-prend-la-forme-de-la-photo-plus-une-bande-de-205-px-2026-09-14) · *Fil, stories, salons audio et podcasts*
- 7 · [⬜ Définition des photos envoyées : plafond levé, double encodage supprimé (2026-09-14)](#-définition-des-photos-envoyées--plafond-levé-double-encodage-supprimé-2026-09-14) · *Fil, stories, salons audio et podcasts*
- 8 · [⬜ Stories : ajouter, supprimer, audience, listes, 24 h (2026-09-12)](#-stories--ajouter-supprimer-audience-listes-24-h-2026-09-12) · *Fil, stories, salons audio et podcasts* · bloqué
- 7 · [⬜ Publications : audience Public / Abonnés / Amis / Moi uniquement (2026-09-12)](#-publications--audience-public--abonnés--amis--moi-uniquement-2026-09-12) · *Fil, stories, salons audio et podcasts* · bloqué
- 10 · [Carte — délai d'affichage des membres autour (2026-08-04)](#carte--délai-daffichage-des-membres-autour-2026-08-04) · *Ambassades, démarches, carte, entreprises et événements*
- 7 · [⬜ Photo de profil : on choisit son cadrage (2026-09-14)](#-photo-de-profil--on-choisit-son-cadrage-2026-09-14) · *Accueil, profil et réglages*
- 6 · [⬜ Champ ville : recherche dans le référentiel (2026-09-13)](#-champ-ville--recherche-dans-le-référentiel-2026-09-13) · *Accueil, profil et réglages*
- 7 · [Bascule en anglais — ~1 600 chaînes branchées, rien vu à l'écran (2026-08-06)](#bascule-en-anglais--1-600-chaînes-branchées-rien-vu-à-lécran-2026-08-06) · *Design, thème, langue et mise en page* · bloqué
- 3 · [⬜ Les echecs attrapes remontent enfin a Crashlytics (2026-09-14)](#-les-echecs-attrapes-remontent-enfin-a-crashlytics-2026-09-14) · *Backend, sécurité et observabilité*
- 5 · [⬜ Balayage des invariants de données — 2 anomalies en production (2026-09-14)](#-balayage-des-invariants-de-données--2-anomalies-en-production-2026-09-14) · *Backend, sécurité et observabilité* · bloqué
- 1 · [Storage — énumération des médias coupée (2026-08-04, DÉPLOYÉ)](#storage--énumération-des-médias-coupée-2026-08-04-déployé) · *Backend, sécurité et observabilité*
- 3 · [⬜ Storage : on dépose, on ne réécrit plus (2026-09-21)](#-storage--on-dépose-on-ne-réécrit-plus-2026-09-21) · *Publication et plateformes*
- 2 · [⛔ « Diaspo Niger s'arrête systématiquement » sur Android 15+ (2026-09-09)](#--diaspo-niger-sarrête-systématiquement--sur-android-15-2026-09-09) · *Publication et plateformes*
- 4 · [⚠️ Rapatriement iOS : deux dépendances **Android** changent de version majeure (2026-09-08)](#-rapatriement-ios--deux-dépendances-android-changent-de-version-majeure-2026-09-08) · *Publication et plateformes*
- 9 · [⬜ La page de suppression de compte demande la suppression au lieu de l'exécuter (2026-09-19)](#-la-page-de-suppression-de-compte-demande-la-suppression-au-lieu-de-lexécuter-2026-09-19) · *Site web*
- 9 · [⬜ Accusés, réactions, modifications et suppressions reçus en direct, discussion en clair (2026-09-21)](#-accusés-réactions-modifications-et-suppressions-reçus-en-direct-discussion-en-clair-2026-09-21) · *Messagerie*
- 9 · [⬜ Partager vers une discussion — groupe et 1:1 (2026-09-09)](#-partager-vers-une-discussion--groupe-et-11-2026-09-09) · *Messagerie*
- 2 · [Accusés livré/lu séparés — sheet infos du message (2026-08-13)](#accusés-livrélu-séparés--sheet-infos-du-message-2026-08-13) · *Messagerie* · bloqué
- 8 · [⬜ Pays en toutes lettres : groupes officiels et filtre par pays (2026-09-13)](#-pays-en-toutes-lettres--groupes-officiels-et-filtre-par-pays-2026-09-13) · *Groupes*
- 3 · [⬜ Groupe privé par lien : demander à rejoindre (2026-09-10)](#-groupe-privé-par-lien--demander-à-rejoindre-2026-09-10) · *Groupes* · bloqué
- 8 · [⬜ Acceptation et départ d'un groupe : rien ne bougeait chez les autres (2026-09-09)](#-acceptation-et-départ-dun-groupe--rien-ne-bougeait-chez-les-autres-2026-09-09) · *Groupes* · bloqué
- 7 · [Groupes — défauts trouvés en vérifiant les épingles (2026-08-05)](#groupes--défauts-trouvés-en-vérifiant-les-épingles-2026-08-05) · *Groupes*
- 1 · [✅ Le bandeau « 1 message non lu » d'une conversation basculée (2026-09-15)](#-le-bandeau--1-message-non-lu--dune-conversation-basculée-2026-09-15) · *Chiffrement de bout en bout et clés*
- 8 · [⬜ Transfert des clés par QR, sans passphrase (2026-09-08)](#-transfert-des-clés-par-qr-sans-passphrase-2026-09-08) · *Chiffrement de bout en bout et clés* · bloqué
- 5 · [⬜ Réglages de notification par type : local et serveur ne divergent plus (2026-09-18)](#-réglages-de-notification-par-type--local-et-serveur-ne-divergent-plus-2026-09-18) · *Notifications et push*
- 7 · [⬜ La messagerie sort de l'écran Notifications (2026-09-13)](#-la-messagerie-sort-de-lécran-notifications-2026-09-13) · *Notifications et push*
- 6 · [⬜ Notifications ouvertes ailleurs ou obsolètes : lues (2026-09-12)](#-notifications-ouvertes-ailleurs-ou-obsolètes--lues-2026-09-12) · *Notifications et push*
- 4 · [Réponse rapide depuis la notification n'envoyait jamais rien (2026-08-13)](#réponse-rapide-depuis-la-notification-nenvoyait-jamais-rien-2026-08-13) · *Notifications et push* · bloqué
- 2 · [✅ Repli navigateur des liens d'app — DÉPLOYÉ (2026-09-09 21:5x)](#-repli-navigateur-des-liens-dapp--déployé-2026-09-09-215x) · *Liens profonds, navigation et QR codes*
- 1 · [⚠️ Hors ligne, un compte connecté est renvoyé sur l'onboarding (2026-09-10)](#-hors-ligne-un-compte-connecté-est-renvoyé-sur-lonboarding-2026-09-10) · *Comptes, session et onboarding*
- 3 · [Blocage, sens inverse — RLS prouvée en base (2026-08-06)](#blocage-sens-inverse--rls-prouvée-en-base-2026-08-06) · *Comptes, session et onboarding*
- 3 · [⬜ Fil : tirer pour rafraîchir partout, et pastille « N nouvelles publications » (2026-09-14)](#-fil--tirer-pour-rafraîchir-partout-et-pastille--n-nouvelles-publications--2026-09-14) · *Fil, stories, salons audio et podcasts*
- 2 · [⬜ Compteurs de commentaires et de repartages justes (2026-09-12)](#-compteurs-de-commentaires-et-de-repartages-justes-2026-09-12) · *Fil, stories, salons audio et podcasts*
- 17 · [Refonte Fil & Discussion — Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser)](#refonte-fil--discussion--priorité-haute--gestes-minuteurs-permissions-le-plus-susceptible-de-casser) · *Fil, stories, salons audio et podcasts*
- 5 · [⬜ Événement supprimé : il disparaît partout (2026-09-12)](#-événement-supprimé--il-disparaît-partout-2026-09-12) · *Ambassades, démarches, carte, entreprises et événements*
- 11 · [Quatrième vague — écrans repris en production (2026-08-03)](#quatrième-vague--écrans-repris-en-production-2026-08-03) · *Design, thème, langue et mise en page* · bloqué
- 5 · [⬜ `public.friends` : le serveur seul écrit l'audience (2026-09-21)](#-publicfriends--le-serveur-seul-écrit-laudience-2026-09-21) · *Backend, sécurité et observabilité*
- 5 · [⬜ Configuration distante `app-config` (2026-08-27)](#-configuration-distante-app-config-2026-08-27) · *Backend, sécurité et observabilité*
- 5 · [⬜ Notice « une nouvelle version est disponible » (2026-09-14)](#-notice--une-nouvelle-version-est-disponible--2026-09-14) · *Publication et plateformes*
- 2 · [⬜ Deux bibliothèques natives réalignées sur 16 Ko (2026-09-08)](#-deux-bibliothèques-natives-réalignées-sur-16-ko-2026-09-08) · *Publication et plateformes*
- 2 · [Messagerie (hors refonte Fil & Discussion)](#messagerie-hors-refonte-fil--discussion) · *Messagerie* · bloqué
- 9 · [Groupes — « Découvrir » lisait le mauvais backend (2026-08-06)](#groupes---découvrir--lisait-le-mauvais-backend-2026-08-06) · *Groupes*
- 5 · [Demandes d'adhésion — brancher Supabase n'avait pas suffi (2026-08-06)](#demandes-dadhésion--brancher-supabase-navait-pas-suffi-2026-08-06) · *Groupes* · bloqué
- 1 · [La porte d'entrée des groupes était grande ouverte (2026-08-06)](#la-porte-dentrée-des-groupes-était-grande-ouverte-2026-08-06) · *Groupes* · bloqué
- 7 · [Bascule design_v2 → production : la carte (§7e, 2026-08-03)](#bascule-design_v2--production--la-carte-7e-2026-08-03) · *Design, thème, langue et mise en page* · bloqué
- 4 · [« Se connecter avec Apple » ajouté (2026-09-01)](#-se-connecter-avec-apple--ajouté-2026-09-01) · *Publication et plateformes* · bloqué

**P2 — fonction secondaire ou cas limite** (89)

- 7 · [⬜ Site web : menu mobile, liens partagés, aperçus de partage (2026-09-08)](#-site-web--menu-mobile-liens-partagés-aperçus-de-partage-2026-09-08) · *Site web*
- 3 · [✅ Vidéos envoyées en messagerie traitées comme des documents (2026-08-30)](#-vidéos-envoyées-en-messagerie-traitées-comme-des-documents-2026-08-30) · *Messagerie*
- 5 · [⬜ Heure et accusé sur tous les messages, bascule supprimée (2026-08-23)](#-heure-et-accusé-sur-tous-les-messages-bascule-supprimée-2026-08-23) · *Messagerie*
- 8 · [Le sondage de groupe s'affiche enfin : bulle dans la discussion (2026-08-24)](#le-sondage-de-groupe-saffiche-enfin--bulle-dans-la-discussion-2026-08-24) · *Groupes*
- 3 · [✅ Événements sur Supabase — BASCULÉ et vérifié SM A515F (2026-09-09 22:35)](#-événements-sur-supabase--basculé-et-vérifié-sm-a515f-2026-09-09-2235) · *Ambassades, démarches, carte, entreprises et événements*
- 8 · [Fiches d'écrans (Claude Design) — reprise écran par écran (2026-08-04)](#fiches-décrans-claude-design--reprise-écran-par-écran-2026-08-04) · *Design, thème, langue et mise en page*
- 5 · [Reprise du design (2026-08-03, suite) — Éco, accueil, carte, discussion](#reprise-du-design-2026-08-03-suite--éco-accueil-carte-discussion) · *Design, thème, langue et mise en page* · bloqué
- 5 · [Bascule design_v2 → production, famille 4 : messagerie, groupes, recherche, profil (2026-08-03)](#bascule-design_v2--production-famille-4--messagerie-groupes-recherche-profil-2026-08-03) · *Design, thème, langue et mise en page*
- 7 · [⬜ Site web entièrement refait sur cahier des charges (2026-09-08)](#-site-web-entièrement-refait-sur-cahier-des-charges-2026-09-08) · *Site web*
- 3 · [⬜ « Supprimer pour tous » proposé sur le message de l'autre en 1:1 (2026-09-21)](#--supprimer-pour-tous--proposé-sur-le-message-de-lautre-en-11-2026-09-21) · *Messagerie*
- 3 · [⬜ Le séparateur « N messages non lus » part quand tout est lu (2026-09-17)](#-le-séparateur--n-messages-non-lus--part-quand-tout-est-lu-2026-09-17) · *Messagerie*
- 3 · [⬜ « Distribué » et « Lu » ne tombent plus à la même seconde (2026-09-16)](#--distribué--et--lu--ne-tombent-plus-à-la-même-seconde-2026-09-16) · *Messagerie*
- 1 · [⬜ Forme de la bulle qui cite un message (2026-09-16)](#-forme-de-la-bulle-qui-cite-un-message-2026-09-16) · *Messagerie*
- 4 · [⬜ « Modifier le message » : saisie en ligne, fenêtre de 48 h, motifs dits (2026-09-16)](#--modifier-le-message---saisie-en-ligne-fenêtre-de-48-h-motifs-dits-2026-09-16) · *Messagerie*
- 5 · [⬜ Le repère de bascule ne parle plus français à tout le monde (2026-09-15)](#-le-repère-de-bascule-ne-parle-plus-français-à-tout-le-monde-2026-09-15) · *Messagerie*
- 2 · [⬜ « Sélectionner » sort de « Autres actions » (2026-09-14)](#--sélectionner--sort-de--autres-actions--2026-09-14) · *Messagerie*
- 1 · [⬜ Sondage dans une discussion privée (2026-09-12)](#-sondage-dans-une-discussion-privée-2026-09-12) · *Messagerie*
- 5 · [⬜ Cartes de post et d'événement lisibles dans une bulle envoyée (2026-09-12)](#-cartes-de-post-et-dévénement-lisibles-dans-une-bulle-envoyée-2026-09-12) · *Messagerie*
- 4 · [⬜ Copier : légendes, positions, sondages, un passage, une sélection (2026-09-12)](#-copier--légendes-positions-sondages-un-passage-une-sélection-2026-09-12) · *Messagerie*
- 6 · [Messagerie — un filtre sans résultat n'est pas une messagerie vide (2026-08-06)](#messagerie--un-filtre-sans-résultat-nest-pas-une-messagerie-vide-2026-08-06) · *Messagerie*
- 3 · [Composeur — largeur de la pilule et « + » en clair (2026-08-05)](#composeur--largeur-de-la-pilule-et----en-clair-2026-08-05) · *Messagerie*
- 2 · [Recherche messagerie — le clavier demandait deux taps (§9b, 2026-08-04)](#recherche-messagerie--le-clavier-demandait-deux-taps-9b-2026-08-04) · *Messagerie*
- 4 · [Zone de saisie des messages — barre multi-ligne (2026-08-04)](#zone-de-saisie-des-messages--barre-multi-ligne-2026-08-04) · *Messagerie*
- 5 · [⬜ Groupes : non-lus depuis l'arrivée, messages système, « Lu » par tous (2026-09-17)](#-groupes--non-lus-depuis-larrivée-messages-système--lu--par-tous-2026-09-17) · *Groupes*
- 5 · [⬜ Groupe privé : un nouveau membre ne voit plus ce qui précède son arrivée (2026-09-16)](#-groupe-privé--un-nouveau-membre-ne-voit-plus-ce-qui-précède-son-arrivée-2026-09-16) · *Groupes*
- 5 · [⬜ Quitter l'ancien groupe officiel : proposé après 6 mois, jamais imposé (2026-09-13)](#-quitter-lancien-groupe-officiel--proposé-après-6-mois-jamais-imposé-2026-09-13) · *Groupes* · bloqué
- 2 · [⬜ Fiche « Membres » d'un groupe : « Erreur de chargement » (2026-09-09)](#-fiche--membres--dun-groupe---erreur-de-chargement--2026-09-09) · *Groupes*
- 3 · [Créer un sondage était impossible pour tout le monde (2026-08-23)](#créer-un-sondage-était-impossible-pour-tout-le-monde-2026-08-23) · *Groupes*
- 3 · [Mentions de groupe : vérifié sur SM A515F (2026-08-23)](#mentions-de-groupe--vérifié-sur-sm-a515f-2026-08-23) · *Groupes*
- 4 · [⬜ « Appareils enregistrés » et « Sauvegarde des clés » ne montrent plus Signal à un compte passé à MLS (2026-09-16)](#--appareils-enregistrés--et--sauvegarde-des-clés--ne-montrent-plus-signal-à-un-compte-passé-à-mls-2026-09-16) · *Chiffrement de bout en bout et clés*
- 6 · [⬜ Les deux bandeaux de clés retirés : ils promettaient faux (2026-09-16)](#-les-deux-bandeaux-de-clés-retirés--ils-promettaient-faux-2026-09-16) · *Chiffrement de bout en bout et clés*
- 3 · [⬜ L'expéditeur MLS datait lui-même ses propres messages (2026-09-15)](#-lexpéditeur-mls-datait-lui-même-ses-propres-messages-2026-09-15) · *Chiffrement de bout en bout et clés*
- 4 · [⬜ L'appartenance MLS se réconcilie au moment du changement (phase 8, 2026-09-15)](#-lappartenance-mls-se-réconcilie-au-moment-du-changement-phase-8-2026-09-15) · *Chiffrement de bout en bout et clés*
- 16 · [⬜ Notifications lues à l'ouverture de leur écran : profil, groupe, commandes, fiche, mentions (2026-09-19)](#-notifications-lues-à-louverture-de-leur-écran--profil-groupe-commandes-fiche-mentions-2026-09-19) · *Notifications et push*
- 5 · [⬜ Cycle de vie d'une demande d'ami : six trous soldés (2026-09-15)](#-cycle-de-vie-dune-demande-dami--six-trous-soldés-2026-09-15) · *Notifications et push* · bloqué
- 2 · [✅ Filtre hashtag : réparé et vérifié sur SM A515F (2026-09-14)](#-filtre-hashtag--réparé-et-vérifié-sur-sm-a515f-2026-09-14) · *Liens profonds, navigation et QR codes*
- 4 · [⬜ Un lien Diaspo Niger dans une discussion sortait de l'app (2026-09-12)](#-un-lien-diaspo-niger-dans-une-discussion-sortait-de-lapp-2026-09-12) · *Liens profonds, navigation et QR codes*
- 2 · [⬜ Lien « Inviter un proche » : il ne menait nulle part (2026-09-09)](#-lien--inviter-un-proche---il-ne-menait-nulle-part-2026-09-09) · *Liens profonds, navigation et QR codes*
- 2 · [✅ Fiche d'ambassade par lien profond : écran rouge — corrigé et vérifié SM A515F (2026-09-08)](#-fiche-dambassade-par-lien-profond--écran-rouge--corrigé-et-vérifié-sm-a515f-2026-09-08) · *Liens profonds, navigation et QR codes*
- 4 · [⬜ Compteurs de Mon espace et du Profil : ils suivent enfin (2026-09-14)](#-compteurs-de-mon-espace-et-du-profil--ils-suivent-enfin-2026-09-14) · *Fil, stories, salons audio et podcasts*
- 2 · [⬜ Supprimer une publication depuis le fil ne ramène plus à l'accueil (2026-09-12)](#-supprimer-une-publication-depuis-le-fil-ne-ramène-plus-à-laccueil-2026-09-12) · *Fil, stories, salons audio et podcasts*
- 10 · [Refonte Fil & Discussion — Priorité moyenne — layout & responsive](#refonte-fil--discussion--priorité-moyenne--layout--responsive) · *Fil, stories, salons audio et podcasts*
- 2 · [⚠️ Carte : bouton « Message » de la fiche membre et icône de la liste des membres proches — corrigés, vérifiés SM A515F (partiel, 2026-09-17)](#-carte--bouton--message--de-la-fiche-membre-et-icône-de-la-liste-des-membres-proches--corrigés-vérifiés-sm-a515f-partiel-2026-09-17) · *Ambassades, démarches, carte, entreprises et événements*
- 7 · [⬜ Ambassades : « officiel / vérifié » **et** les horaires mis en sommeil (2026-09-08)](#-ambassades---officiel--vérifié--et-les-horaires-mis-en-sommeil-2026-09-08) · *Ambassades, démarches, carte, entreprises et événements*
- 6 · [Postes diplomatiques sur la carte : 30 pins sur 32 (2026-09-08)](#postes-diplomatiques-sur-la-carte--30-pins-sur-32-2026-09-08) · *Ambassades, démarches, carte, entreprises et événements*
- 9 · [⬜ Démarches consulaires : données réelles à la place des délais inventés (2026-09-07)](#-démarches-consulaires--données-réelles-à-la-place-des-délais-inventés-2026-09-07) · *Ambassades, démarches, carte, entreprises et événements*
- 2 · [⬜ Modifier le profil : libellés tronqués et code SMS illisible (2026-09-21)](#-modifier-le-profil--libellés-tronqués-et-code-sms-illisible-2026-09-21) · *Accueil, profil et réglages*
- 9 · [⬜ Un refus du serveur ne ment plus : interrupteurs, snackbars, connexion admin (2026-09-18)](#-un-refus-du-serveur-ne-ment-plus--interrupteurs-snackbars-connexion-admin-2026-09-18) · *Accueil, profil et réglages*
- 5 · [⬜ L'écran des appareils ne promet plus ce qu'il ne fait pas (2026-09-16)](#-lécran-des-appareils-ne-promet-plus-ce-quil-ne-fait-pas-2026-09-16) · *Accueil, profil et réglages*
- 5 · [⬜ Noter l'application : bouton des Réglages et invitation automatique (2026-09-14)](#-noter-lapplication--bouton-des-réglages-et-invitation-automatique-2026-09-14) · *Accueil, profil et réglages*
- 3 · [⬜ Groupes en commun ouvrables depuis un profil (2026-09-13)](#-groupes-en-commun-ouvrables-depuis-un-profil-2026-09-13) · *Accueil, profil et réglages*
- 6 · [Pseudo (@handle) — ligne d'appel sur son propre profil](#pseudo-handle--ligne-dappel-sur-son-propre-profil) · *Accueil, profil et réglages*
- 1 · [⬜ L'en-tête d'un sondage effaçait son auteur dans une bulle — corrigé, à revoir (2026-09-15)](#-len-tête-dun-sondage-effaçait-son-auteur-dans-une-bulle--corrigé-à-revoir-2026-09-15) · *Design, thème, langue et mise en page*
- 1 · [⬜ Le pied d'un sondage déborde encore en mode vote — NON corrigé (2026-09-15)](#-le-pied-dun-sondage-déborde-encore-en-mode-vote--non-corrigé-2026-09-15) · *Design, thème, langue et mise en page*
- 7 · [⬜ L'étape « Thème » dit enfin la vérité sur l'accent (2026-09-14)](#-létape--thème--dit-enfin-la-vérité-sur-laccent-2026-09-14) · *Design, thème, langue et mise en page*
- 2 · [⬜ Le sigle DN est le même partout (2026-09-13)](#-le-sigle-dn-est-le-même-partout-2026-09-13) · *Design, thème, langue et mise en page*
- 1 · [Thème sombre — jetons clairs codés en dur](#thème-sombre--jetons-clairs-codés-en-dur) · *Design, thème, langue et mise en page*
- 4 · [Bascule design_v2 → production, famille 2 : les services (2026-08-03)](#bascule-design_v2--production-famille-2--les-services-2026-08-03) · *Design, thème, langue et mise en page*
- 5 · [⬜ Avis sur les entreprises : basculés de Firestore vers Supabase (2026-09-21)](#-avis-sur-les-entreprises--basculés-de-firestore-vers-supabase-2026-09-21) · *Backend, sécurité et observabilité*
- 5 · [Fuseau horaire — heures affichées en UTC (2026-08-04)](#fuseau-horaire--heures-affichées-en-utc-2026-08-04) · *Backend, sécurité et observabilité*
- 7 · [Admin (back-office)](#admin-back-office) · *Backend, sécurité et observabilité*
- 2 · [⬜ Le `.env` embarqué ne livre plus de chemin de poste (2026-09-21)](#-le-env-embarqué-ne-livre-plus-de-chemin-de-poste-2026-09-21) · *Publication et plateformes*
- 7 · [iOS : premier build réussi, sur simulateur (2026-09-01)](#ios--premier-build-réussi-sur-simulateur-2026-09-01) · *Publication et plateformes* · bloqué
- 13 · [Passe pilotée du 2026-08-04 (15:25 → 16:05) — SM A515F, APK debug `54083d6`](#passe-pilotée-du-2026-08-04-1525--1605--sm-a515f-apk-debug-54083d6) · *Journaux de passes appareil*
- 3 · [Fonctionnalité épingle mise en pause (2026-08-14)](#fonctionnalité-épingle-mise-en-pause-2026-08-14) · *Messagerie*
- 1 · [Réactions emoji : une par personne et par message (2026-08-13)](#réactions-emoji--une-par-personne-et-par-message-2026-08-13) · *Messagerie* · bloqué
- 7 · [Discussion — l'horodatage sort de la bulle (fiches 4a/6b, 2026-08-05)](#discussion--lhorodatage-sort-de-la-bulle-fiches-4a6b-2026-08-05) · *Messagerie*
- 10 · [Panneau stickers / GIF / émojis (fiche 26b, 2026-08-05)](#panneau-stickers--gif--émojis-fiche-26b-2026-08-05) · *Messagerie*
- 3 · [⬜ Réorganisation des tuiles de « Mes groupes » + vue grille (2026-09-15)](#-réorganisation-des-tuiles-de--mes-groupes---vue-grille-2026-09-15) · *Groupes*
- 1 · [Groupes & événements en conversation](#groupes--événements-en-conversation) · *Groupes*
- 1 · [Fiche membres de groupe bloquée / vide (2026-08-13)](#fiche-membres-de-groupe-bloquée--vide-2026-08-13) · *Groupes* · bloqué
- 2 · [⬜ Clé AES de repli : Firebase Functions avait divergé (2026-09-06)](#-clé-aes-de-repli--firebase-functions-avait-divergé-2026-09-06) · *Chiffrement de bout en bout et clés* · bloqué
- 3 · [E2EE & chiffrement (priorité haute — sécurité)](#e2ee--chiffrement-priorité-haute--sécurité) · *Chiffrement de bout en bout et clés*
- 1 · [Aperçu de notification en clair (2026-08-13)](#aperçu-de-notification-en-clair-2026-08-13) · *Notifications et push* · bloqué
- 2 · [✅ Lien profond perdu sur une activité neuve — corrigé, vérifié SM A515F (2026-09-11)](#-lien-profond-perdu-sur-une-activité-neuve--corrigé-vérifié-sm-a515f-2026-09-11) · *Liens profonds, navigation et QR codes* · bloqué
- 2 · [⬜ « Session Supabase non établie » ne compte plus comme un plantage (2026-09-11)](#--session-supabase-non-établie--ne-compte-plus-comme-un-plantage-2026-09-11) · *Comptes, session et onboarding*
- 5 · [✅ Annuaire des ambassades : Firestore → Supabase, 32 postes chargés (2026-09-07)](#-annuaire-des-ambassades--firestore--supabase-32-postes-chargés-2026-09-07) · *Ambassades, démarches, carte, entreprises et événements* · bloqué
- 4 · [Position des entreprises : création/édition alimentent enfin latitude/longitude (2026-08-19)](#position-des-entreprises--créationédition-alimentent-enfin-latitudelongitude-2026-08-19) · *Ambassades, démarches, carte, entreprises et événements*
- 3 · [Flags Salons audio / Podcasts / Fil enfin sérialisés + maintenance sans écrasement (2026-08-19)](#flags-salons-audio--podcasts--fil-enfin-sérialisés--maintenance-sans-écrasement-2026-08-19) · *Accueil, profil et réglages* · bloqué
- 3 · [⬜ Grand titre d'en-tête : plus de mot coupé (2026-09-12)](#-grand-titre-den-tête--plus-de-mot-coupé-2026-09-12) · *Design, thème, langue et mise en page*
- 7 · [Le « OVERFLOWED BY 190 » de la recherche venait du rail latéral (2026-08-05)](#le--overflowed-by-190--de-la-recherche-venait-du-rail-latéral-2026-08-05) · *Design, thème, langue et mise en page*
- 5 · [Menus déroulants bornés partout (`isExpanded`, 2026-08-04)](#menus-déroulants-bornés-partout-isexpanded-2026-08-04) · *Design, thème, langue et mise en page*
- 2 · [Bascule design_v2 → production, famille 3 : boutique, support, transferts, appels (2026-08-03)](#bascule-design_v2--production-famille-3--boutique-support-transferts-appels-2026-08-03) · *Design, thème, langue et mise en page*
- 2 · [⬜ Les quatre défauts de la console, triés par appareil (2026-09-10)](#-les-quatre-défauts-de-la-console-triés-par-appareil-2026-09-10) · *Backend, sécurité et observabilité* · bloqué
- 3 · [⬜ Journalisation : deux fuites en release et la garde du LoggerService (2026-09-09)](#-journalisation--deux-fuites-en-release-et-la-garde-du-loggerservice-2026-09-09) · *Backend, sécurité et observabilité* · bloqué
- 1 · [Liens profonds iOS : la moitié testable est bonne (2026-09-01)](#liens-profonds-ios--la-moitié-testable-est-bonne-2026-09-01) · *Publication et plateformes* · bloqué
- 1 · [Session du 2026-08-03 (soir) — SM A515F, refonte enfin lancée](#session-du-2026-08-03-soir--sm-a515f-refonte-enfin-lancée) · *Journaux de passes appareil*
- 2 · [✅ Bulle de chargement d'une vidéo pendant l'upload (2026-08-30)](#-bulle-de-chargement-dune-vidéo-pendant-lupload-2026-08-30) · *Messagerie*
- 21 · [Refonte Fil & Discussion — Priorité basse — cosmétique, faible risque](#refonte-fil--discussion--priorité-basse--cosmétique-faible-risque) · *Fil, stories, salons audio et podcasts*

**P3 — confort, cosmétique, fonction en pause** (36)

- 3 · [⬜ Polices embarquées : plus de téléchargement au premier affichage (2026-09-11)](#-polices-embarquées--plus-de-téléchargement-au-premier-affichage-2026-09-11) · *Design, thème, langue et mise en page* · bloqué
- 2 · [⬜ Icône du lanceur repeinte en vert (2026-09-07)](#-icône-du-lanceur-repeinte-en-vert-2026-09-07) · *Design, thème, langue et mise en page*
- 1 · [⬜ Plugin Gradle Crashlytics : les piles n'étaient pas déchiffrables (2026-09-09)](#-plugin-gradle-crashlytics--les-piles-nétaient-pas-déchiffrables-2026-09-09) · *Backend, sécurité et observabilité* · bloqué
- 1 · [Discussion — heure absente/dupliquée sur les bulles média (2026-08-30)](#discussion--heure-absentedupliquée-sur-les-bulles-média-2026-08-30) · *Messagerie*
- 5 · [Brouillon restauré — le composer restait sur le micro (2026-08-04)](#brouillon-restauré--le-composer-restait-sur-le-micro-2026-08-04) · *Messagerie*
- 4 · [✅ Quatre écrans sans flèche de retour — corrigés et vérifiés SM A515F (2026-09-08)](#-quatre-écrans-sans-flèche-de-retour--corrigés-et-vérifiés-sm-a515f-2026-09-08) · *Liens profonds, navigation et QR codes*
- 9 · [⬜ Point d'accent après chaque titre d'écran (2026-09-13)](#-point-daccent-après-chaque-titre-décran-2026-09-13) · *Design, thème, langue et mise en page*
- 4 · [⬜ Teinte des notifications système en vert (2026-09-07)](#-teinte-des-notifications-système-en-vert-2026-09-07) · *Design, thème, langue et mise en page* · bloqué
- 2 · [⬜ Écran de démarrage repeint en vert (2026-09-07)](#-écran-de-démarrage-repeint-en-vert-2026-09-07) · *Design, thème, langue et mise en page*
- 5 · [Guide de style — alignement des jetons (2026-08-03)](#guide-de-style--alignement-des-jetons-2026-08-03) · *Design, thème, langue et mise en page*
- 3 · [⬜ Les ~920 `debugPrint` restants neutralisés en release (2026-09-09)](#-les-920-debugprint-restants-neutralisés-en-release-2026-09-09) · *Backend, sécurité et observabilité* · bloqué
- 2 · [⬜ Fiches de partage : libellés sur une ligne, vrais logos, bouton (2026-09-20)](#-fiches-de-partage--libellés-sur-une-ligne-vrais-logos-bouton-2026-09-20) · *Messagerie*
- 6 · [⬜ Squelette de chargement de la messagerie (2026-09-15)](#-squelette-de-chargement-de-la-messagerie-2026-09-15) · *Messagerie*
- 7 · [⬜ Une couleur par pièce jointe dans le « + » (2026-09-14)](#-une-couleur-par-pièce-jointe-dans-le----2026-09-14) · *Messagerie*
- 6 · [Discussion — ÉCO rejoint la ligne épinglée (fiche 6b, 2026-08-05)](#discussion--éco-rejoint-la-ligne-épinglée-fiche-6b-2026-08-05) · *Messagerie*
- 4 · [⬜ Les appels de GROUPE restaient lançables alors que le 1-à-1 était en pause (2026-09-14)](#-les-appels-de-groupe-restaient-lançables-alors-que-le-1-à-1-était-en-pause-2026-09-14) · *Appels*
- 1 · [La bulle d'appel elle-même n'apparaissait jamais dans la conversation (2026-08-14)](#la-bulle-dappel-elle-même-napparaissait-jamais-dans-la-conversation-2026-08-14) · *Appels* · bloqué
- 7 · [Appels 1-à-1 (correctifs du 2026-08-03)](#appels-1-à-1-correctifs-du-2026-08-03) · *Appels* · bloqué
- 1 · [Scroll des notifications — mesuré, pas un défaut de l'écran (2026-08-06)](#scroll-des-notifications--mesuré-pas-un-défaut-de-lécran-2026-08-06) · *Notifications et push*
- 1 · [⚠️ Déconnexion — latence supprimée, à vérifier sur appareil](#-déconnexion--latence-supprimée-à-vérifier-sur-appareil) · *Comptes, session et onboarding*
- 2 · [⬜ Fil sombre : même structure que le fil clair (2026-09-13)](#-fil-sombre--même-structure-que-le-fil-clair-2026-09-13) · *Fil, stories, salons audio et podcasts*
- 2 · [✅ Profil : la carte de statistiques débordait par la droite — corrigé et vérifié Pixel 10 Pro XL (2026-09-08)](#-profil--la-carte-de-statistiques-débordait-par-la-droite--corrigé-et-vérifié-pixel-10-pro-xl-2026-09-08) · *Accueil, profil et réglages*
- 2 · [⬜ Deux textes du fil que `font_scale` 1.3 abime — corrigés, à revoir (2026-09-14)](#-deux-textes-du-fil-que-font_scale-13-abime--corrigés-à-revoir-2026-09-14) · *Design, thème, langue et mise en page*
- 2 · [⬜ Une couleur par service dans les deux grilles (2026-09-14)](#-une-couleur-par-service-dans-les-deux-grilles-2026-09-14) · *Design, thème, langue et mise en page*
- 3 · [Débordement du champ « Type * » — création d'ambassade (2026-08-04)](#débordement-du-champ--type----création-dambassade-2026-08-04) · *Design, thème, langue et mise en page* · bloqué
- 1 · [Cartographie des accès `anon` réellement nécessaires (2026-08-13)](#cartographie-des-accès-anon-réellement-nécessaires-2026-08-13) · *Backend, sécurité et observabilité*
- 3 · [Passe nocturne + carte vérifiée sur appareil (2026-08-04, SM A515F)](#passe-nocturne--carte-vérifiée-sur-appareil-2026-08-04-sm-a515f) · *Journaux de passes appareil*
- 2 · [Session appareil du 2026-08-03 — SM A515F, thème sombre, font_scale 1.1](#session-appareil-du-2026-08-03--sm-a515f-thème-sombre-font_scale-11) · *Journaux de passes appareil*
- 12 · [Messages épinglés — le bandeau n'était pas temps réel (2026-08-05)](#messages-épinglés--le-bandeau-nétait-pas-temps-réel-2026-08-05) · *Messagerie* · bloqué
- 1 · [Message d'appel : aperçu et badge non-lu ne se mettaient jamais à jour (2026-08-13)](#message-dappel--aperçu-et-badge-non-lu-ne-se-mettaient-jamais-à-jour-2026-08-13) · *Appels* · bloqué
- 2 · [Écrans de notifications — lot « une seule source » (2026-08-05)](#écrans-de-notifications--lot--une-seule-source--2026-08-05) · *Notifications et push*
- 6 · [Podcasts — 5 écrans passés au système DN (2026-08-04)](#podcasts--5-écrans-passés-au-système-dn-2026-08-04) · *Fil, stories, salons audio et podcasts* · bloqué
- 2 · [Salons audio & appels de groupe — indicateur « parle en ce moment »](#salons-audio--appels-de-groupe--indicateur--parle-en-ce-moment-) · *Fil, stories, salons audio et podcasts* · bloqué
- 3 · [Lecteur de replay — valeurs inventées retirées (2026-08-03)](#lecteur-de-replay--valeurs-inventées-retirées-2026-08-03) · *Fil, stories, salons audio et podcasts* · bloqué
- 1 · [Lecture audio en arrière-plan (podcasts)](#lecture-audio-en-arrière-plan-podcasts) · *Fil, stories, salons audio et podcasts* · bloqué
- 1 · [Supabase branché sur iOS — deux réserves (2026-09-01)](#supabase-branché-sur-ios--deux-réserves-2026-09-01) · *Publication et plateformes*

Par domaine :

- [1. Appareils, comptes de test et méthode](#1-appareils-comptes-de-test-et-méthode) — 3 à faire, 0 faites
- [2. Messagerie](#2-messagerie) — 317 à faire, 0 faites
- [3. Groupes](#3-groupes) — 129 à faire, 0 faites
- [4. Chiffrement de bout en bout et clés](#4-chiffrement-de-bout-en-bout-et-clés) — 122 à faire, 2 faites
- [5. Appels](#5-appels) — 24 à faire, 1 faites
- [6. Notifications et push](#6-notifications-et-push) — 116 à faire, 0 faites
- [7. Liens profonds, navigation et QR codes](#7-liens-profonds-navigation-et-qr-codes) — 36 à faire, 0 faites
- [8. Comptes, session et onboarding](#8-comptes-session-et-onboarding) — 63 à faire, 0 faites
- [9. Fil, stories, salons audio et podcasts](#9-fil-stories-salons-audio-et-podcasts) — 101 à faire, 0 faites
- [10. Ambassades, démarches, carte, entreprises et événements](#10-ambassades-démarches-carte-entreprises-et-événements) — 62 à faire, 0 faites
- [11. Accueil, profil et réglages](#11-accueil-profil-et-réglages) — 59 à faire, 1 faites
- [12. Design, thème, langue et mise en page](#12-design-thème-langue-et-mise-en-page) — 108 à faire, 5 faites
- [13. Backend, sécurité et observabilité](#13-backend-sécurité-et-observabilité) — 67 à faire, 0 faites
- [14. Publication et plateformes](#14-publication-et-plateformes) — 46 à faire, 1 faites
- [15. Site web](#15-site-web) — 23 à faire, 0 faites
- [16. Journaux de passes appareil](#16-journaux-de-passes-appareil) — 19 à faire, 0 faites

<!-- sommaire:fin -->

---

# 1. Appareils, comptes de test et méthode

Piloter l'appareil, les comptes et téléphones disponibles, les pièges de mesure. À lire avant toute passe.

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
- Piège connu (2026-08-30) : au démarrage froid, l'app est très chargée sur
  le thread principal (Maps, Firebase, App Check — logcat montre plusieurs
  « Skipped N frames ») pendant plusieurs secondes. Un `adb shell input tap`
  envoyé pendant cette fenêtre est silencieusement perdu — aucune erreur,
  l'écran ne change simplement pas. Ça s'est fait passer pour un bug de
  navigation (bouton mort) alors que l'app n'avait juste pas fini de
  respirer. Laisser ~15-20 s après le splash avant le premier tap.
- Piège connu (2026-08-30) : `flutter run` perd la connexion au débogueur
  (« Lost connection to device. ») de façon fiable quand l'app repasse en
  arrière-plan (bouton Accueil/Retour système) pendant la session de debug
  sur cet appareil — l'app elle-même continue de tourner, seul le pont de
  debug tombe. Se traduit par la tâche qui se termine sans erreur visible.
  Retour à l'app : `adb shell monkey ...` (ci-dessus) ; pour reprendre le
  hot reload, relancer `flutter run` (pas de perte d'état app, juste du
  débogueur).

---

## ⬜ Compte de test dédié : première connexion (2026-09-09)

**Priorité P0** · importance 4/5 — Un nouvel inscrit — dont les 997 préinscrits notifiés à la publication — reste coincé dans l'enchaînement consentement/profil/intro et n'atteint jamais l'app.

`scripts/creer_compte_test.js` crée — ou réinitialise — un compte Firebase
Auth séparé du compte personnel (`test.diaspo@example.com`, mot de passe tiré
au hasard et affiché une seule fois à l'exécution).

À vérifier **sur SM A515F** :

- [ ] La connexion aboutit depuis l'écran de connexion de l'app, pas seulement
      par l'API.
- [ ] L'enchaînement consentement → configuration du profil → intro se déroule
      en entier (ces trois drapeaux sont dans les préférences **locales** : ils
      se rejouent sur chaque appareil, pas une fois par compte).
- [ ] Compte neuf = **0 groupe, 0 conversation, 0 post, 0 hashtag suivi** : les
      états vides que plusieurs entrées de ce fichier déclarent « jamais vus »
      (sondages, Découvrir, filtres Photos/Vidéos, panneau des villes)
      deviennent enfin observables.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Compte de test dédié : première connexion (2026-09-09) »).

---

## Second appareil : Pixel 10 Pro XL (2026-09-08)

Un **Pixel 10 Pro XL** (`58221FDCQ0085Z`) est apparu à côté du SM A515F. Il
porte le compte **Salim L.**, qui est **administrateur** — donc complémentaire
du SM A515F (compte « Sim A », non-admin, sans pays renseigné).

⚠️ Deux pièges rencontrés :
- `pm path` a renvoyé un chemin `/data/app/…` pour une app **pas installée** —
  un reliquat. Vérifier avec `pm list packages --user 0`, pas avec `pm path`.
- Le compte y étant réel (pas un compte de test), toute action sortante doit
  être faite hors ligne ou pas du tout.

---

# 2. Messagerie

Discussions : bulles, composeur, médias, épingles, réactions, accusés, recherche. Les groupes sont au § 3, le chiffrement au § 4.

---

## ⬜ Présence « En ligne » : elle suit enfin l'état réel (2026-09-22)

**Priorité P1** · importance 4/5 — l'en-tête d'une discussion mentait dans les deux sens : un compte en mode avion restait « En ligne » plusieurs minutes, et un compte qui utilisait l'app s'affichait « Vu il y a environ 2 minutes ».

Corrigé (branche `claude/presence-2209`, période et seuil revus par le second
correctif plus bas : 20 s et 55 s) : au premier plan, battement RTDB de
60 s qui rafraîchit `lastSeen` et réaffirme `isOnline`, marqué
`battement: 60` ; un lecteur tient pour hors ligne un `isOnline` dont le
`lastSeen` a plus de 150 s (heure du serveur, `.info/serverTimeOffset`),
réévalué toutes les 30 s. Écritures en file, et rien ne met « en ligne »
une app qui n'est pas affichée. Un nœud sans `battement` (ancien client)
garde l'ancienne règle. Règles RTDB inchangées (celles en service, relues le
2026-09-22, acceptent le champ). Garde
`test/core/services/presence_fraicheur_test.dart`. Coût : une écriture RTDB
par minute et par utilisateur au premier plan.

- **Second correctif, 2026-09-22** (branche `claude/presence-arriere-plan-2209`) :
  `inactive` n'écrit plus rien (seul `resumed` met en ligne : la course
  disparaît à la source) ; la préférence de visibilité est gardée en mémoire
  et les miroirs Supabase sortent de la file, donc **rien ne précède** le
  « hors ligne » de `hidden` ; et le battement passe à **20 s**, fraîcheur
  **55 s** : même si l'app est gelée avant d'écrire, un lecteur à jour la
  voit hors ligne en moins d'une minute (au lieu de ~95 s par
  `onDisconnect`). Coût : 3 écritures RTDB par minute et par utilisateur au
  premier plan. Pas de coupure volontaire de la connexion RTDB : elle
  porte aussi la signalisation des appels, qui doit survivre à
  l'arrière-plan.

- [ ] **Mode avion, app fermée** chez A : B voit A « En ligne » **moins
      d'une minute et demie** (55 s de fraîcheur + 30 s de réévaluation au
      pire), puis « Vu il y a … » sans rien toucher.
- [ ] **A utilise l'app** plusieurs minutes (écrit, lit, fait défiler) : B
      le voit « En ligne » sans interruption, y compris après une coupure
      réseau brève chez A.
- [ ] **A passe en arrière-plan** (bouton accueil) : B voit « Vu à l'instant »
      en quelques secondes, et plus « En ligne » ; A revient : « En ligne ».
      Refaire 3 fois (mesure d'avant : 3 sur 3 restaient ~95 s) en lisant
      `presence/<uid>` : la dernière écriture doit être `isOnline: false`.
- [ ] **Volet de notifications tiré** chez A, app ouverte : A reste
      « En ligne » (`inactive` n'écrit plus rien).
- [ ] **Un push réveille l'app de A en arrière-plan** : A ne passe PAS
      « En ligne ».
- [ ] **Ancien build** chez A (sans le correctif), nouveau chez B : A en
      ligne reste affiché « En ligne » (ancienne règle, faute de battement).
- [ ] **« Afficher mon statut en ligne » coupé** chez A : aucun battement,
      A reste hors ligne pour tous.
- [ ] `presence/<uid>` dans RTDB : `battement` = 20 et `lastSeen` avance
      d'environ 20 s tant que l'app est affichée.

---

## ⬜ Le clair des messages exclu des sauvegardes Google et iCloud (2026-09-21)

**Priorité P1** · importance 4/5 — les médias chiffrés déjà déchiffrés et le
cache Hive des messages (texte clair des messages chiffrés, seule copie
lisible d'un message MLS) partaient dans la sauvegarde Google, dans le
transfert vers un téléphone neuf et, sur iOS, dans iCloud.

Les règles Android (`regles_sauvegarde.xml`, `regles_extraction_donnees.xml`,
deux blocs) n'excluaient que `files/mls/`. Elles excluent maintenant aussi
`files/medias_dechiffres/` et **tout** `app_flutter/` (répertoire documents :
boîtes Hive, file d'envoi, téléchargements, podcasts) — en entier, pour
qu'une boîte ajoutée plus tard le soit d'office. Sur iOS, le drapeau
`isExcludedFromBackup` est posé sur les deux dossiers
(`exclusion_sauvegarde_ios.dart`, appelé par `MediaDechiffreCache` et
`main.dart`) — ⚠️ Swift jamais exécuté, pas de Mac. Tenu par
`test/core/crypto/etat_mls_hors_sauvegarde_test.dart` (rouge sans les règles).

Conséquence voulue : une restauration sur un téléphone neuf repart sans cache
local ni file d'envoi — les discussions se rechargent du serveur ; les
messages MLS d'avant la restauration, dont le clair n'existait que dans ce
cache, n'étaient de toute façon pas relisibles (la base MLS était déjà
exclue).

- [ ] **Le build passe** : `flutter build appbundle --release` va jusqu'au
  bout — `aapt2` refuse un XML de règles invalide à
  `:app:mergeReleaseResources` (7 min perdues le 2026-09-15 sur un tiret
  double).
- [ ] **Restauration** (téléphone de test, pas le Pixel) : sauvegarde Google
  puis restauration sur un appareil remis à zéro → l'app démarre, se
  reconnecte, les discussions se rechargent ; aucun plantage sur un cache
  absent.
- [ ] **iOS** (dès qu'un build existe) : Réglages › iCloud › Gérer le
  stockage › Sauvegardes › l'app — la taille ne grossit pas avec les photos
  reçues.

---

## ⬜ Médias déchiffrés effacés du disque : suppression, déconnexion, compte supprimé (2026-09-21)

**Priorité P1** · importance 4/5 — une photo, un audio ou un document
chiffré, une fois affiché, restait **en clair** sur le téléphone jusqu'à la
désinstallation : message supprimé pour tous, déconnexion, compte supprimé
n'y changeaient rien. Le dossier étant commun aux comptes, le compte suivant
sur le téléphone héritait des médias du précédent.

`MediaDechiffreCache` écrit chaque média déchiffré dans
`<support>/medias_dechiffres/<messageId>.<ext>`. Son `vider()` était
documenté « à appeler à la déconnexion » et n'était appelé nulle part.
Désormais :
- **suppression pour tous / expiration purgée par le serveur** (pas au
  simple passage du minuteur côté client) : `OubliMediasLocaux` efface le
  fichier du message, et la pièce jointe téléchargée (`FileDownloadService`,
  qui n'était purgée qu'à la déconnexion). Prévenu par la passerelle quand
  elle vide son fil (MLS, y compris le rattrapage de fond de la liste) et
  par le dépôt (messages en clair : cache, pagination, temps réel, mises à
  jour, et le geste lui-même) ;
- **déconnexion** : `vider()` dans `signOut` (`auth_provider.dart`) ;
- **compte supprimé** : 5ᵉ étape de `MaterielLocal.effacer`, qui lève si un
  fichier résiste (effacement retenté au démarrage suivant).

Vérification sur un build **debug** (`run-as` exige un paquet débogable) :
`adb shell run-as com.diasponiger.diasponiger ls files/medias_dechiffres`.

- [ ] **Suppression pour tous, destinataire** : recevoir une photo chiffrée,
  l'afficher (le fichier `<id>.jpg` apparaît dans le dossier) ; l'autre la
  supprime pour tout le monde → le fichier disparaît, discussion ouverte ou
  non.
- [ ] **Suppression pour tous, discussion fermée** : même chose, mais la
  suppression arrive app fermée → le fichier part à la réouverture de la
  discussion (ou dès le rattrapage de fond de la liste pour un fil MLS).
- [ ] **Pièce jointe téléchargée** : télécharger un document, le faire
  supprimer pour tous → le fichier téléchargé disparaît aussi.
- [ ] **Déconnexion** : afficher quelques médias, se déconnecter → dossier
  vide.
- [ ] **Pas de régression** : après reconnexion, les médias encore vivants se
  réaffichent (retéléchargés et redéchiffrés une fois), sans erreur.

---

## ⬜ Message chiffré supprimé pour tous : plus de clair en mémoire ni dans le cache (2026-09-21)

**Priorité P1** · importance 4/5 — le texte, la clé du média et la citation
d'un message MLS supprimé pour tous restaient sur le disque de chaque
téléphone, et dans la mémoire de la passerelle.

- [ ] **Côté auteur** : discussion chiffrée, envoyer une photo avec légende,
  « Supprimer pour tout le monde » → pierre tombale ; tuer l'app, relancer
  hors ligne → toujours la pierre tombale, ni photo ni légende.
- [ ] **Côté destinataire** : même parcours reçu sur l'autre téléphone,
  discussion ouverte puis rouverte après relance à froid → pierre tombale,
  jamais le texte ni la photo, même un instant.
- [ ] **Cache d'avant le correctif** : sur un téléphone qui a un message MLS
  supprimé avant cette version, ouvrir la discussion une fois en ligne, puis
  relancer hors ligne → pierre tombale (l'entrée a été réécrite vidée).
- [ ] **Pas de régression** : les autres messages du même fil gardent texte,
  photos, réponses citées et réactions.

## ⬜ Accusés, réactions, modifications et suppressions reçus en direct, discussion en clair (2026-09-21)

**Priorité P1** · importance 3/5 — dans une discussion non chiffrée restée
ouverte, un accusé de lecture, une réaction ou un épinglage survenu pendant
l'arrière-plan, et toute modification de texte même en direct,
n'apparaissaient qu'à la réouverture de la discussion.

`getMessageUpdatesStream` (`message_supabase_datasource.dart`) s'abonnait aux
UPDATE de `messages` sans rattrapage au rejoint ; il relit désormais les 50
derniers messages de la discussion quand le canal est rejoint, et l'écran
n'applique que leurs métadonnées aux messages déjà affichés. Complète
« Temps réel après l'arrière-plan, et texte supprimé dans la liste », qui
couvrait le canal chiffré. Tenu par
`test/core/services/temps_reel_apres_arriere_plan_test.dart` (branchement
seulement).

- [ ] **HOME court, accusé** : envoyer un message en clair, HOME ; l'autre
  téléphone ouvre la discussion ; revenir → la double coche « Lu » est là
  **sans rouvrir** la discussion (logcat : `realtime: rejoint « msg_updates »
  → rattrapage`).
- [ ] **HOME court, réaction** : même parcours avec une réaction posée par
  l'autre pendant l'absence.
- [ ] **Pas de régression de contenu** : après le retour, les photos, cartes
  de post et réponses citées des 50 derniers messages s'affichent toujours
  (le rattrapage émet des lignes brutes, l'écran doit garder le contenu
  déjà déchiffré).
- [ ] **Modification en direct** : discussion en clair ouverte des deux côtés ;
  l'autre modifie un message → le nouveau texte et « modifié » apparaissent
  **sans rouvrir** la discussion. Puis même chose avec HOME pendant la
  modification.
- [ ] **Modification, côté auteur** : modifier son propre message → le texte
  reste le nouveau, jamais « 🔐 Message chiffré » ni « [🔐 E2EE — session
  requise] » quand l'écho revient, ni après un accusé de lecture.
- [ ] **Deux modifications rapprochées** : l'autre modifie deux fois de suite
  en quelques secondes → c'est la seconde version qui reste affichée.
- [ ] **Suppression pour tous, en direct** : l'autre supprime pour tout le
  monde un message avec photo ou carte de post → la pierre tombale apparaît
  sans rouvrir ; appui long dessus → ni « Copier » ni « Transférer » ne
  rendent l'ancien contenu. Puis même chose avec HOME pendant la
  suppression.
- [ ] **Suppression MLS en direct** : discussion chiffrée ouverte des deux
  côtés ; l'autre supprime pour tout le monde un message texte, puis une
  photo → pierre tombale sans rouvrir, appui long sans « Copier ». Puis
  rouvrir la discussion (chemin du cache) → toujours la pierre tombale.
- [ ] **Modifier puis supprimer vite** : l'autre modifie puis supprime dans
  la foulée → la pierre tombale reste, le texte modifié ne réapparaît pas.

---

## ⬜ Manquements de la passe du 2026-09-21 : cinq correctifs à voir sur appareil

**Priorité P1** · importance 4/5 — trouvés à deux téléphones sur le +26,
corrigés dans le code, jamais vus tourner.

*Bloqué : build Play à mettre à jour (voir « Temps réel après l'arrière-plan,
et texte supprimé dans la liste »).*

- [ ] **« Lu » et réactions en direct côté expéditeur (MLS)** : A écrit, B
  lit → la coche de A passe à « Lu » en quelques secondes, discussion
  ouverte, sans rouvrir. Même chose pour une réaction de B. Le canal `mls_new`
  écoute désormais `mls_message_receipts` et `mls_message_reactions`. Limite :
  un retrait de réaction ne se voit qu'au rafraîchissement suivant.
- [ ] **Sourdine dans le menu de la discussion** : pendant la sourdine, le
  menu dit « Réactiver les notifications » et la lève (`isMuted` n'était
  jamais passé au menu ; test `menu_options_porte_son_etat_test.dart`).
- [ ] **Réglages › Notifications › Aperçu des messages** : l'interrupteur
  existe ; le couper → la bannière suivante dit « Nouveau message » sans le
  texte (colonne `show_message_preview`, lue par send-push) ; le rallumer →
  texte de retour. Tests dans `notification_type_prefs_test.dart`.
- [ ] **Recherche GIF / stickers / émojis** : « Recherche » garde le panneau
  AU-DESSUS du clavier (240 dp) — le champ reste visible, les résultats
  s'affichent pendant la frappe. Vérifier aussi le retour à la normale en
  changeant d'onglet et en refermant le panneau.
- [ ] **« Aucun émoji récent »** en français, lisible en thème sombre, à la
  place de « No Recents » (sélecteur d'émojis et de réactions).
- [ ] **Bannière et message supprimé pour tous** (DÉPLOYÉ le 2026-09-21 :
  migration `20260921230000`, send-push v34) : A envoie deux messages, B en
  arrière-plan, A supprime le second pour tous → la bannière de B ne garde
  que le premier, SANS re-sonner ; supprimer les deux → la bannière
  disparaît. Côté serveur déjà vérifié en réel : suppression de PL1 → ligne
  `messageDeleted` pour Salim, push `200 {"sent":1}`, et **aucune bannière
  parasite** sur le Pixel encore en +26 (l'ancien client ignore le signal).
- [ ] **Édition après lecture** : A corrige un message que B a déjà lu mais
  dont la bannière est encore dans le volet → la bannière prend le nouveau
  texte (le garde serveur ne demande plus une notification NON LUE, seulement
  une bannière envoyée depuis 24 h).
- [ ] **Message éphémère expiré** pendant que sa bannière est affichée → sa
  ligne quitte la bannière (même signal, sur ciphertext vidé).
- [ ] **Carte, calque « Membres » coupé mais position partagée** : le titre
  dit « Membres masqués sur la carte » et précise que la position reste
  partagée, au lieu de « Mode privé activé ». Position non partagée : le
  libellé d'avant.

---

## ⬜ « Supprimer pour tous » proposé sur le message de l'autre en 1:1 (2026-09-21)

**Priorité P2** · importance 3/5 — Sim, créateur du 1:1, se voyait proposer
« Supprimer pour tous » sur un message de Salim. Le serveur refuse
(`mls_supprimer_pour_tous` exige l'expéditeur, vérifié : le message reste
intact en base) — mais l'écran ne disait rien, la bulle restait telle quelle.

Cause : `conversation_screen.dart` tenait pour « admin » d'un 1:1 celui qui
avait créé la conversation. Un 1:1 n'a pas d'administrateur : `isAdmin` ne
vient plus que du groupe. Et un échec de « Supprimer pour tous » affiche
désormais « Ce message n'a pas pu être supprimé pour tout le monde. »
(`delete_message_modal.dart`). Tenu par
`test/features/messages/pas_d_admin_en_un_a_un_test.dart`.

*Bloqué : build Play à mettre à jour (voir « Temps réel après l'arrière-plan,
et texte supprimé dans la liste »).*

- [ ] **1:1, message de l'autre** : la boîte de suppression ne propose plus
  que « Supprimer pour moi ».
- [ ] **Son propre message de moins d'une heure** : « Supprimer pour tous »
  toujours proposé et efficace.
- [ ] **Groupe, administrateur** : « Supprimer pour tous » toujours proposé
  sur le message d'un membre (modération).

---

## ⬜ Temps réel après l'arrière-plan, et texte supprimé dans la liste (2026-09-21)

**Priorité P0** · importance 5/5 — deux défauts trouvés à deux téléphones sur
le +26 (voir « Actualisation automatique après coupure ou retour
d'arrière-plan » et « L'aperçu de la liste dit pourquoi il est vide ») : la
messagerie cessait d'arriver en direct après l'arrière-plan, jusqu'à la
relance de l'app ; et la liste de l'expéditeur gardait le texte d'un message
chiffré supprimé pour tous.

*Bloqué : les deux téléphones portent un build Play — il faut un AAB importé
dans une piste Play (Tests internes) pour les mettre à jour.*

- [ ] **Veille longue** : app en arrière-plan plus d'une heure (derrière une
  autre app), revenir sur une discussion chiffrée ouverte ; l'autre téléphone
  envoie → le message arrive **en direct**, sans relancer. La liste suit
  aussi.
- [ ] **HOME court, discussion affichée** : recevoir un message pendant
  l'absence, revenir → il est **dans le fil** et marqué lu, sans rouvrir.
- [ ] **Pas de doublon** après le rattrapage (le fil dédoublonne par id).
- [ ] **Supprimer pour tous son dernier message chiffré** → la tuile de
  l'expéditeur dit « Message supprimé » **tout de suite**, sans relance.
- [ ] **Modifier son dernier message chiffré** → la tuile prend le nouveau
  texte tout de suite.
- [ ] **Réseau** : basculer plusieurs fois mode avion ↔ réseau, puis
  vérifier que les messages arrivent toujours en direct (le réabonnement ne
  laisse pas le socket fermé).
- [ ] **Discussion chiffrée ouverte HORS LIGNE**, message reçu entre-temps,
  réseau rétabli sans toucher → le message s'insère seul. Le canal `mls_new`
  relit désormais dès son premier `subscribed` (celui du retour du réseau).
- [ ] **Fil complet après une coupure** : discussion chiffrée ouverte hors
  ligne, message reçu, réseau rétabli, revenir à la liste puis rouvrir → TOUT
  le fil du jour est là, pas seulement le dernier message. Le 2026-09-21 sur
  SM A515F il sautait de mardi à PE1 : le rattrapage de fond de la liste
  faisait naître le fil avec le seul delta, et l'amorçage depuis le cache était
  ensuite sauté (`MlsGateway.amorcer` complète désormais un fil vivant ; test
  dans `mls_metadonnees_test.dart`, échoue sur l'ancien code). Probablement
  aussi la cause d'origine de « Le fil chiffré se tronque au redémarrage dès
  qu'un message arrive en direct ».
- [ ] **Carte « Messages non lus » de l'Accueil** : ouvrir une discussion
  chiffrée depuis une bannière, lire, revenir à l'Accueil → le compte retombe.
- [ ] **Statut en ligne** (même livraison, `online_status_provider.dart`) :
  couper « Afficher mon statut en ligne » dans Réglages, modifier sa bio,
  enregistrer → `show_online_status` reste `false` en base.

---

## ⬜ La pastille de non-lus retombe en quittant une discussion chiffrée (2026-09-21)

**Priorité P1** · importance 4/5 — signalé par Salim le 2026-09-21 : la page
Messages ne se met pas à jour après avoir quitté une discussion.

- [ ] **Discussion chiffrée avec non-lus** : l'ouvrir, revenir → la pastille
      de la tuile, le compteur « N non lus » de l'en-tête et le badge de
      l'onglet Messages tombent à 0 en ≤ 1 s, sans tirer-pour-rafraîchir.
- [ ] **Longue discussion, lue en partie** (défilement partiel) : le compte
      restant est juste, pas 0.

---

## ⬜ Les premiers messages reçus restent « Message chiffré » dans la liste (2026-09-21)

**Priorité P1** · importance 4/5 — signalé par Salim le 2026-09-21 : dans la
liste des discussions, l'aperçu des premiers messages qui arrivent reste
« Message chiffré ».

- [ ] **Nouvelle discussion, premier échange** : les premiers messages ne
      restent pas sur « Message chiffré ».
- [ ] **Hors ligne** : pas de boucle de rattrapage (une reprise au plus par
      plancher).
- [ ] **La tuile remonte directement avec son texte** (`attenteDechiffrementMax`,
      3 s) : un message reçu liste à l'écran ne passe plus par « Message
      chiffré ». Vu le 2026-09-21 sur SM A515F (+26) : « Yo » restait ~2 s en
      « Message chiffré » avant ce changement. Réseau lent : la liste ne doit
      pas rester figée plus de ~3 s.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Les premiers messages reçus restent « Message chiffré » dans la liste (2026-09-21) »).

---

## ⬜ Écrire dans une conversation exige d'en être participant (2026-09-20)

**Priorité P0** · importance 4/5 — Un compte connecté pouvait écrire, sous son nom, dans n'importe quelle conversation dont il connaissait l'identifiant — d'abord celle dont il vient d'être exclu. La policy est corrigée ; reste à voir que tous les envois légitimes passent encore.

- [ ] **Premier message d'une discussion neuve** (depuis un profil, depuis la
  carte) : la conversation est créée puis le message part, sans « Message non
  envoyé ».
- [ ] **Message dans un groupe qu'on vient de rejoindre** (adhésion acceptée,
  invitation, lien) : l'envoi passe dès l'ouverture de la discussion.
- [ ] **« Mes notes »** et **partage vers une discussion** (publication,
  profil) : l'envoi passe.
- [ ] **Après avoir quitté un groupe, ou en avoir été retiré** : la discussion
  n'accepte plus rien — et l'échec se dit à l'écran, pas en silence.

## ⬜ Fiches de partage : libellés sur une ligne, vrais logos, bouton (2026-09-20)

**Priorité P3** · importance 2/5 — sur « Partager mon profil », à l'échelle de
police 1,3 du Pixel (texte en gras activé), « WhatsApp » et « Facebook » se
coupaient en plein mot (« WhatsAp / p »), le bouton « Envoyer dans une
discussion » passait sur deux lignes avec l'icône collée au bord, et les tuiles
montraient une bulle de chat et une croix « fermer » au lieu des logos WhatsApp
et X.

⚠️ Sur ce Pixel, deux réglages comptent : `font_scale` 1,3 **et** texte en gras
(`font_weight_adjustment` 300). Un test à 1,0 sans gras ne prouve rien.

- [ ] **Groupe** : fiche « Partager le groupe » — mêmes libellés sur une ligne
      à 1,3 (elle partage désormais la tuile du profil), logos inchangés, et le
      même bouton, dans la couleur secondaire du compte (le profil prend
      l'accent).
- [ ] **Autres feuilles, à 1,3** : publication (`share_post_sheet.dart`) et
      événement / podcast (`share_options_sheet.dart`, largeur fixe de 68 dp,
      libellé à ellipse) — leurs libellés sont-ils coupés ? Non mesuré, non
      touché.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Fiches de partage : libellés sur une ligne, vrais logos, bouton (2026-09-20) »).

---

## ⬜ Le séparateur « N messages non lus » part quand tout est lu (2026-09-17)

**Priorité P2** · importance 3/5 — le séparateur et le badge du bouton
« aller en bas » gardaient le compte d'ouverture jusqu'à la fermeture de
l'écran, même tout lu.

⚠️ Non mesuré : retirer une ligne **au-dessus** de l'écran d'une liste inversée
ne devrait pas décaler ce qu'on voit (le fil est ancré en bas). La case « le fil
ne saute pas » est là pour le confirmer.

- [ ] **Faire défiler** jusqu'à ce qu'il sorte par le haut, puis revenir → il a
      disparu, et **le fil ne saute pas** au moment où il part.
- [ ] **Beaucoup de non-lus** (20+) : en descendant, le chiffre du badge
      descend ; arrivé en bas, le badge disparaît.
- [ ] **Message reçu pendant la lecture** (l'autre écrit pendant qu'on
      descend) : le séparateur part quand même une fois les anciens lus.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Le séparateur « N messages non lus » part quand tout est lu (2026-09-17) »).

---

## ⬜ « Distribué » et « Lu » ne tombent plus à la même seconde (2026-09-16)

**Priorité P2** · importance 3/5 — l'écran d'information d'un message
(`message_info_sheet.dart`) affichait la même heure pour la livraison et la
lecture, sur toutes les discussions en clair.

- [ ] **Discussion en clair, deux téléphones** : A écrit, B reçoit la
      notification sans ouvrir, puis ouvre une minute après → sur l'écran
      d'information du message chez A, « Distribué » et « Lu » ont **deux
      heures différentes**, dans cet ordre.
- [ ] **Un ancien message** (avant la migration) garde « Distribué = Lu » :
      attendu, pas un défaut.
- [ ] **La coche « Distribué »** apparaît toujours chez A quand B reçoit sans
      ouvrir (non-régression de `mark_messages_as_delivered`).

---

## ⬜ Ouvrir une discussion lit ce qui est à l'écran, tout de suite (2026-09-16)

**Priorité P1** · importance 4/5 — le « Lu » à l'ouverture change de rythme :
ce qui est affiché une fois la vue posée est lu **immédiatement**, sans les
400 ms + 700 ms qui protègent un défilement. Ce qui est sous le pli reste non
lu (choix A2).

Recette : `supabase db query --linked -f supabase/diagnostics/2026-09-15_recus_bruts.sql`.

- [ ] **Ouverture, discussion chiffrée** : A envoie 12 messages à B ; B ouvre
      → `read_at` posé **en moins d'une seconde** sur les bulles affichées,
      nul sur celles sous le pli.
- [ ] **Ouverture avec saut au premier non-lu** : les derniers messages, vus
      une fraction de seconde avant le saut, ne sont PAS marqués (le cas que le
      relevé est fait pour éviter).
      **Corrigé le 2026-09-22** (branche `claude/saut-non-lu-2209`) : à défaut
      d'annonce de la liste, l'échéance vient du repère serveur
      (`RepereDeLecture.echeanceDuFil` : date du dernier non-lu, à défaut du
      premier) ; l'écran attend le fil réseau (≤ 6 s) avant de se placer.
      Garde `test/features/messages/saut_premier_non_lu_lien_profond_test.dart`.
      À revoir sur un build qui le porte : même recette (Pixel fermé, 10+
      messages, ouverture par lien profond PUIS par tap sur la bannière) →
      séparateur, placement sur le premier non-lu, `read_at` nul sous le pli.
      ⚠️ **Correctif INCOMPLET — vérifié le même soir sur le +26 (02:47)** : la
      même recette, mais la discussion ouverte **depuis la liste** (tuile
      « Sim A · 02:47 · PT10 · 10 », donc annonce présente et chemin que le
      correctif ne touche pas), donne le même symptôme : fil du cache
      (jusqu'à PS5), puis écran posé en bas sur PT3–PT10, aucun séparateur ;
      PT1 lu **seul** à 02:47:41.189, puis PT2–PT10 ensemble à 02:47:42.808.
      Il y a donc une **seconde cause, non établie**. Écarté : `repere_de_lecture`
      compte bien les messages sans ligne d'accusé (LEFT JOIN, relu en base).
      Pistes à vérifier sur un build debug (le build Play n'écrit aucun
      journal Flutter dans logcat) : le saut de `_scrollToUnreadOrBottom` est
      une ESTIMATION (`maxScrollExtent × rang / total`) qui peut tomber à 0 sur
      une liste paresseuse ; et la première écriture isolée sur PT1 laisse
      penser que la vue a été « posée » avant l'arrivée du fil réseau.
- [ ] **Côté A** : « Lu » apparaît sur les bulles affichées chez B, « Envoyé »
      ou « Distribué » sur les autres.
- [ ] **Retour au premier plan** : B garde la discussion ouverte, passe l'app
      en arrière-plan, A écrit, B revient → le message visible passe à « Lu »
      sans que B touche l'écran.
- [ ] **Une seule écriture à l'ouverture** : dans les journaux d'API Supabase,
      un seul appel d'avancée du curseur (et un seul `marquer_lus_jusqua` une
      fois la migration appliquée), pas un par bulle.
- [ ] **Discussion vide à l'ouverture**, puis un premier message reçu : il est
      bien lu (filet de 6 s si le placement n'a pas eu lieu).
- [ ] **En clair, après la migration** : mêmes cases que ci-dessus.

---

## ⬜ Lecture par curseur dans les discussions en clair (2026-09-16)

**Priorité P1** · importance 4/5 — le « Lu » et le séparateur « N messages non
lus » des discussions **non chiffrées** changent de mécanisme.

- [ ] **En clair, sous le pli** : A envoie 6 messages à B dans une discussion non
      chiffrée ; B ouvre, n'en voit que 3 → chez A, « Lu » sur ces 3 seulement.
      Relever `data->'readAt'` en base : nul sur les 3 autres.
- [ ] **Le séparateur en clair** : même scénario, B rouvre → « 3 messages non
      lus » juste au-dessus du 4ᵉ, et la vue s'y place.
- [ ] **La pastille de la liste descend au fil de la lecture**, sans retomber à
      zéro d'un coup : 6, puis 3 après la première ouverture.
- [ ] **Conversation basculée avec des messages en clair non lus d'avant la
      bascule** : le séparateur les compte, et lire le dernier message chiffré
      les marque aussi. Aucun cas chez de vrais comptes aujourd'hui (les 7
      relevés sont des comptes `banc_b_…`) : à construire.
- [ ] **Compte au drapeau MLS ouvert, discussion encore en clair** : les
      messages y sont bien marqués lus (avant, le curseur partait côté MLS et
      n'y trouvait rien).
- [ ] **Accusé de livraison toujours posé** en recevant app en arrière-plan
      (`mark_messages_as_delivered` a désormais une garde d'identité : si le
      `currentUserId` des préférences diffère de la session, l'accusé est
      refusé — c'est voulu, mais à confirmer qu'il ne l'est pas à tort).

---

## ⬜ Droits d'écriture sur `messages` resserrés : accusés et modification (2026-09-16)

**Priorité P0** · importance 5/5 — jusqu'au 2026-09-16, **tout participant
d'une conversation pouvait réécrire le texte du message de n'importe qui
d'autre**, par PostgREST. Vérifié en production, puis corrigé et redéployé le
jour même (migration `20260916210000`). Le correctif touche le chemin
d'écriture de TOUTE la messagerie : ce qui doit être vérifié ici, ce n'est pas
l'attaque — le banc SQL la couvre — mais que **rien de légitime n'a été
emporté**.

**La régression à craindre est muette** : si les accusés cassent, le « Lu »
cesse simplement d'arriver — aucune erreur, aucun journal, rien à l'écran. Un
seul téléphone ne peut pas le voir. D'où deux appareils, obligatoirement.

- [ ] **Accusé de lecture, deux téléphones** : A écrit à B, B ouvre la
      discussion → la coche passe à « Lu » chez A, en quelques secondes
- [ ] **Accusé de livraison** : B reçoit sans ouvrir (app en arrière-plan) →
      la coche « remis » apparaît chez A
  ⛔ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : `delivered_at` reste NUL tant que la discussion n'est pas ouverte (bannière pourtant reçue et déchiffrée). Par construction : seul `conversation_screen.dart:852` appelle `markAsDelivered` — « remis » n'existe pas pour un message reçu en arrière-plan.
- [ ] **Favori / signalement / supprimer pour moi** sur le message d'un
      **autre** : les trois passent toujours (ce sont les seules écritures
      qu'un non-expéditeur garde)
  ✅ favori et supprimer pour moi, Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (MLS) : Sim met en favori PK1 de Salim (`mls_message_stars`, étoile sous la bulle) et supprime pour lui PK2 (`mls_message_hidden`, bulle retirée chez Sim, toujours visible chez Salim). Signalement pas testé (écrit chez les modérateurs). ⚠️ Et « Supprimer pour tous » était PROPOSÉ sur le message de l'autre : voir « « Supprimer pour tous » proposé sur le message de l'autre en 1:1 ».
- [ ] **Modération** : dans un groupe, un admin fait « supprimer pour tout le
      monde » sur le message d'un membre → la bulle passe à « message
      supprimé » chez les deux
- [ ] **Conversation chiffrée (MLS)** : les accusés et la modification s'y
      comportent pareil — `mls_messages` est une autre table, avec ses propres
      droits, et n'a pas été touchée par cette migration

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Droits d'écriture sur `messages` resserrés : accusés et modification (2026-09-16) »).

---

## ⬜ « Message chiffré » qui ne s'en va pas dans la liste (2026-09-16)

**Priorité P1** · importance 4/5 — signalé sur Pixel 10 Pro XL le 2026-09-16,
dans deux cas : une discussion **jamais ouverte** sur l'appareil, et un
message reçu **pendant que la liste est à l'écran**.

- [ ] **Recevoir, app ouverte sur la liste, sans y toucher** : la tuile passe
      du libellé au vrai texte toute seule, en quelques secondes.
- [ ] **Rafale de 3-4 messages reçus** dans la même discussion : chacun
      remplace le précédent, aucun ne reste sur « Message chiffré ».
- [ ] **Discussion jamais ouverte sur ce téléphone** : la tuile finit par
      afficher le texte sans qu'on l'ouvre. ⚠️ Le rattrapage est **borné aux
      3 conversations les plus récentes** qui en ont besoin : au-delà, il faut
      encore un nouvel événement serveur.
- [ ] **Quatre discussions chiffrées en attente** : vérifier justement ce
      qu'il advient de la 4ᵉ.
- [ ] **Hors ligne** : la liste ne doit ni tourner en boucle de rattrapage ni
      afficher un aperçu faux.

---

## ✅ Curseur de lecture et séparateur « nouveaux messages » (2026-09-16)

**Priorité P1** · importance 4/5 — vérifié **à deux téléphones**, même build
(Pixel 10 Pro XL = Salim, SM A515F = Sim A).

**Ce qui reste à voir**, et qui n'a pas été exercé :

- [ ] **Un défilement rapide ne doit rien « lire »** : traverser vingt bulles
  d'un geste, puis relever les `read_at`. Le seuil (60 %) et le délai (400 ms)
  sont là pour ça, mais aucune passe ne l'a mis à l'épreuve.
- [ ] **En groupe** : le curseur est par utilisateur **et** par message
  (`mls_message_receipts`), donc il devrait tenir à plusieurs membres. Jamais
  vérifié au-delà d'un tête-à-tête.
- [ ] **La pagination** : rouvrir une discussion dont le curseur désigne un
  message **hors de la page chargée**. Le repère doit apparaître en remontant,
  pas se poser au hasard.
- [ ] **Deux appareils du même compte** : le curseur vient du serveur, il
  devrait donc se synchroniser. Non testé.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Curseur de lecture et séparateur « nouveaux messages » (2026-09-16) »).

---

## ⬜ GIF et sticker envoyés en MLS : la bulle ne montrait rien (2026-09-16)

**Priorité P0** · importance 4/5 — signalé à l'usage le 2026-09-16, juste après le déploiement de `gif-proxy` : « les gifs/stickers ne s'affichent pas dans les messages ». Deux messages `sticker` partis en MLS à 05:05 UTC, tous deux muets à l'écran.

- [ ] **Les deux GIFs du 2026-09-16** (05:05 UTC) s'affichent après mise à
      jour, au lieu du cadre cassé
- [ ] **Sticker animé** : l'animation joue, elle ne se fige pas sur la
      première trame (`isAnimated` relu)
- [ ] **Conversation non basculée** : toujours bon — ce chemin-là passait par
      `data->>'fileUrl'` et n'a jamais été touché

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ GIF et sticker envoyés en MLS : la bulle ne montrait rien (2026-09-16) »).

---

## ⬜ Forme de la bulle qui cite un message (2026-09-16)

**Priorité P2** · importance 3/5 — signalé sur capture : une réponse courte à
un message court donnait un bloc **plus haut que large**, où la citation se
lisait comme une étiquette posée à côté du message plutôt que comme le message
cité. Trois changements dans `message_bubble.dart` :

- un plancher de largeur (52 % de l'écran, plafonné à 240) dès qu'il y a une
  citation ;
- la citation étirée sur toute la largeur de la bulle — par `IntrinsicWidth`,
  **réservé au texte** : `AudioMessageBubble` et `AudioFileBubble` contiennent
  un `LayoutBuilder`, qui lève au lieu de rendre une dimension intrinsèque ;
- un aplat translucide sous la citation de la bulle envoyée (le filet seul ne
  la détachait pas), un filet de 3 px, et 12 px d'air en moins entre la
  citation et le texte.

- [ ] **Réponse à une photo, puis à une note vocale** : ces bulles passent par
  le chemin SANS `IntrinsicWidth` — la citation ne s'y étire pas, et rien ne
  doit lever.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Forme de la bulle qui cite un message (2026-09-16) »).

---

## ⬜ « Modifier le message » : saisie en ligne, fenêtre de 48 h, motifs dits (2026-09-16)

**Priorité P2** · importance 3/5 — le geste a été refait en entier, sur
demande. Rien n'est vérifié sur un vrai téléphone : tout ce qui suit vient de
`flutter test` et d'un aperçu de rendu.

**Ce qui a changé.** La boîte de dialogue disparaît : la saisie se fait dans la
barre du bas, sous un bandeau « Modifier le message » qui reprend le gabarit de
celui de la réponse. La fenêtre passe de 25 min à 48 h
(`MessageEntity.fenetreModification` — **rien ne l'impose côté serveur**, la
policy `messages_update` ne connaît pas le temps). Hors fenêtre, l'entrée de
menu reste **visible mais désactivée**, avec le motif en sous-titre, au lieu de
disparaître. Et chaque échec porte enfin sa cause : avant, coupure réseau,
refus serveur et échec de la passerelle MLS s'annonçaient tous « Le délai de
modification est expiré (25 min) ».

- [ ] **Le clavier.** Le bandeau ajoute une ligne au-dessus du composeur :
  vérifier qu'aucun débordement n'apparaît, clavier ouvert, en portrait puis
  en **paysage** — c'est là que le composeur est déjà le plus serré (voir
  « Paysage — overflow quand le chrome dépasse la hauteur »).
  ⬜ moitié, Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : portrait, clavier ouvert → bandeau « Modifier le
  message / PA22ECHEC » + croix au-dessus du champ, aucun débordement (capture).
  Paysage non essayé (rotation = réglage système).
- [ ] **Le bouton.** En modification il doit porter une coche, jamais le micro,
  et un appui long ne doit **pas** lancer un enregistrement vocal. Grisé tant
  que le champ est vide.
  ⬜ en partie, Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : coche bleue à la place du micro (le « + » du
  composeur disparaît aussi) ; champ vidé → coche **grisée**, non cliquable.
  Appui long sur la coche non essayé (risque d'enregistrer).
- [ ] **Les motifs, en vrai.** Couper le réseau et tenter une modification :
  le message affiché doit parler de connexion, pas de délai. Puis dans une
  conversation **basculée en MLS**, vérifier qu'une modification aboutit
  réellement — la passerelle passe par un message de contrôle chiffré, et
  l'échec y était particulièrement trompeur.
    **Corrigé le 2026-09-22** : `estConnecte` (`network_info.dart`) ne compte
    plus le VPN seul — en service, il porte son transport (`dumpsys` du
    A515F en ligne : `Transports: WIFI|VPN`) ; et `editMessage` rend une
    `NetworkFailure` sur toute panne réseau (`estPanneReseau`). À revoir
    sur un build qui le porte : mode avion → message de connexion ; et
    surtout, **en ligne avec le VPN**, tout doit continuer de partir.
- [ ] **« Infos » dit quand.** Le panneau d'informations d'un message modifié
  doit afficher « Modifié · <date> », et « Modifié N fois · <date> » au-delà
  d'une modification. Le texte d'avant n'est **pas** conservé : il n'y a pas
  d'historique de versions à attendre là.
  **Date corrigée le 2026-09-22** : `DateFormat.yMMMd(l10n.localeName)`.
  À revoir : « 22 sept. 2026 01:30 ».

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ « Modifier le message » : saisie en ligne, fenêtre de 48 h, motifs dits (2026-09-16) »).

---

## ⬜ Pastille de non-lus, et séparateur « nouveaux messages » (2026-09-15)

**Priorité P1** · importance 4/5 — signalé à l'usage : ouvrir une discussion
qui a de nouveaux messages n'affiche aucune pastille, et le message neuf met
un instant à apparaître. Trois causes distinctes, deux corrigées et vérifiées,
une qui résiste.

- [ ] **Le verrou de rattrapage, sous charge** : `messages()` partage
  désormais un seul futur par conversation, parce que le rattrapage de
  fond et l'ouverture du fil peuvent tomber ensemble — deux `catchUp`
  concurrents feraient avancer le cliquet deux fois. Tenu par trois tests,
  **jamais éprouvé sur appareil** : à voir en ouvrant une discussion à
  l'instant précis où son rattrapage part.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Pastille de non-lus, et séparateur « nouveaux messages » (2026-09-15) »).

---

## ⬜ « Mes notes » s'ouvre sans aller-retour réseau — vérifié SM A515F (2026-09-15)

**Priorité P1** · importance 4/5 — la tuile « Mes notes » était la seule de la
liste à faire une requête **avant** de pousser son écran : un spinner à la
place de l'icône signet, la tuile intouchable, à **chaque** ouverture. Toutes
les autres discussions s'ouvrent d'un `context.push` synchrone.

- [ ] Démarrage à froid en ligne, tap immédiat avant que la liste n'ait
      chargé : la tuile fait encore son aller-retour (spinner), et
      l'ouverture aboutit
- [ ] Après un tirer-pour-rafraîchir, la première ouverture peut refaire
      l'aller-retour, les suivantes non
- [ ] Compte neuf, « Mes notes » jamais créée : le premier tap la crée et la
      tuile prend son aperçu dans la liste

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ « Mes notes » s'ouvre sans aller-retour réseau — vérifié SM A515F (2026-09-15) »).

---

## ⬜ La liste n'annonce plus « Utilisateur » ni « Message chiffré » (2026-09-15)

**Priorité P1** · importance 4/5 — trouvé en filmant un démarrage à froid sur
Pixel 10 Pro XL : rafale de captures (~0,8 s entre chaque image), app ouverte
directement sur `/messages` par lien profond.

**1. « Message chiffré » n'était pas une attente, c'était un appel manquant.**
`getCachedConversations()` — la première émission, celle qui s'affiche — ne
reconstruisait pas l'aperçu depuis le cache local déchiffré, alors que le
chemin réseau le fait (`_completerAvecMls` → `_apercuDepuisLeCache`).
L'appareil avait le texte sous la main.

**2. « Utilisateur »** est le repli du nom quand le flux de profil n'a rien
émis. Au démarrage il n'a rien émis pour personne. L'avatar et le nom cèdent
désormais la place à un bloc d'attente (`SkeletonBlock`, sans balayage).

- [ ] **Le bloc d'attente n'a pas été vu du tout**, ni dans un tour ni dans
  l'autre : le profil était déjà résolu à la première image. La garde n'a
  donc pas été exercée sur appareil — seul le test la tient
  (`liste_sans_placeholders_test.dart`). À rejouer sur un appareil dont le
  profil distant est lent ou froid : s'il apparaît puis disparaît en une
  image, il vaut mieux que « Utilisateur » ; s'il reste plus d'une seconde
  sur un profil déjà connu, c'est le flux de profil qui devient le sujet.
- [ ] **Compte supprimé ou inconnu** : « Utilisateur » doit **revenir**,
  puisque la lecture est terminée. Une ligne grise à vie serait le défaut
  inverse. Le test le tient hors appareil, mais le cas réel vaut d'être vu.
- [ ] **Discussion chiffrée jamais ouverte sur cet appareil** : le cache local
  n'a pas les messages, donc « Message chiffré » reste — et c'est juste. Vérifier
  que ça n'a pas été remplacé par un bloc gris permanent.
- [ ] **Thème sombre** : le bloc d'attente doit se distinguer du fond `#0F0D0A`
  sans faire un trou blanc dans la ligne.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ La liste n'annonce plus « Utilisateur » ni « Message chiffré » (2026-09-15) »).

---

## ⬜ Le repère de bascule ne parle plus français à tout le monde (2026-09-15)

**Priorité P2** · importance 3/5 — le séparateur posé dans le fil au moment
où la conversation passe au chiffrement de bout en bout portait son libellé
**écrit en dur, en français**, dans `MlsMessageMapper.separateur` : aucune clé
`.arb` ne le couvrait, donc un compte en anglais lisait « Messages d'avant le
chiffrement de bout en bout » au milieu d'une interface anglaise.

Deux changements : le texte devient générique — « Les messages sont chiffrés
de bout en bout » / « Messages are end-to-end encrypted » — et il est
**résolu à l'affichage**, pas à la fusion des deux sources. Le séparateur ne
transporte donc plus de `content` : son identifiant réservé est descendu dans
`MessageEntity` (`idSeparateurMls`, `estSeparateurMls`) pour que la bulle
système le reconnaisse sans importer la pile MLS.

Nuance connue, à juger à l'œil sur un vrai fil : les messages **au-dessus**
du repère ne sont pas chiffrés, et une phrase générique posée au milieu du fil
ne le dit plus. Elle reste vraie pour ce qui suit.

- [ ] **Le fil d'une conversation basculée** (« Mes notes » sur le compte de
  test suffit) : le repère affiche bien la nouvelle phrase, centrée dans sa
  pastille, et **sur une seule ligne** si la largeur le permet.
- [ ] **Compte en anglais** : passer l'app en anglais et rouvrir le même fil.
  Le repère est en anglais. C'était impossible avant ce correctif.
- [ ] **Thème sombre** : la pastille (`Colors.white` à 8 % d'alpha) et le texte
  secondaire restent lisibles par-dessus un fond de discussion personnalisé.
- [ ] **Échelle de police à fond** : la phrase se replie sur deux ou trois
  lignes sans déborder la pastille ni pousser les bulles voisines.
- [ ] **Le repère ne compte toujours pas comme un message** : pas de bandeau
  « non lu » dessus, pas de réponse possible, absent de la recherche — voir
  « Le bandeau « 1 message non lu » d'une conversation basculée ». Le `content`
  vide ne doit avoir rien cassé de ce côté.

---

## ⬜ Squelette de chargement de la messagerie (2026-09-15)

**Priorité P3** · importance 2/5 — les deux attentes de la messagerie ne
disaient pas la même chose que ce qui allait s'afficher. La liste des
discussions montrait un tourniquet centré au milieu du vide, et le fil d'une
discussion, pendant sa première page (`paginationState.isLoadingInitial`),
rendait un `SizedBox.shrink()` — donc **rien du tout** entre l'en-tête et le
composeur : impossible de distinguer « ça charge » de « cette discussion
n'a aucun message ».

Les deux branches rendent maintenant un squelette qui reprend la géométrie
réelle : avatar 50 au rayon 17, filets entre les lignes, marges de bulle
16/64, rayons 18/6, et la colonne d'avatar de 28 réservée à gauche dans un
fil de groupe. C'est tout l'intérêt de la chose : si les blocs ne tombent pas
où le contenu tombera, l'écran saute quand même à l'arrivée des données.

- [ ] **Liste des discussions** : ⚠️ un `force-stop` puis un tap sur l'onglet
  Messages **ne suffit pas** à le voir. Essayé le 2026-09-15 sur Pixel
  10 Pro XL : sur 10 images prises pendant la transition, aucune ne porte le
  squelette — le cache Hive rend la liste avant lui. C'est le bon
  comportement, pas un défaut, mais ça déplace la vérification : il faut un
  cache froid (appareil où l'app vient d'être installée) ou un réseau lent.
  Ce qu'on regarde alors : le squelette sous les puces de filtre, puis la
  vraie liste **sans saut vertical** par rapport aux lignes annoncées.
- [ ] **Fil d'une discussion** : ouvrir une discussion à tête-tête depuis la
  liste. Les bulles vides sont **collées en bas**, contre le composeur, comme
  la vraie liste inversée — pas en haut de l'écran.
- [ ] **Ouverture par lien profond ou par notification** : `state.extra` est
  nul par ce chemin, donc `widget.isGroup` est faux à l'instant du squelette
  et un fil de groupe peut s'afficher sans sa colonne d'avatar. Vérifier si
  le saut de 28 px se voit réellement, ou si la première page arrive trop
  vite pour qu'on le perçoive.
- [ ] **Thème sombre** sur les deux écrans : les blocs doivent rester lisibles
  sur `#0F0D0A` sans virer au gris froid, et le balayage rester discret.
- [ ] **Fond de discussion personnalisé** : avec un papier peint choisi
  (« Fond de discussion »), vérifier que les bulles du squelette ne
  deviennent pas illisibles par-dessus.
- [ ] **Échelle de police à fond** (réglages Android) : le squelette est à
  hauteurs fixes, donc il ne grandit pas ; regarder si l'écart avec le
  contenu réel, lui bien plus haut, produit un saut visible.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Squelette de chargement de la messagerie (2026-09-15) »).

---

## ⬜ L'aperçu de la liste dit pourquoi il est vide (2026-09-15)

**Priorité P0** · importance 5/5 — `conversations.data->>'lastMessage'` porte
le texte du dernier message **en clair** : c'est lui qu'on lit dans la liste
des discussions. « Supprimer pour tout le monde » vidait la ligne `messages`
— contenu, `fileUrl`, cartes de partage, clé du média chiffré — et **ne le
touchait pas**. Supprimer son dernier message donnait donc une bulle
« Message supprimé » avec, une ligne plus haut, son texte parfaitement
lisible. La suppression se disait accomplie pendant que son contenu restait à
l'écran.

- [ ] **La fuite d'origine** : envoyer un texte reconnaissable, le supprimer
  pour tout le monde, revenir à la liste des discussions. La tuile ne montre
  plus le texte, elle dit « Message supprimé ». Vérifier **des deux côtés** :
  l'expéditeur et le destinataire.
- [ ] **En base**, après ce geste : `data->>'lastMessage'` est vide et
  `data->>'lastMessageDeleted'` vaut `true` sur la conversation.
  ⚠️ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (MLS) : `lastMessage` nul (normal, le serveur n'a pas le clair) mais `lastMessageDeleted` NUL aussi — la marque n'est pas posée pour une conversation MLS.
- [ ] **Une photo supprimée** ne s'annonce plus « 📎 Photo » : ni la
  suppression ni l'expiration ne touchent `lastMessageType`, et le libellé de
  type passait avant. Même contrôle pour une **note vocale** (elle gardait son
  icône micro et « 🎤 Message vocal ») et pour un **appel** (combiné vert).
- [ ] **Expiré ≠ supprimé** : faire expirer le dernier message (recette SQL de
  « Messages éphémères — minuteur réparé, purge serveur »). La tuile dit
  « Message expiré », pas « Message supprimé ».
- [ ] **MLS, discussion jamais ouverte sur cet appareil** (ou cache vidé) : la
  tuile dit « Message chiffré », **pas** « Message expiré » — ce qu'elle
  disait depuis que la purge a appris à vider l'aperçu, en annonçant la
  disparition de messages vivants.
- [ ] **Conversation neuve** : une discussion sans aucun message dit toujours
  « Nouvelle conversation ».
- [ ] **Hors ligne / après redémarrage** : le libellé survit au cache Hive —
  rouvrir l'application en mode avion doit encore afficher « Message
  supprimé », pas le texte.
- [ ] **Thème sombre** : les trois libellés restent lisibles dans la liste.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ L'aperçu de la liste dit pourquoi il est vide (2026-09-15) »).

---

## ⬜ Modifier un message chiffré part parfois dans la mauvaise table (2026-09-15)

**Priorité P1** · importance 4/5 — Signalé par Salim : « modifier message se
passe uniquement en visuel, après actualisation le message précédent revient ».

**Mesuré** : deux modifications annoncées réussies n'ont émis **aucun**
`kind='control'` dans `mls_messages`. Elles sont donc parties vers `messages`,
où un message MLS n'a aucune ligne, et `editMessage` y faisait
`if (rows.isEmpty) return;` — succès sans écriture ni signal. Une modification
qui passe bien par la passerelle, elle, **tient** (contrôle émis, texte
conservé après sortie/retour).

**Corrigé** : le `return` muet lève désormais, et l'erreur emporte l'état de
bascule de la conversation (`mls_since`) — l'entrée dont dépend la décision.

**⚠️ Le cas ne se provoque pas depuis l'interface** : pour qu'une bulle MLS
s'affiche, son fil a forcément été amorcé, donc `_connus` contient déjà son
identifiant et l'aiguillage est bon. Il faudrait modifier avant le premier
rendu. La prochaine occurrence en usage réel sera donc la source : elle
affichera une erreur rouge portant l'identifiant du message ET l'état de
bascule.

**⚠️ Piège de recette rencontré** : une tentative de reproduction a tapé dans
la mauvaise conversation ; le texte est parti dans la zone de saisie et a créé
un message au lieu d'en modifier un. Les chiffres lus alors comme « deux
valeurs fausses » étaient deux valeurs justes pour la conversation où la sonde
tournait réellement. **Vérifier l'en-tête de la conversation avant d'agir.**

- [ ] Reproduire en usage réel et relever l'erreur complète (identifiant +
  `mls_since`), puis remonter de là vers la cause.

## ⬜ Messages éphémères — minuteur réparé, purge serveur (2026-09-15)

**Priorité P1** · importance 4/5 — La fonction était **morte en silence** sur
le chemin de production : l'écran de réglage écrivait bien
`conversations.data->>'autoDeleteAfterSeconds'`, mais `MessageSupabaseDataSource`
— le seul datasource branché — ne le lisait jamais à l'envoi et ne posait
jamais `expiresAt` ; aucun balayage serveur n'existait ; et `mls_messages.
expires_at` attendait sans écrivain. Activer le minuteur n'avait aucun effet
observable, et rien ne le disait. Réparé des deux côtés, avec une purge
`pg_cron` qui pose une **pierre tombale** (contenu vidé, `is_deleted`) au lieu
de supprimer la ligne. Mesuré avant livraison : 0 conversation sur 19 avait un
minuteur, 0 message sur 118 une échéance — rien d'existant ne pouvait donc
disparaître rétroactivement.

Protocole : deux téléphones. Les durées proposées sont 24 h / 7 j / 30 j —
trop longues pour une session. Pour éprouver l'expiration elle-même,
antidater l'échéance à la main puis déclencher le balayage :

```sql
UPDATE messages SET data = jsonb_set(data, '{expiresAt}',
  to_jsonb(to_char(now() - interval '1 min' AT TIME ZONE 'UTC',
                   'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
 WHERE id = '<id du message>';
SELECT public.purger_messages_expires();
```

- [ ] **Tous les types** : photo, note vocale, position, sondage, sticker
  portent aussi `expiresAt`. Un message **système** (« X a rejoint ») n'en
  porte pas — il décrit la conversation, pas son contenu.

  ⚠️ **Piège de recette** : antidater `expires_at` en SQL ne suffit pas à voir
  le libellé « supprimé automatiquement ». Le client garde SA date (venue du
  `ttl` du payload) : `isExpired` reste faux chez lui et la bulle dit
  « Message supprimé ». Pour voir le bon libellé, poser un minuteur COURT et
  laisser l'échéance passer des deux côtés.
- [ ] **Expiration côté destinataire**, discussion ouverte : la bulle bascule
  sans rechargement (le temps réel propage la pierre tombale comme il propage
  déjà une suppression).
- [ ] **Avant le passage du balayage** : une échéance dépassée vide déjà la
  bulle sur l'appareil, sans attendre le quart d'heure du `pg_cron`.
- [ ] **Hors ligne** : une échéance dépassée pendant que le téléphone est en
  mode avion vide la bulle quand même à la réouverture de la discussion.
- [ ] **Ce que la pierre tombale emporte** : pour un message média expiré,
  `data ? 'encMedia'` et `data ? 'fileUrl'` sont faux en base — la clé du
  média part avec lui, le blob Storage restant devient illisible. Vérifier de
  même qu'un message qui portait une carte de partage n'a plus `encAnnexes`
  ni `postData`.
- [ ] **Notification déjà reçue** : une push arrivée avant l'expiration reste
  dans le centre de notifications avec son aperçu. Voir « Aperçu des
  notifications MLS » si l'entrée existe.
- [ ] **Thème sombre** : la bulle « Message expiré » est lisible des deux
  côtés (bulle à moi, bulle de l'autre).
- [ ] **Avant le passage du balayage, le contenu ne repart par aucun chemin.**
  Laisser un message expirer, puis, dans le quart d'heure qui précède le
  `pg_cron` : l'appui long ne propose plus ni réaction, ni « répondre », ni
  « modifier » ; **« Copier » ne met rien dans le presse-papiers** ; l'export
  de la conversation (JSON et HTML) écrit « Message supprimé » à sa place et
  **pas** son texte ; la recherche dans la discussion ne le trouve plus par
  son contenu. C'est le chemin qui compte le plus : le serveur n'a encore
  rien effacé, tout tient au garde client.
- [ ] **Hors ligne prolongé** : mode avion, laisser passer l'échéance, rouvrir
  la discussion sans jamais retrouver le réseau — la bulle est vide et
  « Copier » ne rend rien, alors que le balayage serveur n'a évidemment pas
  pu passer.

- ✔ 9 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Messages éphémères — minuteur réparé, purge serveur (2026-09-15) »).

---

## ⬜ Aperçu et compteurs d'une conversation chiffrée (décision J, 2026-09-15)

**Priorité P1** · importance 4/5 — Une conversation basculée à MLS n'écrit
plus rien dans `messages` : sa ligne dans la liste des discussions et ses
pastilles de non-lus viennent désormais de métadonnées posées à part
(migration `20260915200000_mls_metadonnees_en_ligne`). Le déclencheur
serveur **retire** l'aperçu en clair du legacy et pose à la place le type et
l'expéditeur ; le texte de l'aperçu doit être reconstruit par l'appareil
depuis son cache déchiffré. Rien de tout ça n'a jamais tourné sur un
téléphone.

- [ ] **Aperçu après bascule** : une discussion qui contenait des messages en
  clair passe à MLS ; sa ligne cesse d'afficher l'ancien texte en clair et
  n'affiche jamais le texte d'un message chiffré venu d'ailleurs.
- [ ] **Photo envoyée** : la ligne dit « 📎 Document » au pire, jamais une
  ligne vide — le serveur ne distingue pas photo, vidéo et document.
- [ ] **Note vocale** : la ligne montre l'icône micro, pas « Document ».
- [ ] **Réaction, édition, suppression** : aucune ne fait remonter la
  discussion en tête de liste (ce sont des contrôles, pas des messages).
- [ ] **Pastille de non-lus** et **badge @** d'une mention, dans un groupe
  basculé, sur le second appareil du même compte.
- [ ] **Réaction sur un message d'AVANT la bascule**, dans la même discussion :
  elle marche aussi — c'est l'aiguillage par message qui est vérifié là.
- [ ] **Une modification ne remonte pas** la discussion en tête de liste et
  ne déclenche **aucune notification**.
- [ ] **Rouvrir une discussion chiffrée** dans la même session : les messages
  sont toujours là. `catchUp` ne rend que le delta — le fil est gardé par la
  passerelle, et c'est ce qu'il faut voir tenir.
- [ ] **Aperçu sur un appareil qui n'a jamais ouvert la discussion** : il
  montre le libellé de type, jamais le texte d'un message plus ancien.

- ✔ 9 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Aperçu et compteurs d'une conversation chiffrée (décision J, 2026-09-15) »).

---

## ⬜ Un fil chiffré survit au redémarrage de l'application (2026-09-15)

**Priorité P0** · importance 5/5 — Corrigé le 2026-09-15, **jamais vérifié
sur un téléphone**, et c'est ce qui décide de l'ouverture du drapeau.

Deux correctifs, qui vont ensemble : le curseur est **mémorisé**
(`SharedPreferences`, une clé par compte), donc le moteur n'est plus
sollicité pour d'anciens messages ; et le fil est **repris du cache local**
(`MlsGateway.amorcer`) avant chaque lecture, puisque le serveur n'a plus rien
de lisible à offrir. Les placeholders déjà en cache sont écartés à la reprise
— sinon la perte se figerait.

- [ ] **Vider le cache de l'application** puis rouvrir : les anciens messages
  deviennent des placeholders — attendu, c'est la limite du chiffrement — mais
  les nouveaux passent toujours.
- [ ] **Même épreuve après réinstallation** : placeholders attendus aussi.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Un fil chiffré survit au redémarrage de l'application (2026-09-15) »).

---

## ⬜ Pièces jointes chiffrées — images, documents, audio (C4, 2026-09-14)

**Priorité P1** · importance 4/5 — Première tranche du chiffrement des
médias de messagerie (plan MLS, décision C4) : quand le drapeau
administrateur `featureFlags.mediasChiffres` est ouvert, une photo, un
document, un fichier audio ou une note vocale part chiffré (AES-256-GCM,
clé propre au fichier) vers `encrypted_media/…` de Firebase Storage, et sa
clé voyage dans `messages.data.encMedia`, scellée avec la clé dérivée de la
conversation. Le serveur ne voit qu'un blob et un nom générique (« photo »,
« document », « note-vocale »). **La vidéo n'est pas concernée** (elle attend
un déchiffrement par morceaux). Rien de tout ça n'a tourné sur un appareil :
le drapeau est fermé par défaut, et **doit le rester tant que la mise à jour
minimale n'est pas imposée** — un ancien build affiche une image cassée.

Protocole : deux téléphones sur le même build, drapeau ouvert dans le
document `admin_settings` de Firestore (`featureFlags.mediasChiffres: true`),
puis remis à `false` à la fin.

- [ ] **Photo** : envoyée depuis A, elle s'affiche chez B (gabarit flou puis
  image), et chez A dans sa propre bulle **sans rechargement**. En base,
  `data->>'fileName'` vaut `photo`, `data ? 'encMedia'` est vrai, et
  `data->>'fileUrl'` téléchargé à la main donne un fichier illisible.
- [ ] **Réouverture** de la discussion : la photo revient depuis le cache
  local, sans nouveau téléchargement (couper le réseau avant de rouvrir).
- [ ] **Accusé de lecture** : après que B a lu, la bulle de A montre toujours
  la photo (le flux de mises à jour ne doit pas l'effacer).
- [ ] **Plein écran, enregistrer, partager** depuis la bulle de B : l'image
  s'ouvre, s'enregistre dans la galerie (album « Diaspo Niger »), se partage
  en fichier — pas en lien.
- [ ] **Galerie de la conversation** (grille et bandeau compact) : la photo
  chiffrée y figure et s'ouvre en plein écran.
- [ ] **Document PDF** : le tap ouvre la feuille de partage du système (pas
  de navigateur) ; « ouvrir avec » un lecteur PDF affiche le document.
- [ ] **Note vocale** et **fichier audio** : lecture, pause, vitesse, forme
  d'onde — identiques à un envoi en clair.
- [ ] **Mode données réduites** : la barrière de déchiffrement se lève après
  la barrière « télécharger », pas avant (aucun téléchargement sans tap).
- [ ] **Clé de conversation indisponible** (couper le réseau juste avant
  d'envoyer une photo avec le cache de clés vidé) : l'envoi **échoue
  visiblement** — « Clé de conversation indisponible : média non envoyé » —
  au lieu de partir en clair.
- [ ] **Supprimer pour tous** une photo chiffrée : la bulle disparaît chez B,
  `encMedia` n'est plus en base.
- [ ] **Ancien build** (APK précédent) qui reçoit une photo chiffrée : image
  cassée, sans plantage. C'est attendu, et c'est pourquoi le drapeau attend la
  mise à jour minimale.
- [ ] **Thème sombre** : gabarit d'attente et état d'erreur de la barrière
  lisibles.

---

## ⬜ Désigner quelqu'un ouvre sa discussion, plus le sélecteur (2026-09-14)

**Priorité P1** · importance 4/5 — Trois entrées nommaient une personne et retombaient sur le sélecteur générique, identique au bouton « Nouvelle conversation » : la tuile « écrivez à … » de la messagerie vide (qui porte pourtant une flèche d'envoi), un résultat de recherche « personnes », et le bouton « Contacter » d'une fiche entreprise. Il fallait re-chercher à la main la personne qu'on venait de toucher du doigt.

La route `/messages/new` construisait `const NewConversationScreen()` — un
écran sans paramètre, qui ne lisait ni `?userId=` ni `state.extra`. Le
destinataire était donc bien construit par les appelants, puis jeté en silence
par le routeur ([app_router.dart](lib/core/router/app_router.dart)). L'écran
accepte maintenant un destinataire et, quand il en reçoit un, se comporte en
relais : il ouvre la discussion et **se remplace** par elle
([new_conversation_screen.dart](lib/features/messages/presentation/screens/new_conversation_screen.dart)).

- [ ] **Tuile « écrivez à … »** (messagerie vide) : le tap ouvre directement
  la discussion avec cette personne — pas le sélecteur. L'en-tête porte son
  nom et sa photo dès la première frame, sans libellé de repli.
- [ ] **Résultat de recherche « personnes »** : même comportement.
- [ ] **« Contacter » sur une fiche entreprise** : ouvre la discussion avec le
  propriétaire. C'est le seul appelant qui passait par `extra` et non par
  l'URL — à vérifier séparément, il emprunte l'autre branche du code.
- [ ] **Retour depuis la discussion ainsi ouverte** : ramène à la liste des
  messages, **pas** au sélecteur (c'est un `pushReplacement`). Vérifier aussi
  le retour système Android, pas seulement la flèche.
- [ ] **Discussion déjà existante** avec cette personne : on retombe dessus
  avec son historique, aucun doublon créé. À refaire deux fois de suite.
- [ ] **« Nouvelle conversation » et le crayon de l'en-tête** : inchangés, ils
  ouvrent toujours le sélecteur générique. C'est la garde symétrique.
- [ ] **Échec d'ouverture** (mode avion) : le sélecteur reprend la main avec
  l'erreur — pas d'écran bloqué sur le rond de chargement. Le repli vaut
  exactement le comportement d'avant le correctif.
- [ ] **Lien profond `/messages/new?userId=<id>`, pile vide** : la flèche du
  relais ramène à `/messages` et non dans le vide (voir « Pile vide » au § 7).

---

## ⬜ En sélection, la bulle ne fait plus que cocher (2026-09-14)

**Priorité P1** · importance 4/5 — Le mode sélection enveloppait le message dans un `GestureDetector`, mais le contenu gardait tous ses gestes en dessous. Pour un tap, c'est le gestionnaire **le plus profond** qui gagne : toucher un sondage votait au lieu de cocher. Même cause pour l'image (visionneuse), l'aperçu de lien (navigateur), l'envoi échoué (relance), le double-appui (réaction) et le glissement (réponse) — un vote parti par erreur ne se reprend pas d'un geste.

Le contenu passe sous `AbsorbPointer` tant que le mode est ouvert
([message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)) :
plus aucun pointeur ne l'atteint, le geste remonte au parent. L'appui long y
coche désormais aussi, au lieu d'ouvrir une feuille d'actions par-dessus la
barre de sélection. Le défaut est **préexistant** — il devient seulement plus
atteignable depuis « Sélectionner » sorti de « Autres actions ». Couvert par
`test/features/messages/mode_selection_gestes_test.dart` (les trois cas
tombent sans le correctif, vérifié).

- [ ] **Image, vidéo, aperçu de lien en sélection** : le tap coche, la
  visionneuse ne s'ouvre pas, le navigateur non plus.
- [ ] **Note vocale en sélection** : le tap coche, la lecture ne démarre pas.
- [ ] **Message en échec d'envoi, en sélection** : le tap coche, il ne
  relance pas l'envoi.
- [ ] **Sortie du mode** : une fois la sélection vidée, le sondage redevient
  votable et l'image réouvrable. C'est la garde symétrique du banc.
  ⬜ moitié, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : sélection vidée → le sondage redevient votable
  (Rouge + Vert → « Voter » → 2 votes en base). Image non essayée (aucune
  photo dans le 1:1).

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ En sélection, la bulle ne fait plus que cocher (2026-09-14) »).

---

## ⬜ « Sélectionner » sort de « Autres actions » (2026-09-14)

**Priorité P2** · importance 3/5 — Le menu d'appui long montrait cinq entrées et rangeait le reste derrière « Autres actions ». « Sélectionner » y était — et c'est le **seul** chemin vers la sélection multiple : un simple appui sur une bulle ne coche rien tant que le mode n'est pas entré. La conversation savait pourtant déjà tout faire une fois dedans (barre de compte, tout cocher, copier / transférer / supprimer la sélection) : la fonction était complète, sans porte d'entrée trouvable.

L'entrée rejoint la liste visible, juste avant le filet de « Supprimer »
([message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)).
Couvert par `test/features/messages/menu_appui_long_selectionner_test.dart`.

- [ ] **La liste tient sans défiler** sur le SM A515F avec les six entrées
  (Répondre, Copier, Transférer, Épingler, Sélectionner, Supprimer) plus la
  rangée de réactions. À l'échelle de police 1,3, vérifier qu'« Autres
  actions » reste atteignable.
  ⛔ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0), **police 1,0** : la liste ne tient PAS. Message reçu :
  6ᵉ entrée « Signaler » hors écran (bornes 0,0 dans `uiautomator`) ;
  sondage envoyé : « Supprimer » hors écran. La feuille s'arrête sur
  « Sélectionner » (y 2016–2186). Pas d'« Épingler » ni d'« Autres actions »
  dans ce menu MLS. Rien vu à 1,3 (réglage système interdit dans la passe).
  Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff) : même constat sur un message **envoyé** (PA22ECHEC) — Répondre,
  Modifier, Copier, Transférer à…, Ajouter aux favoris visibles, puis
  **« Sélectionner » hors écran** : la porte d'entrée que cette entrée devait
  rendre visible est à nouveau sous le pli pour ses propres messages.
- [ ] **Onde d'appui sur les entrées du menu** : la feuille passe de
  `Container` à `Material`, les `ListTile` peignaient leur onde derrière un
  fond opaque. Vérifier qu'un appui laisse maintenant une trace visible, en
  clair **et** en sombre, et que les coins arrondis du haut n'ont pas bougé.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ « Sélectionner » sort de « Autres actions » (2026-09-14) »).

---

## ⬜ Une couleur par pièce jointe dans le « + » (2026-09-14)

**Priorité P3** · importance 2/5 — Les huit tuiles du « + » se partageaient **deux** valeurs : l'accent du compte pour les médias, le secondaire pour le contenu interactif. Caméra, Galerie, Vidéos, Audio et Document sortaient donc du même orange, seul le libellé les distinguait — et sur un compte en thème Vert, les huit tombaient dans deux verts voisins.

Source unique : `AttachmentAccents`
([attachment_accents.dart](lib/features/messages/presentation/theme/attachment_accents.dart)),
lue par les **deux** surfaces du « + ». Même démarche que « Une couleur par
service dans les deux grilles », avec le même prune pour l'événement des deux
côtés. Contrastes calculés sur l'aplat à 12 % : ≥ 3,3:1 en clair sauf la
galerie (2,3:1, l'orange était déjà ainsi), ≥ 5,4:1 en nocturne. L'audio,
d'abord à 2,0:1, a reçu un or assombri pour le thème clair (3,85:1).

- [ ] **Appui simple sur le « + »** (panneau ancré, grille 3×2) : six teintes
  distinctes — Caméra teal, Galerie orange, Document bleu, Position
  terracotta, Sondage vert feuille, Événement prune.
- [ ] **Appui long sur le « + »** (ancien sheet complet) : une pièce jointe y
  porte la **même** couleur que dans le panneau. S'y ajoutent Vidéos (vert
  Niger) et Audio (or).
- [ ] **Tuile Audio en thème clair** : l'or du guide s'y délavait (2,05:1 sur
  son propre aplat), il est assombri à `#A26C1A` — 3,85:1, du même ordre que
  le bleu du document. Vérifier qu'il se lit encore comme un **or** et pas
  comme un brun, et qu'il ne jure pas avec l'orange de la galerie, deux tuiles
  plus loin. Le nocturne garde l'or du guide.
- [ ] **Salons audio**, si la tuile est réactivée un jour : elle porte le même
  or assombri (voir « Une couleur par service dans les deux grilles »).
- [ ] **Thème sombre** : les huit icônes restent lisibles sur leur aplat à
  12 %.
  ⬜ presque, Passe du 2026-09-22 (~05:35–05:45), build Play 1.2.2+26 (f22aaff, contient 37465e9), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : dans un 1:1, le « + » en montre **six** (Caméra,
  Photos, Documents, Position, Sondage, Événement), toutes lisibles sur leur
  aplat teinté. Les deux autres (propres aux groupes ?) pas vues. Aucune
  touchée.
- [ ] **Compte en thème Orange puis Vert** : les tuiles ne suivent plus
  l'accent du compte. Le « + » lui-même, lui, le suit toujours — vérifier que
  le panneau ne jure pas avec la pastille qui l'ouvre.
- [ ] **Groupe et 1:1** : Position, Sondage et Événement sont conditionnels
  (`onSendLocation`, `onCreatePoll`, `onCreateEvent`). La grille reste régulière
  quand il n'y a que trois ou quatre tuiles.

---

## ⬜ Sondage : voter se voit enfin, et les votants aussi (2026-09-14)

**Priorité P1** · importance 4/5 — Après avoir voté dans une bulle de sondage, la carte restait en mode vote : pas de pourcentages, choix non marqué, seul le total bougeait. Et la liste des votants était vide pour tout le monde, l'auteur compris.

*Bloqué : deux comptes (migration `20260914160000` appliquée, relu en base le 2026-09-22).*

Deux causes, l'une dans l'app, l'autre en base. Le flux du sondage
(`.stream()`) ne sait ni joindre ni lire une autre table : il rendait donc un
sondage « jamais voté » et sans auteur. Et `post_poll_votes` n'est lisible que
par l'auteur de la ligne — la lecture des votants réussissait à vide.
Voir « Sondage dans une discussion privée » pour le parcours de création.

- [ ] **Sondage terminé** : « Sondage terminé » dans la ligne d'info, plus
      aucune façon de voter ni de se corriger.
- [ ] **La notice sous la question** : « Vote public : votre nom sera
      visible », ou « Vote anonyme » — lisible AVANT de choisir, dans la
      bulle comme dans le fil. *Les trois sondages du groupe Testeurs l'ont
      affichée correctement à froid le 2026-09-14 (deux « Vote public », un
      « Vote anonyme ») ; les absences vues pendant la passe venaient de taps
      à l'estime qui regardaient un autre écran.*

- ✔ 15 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Sondage : voter se voit enfin, et les votants aussi (2026-09-14) »).
---

## ⬜ Un message non envoyé ne disparaît plus, et repart tout seul (2026-09-14)

**Priorité P0** · importance 5/5 — Un message écrit hors ligne partait dans Hive et **y restait pour toujours** : `processQueue()` n'était appelé de nulle part. Jamais envoyé, jamais purgé, jamais compté — et disparu de l'écran.

*Bloqué : deux comptes (le réseau se coupe au mode avion).*

`OfflineQueueService` était complet mais orphelin : `processQueue`,
`cleanOldMessages`, `pendingMessagesCountProvider` et
`messageFailureStreamProvider` n'avaient **aucun appelant**. Seul `enqueue`
était branché, sur l'envoi de texte hors ligne.

- [ ] **Une réponse citée et une carte de publication** écrites hors ligne
      repartent **entières**. Les champs plats de `PendingMessage` les
      perdaient, et codaient le type « text » en dur.
  ✅ moitié réponse, Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : réponse à PE1 écrite en mode avion → « Non envoyé », réseau rétabli → repartie seule en 15 s, citation intacte chez le destinataire (« Vous | PE1 | PF1 »). En MLS la citation voyage dans le chiffré, `reply_to_id` reste nul — c'est voulu. Carte de publication pas testée.
- [ ] **Une photo écrite hors ligne** repart avec son image. Si Android a
      purgé le fichier temporaire entre-temps, le message reste affiché en
      échec plutôt que de repartir vide.
- [ ] **Pas de doublon** : un message marqué en échec par le délai de 30 s
      dont l'écho serveur arrive en retard ne doit PAS être renvoyé une
      seconde fois. (`oublierMessageEnAttente` sur l'écho)
- [ ] **Message de plus de 24 h** : il ne repart pas tout seul, il attend
      « Renvoyer ». (`kFenetreRenvoiAutomatique`)
- [ ] **La file ne gonfle pas** : après une série d'envois réussis, vérifier
      qu'il ne reste rien en attente.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Un message non envoyé ne disparaît plus, et repart tout seul (2026-09-14) »).

---

## ⬜ Une discussion ouverte ne reste plus prisonnière de son cache (2026-09-14)

**Priorité P0** · importance 5/5 — Trois chemins laissaient l'écran de discussion sur sa copie locale sans plus rien écouter, dont un qui **écrase le cache** avec du vide.

*Bloqué : deux comptes (le réseau se coupe au mode avion).*

Trouvé en essayant de tester le rattrapage en discussion ouverte, et c'est ce
qui empêchait ce test d'aboutir : `_loadNetworkData()` sortait avant de poser
les abonnements temps réel, donc le rattrapage ne pouvait pas exister.

- [ ] **Discussion ouverte PENDANT que l'appareil est hors ligne**, puis retour
      du réseau : les messages arrivés entre-temps s'affichent seuls. Avant, la
      sortie anticipée sur `isOffline` ne posait **aucun écouteur** et rien ne
      la relançait — l'écran restait figé jusqu'à ce qu'on ressorte et rentre.
      (`message_provider.dart`, `_loadNetworkData`)
  ⛔ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (MLS) : discussion ouverte à froid en mode avion, PE1 envoyé, réseau rétabli sans toucher → rien en 2 min (écran allumé, réseau vérifié) ; PE1 n'apparaît qu'en rouvrant. La liste, elle, l'avait rattrapé. Cause : le canal `mls_new` n'avait pas de rattrapage, et même avec, le premier `subscribed` (celui du retour du réseau) était ignoré. Corrigé (voir « Temps réel après l'arrière-plan, et texte supprimé dans la liste »).
- [ ] **Démarrage à froid directement dans une discussion** (notification, lien
      profond, restauration de route) : la discussion se remplit. La session
      Supabase n'est pas encore établie à cet instant, et `messages_select`
      étant de rôle `public`, la lecture **réussissait à vide** — le repository
      mettait ce vide en cache par-dessus la vraie discussion.
      (`message_supabase_datasource.dart`, garde `_ensureReadableAuth`)
- [ ] **Vérifier qu'aucune discussion n'a été vidée** par ce chemin avant le
      correctif : ouvrir les discussions anciennes et confirmer que l'historique
      est là. Le cache est local, donc le dégât éventuel est sur l'appareil,
      pas en base.
- [ ] **Lecture réseau en échec avec un cache non vide** (réseau très dégradé) :
      l'écran garde la discussion lisible, et une relance finit par aboutir —
      deux essais, à 4 s puis 10 s.
- [ ] **Pas de relance en boucle** : rester hors ligne plusieurs minutes sur
      une discussion ne doit pas produire une requête toutes les secondes
      (`adb logcat`, ou compteur de requêtes côté Supabase).
- [ ] **« Vider la discussion »** continue de fonctionner : une discussion
      réellement vidée doit rester vide, la garde ne doit pas la repeupler.

---

## ✅ Un échec de lecture en messagerie se voit, sans effacer l'écran — corrigé, vérifié SM A515F (2026-09-14)

**Priorité P1** · importance 4/5 — Les trois flux de `MessageRepositoryImpl` avalaient leurs erreurs : plus aucun événement, donc rond de chargement sans fin sur la liste, aucun bandeau, aucun réessai, et l'export d'une discussion qui attend pour toujours.

Se rejoue avec le mode avion, sur un seul téléphone.

**Corrigé le 2026-09-14**, cinq fichiers : `_echecEmis<T>()`
(`StreamTransformer.fromHandlers`, l'idiome déjà utilisé par
`ProfileRepositoryImpl`) remplace les trois `.handleError` ; les trois providers
propagent l'échec en erreur au lieu de le déguiser en `null` ou en liste vide ;
`hasLoadError` ne vaut plus que si la conversation est inconnue et pose un
liseré **au-dessus** du composeur au lieu de le remplacer ; la liste et la
feuille de partage prennent `skipError: true`, pour qu'une panne n'efface jamais
ce qui est déjà à l'écran. Deux tests neufs :
`test/features/messages/echec_de_lecture_test.dart`.

- [ ] **Panne persistante** (et non une simple coupure) : sur un refus RLS qui
      dure, vérifier que la liste finit bien par montrer son état d'erreur —
      `skipError` ne doit masquer une panne que tant qu'il reste quelque chose à
      afficher.
- [ ] **Export d'une discussion** hors ligne (`conversation_options_modal`) :
      doit échouer proprement avec son message, et non rester à tourner.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Un échec de lecture en messagerie se voit, sans effacer l'écran — corrigé, vérifié SM A515F (2026-09-14) »).

---

## ✅ L'identité du correspondant revient seule après une coupure — corrigé, vérifié SM A515F (2026-09-14)

**Priorité P1** · importance 4/5 — Un profil dont la lecture échouait pendant une coupure restait en échec pour toute la vie de l'app : l'en-tête d'une discussion affichait « Conversation » et un avatar « C » à la place du nom, et ni le retour du réseau ni un aller-retour hors de l'écran ne le corrigeaient. Seul un redémarrage.

Se rejoue seul avec le mode avion.

- [ ] **Groupe et « Mes notes » par lien profond** : le semis lit aussi la
      nature du fil dans la conversation en cache (nom et image d'un groupe,
      « Mes notes » par différence avec le compte courant). Écrit, analysé,
      **pas mesuré** : il faudrait l'identifiant d'une conversation de groupe,
      que rien n'expose depuis l'appareil — logcat n'en montre aucun en release
      et la base n'est pas liée sur ce poste.
- [ ] **Notification d'une discussion jamais ouverte** : le push porte déjà
      `senderName`, `senderPhotoUrl`, `senderId` et `conversationType` ;
      [app.dart:92](lib/app.dart:92) les passe en `extra` au moment de
      naviguer, faute de quoi aucun cache local ne peut renseigner un fil
      inconnu. Demande deux comptes et un vrai push pour être vérifié.
- [ ] **Lien profond brut vers une discussion inconnue, hors ligne** : mesuré
      le 2026-09-14 — « Chargement… » et le bandeau « Mode hors ligne », qui
      restent. C'est le cas où aucune source n'existe : ni cache, ni réseau, ni
      `extra`. Vérifier qu'il se remplit bien au retour du réseau.
- [ ] **Compte réellement supprimé** : vérifier que ce cas affiche toujours
      « Utilisateur » et non un état d'erreur réessayable.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ L'identité du correspondant revient seule après une coupure — corrigé, vérifié SM A515F (2026-09-14) »).

---

## ⬜ Actualisation automatique après coupure ou retour d'arrière-plan (2026-09-13)

**Priorité P1** · importance 5/5 — Messages, notifications et fil cessaient de s'actualiser seuls : les canaux se re-rejoignaient bien après une coupure, mais Postgres ne rejoue pas les événements manqués et rien n'allait les relire. Aucune erreur à l'écran — simplement plus rien n'arrivait.

*Bloqué : deux comptes (le réseau se coupe au mode avion).*

Ne se teste **que** sur appareil : la coupure de socket, la mise en veille
Android et la suspension des timers n'existent pas sous `flutter test`.

- [ ] **Écran ouvert alors que l'appareil est DÉJÀ hors ligne**, puis retour
      du réseau : la liste se remplit seule. C'est le trou trouvé pendant la
      passe du 2026-09-14 — la lecture initiale échouait, rien ne la
      retentait, et le premier `subscribed` était sauté comme « déjà lu ».
      Corrigé par `lectureInitialeEnEchec`, **jamais revérifié sur appareil**.
- [ ] **Discussion ouverte** : même scénario, écran de discussion affiché à
      l'écran → les messages manqués s'insèrent dans l'ordre, **sans doublon**
      (la déduplication par id de `MessageNotifier` doit les absorber).
- [ ] **Fil** : Sim publie pendant la coupure → au retour, la pastille
      « nouvelles publications » apparaît toute seule.
      (`feed_supabase_datasource.dart`)
- [ ] **Notifications** : déjà rattrapées avant cette session ; vérifier que
      rien n'a régressé.
- [ ] **Veille longue** (le cas qui a motivé l'observateur de cycle de vie) :
      app en arrière-plan **plus d'une heure** — le JWT Supabase expire et les
      timers Android sont suspendus — puis retour au premier plan : tout
      revient sans redémarrer l'app. (`supabase_auth_bridge.dart`,
      `surveillerLeCycleDeVie`)
  ⛔ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : le Pixel sortait d'un long séjour derrière Facebook. Discussion ouverte au premier plan : PA3 puis PA4 (Sim → Salim) n'arrivent PAS en direct (1 min+, écran éveillé) ; la liste reste figée sur un message de 16:04. Rouvrir la discussion ne répare pas le direct ; seule une relance à froid le rétablit (PA5 arrive alors en ~3 s). Même famille côté Sim après un HOME court : PA2 absent du fil au retour, liste figée à 18:14 alors que PA7 était arrivé.
- [ ] **Pas de tempête de requêtes** : basculer Wi-Fi ↔ données plusieurs fois
      de suite ne doit pas relancer une relecture par seconde (`adb logcat`,
      lignes « realtime: rejoint … → rattrapage »).

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Actualisation automatique après coupure ou retour d'arrière-plan (2026-09-13) »).

---

## ⬜ Nom et avatar du correspondant dans la liste des discussions (2026-09-13)

**Priorité P1** · importance 4/5 — Les lignes affichaient par intermittence « Utilisateur » et un avatar à initiale à la place du correspondant : le flux de profil partait avant que la session Supabase soit établie, la policy `users_select` (rôle `public`) ne renvoyait alors **aucune ligne** pour un profil privé, et cette absence était lue comme « compte supprimé ».

*Bloqué : deux comptes, dont un au profil privé.*

- [ ] **Profil privé** en face : le nom et la photo s'affichent quand même
      dans la liste (l'amitié/la discussion n'est pas un accès au profil, mais
      le nom doit rester lisible).
- [ ] **« Contacts récents »** (Nouvelle conversation) : chaque 1:1 porte le
      nom et la photo du correspondant, plus « Utilisateur » ; le tap ouvre
      la bonne discussion avec le bon en-tête. *Attend un build qui porte le
      correctif du 2026-09-22.*
- [ ] **Compte réellement supprimé**, s'il y en a un sous la main : là,
      « Utilisateur » est le bon affichage — la correction ne doit pas l'avoir
      masqué.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Nom et avatar du correspondant dans la liste des discussions (2026-09-13) »).

---

## ⬜ Sondage dans une discussion privée (2026-09-12)

**Priorité P2** · importance 3/5 — Le « + » du composeur n'offrait « Sondage » que dans les groupes.

*Bloqué : deux comptes (migration `20260912233000` appliquée, relu en base le 2026-09-22).*

- [ ] « Mes notes » garde son brouillon de sondage (note texte), et un groupe
  garde ses permissions « qui peut créer un sondage ».

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Sondage dans une discussion privée (2026-09-12) »).

---

## ⬜ Cartes de post et d'événement lisibles dans une bulle envoyée (2026-09-12)

**Priorité P2** · importance 3/5 — Sur la bulle verte, le nom de l'auteur, « Voir la publication → » et « Voir l'événement → » étaient quasi invisibles (sarcelle et violet sur vert), et le texte « 📌 Post de… » répétait la carte.

- [ ] **Bulle envoyée** : post partagé et événement créé dans la discussion —
  auteur, titre, « Voir … → » en blanc lisible sur un voile sombre ; plus de
  ligne « 📌 Post de Salim L. » / « 📅 test » sous la carte.
  (`shared_card_palette.dart`, `post_message_card.dart`,
  `event_message_card.dart`)
  ⬜ moitié, Passe du 2026-09-22 (~05:15–05:30), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : carte de **publication envoyée** (« Salim L. · In kwana ·
  Voir la publication → », 13/09) : blanc lisible sur le voile vert sombre.
  La carte d'événement vue (« Événement · test ») est une bulle **reçue**.
- [ ] **Bulle reçue** (côté Sim), thème clair ET sombre : accents à la couleur
  du thème, lisibles sur bulle blanche et sur bulle `#252119`.
- [ ] **Texte ajouté par l'utilisateur** sous une carte : toujours affiché.
- [ ] **Taille du texte** (validée par Salim sur aperçu le 2026-09-13) : auteur,
  en-tête, liens, date et lieu 16 ; extrait du post 17,5 ; titre de l'événement
  19. Vérifier sur le Pixel et sur le SM A515F (échelle de police 1.1) qu'aucun
  titre long ne déborde de la bulle.
- [ ] L'aperçu de la liste des discussions garde « 📌 Salim L. » (inchangé).

---

## ⬜ Copier : légendes, positions, sondages, un passage, une sélection (2026-09-12)

**Priorité P2** · importance 3/5 — « Copier » n'existait que pour un message texte : ni légende de photo, ni adresse, ni sondage, ni un seul numéro dans un long message.

- [ ] **Appui long sur une photo ou vidéo AVEC légende** → « Copier » présent,
  colle la légende. Sans légende → pas de « Copier ».
  (`message_copy_text.dart`, `message_bubble.dart`)
- [ ] **Position** → « Copier » colle l'adresse puis un lien Google Maps qui
  s'ouvre depuis une autre app. **Sondage** → la question.
  ⬜ moitié, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : **sondage** → « Copier » colle la question
  (« PA22 Sondage multiple anonyme », relu en collant dans le composeur, vidé
  ensuite sans envoi). Position non essayée.
- [ ] **Autres actions → « Sélectionner le texte »** : feuille avec le texte
  sélectionnable ; appui long dedans, choisir un numéro ou un lien, menu
  système Copier ; « Tout copier » ferme et copie tout. Message long : la
  feuille défile.
  ⬜ presque, Passe du 2026-09-22 (~05:15–05:30), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : sur RATTRAPAGE-HORS-LIGNE-1 → feuille « Sélectionner
  le texte » avec le texte et « Tout copier » ; appui long dans le texte →
  menu système Copier / Partager / Tout sélectionner ; « Tout copier » ferme
  la feuille et copie (collé dans le composeur puis vidé :
  « RATTRAPAGE-HORS-LIGNE-1 »). Reste : un message long qui fait défiler la
  feuille.
- [ ] **Sélection multiple** : sélectionner 3 messages dont un vocal → icône
  Copier dans la barre verte ; le collage donne une ligne
  « [12/09/2026 21:04] Nom : texte » par message texte, dans l'ordre, sans le
  vocal. Sélection de vocaux seuls → pas d'icône. Barre sur écran étroit
  (SM A515F, police 1.1) : le titre « N sélectionnés » ne déborde pas avec
  une icône de plus. (`conversation_screen.dart`)
  ⬜ en partie, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : PH1 + PJ2 sélectionnés → icône Copier ;
  collage = « [21/09/2026 20:04] Salim L. : PH1 » puis « [21/09/2026 20:12]
  Salim L. : Salim L. a raison PJ2 », dans l'ordre. Pas de vocal dans le fil.
  Barre : le titre est **tronqué en « 2 sélecti… »** dès la police 1,0 (il ne
  déborde pas, mais ne se lit plus).

---

## ⬜ Réactions : double tap, cœur rouge, notification, mise à jour (2026-09-12)

**Priorité P1** · importance 4/5 — Le double tap posait d'office un cœur (noir), une réaction n'envoyait aucune notification et disparaissait parfois chez l'autre.

*Bloqué : la notification et la mise à jour croisée demandent deux comptes (Pixel + SM A515F) ; la migration `20260912220000` est appliquée (relu en base le 2026-09-22).*

- [ ] **Cœur rouge** : ❤️ rouge sous la bulle, dans la barre, dans le
  sélecteur, dans une bulle « emoji seul », dans le composeur en tapant, dans
  l'aperçu de la liste des discussions. Aussi ☀️. Et ⚠ reste un symbole de
  texte coloré dans les salons audio. (`assets/google_fonts/Inter-*.ttf`,
  `tools/polices_emoji_couleur.py`)
  ⬜ en partie, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : ❤️ rouge sous la bulle, dans la barre et dans la
  feuille d'appui long (SM A515F (Sim, clair, police 1,0)), et sous la bulle côté Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras). Pas vus : bulle
  « emoji seul », composeur, aperçu de liste, ☀️, salons audio.
  Passe du 2026-09-22 (~05:15–05:30), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : ☀️ **en couleur** dans le sélecteur et sous la bulle (réaction
  sur un ancien message, stockée dans `messages.data.reactions`). Emoji seul,
  composeur et aperçu de liste toujours pas vus : la recherche du sélecteur
  du COMPOSEUR bascule sur le clavier système sans champ visible (défaut
  connu, corrigé pour le +28), test abandonné pour ne pas taper dans le
  composeur à l'aveugle.
- [ ] **Mise à jour croisée** : les deux téléphones sur la même discussion,
  réagir en rafale d'un côté puis de l'autre, quitter/rouvrir la discussion
  entre deux : chaque réaction apparaît chez l'autre sans relancer l'app, et
  l'accusé « Lu » ne disparaît plus. (`message_supabase_datasource.dart`)
  ⬜ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : pas mesuré en direct (le +26 ne rafraîchit pas les réactions
  MLS en direct, connu). Après relance à froid du Pixel, le ❤️ de Sim est bien
  sous PH1, « Lu » conservé.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Réactions : double tap, cœur rouge, notification, mise à jour (2026-09-12) »).

---

## ⬜ Partager vers une discussion — groupe et 1:1 (2026-09-09)

**Priorité P1** · importance 3/5 — Les discussions privées disparaissent du sélecteur de partage et de transfert dès qu'on tape un nom, et une carte partagée ouvre une page 404 au lieu du groupe ou du profil.

Une destination « discussion » a été ajoutée partout, et la résolution
nom/avatar d'une conversation vit désormais dans une seule source
(`conversation_picker_sheet.dart`).

- [ ] **Groupe → discussion** : fiche d'un groupe → Partager → « Envoyer dans
  une discussion ». La liste doit montrer les 1:1 avec le vrai nom et la vraie
  photo du contact, et les groupes avec leur nom.
  (`lib/features/groups/presentation/widgets/share_group_modal.dart`)
- [ ] **Profil → discussion** : idem depuis Partager un profil (le sien et
  celui de quelqu'un d'autre).
  (`lib/features/profile/presentation/widgets/share_profile_modal.dart`)
- [ ] **Recherche dans le sélecteur** : taper le prénom d'un contact doit
  laisser sa discussion privée visible — c'était le bug de fond, présent aussi
  dans « Transférer » et dans le partage entrant depuis une autre app.
  (`conversation_picker_sheet.dart`, `forward_conversation_picker.dart`,
  `share_to_conversation_screen.dart`)
- [ ] **Sélection multiple** : bouton « Sélectionner », cocher 2-3
  discussions, « Envoyer à N conversation(s) » ; vérifier que le message
  arrive dans chacune.
- [ ] **Carte reçue à l'arrivée** : dans la discussion cible, un groupe ou un
  profil partagé doit s'afficher en carte d'aperçu (image + titre) et le tap
  doit ouvrir l'écran **dans l'app**, pas le navigateur (le site rend 404 sur
  ces routes). (`link_preview_bubble.dart`)
- [ ] **Post → discussion** : la liste du partage de post, corrigée, doit
  afficher les 1:1 correctement ; la bulle reçue reste la carte de post.
- [ ] **Événement / salon audio / podcast / épisode** : le bouton Partager
  ouvre désormais une feuille à deux étages (discussion, puis réseaux). Sur
  événement, la bulle reçue doit être la carte d'événement (date + lieu) et
  ouvrir la fiche au tap.
- [ ] **Thème sombre** : feuille de partage, sélecteur et carte d'aperçu en
  mode nuit.
- [ ] **Débordement** : le sélecteur avec le clavier ouvert (champ de
  recherche) sur écran court, et un nom de contact très long.

---

## ⬜ Aucun marqueur technique dans une bulle (2026-09-09)

**Priorité P0** · importance 5/5 — Le soin du cache ou la synchro incrémentale réécrit un marqueur par-dessus un message déjà déchiffré : le texte est perdu pour de bon, le serveur ne pouvant plus le redéchiffrer (ratchet Signal / Sender Key).

**2. La bulle n'affiche plus de vocabulaire interne.** Les trois marqueurs
mènent désormais à `UndecryptableMessageBubble` — « *Message indisponible sur
cet appareil* », en gris, sans bouton. `E2EESessionRequiredBubble` (et son
bouton « Récupérer la clé de groupe ») n'est plus branchée nulle part ; le
remède reste porté **une seule fois** par le bandeau en tête de discussion
(`_buildE2eeRestoreBanner`), au lieu d'être répété sur chaque bulle.

À vérifier **sur SM A515F** :

- [ ] Le fil de la capture n'affiche plus « Message chiffré — clé de groupe
      introuvable », ni le bouton « Récupérer la clé de groupe », ni
      « [Message illisible] » : une ligne grise « Message indisponible sur cet
      appareil » à la place.
- [ ] Une photo **sans légende** s'affiche normalement — la garde lit la
      LISTE, pas `isUndecryptableContent`, qui tient le vide pour illisible et
      masquerait chaque média sans légende.
- [ ] Thème sombre : la ligne grise reste lisible (jetons `textTertiaryColor`
      / `iconTertiaryColor`, pas de teinte figée).
      Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) (clair) : la bulle « Message indisponible sur cet appareil »
      a enfin été vue une fois — dans « Mes notes », sur une note envoyée
      « modifié 18:11 » du 11/09 : icône œil barré, texte gris italique sur la
      bulle verte, aucun « [Message illisible] » ni bouton « Récupérer la clé ».
      Pas vue en sombre (le Pixel n'a pas cette note).
- [ ] ⚠️ Le cache local **fusionne**, il ne se vide pas : un message déjà
      empoisonné par `[Message illisible]` avant ce correctif le reste. Pour
      juger, viser un message encore lisible aujourd'hui, ou vider la
      discussion.

Reste donc à voir **au moins une fois** la nouvelle bulle, et surtout à
exercer le vrai chemin du correctif : envoyer un message dans un groupe,
quitter la discussion, y revenir, faire un pull-to-refresh.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Aucun marqueur technique dans une bulle (2026-09-09) »).

---

## ✅ Vidéos envoyées en messagerie traitées comme des documents (2026-08-30)

**Priorité P2** · importance 4/5 — Une vidéo choisie dans la galerie — le chemin le plus courant — arrive comme un fichier générique, sans aperçu ni lecteur.

- [ ] Envoyer une vidéo depuis la galerie intégrée (`GalleryPickerScreen`,
  sélection unique) : la bulle doit afficher une vignette + bouton lecture,
  pas une icône de fichier. **Bloqué le 2026-08-30** : aucune vidéo dans la
  galerie partagée du SM A515F pour la sélectionner (les vidéos captées par
  l'app restent en stockage privé, jamais dans `DCIM`/`Movies`), et trois
  tentatives pour en déposer une ont échoué — `am start -a VIDEO_CAPTURE`
  sans Activity appelante ne persiste rien, l'appli Caméra stock (Samsung)
  utilise un sélecteur de mode PHOTO/VIDÉO en `SeekBar` (glisser, pas taper)
  qui a déclenché à la place un contrôle d'exposition puis un geste système
  de retour, et un swipe de défilement dans la conversation a été interprété
  comme un geste système (retour à l'app relancée). À reprendre avec une
  vraie vidéo poussée par `adb push` + `MEDIA_SCANNER_SCAN_FILE` plutôt que
  par UI.
- [ ] Envoyer une vidéo via le sélecteur système dédié (`_pickVideo`,
  `image_picker`) — même blocage : nécessite une vidéo déjà dans la galerie.
- [ ] Envoyer plusieurs vidéos/photos mélangées en un lot (revue groupée
  `MediaBatchPreviewScreen`) : chaque vidéo du lot doit garder son type —
  même blocage.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Vidéos envoyées en messagerie traitées comme des documents (2026-08-30) »).

---

## ✅ Bulle de chargement d'une vidéo pendant l'upload (2026-08-30)

**Priorité P2** · importance 1/5 — Impossible d'annuler l'envoi d'une vidéo lancée par erreur : elle part quand même.

- [ ] Vérifier la vignette avec une vidéo bien éclairée (testée dans une
  pièce sombre — la vignette réelle vs le placeholder shimmer étaient
  difficiles à distinguer visuellement dans cette lumière).
- [ ] Vérifier qu'annuler l'upload pendant qu'une vidéo est en cours
  (bouton croix sur l'anneau de progression) fonctionne comme pour une image.
  **Tenté le 2026-08-30, non concluant** : sur un clip de 2,3 Mo (wifi
  correct), l'upload se termine en moins de temps qu'il n'en faut pour
  enchaîner « capturer l'écran → taper la croix » via automation — le bouton
  était encore visible sur la capture mais le message était déjà « Envoyé »
  au moment du tap. Pas un échec du bouton (jamais atteint dans l'état
  voulu) : à refaire au doigt, ou avec une vidéo assez lourde pour laisser
  quelques secondes de marge.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Bulle de chargement d'une vidéo pendant l'upload (2026-08-30) »).

---

## Messagerie (hors refonte Fil & Discussion)

**Priorité P1** · importance 2/5 — Un utilisateur qui a masqué son statut en ligne reste affiché « En ligne » aux autres, contre sa préférence de confidentialité. *Bloqué : deux comptes (statut en ligne, accusé « Reçu »).*

- [ ] **En-tête hero de la liste des messages** (dégradé + puces de filtre, commit `65c1852`) — jamais vu à l'écran, l'APK était cassé (toolchain JDK 17) au moment du commit.
- [ ] **Statut en ligne (Firestore → Supabase)** (commit `b16dc88`) — bug de confidentialité corrigé (préférence `showOnlineStatus` ignorée), jamais vérifié à l'écran.

---

## Discussion — heure absente/dupliquée sur les bulles média (2026-08-30)

**Priorité P3** · importance 3/5 — Certaines bulles média restent sans heure visible, sans moyen de la révéler.

- [ ] **Rafale de messages texte, images, vidéos, documents, notes vocales,
  positions, stickers** du même expéditeur : chaque bulle doit désormais
  porter son heure, y compris celles qui n'étaient pas le dernier message
  de la rafale.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Discussion — heure absente/dupliquée sur les bulles média (2026-08-30) »).

---

## ⬜ GIFs via `gif-proxy` — clés sorties de l'APK (2026-08-27)

**Priorité P0** · importance 4/5 — L'onglet GIFs est **cassé en production depuis le 2026-08-27** : `gif-proxy` n'a jamais été déployée. Ce n'est plus une hypothèse (relevé du 2026-09-16 : `supabase functions list` en donne 16, sans elle ; un POST répond `404 NOT_FOUND`). Tout appel de l'onglet échoue, l'utilisateur lit « Impossible de charger les GIFs. »

Fichiers : `supabase/functions/gif-proxy/index.ts`,
`lib/features/gifs/data/datasources/gif_proxy_datasource.dart`.

- [ ] Recherche : taper un mot renvoie des résultats (chemin `search`)
  ⛔ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (SM A515F) : « Recherche » lève le clavier, qui RECOUVRE le panneau : aucun champ visible ni exposé à l'accessibilité, on tape à l'aveugle, aucun résultat observable.
- [ ] **Un seul aller-retour par requête** : le repli entre fournisseurs est
      passé côté serveur (`provider: 'auto'`). Avant, le client tentait Tenor —
      jamais configuré — puis Giphy, soit deux appels de fonction par frappe.
      Se lit dans les logs de la fonction : une ligne par chargement, pas deux
- [ ] **Cache** : fermer le picker puis le rouvrir doit réafficher la grille
      **sans** appel réseau (tendances gardées 15 min)
- [ ] **Bouton « Réessayer »** : couper le réseau, ouvrir l'onglet, le
      rebrancher, taper Réessayer — la grille doit se remplir sans avoir à
      retaper une recherche
- [ ] **Compte tout frais / app relancée** : le picker exige désormais une
      session Supabase (la fonction refuse l'anonyme). À ouvrir dans les
      premières secondes après un démarrage à froid, quand le pont
      Firebase→Supabase n'a pas encore répondu — voir « Session Supabase »
- [ ] **Poids du média envoyé** : les GIFs partent en `mediumgif` (Tenor) /
      `downsized_medium` (Giphy) au lieu de l'original, qui montait à
      plusieurs Mo payés par chaque destinataire. Vérifier que la qualité
      reste acceptable en plein écran

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ GIFs via `gif-proxy` — clés sorties de l'APK (2026-08-27) »).

---

## ⬜ Heure et accusé sur tous les messages, bascule supprimée (2026-08-23)

**Priorité P2** · importance 4/5 — Un envoi raté au milieu d'une rafale n'affiche pas son « Réessayer » : le message reste non envoyé sans que l'utilisateur le sache ni puisse le relancer.

[message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)
`_buildMetaRow` : le regroupement visuel des rafales ne masque plus rien de la
ligne méta. Chaque message — envoyé comme reçu, isolé comme au milieu d'une
rafale — affiche son heure et, côté envoyé, son accusé. Le champ
`_metaRevealed`, le getter `_isLastInGroup` et la zone de tap invisible de
48×16 px sous la bulle ont été supprimés.

Deux raisons : la zone tapable n'avait aucune affordance (indevinable), et
elle masquait aussi le libellé « Échec · Réessayer » d'un envoi raté qui
n'était pas le dernier de sa rafale — le seul chemin pour relancer l'envoi.

- [ ] **Heure sur chaque message d'une rafale envoyée** : envoyer 3 messages
  coup sur coup en 1:1, vérifier que les 3 portent leur heure sans aucun tap
  (avant : seul le dernier).
- [ ] **Accusé répété** : les 3 portent aussi « · Envoyé »/« · Lu ». C'est le
  point à juger à l'œil — si la répétition est trop bruyante, il suffit de
  re-conditionner `_buildReceiptLabel` à la fin de rafale sans revenir sur
  l'heure.
- [ ] **Plus aucun tap actif** : taper sous une bulle du milieu de rafale ne
  doit plus rien masquer ni révéler (ni ouvrir quoi que ce soit).
- [ ] **Échec d'envoi au milieu d'une rafale** (mode avion, 3 messages, le
  2e forcé en échec) : « Échec · Réessayer » visible et cliquable sur ce
  message sans interaction préalable.
- [ ] **Rafale reçue** et **groupe** : heure sur chaque bulle, nom de
  l'expéditeur toujours sur la seule première bulle, queue de bulle toujours
  sur la dernière (le regroupement visuel n'a pas bougé).

---

## Neuf défauts signalés à l'usage — correctifs du 2026-08-22

Salim a remonté neuf symptômes après usage réel. Huit ont une cause trouvée et
corrigée, le neuvième attend un exemple. **Aucun n'est vérifié sur appareil.**

### 1. L'appui sur une notification ne faisait rien

**À vérifier sur appareil** : ouvrir la page Notifications sur un compte qui a
reçu (a) une demande d'ami, (b) une notification de publication du fil, (c) un
commentaire. Chacune doit ouvrir sa destination. Une notification sans
destination connue ouvre désormais sa fiche au lieu de ne rien faire.

### 2. « Erreur de chargement » intermittente sur les notifications

**À vérifier** : ouvrir la page Notifications juste après un démarrage à froid
(le cas où la course se produit), puis couper/rétablir le réseau en restant sur
l'écran — la liste doit revenir seule, sans message d'erreur.

### 3. Le bandeau de restauration des clés revenait sans arrêt

**À vérifier** : écarter le bandeau avec « Pas maintenant », tuer l'app, la
rouvrir — il ne doit pas revenir. Puis faire une vraie sauvegarde depuis
Sécurité : la veille est effacée.

### 5. La bulle « écrit… » ne s'affichait jamais

**À vérifier — nécessite DEUX téléphones** : A tape, B doit voir la bulle
apparaître, et disparaître ~3 s après l'arrêt de la frappe puis à l'envoi. B
quitte la discussion : la présence doit s'effacer chez A.

### 6. Les messages vocaux ne partaient pas

**À vérifier** : enregistrer un vocal, l'envoyer, vérifier qu'il arrive chez le
destinataire, qu'il se lit des deux côtés, que la forme d'onde et la durée sont
justes, et que l'aperçu de la conversation affiche « Message vocal ».

### 9. L'app restait utilisable par-dessus l'écran de verrouillage — SÉCURITÉ

**À vérifier sur appareil, en deux temps** :

1. App ouverte sur une discussion, verrouiller, rallumer l'écran : le keyguard
   DOIT demander le code, l'app ne doit pas être visible.
2. Recevoir un appel téléphone verrouillé, accepter depuis la bannière :
   l'écran d'appel doit s'afficher par-dessus le keyguard et l'écran s'allumer.
   Raccrocher, verrouiller à nouveau, puis revalider le point 1 (le privilège
   doit avoir été rendu).

---

## Fonctionnalité épingle mise en pause (2026-08-14)

**Priorité P2** · importance 2/5 — La bascule ÉCO, qui partageait sa ligne avec le bandeau épinglé commenté, a pu disparaître en silence : plus de moyen d'économiser les données sur les médias.

Sur demande, le bouton Épingler/Détacher (menu contextuel d'un message), le
bandeau épinglé (`GroupPinnedBanner`) et la ligne « Épinglés » de la fiche
groupe (`_GroupInfoCard`) ont été désactivés — commentés, pas supprimés, pour
réactivation future :
- `lib/features/messages/presentation/screens/conversation_screen.dart` :
  `canPin` figé à `false` ; `_pinMessage`/`_unpinMessage`/
  `_refreshPinnedBanner`/`pinnedMessageIds` commentés.
- `lib/features/groups/presentation/widgets/group_pinned_banner.dart` :
  `_GroupPinnedBannerState.build` ne rend plus que la pastille `trailing`
  (bascule ÉCO — **doit rester visible**, elle n'a rien à voir avec
  l'épinglage) ; `_PinnedRow` et son bloc de rendu commentés en entier.
- `lib/features/groups/presentation/screens/group_detail_screen.dart` :
  la ligne « Épinglés » et `_pinnedSummary` commentées dans `_GroupInfoCard`.

`flutter analyze` propre (aucun avertissement de code mort/import inutilisé)
après ce commentage — les nombreux items `[ ]` d'épingles (« Messages épinglés — le bandeau n'était pas temps réel », « Groupes — défauts trouvés en vérifiant les épingles ») datant d'avant le
2026-08-14 portent sur une fonctionnalité désormais désactivée : les
retester n'a de sens qu'après réactivation.

- [ ] **Bascule ÉCO toujours visible** sur une conversation (1:1 et groupe),
  malgré la pause : c'est le point de vigilance le plus probable de casser
  en silence (elle partage la ligne avec le bandeau épinglé disparu).
- [ ] **Aucun bouton Épingler/Détacher** dans le menu contextuel d'un
  message, 1:1 comme groupe.
- [ ] **Aucune ligne « Épinglés »** sur la fiche groupe, même sur un groupe
  qui avait des épingles avant la pause.

---

## Réactions emoji : une par personne et par message (2026-08-13)

**Priorité P2** · importance 2/5 — Le compteur de réactions est faux, ou retirer sa réaction efface celle de quelqu'un d'autre. *Bloqué : deux comptes.*

- [ ] Deux comptes différents réagissant au même message avec le même emoji
  → le chip affiche bien un compteur à 2, et chacun ne peut retirer que sa
  propre réaction. **Pas vérifiable avec un seul appareil/compte** — nécessite
  un deuxième testeur ou compte connecté ailleurs.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Réactions emoji : une par personne et par message (2026-08-13) »).

---

## Accusés livré/lu séparés — sheet infos du message (2026-08-13)

**Priorité P1** · importance 3/5 — Un message apparaît « Lu » avant d'avoir été ouvert (dès la réception du push), ou ne passe jamais à « Lu » : l'expéditeur est trompé sur ce que l'autre a vu. *Bloqué : deux comptes.*

`mark_messages_as_delivered` marquait `readBy`/`readAt` en même temps que
`deliveredTo`/`deliveredAt`, y compris depuis les handlers de notification
push (app en arrière-plan ou fermée) : un message passait à « lu » avant même
que le destinataire ouvre la conversation. Séparé en deux RPC —
`mark_messages_as_delivered` (livré seul) et `mark_messages_as_read` (lu,
appelée uniquement à l'ouverture réelle de la conversation) — voir
[20260813120000_split_delivered_from_read.sql](supabase/migrations/20260813120000_split_delivered_from_read.sql)
et [message_supabase_datasource.dart:1548](lib/features/messages/data/datasources/message_supabase_datasource.dart:1548).

- [ ] Envoyer un message depuis le compte A à un compte B **avec le compte B
  hors ligne** (notification push reçue, app fermée) : vérifier dans le sheet
  infos du message (appui long → Infos) que l'onglet « Livré à » liste B mais
  que « Lu par » reste vide tant que B n'a pas ouvert la conversation.
- [ ] Ouvrir la conversation côté B : vérifier que B apparaît alors dans « Lu
  par », et que le coche du message (côté A) passe au double-coche bleu à ce
  moment-là, pas avant.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Accusés livré/lu séparés — sheet infos du message (2026-08-13) »).

---

## Messagerie — un filtre sans résultat n'est pas une messagerie vide (2026-08-06)

**Priorité P2** · importance 3/5 — Un groupe créé sans pays reste invisible dans Découvrir dès que le filtre pays automatique s'applique, donc personne ne le trouve pour le rejoindre ; et une puce vide fait croire à une messagerie vide.

`_buildConversationList` branchait sur `filtered.isEmpty`, c'est-à-dire la
liste **après** application de la puce de filtre, et rendait alors la fiche 9e :
« Aucune conversation », « Commencez à discuter avec les membres de la
diaspora », le bouton « Nouvelle conversation », la ligne sur le chiffrement.

- [ ] **Puce « Groupes » sur un compte sans groupe** : « Aucune conversation de
      groupe », même sortie.
- [ ] **Messagerie réellement vide** (compte neuf) : la fiche 9e s'affiche
      toujours, elle — c'est elle qu'on ne voulait pas perdre.
- [ ] **Thème sombre** sur les deux nouveaux états : l'icône est posée à
      `textTertiaryColor` à 50 %, le texte à `textSecondaryColor` — vérifier
      qu'ils restent lisibles.
      ⬜ moitié, Passe du 2026-09-22 (~05:35–05:45), build Play 1.2.2+26 (f22aaff, contient 37465e9), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : « Non lus », tout étant lu → icône double coche
      grise, « Aucun message non lu », « Afficher toutes les conversations » en
      orange : lisibles. L'état « Groupes » vide n'existe pas sur ce compte.

### Le `country_code` n'est plus un problème (vérifié en base le 2026-08-06)

**Arête tranchée le 2026-08-06 : un groupe sans pays vaut désormais `NE`.**

Reste à voir à l'écran — c'est tout ce que la base ne peut pas prouver :

- [ ] **Créer un groupe sans choisir de pays** : il doit apparaître dans
      « Découvrir » avec le filtre `NE`, et la fiche doit afficher « Niger ».
- [ ] **« Groupe de test prive » est de nouveau atteignable** : c'est un groupe
      **privé**, donc à chercher dans « Mes groupes » côté créateur, pas dans
      « Découvrir ».
- [ ] **Un groupe créé AVEC un pays** garde bien le sien à l'écran aussi.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Messagerie — un filtre sans résultat n'est pas une messagerie vide (2026-08-06) »).

---

## Discussion — l'horodatage sort de la bulle (fiches 4a/6b, 2026-08-05)

**Priorité P2** · importance 2/5 — L'heure devient illisible sur certains fonds de discussion, et le « Réessayer » d'un message en échec passe inaperçu.

L'heure et l'accusé de réception étaient rendus à **sept endroits** : en fin de
ligne dans le texte, incrustés sur l'image et la vidéo, dans la ligne du
document, sur la carte de position, sous le lecteur audio, sous le sticker — et
**nulle part** sur les notes vocales. Ils sont désormais posés une seule fois,
sous la bulle, par `_buildMetaRow` de `message_bubble.dart`.

Couvert statiquement par `test/features/messages/message_meta_row_test.dart`
(l'heure n'est plus un descendant de la bulle, elle est sous le texte, la
réaction partage sa ligne, la note vocale en a une). Ce que le test ne peut pas
voir :

- [ ] **Lisibilité de l'heure sur fond de conversation**, en clair et en
  nocturne. Elle était blanche sur l'aplat vert des messages envoyés ; elle est
  maintenant `textTertiaryColor` sur le fond de l'écran.
- [ ] ⚠ **Sur fond d'écran personnalisé** (`ChatWallpaper` + les 8 couleurs de
  `chat_background_colors.dart`) : c'est le cas le plus risqué, l'heure n'a plus
  d'aplat sombre derrière elle comme l'incrustation des médias en avait un.
- [ ] **Chaque famille de bulle** : texte, note vocale (elle en a une pour la
  première fois), photo, photo floutée en mode ÉCO, vidéo, document, sticker,
  position, message transféré, message cité.
- [ ] **Le tap sur l'accusé** ouvre toujours le détail par destinataire.
- [ ] **États transitoires** : « · Envoi… » pendant l'envoi, « · En attente »
  en orange quand le message est dans la file hors-ligne, et
  « · Non envoyé · Réessayer » en cas d'échec (seul état à garder une icône,
  parce qu'il appelle une action).
- [ ] **« Non envoyé · Réessayer »** : le libellé d'échec est passé sous la
  bulle avec le reste ; vérifier qu'il reste lisible et cliquable.
- [ ] **Le cadenas de chiffrement par message a disparu.** Il n'était posé que
  sur les messages « emoji seul » — une incohérence. Le rappel de chiffrement
  reste dans l'en-tête, à côté de « En ligne ». Confirmer que rien ne manque.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Discussion — l'horodatage sort de la bulle (fiches 4a/6b, 2026-08-05) »).

---

## Discussion — ÉCO rejoint la ligne épinglée (fiche 6b, 2026-08-05)

**Priorité P3** · importance 2/5 — Désagrément mineur : pastille ÉCO mal placée ou absente sur une conversation.

La sous-barre « Médias · ÉCO » sous le bandeau épinglé a disparu : la fiche 6b
pose la pastille ÉCO **à droite du bandeau**, sur la même ligne. Le raccourci
« Médias » n'est pas perdu, il est passé dans le menu ⋮ sous le libellé
« Médias partagés » (`sharedMedia`, clé déjà existante).

- [ ] **Sans épingle** : la ligne se réduit à la seule pastille ÉCO, alignée à
  droite — elle ne doit pas disparaître.
- [ ] **Avec le compteur `i/n`** (plusieurs épingles) : le compteur et la
  pastille cohabitent sans se marcher dessus, à font_scale 1.1.
- [ ] **« Mes notes » et demande de message en attente** : pas de pastille ÉCO
  (rien à réduire), et le bandeau seul doit rester correct.
- [ ] **La bascule fonctionne toujours** : appuyer sur ÉCO, revenir, vérifier
  que l'aperçu flouté des médias s'active bien.
- [ ] **« Médias partagés » dans le menu ⋮** ouvre bien la galerie de la
  conversation.
- [ ] ⚠ **Gain de hauteur** : ~40 dp libérés sous l'en-tête. La réserve de
  chrome de `computeMessagePickerHeight` n'a **pas** été rebaissée (le fichier
  était en cours de modification par ailleurs) — le panneau émoji a donc un peu
  moins de place qu'il ne pourrait. À reprendre si l'écran paraît serré.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Discussion — ÉCO rejoint la ligne épinglée (fiche 6b, 2026-08-05) »).

---

## Composeur — largeur de la pilule et « + » en clair (2026-08-05)

**Priorité P2** · importance 3/5 — « Mes notes » s'ouvre sur un document fantôme et chaque note échoue à l'envoi ; en paysage, le composeur passe sous le clavier.

- [ ] ⚠ **Débordement en paysage** trouvé le 2026-08-06 : conversation avec
  toute sa chrome (bandeau épinglé + bandeau de clés), clavier levé, appareil
  en paysage → « BOTTOM OVERFLOWED BY 17 PIXELS », et le composeur passe sous
  la ligne de flottaison. Le portrait est sain. Rien dans logcat, comme toujours
  (Crashlytics remplace `FlutterError.onError`) : seule la bannière rayée le
  prouve. Piste : la chrome fixe de la conversation n'est pas repliable, et en
  paysage il ne reste presque rien après le clavier.
- [ ] **Observation à part** : « Mes notes » affiche maintenant « Aucun
  message » et un bandeau **« Ce groupe a été supprimé »** à la place du
  composeur. Sans rapport avec les gestes vocaux (rien n'a été supprimé pendant
  la passe) — vraisemblablement le ménage des données de test. À vérifier : une
  auto-conversation ne devrait pas pouvoir tomber dans l'état « supprimé ».
- [ ] **font_scale 1.1 avec un texte réel** : les mesures ci-dessus sont à
  l'échelle 1.0 du banc. Vérifier qu'un vrai message long garde une largeur
  confortable sur l'appareil.

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Composeur — largeur de la pilule et « + » en clair (2026-08-05) »).

---

## Panneau stickers / GIF / émojis (fiche 26b, 2026-08-05)

**Priorité P2** · importance 2/5 — Le panneau émojis défile mal ou cache son pied sous la barre de navigation, et affiche « No Recents » en anglais.

Refonte complète : onglets en **pilules Stickers · GIF · Émojis** (l'ordre est
inversé par rapport à avant) suivis d'une loupe, **sections à en-tête**
(RÉCEMMENT UTILISÉS · FAVORIS · un par pack) au lieu des sous-onglets iconiques
horloge/cœur/vignette, grille à tuiles carrées à fond visible, et la note
« téléchargés une fois » descendue **en pied**.

Couvert statiquement par `emoji_sticker_picker_layout_test.dart` (ordre des
pilules, sections, 4 colonnes à 390 dp, pied présent/absent, filtre, nocturne)
et `emoji_sticker_picker_landscape_test.dart` (pas d'overflow à 160/200/260).
Ce que les tests ne voient pas :

- [ ] **Défilement continu** sections + grille, clavier réellement ouvert, sur
  le A51 — c'est un seul `CustomScrollView` désormais.
- [ ] **Padding bas de la ligne d'info** face à la barre de navigation
  gestuelle (la fiche prévoit 26 px pour l'indicateur iOS, on en met 8).
- [ ] **La loupe sur l'onglet Émojis** ouvre la vue de recherche interne du
  paquet `emoji_picker_flutter` (elle est plein cadre, avec son propre retour).
- [ ] **La loupe sur Stickers** filtre sur place. ⚠ Elle cherche dans
  `sticker.emoji` et le nom du pack ; si `emoji` est vide en base pour la
  plupart des stickers, seul le nom du pack remontera. À confirmer sur les
  vraies données.
- [ ] **Grille en paysage** : 4 colonnes à 390 dp, davantage au-delà (sinon les
  tuiles feraient 180 dp). Non vu : aucun pack en base, l'onglet Stickers ne
  s'affiche pas.
- [ ] **Chrome resserré sous 190 dp** : en paysage la ligne d'info disparaît et
  la barre d'onglets se tasse. Vérifier que ça reste lisible.
- [ ] **Nocturne** : pilule sélectionnée sur `textPrimary`, contours sur
  `borderStrong`, en-têtes de section sur le repère `#F4A574`.
- [ ] **Les favoris n'ont plus d'onglet cœur** : ils sont une section, affichée
  seulement si non vide. L'appui long sur un sticker propose toujours
  « Ajouter aux favoris ».
- [ ] ⚠ **« No Recents » est en anglais** dans l'onglet Émojis : c'est la
  chaîne interne de `emoji_picker_flutter`, pas une des nôtres. Elle n'est
  pas localisée par le paquet — à traiter à part (option de config, ou vue
  personnalisée), ce n'est pas un oubli de nos ARB.
- [ ] **L'onglet Stickers reste absent sans pack Supabase** (les packs sont
  vides en base) : dans ce cas le panneau s'ouvre sur GIF ou Émojis.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Panneau stickers / GIF / émojis (fiche 26b, 2026-08-05) »).

---

## Messages épinglés — le bandeau n'était pas temps réel (2026-08-05)

**Priorité P3** · importance 1/5 — Aucun tant que la fonction est désactivée ; à la réactivation, épingles de groupe invisibles pour les autres membres ou dans le désordre. *Bloqué : fonction en pause.*

Restent à voir (demandent un second appareil, ou un build à jour installé) :

- [ ] **Suppression pour tous d'un message épinglé** par B : l'épingle tombe en
  cascade, le bandeau de A doit se vider tout seul.
- [ ] **Contournement posé le 2026-08-05** : les épingles passent désormais
  **toutes** par `conversation_id`, groupe compris (`_pinMessage`,
  `_unpinMessage`, le bandeau et `pinnedMessageIds`). La colonne
  `conversation_id` pointe sur une table réellement peuplée dans les deux cas,
  donc l'épinglage de groupe doit marcher sans migrer les groupes.
  ⚠ **Ce que ça change côté droits** : les policies RLS appliquées sont
  « Conversation participants… », qui n'exigent que d'être dans
  `participant_ids`. La permission de groupe « qui peut épingler »
  (`who_can_pin`, rôles owner/admin/moderator) **n'est plus vérifiée par la
  base** — seul le filtre `canPin` de l'écran subsiste. À reprendre quand les
  groupes vivront dans Supabase.
  - [ ] Épingler dans un groupe : ne doit plus dire « Impossible d'épingler ».
  - [ ] Le bandeau doit apparaître dans le groupe, et le menu basculer sur
    « Détacher ».
  - [ ] **Non-régression 1-à-1** : rien ne doit changer, c'est le chemin qui
    servait déjà.
  - [ ] **Visibilité entre membres** : un second membre du groupe doit voir
    l'épingle — ça dépend de `conversations.participant_ids`, qui doit donc
    contenir tous les membres du groupe (à vérifier, ce n'est pas garanti).
- [ ] ⚠ **Contenu déchiffré dans le bandeau** : toujours pas vu. Les clés E2EE
  sont perdues sur ce build (bandeau « Restaurez vos clés » présent, bulles
  « 🔐 Message chiffré ») et les 3 épingles de test pointent toutes sur du
  texte chiffré (`gcm:` ou `iv:ciphertext`, vérifié en base). Ce point ne
  pourra se solder qu'après restauration des clés.

Et sur un seul appareil, après le correctif de `group_pinned_banner.dart` (la
pastille était perdue avec la ligne quand l'épingle n'était pas résoluble).

- [ ] **Une seule épingle orpheline** (message supprimé avant la cascade) : le
  bandeau ne s'affiche pas, mais la **pastille ÉCO doit rester** à droite.
- [ ] **Épingle de sondage / d'événement pendant le chargement** : la pastille
  ne doit pas clignoter hors de l'écran le temps du fetch.

- [ ] **Épingler un message en cours d'envoi** (couper le réseau, envoyer, puis
  appui long → Épingler) : doit afficher « Attendez l'envoi du message pour
  l'épingler » et ne rien écrire en base. Vérifier ensuite qu'une fois le
  message parti, l'épinglage fonctionne normalement.

### Second système mort trouvé le 2026-08-14 : la ligne « Épinglés » de la fiche groupe

Corrigé : `_GroupInfoCard` lit maintenant `conversationPinnedItemsProvider`
via l'id de conversation du groupe (déjà résolu pour la ligne Médias juste en
dessous). `groupPinnedItemsProvider` et la branche `groupId` de
`GroupPinnedBanner` sont supprimés (plus aucun appelant ne les utilisait).

- [ ] Groupe sans rien d'épinglé : la ligne doit rester absente (comme avant)
  — pas revérifié isolément mais découle du même code que la ligne Médias.

### Troisième bug trouvé le 2026-08-14 : aucun ordre stable entre plusieurs épingles

- [ ] Épingler 2-3 messages dans une même conversation, rouvrir l'écran
  plusieurs fois (ou faire apparaître/disparaître le clavier plusieurs fois) :
  l'ordre `1/n`, `2/n`… doit rester identique à chaque fois (le plus ancien
  épinglé en premier). « Groupe de test privé » porte déjà 1 épingle
  (message « Message de test pour verifier 9c et 9d ») posée pendant cette
  passe — il suffit d'en épingler un second pour tester.

- ✔ 8 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Messages épinglés — le bandeau n'était pas temps réel (2026-08-05) »).

---

## Recherche messagerie — le clavier demandait deux taps (§9b, 2026-08-04)

**Priorité P2** · importance 3/5 — Il faut deux taps pour taper une recherche : le champ semble ne pas répondre.

- [ ] Refaire la passe en **clair et en nocturne** : le correctif touche
      `design_kit.dart`, donc tous les autres `DesignSearchField` du projet
      (boutique, groupes, carte) — vérifier qu'aucun n'a gagné d'ombre parasite.
      ⬜ moitié, Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff) : champ de la messagerie vu en clair (A515F) et en sombre
      (Pixel, bordure orange sur fond sombre, lisible ; à 1,3 la 3ᵉ puce
      « Conversations » est coupée, la rangée défile). Les autres
      `DesignSearchField` (boutique, groupes, carte) pas regardés.
- [ ] Boîte de réception **vide** : le champ n'est pas affiché dans cet état, la
      recherche n'y est donc pas ouvrable — confirmer que c'est bien voulu.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Recherche messagerie — le clavier demandait deux taps (§9b, 2026-08-04) »).

---

## Brouillon restauré — le composer restait sur le micro (2026-08-04)

**Priorité P3** · importance 3/5 — Le brouillon restauré semble non envoyable (micro affiché) : l'utilisateur le retape ou l'abandonne.

- [ ] **Le cas décisif** : taper sans envoyer, **bouton accueil**, relancer
      l'app, rouvrir la conversation → le bouton d'envoi bleu doit être là
      **d'emblée**, sans toucher au champ.
- [ ] Envoyer directement ce brouillon restauré, sans toucher le champ au
      préalable : l'envoi doit aboutir.
- [ ] Le bouton doit être **présent immédiatement**, pas apparaître en fondu :
      le morphing est volontairement court-circuité à la restauration.
- [ ] Non-régression : une conversation **sans** brouillon doit toujours
      afficher le micro.
- [ ] ⚠ **Ne pas réinstaller entre les deux étapes** : `adb install -r` vide les
      données, donc les `SharedPreferences` — le brouillon disparaît et le test
      ne prouve rien. Relancer l'app déjà installée (`am start` / icône).

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Brouillon restauré — le composer restait sur le micro (2026-08-04) »).

---

## Zone de saisie des messages — barre multi-ligne (2026-08-04)

**Priorité P2** · importance 3/5 — La fin d'un brouillon est perdue quand on quitte vite la discussion.

`lib/features/messages/presentation/widgets/message_input.dart`. Le champ
passait de `maxLines: 1` à `minLines: 1 / maxLines: 6`, plus trois correctifs
d'état et un alignement de couleurs. Le composer sert les **trois** cas depuis
le même écran (1-à-1, groupe, « Mes notes ») : tester au moins deux d'entre eux.
`flutter analyze` et les 7 tests de `message_input_composer_test.dart` passent.

- [ ] **Brouillon tapé puis sortie immédiate** : taper quelques caractères et
  quitter l'écran **en moins d'une demi-seconde**. Au retour, le texte complet
- [ ] ⚠ **Non-régression prioritaire — gestes vocaux.** Le bouton d'action doit
  rester dans l'arbre en permanence pour que le push-to-talk fonctionne :
  appui long → enregistrement, glisser à gauche → annulation, glisser vers le
  haut → verrouillage. Rien dans ce lot ne le démonte, mais c'est le premier
  point à retester.
- [ ] **Sheet de repli (appui long sur « + »)** : la section « Caméra » en
  doublon a été supprimée (Photo/Vidéo dédiées, redondantes avec la tuile
  Caméra unifiée). Vérifier qu'il ne manque rien d'utile, et que les tuiles
  suivent maintenant le code couleur du panneau ancré — médias en accent
  primaire, Position/Sondage/Événement en secondaire (fini le violet, l'orange
  et le bleu Material bruts).
- [ ] **Bandeau d'enregistrement en nocturne** : le rouge d'annulation passe par
  `errorColor` au lieu de `Colors.red`. Armer l'annulation (glisser à gauche
  sans relâcher) en mode nuit et vérifier que le bandeau reste lisible.

- ✔ 10 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Zone de saisie des messages — barre multi-ligne (2026-08-04) »).

---

# 3. Groupes

Création, invitations, adhésion, membres, modération, sondages et mentions de groupe.

---

## ⬜ Gérer les membres d'un groupe : notices dans le fil, et deux listes d'admins réconciliées (2026-09-17)

**Priorité P1** · importance 4/5 — trois gestes de la fiche des membres passent
au serveur. Deux d'entre eux ne faisaient rien de visible.

✅ **Migration appliquée en production** (constaté le 2026-09-17 dans
`schema_migrations`, avec `20260917010000` ; code des fonctions en base
identique au fichier, banc rejoué 32/32)
([20260917013200_notices_de_groupe_ecrites_par_le_serveur.sql](supabase/migrations/20260917013200_notices_de_groupe_ecrites_par_le_serveur.sql)).
Le repli `PGRST202` du client ne sert donc plus qu'à une base en retard.

**Ce qui manquait.** 7b3794f a débloqué l'exclusion en retirant l'INSERT système
qui l'empêchait ; il n'a rien mis à la place, donc plus **aucune** notice dans le
fil. Le client ne peut pas en écrire : `messages_insert` exige `firebase_uid() =
sender_id`, et une conversation basculée refuse même avant (23514). Trois RPC
`SECURITY DEFINER` les écrivent maintenant — `exclure_du_groupe`,
`nommer_admin_du_groupe`, `retirer_admin_du_groupe`.

**Deux défauts trouvés en passant, et corrigés dans la même migration :**

1. **Promouvoir et rétrograder ne changeaient rien de visible.** Le client
   n'écrivait que `conversations.data.adminIds`, alors que le badge « admin » de
   la fiche **et** `is_group_admin()` — donc les droits réels — lisent
   `group_members.role`. Mesuré le 2026-09-17 : **3 groupes sur 7** ont les deux
   listes désaccordées — dans le groupe officiel `b21e8f5a…`, `I54Ixk7…` est
   admin dans `adminIds` et simple `member` dans `group_members`. Un promu
   n'avait ni badge ni menu de gestion ; un rétrogradé gardait tous ses droits.
   Les RPC écrivent les deux, et rattrapent la divergence existante au premier
   passage. Depuis
   `20260917010000_group_members_role_sans_auto_promotion.sql`, elles en sont
   même le seul chemin possible : le client ne peut plus écrire `role` du tout.
2. **Exclure quelqu'un absent de `participant_ids` réussissait à vide** :
   l'écran annonçait « Membre retiré » et la personne restait dans
   `group_members`. La RPC supprime la ligne dans tous les cas.

⚠️ **Trouvé en préparant la passe (2026-09-17) : les trois actions n'étaient
accessibles à personne.** « Promouvoir Admin », « Retirer Admin » et « Retirer
du groupe » exigent la conversation du groupe, et la route
`/groups/:groupId/members` ne l'a jamais transmise à
[group_members_screen.dart](lib/features/groups/presentation/screens/group_members_screen.dart) :
le menu d'un admin ne proposait que le rôle modérateur, depuis décembre 2025.
L'AAB compilé pour la passe le prouvait — aucun nom des trois RPC dans
`libapp.so`, le compilateur avait retiré les appels. L'écran retrouve
maintenant la conversation lui-même (`groupConversationIdProvider`), pour un
admin seulement. Test : `test/features/groups/membres_actions_admin_test.dart`.

**La notice n'existe que hors MLS.** En clair dans une conversation chiffrée,
elle dirait au serveur ce que le chiffrement lui tait. Relevé le 2026-09-17 :
**6 groupes en clair, 1 basculé** — la notice s'y verra donc, et de moins en
moins au fil des bascules. Dans le groupe basculé, l'action a lieu sans notice.

**La phrase n'est pas écrite par le serveur**, seulement les identités
(`data.evenement`). La bulle la compose avec `AppLocalizations` : sinon un
compte en anglais lirait du français, la faute que le repère de bascule MLS a
déjà coûtée. Trois voix par action — « Vous avez retiré X », « X vous a confié
le rôle d'admin », « X a nommé Y admin » — parce que « Vous a retiré X » n'est
pas du français. Et pas « X vous a nommé admin » : « vous » avant le verbe
impose l'accord, « nommée » pour une lectrice.

Vérifié avant livraison : la notice ne remonte pas la discussion dans la liste,
ne compte pour personne comme non lu, ne fait pas avancer le curseur de lecture,
ne déclenche aucune notification push, et l'exclu ne peut pas la lire.

Bancs : [tools/rls_tests/notices_de_groupe.sql](tools/rls_tests/notices_de_groupe.sql)
(32 cas, transaction annulée sur la vraie base),
`test/features/messages/retrait_membre_groupe_test.dart` (12 cas) et
`test/features/messages/notices_de_groupe_test.dart` (13 cas).

Pas bloqué, mais **demande deux comptes** : les notices ne se lisent qu'à
plusieurs.

- [ ] **Le menu existe** : Membres → appui long sur un simple membre, en
      admin → « Promouvoir modérateur », « Promouvoir Admin » et « Retirer du
      groupe » (les deux derniers n'étaient jamais apparus). Sur un admin non
      créateur : « Retirer Admin ».
- [ ] **Groupe en clair, exclusion** : l'admin retire un membre → une ligne
      grise centrée apparaît dans le fil, « *Vous avez retiré Hocine du
      groupe* ». Sur le téléphone d'un autre membre, la même ligne dit « *Nasara
      a retiré Hocine du groupe* ».
- [ ] **La notice ne remonte pas la discussion** : dans la liste des messages,
      le groupe garde sa place et son aperçu — l'heure et le dernier message
      affichés ne changent pas, et **aucune pastille de non-lu** n'apparaît chez
      les autres membres.
- [ ] **Aucune notification** : le téléphone des autres membres ne sonne pas et
      n'affiche rien dans le volet.
- [ ] **Côté exclu** : il ne voit pas la notice de son exclusion — le groupe
      disparaît de ses onglets.
- [ ] **Promouvoir** : appui long sur un membre → « Promouvoir Admin ». La notice
      dit « *Vous avez nommé Tchandikou admin* », et sur le téléphone du promu
      « *Nasara vous a confié le rôle d'admin* ». **Le badge « Admin » apparaît sur sa
      ligne** dans Membres (c'est ce qui ne marchait pas), et lui voit
      maintenant le menu de gestion des autres membres.
- [ ] **Rétrograder** : « Retirer Admin ». Notice symétrique, le badge
      part, et le rétrogradé perd l'accès au menu de gestion.
- [ ] **Rattrapage de la divergence** : sur un membre dont le badge manquait
      alors qu'il gérait déjà le groupe, « Promouvoir Admin » fait apparaître le
      badge.
- [ ] **En anglais** (Réglages → langue anglaise) : « *You removed Hocine from
      the group* », « *Nasara made you an admin* » — aucun mot français dans la
      notice.
- [ ] **Relue hors ligne** : après une exclusion, fermer l'app, couper le
      réseau, rouvrir le groupe. La notice dit toujours « *Vous avez retiré
      Hocine du groupe* » (et en anglais sur un compte anglais), pas « *Nasara
      a retiré Hocine du groupe* ». Le fil s'affiche d'abord depuis le cache
      local, qui perdait `evenement` avant le correctif.
- [ ] **Groupe chiffré** : le retrait aboutit comme avant, et **aucune ligne
      n'apparaît dans le fil**. C'est voulu.
- [ ] **Deux appuis de suite** sur « Retirer du groupe » : pas de seconde
      notice, et pas de message d'erreur au second.
- [ ] **Un non-admin** : l'appui long sur un membre n'ouvre aucun menu.
- [ ] **Réseau coupé** au moment de confirmer : « Erreur lors du retrait », le
      membre est toujours là au retour du réseau, et aucune notice n'est
      apparue.

---

## ⬜ Un simple membre pouvait se nommer owner de son propre groupe (2026-09-17)

**Priorité P0** · importance 5/5 — auto-promotion mesurée en production : un
membre ordinaire prend l'admin de son groupe par un simple `UPDATE`, avec
tout ce qui suit (modifier le groupe, exclure/promouvoir dans la
conversation, accès admin aux demandes et invitations).

Mesuré le 2026-09-17 en production, dans une transaction annulée
(`supabase db query --linked -f`) : le membre `vQZE49dTdyRtLwSG6lMIbhAqoFG2`
du groupe `90a2baa1-3927-4b21-97ac-5907002ed75d` a exécuté

```sql
UPDATE group_members SET role = 'owner' WHERE group_id = … AND user_id = <lui>
```

→ 1 ligne modifiée, puis `is_group_admin(groupe) = true` pour ce compte.
`group_members_own` (`FOR ALL USING firebase_uid() = user_id`) ne dit rien
de la colonne `role`, et `authenticated` a `UPDATE` sur toute la table. Le
même trou existait aussi à l'**INSERT** direct, dans un groupe **public**
(`group_members_insert_gate` ne dit rien du rôle non plus).

Effet de bord trouvé au passage, sans rapport avec l'attaque : l'upsert de
`joinGroup` / de l'acceptation d'invitation (`role='member'` sur conflit)
**rétrogradait silencieusement** un admin ou un owner qui « rejoint » à
nouveau son propre groupe (bouton dupliqué, retry réseau).

Corrigé par un déclencheur `BEFORE INSERT OR UPDATE` sur `group_members`
(`supabase/migrations/20260917010000_group_members_role_sans_auto_promotion.sql`) :
pour `authenticated`/`anon`, l'INSERT n'accepte que `role='member'`, et
l'UPDATE refuse tout changement de `role`, `group_id` ou `user_id`. Les
fonctions `SECURITY DEFINER` (création de groupe, groupes officiels,
approbation d'une demande, future RPC de promotion/rétrogradation) tournent
sous leur propriétaire, jamais `authenticated`/`anon` : elles ne voient pas
le garde. Banc SQL en `BEGIN/ROLLBACK` :
`tools/rls_tests/auto_promotion_group_members.sql`.

- [ ] **Rejoindre un groupe public** (`joinGroup`) : la ligne se pose bien en
      `role='member'`, aucune erreur visible dans l'app.
- [ ] **Accepter une invitation de groupe** : idem, `role='member'`, aucune
      régression sur le flux d'invitation.
- [ ] **Quitter un groupe** (`leaveGroup`) : le départ reste immédiat, aucune
      erreur — le déclencheur ne touche pas au `DELETE`.
- [ ] Non-régression : un administrateur ou owner qui rouvre l'écran du
      groupe et qui déclenche à nouveau `joinGroup` (double-tap, retry)
      garde son rôle — ne doit plus jamais retomber à « membre ». **Attention
      en vérifiant** : le déclencheur refuse maintenant cet upsert (42501),
      et `GroupNotifier.joinGroup` avale l'échec (`result.fold((failure) =>
      false, …)`, `group_provider.dart`) — **aucun snackbar n'apparaît, ni
      succès ni erreur**, le tap semble n'avoir rien fait. C'est attendu :
      avant ce correctif, le même tap affichait « Groupe rejoint » tout en
      rétrogradant silencieusement l'admin. Vérifier le rôle dans la fiche
      des membres, pas l'apparition d'un message.

---

## ⬜ Exclure un membre d'un groupe échouait toujours (2026-09-17)

**Priorité P1** · importance 4/5 — un administrateur ne pouvait exclure
personne, dans aucun groupe : « Erreur lors du retrait » à chaque essai, et le
membre restait.

`removeUserFromGroup`
([message_supabase_datasource.dart](lib/features/messages/data/datasources/message_supabase_datasource.dart))
écrivait d'abord un message système « Un utilisateur a été retiré du groupe »
(`sender_id = 'system'`) et ne retirait la personne qu'ensuite. La base refuse
cet INSERT **partout** : la policy `messages_insert` exige `firebase_uid() =
sender_id` (depuis `20260526270000`), et une conversation basculée en MLS le
refuse même avant la policy, par déclencheur (23514). L'exception sautait la
mise à jour de `participant_ids`.

Mesuré en production le 2026-09-17, transaction annulée
([tools/rls_tests/retrait_membre_groupe.sql](tools/rls_tests/retrait_membre_groupe.sql),
9 cas) : 23514 sur le groupe chiffré `d41d4ea0…`, et **pas une ligne
système** dans toute la table `messages` — aucune exclusion n'a jamais abouti
par l'app. Les bancs précédents (voir « Inviter des membres dans un groupe
privé ») rejouaient la mise à jour SQL, jamais le chemin de l'app : ils ne
pouvaient pas le voir.

Corrigé : plus de message système (le client ne peut pas l'écrire ; une notice
devra venir du serveur, et hors MLS seulement), et le retrait lève au lieu de
réussir à vide — conversation illisible, ou mise à jour qui ne touche aucune
ligne. `test/features/messages/retrait_membre_groupe_test.dart` : 4 cas, les
4 tombent sur l'ancien code.

➡️ **Suite** : la notice serveur promise ici existe, voir « Gérer les membres
d'un groupe » juste au-dessus. Ce fichier de test y a grossi à 12 cas, et
couvre maintenant l'appel RPC ; le chemin décrit ci-dessous n'est plus qu'un
repli tant que la migration n'est pas appliquée.

⚠️ **Rien de visible ne disparaît** : le message « Un utilisateur a été retiré
du groupe » n'a jamais existé dans aucun fil.

Pas bloqué : les deux téléphones portent un build debug, mais il faut un build
qui contient le correctif.

- [ ] **Groupe en clair** : l'administrateur ouvre Membres, appui long sur un
      membre → « Retirer du groupe » → confirmer. « Membre retiré », la ligne
      disparaît et `Membres · n` décroît, sans refermer l'écran.
- [ ] **Groupe chiffré** : même geste, même résultat — pas d'erreur, pas de
      bannière « mettez l'application à jour ». Réinviter ensuite la personne
      si le groupe sert encore.
- [ ] **Groupe chiffré, juste après** : l'administrateur envoie un message.
      Il part (la sortie de l'arbre MLS ne bloque pas l'envoi), et le
      téléphone de l'exclu ne le reçoit pas.
- [ ] **Côté exclu** : le groupe quitte les onglets Groupes et Messages sans
      redémarrage (voir « Acceptation et départ d'un groupe : rien ne bougeait
      chez les autres »), et rouvrir la discussion ne l'y remet pas.
- [ ] **Réseau coupé** au moment de confirmer : « Erreur lors du retrait », et
      au retour du réseau le membre est toujours là.

---

## ⬜ Groupes : non-lus depuis l'arrivée, messages système, « Lu » par tous (2026-09-17)

**Priorité P2** · importance 3/5 — quatre règles de lecture propres aux
groupes (étape C du plan du séparateur).
*Bloqué : « Lu par tous » demande un groupe à trois comptes sur trois appareils — il n'y en a
que deux aujourd'hui.*

3. **« Lu » attend tous les membres présents**, arrivés avant le message
   ([accuse_de_groupe.dart](lib/features/messages/presentation/utils/accuse_de_groupe.dart)).
   ⚠️ **Changement visible** : « Vu par N » disparaît de la bulle ; un lecteur
   sur deux affiche « Reçu ». Le détail par membre reste à un tap. Dans la liste,
   la tuile d'un groupe passait au vert dès que le premier autre membre venu
   avait lu.

- [ ] **Nouveau membre** dans un groupe avec de l'historique non lu : à
      l'ouverture, aucun séparateur sur les messages d'avant son arrivée ; la
      pastille de la liste ne les compte pas.
- [ ] **Retirer un membre** d'un groupe **en clair** : la pastille des autres
      membres, et celle de l'administrateur, n'augmente pas.
- [ ] **Groupe à trois** : A écrit ; B lit → chez A, « Reçu », pas « Lu » ;
      C lit → « Lu ». La tuile de la liste suit la même règle.
- [ ] **Membre parti** : A écrit, B lit puis quitte le groupe, C lit → « Lu ».
- [ ] **Groupe chiffré**, membre arrivé après la bascule : la pastille ne
      compte pas l'historique chiffré qu'il ne peut pas lire.

---

## ⬜ Groupe privé : un nouveau membre ne voit plus ce qui précède son arrivée (2026-09-16)

**Priorité P2** · importance 3/5 — une règle écrite de longue date qui ne
s'appliquait **jamais**, et qui retire désormais des messages à l'écran d'un
vrai membre.

`_setupPrivateGroupFilter` (`conversation_screen.dart`) filtrait sur
`GroupEntity.memberJoinedAt`, toujours vide depuis le passage à Supabase : la
date vit dans `group_members.joined_at`, et ni la requête d'appartenance, ni
`GroupModel`, ni `toEntity` ne la portaient. Rebranchée dans
[group_supabase_datasource.dart](lib/features/groups/data/datasources/group_supabase_datasource.dart)
et [group_model.dart](lib/features/groups/data/models/group_model.dart).

⚠️ **Ce que ça n'est pas** : une protection. Le filtre est côté client ; les
messages restent lisibles par PostgREST pour tout participant. Et la date n'est
connue qu'après la relecture du groupe : **une fraction de seconde** à
l'ouverture, le cache peut encore les montrer. Les non-lus (§ C du plan) les
comptent encore.

- [ ] **Compte arrivé le 11/09 dans `2b24986f…`** : ouvrir la discussion → les
      6 messages d'avant n'apparaissent pas, pas même brièvement au-delà de
      l'ouverture ; les messages suivants sont bien là.
- [ ] **Rouvrir** la même discussion (cache chaud) : pas de va-et-vient des
      anciens messages.
- [ ] **L'administrateur** du même groupe (arrivé le 06/08) voit toujours tout.
- [ ] **Groupe public** : aucun changement, rien n'est filtré.
- [ ] **Hors ligne**, discussion déjà ouverte une fois : décrire ce qui
      s'affiche (le groupe ne se relit pas hors ligne — le filtre ne s'applique
      probablement pas).

---

## ⬜ Réorganisation des tuiles de « Mes groupes » + vue grille (2026-09-15)

**Priorité P2** · importance 2/5 — Changement de disposition sans logique de tri/filtre touchée, jamais vu sur un écran.

`_GroupCard` a un en-tête aligné en haut (avatar, nom et bouton sur la même
ligne de départ, au lieu d'être centrés sur toute la hauteur — variable selon
le nombre de pastilles — de la carte) ; la description et les pastilles ne
sont plus indentées sous le nom, elles occupent toute la largeur de la carte,
à la même marge que l'avatar. Une bascule liste/grille est apparue à côté des
onglets « Mes groupes »/« Découvrir » (affichée seulement sur « Mes
groupes ») ; la grille rend une nouvelle vignette `_GroupCardGrid` sur deux
colonnes de largeur égale via `Wrap` + `LayoutBuilder` (pas `GridView.count` —
un ratio largeur/hauteur fixe aurait débordé sur les noms de groupe qui
tiennent sur deux lignes).

- [ ] **Sur appareil** : les pastilles (Officiel, Actif/Calme, ville,
      membres, catégorie) restent lisibles et ne débordent pas de la carte
      sur un écran étroit (360 dp), en clair comme en sombre.
- [ ] **Sur appareil** : la bascule grille affiche des vignettes à deux
      colonnes de largeur égale, sans texte tronqué sur les noms longs
      (« Diaspora Niger — Niamey »).
- [ ] **Sur appareil** : le bouton « Ouvrir »/« Rejoindre » reste au bon
      endroit (ligne d'en-tête en liste, bas de vignette en grille) et
      déclenche la bonne action selon `isJoined`.

## ⬜ Noms des candidats à l'invitation et à l'ajout en appel (2026-09-14)

**Priorité P1** · importance 4/5 — La feuille « Inviter un membre » ne montrait que des « Utilisateur » à avatar gris : on ne pouvait pas savoir qui on invitait. Corrigé, jamais vu sur un écran.

Le nom vient maintenant de `getProfilesByIds`, **une seule requête** pour toute
la liste. Pas un `userStreamProvider` par ligne : sa `family` n'est pas
`autoDispose`, vingt lignes laisseraient vingt abonnements temps réel ouverts
pour le reste de la session.

- [ ] **Sur appareil** : une invitation envoyée depuis cette liste arrive bien
      chez l'invité et porte **son** nom, pas « Utilisateur » — `inviteeName`
      part en base. Voir « Inviter des membres dans un groupe privé » pour le
      reste du parcours.
- [ ] **Sur appareil, en mode avion** : rouvrir la feuille. La liste doit
      **rester affichée**, sans noms (les amis gardent le leur), au lieu de
      basculer sur « Erreur de chargement ». C'est le repli explicite du
      provider ; sans lui, la panne réseau serait pire que le défaut corrigé.
- [ ] **Sur appareil** : même vérification côté appels — pendant un appel,
      « Ajouter un participant » lit le même provider et souffrait du même
      défaut.
- [ ] **Sur appareil, clavier levé — CONSTATÉ le 2026-09-14, 21:23, reste à
      arbitrer** : clavier ouvert (`mInputShown=true`), la liste ne montre plus
      qu'**une seule ligne** et l'amorce de la suivante. Chercher quelqu'un
      oblige donc à taper à l'aveugle. La hauteur de la feuille vaut
      `0,8 × écran − insets` : c'est le `− insets` qui mange la liste alors que
      le clavier la recouvre déjà. Gênant sans être cassé — à Salim de dire si
      ça vaut un correctif.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Noms des candidats à l'invitation et à l'ajout en appel (2026-09-14) »).

---

## ⬜ Groupes officiels de ville (2026-09-14)

**Priorité P1** · importance 5/5 — Quatre invitations sont parties à de vraies personnes le 2026-09-14 : si l'appui n'ouvre rien, ou si quelqu'un se retrouve membre sans l'avoir demandé, c'est déjà arrivé à quelqu'un. (P1 et non P0 : rien n'est *su* cassé — les cinq `switch` sont exhaustifs et le décodage du type est au banc. Ce qui manque, c'est la vérification sur un écran.)

« Diaspora Niger — Montréal ». Trois profils visibles dans une ville
l'ouvrent ; chacun reçoit une notification `cityGroupInvite` et **rien n'est
ajouté d'office**. Laval et Longueuil mènent au groupe de Montréal
(`pole_id`). Un profil invisible n'est ni compté ni invité.

- [ ] **En base, après quelques jours** : le balayage quotidien de 9 h 30
  repasse sur Niamey sans redoubler ni le groupe ni les invitations
  (`SELECT count(*) FROM notifications WHERE type = 'cityGroupInvite'` doit
  rester à 4 tant qu'aucun cinquième profil n'arrive).
- [ ] **Sur appareil, profil invisible** : se mettre invisible, provoquer
  l'ouverture d'un groupe pour sa ville, et vérifier qu'**aucune**
  notification n'arrive.
- [ ] **Sur appareil, réseau lent** : pendant le chargement, l'onglet
  Découvrir montre les groupes, pas une liste vide. Le filtre de ville ne
  filtre rien tant qu'il ne sait pas où sont les groupes (vérifié au banc,
  mais c'est le timing réel qui compte).

**Entrée donnée le 2026-09-14** : une troisième action carrée dans l'en-tête
de l'écran Groupes, entre la recherche et « Créer ». Un **globe**
(`Icons.public`) et pas une carte pliée : celle-ci est déjà l'onglet
« Carte » de la barre du bas, qui mène à la carte des MEMBRES — deux cartes
différentes sous un seul pictogramme, à deux centimètres l'une de l'autre. Le titre de l'écran
passe de « Groupes par pays » à « Groupes sur la carte » — il portait
« par pays », ce n'est plus vrai depuis qu'il y a des épingles de ville.

- [ ] **Sur appareil** : l'icône **globe** se distingue bien de l'onglet
  « Carte » du bas, et son appui ouvre la carte des groupes. L'appui depuis
  l'en-tête n'a PAS été confirmé : les taps automatisés tombaient sur les
  éléments voisins (deux conversations ouvertes par erreur), et j'ai préféré
  m'arrêter. L'arbre d'accessibilité donne bien
  `content-desc="Groupes sur la carte"`, cliquable, aux bonnes bornes.
- [ ] **Sur appareil, échelle de police augmentée** : les trois actions
  tiennent toujours. Le banc couvre 1,0 / 1,1 / 1,3, mais c'est là que l'œil
  ne se remplace pas.

Pas encore vu : la mention GeoNames dans « À propos », la carte, le thème
sombre. La feuille de divulgation du champ ville n'a pas pu être rejouée —
`USER_FIXED` est posé sur les deux permissions et adb ne le retire pas.

- ✔ 10 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Groupes officiels de ville (2026-09-14) »).

---

## ⬜ Quitter l'ancien groupe officiel : proposé après 6 mois, jamais imposé (2026-09-13)

**Priorité P2** · importance 3/5 — Quelqu'un qui a déménagé est sorti d'un groupe sans l'avoir choisi, ne parvient pas à en sortir, ou la notification n'ouvre pas l'écran du choix. *Bloqué : aucune proposition réelle avant le 2027-03-11 — à provoquer en base (recette ci-dessous).*

Consigne de Salim : quitter l'ancien groupe officiel « après 6 mois, avec
avertissement et consentement ». Migration
`20260913050000_depart_groupe_officiel_avec_consentement.sql`, **appliquée en
production** : changer de pays ne retire rien et note le départ ; la tâche
`pg_cron` `proposer-departs-groupes-officiels` (9 h UTC) passe, six mois plus
tard, la ligne à `a_confirmer` et envoie la notification `officialGroupLeave`.
Seule la carte de la fiche du groupe (`official_group_departure_card.dart`)
peut faire sortir, via `repondre_depart_groupe_officiel`. Sans réponse, on
reste. Revenir dans ce pays annule la proposition.

Seule proposition en attente aujourd'hui : `0D3P…`, groupe Cap-Vert, le
2027-03-11. **Recette pour la provoquer sur le compte de test** (envoie une
vraie notification) :

```sql
UPDATE departs_groupe_officiel SET proposer_apres = now()
 WHERE user_id = '<uid du compte>' AND statut = 'en_attente';
SELECT proposer_departs_groupes_officiels();
```

(Il faut d'abord que le compte ait changé de pays en étant membre du groupe
officiel de l'ancien.)

État de départ de Sim A (`vQZE49dTdyRtLwSG6lMIbhAqoFG2`), à restaurer à la fin :
pays **vide**, membre de « Diaspora Niger — Canada » (member), « Testeurs »
(member), « Groupe de test prive » (admin). Notifications autorisées.

1. Profil → Modifier : pays **Canada**, enregistrer (pays vide → Canada : aucun
   départ noté, c'est attendu). Puis pays **Niger**, enregistrer : un départ
   Canada `en_attente` doit apparaître en base, Sim A reste membre de Canada
   et rejoint « — Niger ». Ne pas choisir un pays sans groupe officiel : la
   sauvegarde en créerait un en production.
2. Appliquer la recette SQL ci-dessus avec l'uid de Sim A → push attendu.
3. Cases 1 à 3 ci-dessous (dont « Rester membre »).
4. Pour « Quitter » : nouvelle proposition par Niger → Canada → Niger, recette
   SQL, puis case 4.
5. Remise en état : rejoindre « — Canada » depuis Découvrir, quitter « — Niger »
   par son menu. ⚠️ L'écran de profil n'a **pas d'option « aucun pays »** :
   revenir au pays vide exige un `UPDATE users SET country_code = NULL` en
   base (le classificateur a déjà refusé ce genre d'écriture sur une ligne de
   compte, cf mémoire appareil) — sinon laisser Sim A en Niger et le dire.

- [ ] Le push « Rester dans « Diaspora Niger — … » ? » arrive ; l'appui ouvre
      la fiche du groupe, carte « Vous avez changé de pays » visible, date et
      pays justes.
- [ ] Même chose depuis la liste des notifications (icône groupe).
- [ ] « Rester membre » : message, la carte disparaît, toujours membre, et
      elle ne revient pas au lancement suivant.
- [ ] « Quitter le groupe » : la confirmation s'ouvre ; « Annuler » ne change
      rien ; « Quitter » fait sortir, ferme la fiche, le groupe quitte « Mes
      groupes » et sa discussion n'est plus accessible.
- [ ] Carte lisible en thème sombre, et boutons sans débordement avec
      l'échelle de police maximale.

---

## ⬜ Pays en toutes lettres : groupes officiels et filtre par pays (2026-09-13)

**Priorité P1** · importance 3/5 — Le groupe officiel d'un pays s'appelait « Diaspora Niger — NE », un même pays pouvait en avoir deux (`AO` et « Angola »), et la carte des groupes restait vide.

Plus aucun code ISO en base (décision de Salim) : `users`, `groups` et `posts`
portent le nom accentué du pays (« Algérie », « États-Unis »). Migration
`20260913030000_pays_en_toutes_lettres.sql`, **appliquée en production** et
relue après coup : 5 groupes officiels renommés (dont « — Niger » et
« — Algérie »), compteurs de membres justes partout.

- [ ] Profil → changer de pays pour un pays hors des 28 anciens (Angola) :
      le sélecteur le garde, et « Diaspora Niger — Angola » apparaît dans
      « Mes groupes », sans second groupe du même pays.
- [ ] Rouvrir « Modifier le profil » : le pays est pré-sélectionné, accents
      compris (« Algérie », « Côte d'Ivoire »).
- [ ] Groupes → Découvrir : puces « 🇳🇪 Niger », « 🇨🇦 Canada »,
      « 🇩🇿 Algérie », et le filtre posé d'office est le pays du profil.
- [ ] Rejoindre puis quitter un groupe public avec un compte non admin : le
      nombre de membres suit dans la liste. *Bloqué : deux comptes pour le
      voir côté autre membre.*
- [ ] Nom d'un groupe créé à la main avec « États-Unis » : la pastille de la
      carte affiche « 🇺🇸 États-Unis ».

**Étendu aux groupes de ville le 2026-09-14.** Déménager de Montréal à
Toronto propose de quitter « — Montréal » à six mois, sans toucher au groupe
du Canada. Trois défauts que l'arrivée des groupes de ville révélait ont été
corrigés avant livraison, dont un qui aurait rendu la fonction muette : la
garde « revenu dans le pays » annulait les départs dont le groupe porte le
pays du profil — et un groupe de ville porte le pays de sa ville. Le départ
de Montréal s'annulait donc au premier enregistrement de profil venu,
l'usager étant toujours au Canada. Sept cas rejoués en base, transaction
annulée.

Pour provoquer une proposition sans attendre six mois :

```sql
UPDATE public.departs_groupe_officiel
   SET proposer_apres = now() - interval '1 day'
 WHERE user_id = '<uid>' AND statut = 'en_attente';
SELECT public.proposer_departs_groupes_officiels();
```

- [ ] **Sur appareil** : après un changement de ville et la proposition
  provoquée, la fiche du groupe de l'ancienne ville affiche « Vous avez
  changé de **ville** » et nomme la **ville** quittée — pas « changé de pays »
  ni le nom du pays, qui seraient l'un et l'autre faux puisque l'usager n'a
  pas quitté le pays.
- [ ] **Sur appareil** : le groupe du PAYS n'affiche aucune carte de départ
  dans ce cas.
- [ ] **Sur appareil** : revenir à l'ancienne ville fait disparaître la carte
  sans rien demander.

---

## ⬜ Groupe privé par lien : demander à rejoindre (2026-09-10)

**Priorité P1** · importance 3/5 — Qui reçoit le lien d'un groupe privé tombe sur une impasse ou crée des demandes en double, et l'administrateur ne voit rien arriver. *Bloqué : deux comptes (Sim A est membre des deux groupes privés).*

Consigne de Salim : « pour les groupes privés, celui qui reçoit le lien fait
une demande d'adhésion au groupe ». Le message honnête livré la veille restait
une impasse ; il devient une porte.

- [ ] Depuis un compte **non-membre**, ouvrir le lien d'un groupe privé :
      nom, avatar, « Privé · N membres », bouton « Demander à rejoindre ».
      ⚠️ **Invérifiable en l'état** : « Sim A » (SM A515F) est membre des DEUX
      groupes privés de la base, donc la porte ne s'ouvre jamais pour lui ; et
      le Pixel est resté sur l'écran de connexion (relancé à froid à 01:18).
      Il faut un second compte connecté, ou un groupe privé dont Sim A n'est
      pas membre. La porte n'est couverte que par le test widget et par la
      preuve SQL en transaction annulée.
- [ ] Le bouton devient inactif après l'envoi, et l'administrateur voit la
      demande dans `/groups/<id>/requests`.
- [ ] Redemander deux fois ne doit pas empiler deux demandes.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Groupe privé par lien : demander à rejoindre (2026-09-10) »).

---

## ⬜ Acceptation et départ d'un groupe : rien ne bougeait chez les autres (2026-09-09)

**Priorité P1** · importance 3/5 — Listes de membres et « Mes groupes » figées jusqu'au redémarrage : un exclu garde le groupe à l'écran, un membre accepté ne le voit pas apparaître. *Bloqué : deux comptes.*

Signalé par Salim : « l'acceptation et exit dans les groupes ne sont pas mis à
jour automatiquement du côté de tous les users ». Deux causes superposées,
toutes deux corrigées.

- [ ] **Acceptation d'une demande, écran Membres ouvert** : téléphone A
      (administrateur) sur la fiche du groupe → Membres. Téléphone B demande à
      rejoindre. A accepte depuis l'écran des demandes, revient sur Membres :
      la personne doit y être **sans avoir refermé l'écran**.
- [ ] **Acceptation vue par un TROISIÈME écran** : garder le téléphone A sur
      la liste des membres pendant que l'acceptation se fait ailleurs (par
      exemple depuis l'écran des demandes du même groupe sur l'autre
      appareil). C'est le cas que la migration débloque : la mise à jour
      arrive sans qu'aucun code local ne l'ait demandée.
- [ ] **Départ** : B quitte le groupe. Sur A, resté sur Membres, la ligne
      disparaît et le compte « Membres · N » se décrémente tout seul. C'est
      l'événement DELETE — celui qui ne passe que parce que `group_id` fait
      partie de la clé primaire de `group_members`.
- [ ] **Exclusion** : A exclut B (appui long sur la ligne). Sur B, l'onglet
      Groupes doit perdre le groupe **sans redémarrage de l'app**.
- [ ] **« Mes groupes » à l'acceptation** : B, onglet Groupes ouvert, pendant
      que A approuve sa demande. Le groupe doit apparaître dans la liste tout
      seul, **sans spinner qui vide l'écran** (le rafraîchissement réactif est
      volontairement silencieux).
- [ ] **Fiche ouverte depuis une liste** : ouvrir la fiche groupe **depuis
      l'onglet Groupes** (c'est ce chemin qui passe `initialGroup`, et c'est
      lui qui était figé). Vérifier qu'un renommage ou un changement d'avatar
      fait depuis l'autre téléphone s'y voit sans refermer.
- [ ] **Hors ligne** : couper le réseau du téléphone A sur la fiche groupe. La
      fiche doit garder ce qu'elle affichait (repli sur `initialGroup` /
      lecture one-shot) et non se vider. Au retour du réseau, vérifier qu'une
      modification faite entre-temps finit par arriver.
- [ ] **Quitter et rouvrir vite le même groupe**, plusieurs fois de suite,
      puis vérifier qu'une modification faite depuis l'autre téléphone arrive
      toujours. Le flux est `autoDispose` : chaque aller-retour détruit
      l'abonnement et en recrée un pendant que l'ancien se ferme encore.
      C'est ce que le suffixe unique de topic realtime protège — sur un topic
      partagé, le nouveau canal reste muet sans la moindre erreur.

---

## ⚠️ Lire les groupes SANS session échoue en production (2026-09-09)

**Priorité P0** · importance 5/5 — Tant que la session Supabase n'est pas établie (installation neuve, examinateur Play compris), la liste des groupes, la fiche d'un groupe et les événements affichent une erreur au lieu du contenu.

`20260910014500_has_group_invite_executable_par_anon.sql` ajoute le GRANT
manquant. Prouvé en transaction annulée, dans les deux sens : sans lui `anon`
reçoit 42501 ; avec lui il voit **3 groupes** — les 3 publics, aucun des 2
privés. La visibilité ne bouge pas, l'erreur dure devient un `false`.

- [ ] Un lien profond `/groups/<public>` reçu par quelqu'un qui vient
      d'installer l'app.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⚠️ Lire les groupes SANS session échoue en production (2026-09-09) »).

---

## ⬜ Inviter des membres dans un groupe privé (2026-09-09)

**Priorité P1** · importance 5/5 — Un administrateur ne peut toujours pas faire entrer quelqu'un dans son groupe privé, ou l'invité accepte sans accéder à la discussion ; si l'exclusion ne tient pas, un membre retiré continue de lire le groupe. *Bloqué : deux comptes (sauf l'interface d'invitation côté admin).*

**Ce qui est à vérifier à l'écran** (aucun point ci-dessous n'est couvert par
`flutter analyze`) :

- [ ] Fiche d'un groupe privé dont on est administrateur : la ligne
      « Aucun autre membre » devient « Inviter un membre », en couleur d'accent
      avec un chevron, et ouvre la feuille
      (`group_detail_screen.dart`, `_buildMembersSection`).
- [ ] Menu ⋮ de la fiche : l'entrée « Inviter un membre » est présente pour un
      administrateur, absente pour un simple membre. Son icône
      (`group_add_outlined`) ne doit pas se confondre avec celle de
      « Demandes d'adhésion » juste en dessous.
- [ ] Écran « Membres » : l'icône d'ajout en barre de titre n'apparaît que
      pour un administrateur (`group_members_screen.dart`).
- [ ] Feuille elle-même (`invite_members_sheet.dart`) : suggestions à
      l'ouverture (amis + personnes avec qui on a discuté), recherche par nom
      au-delà de deux caractères, sélection multiple, « Inviter un membre · 2 »
      sur le bouton.
- [ ] **Clavier** : la feuille se recale au-dessus du clavier sans déborder, et
      la croix d'effacement du champ apparaît dès la première frappe (pas au
      bout de 350 ms).
- [ ] **Thème sombre** et **échelle de police à 130 %** sur la feuille.
- [ ] Une personne déjà invitée s'affiche estompée, « Déjà invité », non
      sélectionnable — et le reste après avoir fermé puis rouvert la feuille.
- [ ] **Bout en bout, deux téléphones** : inviter depuis le compte
      administrateur, puis sur l'autre appareil voir l'invitation dans l'onglet
      Groupes, l'accepter, et vérifier que le groupe apparaît **aussi dans
      l'onglet Messages** — c'est ce dernier point qui est nouveau et jamais
      testé (`acceptInvite` raccroche maintenant la conversation, comme
      `joinGroup` le faisait déjà de son côté).

- [ ] Envoyer un message depuis chaque côté : lisible des deux (vrai chemin
      Sender Key — voir la section « un groupe dont on est le seul membre »).

### ⬜ Notifications de groupe : personne n'était prévenu de rien

Le type `groupInvite` est câblé de bout en bout côté app depuis toujours
(routage, style, canal Android, clé de préférence `groups` dans `send-push`),
et un INSERT dans `notifications` déclenche déjà le push. **Aucun code, client
ou serveur, n'en créait jamais** — ni pour une invitation, ni pour une demande
d'adhésion, ni pour sa réponse. Trois déclencheurs ajoutés dans la même
migration.

- [ ] Recevoir la **notification push** d'invitation sur l'autre téléphone,
      app fermée ; l'appui ouvre la fiche du groupe.
- [ ] Sur cette fiche, la barre du bas propose **« Accepter » / « Refuser »**
      et non « Demander à rejoindre » (`_BarreInvitation`,
      `group_detail_screen.dart`). Accepter fait disparaître la barre.
- [ ] Couper la bascule « Groupes » dans les réglages de notifications :
      l'invitation suivante ne doit **pas** arriver en push (elle reste dans
      la liste in-app).
- [ ] Demander à rejoindre un groupe privé depuis l'autre compte :
      l'administrateur reçoit la notification. Approuver : le demandeur reçoit
      « Adhésion acceptée ». Refuser sur une autre demande : « Adhésion
      refusée ».

### ⬜ L'impasse tranchée : l'exclusion s'enregistre, tout membre ouvre sa discussion

À vérifier sur appareil, après déploiement :

- [ ] Quitter un groupe volontairement : toujours possible, et le groupe
      disparaît de l'onglet Messages.
- [ ] Envoyer des messages dans un groupe : personne n'est retiré au passage
      (le déclencheur est posé sur `UPDATE OF participant_ids`, un message
      n'écrit que `data` — couvert par l'étape E du banc, mais jamais vu
      tourner sur un vrai fil).

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Inviter des membres dans un groupe privé (2026-09-09) »).

---

## ⛔ Un groupe dont on est le seul membre refuse TOUS les messages (2026-09-09)

**Priorité P0** · importance 3/5 — Les médias de groupe peuvent échouer à l'envoi faute de destinataires, et leur légende est stockée en clair sur le serveur sous une étiquette « aes » — fuite de texte dans une messagerie annoncée chiffrée.

- [ ] Les envois de **médias** en groupe : le provider ne leur passe aucun
      `participantIds` — et la légende part en clair, voir la section « La
      légende d'une photo/vidéo part EN CLAIR » en tête de fichier.
      ⚠️ **Tentative du 2026-09-11, abandonnée faute de fixture sûre.** Une
      image de test (carré vert 400×400) poussée par `adb` dans `Pictures/`,
      `Download/` **et** `DCIM/Camera/`, chaque fois indexée par
      `MEDIA_SCANNER_SCAN_FILE` (vérifié dans MediaStore), **n'apparaît pas**
      dans la galerie de l'app — analyse des pixels de la capture : aucune
      vignette de cette couleur. Le sélecteur « Documents », lui, filtre sur
      le type et ne montre pas les images. Restait à piocher dans les photos
      personnelles de l'appareil : refusé. **Pour débloquer** : prendre une
      photo par la caméra de l'app pendant une session où Salim est présent,
      ou ajouter une image de test à l'APK. À faire en même temps que le
      correctif de la légende, qui touche le même chemin d'envoi.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⛔ Un groupe dont on est le seul membre refuse TOUS les messages (2026-09-09) »).

---

## ⛔ Un membre non-admin ne peut pas ouvrir la discussion de son groupe (2026-09-09)

**Priorité P1** · importance 4/5 — Si la garde ou l'exclusion a régressé, un membre simple s'octroie des droits ou un exclu revient lire la discussion du groupe. *Bloqué : deux comptes pour l'exclusion ; le reste faisable avec Sim A.*

- [ ] SM A515F (Sim A, membre simple de « Testeurs ») : « Ouvrir la
      discussion » ouvre le fil, sans bandeau rouge.
- [ ] Le groupe apparaît ensuite dans l'onglet Messages de Sim A (c'est
      l'ajout à `participant_ids` qui l'y fait entrer).
- [ ] **Non-régression de la garde** : depuis un compte membre simple, tenter
      de se promouvoir admin ou d'exclure quelqu'un doit toujours être refusé.

---

## ⬜ Fiche « Membres » d'un groupe : « Erreur de chargement » (2026-09-09)

**Priorité P2** · importance 3/5 — Hors ligne, l'utilisateur lit « Erreur de chargement » sans comprendre que c'est le réseau ; si la cause n'était pas le réseau, la fiche Membres reste inaccessible.

Vu sur Pixel 10 Pro XL, non corrigé, cause non isolée. L'écran des membres
s'affichait correctement (« Salim L. — Créateur ») ; après un passage par
l'accueil et un retour dans l'app, il est passé à « Erreur de chargement »
avec un bouton « Réessayer » qui **échoue à chaque fois** (deux essais, à
plusieurs secondes d'écart). Donc `GroupMembersScreen` sans `widget.group`
→ `loadGroup(groupId)` → `getGroupById` en échec.

- [ ] **À voir sur appareil, demande la main de Salim** : couper le réseau est
      un réglage système. Mode avion → onglet Groupes, puis fiche Membres :
      « Pas de connexion internet » aux deux endroits, et « Réessayer » qui
      refonctionne une fois le réseau revenu.
- [ ] Reste ouvert : pourquoi `getGroupById` échouait là où l'écran affichait
      le groupe une minute plus tôt. Si c'était le réseau, c'est réglé par
      le message ci-dessus ; sinon la cause est toujours à trouver.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Fiche « Membres » d'un groupe : « Erreur de chargement » (2026-09-09) »).

---

## Le sondage de groupe s'affiche enfin : bulle dans la discussion (2026-08-24)

**Priorité P2** · importance 4/5 — Un sondage publié reste invisible ou figé pour les membres du groupe, qui ne peuvent pas voter.

Le sondage arrive maintenant comme **bulle dans la conversation** :
`MessageType.poll` + `pollId` sur le message, `PollMessageBubble` qui relit
`post_polls` et monte `PollCard` (vote intégré). La bulle ne porte que l'id :
voter ne réécrit jamais le message, c'est la carte qui se met à jour.

À vérifier sur appareil :

- [ ] Groupe → trombone → **Sondage** : après « Publier », une **bulle de
      sondage** apparaît dans la discussion, avec la question et ses options.
- [ ] **Voter depuis la bulle** : la barre, le pourcentage et le total bougent
      immédiatement (invalidation de `pollStreamProvider` après le vote).
- [ ] Sur un **second téléphone / compte**, le vote de l'autre remonte sans
      quitter l'écran (c'est ce que la publication realtime apporte).
- [ ] Le même chemin depuis le menu **⋮ → Créer un sondage** publie aussi la
      bulle (`conversation_options_modal.dart`).
- [ ] **Liste des conversations** : l'aperçu affiche « 📊 <question> ».
- [ ] **Notification push** reçue par un autre membre : « 📊 Sondage » (la
      question ne part pas dans la notification, même choix que la position).
- [ ] **Transférer** une bulle de sondage est refusé avec un message clair
      (un sondage de groupe n'est lisible que par ses membres).
- [ ] Sondage **terminé** (durée 24 h dépassée) : la bulle montre les
      résultats sans permettre de voter.

---

## Créer un sondage était impossible pour tout le monde (2026-08-23)

**Priorité P2** · importance 3/5 — Les votes restent à 0 ou le sondage d'un post n'est jamais joint, sans message clair.

À vérifier sur appareil :

- [ ] Retirer/changer son vote : le compteur redescend.
- [ ] Fil → nouveau post → **Sondage** joint : le sondage s'affiche sous le
      post publié. En cas d'échec, le toast dit maintenant « Publication
      créée, mais le sondage n'a pas pu être joint »
      ([create_post_screen.dart](lib/features/feed/presentation/screens/create_post_screen.dart)).
- [ ] Message d'erreur : la feuille affiche désormais la cause réelle et non
      plus un texte générique
      ([create_poll_sheet.dart](lib/features/polls/presentation/widgets/create_poll_sheet.dart)).

---

## Mentions de groupe : vérifié sur SM A515F (2026-08-23)

**Priorité P2** · importance 3/5 — La mention n'est ni visible ni cliquable, ou insère un identifiant brut au lieu du pseudo.

- [ ] Coloration de la mention dans la bulle, chez l'expéditeur et chez le
      destinataire. Débloqué : « clé de groupe introuvable » ne s'affiche plus
      (causes corrigées et vérifiées le 2026-08-23, voir « Le message de
      groupe illisible par son propre expéditeur » dans l'archive), et les 61
      messages de groupe des 30 derniers jours partent tous en `aes`, lisible
      par tout le groupe (relu en base le 2026-09-22).
- [ ] Tap sur la mention → ouvre le profil.
- [ ] Compte **avec** poignée : vérifier que c'est `@diaspo_ne` qui est inséré
      et non l'identifiant. Le filtre `@sa` ne le proposait pas ; à retenter
      avec `@dia`.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Mentions de groupe : vérifié sur SM A515F (2026-08-23) »).

---

## Mentionner quelqu'un par son pseudo dans un groupe (2026-08-23)

Les messages passent au même pseudo que le fil
([mention_handle.dart](lib/core/utils/mention_handle.dart)) : la **poignée
publique** (`users.handle`) quand la personne en a choisi une, sinon le pseudo
dérivé du nom. Au 2026-08-23, 2 comptes sur 11 seulement avaient une poignée —
le repli est le cas courant, pas le cas limite.

**À vérifier sur appareil** (nécessite un groupe avec au moins deux membres) :

7. Ouvrir un ancien message qui contient une mention : elle doit rester colorée.

---

## Le pseudo de mention mangeait les lettres accentuées (2026-08-23)

**À vérifier sur appareil** :

1. Nouvelle publication → taper `@Maï` : la personne doit apparaître dans les
   suggestions, et la sélectionner doit insérer `@IbrahimYacoubaMaïdaoua`
   **avec le tréma**, coloré en entier pendant la frappe.
2. Publier, puis taper sur la mention dans le fil : elle doit ouvrir le profil.
3. **Le cas du repli** : ouvrir une publication ou un commentaire **ancien**
   qui contient déjà une mention (forme ASCII), taper dessus — elle doit
   toujours ouvrir le bon profil.
4. Même chose dans les commentaires (`comment_tile`).

Non couvert par les tests : le rendu réel de la liste de suggestions et le
comportement du clavier pendant la saisie du `@`.

---

## Groupes & événements en conversation

**Priorité P2** · importance 2/5 — Carte d'événement mal rendue, « Vu par » faux ou groupe du pays jamais rejoint : gêne visible, sans perte de données.

- [ ] **Bulle `EventMessageCard` en conversation + différenciation groupe** (commit `267d7d3`) : visibilité « publier dans le fil » DM/groupe, badge Admin sur les bulles, « Vu par N » sur messages de groupe lus, boutons appel/vidéo de groupe dans l'app bar, auto-adhésion au groupe pays au chargement du profil — aucun sous-élément vérifié sur device.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Groupes & événements en conversation »).

---

## Fiche membres de groupe bloquée / vide (2026-08-13)

**Priorité P2** · importance 2/5 — Les membres d'un nouveau pays n'ont pas de groupe officiel et ne rejoignent rien, sans erreur visible. *Bloqué : données absentes (attendre un pays sans groupe officiel).*

**Bug structurel trouvé en vérifiant qu'aucun autre groupe officiel n'avait
été oublié** : la RPC `get_or_create_official_group` (déclenchée
automatiquement à chaque profil qui renseigne un pays) reproduisait le même
défaut pour tout NOUVEAU pays — et depuis le 2026-08-06
(`groups_guard_official`), échouait carrément en silence (42501 avalé côté
app), donc plus aucun groupe officiel n'était créé pour un pays inédit.
Corrigé par migration (`20260813233000_fix_official_group_creator_and_admin.sql`) :
la RPC désactive les deux triggers concernés le temps de son propre INSERT,
pose le compte plateforme comme `creator_id`, et ajoute la ligne
`group_members role='owner'` manquante. Détail dans
`docs/ops/GROUPES_OFFICIELS.md`.

- [ ] **Vérification sur appareil demandée par Salim** : dès qu'un vrai
  compte renseigne pour la première fois un pays sans groupe officiel
  existant, confirmer sur cet appareil que le groupe apparaît normalement
  (nom, « Créé par Diaspo Niger », membre compté) — la transaction annulée
  ci-dessus prouve la logique SQL, pas le chemin réel `ProfileNotifier` →
  RPC → écran groupe de bout en bout. Repérable via
  `select id, name, country_code, created_at from groups where is_official
  order by created_at desc;` (un nouveau pays = une ligne de plus).

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Fiche membres de groupe bloquée / vide (2026-08-13) »).

---

## Groupes — « Découvrir » lisait le mauvais backend (2026-08-06)

**Priorité P1** · importance 2/5 — Les nouveaux venus ne trouvent pas les groupes par la recherche et ne rejoignent pas celui de leur pays ; au pire une carte déborde en bande rayée.

À vérifier sur l'appareil :

- [ ] **Recherche de groupes** (loupe de l'écran Groupes) : taper « niger »
      remonte bien les deux groupes « Diaspora Niger ».
- [ ] **Groupe officiel du pays à l'inscription** : renseigner un pays dans le
      profil doit désormais faire apparaître son groupe officiel dans
      « Mes groupes » (chemin `ensureOfficialGroup`, jamais exécuté jusqu'ici).

### §9c — le nom du groupe était rogné par les pastilles de sa carte

- [ ] **Carte d'un groupe officiel, épinglé, actif** : le nom complet est
      lisible (sur deux lignes si besoin), les pastilles « Officiel » et
      ACTIF/CALME sont visibles en bas de carte, **aucun bandeau rayé**.
- [ ] **font_scale 1.1**, même carte : toujours aucun débordement, la ligne de
      méta passe à deux rangs si nécessaire.
- [ ] **Nom très long** (créer un groupe au nom de 60 caractères) : il s'élide
      proprement au bout de la 2ᵉ ligne, sans pousser le bouton hors carte.

### §9e — pourquoi il paraissait inatteignable, et comment l'atteindre

L'item « Messagerie — état vide » était noté inatteignable parce que la
messagerie du compte n'est plus vide. **C'est vrai pour une moitié seulement**
de la fiche. En lisant `messages_screen.dart`, il y a deux déclencheurs
distincts :

| Partie de 9e | Condition | Atteignable aujourd'hui |
|---|---|---|
| **Le corps** (pastille ronde, titre, amorces nommées, CTA, ligne chiffrement) — `_buildEmptyState` | la liste **filtrée** est vide | **oui** |
| **Le chrome** (ni champ de recherche, ni puces de filtre, ni entrée « Archives ») — `isEmptyInbox` | la liste **entière** est vide | non |

Le corps se déclenche donc sans compte neuf :

- [ ] **Puce « Non lus » alors que rien n'est non lu** → le corps de 9e
      s'affiche. C'est le chemin le plus rapide.
- [ ] **Puce « Groupes » sur un compte sans conversation de groupe** → idem.
- [ ] **Archiver toutes les conversations** puis revenir sur « Tous » → idem,
      avec la tuile « Mes notes » conservée au-dessus.

Le chrome de 9e, lui, demande une liste `conversations` réellement vide :
**archiver ne suffit pas**, `isEmptyInbox` lit la liste avant filtrage. Il faut
un compte neuf.

- [ ] **Compte neuf, messagerie jamais utilisée** : vérifier l'absence du champ
      de recherche, des puces de filtre et de l'entrée « Archives » dans
      l'en-tête.

---

## Demandes d'adhésion — brancher Supabase n'avait pas suffi (2026-08-06)

**Priorité P1** · importance 2/5 — Refus inopérants et demandes en double pour l'administrateur ; si les gardes ont régressé, un non-admin traite les demandes et un non-membre lit un groupe privé. *Bloqué : deux comptes (sauf le menu non-admin, faisable avec Sim A).*

Rien de tout ça n'est prouvable sans **deux comptes** :

- [ ] **A refuse** une deuxième demande : elle disparaît de la liste et B ne
      devient pas membre.
- [ ] **B redemande alors qu'il est déjà membre** : message « Vous êtes déjà
      membre de ce groupe » (le garde lisait une colonne vide, il ne se
      déclenchait jamais).
- [ ] **Refus d'invitation** (`declineGroupInvite`) : même chemin RLS que
      l'acceptation, débloqué par la même migration, mais jamais exercé.
- [ ] **Un non-admin ne voit pas** les demandes du groupe, et l'appel RPC lui
      est refusé (« Réservé aux administrateurs du groupe »).

### Le corollaire : un groupe privé ne montrait qu'un seul membre

- [ ] **Un non-membre ne voit toujours rien** d'un groupe privé.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Demandes d'adhésion — brancher Supabase n'avait pas suffi (2026-08-06) »).

---

## La porte d'entrée des groupes était grande ouverte (2026-08-06)

**Priorité P1** · importance 2/5 — Si la garde a cassé l'adhésion, personne ne rejoint plus un groupe public ; si elle a sauté, n'importe qui entre dans un groupe privé dont il connaît l'id. *Bloqué : deux comptes (ou un groupe privé sans Sim A).*

- [ ] **Reste à voir** : rejoindre un groupe public depuis un compte qui n'y a
      jamais mis les pieds (le test l'a fait avec le compte administrateur d'un
      autre groupe), et vérifier qu'un groupe privé sans invitation ne propose
      bien que « Demander à rejoindre ».

---

## Groupes — défauts trouvés en vérifiant les épingles (2026-08-05)

**Priorité P1** · importance 3/5 — Un nouvel inscrit voit son profil échouer au premier enregistrement, et une conversation de groupe ouverte depuis une notification s'affiche comme un 1:1 (en-tête « Utilisateur », boutons d'appel).

**2. Un lien profond vers une conversation de groupe la rend en 1-à-1.**
`app_router.dart:873` lit `isGroup` uniquement dans `state.extra`, absent d'un
lien profond ou d'une notification : `isGroup` retombe à `false`. Ouvrir
`https://diasponiger.web.app/messages/<id d'une conversation de groupe>` donne
un en-tête « Utilisateur » avec boutons d'appel, et le bandeau épinglé
interroge `conversationPinnedItemsProvider` — qui ne renvoie jamais rien pour
un groupe. `ConversationScreen` ne reconcilie jamais ce drapeau avec
`conversation.groupId`, pourtant disponible.

- [ ] Même conversation, ouverte par NOTIFICATION (`state.extra` également nul) :
  même en-tête. Non testé — pas de push déclenchable simplement depuis le poste.
- [ ] Épingler puis détacher un message depuis ce chemin.
- [ ] Non testés faute de jeu de données ou de droits : les 6 `_save` de
  l'admin (compte admin requis), bloquer/débloquer, join/leave de groupe,
  galerie média, appels de groupe, salons audio.
  - [ ] À vérifier sur appareil : reprendre l'assistant de configuration de
    profil et enregistrer du premier coup, sans passer par « Réessayer ».

**3. `isSelfNotes` avait exactement le même défaut** (trouvé en corrigeant le
n°2, corrigé dans la foulée le 2026-08-05). `app_router.dart` lisait
`extra?['isSelfNotes'] as bool? ?? false` : ouvrir « Mes notes » par lien
profond la rendait comme un fil ordinaire — titre tiré du profil au lieu de
« Mes notes », avatar sans le marque-page, boutons d'appel présents, et menu
« + » sans le brouillon de sondage. Même correctif : `_isSelfNotes` dérivé de
`ConversationEntity.isSelfNotesFor(currentUserId)` (participant unique = moi).
Tant que l'utilisateur courant n'est pas chargé, la valeur connue est
conservée plutôt que de conclure « non » à tort (sinon le titre clignote).

- [ ] Ouvrir « Mes notes » par lien profond : titre « Mes notes », avatar
  marque-page, aucun bouton d'appel, pas d'indicateur de présence.
- [ ] Menu « + » du composer dans ce cas : le brouillon de sondage doit être
  proposé (et pas l'événement).
- [ ] Non-régression : depuis la tuile épinglée de la liste des messages, rien
  ne doit changer.

- ✔ 20 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Groupes — défauts trouvés en vérifiant les épingles (2026-08-05) »).

---

# 4. Chiffrement de bout en bout et clés

Signal 1:1 et groupes, repli AES, clés dérivées, sauvegarde et transfert des clés, et tout ce qui pouvait partir en clair.

---

## ⬜ Pixel réinstallé : la discussion MLS avec Sim A se rouvre malgré des Welcome périmés (2026-09-21)

**Priorité P1** · importance 4/5 — relevé par Salim : « 3 non lus » sur Sim A
dans la liste du Pixel, aperçu « Message chiffré », et rien à l'ouverture.
Le Pixel a été **désinstallé puis réinstallé** le 20/09 (`firstInstallTime`
16:42) : base MLS neuve, `identite_mls_changee` à 22:47 UTC. Deux Welcome du
17/09 (epochs 13 et 15) l'attendaient encore, adressés aux KeyPackages de
l'ancienne installation : `traiterWelcome` échouait, l'exception sortait de
`_ensureGroup` avant la jointure externe prévue pour une réinstallation, et
rien n'était journalisé. Correctif : un Welcome illisible est journalisé
(`welcome_illisible`) puis dépassé, sans être marqué consommé
(`mls_conversation_service.dart`, test
`mls_welcome_illisible_apres_reinstallation_test.dart`).

À vérifier sur le Pixel avec l'AAB 1.2.2+24 :
- [ ] ouvrir Sim A → `mls_diagnostics` montre deux `welcome_illisible` (15
      puis 13), puis un commit du device `8ac577df` à l'epoch 17 dans
      `mls_commits` ;
- [ ] les 3 messages des epochs 13-15 **n'apparaissent pas du tout** (chiffrés
      avant la jointure, écartés par `catchUp` via l'epoch d'arrivée
      mémorisée `mls_arrivee_<uid>_<conv>`), et le compteur « non lus »
      retombe à 0 sans autre action (reçus `read_at` posés dans
      `mls_message_receipts`) — Sim A voit donc ces 3 messages « Lu » ;
- [ ] ⚠️ l'aperçu de la liste peut rester sur « Message chiffré » tant
      qu'aucun nouveau message n'arrive (il vient du dernier message serveur,
      non filtré) : à relever ;
- [ ] Sim A (A515F) envoie un message → le Pixel l'affiche en clair, et
      inversement ;
- [ ] relancer l'app sur le Pixel : aucune nouvelle jointure (`mls_commits`
      reste à un seul commit du Pixel).

---

## ⬜ « Appareils enregistrés » et « Sauvegarde des clés » ne montrent plus Signal à un compte passé à MLS (2026-09-16)

**Priorité P2** · importance 3/5 — relevé par Salim sur le Samsung (Sim A) :
les deux écrans étaient presque entièrement consacrés aux clés **Signal**, que
ce compte n'utilise pas (0 message Signal sur Sim A et Salim L., toutes leurs
discussions chiffrées sont en MLS). « Appareils » ouvrait sur « Inscrits : 3
sur 5 », trois « Appareil Android » de juillet-août, un bandeau « Cet appareil
n'a pas pu être identifié » et la limite de 5 — la vraie liste, sous
« Nouveau registre (MLS) … la future messagerie », n'apparaissait qu'en
faisant défiler. « Sauvegarde » annonçait « Cet appareil n'a pas vos clés »
sur un téléphone qui lisait tous ses messages chiffrés, et proposait un
transfert par QR qui n'emporte que Signal.

Désormais, selon `mlsMessagesActifsProvider` :
- **compte passé à MLS** : « Appareils » ne montre que le registre MLS
  (texte d'introduction, « Vu le … », révoqués repliés sous « N appareils
  révoqués », avec leur date) ; « Sauvegarde » garde la carte d'en-tête et
  explique qu'il n'y a rien à sauvegarder ni à transférer, avec un lien vers
  les appareils ;
- **autre compte** : Signal comme avant, et plus de registre MLS.

- [ ] Samsung (Sim A), Réglages › Appareils enregistrés : aucune carte « Appareil Android », aucun « sur 5 » ; « CET APPAREIL » en tête avec « Vu le … » et son code de sécurité ; « 3 appareils révoqués » replié, qui s'ouvre sur trois fiches datées ;
- [ ] Réglages › Sauvegarde des clés : carte « Chiffrement des messages », puis « Vos discussions chiffrées » ; aucun bouton de transfert, aucune passphrase ; la tuile « Appareils enregistrés » ouvre bien l'écran ;
- [ ] un compte **non** passé à MLS : les deux écrans sont ceux d'avant (liste Signal, transfert, sauvegarde), sans section MLS ;
- [ ] les nouveaux textes en thème sombre et à l'échelle de police ×2, sans débordement.

---

## ⬜ L'app lancée sans son écran n'inscrit plus d'appareil fantôme (2026-09-16)

**Priorité P1** · importance 4/5 — le 2026-09-16 à 18:15:32 UTC, sur le Pixel
(Salim L.), **trois** fiches `mls_devices` sont nées en 190 ms, sans
réinstallation, avec un `stable_id` au format UUID au lieu des 32 caractères
hexadécimaux habituels. Toutes trois portaient **la même** identité MLS, qui
n'était pas celle de la vraie installation. Les autres membres ont ensuite tenté
de les ajouter en boucle : 36 KeyPackages réclamés en 7 minutes.

Corrigé : un canal muet fait **attendre**, jamais inventer
(`attendreIdentifiantInstallation`, [lib/core/services/e2ee/stable_device_id.dart](lib/core/services/e2ee/stable_device_id.dart)),
et la passerelle partage l'inscription en cours (`volUnique`,
[lib/core/crypto/mls/mls_providers.dart](lib/core/crypto/mls/mls_providers.dart)).

Contrôle en base, avant et après chaque essai :

```sql
select stable_id, to_char(created_at at time zone 'UTC','HH24:MI:SS') as cree
from mls_devices where created_at > now() - interval '1 hour' order by created_at;
```

- [ ] **Démarrer l'app sans son écran** : écouter un podcast, fermer l'app depuis les récents, puis relancer la lecture depuis les contrôles média du système (écran de verrouillage ou volet). Dans logcat, `flutterEngine warmed up` doit suivre un `Start proc … for service` et non `for top-activity`, sinon l'essai ne prouve rien. Attendu : `stableDeviceId: canal muet … attente` dans le journal, et **aucune** nouvelle ligne `mls_devices` ;
- [ ] puis **ouvrir l'app** sans la tuer : `canal branché après N tentatives`, `last_seen_at` de la vraie fiche (32 hex) se met à jour, toujours aucune ligne neuve ;
- [ ] démarrage à froid ordinaire (icône) : aucune ligne `canal muet` — sinon la fenêtre entre `main()` et `configureFlutterEngine` existe aussi au lancement normal, et chaque démarrage paierait l'attente.

---

## ⬜ MLS après un démarrage à froid : lire et envoyer dans une conversation chiffrée (2026-09-16)

**Priorité P0** · importance 5/5 — en production (build `1.2.1+19` du Play
Store), **après avoir relancé l'app**, une conversation chiffrée n'affichait
plus aucun message reçu et **aucun envoi ne partait**. Constaté sur le Samsung
(Sim A) dans « Testeurs » : 24 `POST /rest/v1/messages` refusés en 400 par
`messages_refuse_conversation_mls_trg` entre 15:41 et 15:46 UTC, et plus une
seule requête `mls_*` depuis le redémarrage de 15:41:45 — alors que la même
installation marchait à 15:32, juste après sa première connexion.

Couvert par `test/core/providers/uid_firebase_provider_test.dart` (uid arrivé
après coup, changement de compte, pas de reconstruction à uid égal). Ce que le
test ne peut pas prouver : **l'ordre réel du démarrage sur un téléphone**, qui
est la panne elle-même. Deux appareils, dans une conversation déjà chiffrée :

- [ ] se déconnecter puis se connecter avec **un autre compte** sans tuer l'app : envoyer dans une conversation chiffrée de ce compte — le `sender_id` de la ligne `mls_messages` est le nouveau compte ;
- [ ] **Anciennes installations encore « actives »** (le troisième défaut du jour) : dans un 1:1 où les deux comptes ont des appareils effacés jamais révoqués, envoyer — le message part (`mls_messages`), et si l'ajout de ces appareils échoue, une ligne `ajout_membres_echoue` apparaît dans `mls_diagnostics` avec son `code`, **une seule fois** par lancement. Avant : « Non envoyé » à chaque essai, 3 KeyPackages réclamés par minute, aucun diagnostic. Relever le `code` : c'est la cause réelle, jamais vue (non reproduite hors du Samsung).

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ MLS après un démarrage à froid : lire et envoyer dans une conversation chiffrée (2026-09-16) »).

---

## ⬜ « Chiffré de bout en bout » corrigé sur 8 surfaces, dont la politique de confidentialité (2026-09-16)

**Priorité P1** · importance 4/5 — la phrase « Vos messages sont chiffrés de
bout en bout. Seuls vous et vos correspondants pouvez les lire » n'était vraie
que dans les fils MLS. Pour les 121 messages `aes`, le serveur détient la
racine des clés (`crypto-keys`) et `public.decrypt_aes_fallback` sait les lire
— vérifié en production le 2026-09-16, la fonction existe toujours : c'est elle
qui fabrique les aperçus push.

Le parti pris : ne plus affirmer en bloc, dire les deux étages. Le chiffrement
de bout en bout est revendiqué **là où il est vrai** — les discussions qui y
sont passées, dont la clé n'existe que sur les appareils — et le reste est
décrit pour ce qu'il est : chiffré en transit et au repos, avec une clé
détenue par le serveur, ce qui est précisément ce qui permet l'aperçu des
notifications. Le pied de page de connexion, trop court pour nuancer, dit
simplement « Vos messages sont chiffrés ».

⚠️ **Le site n'est PAS déployé** : `firebase deploy --only hosting` publie tout
`public/` d'un coup (voir « Site web » au § 15). À faire par un aperçu, quand
Salim l'aura relu.

⚠️ **À vérifier hors du dépôt** : la déclaration « Sécurité des données » de la
Console Play reflète probablement l'ancienne formulation. Elle ne se lit pas
d'ici.

- [ ] Écran de connexion : le pied de page tient sur **une ligne** en français
      comme en anglais, à l'échelle de police par défaut
- [ ] Onboarding, écran Groupes : la puce raccourcie ne casse pas l'alignement
      des trois puces
- [ ] Les quatre écrans en **anglais** aussi (la version longue anglaise est
      encore plus longue que la française)

Fichiers : [app_fr.arb](lib/l10n/app_fr.arb), [app_en.arb](lib/l10n/app_en.arb),
[privacy-policy.html](public/privacy-policy.html),
[fonctionnalites.html](public/fonctionnalites.html)

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ « Chiffré de bout en bout » corrigé sur 8 surfaces, dont la politique de confidentialité (2026-09-16) »).

---

## ⬜ Les deux bandeaux de clés retirés : ils promettaient faux (2026-09-16)

**Priorité P2** · importance 3/5 — « Restaurez vos clés de chiffrement pour
lire vos messages chiffrés sur cet appareil » était faux dans les deux sens, et
mesurable :

- la sauvegarde ne porte que du matériel Signal — identité, pré-clés, sessions
  (`SecureKeyStorage.exportAllKeys`) ;
- **aucun message de production n'a jamais été chiffré par Signal.** Relevé le
  2026-09-16 sur `public.messages` : 121 lignes en `aes`, 10 sans niveau,
  **0 en `e2ee`** ;
- les clés du repli AES ne sont pas dans la sauvegarde : elles sont redérivées
  par l'Edge Function `crypto-keys` à chaque installation. Restaurer ne rendait
  donc aucun message lisible, et ne pas restaurer n'en perdait aucun ;
- le seul état dont la perte coûte vraiment quelque chose est celui du moteur
  MLS, que cette sauvegarde ne touche pas — il est même volontairement exclu
  des sauvegardes Google et iCloud.

Retirés : le `MaterialBanner` du shell (sauvegarde **et** restauration) et le
bandeau de conversation. L'arbitrage « la sécurité prime sur la mise à jour »
part avec eux — il n'y a plus qu'une source de bandeau haut. Le coordinateur
reste entier : c'est lui, et non le bandeau, qui protège, en refusant de
générer une identité neuve par-dessus une sauvegarde restaurable. L'écran
Réglages › Sécurité reste atteignable à la main, sauvegarde et restauration
comprises.

- [ ] Compte avec une sauvegarde distante, application réinstallée : **aucun**
      bandeau de clés au démarrage (c'est le cas `needsRestore`, celui qui se
      déclenchait à chaque installation sur les 5 comptes qui ont une
      sauvegarde)
- [ ] Compte neuf, première connexion : aucun bandeau « Sauvegardez vos clés »
      non plus
- [ ] Ouvrir un fil MLS contenant un message illisible (`🔐 Message chiffré`) :
      plus de bandeau jaune sous l'en-tête, et la bulle reste lisible comme
      telle
- [ ] Le bandeau de **mise à jour**, lui, s'affiche toujours — c'est la seule
      source restante du bandeau haut, et il ne doit pas avoir disparu avec
      l'autre
- [ ] Paysage, clavier ouvert, sur un fil avec un message épinglé : pas de
      `BOTTOM OVERFLOWED` (la mesure de hauteur du `LayoutBuilder` reste, elle
      borne toujours `MessageInput` ; seul le seuil propre au bandeau retiré a
      disparu)
- [ ] Réglages › Sécurité s'ouvre toujours, et sauvegarder puis restaurer y
      fonctionne encore

Fichiers : [bandeaux_shell.dart](lib/core/shell/bandeaux_shell.dart),
[main_shell.dart](lib/core/shell/main_shell.dart),
[conversation_screen.dart](lib/features/messages/presentation/screens/conversation_screen.dart),
[e2ee_backup_coordinator.dart](lib/core/services/e2ee/e2ee_backup_coordinator.dart)

---

## ⬜ L'expéditeur MLS datait lui-même ses propres messages (2026-09-15)

**Priorité P2** · importance 3/5 — `MlsMessageRow.toInsert` n'envoie pas
`created_at` : la colonne a son défaut serveur. L'expéditeur en fabriquait
pourtant un de son côté (`DateTime.now()`, au moment de chiffrer) et le
gardait, sans jamais lire ce que le serveur avait retenu. Deux valeurs pour la
même ligne, et rien pour dire laquelle fait foi.

`publishMessage` relit maintenant `created_at` dans la même requête
(`insert(...).select('created_at')`, donc une seule transaction) et `send`
recolle la valeur sur la ligne rendue. La garde d'aperçu, elle, ne bouge pas :
c'est la valeur écrite qu'on corrige, pas la comparaison.

Reste à voir tourner ce que seul un téléphone montre :

- [ ] Régler l'horloge du téléphone à la main (avance de 3 min), envoyer une
      note chiffrée : l'aperçu doit tenir quand même. ⚠️ **Remettre l'horloge
      automatique après** — une horloge fausse perturbe TLS et les jetons.
- [ ] Message éphémère envoyé depuis cet appareil : le minuteur affiché part
      de l'heure du serveur, pas de celle du téléphone
- [ ] Un envoi dont la réponse se perd (couper le Wi-Fi pendant l'envoi) ne
      doit pas produire de doublon au retour du réseau

Fichiers : [mls_delivery.dart](lib/core/crypto/mls/mls_delivery.dart)
(`publishMessage`, `MlsMessageRow.avecCreatedAt`),
[mls_conversation_service.dart](lib/core/crypto/mls/mls_conversation_service.dart)
(`send`)

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ L'expéditeur MLS datait lui-même ses propres messages (2026-09-15) »).

---

## ⬜ La notification gardait le ciphertext que le message avait perdu (2026-09-16)

**Priorité P0** · importance 5/5 — « Supprimer pour tous » vide
`mls_messages.ciphertext` depuis « « Supprimer pour tous » efface vraiment le
contenu (2026-09-16) », et la purge des éphémères fait le même geste à
l'expiration. **Les deux oubliaient la seconde copie.** Le ciphertext est
aussi recopié dans `notifications.data->>'mlsCiphertext'`, pour que l'appareil
reconstruise l'aperçu (plan MLS § 8) — et cette ligne n'était touchée par
personne.

Fichiers : `supabase/migrations/20260916030000_mls_notifications_suivent_le_message.sql`.

- [ ] **Supprimer pour tous, destinataire hors ligne** : couper le réseau du
  second téléphone, supprimer pour tous depuis le premier, rétablir le
  réseau. La notification ne doit **pas** faire apparaître le texte.
- [ ] **Message éphémère expiré** : même contrôle après l'échéance.
- [ ] **Édition** : corriger un message déjà notifié ; la notification reste
  **non lue** si elle l'était (c'est la différence voulue avec la
  suppression), et ne peut plus afficher le texte d'avant.
  ⚠️ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : côté serveur la copie de PA2 est bien retirée après l'édition ; mais la BANNIÈRE Android de Sim garde « PA2 · 18:00 » (ancien texte) — voir « Une édition corrige la bannière déjà posée ». Et la bannière système garde aussi le texte d'un message SUPPRIMÉ (PA6SECRET), voir « Cinq messages reçus, un seul lisible ».
- [ ] **Suppression d'une conversation entière** : les notifications de tous
  ses messages sont nettoyées en une fois, et l'app ne rame pas.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ La notification gardait le ciphertext que le message avait perdu (2026-09-16) »).

---

## ⬜ La vidéo entre dans le chiffrement (2026-09-16)

**Priorité P1** · importance 4/5 — La vidéo était écartée du chiffrement
depuis C4, et pour une raison précise : le chiffrement passait par la mémoire,
avec un pic proche de trois fois la taille du fichier, et le téléchargement
plafonnait à 10 Mo. Les deux sens vont maintenant d'un fichier vers un autre,
un morceau à la fois. La raison n'existe plus, l'exclusion non plus.

Fichiers : [message_repository_impl.dart](lib/features/messages/data/repositories/message_repository_impl.dart)
(`_envoyerMediaChiffre`), [mls_gateway.dart](lib/core/crypto/mls/mls_gateway.dart)
(`corpsMedia`), [mls_message_mapper.dart](lib/core/crypto/mls/mls_message_mapper.dart).
Couvert hors appareil par
[video_chiffree_test.dart](test/features/messages/video_chiffree_test.dart)
(6 cas).

- [ ] **Envoyer une vidéo dans une conversation basculée** : elle part
      chiffrée, la bulle montre son aperçu et son badge de durée.
- [ ] **La rouvrir** : elle se lit, depuis le fichier déchiffré local.
- [ ] **Une vidéo longue, au-delà de 50 Mo** : l'envoi et la lecture tiennent
      sans que l'application soit tuée pour mémoire. C'est le cas qui
      justifiait l'exclusion.
- [ ] **En base** : ni URL ni clé lisibles, et `content_type` reste grossier.

---

## ⬜ Un média chiffré de plus de 10 Mo était illisible (2026-09-16)

**Priorité P0** · importance 5/5 — **Trouvé en cherchant pourquoi la vidéo
était écartée, et c'est bien plus large que la vidéo.** Le téléchargement
appelait `ref.getData()` sans argument. Le défaut de `firebase_storage` est
**10 Mo** : au-delà, l'appel échoue. Toute photo un peu lourde, tout document,
tout audio long, une fois chiffré, aurait été **illisible**. Le drapeau étant
fermé, personne ne l'avait rencontré.

Fichiers : [media_encryption_service.dart](lib/core/services/e2ee/media_encryption_service.dart)
(`downloadAndDecryptFile`, `dechiffrerFichierVersFichier`). Couvert hors
appareil par
[dechiffrement_media_en_flux_test.dart](test/core/services/e2ee/dechiffrement_media_en_flux_test.dart)
(6 cas, dont la mauvaise clé et le fichier tronqué).

**Les deux sens sont désormais en flux.** `encryptAndUploadFile` chiffre d'un
fichier vers un autre et téléverse ce fichier (`putFile`), au lieu de lire le
média entier et d'envoyer un tampon. Le conteneur versionné sert pour toute
taille — un chemin de moins, le format simple n'est plus qu'un format qu'on
sait lire.

- [ ] **Envoyer puis rouvrir une photo chiffrée de plus de 10 Mo** : elle
      s'affiche. C'était impossible avant, à coup sûr.
- [ ] **Un document chiffré de 30 à 50 Mo** : il se télécharge et s'ouvre,
      sans que l'application soit tuée pour mémoire.
- [ ] **Surveiller la mémoire pendant le déchiffrement** : le pic doit suivre
      la taille d'un morceau, pas celle du fichier.
- [ ] **Un média dont le transfert est coupé en route** : le fichier
      temporaire chiffré ne doit pas rester sur le disque.

---

## ⬜ « Supprimer pour tous » efface vraiment le contenu (2026-09-16)

**Priorité P1** · importance 5/5 — **La promesse du plan n'était pas tenue.**
Le § 6.3 dit que le serveur cesse de servir le ciphertext ; il ne cessait pas.
La suppression posait `is_deleted` et `deleted_at`, et rien d'autre. Le contenu
restait en base, et un destinataire qui n'avait pas encore rattrapé pouvait
encore le déchiffrer.

Fichiers : la migration,
[mls_metadonnees.dart](lib/core/crypto/mls/mls_metadonnees.dart)
(`supprimerPourTous`). Couvert hors appareil par
[suppression_pour_tous_test.dart](test/core/crypto/suppression_pour_tous_test.dart)
(6 cas de structure).

- [ ] **Supprimer pour tous un message chiffré** : la bulle devient une pierre
      tombale, et en base `octet_length(ciphertext)` vaut **0**.
- [ ] **Sur le message de quelqu'un d'autre** : refusé, et l'écran le dit —
      il ne doit pas afficher un succès.
- [ ] **Un appareil qui n'avait pas rattrapé** ne peut plus lire le message :
      c'est tout l'objet du changement, et ça demande un second appareil.
- [ ] **La bascule d'une conversation lève si elle n'est pas enregistrée** :
      `marquerMlsSince` relit désormais la date au lieu de supposer. Sans ça,
      un refus silencieux laissait la conversation à cheval sur les deux
      chemins — groupe MLS créé, messages chiffrés, et le serveur acceptant
      toujours du clair à côté. Difficile à provoquer à la main (tout
      participant a le droit d'écrire) ; à surveiller dans les journaux.
- [ ] **Aucun `decrypt_failed` de plus** dans `mls_diagnostics` après la
      suppression : le rattrapage doit sauter la pierre tombale, pas buter sur
      son ciphertext vide.

---

## ⬜ Une réaction retirée disparaît vraiment de l'écran (2026-09-15)

**Priorité P1** · importance 4/5 — **Trouvé en regardant l'écran, pas le
code.** Une bulle de « Mes notes » affichait un pouce levé alors que
`mls_message_reactions` était **vide** en base. La réaction n'existait plus
côté serveur, et l'écran la montrait quand même.

Le lot porte maintenant un drapeau `lu`. On sort sur l'échec de lecture, plus
sur le vide — une coupure réseau ne doit pas non plus effacer tout l'écran.

Fichiers : [mls_metadonnees.dart](lib/core/crypto/mls/mls_metadonnees.dart)
(`illisible`), [mls_gateway.dart](lib/core/crypto/mls/mls_gateway.dart)
(`_avecMetadonnees`). Couvert hors appareil par
[metadonnees_absence_vs_echec_test.dart](test/core/crypto/metadonnees_absence_vs_echec_test.dart)
(4 cas).

- [x] **Couper le réseau sur un fil qui porte des réactions** : elles restent
      affichées, elles ne s'effacent pas d'un coup. C'est l'autre moitié du
      correctif.
      ⛔ **Mais elles sont PÉRIMÉES** (défaut nouveau) : le fil hors ligne montrait
      le ❤️ retiré de PH1 une minute plus tôt, et PAS le 👍 posé sur PK1 juste
      avant. Cause, par le code : réagir et étoiler ne mettent à jour que l'état en
      mémoire et le serveur — aucun appel `cacheService` dans ces chemins
      (`message_provider.dart` `toggleReaction`/`toggleStar`,
      `message_repository_impl.dart`) ; hors ligne, le fil ressert le dernier
      instantané Hive. Et réseau revenu **discussion restée ouverte**, l'écran est
      resté faux plus d'une minute ; seule la relance à froid en ligne a remis
      l'état juste (PH1 sans réaction, 👍 sur PK1).
      **Corrigé le 2026-09-22** (branche `claude/defauts-hors-ligne-2209`) :
      `toggleReaction` et `toggleStarMessage` reportent la réaction ou l'étoile
      dans le cache Hive après l'écriture serveur (`reporterDansLeCache`),
      garde `test/features/messages/passe_adb_2209_hors_ligne_test.dart`. À revoir sur un build qui le porte : poser,
      retirer, puis mode avion + relance à froid → l'écran montre le dernier
      état. Le « réseau revenu, discussion ouverte, écran figé » n'est pas
      traité ici (rechargement au retour du réseau).

---

## ⬜ Ouvrir une discussion ne la bascule plus (2026-09-15)

**Priorité P0** · importance 5/5 — **Il suffisait de regarder une discussion
pour l'engager.** Le chemin de lecture appelait `ensureGroup`, qui crée le
groupe et pose `mls_since` — une marque définitive : le serveur refuse le
clair ensuite, et rien ne revient en arrière.

La règle posée : **créer est une décision d'écriture, elle appartient à
l'envoi**. La lecture peut *rejoindre* un groupe existant — c'est nécessaire
pour déchiffrer ce qu'on nous envoie — mais sans groupe côté serveur elle
rend la main, puisqu'il n'y a de toute façon aucun message MLS à lire.

Fichiers : [mls_conversation_service.dart](lib/core/crypto/mls/mls_conversation_service.dart)
(`catchUp`). Couvert hors appareil par
[lire_ne_bascule_pas_test.dart](test/core/crypto/lire_ne_bascule_pas_test.dart)
(4 cas, dont la garde d'ordre).

- [ ] **Puis envoyer** : la bascule a lieu à ce moment-là, pas avant.
- [ ] **Recevoir dans une discussion déjà basculée par l'autre** : l'ouvrir
      doit suffire à rejoindre le groupe et à déchiffrer.
- [ ] **Parcourir la liste des discussions** : aucune ne bascule au passage.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Ouvrir une discussion ne la bascule plus (2026-09-15) »).

---

## ⬜ Une conversation ne bascule plus sans ses participants (2026-09-15)

**Priorité P0** · importance 5/5 — **Le défaut est mesuré, pas théorique.**
Relevé en production le 2026-09-15 : deux conversations à deux personnes
avaient basculé en MLS avec **un seul appareil** dans `conversation_devices`,
celui de l'expéditeur. En face, aucune ligne dans `mls_devices` — l'autre
étant sur la version du Play Store, qui n'a pas le registre. Huit messages
sont partis chiffrés pour un groupe d'une personne.

Deux gardes posées :

- `ensureGroup` **refuse de créer le groupe** si un participant n'a aucun
  appareil actif, et lève avant que `mls_since` soit posé — l'envoi retombe
  alors en clair, ce qui est légitime tant que rien n'est engagé. La
  conversation basculera d'elle-même quand l'autre aura ouvert l'app une fois.
- `reconcileMembership` écrit désormais `participant_sans_appareil` quand il
  croise ce cas, pour les conversations déjà basculées.

Fichiers : [mls_conversation_service.dart](lib/core/crypto/mls/mls_conversation_service.dart)
(`refuserSiQuelquUnNePeutPasSuivre`). Couvert hors appareil par
[bascule_refusee_sans_appareil_test.dart](test/core/crypto/bascule_refusee_sans_appareil_test.dart)
(6 cas, dont la garde d'ordre : la vérification doit précéder la création).

- [ ] **L'autre met à jour et ouvre l'app une fois** : il s'inscrit dans
      `mls_devices`, et le message suivant fait basculer la conversation, avec
      **deux** lignes dans `conversation_devices`.
- [ ] **Il lit bien ce qui a été envoyé après la bascule**, et rien d'avant.
- [ ] **Groupe à plusieurs** : un seul membre sans appareil suffit à retenir
      la bascule. Vérifier que ça ne bloque pas l'envoi, seulement le
      chiffrement.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Une conversation ne bascule plus sans ses participants (2026-09-15) »).

---

## ⬜ Code de sécurité d'un appareil MLS (phase 7, 2026-09-15)

**Priorité P1** · importance 4/5 — MLS ne protège pas contre un serveur qui
substituerait un KeyPackage : rien, dans le protocole, ne dit qu'une clé
servie est bien celle de la personne annoncée. La comparaison hors bande est
la seule réponse, et elle est maintenant affichée sous chaque ligne du
registre MLS (écran Appareils) : 60 chiffres en 12 groupes, comparables de
vive voix.

*Bloqué : demande deux téléphones sur deux comptes. Le scan **est** branché
(`QrCodeParser` reconnaît `dn-mls-verif:`, le scanner compare sur place au
lieu de naviguer) et le QR **s'affiche** — les deux vérifiés le 2026-09-15.
Ce qui manque est le geste complet : montrer sur un écran, scanner avec
l'autre.*

Fichiers : [mls_code_securite.dart](lib/core/crypto/mls/mls_code_securite.dart),
[devices_screen.dart](lib/features/settings/presentation/screens/devices_screen.dart)
(`_CodeSecurite`), [mls_device_registry.dart](lib/core/crypto/mls/mls_device_registry.dart)
(`signatureKey`).

- [ ] **Deux téléphones, deux comptes** : le code affiché pour l'appareil de
  A, lu sur le téléphone de B, est le même que celui que A voit chez lui.
  ⬜ Passe du 2026-09-22 (~03:20–03:35), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : **pas faisable sans caméra** — l'app ne montre le code que
  de ses PROPRES appareils (`DevicesScreen`, sans paramètre de compte) ; B ne
  peut le comparer qu'en scannant le QR de A. Et côté Salim, l'écran Appareils
  n'affiche **aucun** code : voir « L'autre bout n'est pas listé » (phase 5).
- [ ] **Après réinstallation** de l'application sur A : son code change, et
  le téléphone de B le signale (« la clé de cet appareil a changé »).
- [ ] **Un appareil sans clé publiée** (ligne ancienne) affiche « code
  indisponible », jamais une suite de chiffres.
- [ ] **Thème sombre** : le code et l'avertissement restent lisibles.
- [ ] **Scan d'un code** depuis le scanner QR du profil : le résultat
  s'affiche **sur place**, sans quitter l'écran.
- [ ] **Scan d'un QR étranger** (profil, lien) : le message dit que ce n'est
  pas un code de vérification — **jamais** « ne correspond pas », qui serait
  une accusation fausse.
- [ ] **Après un scan qui correspond** : la vérification est retenue, et
  l'avertissement « la clé a changé » apparaît si l'app est réinstallée en
  face.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Code de sécurité d'un appareil MLS (phase 7, 2026-09-15) »).

---

## ✅ Le bandeau « 1 message non lu » d'une conversation basculée (2026-09-15)

**Priorité P1** · importance 3/5 — Trouvé par le premier essai réel de MLS,
et par rien d'autre : ni les tests ni le banc ne pouvaient le voir.

Corrigé en sautant les messages système, ce qui aligne le fil sur la règle du
serveur et corrige aussi le rang du premier non-lu : le bandeau se posait
**sur** le séparateur, et l'écran s'y déroulait.

Fichiers : [conversation_screen.dart](lib/features/messages/presentation/screens/conversation_screen.dart)
(`compterNonLus`). Tenu par
[non_lus_fil_test.dart](test/features/messages/non_lus_fil_test.dart) (6 cas).

- [ ] **La pastille de la liste** suit la même règle et retombe à zéro.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Le bandeau « 1 message non lu » d'une conversation basculée (2026-09-15) »).

---

## ⬜ MLS ouvert pour un seul compte (phase 5, 2026-09-15)

**Priorité P0** · importance 5/5 — Le drapeau `featureFlags.mlsMessages` est
global, et l'ouvrir fait **basculer sans retour** : `conversations.mls_since`
ne se remet jamais à NULL, et le legacy refuse ensuite d'y écrire. Vérifier
MLS sur un téléphone demandait donc de basculer la production entière.
Vérifier ne doit pas être un point de non-retour.

`featureFlags.mlsMessagesComptes` est une liste d'uid Firebase pour qui MLS
est actif, le drapeau global restant fermé. La lecture est **tolérante et
fermée par défaut** : clé absente, valeur nulle ou mal typée valent liste
vide, donc personne. Le test a d'ailleurs trouvé avant livraison qu'un `as
List?` sur une chaîne **levait**, ce qui aurait emporté la lecture de tous
les drapeaux.

⚠️ **Retirer un compte de la liste ne débascule pas ses conversations.** La
liste décide de basculer, pas de revenir. Un compte qu'on y met est engagé.

Fichiers : [media_dechiffre_provider.dart](lib/features/messages/presentation/providers/media_dechiffre_provider.dart)
(`mlsMessagesActifsProvider`),
[app_settings_entity.dart](lib/features/admin/domain/entities/app_settings_entity.dart),
[app_settings_model.dart](lib/features/admin/data/models/app_settings_model.dart).
Couvert hors appareil par
[drapeau_mls_par_compte_test.dart](test/features/messages/drapeau_mls_par_compte_test.dart)
(8 cas).

- [ ] **Compte non listé** : rien ne change, les messages partent par le
      chemin d'aujourd'hui. À vérifier AVANT d'ouvrir pour qui que ce soit.
- [ ] **Écran Appareils d'un compte hors drapeau déjà en MLS** (Pixel de
      Salim, sur un build qui porte le correctif) : la liste Signal, puis la
      section « Discussions chiffrées de bout en bout » avec ses 2 appareils
      actifs et leur code de sécurité ; lisible en sombre à la police 1,3 ;
      « Révoquer » absent sur « CET APPAREIL ».
- [ ] **Prise d'effet sans relancer l'app** : le drapeau est lu à chaque
      appel, pas au démarrage.
- [ ] **Écran d'administration** : la liste n'y est pas éditable. Juger s'il
      faut l'y mettre ou la laisser en écriture directe.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ MLS ouvert pour un seul compte (phase 5, 2026-09-15) »).

---

## ⬜ L'état MLS ne quitte plus l'appareil (sauvegardes, 2026-09-15)

**Priorité P1** · importance 5/5 — La base SQLite du moteur
(`<support>/mls/<uid>.sqlite`) porte la clé privée de signature de l'appareil,
les secrets d'epoch et les arbres de groupe. Le manifeste ne portait **aucun**
attribut de sauvegarde, donc `android:allowBackup` valait `true` : le fichier
partait dans la sauvegarde Google et dans le transfert vers un téléphone neuf.
Une exfiltration sans root, sans accès physique, et que rien ne signale.

Il est désormais exclu des deux, par deux fichiers distincts — Android 12 a
séparé la sauvegarde cloud du transfert d'appareil et **ignore**
`fullBackupContent` dès l'API 31, donc n'en corriger qu'un laisserait la
moitié du chemin ouverte.

**Ce que ça ne remplace pas** : le fichier reste en clair sur l'appareil. Le
plan (§ 7.4) veut une clé maître dans le Keystore, et les deux voies ont été
mesurées sans qu'aucune soit ouverte : SQLCipher ne se compile pas sur le
poste (OpenSSL vendu refuse le `perl` de Git Bash), et chiffrer les valeurs
par le `Codec` casserait les lectures (les clés de recherche passent par le
même codec et servent de critère d'égalité). Une troisième contrainte pèse sur
les deux : l'isolate de notification n'a pas de `MethodChannel`, donc pas
d'accès au Keystore.

Fichiers : [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml),
[regles_sauvegarde.xml](android/app/src/main/res/xml/regles_sauvegarde.xml),
[regles_extraction_donnees.xml](android/app/src/main/res/xml/regles_extraction_donnees.xml),
[mls_engine_provider.dart](lib/core/crypto/mls/mls_engine_provider.dart).
Verrouillé par
[etat_mls_hors_sauvegarde_test.dart](test/core/crypto/etat_mls_hors_sauvegarde_test.dart).

- [ ] **La sauvegarde exclut bien le dossier** : `adb shell bmgr backupnow
      com.diasponiger.diasponiger`, puis vérifier que `files/mls` n'est pas
      dans le jeu sauvegardé. Le test de structure lit le manifeste, pas le
      comportement d'Android.
- [ ] **Le reste de l'app est toujours sauvegardé** : l'exclusion ne doit
      porter que sur `mls/`, pas avoir désactivé la sauvegarde en entier.
- [ ] **iOS : écrit le 2026-09-16, JAMAIS COMPILÉ.** `Library/Application
      Support` part dans iCloud, et l'exclusion demande
      `NSURLIsExcludedFromBackupKey`, sans API Dart : le drapeau se pose donc
      par le canal natif existant (`AppDelegate.swift`), et le moteur le
      réclame à l'ouverture du dossier. Ce dépôt n'a pas de Mac — le Swift
      n'est ni compilé ni éprouvé. Sur Android l'appel n'existe pas et retombe
      dans le `catch`, donc il ne peut rien casser ici.
      À vérifier au premier build iOS : que l'appel ne lève pas, puis que le
      dossier est bien absent d'une sauvegarde (Xcode › Devices, ou une
      restauration sur un second appareil).

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ L'état MLS ne quitte plus l'appareil (sauvegardes, 2026-09-15) »).

---

## ⬜ Recherche, favoris et galerie d'une conversation chiffrée (2026-09-15)

**Priorité P1** · importance 4/5 — **Trois écrans posaient au serveur une
question qu'il ne peut pas entendre**, et prenaient sa réponse vide pour une
vérité. Aucun ne levait.

Les trois interrogent désormais aussi le cache Hive, seul endroit où le clair
existe, et gardent le résultat serveur pour l'historique d'avant le
séparateur de bascule, que le cache peut ne pas couvrir en entier. Les deux
sources se dédoublonnent par identifiant, le cache gagne.

**La limite est inhérente, pas un défaut** : on ne trouve que ce que
l'appareil a déjà déchiffré. Une conversation ouverte pour la première fois
sur un téléphone neuf n'a rien à fouiller tant qu'on n'a pas remonté le fil.

Fichiers : [message_repository_impl.dart](lib/features/messages/data/repositories/message_repository_impl.dart)
(`searchMessagesInConversation`, `getStarredMessages`, `getMediaMessages`),
[mls_gateway.dart](lib/core/crypto/mls/mls_gateway.dart) (`favorisParmi`).
Couvert hors appareil par
[lectures_conversation_chiffree_test.dart](test/features/messages/lectures_conversation_chiffree_test.dart)
(11 cas).

- [x] **Chercher un mot d'avant la bascule** : il ressort aussi, sous le
      séparateur.
      ⛔ **Défaut nouveau** : « Yo » ressort aussi une ligne qui affiche le
      **ciphertext brut** « v1:/YO6lTZ8e0b69CLOgLRo7Q==:SEEiIX1Hm… » (04:57,
      Salim). Cause, par le code : `searchMessagesInConversation` garde le
      résultat serveur, un `ilike` sur `data->>content` — pour un ancien message
      chiffré (repli AES `v1:`), c'est le chiffré qui matche (« YO » dans le
      base64, sans casse) et il est affiché tel quel, ni déchiffré ni écarté
      (`message_repository_impl.dart`, `message_supabase_datasource.dart`). Les
      heures sans date (16:02, 04:57, 23:39, 15:36) ne disent pas de quel jour.
      **Corrigé le 2026-09-22** : la recherche serveur déchiffre
      (`_msgFromRowAsync`) puis ne garde que les lignes dont le CLAIR contient
      le mot (`garderSiLeClairContient`, qui écarte aussi les marqueurs
      d'échec). À revoir sur un build qui le porte : « Yo » ne doit plus
      ressortir de chiffré, « message » ne doit pas ressortir « [Message
      illisible] ».
- [ ] **Retirer l'étoile** : il disparaît de la liste.
      ⛔ **Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : ÉCHEC.** Étoile retirée de PJ1 (ligne supprimée de
      `mls_message_stars`), liste rouverte : PJ1 **y est toujours**. Il n'en sort
      qu'après relance à froid. Cause, par le code : `starredMessagesProvider`
      (`message_provider.dart`) est un `FutureProvider.family` **sans
      `autoDispose`**, que rien n'invalide — la liste est figée sur son premier
      calcul pour toute la vie du processus (vaut aussi dans l'autre sens : un
      message étoilé après la première ouverture n'y entrerait pas).
      **Corrigé le 2026-09-22** : `autoDispose` + invalidation dans
      `toggleStar`. À revoir sur un build qui le porte : retirer, rouvrir la
      liste → parti ; étoiler après une première ouverture → présent.
- [ ] **Galerie d'une conversation basculée** : les photos chiffrées y sont,
      et s'ouvrent en plein écran. Croiser avec l'entrée « Pièces jointes
      chiffrées ».
- [ ] **Fil jamais ouvert sur cet appareil** : les trois écrans ne montrent
      rien de la partie chiffrée. Juger si c'est dit de façon acceptable, ou
      s'il faut un mot d'explication.
- [ ] **Fil très long** : mesurer le temps de la recherche locale, le cache
      étant parcouru en entier à chaque frappe.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Recherche, favoris et galerie d'une conversation chiffrée (2026-09-15) »).

---

## ⬜ L'appartenance MLS se réconcilie au moment du changement (phase 8, 2026-09-15)

**Priorité P2** · importance 3/5 — Jusqu'ici la réconciliation d'appartenance
ne tournait qu'à l'envoi : exclure quelqu'un d'un groupe ne le sortait de
l'arbre MLS qu'au prochain message de quelqu'un d'autre, et un arrivant
attendait ce même message pour recevoir son Welcome. Tardif, jamais faux — le
retrait précède le chiffrement, donc l'exclu ne lit rien de neuf.

`MlsGateway.appartenanceChangee` ferme l'écart, accrochée au **flux de la
conversation** et non aux six appelants qui touchent à l'appartenance :
la moitié d'entre eux écrit `group_members`, et c'est un déclencheur serveur
qui recopie dans `conversations.participant_ids` — aucun site d'appel Dart ne
le voit passer, la ligne de conversation les voit tous.

Fichiers : [mls_gateway.dart](lib/core/crypto/mls/mls_gateway.dart)
(`appartenanceChangee`),
[message_repository_impl.dart](lib/features/messages/data/repositories/message_repository_impl.dart)
(`getConversationStream`). Couvert hors appareil par
[mls_appartenance_test.dart](test/core/crypto/mls_appartenance_test.dart)
(8 cas, dont la garde de câblage).

- [ ] **Exclusion pendant que l'écran est ouvert** : A et B dans un groupe
      basculé, l'écran de A ouvert ; exclure B depuis la fiche des membres.
      Sans envoyer un seul message, `mls_commits` doit gagner une ligne au
      nouvel epoch, et `conversation_devices` passer l'appareil de B hors
      `active`.
- [ ] **Arrivée pendant que l'écran est ouvert** : ajouter C au même groupe ;
      un `mls_welcomes` doit apparaître pour son appareil sans qu'aucun
      message ne soit envoyé.
- [ ] **Deux téléphones en ligne sur le même changement** : les deux
      réagissent, un seul gagne l'epoch. Le perdant doit écrire
      `commit_perdu` dans `mls_diagnostics` et **ne rien casser** — c'est
      l'arbitrage du § 5.4, jamais vu à deux vrais appareils.
- [ ] **Coût à l'ouverture** : ouvrir une discussion de groupe nombreuse ne
      doit lancer AUCUN balayage des appareils des participants (la première
      vue n'agit pas). À lire dans les journaux réseau, pas à l'œil.

---

## ⬜ Banc MLS bout en bout contre la vraie base (phase 3, 2026-09-15)

**Priorité P1** · importance 5/5 — Le banc `test/banc/mls_banc_test.dart`
joue trois appareils sans écran (Alice, Bob, Charlie) contre la base de
production, avec le RLS réel et le vrai moteur Rust chargé dans le processus
de test. Il couvre le parcours nominal 1:1, le refus du legacy sur une
conversation basculée (`mls_since`), le message reçu deux fois, l'AAD
déplacé, les messages hors ordre, le moteur détruit et recréé entre deux
envois, l'ajout d'un troisième membre, un message d'un epoch passé reçu
après le commit suivant, la réinstallation d'un appareil (nouvelle
identité, ancienne retirée), le commit concurrent (23505), la révocation et
le rattrapage après coupure. Ce n'est pas un test appareil au sens strict,
mais il est listé ici parce qu'il **ne tourne pas dans `flutter test`
ordinaire** : il lui faut la migration de transport appliquée, trois
sessions authentifiées et la bibliothèque Rust compilée pour le poste.

Fichiers : [mls_banc_test.dart](test/banc/mls_banc_test.dart),
[sessions.mjs](tools/mls_banc/sessions.mjs),
[mls_conversation_service.dart](lib/core/crypto/mls/mls_conversation_service.dart),
[mls_delivery.dart](lib/core/crypto/mls/mls_delivery.dart), migration
`20260915120000_mls_transport.sql`.

Protocole :

```bash
cd rust && cargo build && cd ..                  # bibliothèque hôte
node tools/mls_banc/sessions.mjs > "$TEMP/sessions.json" \
  && MLS_BANC_SESSIONS="$TEMP/sessions.json" flutter test test/banc
node tools/mls_banc/purge.mjs --confirmer        # données laissées en base
node tools/purge_comptes_sonde.mjs --confirmer   # comptes sonde-banc-*
```

Les jetons de sonde expirent en **six minutes** : fabriquer le fichier et
lancer le banc dans la même commande, jamais à l'avance.

- [ ] **Il reste vert deux jours de suite** (les KeyPackages, les sessions
  et les comptes sonde sont neufs à chaque exécution).
- [ ] **Relancer après tout changement du moteur ou du transport.** C'est le
  seul endroit où les deux défauts ci-dessous pouvaient apparaître.

**Ce que le premier passage a trouvé, et qu'aucun test unitaire ne voyait :**

1. **Les KeyPackages survivaient à une réinstallation.** La ligne
   `mls_devices` est mise à jour avec la nouvelle identité MLS, mais ses 51
   paquets restaient publiés — leurs secrets privés partis avec l'ancienne
   base, et portant l'ancienne clé de signature. Le compteur de
   réapprovisionnement les voyait (51 ≥ 10, rien à faire), un membre en
   réclamait un, et l'ajout échouait sur `CreateCommitError` : la clé était
   déjà dans l'arbre. Trois cas sur douze tombaient dessus, tous avec la même
   erreur, sans que rien ne désigne la cause. Corrigé : `ensureRegistered` lit
   l'identité avant de l'écraser et purge les paquets quand elle change.
2. **Une révocation refusée par le RLS ne levait pas.** Un compte tentant de
   révoquer l'appareil d'un autre touchait zéro ligne, sans erreur, et
   l'écran aurait annoncé « appareil révoqué ». Corrigé : `revoke` lit les
   lignes modifiées et lève si elles sont vides.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Banc MLS bout en bout contre la vraie base (phase 3, 2026-09-15) »).

---

## ⬜ Registre d'appareils MLS — inscription à la connexion, KeyPackages, écran (phase 2, 2026-09-15)

**Priorité P1** · importance 4/5 — Première entrée du moteur Rust (OpenMLS,
Flutter Rust Bridge) dans l'app : à chaque connexion, l'appareil s'inscrit
dans `mls_devices` (clé de signature publique, credential, nom, plateforme)
et publie 50 KeyPackages + 1 « dernier recours » dans `mls_key_packages`.
L'écran Réglages › Sécurité › Appareils affiche ce registre sous la liste
Signal, avec révocation. Rien n'a tourné sur un appareil : ni le chargement
de la bibliothèque native au démarrage de l'app réelle (seul le harnais du
spike a tourné), ni l'inscription, ni l'écran. La migration
`20260915100000_mls_registre_appareils.sql` doit être appliquée AVANT
(`supabase db push --linked`, par Salim) ; sans elle, l'inscription échoue
quatre fois puis écrit… dans `mls_diagnostics`, qui n'existe pas non plus —
donc rien, et `MlsDeviceRegistry: enregistrement échoué` dans logcat en
debug seulement.

Fichiers : [mls_engine_provider.dart](lib/core/crypto/mls/mls_engine_provider.dart),
[mls_device_registry.dart](lib/core/crypto/mls/mls_device_registry.dart),
[devices_screen.dart](lib/features/settings/presentation/screens/devices_screen.dart),
[auth_provider.dart](lib/features/auth/presentation/providers/auth_provider.dart)
(`_initializeE2EE`), crate `rust/`.

- [ ] **Révocation depuis un second appareil** (ou depuis SQL) : la ligne
  passe barrée « Révoqué », ses paquets non consommés ont disparu (trigger),
  et au redémarrage l'appareil révoqué **ne se réinscrit pas** (ligne
  `mls_diagnostics` `appareil_revoque_au_demarrage`).
  *Tenté le 2026-09-15, non fait : la seule voie disponible était un `update`
  sur la table de production, refusé par le classificateur de permissions
  (motif « Modify Shared Resources »). Le chemin est couvert par le banc
  (`mls_banc_test.dart`), jamais sur l'appareil. À refaire quand un second
  téléphone portera le même compte, la révocation passant alors par l'écran.*
- [ ] **Compte neuf** : le premier échange de session échoue toujours une
  fois (piège connu) ; l'inscription doit quand même aboutir grâce aux
  réessais (3 s, 6 s, 9 s).
- [ ] **Dette consignée, à ne pas oublier** : la base SQLite du moteur
  (`<support>/mls/<uid>.sqlite`, clé privée de signature comprise) est en
  clair dans le répertoire privé de l'app. La clé maître Keystore/Keychain
  (plan § 7.4) n'est toujours pas posée — les trois obstacles mesurés le
  2026-09-15 sont détaillés dans l'entrée « L'état MLS ne quitte plus
  l'appareil ». Depuis cette date le fichier est au moins exclu des
  sauvegardes.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Registre d'appareils MLS — inscription à la connexion, KeyPackages, écran (phase 2, 2026-09-15) »).

---

## ⬜ Signal remis en service : la garde de session sur les lectures de clés (2026-09-14)

**Priorité P0** · importance 5/5 — Le chiffrement de bout en bout était mort en production : mesuré, **aucun** message ne passait par Signal, tout partait en repli AES. *Bloqué : deux comptes (le destinataire doit publier ses clés depuis SON appareil).*

Corrigé : garde sur les quatre lectures (`getActiveDevices`,
`fetchPreKeyBundle`, `fetchAllPreKeyBundles`,
`_countPublishedOneTimePreKeys`) avec la variante **bornée**
`ensureReadableSession()` — le chemin d'envoi ne doit pas geler — et sur
l'écriture `rotateSignedPreKey` avec `ensureAuthenticated()`. Verrouillé par
`test/core/services/e2ee/acces_supabase_garde_test.dart`, qui refuse tout
nouvel accès Supabase non gardé dans ce fichier.

**À vérifier sur appareil** — rien de tout cela n'est prouvé hors base :

- [ ] **Deux comptes, deux téléphones** : s'envoyer un message texte, puis
      vérifier en base que le message porte `encryptionLevel = 'e2ee'` et non
      `'aes'`. C'est LE test : c'est exactement ce qui ne s'est jamais produit
      depuis le 2026-08-15.
- [ ] **Premier envoi après lancement à froid**, dans les secondes qui suivent
      l'ouverture — c'est la fenêtre où la session Supabase n'est pas encore
      établie, donc celle que le correctif vise. Un `'aes'` ici signifie que la
      borne de 3 s est trop courte sur ce réseau, pas que la garde manque.
- [ ] **Envoi hors ligne** : doit continuer de partir en repli AES sans
      blocage ni attente perceptible. La garde bornée ne doit jamais retarder
      l'envoi — si l'interface fige ~3 s avant que la bulle apparaisse, la
      borne est mal placée.
- [ ] **Groupe** : les messages resteront en `aes` tant que les Sender Keys ne
      sont pas distribuées (`e2ee_sender_key_distributions` est vide en prod,
      voir « Distribution des Sender Keys : jamais rien en base »). Vérifier
      seulement qu'ils partent toujours.
- [ ] **4 comptes sur 35** ont un appareil actif sans `identitySigningKey` et
      resteront en AES par refus explicite : leurs 7 appareils datent d'avant
      le 2026-08-20. Vérifier qu'un de ces comptes republie bien sa clé de
      signature au lancement (self-healing de `_ensurePublishedToSupabase`).

---

## ⬜ Distribution des Sender Keys : la même porte, une marche plus loin (2026-09-14)

**Priorité P1** · importance 4/5 — Tout message de groupe retombe en repli AES, sans que rien ne le signale. *Bloqué : deux comptes dans un même groupe.*

Corrigé dans `lib/core/services/e2ee/sender_key_service.dart` : garde bornée
sur `distributeSenderKey` (écriture, mais avec repli AES, donc bornée) et sur
`fetchPendingDistributions` — cette dernière était la plus vicieuse des deux,
puisqu'un relevé vide fait conclure « aucune distribution en attente » et
laisse les messages des autres illisibles.

**Ce qui reste fragile, et n'est pas corrigé :**

`distributeSenderKeyToGroup` n'accepte la clé que si **chaque** membre l'a
reçue — délibéré, un message qu'une partie du groupe ne peut pas lire serait
pire. Mais sur un groupe de 17 personnes, cela demande 16 sessions 1:1
établies d'un coup, et un seul membre sans `identitySigningKey` (4 comptes sur
35) suffit à maintenir tout le groupe en AES, indéfiniment.

- [ ] Ouvrir un groupe à deux comptes, envoyer un message, puis vérifier
      qu'une ligne apparaît dans `e2ee_sender_key_distributions` — elle
      disparaît après traitement par le destinataire, donc regarder vite, ou
      côté destinataire avant qu'il n'ouvre le groupe.
- [ ] Vérifier que le message de groupe porte alors `encryptionLevel = 'e2ee'`.
- [ ] **Groupe à plus de deux membres** dont un compte ancien (appareil
      enregistré avant le 2026-08-20) : vérifier si le groupe reste en AES, et
      si le compte rendu de distribution le dit à l'utilisateur au lieu de se
      taire.
- [ ] **Redistribution avant traitement** : la table n'a **aucune policy
      UPDATE**, or l'écriture est un `upsert` sur
      `(group_id, sender_id, recipient_id)`. Tant que le destinataire n'a pas
      consommé la ligne, une seconde distribution tombe sur le chemin UPDATE
      et devrait être refusée (42501). Non reproduit — à provoquer en laissant
      un destinataire hors ligne pendant deux envois.

---

## ⬜ Citations et modifications : plus de texte en clair (2026-09-09)

**Priorité P0** · importance 4/5 — Si le correctif ne tient pas, une réponse ou une modification laisse le texte en clair en base, ou le message modifié devient illisible chez le destinataire et la citation disparaît de la bulle. *Bloqué : deux comptes (côté destinataire).*

**1. Répondre recopiait le message cité en clair.** `replyToMessageData`
contient le texte **déjà déchiffré** du message auquel on répond : chaque
réponse en déposait une copie lisible. Une conversation active en laissait donc
une trace message après message. La citation rejoint le blob `encAnnexes`, dans
les **cinq** envois qui l'acceptent : texte, média, note vocale, localisation,
sticker.

**2. Modifier un message annulait son chiffrement.** `editMessage` réécrivait
`data['content']` en clair tout en laissant `encryptionLevel` annoncer 'e2ee',
et gardait le texte d'avant dans `editHistory`. Le texte modifié repasse
maintenant par le chemin de l'envoi (`_encryptContent`), et l'historique ne
garde plus que la date — rien ne l'affichait.

- [ ] **Répondre, dans les cinq cas** : à un texte, à une photo (avec légende),
  **Localisation : composition et citation vues le 2026-09-14, mais envoi
  NON confirmé — mesure écartée.** Sur SM A515F (build 19), l'appui long sur
  la carte « 3010 Boul Lévesque E » propose bien « Répondre », et la bulle
  composée affiche la citation attendue : « Vous — 📍 Position » au-dessus du
  texte. Mais le message est resté en « Envoi… » et **n'est jamais arrivé en
  base** ; au rechargement du fil il avait disparu. ⚠️ Pendant cette fenêtre,
  **un autre agent pilotait le même téléphone** (Galerie active, événements
  clavier vers l'app dans les journaux) : impossible de distinguer un défaut
  d'envoi d'une interférence. À refaire sur un appareil libre — c'est la
  règle de ce fichier, une mesure prise à deux pilotes se jette.
  Restent donc : photo avec légende, note vocale, sticker.
  à une note vocale, à une localisation, à un sticker. La citation doit
  s'afficher au-dessus de la bulle, chez l'expéditeur **et** chez l'autre.
- [ ] ⚠️ **L'aperçu de la liste des discussions garde l'ancien texte après une
  modification** (vu le 2026-09-11 sur le Pixel : la ligne « Sim A » affichait
  encore `REPONSE-TEXTE-1756` alors que la bulle disait `…-EDIT1`).
  **Confirmé aussi en groupe** le même jour : la ligne « Testeurs » annonçait
  `GRP-EDIT-1817` quand la bulle portait `…-EDIT`. Ce n'est donc pas propre au
  1:1.
  `lastMessage` n'est pas réécrit par `editMessage` — cohérent avec la liste
  « pas encore branchés » de « Clés de repli dérivées ».
- [ ] ⚠️ **« Modifier » est introuvable sans le savoir** : l'entrée n'est ni
  dans le menu d'appui long ni dans un sous-menu nommé — il faut toucher
  « Autres actions », **puis faire défiler** la feuille jusqu'en bas (elle
  vient après Infos du message, Partager, Sélectionner). Trois essais y ont
  été perdus ici. À rapprocher de la maquette : est-ce voulu ?

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Citations et modifications : plus de texte en clair (2026-09-09) »).

---

## ⬜ Cartes de partage chiffrées au repos (2026-09-09)

**Priorité P1** · importance 4/5 — La carte partagée disparaît de la bulle sans aucune erreur (dès que l'autre lit le message ou après un redémarrage), ou son contenu reste lisible en clair côté serveur. *Bloqué : deux comptes.*

Une carte de partage (post, événement, annonce, aperçu de lien) ne transite pas
par `content` : elle ne passait donc pas par Signal et partait **en clair**
dans `messages.data`. Elle voyage désormais dans un blob unique `encAnnexes`,
chiffré avec la clé dérivée de la conversation — même famille que les aperçus,
la localisation et les médias.

Les deux formats cohabitent sans migration : un message d'avant garde ses
champs en clair et se relit tel quel. Un client plus ancien n'affichera pas la
carte, mais le texte reste lisible.

C'est le chemin le plus silencieux du dépôt : une carte qui n'arrive pas ne
produit **aucune erreur**, ni à l'écran ni dans logcat.

- [ ] **Aller-retour réel entre deux comptes** : partager un groupe depuis le
  téléphone A vers un 1:1 et vers un groupe ; vérifier sur le téléphone B que
  la carte s'affiche avec image et titre, et que le tap ouvre l'écran.
  (Deux appareils = deux comptes, cf. « Comment tester ».)
- [ ] **La carte survit à un accusé de lecture** : c'était le piège. Le flux de
  mises à jour rend la ligne BRUTE ; sans report explicite, la carte
  disparaissait de la bulle dès que l'autre lisait le message.
  (`message_provider.dart`, `_listenForMessageUpdates`)
- [ ] **La carte survit à un redémarrage** (relecture depuis le cache Hive puis
  depuis le serveur) et à un défilement qui recharge la page de messages.
- [ ] **Hors ligne au moment de l'envoi** : la clé dérivée vient d'un
  aller-retour réseau (`crypto-keys`). Vérifier ce que devient un partage
  envoyé sans réseau, puis à la reconnexion.
- [ ] **En base, plus rien de lisible** : `select data from messages where
  data ? 'encAnnexes' limit 1` ne doit montrer ni titre, ni URL, ni nom.
- [ ] **« Supprimer pour tout le monde » efface aussi la carte** : la ligne ne
  doit plus porter `encAnnexes` après suppression.
- [ ] **Mesure du repli** : quelle proportion des blobs est au format dérivé
  (`v<n>:`) plutôt qu'à la clé globale. Tant que le repli global sert, la
  confidentialité n'est pas acquise — la clé globale est extractible de l'APK.

---

## ⚠️ La légende d'une photo/vidéo part EN CLAIR (2026-09-09, non corrigé)

**Priorité P0** · importance 4/5 — Aujourd'hui la légende de chaque photo, vidéo ou fichier est stockée en clair sur le serveur alors que l'app l'étiquette chiffrée — y compris dans les conversations qui ont une vraie session Signal. *Bloqué : correctif pas encore écrit.*

Trouvé en vérifiant le point « médias de groupe » laissé ouvert dans « Un groupe dont on est le seul membre refuse TOUS les messages ».
`sendMediaMessage` (`message_supabase_datasource.dart:1093`) écrit
`'content': caption ?? ''` **tel quel** dans la ligne `messages`, et pose
`'encryptionLevel': 'aes'` en dur. Il n'appelle jamais `_encryptContent`,
contrairement à `sendTextMessage`. Le repository ne chiffre rien non plus en
amont : `caption` traverse `sendFileMessage`
(`message_repository_impl.dart:429`) sans être touché.

Donc : le texte d'un message **texte** est chiffré (Signal quand une session
existe, repli AES sinon) ; la **légende** d'une photo, d'une vidéo ou d'un
fichier, elle, arrive en clair côté serveur — avec une étiquette
`encryptionLevel: 'aes'` qui annonce le contraire. Les annexes voisines
(citation, carte d'événement, aperçu de lien) sont, elles, bien chiffrées par
`_annexesChiffreesPour` : c'est le seul champ oublié.

**Pas corrigé ici, volontairement** : toucher au chemin d'envoi des médias
demande sa propre passe et une vérification appareil (photo, vidéo, fichier,
note vocale, avec et sans légende, 1:1 et groupe). Un correctif bâclé casse
l'envoi de médias pour tout le monde.

- [ ] Chiffrer `caption` par `_encryptContent`, comme le fait
      `sendTextMessage`, et poser le `encryptionLevel` réellement obtenu.
- [ ] Vérifier que les anciennes légendes en clair restent lisibles (le
      déchiffrement doit tolérer les deux formes).
- [ ] Vérifier l'aperçu de notification, qui reconstruit le texte côté
      Postgres (`decrypt_aes_fallback`).

---

## ⬜ Transfert des clés par QR, sans passphrase (2026-09-08)

**Priorité P1** · importance 3/5 — Un utilisateur qui change de téléphone ne récupère pas ses clés et perd la lecture de tout son historique chiffré, ou tombe sur un plantage en scannant un code expiré ou étranger. *Bloqué : deux téléphones sur le même compte (Pixel déconnecté).*

Reprise des clés d'un téléphone à l'autre sans rien à retenir : l'**ancien**
affiche un QR, le **neuf** le scanne, et l'export complet du stockage sécurisé
voyage chiffré en AES-256-GCM par une clé qui ne quitte jamais le canal
optique. Le serveur ne relaie qu'un blob.

Raccourci utile pour y retourner sans naviguer :
`adb shell am start -a android.intent.action.VIEW -d "diasponiger:///settings/security/transfer/receive" com.diasponiger.diasponiger`
(le lien profond marche, testé).

Le reste demande **deux téléphones** connectés au **même compte** :

- [ ] **Le parcours complet, dans le bon ordre.** Sur l'**ancien** (connecté) :
      Réglages › Sécurité › Sauvegarde des clés › « Transférer vers un nouveau
      téléphone » — le code s'affiche. Sur le **neuf**, sans se connecter :
      « Récupérer depuis mon ancien téléphone » depuis l'écran de connexion,
      scanner le code, puis se connecter. Les clés doivent arriver toutes
      seules.
- [ ] **La permission caméra** sur le téléphone neuf, jamais accordée : elle
      doit être demandée au moment du scan, y compris hors session.
- [ ] **Le QR d'un autre compte est refusé** — « Ce code appartient à un autre
      compte » si l'appareil est déjà connecté ailleurs ; sinon le rendez-vous
      est oublié à la connexion sans rien casser.
- [ ] **Un code expiré** (attendre le quart d'heure de la purge, ou laisser
      l'écran de l'ancien tourner assez longtemps pour que le code affiché ait
      été remplacé deux fois) doit donner « Ce code a expiré », pas un
      plantage.
- [ ] **Le neuf lit enfin l'historique.** Après import, les bulles « clé de
      groupe introuvable » d'un fil de groupe doivent redevenir lisibles, et le
      bandeau de restauration disparaître.
- [ ] **Le code tourne.** Laisser l'écran de récupération ouvert deux minutes :
      le QR doit changer, et un scan du **code précédent** doit encore aboutir.
- [ ] **L'effacement explicite et sa marche arrière.** Sur l'ancien, après le
      transfert : « Effacer les clés de cet appareil » ; l'écran de sauvegarde
      doit alors montrer « Transfert récent », « Annuler le transfert » remettre
      les clés, et « Supprimer la copie » l'effacer pour de bon.
- [ ] **La ligne de rendez-vous ne survit pas.** Après un transfert réussi,
      `select * from e2ee_key_transfers` doit être vide pour ce compte.

---

## ⬜ Clés de repli dérivées, servies par `crypto-keys` (2026-09-06)

**Priorité P0** · importance 4/5 — L'envoi échoue dans une conversation neuve ou après réinstallation, un message part en clair hors ligne, ou les anciens messages deviennent illisibles ; les clés d'un compte peuvent survivre à sa déconnexion.

Chantier en cours : remplacer la clé AES globale (constante de l'APK, donc
lisible par tout utilisateur, donc **aucune confidentialité entre comptes**)
par des clés dérivées d'une racine qui ne quitte pas le serveur —
`K_conv(convId)` et `K_user(uid)`, HKDF-SHA256.

**Branché depuis le 2026-09-06** sur le chemin des messages : `encrypt1to1`,
`encryptGroup` et `encryptSelfNote` utilisent la clé dérivée quand elle est
disponible, et retombent sur la clé globale sinon. Le magasin est amorcé au
démarrage (`main.dart`, depuis le keystore, sans réseau) et rafraîchi après
connexion (`auth_provider._initializeE2EE`).

⚠️ **Tant que le repli sur la clé globale existe, la confidentialité n'est pas
acquise** : quelqu'un capable de faire échouer la récupération de clé obtient
un message chiffré avec la clé que tout porteur de l'APK sait lire. Le format
dit lequel a servi, donc le taux est mesurable :

```sql
SELECT count(*) FILTER (WHERE data->>'content' LIKE 'v%:%:%') AS derivee,
       count(*) FILTER (WHERE data->>'encryptionLevel' = 'aes') AS total
FROM messages;
```

Quand ce taux approche 100 %, le repli doit devenir un refus.

**Pas encore branchés** (toujours sur la clé globale, et lisibles : la lecture
accepte les deux formats) : `lastMessage`, la localisation et l'édition de
message dans `message_remote_datasource`, les comptes de paiement, la
sauvegarde de sessions Signal, la réponse rapide depuis notification.

- [ ] **Premier lancement hors ligne.** Installer, couper le réseau, tenter
      d'envoyer un message. Attendu : refus visible, jamais un message écrit en
      clair en base. C'est le mode de panne central de tout le chantier.
- [ ] **Réinstallation.** Désinstaller/réinstaller, se reconnecter, ouvrir une
      conversation ancienne : les messages d'avant doivent rester lisibles
      (lecture à deux clés) et les nouveaux partir chiffrés.
- [ ] **Nouvelle conversation.** Démarrer une conversation qui n'existait pas
      au dernier `rafraichir` : la clé doit être demandée à la volée, sans que
      l'envoi échoue.
- [ ] **Changement de compte** sur le même téléphone : après déconnexion, les
      clés du compte précédent ne doivent plus être lisibles (`vider()`).
- [ ] **Après le rechiffrement de l'existant** (migration `20260907100000`) :
      rouvrir une conversation ancienne. Les 32 messages rechiffrés doivent
      s'afficher normalement. S'ils virent tous à « [Message illisible] »,
      c'est que le `conversationId` ne descend pas jusqu'au déchiffrement —
      exactement le défaut corrigé le 2026-09-07, à re-vérifier là.
- [ ] **Messages du datasource hérité** (RTDB) : ils restent sur la clé
      globale par choix. Vérifier qu'ils s'affichent toujours, eux aussi.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Clés de repli dérivées, servies par `crypto-keys` (2026-09-06) »).

---

## ⬜ Clé AES de repli : Firebase Functions avait divergé (2026-09-06)

**Priorité P2** · importance 2/5 — Aperçu de notification en base64 ou générique, coordonnées de paiement illisibles — mais le chemin Postgres était déjà aligné et les transferts sont désactivés en prod. *Bloqué : deux comptes (réception d'un message AES).*

`functions/.env` portait une valeur de `ENCRYPTION_KEY` différente de celle du
client (`_sharedKeyString`, `lib/core/services/encryption_service.dart`). Les
deux font 32 octets, le format et le mode sont identiques (AES-256-CBC, PKCS7,
`ivB64:ctB64`) — seule la valeur divergeait, donc **rien ne le signalait** :
`decryptText` rend le texte chiffré tel quel quand la clé est fausse, sans
exception ni log.

**À vérifier sur appareil** — ce que le banc ne peut pas couvrir :

- [ ] Recevoir un message en repli AES (`encryptionLevel = 'aes'`) app en
      arrière-plan, et lire le **corps de la notification** : doit afficher le
      texte, pas du base64 ni « Nouveau message ». C'est le chemin Postgres
      (`decrypt_aes_fallback`), déjà aligné avant cette session — le test
      confirme qu'il l'est bien en pratique.
- [ ] Vérifier qu'un compte de paiement (`mobileNumber` / `iban` / `bic`,
      chiffrés avec cette même clé) se relit correctement après la correction.

`sendChatNotification` (trigger Firestore, `us-central1`) est **encore
déployée** et appelle `decryptText` — mais les messages vivent sur Supabase
depuis la migration, donc elle ne doit plus se déclencher. Si un aperçu push
correct apparaît malgré tout par ce chemin, c'est qu'elle reçoit encore du
trafic : à investiguer.

---

## Messages de groupe qui redeviennent indéchiffrables après réouverture (2026-08-13)

**Priorité P1** · importance 4/5 — Dès que les vraies sessions Signal / Sender Key tournent, des messages déjà lus redeviennent définitivement illisibles à chaque réouverture de conversation. *Bloqué : deux comptes (messages E2EE reçus).*

- [ ] Ouvrir une conversation de groupe avec un historique de messages
  texte de plusieurs membres, vérifier qu'ils se déchiffrent tous, puis
  **quitter et rouvrir la conversation** (ou tirer pour rafraîchir) → les
  mêmes messages doivent rester lisibles, pas basculer sur
  « 🔐 Message chiffré » / « session requise ».
- [ ] Faire défiler vers le haut pour charger une page plus ancienne
  (pagination `loadMore`) dans un groupe déjà ouvert → les messages
  récents déjà affichés restent lisibles pendant le chargement de la
  page suivante.
- [ ] Même scénario sur une conversation **1:1** (pas seulement groupe) —
  la cause racine (ratchet Signal à sens unique) s'applique aussi aux
  messages reçus en 1:1, pas seulement à l'écho de ses propres messages
  déjà couvert par `_reconcileEcho`.
- [ ] Redémarrer l'app à froid sur une conversation de groupe déjà lue →
  le cache local (Hive) doit resservir le texte déchiffré, pas une
  nouvelle tentative de déchiffrement en échec.

---

## E2EE & chiffrement (priorité haute — sécurité)

**Priorité P2** · importance 2/5 — Démarrage lent ou premier envoi raté juste après connexion, clés régénérées par-dessus une sauvegarde — la plupart de ces chemins ont toutefois tourné depuis, dans d'autres sessions.

- [ ] **`KeyBackupService.checkBackupPresence`** (commit `19b092c`) — logique de génération de clés à la connexion changée, pas de re-test device après coup.
- [ ] **Sauvegarde/restauration de clés E2EE bout-en-bout** — nécessite DEUX appareils sur le même build (le destinataire doit republier ses clés depuis SON device) ; seule la republication des clés propres a été validée jusqu'ici.
- [ ] **Déchiffrement réel du bandeau épinglé** (messages) — seul le repli « 🔐 Message chiffré » a été vu à l'écran (clés E2EE perdues sur un build debug réinstallé), jamais le contenu déchiffré effectif.

---

# 5. Appels

Appels 1:1 et de groupe : signalisation, bulle d'appel, WebRTC/TURN.

---

## ⬜ Appel entrant : le nom et la photo de l'appelant viennent de la base (2026-09-21)

**Priorité P1** · importance 4/5 — Fermeture d'une usurpation plein écran (faux appel sous le nom et le visage d'un proche). Les appels sont peu utilisés (dernier le 2026-08-15, 75 en tout), mais c'est l'écran d'appel natif qui est en jeu.

**Ce qui est posé, DÉPLOYÉ le 2026-09-21 :**

- `functions/appels.js` (fonctions pures) : nom et photo lus dans Supabase
  (`users`), blocage respecté (`blocked_users`), type ramené à
  audio/vidéo, identifiants vérifiés avant toute requête — ils partaient tels
  quels dans une URL PostgREST. `onCallUpdated` lit les participants d'AVANT
  la mise à jour et le nom de l'appelé en base. Banc
  `tools/rules_tests/appel_entrant.mjs` : 0 échec ; l'ancienne logique,
  retranscrite, en échoue 7 sur 11. Fonctions redéployées une à une,
  `ACTIVE`.
- `firestore.rules`, `calls/{callId}` : création bornée (`type`, statut,
  forme de `calleeId`, pas d'appel à soi-même) ; mise à jour limitée à
  `status`, `answeredAt`, `endedAt`, `endReason`, `durationSeconds`. Banc
  `tools/rules_tests/appels_firestore.mjs` : 6 échecs sur les règles de
  production, 0 sur les nouvelles, parcours nominal intact. Déployé, relu par
  l'API : identique au dépôt.

**À vérifier sur appareil :**

- [ ] un appel 1:1 sonne avec le VRAI nom et la vraie photo de l'appelant ;
- [ ] décrocher, refuser, raccrocher : l'appel suit son cours, et l'appelant
  refusé reçoit « X a refusé votre appel » avec le vrai nom ;
- [ ] un compte bloqué ne fait plus sonner celui qui l'a bloqué ;
- [ ] appelé occupé : l'appel échoue proprement (statut `busy`).

---

## ⬜ Les appels de GROUPE restaient lançables alors que le 1-à-1 était en pause (2026-09-14)

**Priorité P3** · importance 2/5 — Signalé par Salim : « les groupes possèdent
toujours les icônes des appels ». L'en-tête d'une discussion de groupe affichait
encore les deux boutons (audio, vidéo) alors que les mêmes boutons avaient été
masqués en 1-à-1 un mois plus tôt.

Commenté au même format que le 1-à-1 (code conservé, `TODO(appels)` greppable),
dans [conversation_screen.dart](lib/features/messages/presentation/screens/conversation_screen.dart) :
les deux `IconButton` de l'AppBar, la méthode `_startGroupCall`, et les deux
imports `group_calls/` devenus inutilisés.

- [ ] Ouvrir une discussion de **groupe** : plus aucune icône d'appel dans
      l'en-tête, seul le ⋮ subsiste. Vérifier que le nom du groupe et la ligne
      « N membres » ne se décalent pas maintenant que la rangée d'actions a
      rétréci (deux boutons en moins).
- [ ] Même écran en **thème sombre** et à **grande échelle de police** : la
      rangée d'actions reste alignée, rien ne déborde.
- [ ] Une discussion 1-à-1 et « Mes notes » : inchangées (elles n'avaient déjà
      plus de boutons d'appel).
- [ ] Le ⋮ de groupe ouvre toujours sa feuille d'options complète : elle n'a pas
      été touchée, mais c'est le voisin immédiat des boutons retirés.

**Pour réactiver** : décommenter les trois blocs (chercher « Appels de GROUPE
mis en pause » dans le fichier), et passer le protocole à deux téléphones réels
décrit dans l'entrée du 2026-08-14 — plus un appel de groupe à 3 puis à 5
participants, pour couvrir le maillage **et** le basculement SFU.

---

## La bulle d'appel elle-même n'apparaissait jamais dans la conversation (2026-08-14)

**Priorité P3** · importance 2/5 — Mineur : pas de menu sur une bulle d'appel ; le rappel est volontairement coupé. *Bloqué : fonction en pause (appels 1:1).*

Correctif : `createCallMessage` insère maintenant dans la table Supabase
`messages` avec le même schéma `data` JSONB (camelCase) que
`sendTextMessage`, précédé d'un `SupabaseAuthBridge.ensureAuthenticated()`
comme partout ailleurs où l'app écrit dans Supabase. `_ensureParticipantsInRTDB`
(RTDB) est conservée telle quelle — sert aux règles de permission des appels,
sans rapport avec l'affichage du message. `flutter analyze` propre, mais rien
de tout ça n'exerce un vrai appel WebRTC/coturn ni Supabase.

- [x] Passer ou recevoir un appel (audio ou vidéo), raccrocher → une bulle
  d'appel apparaît dans la conversation (pas seulement l'aperçu en liste),
  avec la bonne icône/couleur selon le statut (terminé, manqué, refusé,
  occupé, sortant annulé) et la durée si décroché. **Vérifié le 2026-08-14
  sur SM A515F (Sim) ↔ Pixel 10 Pro XL (Salim L.), vrai appel audio 1:1** :
  bulle rouge « Appel manqué / Pas de réponse - HH:MM » visible des deux
  côtés (alignée à droite chez l'appelant Sim, à gauche chez Salim L.),
  icône téléphone barré rouge, callback icon présent. Seul le statut
  manqué/pas de réponse a été exercé (deux tentatives, l'app de Salim L.
  n'étant pas au premier plan) ; terminé/refusé/occupé/sortant annulé
  restent à vérifier.
- [ ] Taper sur la bulle → rappelle le contact. Appui long → menu contextuel
  (rappeler / infos / supprimer si auteur ou admin).

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« La bulle d'appel elle-même n'apparaissait jamais dans la conversation (2026-08-14) »).

---

## 🔴 Appels 1-à-1 mis en PAUSE (2026-08-14) — répondre à un appel ne faisait rigoureusement rien

**Priorité P0** · importance 3/5 — Le Mode Voyage ne tourne jamais : la position des voyageurs ne remonte pas, et le service de premier plan « localisation » déclaré à Google n'a plus de fonction visible — le motif de fond des cinq refus Play.

**Ce qui a été commenté (code conservé, pas supprimé)** :
- `conversation_screen.dart` : les deux `IconButton` d'appel 1-à-1 dans
  l'AppBar (audio/vidéo — ⚠️ il était écrit ici que les boutons d'appel de
  GROUPE juste en dessous restaient actifs, « système différent/LiveKit,
  pas concerné » : **c'était faux**, un appel de groupe à moins de 5
  participants tourne en maillage sur le même `webrtc_service.dart`. Ils
  ont été mis en pause à leur tour le 2026-09-14, voir « ⬜ Les appels de
  GROUPE restaient lançables alors que le 1-à-1 était en pause
  (2026-09-14) ») ; le rappel en un geste sur une bulle d'appel
  (`onCallBack: null`) ; les méthodes
  `_startCall`/`_handleCallBack` et leurs imports (`call_entity.dart`,
  `call_provider.dart`, `call_screen.dart`) devenus inutilisés.
- `profile_screen.dart` : l'entrée « Historique des appels » (menu Profil).

**Pour réactiver** : décommenter ces blocs (cherchez « Appels 1-à-1 mis en
pause » dans les deux fichiers), puis reprendre EXACTEMENT ce test avant de
relivrer — deux téléphones réels, pas d'émulateur, personne d'autre dessus :
1. Appel connecté normalement des deux côtés.
2. Couper le wifi ~10 s côté appelé en pleine communication (force une
   coupure ICE réelle) : l'appel doit survivre via `_retryIceRestart()`, pas
   raccrocher après le timeout de 30 s.
3. Appeler B depuis A pendant que A a déjà un appel sortant en cours vers un
   tiers : B doit recevoir un refus « occupé » propre, pas un plantage muet.
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

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« 🔴 Appels 1-à-1 mis en PAUSE (2026-08-14) — répondre à un appel ne faisait rigoureusement rien »).

---

## Message d'appel : aperçu et badge non-lu ne se mettaient jamais à jour (2026-08-13)

**Priorité P3** · importance 1/5 — Aucun tant que les appels 1:1 sont masqués ; ensuite, un premier appel ne laisserait aucune trace dans la liste des discussions. *Bloqué : fonction en pause (appels 1:1) + deux comptes.*

Correctif : nouvelle méthode privée `_updateConversationLastMessage`
dans `call_message_service.dart`, calquée sur celle de
`MessageSupabaseDataSource`/`BackgroundReplyService` (mêmes clés
camelCase, même colonne top-level `last_message_at`, incrément
`unreadCount` pour tous les participants sauf l'auteur de l'appel). La
création de conversation 1:1 (`_getOrCreateConversation`) écrit
maintenant `unreadCount`/`requestStatus` comme
`createIndividualConversation`, sans plus dupliquer `created_by`/
`last_message_at` (colonnes top-level) dans `data`. `flutter analyze`
propre, mais rien de tout ça n'exerce un vrai appel WebRTC/coturn ni
Supabase.

- [ ] Passer un premier appel vers un contact sans conversation 1:1
  existante → une nouvelle conversation est créée et apparaît normalement
  dans la liste (aperçu + badge), pas seulement après l'envoi d'un
  message texte ultérieur.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Message d'appel : aperçu et badge non-lu ne se mettaient jamais à jour (2026-08-13) »).

---

## Appels WebRTC

**Priorité P0** · importance 2/5 — Les appels de groupe restent muets ou ne se connectent jamais en données mobiles : le relais TURN n'a jamais été validé depuis la rotation du 16/07, et la signalisation de groupe a déjà été refusée trois jours en production sans aucune erreur visible. *Bloqué : deux comptes.*

### Premier appel de groupe réel entre les deux téléphones (2026-09-11 18:59)

✅ **Le relais TURN alloue** : parmi les candidats figurent des `typ relay`
sur `72.62.212.223` (le VPS coturn), avec leurs `raddr` publics. C'est la
première preuve depuis la rotation de secret du 16/07 que l'allocation
fonctionne — en wifi ; la validation « 4G/5G sans wifi » reste entière.

⛔ **L'écran d'appel n'offre aucun moyen de raccrocher tant qu'il « connecte ».**
Capture à l'appui : fond noir, une roue, « Connexion en cours… », et **rien
d'autre** — pas de bouton rouge, pas de croix, aucun contrôle. L'appelant ne
peut sortir que par le geste système, et le nœud reste alors ouvert côté
serveur avec lui en participant. À traiter en même temps que le point
suivant : un appel qui ne joint personne doit pouvoir être abandonné.

⛔ **Et l'appel reste ouvert indéfiniment.** Relevé le **2026-09-13 à 23:21**,
soit deux jours après : `/group_calls/5NSEJFNAccicDNJjvOPw/participants`
contient toujours Sim A avec son `joinedAt` du 2026-09-11. Ni la sortie par le
geste système, ni l'`am force-stop` qui a suivi, ni aucun ménage côté serveur
(`cleanupStaleGroupCalls`) ne l'ont refermé. Un appel abandonné reste donc
« en cours » pour qui lit ce nœud.

⛔ **Mais l'appelé n'a jamais rien vu.** Sur le Pixel (Salim L., app au premier
plan, écran Réglages), aucun écran d'appel entrant, aucune bannière, et
`dumpsys notification` ne montre **aucune** notification d'appel — seulement
l'ancienne notification de message. L'appelant est resté sur « Connexion en
cours… ». Donc : signalisation écrite, destinataire jamais prévenu. À
instruire côté `onCallCreated` (push d'appel) **et** côté écoute in-app du
nœud `group_calls`, puisque l'app de l'appelé était ouverte.

- [ ] **Appel 1:1 après restriction** (2026-08-03) : un appel complet entre deux comptes doit fonctionner à l'identique — sonnerie, décroché, audio des deux côtés, passage en vidéo, raccrochage. C'est le test de non-régression du changement de règles ; tout échec se manifestera par une signalisation muette (l'appelé ne voit jamais l'offre) plutôt que par une erreur explicite.
- [ ] **Appel de groupe après restriction** (2026-08-03) : entrer dans un appel de groupe écrit d'abord `participants/<uid>` (autorisé pour soi-même) puis lit le reste — vérifier que rejoindre, voir les autres arriver et repartir, et l'audio de bout en bout fonctionnent toujours. La signalisation est maintenant limitée aux couples émetteur/destinataire dont on fait partie, et `hostId`/`status`/`mode` restent lisibles avant d'avoir rejoint.
- [ ] **Relais TURN coturn en production** — à valider par un vrai appel en 4G/5G **sans wifi** (cas NAT symétrique, celui que TURN est censé résoudre) ; vérifier aussi que `grep -ci allocation` augmente dans les logs coturn pendant l'appel. Jamais confirmé depuis la rotation de secret du 16/07.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Appels WebRTC »).

---

## Appels 1-à-1 (correctifs du 2026-08-03)

**Priorité P3** · importance 2/5 — Aucun pour l'utilisateur tant que la fonction est masquée. *Bloqué : fonction en pause + deux comptes.*

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

---

# 6. Notifications et push

Chaîne FCM, aperçus, réponse rapide, écran Notifications.

---

## ⬜ Notifications entre comptes : le serveur rédige le texte et filtre les données (2026-09-21)

**Priorité P1** · importance 4/5 — Fermeture d'un faux appel entrant et d'un hameçonnage possibles depuis n'importe quel compte. Côté app rien ne change, mais tous les textes de ces notifications viennent maintenant du serveur : à relire à l'écran une fois.

**Ce qui est posé :** texte rédigé par le serveur pour chaque type (mêmes
phrases qu'avant), nom de l'acteur lu dans `users`, titre d'événement lu dans
`events` et seulement si le destinataire en est l'organisateur ; `p_data` en
liste blanche (identifiants de cible et quelques scalaires bornés, jamais
`type`/`title`/`body`) ; `report_resolved` réservé aux administrateurs ;
`anon` sans exécution.

**À vérifier sur appareil :**

- [ ] demande d'ami, acceptation, commentaire, réponse, « j'aime »,
  repartage, participation à un événement, invitation à un appel de groupe :
  chaque push arrive, avec le bon nom et le bon texte ;
- [ ] **le « j'aime » arrive désormais** — il n'est jamais arrivé ;
- [ ] toucher la notification ouvre le bon écran (fiche de l'émetteur pour
  une demande d'ami, publication, événement, appel) ;
- [ ] un signalement traité depuis le back-office prévient bien l'auteur.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Notifications entre comptes : le serveur rédige le texte et filtre les données (2026-09-21) »).

---

## ⬜ Notifications lues à l'ouverture de leur écran : profil, groupe, commandes, fiche, mentions (2026-09-19)

**Priorité P2** · importance 3/5 — La cloche compte des notifications dont la
cible a déjà été vue : « certaines ne se mettent pas comme lues
automatiquement ».

Ce qui marque maintenant (`NotificationReadSync`, une écriture
best-effort à l'ouverture) :
- **Profil** d'une personne → ses `friendAccepted` / `friendRequestAccepted`
  (trois clés, `friendAccepted` n'a parfois que `target_id`).
- **Fiche d'un groupe** → `groupRequestApproved`, `groupRequestRejected`,
  `officialGroupLeave`, `cityGroupInvite`. **Pas** `groupInvite` ni
  `groupJoinRequest` : elles appellent un geste, la base les ferme.
- **Fiche de notification** (appui long, lien) → la notification affichée.
  Destination unique de `system`, `supportReply`, `missedCall`, transferts…
- **Lecture d'une discussion** → `messageMention`, **côté serveur seulement** :
  `marquer_lus_jusqua` (lecture par curseur, bornée au dernier message vu par
  jointure sur l'identifiant du message) et `mark_messages_as_read` (ancien
  chemin, et action « Marquer comme lu » de la bannière), migration
  `20260919120000`. Il n'y a plus de marquage côté client des mentions.
- **Arrivée pendant que l'écran est ouvert** (`LectureALArrivee`, 2026-09-20) →
  jusque-là, une notification écrite APRÈS l'ouverture de son écran restait non
  lue. Un canal permanent sur les `INSERT` du compte confronte chaque
  notification à la page affichée **en haut de la pile** ; si c'est sa
  destination (la même table que l'ouverture : fil, événement, groupe, profil,
  commandes), elle est marquée lue par son id. Trois conditions à la fois :
  application au **premier plan** (`resumed` strict), écran **du dessus** (pas
  un écran seulement ouvert dessous), ligne **pas déjà lue**. Jamais la
  messagerie, jamais ce qui appelle un geste.
- **Reprise au premier plan** (`surReprise`) → ce qui est arrivé application en
  arrière-plan, ou canal coupé, n'a pas été jugé à l'arrivée. Au retour,
  l'écran affiché lit ses notifications comme à son ouverture (même table,
  `markDisplayedRead`).
- **Push `system` touchée** → une annonce n'a pas de cible (`targetId` sort
  vide, la table n'a pas de colonne `target_id`) mais son code, `data.annonce`
  (« maj-1.2.1-chiffrement »), que `send-push` recopie dans la push. La ligne se
  retrouve par ce code, restreinte au type `system`. Filtre `eq` simple : le
  code contient des points, que la liste blanche des identifiants refuse
  exprès pour le filtre `or=(…)`.

- [ ] **Profil** : compte A a une notification « demande acceptée » de B non
  lue ; ouvrir le profil de B **depuis la discussion** (pas depuis la liste) ;
  la cloche baisse de 1 sans rouvrir l'app.
- [ ] **Groupe** : notification « invitation de ville » non lue ; ouvrir la
  fiche du groupe depuis Découvrir → lue. Une `groupInvite` en attente
  **reste** non lue.
- [ ] **Fiche** : appui long sur une notification `system` → lue à l'ouverture
  de la fiche, le bouton « Marquer comme lu » disparaît.
- [ ] **Mention** : conversation en sourdine, un message qui nomme le compte ;
  ouvrir la discussion → `is_read = true` en base (la ligne est à l'écran de
  Notifications : elle doit en sortir de « Non lues »). Chemin par curseur,
  `marquer_lus_jusqua` seul : c'est le premier passage réel depuis le retrait
  du marquage client. Un message écrit APRÈS ce que l'écran a vu doit, lui,
  rester non lu.
- [ ] **Mention, action de la bannière** — *migration `20260919120000` appliquée
  (relue en base le 2026-09-20)* : même mise en place, la mention posée en bannière ;
  toucher « Marquer comme lu » sur la bannière → `is_read = true`. Sans la
  migration ce chemin ne la marque pas.
- [ ] **Non-régression** : une demande d'ami en attente reste non lue et garde
  ses boutons.
- [ ] **Arrivée — événement ouvert** : compte A (organisateur) sur la fiche de
  son événement ; compte B s'inscrit → la notification « participation » de A
  passe en lue SANS quitter l'écran (`is_read = true` en base dans la
  seconde).
- [ ] **Arrivée — publication ouverte** : A sur sa publication ; B la commente
  → lue, et le commentaire s'affiche.
- [ ] **Arrivée — profil ouvert** : A sur le profil de B ; B accepte la demande
  de A → `friendAccepted` lue.
- [ ] **Arrivée, négatif — application en arrière-plan** : A sur la fiche de
  l'événement, écran verrouillé ; B s'inscrit → la notification reste NON lue
  en base TANT QUE l'application n'est pas revenue au premier plan.
- [ ] **Reprise** : suite du cas précédent — A déverrouille et revient sur
  l'application, sans changer d'écran → la notification passe en lue dans la
  seconde qui suit (trace `reprise sur /events/… — notifications de l'écran
  marquées lues`). Contre-épreuve : la même chose depuis `/home` ne lit rien
  (`ignorée : ce n'est la destination d'aucune notification`).
- [ ] **Push `system` touchée** : insérer une annonce `system` pour UN compte de
  test (la recette de diffusion, en ciblant ce seul compte — l'insertion envoie
  une vraie push) ; app fermée, toucher la bannière → `is_read = true` en base
  pour ce code, et la carte s'affiche lue dans la liste. Une autre annonce, de
  code différent, reste non lue.
- [ ] **Arrivée, négatif — écran par-dessus** : A sur la fiche de l'événement,
  puis ouvre un profil PAR-DESSUS ; B s'inscrit → NON lue.
- [ ] **Arrivée, négatif — geste attendu** : A sur le profil de C ; C lui envoie
  une demande d'ami → reste non lue, boutons Accepter/Refuser présents.
- [ ] **Arrivée — changement de compte** : déconnexion, puis connexion avec B ;
  une notification arrive pour B sur son écran → lue ; rien ne change pour A.
- [ ] **Arrivée — retour du réseau** : couper le réseau deux minutes, le
  rétablir, provoquer une arrivée sur l'écran ouvert → lue. Le canal se rouvre
  avec une attente plafonnée à 60 s : compter jusqu'à une minute.

*Ce que les bancs ne voient pas* : la requête PostgREST réelle (`in.(…)` +
`or=(data->>k.eq.v)`) — testée à la forme, jamais rejouée contre la base ;
l'écriture est best-effort, un refus ne laisse qu'un `debugPrint`.
Pour l'arrivée : la décision (`LectureALArrivee`) et la lecture de la page
affichée (`emplacementAffiche`, contre le vrai `go_router`) sont éprouvées, et
chacune fait tomber des tests quand on la casse. **Jamais rejoués** : le canal
Supabase réel, l'état `resumed`, et la **forme de `payload.newRecord`** — `data`
doit arriver décodé en carte. Lu dans le paquet verrouillé (`realtime_client`
2.11.0, `convertCell` : `jsonb` → `toJson`, qui décode une chaîne et laisse une
carte telle quelle), pas observé sur le fil. Si `data` arrivait quand même en
chaîne, rien ne serait jamais lu, sans la moindre erreur : si les cases
« Arrivée » ne marquent rien, c'est la première chose à regarder.
**Chaque arrivée journalise une ligne**, sans identifiant :
`LectureALArrivee: <type> sur /feed/… — <verdict>` (marquée lue ; application
pas au premier plan ; écran affiché inconnu ; pas la destination de l'écran ;
déjà lue ; ÉCHEC de l'écriture ; erreur inattendue — l'écriture avale ses
erreurs, le verdict lit son résultat au lieu de la croire réussie, et une
session Supabase illisible replanifie l'abonnement au lieu d'ouvrir un canal
`anon` muet). `adb logcat -s flutter | grep LectureALArrivee` dit
donc POURQUOI une case ne marque rien — un garde qui refuse ne lève rien, et
celui de visibilité de la discussion, toujours faux sur appareil le 2026-09-16,
n'avait laissé aucune trace : trois builds. Aucune ligne du tout après une
arrivée = le canal ne s'est pas ouvert (session, réseau) ou n'est pas surveillé.
*Ce qui n'est PAS corrigé* : une notification arrivée pendant qu'un écran se
trouvait PAR-DESSUS sa destination (la fiche de l'événement, puis un profil
ouvert dessus), puis la destination retrouvée en fermant cet écran — aucun
changement d'état de l'application, donc ni arrivée jugée (ce n'était pas
l'écran du dessus) ni reprise. Elle reste non lue jusqu'à la prochaine
ouverture. Il faudrait observer la navigation (`didPop`) ; jamais mesuré comme
fréquent.

---

## ⬜ Réglages de notification par type : local et serveur ne divergent plus (2026-09-18)

**Priorité P1** · importance 3/5 — Couper « Messages » (ou « Groupes »,
« Événements »…) écrivait la préférence locale, qui ne décide que de
l'**affichage** au premier plan, puis recopiait la carte
`users.notification_prefs` — la seule que `send-push` consulte — dans un
`catch` qui avalait l'échec (« Best effort : l'appareil se resynchronisera à la
bascule suivante »). Un utilisateur qui voit « Messages » sur « désactivé » ne
rebascule pas : le back-end continuait de pousser, sans un signal. Et
`setLocalEventsEnabled`, qui écrit une colonne dédiée PUIS la carte, n'avait
aucun `try/catch` : l'échec remontait à un appelant en `unawaited`,
préférence locale déjà changée. Deux appelants, dont « M'avertir du prochain »
sur l'Accueil.

Chaque écriture rend maintenant `false` si le serveur refuse, revient à la
valeur d'avant **des deux côtés** (et remet la colonne dédiée si la carte
échoue après elle), et l'écran le dit. Les écritures sont **sérialisées** : le
retour en arrière n'a de sens que si aucune autre écriture n'est en vol — deux
bascules rapides sur un réseau lent, dont la première échoue, laissaient sinon
le serveur avec la carte entière (première bascule comprise) et l'appareil sans.
Enfin `updateNotificationPrefs` et `updateNotifyLocalEvents` **vérifient qu'une
ligne a été touchée** : PostgREST rend 200 sur un `UPDATE` qui ne matche rien.

- [ ] **Réseau coupé, Notifications → « Messages »** : l'interrupteur revient à
  sa position, le snackbar d'échec s'affiche, et en quittant puis rouvrant
  l'écran la valeur est toujours l'ancienne (la préférence locale n'est pas
  restée écrite).
- [ ] **Réseau rétabli, même bascule** : elle tient, et
  `supabase db query --linked "select notification_prefs from users where
  id='…'"` porte la nouvelle valeur. **Le vrai test** : app fermée, un autre
  compte écrit → aucune notification quand « Messages » est coupé.
- [ ] **« M'avertir du prochain » (Accueil), réseau coupé** : revient, snackbar ;
  réseau rétabli : `notify_local_events` ET `notification_prefs.local_events`
  suivent.
- [ ] **Deux bascules à la suite, réseau coupé entre les deux** : les deux
  reviennent, ou la carte serveur correspond exactement à ce que l'écran
  affiche. Jamais l'un sans l'autre.
- [ ] **Thème sombre et grande police** sur le snackbar d'échec.

---

## ⬜ Une édition corrige la bannière déjà posée (2026-09-16)

**Priorité P1** · importance 4/5 — Avant : la bannière gardait le texte
d'avant, et surtout **la pile le gardait 24 h** — le message suivant de la
conversation réaffichait la ligne périmée au-dessus de la neuve. Le texte faux
ne restait pas, il **revenait**, et rien ne permettait de s'en apercevoir.

Maintenant, une édition envoie un `messageEdited` **silencieux** : `send-push`
le passe en data-only, donc le système n'affiche rien de lui-même ; l'appareil
corrige sa ligne dans la pile et **repose la même bannière**, sans la faire
re-sonner (`onlyAlertOnce`). On ne la retire pas pour la reposer : ça la ferait
sonner et disparaître un instant.

**Le garde qui compte** : la correction n'est envoyée qu'aux destinataires dont
une notification `message` est encore **non lue** pour cette conversation, et
l'appareil refuse en plus de reposer une bannière si le message corrigé n'est
pas dans sa pile. Une édition ne doit **jamais** faire réapparaître une
conversation déjà lue.

- [ ] **Réaction ou suppression en chiffré** : elles passent par le même
  transport de contrôle mais ne doivent **rien** changer à la bannière.
  ⬜ moitié, Passe du 2026-09-22 (~03:10–03:17), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : **réaction** de Sim sur PK1, pile PV affichée →
  bannière de réaction séparée (« A réagi 👍 à votre message »), la pile PV
  reste identique (`when` inchangé). Suppression pas faite (son traitement
  change sur le +28).

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Une édition corrige la bannière déjà posée (2026-09-16) »).

---

## ⬜ Cinq messages reçus, un seul lisible : la bannière ne s'empilait pas (2026-09-16)

**Priorité P0** · importance 5/5 — Quand l'application est en arrière-plan ou
fermée — c'est-à-dire quand une notification sert vraiment — la bannière est
posée par `_showFallbackMessageNotification`, sous le couple
`(tag: 'msg_<conversation>', id: 0)`. **Android identifie une notification par
ce couple** : chaque message écrasait le précédent. Un seul lisible, aucun
compteur, et rien qui dise que les autres ont existé. Vaut autant pour
plusieurs messages d'une même personne que pour un groupe qui s'anime.

D'où une pile en `SharedPreferences` — le seul état que les deux isolates
partagent — lue par l'arrière-plan pour construire un `MessagingStyle`, et
**alimentée aussi par le premier plan** pour que l'historique ne reparte pas
de zéro quand l'application passe en arrière-plan.

Elle se vide dès que la conversation est vue (ouverture, retrait depuis un
autre appareil), plafonne à 6 messages, ignore un même `messageId` empilé deux
fois (un push peut arriver en double), oublie ce qui a plus de 24 h, et
disparaît entièrement à la déconnexion — elle porte du texte en clair.

- [ ] **Groupe qui s'anime, app tuée** : la bannière porte le nom du groupe en
  titre et **chaque message précédé de son expéditeur**.
- [ ] **Deux conversations en parallèle** : deux bannières distinctes, chacune
  avec sa propre pile.
- [ ] **Pastille du lanceur** (Samsung, Xiaomi) : le chiffre suit le nombre de
  messages en attente, pas « 1 ».
- [ ] **Passer du premier plan à l'arrière-plan en cours de conversation** :
  les messages vus au premier plan figurent encore dans la bannière suivante.
  Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PK1 reçu discussion affichée, HOME, PK2 reçu → la bannière ne montre QUE PK2 (`number=1`). Contraire à cette case, conforme à « les lus ne reviennent pas » plus haut dans la même entrée : les deux règles se contredisent, à trancher.
- [ ] **Même message poussé deux fois** (couper/rétablir le réseau) : une
  seule ligne dans la bannière.
- [ ] **Se déconnecter** : plus aucun texte de message dans les préférences
  (`notif_pile_*`).
- [ ] **Pile à cheval sur minuit** : recevoir un message avant minuit et un
  après, puis regarder la bannière. Celui d'avant doit porter « hier », sinon
  l'ordre paraît faux — 23:50 semble plus tard que 00:05. La fenêtre de la pile
  est de 24 h, donc le cas est atteignable toutes les nuits.
- [ ] **Groupe** : chaque ligne montre son expéditeur **une seule fois**.
- [ ] **En groupe, deux personnes qui alternent** : les en-têtes alternent aussi,
  et chaque bloc reste attribué à la bonne personne.
- [ ] **Deux membres d'un groupe portant le même nom affiché** : ils ne sont pas
  fondus en une seule personne.

- ✔ 11 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Cinq messages reçus, un seul lisible : la bannière ne s'empilait pas (2026-09-16) »).

---

## ⬜ Trois cas de messagerie que les notifications ne couvraient pas (2026-09-16)

**Priorité P1** · importance 4/5 — Trouvés en comparant les deux déclencheurs
de production ligne à ligne, puis en recoupant avec les données. Aucun ne
produisait d'erreur, c'est ce qui les avait gardés en place.

- [ ] **Note vocale reçue** (conversation chiffrée ET conversation claire) :
  la bannière dit « 🎙️ Message vocal », plus « Nouveau message ».
- [ ] **Sticker reçu en clair** : « 🎨 Sticker », et surtout **pas une URL**.
- [ ] **Document reçu** : « 📄 <nom du fichier> ».
- [ ] **Réagir à un message chiffré depuis l'autre téléphone** : l'auteur
  reçoit « A réagi 🎉 à votre note vocale » — avec l'emoji, et en disant à quoi.
  *(Décision de Salim du 2026-09-16 : les deux transports se ressemblent,
  quitte à donner l'emoji à FCM. Le libellé, lui, ne dit que le TYPE du
  message — jamais son contenu.)*
- [ ] **Réagir à une photo, à un texte, à un sondage** : le libellé suit
  (« votre photo », « votre message », « votre sondage »), et il est le même
  en clair et en chiffré.
  ⬜ en partie, Passe du 2026-09-22 (~03:10–03:17), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Salim réagit 👍 au sondage « PQ Sondage » de Sim
  (double tap sur la question, aucun vote parti) → notification et bannière
  chez Sim, app fermée : « A réagi 👍 à votre **sondage** » ; sur un texte :
  « … à votre message ». Photo non testée, et seulement en chiffré.
- [ ] **Droits de la table** : marquer lu, supprimer une notification et faire
  défiler la liste marchent toujours. C'est ce que le `REVOKE ALL` pouvait
  casser — vérifié par banc côté serveur, jamais depuis l'app.
- [ ] **Conversation en sourdine + mention** (conversation en clair) : la
  bannière arrive, libellée « Mention », et l'appui ouvre **la discussion**.
- [ ] **Conversation en sourdine sans mention** : toujours silencieuse.
- [ ] **Conversation NON muette + mention** : une seule notification, pas deux.
- [ ] **Conversation chiffrée en sourdine + mention** : silencieuse, et c'est
  attendu — le noter si ça surprend à l'usage.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Trois cas de messagerie que les notifications ne couvraient pas (2026-09-16) »).

---

## ⬜ Types, libellés et bascules : trois écarts entre ce qui est écrit et ce qui est lu (2026-09-16)

**Priorité P1** · importance 4/5 — Inventaire du 2026-09-16, à partir des
écrivains eux-mêmes (client, migrations, `functions/index.js`) plutôt que
d'une lecture. Trois écarts, tous muets.

- [ ] **Une annonce `system`** s'affiche « Message système », pas « Général ».
- [ ] **Un j'aime sur ma publication** : la notification s'appelle « Nouveau
  j'aime », et l'appui ouvre **la publication**, pas la fiche.
- [ ] **Couper « Messages système »**, puis se faire envoyer une annonce :
  rien ne doit arriver, **app ouverte comme app fermée**. C'est le test de la
  parité — avant, elle passait app ouverte.
- [ ] **Couper « Groupes »**, puis déclencher une invitation de groupe de
  ville : rien ne doit arriver app fermée non plus.
- [ ] **Couper « Demandes d'ami »**, puis faire accepter une demande : la
  notification d'acceptation ne doit pas arriver.
- [ ] **Écran Notifications, filtres** : les onglets fonctionnent encore après
  le retrait des quatre types morts (ils figuraient dans trois listes de
  filtres).
- [ ] **Réglages → Notifications** : les bascules s'affichent et se
  souviennent (la pile Firestore supprimée n'était pas celle qui sert, mais
  c'est le moment de le vérifier).

---

## ⬜ Aperçu MLS quand l'app est OUVERTE (le même message, l'autre isolate)

**Priorité P0** · importance 5/5 — Signalé par Salim le 2026-09-15 : « les
messages reçus affichent *Nouveau message* au lieu du contenu ». Ce n'était
pas le chiffrement, et pas non plus le chemin décrit dans « Aperçu des
notifications MLS reconstruit sur l'appareil (phase 4, Android) » : celui-là
ne couvre que l'isolate d'arrière-plan. **Au premier plan, rien ne
déchiffrait.** `_handleForegroundMessage` passait le repli générique du
serveur à la bannière in-app comme à la notification système. Le même message
s'affichait donc en clair app fermée et générique app ouverte.

- [ ] **App ouverte sur un AUTRE écran** (le fil, pas la discussion), message
  MLS reçu : la bannière in-app affiche le **vrai texte**.
  Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : app sur l'Accueil, PC1 reçu → c'est la fenêtre surgissante SYSTÈME qui s'affiche, avec le vrai texte (« Salim L. PC1 · 19:22 ») ; aucune bannière propre à l'app observée.
- [ ] **Sondage et appel** reçus chiffrés : libellés « Sondage » et « Appel »
  (deux types que `resume` ignorait, d'où un repli générique alors que le
  message était déchiffré).
  ⬜ moitié, Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : **app fermée** (HOME + `am kill`), sondage « PQ
  Sondage » reçu → la ligne de la bannière dit « Sondage · 02:07 ». Appel non
  testé (appels en pause), app ouverte non testée.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Aperçu MLS quand l'app est OUVERTE (le même message, l'autre isolate) »).

---

## ⬜ Aperçu des notifications MLS sur iOS : une extension, pas un isolate (phase 4, moitié iOS)

**Priorité P1** · importance 4/5 — *Bloqué : ce poste n'a pas de Mac. Rien de
ce qui suit n'a jamais été compilé.* Pendant iOS de « Aperçu des notifications
MLS reconstruit sur l'appareil (phase 4, Android) ».

**Un défaut réel trouvé en écrivant ceci** : `preview_without_state` rend le
**payload** du § 6.2 — du JSON portant la citation, les mentions et les
identifiants —, pas un texte. La première version du Swift le posait tel quel
dans la bannière, c'est-à-dire tout le contenu sur l'écran verrouillé. Corrigé
(`MlsPontNatif.resume`), et la table d'étiquettes est comparée à celle du Dart
par un banc qui lit les deux fichiers.

**Trois risques non levés faute de machine** : la mémoire d'une NSE est
plafonnée vers 24 Mo et le coût du `VACUUM INTO` d'OpenMLS n'a jamais été
mesuré ; le `-force_load` de `libdiaspo_mls.a` dans la cible d'extension tire
la glu FRB, dont l'absence de dépendance à la VM Dart au lien reste à prouver ;
et l'extension embarque sa propre copie du moteur, donc l'IPA grossit d'autant.

Fichiers : [ios/NotificationService/](ios/NotificationService/README.md) (les
étapes Xcode y sont listées, avec ce qu'elles conditionnent),
[mls_chemin_base.dart](lib/core/crypto/mls/mls_chemin_base.dart),
[mls_partage_extension_ios.dart](lib/core/crypto/mls/mls_partage_extension_ios.dart),
[AppDelegate.swift](ios/Runner/AppDelegate.swift), `rust/src/ffi.rs`.
Garde-fou hors appareil : `test/core/crypto/mls_apercu_ios_parite_test.dart`
(14 cas, vérifiés en cassant deux valeurs).

- [ ] **Créer la cible dans Xcode** et lier `libdiaspo_mls.a` : `project.pbxproj`
  n'est **délibérément pas modifié à la main** ici. Tant que ce n'est pas fait,
  ce dossier n'entre dans aucune build.
- [ ] **Activer App Groups sur les deux App ID** et régénérer les profils.
  Avant ça, `containerURL` rend nil, le Dart reste sur `Application Support`,
  et l'aperçu retombe silencieusement sur le texte générique — donc ne pas
  conclure « l'extension ne marche pas » sans avoir vérifié ce point.
- [ ] **L'extension est bien invoquée** : un `NSLog` en tête de `didReceive`.
  C'est la vérification du `mutable-content`.
- [ ] **`cheminBase` désigne un fichier qui existe** : c'est là que tout se
  joue, et l'échec est muet.
- [ ] **La bannière affiche le vrai texte, et pas du JSON** — le défaut
  ci-dessus, à revérifier sur l'appareil et pas seulement dans le banc.
- [ ] **Migration d'une base existante** : installer une version antérieure,
  basculer une conversation, mettre à jour, vérifier que la conversation reste
  **lisible** (la base a été déplacée, pas recréée).
- [ ] **Mémoire de l'extension** : vérifier qu'elle n'est pas tuée sur une
  conversation à gros état (groupe fourni, plusieurs epochs).
- [ ] **Après déconnexion**, plus aucun aperçu déchiffré : `currentUserId` est
  retiré du groupe partagé (`effacerContexteMls`).
- [ ] **Taille de l'IPA** avant/après, sur une vraie archive.

---

## ⬜ Aperçu des notifications MLS reconstruit sur l'appareil (phase 4, Android)

**Priorité P0** · importance 5/5 — Ce que MLS casse et qu'il faut rebâtir :
jusqu'ici Postgres **déchiffrait** dans le trigger et mettait le vrai texte
dans `notifications.body`, qui partait tel quel dans le push. Le serveur ne
le peut plus. Il envoie donc un repli générique (« Nouveau message »,
« Pièce jointe ») **et le ciphertext** (185 octets mesurés pour un texte
court, omis au-delà de 2500), et c'est l'isolate de notification qui
reconstruit l'aperçu en déchiffrant localement.

**Le piège, et pourquoi il ne se voit pas à la relecture.** Déchiffrer
consomme une génération du cliquet. Si l'isolate déchiffrait sur la base
principale, l'application — qui traite ensuite le même message — ne pourrait
plus le lire : la conversation deviendrait illisible **sans qu'aucune erreur
ne le dise**. Le déchiffrement passe donc par `apercuSansEtat`, qui travaille
sur une copie jetable produite par `VACUUM INTO` côté Rust, lue puis
supprimée. Un seul écrivain de l'état MLS : l'application.

- [ ] **Deux pushs pour le même message** (relancer l'envoi, ou couper/rétablir
  le réseau) : la bannière reste correcte, et le message reste lisible dans
  l'app.
- [ ] **Message d'un epoch non encore traité** (envoyer juste après un ajout
  de membre) : la bannière retombe sur le repli générique, sans planter, et
  l'app affiche le texte une fois le commit traité.
- [ ] **Média, note vocale, position** : la bannière dit « Pièce jointe »,
  « Note vocale », « Position » — jamais le nom du fichier.
- [ ] **Aucune copie jetable ne traîne** : `run-as … ls files/…/mls/` ne
  montre aucun fichier `*apercu-*`.
- [ ] **Un ancien build** qui reçoit un push MLS : bannière générique, aucun
  plantage.
- [ ] **Réglage « aperçu des messages » désactivé** : le corps reste
  générique même quand le déchiffrement aurait réussi. Câblé le 2026-09-15 —
  `MlsNotificationPreview.concerne` lit le drapeau `showMessagePreview` que
  `send-push` transmet déjà —, à vérifier sur appareil.
  ⛔ Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : impossible à tester — **le réglage n'existe pas dans l'app**. `PreferencesService.setShowMessagePreview` n'a aucun appelant ; l'écran Réglages › Notifications ne propose pas d'« Aperçu des messages ».

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Aperçu des notifications MLS reconstruit sur l'appareil (phase 4, Android) »).

---

## ⬜ Cycle de vie d'une demande d'ami : six trous soldés (2026-09-15)

**Priorité P2** · importance 3/5 — Aucun de ces six n'était visible pour un usager, mais l'un d'eux laissait n'importe quel compte fabriquer une demande d'ami **au nom de quelqu'un d'autre**. *Bloqué : deux comptes pour les points croisés.*

- [ ] **Annuler puis accepter** (deux comptes) : A envoie, B ouvre l'écran
  Notifications, A annule depuis « Envoyées », B tape « Accepter » sans
  rafraîchir → message clair « cette demande a été annulée », et rien en base.
- [ ] **La notification orpheline disparaît** : après l'annulation, la carte de
  B n'affiche plus de boutons **et** la pastille de la cloche redescend.
- [ ] **Accepter puis réaccepter** : après une acceptation, la demande n'existe
  plus en base (`friend_requests` vide pour ce couple) et l'amitié est là.
- [ ] **Refuser** : même chose, document supprimé, aucune amitié.
- [ ] **Renvoyer après un refus** : A peut réenvoyer une demande à B.

## ⬜ Accepter une demande d'ami : « Erreur de chargement » (2026-09-14)

**Priorité P0** · importance 5/5 — Accepter une demande d'ami échoue en production pour la quasi-totalité des comptes : le lot est refusé en entier, rien ne bouge en base, et l'usager lit « Erreur de chargement ». *Bloqué : deux comptes, dont un qui n'a jamais eu de document `users` Firestore.*

- [ ] **Accepter depuis l'écran Notifications**, compte expéditeur **sans**
  document `users` Firestore : « Demande acceptée », et en base
  `status: accepted` + les deux sous-collections `friends` créées.
- [ ] **Accepter depuis l'écran Amis** (onglet « Reçues ») : même résultat.
  Cet écran n'affichait **rien** en cas d'échec — ni sur « Accepter », ni sur
  « Refuser », ni sur « Annuler » ; il affiche désormais une erreur rouge.
- [ ] **Accepter depuis la fiche de profil** : même résultat. Le message
  d'échec y rendait l'exception brute (chemin du document Firestore et uid) ;
  il passe par `messageErreurUsager`.
- [ ] **Retirer un ami** : les deux entrées disparaissent des deux côtés.
- [ ] **Message d'échec** : couper le réseau et accepter → « Connexion
  indisponible… », pas « Erreur de chargement » (qui ne distinguait pas un
  réseau coupé d'un refus de droits).
- [ ] **Audience « Amis » après coup** : la nouvelle amitié arrive bien dans
  `public.friends` (miroir), donc une publication « Amis » devient visible —
  voir « Publications : audience Public / Abonnés / Amis / Moi uniquement ».

## ⬜ La messagerie sort de l'écran Notifications (2026-09-13)

**Priorité P1** · importance 3/5 — L'écran Notifications recopiait chaque message reçu : 90 lignes « message » sur 117 en base, le reste noyé dessous, et la cloche comptait deux fois ce que l'onglet Messages compte déjà.

Demandé par Salim. Les lignes `message` et `messageReaction` restent
écrites en base (c'est leur INSERT qui déclenche le push) : elles sont
écartées **à la lecture**, dans la requête. Le flux n'est plus `.stream()`
(un seul filtre possible) mais un canal realtime qui relance la requête
filtrée. (`notification_supabase_datasource.dart`,
`kTypesHorsEcranNotifications` dans `notification_entity.dart`)

- [ ] **Liste** : recevoir un message (compte A → B) puis ouvrir
  Notifications sur B : aucune ligne de message ; les autres notifications
  (demandes d'ami, événements, fil) sont là, **pleine page** — plus de liste
  presque vide sur un compte qui reçoit beaucoup de messages.
- [ ] **Temps réel** : écran Notifications ouvert sur B, A envoie un message
  → rien ne bouge ; A envoie une demande d'ami ou commente un post de B → la
  ligne apparaît sans quitter l'écran.
  ⬜ moitié, Passe du 2026-09-22 (~03:20–03:35), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : écran Notifications ouvert sur le Pixel (« 3 non
  lues »), Sim envoie PX3 → relevé de l'écran **identique** avant/après,
  alors qu'une notification `message` non lue est créée et que la bannière
  système « PX3 » est posée. Demande d'ami / commentaire : pas testés
  (publication interdite dans la passe).
- [ ] **Cloche** : la pastille de l'accueil ne monte pas à la réception d'un
  message (l'onglet Messages, lui, monte), et monte sur une notification
  d'un autre type.
- [ ] **Push** : le message reçu app fermée affiche toujours sa bannière, et
  la toucher ouvre la discussion.
- [ ] **Tout lire** / **Tout supprimer** (réglages) : n'agissent que sur ce
  que l'écran montre.
- [ ] **Reconnexion** : mode avion 30 s sur l'écran Notifications, puis
  retour → la liste reste affichée et se remet à jour (une notification reçue
  pendant la coupure apparaît).
- [ ] **Pagination** : sur un compte à plus de 20 notifications hors
  messagerie, faire défiler jusqu'en bas charge la suite.

## ⬜ Notifications ouvertes ailleurs ou obsolètes : lues (2026-09-12)

**Priorité P1** · importance 3/5 — Le compteur de notifications ment : des notifications déjà vues dans la discussion, touchées dans le volet système ou portant sur un contenu supprimé restent « non lues ».

- [ ] **Discussion lue** : recevoir un message (compte A → B), NE PAS ouvrir
  l'écran Notifications, ouvrir la discussion, puis ouvrir Notifications :
  la ligne est en registre « lue ». (`message_supabase_datasource.dart`,
  RPC `mark_messages_as_read`) — *Depuis le 2026-09-13 la ligne n'est plus
  à l'écran (voir « La messagerie sort de l'écran Notifications ») : vérifier
  `is_read` en base.*
- [ ] **Push touchée** : toucher la notification dans le volet Android,
  revenir, ouvrir Notifications : lue. (`notification_read_sync.dart`)
- [ ] **Publication ouverte depuis le fil** : une notification de commentaire
  sur un post, ouvrir ce post depuis le fil → la notification est lue.
- [ ] **Demande d'ami acceptée depuis l'écran Amis** : la notification de la
  demande passe en « lue ».
- [ ] **Contenu supprimé** : supprimer un événement auquel quelqu'un s'est
  inscrit → la notification « participation » de l'organisateur est lue.
- [ ] **Compteur** : le badge « N non lues » de l'en-tête et la puce « Non
  lues » baissent d'autant, sans rouvrir l'app.

## Page Notifications à plat + heure sur le seul dernier message d'une rafale (2026-08-23)

**Priorité P1** · importance 4/5 — Le tap ajouté sur la bulle peut empêcher d'ouvrir une photo ou de relancer un message en échec ; au mieux, les heures clignotent sur toute la conversation après chaque réaction.

Deux changements distincts, aucun couvert par `flutter test`.

**1. Le regroupement de la page Notifications est retiré**
([notifications_screen.dart](lib/features/notifications/presentation/screens/notifications_screen.dart)).
Les tuiles pliées « 3 nouveaux messages » / « 2 demandes d'ami »
(`_NotificationGroup`, `_NotificationGroupItem`, `_CompactNotificationItem`,
et les helpers `_groupNotifications`/`_autoGenerateGroupKey`) sont supprimées :
une notification = une ligne. Les tranches de temps (« AUJOURD'HUI », « CETTE
SEMAINE »…) et les trois filtres (Tout / Non lues / Mentions) sont conservés.
Le résumé des notifications **push** Android (`setAsGroupSummary`, InboxStyle
dans `notification_service.dart`) n'est pas touché — c'est un autre système.

- [ ] Les **tranches de temps** restent correctes et ne se répètent pas.

**2. Dans une rafale, seul le dernier message affiche son heure**
([message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)).
La règle existait pour les messages *envoyés* ; elle vaut désormais aussi pour
les messages *reçus* (`showTimeInfo = _isLastInGroup || _metaRevealed`).

- [ ] Le même cas sur des messages **reçus** : **pas vérifié**, aucun message
  reçu disponible sur le compte de test (les deux conversations ne contiennent
  que des messages envoyés ; celle du groupe est en « clé de groupe
  introuvable »). C'est pourtant la moitié de la demande — à refaire avec un
  second compte.
- [ ] Un **tap sur la bulle** (reçue comme envoyée) révèle son heure ; un
  second tap la remasque. ⚠️ Signalé cassé à l'usage le 2026-08-23 : le
  `GestureDetector` de la bulle ne portait que `onLongPress`/`onDoubleTap`,
  donc le tap ne déclenchait **rien** — la seule cible était une bande
  *invisible* de 48×16 dp posée sous la bulle, introuvable. Corrigé par
  `_onTapRevelerHeure`. À vérifier en priorité, avec trois sous-points :
  - le tap ne vole pas les gestes voisins (ouvrir une image, relancer un
    envoi en échec, sélection multiple, appui long, swipe pour répondre) ;
  - le double-tap pose toujours la réaction ❤️ ;
  - le tap simple accuse ~300 ms de retard (Flutter attend d'écarter le
    double-tap) — dire si c'est perceptible au point de gêner.
- [ ] ⚠️ **Scintillement observé le 2026-08-23** : juste après avoir posé une
  réaction ❤️, **toutes** les bulles de la conversation ont affiché leur heure
  d'un coup (le regroupement s'était défait), puis c'est rentré dans l'ordre à
  la réouverture. Piste : pendant le rebuild qui suit l'écriture, la liste passe
  par un état où les voisins d'index ne sont plus les voisins chronologiques, ce
  qui fait échouer `memeRafale`. Sans conséquence durable, mais à confirmer — et
  à corriger si ça se voit à chaque réaction.
- [ ] L'accusé de réception (« Envoyé »/« Lu »/« Vu par N ») reste sur les
  seuls messages envoyés.
- [ ] **Rupture de 15 minutes** (`kDureeRafale`,
  [message_grouping.dart](lib/features/messages/presentation/utils/message_grouping.dart)) :
  deux messages du même expéditeur espacés de plus de 15 min ne forment plus
  une rafale — celui du matin retrouve son heure. La rupture casse aussi le
  regroupement **visuel** (queue de bulle, nom de l'expéditeur en groupe) :
  c'est voulu, mais c'est le point à regarder en premier au téléphone. Le
  seuil est une constante, facile à retoucher si 15 min tombe mal.
  Comportement verrouillé par
  [rafale_position_test.dart](test/features/messages/rafale_position_test.dart)
  (7 cas), mais aucun test ne couvre le **rendu**.

- ✔ 10 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Page Notifications à plat + heure sur le seul dernier message d'une rafale (2026-08-23) »).

---

## Réponse rapide depuis la notification n'envoyait jamais rien (2026-08-13)

**Priorité P1** · importance 3/5 — Taper une notification de message n'ouvre pas la conversation ; la réponse rapide, masquée, ne peut rien casser tant qu'elle l'est. *Bloqué : deux comptes (ou message inséré en base).*

- [ ] Taper « Répondre », taper du texte, envoyer → la confirmation
  « Message envoyé » s'affiche, ET le message apparaît réellement dans la
  conversation. **Reste bloqué — voir « Quatrième bug » ci-dessous, action
  masquée en attendant.**
- [ ] Même test avec le téléphone en mode avion au moment de la réponse →
  le message part en file d'attente, puis rouvrir l'app une fois reconnecté
  doit l'envoyer automatiquement (pas besoin de le retaper). Bloqué par le
  même « Quatrième bug ».
- [ ] Action « Marquer comme lu » depuis une notification → le compteur non
  lu de la conversation redescend à 0 dans la liste des conversations.
  Bloqué par le même « Quatrième bug » (même mécanisme de dispatch).

**Quatrième bug, trouvé en testant le tap réel sur « Répondre » (2026-08-14),
bloquant :** les trois bugs ci-dessus posés et vérifiés (currentUserId,
écriture Supabase, boutons visibles), taper « Répondre » ouvre bien le champ
de saisie inline par-dessus la notification (comportement Android correct,
confirmé par capture), taper du texte et valider ferme bien ce champ — mais
**aucun message n'atteint jamais la base**, et strictement aucun code Dart ne
s'exécute ensuite. Isolé précisément par `adb logcat` :
- Android délivre bien le broadcast à notre récepteur (confirmé à chaque
  tentative) :
  `ActivityManager: Received BROADCAST intent … act=com.dexterous.
  flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED
  cmp=com.diasponiger.diasponiger/com.dexterous.flutterlocalnotifications.
  ActionBroadcastReceiver … sent=0` ;
- `RemoteInputQuickSettingsDisabler: setRemoteInputActive : false` juste
  après le tap confirme que le texte a bien été capturé côté système ;
- mais après ce broadcast, **zéro ligne de log Flutter**, y compris une
  ligne ajoutée spécifiquement comme diagnostic dans
  `notificationActionBackgroundHandler` pour le cas où l'input serait
  vide/null (elle ne s'est jamais déclenchée non plus — le handler Dart ne
  s'exécute donc pas du tout, ce n'est pas juste une branche de code
  manquante).

**Décision avec Salim (2026-08-14) :** masquer les deux boutons (Répondre
**et** Marquer comme lu — même mécanisme de dispatch, donc même panne, même
si seul Répondre a été testé bouton par bouton) plutôt que de laisser une
action qui échoue en silence. Un seul commutateur,
`kNotificationQuickActionsEnabled` dans
[notification_service.dart](lib/core/services/notification_service.dart),
contrôle les deux emplacements où les actions Android sont construites
(`_showLocalNotification` et `_showFallbackMessageNotification`). iOS non
touché — mécanisme de dispatch différent (délégué `UNUserNotificationCenter`,
pas de `ActionBroadcastReceiver`), jamais mis en cause par ce diagnostic.

- [ ] Avant de remettre `kNotificationQuickActionsEnabled` à `true` : relancer
  ce test bout-en-bout sur appareil réel, pas seulement `flutter analyze`.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Réponse rapide depuis la notification n'envoyait jamais rien (2026-08-13) »).

---

## Aperçu de notification en clair (2026-08-13)

**Priorité P2** · importance 2/5 — Une notification de message E2EE affiche « Nouveau message » au lieu du texte ; le serveur, lui, ne voit jamais le clair. *Bloqué : deux comptes.*

**E2EE Signal réel** (`e2eePayloads`/`senderKeyPayload`) : le serveur ne peut
toujours pas déchiffrer — la ligne `notifications` transporte désormais le
vrai payload chiffré (au lieu du placeholder `'[E2EE]'`) pour un
déchiffrement côté client. **Trouvaille en marge** : `setE2EEDecryptionCallback`
n'était appelé **nulle part** dans l'app (vérifié par grep sur tout le
dépôt) — le déchiffrement foreground n'avait donc jamais fonctionné, même
avant ce correctif. Câblé maintenant dans `app.dart`. Ne fonctionnera qu'au
premier plan ; l'arrière-plan nécessiterait de charger tout le magasin de
sessions Signal dans un isolate séparé — non fait, hors périmètre.

- [ ] **Cas E2EE Signal établi (au premier plan) : session réelle obtenue,
      rendu à l'écran non capturé en direct.** En envoyant dans « Diaspora
      Niger — Canada » (`0ce4c63f`, Salim + Sim vrais membres), une session
      Sender Key s'est établie à la volée — vérifié en base :
      `encryptionLevel = 'e2ee'`, `senderKeyPayload` présent dans les deux
      côtés (`messages.data` ET `notifications.data`, donc le cablage SQL qui
      transporte le vrai payload au lieu du placeholder `'[E2EE]'`
      fonctionne), `notifications.body` resté générique côté serveur (jamais
      de fuite). Trois tentatives de capture en direct ont échoué pour des
      raisons de timing/navigation (app repassée en arrière-plan entre
      l'envoi et la vérification, conversation ouverte qui supprime la
      notification, messages de test envoyés par erreur vers `883c9d96` au
      lieu du groupe visé) — jamais une preuve que le déchiffrement échoue.
      Rejeu impossible avec le même message (clé Signal à usage unique,
      supprimée après un déchiffrement réussi — pas une clé « rejouable »
      comme le repli AES). Le code manquant pour ce cas
      (`NotificationDecryptionService` → `MessageCryptoService.decrypt`) est
      le même chemin déjà exercé pour afficher les vrais messages dans une
      conversation ouverte — `flutter analyze` propre, mais pas vu rendre à
      l'écran pour une notification.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Aperçu de notification en clair (2026-08-13) »).

---

## Scroll des notifications — mesuré, pas un défaut de l'écran (2026-08-06)

**Priorité P3** · importance 2/5 — La dernière notification reste à moitié coupée en bas de liste.

- [ ] ⚠ **À refaire au doigt.** Aucun `adb input swipe` n'a fait défiler cette
  liste, et un glissement lent (1500 ms) a été interprété comme un **tap**.
  L'injection n'est pas fiable ici : je ne peux ni confirmer ni infirmer un
  défaut vécu au doigt. Le test : la liste doit remonter de ~87 dp et découvrir
  le bas de la dernière carte.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Scroll des notifications — mesuré, pas un défaut de l'écran (2026-08-06) »).

---

## Push FCM des messages — chaîne serveur rétablie (2026-08-05)

**Priorité P1** · importance 5/5 — Les messages reçus app fermée peuvent ne produire aucune notification, en produire deux, ou ignorer une conversation mutée ou une préférence coupée (aperçu affiché alors qu'il est désactivé). *Bloqué : deux comptes (ou message inséré en base).*

Reste ce que seul un téléphone peut dire — le rendu, le groupement, les
doublons :

- [ ] **Message 1-à-1, app réellement tuée** (balayée des récents, pas
      `force-stop`) : reste à faire.
- [ ] **Conversation ouverte au premier plan** : pas de notification système.
- [ ] **Conversation mutée** : rien n'arrive (le trigger filtre `data.mutedBy`).
- [ ] **« Mes notes »** : s'écrire à soi-même ne déclenche aucune notification.
- [ ] **Bascule push du profil sur `off`** : plus rien n'arrive côté FCM alors
      que la cloche in-app continue de se remplir.
- [ ] **Rebasculer sur `on`** : les notifications reviennent sans redémarrage.

**3. iOS : aucun push possible, à deux niveaux.**

- `aps-environment` ajouté à `ios/Runner/Runner.entitlements`. Sans lui,
  l'enregistrement APNs échouait, `getAPNSToken()` renvoyait nil et
  `_getToken()` sortait avant même d'appeler `getToken()` : aucun token FCM
  n'était jamais enregistré sur iOS.
  ⚠️ **La clé seule ne suffit pas** : il faut activer la capability « Push
  Notifications » sur l'App ID **et** régénérer le profil de provisionnement,
  sinon la signature échoue. Ça se fait dans Xcode, pas ici.
- `saveVoipTokenForUser` est enfin appelée : `_bindVoipTokenTo` branche
  `onVoipTokenUpdated` à la connexion (et rattrape un jeton déjà reçu), et la
  déconnexion vide `users.voip_token`. Sans ça, la colonne restait vide et les
  appels CallKit iOS ne pouvaient pas sonner.

Rien de tout ça n'est vérifiable depuis Windows — aucune de ces cases ne sera
cochée sans un Mac et un appareil iOS.

- [ ] Token FCM enregistré sur iOS après connexion (ligne `users.fcm_tokens`).
- [ ] `users.voip_token` renseigné, et vidé à la déconnexion.

- ✔ 9 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Push FCM des messages — chaîne serveur rétablie (2026-08-05) »).

---

## Écrans de notifications — lot « une seule source » (2026-08-05)

**Priorité P3** · importance 1/5 — Invitations, rappels, abonnés et alertes de proximité portent la même pastille verte — purement visuel.

- [ ] **Relevé au passage — le pilotage `adb` dérive sur cet écran.** Quand
  une notification change de registre, la carte perd sa hauteur et **tout ce
  qui est en dessous remonte** : un tap calculé sur une capture prise 3 s plus
  tôt tombe à côté (deux fois sur trois ici, dont une navigation involontaire
  dans une conversation, et une demande acceptée au lieu d'être refusée).
  Recapturer **juste avant chaque tap**, ou tester au doigt. Ce n'est pas un
  défaut de l'app — c'est une limite de la méthode.
- [ ] **Relevé au passage — la palette de familles rend deux teintes, pas
  quatre.** `groupInvite`, `eventReminder`, `newFollower` et `proximityAlert`
  ressortent toutes du **même vert** : `successColor` et
  `adaptiveSecondaryColor` sont trop proches sur ce thème. Seul l'or des
  commandes se distingue. À arbitrer — soit on assume deux familles visuelles,
  soit on écarte les deux teintes.

- ✔ 35 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Écrans de notifications — lot « une seule source » (2026-08-05) »).

---

# 7. Liens profonds, navigation et QR codes

Liens d'app, routes et gardes du routeur, flèche retour, scanner et QR.

---

## ✅ Filtre hashtag : réparé et vérifié sur SM A515F (2026-09-14)

**Priorité P2** · importance 3/5 — Ouvrir un hashtag alors que le fil est déjà à l'écran annonçait le filtre mais montrait le fil non filtré ; et le filtre ne se levait jamais, donc revenir au fil général le laissait filtré.

**Corrigé et vérifié le 2026-09-14** (`feed_provider.dart`, `feed_screen.dart`,
`feed_supabase_datasource.dart`), couvert par
`test/features/feed/feed_filtre_hashtag_test.dart`.

- [ ] **Depuis un fil déjà ouvert** : toucher un hashtag dans une publication,
  puis un autre — la liste doit changer à chaque fois, pas seulement la
  bannière.
- [ ] **Depuis l'app fermée** (démarrage à froid) : le même lien filtre bien.
  Non rejoué : les deux liens profonds envoyés à chaud **remplacent** la route
  au lieu de l'empiler (le retour système ramène l'accueil, pas le fil).

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Filtre hashtag : réparé et vérifié sur SM A515F (2026-09-14) »).

## ✅ Lien `diasponiger://` au démarrage à froid — corrigé, vérifié SM A515F (2026-09-14)

**Priorité P1** · importance 4/5 — Un lien du schéma maison ouvert alors que l'app n'est pas lancée tombait sur « Page Not Found ». Les QR codes du projet passent tous par ce schéma.

Se rejoue seul : `adb shell am start -a android.intent.action.VIEW -d …`.

**Corrigé** dans
[MainActivity.java](android/app/src/main/java/com/diasponiger/diasponiger/MainActivity.java:332) :
`getInitialRoute()` rend la route remise à plat, et la construction vit
désormais dans `routeDepuisIntent()`, partagée avec `pushRouteFromIntent`.
⚠️ `getInitialRoute()` est **déprécié** dans cet embedding (javac le signale
depuis ce correctif) mais reste le point d'entrée qu'`audio_service` interroge :
à revérifier à chaque montée de Flutter ou d'`audio_service`.

- [ ] **Les autres sections à froid** (`groups`, `profile`, `events`, `posts`) :
      un seul identifiant a été essayé, celui d'une discussion.
- [ ] **Moteur en cache sans activité** (app balayée des récents pendant que le
      service audio tourne) : le lien doit encore arriver — c'est le chemin
      `onCreate` + `pushRouteFromIntent`, non rejoué depuis ce correctif.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Lien `diasponiger://` au démarrage à froid — corrigé, vérifié SM A515F (2026-09-14) »).

---

## ⬜ Un lien Diaspo Niger dans une discussion sortait de l'app (2026-09-12)

**Priorité P2** · importance 3/5 — Taper un lien du projet dans un message affichait « Ouvrir ce lien ? », passait par Android, et la discussion disparaissait : le retour menait ailleurs.

`lib/core/services/qr_code_parser.dart` (`routeInterne`),
`lib/features/messages/presentation/widgets/link_preview_bubble.dart`,
`lib/features/messages/presentation/widgets/message_bubble.dart`.

Corrigé : un seul lecteur, celui du scanner (`QrCodeParser`), et
`context.push` sur la discussion. Le parseur de `DeepLinkService`, déjà repéré comme doublon
à fusionner, est supprimé. Tenu par `test/core/services/liens_dans_l_app_test.dart`
(chaque lien généré par l'app se relit en route ; garde textuel vérifié en
retirant la branche : il tombe).

- [ ] Dans une discussion, taper un lien `https://diasponiger.web.app/feed/<id>`
      écrit en texte : la publication s'ouvre **sans** boîte de confirmation,
      et la flèche ramène **à la discussion**.
- [ ] Même chose avec un lien sans schéma (`diasponiger.com/groups/<id>`).
- [ ] Un lien vers un site tiers garde sa boîte « Ouvrir ce lien ? ».
- [ ] Carte « groupe » partagée dans une discussion : toujours la fiche, retour
      à la discussion (non-régression).

---

## ✅ Lien profond perdu sur une activité neuve — corrigé, vérifié SM A515F (2026-09-11)

**Priorité P2** · importance 2/5 — Sur ces configurations, un lien reçu rouvre l'app sur son dernier écran au lieu de la destination. *Bloqué : appareil Android ≤ 11 ; cas AudioService non reproductible en labo.*

`MainActivity.java`, `lib/core/router/liens_natifs.dart`, `lib/core/router/app_router.dart`.

Le moteur Flutter est mis en cache par `audio_service`. L'embedding ne lit
**jamais** la route de l'intent sur un moteur en cache
(`doInitialFlutterViewRun()` sort dès sa première ligne), `audio_service` ne
la lit qu'à la création du moteur, et `onNewIntent` ne sert qu'une instance
existante. Un lien reçu par une activité **neuve** alors que le processus vit
encore était donc ignoré : l'app se rouvrait sur son dernier écran.

- [ ] Non reproduit en labo : moteur créé par `AudioService` juste avant
      l'activité (le Dart réclame alors la route par `takePendingLink`).
      Couvert seulement par `test/core/router/liens_natifs_test.dart`.
- [ ] Sur un vrai Android ≤ 11 : quitter par le retour, puis taper un lien.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Lien profond perdu sur une activité neuve — corrigé, vérifié SM A515F (2026-09-11) »).

---

## ✅ Repli navigateur des liens d'app — DÉPLOYÉ (2026-09-09 21:5x)

**Priorité P1** · importance 3/5 — Un lien partagé, surtout via WhatsApp, mène à une page qui n'ouvre ni l'app ni le Play Store, et le destinataire décroche.

`public/ouvrir.html` répond désormais à `/groups/**`, `/g/**`, `/feed/**`,
`/events/**`, `/businesses/**`, `/marketplace/**`, `/audio-rooms/**`,
`/podcasts/**`, `/profile/**`, `/p/**`, `/embassies/**`, `/calls/**` — sur
les **deux** sites de `firebase.json`, inséré avant `**`. La page dit le
**type** de contenu (« Groupe », « Événement »…) et jamais lequel : aucun
appel réseau, aucun nom, cohérent avec la garde de `20260909201500`.

- [ ] Une fois déployé : ouvrir `https://diasponiger.web.app/groups/<id>` dans
      **Chrome** sur un téléphone **sans** l'app → page interstitielle, puis
      « Ouvrir dans l'application » → Play Store.
- [ ] Le même lien envoyé par WhatsApp, ouvert dans son navigateur intégré.

---

## ⬜ Lien « Inviter un proche » : il ne menait nulle part (2026-09-09)

**Priorité P2** · importance 3/5 — Les invitations envoyées pointent vers une mauvaise page, ou les anciens liens déjà partagés tombent sur un écran d'erreur.

`generateInviteLink()` fabriquait `/invite?ref=<uid>` et **aucune route
n'existait** pour ce chemin. Mesuré : atterrissage sur l'accueil, `ref` perdu.

Le vrai problème était le choix de la cible : un lien d'invitation s'adresse
par définition à quelqu'un qui **n'a pas** l'app, à qui un lien profond ne
sert à rien. Il pointe désormais `/telecharger`.

Et parce que l'intent-filter App Links revendique l'hôte **entier**, ce lien
ouvre quand même l'app chez qui l'a déjà : deux routes de redirection
(`/telecharger` et `/invite`, ce dernier pour les liens déjà partagés)
renvoient explicitement sur l'accueil, au lieu de dépendre de ce que GoRouter
fait d'un chemin inconnu — il n'y a ni `errorBuilder` ni `onException`.

- [ ] Accueil → « Inviter un proche » → le lien partagé finit par
      `/telecharger?ref=<uid>`.
- [ ] Un ancien lien `/invite?ref=…` → l'accueil aussi.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Lien « Inviter un proche » : il ne menait nulle part (2026-09-09) »).

---

## ⬜ Le scanner de l'accueil lit tous les QR du projet (2026-09-09)

**Priorité P1** · importance 4/5 — Le scanner refuse les QR que l'app fabrique elle-même (« QR code invalide ») : ajout d'amis, partage de groupe et transfert de clés par QR inaccessibles depuis l'accueil.

Le scanner ouvert depuis l'accueil (`/qr-scanner`) ne savait lire qu'un QR de
**profil**. Tout le reste — le QR de groupe que `share_group_modal` affiche
juste à côté, le code de transfert de clés, les liens du site — tombait sur
« QR code invalide ou format non reconnu ».

`lib/core/services/qr_code_parser.dart` (couvert par
`test/core/services/qr_code_parser_test.dart`, 23 cas) reconnaît maintenant
profil (lien long et code court), groupe, fil, événement, entreprise, produit,
ambassade, salon audio, podcast, épisode, appel, le schéma `diasponiger://` et
le rendez-vous de transfert de clés. Rien de tout cela n'a été rejoué caméra en
main :

- [ ] **QR de groupe** — afficher le QR d'un groupe sur un second écran
      (Discussions › groupe › Partager), le scanner depuis l'accueil : la
      fiche du groupe doit s'ouvrir.
- [ ] **QR de profil**, les deux formes : le lien long `/p/u/<id>` (bouton
      « Mon QR Code » du scanner) et le code court `/p/<code>` (dialogue de
      partage du profil, qui passe par le serveur pour être résolu).
- [ ] **Code de transfert de clés** scanné depuis l'accueil : doit basculer
      sur l'écran de récupération avec le message « Code de transfert de clés :
      ouverture de l'écran de récupération. », et **pas** une erreur.
- [ ] **QR d'un autre service** (n'importe quel QR du commerce) : message
      d'erreur, la caméra ne doit pas rester bloquée.

**Piège de mesure (2026-09-09)** : le premier symptôme rapporté (« ça ne marche
pas ») venait d'un APK antérieur au correctif — construit à 19:55, correctif
committé à 20:12. Avant toute conclusion sur un comportement appareil, comparer
`lastUpdateTime` (`dumpsys package`) à l'horodatage du commit.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Le scanner de l'accueil lit tous les QR du projet (2026-09-09) »).

---

## ✅ Trois routes plantaient sur un cast non nullable — corrigées et vérifiées SM A515F (2026-09-08)

**Priorité P1** · importance 4/5 — N'importe quel membre pourrait ouvrir le formulaire d'édition d'un groupe qu'il n'administre pas, par un simple lien.

Les routes résolvent maintenant l'identifiant (`EventEditRoute`,
`EventRecapRoute`, `GroupEditRoute`), et l'état sans contenu passe par une
brique partagée, `DesignUnavailableBody` (design_kit), que la fiche
d'ambassade utilise aussi désormais.

⚠️ **La vraie question n'était pas le plantage.** `EditEventScreen` et
`EditGroupScreen` n'ont **aucune** vérification d'autorisation : elles
faisaient confiance à leur appelant, dont le bouton est masqué derrière
`isOrganizer` / `isCreator || isAdmin`. Un lien profond court-circuite cet
appelant — résoudre l'identifiant sans garde aurait donc ouvert le formulaire
d'édition de l'événement ou du groupe de n'importe qui. Le plantage, lui,
fermait la porte. La garde est portée par les routes, repli superAdmin sur les
groupes officiels compris, et couverte par 11 tests widget.

- [ ] L'équivalent pour un **groupe** dont on n'est pas administrateur :
      toujours pas vu (il faudrait un groupe partagé entre les deux comptes).

- ✔ 7 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Trois routes plantaient sur un cast non nullable — corrigées et vérifiées SM A515F (2026-09-08) »).

---

## ✅ Fiche d'ambassade par lien profond : écran rouge — corrigé et vérifié SM A515F (2026-09-08)

**Priorité P2** · importance 3/5 — Le bouton « détails » de la carte peut encore afficher l'écran rouge « Null check operator » au lieu de la fiche.

La route résout maintenant l'identifiant (`EmbassyDetailRoute` +
`embassyByIdProvider`), avec un état de chargement et deux états nommés, tous
munis d'une sortie (`DesignExitOnlyBody` + bouton « Retour à l'annuaire »).

- [ ] Bouton « détails » de la fiche d'ambassade **sur la carte** : c'est le
      second chemin qui plantait, corrigé par ricochet mais jamais rejoué à
      la main sur appareil.
- [ ] Fiche hors de la juridiction de l'usager ouverte par lien partagé :
      elle doit s'afficher (le filtre de juridiction ne vaut que pour la
      liste). Couvert en test widget, pas sur appareil.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Fiche d'ambassade par lien profond : écran rouge — corrigé et vérifié SM A515F (2026-09-08) »).

---

## ✅ Quatre écrans sans flèche de retour — corrigés et vérifiés SM A515F (2026-09-08)

**Priorité P3** · importance 3/5 — Flèche peu lisible ou difficile à toucher, ou un écran rare sans sortie visible (le geste retour système reste disponible).

La flèche des en-têtes plats est maintenant une brique unique du kit,
`DesignBackLeading` ; les Réglages la dessinaient à la main, ils sont passés
dessus. Verrouillé par `test/core/router/fleche_retour_test.dart`.

Piège de test relevé au passage : en debug, ce téléphone met **plus d'une
minute** à peindre l'écran d'un lien profond à froid, et affiche entre-temps
un aplat gris-bleu vide. Une capture à 30 s montre le gris et se lit comme un
écran cassé. Rafale de `screencap` toutes les 15 s, garder la plus grosse.

Reste à voir, par ordre d'intérêt :

- [ ] **La flèche est-elle lisible sur une image de couverture ?** C'est le
      seul endroit où le contraste n'est pas garanti par le thème :
      `/businesses/:id` et `/marketplace/:productId` posent une vraie photo
      (`CachedNetworkImage`). Non testable ici — l'annuaire est vide sur ce
      compte et la boutique est derrière un drapeau. `/embassies/:id` ne
      compte pas : son en-tête est un aplat teinté, pas une photo.
- [ ] Les ~10 écrans restants atteignables mais non atteints (voir le piège
      d'`am start` ci-dessous).

**Deux pièges de méthode rencontrés, à retenir :**

1. **L'autre agent installe son APK sur le même téléphone.** À 01:13:54 le
   `base.apk` a changé en plein test : mes mesures des dix minutes suivantes
   ne portaient pas sur mon build, et j'ai failli conclure qu'un écran
   corrigé n'avait pas de flèche. Encadrer **chaque** mesure d'un contrôle
   `md5sum` local ↔ appareil, avant *et* après — pas seulement à
   l'installation.
2. **Le lien profond à froid retombe sur `/home` de façon intermittente.**
   Course entre le `redirect` de démarrage (auth, consentement, config) et le
   rejeu du lien mis de côté. Un `uiautomator dump` qui montre `Bonjour,`
   (accueil) ou `Diaspo Niger` (splash) est une mesure **ratée**, pas un
   écran sans flèche : toujours identifier l'écran atteint avant de conclure.
   Plus fiable : lancer l'app, attendre qu'elle soit posée, puis envoyer les
   intents à chaud.

- [ ] Rendu en **thème clair** : les quatre écrans n'ont été vus qu'en sombre.
- [ ] Zone tactile de `DesignBackLeading` : 28x34 dp, sous les 48 dp
      recommandés. C'est la dimension que les Réglages embarquaient déjà.
      Atteinte du premier coup lors du test, mais avec un tap `adb` au pixel
      près — pas au pouce.

- ✔ 9 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Quatre écrans sans flèche de retour — corrigés et vérifiés SM A515F (2026-09-08) »).

---

## Feuille de partage fantôme au démarrage (2026-08-04)

**Priorité P1** · importance 4/5 — Une feuille de partage fantôme se rouvre à chaque démarrage, ou le partage depuis une autre app échoue ou s'ouvre en double.

Bug constaté sur appareil (SM A515F) : la feuille « Envoyer à… / Partagé
depuis une autre app », pastille « 1 texte », se rouvrait par-dessus l'accueil
à **chaque** démarrage à froid, sans qu'aucun partage n'ait été fait.

Cause : `receive_sharing_intent` traduit tout `ACTION_VIEW` sans type MIME en
élément `SharedMediaType.url`, et Android redonne à l'activité racine l'intent
d'origine de sa tâche à chaque relance. Une seule ouverture par lien profond
(`diasponiger://`, `diasponiger.web.app`) suffisait donc à faire revenir le
faux « 1 texte » indéfiniment. Corrigé en écartant les éléments `url` (l'app ne
déclare aucun filtre `ACTION_SEND`), en purgeant l'état natif via `reset()`, et
en attendant la réponse du canal natif avant de marquer le contenu consommé.

Rien de tout ça n'est vérifiable sans appareil :

- [ ] Ouvrir un lien profond (`https://diasponiger.web.app/feed/<id>`) pour
      réarmer l'intent de tâche, puis `am force-stop` + relance : **la feuille
      ne doit plus apparaître**. C'est le cas décisif.
- [ ] Répéter la relance 3 ou 4 fois de suite — le symptôme était systématique.
- [ ] Fermer la feuille sans envoyer puis relancer : le contenu ne doit pas
      revenir.

### Partage entrant activé le même jour

Les `intent-filter ACTION_SEND` / `SEND_MULTIPLE` ont été ajoutés au manifest
dans la foulée (text, image, video, `*/*`) : jusque-là l'app n'apparaissait pas
dans le sélecteur « Partager » et `ShareToConversationScreen` n'était
atteignable par aucun partage réel.

⚠️ **Ça remet le bug ci-dessus en jeu pour de vrai** : un partage devient
l'intent d'origine de la tâche, qu'Android redonne à chaque relance — et un
`text/plain` légitime n'est plus filtrable comme l'était le faux `url`. Deux
barrières ajoutées : `MainActivity.clearSharedIntent()` (neutralise
`activity.getIntent()`, couvre rotation et retour depuis les récents) et une
**empreinte SHA-256 persistée** du dernier partage présenté, seule protection
qui survive au redémarrage du process. Aucune des deux n'a tourné sur appareil.

- [ ] Partager un texte depuis Chrome ou Messages : Diaspo Niger doit
      apparaître dans le sélecteur, la feuille s'ouvrir, l'envoi aboutir.
- [ ] **Puis `am force-stop` + relance : la feuille ne doit PAS revenir.**
      C'est le cas décisif de l'empreinte persistée.
- [ ] Idem avec une image, une vidéo, un PDF, et une sélection multiple
      d'images (`SEND_MULTIPLE`).
- [ ] Partager pendant que l'app tourne déjà (flux temps réel, pas le contenu
      initial) — vérifier qu'une seule feuille s'ouvre, sans doublon.
- [ ] Tourner l'écran feuille ouverte, puis revenir depuis les récents : pas de
      seconde feuille.
- [ ] Limite assumée : partager **exactement** le même contenu deux fois de
      suite en tuant l'app entre les deux est ignoré la 2ᵉ fois. Vérifier que
      ça reste supportable en usage réel.

### Liens profonds routés vers `/feed/:id` (2026-08-04)

⚠️ **Le clic sur un lien n'ouvre l'app que si sa signature est déclarée.**
`assetlinks.json` couvre maintenant Play App Signing **et la clé release
locale** (`DD:A6:5C:…`), et il est **déployé** depuis le 2026-08-04 sur
`diasponiger.web.app` comme sur `diaspo-niger.web.app` — donc un APK release
installé à la main vérifie ses liens. La clé **debug** (`87:32:AD:…`) n'y est
pas : sur un build debug, Android ouvrira Chrome.

Contournement retenu, **déjà appliqué sur le téléphone de test** : approuver
les domaines à la main, ce qui court-circuite la vérification serveur (le
`Selection state` passe à `Enabled`, `Verification link handling allowed:
true`). À refaire après chaque réinstallation :

```
adb shell pm set-app-links-user-selection --user 0 --package com.diasponiger.diasponiger true diasponiger.web.app
adb shell pm set-app-links-user-selection --user 0 --package com.diasponiger.diasponiger true diasponiger.com
adb shell pm get-app-links --user 0 com.diasponiger.diasponiger
```

À défaut, un intent explicite contourne aussi la résolution — mais il ne teste
alors plus le chemin réel d'un clic sur un lien :

```
adb shell am start -a android.intent.action.VIEW -d "https://diasponiger.web.app/feed/<postId>" com.diasponiger.diasponiger
```

- [ ] **Déconnecté** puis lien : doit passer par la connexion et **arriver sur
      la publication** une fois connecté.
- [ ] Lien vers un post supprimé ou un id inexistant : vérifier que
      `PostDetailScreen` dégrade proprement au lieu de planter.

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Feuille de partage fantôme au démarrage (2026-08-04) »).

---

# 8. Comptes, session et onboarding

Connexion, déconnexion, session Supabase, onboarding et assistant de profil, blocage.

---

## ⬜ Supprimer mon compte : demande, 30 jours, annulation, purge (2026-09-18)

**Priorité P0** · importance 5/5 — « Supprimer mon compte » ne supprimait presque
rien : le profil, les publications, les messages, les amis et l'adresse e-mail
(dans `auth.users`) restaient en base, seul le compte Firebase disparaissait,
et le dialogue promettait « toutes vos données supprimées définitivement ».
C'est un motif de refus Play et un défaut de conformité. Le nouveau flux
DÉTRUIT des données pour de bon : il se vérifie sur des comptes jetables, jamais
sur un vrai compte.

Modèle : demande → désactivation immédiate → **30 jours** → purge. La demande
(`request_account_deletion`) masque le compte tout de suite ; se reconnecter
avant l'échéance l'annule ; à l'échéance une Cloud Function supprime le compte
Firebase PUIS purge Supabase en une transaction.

*Bloqué : demande deux téléphones, deux comptes jetables et l'accès à la base.*

**Jamais vu sur appareil, et aucune demande réelle n'a encore traversé la chaîne.**

Fichiers : [migration](supabase/migrations/20260918224100_suppression_de_compte_par_phases.sql),
[banc SQL](tools/rls_tests/suppression_compte.sql) (49 cas, rejoué dans un
`BEGIN … ROLLBACK` en production le 2026-09-18 : 0 échec, état intact après),
[fonction planifiée](functions/index.js) (`finalizeAccountDeletions`),
[datasource](lib/features/auth/data/datasources/auth_remote_datasource.dart),
[écran d'annulation](lib/features/auth/presentation/screens/account_deletion_pending_screen.dart),
[porte du routeur](lib/core/router/app_router.dart) (étape 3b).

- [ ] **Premier passage sur une vraie demande** : sur un compte jetable dont on
  avance `execute_at`, la fonction supprime le compte Firebase (`deleteUser`)
  PUIS appelle `complete_account_deletion`, dans cet ordre ; `ok: true`,
  `summary` renseigné, ligne `completed`. C'est ce passage-là, et lui seul, qui
  prouve que `claim_due_account_deletions` rend bien les comptes dus.
- [ ] **Demande, compte à mot de passe connecté depuis plus de 4 minutes** :
  le mot de passe est demandé AVANT toute désactivation. Un mot de passe faux
  ne désactive rien (`account_deletion_requests` reste vide).
- [ ] **Demande aboutie** : snackbar « Compte désactivé. Suppression définitive
  le … » avec la bonne date (+30 jours, dans la langue de l'appareil), retour sur
  l'écran de connexion, ligne `pending` en base, `users.is_private = true`,
  `fcm_tokens = []`.
- [ ] **Vu d'un AUTRE compte** : le profil, les publications et les stories du
  compte désactivé ont disparu (profil, fil, stories) ; ses messages restent
  dans les groupes.
- [ ] **Se reconnecter pendant le délai** : l'écran « Suppression du compte
  programmée » avec la date, et rien d'autre (ni onglets, ni retour possible).
  « Se déconnecter » fonctionne.
- [ ] **Annuler** : retour sur l'accueil, profil et publications de nouveau
  visibles, commerces réactivés. ⚠ Les notifications push ne reprennent que si
  le jeton FCM est ré-enregistré (la RPC ne le restaure pas) : vérifier
  `users.fcm_tokens` non vide après la reconnexion.
- [ ] **Deuxième téléphone connecté au même compte** au moment de la demande :
  mesurer QUAND il tombe sur l'écran d'annulation (sa session Supabase est
  révoquée, mais son jeton peut vivre jusqu'à une heure).
- [ ] **Compte Google ou Apple** : aucune demande de mot de passe (limite
  connue : la ré-authentification ne sait pas rejouer un fournisseur social).
- [ ] **Échéance** (avancer `execute_at` en base sur le compte jetable, puis
  attendre le passage horaire ou invoquer la fonction) : le compte Firebase
  disparaît (connexion impossible), `cleanupUserData` a tourné (Firestore,
  Storage), `account_deletion_requests.status = completed` avec son `summary`,
  plus aucune ligne `users` / `auth.users` / `auth_mappings`.
- [ ] **Se réinscrire avec la MÊME adresse e-mail** : un compte neuf et vide,
  pas rattaché à l'ancien (l'échange Firebase retrouve l'utilisateur par
  e-mail ; c'est pour cela que `auth.users` est supprimé).
- [ ] **Dans un groupe où le compte était** : ses messages en clair s'affichent
  « Compte supprimé » sans plantage de l'écran (l'`uid` `compte_supprime` est
  inconnu du client : avatar et nom de repli) ; le groupe a un nouveau
  propriétaire qui peut administrer ; les conversations à deux ont disparu chez
  l'autre.
- [ ] **Conversation MLS** : les messages du compte supprimé s'affichent
  « message supprimé » chez les autres, sans plantage.
- [ ] **Fenêtre de résurrection** : juste après la déconnexion de la demande, la
  ligne `users` n'est PAS recréée par un échange de jeton (l'app ne doit rien
  écrire en tâche de fond pour un compte masqué). À observer sur la base.
- [ ] **Hors ligne** : se connecter avec un compte `pending` sans réseau laisse
  entrer (choix assumé : une lecture ratée ne doit pas enfermer ; le compte
  reste masqué côté serveur). À confirmer, et que la porte se ferme au retour du
  réseau.
- [ ] **Thème sombre et grande police** sur l'écran d'annulation, et sur le
  dialogue de confirmation dont le texte est long (~20 lignes : il doit
  défiler, sans débordement sur un petit écran).
- [ ] **NE PAS tester sur le compte plateforme** : la demande y est refusée
  (`compte_plateforme`) — c'est le banc SQL qui le prouve, pas un téléphone.

- [ ] **Feuille MLS d'un appareil supprimé** (corrige une limite annoncée à
  tort) : après la purge d'un compte jetable membre d'un groupe chiffré, un
  autre membre EN LIGNE commite le retrait dans l'instant (la purge retire la
  personne de `participant_ids`, ce qui déclenche
  `MlsGateway.appartenanceChangee` → `reconcileMembership`) ; un membre hors
  ligne le fait à son prochain envoi. À vérifier : le groupe continue de
  fonctionner pour les autres, l'epoch avance, et l'arbre public
  (`mls_group_info`) ne contient plus la feuille supprimée. Le banc MLS le
  prouve sur le vrai moteur (« appareil révoqué : retiré au prochain
  reconcile ») ; il ne prouve ni le déclenchement par la purge ni le réseau.
- [ ] **Après une restauration Supabase** (`docs/deploiement/ROLLBACK_AND_DATA.md`,
  § 2.1) : `finalizeAccountDeletions` a été redéployée seule le 2026-09-19 (v2, avec
  l'écriture de `deleted_accounts/<uid>` dans le code en ligne). Sur un compte
  jetable : la pierre
  tombale est écrite AVANT la purge ; `node
  tools/rejouer_suppressions_apres_restauration.mjs` en simulation ne liste rien
  d'autre que des comptes à restes ; procédure essayée UNE FOIS à blanc (restaurer
  n'est pas nécessaire : recréer à la main des restes pour l'uid jetable suffit).

- [ ] **Effacement différé des clés et de la base MLS du téléphone** (migration
  `20260919123300` appliquée le 2026-09-19 ; si la RPC répondait 404 — base
  restaurée à un état antérieur —, le passage garde ses marqueurs et n'efface
  RIEN). Sur un compte jetable, dans cet ordre :
  1. demander la suppression : la clé SharedPreferences `effacement_local_differe_v1`
     porte l'uid et l'échéance, et le fichier `<uid>.sqlite` (dossier `mls/` de
     l'application ; conteneur du groupe d'application sur iOS) existe toujours ;
  2. **annuler** : le marqueur disparaît ; l'app retrouve ses messages chiffrés
     (rien n'a été perdu) ;
  3. redemander, puis passer la ligne à `completed` en base (compte jetable
     seulement) et avancer l'horloge du téléphone de deux jours : au lancement
     suivant, `<uid>.sqlite` et ses `-wal`/`-shm` ont disparu, les clés Signal et
     `aes_derivee_*` aussi, et l'application démarre sans erreur ;
  4. **un autre compte du même téléphone n'est pas touché** : sa base, ses
     vérifications, ses curseurs de lecture.
- [ ] **Effacement différé : les refus.** Annulée sur un autre appareil (compte
  vivant) : le serveur répond faux, RIEN n'est effacé, et le marqueur disparaît à
  la reconnexion. Téléphone hors ligne au lancement : rien n'est effacé, aucun
  plantage, réessai au lancement suivant. Compte connecté : jamais effacé.
- [ ] **Le dialogue de confirmation** annonce l'effacement des clés « au premier
  lancement de l'application qui suit la suppression définitive » — et non à
  l'instant : vérifier que le texte (long) défile sans débordement.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Supprimer mon compte : demande, 30 jours, annulation, purge (2026-09-18) »).

---

## ⬜ Expulsion admin et bannissement : ils n'éjectaient personne (2026-09-16)

**Priorité P0** · importance 5/5 — Un compte banni depuis la console restait
pleinement actif sur son téléphone : il continuait d'écrire, de recevoir ses
notifications et de lire ses discussions, pendant que la console affichait
« banni » et que l'audit enregistrait un succès. La modération ne pouvait donc
rien arrêter en cours de route.

À vérifier **à deux appareils** : un téléphone connecté sur un compte
ordinaire, l'autre sur la console admin.

*Bloqué : demande un second téléphone et un compte admin.*

Fichiers : [session_service.dart](lib/core/services/session_service.dart)
(`_surveillerDecisionsAdmin`, `doitEjecterSurDecisionAdmin`),
[admin_provider.dart](lib/features/admin/presentation/providers/admin_provider.dart)
(`forceLogoutUser`, `banUser`). Banc :
[session_expulsion_admin_test.dart](test/core/services/session_expulsion_admin_test.dart)
— il couvre la décision, pas le transport Realtime ni la RLS, qui sont
justement ce qui reste à prouver ici.

- [ ] **« Déconnecter » depuis la console** : le téléphone sort **dans la
  seconde**, sans rien toucher, et affiche « Session fermée » — pas
  « Connecté ailleurs ».
- [ ] **Se reconnecter juste après** : ça marche du premier coup. C'est le
  test de l'effacement de la sentinelle ; s'il rate, le compte est expulsé à
  chaque connexion, définitivement.
- [ ] **Bannir depuis la console** : le téléphone sort et affiche « Compte
  suspendu ».
- [ ] **Sur un compte SANS document Firestore `users`** (46 sur 54 le
  2026-09-16 — donc presque n'importe quel compte autre que ceux de test) :
  l'expulsion marche quand même. C'est tout l'objet du correctif ; le tester
  sur un compte de test qui a un document Firestore ne prouverait rien.
- [ ] **Application en arrière-plan** au moment de l'expulsion : au retour au
  premier plan, l'appareil est bien sorti (la lecture initiale rattrape ce que
  le canal Realtime a manqué).
- [ ] **Après `flutter build apk --release`** : vérifier sur un build release,
  le canal Realtime dépendant de la session Supabase — voir « Session Supabase
  non établie » ne compte plus comme un plantage.
- [ ] **Compte de la liste `multiAppareilComptes`** : il n'est PAS expulsé,
  bannissement compris (choix assumé — voir « Verrou de version minimale et
  multi-appareil »).
- [ ] **Rien de neuf n'éjecte** : un compte ordinaire, non banni, sur un seul
  téléphone, reste connecté toute une session d'usage normal. Ce canal ne
  porte que des décisions admin ; s'il se met à éjecter sur autre chose, c'est
  « une seule session » qui vient d'être généralisée par accident.
- [ ] **Thème sombre** et **grande police** sur les deux nouveaux dialogues.

---

## ⬜ Verrou de version minimale et multi-appareil (2026-09-15)

**Priorité P1** · importance 5/5 — Deux préalables du plan MLS, construits le
même jour et **tous deux inertes par défaut**. Ce qui doit être vérifié, c'est
justement qu'ils restent inertes tant qu'on ne les ouvre pas : une erreur dans
l'un ferme l'application à tout le monde, une erreur dans l'autre déconnecte
sans raison.

*Bloqué : le verrou demande de publier `VERSION_MINIMALE_APP` ; le
multi-appareil demande d'ajouter un compte à `multiAppareilComptes` et un
second téléphone.*

**⚠️ Rectifié le 2026-09-21 : jusqu'à ce jour, publier le secret n'aurait
RIEN fait.** `VERSION_MINIMALE_APP` manquait à la liste blanche d'`app-config`
(`CLES_PUBLIQUES`) : le verrou lisait une clé que la fonction ne servait
jamais, quoi qu'on pose dans les secrets. Ajoutée et **déployée (v5)** le
2026-09-21 — réponse relue octet pour octet identique avant et après (même
empreinte, secret non posé), 200 sans aucun en-tête, donc démarrage avant
connexion intact. Le blocage n'est plus que de poser le secret, et c'est sans
risque pour tester les trois premières cases : le client refuse de bloquer tant
que `DERNIERE_VERSION_APP` est inférieure à la version exigée. Ce verrou est la
condition 3 de la fermeture 1.1b (voir « `users` : un compte connecté lit
e-mail, position et jetons d'autrui »).

Fichiers : [version_minimale.dart](lib/core/services/version_minimale.dart),
[ecran_mise_a_jour_requise.dart](lib/core/shell/ecran_mise_a_jour_requise.dart),
[session_service.dart](lib/core/services/session_service.dart) (`doitEjecter`).

- [ ] **Sans rien publier** : l'application démarre normalement (c'est l'état
  du jour, à confirmer après la mise à jour du build).
- [ ] **`VERSION_MINIMALE_APP` égale à la version installée** : rien ne
  bloque.
- [ ] **Version minimale supérieure à ce que sert le store** : rien ne bloque
  non plus — c'est le garde principal, et il se vérifie en production, pas
  seulement au banc.
- [ ] **Version minimale atteignable** : l'écran de blocage s'affiche, sans
  moyen d'en sortir, et le bouton ouvre bien la fiche du store.
- [ ] **Thème sombre** et **grande police** sur cet écran : il n'a pas de
  défilement horizontal et le bouton reste atteignable.
- [ ] **Multi-appareil fermé** : se connecter sur un second téléphone
  déconnecte toujours le premier (« Connecté ailleurs »).
- [ ] **Multi-appareil ouvert pour le compte de test** : les deux téléphones
  restent connectés, et chacun reçoit les messages.
- [ ] **Transfert de clés** depuis l'ancien téléphone, multi-appareil ouvert :
  vérifier que le dépôt marche toujours **après** connexion du neuf — l'ordre
  imposé jusqu'ici n'a plus de raison d'être, mais rien ne le prouve encore.

---

## ⬜ « Session Supabase non établie » ne compte plus comme un plantage (2026-09-11)

**Priorité P2** · importance 2/5 — Rien de visible si le correctif ne tient pas (faux plantages fatals dans Crashlytics) ; s'il a cassé l'écriture, le statut « En ligne » devient faux.

Les quatre appels passent désormais par `_marquerDerniereConnexion`, « au
mieux » avec `catchError`, sur le modèle de `_initializeE2EE` juste à côté. Rien
d'important n'est perdu : l'horodatage est réécrit à la prochaine ouverture de
session. Garde-fou :
[derniere_connexion_au_mieux_test.dart](test/features/auth/derniere_connexion_au_mieux_test.dart)
— un seul appel à `updateLastLogin` dans le fichier, et il attrape l'échec.

⚠️ Attribution **par le code, pas par la pile** : la fiche Crashlytics de ce
problème n'a pas été ouverte. Les autres appelants de `_requireAuth` sont des
écritures déclenchées par l'utilisateur et attendues dans un `try` ; celui-ci
est le seul lancé à vide. Si le problème réapparaît sur une version qui porte
le correctif, c'est que l'attribution était incomplète.

- [ ] **Crashlytics** : plus aucun « Session Supabase non établie » sur la
  version qui embarque le correctif.
- [ ] **Non-régression** : après connexion, le profil affiche toujours
  « En ligne » (c'est `lastLoginAt` qui le nourrit) — sur un compte existant,
  en ligne.

---

## ⬜ Onboarding rejoué : une lecture en échec n'est plus « jamais vu » (2026-09-10)

**Priorité P1** · importance 5/5 — Un utilisateur sur réseau lent ou coupé se voit rejouer consentement, assistant de profil (qui peut réécrire son nom) et carrousel d'accueil.

**Ce qui a été observé.** Le 2026-09-10 sur SM-A515F (`R58N91XBA7B`), compte
« Sim A », après plusieurs `adb install -r` d'un APK release : l'app a démarré
sur l'onboarding 1/5 alors que le compte l'avait terminé de longue date.

**Le défaut corrigé est donc bien celui-là.** Un échec de lecture était
converti en `false`, c'est-à-dire en « rejoue tout ».
`SupabaseAuthBridge.ensureReadableSession` rend la main au bout de **3 s sans
session** en laissant la synchronisation finir en tâche de fond : un démarrage
à froid sur réseau lent dépasse ce budget et faisait tomber les quatre
drapeaux ensemble — consentement (réécrit `consent_date`), assistant de profil
en 4 étapes (**écrit dans le profil, peut renommer le compte**), puis l'intro.
L'indéterminé est désormais distinct de `false` de bout en bout, et ne
redescend jamais un drapeau. Verrouillé par
`test/features/onboarding/lecture_en_echec_test.dart` (21 cas).

À vérifier sur appareil — rien de tout ceci n'est observable par
`flutter test` :

- [ ] **Compte neuf** : créer un compte et confirmer que consentement,
      assistant de profil puis les 5 écrans d'intro s'affichent bien dans cet
      ordre. C'est le cas que le repli optimiste pourrait avaler ; le test
      « les quatre lectures rendent false » le couvre en unitaire, pas en
      vrai.
⛔ **La reproduction hors ligne ne se rejoue plus telle quelle, et c'est le
piège de ce test.** En tapant « Passer » le 2026-09-10, `completeIntro()` a
écrit le drapeau **des deux côtés** — base *et* SharedPreferences. Or le dépôt
consulte le local en premier : sur « Sim A », `has_seen_onboarding` est
désormais vrai en cache, donc **plus aucun appel réseau n'est émis** pour ce
drapeau. Mode avion ou pas, il n'y a plus rien à observer. Un « ça ne fait plus
le bug » mesuré comme ça ne prouve **rien** : le correctif n'est même pas
sollicité.

Pour que le correctif soit sollicité, il faut réunir les trois à la fois :
authentifié, **drapeau local absent**, réseau coupé. Le drapeau local ne
s'efface ni par `adb install -r` (qui conserve les données) ni depuis ce poste
(build release, `run-as` refusé). Il faut donc `pm clear`, qui emporte aussi la
session Firebase — **et une reconnexion, qui ne peut être faite que par
l'utilisateur au téléphone.**

- [ ] **Le test décisif** (demande une reconnexion manuelle) :
      1. `adb -s R58N91XBA7B install -r <apk>` — l'APK doit être signé avec
         `android/app/diaspo-niger-release.jks`, sinon la signature diffère et
         Android impose une désinstallation ;
      2. `adb -s R58N91XBA7B shell pm clear com.diasponiger.diasponiger` ;
      3. **l'utilisateur se reconnecte** sur un compte dont
         `has_seen_onboarding` vaut **`false`** en base. Le drapeau restant
         faux côté serveur, il n'est jamais recopié en local : la condition
         « local absent » se maintient toute seule, autant de fois qu'on veut.
         ⚠️ **Deux comptes de test quasi homonymes coexistent**, et ils ne sont
         pas dans le même état — se tromper de l'un pour l'autre donne deux
         conclusions opposées :
         - `test.diaspo@`**`example`**`.com` (« Compte Test », celui de
           `scripts/creer_compte_test.js`) : les **quatre** drapeaux à `true`,
           donc **inutilisable tel quel** pour ce test ;
         - `test.diaspo@`**`exemple`**`.com` (« Test User », orthographe
           française, visiblement créé par accident) : `has_seen_onboarding` et
           `profile_config_complete` à `false` — **c'est celui-ci qu'il faut**,
           et il ne demande aucune écriture en base.

      ⚠️ **Ne pas terminer l'assistant de profil après la reconnexion.** Sur
         ce compte, `profile_config_complete` est faux : la connexion en ligne
         atterrit sur `/profile-config`. Le finir écrirait `true` en base ET en
         local, et détruirait la condition du test. Tuer l'app là, sans
         toucher à l'assistant.
      4. mode avion, puis redémarrage forcé de l'app.
      Attendu **après correctif** : `/home`.
      ⚠️ **Avant correctif, l'écran fautif n'est PAS le carrousel de
      bienvenue, c'est `/profile-config`** — et confondre les deux ferait
      conclure à tort que « ça ne fait plus le bug ». Raison : `_lireDrapeau`
      ne mémorise en local que les `true`. À la reconnexion en ligne,
      `has_given_consent` (vrai en base) est donc mis en cache, alors que
      `profile_config_complete` et `has_seen_onboarding` (faux en base) ne le
      sont pas. Hors ligne, seuls ces deux-là repassent par le réseau, et le
      routeur teste le profil (étape 7) **avant** l'intro (étape 8). C'est
      donc `/profile-config` vs `/home` qui distingue les deux builds.

- [ ] **La reprise** : la lecture indéterminée est retentée une fois après 4 s
      (`OnboardingNotifier.delaiDeReprise`). Sur un compte neuf dont la
      première lecture échoue, l'écran de consentement doit apparaître ~4 s
      après l'entrée dans l'app, pas jamais.
- [ ] **Réinstallation** : `adb install -r` conserve les préférences, une
      désinstallation non. Vérifier qu'après désinstallation + réinstallation,
      un compte à jour côté serveur ne rejoue **pas** l'onboarding — c'est la
      moitié serveur du garde-fou.

⚠️ Le drapeau local ne se relit pas depuis ce poste : le build de l'appareil
est **release**, `run-as` répond « package not debuggable ». Pour départager
local et distant, passer par `public.users` en base, pas par `shared_prefs/`.

### ⬜ Reprise des drapeaux restés sur Firestore (2026-09-10)

Inventaire fait le 2026-09-10, une fois le correctif de lecture posé : la
lecture réussit désormais, mais elle peut rendre un `false` **sincère et
périmé** — le compte a fini son onboarding avant la bascule du 2026-08-13
(`160d417`), quand l'app écrivait ces drapeaux sur Firestore.

`supabase/migrations/20260910071000_reprise_drapeaux_onboarding_firestore.sql`
monte donc **une seule ligne**, par `or` colonne par colonne (jamais une
affectation sèche) et `coalesce` sur `consent_date` : rejouer la migration ne
change rien, et aucun drapeau ne peut redescendre.

À vérifier sur appareil :

- [ ] **Le compte repris ne rejoue plus rien** : se connecter avec
      `czk5UoUclLOFmbRtUIZ5XYLYKo52` sur un téléphone où l'app vient d'être
      **désinstallée** (le cache local masquerait le résultat — `adb install -r`
      ne suffit pas). Attendu : `/home` directement, ni consentement, ni
      assistant de profil, ni les 5 écrans d'intro.
- [ ] **Ce compte n'a pas de `display_name`** (`handle = 'diaspo_ne'` et
      `country_code = 'NE'` sont posés, le nom non) : l'assistant de profil a
      tourné le 2026-08-13 sans que tout arrive en base. Monter
      `profile_config_complete` le fait donc entrer dans l'app **sans nom
      affiché**. Regarder ce que donnent le profil, le bandeau de complétude
      (§11f) et l'en-tête des discussions dans cet état — c'est le seul point
      où cette migration peut se voir en mal.

---

## ⚠️ Hors ligne, un compte connecté est renvoyé sur l'onboarding (2026-09-10)

**Priorité P1** · importance 3/5 — Un compte connecté qui perd le réseau (métro, avion, zone blanche) est renvoyé sur le carrousel de bienvenue.

Trouvé par accident en coupant le réseau pour déclencher une erreur de carte.
Le compte était connecté, l'app affichait la carte en mode public. Mode avion
activé, un rechargement forcé → l'app bascule sur **« Bienvenue sur Diaspo
Niger »**, le carrousel d'accueil.

**La session n'est PAS perdue** — c'est le point rassurant, et il a demandé
d'être vérifié : « Passer » ramène directement à l'accueil connecté (« Bonjour,
Sim », messages non lus et notifications intacts). Aucun `FATAL EXCEPTION`, et
le pid n'a pas changé : l'app n'a ni planté ni redémarré, elle a **navigué**.

**Correctif proposé, non appliqué** : pour un utilisateur **déjà authentifié**,
un échec de lecture devrait valoir « ne pas interrompre » plutôt que « jamais
vu ». Se tromper dans ce sens coûte un carrousel sauté une fois ; se tromper
dans l'autre coûte une interruption à chaque coupure réseau. Non appliqué parce
que toucher à une garde du routeur est précisément ce qui a déjà coûté cher ici
(gating feature-flag, garde de session) — à décider explicitement.

✅ **Tranché et appliqué le 2026-09-10**, exactement dans ce sens, et **sans
toucher au routeur** : c'est la valeur qu'on lui donne qui change, pas la
règle 8. Voir « ⬜ Onboarding rejoué : une lecture en échec n'est plus “jamais
vu” » en tête de fichier — l'indéterminé y devient une valeur à part entière de
la source distante jusqu'au notifier, et 21 cas le verrouillent. Cette
observation-ci reste la seule reproduction **à volonté** du défaut : c'est elle
qu'il faut rejouer pour valider le correctif sur appareil.

- [ ] **Reproduire proprement** : compte connecté, mode avion, naviguer →
  le carrousel doit apparaître. Puis vérifier qu'après retour du réseau **et**
  redémarrage l'app revient d'elle-même à l'accueil (observé une fois : elle
  restait sur l'onboarding, réseau rétabli, y compris après redémarrage — mais
  le Wi-Fi pouvait n'être pas encore rétabli au lancement, donc à confirmer).

---

## ⚠️ Déconnexion — latence supprimée, à vérifier sur appareil

**Priorité P3** · importance 2/5 — Le tap de confirmation peut atterrir sur la boîte « Connecté ailleurs » superposée ; gêne ponctuelle, sans perte.

Désormais `signOut()` rend la main dès que le jeton Firebase est effacé ; le
ménage distant (jeton FCM, révocation Supabase, compte Google) part en tâche
de fond, dans cet ordre car la révocation coupe la session dont le retrait du
jeton a besoin. La purge locale (Hive, préférences, pièces jointes en clair)
reste attendue : elle décide de ce dont le compte suivant hérite.

Fichiers : `lib/features/auth/data/repositories/auth_repository_impl.dart`,
`lib/features/auth/data/datasources/auth_remote_datasource.dart`,
`lib/features/profile/presentation/screens/profile_screen.dart`.

- [ ] **⚠️ Le dialogue « Connecté ailleurs » peut avaler le tap.** Rencontré le
      2026-09-08 : `SessionService._handleForceLogout()` a ouvert sa boîte
      par-dessus le dialogue de déconnexion, et le tap de confirmation a
      atterri dessus — première mesure perdue. À vérifier avant d'appuyer.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⚠️ Déconnexion — latence supprimée, à vérifier sur appareil »).

---

## ⬜ Déconnexion forcée « Connecté ailleurs » — trois trous refermés

**Priorité P0** · importance 3/5 — Après une éjection « Connecté ailleurs », le compte suivant hérite des caches et pièces jointes en clair, et l'appareil continue de recevoir les notifications du compte sorti. *Bloqué : second appareil connecté au même compte.*

Trouvée en mesurant la latence ci-dessus. Cette voie ne faisait que
`FirebaseAuth.signOut()` + `clearSessionId()`, d'où trois défauts :

- **ni purge des caches, ni des préférences personnelles, ni des pièces
  jointes en clair** — le compte suivant sur ce téléphone en héritait ;
- **ni retrait du jeton FCM** — l'appareil restait inscrit aux notifications
  du compte sorti ;
- **`AuthState` restait sur `authenticated`** alors que Firebase était sorti :
  le garde du routeur (« si non authentifié → /auth/login ») ne voyait rien,
  seule la navigation explicite du bouton OK masquait l'incohérence.

- [ ] **Provoquer la déconnexion forcée** : se connecter au même compte sur un
      second appareil, et sur le premier vérifier que le dialogue apparaît,
      que OK mène bien à l'écran de connexion, et que le texte est traduit
      (basculer la langue de l'appareil pour voir la version anglaise).
- [ ] **Nettoyage après déconnexion forcée** : sur l'appareil éjecté, vérifier
      que les boîtes Hive de `app_flutter/` sont à 0 octet, que
      `currentUserId` a disparu de `FlutterSharedPreferences.xml`, et que le
      jeton FCM de cet appareil ne figure plus dans `users.fcm_tokens`. Rien
      de tout cela n'avait lieu avant.
- [ ] **Cohérence du routeur** : après l'éjection, ne pas toucher OK et tenter
      d'atteindre un écran protégé par lien profond — le garde doit renvoyer
      sur `/auth/login`, ce qu'il ne faisait pas quand `AuthState` restait
      `authenticated`.
- [ ] **Session Supabase périmée** : laisser l'app en arrière-plan plus d'une
      heure (le timer de renouvellement du pont ne tourne pas en veille), la
      rouvrir, se déconnecter aussitôt. C'est le seul cas où `signOut()`
      attend encore quelque chose de réseau : une re-mint bornée à 3 s, sans
      laquelle le jeton FCM resterait en base. Mesurer le délai perçu, et
      revérifier que `fcm_tokens` est bien nettoyé.
- [ ] **Reconnexion immédiate** : se déconnecter puis se reconnecter aussitôt
      sur **un autre compte**, et vérifier qu'aucune donnée du compte
      précédent ne subsiste (brouillons, hashtags suivis, pièces jointes
      téléchargées) — la purge locale est attendue, mais le ménage distant
      tourne encore pendant la saisie des identifiants.
- [ ] **Compte Google** : se déconnecter d'un compte connecté via Google, puis
      relancer une connexion Google — le sélecteur de compte doit réapparaître
      (c'est `_googleSignIn.signOut()`, désormais en tâche de fond).
- [ ] **Déconnexion hors ligne** : mode avion, Déconnexion — doit sortir
      immédiatement sur l'écran de connexion (le réseau n'est plus sur le
      chemin critique) sans message d'erreur.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Déconnexion forcée « Connecté ailleurs » — trois trous refermés »).

---

## Blocage, sens inverse — RLS prouvée en base (2026-08-06)

**Priorité P1** · importance 3/5 — Une personne bloquée peut continuer d'écrire à celle qui l'a bloquée, ou rester visible sur la carte et l'accueil.

La politique RLS était le vrai verrou : `blocked_users_own` en `ALL` sur
`firebase_uid() = blocker_id` ne laissait lire que les lignes où l'on est le
**bloqueur**. La recherche inverse échouait **en silence** — requête réussie,
zéro ligne. Corrigé par la migration `20260806120000`.

⚠️ **Correction d'une description fausse écrite précédemment dans ce fichier.**
Une version précédente de ce point disait « le composeur se ferme ». **C'est
faux**, et la capture l'a montré : `isBlockedByOther` ne masque pas le
composeur. Le champ de saisie reste visible et éditable ; ce sont les
**actions** qui sont refusées (six branches, toutes dans des gestionnaires
d'envoi, pas dans le rendu). Ce qui masque le composeur, c'est `isBlocked` —
l'autre sens, quand c'est *vous* qui avez bloqué.

Ne pas chercher un composeur qui disparaît : il ne disparaîtra pas.

- [ ] **Ce qui reste à vérifier : le refus effectif de l'envoi.** Conversation
  ouverte avec un compte qui vous a bloqué, taper un message, appuyer sur
  envoyer — l'envoi doit être refusé avec un message, et rien ne doit partir.
  C'est le seul maillon non prouvé de toute la chaîne.
- [ ] **Vérifier aussi la carte, l'accueil et les notifications** sous
  blocage : la personne doit disparaître des quatre.
- [ ] **Débloquer** et vérifier que tout revient — la table est publiée en
  realtime avec `REPLICA IDENTITY FULL` précisément pour que la suppression
  soit livrée ; sans ça le déblocage n'aurait pris effet qu'au relancement.

---

## Sécurité / Comptes connectés

**Priorité P0** · importance 2/5 — Si la bascule d'identité des policies a trop ouvert, un compte lit ou modifie les données privées d'un autre ; si elle a trop fermé, ces actions échouent en silence. *Bloqué : deux comptes (ou simulation JWT en base).*

- [ ] **Identité des policies RLS réparée** (migration `20260803170000`, 2026-08-03) : 48 policies comparaient `current_user_id()` (identifiant Supabase Auth) à des colonnes contenant des Firebase UID — mesuré en production, **0 correspondance sur 1247 comptes**. Tout ce qui est « à moi » était donc refusé en silence, les échecs étant avalés par des `catch { debugPrint }`. Après `supabase db push`, vérifier sur un compte réel que ces actions **fonctionnent enfin** : modifier son profil, s'abonner à un podcast, suivre quelqu'un, mettre un post en favori, publier une story et y réagir, ouvrir un ticket de support, signaler un contenu, consulter son historique de transactions. Vérifier aussi qu'un profil passé en privé redevient visible à son propriétaire.
- [ ] **Appareils connectés (#10) migrés vers Supabase `e2ee_devices`** (commit `267d7d3`) — la liste « s'affiche enfin » côté code, jamais confirmé à l'écran.
- [ ] **Flux caméra/galerie/éditeur + permissions manifest** (`WRITE_EXTERNAL_STORAGE`/`READ_MEDIA_IMAGES`/`VIDEO`, réintroduites après une perte accidentelle, commit `9ea9b45`) — jamais revalidées par un flux caméra/galerie réel.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Sécurité / Comptes connectés »).

---

## Assistant de configuration du profil

**Priorité P1** · importance 4/5 — Un nouvel utilisateur termine l'assistant sans que son nom ni sa ville soient enregistrés (le compte czk5… en porte la trace) et apparaît sans nom.

- [ ] **Persistance des valeurs saisies dans l'assistant** : après la
  relance, l'accueil affiche toujours « Complétez votre profil 2/5 » et
  « Ajouter ma ville » — les champs de l'assistant (nom, pays/ville,
  centres d'intérêt) ne semblent pas avoir été enregistrés côté serveur, ce
  qui est cohérent avec le `PERMISSION_DENIED` ci-dessus. À revérifier une
  fois le rejet Firestore corrigé.
- [ ] **Étape 3/4 « Choisissez-en au moins deux »** : le bouton « Suivant »
  reste actif et laisse passer avec « Aucun sélectionné ». Soit la contrainte
  est réelle et il faut la faire respecter, soit la copie est fausse.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Assistant de configuration du profil »).

---

# 9. Fil, stories, salons audio et podcasts

Refonte Fil & Discussion (28 tours), stories, salons audio, podcasts.

---

## ⬜ Une image seule prend la forme de la photo, plus une bande de 205 px (2026-09-14)

**Priorité P1** · importance 4/5 — Une photo portrait publiée dans le fil perdait la moitié de sa hauteur, coupée au centre sans que rien ne le signale.

`post_card.dart` posait l'image unique dans une bande de 205 px de haut en
`BoxFit.cover`. Le cadre suit maintenant le ratio réel de la photo, borné
entre 4:5 (portrait) et 1,91:1 (paysage) — `post_image_frame.dart`. Couvert
par `post_image_frame_test.dart`, qui ne vérifie que le calcul des bornes.

- [ ] **Publier une photo portrait**, la voir dans le fil : elle n'est plus
  coupée au centre. C'est le cas qui ne marchait pas.
- [ ] **Photo très haute** (capture d'écran de téléphone, 9:16) : bornée à
  4:5, donc encore un peu rognée — vérifier que ça reste acceptable et que la
  carte ne mange pas tout l'écran.
- [ ] **Panorama** : borné à 1,91:1, pas réduit à un filet.
- [ ] **Saut de mise en page** : le cadre vaut 4:3 tant que la photo n'est pas
  décodée, puis prend sa vraie forme. En descendant un fil neuf, regarder si
  le saut gêne la lecture — c'est le compromis de ce correctif. En remontant,
  il ne doit plus se produire (les formes déjà vues sont retenues).
- [ ] **Deux à quatre images** : la grille carrée n'a pas changé, vérifier
  qu'elle n'a pas bougé pour autant.
- [ ] **Thème sombre** : le rayon de 20 et le fond de carte suivent le
  nouveau cadre.

## ⬜ Définition des photos envoyées : plafond levé, double encodage supprimé (2026-09-14)

**Priorité P1** · importance 4/5 — Toute photo publiée sortait à 768 px de petit côté et traversait deux compressions JPEG à 85 : floue dès qu'un écran de 1080 px l'affiche pleine largeur.

Le sélecteur bornait à 1024 px puis ré-encodait à 85, et `uploadImage()`
ré-encodait une seconde fois à 85 en ramenant le petit côté à 800
(`image_upload_service.dart`). La sélection est désormais une étape
quasi transparente (2048 px, qualité 95) et la seule qualité livrée est celle
de la compression finale : petit côté 1080, qualité 88.

⚠ Le réglage distant `app_config/settings.mediaLimits` porte encore
1024 / 85 / 800 et **écrasait** le code : `setConfig()` ne descend plus sous le
plancher du code. Tant que le document Firestore n'est pas mis à jour, c'est ce
plancher qui s'applique — le vérifier fait partie du test.

- [ ] **Publier une photo depuis le fil** (`create_post_screen.dart`), la
  rouvrir en plein écran et zoomer : le grain doit être nettement moindre
  qu'avant. Comparer avec une publication antérieure au correctif.
- [ ] **Photo portrait** : c'est le cas qui souffrait le plus (768 px de large
  rééchantillonnés vers 1080). Vérifier aussi qu'elle n'est pas rognée à
  l'excès dans la carte du fil — l'image unique y est affichée sur une bande
  de 205 px de haut, indépendamment du correctif.
- [ ] **Capture d'écran ou affiche avec du texte** publiée comme photo : le
  texte doit rester lisible (c'est le contenu que le JPEG maltraite le plus).
- [ ] **Affiche d'événement portrait** (`create_event_screen.dart`) : la boîte
  était 1920×1080, donc une affiche portrait sortait à 810 px de large ; elle
  est maintenant carrée à 2048.
- [ ] **Avatar** changé depuis le Profil, puis vu en grand sur la fiche de
  profil (et non en vignette de 40 px, où rien ne se voit).
- [ ] **Photo d'entreprise, de produit, de groupe, de story, pochette de
  podcast** : mêmes chemins d'envoi, une vérification rapide sur chacun.
- [ ] **Poids et lenteur** : une photo pèse maintenant ~3 à 5 fois plus.
  Envoyer une publication en 3G/Edge et regarder si le temps d'envoi reste
  acceptable depuis Niamey — c'est le compromis à valider, pas seulement la
  netteté.

## ⬜ Compteurs de Mon espace et du Profil : ils suivent enfin (2026-09-14)

**Priorité P2** · importance 3/5 — Les chiffres affichés étaient ceux du démarrage de l'app : suivre quelqu'un, publier, enregistrer une publication ne les bougeait pas.

Trois causes distinctes (`feed_provider.dart`, `follow_button.dart`) : les
compteurs d'abonnés/abonnements n'étaient invalidés **par personne** et ne sont
pas `autoDispose` ; les compteurs de publications et de favoris sont
`autoDispose` mais l'écran qui les affiche reste monté sous l'écran de
rédaction, donc personne ne les relâche ; et le compteur de partages de la
carte n'était jamais relu après un partage externe. Couvert en test par
`feed_compteurs_rafraichis_test.dart` — qui ne dit rien de ce qui s'affiche.

- [ ] **Onglet « Abonnements » du fil** juste après avoir suivi quelqu'un : ses
  publications y apparaissent (la liste des comptes suivis était, elle aussi,
  figée jusqu'au redémarrage).
  ⚠ 2026-09-14 : vu fonctionner sur SM A515F, mais **ça ne prouve pas le
  correctif** — cet onglet appelle `getFollowingIds()` sur la source de
  données, pas le provider invalidé. Ce qui reste à vérifier, c'est le tri
  « Pour vous » (le scoreur) et les repartages injectés, qui eux lisent le
  provider.
- [ ] **Publications** : publier depuis le fil, revenir à Mon espace → le
  chiffre a augmenté ; supprimer la publication → il redescend. Même contrôle
  sur l'écran Profil, ligne « Mes publications ».
- [ ] **Enregistrés** : toucher le marque-page d'une publication → le chiffre de
  Mon espace et la ligne « Publications enregistrées » du Profil suivent.
- [ ] **Partages** : partager une publication vers WhatsApp → le compteur de
  partages de la carte s'incrémente sans recharger le fil.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Compteurs de Mon espace et du Profil : ils suivent enfin (2026-09-14) »).

## ⬜ Fil : tirer pour rafraîchir partout, et pastille « N nouvelles publications » (2026-09-14)

**Priorité P1** · importance 3/5 — Le fil pouvait rester figé sans que rien ne le signale : la pastille ne dépendait que du canal temps réel, et le geste de rafraîchissement ne partait pas sur un fil court, vide ou en erreur.

Trois changements, aucun vu sur un téléphone (`feed_screen.dart`,
`feed_provider.dart`, `new_posts_pill.dart`, `feed_error_state.dart`) :
un sondage toutes les 60 s qui alimente la pastille, le tiré-pour-rafraîchir
rendu possible dans tous les états, et la pastille redessinée (avatars des
auteurs, entrée/sortie animées). Couvert en test par
`feed_sondage_nouvelles_publications_test.dart` et `new_posts_pill_test.dart`,
qui ne disent rien du rendu ni du geste.

- [ ] **Isoler le sondage** : ce qu'il apporte vraiment, c'est le cas où le
  canal est muet **sans se rejoindre** (websocket filtrée par le réseau,
  canal jamais souscrit) — une coupure franche ne le reproduit pas, puisque
  le canal se rejoint et rattrape. Piste : bloquer le websocket seul (proxy,
  ou réseau qui filtre `wss://`) en laissant passer le HTTP, puis publier.
- [ ] **Publication d'un ami** (audience « Amis », deux comptes amis) : elle
  arrive par le sondage alors que le canal temps réel l'écarte volontairement.
- [ ] **Pas de sondage en arrière-plan** : passer sur l'onglet Messages ou
  mettre l'app en arrière-plan, attendre trois minutes, revenir — vérifier
  dans les journaux (`adb logcat`) qu'aucune requête de fil n'est partie
  entre-temps, et qu'une seule part au retour.

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Fil : tirer pour rafraîchir partout, et pastille « N nouvelles publications » (2026-09-14) »).

## ⬜ Fil sombre : même structure que le fil clair (2026-09-13)

**Priorité P3** · importance 2/5 — En thème sombre, le fil n'avait pas la même mise en page qu'en clair (titre, onglets, cartes, bouton d'écriture) : deux téléphones affichaient deux fils différents.

- [ ] **Pixel** (`font_scale` 1.3) : « Abonnements » n'est plus tronqué et la
  date du fil tient sur sa ligne. *Bloqué : le Pixel porte la version Play Store.*
  **Corrigé le 2026-09-22** (branche `claude/onglet-abonnements-2209`) : le
  libellé est mesuré tel qu'il sera dessiné, gras compris, et **réduit**
  jusqu'à 80 % pour tenir (`reductionPourTenir`, `FittedBox`) ; en deçà,
  l'ellipse reprend. Garde `test/features/feed/feed_segmented_control_test.dart`.
  À revoir sur le Pixel avec un build qui le porte : « Abonnements » entier.
- [ ] Autres écrans du fil en sombre : Mes abonnements, Mes publications,
  Enregistrés — rayons et pastilles comme en clair.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Fil sombre : même structure que le fil clair (2026-09-13) »).

## ⬜ Stories : ajouter, supprimer, audience, listes, 24 h (2026-09-12)

**Priorité P1** · importance 4/5 — Une story restreinte à une liste ou masquée à quelqu'un lui reste visible si la base n'est pas migrée ; sans le correctif, impossible de publier une deuxième story, d'en retirer une, et sa propre story ne disparaît jamais. *Bloqué : deux comptes pour l'audience (Pixel + SM A515F).*

Prérequis en place : migrations 20260912200000, 20260912201000 et 20260912230000 appliquées, `mirrorFriendToSupabase` déployée (relu le 2026-09-22).

- [ ] **Deuxième story** : avec une story active, le « + » de mon avatar reste
  visible ; le toucher publie une autre story. Appui long sur l'avatar : idem.
  (`story_rail.dart`, `story_creation.dart`)
- [ ] **Échec dit** : refuser la permission photos → message « L'accès aux
  photos est refusé » ; succès → « Story publiée · <audience> ».
- [ ] **Liste restreinte** (deux comptes) : Pixel met Sim dans la liste
  restreinte, publie en « Liste restreinte » : Sim la voit, un autre compte
  non. (`story_privacy_screen.dart`, `/feed/stories/privacy`)
- [ ] **Masquer** (deux comptes) : Pixel masque Sim, publie « Tout le monde » :
  Sim ne la voit pas ; retirer Sim de la liste → elle réapparaît au prochain
  rafraîchissement.
- [ ] **24 h** : la story du 3 août de Sim A ne s'affiche plus sur SM A515F ;
  une story publiée quitte le rail à H+24 sans relancer l'app.
  ✅ SM A515F, build `dd38fda`, 2026-09-13 : la story du 3 août a disparu (première moitié). Le départ à H+24
  sans relancer reste à voir.
- [ ] **Stories des autres** : Pixel publie ; sur SM A515F, tirer le fil vers
  le bas → la story apparaît (sans redémarrer), ou au plus tard 2 min après.
- [ ] **Minuteur** (correctif `8c3eb5a`, pas dans `dd38fda`) : la barre du haut
  se remplit pendant les 5 s d'une photo ; appui long = pause ; sur ma story,
  « il y a … · expire dans N h ». Constaté avant correctif : barre vide, sur
  Pixel (version Play 18) comme sur SM A515F.
- [ ] **Écran « Mes stories »** : thème sombre, clavier ouvert dans le
  sélecteur de personnes, nom très long, `font_scale` 1.3 (Pixel).

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Stories : ajouter, supprimer, audience, listes, 24 h (2026-09-12) »).

## ⬜ Publications : audience Public / Abonnés / Amis / Moi uniquement (2026-09-12)

**Priorité P1** · importance 4/5 — Une publication « Amis » ou « Moi uniquement » serait lue par qui ne devrait pas si la base n'est pas migrée, ou au contraire invisible pour les amis si le miroir des amitiés n'est pas déployé. *Bloqué : deux comptes (Pixel = Salim, SM A515F = Sim, amis dans Firestore).*

Prérequis en place : migrations 20260912200000, 20260912201000 et 20260912230000 appliquées, `mirrorFriendToSupabase` déployée (relu le 2026-09-22).

- [ ] **Feuille d'audience** : Créer une publication → puce « Public » → 4
  choix avec explication ; la puce reprend l'icône et le libellé choisis.
  Idem en édition d'une publication existante.
  (`create_post_screen.dart`)
- [ ] **Amis** (deux comptes) : Pixel publie « Amis » : visible sur SM A515F
  (Sim est ami), avec le pictogramme 👥 dans la ligne de métadonnées ; pas de
  bouton repartager ni partager sur la carte.
- [ ] **Moi uniquement** : visible seulement sur le Pixel ; Sim ne la voit ni
  dans « Pour toi », ni dans « Récent », ni sur le profil de Salim.
- [ ] **Abonnés** : un compte qui suit Salim sans être son ami la voit ; un
  compte qui ne le suit pas, non.
- [ ] **Mention** dans une publication « Moi uniquement » : la personne
  mentionnée ne reçoit AUCUNE notification.
- [ ] **Onglet Abonnements** : les publications d'un ami apparaissent même si
  on ne le suit pas.
- [ ] **Nouvelle amitié** (après déploiement de la fonction) : accepter une
  demande d'ami, puis publier « Amis » : le nouvel ami la voit.

## ⬜ Compteurs de commentaires et de repartages justes (2026-09-12)

**Priorité P1** · importance 3/5 — Le détail d'une publication n'affiche que ses propres commentaires alors que le compteur en annonce plus, et les chiffres de la liste ne bougent pas après un commentaire.

Prérequis : `supabase db push` (20260912201000).

- [ ] **Compteur après commentaire** : commenter depuis le détail, revenir au
  fil : le chiffre de la carte a augmenté ; supprimer le commentaire : il
  redescend. (`FeedNotifier.syncCounts`)
- [ ] **Repartage** : repartager puis annuler : le chiffre revient à sa valeur
  de départ, jamais -1 ni +2.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Compteurs de commentaires et de repartages justes (2026-09-12) »).

## ⬜ Supprimer une publication depuis le fil ne ramène plus à l'accueil (2026-09-12)

**Priorité P2** · importance 3/5 — Chaque suppression depuis le fil renvoyait à l'accueil, obligeant à rouvrir le fil.

- [ ] Même geste depuis le détail d'une publication : l'écran de détail se
  ferme, on revient au fil.
- [ ] « Mes publications » : suppression, la liste se met à jour.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Supprimer une publication depuis le fil ne ramène plus à l'accueil (2026-09-12) »).

## Podcasts — 5 écrans passés au système DN (2026-08-04)

**Priorité P3** · importance 1/5 — Aucun aujourd'hui : les écrans ne sont atteignables que par lien profond. *Bloqué : fonction masquée.*

**Leur apparence change** : titres en serif `DNText.serif(22)`, barre du haut
à plat sur `context.dn.surface`, icônes et textes sur les jetons `context.dn`
au lieu de `Theme.of(context)` brut. Aucun changement fonctionnel — la
migration ne touchait que des couleurs et des styles de texte.

- [ ] **Accueil podcasts** (`podcasts_home_screen.dart`) : titre serif, barre
  de recherche, listes — en clair **et** en nocturne.
- [ ] **Mes podcasts** (`my_podcasts_screen.dart`) : titre serif, état vide
  (icône 80 sur `onSurface4`), boutons « + ».
- [ ] **Fiche podcast** (`podcast_detail_screen.dart`) : en-tête, bouton
  d'abonnement — sa couleur suit **l'accent du compte**, pas le terracotta.
- [ ] **Statistiques** (`podcast_stats_screen.dart`) : cartes de stats et
  barre de progression (accent du compte également).
- [ ] **Enregistrer un épisode** (`record_episode_screen.dart`) : barre du
  haut, sélecteur audio/vidéo, bouton « Brouillon » toujours présent.
- [ ] ⚠️ **Vérifier le nocturne en priorité** : `context.dn` gère les deux
  thèmes, mais ces cinq écrans n'ont jamais été vus en nocturne sur appareil.

---

## Refonte Fil & Discussion — Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser)

**Priorité P1** · importance 3/5 — Des gestes et parcours fréquents (répondre en glissant, envoyer plusieurs photos, panneau de la carte, vote sur un sondage) peuvent ne rien faire ou déborder, sans aucune erreur visible.

- [ ] **Repli du rail au défilement** (`feed_screen.dart`/`story_rail.dart`, ajouté 2026-07-31) : `AnimatedCrossFade` déclenché à `scrollOffset > 24`, bascule vers la barre compacte (3 avatars superposés + « N récits aujourd'hui » + « Afficher »), tap sur « Afficher » qui scrolle en haut et redéplie. *(2026-08-03 : **non atteignable en l'état, faute de données** — le fil du compte de test ne contient qu'une seule publication sur les trois onglets, donc la liste ne défile pas et `scrollOffset` ne dépasse jamais 24. Il faut un fil d'au moins un écran et demi.)*
- [ ] **Story vidéo** (ajouté 2026-07-31) : sélection galerie (max 30s), upload + compression + génération de miniature, lecture avec `video_player` dans le viewer (autoplay, barre de progression synchronisée sur la position réelle au lieu du minuteur fixe 5s, passage automatique à la story suivante en fin de lecture). *(2026-08-03 : non testé, mais le blocage Storage qui l'aurait fait échouer — `stories/…/video_*.mp4` — est levé.)*
- [ ] **Réactions sur une story** (ajouté 2026-07-31) : barre de 6 emojis en bas du viewer (stories des autres uniquement), tap = pose la réaction, retaper le même emoji la retire (toggle), l'emoji actif doit rester visuellement mis en évidence. *(2026-08-03 : **non testable en solo par construction** — la barre n'est rendue que sur la story d'un autre auteur. Demande un deuxième compte.)*
- [ ] **Envoi groupé de médias en message** (`media_batch_preview_screen.dart`, ajouté 2026-07-31, §27d) : sélection multiple dans la galerie → pellicule de revue avec case à cocher par média, poids total qui se recalcule au décochage, bascule « qualité réduite » qui compresse réellement à l'envoi, CTA qui nomme le nombre. Le cas 1 seul média doit toujours passer par l'éditeur mono-fichier existant (non touché) — vérifier qu'aucune régression n'est apparue là.
- [ ] **Composer un sondage sur un post** (`create_post_screen.dart` → icône Sondage) : ouverture du sheet, saisie, publication du post d'abord puis création du sondage — vérifier que le sondage apparaît bien après coup sur le post publié.
- [ ] **Composer un lieu sur un post** : `LocationPickerModal` (permission localisation, recherche d'adresse, sélection sur carte), aperçu de la carte statique sur `post_card.dart`.
- [ ] **Vote sur un sondage de post** (`poll_card.dart` réutilisé) : sélection d'option, soumission, affichage des résultats après vote/expiration.
- [ ] **Panneau membres carte** (`map_screen.dart`) : `DraggableScrollableSheet` à 3 positions (18/45/92%), glisser pour changer de position.
- [ ] **Contrôles d'appel** (`call_screen.dart`, `group_call_screen.dart`) : 4 boutons nommés 64px, bouton raccrocher pleine largeur, grille 2×2 en appel de groupe.
- [ ] **"Proches de vous"** (`new_conversation_screen.dart`) : n'apparaît que si permission localisation déjà accordée — vérifier l'affichage et le calcul de distance.
- [ ] **Coloration hashtags en direct** (composer post + commentaire) : `HashtagHighlightingController`, surtout pendant la composition IME (clavier téléphone).
- [ ] **Glisser-pour-répondre** sur une bulle de message : seuil 52px, translation bornée à 90px.
- [ ] **Enregistrement vocal** : 3 états (en cours / annulation armée / verrouillé), gestes de glissement.
- [ ] **Enregistrement micro d'un épisode de podcast** (`record_episode_screen.dart`, ajouté 2026-08-03) : permission micro (première demande), chrono, niveau d'entrée qui bouge vraiment, pause/reprise (le chrono doit repartir au bon endroit), « Terminer » qui produit un fichier lisible avec la bonne durée, « Annuler » qui supprime le fichier partiel, et sortie de l'écran en cours d'enregistrement qui libère bien le micro. Le service `AudioRecordingService` est partagé avec les messages vocaux : vérifier qu'enchaîner les deux ne casse rien.
- [ ] **Bilan de reprise après coupure** (`reconnection_summary.dart` + `offline_sync_service.dart`, ajouté 2026-08-03, maquette 3b) : mettre des actions en file hors ligne, couper longtemps, puis rebrancher → une feuille doit s'ouvrir avec « Envoyé en priorité » (une ligne par action, avec son sort), l'avertissement rouge si des actions ont été abandonnées après 3 tentatives, et « Reçu pendant votre absence » (messages non lus + notifications). Vérifier aussi qu'elle **ne s'ouvre pas** quand rien n'était en attente, et qu'elle ne s'empile pas si deux synchros s'enchaînent. Réserve : les lignes n'affichent que le nom de la collection Firestore, la file d'attente ne stocke pas de libellé lisible.
- [ ] **Fil hors ligne et 4 échecs distingués** (`feed_provider.dart`, `feed_error_state.dart`, ajouté 2026-08-03, maquettes 2a/2b) : couper la donnée réellement (pas le VPN) après avoir chargé le fil une fois → les publications en cache doivent réapparaître avec le bandeau « Fil hors ligne · dernière mise à jour … », et non l'écran d'erreur. Vérifier aussi les 4 cas d'échec : pas de connexion (pas de bouton Réessayer, c'est voulu), panne serveur (compte à rebours 15 s qui relance tout seul), réseau lent, et publication non envoyée (carte en tête du fil avec Réessayer/Abandonner, le texte saisi doit être conservé). Les cas « panne serveur » et « réseau lent » dépendent de la classification par sous-chaîne du message d'erreur — à confronter aux vrais messages Supabase.
- [ ] **Bandeau de reconnexion salon audio** (`audio_room_screen.dart`, ajouté 2026-08-03) : couper la donnée en plein salon doit afficher le bandeau « Reconnexion en cours… » puis « Connexion audio perdue » avec le bouton Réessayer, et le bouton doit réellement redemander un jeton LiveKit et remettre le son. Non vérifiable sans deux appareils et une vraie coupure réseau.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Refonte Fil & Discussion — Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser) »).

---

## Refonte Fil & Discussion — Priorité moyenne — layout & responsive

**Priorité P2** · importance 3/5 — Ambassades rangées dans la mauvaise zone (la fonction en tête de la fiche Play) et en-tête de carte qui chevauche les commandes Google Maps.

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

---

## Salons audio & appels de groupe — indicateur « parle en ce moment »

**Priorité P3** · importance 1/5 — Indicateur de parole absent ou collé — cosmétique. *Bloqué : fonction masquée + deux comptes (cinq pour l'appel de groupe).*

Ce bloc demande **deux comptes sur deux téléphones** : l'anneau ne s'allume que
sur une voix réellement captée par le SFU.

- [ ] **Anneau vert des intervenants** (`audio_room_screen.dart`, `audio_room_provider.dart`, 2026-08-03) : les tuiles `SpeakerTile` recevaient `talking: false` en dur — l'anneau ne s'est jamais allumé depuis l'écriture de l'écran. Il est maintenant piloté par `audioRoomSpeakingProvider` (flux `ActiveSpeakersChangedEvent` de LiveKit). Vérifier **les deux dispositions** : la grille (salon vidéo, tuiles 88 px) et le `Wrap` (salon audio seul, tuiles 52 px). Contrôler aussi l'extinction : l'anneau doit retomber quand la personne se tait, pas rester allumé.
- [ ] **Bordure de participant actif en appel de groupe** (`group_call_provider.dart`, 2026-08-03) : `speakingParticipantIds` était déclaré dans l'état et lu par l'écran, mais jamais alimenté. ⚠ **Ne se voit qu'à partir de 5 participants** (`meshToSfuThreshold`) : en dessous l'appel est en mesh, LiveKit n'est pas dans la boucle et le set reste vide — c'est le comportement attendu, pas une régression. Vérifier aussi qu'après avoir quitté l'appel aucune bordure ne reste collée.

---

## Lecteur de replay — valeurs inventées retirées (2026-08-03)

**Priorité P3** · importance 1/5 — Aucun aujourd'hui : le lecteur de replay n'est pas atteignable. *Bloqué : fonction masquée.*

- [ ] **Replay sans chapitres** (`replay_player_screen.dart`) : cinq chapitres fictifs (« Introduction », « Actualités », « Diaspora & politique », « Q&R », « Conclusion ») s'affichaient quand l'entité n'en portait aucun, et le tap sautait à `i/5` de la piste. Sur un replay sans chapitre, la ligne « Chapitre n/N » et la pastille « Chapitres » doivent maintenant **disparaître**, et le grand titre afficher le nom du salon. Vérifier aussi le cas inverse : un replay **avec** chapitres réels doit toujours les lister avec leurs horodatages, et le tap sauter au bon endroit.
- [ ] **Compteur de temps en vidéo** (`replay_player_screen.dart`) : le temps écoulé et la durée totale dérivaient d'un `Duration(hours: 1, minutes: 14)` codé en dur — le compteur n'avait aucun rapport avec le fichier lu. Il vient maintenant du `VideoPlayerController`. Vérifier que la durée affichée correspond à la vraie, et que le compteur **avance** pendant la lecture (un écouteur a dû être ajouté, il n'y en avait aucun).
- [ ] **Glisser sur la forme d'onde en vidéo** : le geste ne faisait que déplacer le curseur à l'écran, la lecture continuait à sa position d'origine. Il doit maintenant vraiment chercher dans le flux.

---

## Lecture audio en arrière-plan (podcasts)

**Priorité P3** · importance 1/5 — Aucun aujourd'hui ; à la réactivation, AudioService lèverait une SecurityException au premier startForeground si son type de service reste déclaré sans l'autorisation. *Bloqué : fonction désactivée dans ce build.*

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

---

## Refonte Fil & Discussion — Priorité basse — cosmétique, faible risque

**Priorité P2** · importance 1/5 — Petits défauts d'affichage, le plus sérieux étant un brouillon de publication perdu ou impossible à reprendre.

- [ ] Carte "ambassade la plus proche" + badge "Fermé" sur la liste.
- [ ] **Drapeau par pays sur la liste des ambassades** (ajouté 2026-07-31) : correspondance normalisée (accents/casse ignorés) sur `ProfileOptions.countries` — vérifier le taux de correspondance réel sur les données de prod (repli silencieux si aucune correspondance, donc un drapeau manquant n'est pas un bug, juste à surveiller si ça arrive trop souvent).
- [ ] Bandeau conséquences du blocage (comptes bloqués).
- [ ] Écrans légaux fusionnés en onglets (CGU/confidentialité/code de conduite).
- [ ] **Code de conduite hors ligne, texte accentué** (corrigé 2026-09-22) : le
  texte de secours, affiché quand le document Firestore ne se charge pas, était
  écrit sans un seul accent (« diaspora nigerienne », « vous vous engagez a »).
  Mode avion, Réglages → Code de conduite : relire les 11 sections en français.
  (`code_of_conduct_screen.dart`, garde `code_de_conduite_accents_test.dart`)
- [ ] Mon espace : carte Brouillons (sauvegarde/reprise/suppression), tuile Hashtags suivis + bouton Suivre/Suivi sur le bandeau de filtre hashtag du fil.
- [ ] Chip "groupes en commun" sur les cartes de demande d'ami.
- [ ] Filtre "Archives" unifié dans la liste des messages (4e puce).
- [ ] En-tête de discussion 58px, avatar 38px/rayon 13, cadenas E2EE.
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

# 10. Ambassades, démarches, carte, entreprises et événements

Annuaires, démarches consulaires, carte des membres et des postes, événements.

---

## ⚠️ Carte : bouton « Message » de la fiche membre et icône de la liste des membres proches — corrigés, vérifiés SM A515F (partiel, 2026-09-17)

**Priorité P2** · importance 3/5 — Deux boutons de `/map` liés à la
messagerie se comportaient mal, signalé par Salim :

1. Dans la feuille de détail d'un membre (`_showMemberDetails`), le bouton
   « Message » (visible seulement si ami) fermait la feuille puis échouait
   **en silence** si `createIndividual` échouait : aucun SnackBar, aucune
   navigation, retour muet sur la carte.
2. Dans la liste « Membres à proximité » (`_buildMemberSheetItem`), l'icône
   bulle de discussion à droite de chaque ligne ne faisait qu'ouvrir la même
   fiche de détail que le tap sur la ligne entière — un doublon d'action
   mort, pas le raccourci de message qu'elle laisse croire.

Corrigé dans `map_screen.dart` : une méthode partagée
`_startConversationWith` crée/ouvre la conversation et affiche
`messageErreurUsager` en cas d'échec ; l'icône de la liste envoie désormais
un message direct si la personne est déjà amie, et retombe sur la fiche
membre sinon (comportement inchangé pour les non-amis, qui ne peuvent pas
encore être contactés directement).

- [ ] **Bouton Message (fiche membre, ami) — coupure réseau** — pas testé :
  couper le réseau du SM A515F est un réglage système, à faire par Salim
  (voir `project_device_testing.md`), pas depuis une session adb seule.
- [ ] **Icône bulle (liste des membres proches, non-ami)** — pas testé : le
  compte connecté n'avait qu'un seul membre autour pendant la passe (Salim L.,
  déjà ami) — aucun non-ami disponible pour rejouer ce cas.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⚠️ Carte : bouton « Message » de la fiche membre et icône de la liste des membres proches — corrigés, vérifiés SM A515F (partiel, 2026-09-17) »).

---

## ⬜ Qui peut voir un événement : discussion, groupes, personnes, tout le monde (2026-09-12)

**Priorité P0** · importance 5/5 — Un événement « visible uniquement par les participants » d'une discussion était lisible par TOUT LE MONDE (policy `events_select` ouverte, aucun filtre `is_public`), et le seul choix était un interrupteur caché sous la catégorie.

*Bloqué : deux comptes (Pixel Salim + SM A515F Sim) et un tiers pour « personnes choisies ». La migration `20260912233000` est appliquée (relu en base le 2026-09-22).*

- [ ] **Formulaire** (depuis une DM, depuis un groupe, depuis Événements) :
  « Qui peut voir cet événement ? » juste sous la description ; 4 choix en DM
  / groupe, 3 hors discussion ; plus d'interrupteur en bas.
  (`event_audience_picker.dart`, `create_event_screen.dart`)
- [ ] **Cette discussion** (défaut en DM) : Salim crée dans la DM avec Sim →
  Sim le voit (bulle + fiche) ; un 3e compte ne le voit ni dans « À venir »
  ni par lien profond `/events/<id>` (fiche en erreur, pas de chargement
  infini).
- [ ] **Mes groupes** : la feuille liste mes groupes, cases à cocher, « Valider
  (N) » ; un membre d'un groupe choisi voit l'événement dans « À venir ».
  Publier sans groupe coché → message « Choisissez au moins un groupe ».
- [ ] **Personnes choisies** : suggestions (amis, discussions) puis recherche
  à 2 lettres ; la personne invitée reçoit « Invitation à un événement » et le
  tap ouvre la fiche.
- [ ] **Tout le monde** : visible dans « À venir » pour tous, et par un
  visiteur non connecté si le site/les liens le permettent.
- [ ] S'inscrire à un événement qu'on ne voit pas est refusé (tiers).

---

## ⬜ Événement supprimé : il disparaît partout (2026-09-12)

**Priorité P1** · importance 3/5 — Un événement annoncé « supprimé » reste affiché à l'accueil et dans les listes, ou n'est en réalité pas supprimé du tout (suppression depuis le back-office).

Prérequis pour le cas admin en place : migration 20260912200000 et policies
`events_admin_*` (relu en base le 2026-09-22).

- [ ] **Organisateur** : créer un événement passé ou à venir, le voir à
  l'accueil, le supprimer depuis sa fiche : retour à la liste, il a disparu
  d'« À venir », de « Passés » et de l'accueil — sans tirer pour rafraîchir.
  (`event_provider.dart` `forgetDeletedEvent`)
- [ ] **Relancer l'app** : il ne revient pas (cache purgé,
  `CacheService.removeCachedEvent`).
- [ ] **Back-office** (Pixel, admin) : supprimer un événement dont on n'est
  pas l'organisateur → il disparaît. Annuler un événement : fonctionne (le champ
  `updated_at` inexistant faisait tout échouer).
- [ ] **Fiche ouverte par lien profond** puis supprimée : on atterrit sur
  `/events`, pas sur une fiche vide.
- [ ] **Supprimé ailleurs** : supprimer sur un téléphone, tirer pour
  rafraîchir l'accueil de l'autre : l'événement disparaît.

---

## ✅ Événements sur Supabase — BASCULÉ et vérifié SM A515F (2026-09-09 22:35)

**Priorité P2** · importance 4/5 — La création d'événement, passée sur un datasource Supabase neuf, pourrait échouer en silence (RLS), un événement plein resterait ouvert aux inscriptions et le prix saisi disparaîtrait.

- [ ] Une fois la migration appliquée et le provider basculé : créer un
      événement depuis l'app, le retrouver dans le back-office admin, et
      l'inverse.
- [ ] Un événement avec `maxAttendees = 1` doit s'afficher **complet** après
      une inscription (c'est le défaut que la policy élargie corrige).
- [ ] Le prix saisi à la création doit se relire sur la fiche.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Événements sur Supabase — BASCULÉ et vérifié SM A515F (2026-09-09 22:35) »).

---

## ⬜ Ambassades : « officiel / vérifié » **et** les horaires mis en sommeil (2026-09-08)

**Priorité P2** · importance 3/5 — Les 32 fiches affirmeraient une validation officielle par l'ambassade et un état « Ouvert » qui ne reposent sur rien, ce qui trompe l'usager et reste visible sur la capture 2 de la fiche Play.

`lib/features/embassies/presentation/screens/embassy_detail_screen.dart` :
la pastille bleue `Icons.verified` collée au nom du poste (en-tête déroulant)
et le bandeau « **Compte Officiel Vérifié** » en tête de l'onglet *Infos* sont
**commentés**, en attendant confirmation auprès des postes. Les deux ne
tenaient qu'à `embassy.isVerified`, un drapeau de **modération interne**
(écran admin de vérification) : il ne dit pas que l'ambassade reconnaît la
fiche, alors que les deux affichages le laissaient croire — juste au-dessus
des coordonnées dont la fiche prévient elle-même, plus bas, qu'elles sont
parfois fautives.

- [ ] Ouvrir une fiche d'ambassade : plus aucune pastille bleue à côté du nom
      dans l'en-tête, et plus de bandeau bleu au-dessus de l'adresse.
- [ ] Vérifier que le titre sur deux lignes reste bien posé sans la pastille
      (l'alignement `CrossAxisAlignment.end` de la `Row` avait été choisi
      pour elle).
- [ ] Thème sombre : le bandeau bleu était le seul bloc à couleur fixe de
      cette zone — confirmer qu'il ne laisse pas de vide ni de double marge.

### Deuxième passe : les horaires, et le bandeau vert « Ouvert »

Même écran, même raison — les horaires ne sont pas sûrs non plus. Sont
commentés :

- `_todayHours()` et la ligne « **Aujourd'hui · \<horaires\>** » du bandeau
  d'état ;
- le tableau « **Horaires d'ouverture** » de l'onglet *Infos* (jour → plage) ;
- le **bandeau vert « Ouvert »** : `_buildStatusBanner` rend maintenant
  `SizedBox.shrink()` quand `isTemporarilyClosed` est faux.

Ce qui **reste** affiché : le rouge « Temporairement fermé » (+ message +
date de réouverture), qu'un administrateur pose explicitement — c'est une
mise en garde, elle échoue du bon côté. Le badge « Fermé » de l'item de liste
suit le même drapeau, inchangé.

- [ ] Ouvrir une fiche : l'onglet *Infos* commence directement par l'adresse,
      sans bandeau vert ni double marge en haut.
- [ ] Faire défiler l'onglet *Infos* jusqu'aux services : plus de section
      « Horaires d'ouverture », et pas de trou entre les services et
      « Juridiction ».
- [ ] Si une fiche peut être passée en `is_temporarily_closed` côté admin :
      vérifier que le bandeau rouge s'affiche toujours, avec sa date de
      réouverture.

⚠️ **La liste, elle, affiche toujours « ● Ouvert »** sur sa carte « Le plus
proche » (`embassies_screen.dart`, `_NearestEmbassyCard`), en vert, calculé sur
le seul `isTemporarilyClosed` — sans lire le moindre horaire, exactement ce que
ce commit vient de retirer de la fiche de détail. La capture 2 de la série Play
le montre donc. Deux écrans, deux traitements du même drapeau.

- [ ] Trancher : soit la carte « Le plus proche » perd son état « Ouvert »
      comme la fiche, soit les deux le retrouvent quand des horaires existeront
      en base. En l'état, la fiche boutique affiche une mention qui ne repose
      sur rien.

---

## Postes diplomatiques sur la carte : 30 pins sur 32 (2026-09-08)

**Priorité P2** · importance 3/5 — Les postes diplomatiques resteraient invisibles ou mal placés sur la carte, et en anglais les postes sans coordonnées disparaîtraient de l'annuaire alors que le compteur les compte.

Les 32 fiches importées le 2026-09-07 sont arrivées **sans latitude ni
longitude** : `diplomatie.gouv.ne` ne publie que des adresses postales, dont
huit sont de simples boîtes postales. Depuis l'import, aucun poste n'a jamais
eu de pin — `map_screen.dart` saute toute fiche sans coordonnées, et le bouton
« voir sur la carte » du détail est masqué par `hasCoordinates`.

- [ ] **Les pins bleus d'ambassade apparaissent** sur la carte principale, à
      côté des membres — vérifier au moins un poste (Paris, Cotonou, Abuja
      selon la position du testeur), et que la bascule « Ambassades » du menu
      de filtres les fait bien disparaître/réapparaître.
- [ ] **Le tap sur un pin** ouvre la fiche flottante (nom, adresse, tél, mail,
      services) et « Voir la fiche complète » mène au détail.
- [ ] **2 postes restent sans pin, et c'est délibéré.** Khartoum : aucune
      source ne le connaît. Djeddah : le seul résultat (Al Kausar, 22 km au
      nord du centre) n'est pas typé `embassy` par Google, contrairement aux
      neuf autres — une position fausse enverrait l'usager à 22 km. À
      confirmer auprès des deux postes.
- [ ] **Abuja a bougé de 5,7 km** : le nœud OSM (« 305 Diplomatic Drive »,
      quartier des affaires) est contredit par l'annuaire officiel
      (« Maitama District ») **et** par le lieu typé `embassy` de Google, tous
      deux à Maitama. Vérifier que le pin d'Abuja est bien à Maitama.
- [ ] **Copenhague reste ouvert** : nœud OSM (Rosbæksvej, Østerbro) contre
      adresse publiée (Niels Juels Gade 5), 5,1 km, et Google n'y connaît aucun
      lieu typé `embassy` pour départager. Position OSM retenue en attendant.
- [ ] ⚠️ **En anglais**, le repli des postes sans coordonnées valait
      « Others » alors que l'écran n'affiche que les zones de sa liste
      française : **tout poste sans coordonnées disparaissait de l'annuaire**
      (le compteur, lui, les comptait). Corrigé par une constante partagée,
      mais **vérifié en français seulement** — à revoir en basculant la langue
      du téléphone.

⚠️ Découverte au passage, non corrigée : **aucune API Google Maps n'est activée
sur le projet Cloud** hormis le SDK de la carte. `Geocoding API`, `Places API`
et `Places API (New)` répondent toutes `REQUEST_DENIED` /
`SERVICE_DISABLED` — donc `PlaceSearchService` (barre de recherche de la carte,
sélecteur de position des entreprises et du partage de lieu) tombe **toujours**
sur son repli `geocoding` côté appareil, sans que rien ne le signale. À vérifier
sur appareil : la recherche de lieu renvoie-t-elle des résultats utilisables ?

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Postes diplomatiques sur la carte : 30 pins sur 32 (2026-09-08) »).

---

## ⬜ Démarches consulaires : données réelles à la place des délais inventés (2026-09-07)

**Priorité P2** · importance 3/5 — Le back-office ne saurait pas quelle démarche notariée est demandée, l'usager devrait ressaisir son profil, et une course hors ligne intermittente afficherait un écran d'erreur (désormais neutre) au lieu du formulaire.

L'écran de demande administrative (`administrative_request_screen.dart`)
portait deux tables codées en dur : `_requiredDocuments`, des pièces
« propositions indicatives », et `_indicativeDelay`, des délais **entièrement
inventés** — « Environ 3 à 4 semaines », « Sous 48 à 72 heures (urgence
voyage) » — affichés en gras dans la couleur primaire, donc lus comme
officiels. Quelqu'un pouvait réserver un vol sur ce dernier chiffre.

Remplacé par le catalogue des 20 démarches publiées par le ministère
(diplomatie.gouv.ne, consultée le 2026-09-07), chargé dans cet ordre :
Supabase (`get_demarches_catalogue()`), cache du dernier chargement réussi,
puis `assets/data/demarches_consulaires.json` embarqué dans l'APK. La source
ne publiant AUCUN délai, l'écran affiche désormais « Délai de traitement non
communiqué par la source » — il n'y a pas de table de remplacement.

- [ ] Ouvrir « Passeport — première demande ou renouvellement » et vérifier
      son avertissement (la source la titrait « prorogation » à tort).
- [ ] Vérifier « Aucun frais mentionné par la source » (déclarations de
      naissance et de mariage) et la mention conditionnelle des deux démarches
      de décès.
- [ ] **En ligne, le pré-remplissage n'a jamais été vu se remplir.** Ouvrir
      « Demande » avec du réseau et vérifier que le nom, le téléphone et
      l'e-mail arrivent du profil, et que le bandeau vert « Formulaire
      pré-rempli » s'affiche — par les **deux** chemins, qui n'ouvrent pas les
      mêmes providers : annuaire → fiche → « Demande », puis à froid par lien
      profond `diasponiger://embassies/<id>` → « Demande ».

      C'est ce qui valide la tolérance posée sur cet écran dans
      `test/core/providers/autodispose_read_guard_test.dart`. La lecture
      synchrone de `currentUserAsyncProvider` y est acceptée sur un seul
      argument : `embassiesListProvider` est `keepAlive` et regarde les deux
      providers que lit `_preFillFromProfile`, et les deux chemins vers le
      formulaire passent par lui. Si le bandeau manque **par lien profond
      seulement**, l'argument est faux et la méthode doit passer en `async`
      (`unawaited(...)` + `await ref.read(...future)` sous `try`).
- [ ] ⛔ **Le suffixe d'origine du pied de source reste non vu.** Il devrait
      afficher « · liste enregistrée hors ligne » (cache) ou « · liste fournie
      avec l'application » (asset). C'est le seul élément d'affichage de cet
      écran jamais observé.

      Cinq tentatives, deux obstacles qui alternent : soit l'app reste bloquée
      au splash sur un démarrage à froid sans réseau, soit un **écran rouge
      Flutter** surgit sur le chemin fiche → « Demande », toujours sur la même
      requête :

      ```
      ServerFailure(ClientException with SocketException: Failed host lookup:
      'zyrfkcjjrhddpfxcgezo.supabase.co', uri=.../rest/v1/users?select=%2A&id=eq.<uid>)
      ```

- [ ] Reprendre la reproduction **par le parcours réel**, à la main plutôt
      qu'en script : liste → fiche → « Demande », hors ligne, à froid,
      plusieurs fois. La pile s'imprime maintenant, donc une seule occurrence
      suffira à trancher.
      ⚠️ Obstacle non résolu : `input tap` sur « Détails » n'ouvre pas la
      fiche quand la liste vient d'un lien profond (`diasponiger://embassies`).
      Ni les coordonnées ni l'attente (jusqu'à 75 s) n'y changent rien —
      la cause reste à trouver, et c'est ce qui a bloqué l'automatisation.

**✅ Symptôme traité, indépendamment de la traque.** Vu la rareté du défaut,
le gain n'était pas dans la ligne exacte mais dans le fait qu'**une exception
ne doit jamais s'afficher telle quelle**. `main.dart` pose désormais un
`ErrorWidget.builder` global (`construireEcranErreurNeutre`) qui rend
« Une erreur est survenue » à la place du message brut — donc plus d'hôte
Supabase ni d'identifiant de compte à l'écran, quelle que soit la ligne
fautive. Posé en debug aussi, pour que ce chemin soit réellement exercé ; la
pile continue de sortir en console via `presentError`.

- [ ] Reste à voir sur un vrai téléphone, pour les glyphes : `flutter test`
      dessine le texte avec sa police de test (chaque caractère devient un
      pavé plein), donc l'image prouve les couleurs et la mise en page, pas
      le texte. Suppose de provoquer une levée à la demande — et celle qu'on
      connaît ne se reproduit pas.
- [ ] Premier lancement **hors ligne, cache vide** : l'écran doit afficher la
      liste embarquée, pas un spinner ni une erreur. (Même blocage que
      ci-dessus.)
- [ ] Aucun débordement sur les libellés les plus longs à **échelle de police
      1.1** (le résumé de la carte consulaire fait trois lignes).
- [ ] Envoyer une demande, puis vérifier côté back-office que
      `additionalData` porte bien `demarcheId` / `demarcheTitre` : le
      `requestType` seul ne suffit pas à savoir laquelle des six démarches
      notariées a été demandée.

- ✔ 10 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Démarches consulaires : données réelles à la place des délais inventés (2026-09-07) »).

---

## ⛔ Annuaire des ambassades : deux défauts vus sur appareil (2026-09-07)

**Priorité P1** · importance 5/5 — Après une coupure de quelques minutes, la session pourrait rester anonyme au retour du réseau et bloquer en silence les lectures et écritures Supabase (messagerie comprise) jusqu'au redémarrage, et l'annuaire tournerait sans fin sur un réseau qui ne résout rien.

Trouvés en testant l'écran des démarches sur SM A515F — ils sont dans
`embassies_supabase_datasource.dart` / `20260907190000_annuaire_postes_diplomatiques.sql`,
pas dans le catalogue des démarches. **Les deux bloquent le test hors ligne
des démarches**, l'annuaire étant le seul chemin vers cet écran.

- [ ] ⛔ **`messageErreurUsager` n'a PAS pu être vu sur appareil.** Ni l'un ni
      l'autre des deux états atteignables ne le déclenche :

      - cache peuplé + hors ligne → la copie locale est servie, pas d'erreur ;
      - cache vide + hors ligne → **attente infinie**, voir ci-dessous.

      À reprendre par un écran sans repli local. `Annuaire Business` a été
      essayé : il dégrade en état vide, pas en erreur.

**Cas du « réseau menteur » reproduit le 2026-09-08 — et le délai NE SUFFIT
PAS.** C'est le résultat important de la journée sur ce point.

*Comment le fabriquer* (utile, la condition est difficile à obtenir autrement) :
DNS privé en mode strict vers un hôte inexistant. Le WiFi reste `CONNECTED`,
donc `connectivity_plus` voit son transport et `isConnected` rend `true`, mais
toute résolution meurt.

```bash
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier dns-inexistant.invalid
# vérification : `ping <hôte>` doit répondre « unknown host »
# restauration OBLIGATOIRE :
adb shell settings put global private_dns_mode opportunistic
adb shell settings delete global private_dns_specifier
```

*Ce qu'on observe* : l'annuaire tourne encore à 6 s, à 16 s, **et à 60 s** —
alors que le délai du dépôt est de 10 s.

*Hypothèse de tête, à confirmer* : `embassiesList` observe
`currentUserAsyncProvider` **et** `userStreamProvider`. Chaque tentative du
pont d'authentification fait réémettre ces flux, donc reconstruit le provider
et **redémarre le compte à rebours** avant qu'il n'arrive à terme. Le délai
borne bien *une* tentative — c'est ce que prouve
`annuaire_repli_hors_ligne_test.dart` — mais il ne peut rien contre un
provider qu'on relance sans cesse.

- [ ] Vérifier cette hypothèse (journaliser les reconstructions de
      `embassiesList`), puis traiter la cause : ne pas faire dépendre la
      liste de flux d'authentification qui s'agitent pendant une panne, ou
      mémoriser le premier résultat plutôt que tout rejouer.

- [ ] La reprise au retour du réseau (`reprendreApresRetourReseau`) n'est
      **pas vérifiée sur appareil**. Un premier essai a montré qu'elle ne
      partait jamais — `_etaitConnecte` valait `true` alors qu'on s'abonne
      *pendant* la coupure, donc le `true` du retour ne ressemblait pas à une
      transition. Corrigé, mais le second essai n'a pas abouti : le processus
      a été relancé avant la fin des six tentatives.

- ✔ 7 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⛔ Annuaire des ambassades : deux défauts vus sur appareil (2026-09-07) »).

---

## ✅ Annuaire des ambassades : Firestore → Supabase, 32 postes chargés (2026-09-07)

**Priorité P2** · importance 2/5 — Les administrateurs écriraient encore dans une collection Firestore que plus personne ne lit, ou recevraient un faux succès sur un refus RLS : l'annuaire ne pourrait plus être tenu à jour depuis l'app. *Bloqué : compte administrateur.*

L'écran « Ambassades » lisait la collection Firestore `embassies`, **vide
depuis toujours** : la liste n'a jamais rien affiché. L'annuaire passe sur
Supabase (`20260907180000_annuaire_postes_diplomatiques.sql`) avec les 32
postes publiés par diplomatie.gouv.ne, relevés et corrigés le 2026-09-07.

- [ ] **Mode avion sans jamais avoir chargé** : liste vide, pas de plantage.
      (Non testé : le cache était déjà peuplé, et le vider demande de
      désinstaller — ce qui coûte la session Firebase.)
- [ ] La réserve `data_notes` s'affiche sur les fiches concernées (Abidjan,
      Ankara, Cotonou, Doha, La Havane, Berlin, Copenhague, Rome, Kano,
      Paris, Pretoria, Rabat, Riyad, Washington, Genève, Pékin, Khartoum,
      Le Caire, New York, Paris/UNESCO) et reste lisible en **thème sombre**
      (`surfaceContainerHighest` / `onSurfaceVariant`).
- [ ] Admin : vérifier / suspendre un poste (`admin_embassy_verification_screen`)
      écrit bien dans Supabase, et l'échec RLS non-admin remonte un message
      au lieu d'un faux succès.
- [ ] Admin : créer un poste (`admin_create_embassy_screen`) le fait
      apparaître dans la liste — l'écran écrivait dans Firestore, donc dans
      une collection que plus personne ne lit.

**Épingle distincte sur la carte** (2026-09-08) — la carte plaçait toujours une
épingle ordinaire pour Copenhague. Elle y reste (la retirer ferait disparaître
l'ambassade) mais se signale : **bordure discontinue et ambre** au lieu du
cercle bleu plein, convention cartographique du tracé approximatif.

- [ ] **NON VÉRIFIÉ SUR APPAREIL.** Trois obstacles cumulés :
  1. sur le **Pixel**, la carte est derrière l'écran « Mode privé activé » —
     l'ouvrir demande d'activer le partage de position sur le compte réel de
     Salim, ce qui est un réglage de confidentialité que je ne touche pas ;
  2. sur le **SM A515F**, l'autre agent pilotait l'appareil au même moment
     (écran « Modifier l'événement » apparu sous mes taps) — usage concurrent,
     mesure abandonnée ;
  3. et même avec l'accès, **Google Maps rend dans un `SurfaceView`**, que
     `adb shell screencap` capture en noir. Une capture d'écran ne prouverait
     donc probablement rien.

  La bonne façon de le vérifier serait un test de rendu sur la fonction qui
  peint l'épingle — mais elle est privée dans l'État de `map_screen.dart` et
  l'extraire dépasse ce qui a été demandé.

- ✔ 7 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Annuaire des ambassades : Firestore → Supabase, 32 postes chargés (2026-09-07) »).

---

## Position des entreprises : création/édition alimentent enfin latitude/longitude (2026-08-19)

**Priorité P2** · importance 2/5 — Les entreprises créées resteraient sans pin sur la carte et l'édition pourrait écraser les compteurs serveur, sur un annuaire aujourd'hui vide donc avec peu d'usagers touchés.

- [create_business_screen.dart](lib/features/businesses/presentation/screens/create_business_screen.dart)
  gagne une tuile « Position sur la carte » (section Localisation) qui ouvre
  le `LocationPickerModal` de la messagerie (GPS, tap carte, recherche de
  lieu) ; à défaut de choix explicite, l'adresse saisie est géocodée à la
  soumission (meilleur effort, 5 s, jamais bloquant).
- Le même écran devient l'écran d'édition (`/businesses/:id/edit`) : **cette
  route n'existait pas** — le menu « Modifier » de la fiche poussait dans le
  vide depuis toujours.
- `getNearbyBusinesses` : le calcul du delta de longitude utilisait une
  fonction `_cos` qui convertissait en radians **sans jamais appliquer le
  cosinus** (à Niamey, fenêtre ~4× trop large). Corrigé avec `dart:math`.
- `updateBusiness` (datasource) n'écrase plus les champs serveur
  (`createdAt`, compteurs, boost, `isVerified`) — sinon la première édition
  aurait retapé `createdAt` en chaîne ISO et cassé les tris.

À vérifier sur appareil (rien de tout ceci n'a tourné sur un vrai téléphone) :
- [ ] Créer une entreprise avec position choisie sur la carte (permission
  localisation runtime, gestes du modal dans le bottom sheet, thème sombre
  de la tuile et du modal), puis vérifier que le **pin apparaît sur la
  carte** (couche entreprises activée) et que son tap ouvre la fiche.
- [ ] Créer une entreprise **sans** toucher la carte mais avec une adresse
  réelle : le géocodage de repli doit poser lat/lng (à vérifier en base ou
  par le pin) ; hors ligne ou adresse introuvable, la création doit passer
  quand même, juste sans pin.
- [ ] Menu « Modifier » de la fiche (propriétaire) : l'écran s'ouvre
  prérempli (photos existantes supprimables, pays, téléphone re-séparé
  indicatif/numéro), la position existante s'affiche et se modifie, et la
  fiche détail montre les changements au retour.
- [ ] `viewCount`/`averageRating`/`isBoosted` inchangés en base après une
  édition (garde anti-écrasement du datasource).

---

## Réglages/Carte — deux interrupteurs de partage de position désynchronisés (2026-08-13)

**Priorité P0** · importance 5/5 — Un usager qui a coupé le partage continuerait à publier sa position GPS précise toutes les deux minutes dans la table `users`, lisible via l'API par tout compte connecté si le profil n'est pas privé, en contradiction avec la divulgation de localisation qui vient de faire refuser l'app par Play.

Cause : `share_location` (écrit par Réglages/Profil, `profile_preferences_provider.dart`)
et `nearbyMembersEnabled` (préférence locale du calque « Membres » de la
carte, `map_screen.dart`) sont deux réglages distincts qui devraient être un
seul. `LocationPublisherService.start()` ne se fiait qu'au second.

Corrigé (`lib/core/services/location_publisher_service.dart`,
`lib/features/profile/presentation/providers/profile_preferences_provider.dart`) :
`start()` relit désormais `share_location` depuis le profil serveur à chaque
démarrage (auto-guérison des comptes déjà désynchronisés, sans action de leur
part), et `ProfilePreferences.set` déclenche `start()`/`stop()` immédiatement
quand on bascule « Ma localisation ». Le calque « Membres » de la carte reste
inchangé (c'est un filtre d'affichage, pas un consentement).

**Rien de ceci n'est vérifiable par `flutter analyze`/`flutter test` seuls**
(permission GPS réelle, cycle de vie `resumed`/`paused` de l'app) :

- [ ] Mettre l'app en arrière-plan puis la ressortir plusieurs fois de suite
  (volet de notifications, `inactive` transitoire) avec le partage désactivé :
  vérifier dans les logs qu'aucune requête profil réseau superflue n'est
  déclenchée à chaque aller-retour (le garde `_positionSubscription != null`
  doit court-circuiter).
- [ ] Compte préexistant en base avec `share_location = true` mais sans
  position (reproduire l'état d'Ibrahim) : relancer l'app et vérifier
  l'auto-guérison, sans toucher à aucun réglage.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Réglages/Carte — deux interrupteurs de partage de position désynchronisés (2026-08-13) »).

---

## Carte — délai d'affichage des membres autour (2026-08-04)

**Priorité P1** · importance 4/5 — Le suivi de fond n'alimenterait jamais la carte, et la session Supabase de l'isolate de fond pourrait invalider celle du premier plan, coupant la messagerie des usagers qui partagent leur position.

`map_screen.dart` : trois changements qui ne se voient que sur un vrai GPS et
un vrai cache d'images, `flutter analyze` n'en dit rien.

- [ ] **Ouverture à froid de la carte** : la dernière position connue doit
  peupler la carte **tout de suite** (marqueur rouge + liste des membres),
  sans attendre le point GPS frais. Mesurer le délai entre le tap sur
  l'onglet Carte et le premier pin visible — avant, le spinner tenait 3 à
  15 s. Refaire l'essai après `adb shell am force-stop` pour être sûr que
  le cache de position est bien froid.
- [ ] **Première ouverture après installation** (aucune position connue) :
  vérifier que le spinner reste puis cède la place à la carte normale, et
  **pas** au bandeau « accès restreint par réciprocité ».
- [ ] **GPS coupé pendant que la carte est ouverte** : le bandeau de
  restriction ne doit apparaître que si aucune position n'a jamais été
  obtenue ; sinon la carte garde la dernière position et continue le suivi.
- [ ] **Pins générés en parallèle** : avec plusieurs membres autour et le
  cache d'avatars vidé (réinstallation), tous les pins doivent apparaître
  d'un coup après ~3 s max, pas un par un.

- [ ] **Accueil, section « membres autour »** (même correctif que la carte,
  `home_screen.dart`) : au lancement à froid, la section doit se remplir dès
  la dernière position connue, sans attendre le point GPS. Et si le GPS
  n'aboutit pas alors qu'une position connue existait, **aucun** message
  d'erreur de localisation ne doit s'afficher.

### Temps réel des positions (nécessite **deux** comptes)

Ces points ne se vérifient qu'avec deux téléphones (ou un téléphone + un
compte piloté depuis le SQL Supabase, en modifiant `latitude`/`longitude`/
`location_updated_at` de la ligne `users`).

### ↩️ Compte restauré le 2026-08-05 — à re-préparer avant tout nouveau test

Le maquillage décrit ci-dessous **a été défait** : « Salim L. » est revenu à
`share_location = false`, position `45.5802795 / -73.6459928`,
`location_updated_at = 2026-08-04 18:32:45+00`, `is_online = false`. Plus
aucune fausse donnée en base. Pour retester, rejouer la préparation :

```sql
update users
   set share_location = true,
       latitude  = 45.5980,
       longitude = -73.6459,
       is_online = true,
       last_seen_at = now(),
       show_online_status = true
 where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';
```

⏳ **La présence tient une heure**, via la seconde porte du filtre
(`is_online` + `last_seen_at` de moins d'une heure). Passé ce délai, rejouer
`update users set last_seen_at = now() where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';`
La première porte (`location_updated_at` < 5 min) est trop courte pour un
test manuel.

**Pour tout remettre en état après le test** :

```sql
update users
   set share_location = false,
       latitude  = 45.5802795,
       longitude = -73.6459928,
       location_updated_at = '2026-08-04 18:32:45.536012+00',
       is_online = false
 where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';
```

⚠️ `share_location` est la colonne **serveur**. Si l'app tourne sur le second
compte et enregistre son profil, elle peut la réécrire depuis son état local
— revérifier la colonne après coup (même piège que l'interrupteur push, voir
`CLAUDE.md`, « Réglages : une seule source »).

- [ ] **Sortie de rayon, confirmation visuelle** (facultatif) : si l'occasion
  se présente — téléphone franchement au repos, carte ouverte — refaire le
  protocole en une seule commande. Ne pas y consacrer d'effort dédié : le
  rapport entre le coût et ce qui reste inconnu ne le justifie plus.
- [ ] **Retour d'arrière-plan** : A met l'app en arrière-plan puis revient —
  le canal temps réel doit se reprendre (vérifier qu'un déplacement de B est
  de nouveau vu tout de suite, et pas seulement au sondage).
- [ ] **Coupure du réglage** : A désactive « Membres à proximité » →
  l'app cesse d'écrire sa position (vérifier que `location_updated_at` de A
  ne bouge plus dans Supabase).
- [ ] ⛔ **Suivi en arrière-plan → Supabase** : le service de fond écrivait
  dans Firestore, la carte lit Supabase — ses mises à jour n'arrivaient donc
  jamais. Activer le suivi en arrière-plan, fermer l'app, se déplacer, et
  vérifier dans Supabase que `users.latitude` / `location_updated_at` de A
  bougent bien. Surveiller aussi logcat : `Background Location: Supabase
  indisponible` signale que l'isolate n'a pas pu initialiser son client (le
  `.env` n'est peut-être pas lisible depuis l'isolate d'arrière-plan).
- [ ] **Pas de double session Supabase** : après un tour de suivi en fond,
  vérifier que la session du premier plan tient toujours (aucun 401 dans
  logcat, les messages arrivent encore). L'isolate utilise une clé de session
  distincte (`supabase.background.session`) précisément pour ça.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Carte — délai d'affichage des membres autour (2026-08-04) »).

---

# 11. Accueil, profil et réglages

Grille d'accueil et « Tous les services », profil, pseudo, réglages, feature flags d'écrans.

---

## ⬜ Modifier le profil : libellés tronqués et code SMS illisible (2026-09-21)

**Priorité P2** · importance 3/5 — Signalé par Salim sur capture (thème
sombre, police agrandie). Trois défauts, un écran :

- le titre tombait en « Modifier l… . » entre ✕, l'œil et « Enregistrer » ;
- « Origine au … » et « Qui peut voi… » : libellé et valeur se partageaient la
  ligne par moitié ;
- dans la boîte « Vérification du numéro », les chiffres saisis n'étaient que
  des bouts de traits : case de 45 px moins 24 px de remplissage latéral par
  défaut, pour un chiffre de 22 px agrandi par la police du téléphone.

Corrigé : titre dans un `FittedBox(scaleDown)` ; valeur **sous** le libellé
dans les deux lignes ; cases OTP en `Expanded` sans remplissage latéral.
`flutter analyze` propre, **rien vu à l'écran**.

Fichier :
[edit_profile_screen.dart](lib/features/profile/presentation/screens/edit_profile_screen.dart).

- [ ] Police du téléphone au maximum, thème sombre : titre entier (même
  rétréci), « Origine au Niger » et « Qui peut voir mon numéro ? » en entier,
  valeur lisible en dessous.
- [ ] Modifier le numéro → Vérifier : les six chiffres du code se lisent en
  entier dans leurs cases, sans débordement de la boîte ; retour arrière d'une
  case à l'autre toujours fonctionnel.

---

## ⬜ 🔴 Modifier son profil réactivait ce qu'on avait coupé (2026-09-18)

**Priorité P0** · importance 4/5 — Enregistrer l'écran « Modifier le profil »
remettait à `true` la **position partagée**, le **statut en ligne** et les
**notifications**, quoi qu'on ait choisi dans Réglages. Aucune erreur, aucun
message : la valeur reprenait seulement son défaut. Trouvé en relisant les
appelants de `ProfileNotifier.updateProfile`, jamais observé sur appareil.

Corrigé : l'écran part de `currentProfile()` (le profil courant, quitte à le
chercher) puis `copyWith`. Un banc d'architecture interdit désormais à toute
couche de présentation de construire un `ProfileEntity(` de zéro (aucune
exception). **⚠️ Des comptes réels ont pu être touchés** — tout compte ayant
coupé l'un de ces réglages puis modifié son profil ; rien ne permet de les
retrouver après coup.

Fichiers :
[edit_profile_screen.dart](lib/features/profile/presentation/screens/edit_profile_screen.dart),
[profile_provider.dart](lib/features/profile/presentation/providers/profile_provider.dart),
[profil_jamais_reconstruit_en_presentation_test.dart](test/core/architecture/profil_jamais_reconstruit_en_presentation_test.dart).

- [ ] **Le parcours qui cassait** : dans Réglages, couper « Ma position »,
  « Statut en ligne » et les notifications ; puis Profil → Modifier → changer la
  bio → Enregistrer. Les trois restent coupés dans Réglages, ET côté serveur :
  `supabase db query --linked "select share_location, show_online_status,
  notifications_enabled from users where id='…'"` rend trois `false`. Avant :
  trois `true`.
  ⛔ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : position et notifications restent coupées (base : false), mais **`show_online_status` repasse à `true`**. L'interrupteur « statut en ligne » écrit par `OnlineStatusService` sans prévenir `ProfileNotifier` : `currentProfile()` garde `true`, et l'enregistrement réécrit toutes les colonnes. Corrigé ensuite (`appliquerSansEcrire`, `online_status_visibility_test.dart` échoue sur l'ancien code) — à revérifier sur un build qui le contient.
- [ ] **Compétences et région** : renseignées avant la modification, intactes
  après.
- [ ] **Après un redémarrage à froid** (profil pas encore en cache), modifier
  puis enregistrer : l'enregistrement aboutit — le profil est retrouvé au lieu
  d'être reconstruit. Même parcours pour l'**assistant de configuration**
  (onboarding) : « Terminer » aboutit du premier coup, sans passer par
  « Réessayer » — il partage désormais `currentProfile()` avec l'écran de
  modification, alors qu'il en avait sa propre copie.
- [ ] **Réseau coupé** : « Enregistrer » affiche l'erreur existante, l'écran
  reste ouvert et le spinner s'arrête.
- [ ] **Comptes de test existants** : lire ces trois colonnes sur les comptes qui
  ont déjà modifié leur profil, pour mesurer s'ils ont été touchés.

---

## ⬜ Un refus du serveur ne ment plus : interrupteurs, snackbars, connexion admin (2026-09-18)

**Priorité P2** · importance 3/5 — Des écritures que l'utilisateur déclenche
d'un geste échouaient sans le dire, et plusieurs laissaient l'écran affirmer
le contraire de ce qui s'était passé. Relevé à la relecture de l'audit
`unawaited`/`discarded_futures`, jamais reproduit sur appareil :

Ces écritures rendent désormais `Future<bool>` (`false` = rien n'a été
enregistré, l'état visible est déjà revenu à la vérité) et l'écran le dit par
`reportIfFailed` : snackbar « Une erreur est survenue ». Couvert par des bancs
Dart, dont chacun a été vérifié en remettant l'ancien comportement (il
échoue). **Ce qu'un banc ne voit pas** : un vrai refus serveur, et le rendu du
snackbar — d'où les cases ci-dessous.

Fichiers :
[action_feedback.dart](lib/core/utils/action_feedback.dart),
[online_status_service.dart](lib/core/services/online_status_service.dart),
[online_status_provider.dart](lib/features/profile/presentation/providers/online_status_provider.dart),
[profile_preferences_provider.dart](lib/features/profile/presentation/providers/profile_preferences_provider.dart),
[notification_preferences_provider.dart](lib/features/settings/presentation/providers/notification_preferences_provider.dart),
[admin_login_screen.dart](lib/features/admin/presentation/screens/admin_login_screen.dart).

- [ ] **Réseau coupé, Réglages → « Statut en ligne »** : basculer
  l'interrupteur. Il revient à sa position d'origine (pas sur « visible »
  d'office) et le snackbar d'échec s'affiche. Sur l'écran **Profil**, le même
  interrupteur n'est plus verrouillé sur « Erreur de chargement ».
- [ ] **Idem « Profil visible » et « Ma position »** : l'interrupteur revient,
  snackbar. « Ma position » : réseau coupé puis rétabli, le point n'apparaît
  pas sur la carte d'un second compte.
- [ ] **Interrupteur maître des notifications, réseau coupé** : il revient sur
  « activé ». Réseau rétabli, basculer : `users.notifications_enabled` suit
  (`supabase db query --linked "select notifications_enabled from users where
  id='…'"`), et un push de test n'arrive plus.
- [ ] **Mes podcasts, réseau coupé** : « Mettre en pause » puis « Supprimer » →
  snackbar d'échec, jamais « publié » / « supprimé ». Réseau rétabli : le
  message de succès n'apparaît qu'**après** l'opération, plus au tap.
- [ ] **Fiche d'une notification, réseau coupé** : « Supprimer » → snackbar
  d'échec et la fiche **reste ouverte** (elle se refermait avant le résultat).
- [ ] **Épisode de podcast, réseau coupé** : toucher le cœur → il revient vide,
  avec le snackbar.
- [ ] **Connexion admin (`AdminApp`) avec un compte sans droits** : « Accès
  refusé. Compte administrateur requis. » ; réseau coupé au moment du refus :
  le message ajoute « La session n'a pas pu être fermée : réessayez ».
- [ ] **Thème sombre et grande police** sur le snackbar d'échec (fond
  `AppColors.error`, texte blanc par défaut).
- [ ] **Masquer puis ré-afficher son statut en ligne** (corrigé, jamais vu
  sur appareil) : `_setupPresenceForUser` sortait sur « Already tracking user »
  dès que l'uid était retenu, ce qu'il est après un masquage — la présence
  n'était rétablie qu'au prochain retour au premier plan. La garde exige
  maintenant aussi l'écoute de connexion (`isPresenceTracked`). Depuis un
  second téléphone : masquer → le compte passe « hors ligne » ; ré-afficher →
  il repasse « en ligne » **sans relancer l'app** ; tuer l'app → il repasse
  « hors ligne » (le gestionnaire de déconnexion est bien reposé). Le banc
  `online_status_presence_test.dart` ne fige que le prédicat, pas ce câblage.

---

## ⬜ L'écran des appareils ne promet plus ce qu'il ne fait pas (2026-09-16)

**Priorité P2** · importance 3/5 — L'écran « Appareils connectés » était la
troisième réponse du projet à « quels appareils tiennent ce compte », et elle
ne concordait avec aucune des deux autres. Trois affirmations fausses, toutes
mesurées le 2026-09-16 :

- « jusqu'à 5 appareils connectés simultanément », alors que `SessionService`
  n'en autorise **qu'un** ;
- « Appareils connectés », alors que la liste est celle des inscriptions de
  clés Signal (`e2ee_devices`), que rien n'élague : le compte principal y avait
  **3 lignes, dernière activité le 23 août**, pour un seul appareil réel ;
- « Révoquer », présenté comme une déconnexion à distance (le commentaire de
  `removeDevice` disait littéralement « déconnexion à distance ») alors que
  c'est un `DELETE` sur une ligne de registre : l'appareil visé garde sa
  session, ses notifications et ses messages.

Les textes disent maintenant ce qui se passe, et `removeDevice` vérifie les
lignes touchées au lieu d'annoncer un succès à vide. **Ce qui reste ouvert :
déconnecter UN appareil est impossible aujourd'hui** — `users.session_id` est
une colonne unique par compte, cf. « Expulsion admin et bannissement ».

Fichiers :
[devices_screen.dart](lib/features/settings/presentation/screens/devices_screen.dart),
[device_sync_service.dart](lib/core/services/e2ee/device_sync_service.dart).

- [ ] **Lire l'écran en entier** : plus aucune mention de « connectés
  simultanément », le compteur dit « Inscrits : n sur 5 », et l'avertissement
  de suppression dit bien que l'appareil reste connecté.
- [ ] **Supprimer les clés d'un appareil qui n'est pas le sien** : le message
  est « Clés supprimées », la ligne disparaît, et — c'est le point —
  **l'autre téléphone continue de recevoir les messages**. C'est désormais ce
  que le dialogue annonce ; le vérifier à deux appareils.
- [ ] **Le bouton de sa propre carte** : `removeDevice` refuse l'appareil
  courant. Vérifier que l'écran ne laisse pas croire l'inverse.
- [ ] **Grande police** (réglages système à fond) : les deux boutons de carte
  — « Renommer » / « Supprimer » — tiennent côte à côte sans rognage. Rien
  n'a été rendu en image, les libellés ayant seulement changé de mot.
- [ ] **Anglais** : basculer la langue et relire les mêmes écrans.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ L'écran des appareils ne promet plus ce qu'il ne fait pas (2026-09-16) »).

---

## ⬜ 🔴 Bloquer un utilisateur ne bloque rien — corrigé (2026-09-14)

**Priorité P0** · importance 5/5 — Bloquer quelqu'un n'écrivait rien, nulle part : ni dans Firestore, ni dans le miroir Supabase dont dépendent les policies. L'écran affichait la personne comme bloquée sans qu'elle le soit. Corrigé le 2026-09-14, **jamais vérifié sur appareil**. *Bloqué : deux comptes.*

**Correctif.** Les deux écritures de profil sont retirées — aucune n'était
lue : la liste des bloqués vient de la sous-collection `blocked_users`
(`blockedUsersProvider`), le sens inverse passe par Supabase
(`usersWhoBlockedMe`), et `functions/index.js` ne balaie ces tableaux qu'au
nettoyage de suppression de compte, en Admin SDK. Il ne reste qu'une écriture
Firestore, dans sa propre sous-collection : plus de lot du tout. Le miroir
Supabase est maintenant tenté **quoi qu'il arrive** à Firestore, et son échec
n'est plus avalé par un `debugPrint` — un blocage à moitié posé se dit.

**Écrans.** Les trois appels au blocage annonçaient déjà l'échec. Le
quatrième, la case « bloquer aussi » de `report_content_modal.dart`, jetait le
résultat : le blocage pouvait échouer sous un « Merci pour votre signalement »
vert. Il dit maintenant que le signalement est parti mais que le blocage n'a
pas suivi. Au passage, `business_reviews_screen.dart` sort de la liste
d'exceptions de `test/core/errors/echec_muet_test.dart` — il avait **deux**
branches muettes (suppression d'un avis, réponse du gérant), pas la seule que
sa note d'exception décrivait.

- [ ] **Bloquer** depuis la fiche de profil : la personne apparaît dans
  Réglages → Utilisateurs bloqués, et **en base** — `users/{moi}/blocked_users`
  côté Firestore **et** une ligne dans `public.blocked_users`.
- [ ] **Ses publications disparaissent** du fil (c'est la policy Supabase qui
  tranche, donc le miroir doit être écrit).
- [ ] **Débloquer** : les deux disparaissent, des deux bases.
- [ ] **Bloquer depuis un signalement** (case « bloquer aussi ») : la ligne
  arrive dans les deux bases, et un échec du blocage seul se dit à l'écran
  sans faire croire que le signalement a échoué.
- [ ] **Miroir en échec** : couper le réseau juste après avoir bloqué — le
  message d'erreur doit apparaître, et rebloquer une fois le réseau revenu
  doit aboutir (les deux écritures sont idempotentes).
- [ ] **Avis d'un commerce** (`business_reviews_screen.dart`) : supprimer son
  avis et répondre en tant que gérant annoncent maintenant l'échec autant que
  le succès — vérifier qu'un refus affiche bien un bandeau rouge.

## ⬜ Photo de profil : on choisit son cadrage (2026-09-14)

**Priorité P1** · importance 4/5 — L'avatar est un carré : la photo choisie était rognée en son centre, et personne ne décidait de ce qui restait — un portrait y perdait le haut du crâne ou le menton.

Nouvel écran `photo_crop_screen.dart` entre le choix de la photo et l'envoi :
on déplace, on pince pour zoomer, seul le carré part. Branché sur les deux
chemins (`edit_profile_screen.dart` et `profile_config_screen.dart`). Les deux
grands avatars de 76 px passent en `BoxFit.contain` : une photo d'avant ce
correctif, donc rectangulaire, se montre entière plutôt que coupée. Couvert par
`photo_crop_screen_test.dart`, qui ne vérifie que le calcul du découpage.

- [ ] **Changer la photo depuis le Profil** (appareil photo *et* galerie) :
  l'écran de cadrage s'ouvre, le geste de déplacement suit le doigt, le
  pincement zoome, et on ne peut pas faire sortir le cadre de la photo.
- [ ] **Ce qu'on voit est ce qu'on garde** : cadrer sur un détail précis
  (un visage en haut de la photo), valider, et retrouver **ce** cadrage sur
  l'avatar du profil, du fil et d'une discussion.
- [ ] **Renoncer** : la croix referme l'écran sans rien changer à la photo
  actuelle.
- [ ] **Photo en portrait très haut** (9:16) : elle remplit le cadre et ne
  peut pas être dézoomée sous le carré — arbitré le 2026-09-14, ce n'est pas
  un défaut. Ce qui se vérifie ici, c'est qu'on atteint **toute** la photo en
  la faisant glisser : le haut comme le bas doivent pouvoir venir dans le
  cadre.
- [ ] **Lenteur** : sur le SM A515F, le découpage tourne dans un isolate mais
  décode une image de 2048 px — mesurer le temps entre « valider » et le
  retour à l'écran de profil.
- [ ] **Ancienne photo, non carrée** : ouvrir le profil d'un compte qui n'a
  pas changé sa photo — elle s'affiche entière, avec des bandes sur les côtés.
  Juger si le rendu tient (c'est le choix fait le 2026-09-14) ou s'il vaut
  mieux inviter à recadrer.
- [ ] **Vignettes de liste** (fil, discussions, membres) : elles restent en
  `cover` — vérifier que ça ne jure pas avec le profil.

## ⬜ Noter l'application : bouton des Réglages et invitation automatique (2026-09-14)

**Priorité P2** · importance 3/5 — Le dialogue natif d'avis ne dit jamais s'il s'est affiché : aucun banc, aucun journal ne peut distinguer « montré » de « avalé par le quota ».

*Bloqué pour le dialogue natif : un compte neuf, et huit ouvertures étalées
sur plus de trois jours, sur une installation **venue de Play** — c'est le cas
des deux téléphones depuis le build 1.2.2+26. Un APK latéral ne le montrera
jamais, même en release.*

Le paquet `in_app_review` entre dans le projet
([app_review_service.dart](lib/core/services/app_review_service.dart)), avec
deux chemins volontairement distincts :

- **le bouton** des Réglages ouvre la **fiche du store**, jamais le dialogue
  natif — Google demande expressément de ne pas câbler un bouton « Noter »
  sur `requestReview()`, que le quota peut avaler : l'utilisateur voit alors
  un bouton mort ;
- **l'invitation automatique** part de l'écran d'Accueil
  ([home_screen.dart](lib/features/home/presentation/screens/home_screen.dart)),
  après huit ouvertures, trois jours d'ancienneté, et une seule fois par
  trimestre.

[app_review_service_test.dart](test/core/services/app_review_service_test.dart)
tient les seuils, le recalage d'une horloge menteuse, et le point qui compte :
un `requestReview()` muet ne doit pas relancer la demande à **chaque**
ouverture. Ce que le banc ne peut pas voir :

- [ ] **L'appui ouvre l'application Play Store** sur la fiche Diaspo Niger, pas
      un navigateur ni « élément introuvable ». La fiche est bien publiée :
      vérifié en ligne le 2026-09-14 (Mirai Tech., 10+ téléchargements).
- [ ] **Sans Play Store** (ou Play désactivé) : le bandeau
      « Impossible d'ouvrir la fiche du store… » s'affiche. Le bouton ne doit
      jamais rester muet.
- [ ] **iOS** : `https://apps.apple.com/app/id6807607258` répondait
      « The page you're looking for can't be found » le 2026-09-14 — la fiche
      n'est pas publiée. Le bouton mènera là tant que ce n'est pas le cas
      (voir « iOS : signature et conformité export jamais compilées » au § 14).
- [ ] **L'invitation ne s'empile pas** : jamais par-dessus les coach marks du
      premier démarrage, ni par-dessus un écran poussé par un lien profond ou
      une notification pendant les quatre secondes d'attente.
- [ ] **Le compteur tient au redémarrage** : huit ouvertures cumulées, pas
      huit d'affilée dans la même session. `adb shell run-as` sur les clés
      `review_*` de `SharedPreferences` permet de le lire sans attendre.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Noter l'application : bouton des Réglages et invitation automatique (2026-09-14) »).

---

## ⬜ Groupes en commun ouvrables depuis un profil (2026-09-13)

**Priorité P2** · importance 3/5 — Le profil d'une autre personne n'affichait qu'une pastille « 3 groupes en commun », inerte : ni lesquels, ni comment y aller.

*Bloqué : deux comptes partageant au moins deux groupes, dont un sans aucun message.*

- [ ] **Groupe sans aucun message** (sa conversation n'existe pas encore) :
      l'appui ouvre la **fiche** du groupe, pas un écran vide.
- [ ] **Plus de quatre groupes partagés** : « Voir tout » déplie la liste sur
      place ; la bio et les médias restent atteignables.
- [ ] **Aucun groupe en commun**, et **personne bloquée** : la section est
      absente dans les deux cas.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Groupes en commun ouvrables depuis un profil (2026-09-13) »).

---

## ⬜ Champ ville : recherche dans le référentiel (2026-09-13)

**Priorité P1** · importance 4/5 — Le champ ville du profil, refait : ce qu'il retient décide des groupes de ville à venir, et il lit maintenant la position de l'appareil.

Le champ ville du profil est un `CustomTextField` nu. Relevé en base le
2026-09-13 sur les neuf profils qui portent une ville : « Niamey » ×3 et
« niamey » ×1, « Arewa » (un département), « Almoustapha » (un prénom) et
l'adresse e-mail du compte de test. Ouvrir des groupes de ville là-dessus
referait le problème des pays, en pire.

D'où le référentiel `public.villes` (33 880 villes, GeoNames `cities15000`
pour le monde et le fichier `NE` filtré sur les 48 villes de
`ProfileOptions.nigerRegions` pour le Niger), et
[ville_search_field.dart](lib/shared/widgets/ville_search_field.dart), qui
retient une **ligne** du référentiel et non la chaîne saisie — retoucher le
texte défait le choix.

[ville_search_field_test.dart](test/shared/ville_search_field_test.dart) tient
les quatre règles au banc (proposition bornée au pays, choix d'une ligne,
choix défait à la frappe, échec de recherche sans écran rouge). Ce que le banc
ne peut pas voir :

- [x] **Sur appareil** : « À propos » (Profil → Réglages → À propos) affiche
  « Liste des villes : GeoNames (CC BY 4.0) » sous « Tous droits réservés ».
- [ ] **En anglais** : la même mention, `cityDataCredit` étant traduite.
Le champ est désormais posé sur **Modifier le profil**
([edit_profile_screen.dart](lib/features/profile/presentation/screens/edit_profile_screen.dart)),
et `users.ville_id` fait l'aller-retour. Sept cas de cohérence ville ↔ pays
sont vérifiés en base, pas ici.

- [ ] **Sur appareil** : la liste de suggestions s'ouvre sous le champ sans
  passer sous le clavier (voir « Débordement clavier » du domaine Design) et
  se ferme à la perte du focus. Le champ est en bas d'un formulaire long :
  c'est le cas où la liste risque de sortir de l'écran.
- [ ] **Sur appareil** : « Utiliser ma position » ouvre la feuille de
  divulgation **avant** la boîte système (voir « Divulgation préalable de la
  localisation » du domaine Publication), et le texte est bien celui du champ
  ville — « ni enregistrées ni partagées », pas celui de la carte. Accepter
  propose « Vous êtes à … ? » ; « Non » referme sans rien écrire.
- [ ] **Sur appareil, hors d'une ville connue** : « Aucune ville de la liste à
  proximité » s'affiche au lieu d'une proposition fausse.

**Reprise de l'existant, faite le 2026-09-14** (`20260914150000`). Neuf des
treize profils qui portaient une ville sont reliés au référentiel : Niamey ×4
(dont un écrit « niamey », désormais normalisé par le déclencheur), Bouza,
Dosso, Magaria, Kaduna, Djelfa. Quatre restent du texte libre, et c'est
exact : « Almoustapha » (un prénom), « Arewa » (un département), l'adresse du
compte de test, et « Montréal » — dont le profil n'a pas de pays, si bien que
le relier changerait aussi son pays. Décision : à proposer, pas à imposer.

- [ ] **Sur appareil, l'un des comptes de Niamey** : le profil affiche
  « Niamey » avec la pastille verte (une ville retenue), et le champ n'est
  plus du texte nu. Le compte qui avait écrit « niamey » en minuscules doit
  afficher « Niamey ».
- [ ] **Sur appareil, les comptes « Almoustapha » et « Arewa »** : le texte
  est intact, sans pastille, et l'enregistrement du profil ne l'efface pas.

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Champ ville : recherche dans le référentiel (2026-09-13) »).

---

## ✅ Profil : la carte de statistiques débordait par la droite — corrigé et vérifié Pixel 10 Pro XL (2026-09-08)

**Priorité P3** · importance 2/5 — Au pire un défaut de contraste ou de gouttière en thème clair — le débordement lui-même est corrigé et vérifié.

- [ ] Un compteur à **trois chiffres** ne déforme pas sa colonne — pas
      vérifiable sur ce compte (4 / 2 / 0 / 1). Couvert au banc seulement.
- [ ] Rendu en thème **clair** : jamais regardé.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ✅ Profil : la carte de statistiques débordait par la droite — corrigé et vérifié Pixel 10 Pro XL (2026-09-08) »).

---

## Flags Salons audio / Podcasts / Fil enfin sérialisés + maintenance sans écrasement (2026-08-19)

**Priorité P2** · importance 2/5 — L'admin croit activer ou désactiver une fonction sans que rien ne soit écrit, ou basculer la maintenance réinitialise d'autres fonctions. *Bloqué : back-office : connexion manuelle superAdmin (Salim L.).*

Deux bugs de la même famille que les préférences profil (reconstruction
partielle) corrigés dans le module admin :

1. `FeatureFlagsModel`
   ([app_settings_model.dart](lib/features/admin/data/models/app_settings_model.dart))
   ne sérialisait **pas du tout** `audioRooms`, `podcasts`, `feed` : les
   interrupteurs « Salons audio » et « Podcasts » du back-office étaient
   perdus à l'écriture, et la lecture retombait toujours sur les défauts de
   l'entité (salons/podcasts désactivés) quoi que contienne Firestore. C'est
   une cause plus simple que la piste « écriture refusée en silence » notée
   le 2026-08-19 ci-dessous : même acceptée, l'écriture ne contenait pas ces
   clés.
2. `toggleMaintenanceMode`
   ([app_settings_provider.dart](lib/features/admin/presentation/providers/app_settings_provider.dart))
   reconstruisait l'entité champ par champ (6 flags sur 9) : basculer la
   maintenance aurait écrasé `audioRooms`/`podcasts`/`feed` avec les défauts.
   Réécrit en `copyWith`, avec sentinelle dans
   [app_settings_entity.dart](lib/features/admin/domain/entities/app_settings_entity.dart)
   pour que `maintenanceMessage: null` efface vraiment le message (l'écran
   admin passait déjà `null` pour effacer — no-op silencieux avant).

**État prod lu le 2026-08-19** (admin SDK, lecture seule) : `featureFlags` =
audioRooms `false`, podcasts `false`, businessDirectory `false`, marketplace
`false`, moneyTransfer `false`, events/groups/embassies `true`, pas de clé
`feed` ; **`lastUpdated` = 2026-05-22** → aucune sauvegarde du back-office
n'a abouti depuis 3 mois. La règle déployée exige
`users/{uid}.adminRole == 'superAdmin'` pour écrire `app_config/*`, et la
famille « faux succès » des `set()` Firestore masquerait un refus : le test
appareil ci-dessous doit donc se juger sur le **document** (le `lastUpdated`
doit bouger), pas sur l'absence d'erreur à l'écran.

**Non vérifié sur appareil** :
- [ ] Back-office : activer « Salons audio » et « Podcasts », sauvegarder,
  relancer l'app → `/audio-rooms` et `/podcasts` ne redirigent plus sur
  `/home` (première fois que ces interrupteurs peuvent réellement agir).
- [ ] Back-office : basculer le mode maintenance ON puis OFF → les
  interrupteurs Salons audio/Podcasts gardent leur état (avant le correctif
  ils seraient retombés à désactivé). Le flag `feed` est lui aussi préservé
  dans Firestore, même s'il n'agit plus sur l'app depuis que le Fil est
  toujours actif (voir « Annuaire, Fil et Ambassades toujours actifs — plus de flag »).
- [ ] Effacer le message de maintenance (vider le champ) puis sauvegarder →
  le message ne réapparaît pas à la réouverture de l'écran.

---

## Carte « Pour commencer » : chaque ligne gagne son propre critère (2026-08-14)

Les 3 lignes de `_PourCommencerCard`
([home_screen_widgets.dart](lib/features/home/presentation/screens/home_screen_widgets.dart))
restaient toutes affichées tant que le *profil* était incomplet (photo/ville/
pays/profession/bio), même si l'utilisateur avait déjà rejoint des groupes ou
discuté avec quelqu'un — aucune des 3 actions n'était suivie individuellement.
Chaque ligne se masque désormais sur son propre signal, calculé dans
[home_screen.dart](lib/features/home/presentation/screens/home_screen.dart) :
- « Trouver des proches » : `conversationsProvider` contient une conversation
  individuelle qui n'est pas « Mes notes » (`isIndividual && !isSelfNotesFor`) ;
- « Rejoindre un groupe » : `myGroupsNotifierProvider` non vide ;
- « Activer la carte » : `_locationError == null` (même signal que la ligne
  « membres proches » du bloc « Aujourd'hui », déjà en prod).

`flutter analyze` propre sur les deux fichiers touchés. **Non vérifié sur
appareil** : il faudrait un compte avec profil incomplet MAIS déjà dans un
groupe (ou déjà en conversation) pour confirmer que la ligne correspondante
disparaît bien sans faire disparaître les deux autres, et que la carte entière
se masque quand les 3 sont accomplies pendant que le profil reste incomplet.

---

## Pseudo (@handle) — ligne d'appel sur son propre profil

**Priorité P2** · importance 3/5 — La fonction pseudo reste invisible pour 9 comptes sur 11, ou la ligne d'appel apparaît sur le profil d'autrui ou déborde à côté du nom.

Contexte : la ligne `@handle` disparaît purement et simplement quand le champ
est vide, et 9 comptes sur 11 en prod n'en ont aucun — rien n'indiquait que
la fonctionnalité existait. Une ligne d'appel prend désormais la place du
`@handle` manquant, **uniquement sur son propre profil**.

- [ ] Onglet **Profil** avec un compte sans pseudo : la ligne
  « Choisir mon pseudo » (icône @) s'affiche sous le nom
  (`lib/features/profile/presentation/screens/profile_screen.dart`).
- [ ] Le tap ouvre l'édition **avec le curseur dans le champ**, donc le champ
  défilé à l'écran (`/profile/edit?focus=handle`,
  `edit_profile_screen.dart` + `widgets/handle_field.dart`).
- [ ] Avec un compte **qui a** un pseudo (`sim`, `diaspo_ne`) :
  c'est bien `@sim` qui s'affiche, pas l'appel.
- [ ] Profil de **quelqu'un d'autre** sans pseudo : **aucune** ligne
  d'appel (on ne peut rien y faire)
  — `profile_view_screen.dart`, garde `_isCurrentUser`.
- [ ] Son propre profil ouvert par `/profile/<son id>` (lien profond, QR,
  liste de membres) : même appel que sur l'onglet Profil.
- [ ] Lisibilité en **thème sombre** (couleur `adaptivePrimaryColor`) et à
  `font_scale 1.1` : la ligne est dans un `Flexible`, vérifier l'absence de
  débordement à côté du nom.

---

# 12. Design, thème, langue et mise en page

Palette, thème sombre, icônes, polices, débordements, paysage, bascule design_v2, traduction anglaise.

---

## ⬜ L'en-tête d'un sondage effaçait son auteur dans une bulle — corrigé, à revoir (2026-09-15)

**Priorité P2** · importance 3/5 — Dans une bulle de discussion, le nom de l'auteur du sondage disparaissait purement et simplement, et l'horodatage débordait de la carte.

Dans [poll_card.dart](lib/features/polls/presentation/widgets/poll_card.dart),
la rangée d'en-tête « auteur · il y a X » posait le libellé de temps **sans
contrainte** à côté d'un `Expanded`. `RenderFlex` sert les enfants
inflexibles en premier : « il y a environ un jour » prenait toute sa largeur
intrinsèque, l'`Expanded` du nom tombait à zéro — donc **invisible**, pas
tronqué — et la rangée débordait de 7,5 px. `PollMessageBubble` contraint la
carte à 288 dp ; c'est là que ça se voyait.

Le libellé est maintenant **mesuré** (`TextPainter`, échelle de police
comprise) : la forme longue de `timeago` est gardée tant qu'elle tient dans la
moitié de la rangée, sinon la forme compacte de `DateFormatter.timeAgoShort`
prend le relais (« 1 j », « 12 min »). Mesurer plutôt que se fier à la seule
largeur, parce que le facteur d'échelle vient des réglages de l'appareil —
même famille que « Deux textes du fil que `font_scale` 1.3 abime ».

- [ ] **Le même sondage dans le fil** (carte large, [post_card.dart](lib/features/feed/presentation/widgets/post_card.dart)) :
  la forme **longue** doit y rester, « il y a environ un jour ». C'est le
  point qui distingue le correctif d'un raccourcissement partout.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ L'en-tête d'un sondage effaçait son auteur dans une bulle — corrigé, à revoir (2026-09-15) »).

## ⬜ Le pied d'un sondage déborde encore en mode vote — NON corrigé (2026-09-15)

**Priorité P2** · importance 3/5 — Même motif que l'en-tête, même bulle, mais dans `_pied` : « N votes » disparaît et « Voir les résultats » est rogné.

`_pied` ([poll_card.dart](lib/features/polls/presentation/widgets/poll_card.dart))
traite le cas à **une seule action** par `Row(Expanded(compte), action)` —
exactement le motif corrigé dans l'en-tête. À 288 dp en mode vote, l'unique
action est « Voir les résultats » : elle déborde de 22 px et écrase le compte
à zéro. Le cas à **deux** actions, lui, est correct (branche `Column` + `Wrap`,
posée le 2026-09-14), et c'est pourquoi les bancs existants ne le voyaient
pas : ils montent la carte en mode résultats, à 320 dp.

Pas corrigé ici : contrairement à l'en-tête où il s'agit d'un libellé de
texte, l'enfant trop large est un `TextButton`, et le choisir entre empiler
(précédent du fichier), raccourcir le libellé ou l'ellipser est un arbitrage
de maquette, pas une évidence technique.

- [ ] **Bulle de sondage reçue, pas encore voté** : « 3 votes » doit rester
  lisible à gauche et « Voir les résultats » entier à droite. Aujourd'hui, en
  release, le débordement est **silencieux** (pas de bande jaune et noire) :
  c'est le texte rogné qu'il faut regarder.

## ⬜ Deux textes du fil que `font_scale` 1.3 abime — corrigés, à revoir (2026-09-14)

**Priorité P3** · importance 2/5 — À grande police, l'horodatage d'une publication était coupé et le bandeau hors ligne se lisait mal. Rien ne débordait, mais de l'information se perdait.

**Corrigés le 2026-09-14** (`post_card.dart`, `feed_error_state.dart`,
`app_fr.arb`, `app_en.arb`). Le bandeau est couvert par
`test/features/feed/feed_bandeau_hors_ligne_test.dart` ; la ligne d'auteur,
elle, ne l'est pas — c'est du rendu à une échelle donnée, un test unitaire
n'en dirait rien.

- [ ] **Bandeau hors ligne** : « Fil hors ligne · dernière mise à jour **il**
  y a 11 **minutes** » — minuscule en milieu de phrase, pluriel décliné. Le
  bandeau apparaît en coupant le réseau sur le fil général (il se replie sur
  son cache ; c'est le hashtag jamais consulté qui donne l'écran d'échec).
- [ ] **Ailleurs dans l'app** : `minutesAgo` / `hoursAgo` / `daysAgo` servent
  aussi à l'accueil et sur la carte, où ils commencent la ligne. Vérifier
  qu'ils y gardent leur majuscule (« Il y a 3 heures ») — seul le bandeau du
  fil l'abaisse.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Deux textes du fil que `font_scale` 1.3 abime — corrigés, à revoir (2026-09-14) »).

## ⬜ L'étape « Thème » dit enfin la vérité sur l'accent (2026-09-14)

**Priorité P2** · importance 3/5 — Deux défauts au même endroit, étape 4/4 de la configuration du profil ([profile_config_screen.dart](lib/features/profile/presentation/screens/profile_config_screen.dart)).

**L'ordre des pastilles.** Le même réglage était présenté dans deux ordres
opposés : Orange puis Vert ici, Vert puis Orange dans les Réglages.
L'onboarding s'aligne sur les Réglages.

**Les vignettes mentaient sur l'accent.** Les trois aperçus Clair / Sombre /
AUTO peignaient leur barre avec la paire **orange**, quel que soit l'accent
choisi — observé sur Pixel le 2026-09-14, trois vignettes oranges juste
au-dessus de la pastille verte qu'on venait de toucher. La vignette lit
maintenant l'accent au provider et reprend le `colorScheme.primary` du thème
qu'elle représente. C'est le défaut que `950024b` nommait — « un aperçu qui
ment sur ce qu'il propose » — corrigé alors sur la seule moitié clair/sombre.

- [ ] **Configuration du profil, étape 4/4** : Vert en première position,
  Orange en seconde.
- [ ] **Réglages → thème** : l'ordre y est identique, les deux écrans se
  lisent pareil.
- [ ] **La sélection suit toujours la bonne pastille** : toucher Orange
  sélectionne Orange (c'est la régression qu'un échange de positions invite —
  les `isSelected` ont bougé avec leur widget, à confirmer à l'œil).
- [ ] **Compte en Vert** : les trois vignettes portent une barre **verte**.
  C'est le cas qui a révélé le défaut.
- [ ] **Compte en Orange** : elles portent une barre orange — la correction ne
  doit pas avoir inversé le mensonge.
- [ ] **Au tap sur une pastille**, les trois vignettes se repeignent
  **immédiatement**, sans quitter ni rouvrir l'étape (elles lisent le
  provider, que `_selectThemeColor` écrit aussitôt).
- [ ] **Vignette AUTO** : ses deux moitiés, claire et sombre, portent chacune
  la bonne nuance de l'accent — `secondary` / `secondaryLight` en Vert,
  `primaryDark` / `primaryLight` en Orange. C'est la seule qui montre les
  deux à la fois, donc la seule où un mélange se verrait.

---

## ⬜ Une couleur par service dans les deux grilles (2026-09-14)

**Priorité P3** · importance 2/5 — Les tuiles de service se partageaient trois valeurs : le Fil et les Amis avaient **exactement** la même couleur, l'Annuaire une variante d'orange indiscernable du Fil, et sur l'accueil l'Annuaire était colorié avec `colorScheme.onPrimaryContainer` — un jeton de *texte*, presque noir. L'indigo des Ambassades tombait à 2,3:1 sur l'aplat sombre de sa tuile.

Une seule source désormais : `ServiceAccents`
([service_accents.dart](lib/features/home/presentation/theme/service_accents.dart)),
lue par « Tous les services » et par la grille de l'accueil. Contrastes
calculés (icône sur son propre aplat) : ≥ 3,4:1 en clair sauf le Fil à 2,4:1
(l'orange était déjà ainsi), ≥ 5,1:1 en nocturne.

- [ ] **Compte en thème Orange** : les tuiles ne bougent plus avec l'accent du
  compte (elles ne lisent plus `adaptivePrimaryColor`). Vérifier que le résultat
  reste cohérent avec le reste de l'écran, boutons compris.
- [ ] Le prune des Événements est la seule teinte hors guide de style : juger
  à l'œil si elle tient à côté du bleu des Ambassades, sa voisine de rangée.
  Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff) : vu en clair et en sombre à côté du bleu des Ambassades — les deux
  se distinguent. Le jugement de goût reste à Salim, case laissée.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Une couleur par service dans les deux grilles (2026-09-14) »).

---

## ⬜ Le sigle DN est le même partout (2026-09-13)

**Priorité P2** · importance 3/5 — Trois écrans dessinaient la marque chacun à leur façon : écran de démarrage en vert sans serif, page de connexion en Playfair sur l'accent du compte — donc **orange** pour qui a choisi le thème Orange —, gabarit d'illustration du design kit sur ce même accent à un autre rayon. On touchait une icône verte au lanceur pour tomber sur un sigle orange.

- [ ] **Page de connexion**, app déconnectée : même vert, même lettrage,
      même arrondi que l'écran de démarrage. Pas vu — l'appareil était
      connecté, et s'en déconnecter coûterait la session de test.
      (`auth_scaffold.dart`)
- [ ] **Gabarit d'illustration** (onboarding, écrans à illustration) : la
      pastille 62 est bien centrée dans son bloc rayé.

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Le sigle DN est le même partout (2026-09-13) »).

---

## ⬜ Point d'accent après chaque titre d'écran (2026-09-13)

**Priorité P3** · importance 3/5 — Le point terracotta qui signe les titres manquait sur la plupart des écrans (onglets, `AppBar` simples, Fil, salons, podcasts), et disparaissait sous l'ellipse d'un titre long.

Une seule source : `DesignTitle` ([design_kit.dart](lib/core/theme/design_kit.dart)).
Tests : `test/core/theme/design_title_point_test.dart`. Volontairement **sans
point** : noms saisis (groupe, salon, contact, sujet de ticket), barres de
sélection et visionneuses média sur fond noir. Le back-office l'a depuis le
2026-09-13, en **terracotta** comme l'app (`AdminColors.titleDot`) : seule
exception à « pas d'orange dans l'admin », l'action y reste bleue.

- [ ] Les 7 grands en-têtes (Messages, Groupes, Profil, Réglages,
  Notifications, Annuaire, Mes stories) : point terracotta collé au dernier
  mot, jamais seul sur une ligne ; « Notifications. » tient toujours sur une
  ligne au Pixel (`font_scale` 1.3).
- [ ] Un écran à `AppBar` simple (Amis, Mes commandes, Historique des
  paiements) : point présent, taille 22.
- [ ] Titre long dans une `AppBar` (« Personnel - <ambassade> » depuis une
  fiche ambassade, police agrandie) : « … » **puis** le point, qui reste
  visible.
- [ ] Fil (« Le fil. »), Mon espace, Mes publications, Enregistrés, Mon réseau :
  point à la couleur d'accent du Fil — **violet en thème sombre** (Nocturne),
  terracotta en clair.
- [ ] Salons audio, Podcasts, Nouveau podcast, Programmer un salon : point
  présent, police serif des salons conservée.
- [ ] Mot de passe oublié, Nouvel événement, Modifier mon profil : taille et
  graisse propres à ces écrans inchangées, seul le point s'ajoute.
- [ ] Thème sombre : le point reste lisible sur chaque famille.
- [ ] **Back-office web** (`lib/features/admin/main.dart`) : connexion, puis
  les en-têtes de page (Tableau de bord, Utilisateurs, Signalements,
  Modération, Transferts, Audit…) et les barres Paramètres, Feature flags,
  Créer un administrateur : point **terracotta** (le même orange que dans
  l'app), police Inter inchangée ; boutons et onglets toujours bleus.
- [ ] Depuis l'app, `/admin/embassies/create` et `/admin/support` : point
  terracotta dans la typographie de l'app (Playfair), lisible aussi en thème
  sombre.

## ⬜ Grand titre d'en-tête : plus de mot coupé (2026-09-12)

**Priorité P2** · importance 2/5 — Le titre « Notifications » s'affichait coupé au milieu du mot (« Notificatio / ns ») sur Pixel, avec une police système agrandie.

Constaté sur Pixel 10 Pro XL (densité 440, `font_scale` 1.3) le 2026-09-12.

- [ ] **Pixel** : Notifications avec des non lues (« Tout lire » visible) : le
  titre tient sur une ligne, en taille réduite. (`design_kit.dart`
  `DesignHeaderTitle`)
- [ ] **SM A515F** (`font_scale` 1.1) : les 7 en-têtes (Messages, Groupes,
  Profil, Réglages, Notifications, Annuaire, Mes stories) gardent leur taille
  30 quand ils tiennent.
- [ ] Un titre de plusieurs mots (« Annuaire des entreprises ») passe à la
  ligne entre les mots, jamais au milieu.

## ⬜ Polices embarquées : plus de téléchargement au premier affichage (2026-09-11)

**Priorité P3** · importance 4/5 — Hors ligne au premier lancement, la typographie de marque retombe sur la police système et l'erreur continue de polluer Crashlytics — gêne visuelle, aucune fonction perdue. *Bloqué : réinstallation propre (efface les données, déconnecte le compte).*

Crashlytics montrait `Failed host lookup: 'fonts.gstatic.com'` (4 événements,
3 utilisateurs) : `google_fonts` téléchargeait chaque graisse au premier
affichage. Hors ligne — métro, avion, zone blanche — le texte retombait sur la
police système.

[assets/google_fonts/](assets/google_fonts/) porte désormais **24 fichiers
(2,48 Mo)** : Inter, Playfair Display, Roboto Mono, Instrument Sans et Figtree
en 400–700 ; Instrument Serif en Regular + Italic (ses seules graisses) ; IBM
Plex Mono et Caprasimo en Regular. Pris aux URL exactes que le paquet appelait
(`fonts.gstatic.com/s/a/<sha256>.ttf`) et vérifiés contre le sha256 et la
taille qu'il exige lui-même. Les 8 licences OFL sont jointes
(`LICENCE-*.txt`) et enregistrées par
[licences_polices.dart](lib/core/utils/licences_polices.dart).

- [ ] **Hors ligne dès le premier lancement** : installation neuve (ou données
  effacées — ⚠️ ça déconnecte le compte), **mode avion avant** le premier
  lancement → titres en Playfair Display, texte en Inter, aucune police
  système. Un appareil qui a déjà téléchargé les polices les garde en cache
  disque : il ne montre **pas** la différence.
- [ ] **Crashlytics** : plus aucun `Failed host lookup: 'fonts.gstatic.com'`
  sur la version qui embarque les polices.
- [ ] **Poids** : +2,5 Mo attendus sur l'APK comme sur le bundle.

---

## ⬜ Teinte des notifications système en vert (2026-09-07)

**Priorité P3** · importance 3/5 — Icône de notification dans la mauvaise teinte, ou carré blanc si Android retombe sur l'icône du lanceur — défaut purement visuel. *Bloqué : deux comptes (émetteur de notifications).*

La petite icône de la barre d'état (`ic_stat_notification`) est une
**silhouette blanche sur transparent** — c'est Android qui la colore, avec la
teinte d'accent. La repeindre revient donc à changer cette teinte, pas le PNG.

Elle est posée par **deux chemins** selon l'état de l'app, et les deux ont dû
être changés : `notification_accent` dans
`android/app/src/main/res/values/colors.xml` (lu par le SDK Firebase via
`default_notification_color` du manifeste, chemin utilisé pour tous les types
sauf `message`) et la nouvelle constante `AppColors.notificationAccent`
(passée par `flutter_local_notifications` — les messages partent en *data-only*
depuis `send-push`, donc c'est le client qui construit leur notification).

- [ ] **Notification de message, app tuée.** C'est le chemin
      `flutter_local_notifications`. Petite icône verte dans la barre d'état
      et filet vert dans le volet. ⚠️ `am force-stop` empêche la livraison FCM
      — lancer l'app, attendre, puis `KEYCODE_HOME` (cf. méthode plus bas).
- [ ] **Notification d'un autre type** (demande d'ami, événement…). C'est le
      chemin SDK Firebase, donc la ressource XML. Même vert attendu.
- [ ] **Canal « general_channel ».** Il n'était pas teinté du tout avant :
      vérifier qu'il l'est maintenant, et que rien n'y a régressé.
- [ ] **Silhouette intacte.** Le PNG n'a pas été touché ; vérifier qu'aucune
      notification ne montre un carré ou un disque blanc (le symptôme quand
      Android retombe sur `@mipmap/ic_launcher`).

Non touché, volontairement : les `ledColor` (couleur de la LED de
notification, sémantique par type — bleu pour les amis, violet pour les
groupes…), les deux teintes d'état de l'upload (`#4CAF50` succès /
`#FF9800` en attente), et l'icône orange `#E97424` en dur du dialogue
« Activer les notifications » (`notification_service.dart`), qui est un
élément d'interface in-app et non une notification.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Teinte des notifications système en vert (2026-09-07) »).

---

## ⬜ Icône du lanceur repeinte en vert (2026-09-07)

**Priorité P3** · importance 4/5 — Icône mal découpée ou délavée sur l'écran d'accueil — première impression de marque dégradée, sans effet fonctionnel.

- [ ] **Icône dans le tiroir d'applications et sur l'écran d'accueil.** Vert
      `#009600`, sigle blanc lisible, forme adaptive correcte (le lanceur
      découpe en cercle/squircle selon le thème du téléphone).
- [ ] **iOS.** Icônes régénérées mais jamais compilées ni vues (aucun Mac dans
      la boucle) — cf. l'entrée « iOS : signature et conformité export ».

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Icône du lanceur repeinte en vert (2026-09-07) »).

---

## ⬜ Écran de démarrage repeint en vert (2026-09-07)

**Priorité P3** · importance 3/5 — Pastille verte terne sur fond sombre, ou accent vert qui déborde sur l'app d'un compte orange — cosmétique.

Demande produit : sur l'écran d'attente `/splash` (le premier écran Flutter
affiché, `initialLocation` du routeur), la pastille « DN » et le cercle de
progression passent de l'orange primaire au vert `AppColors.secondary`
(`#009600`) / `secondaryGradient`. Fichier :
[splash_screen.dart](lib/features/auth/presentation/screens/splash_screen.dart).

La teinte est **fixe** : elle ne suit pas l'accent choisi par le compte
(orange ou vert). Un compte en thème Orange verra donc un splash vert puis une
app orange — c'est voulu, pas une dérive à corriger.

- [ ] **Sous-titre du splash, nouveau build** : « nigérienne » accentué en
      français ; en anglais, « Connecting the Nigerien diaspora » dès le
      démarrage à froid. (`splash_screen.dart`)
- [ ] **Compte en thème Orange.** Confirmer que seul le splash est vert et que
      le reste de l'app reste orange (pas de contamination).

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Écran de démarrage repeint en vert (2026-09-07) »).

---

## Bascule en anglais — ~1 600 chaînes branchées, rien vu à l'écran (2026-08-06)

**Priorité P1** · importance 4/5 — Un utilisateur qui veut supprimer son compte peut rester bloqué sur une erreur sans ré-authentification — fonction exigée par Google Play — et un anglophone voit un mélange de langues. *Bloqué : compte jetable (suppression de compte).*

Toute l'application vient d'être branchée sur `l10n` : l'admin (0 fichier sur
34 utilisait `l10n`), `businesses` (0/40), `embassies`, `transfers`,
`marketplace`, puis les 19 modules restants, `lib/shared/` et `lib/core/`.

**Comment basculer** : Réglages → choix de la langue
([settings_screen.dart:721](lib/features/settings/presentation/screens/settings_screen.dart:721),
`localeNotifierProvider.setLocale`). Les deux locales sont `fr` et `en`.

### Ce qui n'a jamais été vu en anglais

- [ ] **Le back-office en entier.** C'est le plus gros risque : 432 chaînes
  d'un coup, et il affichait du français en dur à un anglophone jusqu'ici.
  Parcourir les 18 écrans, en cherchant les libellés restés français.
- [ ] **Les écrans de profil**, notamment `edit_profile_screen` et
  `profile_config_screen` : les listes profession / région / ville viennent de
  `lib/core/constants/profile_options.dart` et restent **en français dans les
  deux langues** (ce sont des valeurs persistées, pas des libellés). Vérifier
  surtout que choisir « Autre » ouvre bien le champ libre — c'est exactement ce
  que ma régression `l10n.other` cassait, corrigée en `66248d2`.
- [ ] **Les 5 écrans qui utilisent `ErrorView`** : son « Réessayer » était en
  dur jusqu'à `4d6bc1b`.
- [ ] **La barre de navigation et le rail paysage** : leurs libellés sont
  passés sur `l10n` et c'est ce qui a cassé les tests du rail.

### Ce qui change aussi en français

- [ ] **141 accents restaurés** : « Reessayer » → « Réessayer », « Systeme » →
  « Système », « Echoue » → « Échoué », « Evenements par Categorie »… Séquelles
  de la réparation d'encodage CP850, invisibles jusqu'ici parce que ces chaînes
  n'étaient pas branchées. Un coup d'œil sur l'admin et les transferts suffit.

### Deux corrections de comportement, invisibles à l'analyse

- [ ] **Suppression de compte** : la demande de ré-authentification était
  détectée en cherchant « mot de passe » dans le message d'erreur — donc jamais
  en anglais, et à tort sur « Email ou mot de passe incorrect ». Elle se fie
  maintenant au code Firebase `requires-recent-login` (`9b7e69d`). Tester le
  parcours complet de suppression, en français **et** en anglais.
- [ ] **Compte supprimé** : `displayName == l10n.deletedUser` ne pouvait être
  vrai qu'en français. Passé sur `DeletedAccount.storedName`, le marqueur que
  le backend écrit réellement (`af44df0`, `4c32c01`). Vérifier qu'une
  conversation avec un compte supprimé affiche bien l'état « compte supprimé »
  et bloque le chat, dans les deux langues.

### Connu, non corrigé

- Les messages d'erreur voyagent comme **texte** dans `Failure(...)` : ils
  resteront en français en anglais. 207 sites de construction, 327 de lecture.
  ⚠ `lib/core/errors/app_error_messages.dart` contient **déjà** des messages
  FR/EN avec un `setLocale` — l'infrastructure existe, elle n'est simplement
  reliée à rien. C'est un raccordement, pas une création.
- Des libellés d'affichage vivent dans les entités (`requestTypeLabel`, statut
  de transaction, moyen de paiement) : pas de `context`, donc pas traduits.
- ~30 chaînes affichées n'ont aucune clé ARB, dont plusieurs ne doivent pas
  être traduites (séparateurs ` · `, gabarit `+227 XX XX XX XX`, badge `ÉCO`).

---

## Le « OVERFLOWED BY 190 » de la recherche venait du rail latéral (2026-08-05)

**Priorité P2** · importance 2/5 — En paysage clavier levé, les derniers items du rail latéral deviennent inatteignables ou le contenu est rogné — cas limite du téléphone tourné.

Le bandeau rayé se voit **depuis** l'écran de recherche de la messagerie, mais
le `RenderFlex` fautif est au-dessus de cet écran dans l'arbre : c'est
`TabletNavigationRail` (`lib/shared/widgets/tablet_navigation_rail.dart`).

**Correctif** : le rail défile (`SingleChildScrollView` + `mainAxisSize.min`)
au lieu de forcer sa hauteur. Tant qu'il y a la place, rien ne change à
l'écran (les items étaient déjà alignés en haut).

À vérifier sur l'appareil :

- [ ] **Paysage + clavier** (`adb shell settings put system user_rotation 1`),
      messagerie → taper dans le champ de recherche : **aucun bandeau rayé**,
      et zéro `RenderFlex … overflowed` dans logcat.
- [ ] **Les cinq items du rail restent atteignables** clavier levé : faire
      défiler le rail du doigt et taper « Profil » — la navigation doit partir.
      Vérifier aussi que ce défilement ne vole pas le geste au contenu à droite.
- [ ] **Portrait + clavier**, même écran : le rail ne doit pas apparaître du
      tout (largeur < 700 dp), la barre du bas reste en place, rien ne déborde.
- [ ] **font_scale 1.1** en paysage clavier levé : toujours aucun bandeau, et
      les libellés du rail ne sont pas coupés en plein mot.
- [ ] **Retour au portrait** après avoir fait défiler le rail : pas d'état de
      défilement résiduel qui décalerait la barre du bas.

### Le paysage fait basculer TROIS bascules « large », pas une

À 914 dp de large, le téléphone en paysage franchit trois seuils indépendants.
Il faut donc lire tout bug de paysage comme un bug de **mode tablette** :

| Seuil | Où | Ce qui bascule | État |
|---|---|---|---|
| 700 dp | `main_shell.dart` (`_kTabletBreakpoint`) | rail latéral au lieu de la barre du bas | **débordait — corrigé** |
| 700 dp | `feed_screen.dart:179` | rail droit (filtres villes + hashtags), FAB 64 au lieu de 52 | sain : le rail droit est une `ListView` |
| 600 dp | `responsive_service.dart` (`isTablet`) | `profile_screen` passe en largeurs tablette | sain : ce ne sont que des `maxWidth` dans des slivers |

Le seuil admin (`admin_dashboard_screen.dart:226`, 1200 dp) n'est pas franchi
en paysage. Vérifier quand même à l'œil, une fois, que le fil et le profil en
paysage ne sont pas juste « non débordants » mais **utilisables** :

- [ ] **Fil en paysage** : le rail droit de 330 dp ne mange pas la colonne
      centrale (elle passe de 640 à ~498 dp), et le FAB à 64 ne recouvre pas le
      dernier post.
- [ ] **Profil en paysage** : contenu centré, pas collé au rail de gauche.

---

## Menus déroulants bornés partout (`isExpanded`, 2026-08-04)

**Priorité P2** · importance 2/5 — Libellé de menu tronqué ou rogné dans des formulaires secondaires (boutique et transferts sous drapeau de fonction) — gêne de lecture, pas de blocage.

Balayage des 16 menus restants, même cause que le champ « Type * » ci-dessous.
Un seul écran débordait réellement à l'échelle 1.0 ; le reste est du
durcissement, donc à regarder surtout **à `font_scale` 1.1 et plus**.

- [ ] **Ambassade → « Demande administrative »** : le champ « Type de demande »
  ne déborde plus. C'est le cas le plus visible (débordait de 234 px en test).
- [ ] **Recherche d'employés d'une ambassade** : filtre « Département » —
  désormais monté par `test/features/embassies/employee_search_overflow_test.dart`,
  mais ce test ne prouve **pas** le correctif (vérifié par mutation : il passe
  aussi sans `isExpanded`, l'ellipse sur l'élément masquant le débordement).
  L'écran reste donc à regarder pour de vrai.
- [ ] Créer une entreprise, créer un podcast, fiche entreprise (feuille « Type
  de publication ») : vérifier qu'aucun libellé n'est tronqué à tort.

### Ellipse sur les éléments eux-mêmes (complément, 2026-08-04)

Durcissement récupéré d'une session parallèle : `maxLines: 1` + ellipse sur les
libellés des éléments, en plus d'`isExpanded` sur le champ. Le risque n'est plus
le débordement mais la **troncature abusive** — un « … » là où le libellé tenait.

- [ ] **Créer un podcast → « Langue » et « Fréquence de publication »** : les
  libellés traduits (haoussa, zarma) s'affichent en entier, pas en « … ».
- [ ] Les mêmes à `font_scale` 1.1 : là, une ellipse est normale.

---

## Débordement du champ « Type * » — création d'ambassade (2026-08-04)

**Priorité P3** · importance 2/5 — Formulaire du back-office légèrement rogné, visible des seuls administrateurs. *Bloqué : compte admin.*

Corrigé à l'aveugle (pas d'appareil branché pendant la correction), couvert
par `test/features/admin/admin_create_embassy_overflow_test.dart`.

- [ ] **/admin/embassies/create, champ « Type * »** : plus de bandeau
  « RIGHT OVERFLOWED BY 54 PIXELS ». Vérifier aussi que le libellé
  « Ambassade » reste lisible et que la flèche du menu est à sa place.
- [ ] **Menu déroulant ouvert** : les quatre types (dont « Mission
  diplomatique », le plus long) s'affichent en entier, sans ellipse.
- [ ] **Même écran à `font_scale` 1.1** : les six en-têtes de section
  (« Localisation GPS (optionnel) » est le plus long) passent à la ligne au
  lieu de déborder.

---

## Fiches d'écrans (Claude Design) — reprise écran par écran (2026-08-04)

**Priorité P2** · importance 4/5 — Réglages de notifications ou nom d'appareil qui semblent enregistrés mais ne le sont pas ; la liste d'appareils E2EE peut aussi grossir sans limite, le plafond de 5 n'étant appliqué nulle part (décision en attente, pas un test).

Reprise des écrans sur le document `Fiches d'écrans.dc.html` (17 fiches),
validées une par une avec Salim avant branchement.

- [ ] **20b — renommer un appareil** (`device_sync_service.dart`) : le
  renommage écrivait dans Firestore alors que la liste lit Supabase — il
  n'avait donc **aucun effet visible**. Câblé sur `e2ee_devices.device_name`.
  À vérifier : renommer un appareil, revenir, le nouveau nom persiste après
  un « tirer pour rafraîchir » **et** après relance de l'app. Vérifier aussi
  qu'un échec affiche bien une erreur (l'écran affichait « Appareil renommé »
  quoi qu'il arrive). ⚠ La migration `20260720120200` doit être appliquée au
  distant, sinon le repli garde la liste mais ignore le nom.
**✅ Accumulation d'appareils corrigée le 2026-08-04.** L'identifiant était un
`Uuid().v4()` rangé dans le stockage sécurisé : perdu au moindre vidage de
données, donc chaque régénération de clés créait une **nouvelle** ligne dans
`e2ee_devices`. Il dérive désormais du **SSAID Android**, propre au triplet
(clé de signature, utilisateur, appareil) depuis Android 8 — il survit au
vidage de données et à une réinstallation signée de la même clé. Lu par une
méthode ajoutée au canal natif déjà existant, donc **sans nouvelle
dépendance**. Le SSAID n'est jamais transmis : on publie un condensé SHA-256
salé par l'identifiant de compte, de sorte que deux comptes sur le même
téléphone restent incomparables côté serveur. Couvert par
`test/core/services/stable_device_id_test.dart` (4 cas).

- [ ] **Pas vérifiable sur cet appareil sans repartir de zéro** : les clés
  locales existent, donc `initializeKeys` sort tôt et l'identifiant en place
  (aléatoire) est conservé — c'est voulu, aucune session n'est cassée. Pour
  prouver le correctif il faut un compte ou un appareil neuf : générer des
  clés, vider les données, régénérer, et vérifier qu'**aucune 4ᵉ ligne**
  n'apparaît.

### 🔴 Le plafond de 5 appareils n'est appliqué nulle part

Vérifié sur la base distante (`pg_get_functiondef`) : `e2ee_add_active_device`
se contente d'un `ARRAY(SELECT DISTINCT unnest(active_devices || ARRAY[...]))`,
**sans aucun contrôle de nombre**. Et le seul test de plafond côté client vit
dans `DeviceSyncService.registerCurrentDevice`, qui **n'est pas sur le chemin
vivant** — la publication réelle passe par
`KeyManagerService._publishKeysToSupabase`, qui fait l'upsert et appelle la RPC
directement.

Donc « 3 appareils sur 5 » et « au-delà de 5, il faudra en révoquer un » sont
des promesses que le backend ne tient pas : la liste peut croître sans limite,
et chaque message destiné au compte doit être chiffré pour **chaque** entrée.

- [ ] **Décision en attente de Salim** : faire appliquer le plafond par la RPC
  (modifie une fonction déployée, donc production) et brancher le parcours
  « révoquer un appareil », ou retirer la promesse de l'interface.
- [ ] **20d — Réglages → Notifications** (`settings_screen.dart`,
  `notification_settings_screen.dart`) : la ligne « Notifications » de
  Réglages → Application ouvrait une feuille modale doublant l'écran ; elle
  pointe maintenant sur `/notifications/settings` et la modale est supprimée.
  À vérifier au doigt : le tap ouvre bien le nouvel écran (l'écran lui-même a
  été vu, mais pas ce chemin — build cassé par une session concurrente).
- [ ] **20d — sélecteur d'heures calmes** : le tap sur « De 22:00 à 08:00 »
  doit enchaîner deux sélecteurs (début puis fin) et n'enregistrer que si les
  deux sont confirmés. Jamais ouvert sur appareil.
- [ ] **20d — « Messages système » désactivable** : le verrou de la fiche a
  été abandonné (choix de Salim). L'interrupteur doit se couper et se
  rallumer normalement, et l'état doit survivre à une relance.

- [ ] **5a « Mon espace »** (`lib/features/feed/presentation/screens/mon_espace_screen.dart`) —
  refait sur la fiche : ligne d'identité `@poignée · Origine → Ville`, **trois**
  cases de stats (Publications / Abonnés / Abonnements) au lieu de deux, les
  cinq raccourcis regroupés dans **une seule carte** à filets au lieu de cinq
  cartes séparées, compteurs à droite de chaque ligne, pastilles d'icône
  34×34, et carte « Brouillons » réduite à une ligne avec chevron (les boutons
  Reprendre/Supprimer sont partis en 5b). À vérifier à l'œil : la trajectoire
  ville s'affiche bien quand `originCity`/`currentCity` sont renseignés, les
  compteurs ne restent pas bloqués sur « — », et le rendu en nocturne (rayons
  serrés) reste cohérent.
- [x] **Brouillons de publication multiples** (`preferences_service.dart`,
  `create_post_screen.dart`) — vérifié le 2026-08-04 sur SM A515F : rédiger un
  post puis « Annuler » écrit bien `flutter.post_drafts`, et la carte
  brouillon apparaît dans Mes publications après relance de l'app.
  Reste à vérifier à la main : 1) **deux** brouillons coexistent (le second
  n'écrase pas le premier) ; 2) « Reprendre » ouvre le bon texte ; 3) publier
  supprime le bon brouillon ; 4) la migration v1 → v2 sur une install qui
  possède un `post_draft` d'avant (⚠ `adb install -r` vide les données).
- [ ] **5b « Mes publications »** (`my_posts_screen.dart`, `my_post_card.dart`)
  — en-tête sur mesure + loupe (filtre local), onglets pleins
  « Publications · N » / « Repartages · N », carte de post compacte (méta,
  vignette 56×56, barre d'engagement, « Modifier », menu ⋯). **Jamais vue avec
  une vraie publication** : le compte de test en a zéro, seules la carte
  brouillon et l'état vide ont été rendus à l'écran. À revoir sur un compte
  qui publie : la ligne de méta (« Hier · 18:40 · Public »), la vignette
  média, le compteur de repartages qui disparaît à 0, et la recherche.
- [x] **5g « Votre première publication »** — vérifié le 2026-08-04 : cercle
  104, titre Caprasimo, deux amorces, bouton plein et FAB. Les deux amorces
  ouvrent l'éditeur pré-configuré (`?compose=photo|poll`) : **non testées**,
  la photo demande la permission galerie sur l'appareil.
- [x] **5c « Enregistrés »** (`saved_posts_screen.dart`, `saved_post_card.dart`)
  — vérifié le 2026-08-04 avec un post enregistré : en-tête + compteur, chips,
  sur-titre « CETTE SEMAINE », carte courte avec Retirer / Partager.
  Restent à vérifier : les filtres **Photos** et **Vidéos** (le compte de test
  n'a qu'un post texte, donc la vignette 72×72 n'a jamais affiché d'image), la
  feuille **Partager**, et le glissement latéral pour retirer.
- [x] **5d « Mon réseau »** (`follows_screen.dart`, `feed_pill_tabs.dart`,
  `follow_button.dart`) — vérifié le 2026-08-04 : en-tête, onglets à compteur
  permanent, barre de recherche, ligne de contact et pastille « Suivi ».
  Restent à vérifier : la **recherche** (le compte n'a qu'un abonnement), les
  **lignes de hashtag** sous Abonnements (aucun hashtag suivi sur ce compte),
  et le basculement Suivre → Suivi au doigt.
- [x] **20a « Modifier le profil »** — vérifié le 2026-08-04 : ✕ enfin
  visible, pastille photo neutre, et « Qui peut voir mon numéro ? » affiche
  « Tout le monde » (elle n'affichait rien). Restent à vérifier : la carte
  du numéro **vérifié** (le compte de test n'a pas de numéro vérifié, donc
  ni le masquage « +33 6 12 •• •• 47 » ni « Vérifié par SMS » n'ont été vus),
  et le sélecteur de visibilité au doigt.
- ⚠ **Publication de test à supprimer** : un post public « Publication de test
  pour verifier l affichage de Mes publications - a ignorer #DiasporaNiger » a
  été publié le 2026-08-04 depuis le compte `Sim A.` pour valider 5b/5c. Il
  est **toujours en ligne** et visible dans le fil de la diaspora.

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Fiches d'écrans (Claude Design) — reprise écran par écran (2026-08-04) »).

---

## Reprise du design (2026-08-03, suite) — Éco, accueil, carte, discussion

**Priorité P2** · importance 4/5 — Le mode données réduites pourrait télécharger les médias quand même et consommer le forfait de ceux qui l'ont activé pour l'éviter ; le reste est visuel. *Bloqué : deux comptes (réception de médias).*

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

- [ ] **Brouillon d'épisode de podcast** (`record_episode_screen.dart`,
  `podcast_provider.dart`, §2d). Le chemin est neuf de bout en bout, et rien
  ici n'est vérifiable sans base réelle :
  - enregistrer un épisode puis appuyer sur **« Brouillon »** : la
    confirmation doit dire « enregistré en brouillon », **pas** « publié » ;
  - vérifier en base que la ligne a bien `status = 'draft'` **et**
    `published_at` **nul** — c'est le point le plus facile à casser, le
    provider posait la date dès qu'il n'y avait pas de programmation ;
  - le brouillon **ne doit pas apparaître** comme épisode publié dans la
    fiche du podcast (§3b) ni pour un abonné ;
  - il **ne doit pas compter** dans la section « Rythme de publication » des
    statistiques (§4a) — c'est exactement à quoi sert `published_at` nul ;
  - contre-test : « Terminer et publier » doit toujours produire
    `status = 'published'` avec une date. Une régression ici rendrait la
    publication silencieusement inopérante.

- [ ] **Note « muet en silence » de la modération fantôme** (§3c,
  `ghost_moderator_screen.dart`). Vérifier que la phrase apparaît bien sous
  la grille des quatre actions et reste lisible — elle est en chasse fixe
  taille 9. C'est la seule chose qui distingue cette action d'un mute
  ordinaire : si elle déborde ou passe inaperçue à `font_scale = 1.1`, elle
  ne remplit pas son rôle.

---

## Quatrième vague — écrans repris en production (2026-08-03)

**Priorité P1** · importance 3/5 — Un badge qui affiche le chiffrement de bout en bout sur un appel qui ne l'est pas trompe l'utilisateur sur sa confidentialité ; les écrans de récupération des clés peuvent être illisibles de nuit. *Bloqué : deux comptes (appel).*

### À vérifier en thème sombre en priorité

C'est la famille de défauts la plus récurrente du projet, et cette vague a
converti une centaine de couleurs figées en jetons adaptatifs.

- [ ] **Appareils connectés** (`devices_screen.dart`) et **Sauvegarde des
  clés** (`security_backup_screen.dart`) — 26 couleurs routées, dont des
  fonds `shade50` presque blancs. Ce sont les écrans qu'on ouvre dans le
  noir après avoir perdu son téléphone : vérifier que la carte « sauvegarde
  active », l'avertissement de passphrase et le bouton « Révoquer » restent
  lisibles.
- [ ] **Modifier le profil**, **Réglages de notifications**, **Messages
  favoris**, **Nouvelle conversation** — mêmes conversions.

### Les trois blancs volontairement conservés (`edit_profile_screen.dart`)

Ils sont posés sur un aplat saturé et **doivent** rester blancs. Le
raisonnement dit qu'ils passent ; seul l'écran le prouve.

- [ ] SnackBar de succès après enregistrement du profil — glyphe blanc sur
  le vert de succès, en clair **et** en nuit.
- [ ] Pastille de code langue (FR, HA…) dans « Langues parlées », état
  sélectionné et non sélectionné.

### Les voiles de contraste laissés en place

Trois écrans gardent des noirs semi-transparents parce qu'ils sont posés
sur du contenu arbitraire. À vérifier **sur une image claire**, cas où un
voile trop faible devient illisible :

- [ ] **Galerie de conversation** — la durée d'une vidéo (« 0:12 ») sur une
  vignette surexposée.
- [ ] **Écrans d'appel** — les commandes blanches sur un flux vidéo clair.
- [ ] **Carte** — les épingles et cercles de rayon, laissés en couleurs
  fixes parce qu'ils se lisent sur le fond Google Maps et non sur le fond
  de l'app.

### Points qui ne se voient qu'à l'exécution

- [ ] **Mention « CHIFFRÉ DE BOUT EN BOUT » de l'appel 1-à-1.** Elle est
  conditionnée à `E2EEService.instance.isE2EEEnabled`. Vérifier les deux
  sens : qu'elle **apparaît** sur un appel réellement chiffré, et qu'elle
  **n'apparaît pas** si la clé n'est pas posée. Un badge qui ment sur le
  chiffrement est pire que pas de badge.
- [ ] **Fil et Mon espace en thème clair (mode « organic »).** 13 libellés
  sont passés de la police de l'app à **Figtree** via `FeedText`. Le défaut
  était invisible en nuit et ne se voit qu'en clair, à côté des titres
  Caprasimo. Prévoir un premier lancement **avec réseau** : `google_fonts`
  télécharge les fontes.
- [ ] **Modifier le profil — l'avatar a changé de place.** Il quitte
  l'en-tête héros pour rejoindre le formulaire. Vérifier que l'animation
  `Hero` (tag `profile_avatar`) depuis l'écran de profil ne saute pas, et
  que la barre repliée reste lisible au défilement.
- [ ] **Réglages de notifications** — les libellés de section sont passés en
  chasse fixe capitales. À `font_scale = 1.1`, vérifier qu'ils ne coupent
  pas (« CE QUI VOUS ALERTE » est long).

---

## Thème sombre — jetons clairs codés en dur

**Priorité P2** · importance 3/5 — Un écran de profil ou la carte peut rester sur fond clair avec du texte clair en mode nuit, donc illisible.

- [ ] **Les 9 autres fichiers de la même passe** : 4 écrans de transferts,
  3 écrans de profil, la carte et `friend_list_item` — non atteignables sans
  session, la réinstallation déconnecte l'app. À rouvrir en mode nuit une fois
  reconnecté.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Thème sombre — jetons clairs codés en dur »).

---

## Guide de style — alignement des jetons (2026-08-03)

**Priorité P3** · importance 3/5 — Contours de puces, de cartes ou de bulles trop discrets qui se fondent dans le fond — cosmétique, et une partie des teintes a changé depuis (recolorisation du 2026-08-25).

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

- [ ] **Bordure des bulles reçues** (`messages/…/message_bubble.dart`, les deux
  copies) : `_kRecvBorderLight/Dark` figeaient `#EFE7DB` / `#3D352C` ; passe
  par `context.borderColor`. Seul le nocturne change (`#2A241E`). **À
  vérifier** : dans une conversation en mode nuit, la bulle reçue doit encore
  se détacher du fond.

---

## Bascule design_v2 → production, famille 2 : les services (2026-08-03)

**Priorité P2** · importance 3/5 — Écrans de services toujours actifs, jamais vus tourner : débordement, texte illisible de nuit, voire champ inaccessible sous le clavier à la création d'événement.

Onze écrans sont passés de `lib/design_v2/` à `lib/features/` : annuaire
Business (5), ambassades (4), événements (2). Ils étaient jusqu'ici
inatteignables autrement que par la galerie `/design-v2` ; ils sont
maintenant **ceux que l'app ouvre pour de bon**. Rien n'a été vu tourner.

- [ ] **Annuaire Business** (§17c, §17d, §18a→18d) : liste, fiche, création,
  avis et mise en avant. Vérifier surtout la **fiche** (`business_detail`),
  qui empile en-tête, posts, avis et actions — c'est là qu'un débordement à
  `font_scale = 1.1` est le plus probable.
- [ ] **Ambassades** (§13b, §16d, §17a, §17b) : liste, fiche, demande
  administrative, message. Le statut ouvert/fermé est passé aux jetons
  `errorColor`/`successColor` : **regarder en thème sombre**, c'est
  exactement ce que ce changement corrige.
- [ ] **Événements** (§13a, §16e) : liste et création. La création est le
  formulaire le plus long des trois features (sélection de médias,
  localisation, date) — vérifier qu'aucun champ ne passe sous le clavier.
- [ ] **Thème sombre des onze écrans**, en priorité. C'est la famille de
  défauts la plus récurrente du projet, et ces écrans n'ont jamais été
  affichés ailleurs que dans la galerie de debug.

---

## Bascule design_v2 → production, famille 3 : boutique, support, transferts, appels (2026-08-03)

**Priorité P2** · importance 2/5 — Écrans secondaires jamais vus tourner qui pourraient déborder, ou une frise de transfert trompeuse sur un échec.

Dix écrans de plus dans `lib/features/`, jamais vus tourner :

- [ ] **Support** (§22a→22d) : nouveau ticket, mes demandes, suivi, état vide.
- [ ] **Historique d'appels** (§13c) et **création de podcast** (§2c).

---

## Bascule design_v2 → production, famille 4 : messagerie, groupes, recherche, profil (2026-08-03)

**Priorité P2** · importance 4/5 — Un geste vocal mal signalé peut faire envoyer une note qu'on voulait annuler ; le reste est de la mise en page sur des écrans très fréquentés mais déjà utilisés au quotidien.

Onze fichiers, dont toute la discussion. C'est le lot le plus visible des
quatre familles, et **trois écrans y perdent leur en-tête** — c'est voulu,
mais c'est exactement ce qu'il faut regarder en premier :

- [ ] **Messagerie — liste** (§9a, §9e) : l'en-tête dégradé et ses cercles
  décoratifs ont disparu au profit d'un en-tête plat. Vérifier que le compteur
  de non-lus reste lisible et que la liste ne commence pas collée au haut de
  l'écran.
- [ ] **Mon profil** (§10a) : l'écran n'a plus de `SliverAppBar`. Il ne se
  replie donc plus au défilement — plus d'avatar+nom qui apparaît en haut.
  Vérifier que le retour et les actions restent atteignables tout en bas de
  page, puisqu'il n'y a plus de barre épinglée.
- [ ] **Recherche** (§12d) : plus de titre d'écran, le champ **est**
  l'en-tête. Ouvrir la recherche depuis les groupes et depuis les
  discussions : le contexte doit rester visible dans le **placeholder**
  (« Rechercher un groupe… ») — c'est le seul endroit où il subsiste.
- [ ] **Discussion complète** (§3b, §3c, §4a→4f, §6b, §6c) : écran, composer,
  bulles texte et bulles audio sont maintenant tous en v2. À regarder
  ensemble — les trois états d'enregistrement vocal avec leurs libellés
  (« Glisser ‹ pour annuler », « Relâcher pour annuler », « Mains libres »),
  la pastille de vitesse en contour, le poids du fichier.
- [ ] **Groupes** (§9c, §9d, §9f) et **notifications** (§12c).

---

## Bascule design_v2 → production : la carte (§7e, 2026-08-03)

**Priorité P1** · importance 2/5 — La carte pourrait ne pas se recharger après un passage en mode liste ou démarrer dans le mauvais mode, et le tri inventer un classement sans position. *Bloqué : compte de test en mode privé (activer le partage demande l'accord de Salim).*

Le §7e entre en production. C'est le lot le plus testable de la session,
parce qu'il change un **comportement**, pas seulement un habillage :

- [ ] **Bascule Carte / Liste** dans l'en-tête du panneau. En mode liste la
  carte n'est **pas chargée du tout** (un aplat la remplace) : vérifier
  qu'aucune tuile ne se télécharge, et que revenir en mode carte la recharge
  correctement.
- [ ] **Démarrage en mode liste si « données réduites » est actif** dans les
  réglages. C'est le point le plus facile à casser sans le voir : couper le
  réglage, rouvrir la carte, elle doit démarrer en mode carte ; le rallumer,
  elle doit démarrer en liste.
- [ ] **Badge « tuiles allégées »** et bouton **« Plein écran »**.
- [ ] **Tri « Les plus proches » ⇄ « Par nom »**. Le tri par distance ne
  s'applique que si la position est connue — vérifier **position coupée** :
  l'ordre d'arrivée doit être conservé, pas un classement inventé.

- [ ] **Réglages de notifications** (§20d) : seul le titre de la barre a
  changé (serif, barre plate). Vérifier que les **étiquettes de section en
  chasse fixe** et le bandeau d'information sont restés tels quels — c'est
  précisément ce qu'une bascule du fichier aurait annulé.
- [ ] **Titres serif portés sans bascule** — appareils connectés (§20b),
  sauvegarde des clés (§20c), appel 1-à-1 (§23a). Dans les trois cas seul le
  titre a bougé. Ce qu'il faut vérifier est donc l'**absence** de changement
  ailleurs : les pastilles d'état (vert/orange/rouge) des appareils et des
  clés doivent rester celles des jetons adaptatifs — les regarder en **thème
  sombre**, c'est là qu'une régression se verrait.
- [ ] **Appel 1-à-1** (§23a) : le nom passe en serif blanc sur le fond
  sombre. Vérifier qu'il reste lisible **par-dessus le flux vidéo**, et
  qu'un nom long ne déborde pas à `font_scale = 1.1` — le serif est plus
  large que la fonte précédente à taille égale.

---

# 13. Backend, sécurité et observabilité

Supabase et Firebase côté serveur, accès anon, stockage, journaux, Crashlytics, back-office.

---

## ⬜ `users` : un compte connecté lit e-mail, position et jetons d'autrui (2026-09-21)

**Priorité P0** · importance 5/5 — Dernière exposition vivante de l'audit pré-prod (1.1b), et c'est le fond des refus Play sur la localisation. Rien n'est fermé : ce qui a été posé le 2026-09-21 PRÉPARE la fermeture, qui exige une version cliente.

**Version cliente ÉCRITE le 2026-09-21** (commits `da15fbc` et suivant) — les
16 sites : 11 lectures de `*` (dont un `.stream()` et le `RETURNING *` de
`updateProfile`), 3 lectures nommées de colonnes révoquées sur sa propre ligne
— **dont l'enregistrement du jeton push** — et 2 abonnements temps réel. Plus
deux upserts que la première version gardait et que **la répétition a pris en
défaut** : sous la cible, `ON CONFLICT DO UPDATE SET col = EXCLUDED.col` exige
de LIRE la colonne, donc écrire `email`/`phone_number` par upsert tombait en
42501 (enregistrement du profil, connexion). Remplacés par
`ecrireSaLigneUsers` (UPDATE puis INSERT). Migration `20260921093000`
APPLIQUÉE (positions par identifiants, jeton push modifié en base).

**Changements de comportement à connaître :** la carte en mode pays trie par
dernière activité (et non plus par date de position, qui n'est plus lisible) ;
la carte en direct demande les positions par lots de 300 ms au lieu de les lire
dans le message ; la liste des mentions n'affiche plus l'e-mail d'autrui quand
son nom manque (« Utilisateur » à la place).

**Le piège des deux abonnements temps réel.** Mesuré en exécutant la
fonction même du serveur (`realtime.apply_rls`,
`tools/rls_tests/temps_reel_droits_colonnes.sql`) : le temps réel respecte
les droits par colonne, mais **en retirant la colonne, sans erreur**. Donc
sous la cible : la carte en direct ne bougerait plus personne, et la
révocation de session par un administrateur cesserait — les deux en silence.

**À vérifier sur appareil, sur un build de cette version** (rien n'a été vu
tourner) :

- [ ] profil (le sien, celui d'un autre), recherche, liste des discussions,
  carte et back-office s'affichent comme avant — le sien avec son e-mail et
  son téléphone ;
  ✅ en partie, Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : son profil (Sim), celui d'un autre (Salim : nom, pseudo, en ligne, groupes en commun, aucun e-mail), recherche « Salim » (2 résultats), liste des discussions : tout s'affiche. Aucun écran n'affiche son propre e-mail ; Sim n'a pas de téléphone. Carte et back-office non vus.
- [ ] **un nouvel appareil reçoit les notifications push** — c'est le site le
  plus dangereux ; et après déconnexion, l'appareil n'en reçoit plus ;
- [ ] modifier son profil (téléphone compris) et enregistrer : pas d'erreur,
  valeurs relues ;
- [ ] **première connexion d'un compte neuf** (chemin INSERT de
  `ecrireSaLigneUsers`), puis première sauvegarde de son profil ;
- [ ] la carte bouge en direct (délai de l'ordre de la demi-seconde), un
  profil qui coupe le partage en disparaît aussitôt, et le mode « pays »
  affiche bien des marqueurs ;
- [ ] une session révoquée par un administrateur éjecte bien l'appareil, un
  bannissement aussi ;
- [ ] la liste des discussions garde les noms après une coupure réseau (le
  flux de profil relit à la reconnexion, comme `.stream()` le faisait) ;
- [ ] puis, après publication et pose du verrou : répéter la cible par son
  banc (0 échec attendu) avant de l'appliquer.

---

## ⬜ Avis sur les entreprises : basculés de Firestore vers Supabase (2026-09-21)

**Priorité P2** · importance 3/5 — L'annuaire affichait 0 avis et aucune note quelles que soient les évaluations : les avis allaient dans Firestore, les entreprises vivent dans Supabase. Le drapeau `businessDirectory` est fermé et la production porte 2 fiches, 0 avis.
*Bloqué : le drapeau `businessDirectory` à ouvrir sur un appareil. Le build Play 1.2.2+26 (`f22aaff`) contient déjà `e2dca73`.*

**Côté app** — `ReviewSupabaseDataSource` remplace le datasource Firestore
(supprimé). La réponse du gérant passait par `updateReview`, c'est-à-dire par
la réécriture de l'avis d'autrui : les règles Firestore la refusaient déjà, elle
passe maintenant par `replyToReview`. Test
`test/features/businesses/review_supabase_datasource_test.dart` (11 cas) : le
corps de chaque requête est vérifié clé par clé, car une colonne de trop fait
tomber toute la requête en 42501.

**Règles nouvelles côté serveur** (l'écran les respectait déjà en masquant les
boutons) : le gérant ne note pas sa propre fiche, on ne se trouve pas « utile »
soi-même, on ne signale pas son propre avis.

**À vérifier sur appareil** (migrations appliquées, nouvelle version, drapeau
ouvert) :

- [ ] déposer un avis avec une photo : il apparaît, avec **son propre** nom et
  sa photo ; la note et le nombre d'avis de la fiche et de sa carte dans
  l'annuaire se mettent à jour ;
- [ ] le modifier, puis le supprimer : la note suit, et retombe à « pas de
  note » au dernier avis retiré ;
- [ ] un second compte : « Utile » monte puis redescend ; « Signaler » affiche
  le message de réussite, et le signalement apparaît dans le back-office
  (écran Signalements, type « Avis », bouton vers la fiche) ;
- [ ] le gérant répond à un avis, puis retire sa réponse ;
- [ ] le gérant modifie sa fiche juste après (nom, téléphone) : pas de 42501.

---

## ⬜ Promotion payante et badge « vérifié » fermés au client (2026-09-21)

**Priorité P1** · importance 4/5 — Le drapeau `businessDirectory` est fermé et la production ne porte que 2 fiches, mais ce durcissement change le comportement d'un écran d'édition que personne n'a jamais ouvert sur un téléphone.

**À vérifier sur appareil** (rien n'a été vu tourner, le drapeau est fermé) :

- ouvrir une fiche, changer le nom, le téléphone, la description, les horaires
  et enregistrer — **doit passer**. Si ça tombe en 42501, la garde est trop
  large et c'est elle qu'il faut corriger, pas le client ;
- créer une entreprise de bout en bout ;
- côté back-office : vérifier une fiche (`admin_provider.dart:547` et `:577`)
  et basculer la promotion (`:~600`) — les deux passent par PostgREST sous
  l'identité de l'administrateur, et le banc les couvre (cas 15 et 16), mais
  jamais depuis l'écran ;
- le compteur de vues d'une fiche doit continuer de monter
  (`increment_business_view_count`, chemin `SECURITY DEFINER`).

**⚠️ Risque connu, étroit, assumé.** `updateBusiness` renvoie le modèle que
l'écran détient. Si un administrateur vérifie la fiche pendant que son
propriétaire a l'écran d'édition ouvert, la prochaine modification, même
innocente, lèvera 42501 sur une valeur périmée. Le remède définitif est côté
client : cesser d'envoyer `is_verified`, `is_boosted` et `boost_expires_at`
dans `_versLigne`. À faire avec la prochaine version cliente.

---

## ⬜ Salons audio : l'argent et l'identité repassent au serveur (2026-09-21)

**Priorité P1** · importance 3/5 — Dernière pièce de la chaîne de paiement. Le drapeau `audioRooms` est fermé et les quatre tables sont vides : rien n'est vérifiable sans ouvrir le drapeau sur un appareil, et c'est justement ce qu'il faudra faire avant toute réouverture.

**À vérifier sur appareil, le jour où le drapeau s'ouvrira** (rien de tout
ceci n'a été vu tourner) :

- créer une salle, la démarrer, la terminer — les dix colonnes accordées
  suffisent-elles vraiment au parcours complet ? Le banc les a mesurées dans
  `audio_room_remote_datasource.dart`, pas observées à l'usage ;
- couper puis rétablir le micro d'un intervenant (`mutedSpeakers`) ;
- **régression attendue et voulue** : `getOrCreateCreatorProfile` et
  `enableMonetization` (`monetization_supabase_datasource.dart:251` et `:280`)
  échouent désormais en 42501 au lieu de réussir. La fiche de créateur naît
  côté serveur, à l'embarquement Stripe. Vérifier que l'écran de monétisation
  ne reste pas bloqué sur un chargement muet ;
- `markTicketUsed` (`:113`) échouait déjà faute de policy d'UPDATE ; il échoue
  maintenant plus tôt. Vérifier que l'écran le dit.

---

## ⬜ `public.friends` : le serveur seul écrit l'audience (2026-09-21)

**Priorité P1** · importance 3/5 — Un compte connecté pouvait insérer, modifier et supprimer ses propres lignes d'amitié par PostgREST, alors que cette table décide des audiences « Amis » et « Abonnés ». Le fil doit continuer de lire ses amitiés.

- `onFriendRequestAccepted` (nouveau) écrit les deux sens dans
  `public.friends` à la transition `pending → accepted`. C'est désormais le
  seul chemin d'entrée. Il marche avec **toutes les versions de l'app déjà
  installées** : cette mise à jour n'a pas changé côté client.

- [ ] **Accepter une demande d'ami** : l'ami apparaît des deux côtés, et le
  journal ne porte aucun « ajout … ignoré ». C'est LE test qui compte : si
  `onFriendRequestAccepted` ratait, l'amitié n'entrerait plus du tout dans
  `public.friends` — l'audience « Amis » resterait fermée au lieu de s'ouvrir
  à tort. Panne silencieuse, invisible tant qu'aucune publication « Amis »
  n'existe.
- [ ] **Auto-acceptation croisée** (deux personnes s'envoient une demande
  l'une à l'autre) : `sendFriendRequest` accepte la demande inverse — même
  transition, donc même déclencheur, à confirmer en vrai.

- [ ] **Fil et personnalisation** : ouvrir le fil avec un compte qui a des
  amis — les publications d'amis s'affichent, et « Découvrir » ne se vide pas.
- [ ] **Accepter une demande d'ami de bout en bout** : l'ami apparaît des deux
  côtés, et la publication « Amis » de l'un devient visible à l'autre (créer
  une publication à cette audience pour le vérifier — il n'en existe aucune).
- [ ] **Retirer un ami** : l'audience se referme des deux côtés.

## ⬜ Push arbitraire : type en liste fermée, blocage, quota (2026-09-21)

**Priorité P0** · importance 4/5 — N'importe quel compte connecté pouvait faire arriver sur le téléphone de n'importe qui une bannière de son cru, sous le type de son choix — `system` compris. Reste à voir que les notifications légitimes arrivent toujours.

Trois gardes :

1. **Type en liste fermée** — les douze que `lib/` émet vraiment. `system`,
   `message`, `messageMention` et les types de groupe viennent de
   déclencheurs serveur qui écrivent directement dans `notifications` : ils ne
   passent pas par cette RPC et ne sont pas concernés. Vérifié en base : les
   types hors liste n'ont aucun `actor_id`, signature d'une écriture serveur.
2. **Le blocage est respecté**, en silence — une erreur apprendrait à
   l'appelant qu'il est bloqué.
3. **Quota horaire** : 60 par émetteur, 10 par couple émetteur/destinataire.

- [ ] **Demande d'ami, acceptation, commentaire, inscription à un
  événement** : la notification arrive toujours chez le destinataire. C'est
  le test qui compte — un type oublié dans la liste fermée ferait échouer la
  RPC, et l'appelant **avale l'erreur** (`catch` qui n'interrompt rien).
- [ ] **Bloquer quelqu'un, puis se faire notifier par lui** : rien n'arrive.
- [ ] **Surveiller le journal** : `type … non autorisé` sur un parcours
  normal désigne un type manquant dans la liste.

## ⬜ `users` n'est plus lisible sans compte (2026-09-20)

**Priorité P0** · importance 5/5 — Avec la seule clé publique de l'APK, un anonyme lisait 123 profils : 85 e-mails, 55 téléphones, 61 positions GPS (mesuré en production). La migration ferme la porte ; reste à voir qu'un démarrage lent n'y perd rien.

**Ce que le banc ne voit pas.** Pendant la fenêtre `_startFromLocalSession`
(session Firebase locale, pont Supabase pas encore confirmé), une lecture de
`users` peut partir en anon. Jusqu'ici elle **réussissait** pour tout profil
non privé ; elle rendra désormais 42501. Lu dans le code :

- `getProfile`, `getProfilesByIds`, `getNearbyProfiles`, `isHandleAvailable`,
  `_readFlag` attendent la session et lèvent sans interroger — inchangés ;
- `getUserStream` attend 3 s puis s'abonne **quoi qu'il arrive**
  (`profile_supabase_datasource.dart:138`) : en anon, la lecture initiale
  lèvera au lieu de rendre une ligne ;
- `_getUserDataFromSupabase` (`auth_remote_datasource.dart:732`) n'attend
  rien : son `catch` retombe sur les données Firebase Auth, donc
  `adminRole = null` et `isBanned = false` le temps de cette fenêtre ;
- `searchProfiles`, `getProfilesByCountry` et `nomDe` (`mls_providers.dart:60`)
  n'attendent rien non plus.

- [ ] **Démarrage à froid sur réseau lent** (bridé, pas coupé — voir
  « Cartographie des accès anon réellement nécessaires » : le réseau coupé ne
  reproduit pas cette fenêtre) : la liste des discussions affiche
  les noms et avatars, pas « Utilisateur », et ils ne disparaissent pas après
  coup.
- [ ] **Même démarrage, compte administrateur** : l'entrée du back-office est
  là dès l'accueil, ou y revient sans relancer l'app.
- [ ] **Inscription d'un compte neuf** : le champ pseudo ne reste pas bloqué
  et l'enregistrement du profil aboutit (le premier échange d'un compte neuf
  échoue : sans session, `isHandleAvailable` rend « libre » sans interroger
  et laisse la contrainte UNIQUE trancher).
- [ ] **Recherche de membres et carte** juste après l'ouverture : des
  résultats, pas un écran d'erreur.

## ⬜ Les echecs attrapes remontent enfin a Crashlytics (2026-09-14)

**Priorité P1** · importance 4/5 — Aucun refus de permission n'atteignait Crashlytics : c'est pour ça qu'accepter une demande d'ami est resté impossible des mois. Chaque échec montré à l'usager y part désormais en non-fatal.

Deux précautions, testées : le message est **caviardé** (uid, uuid, e-mail,
JWT, sous-domaine du projet) parce que PostgREST met l'URL complète dans ses
messages et Firebase le chemin du document ; et une même panne ne part
**qu'une fois par 5 minutes**, sinon un écran en erreur hors ligne inonderait
la console — `messageErreurUsager` est aussi appelé depuis des `build`.

- [ ] **Vérifier l'arrivée** : couper le réseau, ouvrir un écran qui charge,
  puis consulter la console Crashlytics — un non-fatal `echec_affiche` avec
  la clé `famille_echec = reseau`.
- [ ] **Vérifier le caviardage sur un vrai message** : la fiche Crashlytics ne
  doit contenir ni uid, ni uuid, ni le sous-domaine Supabase.
- [ ] **Vérifier le volume** après 24 h : si une famille domine, c'est une
  fonctionnalité cassée, pas du bruit — c'est exactement ce qu'on cherche.

## ⬜ Balayage des invariants de données — 2 anomalies en production (2026-09-14)

**Priorité P1** · importance 4/5 — Deux écritures n'ont pas eu lieu, sans erreur nulle part : deux amitiés à sens unique (une personne ne voit pas les publications « Amis » de deux autres) et un événement restreint à un ensemble vide (visible de personne). *Bloqué pour la réparation : décision de Salim, ce sont des écritures en production.*

`tools/invariants_donnees.py` — la contrepartie Supabase du banc de règles.

```bash
python tools/invariants_donnees.py
```

- [ ] **Événement restreint sans invités** : créer un « Personnes choisies »,
  choisir quelqu'un, puis tout décocher et valider — le formulaire doit
  refuser. Puis vérifier qu'un échec d'audience affiche bien le message rouge
  « personne d'autre que vous ne le voit ».
- [ ] **Modifier l'audience après coup** : ouvrir un événement dont on est
  l'organisateur → Modifier → le sélecteur doit être **pré-rempli** avec
  l'audience réelle (et non « Public » par défaut), en changer les invités,
  enregistrer, rouvrir : le choix tient. Les personnes ajoutées reçoivent la
  notification d'invitation que pose `set_event_audience`.
- [ ] **Bandeau d'avertissement** : sur un événement restreint à une audience
  vide, l'organisateur voit le bandeau rouge « Personne d'autre que vous ne
  voit cet événement » ; les autres comptes ne voient rien (et pour cause, ils
  ne voient pas l'événement).
- [ ] **L'événement fautif de production** (`fea8bc43…`, organisateur
  `mz4JJ8Fh…`) est toujours invisible, mais **son auteur peut désormais le
  réparer lui-même** depuis l'écran de modification. Rien à écrire en base :
  on ne devine pas à sa place qui il voulait inviter. Vérifier sur appareil que
  le bandeau apparaît bien et que le sélecteur enregistre.
- [ ] **Relancer le balayage après chaque lot** qui touche une écriture en
  deux temps, et y ajouter l'invariant correspondant.

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Balayage des invariants de données — 2 anomalies en production (2026-09-14) »).

## ⬜ Les quatre défauts de la console, triés par appareil (2026-09-10)

**Priorité P2** · importance 2/5 — Si c'est un vrai utilisateur, il subit des plantages à l'ouverture d'écrans de paiement ou d'appel, et le taux sans plantage suivi par Play chute. *Bloqué : hors appareil (Crashlytics / Play Console).*

- [ ] **Identifier le OnePlus 8 Pro / Android 11** : il porte ces sept
  plantages ET 75 % des erreurs `google_fonts`. Testeur de la piste interne,
  appareil d'un proche, autre outil automatisé ? Tant qu'il n'est pas
  identifié, le compter comme un **vrai utilisateur**.
- [ ] **`RenderFlex` (21) et `GoError` (19)** : appareil de test uniquement.
  Aucun des deux n'est diagnosticable en l'état — la pile s'arrête à
  `main.dart:172`/`184`, c'est-à-dire au **gestionnaire d'erreurs**, jamais au
  widget ni au `context.pop()` fautif. ⚠️ Le problème « RenderFlex » est en
  réalité un **fourre-tout** : sa fiche contient aussi un avertissement
  `ListTile background color or ink splashes may be invisible`, sans rapport.
  Crashlytics regroupe par pile, et toutes les erreurs Flutter partagent la
  même — celle du gestionnaire. Y toucher demande d'abord de les distinguer.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Les quatre défauts de la console, triés par appareil (2026-09-10) »).

---

## ⬜ Journalisation : deux fuites en release et la garde du LoggerService (2026-09-09)

**Priorité P2** · importance 2/5 — Les erreurs de la carte resteraient invisibles en production ; le risque de régression d'appel est faible, seul un log ayant changé. *Bloqué : mode privé du compte de test (carte) et deux comptes (appel).*

**Suite (2026-09-09) — les erreurs remontent maintenant à Crashlytics.**
Le garde laissait les 9 appels `LoggerService.w/e` (carte, publication de
position, profil) totalement muets en production. `_log` remonte désormais le
**seul** niveau `error` à `FirebaseCrashlytics.recordError(..., fatal: false)`,
avec `reason` = le message. Les autres niveaux restent debug-only.

- [ ] **Aucune régression d'appel** : passer un appel 1:1, sonnerie et bulle
  d'appel comme avant. Le jeton VoIP est toujours propagé à
  `onVoipTokenUpdated` — seul son affichage a changé — mais c'est le chemin
  iOS/CallKit, donc à revalider le jour où un appareil iOS est disponible.
- [ ] **Carte en release** : ouvrir la carte hors ligne (c'est là que les
  `LoggerService.w` de `map_screen.dart` se déclenchent) et vérifier que
  l'écran se comporte comme avant — le silence des logs ne doit rien changer
  à l'affichage ni aux replis.
- [ ] **Remontée Crashlytics** : provoquer le `LoggerService.e` de
  `map_screen.dart:760` (« Error loading nearby members », carte hors ligne)
  sur un APK **release**, puis vérifier dans la console Firebase Crashlytics
  qu'un non-fatal apparaît avec ce message en `reason`. Compter quelques
  minutes de latence, et **relancer l'app une fois** : Crashlytics n'envoie
  souvent son lot qu'au démarrage suivant. Ne pas chercher à le vérifier en
  debug — la branche n'y est pas prise.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Journalisation : deux fuites en release et la garde du LoggerService (2026-09-09) »).

---

## ⬜ Les ~920 `debugPrint` restants neutralisés en release (2026-09-09)

**Priorité P3** · importance 3/5 — Au pire, des traces d'appel (SDP, candidats ICE) restent lisibles par adb sur un APK de production — aucun effet fonctionnel attendu. *Bloqué : deux comptes (appel).*

[main.dart](lib/main.dart) — une ligne, en tête de `main()` :

```dart
if (kReleaseMode) {
  debugPrint = (String? message, {int? wrapWidth}) {};
}
```

- [ ] **Rien n'a changé en debug** : `flutter run` et vérifier que les logs
  habituels sortent toujours (la neutralisation est derrière `kReleaseMode`).
  Non vérifié — la session n'a construit que des release.
- [ ] **Appel WebRTC sur la release** : non parcouru. `webrtc_service.dart`
  porte 140 `debugPrint` à lui seul — c'est le plus gros bloc encore non
  observé.
- [ ] **Carte avec partage de position actif** : l'onglet Carte a bien été
  ouvert, mais le compte est en « Mode privé activé » : l'écran s'arrête sur
  sa carte d'invitation (et la liste par ville, qui charge bien les ambassades).
  Le rendu cartographique et les positions temps réel des membres — donc les
  logs de `location_publisher_service` et du canal realtime — n'ont pas été
  exercés.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Les ~920 `debugPrint` restants neutralisés en release (2026-09-09) »).

---

## ⬜ Second verrou : `print` brut et paquets tiers (2026-09-09)

[logs_release.dart](lib/core/utils/logs_release.dart) — `main()` lance
désormais le démarrage dans une zone qui avale `print` :

```dart
void main() => demarrerSansLogsEnRelease(_demarrer);
```

⚠️ **Deux pièges de mesure rencontrés, à ne pas répéter.**

**0. Le relevé `uiautomator` peut contredire l'écran.** Le plus coûteux des
trois. En cherchant à supprimer le message envoyé par erreur, le dump plaçait
la bulle visée à `601,941` ; l'appui long à cet endroit a sélectionné un
**autre** message (une position, envoyée 56 min plus tôt), deux fois de suite.
La capture d'écran, elle, montrait la bonne chose. Sur cet écran Flutter,
l'arbre sémantique ne reflétait pas la position de défilement réelle.

**Conséquence pratique** : pour toute action destructrice sur appareil,
ne jamais se fier au dump seul. Ouvrir le menu, **capturer l'écran, vérifier
visuellement la cible sélectionnée**, et seulement ensuite confirmer. C'est ce
contrôle qui a évité de supprimer un message innocent.

**Et quand la vérification est impossible, renoncer.** La feuille d'actions
occupe le bas de l'écran et masque tout ce qui s'y trouve : elle ne laisse voir
la bulle sélectionnée (les autres sont estompées par le voile) que si celle-ci
est assez haute. Pour un message situé en bas — typiquement le dernier de la
conversation — la cible est *derrière* la feuille, et « Supprimer » devient un
tap non vérifiable. Deux messages de test (`test-logs` 19:37, `zone-verif`
20:03) ont été laissés en place pour cette raison : deux chaînes inoffensives
coûtent moins cher qu'une suppression à l'aveugle après trois erreurs de
ciblage.

**1. Les coordonnées de tap se périment.** Une première tentative d'usage a
échoué en silence : la liste s'était réordonnée depuis la capture précédente
(un message reçu remonte sa conversation), et le tap à `540,987` a ouvert un
groupe au lieu du 1:1. La suite est partie à l'aveugle — un `KEYCODE_BACK` de
trop a quitté l'app, un autre tap a **envoyé un lien de partage de groupe** dans
la vraie conversation à 19:57. Toujours re-dumper l'UI et localiser la cible par
son libellé avant chaque tap, jamais réutiliser des coordonnées d'un dump
antérieur.

**2. « Zéro log » ne vaut que si l'app a travaillé.** Cette tentative ratée
donnait pourtant 0 ligne flutter — un résultat juste, obtenu pour de mauvaises
raisons. Elle reste exploitable *a posteriori* (1 754 lignes horodatées 19:57
dans la fenêtre, et l'envoi accidentel a bien eu lieu), mais c'est un coup de
chance. Exiger une preuve d'activité explicite : ici, l'accusé « Envoyé » sur
un message nommé.

---

## ⬜ Plugin Gradle Crashlytics : les piles n'étaient pas déchiffrables (2026-09-09)

**Priorité P3** · importance 4/5 — Les plantages Android arriveraient obfusqués et resteraient indiagnosticables — confort du développeur, sans effet direct sur l'utilisateur. *Bloqué : mode privé du compte de test / nouvelle version publiée.*

Déclaré dans [settings.gradle.kts](android/settings.gradle.kts) et
[app/build.gradle.kts](android/app/build.gradle.kts).

- [ ] **Piles déobfusquées dans la console** : après une remontée réelle,
  vérifier que la trace est lisible (noms de classes Dart/Java, pas `a.b.c`).
  C'est le bénéfice concret du plugin, et il ne se voit que côté console.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Plugin Gradle Crashlytics : les piles n'étaient pas déchiffrables (2026-09-09) »).

---

## ⬜ Configuration distante `app-config` (2026-08-27)

**Priorité P1** · importance 3/5 — Une configuration distante absente ou lente peut retarder chaque démarrage jusqu'à 4 s, ou fournir de mauvaises valeurs à la carte, aux liens profonds et aux salons LiveKit.

L'app va chercher sa configuration publique auprès de l'Edge Function
`app-config` au démarrage, avec le `.env` embarqué en filet.
Fichiers : `supabase/functions/app-config/index.ts`,
`lib/core/services/remote_config_service.dart`, `lib/core/constants/app_config.dart`.

- [ ] **Nominal** : fonction déployée, l'app démarre et la carte / les liens
      profonds / LiveKit fonctionnent (valeurs venues du serveur)
- [ ] **Hors ligne au tout premier lancement** : aucun cache, aucun réseau →
      l'app doit démarrer sur le `.env` sans ralentissement visible
- [ ] **Fonction non déployée** (404) : même exigence, démarrage normal
- [ ] **Bascule à chaud** : changer `LIVEKIT_SERVER_URL` par
      `supabase secrets set`, redémarrer l'app, la nouvelle valeur doit
      s'appliquer **sans réinstaller l'APK** — c'est tout l'intérêt
- [ ] Vérifier que le délai de 4 s ne retarde jamais le premier écran

⚠️ `SUPABASE_URL` et `SUPABASE_ANON_KEY` restent volontairement dans le `.env` :
ils ouvrent la connexion qui sert à joindre `app-config`.

---

## Cartographie des accès `anon` réellement nécessaires (2026-08-13)

**Priorité P3** · importance 2/5 — Un avertissement et une petite fuite mémoire, sans plantage ni effet visible.
    - **Trouvaille incidente, hors périmètre — CORRIGÉE le 2026-09-01** :
      `setState() called after dispose()` dans `_startGroupConversation`
      (`group_detail_screen.dart:640`), capturé par Crashlytics. Pas un
      crash, mais une fuite mémoire potentielle. Un `if (!mounted) return;`
      est posé après l'`await` de `createGroup()`. Le correctif existait
      depuis le 2026-08-13 sur la branche `claude/reverent-payne-8d5b4d`,
      jamais rapatriée — repris tel quel.
      - [ ] **À vérifier sur appareil** : ouvrir la fiche d'un groupe, taper
        « Ouvrir la discussion » et revenir en arrière aussitôt (ou couper
        le réseau pour faire traîner l'appel). Plus aucun `setState() called
        after dispose()` dans Crashlytics ni dans logcat.

---

## Bruit dans logcat — deux traces à ne pas re-diagnostiquer (2026-08-05)

**Priorité P0** · importance 2/5 — Soit les règles durcies empêchent tout appel de sonner sans la moindre erreur, soit la production reste permissive et n'importe quel compte connecté peut lire ou remplacer la clé E2EE d'un appel ; s'y ajoute une suppression de compte qui peut laisser des données derrière elle. *Bloqué : deux comptes.*

### 🔴 Supprimer un compte laisse un ami fantôme chez tous ses amis

- [ ] 🔴 **Le nettoyage était encore tout-ou-rien après le correctif — corrigé
  le 2026-08-06, NON déployé.** Le commit `8d769d3` a isolé le journal d'audit,
  mais les **17 étapes** du bloc Firestore restaient dans un `try` **unique** :
  la première qui levait (index composite manquant, document malformé, valeur
  inattendue) sautait droit au `catch` final et **toutes les suivantes étaient
  ignorées en silence**. Casser sur les demandes d'ami (1.3) laissait derrière
  elle notifications, conversations, groupes, produits, transactions,
  signalements. Les sections 2 (RTDB) et 3 (Storage) avaient déjà leur filet ;
  `results.firestore.errors` était déclaré et journalisé mais **jamais
  alimenté** — impossible de savoir où le nettoyage s'était arrêté.
  Chaque étape est désormais enveloppée par un helper `etape(nom, travail)` qui
  journalise et pousse dans `results.firestore.errors`, puis continue.
  **À faire** : redéployer `cleanupUserData` **seul** (cf. l'entrée ci-dessus
  sur les orphelines, et ne jamais `--force`), puis rejouer le scénario à deux
  comptes jetables en forçant l'échec d'une étape intermédiaire — vérifier que
  les étapes suivantes s'exécutent quand même et que l'étape fautive apparaît
  nommée dans les journaux.

### 🔴 La signalisation des appels de groupe était refusée EN PRODUCTION

- [ ] 🔴 **À VÉRIFIER EN PRIORITÉ, ET C'EST LA SEULE CHOSE QUI MANQUE** : un
  appel 1:1 et un appel de groupe, à deux comptes. Le banc prouve que les
  règles laissent passer le parcours réel ; il ne prouve pas qu'un appel
  aboutit (FCM, CallKit, coturn, WebRTC).
- [ ] **`e2ee_key` des appels de groupe est écrite mais JAMAIS LUE.** Une seule
  occurrence dans tout `lib/` (`group_call_service.dart`, `_shareE2EEKey`), et
  c'est l'écriture. Personne ne récupère la clé en rejoignant. Le chiffrement
  de bout en bout des appels de groupe n'est donc pas câblé — la clé est
  publiée dans le vide. Même motif que les champs d'état jamais alimentés déjà
- [ ] Le repliage de `handleNewMessagePush` dans `onMessageCreated` avait perdu
  le **contrôle de participation** (`callerUid`) : sans lui, le callable
  laisserait pousser une notification vers une conversation dont on ne fait pas
  partie. Réinjecté depuis le stash, mais **jamais exercé** — à tester si le
  callable redevient utilisé.

### `FAILED_PRECONDITION` — index manquant sur les événements

- [ ] ⚠ **Le fichier `firestore.indexes.json` est en retard sur la production
  — 47 entrées contre 71 déployées.** Même dérive que celle trouvée sur les
  règles. L'index a donc été créé **par l'API Firestore, pas par
  `firebase deploy --only firestore:indexes`** : déployer le fichier
  proposerait de supprimer 24 index en service. À resynchroniser depuis la
  prod avant tout déploiement d'index, comme on l'a fait pour les règles.
- [ ] Le **rendu de la liste** dans l'écran Événements reste à voir au doigt :
  j'ai prouvé que la requête aboutit et que la donnée remonte, pas que l'onglet
  l'affiche.

- ✔ 18 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Bruit dans logcat — deux traces à ne pas re-diagnostiquer (2026-08-05) »).

---

## Storage — énumération des médias coupée (2026-08-04, DÉPLOYÉ)

**Priorité P1** · importance 4/5 — Si un chemin de l'app liste encore les objets Storage, la galerie « Médias » d'une conversation est vide ou en erreur ; si la lecture elle-même était touchée, plus aucune image de message ne s'afficherait.

`storage.rules` : `match /messages/{conversationId}/{allPaths=**}` passait
`allow read: if isAuthenticated()`. Or `read` couvre `get` ET `list` — connaître
un `conversationId` suffisait donc à énumérer puis télécharger tout le média de
la conversation, y compris pour un membre exclu d'un groupe. Séparé en
`allow get` / `allow list: if false`, **déployé sur `diaspo-niger`**.

- [ ] Vérifier la galerie « Médias » d'une conversation (si elle liste des
      objets Storage plutôt que des lignes de base, elle casserait).

---

## Fuseau horaire — heures affichées en UTC (2026-08-04)

**Priorité P2** · importance 3/5 — Hors ligne, le fil reste sur des squelettes sans fin au lieu d'afficher le cache, et des heures ou des jours peuvent rester décalés dans les écrans non vérifiés.

Corrigé en normalisant **à la désérialisation** (tout `DateTime` sortant d'un
modèle est local, cf. `lib/core/utils/date_parsing.dart`) et en réencodant
en UTC explicite à la sérialisation. 21 tests unitaires couvrent la
régression, mais rien de tout cela ne prouve le rendu réel : à vérifier sur
appareil, **hors du fuseau UTC**.

- [ ] Commentaires, notifications, événements (début/fin), appels (journal),
      stories : mêmes vérifications — pas de données sur le compte de test.

⚠️ **Bug distinct trouvé au passage — le repli hors-ligne ne fonctionne pas.**
Rien à voir avec le fuseau. En mode avion réel (vérifié : `airplane_mode=1`,
`wlan0` coupée) :

- le démarrage à froid reste **~2 min sur le splash** avant d'atteindre
  l'accueil ;
- l'écran « Le fil » affiche des **squelettes de chargement indéfiniment**
  au lieu des publications en cache, alors que le cache est bien présent et
  valide ;
- l'app finit par revenir au splash (redémarrage).

Le repli annoncé (maquette 2a : « si une page est en cache, on l'affiche
plutôt qu'un fil vide ») ne se déclenchait donc pas.

**Corrigé le 2026-08-04, couvert par 6 tests unitaires.** Cause commune aux
deux symptômes : des attentes réseau **sans borne**. Un socket qui *pend* au
lieu d'échouer ne rend jamais la main, donc le chemin de repli n'était jamais
atteint.

- Fil (`feed_provider`) : cache affiché **avant** d'interroger le réseau, plus
  10 s de borne sur la page (`loadInitial`/`loadMore`) et 5 s sur les
  enrichissements — cf. `test/features/feed/feed_offline_fallback_test.dart`.
- Démarrage (`auth_provider`) : 8 s de borne sur `getCurrentUser()`, puis
  démarrage sur la session Firebase locale plutôt qu'un renvoi vers
  `/auth/login` (se reconnecter exige le réseau, précisément ce qui manque)
  — cf. `test/features/auth/auth_offline_start_test.dart`.

- [ ] mode avion + démarrage à froid : l'accueil s'affiche en quelques
      secondes, plus en ~2 min
- [ ] mode avion + « Le fil » : les publications en cache s'affichent, avec le
      bandeau « contenu hors ligne », au lieu des squelettes
- [ ] retour du réseau : le contenu frais remplace le cache sans action
- [ ] réseau lent mais fonctionnel : vérifier que les bornes (8 s / 10 s) ne
      dégradent pas un chargement légitime

- ✔ 6 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Fuseau horaire — heures affichées en UTC (2026-08-04) »).

---

## Admin (back-office)

**Priorité P2** · importance 3/5 — Si la garde ne tient pas, un compte ordinaire peut entrer invisible dans un salon audio ; le reste touche des outils réservés aux administrateurs.

- [ ] **Migration des 18 écrans admin + `admin_app` vers `AdminColors`** — jamais vérifiée à l'écran ; en particulier la couleur bleu d'action (jamais orange) jamais confirmée visuellement.
- [ ] **Modérateur fantôme — Muet / Exclure / Bloquer** (`ghost_moderator_screen.dart`, ajouté 2026-08-03) : les trois boutons ouvrent une feuille de sélection de participant puis appliquent l'action. Trois choses ne peuvent être vérifiées que sur un salon réel avec deux comptes : que la feuille liste bien les participants visibles (les fantômes doivent en être exclus), que l'action passe réellement les règles RTDB (nécessite `/admins/<uid>: true` dans la Realtime Database — sinon échec silencieux côté règles), et que le SnackBar d'erreur remonte quand ça échoue.
- [ ] **Ouverture et fermeture de la session fantôme** (`ghost_moderator_screen.dart`, 2026-08-03) : l'écran appelle maintenant `joinAsGhostModerator()` à l'ouverture — auparavant il ne rejoignait jamais le salon, donc `isGhostMode` restait faux, les compteurs affichaient 0 et les trois actions ne trouvaient aucune cible. À vérifier sur un salon réel avec deux comptes : que les compteurs se remplissent, que l'admin **n'apparaît pas** dans la liste des participants côté hôte, que la durée s'incrémente (rafraîchie toutes les 30 s), et surtout qu'en quittant l'écran l'admin est bien retiré du salon (`leaveRoom` n'est appelé que si c'est cet écran qui a ouvert la session — un admin déjà présent dans le salon ne doit pas en être éjecté).
- [ ] **Point d'entrée de la vue fantôme** (`audio_rooms_list_screen.dart`, 2026-08-03) : icône œil barré sur chaque carte de salon, visible **uniquement** pour un compte admin. Vérifier qu'elle est absente pour un compte normal, et que le tap dessus n'ouvre pas le salon en même temps (elle est imbriquée dans le `GestureDetector` de la carte).
- [ ] **États d'échec de la vue fantôme** (`ghost_moderator_screen.dart`, 2026-08-03) : salon inexistant ou compte non autorisé doivent afficher l'écran d'erreur avec le motif, plus l'écran vide à zéro d'avant.
- [ ] **Garde d'accès à la vue fantôme** (`app_router.dart`, ajouté 2026-08-03) : ouvrir `/audio-rooms/<id>/ghost` avec un compte **non** admin doit rediriger vers le salon. Jamais testé avec deux comptes de rôles différents.
- [ ] **Promotion d'un admin propagée aux 3 backends** (`role_management_provider.dart`, ajouté 2026-08-03) : promouvoir un utilisateur depuis l'écran de gestion des rôles doit écrire Firestore **et** `users.is_admin`/`admin_role` dans Postgres **et** `/admins/<uid>` en RTDB. Nécessite la migration `20260803120000_admin_can_manage_admin_flags.sql` poussée, et l'amorçage manuel du premier admin en SQL. Le message d'erreur de désynchronisation n'a jamais été vu à l'écran.

---

# 14. Publication et plateformes

Play Store, exigences Android, build release, iOS.

---

## ⬜ Bloqueurs de publication — Play & iOS (état 2026-09-21)

**Priorité P0** · importance 5/5 — Empêchent la mise en production. Plusieurs corrigés ce jour ; le reste exige un appareil, un Mac, ou une valeur/décision du propriétaire.

### Résolu par décision produit
- **✅ Cohérence « position approximative » — sens ARRONDI choisi (2026-09-21).**
  L'app publiait une position précise (coordonnées brutes vers
  `users.latitude/longitude`, que la carte montre aux autres) tout en
  promettant « approximative, jamais l'adresse exacte ». Sur décision du
  propriétaire (après un premier choix « texte » revenu sur), la POSITION est
  arrondie à ~100 m (3 décimales) au point d'écriture unique
  (`updateLocation`, `arrondirPositionPartagee` dans
  `lib/core/utils/position_partagee.dart`) : la carte montre un quartier, jamais
  le bâtiment. Les deux publieurs y passent ; le service d'arrière-plan repasse
  de `.high` à `.medium` (batterie). Le texte « approximative, jamais l'adresse
  exacte » est RESTAURÉ — il est vrai désormais. Test
  `test/core/position_partagee_test.dart`, analyse propre.
  - [ ] ⚠️ **Action Play du propriétaire** : le formulaire Data Safety peut
    (et doit) déclarer la localisation **approximative** — c'est le sens le plus
    simple au réexamen, et il correspond maintenant au comportement réel.
  - [ ] Vérifier sur la carte que les positions des autres restent utiles au
    grain ~100 m (membres « à moins de 5 km » toujours pertinents) ; ta propre
    position (centrage) vient de l'appareil, pas de la valeur arrondie.

### ⬜ Exige une valeur ou une décision du propriétaire
- **✅ Consentement UMP (RGPD) CÂBLÉ le 2026-09-21** (commit `29d37b2`) :
  `tracking_consent_service.dart` recueille l'UMP (`requestConsentInfoUpdate` +
  `loadAndShowConsentFormIfRequired`) avant l'ATT, et n'initialise AdMob que si
  `canRequestAds` ; `NativeAdWidget` n'appelle plus AdMob sans consentement.
  **Reste côté propriétaire** : publier le message GDPR dans la console AdMob
  (Confidentialité et messages).
  - [ ] **Affichage réel du formulaire (EEE)** : forcer
    `ConsentDebugSettings(debugGeography: eea, testIdentifiers: […])`, l'app doit
    montrer le formulaire ; hors EEE, pas de formulaire et les pubs se chargent.
    Non couvert par cette passe (exige le message GDPR publié + une pub réelle).
- **⬜ Clé Google Maps non restreinte — recette console prête (empreintes
  fournies le 2026-09-21).** La clé du manifeste
  (`com.google.android.geo.API_KEY`, `AIzaSyCnbdymYwzJXPA2YY1PMexCU_iGaN5tPek`,
  « No App Restrictions ») est **la MÊME** que celle servie par `app-config`
  (`GOOGLE_MAPS_API_KEY`, usages REST Dart). La restreindre « aux apps
  Android » **casserait** le REST → **deux clés** :

  **(a) Clé Maps du manifeste — restreinte Android.** Google Cloud Console →
  cette clé (ou une nouvelle) → Application restrictions = « Android apps » →
  ajouter le package `com.diasponiger.diasponiger` avec **les DEUX** SHA-1 :
  - **Signature Play** (production, APK installés du Store) :
    `5B:2F:DA:41:0A:46:14:95:CA:C0:54:27:9C:95:BD:0F:3E:BA:1C:DC`
    (⚠️ à **confirmer** dans Play Console → Test et publication → Intégrité de
    l'app / Signature de l'app ; déduit ici du 2ᵉ hash de `google-services.json`
    et du 1ᵉʳ SHA-256 d'`assetlinks.json` `91:71:E2:D7:…`).
  - **Upload / test release local** (ton keystore `diaspo-niger-release.jks`,
    alias `diaspo-niger`) : `6C:D4:4A:2D:13:60:56:E7:FE:E0:79:D2:85:C0:89:35:C3:DE:10:D1`
    (SHA-256 `DD:A6:5C:3E:…:CF:5D`, celui qui matche `assetlinks.json`).
    API restrictions = « Maps SDK for Android » (+ éventuellement Maps SDK
    associés). Mettre la valeur de cette clé dans le manifeste.

  **(b) Clé REST séparée** (pour `app-config` `GOOGLE_MAPS_API_KEY`) : restreinte
  par **API** (Geocoding / Places / …) et/ou IP si appelée côté serveur — **PAS**
  « Android apps ». Ne jamais fusionner (a) et (b).

  Les empreintes ci-dessus sont publiques (déjà dans `assetlinks.json` et
  `google-services.json`) ; extraites via
  `keytool -list -v -keystore diaspo-niger-release.jks -alias diaspo-niger`.

### ⬜ iOS — non traitable en aveugle sous Windows (Mac/Xcode requis)
- **Entitlements non référencés** : `ios/Runner/Runner.entitlements` existe mais
  `CODE_SIGN_ENTITLEMENTS` est **absent du pbxproj** (0 occurrence) — l'app se
  build sans ses entitlements (push, associated domains). À ajouter dans les
  deux configs Xcode.
- **`PrivacyInfo.xcprivacy` absent** : Apple l'exige désormais. À créer avec
  les déclarations d'usage de données (décision légale/produit).
- **`UIBackgroundModes`** présent dans `Info.plist` : à justifier ou retirer.
- **Rust jamais compilé pour iOS** : le crate `rust/` (MLS) n'a pas de cible
  iOS produite — à faire sur un Mac avant toute soumission.

### ⬜ À vérifier
- **✅ App Links scopés le 2026-09-21.** Le filtre `autoVerify` réclamait TOUT le
  domaine (les deux hôtes servent `assetlinks.json`, `autoVerify` réussit) sans
  `pathPrefix` : l'app, qui n'a de route pour AUCUNE page web, captait et
  cassait `/delete-account`, `/privacy-policy`, `/terms-of-service`,
  `/forgot-password`, etc. — dont la page de suppression de compte tout juste
  réparée. Restreint aux 12 chemins de contenu (mêmes que les rewrites SPA de
  `firebase.json`) : `/audio-rooms`, `/businesses`, `/calls`, `/embassies`,
  `/events`, `/feed`, `/g/`, `/groups`, `/marketplace`, `/p/`, `/podcasts`,
  `/profile`. (`/p/` et `/g/` avec barre finale : `/p` seul aurait capté
  `/privacy-policy`.) XML validé.
  - [ ] **Auto-vérification** (nécessite un build **signé release** — le
    certificat debug n'est pas dans `assetlinks.json`, donc `verified` est
    impossible à obtenir sur l'APK debug) : `adb shell pm verify-app-links
    --re-verify com.diasponiger.diasponiger` puis `adb shell pm get-app-links
    com.diasponiger.diasponiger` = « verified » ; taper un lien
    `https://diasponiger.com/groups/<id>` ouvre l'app, `…/delete-account` ouvre
    le NAVIGATEUR.
- **Version** (mesuré 2026-09-21) : `pubspec.yaml` = `1.2.1+23`, mais
  `app-config` annonce `DERNIERE_VERSION_APP = 1.2.1+19` — la version en cours
  est donc **en avance** sur celle annoncée comme la plus récente. Sans effet
  gênant aujourd'hui (l'app ne se propose pas une mise à jour vers une version
  plus ancienne), mais **à la publication d'un build il faut poser
  `DERNIERE_VERSION_APP` à sa vraie version** (`supabase secrets set …`) ; et
  c'est le préalable au verrou 1.1b (`VERSION_MINIMALE_APP` doit être ≤
  `DERNIERE_VERSION_APP` pour bloquer).

---

## ⬜ Le serveur ne supprime plus un chemin Storage dicté par le client (2026-09-21)

**Priorité P0** · importance 5/5 — N'importe quel compte connecté pouvait faire effacer par le serveur **n'importe quel objet du bucket**, y compris la sauvegarde d'identité Signal d'autrui. Reste à voir qu'une suppression légitime fonctionne encore.

Cinq sites dérivaient ainsi un chemin d'une URL lue en base :
`deleteMessageForEveryone` (2), `deleteGroup`, `cleanupExpiredMessages` et
`cleanupExpiredMediaFiles` — les deux dernières étant **planifiées**, donc
déclenchables sans appel. Tous passent maintenant par `cheminStorageSur`,
qui refuse ce qui sort des préfixes attendus.

**Corrigé, pas supprimé.** Aucune de ces fonctions n'est appelée par `lib/`
aujourd'hui — ce sont des restes de l'ère Firebase. Les effacer serait plus
net, mais des APK déjà installés peuvent encore les appeler : même prudence
que pour `sendMessagePush`. À revoir quand l'adoption des versions sera
connue.

- [ ] **Supprimer pour tous un message AVEC média** (photo, vidéo, note
  vocale) et vérifier que le fichier disparaît vraiment. C'est le test qui
  compte : si un préfixe est faux, la suppression ne se fait plus et
  l'échec est **avalé** (`console.warn`, puis on continue).
- [ ] **Supprimer un groupe** qui a une image : l'image disparaît.
- [ ] **Message éphémère avec média** : à l'expiration, le fichier part.
- [ ] **Surveiller le journal** : une ligne « chemin Storage REFUSÉ » sur un
  parcours normal signale un préfixe mal choisi ; sur un parcours anormal,
  une tentative.

## ⬜ Storage : on dépose, on ne réécrit plus (2026-09-21)

**Priorité P1** · importance 4/5 — Sept chemins Storage n'avaient aucun propriétaire, et `write` couvrait la réécriture : l'URL d'un média livrant son chemin, tout compte connecté pouvait remplacer la photo d'un commerce, l'image d'une publication ou le média d'une conversation. Reste à voir qu'un envoi réel passe toujours.

`storage.rules` — **DÉPLOYÉ le 2026-09-21** (`firebase deploy --only
storage`, ruleset `22df22d8`). Relu par l'API `firebaserules` juste après :
la production est identique au dépôt, hors commentaires. Trois changements :

- `messages`, `groups`, `events`, `products`, `businesses`, `posts`,
  `stories` exigent désormais un chemin LIBRE (`resource == null`). Aucun
  envoi de l'app ne réécrit : tous les noms portent un horodatage à la
  milliseconde.
- `isImage()` passe de `image/.*` à une liste fermée — `image/svg+xml`
  n'est plus accepté (un SVG est un document exécutable, servi depuis un
  domaine Google avec le type qu'on lui a donné).
- `read` séparé en `get` + `list: if false` sur les six chemins qui
  l'ouvraient : connaître un identifiant ne suffit plus à ÉNUMÉRER le
  dossier.

- [ ] **Envoyer une photo dans une discussion**, une image de publication,
  une story, une photo de groupe et une photo de profil : chacune part et
  s'affiche. C'est le test qui compte — si un chemin de l'app réécrivait
  sans que je l'aie vu, l'envoi échouerait en `unauthorized`, et l'app avale
  déjà certains de ces échecs.
- [ ] **Deux envois dans la même milliseconde** (rafale de photos) : le
  second ne doit pas échouer. L'horodatage est la seule garantie d'unicité.
- [ ] **Relire un ancien média** d'une conversation et d'une publication :
  la lecture par chemin exact n'a pas bougé.

## ⬜ Le `.env` embarqué ne livre plus de chemin de poste (2026-09-21)

**Priorité P2** · importance 3/5 — Le `.env` est un asset Flutter : il part en clair dans chaque APK. Il y livrait un chemin Windows absolu (nom d'utilisateur, arborescence, nom du fichier de clé admin) et le récit d'une fuite passée. Reste à voir qu'un build réel démarre toujours.

Deux retraits, sans toucher à aucune valeur :

- `GOOGLE_APPLICATION_CREDENTIALS` — son seul lecteur,
  `scripts/creer_compte_test.js`, retrouve la clé tout seul en balayant la
  racine (`*-adminsdk-*.json`) ; son branchement `.env` a été supprimé.
- le récit d'incident sur l'ancienne `service_role`, remplacé par une ligne
  neutre.

- [ ] **Construire un APK et l'ouvrir** : `unzip -p <apk> assets/flutter_assets/.env`
  ne doit contenir ni `GOOGLE_APPLICATION_CREDENTIALS`, ni `C:\`, ni le récit
  d'incident.
- [ ] **Démarrage de l'app** sur ce build : Supabase, la carte et les liens
  profonds fonctionnent (les cinq variables réellement lues sont intactes,
  mais rien ne l'a vérifié sur un téléphone).

## ⬜ Notice « une nouvelle version est disponible » (2026-09-14)

**Priorité P1** · importance 3/5 — Le bandeau de mise à jour partage désormais
son canal avec le rappel de sauvegarde des clés E2EE : une erreur d'arbitrage
ferait taire le second, et des messages deviendraient illisibles au changement
d'appareil.

Bandeau non bloquant en tête d'application quand une version plus récente
existe sur le store. La version disponible vient du serveur — clé
`DERNIERE_VERSION_APP` de l'Edge Function `app-config`, au format de la ligne
`version:` de `pubspec.yaml` (`1.3.0+20`) — parce qu'un APK ne peut pas savoir
qu'il en existe un plus récent que lui.
Décision et silences tenus par `test/core/services/mise_a_jour_service_test.dart`
(22 cas).

- [ ] **« Mettre à jour » ouvre la bonne fiche** : Play Store sur
      `com.diasponiger.diasponiger`, et non une page « application
      introuvable » (les deux liens du projet ont déjà été faux).
- [ ] **Revenir du store sans installer** : le bandeau doit pouvoir
      reparaître au démarrage suivant — contrairement à « Pas maintenant »,
      partir vers le store n'écarte pas la version.
- [ ] **Le rappel E2EE passe devant** ([main_shell.dart](lib/core/shell/main_shell.dart)) :
      avec un compte dont les clés ne sont pas sauvegardées ET la clé serveur
      posée, c'est le bandeau des clés qui doit s'afficher ; une fois traité,
      celui de la mise à jour doit prendre sa place **sans relancer l'app**.

      Ce qui reste à l'appareil : que l'enchaînement se produise **vraiment**,
      avec de vrais coordinateurs et un vrai `ScaffoldMessenger`.
- [ ] **Rendu du bandeau** : le **débordement** n'est plus une question ouverte
      — `test/core/shell/bandeaux_shell_test.dart` rend les deux bandeaux du
      shell (mise à jour **et** E2EE, qui porte trois actions) sur 411, 360 et
      320 dp de large, aux échelles de police 1,0 / 1,3 / 1,6 / 2,0, en clair
      et en sombre : 51 cas, aucun débordement. Reste à juger **à l'œil** ce
      qu'un banc ne voit pas : contraste et couleurs du bandeau en thème
      sombre sur un vrai écran.
- [ ] **Hors ligne au démarrage** : aucune notice, aucun blocage du premier
      écran (`RemoteConfigService` sert alors son cache, ou rien).

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Notice « une nouvelle version est disponible » (2026-09-14) »).

---

## ⬜ Divulgation préalable de la localisation (refus Play du 2026-09-09)

**Priorité P0** · importance 5/5 — Un sixième refus Google Play, l'app restant bloquée hors du Store.

Ce qui a été posé (`lib/core/widgets/location_disclosure.dart`) :

- `LocationDisclosureNotice`, bloc de texte **sur l'écran d'onboarding**, sous
  les deux interrupteurs ;
- `afficherDivulgationLocalisation(context)`, feuille modale avec
  « Accepter et continuer » / « Non, merci », affichée **avant** la boîte
  système ;
- `demanderLocalisationAvecDivulgation(context)`, la porte d'entrée unique :
  elle ne montre la feuille que si le système va réellement poser la question.

Câblée sur les quatre chemins qui déclenchent la demande : onboarding 5/5,
Accueil (`_loadData`), Carte (`_getCurrentLocation`), et le Mode Voyage du
profil — celui-ci avec la variante « même lorsque l'application est fermée ou
n'est pas utilisée », exigée parce que son service publie une position toutes
les 5 minutes hors premier plan.

**Cinquième chemin depuis le 2026-09-13** : « Utiliser ma position » dans le
champ ville du profil
([ville_search_field.dart](lib/shared/widgets/ville_search_field.dart)), avec
une variante de texte à lui, `UsageLocalisation.champVille`. C'est le seul
usage qui ne publie rien — la position est lue une fois, sur l'appareil, pour
proposer une ville de la liste ; seul le NOM de la ville part dans le profil.
Le texte le dit et ne promet pas la carte des membres, qui ne la reçoit pas.
Précision demandée : `LocationAccuracy.low`, une ville se trouvant au
kilomètre près.

- [ ] **Déclaration Play à revoir avant le prochain envoi** : la fiche
  « Sécurité des données » décrit les usages de la position déclarés jusqu'ici.
  Ce cinquième usage ne collecte ni ne partage rien de plus — mais c'est à
  vérifier sur la fiche, pas à supposer, après cinq refus.

- [ ] **Appui sur « Commencer » avec Localisation activée** : la feuille
      s'ouvre-t-elle **avant** la boîte système Android ? « Non, merci » doit
      n'ouvrir aucune boîte et laisser entrer dans l'application.
- [x] **Thème sombre** sur la feuille et sur le bloc de l'onboarding (jetons
      adaptatifs, jamais `AppColors` en dur).
      **Le bloc d'onboarding dans ce thème reste à voir** : il demande
      l'échappatoire routeur, jamais committée.
- [ ] **Position dans une discussion** : ouvrir le sélecteur de position
      depuis une conversation. La feuille doit porter le texte *discussion*
      (« participants de la discussion »), jamais celui de la carte. Un refus
      à l'ouverture doit laisser le bouton « envoyer ma position » reproposer
      la feuille.
  Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : permission de localisation déjà accordée sur le SM A515F → le sélecteur s'ouvre directement sur la carte, sans feuille ; la feuille ne se voit qu'avec la permission retirée (réglage système, pas fait par adb).
- [ ] **Lien « Lire la politique de confidentialité »** depuis la feuille
      pendant l'onboarding : `/settings/privacy` est censé échapper aux
      redirections du routeur, à confirmer avant que le profil soit complet.

⚠️ Interrupteur **Podcasts** du back-office désormais inerte, et c'est
voulu : `FOREGROUND_SERVICE_MEDIA_PLAYBACK` a été retirée du manifeste alors
que `AudioService` déclare toujours `foregroundServiceType="mediaPlayback"`.
L'allumer rouvrait `/podcasts` sur un build où la lecture lève une
`SecurityException` au premier `startForeground` (Android 14+). Il redevient
actif tout seul quand `kPodcastsSupportesParCeBuild` repasse à `true`, ce que
`test/core/podcasts_service_premier_plan_test.dart` interdit de faire sans
rétablir l'autorisation.

- [ ] **Admin › Fonctionnalités** : vérifier que la ligne Podcasts s'affiche
      bien grisée, avec son explication, et que /podcasts reste inaccessible.
      ⚠️ **2026-09-11 : écran introuvable depuis l'app.** Sur le Pixel, compte
      **administrateur** : aucune entrée d'administration dans le Profil ni
      dans Réglages, et le lien profond `diasponiger:///admin` rend
      « Page Not Found — no routes for location: /admin ». Le routeur ne
      connaît que `/admin/embassies`, `/admin/embassies/create` et
      `/admin/support` ; les écrans Fonctionnalités / tableau de bord vivent
      dans une coquille séparée (`lib/features/admin/presentation/admin_app.dart`,
      routes `/dashboard`…) qui n'est branchée nulle part. À trancher : soit
      la brancher, soit retirer ces écrans de la liste des tests.

- ✔ 9 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Divulgation préalable de la localisation (refus Play du 2026-09-09) »).

---

## ⛔ « Diaspo Niger s'arrête systématiquement » sur Android 15+ (2026-09-09)

**Priorité P1** · importance 4/5 — Sur Android 15+, « Diaspo Niger s'arrête systématiquement » après chaque redémarrage du téléphone — risque résiduel, le récepteur étant déjà prouvé désenregistré.

Corrigé des deux côtés : `autoStartOnBoot: false`
(`lib/core/services/background_location_service.dart`) pour dire l'intention,
**et** `tools:node="remove"` sur le receiver dans
`android/app/src/main/AndroidManifest.xml` — parce que le drapeau n'est lu
qu'après le premier lancement de l'app, ce qui laisse sans lui une fenêtre
ouverte juste après une mise à jour.

Restent à faire, l'un et l'autre à la main :

- [ ] ⚠️ **Redémarrage réel du téléphone** — le seul chemin qui rejoue
      vraiment BOOT_COMPLETED (`am broadcast … BOOT_COMPLETED` est refusé au
      shell : « Permission Denial »).
- [ ] Le partage de position continu **démarre toujours** quand on l'active
      dans l'app (c'est la seule chose que le receiver retiré aurait pu
      fournir, et il ne la fournissait qu'au boot).

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⛔ « Diaspo Niger s'arrête systématiquement » sur Android 15+ (2026-09-09) »).

---

## ⚠️ Rapatriement iOS : deux dépendances **Android** changent de version majeure (2026-09-08)

**Priorité P1** · importance 4/5 — Le scan de QR, dont le transfert de clés E2EE vers un nouveau téléphone, ne décode plus rien après la montée de version majeure.

| Paquet | Avant | Après | Ce qu'il porte |
|---|---|---|---|
| `mobile_scanner` | `^5.2.3` | `^7.4.0` | tout le scan de QR |
| `purchases_flutter` | `^8.7.0` | `^10.10.1` | abonnements RevenueCat |

`flutter analyze lib/` est propre et les 445 tests passent, mais **aucune des
deux n'a tourné sur un appareil depuis la montée**. Le scan de QR, lui, a été
vérifié sur SM A515F le 2026-09-08 — mais **avant** ce changement : cette
vérification ne vaut plus.

- [ ] **Scanner de QR sur SM A515F** — ouvrir `/qr-scanner`, scanner un code de
      transfert de clés **et** un QR de profil. `mobile_scanner` 7 a changé la
      signature de `errorBuilder` (adaptée dans
      `lib/features/profile/presentation/screens/qr_scanner_screen.dart`) ; le
      reste de son API caméra n'a pas été rejoué sur appareil.
- [ ] **Permission caméra au premier lancement** après la montée, et la
      lampe torche : c'est là qu'un changement de plugin caméra se voit.
- [ ] **Achat RevenueCat** — `purchasePackage` est déprécié en 10.x, remplacé
      par `purchase(PurchaseParams.package(...))` qui renvoie un
      `PurchaseResult` (`lib/core/services/revenue_cat_service.dart`).
      Intestable en pratique tant que le contrat « applications payantes »
      n'est pas signé — à ne pas oublier le jour où il le sera.

- [ ] **Le `force("com.google.mlkit:barcode-scanning:17.3.0")`** porte la note
      « à retirer quand mobile_scanner sera monté en 6.x/7.x » — c'est fait.
      À réévaluer, sans jamais sauter la vérification ci-dessus.

- ✔ 3 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⚠️ Rapatriement iOS : deux dépendances **Android** changent de version majeure (2026-09-08) »).

---

## ⬜ Deux bibliothèques natives réalignées sur 16 Ko (2026-09-08)

**Priorité P1** · importance 3/5 — Écran caméra noir ou QR jamais reconnu, voire plantage natif à l'ouverture d'un appel de groupe, sans aucune erreur Dart.

Les deux venaient de dépendances transitives de plugins, remplacées dans
`android/build.gradle.kts` :

- `libbarhopper_v3.so` — `com.google.mlkit:barcode-scanning:17.2.0`, épinglé
  par `mobile_scanner 5.2.3`. Forcé en **17.3.0**, alignée 16 Ko, même API,
  minSdk 21 contre 24 pour l'app.
- `libnoise.so` — `com.github.paramsen:noise:2.0.0` (JitPack, abandonné),
  tiré par `livekit_client 2.4.1`. Substitué par **`io.livekit:noise:2.0.0`**
  sur Maven Central : LiveKit a republié le *même* artefact recompilé en
  16 Ko — mêmes classes, même package `com.paramsen.noise`. C'est ce que
  `livekit_client` utilise lui-même depuis sa 2.5.0.

Vérification reproductible : `python tools/verifie_alignement_16k.py
build/app/outputs/bundle/release/app-release.aab`.

**Aucune ligne de Dart n'a changé** — seule la résolution Gradle. Le risque
n'est donc pas dans l'UI mais dans le code natif chargé à l'exécution, que
`flutter analyze` et `flutter test` ne touchent pas :

- [ ] **Appel audio de groupe** puis **appel vidéo** (LiveKit) : connexion,
      son dans les deux sens, caméra. `libnoise.so` n'est chargé que par le
      visualiseur audio natif de LiveKit (`createVisualizer`), que l'app
      n'appelle **nulle part** — le remplacement ne devrait donc rien changer,
      mais c'est une substitution de module au niveau Gradle : elle mérite un
      appel réel avant publication.
- [ ] **Salon audio** et **podcast en direct** : même moteur LiveKit, autres
      écrans d'entrée.

---

## ⬜ Passage à targetSdk 36 (Android 16) — exigence Play (2026-09-08)

**Priorité P0** · importance 3/5 — Sur Android 15+, le champ de saisie, les onglets ou les boutons d'une feuille passent sous la barre de navigation et deviennent inaccessibles. *Bloqué : appareil Android 15+ connecté (Pixel déconnecté).*

Play Console refuse toute mise à jour à partir du **31/10/2026** si l'app ne
cible pas l'API 36. La 1.2.0 publiée cible 35.

Ce que ce passage change au comportement Android — à regarder sur appareil,
`flutter analyze`/`flutter test` n'en voient rien :

- [ ] **Verrou d'orientation ignoré sur grand écran.** À partir de 36, sur un
      écran de largeur ≥ 600 dp, `setRequestedOrientation()` ne fait plus
      rien. Seul appelant côté app :
      `lib/features/messages/presentation/screens/video_player_screen.dart:78`
      (paysage forcé en plein écran). Sur téléphone (SM A515F) le verrou
      tient toujours ; sur tablette / pliable ouvert il sera ignoré. À voir
      si la vidéo reste regardable sans le verrou.
- [ ] **Retour prédictif** : `enableOnBackInvokedCallback="true"` est déjà
      posé au manifeste, donc rien de nouveau à activer — mais l'animation
      système devient le défaut. Revérifier les sorties d'écran par geste de
      retour, notamment les routes de lien profond (cf. la règle
      « couvrir les TROIS sorties »).

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« ⬜ Passage à targetSdk 36 (Android 16) — exigence Play (2026-09-08) »).

---

## ⬜ iOS : signature et conformité export jamais compilées (2026-09-01)

Le compte Apple a été lu en direct : Team ID `3WM7VK48T3`, aucun App ID,
aucune clé APNs, aucun certificat, aucune app dans App Store Connect. État
complet et marche à suivre dans `docs/ops/PUBLICATION_IOS.md`.

Deux modifications ont été faites en aveugle dans le dépôt :

- `ios/Runner.xcodeproj/project.pbxproj` — `DEVELOPMENT_TEAM = 3WM7VK48T3`
  sur les 3 configurations de la cible `Runner`.
- `ios/Runner/Info.plist` — `ITSAppUsesNonExemptEncryption` à `<true/>`.

**Ni l'une ni l'autre n'a été compilée.** Le poste est sous Windows ; un
build iOS exige macOS + Xcode. Le plist est validé par `plistlib` et
l'insertion pbxproj respecte la syntaxe du fichier, mais ça ne prouve pas
que Xcode ouvre le projet ni que l'archive se signe.

À vérifier dès qu'un Mac est disponible :

- ⬜ Xcode ouvre `ios/Runner.xcworkspace` sans erreur de projet corrompu
- ⬜ l'équipe `3WM7VK48T3` apparaît bien dans Signing & Capabilities
- ⬜ `flutter build ipa` produit une archive signée
- ⬜ App Store Connect accepte le téléversement et pose la question export
      attendue (conséquence directe du `<true/>`)

Rappel : rien de tout ça ne peut aboutir tant que l'App ID n'est pas
enregistré chez Apple (étape 3 du document ci-dessus) — la capability Push
notamment conditionne la signature.

---

## iOS : premier build réussi, sur simulateur (2026-09-01)

**Priorité P2** · importance 3/5 — La version iOS partirait avec des fonctions matérielles jamais vues fonctionner (caméra, micro, push, appels), avec un refus App Store probable. *Bloqué : iOS / Mac + iPhone réel + compte Apple Developer.*

**Ce que le simulateur ne peut pas couvrir** — tout ce qui suit reste à faire
sur un iPhone réel, et une partie exige un compte Apple Developer :

- [ ] Caméra réelle : scan QR (`mobile_scanner` 7.x, API changée), photos,
      vidéo WebRTC.
- [ ] Micro réel : messages vocaux, appels.
- [ ] Notifications push reçues (exige clé APNs + compte développeur).
- [ ] Appels CallKit/PushKit (exige compte développeur).
- [ ] Localisation réelle et carte Google Maps.
- [ ] Achats RevenueCat après la montée en version majeure 8 → 10.
- [ ] Deep links / Universal Links (exige Associated Domains signés).

- ✔ 4 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« iOS : premier build réussi, sur simulateur (2026-09-01) »).

---

## ⚠️ Simulateur : lancer DeviceHub AVANT de démarrer l'app (2026-09-01)

**Sans fenêtre de simulateur ouverte, l'app se lance mais Flutter ne dessine
jamais rien** — écran gris uniforme, aucune erreur, aucun plantage, la VM Dart
répond et les journaux montrent l'initialisation complète. On croit à un bug
de l'app ; c'en est un du poste de travail. Une demi-heure perdue à chercher
au mauvais endroit.

Xcode 27 n'a plus de `Simulator.app` : c'est **`DeviceHub.app`** qui porte la
fenêtre, dans `Contents/Applications/` et non plus
`Contents/Developer/Applications/`.

```bash
open /Users/mouba/Downloads/Xcode-beta.app/Contents/Applications/DeviceHub.app
```

---

## « Se connecter avec Apple » ajouté (2026-09-01)

**Priorité P1** · importance 2/5 — Connexion Apple cassée ou compte créé sans nom : rejet App Store assuré, Apple exigeant ce fournisseur dès qu'un tiers (Google) est proposé. *Bloqué : iOS / Mac + compte Apple Developer.*

Apple exige ce fournisseur de toute app en proposant déjà un tiers — Google
ici — et son absence vaut un rejet à la soumission. Le bouton n'apparaît que
sur iOS/macOS : sur Android il ouvrirait un parcours web réclamant une
configuration Service ID distincte, absente aujourd'hui, et échouerait sous
les yeux de l'utilisateur.

- [ ] **Parcours complet à vérifier** — impossible sur simulateur non signé :
      la feuille système Apple exige la capability « Sign In with Apple » sur
      l'App ID, donc un compte développeur. Le bouton s'affiche, mais
      l'autorisation sera refusée.
- [ ] **Le nom n'est donné qu'à la PREMIÈRE autorisation.** Apple ne renvoie
      `givenName`/`familyName` qu'une fois, jamais ensuite, et jamais dans le
      jeton. Le code les capte et appelle `updateDisplayName` dans la foulée —
      **à vérifier sur un compte Apple neuf**, car un second essai avec le même
      compte ne rejouera pas ce cas. Pour le reproduire : *Réglages › Apple ID ›
      Connexion et sécurité › Connexion avec Apple*, puis retirer l'app.
- [ ] **« Masquer mon adresse e-mail »** donne une adresse
      `@privaterelay.appleid.com`. Vérifier que le profil se crée normalement,
      et garder en tête que tout courriel envoyé hors du relais Apple
      n'arrivera pas.
- [ ] Rendu du bouton en thème sombre : le logo Apple est monochrome, il est
      teinté par `AuthButton.tintIcon` avec la couleur du texte. Dessiné en noir
      sans cette teinte, il disparaîtrait sur fond sombre.

---

## Supabase branché sur iOS — deux réserves (2026-09-01)

**Priorité P3** · importance 1/5 — Si les Edge Functions manquaient vraiment, configuration distante et proxy GIF seraient hors service ; sur simulateur, les parcours authentifiés restent intestables.

**1. App Check échoue en 403 « App attestation failed ».** Attendu sur
simulateur : l'app produit bien un jeton de debug, mais il n'est pas déclaré
côté Firebase, donc l'échange est refusé.

```
Firebase App Check Debug Token: E42FC20C-8AE4-4474-BCFC-9A52B36DECEB
```

- [ ] Déclarer ce jeton dans *Firebase Console › App Check › l'app iOS ›
      Gérer les jetons de debug*. **Sans lui, tout parcours authentifié est
      intestable sur simulateur** dès que App Check est en mode contraint.
      Le jeton est propre à cette installation : il change à chaque
      réinstallation complète.

- ✔ 1 case déjà vérifiée : archivée dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Supabase branché sur iOS — deux réserves (2026-09-01) »).

---

## Liens profonds iOS : la moitié testable est bonne (2026-09-01)

**Priorité P2** · importance 2/5 — Sur iPhone, tous les liens partagés s'ouvrent dans Safari au lieu de l'app. *Bloqué : iOS : app signée avec Associated Domains.*

- [ ] **Universal Links intestables sans compte développeur.**
      `https://diasponiger.web.app/auth/register` s'ouvre **dans Safari**, pas
      dans l'app : l'association de domaine exige une app signée portant
      l'entitlement Associated Domains, plus le fichier AASA validé par le CDN
      d'Apple. Rien à corriger côté code — à revérifier après la première
      signature.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Liens profonds iOS : la moitié testable est bonne (2026-09-01) »).

---

# 15. Site web

diasponiger.web.app : pages, palette, menu, aperçus de partage.

---

## ⬜ La page de suppression de compte demande la suppression au lieu de l'exécuter (2026-09-19)

**Priorité P1** · importance 4/5 — la page `/delete-account` (probablement
l'URL déclarée à Play) supprimait Firestore puis le compte Firebase, **jamais
Supabase**, et promettait « toutes vos données effacées » : la personne partait
en croyant tout effacé, ses messages, son profil et son e-mail restaient.
*Bloqué en partie : la page n'est pas publiée — `firebase deploy --only
hosting` envoie TOUT `public/`, c'est une décision de Salim, à part. Le backend
dont elle dépend est en production : migration `20260918224100` relue dans
`schema_migrations` et `finalizeAccountDeletions` (planifiée) relue dans
`firebase functions:list`, le 2026-09-22.*

La page suit maintenant le même chemin que l'application : connexion Firebase
(en mémoire, rien n'est stocké dans le navigateur), puis
`auth-firebase-exchange`, puis `request_account_deletion()`. Le compte est
désactivé tout de suite, la suppression tombe 30 jours plus tard, et se
reconnecter à l'application avant l'annule. Plus de Firestore, plus de
`deleteUser` : la page ne supprime rien elle-même. La logique vit dans
[public/assets/delete-account.js](public/assets/delete-account.js), partagée
par les deux langues. Le côté application et la purge : voir « Supprimer mon
compte : demande, 30 jours, annulation, purge ».

Bancs : `node --test tools/site_tests/suppression_compte_page.test.mjs` (44
cas ; 13 défauts injectés, tous attrapés) et un serveur jetable qui sert les
vraies pages avec un faux Firebase et un faux Supabase (rendu FR/EN vu à 375 px,
succès, trois refus, 404, 401/403, 500, réponse sans date, nouvel essai). **Rien
de tout cela ne touche la production**, et tout y est de même origine :

- [ ] **Bout en bout, sur un compte JETABLE** (jamais le compte réel ni
      `test.diaspo@example.com` : la suppression désactive vraiment le compte).
      Créer un compte dans l'app, ouvrir `/delete-account`, se connecter, taper
      SUPPRIMER, confirmer. Attendu : « Demande enregistrée… supprimé
      définitivement le » + la date du jour **+ 30 jours**. En base :
      `account_deletion_requests` en `pending`, profil masqué. Puis ouvrir
      l'app avec ce compte : l'écran « Suppression du compte programmée »
      propose « Annuler la suppression ».
- [ ] **CORS réel** — le seul point que les deux bancs ne peuvent pas voir.
      Depuis `diasponiger.web.app`, la console réseau ne doit montrer aucune
      préflight refusée, ni sur l'échange (préflight mesurée : 200) ni sur
      `/rest/v1/rpc/request_account_deletion` (**jamais mesurée**).
- [ ] **Rejouer la demande** sur le même compte : la même échéance revient, pas
      un refus, pas une nouvelle date (la RPC est idempotente).
- [ ] **Les refus vus en vrai.** Ils n'ont été vus que contre un faux backend :
      `compte_plateforme`, `obligations_financieres`, `suppression_deja_engagee`
      s'affichent et **restent** affichés (avant, un message disparaissait au
      bout de 5 s), le formulaire disparaît et la session est fermée.
- [ ] **Aucune session gardée** : après une demande, recharger la page → un
      formulaire vide, et l'onglet Application des outils de développement
      (IndexedDB `firebaseLocalStorageDb`) ne contient aucune session.
- [ ] **Sur un vrai téléphone, en français et en anglais** : le bouton
      « Demander la suppression de mon compte » passe sur deux lignes en
      portrait, les trois listes gardent leurs marqueurs (→ étapes, ✕ supprimé,
      • conservé), rien ne déborde à 200 % de taille de police.
- [ ] **Gestionnaire de mots de passe** : `autocomplete="email"` et
      `current-password` sont posés ; le navigateur propose l'identifiant, et
      n'enregistre rien après la demande.
- [ ] **Comptes Google / Apple** : la page exige un mot de passe, elle ne les
      concerne pas (comme avant). Vérifier que la phrase « À savoir » les
      renvoie à l'application, et que « Supprimer mon compte » est bien dans le
      Profil.
- [ ] **Le dialogue « Supprimer mon compte » de l'application** : son texte
      (`deleteAccountWarning`) a gagné une puce sous « Sera conservé »
      (l'identifiant technique qui subsiste dans les groupes chiffrés : la
      credential MLS contient l'uid jusqu'au prochain commit d'un membre), et sa
      phrase sur les groupes en a gagné une (« … et un groupe dont vous étiez le
      dernier membre est supprimé »). Vérifier qu'il défile jusqu'au bout et que
      ses deux boutons restent atteignables, en français et en anglais, à 200 % de
      taille de police — avec le paragraphe sur l'effacement des clés, c'est sa version la plus longue.

---

## ⬜ Site web entièrement refait sur cahier des charges (2026-09-08)

**Priorité P2** · importance 4/5 — Un visiteur sur téléphone n'arrive pas à la fiche Play depuis la page de téléchargement ou le QR code, au moment même du lancement.

Le site n'est plus la même page avec un autre thème : c'est une landing où
l'application est le sujet. Sept sections, trois pages nouvelles
(`/fonctionnalites`, `/a-propos`, `/telecharger`), une feuille de style
partagée (`public/assets/`) au lieu du CSS recopié dans chaque page.

- [ ] **Le héros sur un vrai téléphone** : globe animé, appareil qui monte,
      trois pastilles de notification. Vérifier que l'animation ne saccade pas
      sur le SM-A515F, et qu'elle ne se rejoue pas à chaque défilement.
- [ ] **Sélecteur de fonctionnalités** : six onglets qui changent la capture.
      À vérifier au doigt (zone de frappe) et au lecteur d'écran (`role="tab"`,
      flèches du clavier).
- [ ] **Page `/telecharger`** : elle détecte l'appareil. Sur Android elle doit
      montrer « Ouvrir Google Play », sur iPhone « Bientôt sur iOS », sur
      ordinateur le QR code. Les trois cas sont à voir en vrai.
- [ ] **Le QR code** doit s'ouvrir sur la bonne fiche Play depuis l'appareil
      photo du téléphone.
- [ ] **Lisibilité au soleil** : la page est claire, elle se comporte à
      l'inverse d'une page sombre en extérieur.
- [ ] **`prefers-reduced-motion`** : avec « Réduire les animations » activé,
      le globe, le téléphone et les pastilles doivent apparaître sans
      mouvement.
- [ ] **Poids et vitesse** : huit captures WebP (~300 Ko), deux feuilles de
      style, un script. À mesurer en 3G, objectif Lighthouse 90+.

---

## ⬜ Site web : menu mobile, liens partagés, aperçus de partage (2026-09-08)

**Priorité P2** · importance 5/5 — Sur mobile, la navigation du site n'offre ni téléchargement ni langue, et un lien de post partagé sur WhatsApp retombe sur l'accueil sans aperçu.

`public/` (déployé sur `diasponiger.web.app`). Rien ici n'est couvert par
`flutter analyze` : c'est du HTML statique, vérifié en local sur un viewport
émulé et par un banc Node qui rejoue le vrai bloc JavaScript extrait des
pages livrées (18 chemins). Il reste ce qu'un navigateur de téléphone seul
peut dire.

- [ ] **Menu mobile** — sous 900 px, `.nav-links` était en `display: none`
      **sans remplacement** : la barre de nav ne montrait plus que le logo,
      ni bouton « Télécharger », ni bascule FR/EN. Un bouton hamburger ouvre
      désormais un panneau déroulant. À voir sur le navigateur du téléphone :
      le panneau est opaque (`#14110d`), les six lignes tiennent sans
      débordement, et un tap sur un lien le referme.
- [ ] **Lien partagé qui ouvre l'app** — l'app partage `/feed/<id>` mais le
      panneau « Ouvrir dans Diaspo Niger » ne se déclenchait que sur
      `/profile/` et `/p/` : un post partagé tombait sur la page d'accueil,
      sans aucun moyen d'atteindre le contenu. Les 13 routes de l'app sont
      maintenant reconnues. Test réel : partager un post depuis l'app, ouvrir
      le lien depuis WhatsApp sur un téléphone **sans** l'app (ou app
      désinstallée) → le panneau doit s'afficher ; avec l'app installée,
      App Links doit l'ouvrir sans même passer par le site.
- [ ] **Aperçu de partage** — aucune balise Open Graph n'existait : coller un
      lien du site dans WhatsApp/Facebook ne montrait rien. `og:image` pointe
      sur `og-image.png` (1200×630, généré). À vérifier en collant le lien
      dans une conversation WhatsApp (le cache de l'aperçu peut retenir
      l'ancienne version pendant plusieurs heures).
- [ ] **Universal links iOS** — `apple-app-site-association` contenait encore
      `VOTRE_TEAM_ID` et un bundle inexistant (`com.diasponiger.diaspo_niger`
      au lieu de `com.diasponiger.diaspoNiger`), et Firebase le servait en
      `text/html` faute d'extension — Apple exige `application/json`. Les
      trois sont corrigés, mais **rien ne peut être vérifié tant que l'app
      iOS n'est pas installée sur un appareil** (voir la session iOS).

**Après déploiement** (`firebase deploy --only hosting`), à contrôler en
ligne — ces trois-là ne se voient pas en local :

- [ ] `curl -sI https://diasponiger.web.app/.well-known/apple-app-site-association | grep -i content-type`
      doit rendre `application/json`.
- [ ] `https://diasponiger.web.app/robots.txt` et `/sitemap.xml` doivent
      rendre leur propre contenu, pas la page d'accueil (la réécriture `**`
      les avalait : ils n'existaient pas).
- [ ] Le favicon apparaît dans l'onglet (la page d'accueil n'en avait aucun).

---

# 16. Journaux de passes appareil

Comptes rendus de passes complètes, gardés pour leurs cases encore ouvertes et leurs constats.

---

## Passe pilotée du 2026-08-04 (15:25 → 16:05) — SM A515F, APK debug `54083d6`

**Priorité P2** · importance 3/5 — Le partage entrant et les liens ouverts depuis une autre app pourraient ne rien ouvrir, et hors ligne l'app paraît normale en affichant des correspondants anonymes et des squelettes sans fin ; les autres cases (sauvegarde, bandeau, brouillon, repli hors ligne, boucle du jeton, « CET APPAREIL », restauration des clés) sont soldées dans l'entrée ou ailleurs.

### 🔴 Trouvé — Firebase App Check refuse l'attestation à chaque démarrage

À chaque démarrage à froid (3/3) :

```
⚠️ Erreur lors de la récupération du debug token: [firebase_app_check/unknown]
FirebaseException: Error returned from API. code: 403 body: App attestation failed.
```

- [ ] Sans conséquence visible tant qu'App Check n'est pas en *enforcement* —
      mais si un backend Firebase passe en enforcement, tous les appels de cet
      appareil seront rejetés. Vérifier l'état d'enforcement côté console, et
      enregistrer le jeton de debug pour les builds debug.

### ⚠ À confirmer au doigt — intermittence du clavier de recherche

Sur 7 cycles ouverture/fermeture enchaînés par script (tap champ → `dumpsys` →
tap ←), le clavier est monté **5 fois sur 7**. Les deux échecs sont survenus
juste après une fermeture, donc probablement pendant l'animation de repli — mon
automatisation retape plus vite qu'un humain. **Ce n'est pas un bug établi.**

- [ ] Refaire une dizaine d'ouvertures/fermetures **au doigt**, à rythme normal :
      si le clavier monte à chaque fois, clore le point ; sinon, le §9b n'est
      qu'à moitié corrigé.

### ⚪ Fausses alertes — ne pas les rouvrir

- Le **liseré blanc au bord gauche**, visible à la même hauteur sur trois
  captures d'écrans différents, est la surcouche Samsung « Edge panel »
  (`com.samsung.android.app.cocktailbarservice`), **pas** un widget qui déborde.
- Une navigation spontanée vers `/profile` observée une fois n'est **pas**
  reproductible (0 navigation en 70 s puis en 30 s d'observation immobile) :
  c'était un tap extérieur sur le téléphone, pas l'app.

### À arbitrer

- [ ] Depuis l'onglet Messages, le **retour Android quitte l'app** au lieu de
      revenir sur Accueil. Comportement courant, mais à trancher.

### 🔴 Trouvé — un lien vers une publication inexistante reste bloqué sur les squelettes

L'écran affiche maintenant « Publication introuvable » (avec « Retour au fil »)
ou « Impossible d'afficher cette publication » (avec « Réessayer », qui n'a de
sens que sur une panne), et **le champ de commentaire est masqué** dans les deux
cas.

- [ ] Rejouer avec une publication **réellement supprimée** (pas seulement un id
      inventé) : c'est le cas que rencontrera un vrai utilisateur.

### ⚠ Empreinte mémoire à surveiller

`dumpsys meminfo` pendant la passe : **TOTAL PSS ≈ 1,0 Go** (Native Heap 100 Mo,
Dalvik 26 Mo), et le système tuait des process en arrière-plan au même moment
(`edgelighting`, `mobileservice`, `turbo:aab`). C'est un **build debug** avec
Impeller et la carte Google ouverte, donc non représentatif tel quel.

- [ ] Refaire la mesure sur un **build release**, carte fermée puis ouverte, pour
      savoir si le pic vient de la carte ou du mode debug.

### ✅ Feuille de partage fantôme — ne réapparaît plus (3 relances sur 3)

- [ ] Reste à faire : un **vrai partage entrant** depuis Chrome ou Messages
      (image, vidéo, PDF, sélection multiple) — non testable en pilotage `adb`
      sans passer par le sélecteur système.

### 🔴 Trouvé hors ligne — trois défauts distincts

- [ ] **Aucun indicateur « hors ligne » hors du fil.** L'accueil, la carte, les
      messages et le profil ne signalent rien : l'app a l'air normale alors que
      rien ne se charge. Seul « Le fil » a son bandeau. À uniformiser.
- [ ] **Le nom du correspondant retombe sur « Utilisateur »** dans la liste des
      conversations (« Salim L. » en ligne, « Utilisateur » + initiale « U »
      hors ligne). Le dernier message, lui, est bien en cache — c'est donc le
      profil du correspondant qui n'est pas mis en cache.
- [ ] « Autour de vous » (accueil) reste sur **4 avatars squelettes** hors ligne,
      sans état vide.

### Bilan du programme — ce qui reste, et pourquoi

- [ ] ⚠ **`am start` ne prouve pas le clic réel.** Android répond « Activity not
      started, its current task has been brought to the front » — le cas a bien
      été exercé, mais un vrai clic vient d'une autre app (Chrome, Messages)
      avec sa propre tâche. À refaire au doigt depuis Chrome pour être complet.
- [ ] Même chemin **déconnecté** : la route doit être mise de côté puis rejouée
      après connexion (étapes 0 et 10 du `redirect`) — non exercé.
- [ ] 🧹 **Reste un brouillon de test de 2000 caractères dans « Mes notes »** :
      ma tentative de nettoyage par `input keycombination` n'a pas pris. À
      effacer à la main.

### ⚠ Partage entrant : non présenté par `am start` — à confirmer au doigt

`am start -a android.intent.action.SEND -t text/plain --es
android.intent.extra.TEXT … com.diasponiger.diasponiger` : l'app démarre bien
(l'intent est accepté, `pkg=com.diasponiger.diasponiger`) mais **atterrit sur
`/home`** — la feuille « Envoyer à… » ne s'ouvre pas.

- [ ] **À faire au doigt** : partager un texte depuis Chrome ou Messages, et
      vérifier que la feuille s'ouvre. Puis `am force-stop` + relance : elle ne
      doit PAS revenir (c'est le test de l'empreinte persistée).

### Deux pièges de pilotage `adb` à connaître

- `adb shell input text` **perd des morceaux** au-delà de quelques centaines de
  caractères : 2400 caractères envoyés en 8 fois n'en ont produit que 1561.
  Vérifier le compteur à l'écran plutôt que de supposer.
- Les arguments contenant des **espaces** sont découpés par le shell : un
  `--es … "Partage de test" com.diasponiger…` a donné `pkg=de`. Utiliser un
  texte sans espace, ou quoter côté appareil.

- ✔ 29 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Passe pilotée du 2026-08-04 (15:25 → 16:05) — SM A515F, APK debug `54083d6` »).

---

## Passe nocturne + carte vérifiée sur appareil (2026-08-04, SM A515F)

**Priorité P3** · importance 2/5 — Un panneau d'exploration par ville mal rendu ou un badge vérifié peu contrasté en thème sombre, sans perte de fonction.

**Fausse alerte notée pour mémoire** : la ligne de fraîcheur du panneau
affiche deux « Chargement… » tant que la position n'est pas acquise. Ce n'est
pas un champ mort — au bout des 15 s de `timeLimit`, en intérieur sans fix
GPS, l'écran bascule sur 8c. Ne pas rouvrir ce faux bug.

**Reste à vérifier sur ces fiches :**
- [ ] 8c — le panneau bas « Sans localisation, explorez par ville » **existe**
  (`_buildExploreByCityPanel`) mais **n'a pas pu être vu** : il n'y a
  aucune ambassade en base (`/embassies` affiche « Aucune ambassade
  disponible ») et le compte de test n'a aucun groupe. Le panneau s'escamote
  correctement au lieu d'afficher une coquille vide. À revérifier dès qu'une
  ambassade ou un groupe public existe avec une ville renseignée.
- [ ] 7d — cluster de pins et les trois crans de la feuille (18/45/92 %) non
  exercés : un seul membre autour, donc pas de cluster.
- [ ] 11d — badge « vérifié ».

- ✔ 5 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Passe nocturne + carte vérifiée sur appareil (2026-08-04, SM A515F) »).

---

## Session du 2026-08-03 (soir) — SM A515F, refonte enfin lancée

**Priorité P2** · importance 2/5 — Fermer la feuille des langues pourrait modifier le profil à l'insu de l'usager ; les autres cases (styles de carte désormais présents, débordement du volet, restauration des clés vérifiée le 2026-08-23) sont soldées.

**Sélecteur multi-choix des langues (§20a)** — écrit, **jamais lancé**

- [ ] Le téléphone s'est déconnecté avant que je puisse l'ouvrir. `flutter
      analyze` passe, mais rien n'a été vu. À vérifier :
  - la puce « +N langues » ouvre bien une feuille, et ne déplie plus la
    liste sur place ;
  - cocher/décocher met à jour le compteur « N sélectionné(s) » en tête de
    feuille **en direct** ;
  - **fermer la feuille sans « Terminer » ne modifie rien** — c'est le point
    le plus important, la sélection travaille sur une copie ;
  - « Terminer » reporte le choix sur les puces de la carte ;
  - quand les 7 langues sont choisies, la puce « +N » **disparaît** au lieu
    d'afficher « +0 langues » ;
  - à `font_scale = 1.1`, la feuille reste utilisable et le bouton
    « Terminer » atteignable (elle est en `isScrollControlled`).

- ✔ 10 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Session du 2026-08-03 (soir) — SM A515F, refonte enfin lancée »).

---

## Session appareil du 2026-08-03 — SM A515F, thème sombre, font_scale 1.1

**Priorité P3** · importance 2/5 — Empreinte de clé à peine visible en sombre et quelques libellés tronqués ou sans accents : gêne cosmétique.

- [ ] Empreinte de clé quasi invisible (écran des appareils) : le texte
  utilisait `theme.colorScheme.outline`, une couleur de **bordure**.
  Corrigé vers `textSecondaryColor` — **non vérifié à l'écran**, l'app a
  redémarré avant que j'y revienne. À confirmer.
- [ ] Texte codé en dur et sans accents sur ce même écran (« jusqu'a 5
  appareils connectes simultanement ») alors que la clé localisée existait
  et n'était pas utilisée. Corrigé — **non vérifié à l'écran**.

À retenir pour les prochaines sessions : vérifier `ui_night_mode` **avant
et après** chaque série de captures. Piloter l'app par taps aveugles peut
modifier des réglages système et fabriquer de faux défauts visuels.

### ⚠ Ouvert : « Précédent » toujours tronqué

Correctif appliqué en second recours : le libellé des boutons de la
trousse est enveloppé dans un `FittedBox(scaleDown)`, pour qu'un mot trop
long **rétrécisse** au lieu d'être coupé. **Non vérifié sur appareil** —
à confirmer au prochain passage.

- ✔ 2 cases déjà vérifiées : archivées dans [TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« Session appareil du 2026-08-03 — SM A515F, thème sombre, font_scale 1.1 »).
