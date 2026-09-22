# Tests sur appareil — déjà vérifiés

Archive de [TESTS_APPAREIL_A_FAIRE.md](TESTS_APPAREIL_A_FAIRE.md) : les
entrées dont toutes les cases sont cochées, et les cases cochées des entrées
encore ouvertes, avec leurs notes (appareil, build, date, ce qui a été vu).
Générée par `tools/archiver_tests_appareil.py` : on n'y écrit pas à la main,
on y cherche (« voir « Titre » » d'une entrée de la liste peut mener ici).

Une régression sur un point archivé se rouvre dans la liste, pas ici.

# Archivage du 2026-09-22

## 1. Appareils, comptes de test et méthode

### ⬜ Compte de test dédié : première connexion (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Non-régression sur compte existant — ✅ SM A515F, 2026-09-09.** La
      fonction d'échange sert TOUTES les connexions, pas seulement les
      premières : après le redéploiement, démarrage à froid de l'APK debug
      1.2.1+11 déjà installé (le correctif étant côté serveur, rien à
      recompiler). Logcat : `SupabaseAuthBridge: session sync OK`, aucun
      `exchange failed`, aucun 401. Accueil rempli avec des données qui
      exigent une session authentifiée — badge de 2 notifications, « Membres
      à proximité · 1 », ville et progression de profil.
- [x] **Compte neuf connecté depuis l'app — ✅ SM A515F, 2026-09-09.** Compte
      Firebase créé pour l'occasion, connexion par l'écran de l'app (pas par
      l'API), logcat vidé juste avant. Résultat : **une seule** ligne du pont,
      `SupabaseAuthBridge: session sync OK`, à la seconde de la connexion.
      Aucune occurrence de `exchange failed`, aucune ligne Flutter portant un
      401. C'est exactement l'endroit où le défaut se voyait : avant le
      correctif, le premier échange échouait et seule la reprise 5 s plus tard
      sauvait la mise. L'app enchaîne ensuite sur le consentement, donc le
      parcours d'inscription reprend normalement.

---

### ⚠️ L'appareil porte une RELEASE depuis le 2026-08-23

Le SM A515F a été rebasculé en build **release** (construite depuis le
worktree, avec tout le travail de la session). Deux conséquences pour les
prochaines vérifications :

- **`debugPrint` ne sort plus dans logcat.** C'est exactement ce qui a permis
  de trouver la cause de l'écran Notifications en erreur ce jour-là
  (`NotificationSupabaseDataSource: flux interrompu … RealtimeSubscribeException`).
  Pour un diagnostic du même genre, il faudra réinstaller un build debug —
  donc désinstaller la release, **donc effacer les données locales**.
- Les données de l'app ont été effacées par la désinstallation (session, cache,
  clés E2EE locales). Une sauvegarde de clés a été créée par l'utilisateur juste
  avant, le 23/8/2026 à 21:53 depuis ce même appareil ; la restauration se fait
  depuis Réglages → Sécurité → Sauvegarde des clés, avec sa passphrase.

#### Re-vérifié sur la release, après reconnexion et restauration des clés

Tout ce qui suit a été revu sur le build **release** installé le 2026-08-23,
une fois l'utilisateur reconnecté et ses clés restaurées. Les mêmes points
avaient été validés en debug plus tôt dans la journée ; cette passe confirme
qu'ils survivent au changement de build et à la réinstallation.

- [x] **Démarrage à froid** (`am force-stop` puis relance) : l'app arrive
  directement sur l'accueil connecté, sans repasser par l'écran de connexion.
- [x] **Aucun crash** dans logcat. Le bruit restant est attendu : profil ART
  périmé après réinstallation (`ClassLoaderContext mismatch`), refus SELinux
  bénin sur `max_map_count`, et `GoogleCertificatesRslt: not allowed` — normal
  pour un APK signé avec la clé de dev.
- [x] **Messages déchiffrés et lisibles** : la restauration des clés a bien
  fonctionné.
- [x] **Page Notifications** : charge (17 non lues), liste **à plat**, actions
  en ligne « J'y vais » / « Voir » présentes.
- [x] **Rafales** : `rafale_A` / `rafale_B` / `rafale_C` → seul le dernier porte
  son heure.
- [x] **Rupture de 15 min** : le sondage de 05:18 garde son heure, séparé de la
  rafale suivante du même expéditeur.
- [x] **Tap sur une bulle masquée** : révèle son heure.
- [x] La réaction ❤️ posée avant la réinstallation est toujours là.

⚠️ **Portée de ce « aucune erreur »** : en release les `debugPrint` ne sortent
pas, donc le contrôle logcat ne couvre que les crashes natifs et les exceptions
Java. Une erreur Dart silencieuse ne s'y verrait pas — elle partirait chez
Crashlytics.

---

## 2. Messagerie

### ⬜ Les premiers messages reçus restent « Message chiffré » dans la liste (2026-09-21)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Liste à l'écran, deux messages reçus à moins de 5 s** (depuis l'autre
      téléphone) : l'aperçu passe au texte du second en ≤ 5-6 s, sans toucher.
      ✅ Passe du 2026-09-22 (~03:20–03:35), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Pixel sur la liste (démarrage à froid), Sim envoie PX1
      (03:22:45.2) puis PX2 (03:22:49.9, 4,7 s après) → la tuile « Sim A » dit
      « PX2 · 2 » dès le premier relevé (≈ 1 s), jamais « Message chiffré », et
      le reste 50 s (relevés toutes les ~3,5 s). `6646318` est bien dans f22aaff.

---

### ⬜ Fiches de partage : libellés sur une ligne, vrais logos, bouton (2026-09-20)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Profil, échelle 1,3 + texte en gras** : Partager mon profil → « WhatsApp »,
      « Facebook », « X » et « Plus » tiennent chacun sur une seule ligne, sans
      coupure ni débordement. Le texte rétréci reste lisible. (Le Pixel, ou le
      A515F réglé à 1,3 et gras : à 1,0 sans gras le défaut n'existe pas.)
      ✅ Passe du 2026-09-22 (~05:35–05:45), build Play 1.2.2+26 (f22aaff, contient 37465e9), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : « WhatsApp », « Facebook », « X », « Plus » chacun sur une
      seule ligne, sans coupure, lisibles. La carte est plus haute que l'écran à
      cette échelle : le bouton « Envoyer dans une discussion » est à moitié sous
      le pli à l'ouverture, et apparaît en entier en faisant défiler la carte.
- [x] **Profil, logos, thème clair** : WhatsApp, Facebook et X montrent leur logo de
      marque (X : logo blanc sur pastille noire), « Plus » ses trois points — vu
      SM A515F, build 1.2.2+23, 2026-09-20.
- [x] **Profil, logos, thème sombre** : le X passe en blanc avec logo noir.
      ✅ Passe du 2026-09-22 (~05:35–05:45), build Play 1.2.2+26 (f22aaff, contient 37465e9), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : X sur pastille blanche, logo noir ; WhatsApp, Facebook et
      « Plus » gardent leur logo et leur teinte.
- [x] **Bouton « Envoyer dans une discussion », profil, à 1,0** : une seule ligne,
      l'icône et le texte à distance des bords — vu SM A515F, build 1.2.2+23,
      2026-09-20. « Scanner un QR code », dessous, inchangé.
- [x] **Bouton, à 1,3 + texte en gras** : toujours une seule ligne, l'icône n'est
      plus collée au bord gauche ; le texte rétréci reste lisible.
      ✅ Passe du 2026-09-22 (~05:35–05:45), build Play 1.2.2+26 (f22aaff, contient 37465e9), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : « Envoyer dans une discussion » sur une ligne, icône à
      distance du bord gauche, texte lisible (après défilement de la carte).

---

### ⬜ Le séparateur « N messages non lus » part quand tout est lu (2026-09-17)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Tout tient à l'écran** : 3 non-lus, ouvrir → séparateur visible, les 3
      lus aussitôt (A2) → le séparateur **reste** tant qu'on ne bouge pas.
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Pixel fermé, Sim envoie PS1–PS3, ouverture à froid →
      « 3 messages non lus » au-dessus de PS1, les trois `read_at` posés
      (02:19:44), séparateur **toujours là** 6 s plus tard sans rien toucher.
- [x] **Message reçu après que tout est lu** : aucun séparateur ne revient.
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : discussion restée ouverte, PS4 arrive en direct → aucun
      séparateur ; livré en 1,4 s, lu en 3 s.
- [x] **Rouvrir** la discussion lue : pas de séparateur.
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : relance à froid après lecture de PS1–PS3 → aucun
      séparateur.

---

### ⬜ Droits d'écriture sur `messages` resserrés : accusés et modification (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Modifier son propre message** : A modifie, le nouveau texte tient
      après un retour arrière et une relecture (voir « Modifier un message en
      ligne »)
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA2 → PA2M, part en message de contrôle, `edited_at` posé ; « modifié » EN DIRECT chez le destinataire, et le texte tient après sortie + réouverture chez l'expéditeur.
- [x] **Réaction** : B réagit au message de A → l'emoji apparaît des deux
      côtés
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (MLS) : 👍 en base et chez son auteur tout de suite ; chez l'autre, visible seulement à la réouverture de la discussion — pas en direct (même cause que « Lu »).

---

### ✅ Curseur de lecture et séparateur « nouveaux messages » (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Les messages affichés sont marqués lus** : bloc visible à l'ouverture
  (05:20:27) → `read_at` à **05:20:29**.
- [x] **Ceux restés SOUS LE PLI ne le sont pas** — c'est le point central.
  Quatre blocs hors écran, `read_at` **nul**, `delivered_at` posé. L'ancien
  `markAsRead` global les aurait tous marqués.
- [x] **Reçu ≠ lu** : deux messages livrés à 04:41:03 et lus seulement à
  **05:02:45** — vingt minutes d'écart, tombant exactement sur l'instant où
  les bulles ont été montrées.
- [x] **Côté expéditeur** : « Envoyé » sur les quatre blocs sous le pli, jamais
  « Lu ».
- [x] **Le séparateur s'affiche au bon rang** : « 1 message non lu » posé juste
  au-dessus du seul non-lu, et la vue s'y place.

---

### ⬜ GIF et sticker envoyés en MLS : la bulle ne montrait rien (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Envoyer un GIF dans une conversation basculée MLS** : la vignette
      s'affiche chez l'expéditeur **et** chez le destinataire
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : GIF des tendances envoyé par Sim, vignette animée des deux côtés, reçu en direct (`content_type = sticker` en base).

---

### ⬜ Forme de la bulle qui cite un message (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Thème sombre** : l'aplat blanc à 14 % sur le vert `#009600` — détaché
  sans virer au laiteux.
  ✅ Passe du 2026-09-22 (~05:10), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Salim répond à PZ2 en le citant (« PQR1 ») → sur le Pixel
  (sombre, police 1,3 + gras), la bulle envoyée porte un encart vert plus
  clair « Sim A · PZ2 », détaché du vert de la bulle sans virer au laiteux,
  filet blanc à gauche.
- [x] **Échelle de police à 130 %** (réglages Android) : la citation tient sur
  ses deux lignes, la bulle ne déborde pas. Voir « Échelle de police ».
  ✅ Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras) : PF1 (reçue, cite « Vous · PE1 ») à la police 1,3 + gras →
  citation sur deux lignes, bulle entière, rien ne déborde.
- [x] **Bulle reçue** portant une citation, en clair et en sombre.
  ⬜ moitié, Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff) : vue en **sombre** sur le Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras) (PF1 : fond gris foncé,
  filet orange, « Vous » en orange, lisible). En clair, pas de bulle reçue
  citante dans le 1:1 côté Sim.
  ✅ Passe du 2026-09-22 (~05:10), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : la moitié claire — sur le SM A515F (clair), PQR1 reçu sous
  « 1 message non lu » : encart gris « Vous · PZ2 », filet orange, lisible.

---

### ⬜ « Modifier le message » : saisie en ligne, fenêtre de 48 h, motifs dits (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le brouillon survit.** C'est le point à vérifier en premier, parce
  qu'il se perd en silence : écrire un début de message SANS l'envoyer, entrer
  en modification sur un message plus haut, ressortir par la croix — le
  brouillon doit être revenu intact dans le champ. Puis recommencer en
  **quittant la discussion** en pleine modification : à la réouverture, c'est
  le brouillon qui doit être là, jamais le texte du message modifié. Tenu par
  `test/features/messages/modifier_message_test.dart`, mais le cycle de vie
  réel de l'écran n'est pas celui du banc.
  ✅ Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim), 1:1 MLS : « BROUILLON22 » tapé sans envoyer, « Modifier »
  sur PA22ECHEC → le champ prend le texte du message ; sortie par la croix →
  « BROUILLON22 » revient intact. Puis modification rouverte et **discussion
  quittée** (deux Retour) ; rouverte depuis la liste → « BROUILLON22 » dans le
  champ, aucun bandeau de modification.
- [x] **Message d'hier.** Un message de la veille doit encore se modifier
  (c'était le cas le plus courant refusé par la fenêtre de 25 min). Un message
  de plus de 48 h doit montrer l'entrée **grisée**, avec « Passé 48 h, un
  message ne se modifie plus » en sous-titre.
  ✅ Passe du 2026-09-22 (~05:15–05:30), build Play 1.2.2+26 (f22aaff), SM A515F (Sim), 1:1 MLS : appui long sur PF1 (21/09 19:31) → « Modifier » actif ;
  sur « Hi » (Sim, avant le 13/09) → « Modifier » **grisé** (`enabled=false`)
  avec « Passé 48 h, un message ne se modifie plus » en sous-titre. Rien
  modifié.

---

### ⬜ Pastille de non-lus, et séparateur « nouveaux messages » (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Démarrage à froid, sans ouvrir aucun fil** : vérifié le 2026-09-15 sur
  Pixel 10 Pro XL. « 3 non lus » en sous-titre, pastille **3** sur la tuile,
  puce « Non lus 3 », badge **3** sur l'onglet Messages, horodatage en orange,
  et l'aperçu en clair (l'emoji du dernier message). Avant : « Message
  chiffré », aucune pastille, vingt secondes durant, notification en clair à
  l'écran.
- [x] **L'expéditeur ne voit pas « Lu »** : vérifié à deux téléphones. Deux
  messages envoyés du SM A515F (Sim A) restent « Envoyé » tant que le Pixel
  n'ouvre pas. Ferme la case laissée ouverte par la passe précédente.
- [x] **Le séparateur** : vérifié le 2026-09-15 sur Pixel 10 Pro XL. Sept
  messages reçus sans ouvrir, puis ouverture : la pastille orange
  « 7 messages non lus » se pose au bon rang — sept messages d'autrui en
  dessous, ni plus ni moins — et la vue s'y place.

  L'ordre n'a finalement **pas** été changé : `markAsRead` part toujours au
  premier rendu. C'est le **compteur** qui est relevé avant, sur la liste
  vivante, et le séparateur qui se place par le **rang**
  (`rangDesDerniersDAutrui`) au lieu de l'état de lecture — lequel est
  déjà faussé quand le fil arrive.
- [x] **Mesuré, puis corrigé.** Avant : le fil s'affichait depuis le cache,
  **sans** les messages reçus entre deux visites, et il fallait 2,5 à 3 s
  (trois à quatre images de rafale) pour les voir apparaître. Après : ils
  sont là dès la **première image** après le tap. La liste déclenche un
  rattrapage de fond qui les déchiffre **et les met en cache** avant
  qu'on ouvre.

---

### ⬜ « Mes notes » s'ouvre sans aller-retour réseau — vérifié SM A515F (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] App déjà chargée, liste affichée : taper « Mes notes » ouvre l'écran
      **sans spinner** sur la tuile
- [x] Un message envoyé depuis cette ouverture-là part vraiment — pas de
      « Non envoyé · Réessayer » (c'est la panne de 2026-08-06). Prouvé en
      base, pas à l'écran : `mls_messages` de `805adcaa…` est passé de 5 à 6
      lignes, la dernière 23 s après le tap. L'écran seul ne suffirait pas,
      il affiche « Envoyé » de façon optimiste.
- [x] Réseau coupé, liste déjà chargée depuis le réseau : l'ouverture aboutit
      quand même (c'est le test ci-dessus)
- [x] Réseau coupé **et** liste jamais chargée depuis le réseau (démarrage à
      froid hors ligne) : doit échouer proprement sur le SnackBar
      « Impossible d'ouvrir Mes notes pour le moment ». Vérifié SM A515F le
      2026-09-15 : le SnackBar s'affiche, la liste ne bouge pas, aucun écran
      fantôme. Le point qui comptait était qu'un refus se **dise** — un écran
      qui n'annonce rien se lit comme « le tap n'a pas pris ».
- [x] Même parcours depuis « Nouvelle conversation » (l'autre appelant)
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : « Nouvelle conversation » → « Mes notes » → l'écran
      « Mes notes · Notes personnelles » s'ouvre en ~1 s.

---

### ⬜ Accusé « lu » mensonger, et aperçu chiffré qui ne venait jamais (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **La pastille revient** : vérifié le 2026-09-15 sur Pixel 10 Pro XL.
  Deux messages reçus de Sim A sans ouvrir la discussion → pastille « 2 » sur
  la tuile, puce « Non lus 3 », badge « 3 » sur l'onglet Messages. ⚠️ **Mais
  la cause n'était pas celle annoncée** : voir « ce que j'avais dit à tort »
  ci-dessous. À refaire une fois le correctif de la course livré, pour
  s'assurer que la pastille tombe **aussi** quand on ouvre.
- [x] **L'aperçu chiffré arrive sans ouvrir** : vérifié, « Hccuycyfyfyf » puis
  « Fghg » s'affichent dans la tuile. ⚠️ Mais **un rafraîchissement en
  retard** : l'isolate met l'aperçu en cache après l'émission de la liste. Le
  texte n'apparaissait qu'après un « tirer pour rafraîchir ». Corrigé par une
  seconde lecture bornée (400 ms) — à revérifier.
- [x] **Après le correctif de la course** : vérifié le 2026-09-15 sur Pixel
  10 Pro XL, build reconstruit. Cinq messages traînaient avec `read_at` nul
  depuis une demi-heure ; ouvrir la discussion les a **tous** marqués lus à
  02:37:49 UTC, une seconde après le tap. Avant, ils restaient nuls
  indéfiniment.

  | message | `delivered_at` | `read_at` |
  |---|---|---|
  | 02:04:23 | 02:09:23 | **02:37:49** |
  | 02:04:53 | 02:09:23 | **02:37:49** |
  | 02:07:47 | 02:09:23 | **02:37:49** |
  | 02:11:25 | 02:11:30 | **02:37:49** |
  | 02:13:19 | 02:17:14 | **02:37:49** |

  Et deux messages arrivés **pendant** que la discussion était affichée
  (02:38:35, 02:38:46) ont été marqués lus à leur tour : le garde
  `_estAffichee` ne bloque pas la lecture légitime. Recette :
  `supabase db query --linked -f supabase/diagnostics/2026-09-15_recus_bruts.sql`.
- [x] **Ce que cette passe n'a PAS montré** : que l'expéditeur repasse à
  « Lu » de son côté. Le A515F était piloté par un autre agent, je n'ai pas
  regardé son écran après coup. À confirmer à deux téléphones.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : l'expéditeur (Pixel) repasse bien à « Lu »… à la réouverture de la discussion, pas en direct (voir « Droits d'écriture sur `messages` resserrés »).
- [x] **L'aperçu chiffré arrive sans rafraîchir** : vérifié le 2026-09-15.
  « Tggt » puis « Erty » s'affichent **dès la première image** après le
  splash, sans « tirer pour rafraîchir ». La seconde lecture bornée (400 ms)
  referme bien la course avec l'isolate.
- [x] **Deux ouvertures de suite** : la seconde ne doit pas réécrire `read_at`
  — « lu à 14 h 03 » ne devient pas « lu à l'instant ». C'est ce que tient le
  filtre `read_at IS NULL`.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA1 lu à 17:56:47, inchangé après trois réouvertures.
- [x] **Et l'expéditeur ne voit pas « Lu »** tant que la discussion n'a pas
  été ouverte — c'est la moitié de ce correctif qui se voit **sur l'autre
  téléphone**. Les deux appareils sont nécessaires.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : « Envoyé » et `read_at` nul tant que Sim n'a pas ouvert (liste consultée, app en arrière-plan : rien de posé).
- [x] **Puis revenir à la discussion** : elle doit se marquer lue
  immédiatement. Le garde ne doit pas empêcher la lecture normale.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : réouverture → PA2 marqué lu dans la seconde (18:02:40).
- [x] **L'aperçu chiffré arrive sans ouvrir** : la tuile doit montrer le texte
  du message, pas « Message chiffré ». ⚠️ Ne marche que si le **push a été
  reçu** : vérifier notifications activées, et que le réglage « aperçu des
  messages » est ON (sinon l'isolate ne déchiffre pas, par respect du
  réglage).
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : tuile « Salim L. · PA1 · 1 » dans la liste de Sim, sans ouvrir.
- [x] **Supprimer pour tout le monde son dernier message** : la liste ne doit
  **pas** faire réapparaître le texte par l'aperçu de notification, qui a été
  posé avant la suppression. C'est le cas le plus dangereux du lot, et le test
  le tient hors appareil.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS côté destinataire : la tuile de Sim dit « Message chiffré » (pas le texte). ⚠️ Mais l'EXPÉDITEUR fuit par son cache local — voir « L'aperçu de la liste dit pourquoi il est vide ».

---

### ⬜ La liste n'annonce plus « Utilisateur » ni « Message chiffré » (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Mesure refaite** le 2026-09-15 sur Pixel 10 Pro XL, APK reconstruit
  et installé, **deux démarrages à froid** ouverts par lien profond sur
  `/messages`, rafale `screencap` sur le téléphone. Sur la première image
  après le splash — celle qui portait les deux libellés :
  - « Utilisateur » : **absent des deux tours**, les vrais noms sont là
    d'emblée (« Sim A », « Ibrahim Yacouba Maï… »).
  - « Message chiffré » : **remplacé par le vrai aperçu dès la première
    image** pour un message déjà déchiffré en cache (tour 1, message de
    21:20) — il fallait ~3 s avant. C'est la preuve du correctif de
    `getCachedConversations()`.
  - ⚠️ **Il reste** au tour 2, pour un message arrivé à 21:23 pendant que
    l'app était fermée : son clair n'est pas encore dans le cache local.
    C'est **juste**, et aucun correctif d'aperçu ne peut inventer ce texte.

---

### ⬜ Squelette de chargement de la messagerie (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le squelette ne revient pas** sur un « tirer pour rafraîchir » ni au
  retour sur l'onglet Messages (`skipLoadingOnRefresh` / `OnReload`) : la
  liste déjà affichée doit rester en place.
  ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), SM A515F : rafale de 8 captures sur le téléphone pendant un
  tirer-pour-rafraîchir, puis 6 pendant Accueil → Messages : la liste reste en
  place à chaque image, aucun squelette.
- [x] **Fil de groupe** : vérifié le 2026-09-15 sur Pixel 10 Pro XL, thème
  sombre, « Groupe de test prive » ouvert depuis la liste. La colonne
  d'avatar est bien réservée à gauche, les bulles sont collées en bas contre
  le composeur, et le balayage traverse l'écran d'un bloc. Capturé par
  rafale `screencap` **sur le téléphone** (une capture par USB coûte ~1 s,
  trop lent) : 12 images pendant le tap, le squelette tient sur une seule.
  Reste à voir : que les bulles ne sautent pas de 28 px quand les messages
  arrivent — l'image d'après était déjà la liste chargée.

---

### ⬜ L'aperçu de la liste dit pourquoi il est vide (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Pas le dernier** : supprimer un message qui n'est PAS le dernier de la
  discussion laisse l'aperçu intact (c'est l'égalité `last_message_at` =
  `created_at` du message qui décide).
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (MLS) : PD5 supprimé pour tous (« Message supprimé » dans le fil), la tuile garde « Vous: PF1 ».
- [x] **Un message neuf efface la marque** : après la suppression, envoyer un
  autre message. La tuile affiche son texte, et plus jamais « Message
  supprimé » — la marque doit disparaître, sinon elle colle à la conversation
  pour toujours.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA7 envoyé après la suppression → tuile « Vous: PA7 » chez l'expéditeur.

---

### ✅ Le temps réel n'écoutait pas les messages chiffrés (2026-09-15)

**Priorité P0** · importance 5/5 — Signalé par Salim : « les messages ne
s'actualisent pas ». **Corrigé et vérifié à deux téléphones.**

Le temps réel s'abonnait à `conversations` et `messages`, **jamais à
`mls_messages`**. Or depuis la bascule MLS, ce sont les messages chiffrés qui
sont vivants : dans une conversation basculée, plus RIEN n'arrivait en direct
— il fallait ressortir de la conversation et y revenir. Mesuré : Pixel resté
ouvert sur la conversation, message envoyé du SM A515F, rien à l'écran.

Le serveur était déjà prêt — `mls_messages` figure dans la publication
`supabase_realtime` et porte sa politique SELECT « participants ». Il manquait
seulement l'abonnement côté client.

Corrigé : la datasource émet un **signal** (pas un message : la ligne est
chiffrée, seule la passerelle sait la lire), et le dépôt le fusionne
(`Rx.merge`) au flux existant en relisant le fil par `catchUp`, qui est
incrémental. L'écran dédoublonne déjà par identifiant.

- [x] **Vérifié le 2026-09-15** : `LIVE-TEST` envoyé du A515F apparaît sur le
  Pixel « À l'instant », **sans y toucher**, dans une conversation chiffrée.

---

### ✅ Temps réel des messages chiffrés — les trois cas (2026-09-15)

**Priorité P0** · importance 5/5 — Signalé par Salim : « les messages ne
s'actualisent pas », puis « les modifications et suppression ne sont pas
instantanés ». **Corrigé et vérifié à deux téléphones, les trois cas.**

- [x] **Nouveau message** : `CACHE-LIVE` envoyé du SM A515F apparaît sur le
  Pixel « À l'instant », sans y toucher.
- [x] **Modification** : `VRAI-MODIF · modifié` remplace le texte en direct.
- [x] **Suppression** : après purge serveur, la bulle devient « Message
  supprimé » en direct.
- [x] **Ce qui arrive en direct SURVIT** à une sortie/retour de la
  conversation.
- [x] **EN GROUPE aussi** — vérifié dans « Testeurs » (basculé le 2026-09-15 à
  19:53, 2 membres) : `GROUPE-LIVE` arrive en direct et **déchiffré** sur le
  Pixel, sa modification s'y affiche `GROUPE-MODIF`, et après purge la bulle
  devient « Message supprimé ». Les trois sans jamais toucher au Pixel.

  ⚠️ **Observation, état antérieur non causé par ces correctifs** : le message
  chiffré déjà présent dans ce groupe (19:54) s'affiche sur le Pixel comme
  « Message indisponible sur cet appareil » — il est illisible pour lui. Les
  messages envoyés APRÈS se déchiffrent normalement. À regarder par qui
  travaille sur le rattrapage MLS de groupe.

**Ce qu'il fallait, et rien de plus** — trois petites pièces, aucune migration :

1. **s'abonner à `mls_messages`** : le temps réel n'écoutait que `messages`,
   alors que depuis la bascule ce sont les messages chiffrés qui sont vivants ;
2. **écouter `insert` ET `update`** : `insert` porte les nouveaux messages et
   les modifications (qui voyagent dans un message de contrôle, donc une ligne
   de plus) ; `update` porte les suppressions, qui ne sont qu'un passage de
   `is_deleted` à vrai ;
3. **mettre en cache ce qui arrive par ce chemin** : le cache local est le
   SEUL endroit qui garde le clair d'un message chiffré. Sans ça un message
   livré en direct vivait en mémoire et nulle part ailleurs — il s'affichait,
   puis disparaissait à la reconstruction suivante.

⚠️ **`REPLICA IDENTITY FULL` n'est PAS nécessaire**, contrairement à ce qui
avait été écrit ici la veille. Le filtre d'un `update` s'évalue sur la
NOUVELLE ligne, qui porte `conversation_id`. `FULL` ne sert qu'à un `delete`
(seule l'ancienne ligne existe, réduite à la clé primaire) ou pour lire
`payload.oldRecord`. Preuve dans le dépôt : `getMessageUpdatesStream`
s'abonne depuis toujours à `update` sur `messages` avec le même filtre, et
c'est ce qui fait arriver les accusés de lecture. On ne supprime jamais de
ligne, donc `delete` n'a rien à faire dans l'abonnement — d'où `insert` +
`update` nommés un par un plutôt qu'un `all` fourre-tout.

⚠️ **Rien à faire pour la tombe** : la relecture la pose déjà,
`_avecMetadonnees` marquant `deletedForEveryone` depuis `is_deleted = true`.

⚠️ **Piège de recette, coûteux** : trois essais d'affilée ont conclu « rien
n'arrive en direct » alors que **les messages n'étaient jamais partis** — les
taps avaient ouvert « Mes notes ». C'est ce qui avait fait accuser `event: all`
et annuler une correction saine. **Vérifier l'en-tête de la conversation PUIS
la présence du texte dans la zone de saisie avant de conclure.**

---

### ✅ Média chiffré illisible à l'arrivée — et le débordement qui va avec (2026-09-15)

**Priorité P0** · importance 5/5 — Signalé par Salim : « je n'arrive pas à
lire les audios et aussi il y a overflow des deux côtés ». **Corrigé, à
vérifier sur appareil.**

**Un seul défaut, deux symptômes.** Le mapper MLS posait
`fileUrl: body['storagePath']` et **rien d'autre** : `mediaChiffre` restait
nul. Or `MediaChiffreGate` ne déchiffre QUE si ce champ existe — nul, il
laisse passer le message tel quel, et la bulle tente d'ouvrir le blob
**chiffré**.

1. la note vocale ne se lit pas (`_togglePlayPause` échoue) ;
2. l'erreur est alors ajoutée dans `_buildControlsRow`, une `Row` **sans le
   moindre `Flexible`** dans une bulle de 250 px — d'où le **débordement**,
   des deux côtés puisque les deux appareils suivent le même chemin.

Ça ne touchait pas que l'audio : **toute image, vidéo ou pièce jointe reçue
en MLS** était concernée, la porte étant commune.

Corrigé aux deux endroits : le mapper reconstruit la fiche du média depuis le
payload (`storagePath`, `fileKey`, `fileNonce`, `fileName`, `mimeType`,
`fileSize` — `encryptedUrl` reste vide, le téléchargement se fait par
`storagePath`), et l'erreur de la rangée de contrôles est passée en
`Flexible` + ellipse : une erreur doit se voir, pas casser la mise en page.

- [x] **Vérifié à deux téléphones le 2026-09-15**, dans « Testeurs » :
  - une note vocale **reçue se lit** sur le Pixel (`0:07 / 0:10`, onde
    parcourue, tête de lecture) — donc téléchargée ET déchiffrée ;
  - une **image reçue s'affiche** (flou d'attente, puis la photo) ;
  - une note vocale **envoyée se lit** chez l'expéditeur (`0:03 / 0:03`) ;
  - **plus aucun débordement** : l'erreur de lecture s'affiche tronquée
    (« Erreur de l… ») à l'intérieur de la bulle.

  ⚠️ **Les médias envoyés AVANT ce correctif restent illisibles** : leur
  entité en cache n'a pas la fiche du média, et rien ne la recalcule. C'est
  visible à l'écran (« Image non disponible », erreur de lecture). Ça ne se
  répare pas tout seul — il faudrait renvoyer le média, ou purger le cache
  local de la conversation.

---

### ✅ Note vocale impossible à envoyer en conversation chiffrée (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Vérifié après correctif** : 4 notes vocales dans `mls_messages`,
  `content_type = voice`, chiffrées (1,7 à 4 Ko), chacune avec une échéance de
  **86400 s** — donc l'audio porte bien le minuteur éphémère. La bulle de
  l'expéditeur affiche le signe ⏱ dès l'envoi.

---

### ⬜ Messages éphémères — minuteur réparé, purge serveur (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Pose de l'échéance** : minuteur à 24 h dans une discussion, envoyer un
  texte. En base, `data->>'expiresAt'` vaut `created_at` + 24 h.
- [x] **Minuteur coupé** : remettre sur « Désactivé », le message suivant n'a
  plus de clé `expiresAt` du tout.
- [x] **Minuteur changé en cours de route** : passer de 24 h à 7 j, le message
  suivant prend la nouvelle durée sans redémarrer l'application (le réglage
  est relu à chaque envoi, jamais mémorisé).
  ✅ Passe du 2026-09-22 (~03:55–04:02), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : minuteur « 24 heures » (`autoDeleteAfterSeconds` 86400) →
  PZ1 part avec `expires_at` = +24,00 h ; puis « 7 jours » **sans relancer
  l'app** (604800) → PZ2 part à +168,00 h. Chez Salim (discussion ouverte),
  PZ1 et PZ2 arrivent en direct avec l'icône minuteur. Minuteur remis sur
  « Désactivé » ensuite (champ revenu à nul, comme avant).
- [x] **Messages déjà envoyés** : changer le minuteur ne touche pas les
  échéances des messages précédents.
  ✅ Passe du 2026-09-22 (~03:55–04:02), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : après le passage à 7 jours, PZ1 garde son échéance à +24 h
  (relue en base) ; les 53 messages des 3 h d'avant n'en ont pris aucune (relu en base).
- [x] **Expiration côté expéditeur — CORRIGÉ et vu à l'écran le 2026-09-15.**
  La bulle affiche bien la pierre tombale (icône + libellé), au lieu de
  disparaître. Cause : `conversation_screen.dart` filtrait la liste sur
  `!m.isDeletedFor(moi)`, or `isDeletedFor` vaut
  `deletedForEveryone || deletedFor.contains(moi)` — **tout** message supprimé
  pour tous, y compris un éphémère arrivé à échéance (que
  `videeParExpiration` marque exactement ainsi), était retiré AVANT d'atteindre
  la bulle. Le rendu de tombe de `message_bubble.dart` était donc du code
  inatteignable. Le filtre vise maintenant `deletedFor` seul ; la bulle sait
  déjà se taire pour un message supprimé pour moi seul.

  ⚠️ **Méthode** : quatre hypothèses ont été écartées avant celle-là (curseur
  de rattrapage, mélange UTC/local, aller-retour JSON du cache, verrou
  d'amorçage). Ce qui a tranché n'est aucune déduction mais une **sonde
  temporaire** dans `_fusionnerAvecMls` journalisant le contenu réel de la
  liste : elle a montré les entités présentes avec `deletedForEveryone=true`,
  donc écartées plus bas. Poser la sonde plus tôt aurait économné des heures.

  ⚠️ **Piège de recette** : antidater `expires_at` en SQL ne suffit pas à voir
  le libellé « supprimé automatiquement ». Le client garde SA date (venue du
  `ttl` du payload) : `isExpired` reste faux chez lui et la bulle dit
  « Message supprimé ». Pour voir le bon libellé, poser un minuteur COURT et
  laisser l'échéance passer des deux côtés.
- [x] **⛔ Le fil chiffré disparaissait entièrement au démarrage — CORRIGÉ.**
  Trouvé en cherchant la pierre tombale : trois messages MLS **vivants** en
  base (ciphertext non vide, `is_deleted` faux), **aucun à l'écran** après
  redémarrage, et **zéro ligne dans `mls_diagnostics`**. Dans le même
  processus le fil s'affichait ; seul le démarrage à froid perdait tout, et
  renvoyer un message le repeuplait — ce qui faisait passer la panne pour un
  caprice d'affichage. Cause : `MlsGateway.amorcer` sortait sur
  `_fil.containsKey(...)`, or `_mlsDuCache` rend `const []` dès que `mlsSince`
  est nul, et `mlsSince` vient d'une lecture réseau ; au démarrage `enMls`
  reste vrai **par le drapeau de compte** pendant que la date manque encore.
  Le premier appel posait `_fil[conv] = []` et verrouillait le fil pour toute
  la vie du processus. Corrigé : on ne verrouille que sur un amorçage non
  vide. Vérifié sur SM A515F le 2026-09-15 — message restauré sous le
  séparateur après démarrage à froid. Test :
  `lectures_conversation_chiffree_test.dart` § « amorçage du fil chiffré »
  (rougit bien sans le correctif).
- [x] **EN GROUPE aussi** — « Testeurs » (basculé, 2 membres), 2026-09-15 :
  minuteur 24 h posé depuis le menu du groupe, écrit en base ; message envoyé
  → `expires_at` avec un **écart de 86400 s exactement** ; le signe éphémère
  (⏱) apparaît **chez l'expéditeur dès l'envoi** ET **chez le destinataire**
  (donc recalculé depuis le `ttl` du payload, pas lu dans la colonne) ; la
  pierre tombale s'affiche des deux côtés. Rien de spécifique au groupe : le
  minuteur vit sur la conversation, quel que soit son type.
- [x] **Côté MLS**, drapeau ouvert : `mls_messages.expires_at` renseigné à
  l'envoi — **écart mesuré 86400 s exactement** — et `length(ciphertext)` à 0
  après purge. Vérifié sur SM A515F le 2026-09-15 (la conversation bascule à
  MLS dès son ouverture quand le compte est dans `mlsMessagesComptes`, si bien
  que c'est le chemin MLS et non le legacy qui a été exercé).
- [x] **Reste du point MLS — VÉRIFIÉ À DEUX TÉLÉPHONES le 2026-09-15.**
  Le Pixel 10 Pro XL ne porte PLUS la version du Play Store : il a un build
  **debug**, signé du même keystore que le SM A515F (`8732adee…c5`,
  `installerPackageName=null`). `install -r` y passe donc, données conservées.
  La note « irremplaçable sans désinstaller » était périmée.

  Message éphémère envoyé du A515F (Sim) → reçu **déchiffré** sur le Pixel
  (Salim) avec le **signe minuteur** : l'échéance est bien recalculée chez le
  destinataire depuis le `ttl` du payload. Et les pierres tombales s'y
  affichent « **Message expiré** » (icône minuteur barré), pas « Message
  supprimé ».

  ⚠️ **Écart de libellé entre les deux appareils, expliqué** : l'expéditeur
  affichait « Message supprimé » pour les mêmes messages. C'est un artefact de
  recette, pas un défaut — l'échéance avait été antidatée en SQL côté serveur
  seulement. L'expéditeur garde SA date (venue du `ttl`, donc future →
  `isExpired` faux → « supprimé »), tandis que le destinataire reconstruit
  l'entité depuis la ligne tombale et utilise donc la COLONNE, antidatée →
  « expiré ». En usage réel les deux dates coïncident et les deux écrans
  diraient « expiré ».

  ⚠️ **Aucun `decrypt_failed` lié aux tombes** (le garde tient) — mais
  **observation à part** : 11 `decrypt_failed` en rafale de 1,6 s sur le
  Pixel, `{"code":"openmls","epoch":0}`, sans `message_id`, juste après la
  réinstallation de l'app. Transitoires : le message suivant s'est déchiffré
  normalement et le fil s'affiche correctement. Piste possible d'une course au
  démarrage du moteur MLS — hors de cette fiche, à confirmer.

---

### ⬜ Aperçu et compteurs d'une conversation chiffrée (décision J, 2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Reçus de lecture écrits** : ouvrir la conversation sur le Pixel a
  posé 14 lignes dans `mls_message_receipts`, toutes au compte du Pixel, sur
  des messages reçus de l'autre compte. ✅ 2026-09-15. Reste à voir que les
  coches de l'expéditeur passent au bleu **sans rechargement**.
- [x] **Réaction sur un message REÇU** : posée depuis le Pixel sur un message
  de Sim A, elle atterrit dans `mls_message_reactions` (le cas RLS
  « participant sans être l'expéditeur »), et **revient sur la bulle après
  redémarrage**. ✅ 2026-09-15.
- [x] **Aperçu depuis le cache sur un message reçu** : la ligne de la
  discussion affiche « Hh », le vrai texte, et non le libellé générique.
  ✅ 2026-09-15.
- [x] **Réaction sur un message chiffré** : posée, elle atterrit dans
  `mls_message_reactions` et **revient sur la bulle après un arrêt complet**
  de l'application — donc lue depuis la table, pas gardée à l'écran.
  ✅ SM A515F, 2026-09-15. Le premier essai a **échoué en silence** : le
  durcissement des droits avait cassé l'`upsert` (voir « Un upsert PostgREST
  réécrit la clé primaire »). Reste à voir entre **deux** comptes.
- [x] **Supprimer pour moi** un message chiffré : la ligne atterrit dans
  `mls_message_hidden`, et après un **arrêt complet** de l'application le
  message **n'est plus dans le fil** — donc relu depuis la table, pas gardé
  à l'écran. ✅ Pixel 10 Pro XL, 2026-09-15. Reste à confirmer qu'il demeure
  visible en face.
- [x] **Supprimer pour tous** : `is_deleted` est posé sur la ligne, et après
  un **arrêt complet** la bulle affiche « Message supprimé » — donc relu
  depuis la base. La mention « modifié » survit à côté, ce qui est correct :
  le message a bien été modifié avant d'être supprimé. ✅ Pixel 10 Pro XL,
  2026-09-15. Reste à voir la bulle **du côté du destinataire**.
- [x] **Favori** posé sur un message chiffré : la ligne atterrit dans
  `mls_message_stars`. ✅ Pixel 10 Pro XL, 2026-09-15. Reste à voir qu'il
  tient après réouverture, et l'écran des favoris.
- [x] **Modifier** un message chiffré : un message `kind = 'control'` part,
  la cible reçoit `edited_at`, la bulle affiche le nouveau texte marqué
  « modifié », et **aucune bulle vide ne s'ajoute** — le contrôle n'apparaît
  pas dans le fil. ✅ Pixel 10 Pro XL, 2026-09-15. Reste à voir le résultat
  **du côté du destinataire**.
- [x] **« Modifier » n'apparaît que 25 minutes** : présent sur un message
  frais, absent au-delà (`canEdit`). ✅ 2026-09-15.

---

### ⛔ Le fil chiffré se tronque au redémarrage dès qu'un message arrive en direct (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Reproduire volontairement** : A envoie pendant que B a la discussion
  ouverte (livraison en direct), puis tuer et rouvrir B. Le message doit
  rester.
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA13LIVE reçu EN DIRECT sur le Pixel, arrêt complet, réouverture → présent, et tout le fil du jour (reçus en direct, modifié, avec réaction) survit à deux arrêts complets. ⚠️ Mais une forme voisine existe : sur le SM A515F, après une ouverture HORS LIGNE puis une réouverture en ligne, le fil a caché ~20 messages du jour (de « Tygg » mardi directement à PE1), revenus après une relance. Aucune perte en base.

---

### ⬜ Un fil chiffré survit au redémarrage de l'application (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Message propre à l'appareil**, application **tuée** puis rouverte :
  le message chiffré est toujours affiché en clair (`Ttg`, sous le
  séparateur), et `mls_diagnostics` ne porte aucun `decrypt_failed`.
  ✅ SM A515F, 2026-09-15. **Ce que ça prouve exactement** : l'amorçage
  depuis le cache (`MlsGateway.amorcer`). Sans lui le message aurait
  *disparu* du fil — `catchUp` saute mes propres messages, et le legacy n'a
  aucune ligne pour lui.
- [x] **Message REÇU d'un autre appareil**, déchiffré une fois, puis
  application tuée et rouverte. ✅ **Pixel 10 Pro XL (compte Salim L.)
  contre SM A515F (compte Sim A), 2026-09-15.** Deux messages reçus du
  SM A515F restent lisibles après arrêt complet, avec leur réaction. Et
  `mls_diagnostics` ne porte **aucun** `decrypt_failed` postérieur au
  redémarrage — les 11 antérieurs viennent de l'historique d'avant que ce
  Pixel ne rejoigne le groupe, ce qui est attendu. C'était le dernier P0 de
  cette entrée.
- [x] **Deux messages échangés**, application tuée, rouverte : vérifié le
  2026-09-15 sur SM A515F, dans « Mes notes ». Deux messages MLS envoyés,
  l'application relancée deux fois entre les deux (le système la tuait sous
  la pression mémoire du build debug), et le fil a montré le texte à chaque
  réouverture — jamais un placeholder.
- [x] **Un troisième message** arrive après la réouverture : il se déchiffre
  normalement (le curseur repris ne doit pas sauter ce qui est neuf).
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras) relancé à froid (00:39), resté au premier plan ; « PA22ECHEC »
  envoyé par Sim à 00:44:12 → affiché en clair dans la liste du Pixel ;
  `mls_diagnostics` : 0 ligne sur l'heure.
- [x] `mls_diagnostics` ne se remplit pas de `decrypt_failed` à chaque
  lancement : **zéro ligne** sur toute l'heure de l'essai, redémarrages
  compris. C'était le symptôme silencieux du défaut.

---

### ⬜ En sélection, la bulle ne fait plus que cocher (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Sondage en sélection** : toucher une option coche la ligne, aucun
  vote ne part. Vérifier ensuite **dans le sondage lui-même** (sortir du mode,
  rouvrir) qu'aucune voix n'a été enregistrée.
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0), 1:1 MLS, sondage PA22 : en sélection (1 sélectionné),
  toucher « Rouge » a basculé la ligne (sélection vidée, barre fermée) et
  **aucun vote** n'est parti (`post_poll_votes` = 0, carte « Aucun vote »).
- [x] **Double-appui en sélection** : aucune réaction ne se pose.
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : double-appui sur PK1 → coché puis décoché, aucune barre
  de réactions, 0 réaction en base sur PK1.
- [x] **Glissement horizontal en sélection** : ne passe pas en réponse.
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : glissé 150→700 px sur PK1 → rien, toujours « 2
  sélectionnés », aucun bandeau de réponse.
- [x] **Défilement de la liste en sélection** : toujours fluide — l'absorption
  ne doit pas gêner le `ListView`, qui est au-dessus et non dedans.
  ✅ Passe du 2026-09-22 (~05:15–05:30), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : « 1 sélectionné », glissés dans la zone du fil vers le haut et
  vers le bas → le fil défile dans les deux sens, la sélection reste. ⚠️ Un
  premier essai partait du bas de l'écran alors que le clavier était ouvert :
  les glissés ont tapé « 5⁵⁰ » dans le composeur (rien d'envoyé, champ
  vidé) — ce n'était pas une mesure du défilement.
- [x] **Appui long sur un deuxième message en sélection** : il s'ajoute à la
  sélection, sans rouvrir le menu d'actions.
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : appui long sur PJ2 → « 2 sélectionnés », aucune
  feuille d'actions.

---

### ⬜ « Sélectionner » sort de « Autres actions » (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Appui long sur un message texte** : « Sélectionner » se lit au premier
  écran, sans déplier « Autres actions ». Le toucher ferme la feuille et fait
  apparaître la barre « 1 sélectionné ».
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : appui long sur PH1 (reçu) → réactions, Répondre,
  Copier, Transférer à…, Ajouter aux favoris, **Sélectionner** au premier
  écran ; le toucher ferme la feuille, barre « 1 sélectionné ».
- [x] **Appui long sur un sondage** : même menu. La carte de vote ne doit pas
  avaler le geste — ses options sont tactiles, c'est le cas qui pouvait
  échouer.
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : appui long sur la carte du sondage PA22 → même menu,
  la carte n'avale pas le geste.
- [x] **En mode sélection, taper une option de sondage** coche le message
  au lieu de voter — corrigé depuis, voir « En sélection, la bulle ne fait
  plus que cocher ».
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : voir « En sélection, la bulle ne fait plus que cocher ».

---

### ⬜ Sondage : voter se voit enfin, et les votants aussi (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Voter dans une bulle de sondage** (DM et groupe) : la carte bascule
      aussitôt sur les pourcentages, l'option choisie reste encadrée, et le
      nom de l'auteur s'affiche en en-tête. (`poll_supabase_datasource.dart`,
      `poll_card.dart`)
- [x] **Quitter l'écran et revenir** : le vote est toujours marqué comme le
      sien. C'est ce qui ne tenait pas.
- [x] **« Modifier mon vote »** : la sélection se rouvre sur son propre choix ;
      en choisir un autre le remplace (l'ancien compteur retombe) ;
      tout décocher affiche « Retirer mon vote » et remet le total à zéro.
- [x] **Sondage à choix multiple** : plusieurs cases, total = nombre de voix.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : « PA22 Sondage multiple anonyme » créé dans le 1:1
      (`allow_multiple` et `is_anonymous` vrais en base) ; cases à cocher, Rouge +
      Vert → « Voter » → 50 % / 50 %, « 2 votes », `total_votes = 2` ; écran de
      résultats « Votre choix » sur les deux, 1 · 50 % chacun.
- [x] **Écran de résultats d'un sondage normal** : le badge « Votre choix »
      apparaît, et les votants sont listés sous chaque option, pour tous ceux
      qui voient le sondage. (`poll_results_screen.dart`, RPC
      `poll_option_voters`) — plus de « Aucun vote pour le moment » sous une
      option qui en a.
- [x] **Sondage anonyme** : vérifié SM A515F sur un vrai sondage anonyme du
      groupe Testeurs — la bulle dit « Vote anonyme », l'écran de résultats
      n'affiche aucun votant et porte « Sondage anonyme : personne ne voit qui
      a voté quoi », alors que le sondage a 2 voix. En base, sous l'identité du
      lecteur : `poll_option_voters` rend 0 ligne pour l'anonyme et 2 pour le
      sondage normal du même groupe.
- [x] **Créer** un sondage anonyme depuis la feuille (la bascule est éteinte
      par défaut) : c'est la seule moitié non rejouée à la main.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : bascule « Sondage anonyme » éteinte par défaut,
      allumée → notice « Sondage anonyme : personne ne voit qui a voté quoi. »
      sous les bascules ; publié, `is_anonymous = true`. Résultats : aucun votant
      listé, ni chez Sim ni chez Salim (Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras)).
- [x] **Un sondage créé avant cette version** reste non anonyme (défaut
      `FALSE`) : sa notice dit bien « vote public ».
- [x] **Deux téléphones en même temps** : le vote de l'un fait bouger le
      compteur chez l'autre sans quitter l'écran (temps réel).
- [x] **Échelle de police 1.3** : le pied de carte ne déborde pas, il passe
      à la ligne (vérifié SM A515F). Mais les deux boutons se retrouvent l'un
      sous l'autre avec « 2 votes » centré entre eux : c'est laid, et ça
      empire avec la police. À reprendre.
- [x] **Thème sombre** : carte vérifiée SM A515F — fond sombre, notice
      lisible en gris, option choisie encadrée en violet, pied sur une ligne.
- [x] **Thème sombre** : la feuille de création et l'écran de résultats.
      ⬜ moitié, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : écran de résultats vu en sombre sur le Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras) —
      lisible, options encadrées en violet clair, notice anonyme en gris. Feuille
      de création pas vue en sombre (le Pixel est le vrai compte : pas de sondage
      créé depuis lui).
      ✅ Passe du 2026-09-22 (~05:35–05:45), build Play 1.2.2+26 (f22aaff, contient 37465e9), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : la **feuille de création** en sombre — champs, bascules,
      notice « Les votes ne sont pas anonymes », durées (« Illimité » passe à la
      ligne à 1,3, sans coupure), « Publier » : tout lisible. Fermée sans publier
      (0 sondage créé). Détail : la feuille monte jusque sous la barre d'état,
      sa poignée passe par-dessus.
- [x] **Coin de queue de la bulle envoyée** : plus de triangle vert sous la
      carte — elle reprend les rayons de la bulle. Vérifié SM A515F sur les
      deux bulles envoyées et sans régression sur la bulle reçue.
      (`message_bubble.dart` passe `_getBorderRadius()`)
- [x] **Pied de carte sur une bulle reçue** (plus étroite qu'une bulle
      envoyée) : corrigé et revérifié SM A515F — « 2 votes » garde sa ligne,
      les deux actions sont alignées à droite dessous, aux échelles 1.0 et
      1.3, sans un seul avertissement de débordement dans logcat.
      (`poll_card.dart`, `_pied`)
- [x] **Avant la migration** : voter fonctionne toujours (repli sur l'ancien
      chemin), mais la liste des votants reste vide.

---

### ⬜ Un message non envoyé ne disparaît plus, et repart tout seul (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Écrire un message hors ligne**, quitter l'écran, y revenir : il est
      toujours là, marqué en échec, avec « Renvoyer ». Vérifié SM A515F le
      2026-09-14 : `FILE-ATTENTE-2` écrit radios coupées, écran quitté 18 s
      (au-delà des 5 s de grâce de l'`autoDispose`), toujours présent au
      retour — « ⚠ Non envoyé · Réessayer ».
      (`message_provider.dart`, `_avecMessagesJamaisPartis`)
- [x] **Renvoi manuel** : l'appui sur « Réessayer » envoie le message et la
      bulle passe à « Reçu ». Vérifié le 2026-09-14, une seule ligne en base,
      **aucun doublon**.
- [x] **Rétablir le réseau sans rien toucher** : il part seul, et la ligne de
      la liste se met à jour. (`RenvoiMessagesEnAttente`, tenu en vie par
      `app.dart`)
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA11OFF écrit en MODE AVION → « Non envoyé · Réessayer » ; mode avion coupé à 18:23:46 sans rien toucher → parti seul avant 18:24:24, une seule ligne, reçu et lu par Salim.

      ⛔ **A ÉCHOUÉ au premier essai (2026-09-14), correctif posé, non
      revérifié.** Une minute après le retour du réseau, rien n'était parti.
      La cause n'est pas le renvoi mais son **déclencheur** :
      `ConnectivityService.isConnected` vaut `!results.contains(none)`, et
      `connectivity_plus` liste `vpn` tant que le tunnel est debout. Le
      SM A515F porte un VPN permanent : couper les deux radios laisse donc
      l'app **se croire en ligne**, aucune transition `false → true` n'est
      émise au retour, et le déclencheur ne part jamais. Même illusion avec un
      portail captif. Ajout d'un battement de 60 s qui ne demande rien à
      personne (`RenvoiMessagesEnAttente.intervalleDeControle`) — c'est lui
      qu'il faut vérifier.

      ⚠️ **Et ça condamne la méthode de test elle-même** : `svc wifi disable`
      + `svc data disable` ne rend pas l'app hors ligne **à ses propres yeux**
      tant que le VPN tient. Pour éprouver un chemin qui dépend de
      `connectivityNotifierProvider`, il faut le **mode avion** (qui, lui,
      couche le tunnel) — ou couper le VPN d'abord. Ce détour explique aussi
      pourquoi les points ci-dessus ont réussi : le message n'est jamais passé
      par la branche « hors ligne », il a pris le chemin normal, a échoué, et
      c'est l'accroche sur l'échec qui l'a sauvé.
- [x] **Tuer l'app entre les deux**, puis la rouvrir en ligne : il part au
      démarrage — le renvoi ne dépend pas d'une transition de connectivité.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA12KILL « Non envoyé » en mode avion, force-stop, réseau rétabli, relance à 18:26:47 → envoyé à 18:26:54, lu 18:26:58.
- [x] **Échec en ligne** (et non hors ligne) : couper le réseau juste après
      l'appui sur envoyer. Même traitement — gardé, renvoyable.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0), 1:1 MLS : « PA22ECHEC » envoyé puis mode avion dans la
      même commande adb (00:42:39) → « Envoi… », puis « Non envoyé · Réessayer »
      après le délai ; rien en base. Mode avion coupé à 00:44:04 sans rien
      toucher → parti seul à 00:44:12, **une** ligne `mls_messages`, toujours une
      seule 90 s plus tard (le battement de 60 s ne l'a pas renvoyé) ; bulle
      « Envoyé ».

---

### ✅ Un échec de lecture en messagerie se voit, sans effacer l'écran — corrigé, vérifié SM A515F (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Hors ligne, démarrage à froid** : la liste s'affiche depuis le cache —
      ni rond de chargement sans fin, ni « aucune discussion », ni écran
      d'erreur. Vérifié SM A515F le 2026-09-14 (release md5 `77bdcfd0…`).
- [x] **Discussion ouverte hors ligne** : messages en place, liseré « Erreur de
      chargement » au-dessus du composeur, **composeur utilisable** (texte saisi,
      clavier, bouton d'envoi présent), et aucune mention de suppression.
      Vérifié SM A515F le 2026-09-14.
- [x] **Retour du réseau** : l'en-tête se remplit (+30 s) et le liseré disparaît
      (+70 s), sans quitter l'écran. Vérifié SM A515F le 2026-09-14.

---

### ✅ L'identité du correspondant revient seule après une coupure — corrigé, vérifié SM A515F (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Par lien profond, hors ligne** : plus de « Utilisateur » pendant que la
      session se restaure — l'en-tête reste sur « Chargement… » puis affiche
      « Salim L. ». L'interlocuteur se déduit de la conversation **par
      différence avec le compte courant** : tant que la session n'est pas
      restaurée, il n'y a personne à nommer, et `currentUser == null` compte
      donc comme identité en attente
      ([conversation_screen.dart:1199](lib/features/messages/presentation/screens/conversation_screen.dart:1199)).
      Vérifié SM A515F le 2026-09-14 (release md5 `9641765b…`).
- [x] **La fenêtre elle-même** — instruite le 2026-09-14, et refermée par les
      deux bouts. La cause : `authStateChanges`
      ([auth_remote_datasource.dart:574](lib/features/auth/data/datasources/auth_remote_datasource.dart:574))
      enchaînait en `asyncMap` **trois appels distants** — pont
      Firebase→Supabase, upsert, lecture de la ligne `users` — et n'émettait
      rien tant qu'ils n'avaient pas rendu la main. Hors ligne, ils mettent une
      à deux minutes à échouer : l'app n'avait aucun compte courant pendant tout
      ce temps, alors que Firebase tient l'utilisateur en mémoire dès son
      initialisation. L'identité locale part maintenant en première émission,
      l'enrichissement distant suit — et un échec ne termine plus le flux.
      ⚠️ Analysé et couvert par les tests, mais **son effet propre n'a pas été
      isolé sur appareil** : le semis ci-dessous masque désormais le symptôme.
- [x] **Le nom dès la première image**, sans passer par « Chargement… » : un
      flux n'émet jamais dans l'image du premier rendu, donc même avec tout en
      cache l'en-tête affichait son repli. `_semerIdentiteConnue()`
      ([conversation_screen.dart:189](lib/features/messages/presentation/screens/conversation_screen.dart:189))
      lit à l'ouverture trois sources locales et **synchrones** — uid Firebase,
      conversation en cache, profil en cache — et les pose comme valeurs de
      départ. Mesuré par rafale de captures (25 en 25 s) sur SM A515F le
      2026-09-14, lien profond en mode avion, release md5 `4b37b3c2…` : trois
      états seulement — écran de lancement, écran blanc, puis **« Salim L. »**.
      Aucune image ne montre « Chargement… ».
- [x] **Hors ligne, dès l'ouverture** : l'en-tête affiche « Salim L. » et son
      avatar « SL » sans attendre le réseau, et la liste des discussions ne
      montre plus « Utilisateur ». Vérifié SM A515F le 2026-09-14 (release md5
      `83a6ec4e…`) ; au retour du réseau, « En ligne » et la pastille de
      présence s'ajoutent.
- [x] **Après correction** : les quatre étapes rejouées sur la release du
      correctif (md5 `103379e7…`) — hors ligne l'en-tête affiche toujours son
      repli, puis **se remplit tout seul 20 s après le retour du réseau**
      (« Salim L. », « En ligne », pastille de présence), sans quitter l'écran
      ni redémarrer l'app. Vérifié SM A515F le 2026-09-14.

---

### ⬜ Actualisation automatique après coupure ou retour d'arrière-plan (2026-09-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Liste des discussions** : un correspondant écrit pendant que le
      téléphone est hors ligne ; rétablir le réseau → la ligne remonte et le
      compteur de non-lus apparaît, **sans** tiré-pour-rafraîchir.
      Vérifié SM A515F le 2026-09-14, rôles inversés (Salim écrit, Sim est
      hors ligne), coupure de 45 s, écran jamais touché :
      03:34 en ligne « …-LIGNE-1 · 03:28 · 1 » → 03:35 hors ligne, inchangée
      → réseau rétabli 03:35:46 → **03:36, 15 s après : « …-LIGNE-2 · 03:34 ·
      2 »**. Le logcat ne porte aucun événement FCM après la reconnexion (le
      seul est à 03:34:24, avant) : ce n'est pas un push qui a rafraîchi.
      (`message_supabase_datasource.dart`, `realtime_rattrapage.dart`)

---

### ⬜ Nom et avatar du correspondant dans la liste des discussions (2026-09-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Démarrage à froid**, app tuée puis relancée directement sur l'onglet
      Discussions : aucune ligne ne montre « Utilisateur » — ni au premier
      rendu, ni après une seconde. Vérifié SM A515F le 2026-09-13
      (`force-stop` puis `am start` : la ligne « Salim L. » et son avatar à
      initiales sont corrects d'emblée). (`profile_supabase_datasource.dart`,
      `conversation_item.dart`)
- [x] **Mode avion au lancement** puis retour réseau : la ligne se remplit
      seule, sans afficher « Utilisateur » entre-temps.
      Mesuré deux fois le 2026-09-14 (SM A515F, release du jour), deux
      résultats : la liste s'est peinte depuis le cache en affichant
      **« Utilisateur »**, puis, au second essai, est restée sur un **rond de
      chargement sans fin** — ni liste, ni erreur. Dans les deux cas elle s'est
      remplie seule au retour du réseau (« Salim L. » et son avatar à +75 s) :
      c'est la seconde moitié de l'exigence qui tient, pas la première, donc la
      case reste ouverte. L'en-tête d'une discussion, lui, ne se rattrape pas —
      voir « ✅ L'identité du correspondant revient seule après une
      coupure ».
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : mode avion, `force-stop`, `diasponiger://messages` →
      liste peinte depuis le cache avec « Salim L. » (SL) et « Test Appareil »
      (TA), **aucun « Utilisateur »** ; réseau rétabli : inchangé, toujours aucun
      « Utilisateur » (3 relevés à 3 s).
      ⛔ **Défaut nouveau, même famille, autre écran** : « Nouvelle conversation »
      → « Contacts récents » affiche **trois lignes « Utilisateur »** avec l'initiale
      « U ». Cause, par le code : `_buildRecentTile`
      (`new_conversation_screen.dart`) écrit `conversation.name ?? l10n.user` et
      `conversation.imageUrl` — or la section ne garde que des 1:1
      (`isIndividual`), qui n'ont pas de `name` : le correspondant n'est jamais
      résolu par son profil comme le fait la liste.
      **Corrigé le 2026-09-22** (branche `claude/trois-defauts-2209`) : la tuile
      lit `userStreamProvider(autre)` comme `ConversationItem`, garde
      `test/features/messages/passe_adb_2209_trois_defauts_test.dart`.
- [x] **« Mes notes »** (fil à participant unique) : titre correct — vérifié
      SM A515F le 2026-09-13. L'absence de requête de profil sur identifiant
      vide, elle, ne se voit pas à l'écran : elle tient à la garde
      `otherUserId.isNotEmpty`.

---

### ⬜ Sondage dans une discussion privée (2026-09-12)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **« + » dans une DM** : « Sondage » présent ; créer (question + 2
  options) → bulle sondage chez les deux ; Sim vote, Salim voit le compte.
  (`conversation_screen.dart`, `create_poll_sheet.dart`,
  `poll_supabase_datasource.dart`)
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : « + » du 1:1 MLS sur le SM A515F (Sim, clair, police 1,0) → « Sondage » présent (avec
  Caméra, Photos, Documents, Position, Événement) ; question + 2 options →
  bulle chez Sim ; après relance à froid, bulle chez Salim (Pixel 10 Pro XL (Salim, sombre, police 1,3 + gras)) avec
  « Vote anonyme » et « 2 votes » (les deux voix de Sim).

---

### ⬜ Réactions : double tap, cœur rouge, notification, mise à jour (2026-09-12)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Double tap** sur une bulle (texte, photo, emoji seul) : une barre
  flottante au-dessus de la bulle avec 👍 ❤️ 😂 🙏 😮 et un « + ». Choisir un
  emoji le pose ; toucher à côté ferme sans rien poser ; la barre ne sort
  jamais de l'écran (bulle tout en haut → barre en dessous).
  (`reaction_picker.dart`, `message_bubble.dart`)
  ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0), 1:1 MLS : double tap sur PH1 → barre 👍 ❤️ 😂 🙏 😮 +
  au-dessus de la bulle ; toucher à côté la ferme, aucune ligne en base ; sur
  la bulle du HAUT (PE1, juste sous l'en-tête) la barre reste à l'écran en
  recouvrant l'en-tête (y 132–248) — elle ne passe pas dessous, mais ne sort
  pas. ❤️ choisi dans la barre : posé (`mls_message_reactions`). Photo et
  emoji seul non essayés (pas de photo à envoyer, cf. règles de la passe).
- [x] **« + »** (barre du double tap ET feuille d'appui long) : ouvre le
  sélecteur complet, recherche comprise (le clavier remonte la feuille) ;
  l'emoji choisi est posé.
  ⬜ moitié, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : « + » de la barre du double tap → sélecteur
  complet ; la loupe fait monter le clavier ET la feuille (champ visible) ;
  « fire » → 🔥 posé sur PH1, une ligne en base. « + » de la feuille d'appui
  long non essayé. L'onglet récents dit « No Recents » en anglais — déjà
  consigné, corrigé pour le +28 (« Manquements de la passe du 2026-09-21 »).
  La recherche du sélecteur est en mots-clés anglais (« fire »).
  ✅ Passe du 2026-09-22 (~05:15–05:30), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : la moitié « feuille d'appui long » — « + » de la feuille sur
  « Hi » → sélecteur complet (9 onglets), loupe → clavier et champ visibles,
  « sun » → ☀️ posé sous la bulle ; retiré ensuite par le même chemin.
- [x] **Notification** : Sim réagit à un message de Salim → Salim reçoit
  « Sim · A réagi ❤️ à votre message », app fermée comme ouverte ; le tap
  ouvre la discussion. Changer d'emoji ne fait pas une 2e ligne en base
  (l'écran Notifications ne montre plus les réactions depuis le 2026-09-13 —
  voir « La messagerie sort de l'écran Notifications »).
  Aucune bannière si la discussion est déjà ouverte, ni si elle est en
  sourdine.
  ⬜ en partie, Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff) : Sim pose 🔥 puis le remplace par ❤️ sur PH1 →
  **une seule** ligne `mls_message_reactions` (❤️) et **une seule** ligne
  `notifications` pour Salim (`messageReaction`, « Sim A » / « A réagi ❤️ à
  votre message ») ; bannière lue dans le volet du Pixel
  (`dumpsys notification --noredact`), app ouverte sur Réglages. Pas fait :
  app fermée, tap sur la bannière, discussion ouverte, sourdine.
  ⬜ presque, Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (PK1 de Salim) :
  - discussion **ouverte** sur le Pixel : 😂 → ligne `notifications` créée,
    **aucune bannière** dans le volet ;
  - app **fermée** (HOME + `am kill`) : 😂 → 🙏 → bannière « Sim A · A réagi 🙏
    à votre message », et toujours **une seule** ligne `notifications` ;
  - **tap** sur la bannière (volet ouvert par `cmd statusbar`) → ouvre la
    discussion avec Sim A, bannière retirée.
  Reste : la sourdine.
  ✅ Passe du 2026-09-22 (~03:10–03:17), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : la **sourdine** aussi — Sim met le 1:1 en sourdine depuis la
  liste (`mutedBy` : `forever`), Salim réagit 😂 à PV3 → réaction enregistrée,
  **aucune** notification ni bannière chez Sim. Sourdine levée ensuite
  (« Réactiver les notifications »), `mutedBy` revenu à `{}` comme avant.

---

### ⬜ Aucun marqueur technique dans une bulle (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le vrai test du correctif**, moitié faite (SM A515F, 19:46) : le 1:1
      « Salim L. » ouvert, quitté, rouvert — « Yo », la note vocale, la carte
      de position, « test-logs » et le message qui venait d'arriver sont tous
      restés lisibles, aucun marqueur. ⚠️ **Le pull-to-refresh et la remontée
      d'une page restent à faire** : le glissé lancé depuis le milieu du fil
      est tombé sur la **carte de position**, qui l'a pris pour un tap et a
      ouvert Google Maps. Repris depuis la marge gauche (x=90) : **même
      résultat**, la carte s'ouvre encore — dans ce fil-là, la rangée du
      message est cliquable sur toute la largeur. La remontée a donc été faite
      dans « Groupe de test privé » (20:14), fil sans carte : le défilement
      jusqu'au 30 août marche et les 4 vidéos restent intactes. Reste à
      refaire sur un fil de **texte** long.
      **✅ Fait le 2026-09-11 18:45, SM A515F, 1:1 « Salim L. »** (fil mixte :
      textes, note vocale, carte de position, cartes de partage). Geste lancé
      **depuis la marge gauche (x=60)**, ce qui évite la carte qui captait les
      glissés précédents : rafraîchissement, puis remontée d'une page. Aucun
      marqueur n'apparaît — ni « Message indisponible », ni « clé de groupe
      introuvable », ni « [Message illisible] » — et les bulles déjà lisibles
      (dont `CLEF-TEST`, `REPONSE-TEXTE…`, la note vocale et la carte) le
      restent. C'est le chemin qui, avant le correctif, réécrivait un marqueur
      par-dessus du texte déchiffré.
- [x] Écho temps réel : la bulle garde son texte (SM A515F, 19:47).
      `ECHO-DM-1947` envoyé dans le 1:1 est passé à `· Reçu` en gardant son
      texte — `reconcileEchoContent` fait son travail. ⚠️ Fait en **1:1**, pas
      en groupe : l'envoi de groupe était cassé (voir la section « Un groupe
      dont on est le seul membre » ci-dessous), donc le chemin Sender Key de
      `reconcileEchoContent` n'est toujours pas exercé.
- [x] Une conversation 1:1 avec du contenu s'affiche normalement — texte en
      clair, note vocale, carte de position, aucun placeholder (Pixel, 19:31).
- [x] Les médias **sans légende** ne sont pas détournés par la garde : un fil
      de 4 vidéos s'affiche intact (SM A515F, 19:20). C'était le risque du
      choix « la LISTE plutôt qu'`isUndecryptableContent` ».

---

### ✅ Vidéos envoyées en messagerie traitées comme des documents (2026-08-30)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Envoyer une vidéo depuis la caméra unifiée (`CameraCaptureScreen`),
  mode vidéo explicite, sur SM A515F** : bulle `VideoBubble` correcte
  (cadre 16:9, bouton lecture), confirmée sur le build reconstruit à neuf.
- [x] **Taper sur une bulle vidéo reçue → `VideoPlayerScreen` en plein écran,
  sur SM A515F** : lecteur ouvert, barre de progression et minuteur actifs.
- [x] **Vérifier que l'onglet vidéos de la galerie média liste bien les
  nouvelles vidéos envoyées, sur SM A515F** : « Options de la conversation »
  → « Médias partagés » → onglet « Vidéos · 3 » affiche bien les 3 vidéos
  envoyées dans la conversation, en grille avec vignette + bouton lecture.

---

### ✅ Bulle de chargement d'une vidéo pendant l'upload (2026-08-30)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Envoyer une vidéo (caméra unifiée) et observer la bulle pendant
  l'upload, sur SM A515F** : vignette assombrie + badge caméra + anneau de
  progression affichés (capture prise pendant l'upload, avant la fin) ; la
  bulle finale devient bien `VideoBubble` à la fin, aucune régression.

---

### ✅ Badge de durée manquant sur les bulles vidéo (2026-08-30)

En vérifiant le point précédent sur appareil, aucune des vidéos envoyées
n'affichait le badge de durée (coin haut droit) que `VideoBubble` sait
pourtant déjà dessiner (`if (duration != null) ...`). Cause : rien dans
[message_repository_impl.dart](lib/features/messages/data/repositories/message_repository_impl.dart)
`sendFileMessage` ne calculait `videoDuration` avant l'envoi — le champ
existait de bout en bout côté modèle/datasource/DB (déjà utilisé par
Fil/Stories/Podcasts via `VideoUploadService`) mais jamais alimenté côté
messagerie. Corrigé en lisant la durée localement via
`VideoCompress.getMediaInfo` (déjà une dépendance du projet, méthode qui ne
compresse pas — lecture de métadonnées seule) avant l'upload, même schéma que
`audioDuration` juste au-dessus dans la même fonction. `flutter analyze`
propre sur tout le dépôt.

- [x] **Envoyer une vidéo et vérifier que le badge de durée apparaît, sur
  SM A515F** : badge « 🎥 0:02 » en coin haut droit sur la bulle envoyée
  (clip de 3 s), lecture correcte de la durée réelle.

---

### Discussion — heure absente/dupliquée sur les bulles média (2026-08-30)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Message d'appel** ✅ **vérifié 2026-08-30 sur SM A515F, deux fois** :
  rafale de 6 appels consécutifs (manqués sortants/entrants + un décroché
  15 s), chacun affiche sa propre heure dans la ligne de statut (« Pas de
  réponse - 23:40 », « Appel terminé - 23:44 »…) — jamais deux fois la
  même, jamais absente. Reconfirmé sur un second `flutter run` tout frais
  (pas un hot reload de la même session) pour écarter un état résiduel.
  Restent non vérifiés sur appareil : appel de groupe, et le cas décliné
  (`isDeclined`, libellé orange).

---

### ⬜ GIFs via `gif-proxy` — clés sorties de l'APK (2026-08-27)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Onglet GIFs : les tendances se chargent (chemin `trending`)
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (SM A515F).
- [x] Onglet Stickers : fonds transparents (paramètre `type=sticker`)
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS.
- [x] Envoyer un GIF dans une conversation aboutit toujours
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS.

---

### Heure/accusé masqués au tap sur une rafale envoyée (2026-08-14)

> **Obsolète depuis le 2026-08-23** : la bascule décrite ci-dessous a été
> supprimée, l'heure s'affiche désormais sur tous les messages. Voir
> « Heure et accusé sur tous les messages, bascule supprimée ».

[message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart) :
un message envoyé qui n'est pas le dernier d'une rafale masquait déjà son
heure par regroupement visuel, mais sans aucun moyen de la consulter
individuellement. Un tap sur la ligne meta (zone masquée sous la bulle) la
révèle, un second tap la remasque. Les messages reçus ne sont pas concernés.

- [x] **Testé sur SM A515F** (build debug fraîchement compilé) : conversation
  avec deux messages envoyés consécutifs (« bvvgc » puis « bvvgcv »). Le
  premier n'affiche aucune heure par défaut ; un tap sur la zone sous la
  bulle révèle « 19:55 · Lu » ; un second tap la remasque. Le dernier message
  de la rafale (« bvvgcv ») et tous les messages reçus affichent leur heure
  en permanence, sans interaction, comme attendu.

---

### Réactions emoji : une par personne et par message (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Poser une réaction (appui long → sélecteur rapide), la voir
  apparaître avec la bonne surbrillance — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  compte « Sim A », groupe « Groupe de test privé ». Le chip ❤️ apparaît avec
  bordure/fond teintés (couleur d'accent), et un appui long ultérieur montre
  bien l'émoji comme sélectionné dans la rangée rapide.
- [x] **Reposer la même réaction → elle disparaît (toggle off) — VÉRIFIÉ SUR
  SM A515F (2026-08-13)** : re-sélectionner 😂 depuis la rangée rapide retire
  le chip.
- [x] **Poser un emoji différent sur un message déjà réagi par soi →
  remplace l'ancien, ne l'additionne pas — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  ❤️ posé, puis 😂 sélectionné → un seul chip (😂) reste affiché, pas deux.
- [x] **Fiche message (appui sur l'accusé « Envoyé ») → onglet Réactions liste
  qui a réagi et avec quel emoji — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  « Réactions · 1 » dans les onglets, détail « Sim A — ❤️ » correct. Avant le
  correctif cet onglet était toujours vide (service RTDB mort) ; confirmé
  qu'il lit maintenant la vraie donnée.

---

### Retour à la ligne des bulles de discussion après l'agrandissement du texte (2026-08-13)

`fontSize` du texte des bulles porté à 17 (texte, liens, mentions) et padding
interne desserré (14/10/8) dans
[message_bubble.dart:2156](lib/features/messages/presentation/widgets/message_bubble.dart:2156)
— la taille précédente (15, puis 16) était jugée trop petite. Vérifié sur
SM A515F : les bulles existantes (messages courts « Salut », « Yo », « Hi »)
s'affichent sans overflow, mais un essai d'envoi d'un message long depuis
l'appareil (`adb shell input text`) n'a pas abouti — le champ ne recevait pas
le texte tapé — donc le retour à la ligne sur un message qui remplit toute la
largeur de la bulle n'a jamais été vu en vrai à cette taille de police.

- [x] **Envoyer un vrai message long, `font_scale` par défaut — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  - **1:1** (conversation « Salim L. ») : message réel envoyé par Salim
    (« Ceci est un message test assez long pour verifier que le texte se
    replie bien dans la bulle sans depasser ni tronquer quoi qui arrive. »)
    — se replie proprement sur 5 lignes, aucun débordement.
  - **Groupe** (« Diaspora Niger — Canada ») : le message de stress-test
    existant (~2000 caractères, alternant texte et segments de type
    téléphone auto-liés) se replie entièrement dans la largeur de la bulle,
    y compris aux frontières des segments liés, sans dépassement horizontal.
  - Tentative d'envoi d'un nouveau message dans un troisième groupe
    (« Groupe de test privé ») interrompue par des redémarrages concurrents
    de l'app (rebuilds/réinstalls de Salim en parallèle sur le même
    appareil) puis un état « Connexion en cours... » resté bloqué >40s —
    observation isolée, pas reproduite volontairement, probablement liée au
    nombre de kill/reinstall consécutifs plutôt qu'au correctif de police.
- [x] **`font_scale` à 1.1 — VÉRIFIÉ SUR SM A515F (2026-08-13)** : réglé via
      `adb shell settings put system font_scale 1.1` (déjà actif au moment du
      test, probablement réglé par Salim). Vérifié en paysage (l'appareil a
      basculé d'orientation plusieurs fois pendant le test, hors de mon
      contrôle) :
  - **1:1** (« Salim L. ») : le même message test se replie proprement sur
    2 lignes (largeur plus grande en paysage), toujours aucun débordement.
  - **Groupe** (« Diaspora Niger — Canada ») : la fin du message de
    stress-test s'affiche sur 2 lignes, entièrement contenue dans la bulle
    envoyée, aucun débordement.
  - ⚠ **Débordement réel observé, mais ailleurs** : `BOTTOM OVERFLOWED BY
    43 PIXELS` sur l'**aperçu du brouillon du composer** (pas une bulle
    envoyée) quand un brouillon très long (le brouillon de stress-test
    existant, 224/2000 caractères) est combiné au clavier ouvert en
    paysage. Correspond au défaut déjà loggé par Salim (commit
    `a9b1fa5`/`6d86b58`, « reconfirme overflow paysage 47px avec brouillon
    de 2 lignes ») — reproduit indépendamment ici à 43px, même famille de
    bug, pas un nouveau défaut de ce correctif-ci.

---

### Accusés livré/lu séparés — sheet infos du message (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] ~~Migration à déployer~~ — fait le 2026-08-13, en deux temps :
  [20260813120000_split_delivered_from_read.sql](supabase/migrations/20260813120000_split_delivered_from_read.sql)
  puis [20260813130000_fix_receipts_uuid_type_and_anon_grant.sql](supabase/migrations/20260813130000_fix_receipts_uuid_type_and_anon_grant.sql)
  — la première utilisait un paramètre `UUID` copié de l'ancienne RPC alors que
  `messages.conversation_id` est en réalité `TEXT` sur le distant (jamais
  `UUID`, malgré ce qu'affirmait `20260727180000`) : la RPC livrée existait
  mais plantait à chaque appel (`operator does not exist: text = uuid`),
  avalé en silence par le `catch` Dart. Bonus découvert au passage : une
  `mark_messages_as_read(TEXT, TEXT)` orpheline traînait déjà côté distant,
  sans vérification de participant et **accessible à `anon`** — remplacée par
  la version correcte. Cause structurelle notée dans la migration : le
  `REVOKE ALL ... FROM PUBLIC` classique ne retire pas l'accès `anon`, accordé
  directement par `ALTER DEFAULT PRIVILEGES` sur ce projet — probablement vrai
  pour d'autres RPC du projet, **non auditées ici**.
- [x] **`mark_messages_as_read` re-testée le 2026-08-30 avec deux vrais comptes** (transaction annulée, zéro donnée persistée) :
  - 1:1 réel (conversation `bb974232-…`, comptes `U64HK…`/`DfSyA…`) : un appel du vrai destinataire pose `readBy`+`readAt` **et** `deliveredTo`+`deliveredAt` en un seul passage (« lire implique avoir reçu », comme documenté dans la RPC) ; un second appel est sans effet (idempotent, pas de doublon).
  - Groupe réel (conversation `53fac82c-…`, 3 comptes) : un message déjà lu par 1 participant, lu ensuite par le 3e (compte réel `czk5U…`, jusque-là absent) → `readBy` passe correctement à 3 entrées (sender + 2 lecteurs), ce qui alimente `groupReadCount` (`message_bubble.dart:2438`) et donc « Vu par 2 ».
  - Reste non fait : la confirmation **à l'écran** (bascule visuelle du coche + sheet Infos en direct). Tentée sur le SM A515F mais **abandonnée** — l'écran a changé tout seul entre deux captures (menu conversation → Médias partagés) sans action de ma part, signe d'une session déjà active sur l'appareil (Salim ou l'autre agent) ; réflexe [[project_device_testing]] : ne pas insister dessus.
  - **Deuxième tentative, même session** : l'appareil (compte `vQZE…`, « Sim A ») s'est stabilisé sur la conversation « Salim L. » — la longue instabilité venait en fait de l'horloge de la barre de statut (change chaque minute), pas d'un humain qui naviguait ; le hash-diff toutes les 20 s ne pouvait donc jamais atteindre 3 checks identiques. Un message de test réel envoyé depuis l'appareil (`test-verif-lu-auto-2026-08-30`, conversation `debef5f0-…`, compte `vQZE…` → `U64HK…`) s'affiche bien « Envoyé » à l'écran, confirmé côté base (`deliveredTo`/`readBy` ne contiennent que l'expéditeur). Étape suivante bloquée : appeler `mark_messages_as_read` pour de vrai (hors transaction annulée) comme le ferait le compte `U64HK…` en ouvrant la conversation a été **refusé par le classificateur de permissions Claude Code** (écriture directe en prod via `supabase db query --linked`, même sur un message de test) — cohérent avec [[project_device_testing]] (« la première voie a été refusée… lui expliquer le blocage et proposer l'alternative »). Pour finir cette case : soit Salim ouvre lui-même le compte `U64HK…`/« Salim L. » (autre appareil ou session web) et lit ce message de test pendant que l'appareil `vQZE…` reste à l'écran pour voir le coche passer au bleu, soit il autorise explicitement l'action en base pour la prochaine tentative.
- [x] ~~Auditer les autres RPC `SECURITY DEFINER` du projet pour le même trou
  `anon`~~ — fait le 2026-08-13. ~45 fonctions `SECURITY DEFINER` accessibles
  à `anon` passées en revue (corps + appelants Dart). Sept avaient un vrai
  trou (aucune vérification d'appelant, pas seulement le grant par défaut) :
  - 🔴 **`lock_escrow_for_release(uuid, text)`** — libère l'escrow d'une
    commande marketplace (déclenche le virement Stripe). `p_caller_id = NULL`
    contournait entièrement le contrôle d'appartenance ; même renseigné,
    c'était une valeur fournie par l'appelant, jamais vérifiée contre une
    session. Seul appelant légitime : l'Edge Function
    `process-escrow-release`, qui valide déjà le JWT et appelle en
    `service_role`. Corrigé en fermant l'accès direct anon/authenticated
    (`service_role` uniquement) et en rendant le contrôle NULL strict.
  - 🟠 **`e2ee_add_active_device`/`e2ee_remove_active_device(text, text)`** —
    zéro vérification : n'importe qui pouvait ajouter/retirer un appareil de
    la liste des appareils actifs E2EE **de n'importe quel utilisateur**
    (risque d'écoute via un appareil injecté, ou déni de service en retirant
    les appareils d'une victime). Corrigé : `p_user_id` doit désormais
    matcher `firebase_uid()`.
  - 🟠 **`consume_one_time_prekey(text, text)`** — cross-utilisateur par
    conception (Alice consomme une clé de Bob), mais accessible sans compte
    du tout, ce qui rend l'épuisement du stock de clés gratuit et anonyme.
    Relevé à « authentifié » minimum.
  - 🟡 **`increment_column`** — allowlist déjà en place (compteurs Heritage),
    mais aucune vérification d'appelant. Relevé à « authentifié ».
  - Voir [20260813150000_close_anon_rpc_holes.sql](supabase/migrations/20260813150000_close_anon_rpc_holes.sql).
    Testé sur le distant en transaction annulée (rien persisté) : le bug
    NULL de l'escrow est bien fermé (preuve indirecte — l'appel avec le bon
    buyer_id n'aurait pas pu réussir si un appel précédent avait déjà fait
    passer `escrow_status` à `releasing`).
  - ~15 RPC de compteurs vanité (likes/vues/partages posts, podcasts,
    produits) : anon peut gonfler des métriques, aucun impact
    données/argent — **non corrigées**, laissées telles quelles.
  - `delete_group`, `accept_friend_request`, `insert_group`,
    `join_group_conversation`, `create_user_notification`,
    `get_or_create_official_group`, `get_feed_reposts` : déjà correctement
    gardées en interne (ou lecture de contenu déjà public) malgré le grant
    `anon` inutile — pas des trous réels.
  - 🔴 **Découverte plus large, non corrigée** : `anon` a en fait
    INSERT/UPDATE/DELETE au niveau **table** sur quasiment tout le schéma
    public (`users`, `messages`, `orders`, `payment_accounts`,
    `transactions`, `escrow_transactions`, `e2ee_user_keys`,
    `admin_audit_logs`...) — même `ALTER DEFAULT PRIVILEGES` que pour les
    fonctions, mais sur les tables. RLS est donc la **seule** barrière,
    projet entier, sans aucun filet au niveau des droits. Conséquence
    directe : `array_append_unique`/`array_remove_element` (mutateurs
    génériques sans allowlist, appelés aujourd'hui seulement sur
    `audio_rooms`) restent exploitables sur n'importe quelle table si sa RLS
    a un trou — non auditée table par table, périmètre bien plus large
    qu'une session. **Prochain audit à faire : lister les accès anon
    réellement nécessaires (signup, vérif téléphone, lecture profils
    publics...) avant d'envisager un `REVOKE` généralisé — risque réel de
    casser des parcours anonymes légitimes si fait à l'aveugle.**

---

### Messagerie — un filtre sans résultat n'est pas une messagerie vide (2026-08-06)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Puce « Non lus », tout étant lu** : « Aucun message non lu » + le lien
      « Afficher toutes les conversations », et **pas** la fiche 9e. Le lien
      doit ramener sur « Tous » avec la liste complète.
      ✅ Passe du 2026-09-22 (~01:55), build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair) : tout lu → « Aucun message non lu » et le bouton « Afficher toutes
      les conversations », pas la fiche 9e ; le bouton ramène sur « Tous », liste
      complète (Mes notes, Salim L., Testeurs, Diaspora Niger — NE…).
- [x] **Archives vides** et **recherche sans résultat** : inchangés, ils ont
      leurs propres états vides depuis toujours.
      ⬜ moitié, Passe du 2026-09-22 (~01:55), build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair) : puce « Archives » → « Aucune conversation archivée ».
      Recherche sans résultat pas faite : la passe a été arrêtée (quelqu'un s'est
      servi du téléphone).
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), SM A515F : recherche « zqxw » → « Tout · 0 / Personnes · 0 /
      Conversations · 0 » et « Aucun nom ne correspond à « zqxw ». ».

---

### Discussion — l'horodatage sort de la bulle (fiches 4a/6b, 2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Accusé de réception en toutes lettres** (vu 2026-08-05, SM A515F, nocturne) : « 22:15 · Envoyé » et
  « 12:06 · Envoyé » lus a l ecran, coches et pastille bleue disparues.
  Restent a voir « Reçu », « Lu » et « Vu par N » — il faut un second
  appareil. Ancien libelle :
  « · Reçu », puis « · Lu » (bleu) — et « · Vu par N » en groupe. Les trois
  coches cerclées et la pastille bleue ont disparu. Vérifier surtout que la
  ligne ne devient pas trop longue sur un message court à font_scale 1.1 : le
  libellé est nettement plus large qu'une coche de 18 px.

---

### Discussion — ÉCO rejoint la ligne épinglée (fiche 6b, 2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Avec une épingle** (vu 2026-08-05, SM A515F, nocturne) : le bandeau « Message épinglé 1 · 1/3 » et la
  pastille « ⊕ ÉCO » tiennent bien sur une seule ligne, sans sous-barre.
  Reste a verifier avec un titre long :
  seule ligne, le bandeau prenant la place qui reste. Vérifier qu'un titre long
  s'ellipse au lieu de pousser la pastille hors de l'écran.

---

### Composeur — l'emoji est sorti du champ, puis y est revenu (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Largeur du champ** (2026-08-05) : c'est ce point qui a fait revenir
  l'emoji dans la pilule. Verrouillé par un test — la pilule garde plus des
  deux tiers de la largeur du composer. Reste à confirmer à font_scale 1.1.
- [x] **Bascule emoji ↔ clavier** (vu 2026-08-05, SM A515F, nocturne) : la pastille passe bien au glyphe
  clavier a l ouverture du panneau. Detail :
  d'intensité de fond quand le panneau est ouvert ; en nocturne le fond pastel
  est remplacé par l'accent teinté (`#F4A574` à 18/28 %) — vérifier qu'il ne
  fait pas un pavé lumineux.
- [x] ⚠ **« Plus rien dans la pilule à part le texte » n'est plus vrai** — la
  pastille emoji y est retournée le 2026-08-05, sur demande de Salim (« la
  pilule est trop étroite »). Voir la section suivante : les quatre commandes en
  ligne coûtaient 176 dp de chrome sur 393. La contrainte technique du lot C
  tient toujours (la pastille reste entièrement à droite du champ, elle
  n'empiète pas dessus) et son test passe, **mais l'intention « pastille
  autonome » de la fiche 26b est entamée**. À arbitrer avec Salim si la fiche
  l'exige explicitement.

---

### Composeur — largeur de la pilule et « + » en clair (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **La pilule était trop étroite.** Trois pastilles autonomes de 44 plus
  quatre écarts = 176 dp de chrome : il ne restait que 217 dp de pilule (55 % de
  l'écran) et 51 % pour le texte. Un message qui tenait en 4 lignes en prenait 6.
  Corrigé en rendant la pastille emoji à la pilule et en resserrant la géométrie
  (marges 10 → 6, écarts 8 → 6, « + » et emoji 44 → 40 ; le bouton d'envoi garde
  44, c'est l'action principale). **Pilule 55 % → 73 %, champ 51 % → 58 %.**
- [x] **Le « + » était invisible en thème clair.** Relevé au pixel sur la
  capture : l'aplat du bouton et le fond de page donnaient **la même valeur**,
  `#F2E5D9` — l'accent à 12 % posé sur le crème, ce sont deux teintes
  identiques. Il n'y avait pas de bouton à l'écran, juste un glyphe orange.
  Il reprend désormais la surface de la pilule (blanc `#FFFFFF`, même liseré,
  même ombre) : relevé après correctif, disque `#FFFFFF` contre page `#F2EEE8`.
  Effet de bord utile : l'état « ouvert » passe au pêche `#EBD5C5` et devient
  franc, alors qu'il glissait avant de 12 % à 20 % d'un aplat déjà invisible.
  **Le thème sombre n'est pas touché** — le disque brun y ressortait déjà.
- [x] **Les deux thèmes vérifiés à l'écran**, barre recadrée et agrandie ×2 : la
  pastille emoji pêche sur la pilule blanche se détache bien (ma crainte qu'elle
  s'y noie était infondée), le badge cadenas n'est pas rogné par le bord, la
  pastille ne touche pas l'angle arrondi. Zéro `RenderFlex … overflowed` dans le
  tampon. ⚠ Le mode nuit du téléphone a été basculé en `no` pour le test puis
  **remis sur `yes` / `ui_night_mode=2`**, son état d'origine.
- [x] **Gestes vocaux — 3 sur 4 vérifiés** (2026-08-05, 06:05 → 06:11, « Mes
  notes », thème sombre, font_scale 1.1). Injection d'un vrai flux tactile via
  `input motionevent DOWN/MOVE/UP` chaîné dans **une seule** commande shell —
  Flutter le traite comme un doigt. La méthode par `input tap` successifs ne
  marche pas : l'écran bouge entre la capture et l'action.
  - **Appui long → enregistrement** : bandeau, minuterie, waveform, indicateur
    de verrouillage. Fonctionne.
  - **Glisser à gauche → annulation** : bandeau rouge, poubelle, et au
    relâchement **rien n'est envoyé**. Fonctionne.
  - **Glisser vers le haut → verrouillage** : « Relâchez pour verrouiller »,
    puis « Verrouillé — Mains libres, vous pouvez lâcher l'écran », minuterie
    qui continue sans le doigt. Fonctionne.
  - **Envoi depuis l'état verrouillé** : bulle audio verte, lecteur, durée
    1:15, contrôle de vitesse. Fonctionne. ⚠ Un vocal de test de 1:15 traîne
    dans « Mes notes », à supprimer.
  - [x] **Appui long puis simple relâchement** (sans glissement) — vérifié le
    2026-08-06 à 07:20. Le geste fonctionne : bulle audio de 0:02 créée. ⚠ Mais
    l'envoi a **échoué** (« À l'instant · Non envoyé · Réessayer »), alors que
    l'envoi depuis l'état verrouillé avait réussi une heure plus tôt. Entre les
    deux, « Mes notes » était passé par l'état « Ce groupe a été supprimé ».
    C'est la conséquence concrète du raccourci de `EnsureSelfNotesNotifier`
    (voir ci-dessous) : la conversation renvoyée par le cache pointe sur un
    document absent, donc toute écriture échoue. À noter au crédit de l'app :
    l'échec est **affiché** avec une action « Réessayer », il n'est pas avalé.
- [x] ⚠ **Défaut trouvé pendant ce test — libellés tronqués dans le bandeau
  d'enregistrement**, à font_scale 1.1 sur le A51 : « Relâc… » au lieu de
  « Relâcher pour annuler », « L'enregi… » au lieu de « L'enregistrement sera
  supprimé », et « Glisser ‹… » en permanence. L'utilisateur ne pouvait pas lire
  ce qui allait lui arriver au moment où il annule — précisément le moment où il
  faudrait qu'il comprenne.
  **Cause** : le libellé partageait sa ligne avec la minuterie et le waveform et
  n'en recevait que 2/5 (`Expanded(flex: 2)` contre `flex: 3` au waveform).
  **Correctif** : le libellé a sa propre ligne, pleine largeur, sous la ligne
  minuterie + waveform ; les textes passent à `maxLines: 2` pour encaisser les
  fortes échelles au lieu de se couper.
  **Vérifié à l'écran le 2026-08-05 (06:44 → 06:47)**, APK `255dd2f`, thème
  sombre, font_scale 1.1 : « Glisser ‹ pour annuler · ↑ pour verrouiller » puis
  « Relâcher pour annuler » / « L'enregistrement sera supprimé » s'affichent en
  entier. Le relâchement annule bien (aucun vocal envoyé), zéro `RenderFlex`
  dans le tampon.

---

### Panneau stickers / GIF / émojis (fiche 26b, 2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] ⚠ **Le smiley du composeur ouvre bien les ÉMOJIS** (vu 2026-08-05, SM A515F, nocturne) — le piege de
  l index est evite. Detail :
  devenu « Stickers » : le code est passé d'un index à une énumération
  (`MessagePickerTab`) exprès pour ça, mais c'est le premier geste à refaire.
- [x] **Ligne d'info en pied** (vu 2026-08-05) : « ⓘ Téléchargés une fois,
  envoyés sans données » est bien SOUS la grille, avec son filet, sur
  l'onglet GIF ; absente de l'onglet Émojis. L'en-tête « TENDANCES » en
  terracotta porte la bascule GIFs/Stickers.

---

### Messages épinglés — le bandeau n'était pas temps réel (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Épinglage distant** (INSERT serveur, écran ouvert) : compteur passé de
  `1/3` à `1/4` tout seul.
- [x] **Désépinglage distant** (DELETE serveur, écran ouvert) : `1/4` → `1/3`
  tout seul — c'est le cas qui dépend de `replica identity full`.
- [x] **Bandeau + pastille ÉCO sur une seule ligne** (fiche 6b) : libellé à
  gauche, compteur `i/n` puis pastille à droite, sans chevauchement.
- [x] **Tap = défilement Telegram + saut au message** : `1/3` → `2/3`, libellé
  « Message épinglé 2 », et la liste a bien sauté au message ciblé.
- [x] **Bandeau au clavier ouvert** : reste visible, aucun débordement, la
  pastille est conservée.
- [x] **Chemin groupe — testé le 2026-08-05, il ne marche pas**, et pas à cause
  du temps réel : dans « Groupe de test prive », appui long → Autres actions →
  **Épingler** répond **« Impossible d'épingler ce message »**. Cause établie en
  base : `group_pinned_items.group_id` porte une clé étrangère vers
  `groups(id)`, or ce groupe a pour id `yflqsRLMMhTPpiW0NFHx` — un **id de
  document Firestore**, absent de `public.groups` (0 ligne). L'insertion viole
  donc la contrainte, `pinItem` lève, et le message d'échec s'affiche. Tant que
  les groupes vivent dans Firestore et les épingles dans Supabase, **aucun
  message de groupe ne peut être épinglé**. Le filtre `group_id` du bandeau
  reste donc non prouvé — il n'y a rien à afficher.
- [x] **Repli illisible corrigé** (2026-08-05) : dans ce cas le bandeau
  affichait « Message épinglé » **sous** le libellé « Message épinglé 1 », soit
  deux fois la même chose. Il dit maintenant « 🔐 Message chiffré ». À revoir à
  l'écran sur un build à jour.
- [x] **Vérifié sur SM A515F le 2026-08-14.** Dans « Groupe de test privé »
  (0 épingle au départ) : épinglage d'un message via Autres actions →
  Épingler → bandeau de conversation affiche bien « Message épinglé » (donc
  le contournement RLS conversation_id du 2026-08-05 tient toujours) ; retour
  à la fiche groupe → la ligne « Épinglés · 1 message » apparaît, compte
  correct. Avant ce correctif elle n'aurait jamais pu s'afficher, quel que
  soit l'état des épingles.

---

### Recherche messagerie — le clavier demandait deux taps (§9b, 2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le cas décisif** : depuis la liste des messages, **un seul tap** sur le
      champ de recherche → le clavier doit monter immédiatement et **rester**.
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), SM A515F : un tap → `mInputShown=true` à 0,5 s, 1,5 s et 3 s ;
      même chose sur le Pixel (sombre, police 1,3).
- [x] Enchaîner : saisir un terme sans re-toucher le champ, vérifier que le
      filtrage et les sections **Personnes** / **Conversations** répondent.
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), SM A515F : « Sal » tapé aussitôt → « Personnes · 4 » (Salim,
      Saleh, issaleko, Abdou) et « Conversations · 1 » (Salim L.), nom surligné.
- [x] Fermer par la flèche ←, puis rouvrir par un tap : le clavier doit remonter
      du premier coup **à chaque fois**, pas seulement la première.
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), SM A515F : deux cycles fermeture ← / tap → clavier monté et resté
      les deux fois.
- [x] Non-régression visuelle (fiche 9b) : bordure accent, loupe orange et halo
      3 px toujours présents en recherche — et **aucune ombre** quand le champ
      est au repos (le `DecoratedBox` est désormais permanent).
      ✅ Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), SM A515F : en recherche, bordure et loupe orange, halo ; au repos,
      aucune ombre (capture). ⚠️ L'indication au repos dit « Rechercher une
      personne, un message » alors que l'écran précise ensuite que « la recherche
      porte sur les noms » : le libellé promet ce qu'il ne fait pas.

---

### Brouillon restauré — le composer restait sur le micro (2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] ~~Brouillon de **plus de 2000 caractères** : l'état « dépassement »~~ —
      **caduc depuis le 2026-08-04.** L'état `_isOverLimit` a été supprimé : le
      `maxLength: 2000` du `TextField` tronque la saisie *et* le collé, donc le
      dépassement était inatteignable. Il reste à vérifier au doigt qu'un
      brouillon exactement à 2000 caractères se restaure sans casse.

---

### Zone de saisie des messages — barre multi-ligne (2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Croissance de la barre** — vérifié. 1 ligne → 6 lignes, la barre monte
  ligne après ligne ; à 12 lignes elle a **exactement la même hauteur** qu'à 6 et
  affiche L7–L12, donc le champ défile en interne en suivant le curseur. Le
  « + » et l'emoji restent collés en bas, le bouton rond ne bouge pas.
  Mesures au banc de test (échelle 1.0) : 23 px par ligne, plafond 162 px pour
  le champ / 190 px pour le composer.
- [x] **Retour à la ligne** — vérifié au `keyevent 66`. Entrée insère bien un
  saut de ligne et **n'envoie pas** (aucun message n'est parti dans la
  conversation). Reste à confirmer avec un **clavier physique**.
- [x] **Rendu en nocturne** à 6 lignes : la pilule reste une carte aux coins
  arrondis lisible, pas un rectangle mou. Rien à redire.
- [x] **Le panneau pièces jointes se ferme au clavier** — vérifié. « + » →
  grille ouverte, `mInputShown=false`, glyphe en « × » ; tap sur le champ →
  grille disparue, `mInputShown=true`, retour au « + ». Le bug est corrigé.
- [x] ⚠ **Débordement au « + » — trouvé par Salim, que mes captures avaient
  manqué, corrigé.** Symptôme : champ sur plusieurs lignes, appui sur « + », et
  l'overflow apparaît **au moment où le clavier disparaît**. Mes cinq captures
  ne le montraient pas parce qu'elles étaient prises dans « Mes notes », qui n'a
  presque pas de chrome fixe — le bug demande une conversation chargée.
  Mécanisme : `_toggleAttachPanel` baisse le clavier **puis insère le panneau
  aussitôt** ; pendant les ~250 ms de repli, l'inset du clavier vaut encore sa
  pleine valeur *et* le panneau est déjà dans la colonne. Avec la chrome de la
  conversation 1-à-1 (bandeau épinglé + chips Médias/ÉCO + bandeau de clés
  ≈ 240 dp) et le champ à 6 lignes : `RenderFlex overflowed by 85 pixels`,
  reproduit au banc. Le passage au multi-ligne n'a pas créé le défaut, il a
  rendu le composer assez haut pour qu'une mise en page déjà juste bascule.
  Correctif : les panneaux (pièces jointes **et** emoji) prennent désormais *la
  place* du clavier — leur fraction visible suit son retrait, donc la hauteur
  totale ne varie jamais. Piège au passage : `MediaQuery.viewInsets.bottom` vaut
  déjà 0 dans le `body` d'un `Scaffold` (il l'a consommé pour rétrécir) ; il
  faut lire `View.of(context).viewInsets`. Couvert par le 8ᵉ test du fichier.
  **Vérifié sur appareil le 2026-08-05 (06:07 → 06:12), thème clair, APK
  `2fe9240` bâti depuis un worktree isolé.** Conversation « Salim L. » (celle
  qui a toute la chrome), champ à 6 lignes, appui sur « + » : la frame
  transitoire montre le clavier qui descend, le panneau pas encore révélé et le
  composer stable — **aucune bannière rayée**, et zéro `RenderFlex … overflowed`
  dans le tampon. Trois cycles ouverture/fermeture d'affilée : le panneau
  s'affiche les trois fois.
- [x] ⚠ **Régression intermédiaire — le panneau ne s'affichait plus DU TOUT.**
  Signalée par Salim (« le modal du + ne s'affiche pas ») sur le premier
  correctif. Cause : le créneau clavier lit `View.of(context).viewInsets` pour
  contourner le `Scaffold`, mais **cette lecture ne crée aucune dépendance** —
  rien ne redemandait de build quand le clavier finissait de se replier, donc la
  fraction visible restait à 0. Le panneau n'apparaissait que si un autre
  `setState` (flux de messages) passait par là au bon moment : d'où
  l'intermittence, et d'où ma capture faussement rassurante. Corrigé par un
  `WidgetsBindingObserver` (`didChangeMetrics` → redessin tant qu'un panneau est
  ouvert). **Leçon** : une capture unique ne distingue pas « ça marche » de
  « ça a marché cette fois-ci » — pour tout ce qui dépend d'une animation, faire
  au moins trois cycles.
- [x] **Aucun autre débordement** à font_scale 1.1 : aucune bannière rayée
  jaune/noir sur les cinq captures (1 ligne, 6, 12, panneau ouvert, panneau
  fermé), et zéro `RenderFlex … overflowed by` dans le tampon logcat. ⚠ Le
  logcat seul ne suffit pas à conclure (Crashlytics remplace
  `FlutterError.onError`, cf. fiche « erreurs Flutter silencieuses ») — et le
  cas ci-dessus prouve qu'une capture sur le mauvais écran ne prouve rien non
  plus.
- [x] **Brouillon restauré** : à l'ouverture de « Mes notes », le brouillon
  laissé s'affiche déjà sur 2 lignes **et** le bouton est en mode envoi (bleu +
  cadenas) sans toucher au champ.
- [x] **Compteur de caractères** — vérifié sur la seconde passe (2026-08-05,
  00:55 → 00:59, APK debug installé à 23:55:57). Pastille « 204 / 2000 » puis
  « 224 / 2000 » en bas à droite **dans** la pilule, sur le fond neutre
  `surfaceVariant`, la barre étant à son plafond de 6 lignes. Reste à voir
  l'orange (sous 100 restants) et le rouge (à 2000), non atteints.
- [x] **La barre redescend** : en effaçant, elle repasse de 6 lignes à 1 sans
  saut ni scintillement.

---

## 3. Groupes

### ⬜ Noms des candidats à l'invitation et à l'ajout en appel (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Sur appareil — VÉRIFIÉ SM A515F le 2026-09-14, 21:22** : « Groupe de
      test prive », compte « Sim A » (qui partage un fil de 21 personnes). Les
      suggestions portent toutes un **nom et une photo** — « Abdou Sala
      L'auteur », « Abdoul Dee Ibrahim », « Albade Mohamed »… — classées par
      nom. Plus une seule ligne « Utilisateur » à avatar gris, là où la
      capture d'avant correctif n'avait que ça sur huit lignes. APK debug
      `d2fc966d921aed9c7cbe229843a14e29`, commit `d4245ea`.
- [x] **Sur appareil — VÉRIFIÉ SM A515F le 2026-09-14, 21:23** : un seul
      candidat sans nom dans la liste du compte de test. Il s'affiche bien
      « Utilisateur » — le repli localisé, posé par l'écran — et il est
      **la dernière ligne**, après « Yahaiya Moussa ». C'est la règle de tri
      qui le veut : une chaîne vide remonterait en tête d'un tri
      alphabétique.

---

### ⬜ Groupes officiels de ville (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Sur appareil, sur l'un des quatre comptes invités** : la notification
  « Rejoindre « Diaspora Niger — Niamey » ? » est bien arrivée, porte l'icône
  et la couleur des groupes, et son appui ouvre la **fiche du groupe** — pas
  la liste des notifications. C'est le chemin que l'analyseur a forcé à
  compléter dans cinq `switch` : sans eux la notification arrivait et
  n'ouvrait rien.
- [x] **Sur appareil** : sur cette fiche, « Rejoindre » fonctionne et le
  compteur de membres suit. Ne rien faire ne doit rien changer : le groupe
  doit rester à **1 membre** tant que personne n'a appuyé — c'est vérifiable
  en base à tout moment.
- [x] **Sur appareil** : la carte des groupes (Groupes → carte) montre une
  épingle par VILLE en plus des épingles de pays, au bon endroit, et le
  panneau du bas porte le nom de la ville.
- [x] **Sur appareil** : « Diaspora Niger — Angola » et « — Cap-Vert »
  apparaissent enfin sur la carte. Leurs pays n'étaient dans aucun des 32
  centroïdes écrits en dur : les deux groupes existaient et n'étaient
  simplement jamais dessinés, sans le moindre message.
- [x] **Sur appareil** : les 32 pays qui ont un centroïde n'ont pas bougé
  (Niger, France, Canada…) — le repli par la plus grande ville ne sert que
  là où il n'y avait rien.
- [x] **Sur appareil, fiche « Diaspora Niger — Niger »** : une section
  « Ville » liste « Niamey · 2 » (2 depuis que Sim A a rejoint), au-dessus des
  membres. Vérifié le 2026-09-14 ; l'appui sur la puce reste à essayer. Sur la fiche de « — Niamey » comme sur celle
  du Canada (aucun groupe de ville), la section doit être **absente** — pas
  vide, absente.
- [x] **Sur appareil, onglet Découvrir** : choisir un pays fait apparaître
  une rangée « Ville » sous celle des pays ; choisir « Niger » puis
  « Niamey » ne laisse que le groupe de Niamey. Revenir à « Tous » sur le
  pays fait disparaître la rangée. Changer de pays doit remettre la ville à
  zéro — sinon « Niamey » sous « Canada » vide l'onglet sans rien dire, et
  cet écran a déjà eu trois causes indistinguables d'écran blanc.
- [x] **Sur appareil** : la carte montre « Diaspora Niger — Niamey » à
  Niamey, et « — Niger » à sa place habituelle — deux épingles distinctes,
  pas une seule. C'est le cas où ville et pays coexistent au même endroit du
  monde, celui qui risque de les superposer.

  Vu le 2026-09-14 : l'épingle de Niamey porte l'infobulle « Niamey ·
  1 groupe » et ouvre un panneau titré « Niamey » avec « Diaspora Niger —
  Niamey · 2 membres · Officiel ». Cap-Vert apparaît dans l'Atlantique et
  Angola au sud — les deux qui n'étaient jamais dessinées. Algérie, Niger et
  Nigeria restent à leur centroïde habituel.
- [x] **Sur appareil** : les trois actions tiennent sur une ligne sans rogner
  le titre « Groupes » ni le sous-titre. Vu le 2026-09-14 (première version,
  avec la carte pliée ; le globe ne change pas l'encombrement).
   - [x] **Sur appareil** : « Mes groupes » liste bien les groupes du compte,
     et l'onglet Découvrir affiche des groupes au lieu de squelettes — y
     compris en allant sur l'onglet Groupes **tout de suite** après le
     lancement, avant que l'authentification ait fini de se résoudre. C'est ce
     timing-là qui déclenchait la panne.

     Vérifié sur SM A515F le 2026-09-14, APK release `f71e242b…` (`417398e`),
     onglet Groupes ouvert **7 s après le lancement** — le timing même qui
     cassait : « 5 rejoints » et la liste s'affiche, Découvrir montre
     « Suggéré pour toi » puis de vraies cartes. Avant le correctif, au même
     endroit : « 0 rejoint » et quatre squelettes.

---

### ⬜ Groupe privé par lien : demander à rejoindre (2026-09-10)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Un lien vers un groupe supprimé garde « Ce groupe est privé ou n'existe
      plus. » — pas de bouton. ✅ SM A515F 2026-09-10 01:44, APK md5 8f9cc4d9b2.

---

### ⚠️ Lire les groupes SANS session échoue en production (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Après `db push` : démarrage à froid, ouvrir l'onglet Groupes tout de
      suite (avant que la session s'établisse) — la liste doit s'afficher.
      **✅ 2026-09-11 17:37, SM A515F, build 18 (md5 `37708518…`).** Sonde
      anonyme `GET /rest/v1/groups?select=id,name` avec la clé publique du
      `.env` → **200, 4 groupes** (les publics), là où elle rendait 401 /
      42501 : le GRANT est en production. Puis `force-stop` et lien profond
      `diasponiger:///groups` : « 3 rejoints », liste affichée à 9 s comme à
      17 s (captures identiques), aucune « Erreur de chargement ». La fenêtre
      sans session elle-même ne se voit pas à l'écran sur un build release
      (journaux muets) : c'est la sonde anonyme qui prouve ce chemin.

---

### ⬜ Inviter des membres dans un groupe privé (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **« Retirer du groupe » ne retirait pas du groupe** — corrigé (voir la
      section suivante).
      `removeUserFromGroup` (`message_supabase_datasource.dart:2045`) ne touche
      que `conversations.participant_ids` et `data.adminIds` ; la ligne
      `group_members` reste, donc la personne **figure toujours dans la liste
      des membres** et compte dans `member_count`. Aucune policy ne permet à
      un administrateur de supprimer la ligne d'un autre : il faut une RPC
      `SECURITY DEFINER` dédiée.

---

### ⛔ Un groupe dont on est le seul membre refuse TOUS les messages (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Envoi dans un groupe où l'on est seul : `GRP-FIX-2041` passe à
      **`À l'instant · Envoyé`** (20:40), là où `ECHO-A-1944` restait en
      « Non envoyé » à 19:44 sur le même groupe et le même compte.
- [x] Il est **réellement parti côté serveur**, pas seulement affiché : la
      liste des discussions montre « Groupe de test privé — 20:40 — Vous:
      GRP-FIX-2041 » et le groupe est remonté en tête. C'est
      `_updateConversationLastMessage`, qui ne s'exécute qu'après l'insert.
      À l'échec de 19:44, cette même ligne était restée sur « 30 août ».
- [x] Quitter la discussion, y revenir : la bulle est toujours là, **en
      clair** (20:42) — l'aller-retour Sender Key du chiffrement de groupe
      tient.
- [x] **Le vrai chemin Sender Key vers autrui, exercé pour la première fois**
      (2026-09-09, 22:52-22:54). Groupe « Testeurs », 2 membres. Depuis le
      SM A515F, compte **Sim A qui n'est pas administrateur** : la discussion
      s'ouvre (plus de 42501), `SENDERKEY-2253` part et passe à
      « À l'instant · Reçu ». Sur le Pixel, compte Salim L., la bulle
      s'affiche **en clair** — « Sim A / SENDERKEY-2253 », 22:52, thème
      sombre, aucun placeholder. Chiffrement de groupe, aller ET retour, entre
      deux comptes distincts.
- [x] Par la même occasion : l'écho temps réel **en groupe**, qui manquait à
      la section « Aucun marqueur technique dans une bulle » — la bulle a
      gardé son texte côté expéditeur.

---

### ⬜ Fiche « Membres » d'un groupe : « Erreur de chargement » (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Le message ne ment plus quand c'est le réseau : hors ligne, la fiche
      Membres et l'onglet Groupes affichent « Pas de connexion internet » au
      lieu de « Erreur de chargement ». Fait au seul endroit qui compte pour
      l'onglet Groupes — `_buildErrorWidget`, devant `FailureMapper`, parce
      qu'une erreur réseau ne dit pas toujours qu'elle en est une.
- [x] La flèche « retour » de la fiche Membres ne quitte plus l'application :
      `context.canPop() ? context.pop() : context.go('/home')`, le même repli
      que la fiche du groupe juste à côté.
- [x] **Vérifié SM A515F, 22:57** (build `b38194eb…46f3`) : lien profond
      direct sur `/groups/<uuid>/members`, app relancée à froid — la fiche
      s'ouvre seule dans la pile, et la flèche ramène à **l'accueil**
      (« Bonjour, Sim », `MainActivity` toujours au premier plan). Avant, elle
      renvoyait au lanceur. Au passage, l'écran affiche bien « Erreur de
      chargement » et non « Pas de connexion internet » — l'appareil était en
      ligne et l'uuid bidon : la branche hors ligne ne se déclenche pas à
      tort.

---

### Mentions de groupe : vérifié sur SM A515F (2026-08-23)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Taper `@sa` ouvre la liste — « Salim L. » en titre, `@SalimL` en
      sous-titre. Le filtre trouve bien par le **début d'un mot** du nom
      affiché, pas seulement par le début du nom complet.
- [x] Sélectionner insère `@SalimL ` — pseudo sans espace, espace après,
      curseur derrière, liste refermée. Le point de « Salim L. » est bien
      retiré.
- [x] Le membre `diaspo_ne` n'apparaît pas sur `@sa` : le filtrage est correct,
      il ne propose pas tout le monde.
- [x] Le garde anti-e-mail fonctionne — trop bien, même : un `@` précédé d'un
      caractère de mot n'ouvre pas la liste. Rencontré pour de vrai, un
      brouillon `@sa` restant en place faisait que le second `@sa` tapé
      derrière n'ouvrait rien. C'est le comportement voulu, mais il surprend.

---

### Modération des membres de groupe : trou RLS fermé + bug de départ trouvé (2026-08-14)

`conversations_update` (`participant_ids @> [firebase_uid()]`) autorisait
n'importe quel participant à écrire `data.adminIds`/`participant_ids` sans
vérification de rôle — n'importe quel membre pouvait s'auto-promouvoir admin
ou exclure quelqu'un via une écriture directe, dans n'importe quel groupe
(pas seulement officiel). Fermé par un trigger `BEFORE UPDATE`
(`20260814000500_guard_conversation_admin_fields.sql`), pas par une policy
RLS seule (comparaison OLD/NEW propre, cf [[project_rls_testing_bypass_pitfall]]
pour la méthode de vérification utilisée). Détail dans
`docs/ops/GROUPES_OFFICIELS.md`.

- [x] **Testé en base** (`SET LOCAL ROLE authenticated` + `request.jwt.claims`,
  transaction annulée) : promotion par un non-admin refusée (42501),
  promotion par un admin existant acceptée, champ sans rapport (`mutedBy`)
  toujours modifiable par un simple participant, superAdmin accepté sur le
  groupe officiel sans être dans `adminIds` ni `group_members`.

**Corrigé aussi** : `leaveGroup()` (`group_supabase_datasource.dart:343`) ne
supprimait que la ligne `group_members` — ne touchait jamais
`conversations.participant_ids`. Un membre qui quittait un groupe restait
participant de sa conversation, avec accès en lecture aux messages envoyés
après son départ (`conversations_select` se fie à `participant_ids`). RPC
`SECURITY DEFINER` dédiée (`leave_group_conversation`,
`20260814001500_leave_group_removes_conversation_participant.sql`) — un
simple `UPDATE` échoue de toute façon sur `conversations_update`, qui exige
implicitement que l'appelant reste participant après l'update.

- [x] **Testé en base** (même méthode) : le départ retire bien l'appelant de
  `participant_ids` (et de `adminIds` s'il y était), un appel sur un groupe
  dont on n'est pas membre ne fait rien sans erreur. ⚠️ Piège de test :
  une fonction `SECURITY DEFINER` créée **après** `SET LOCAL ROLE
  authenticated` appartient à `authenticated`, pas `postgres` — elle reste
  soumise à RLS malgré son mot-clé (deux faux échecs avant de comprendre).
- [x] **Vérifié sur SM A515F le 2026-08-14** (compte Sim A, groupe « Testeurs »,
  2 membres). Fiche groupe → menu ⋮ → « Quitter » → confirmation : bandeau
  « Vous avez quitté le groupe » dans la discussion, aucun plantage. Confirmé
  en base dans la foulée : `group_members` et `conversations.participant_ids`
  ne portent plus que Salim. Accès en lecture testé en insérant un message
  comme Salim juste après (`SET ROLE authenticated` + JWT de Sim A) : `select`
  rend **0 ligne** — avant le correctif, Sim A l'aurait encore lu. Message de
  test supprimé, Sim A rejoint le groupe ensuite pour restaurer l'état
  antérieur (`group_members` + `participant_ids`).

---

### Supprimer un groupe ne supprimait que la ligne `groups` (2026-08-14)

Signalement de Salim (« la gestion des groupes se passe pas bien ») en
creusant le comportement de « Quitter »/« Supprimer » un groupe. `delete_group()`
(bouton « Supprimer le groupe » de la fiche d'édition, admin/créateur
seulement) ne supprimait que la ligne `groups`. Contrairement à
`events`/`post_polls`/`group_pinned_items` (déjà `ON DELETE CASCADE` depuis
`groups.id`), `group_members` et `conversations` n'ont **aucune** contrainte
de clé étrangère vers `groups` : `group_members` restait avec des lignes
orphelines, et **la conversation + tous ses messages restaient intacts et
lisibles indéfiniment** par tous les anciens membres — « supprimer le
groupe » ne supprimait pas la discussion du tout.

Décision de Salim : supprimer un groupe doit le dissoudre pour **tout le
monde**, comme quitter mais appliqué à tous les membres d'un coup — pas
seulement pour l'admin qui agit. Corrigé (migration
`20260814003000_delete_group_cascades_membership_and_conversation.sql`) :
`delete_group()` supprime aussi `conversations` (cascade déjà en place vers
`messages`/`group_pinned_items`/`events` liés à la conversation) et
`group_members` avant de supprimer `groups`. Autorisation inchangée
(`creator_id = v_uid` uniquement) — pas étendue au superAdmin comme
`groups_update_admin` l'a été : la suppression reste une action plus lourde,
réservée au compte plateforme pour un groupe officiel.

- [x] **Testé en base** (groupe/membres/conversation/message jetables créés
  dans une transaction annulée par `ROLLBACK`) : avant suppression — 1
  groupe, 2 membres, 1 conversation, 1 message ; tentative par un
  non-créateur — bloquée (`not_authorized`) ; suppression par le vrai
  créateur — les quatre compteurs tombent à 0. Rien laissé en base.
- [x] **Vérifié sur SM A515F le 2026-08-14** (compte Sim A, groupe « A
  supprimer (test) » créé pour l'occasion : Sim A créateur, Salim membre, un
  message échangé). Fiche groupe → menu ⋮ → « Modifier » → icône poubelle →
  « Voulez-vous vraiment supprimer ce groupe ? Cette action est
  irréversible. » → confirmation : bandeau « Groupe supprimé », retour propre
  à la liste (3 → 2 groupes rejoints), aucun plantage. Confirmé en base dans
  la foulée : `groups`, `group_members`, `conversations` et `messages`
  retombent tous à 0 ligne pour ce groupe.

---

### Groupes & événements en conversation

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Alignement des bulles reçues dans une série de groupe — CORRIGÉ ET VÉRIFIÉ SUR APPAREIL** (`message_bubble.dart`, `conversation_screen.dart`, SM A515F, 2026-08-13). Deux défauts distincts trouvés sur le même chemin :
  1. Le padding gauche des messages reçus en groupe passait de 8 (avatar affiché sur le 1er message d'une série) à 16 (pas d'avatar sur les suivants) — saut de 28px, bulles non alignées verticalement dans une même série. Corrigé en réservant toujours la largeur de l'avatar (`SizedBox(width: 28)` en son absence) pour tout message reçu d'un groupe (`groupId` non nul).
  2. **Avatar dupliqué** — `conversation_screen.dart` enveloppait `MessageBubble` dans SA PROPRE colonne avatar (radius 12, gris, sans badge vérifié ni tap-profil) pour tout message de groupe reçu, en plus de l'avatar interne de `MessageBubble` (radius 14, coloré) : deux cercles « S » côte à côte sur chaque message montrant l'expéditeur. Les deux branches du ternaire `_isGroup && !isMe ? Row(...) : MessageBubble(...)` construisaient `MessageBubble` avec des paramètres strictement identiques — le wrapper était mort code redondant. Supprimé, un seul appel `MessageBubble(...)` désormais.

  Vérifié sur le groupe « teste » (messages réels de Salim L., série de 2 sur 18 juillet 2026) : un seul avatar par message, bulles alignées au même bord gauche que le message montre le nom/avatar ou non.

---

### Fiche membres de groupe bloquée / vide (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Vérifié sur SM A515F**, groupe « Diaspora Niger — Canada » (2 membres,
  compte Sim A) : par le chemin en-tête de conversation → fiche → Tout voir —
  celui qui reproduisait les DEUX défauts — la fiche affiche « Membres · 2 »,
  « Ouvrir la discussion », les deux membres nommés (Sim A · Créateur, Salim
  L.), et « Tout voir » ouvre la liste immédiatement au lieu de tourner dans
  le vide.
- [x] **Vérifié sur SM A515F** : la ligne créateur affiche désormais
  « Diaspo Niger · Créateur » (sans profession) sur la fiche ET sur l'écran
  « Tout voir », cohérent avec « Créé par Diaspo Niger » en bas de fiche.
- [x] **Vérifié sur SM A515F, connecté en Sim A** (donc point de vue d'un
  membre normal, pas du compte plateforme) : la fiche affiche « Membres · 3 »,
  la ligne « Diaspo Niger · Créateur » sans chevron ni tap possible, et
  « Salim L. » apparaît comme 3e membre (compte déjà présent en base,
  simplement jamais vu résolu avant ce test).
- [x] **Testé en base (pas sur appareil — aucun compte de test n'a de pays
  encore sans groupe officiel)** : rejoué sous une identité non-admin réelle
  (`U64HKfrjM5NwR6HO00XPKo6168z2`), dans une transaction annulée par
  `ROLLBACK` (`SET LOCAL request.jwt.claims`). Cas nouveau pays (France,
  simulé) : plus d'exception, `creator_id` = compte plateforme,
  `member_count = 1`, aucune trace laissée par le ROLLBACK, les 4 triggers de
  `groups` réactivés après coup. Cas pays déjà couvert (Canada) : retour
  identique à avant, aucun INSERT déclenché.
- [x] **Accusé « Envoyé » sur rafale de messages (`conversation_screen.dart`,
  `_getMessageGroupPositionReversed`)** : `first`/`last` étaient inversés —
  dans une liste inversée (index 0 = plus récent), le message le plus ANCIEN
  d'une rafale du même expéditeur héritait de `MessageGroupPosition.last`,
  donc de l'accusé « Envoyé » porté par `_isLastInGroup`
  ([message_bubble.dart:230](lib/features/messages/presentation/widgets/message_bubble.dart:230)),
  à la place du plus récent — symptôme rapporté : « j'envoie deux messages
  d'affilée, je ne vois "Envoyé" que sur le 1er ». Corrigé en échangeant les
  deux branches.
  **Vérifié sur SM A515F le 2026-08-13** (compte Sim A, conversation « Mes
  notes », 2 messages envoyés coup sur coup) : seul le 2e message porte
  « À l'instant · Envoyé », le 1er n'en porte aucun. La queue de bulle
  (`_getBorderRadius`) suit aussi la correction attendue — petit rayon en
  bas à droite sur la bulle du bas (fin de rafale) au lieu du haut. Pas
  d'erreur en logcat.
  **`showSenderInfo` vérifié le 2026-08-13** dans le groupe « Testeurs »,
  côté réception (Sim A regarde une rafale de « Salim L. ») : rafale de 3
  lignes insérée directement en base (`messages`, même `sender_id`, +5 s
  et +10 s, nettoyée juste après par un `DELETE` sur leurs ids) pour
  simuler une rafale de l'autre membre sans dépendre d'un 2e appareil. Le
  nom « Salim L. » + badge « Admin » ne s'affichent que sur la bulle du
  HAUT (la plus ancienne) ; les 2 bulles suivantes n'ont ni nom ni badge —
  comportement attendu confirmé côté réception aussi, pas seulement côté
  émission.
  **Tap-to-reveal vérifié le 2026-08-13** dans la conversation « Salim L. »
  (1:1, 2 messages envoyés coup sur coup « bvvgc »/« bvvgcv ») : le message
  précédent (« bvvgc ») n'affiche rien par défaut, un tap sur la ligne
  méta (sous la bulle) révèle « 19:55 · Lu » — confirmé via
  `uiautomator dump` (content-desc passe de `"bvvgc"` à `"bvvgc\n19:55"`)
  et capture d'écran. Les messages reçus (rafale de 5 dans la conversation
  « Salim L. ») affichent chacun leur heure individuellement sans tap,
  comme attendu (`showTimeInfo = _isLastInGroup || !isMe || _metaRevealed`).
  ⚠️ Piège rencontré en testant : un premier build (`flutter build apk
  --debug`) avait son démon Gradle tué en cours (autre agent qui buildait
  en parallèle) — le retry a réussi mais a silencieusement produit un APK
  au comportement incohérent avec le code source (rafales reçues
  n'affichant l'heure que sur le dernier message, contredisant le code
  lu). Un `flutter clean` + rebuild complet a résolu l'incohérence. Ne pas
  faire confiance à un build qui a suivi un échec de démon Gradle, même
  si le retry annonce un succès — repartir d'un `flutter clean`.

---

### Groupes officiels — organisation de la gestion au quotidien (2026-08-13)

Suite du correctif creator_id/RPC pays : Salim est déjà superAdmin plateforme
mais n'avait aucun droit RLS sur un groupe officiel sans ligne
`group_members` dédiée — impraticable au quotidien (aurait fallu se
reconnecter comme le compte plateforme à chaque action). Corrigé par
migration `20260813234500_superadmin_manages_official_groups.sql` :
`groups_update_admin` accepte désormais `is_group_admin(id) OR (is_official
AND is_admin())`, portée volontairement limitée aux groupes officiels (pas
un accès superAdmin global à `groups`). Détail complet dans
`docs/ops/GROUPES_OFFICIELS.md`.

⚠️ **Piège de méthode découvert en vérifiant ce correctif** : `supabase db
query --linked` se connecte en `postgres` (`rolbypassrls = true`) —
contourne RLS entièrement, quel que soit `request.jwt.claims` posé avec `SET
LOCAL`. Un premier test « groupe privé refusé » avait silencieusement réussi
alors qu'il aurait dû échouer — faux positif pur, RLS jamais évalué.
Refait avec `SET LOCAL ROLE authenticated;` en plus (rôle sans
`BYPASSRLS`, celui que PostgREST utilise réellement) : les fonctions
`SECURITY DEFINER` (`get_or_create_official_group`) n'étaient pas affectées
par ce piège — elles s'exécutent avec les privilèges de leur propriétaire
quel que soit l'appelant — mais toute vérification directe d'une policy sur
une table (`UPDATE`/`DELETE` brut) l'est.

- [x] **Testé en base avec la méthode corrigée** (transaction annulée par
  `ROLLBACK`, `SET LOCAL ROLE authenticated` + `request.jwt.claims`) :
  Salim (superAdmin, son propre compte) peut modifier le groupe officiel ;
  le même compte reste bloqué (0 ligne) sur un groupe privé de Sim A dont il
  n'est ni créateur ni membre. Pas testé sur appareil — nécessiterait de
  construire un écran de modification de groupe officiel côté app, qui
  n'existe pas encore (le bouton « Modifier » existant n'a jamais été
  vérifié bout en bout, cf plus haut dans ce fichier).

---

### Demandes d'adhésion — brancher Supabase n'avait pas suffi (2026-08-06)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **La demande apparaît chez l'administrateur** — vérifié sur SM A515F le
      2026-08-06. La demande a été **créée en base** (pas depuis un second
      téléphone) : c'est donc l'affichage qui est prouvé, pas l'émission. Le
      menu du groupe porte « Demandes d'adhésion · 1 » avec sa pastille, et
      l'écran liste bien le demandeur. Avant la migration, cette liste était
      vide — c'était le blocage principal.
- [x] **L'approbation fait entrer le demandeur** — vérifié le 2026-08-06, les
      trois anomalies d'origine tombant d'un coup :
      `status = 'approved'`, `processed_by = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'`
      (l'uid **Firebase**, plus l'uuid Supabase), et le demandeur présent dans
      `group_members` — le groupe passe de 1 à 2 membres. SnackBar
      « Demande approuvée », liste vidée immédiatement.
      Donnée de test retirée après coup.
      Reste non vu, faute d'un second appareil : que le groupe apparaisse dans
      « Mes groupes » du demandeur et qu'il accède aux messages.
- [x] **Invitation acceptée** — vérifié sur SM A515F le 2026-08-06, compte
      « Sim » acceptant une vraie invitation à « Testeurs » (groupe privé).
      `group_members` gagne bien la ligne `role = 'member'`, le groupe entre
      dans « Mes groupes » (« 2 rejoints » → « 3 rejoints »).

      Deux choses valent d'être retenues de ce test :

      **Le bouton semblait mort.** Deux captures prises 6 et 7 s après le tap
      montraient un écran inchangé. La SnackBar d'erreur dure ~4 s : c'est la
      fenêtre de capture qui était trop lente, pas le bouton qui ne répondait
      pas. En capturant à 1 s, « Action impossible pour le moment, réessayez. »
      apparaît. Ne jamais conclure « bouton mort » sans une capture immédiate.

      **La cause était une cinquième anomalie, antérieure et jamais vue.**
      `group_invites_own` avait un `USING` (inviter OU invité) et un
      `WITH CHECK` (inviter **seulement**) asymétriques : l'invité pouvait lire
      son invitation mais pas écrire sa réponse — `42501`. `acceptGroupInvite`
      **et** `declineGroupInvite` étaient donc morts pour le destinataire
      depuis toujours. Corrigé par
      `20260806200000_invite_repondre_par_l_invite.sql`.
      L'audit initial n'avait lu que les `USING` des policies : sur une table
      en écriture, lire le `WITH CHECK` est la moitié qui manque.
- [x] **Groupe privé à 2 membres** — vérifié sur SM A515F le 2026-08-06, du
      côté du membre non-administrateur : « Testeurs » affiche bien **2**
      après l'entrée de Sim. Avant la migration il aurait affiché 1.
      Vérifié depuis ce seul compte ; la vue de l'administrateur n'a pas été
      regardée (elle passait déjà, `firebase_uid() = user_id` couvrant sa
      propre ligne).

---

### Groupes — défauts trouvés en vérifiant les épingles (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Conversation de GROUPE par lien profond** → en-tête « Diaspora Niger
  … », avatar vert à icône groupe, sous-titre « Groupe », appels de groupe.
  Commande :
  ```
  adb shell am start -a android.intent.action.VIEW -d "https://diasponiger.web.app/messages/0ce4c63f-ef7a-4616-8d52-88f22444a4ca" -p com.diasponiger.diasponiger
  ```
- [x] **Groupe hérité Firestore par lien profond** (`68672ea9-…`,
  `yflqsRLMMhTPpiW0NFHx`) → « Groupe de test prive », « 1 membre », historique
  présent (plus de « Aucun message »).
- [x] **Retour depuis un lien profond** (bouton retour système) → liste des
  messages, plus d'écran noir.
- [x] **Non-régression 1-à-1** → « Salim L. », « En ligne », avatar terracotta,
  appels 1-à-1, bandeau épinglé « 1/3 ». Le nom du correspondant ne s'affichait
  PAS avant (« Utilisateur ») : `otherUserId` n'était pas réconcilié non plus,
  corrigé dans la même passe.
- [x] **Bandeau épinglé** visible et fonctionnel sur le DM (correctif « épingle
  portée par la conversation »).
- [x] **Liste des messages** : les deux groupes réapparaissent avec leur nom, et
  la tuile « Mes notes » a retrouvé son sous-titre « Notes, brouillons et
  sondages ». Avant le correctif, les deux groupes étaient absorbés par la tuile
  « Mes notes » et absents du flux (« 2 groupes actifs » sans aucun groupe
  visible).
- [x] **Pas de recréation de conversation** : `count(*)` sur `conversations`
  inchangé (8 avant / 8 après), `yflqsRLMMhTPpiW0NFHx` toujours à 1 ligne.
- [x] **Menu ⋮ sur la conversation de groupe** → options de conversation
  (recherche, médias, sourdine, éphémères, archiver, fond, favoris, exporter,
  signaler) et **pas** l'option « Bloquer », qui est gardée par
  `!isGroup && otherUserId != null` dans `ConversationOptionsModal`. C'est la
  preuve que le drapeau est correct sur ce chemin.
- [x] **Flèche de l'en-tête depuis un lien profond** → ramène à la liste des
  messages, pas d'écran noir. Les trois sorties du retour sont donc couvertes
  (bouton système, flèche ; le geste de bord emprunte le même `PopScope`).
- [x] **Recréation par le VRAI chemin — PROUVÉ le 2026-08-05.** Le lien profond
  ouvre la conversation par son id et ne passe PAS par
  `createGroupConversation` ; le compte inchangé ne prouvait donc rien. Refait
  par le vrai chemin (fiche du groupe → « Ouvrir la discussion »), **deux fois
  de suite** sur `yflqsRLMMhTPpiW0NFHx` : la même conversation se rouvre avec
  son historique, `count(*)` = 8 avant / 8 après, groupe hérité 1 / 1.

  ⚠️ Ce test a d'abord été **impossible** : le bouton « Ouvrir la discussion »
  était MORT (voir ci-dessous).
- [x] Vérifié sur appareil : le bouton ouvre bien la discussion, deux fois de
  suite, sur le groupe hérité.
- [x] **Audit ciblé mené le 2026-08-06.** Critère retenu : occurrence suivie
  d'un abandon silencieux (`return`, `return null`, `return false`) dans un
  fichier qui ne `watch` pas ce provider. Point structurel confirmé : **aucun
  `watch(currentUserAsyncProvider)` au niveau racine/shell** — il n'est
  maintenu vivant que par 24 sites dispersés, donc rien ne le garde chaud. Et
  `currentUserProvider` est un provider **différent** : le watcher ne maintient
  pas l'autre (c'est ce qui piégeait la fiche de groupe).
- [x] **`conversation_actions_provider` (6 méthodes) — CORRIGÉ ET VÉRIFIÉ.**
  `muteConversation`, `archiveConversation`, `deleteConversation`,
  `reportConversation`, `reportMessage`, `reportGroup` rendaient toutes `false`
  sans rien faire — et les appelants **ignorent ce booléen**, donc aucune
  erreur n'était affichée. Preuve sur appareil avec la cloche « Couper les
  notifications » de la fiche de groupe : avant, `data->'mutedBy'` restait
  `null` malgré le tap ; après, il passe à
  `{"vQZE49…": "forever"}`, et le re-tap le vide (`{}`). Les deux sens
  vérifiés.
- [x] **`group_detail_screen` (3 méthodes) — CORRIGÉ, non testé.**
  `_requestToJoin`, `_joinGroup`, `_leaveGroup` sortaient sur un `return` nu.
  C'est le même écran où « Ouvrir la discussion » était prouvé mort, donc le
  provider y est bien éteint. Non testés faute de jeu de données : il faut un
  groupe non rejoint (join) et accepter de quitter un groupe (leave).
  ⚠️ `_leaveGroup` a reçu un `if (!mounted) return;` après l'attente —
  l'analyzer signalait un `BuildContext` traversant un saut asynchrone.
- [x] **Deuxième passe le 2026-08-06 — 8 fichiers, 41 sites corrigés.**
  `admin_settings_screen` (6 × `_save`/`_saveUrls`/`_saveIntervals`),
  `groups_screen` (3), `blocked_users_provider` (2),
  `notification_provider` (2), `media_gallery_provider` (2),
  `group_request_provider` (2), `group_call_provider` (6),
  `audio_room_provider` (18).

  Trois sites **volontairement laissés** en lecture synchrone, leurs méthodes
  n'étant pas `async` : `groups_screen._loadDefaultCountryFilter`,
  `group_call_provider._checkIfLastParticipant`,
  `audio_room_provider.retryAudioConnection`. Y mettre un `await` ne
  compilerait pas.

  Deux pièges rencontrés, à connaître avant toute nouvelle passe :
  - **précédence** : `read(p).valueOrNull?.id` devient
    `(await read(p.future))?.id` — sans les parenthèses le `await` porte sur
    la mauvaise expression (1 cas, `group_call_provider`) ;
  - **`BuildContext` après saut asynchrone** : `groups_screen._leaveGroup` a
    dû recevoir un `if (!mounted) return;` (l'analyzer l'attrape).
- [x] **Vérifié sur appareil** : « Tout lire » de l'écran Notifications
  (`markAllAsRead`). Avant : « 7 non lues », badge 7 sur la puce, bouton
  présent. Après : compteur, badge, bouton et pastilles disparus, icônes en
  état lu.
- [x] **Troisième passe — `message_provider` (15 sites), le plus gros
  gisement.** Il avait 16 occurrences pour 16 abandons silencieux, et seul
  `createGroup` avait été traité. Corrigés : `toggleStar`, `editMessage`,
  `forwardMessage`, `deleteForMe`, `createIndividual`, `ensure` (Mes notes),
  les deux `mark` (lu / distribué), `acceptRequest`, `declineRequest` et les
  cinq envois à paramètres nommés. `_preEstablishE2EESessions` (ligne 157)
  reste en lecture synchrone : méthode non `async`.

  **Vérifié sur appareil — c'est le plus parlant du lot** : la conversation
  `883c9d96-…` affichait **4 non lus**. Elle avait déjà été ouverte à 10:56
  pendant le test de non-régression du DM, et le compteur était **resté à 4** :
  `markAsRead.mark()` ne faisait donc rien. Après correctif, une simple
  ouverture le remet à `0`. Autrement dit, **les messages ne se marquaient pas
  comme lus** — le badge de la liste et celui de la barre de navigation
  restaient donc allumés indéfiniment.
- [x] **Quatrième passe — 15 sites** : `heritage_provider` (8),
  `notification_preferences_provider` (3), `create_event_screen` (1),
  `add_payment_account_screen` (1), `typing_indicator_provider` (1),
  `create_business_screen` (1). `create_event_screen._prefillLocation` laissé
  synchrone (non `async`). `create_event_screen._createEvent` a reçu un
  `if (!mounted) return;`.
- [x] 🔴 **Découverte : le piège n'est pas propre à `currentUserAsyncProvider`.**
  En vérifiant l'interrupteur maître des notifications, l'UI basculait mais
  `users.notifications_enabled` ne bougeait pas. Cause : un **second garde de
  la même famille** juste en dessous —
  `ref.read(profileNotifierProvider(userId)).valueOrNull`, sur un
  `StateNotifierProvider.autoDispose` dont le `_loadProfile()` ne pose `state`
  de façon synchrone que s'il trouve un cache. Sans cache, l'étage serveur
  était sauté en silence : la bascule n'éteignait que l'affichage local, et
  **le back-end continuait de pousser** alors que l'interrupteur affichait
  « désactivé » — exactement ce que le commentaire du code disait vouloir
  éviter. Un `StateNotifierProvider` n'a pas de `.future` : le correctif
  retombe explicitement sur le dépôt (`_loadProfileFor`).

  Vérifié sur appareil : `enabled=false` → `profile=ok` →
  `users.notifications_enabled = false`, puis remis à `true`.

  ⚠️ **Leçon de méthode** : deux mesures intermédiaires ont été jetées avant
  celle-ci. La préférence **locale** et la colonne **serveur** s'étaient
  désynchronisées à force d'essais, si bien que le tap rejouait parfois la
  valeur déjà en base — l'absence de changement ne prouvait alors rien. Il faut
  lire l'état des DEUX côtés avant de taper, et instrumenter plutôt que de
  déduire.
- [x] **Cinquième passe — audit des AUTRES providers, et révision à la baisse.**
  L'estimation « 24 sites suspects » de la passe précédente était **fausse** :
  le filtre portait sur la mauvaise ligne du `grep -A 1`. Mesure refaite :

  - Providers non-family lus en `.valueOrNull` avec abandon
    (`currentUserProvider` ×25, `appSettingsNotifierProvider` ×5,
    `blockedUsersProvider`, `activeStoriesProvider`, …) : **zéro** site sans
    `watch` local. Le provider est chaud partout où il est lu — rien à faire.
  - Providers **family** (que le regex précédent ratait, d'où l'angle mort qui
    avait laissé passer `profileNotifierProvider`) : `profileNotifierProvider`
    est lu sans `watch` local dans 7 fichiers. En les lisant un par un, la
    plupart sont des **pré-remplissages avec repli gracieux**
    (`profile?.currentCountry`) dans des méthodes non `async` — dégradation
    acceptable, pas un blocage : `business_provider._loadUserLocation`,
    `create_product_screen._initUserCountry`,
    `create_event_screen._prefillLocation`, `story_rail`,
    `marketplace_provider`. `edit_profile_screen` a déjà un `else` de repli.

---

## 4. Chiffrement de bout en bout et clés

### ⬜ MLS après un démarrage à froid : lire et envoyer dans une conversation chiffrée (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] A connecté, **app tuée puis relancée** (pas seulement mise en arrière-plan) : ouvrir la conversation — les messages chiffrés reçus s'affichent ; *(2026-09-16, Samsung, APK 1.2.1+20 : `force-stop` puis relance, « Testeurs » affiche le message chiffré « Test »)*
- [x] depuis A, toujours après la relance : envoyer un texte — une ligne apparaît dans `mls_messages` (et aucun `POST messages` en 400 dans les journaux d'API), B le lit ;
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Pixel relancé à froid (force-stop + lien profond, session conservée) → PA6SECRET, PA7, PA8–10 dans `mls_messages`, lus par Sim.
- [x] **1:1 chiffré après réinstallation des DEUX téléphones** *(2026-09-16, 18:15 UTC, Samsung puis Pixel réinstallés depuis le partage interne : commit de rejointure `60dfb704` à l'epoch 3, puis « Hi » publié dans `mls_messages` à l'epoch 4 et notification créée pour le Pixel — la LECTURE côté Pixel reste à voir)* (le second défaut du même jour) : A envoie dans la discussion — il part (une ligne `mls_commits` du nouvel appareil de A précède le message), sans que B ait rien fait. Avant le correctif : « Non envoyé » pour toujours, faute de membre vivant pour envoyer le Welcome ; un 1:1 refusait toute jointure externe. Désormais permise au seul compte qui avait déjà un appareil dans le groupe (`_jointureExternePossible`, `mls_conversation_service.dart`), cas couvert par `test/banc/mls_banc_test.dart`.

---

### ⬜ « Chiffré de bout en bout » corrigé sur 8 surfaces, dont la politique de confidentialité (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] FAQ › « Mes messages sont-ils protégés ? » : la réponse est bien plus
      longue qu'avant (deux phrases au lieu d'une) — vérifier que le panneau
      dépliant ne déborde pas, et à l'échelle de police ×2
  ✅ Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : réponse en deux phrases, panneau sans débordement sur SM A515F (police 1,0, clair) et Pixel (police 1,3 + gras, sombre). Échelle ×2 non essayée (réglage système).
- [x] Réglages › Sécurité › Sauvegarde : la carte d'en-tête tient sans
      débordement, en clair comme en sombre
  ✅ Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : carte « Chiffrement des messages » sans débordement en clair (SM A515F) et en sombre à 1,3 + gras (Pixel).

---

### ⬜ L'expéditeur MLS datait lui-même ses propres messages (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Envoyer une note chiffrée : elle part, et l'aperçu de la liste montre
      son texte **sans rouvrir le fil**. Vérifié SM A515F le 2026-09-15, et
      la chaîne entière est prouvée : le serveur a daté la ligne
      `03:41:33.000957`, le cache Hive de l'appareil porte exactement
      `2026-09-16T03:41:33.000957` pour ce message, et la tuile affiche son
      texte — y compris après un tirer-pour-rafraîchir, qui est ce qui le
      faisait tomber avant.

---

### ⬜ La notification gardait le ciphertext que le message avait perdu (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Migration appliquée** : `supabase db push --linked`, puis vérifier
  qu'aucune notification `message` ne porte encore `mlsCiphertext` pour un
  message supprimé.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : `20260916030000` dans `schema_migrations`, déclencheurs présents ; 0 copie `mlsCiphertext` pour un message supprimé sur 324 ; la ligne de PA6SECRET a perdu sa copie dans la seconde de la suppression.
- [x] **Aperçu normal intact** : un message reçu et non supprimé affiche
  toujours son texte — le nettoyage ne doit pas mordre sur le cas courant.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA1 (non supprimé) garde sa copie (496 car.), bannières déchiffrées à l'écran.

---

### ⬜ Une réaction retirée disparaît vraiment de l'écran (2026-09-15)

**Priorité P1** · importance 4/5 — **Trouvé en regardant l'écran, pas le
code.** Une bulle de « Mes notes » affichait un pouce levé alors que
`mls_message_reactions` était **vide** en base. La réaction n'existait plus
côté serveur, et l'écran la montrait quand même.

La cause est la septième forme d'échec muet de ce dépôt. `MlsMetadonnees.pour`
rendait un lot **vide** dans deux cas très différents : le serveur ne porte
aucune métadonnée, et la lecture a échoué. L'appelant sortait sur le vide,
donc sans recoller — et le recollage ne fait pas qu'ajouter, il **efface**
aussi ce que le serveur ne porte plus. Le fil venant du cache de l'appareil,
les réactions, étoiles et marques d'hier restaient figées.

Conséquence : une réaction retirée restait affichée pour toujours, et une
réaction dont l'écriture avait échoué **paraissait avoir pris**.

Le lot porte maintenant un drapeau `lu`. On sort sur l'échec de lecture, plus
sur le vide — une coupure réseau ne doit pas non plus effacer tout l'écran.

Fichiers : [mls_metadonnees.dart](lib/core/crypto/mls/mls_metadonnees.dart)
(`illisible`), [mls_gateway.dart](lib/core/crypto/mls/mls_gateway.dart)
(`_avecMetadonnees`). Couvert hors appareil par
[metadonnees_absence_vs_echec_test.dart](test/core/crypto/metadonnees_absence_vs_echec_test.dart)
(4 cas).

- [x] **Le badge d'une réaction absente du serveur disparaît** : vérifié le
      2026-09-16 sur SM A515F, et par le meilleur des témoins — un pouce levé
      qui traînait sur « SondeA » depuis la veille, alors que
      `mls_message_reactions` ne portait **aucune** ligne pour cette
      conversation. Build neuf installé, discussion rouverte : le badge a
      disparu. C'est exactement le cas que le correctif vise, observé sur une
      donnée réelle et non fabriquée.
- [x] **Réagir puis retirer la réaction dans la foulée** : le badge disparaît,
      et `mls_message_reactions` ne porte plus la ligne. Reste à faire — le
      téléphone était tenu par une autre session.
      ✅ Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim), 1:1 MLS : ❤️ sur PH1 retiré (double tap → ❤️) → badge parti
      à l'écran, 0 ligne `mls_message_reactions` pour PH1.
- [x] **Étoiler puis retirer** : même chose côté `mls_message_stars`.
      ✅ Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : PJ1 étoilé puis désétoilé → ligne retirée de
      `mls_message_stars`, étoile partie de la bulle (PK1 garde la sienne). La LISTE
      des favoris, elle, ne suivait pas — défaut corrigé le 2026-09-22, voir
      « Recherche, favoris et galerie d'une conversation chiffrée ».
- [x] **Réagir hors ligne** : le badge ne doit pas rester figé comme un succès
      une fois la connexion revenue sans que rien n'ait été écrit.
      ✅ Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : mode avion, 😮 sur PJ2 → badge affiché, puis **retiré seul
      en moins de 16 s** ; réseau rétabli : aucune ligne écrite après coup. Aucun
      message n'a été vu à l'écran pour dire l'échec (le badge disparaît sans
      explication).
- [x] **Couper le réseau sur un fil qui porte des réactions** : elles restent
      affichées, elles ne s'effacent pas d'un coup. C'est l'autre moitié du
      correctif.
      ✅ Passe du 2026-09-22 (suite, ~01:20–01:40), build Play 1.2.2+26 (f22aaff), SM A515F (Sim) : mode avion + relance à froid → les réactions restent
      affichées, rien ne s'efface d'un coup.
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

### ⬜ Ouvrir une discussion ne la bascule plus (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Ouvrir une discussion jamais basculée, drapeau ouvert, sans rien
      écrire** : vérifié le 2026-09-15 sur SM A515F, conversation
      `97ac9997…` (7 messages en clair). Ouverte, laissée trois minutes,
      `mls_since` est resté **nul** et le compteur de conversations basculées
      n'a pas bougé. Que MLS était bien actif est prouvé par la suite : le
      même écran a fait tomber la garde de bascule douze minutes plus tard.

---

### ⬜ Une conversation ne bascule plus sans ses participants (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Deux comptes, un seul à jour** : vérifié le 2026-09-15 sur SM A515F.
      Message envoyé à « Test Appareil », qui n'a aucun appareil MLS. Résultat
      exact attendu : la ligne est allée dans `messages` (le clair, 8 → 9),
      `mls_since` est resté **nul**, aucune ligne dans `mls_messages`, et
      `mls_diagnostics` a reçu `bascule_refusee_sans_appareil` à 21:58:55 avec
      `participants_sans_appareil: 1`. Le message n'est pas perdu, la
      conversation n'est pas gelée, et le refus se voit.

---

### ⬜ Code de sécurité d'un appareil MLS (phase 7, 2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le code s'affiche** sous chaque appareil du registre MLS, en 12
  groupes de 5 chiffres, lisible sans troncature. ✅ SM A515F, 2026-09-15 :
  `22230 38146 54707 62226 81456 64965 10205 68341 64687 01548 66580 85468`,
  **recalculé indépendamment** (Python, depuis `mls_identity` et
  `signature_key` de la production) — identique chiffre pour chiffre. Le
  rendu anglais reste à voir.
- [x] **Sélection et copie** du code fonctionnent (comparer par message écrit
  est le second canal le plus courant).
  ✅ Passe du 2026-09-22 (~03:20–03:35), build Play 1.2.2+26 (f22aaff), SM A515F : appui long sur le code → menu système « Copier /
  Partager / Tout sélectionner » ; « Tout sélectionner » + « Copier », collé
  dans le champ de recherche de la messagerie : les 12 groupes, identiques à
  l'écran (champ vidé ensuite).
- [x] **Le QR s'affiche** et se met en page. ✅ SM A515F, 2026-09-15 — après
  correction : il s'ouvrait **entièrement vide**, sans titre ni bouton.
  `AlertDialog` mesure son contenu par dimensions intrinsèques et
  `QrImageView` contient un `LayoutBuilder`, qui ne sait pas y répondre. Rien
  dans `logcat` et pas d'écran rouge — `FlutterError.onError` part chez
  Crashlytics ; il a fallu `flutter attach` pour lire la cause. Tenu par
  `test/core/crypto/mls_code_qr_test.dart`, qui rejoue le dialogue entier.

---

### ✅ Le bandeau « 1 message non lu » d'une conversation basculée (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Bandeau disparu** : vérifié le 2026-09-15 sur SM A515F, build debug
      réinstallé, « Mes notes » rouverte. Le fil montre le séparateur puis les
      trois messages chiffrés, et plus aucun « non lu ».
- [x] **Un vrai non-lu s'affiche toujours** : à deux comptes, recevoir un
      message sans ouvrir la discussion, puis l'ouvrir — le bandeau doit
      apparaître au bon endroit, au-dessus du message reçu.
      ✅ Passe du 2026-09-22 (~03:20–03:35), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PS1–PS3 reçus app fermée puis discussion ouverte →
      « 3 messages non lus » juste au-dessus de PS1 ; de même « 1 message non lu »
      au-dessus de PU1 puis de PS5.

---

### ⬜ MLS ouvert pour un seul compte (phase 5, 2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Compte listé, première conversation** : vérifié le 2026-09-15 sur
      SM A515F, dans « Mes notes » (un seul participant, personne d'autre
      engagé). `mls_since` posé à 13:53:59 UTC, un commit à l'epoch 0, **deux**
      lignes dans `mls_messages` (371 et 388 octets), et les 15 messages en
      clair intacts au-dessus du séparateur « Messages d'avant le chiffrement
      de bout en bout ». Aucune ligne dans `mls_diagnostics`. Et le serveur ne
      lit rien : chercher le texte des deux messages dans les ciphertexts rend
      zéro. **C'est la preuve de vie de la phase 5.**
- [x] **L'autre bout n'est pas listé** : c'est le cas qui décide. Vérifier ce
      que voit le destinataire, et que rien ne se perd en silence.
      ✅ Passe du 2026-09-22 (~03:20–03:35), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Salim n'est pas dans `mlsMessagesComptes`, Sim oui. Côté
      Salim, **rien ne se perd** : sur toute la passe du 2026-09-22, messages,
      réactions, modifications (« modifié »), sondages, séparateur et bannières
      déchiffrées lui arrivent. Ce qu'il voit d'autre : Réglages › Sécurité ›
      Appareils reste sur la **liste Signal** (« Inscrits : 2 sur 5 »,
      empreintes), sans registre MLS ni **code de sécurité**, alors qu'il a 2
      appareils MLS actifs (7 au total) dans `mls_devices` — l'écran choisit sur
      le drapeau du compte (`mlsMessagesActifsProvider`), pas sur « a des
      discussions chiffrées ». Il ne peut donc pas vérifier la clé de son
      interlocuteur ni la sienne.
      **Corrigé le 2026-09-22** (branche `claude/ecran-appareils-2209`) : hors
      drapeau, dès qu'un appareil MLS non révoqué existe, l'écran ajoute sous
      la liste Signal une section « Discussions chiffrées de bout en bout »
      (registre, codes de sécurité, révocation) — `registreMlsEnPlus`, gardes
      `test/features/settings/ecran_appareils_registre_mls_test.dart` et
      `appareils_et_sauvegarde_selon_mls_test.dart`.

---

### ⬜ L'état MLS ne quitte plus l'appareil (sauvegardes, 2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Rien ne casse au démarrage** : vérifié le 2026-09-15 sur SM A515F.
      APK debug arm64 installé par-dessus l'existant (`install -r`, Success),
      app lancée, aucune `E/flutter` ni `FATAL` dans logcat. Les deux règles
      sont bien compilées dans l'APK et référencées par le manifeste fusionné
      (`aapt2 dump xmltree`), ce qu'aucun test de structure ne peut dire.
      Au passage, le moteur Rust charge en debug comme en release et
      l'appareil se réinscrit avec la **même** identité — la base SQLite a
      survécu à la réinstallation, et l'idempotence tient.

---

### ⬜ Recherche, favoris et galerie d'une conversation chiffrée (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Chercher un mot d'un message chiffré** : il ressort, avec sa bulle et
      son horodatage justes.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0), 1:1 MLS : « PJ2 » → « Salim L. a raison PJ2 · 20:12 » ;
      « PF1 » (envoyé par Sim) → « PF1 · 19:31 ». ⚠️ Le fond de la liste de
      résultats est translucide : le fil se lit en transparence derrière.
- [x] **Chercher un mot d'avant la bascule** : il ressort aussi, sous le
      séparateur.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : « test » ressort `test-logs` (09/09) et `CLEF-TEST-1741`.
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
- [x] **Un mot présent des deux côtés** : une seule occurrence par message,
      pas de doublon.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : « PE1 » → une seule ligne (la citation dans PF1 ne
      double pas) ; « Yo » → 4 lignes distinctes, aucun doublon.
- [x] **Étoiler un message chiffré, puis ouvrir la liste des favoris** : il y
      est. C'était le défaut le plus trompeur, l'étoile s'affichant dans le
      fil pendant que la liste restait vide.
      ✅ Passe du 2026-09-22, build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : PJ1 étoilé (`mls_message_stars`, 00:21:43) → la liste
      montre PK1 et PJ1, avec « Aller au message ».

---

### ⬜ Banc MLS bout en bout contre la vraie base (phase 3, 2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le banc passe** en entier sur la base de production — **14 cas, le
  2026-09-15 à 05:58**, RLS réel, moteur Rust chargé dans `flutter test`.
  Trafic produit : 98 messages chiffrés, 68 commits, 41 Welcome, 24
  conversations basculées.
- [x] **Il échoue quand on casse un cas exprès** — vérifié le 2026-09-15 :
  l'AAD de commit retiré de `add_members`, deux cas tombent (le message d'un
  epoch passé et la révocation), parce qu'un commit sans AAD devient
  illisible pour les autres membres. Moteur restauré, banc revenu au vert.
- [x] **`mls_diagnostics` ne contient que les lignes attendues** :
  `decrypt_failed` (messages antérieurs à un ajout, appareil révoqué),
  `commit_perdu` (cas concurrent), `identite_mls_changee` (réinstallations).
  `commit_illisible` et `epoch_futur` n'apparaissent que sur le passage
  saboté — c'est ce qui rend le sabotage visible en base.

---

### ⬜ Registre d'appareils MLS — inscription à la connexion, KeyPackages, écran (phase 2, 2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Démarrage de l'app** (build release) : vérifié le 2026-09-15 sur
  SM A515F — l'app démarre et s'inscrit, donc `RustLib.init()` a chargé
  `libdiaspo_mls.so` sans planter (sans elle, aucune ligne n'aurait été
  écrite).
- [x] **Inscription** : ligne `mls_devices` du compte « Sim A »
  (`vQZE49dT…`), `platform = 'android'`, `name = 'Samsung SM-A515F'`,
  créée à 05:47, et **51** lignes `mls_key_packages` (50 + 1
  `is_last_resort`). **C'est la preuve de vie de la phase 2.**
- [x] **Idempotence** : une seule ligne, `last_seen_at` avancé à 06:09 après
  un second lancement, toujours 51 paquets — aucun nouveau tant qu'il en
  reste ≥ 10.
- [x] **Écran Appareils** : vérifié le 2026-09-15 sur SM A515F (build
  sideloadé versionCode 19). Sous l'avertissement des 5 appareils Signal, la
  section « Nouveau registre (MLS) » porte son texte d'explication puis une
  seule carte, bordée de vert : « Samsung SM-A515F », le badge « CET
  APPAREIL » en vert, et « 15/09 04:33 » — la dernière vue, avancée par le
  lancement même. **Aucun bouton Révoquer sur cette carte**, alors que les
  trois cartes Signal au-dessus en portent un : c'est la garde attendue.
- [x] **Thème sombre** : vérifié le 2026-09-15 sur SM A515F, même écran en
  `uimode night yes`. Le titre, le texte d'explication et la date passent en
  clair sur fond noir, la bordure et le badge « CET APPAREIL » restent verts
  et lisibles — aucun jeton clair figé, le défaut que ce dépôt a déjà payé
  48 fois.

---

### ⬜ Citations et modifications : plus de texte en clair (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **La citation survit à un accusé de lecture** : même piège que les
  cartes ; le flux de mises à jour rend la ligne brute.
  **✅ 2026-09-11 17:56-17:58, SM A515F (Sim A) ↔ Pixel (Salim L.), build 18.**
  `REPONSE-TEXTE-1756` répond à `CLEF-APRES-1745` : la citation s'affiche des
  **deux** côtés (« Vous » chez l'expéditeur, « Sim A » chez l'autre), et elle
  est toujours là côté expéditeur après le passage à « Lu ». En base, le
  message porte `encAnnexes` et **aucun** `replyToMessageData` en clair.
- [x] **Modifier un message de « Mes notes »** (aucun destinataire, chemin
  `selfNote`). **✅ 2026-09-11 18:16, SM A515F.** `NOTE-1811` → `…-EDIT` :
  bulle « modifié », et en base contenu **rechiffré** `v1:Oag0XsFuP…`,
  `editedAt` posé, historique à 1 entrée sans `content`. Le chemin
  `encryptSelfNote` profite donc aussi des clés dérivées.
- [x] **Rouvrir la conversation après avoir modifié** : côté EXPÉDITEUR, le
  texte modifié doit rester. **✅ 2026-09-11 18:09** : `am force-stop` puis
  réouverture par lien profond — la bulle affiche toujours
  `…-EDIT1-EDIT2`, donc le cache local a bien été réécrit. Il ne sait pas relire son propre message chiffré
  (les charges Signal visent les appareils du destinataire) : sa bulle vient du
  cache, qui est réécrit à la modification. Si le texte d'avant revient, c'est
  cette réécriture qui a manqué.
- [x] **Modifier deux fois de suite** le même message : la deuxième
  modification doit rester lisible (les charges du format précédent sont
  purgées avant d'écrire les nouvelles).
  **✅ 2026-09-11 18:08** : `…-EDIT1` puis `…-EDIT1-EDIT2` ; contenu rechiffré
  à chaque fois (`v1:W/IS7Kf…`), `editHistory` à 2 entrées, aucune avec texte,
  et la bulle reste lisible chez l'expéditeur comme sur le Pixel.
- [x] **En base** : `select data->>'content' from messages where data ?
  'editedAt'` ne doit plus rien montrer de lisible, et
  `data->'editHistory'` ne doit plus contenir de champ `content`.
  **✅ 2026-09-11, sur TOUTE la table `messages`** (pas seulement le message de
  test) : 1 seul message porte `editedAt`, son contenu est au format dérivé
  `v1:`, 0 contenu lisible, et **0** entrée d'`editHistory` portant `content`.

---

### ✅ Rappel des clés : « Ne plus me le rappeler » — vérifié SM A515F (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le bandeau global à trois boutons.** « Ne plus me le rappeler » +
      « Pas maintenant » + « Restaurer », en français, portrait, densité 420 /
      échelle de police 1,0 : aucun débordement, `OverflowBar` empile les trois
      actions. ⚠️ Il occupe alors ~22 % de la hauteur d'écran — voir la note
      plus bas. **Repassé le 2026-09-08 en échelle de police 1,3 et densité
      440** (la configuration qui a déjà fait déborder d'autres rangées) : rien
      ne déborde, le message passe à trois lignes et le bandeau occupe ~27 % de
      la hauteur en portrait ; **en paysage les trois actions tiennent sur une
      seule ligne**.
- [x] **Le rappel se tait pour de bon.** Tap « Ne plus me le rappeler » →
      `e2ee_prompt_snoozed_needsRestore_<uid>` passe à `-1` immédiatement →
      `am force-stop` + relance à froid : le bandeau ne revient pas. Confirmé
      aussi après réinstallation de l'APK (la veille survit à `install -r`).
- [x] **Le bandeau de conversation obéit — dans les deux sens.** Fil de groupe
      « Diaspora Niger — Canada », entièrement illisible : veille active → pas
      de bandeau jaune ; veille retirée → bandeau jaune présent, avec le
      bandeau global au-dessus.

---

### ⚠️ Clés dérivées : premier test appareil (2026-09-07, SM A515F)

**Priorité P0** · importance 5/5 — Si `crypto-keys` renvoie encore une liste vide, tous les messages rechiffrés à la clé dérivée s'affichent « [Message illisible] » pour tout le monde, sans aucune erreur.

Testé sur SM A515F avec un build propre (`flutter clean` obligatoire — un APK
du 30 août traînait dans `build/` et se serait installé en silence).

**Vérifié bon** : démarrage, `SupabaseAuthBridge: session sync OK`, liste des
conversations et aperçus en clair, messages en clé globale lisibles, aucun
crash (le process tué en cours de test l'a été par une commande externe, pas
par une exception).

**DÉFAUT TROUVÉ ET CORRIGÉ** : tous les messages rechiffrés s'affichaient
`[Message illisible]`. L'Edge Function `crypto-keys` filtrait les conversations
avec `.contains('participant_ids', [user.id])`, où `user.id` est l'uuid
Supabase — alors que `participant_ids` contient des **UID Firebase hérités**
(`vQZE49dTdyRtLwSG6lMIbhAqoFG2`). Le filtre ne correspondait jamais :
l'endpoint répondait **200 avec une liste vide**, donc aucune clé de
conversation, donc tout illisible. Aucune erreur nulle part.

Trace décisive, une fois l'instrumentation ajoutée :
`DerivedKeyStore: 1 clé(s) reçue(s)` — la clé utilisateur seule, zéro
conversation, alors que le compte en a 4.

Corrigé en retirant le filtre : la RLS de `conversations`
(`participant_ids @> ARRAY[firebase_uid()]`) faisait déjà le travail,
correctement. **Ne jamais réintroduire ce filtre applicatif.**

- [x] **À revérifier après redéploiement de `crypto-keys`** : rouvrir la
      conversation `debef5f0…`, ses 2 messages rechiffrés doivent s'afficher.
      **✅ 2026-09-11 17:47, Pixel 10 Pro XL (Salim L.), thème sombre.** Les
      deux seuls messages `v1:` de la conversation (2026-08-23 04:03 et
      2026-08-31 02:55 UTC, envoyés par Sim A) s'affichent en clair : la
      carte d'événement « 📅 testeur » et « test-verif-lu-auto-2026-08-30 ».
      Aucun « Message indisponible » dans le fil.
- [x] Puis envoyer un message : il doit partir au format `v1:…` en base.
      **✅ 2026-09-11, SM A515F (Sim A) → Pixel (Salim L.), build 18.**
      Cause trouvée d'abord : le correctif de `crypto-keys` (`9b737ea`,
      2026-09-07 20:13 UTC) n'avait **jamais été déployé**. La version en
      ligne (v2, déployée à 03:05 UTC le même jour) portait encore
      `.contains('participant_ids', [user.id])` — vérifié en retéléchargeant
      le code déployé, pas supposé. Conséquence mesurée en base : depuis le
      2026-08-31, **0 message au format dérivé**, tout partait à la clé
      globale, celle que tout porteur de l'APK sait lire.
      Avant/après : `CLEF-TEST-1741` (21:43 UTC) part à la clé globale ;
      `crypto-keys` redéployée seule (v3, 21:44 UTC, accord de Salim) ;
      relance à froid du SM A515F ; `CLEF-APRES-1745` (21:45 UTC) part en
      `v1:K4Hj…`. Sur le Pixel, **sans redémarrage**, la bulle s'affiche en
      clair : la clé de conversation manquante est obtenue à la demande.

---

### ⬜ Clés de repli dérivées, servies par `crypto-keys` (2026-09-06)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Aperçu de notification** après le branchement : le corps doit rester le
      vrai texte (`decrypt_aes_fallback` devra dériver `K_conv`), pas du base64
      ni « Nouveau message ».
      **✅ 2026-09-11 18:23, Pixel (Salim L.) → SM A515F (Sim A), build 18.**
      Message envoyé depuis le Pixel, stocké `v1:cQdYIRJlvV5…` — donc chiffré
      avec la clé dérivée de la conversation, pas la clé globale. Sur le
      SM A515F, app en arrière-plan, la notification porte
      `android.title = « Salim L. »` et `android.text = « NOTIF-TEST-1823 »`
      (relevé par `dumpsys notification --noredact`, canal `msg_debef5f0…`).
      Le déchiffrement côté Postgres dérive donc bien `K_conv`. Trajet complet
      Pixel → FCM → appareil en ~1 s.

---

### Bandeau « Restaurez vos clés » toujours répété malgré la mise en veille du 22/08 (2026-08-25)

Salim signale que le bandeau (`e2eeRestoreNudgeMessage`, main_shell.dart)
revient encore « très très souvent » — y compris après un tap sur
« Pas maintenant » — alors que le correctif de mise en veille persistée 7 jours
(commit `4464780`, 2026-08-22) est bien dans l'APK installé
(`lastUpdateTime=2026-08-25 11:40`, largement postérieur au commit).

**Constaté sur SM A515F** (compte Sim A, `vQZE49dTdyRtLwSG6lMIbhAqoFG2`) :
`run-as com.diasponiger.diasponiger cat shared_prefs/FlutterSharedPreferences.xml`
ne contient **aucune** clé `e2ee_prompt_snoozed_*`, alors que d'autres prefs
du même fichier (session Supabase, thème, `has_seen_onboarding_…`) sont bien
présentes. Le mécanisme de mise en veille n'a donc jamais réussi à écrire sur
cet appareil — ou n'a jamais été déclenché avec succès.

Cause non confirmée à ce stade : `_isSnoozed`/`_snooze`
([e2ee_backup_coordinator.dart](lib/core/services/e2ee/e2ee_backup_coordinator.dart))
avalaient toute exception sans laisser de trace, impossible de distinguer
« jamais appelé » de « appelé et en échec ». Un `debugPrint` a été ajouté sur
l'échec (poussé sur la branche partagée).

- [x] **Reproduit et confirmé fonctionnel le 2026-08-25, même session, une
  fois le compte reconnecté par Salim.** Séquence : app au premier plan
  (compte Sim A), tap « Pas maintenant », `run-as … cat
  FlutterSharedPreferences.xml` → `flutter.e2ee_prompt_snoozed_needsRestore_…`
  bien présent. Puis `am force-stop` + relance à froid (`monkey`, ~16 s) :
  la clé **survit** (même valeur), et le bandeau **ne réapparaît pas** sur
  l'écran d'accueil. Le mécanisme fonctionne donc correctement dans l'usage
  normal (app ouverte le temps du tap, puis fermée). La série de 7
  redémarrages sans aucune clé écrite, observée plus tôt dans la même
  session, reste inexpliquée avec certitude — hypothèse la plus probable :
  aucun de ces redémarrages n'incluait un tap réel sur « Pas maintenant »
  (compte déconnecté à un moment donné pendant cette série). Le
  `debugPrint` ajouté reste utile en filet si un échec d'écriture silencieux
  se reproduit.

---

### E2EE réparé : la clé de signature est publiée avec le bundle (2026-08-23)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Après mise à jour, l'appareil republie : `signed_pre_key` porte
      `identitySigningKey` en base (appareil `be32f0e9…`, actif à 22:43).
- [x] Le journal dit la vérité au lieu d'accuser un MITM :
      « U64HK… (appareil 1) n'a pas publié sa clé de signature — session Signal
      impossible, repli AES », puis « Sender Key remise à 0/2 membres — repli
      AES maintenu ».
- [x] **L'en-tête affiche « 3 membres 🔓 Clé partagée »** — ce qui valide au
      passage l'indicateur du commit précédent, que je n'avais pas pu voir.
- [x] Le débordement introduit au premier jet (« 3 me… » tronqué) est corrigé :
      les deux libellés sont `Flexible` avec ellipsis.

---

### Le repli AES d'un groupe est désormais signalé (2026-08-23)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Logique couverte par
      [group_encryption_status_test.dart](test/features/messages/group_encryption_status_test.dart)
      (9 tests) : distribution complète / partielle / impossible, et le fait
      qu'un groupe sans autre membre ne compte pas comme « chiffré ».
- [x] **Rendu vérifié** le 2026-08-23 : « Diaspora Niger — Canada » affichait
      « 3 membres 🔓 Clé partagée » dans l'en-tête.

---

### Sender Key : l'envoi fabriquait une clé que personne n'avait — RÉSOLU (2026-08-23)

La cause de fond des messages de groupe illisibles, sous le symptôme déjà
traité côté affichage.

`SenderKeyService.encryptWithSenderKey` faisait
`senderKey ??= await createSenderKey(groupId)`. **L'envoi fabriquait donc une
Sender Key à la volée et chiffrait avec, sans la remettre à personne.** Le
message était illisible par tout le groupe, définitivement — et pas rattrapable
après coup : `decryptWithSenderKey` refuse un index de chaîne passé, et le
ratchet avance à l'émission. Distribuer ensuite arrive toujours trop tard d'un
cran.

Le repli AES existait pourtant, annoncé par le commentaire de `encryptGroup`
(« AES-GCM fallback for groups without established Sender Keys ») — mais cette
ligne le rendait **inatteignable**.

Ce qui change :

- `E2EESenderKey` porte `isDistributed`, faux par défaut **y compris pour les
  clés déjà en stockage** : elles ont été fabriquées par l'ancien chemin, les
  relire comme distribuées produirait de nouveaux messages illisibles.
- `distributeSenderKey` renvoie désormais `true`/`false` — elle échouait en
  silence quand aucune session Signal n'existait avec le membre.
- `distributeSenderKeyToGroup` ne marque la clé distribuée que si **chaque**
  autre membre l'a reçue. Sinon on reste en AES : un message qu'une partie du
  groupe ne peut pas lire est pire qu'un message chiffré avec la clé partagée.
- `encryptWithSenderKey` ne crée plus rien et rend `null` tant que la clé n'est
  pas distribuée → repli AES, lisible par tout le monde.

**Vérifié sur SM A515F**, et confirmé en base :

- [x] Message envoyé dans « Diaspora Niger — Canada » : **lisible** à l'envoi.
- [x] **Toujours lisible** après avoir quitté la discussion et l'avoir rouverte
      — ce qui valide au passage la persistance du texte clair, non vérifiée à
      la session précédente.
- [x] `messages.data->>'encryptionLevel'` : le nouveau message est `aes`, les
      trois anciens sont `e2ee`. Le repli est bien pris, et le diagnostic est
      confirmé par la donnée.

**Conséquence assumée** : le premier message d'un groupe part en AES tant que la
distribution n'a pas abouti pour tous les membres. C'est un cran de moins que le
chiffrement de groupe, mais c'est le comportement que le code annonçait déjà —
et infiniment mieux qu'un message que personne ne peut lire.

**Traité** le 2026-08-23 : le repli AES est désormais signalé dans l'en-tête de
la conversation (cadenas ouvert + « Chiffrement partagé », appui explicatif).
Voir l'entrée « Le repli AES d'un groupe est désormais signalé » ci-dessus.

**Non réparable** : les messages envoyés avant ce correctif restent illisibles
pour toujours. Il en traîne trois dans « Diaspora Niger — Canada », dont mes
messages de test.

---

### Le message de groupe illisible par son propre expéditeur — CAUSE TROUVÉE (2026-08-23)

Constaté sur SM A515F : le message qu'on vient d'envoyer dans un groupe
s'affiche **« 🔒 Message chiffré — clé de groupe introuvable »**, à son propre
auteur, une seconde après l'envoi. Il porte pourtant « Vu par 1 ».

**Ce n'est pas un défaut de chiffrement.** Signal (1:1) comme Sender Key
(groupes) font avancer le ratchet à l'émission et ne conservent pas la clé du
message envoyé : le texte clair de NOS messages n'existe que localement, par
construction. C'est un choix du protocole, pas un accident. Deux endroits le
laissaient filer.

**1. L'écho temps réel écrasait le texte clair.** `_reconcileEcho` gardait bien
la copie locale quand l'écho revenait illisible — mais son filtre ne
connaissait QUE `🔐 Message chiffré`. Les groupes remontent l'autre
placeholder, `[🔐 E2EE — session requise]` : l'écho passait au travers. La
liste existait en double, ici et dans `_undecryptablePlaceholders` du
repository — qui, lui, connaissait les deux — et elle avait divergé. Elle vit
désormais dans
[undecryptable_placeholders.dart](lib/core/services/e2ee/undecryptable_placeholders.dart),
avec la règle de fusion sous forme de fonction pure, testée.

**2. Le cache était empoisonné.** `getNewMessagesStream` mettait en cache les
messages du serveur tels quels, placeholder compris, et `cacheMessages`
fusionne par id avec la nouvelle version qui l'emporte. Le texte clair de
l'expéditeur n'était donc **jamais persisté** : à la réouverture de la
discussion, `_healUndecryptable` n'avait plus rien de bon à récupérer. Le flux
passe maintenant par le même soin que la pagination, et `sendTextMessage` met
le texte clair en cache dès l'envoi.

- [x] **Point 1 vérifié sur appareil** : « essai after fix » reste lisible
      douze secondes après l'envoi, là où il basculait en placeholder.
- [x] **Point 2 vérifié** le 2026-08-23, en même temps que le correctif Sender
      Key ci-dessus : message envoyé dans un groupe, discussion quittée puis
      rouverte — le texte reste lisible.

**Ce qui reste vrai, et n'est pas corrigé** : les messages envoyés AVANT ce
correctif restent illisibles pour toujours — leur texte clair n'a jamais été
persisté nulle part, et le chiffré ne se relit pas. Trois d'entre eux traînent
dans « Diaspora Niger — Canada ».

**Non exploré** : pourquoi la Sender Key n'est-elle pas établie au moment du
premier envoi ? `distributeGroupSenderKey` part en « fire and forget » au
chargement de la conversation (message_provider.dart) ; un envoi qui le précède
chiffre avec une clé que l'appareil ne sait pas relire. Le correctif ci-dessus
rend le symptôme invisible, il ne change pas ça.

---

## 5. Appels

### La bulle d'appel elle-même n'apparaissait jamais dans la conversation (2026-08-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

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

---

### 🔴 Appels 1-à-1 mis en PAUSE (2026-08-14) — répondre à un appel ne faisait rigoureusement rien

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **`callNotificationHandlerProvider` n'était jamais lu** (`lib/app.dart`) —
  Riverpod est paresseux : sans un `ref.watch` quelque part, ce `Notifier` ne
  se construit jamais, donc `_listenToNativeCallEvents()` et
  `_checkPendingCallsOnStart()` ne tournaient JAMAIS. Confirmé par
  `git log -S` sur tout l'historique : ce provider n'a été lu nulle part
  depuis sa création (`fcf821b`). Conséquence : accepter un appel depuis la
  bannière CallKit native (écran verrouillé ou app tuée) n'invoquait jamais
  `answerCall()` — la bannière se refermait, rien d'autre ne se passait.
  Explique pourquoi les vérifications « Acceptation depuis l'écran verrouillé »
  du bloc précédent (2026-08-03) n'ont jamais pu être concluantes : le
  réglage manifest était correct, mais rien en dessous n'écoutait.
  Correctif : `ref.watch(callNotificationHandlerProvider)` ajouté dans
  `_NigerDiasporaAppState.build()`. **Vérifié sur device (SM A515F +
  émulateur, 2026-08-14) : décroché, connecté.**
- [x] **Second appel pendant qu'un premier est en cours** (`call_provider.dart`,
  commit `6f572a9`) : `answerCall()` refusait en silence tout appel entrant
  différent de celui déjà suivi par `state.call` — y compris quand ce
  `state.call` était son PROPRE appel sortant en cours de composition.
  Décline désormais explicitement (occupé) et referme la bannière CallKit du
  second appel via `NativeCallService.endCallById` (nouveau).
- [x] **La reconnexion ICE ne retentait jamais réellement**
  (`webrtc_service.dart`) : `_attemptReconnection()` posait
  `WebRTCConnectionState.reconnecting` puis s'auto-rappelait en cas d'échec —
  mais son propre garde anti-doublon (basé sur ce même état) bloquait la
  relance. Un seul échec de signalisation transitoire (ex. jeton Firebase en
  cours de renouvellement pendant l'écriture RTDB de `ice_restart_offer`)
  achevait l'appel au bout du timeout de 30 s au lieu d'épuiser ses 3
  tentatives. Logique de relance extraite dans `_retryIceRestart()`, séparée
  du garde d'état.
- [x] Confusion « appel manqué » côté appelant (`call_message_service.dart`,
  `call_message_bubble.dart`, `conversation_item.dart`) : le même aperçu de
  message est vu par les deux côtés d'un appel sans réponse ; « manqué »
  sous-entend « vous avez manqué cet appel », faux pour l'appelant. Libellé
  neutre (« Pas de réponse ») des deux côtés.

---

### Message d'appel : aperçu et badge non-lu ne se mettaient jamais à jour (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Passer ou recevoir un appel (audio ou vidéo), le laisser sonner sans
  décrocher puis raccrocher → dans la liste des conversations, la
  conversation remonte en tête et l'aperçu affiche « 📞 Appel {audio/vidéo}
  manqué/refusé/sortant » (pas l'ancien dernier message texte). **Vérifié le
  2026-08-14 sur SM A515F (compte Sim) ↔ Pixel 10 Pro XL (compte Salim L.),
  vrai appel audio 1:1 non décroché** : côté Sim, « Salim L. / Vous : Appel
  audio manqué » remonte en tête de liste ; seul le variant manqué/pas de
  réponse a été exercé, pas refusé/occupé/sortant annulé.
- [x] Depuis le téléphone qui n'a **pas** initié l'appel, vérifier que le
  badge non-lu de cette conversation s'incrémente après l'appel (et
  redescend à 0 en rouvrant la conversation). **Vérifié le 2026-08-14** :
  côté Salim L. (non-initiateur), badge rouge « 1 » sur la conversation
  « Sim A » après l'appel manqué. Redescente à 0 à la réouverture non
  contrôlée séparément (la conversation a été ouverte dans la foulée).

---

### Appels WebRTC

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Étanchéité de la signalisation** (2026-08-03) : avec un **troisième** compte, vérifier qu'il ne peut ni lire ni écrire le nœud d'un appel auquel il ne participe pas. Se teste depuis la console Firebase (simulateur de règles) avec l'UID du tiers sur `calls/<id>` — doit refuser lecture et écriture.
      **✅ Mesuré le 2026-09-14 par le banc, sans appareil.**
      `firebase emulators:start --only database` puis
      `node tools/rules_tests/signalisation_appels.mjs` : « un tiers lit la
      signalisation de A vers B » → **refusé (401)** ; « un ANONYME pose la
      clé absente » → refusé ; « un TIERS remplace la clé existante » →
      refusé ; « un TIERS lit la clé » → refusé. Verdict du banc :
      **parcours nominal INTACT, étanchéité fermée**.
      **Et ça vaut pour la production** : `database:get "/.settings/rules"`
      comparé au fichier du dépôt donne **88 règles de chaque côté, zéro
      écart** — l'émulateur a donc chargé exactement les règles déployées.
      ⚠️ Le banc signale en revanche **« client périmé : CASSÉ »** : un APK
      antérieur au 2026-08-06 écoute `participants` avant de s'y inscrire et
      mourrait en silence. Sans conséquence aujourd'hui (les deux téléphones
      portent les builds 18 et 19, et l'app n'est pas publiée), mais à
      garder en tête avant toute ouverture au public.

---

## 6. Notifications et push

### ⬜ Notifications entre comptes : le serveur rédige le texte et filtre les données (2026-09-21)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **un push réel passe par la v33** — relire `net._http_response` après
  la prochaine notification (HTTP 200 attendus), et qu'un message de
  discussion arrive toujours sur un téléphone.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff) : `net._http_response` sur 3 h → 46 réponses, **toutes 200**
  `{"sent":1,"removed":0}` ; la fonction déployée est désormais la **v34**
  (successeur de la v33), et les pushs arrivent bien sur le Pixel (bannières
  relues par `dumpsys notification`).

---

### ⬜ Une édition corrige la bannière déjà posée (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Bannière affichée, l'autre corrige son message** : la bannière montre
  le **nouveau** texte, **sans** sonner ni vibrer une seconde fois.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Pixel fermé, PU1 reçu → « PU1 · 02:58 » ; Sim le modifie →
  la même bannière dit « PU1 EDIT · 02:58 » (heure d'origine gardée),
  drapeaux `ONLY_ALERT_ONCE|SILENT`, `when` inchangé : pas de nouvelle alerte.
- [x] **Conversation déjà lue, l'autre corrige** : **aucune** bannière ne
  réapparaît. C'est le point le plus important.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PT1–PT10 lus, Pixel fermé, Sim modifie PT10 → aucune
  bannière dans le volet. Côté serveur, un `messageEdited` est bien créé et
  poussé (règle du 21/09 : bannière envoyée depuis 24 h, lue ou non) ; c'est
  l'appareil qui refuse de la reposer, le message n'étant plus dans sa pile.
- [x] **Édition en conversation chiffrée** : même comportement — le texte
  corrigé s'affiche, et il a bien été déchiffré sur l'appareil.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : le cas ci-dessus est en MLS — le texte corrigé de la
  bannière a été déchiffré sur l'appareil (le serveur ne voit qu'un
  `kind=control`).
- [x] **Puis ouvrir la conversation** : le message reste **lisible**. C'est le
  test du cliquet : corriger une bannière passe par la copie jetable.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : relance à froid → « PU1 EDIT · modifié », « PT9 EDIT »,
  « PT10 EDIT » lisibles, et le volet se vide.
- [x] **Pile de plusieurs messages** : seule la ligne corrigée change, elle
  garde sa place et son heure d'envoi.
  ⛔ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS (MLS) : PA2 modifié en PA2M à 18:13 ; la pile de Sim affichait encore « PA2 · 18:00 » à 18:21. L'édition ne corrige pas la ligne déjà posée.
  ✅ Passe du 2026-09-22 (~03:10–03:17), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Pixel fermé, PV1–PV3 → pile `number=3` ; Sim modifie PV2 →
  lignes « PV1 · 03:09 », « **PV2 EDIT** · 03:09 », « PV3 · 03:09 » : seule la
  ligne corrigée change, à sa place, avec son heure ; `when` et `number`
  inchangés, `ONLY_ALERT_ONCE`. (L'échec d'hier ne se reproduit plus.)
- [x] **Édition d'un message ancien** (hors des 6 de la pile) : rien ne se
  passe, et surtout aucune bannière ne surgit.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : bannière « PU1 EDIT » posée, Sim modifie PT9 (lu, hors
  pile) → volet inchangé, aucune bannière nouvelle.

---

### ⬜ Cinq messages reçus, un seul lisible : la bannière ne s'empilait pas (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **App tuée, cinq messages de la même personne** : une seule bannière,
  qui les montre **tous**, avec le compteur à 5.
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : HOME puis `am kill` ; PB1–PB5 → une bannière, `number=5`, cinq lignes dans l'ordre.
  Passe du 2026-09-22 (~02:00–02:30), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : avec **12** messages (PQ1–PQ12), la bannière montre les 6
  derniers (PQ7–PQ12, dans l'ordre, avec l'heure) — plafond voulu — mais
  `number=6` : rien ne dit que 12 messages sont arrivés.
- [x] **Ouvrir la conversation, puis recevoir un nouveau message** : la
  bannière ne montre QUE le nouveau — les lus ne reviennent pas.
  ⛔ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : la pile n'est PAS vidée par la lecture. Après avoir lu PA2 (18:02) et rouvert la discussion (18:11), la bannière de PA8–PA10 contenait encore « PA2 · 18:00 » — et « PA6SECRET · 18:14 », supprimé pour tous entre-temps : le texte supprimé reste lisible dans le volet. PA7, reçu app au premier plan, a formé une bannière séparée hors de la pile.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : cette fois la pile s'est vidée. PT1–PT10 lus par
  l'ouverture de 02:47 ; Pixel fermé, PU1 reçu à 02:58 → bannière
  `number=1`, « PU1 » seul, aucun PT. (L'échec d'hier portait sur une
  réouverture ; ici, ouverture à froid.)
- [x] **Appui sur la bannière empilée** : ouvre la bonne conversation, et la
  bannière disparaît.
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : démarrage à froid DIRECTEMENT dans la bonne discussion (« 5 messages non lus »), bannière retirée, messages lus.
- [x] **Heure affichée** sur la bannière, et c'est celle de l'**envoi**. ✅ **2026-09-16, prouvé à la milliseconde** : le `when` de la bannière du Pixel vaut `1789538396006`, et `mls_messages.created_at` du message vaut `2026-09-16 05:59:56.005661` — soit exactement le même horodatage. Même correspondance côté clair sur le SM A515F (`1789532896525` ↔ `messages.created_at 04:28:16.52452`). C'est donc bien l'heure d'ENVOI qui voyage, pas celle de la livraison. Reste à vérifier à la main :
  couper le réseau, se faire envoyer un message, rétablir. L'heure doit être
  celle de l'envoi, pas celle du retour de réseau.
- [x] **Ordre** : cinq messages d'affilée, le plus ancien **en haut**.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PA8, PA9, PA10 empilés dans une seule bannière, plus ancien en haut.
- [x] **Rattrapage hors ligne** : plusieurs messages d'un coup au retour du
  réseau, dans le bon ordre même s'ils n'arrivent pas dans cet ordre-là.
  ✅ Passe du 2026-09-22 (~03:55–04:02), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : A515F app fermée (HOME + `am kill`) et en **mode avion** ;
  Salim envoie PY1 (03:55:51), PY2 (03:56:10), PY3 (03:56:30) ; mode avion
  coupé à 03:56:52 → au plus tard 03:57:13, **une** bannière « Salim L. » avec
  PY1, PY2, PY3 **dans l'ordre**, déchiffrés, `number=3`. Côté Salim, le Pixel
  affichait Sim « En ligne » pendant tout le mode avion (présence périmée).
- [x] **Heure sur chaque ligne** de la pile, pas seulement dans l'en-tête, et
  **en fin de ligne**. ✅ **2026-09-16, deux appareils** : `dumpsys notification --noredact` rend `android.text = Cfg · 01:59` sur le Pixel (groupe chiffré) et `Ok · 01:29` sur le SM A515F (1:1 en clair), les deux sous `android.template = MessagingStyle`. ⚠️ Elle ne sera pas alignée sur le bord droit : une
  ligne de notification est du texte, pas une mise en page. Un vrai alignement
  demanderait un `RemoteViews` maison, au prix du regroupement par expéditeur
  et des avatars — à trancher à l'écran si la fin de ligne ne suffit pas.
- [x] **Message long qui passe à la ligne** : l'heure reste lisible et ne se
  retrouve pas seule sur une deuxième ligne de façon gênante.
  ✅ Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : message de 19 mots, trois lignes dans la bannière dépliée, « · 20:11 » en fin de dernière ligne, rien de perdu.
- [x] **1:1** : le texte n'a rien perdu (aucun préfixe à retirer là).
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS.
- [x] **Message dont le texte commence par le nom de l'expéditeur** (« Alice a
  raison ») : rien n'est rogné.
  ✅ Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : « Salim L. a raison PJ2 » affiché en entier sous l'en-tête « Salim L. ».
- [x] **Trois messages d'affilée du même contact** : un seul en-tête à son nom,
  trois lignes en dessous, chacune avec son heure.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : un seul en-tête « Salim L. », une ligne par message avec son heure.

---

### ⬜ Trois cas de messagerie que les notifications ne couvraient pas (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Retirer cette réaction** : la notification disparaît de la liste.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Pixel fermé, Sim pose 😮 sur PK1 → ligne `messageReaction`
  non lue + bannière ; Sim la retire → la ligne est **supprimée** (0), la
  réaction aussi. ⚠️ La **bannière** « A réagi 😮 » reste dans le volet du Pixel
  jusqu'à l'ouverture de la discussion. Et une notification déjà **lue** n'est
  pas supprimée (voulu : `AND NOT n.is_read`) — deux lignes lues 👍/🙏 de la
  veille sont restées.
- [x] **Réagir à son propre message** : aucune notification.
  ✅ Passe du 2026-09-22 (~02:50–03:00), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : Sim pose 👍 sur son PT10 → réaction enregistrée, **aucune**
  ligne `notifications` ni pour Sim ni pour Salim ; retirée ensuite.

---

### ⬜ Aperçu MLS quand l'app est OUVERTE (le même message, l'autre isolate)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **App ouverte, notification système** (couper la bannière in-app en
  ouvrant une autre discussion) : même texte dans le volet Android.
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : volet Android « PC1 · 19:22 », texte déchiffré.
- [x] **Puis ouvrir la discussion** : le message est **lisible** dans la
  bulle. C'est le test du cliquet — au premier plan, le moteur qui fait foi
  est ouvert dans le même processus que la copie jetable.
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PC1 lisible.
- [x] **Deux appareils, un aller-retour de cinq messages** app ouverte des
  deux côtés : aucun ne retombe sur « Nouveau message », aucun ne devient
  illisible dans la conversation.
  ✅ Passe du 2026-09-21 (soir), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : PD1–PD5 alternés, discussion ouverte des deux côtés : 5/5 en direct et lisibles des deux côtés.

---

### ⬜ Aperçu des notifications MLS reconstruit sur l'appareil (phase 4, Android)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **App tuée, message MLS reçu** : la bannière affiche le **vrai texte**, ✅ **2026-09-16** : la bannière du Pixel porte `Cfg`, le vrai texte d'un message d'une conversation **chiffrée** — pas le repli « Nouveau message ». Le cache `mls_apercu_*` des préférences en contient d'autres (`Hgg`, `Gy`), donc l'isolate déchiffre bien, plusieurs fois.
  Contrôle d'origine :
  pas « Nouveau message ». Sur SM A515F, `adb shell am force-stop` puis
  envoi depuis un autre appareil.
- [x] **Puis ouvrir l'app** : le même message s'affiche dans la conversation,
  **lisible**. C'est le test du piège : si l'aperçu avait consommé le
  cliquet, la bulle porterait un placeholder.
  ✅ Passe du 2026-09-21, build Play 1.2.2+26 (f22aaff) sur Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : bannière « PA1 · 17:54 » déchiffrée, puis PA1 lisible dans la discussion.
- [x] **Conversation en sourdine** : aucune notification (le trigger respecte
  `mutedBy`).
  ✅ Passe du 2026-09-21 (20 h), build Play 1.2.2+26, Pixel 10 Pro XL (Salim) + SM A515F (Sim), 1:1 MLS : sourdine 1 h posée par Sim (`mutedBy` en base), PH1 envoyé → aucune notification sur le téléphone, aucune ligne `notifications`. ⚠️ Le menu de la discussion affiche toujours « Mettre en sourdine » pendant la sourdine et n'offre pas de la lever ; seul l'appui long dans la liste propose « Réactiver les notifications ».

---

### Notification de message → « Utilisateur », écran bloqué (2026-08-30)

Signalé par Salim : taper une notification de message dans `/notifications`
ouvrait `/messages/<id>` sur un en-tête « Utilisateur » et rien d'exploitable
— pas un bug de code, de la donnée périmée. Confirmé par logcat en direct
(sans toucher au téléphone pendant que Salim l'utilisait) :

```
markAsDelivered error: PostgrestException(message: mark_messages_as_delivered: user is not a participant, code: P0001…)
```

Les conversations visées (`883c9d96-…`, `54de1817-…`, notifications datées du
12–14 août) ont été détruites par la purge `messages`/`conversations` du
2026-08-14 (voir [[project_messages_conversations_purge_2026_08_14]]) ; les
notifications, elles, ont survécu à la purge et pointaient vers un id mort.
`ConversationScreen` a bien un état `isDeleted` (ligne ~1124) qui affiche
« Ce groupe a été supprimé »/« Cette conversation a été supprimée » à la
place du composeur — mais l'en-tête retombe sur le texte générique
« Utilisateur » faute de pouvoir dériver un nom d'une conversation
inexistante, d'où l'impression de blocage total.

- [x] **Corrigé côté donnée** : 29 notifications `type='message'` dont
  `data->>targetId` ne correspond plus à aucune ligne `conversations` ont été
  supprimées en prod (`supabase db query --linked`, confirmé avec Salim avant
  le DELETE). Ce sont exclusivement de vieilles notifs de test antérieures à
  la purge — aucune conversation live touchée.
- [x] **Corrigé et vérifié sur SM A515F (2026-08-30)** : `_buildAppBar` reçoit
  désormais `isDeleted` et affiche « Conversation supprimée » au lieu du
  générique « Utilisateur ». Repro par lien profond (`am start -a VIEW -d
  https://diasponiger.web.app/messages/883c9d96-…`, id déjà confirmé
  inexistant en base) plutôt que par insertion de notification de test — un
  `INSERT` sur `notifications` a été refusé par le classificateur de
  permissions même en compte de test, l'écriture directe en base reste
  réservée à Salim. Session préservée par le rebuild+`install -r`.
- [x] **Second signalement, même jour : le flash « Utilisateur » pendant le
  chargement d'une conversation bien vivante** (pas supprimée). Par lien
  profond/notification, `widget.conversationName` est nul — il faut deux
  allers-retours successifs (conversation, puis profil du correspondant)
  avant d'avoir un vrai nom, et `displayName` retombait sur `l10n.user`
  pendant cette fenêtre avant de se corriger tout seul. Ajouté un garde
  `identityLoading` qui affiche `l10n.loading` (« Chargement... ») tant que
  l'un des deux flux n'a pas encore émis. `flutter analyze` propre. Repro
  device par lien profond vers une conversation vivante (`debef5f0-…`) après
  démarrage à froid (`force-stop` + relance) : la fenêtre s'est résolue plus
  vite que le round-trip `adb screencap` (deux captures rapprochées montrent
  directement le bon nom, jamais « Utilisateur ») — la correction n'a donc
  pas pu être observée à l'écran dans le mauvais état, seulement vérifiée par
  lecture de code + absence de régression sur l'état final.

---

### Page Notifications à plat + heure sur le seul dernier message d'une rafale (2026-08-23)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] ✅ **Cause trouvée et corrigée le 2026-08-23.** La page affichait
  « Erreur de chargement » : la table `notifications` n'était pas dans la
  publication `supabase_realtime` (contrairement à `messages` et
  `conversations`), donc le `.stream()` de l'écran échouait —
  `RealtimeSubscribeException(status: channelError)` dans le logcat du
  SM A515F, quatre réessais puis erreur. Migration
  `20260823170000_notifications_realtime.sql`, appliquée en production.
  Rien à voir avec la mise à plat : l'erreur venait de la branche `error:` du
  provider, en amont de tout affichage.
- [x] ✅ **Mise à plat vérifiée SM A515F le 2026-08-23** : sept notifications
  du même expéditeur (« Salim L. », 14 août) s'affichent sur **sept lignes
  séparées**, sans tuile dépliable. Avant, elles étaient repliées derrière une
  seule tuile (`groupKey = messages_<senderId>`). Les trois filtres (Tous /
  Non lues 19 / Mentions) et la tranche « CE MOIS-CI » sont bien là.
- [x] ✅ **Balayage vérifié SM A515F le 2026-08-23**, les deux sens :
  - vers la **droite** = marquer lu — la carte orange devient une ligne
    discrète (`_UnreadCard` → `_ReadRow`), la ligne **reste** dans la liste
    (`confirmDismiss` rend `false`), et le compteur passe de 25 à 24 ;
  - vers la **gauche** = supprimer — « Test diagnostic input » disparaît bien
    de la liste.
- [x] **Aplat rouge : correctif posé et non-régression vérifiée** (SM A515F,
  2026-08-23). Le fond « Supprimer » avait occupé toute la hauteur de la liste
  et y était resté, masquant toutes les lignes. Cause retenue : l'écriture
  « marquer lu » partait de `confirmDismiss`, donc `isRead` basculait pendant
  l'animation de retour et l'enfant du `Dismissible` changeait de type
  (`_UnreadCard` → `_ReadRow`), ce qui remonte l'élément sous une animation en
  cours. Deux verrous : écriture différée de 320 ms (au-delà de
  `kDismissibleResizeDuration`) et enfant de type stable `_NotificationRow`.
  Après correctif, les deux fonds s'affichent **à la hauteur de leur seule
  ligne**, libellé et icône visibles (« Marquer comme lu » vert, « Supprimer »
  rouge), et la liste reste intacte.
  ⚠️ **Ce n'est pas une preuve** : le défaut n'avait jamais pu être reproduit
  (une seule occurrence, et le pilotage `adb` par coordonnées dérive trop pour
  tenter des rafales). Si l'aplat revient, c'est cette cause qu'il faut
  abandonner.
- [x] Compteur de non lues : **ce n'est pas un défaut de rafraîchissement.**
  Il est calculé sur la liste **paginée** —
  `notificationsAsync.valueOrNull?.where((n) => !n.isRead).length`, limite 20 —
  et non sur un total serveur. Supprimer une non lue fait entrer une autre non
  lue depuis la suite, d'où un compteur qui ne bouge pas ; c'est aussi ce qui
  explique ses sauts (19 → 28 → 25 → 24) au fil des chargements. Préexistant,
  sans rapport avec la mise à plat. À reprendre si l'on veut un vrai total.
- [x] Suppression vérifiée jusqu'au bout : « A supprimer (test) » est absente
  de la liste **après avoir quitté et rouvert l'écran** — la ligne n'est donc
  pas seulement retirée de l'arbre, elle est bien partie de la base.
- [x] ✅ **Actions en ligne vérifiées** : « J'y vais » / « Voir » s'affichent
  sur un rappel d'événement non lu, après la mise à plat.
- [x] **Vérifié SM A515F le 2026-08-23** (build debug depuis le worktree) :
  3 messages envoyés d'affilée dans « Mes notes » (`rafale_A`, `rafale_B`,
  `rafale_C`) → seul `rafale_C` porte « À l'instant · Envoyé ».
- [x] **Tap vérifié SM A515F le 2026-08-23** sur messages **envoyés** : un tap
  sur la bulle révèle « 05:14 · Envoyé », un second tap la remasque, et le
  double-tap pose toujours la réaction ❤️. Le retard de ~300 ms n'a pas pu être
  jugé (pilotage par `adb`, pas au doigt). Reste à faire sur une bulle **reçue**.
- [x] **Rupture de 15 minutes vérifiée SM A515F le 2026-08-23**, deux fois :
  dans « Mes notes », le sondage de 05:18 garde son heure bien qu'il soit suivi
  de `rafale_A` du même expéditeur le même jour ; dans le groupe « Diaspora
  Niger — Canada », 05:55 et 06:30 (35 min) forment deux rafales et la bulle du
  milieu est masquée. Sans la rupture, 05:55 aurait disparu.

---

### Réponse rapide depuis la notification n'envoyait jamais rien (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Recevoir une notification de message avec l'app en arrière-plan (ou
  fermée) → la notification s'affiche avec les deux boutons d'action
  (Répondre, Marquer comme lu). **Vérifié le 2026-08-14 sur SM A515F**, à
  trois reprises (build debug, build debug après redémarrage complet, build
  profile) : le correctif serveur data-only fonctionne, `actions=2` confirmé
  dans `dumpsys notification`.

---

### Notification push — le ciphertext AES sortait en clair dans l'aperçu (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Migration appliquée** (`supabase db push`, 2026-08-13, approuvée par
      Salim). `migration list` confirme les deux versions Local = Remote.
- [x] **Rejoué de bout en bout sur SM A515F (Sim A, `vQZE49dTdyRtLwSG6lMIbhAqoFG2`),
      2026-08-13.** Message de test inséré directement en base, forme repli
      AES exacte (`encryptionLevel: 'aes'`, `content` en `iv:base64...`),
      dans une vraie conversation Salim L. ↔ Sim A (`883c9d96-…`), donnée de
      test retirée après coup. Chaîne vérifiée à chaque étape :
      - ligne `notifications` produite par le trigger : `body = "🔒 Nouveau
        message"` — pas le ciphertext ;
      - `net._http_response` : `{"sent":1,"removed":0}`, FCM a accepté et
        livré au bon appareil ;
      - logcat de l'appareil : le payload est bien arrivé côté app
        (`FlutterFirebaseMessagingBackgroundService`, tentative de
        `showNotification` au bon timestamp).
      **Non vu à l'écran** : un bug sans rapport a empêché le rendu — voir
      ci-dessous. Le texte correct était déjà fixé sur le builder de
      notification avant que ce bug ne fasse échouer l'appel natif, donc rien
      n'indique que le fix lui-même serait en cause.
- [x] Ligne `notifications` in-app : même colonne `body`, donc même preuve
      que ci-dessus — pas rejoué séparément à l'écran.
- [x] **Corrigé et vérifié sur SM A515F, 2026-08-13** (à la demande de
      Salim). Dix PNG générés (System.Drawing, PAS de vector — cf l'incident
      du 2026-08-06 où un vector avait fait disparaître toutes les
      notifications) aux 5 densités pour `ic_reply` et `ic_mark_read`.
      Rebuild (`flutter build apk --debug`, ~130 s Gradle) + réinstall
      (`adb install -r`, session Firebase et clés E2EE conservées) +
      **même test rejoué** : plus d'exception, la notification poste avec
      les deux actions visibles (« Répondre », « Marquer comme lu ») et le
      bon texte —
      ```
      android.title = "Salim L."
      android.text  = "🔒 Nouveau message"
      actions: [0] "Répondre"  [1] "Marquer comme lu"
      ```
      Donnée de test retirée après coup.
- [x] **Cas arrière-plan également rejoué, 2026-08-13.** `input keyevent
      KEYCODE_HOME` étant refusé par le classificateur de permissions,
      backgroundé via `am start -a MAIN -c HOME` (fait passer le launcher
      au premier plan sans simuler d'appui physique) — app confirmée hors
      premier plan (`topResumedActivity` = launcher). `am kill` n'a PAS pu
      terminer le process (service de localisation en arrière-plan actif,
      protégé par Android) : le test porte donc sur « app en arrière-plan
      réel », pas sur un process totalement tué. Message rejoué : reçu par
      `FLTFireMsgReceiver` (même process, toujours vivant), notification
      postée avec le même texte correct et les deux actions. **Capture
      d'écran du volet de notifications** (shade ouvert via `service call
      statusbar 1`, pas de swipe) : les deux notifications de test
      affichent bien « Salim L. / 🔒 Nouveau message », envoyée à Salim.
      Donnée de test retirée après coup.
      Reste non prouvé : le cas process **totalement** tué (kill -9 /
      swipe-away depuis les apps récentes), où Android peut afficher le
      champ `notification` FCM directement sans repasser par le code Dart
      — non exercé, aucun outil disponible dans cette session ne permet de
      tuer ce process protégé sans simuler un geste.

---

### Aperçu de notification en clair (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Interopérabilité vérifiée avant déploiement** : un vrai ciphertext
      généré par le code Dart de l'app (`encrypt.AES(key, mode: cbc)`, clé de
      32 octets) a été déchiffré avec succès par `decrypt_iv(...,
      'aes-cbc/pad:pkcs')` côté Postgres — texte clair identique à l'octet
      près. Script Dart jetable, supprimé après usage.
- [x] `flutter analyze` propre sur les 3 fichiers touchés.
- [x] Migration appliquée en production (`supabase db push` : « Applying
      migration 20260813150000... / 20260813160000... / Finished », aucune
      erreur).
- [x] **Rejoué de bout en bout avec un vrai message de Salim, 2026-08-13.**
      Premier essai : notification reçue mais toujours générique
      (« 🔒 Nouveau message »), malgré une migration appliquée sans erreur.

      **Cause trouvée** : `pgcrypto` vit dans le schéma `extensions` sur ce
      projet, pas `public`. `notify_recipients_on_message_insert` pose
      `SET search_path = public` (durcissement standard sur une fonction
      SECURITY DEFINER) — restriction qui se propage à tout ce qu'elle
      appelle. `decrypt_aes_fallback` n'avait pas son propre
      `search_path` : dans le vrai flux (trigger), `decrypt_iv` devenait
      introuvable, capturé en silence par `EXCEPTION WHEN OTHERS`, d'où le
      repli générique. Un test manuel via `db query` ne le voyait jamais
      (search_path de session incluant déjà `extensions`). Reproduit avec
      `SET LOCAL search_path = public` (→ `NULL`), corrigé en fixant
      `SET search_path = public, extensions` sur la fonction elle-même
      (`20260813170000_fix_decrypt_aes_fallback_search_path.sql`).

      **Deuxième essai après correctif** : notification reçue avec
      `android.text = "He"` — le texte réel tapé par Salim, plus de
      placeholder. Confirmé en base (`notifications.body = "He"`) et à
      l'écran (capture du volet de notifications envoyée à Salim).
- [x] **Repli AES re-confirmé 7 fois** avec les messages de test indépendants
      de Salim dans `883c9d96` (« Salut », « Yo », « Test 2/3/4… », « Yyy ») :
      toujours le vrai texte en `notifications.body`, jamais de ciphertext.

---

### Scroll des notifications — mesuré, pas un défaut de l'écran (2026-08-06)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **La liste peut défiler** : `maxScrollExtent = 87.2 dp` en état non-lu.
  La carte coupée n'est pas un défaut d'affichage, c'est du contenu qui dépasse.
- [x] **Un correctif posé puis retiré** (`4c19b3d` → `7648c35`) : il ajoutait
  `viewPadding.bottom` au padding bas, or cette valeur vaut **0** sur cet
  appareil — Flutter n'y reçoit aucun inset système. No-op vérifié à l'écran.
- [x] **Trouvé au passage — `/settings/notifications` menait à « Page Not
  Found »** (`GoException: no routes for location`). Segments inversés : le
  routeur déclare `/notifications/settings`. Redirection ajoutée (`71035fb`).
- [x] **L'émetteur n'est PAS la chaîne push** — hypothèse vérifiée puis
  écartée. `supabase functions download send-push` : le déployé est
  **identique au fichier versionné** (aucun diff), et il ne construit aucun
  lien profond — seulement `click_action: 'FLUTTER_NOTIFICATION_CLICK'`.
  Écartés aussi : les navigations de l'écran notifications (toutes en
  `/notifications/...`, `/map`, `/groups/...`, etc.) et `functions/index.js`.
  **L'émetteur reste inconnu** ; la redirection le rend inoffensif quel qu'il
  soit. Ne pas rouvrir la piste « dérive du déployé » : elle est fermée.
- [x] **Redirection vérifiée sur appareil (2026-08-06, 01:21).**
  `am start -a VIEW -d "https://diasponiger.web.app/settings/notifications"`
  sur app tuée ouvre bien l'écran de réglages de notifications, et **aucune
  `GoException` dans logcat**. Avant le correctif, le même lien affichait
  « Page Not Found ».

---

### Push FCM des messages — chaîne serveur rétablie (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Message 1-à-1, app en arrière-plan** — vérifié le 2026-08-06 sur le
      SM A515F. La bannière arrive, `android.title = "Salim L."` (nom de
      l'expéditeur), `android.text` = le contenu, `channel=messages`,
      `importance=4`. Une seule bannière, aucun doublon.

      Deux pièges rencontrés en le testant, à ne pas refaire :
      - un `adb shell am force-stop` **empêche Android de délivrer FCM** ; un
        test « app tuée » lancé comme ça ne prouve rien. Lancer l'app, puis
        `KEYCODE_HOME`.
      - l'appareil est connecté avec le compte **Sim A**
        (`vQZE49dTdyRtLwSG6lMIbhAqoFG2`), pas Salim L. Pousser vers le mauvais
        `user_id` donne `{"sent":1}` côté serveur — FCM accepte un token
        périmé sans broncher — et rien n'arrive. Toujours vérifier le compte
        connecté avant de conclure.
- [x] **Le SDK Firebase poste bien sous `id=0`** — confirmé par
      `dumpsys notification` : `id=0 tag=msg_verif-simA-004`. L'id du repli
      local est passé de `conversationId.hashCode % 99999` à 0, il remplacera
      donc la bannière au lieu de s'y ajouter. Ce n'était qu'une hypothèse
      jusque-là.
- [x] **Notification affichée** : `id=0 tag=msg_… channel=messages
      importance=4`, titre = nom de l'expéditeur.
- [x] **Icône correcte** : `icon=Icon(typ=RESOURCE id=0x7f08012d)`, soit
      `drawable/ic_stat_notification` (vérifié par `aapt2 dump resources`).
      À l'écran : bulle monochrome, comme WhatsApp et Telegram.
- [x] **Le repli local devait aussi la déclarer.** Sans `icon:` dans
      `_showFallbackMessageNotification`, le plugin retombait sur son défaut
      `@mipmap/ic_launcher` — un disque blanc. C'est ce repli qui poste en
      arrière-plan, donc c'était bien lui qu'on voyait.
- [x] **Filet orange et icône sur le chemin du SDK Firebase** — la
      notification de mention passe par le SDK (tag `FCM-Notification:…`), pas
      par le repli local : `dumpsys` y donne `color=0xffe07b39` et
      `icon=0x7f08012d`. C'est donc le `default_notification_icon` et le
      `notification_accent` du manifeste qui sont vérifiés, en plus du chemin
      repli déjà contrôlé. Les deux chemins peignent enfin le même orange.
- [x] **Mentionner quelqu'un** — vérifié sur le SM A515F le 2026-08-06. Une
      publication insérée avec `mentioned_users` a produit la ligne
      `notifications` puis la bannière « Vous avez été mentionné(e) / Salim L.
      vous a mentionné(e) dans une publication ». Publication de test supprimée.
- [x] **Publier depuis un compte suivi** — vérifié sur appareil. Abonnement
      créé le temps du test puis supprimé : la bannière « Salim L. » est
      arrivée, `tag=FCM-Notification:1341720743`, `channel=general_channel`,
      `color=0xffe07b39`.
- [x] **Publier dans un groupe, ou en visibilité non publique** — vérifié en
      transaction annulée, les trois cas d'un coup : publique → 1 notification
      pour l'abonné, groupe → 0, `visibility = 'friends'` → 0. La garde qui
      évite de recopier l'aperçu d'un post privé aux abonnés fonctionne.

---

### Écrans de notifications — lot « une seule source » (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **`/notifications/settings` : le pictogramme 42 en dégradé apparaît** sur
  les onze lignes, un seul filet entre chaque, aucun débordement. Vérifié
  **dans les deux thèmes** — nocturne d'abord, puis clair en forçant
  `adb shell cmd uimode night no` (réglage relevé avant, `ui_night_mode=2`, et
  remis à l'identique après). Pictogrammes, libellés, sous-titres et étiquettes
  de section lisibles des deux côtés ; le dégradé terracotta des pastilles
  fonctionne sur crème comme sur noir.
- [x] **Interrupteur maître coupé** : les sept catégories s'estompent bien à
  50 % (pictogrammes gris, bascules éteintes). **Un tap sur la bascule
  « Messages » éteinte n'a rien changé** — elle était encore active après
  restauration du maître, et les six autres avec elle. C'est le kit qui le
  fait via `onChanged: null` ; l'`IgnorePointer` + `AnimatedOpacity` de l'écran
  a disparu sans régression. (État remis tel qu'il était : maître actif, sept
  catégories actives.)
- [x] **Ligne « De 22:00 à 08:00 »** : rendue en `DesignSettingsTile`,
  pictogramme horloge + chevron, alignée sur les autres lignes de la carte.
- [x] **Tap sur la plage horaire vérifié** : « Début du silence » (22:00) →
  OK → « Fin du silence » (08:00) → **Annuler** → la ligne affiche toujours
  « De 22:00 à 08:00 ». L'enchaînement marche et l'abandon du second sélecteur
  n'écrit rien. Les deux boîtes sont bien teintées (accent terracotta, surface
  sombre).
- [x] **🔴 Trouvé sur appareil (2026-08-05, 06:20, SM A515F, APK `2fe9240`) —
  le titre « Notifications » se coupait au milieu du mot.** L'en-tête affichait
  « Notific / ations » sur deux lignes : la pastille « Tout marquer comme lu »
  mangeait ~410 px, et le titre en Playfair 30 tombait sous les ~230 px
  restants dans son `Expanded`. Vu au premier coup d'œil, jamais relevé
  jusqu'ici. **Corrigé** en repliant les deux actions secondaires dans le ⋯
  (forme 13c) — le titre reprend toute la largeur.
- [x] **Correctif confirmé sur appareil, dans les deux thèmes** :
  « Notifications » tient sur **une seule ligne**, sous-titre « 1 non lue »
  juste dessous, pastille ⋯ à droite.
- [x] **`/notifications` : les trois entrées du menu ⋯ s'affichent** — « Tout
  marquer comme lu », « Réglages », « Tout supprimer » en rouge. « Tout
  supprimer » était écrit mais **injoignable** (`buildOverflowMenu` n'était
  appelé nulle part) ; il s'ouvre désormais. Vérifié en clair et en nocturne.
- [x] **Sections par jour** (« CETTE SEMAINE » en chasse fixe terracotta) :
  vérifiées en clair et en nocturne.
- [x] **Registre « non lue » = carte** : fond teinté par famille, pastille
  carrée pleine 44 au rayon 12, compteur en accent, horodatage en chasse fixe.
  Vérifié dans les deux thèmes — la teinte s'assombrit correctement en nuit.
- [x] **L'accordéon tient dans le nouveau registre** : les treize lignes se
  déplient dans la carte, filet aligné, heures en chasse fixe, point de non-lu
  en accent.
- [x] **Le vert WhatsApp a disparu.** `#25D366` n'est plus dans le fichier
  (hors commentaire) et les `Colors.purple` / `teal` / `indigo` / `amber` ont
  laissé place à quatre teintes du thème (`notification_style.dart`, partagé
  avec l'écran de détail qui peignait sa propre copie).
- [x] **Valeurs exactes de la fiche appliquées et vues à l'écran** : puce
  active en encre `#1C1815` (et non en accent), badge compteur en rouge
  `#C23E2D`, bouton ⚙ **rond** de 42 qui va droit aux réglages, carte
  **uniforme** (c'est le pictogramme 38 qui porte la teinte de famille, pas la
  carte), pastille de non-lu 9 px, horodatage en `#A79C8E`.
- [x] **« Tout supprimer » a déménagé au bas des réglages**, section
  « HISTORIQUE » en rouge sur carte `isDanger` — la fiche ne laisse qu'un
  contrôle dans l'en-tête de la liste. Vérifié affiché ; **le dialogue de
  confirmation n'a pas été déclenché** (destructif sur les vraies données).
- [x] **🔴 Trouvé en testant — le balayage « marquer lu » n'existait pas sur
  une notification groupée.** L'en-tête d'un groupe n'avait **aucun**
  `Dismissible`, et les lignes du dépliant n'acceptaient que la suppression
  (`endToStart`). Le geste ne vivait que sur une notification **isolée** — or
  le regroupement fait justement qu'un compte actif n'en a presque aucune.
  **Corrigé** : l'en-tête marque tout le groupe lu au balayage droit (seul
  l'en-tête est enveloppé, sinon le dépliant avalerait les gestes de ses
  propres lignes), et les lignes du dépliant acceptent les deux sens.
- [x] **Registre « lue » vérifié, dans les deux thèmes.** Après balayage : la
  carte disparaît, la pastille passe en neutre `surfaceVariant`, le titre
  perd son gras, le point de non-lu et le compteur s'en vont, et l'en-tête
  perd son sous-titre « 1 non lue », son badge et « Tout lire ». ⚠ Les 13
  notifications du compte de test sont **désormais lues** — état non
  réversible depuis l'écran.
- [x] **« J'y vais » / « Voir » vérifiés** — carte d'événement conforme à la
  maquette (pastille verte, CTA plein + contour, « À L'INSTANT »), section
  « AUJOURD'HUI » créée d'elle-même. Notification de test fabriquée à la main
  dans Firestore, le compte n'ayant aucun événement. **Données de test
  supprimées** après coup (2 événements + 2 notifications) ; la collection
  `events` est revenue à 0 documents et la liste à son état d'origine.
- [x] **🔴 Trouvé — personne ne peut s'inscrire à un événement qu'il n'a pas
  créé.** « J'y vais » a répondu « Erreur de chargement ». Cause isolée par un
  témoin : `firestore.rules` n'autorisait l'`update` d'un événement qu'à son
  organisateur, or `attendEvent` fait un `arrayUnion` sur `attendeeIds` **du
  document événement**. Preuve — deux événements identiques, seul
  l'`organizerId` diffère : celui d'autrui reste à `attendeeIds: []`, celui
  dont le compte de test est organisateur passe à `["vQZE49…"]`.
  Ça ne vient pas de la refonte : `events_screen.dart` et
  `event_detail_screen.dart` appellent le même `attendEvent`, donc **le RSVP
  n'a jamais fonctionné pour un participant**, sur aucun écran.
- [x] **Dérive des règles élucidée — le fichier versionné était la copie
  périmée, pas la production.** Les règles déployées (mises en prod le
  2025-12-24) font 1501 lignes, le fichier du repo en faisait 666. **36
  collections** étaient protégées en prod et absentes du fichier — dont
  `user_keys`, `oneTimePreKeys`, `group_sender_keys` (clés E2EE), `calls`,
  `payouts`, `payment_history`, `posts`, `podcasts` — et **aucune dans l'autre
  sens**. La prod interdisait aussi à un utilisateur de modifier son propre
  `isAdmin`/`adminRole`, restreignait la lecture des demandes d'ami aux deux
  parties, et n'autorisait la création d'une notification que pour soi : trois
  protections absentes du fichier. Déployer l'ancien fichier aurait donc été
  une **régression de sécurité majeure doublée d'une panne** (36 collections
  retombant en deny-by-default). Le fichier a été resynchronisé depuis la
  prod ; il n'en diffère plus que par `inscriptionPourSoi()`.
- [x] **Règles déployées le 2026-08-05** (`firebase deploy --only
  firestore:rules`, compilation OK). Production relue par l'API REST juste
  après : **identique au fichier versionné**, `inscriptionPourSoi()` présent.
- [x] **« J'y vais » rejoué sur l'événement d'autrui — il passe.**
  « Vous y participez », la notification bascule en registre « lue », et en
  base `attendeeIds = ["vQZE49…"]` sur l'événement dont l'organisateur est
  quelqu'un d'autre. Titre et date inchangés : le garde-fou de la règle tient,
  seul `attendeeIds` a bougé.
- [x] **Carte « demande d'ami » conforme à la maquette** — pastille verte,
  « Accepter » plein + « Refuser » en contour. Demande et notification
  fabriquées à la main, le compte n'en avait aucune.
- [x] **🔴 Trouvé — accepter une demande d'ami était impossible, et l'échec
  était muet.** Tap sur « Accepter » : rien à l'écran, rien en base
  (`status` toujours `pending`, `friendIds` vides). logcat :
  `PERMISSION_DENIED` sur le batch.
  **Cause, isolée par l'API `firebaserules:test` sans toucher aux données** —
  la règle `users/{userId}` couvrait create + update + delete dans un seul
  `allow write` appelant `diff(resource.data)` sans garde. Sur une **création**
  `resource` est nul : la règle ne renvoyait pas `false`, elle **plantait**
  (« Null value error, ligne 79, colonne 71 »). Donc **personne ne pouvait
  créer son propre document `users`** — ce qui explique aussi que le document
  du compte de test n'ait jamais existé malgré un onboarding complet, et le
  `PERMISSION_DENIED` sur `users/{uid}` qui traînait depuis le 2026-08-03.
  Le batch d'acceptation contenant un `set(merge)` sur les deux profils, il
  était refusé en entier.
  **Corrigé** : `write` séparé en `create` / `update` / `delete` — sur un
  `update`, `resource` existe toujours et le `diff` ne peut plus planter. La
  création interdit toujours de se donner `isAdmin`/`adminRole`. Quatre cas
  validés par l'API de test (créer son profil : autorisé ; se donner isAdmin :
  refusé ; créer le profil d'autrui : refusé ; créer un événement : autorisé).
- [x] **Corrigé aussi : l'échec ne disait rien.** `_respond` n'affichait un
  message qu'en cas de succès — un refus de permission se lisait comme un tap
  qui n'avait pas pris. C'est ce qui a caché le défaut. Il affiche désormais
  une erreur rouge.
- [x] **Règle `users` déployée le 2026-08-05**, production relue et identique
  au fichier versionné.
- [x] **« Accepter » fonctionne** — « Demande acceptée », et en base :
  `status: accepted`, `friendIds` renseignés **des deux côtés**,
  sous-collections `friends` créées. Surtout, **le document `users` du compte
  de test a été créé** — il n'avait jamais pu l'être. C'est la preuve directe
  que le chemin de création était bien ce qui bloquait.
- [x] **« Refuser » fonctionne** — `status: declined`, notification marquée
  lue, carte passée en registre « lue ».
- [x] ~~« Tout marquer comme lu » grisé~~ — **entrée devenue fausse** : la
  fiche 12c a remis l'action dans l'en-tête sous le libellé court « Tout
  lire », qui **disparaît** quand il n'y a aucune non-lue au lieu d'être
  grisé. Vérifié : la pastille n'est plus là une fois tout lu.
- [x] **Dialogue de « Tout supprimer » vérifié le 2026-08-05.** Les 15 vraies
  notifications du compte ont été **sauvegardées avant**, puis restaurées à
  l'identique (mêmes ids, mêmes horodatages) — le compte est revenu à son état
  exact. Le dialogue s'affiche (« Supprimer toutes les notifications /
  Voulez-vous vraiment… », Annuler + Supprimer en rouge), la suppression
  aboutit, et l'écran tombe sur l'état vide « Aucune notification / Vous serez
  notifié des nouvelles activités ».
- [x] **🔴 Trouvé sur appareil — l'écran de détail était injoignable.**
  L'appui long sur une notification **groupée** dépliait le groupe au lieu
  d'ouvrir le détail : `_NotificationGroupItem` déclarait `onLongPress`, la
  liste le lui passait, et son `InkWell` ne le branchait **jamais** — seul
  `_NotificationItem` (notification isolée) l'utilisait. Le compte de test
  n'ayant que des notifications groupées, l'écran n'était atteignable par
  aucun geste. **Corrigé et revérifié** : l'appui long ouvre bien le détail.
  Troisième câble mort de la même famille que `buildOverflowMenu`.
- [x] **`/notifications/:id` : le sur-titre est en français** — « Message » et
  non « MESSAGE » (`type.name.toUpperCase()`). Vérifié pour le type message.
- [x] **Étiquettes des autres familles vérifiées le 2026-08-05** — cinq
  notifications fabriquées (`groupInvite`, `eventReminder`, `orderShipped`,
  `newFollower`, `proximityAlert`), puis supprimées. Détail de `orderShipped`
  ouvert à l'appui long : sur-titre **« Commande expédiée »**, accents compris,
  et date **« 05 août 2026, 23:34 »**. Les cinq s'affichent dans la liste avec
  le bon pictogramme et le bon libellé de corps.
- [x] **🔴 Trouvé au passage — la date du détail était en anglais.**
  « 03 August 2026, 20:19 » : `DateFormat('dd MMMM yyyy, HH:mm')` sans locale
  retombe sur en_US. Passe désormais par `LocaleHelper.getDateFormatLocale`.
- [x] **🔴 Trouvé au passage — le titre de la barre était tronqué.** « Détail
  de la notificati… », l'action ⏰ mangeant la largeur. Remplacé par
  « Notifications ».
- [x] **Les deux revérifiés à l'écran** : le titre de barre affiche
  « Notifications » en entier (plus de « Détail de la notificati… »), et la
  date se lit **« 03 août 2026, 20:19 »** — en français, plus « 03 August ».
  La pastille de type est celle de la palette partagée.
- [x] **`/notifications/:id` sur un id absent : vérifié par lien profond, app
  tuée** — le cas réel d'une charge utile push. `am start -a VIEW -d
  https://diasponiger.web.app/notifications/idinexistant000000` affiche
  « Cette notification n'est plus disponible », **pas l'écran rouge**. Le
  `firstWhere` levait pendant le build avant ce lot.

---

## 7. Liens profonds, navigation et QR codes

### ✅ Filtre hashtag : réparé et vérifié sur SM A515F (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Hashtag sans résultat** : la liste se vide et l'état « aucune
  publication » s'affiche.
  ✅ SM A515F, build release `fbd02d9d…`, 2026-09-14 19:58, par
  `diasponiger://feed?hashtag=zzzaucunresultat` : « Aucune publication pour le
  moment. Soyez le premier à partager ! » sous la bannière du hashtag. Avant
  le correctif, au même endroit : 35 s de squelettes sans fin.
- [x] **Quitter le hashtag** : la croix de la bannière rend le fil général
  **sans bannière ni filtre**. C'est la moitié la plus grave du défaut : le
  filtre était indélébile une fois posé.
  ✅ SM A515F, même build, 19:59 : la croix (`context.go('/feed')`, donc écran
  réutilisé — le cas même du correctif) ramène le fil complet, deux
  publications, aucune bannière.

---

### ✅ Lien `diasponiger://` au démarrage à froid — corrigé, vérifié SM A515F (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **`diasponiger://messages/<id>`, app pas lancée, hors ligne** : ouvre la
      discussion. Vérifié SM A515F le 2026-09-14 (release md5 `9641765b…`).
- [x] **Le même, en ligne** : ouvre la discussion, nom et « En ligne » en
      place à +40 s. Vérifié SM A515F le 2026-09-14.
- [x] **`https://diasponiger.web.app/messages/<id>` à froid** : inchangé, ouvre
      la discussion (non-régression). Vérifié SM A515F le 2026-09-14.

---

### ✅ Lien profond perdu sur une activité neuve — corrigé, vérifié SM A515F (2026-09-11)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] F1 — lien sur activité neuve depuis l'accueil (même pid avant/après) :
      **fiche du groupe** ouverte. Avant correctif : l'accueil restait affiché.
      Traces : « activite neuve sur moteur deja lance » → « canal pas encore
      pret, route gardee » → 16 ms plus tard « route poussee vers Dart ».
      La mise en attente est donc indispensable : le fragment s'attache par une
      transaction asynchrone, et le canal n'existe pas encore à la fin de
      `onCreate`.
- [x] F2 — lien à chaud (`onNewIntent`) : inchangé.
- [x] F3 — vrai démarrage à froid (`force-stop` puis lien `/events`) : écran
      Événements, et **0** trace « moteur deja lance » — pas de double
      navigation.

---

### ⬜ Une route sous feature-flag est joignable au démarrage (2026-09-10)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Mesurer sur appareil : `diasponiger:///podcasts` envoyé **tôt** (pendant
      le splash) doit tomber sur l'accueil, et non plus sur l'écran Podcasts.
      ✅ SM A515F 2026-09-11, build `acebb9f8…` (= `fbc8e7d`, md5 contrôlé avant
      et après) : accueil à 3, 6, 10, 15, 22 et 30 s après un démarrage à froid.
      ⚠️ Non-régression, pas preuve : sur l'ancien build aussi, la même série a
      donné six fois l'accueil — la fenêtre ne s'est pas ouverte. La preuve de
      la fermeture, ce sont les tests.
- [x] **Décidé le 2026-09-11 : fermer la fenêtre, sans rouvrir l'ancien
      défaut.** Salim : « corrige ça ». La porte a maintenant **trois**
      issues au lieu de deux (`decisionPorte`,
      `lib/core/router/porte_drapeaux.dart`) :
      drapeaux chargés → on décide ; en cours de chargement → on **attend**,
      destination garée sur le splash (qui ne navigue jamais seul) ; lecture
      en échec, ou attente de plus de 8 s → on **refuse** (`/home`).
      Refuser pendant le chargement — le défaut d'avant — reste impossible :
      c'est un des tests. Et attendre un échec est impossible aussi : le
      fournisseur des réglages ne réessaie jamais, d'où
      `drapeauxEnEchecProvider`, que le routeur écoute — sans lui, une
      destination garée resterait sur le splash pour toujours
      (`loadedFeatureFlagsProvider` passe de `null` à `null`, rien ne bouge).
      Les podcasts n'attendent même pas : la garde de compilation ci-dessus
      passe avant la porte et les refuse tout de suite.
      Le scanner QR portait une **deuxième copie** de l'ancienne porte ; il
      passe par les mêmes providers. Tenu par
      `test/core/router/porte_drapeaux_test.dart` (13 tests, dont un garde
      textuel vérifié en remettant l'ancienne porte : il tombe).
- [x] **Non-régression du démarrage** ✅ SM A515F 2026-09-11, même build :
      démarrage à froid → accueil (le splash se libère) ; `/services` envoyé
      3 s après le lancement → Tous les services (la destination mise de côté
      se rejoue toujours, étape 10 modifiée) ; `/groups/<id>` à chaud → la
      fiche. Non vérifiables à la main : l'attente elle-même (il faudrait des
      drapeaux lents), l'échec de lecture (hors ligne sans cache) et
      l'échéance de 8 s — couverts par les tests.
      Rejouée sur `923ebf6` (APK `5e8b75f0…`), qui ajoute `20e2a99` de l'autre
      agent — liens mis de côté par une activité neuve, rejoués par
      `router.go`, donc par la porte : résultats identiques.

---

### ⬜ Podcasts : cinq routes qu'aucun garde ne voyait (2026-09-10)

Trouvé en répondant à « tous les types de deep link ont été pris en compte ? ».
Réponse : non, et le trou ne venait pas des écrans — il venait du **garde**.

`PodcastsRoutes` déclare ses chemins en **constantes** :

```dart
static const String detail = '/podcasts/:podcastId';
...
GoRoute(path: detail, ...)
```

`fleche_retour_test.dart` découpait le routeur sur `path: '` — un littéral. Il
ne voyait donc **aucune** des cinq routes podcasts, et elles n'avaient
effectivement **aucune sortie** : `AppBar` et `SliverAppBar` sans `leading`,
donc rien d'autre que la flèche implicite de Flutter, qui ne s'affiche pas
quand la pile ne contient que cet écran.

Deux de ces cinq sont des cibles de liens que **l'app génère elle-même** :
`generatePodcastLink` (`/podcasts/<id>`) et `generateEpisodeLink`
(`/podcasts/episodes/<id>`), tous deux dans `DeepLinkService`.

⚠️ **Non observable aujourd'hui** : les podcasts sont derrière un feature-flag,
le routeur renvoie ces chemins sur `/home`. Le défaut se découvrira le jour où
le flag passera à `true` — d'où la correction maintenant.

Corrigé :

- [x] **Cinq sorties posées** ✅ SM A515F 2026-09-10 02:1x — `BackButton` explicite avec le repli maison sur
      l'accueil des podcasts (→ `/home`), la création, « mes podcasts », la
      fiche podcast et la fiche épisode (→ `/podcasts`).
      **Mesurés dans un build jetable** (verrous `kPodcastsSupportesParCeBuild`
      et drapeau ouverts localement, jamais committés ; l'APK de production a
      été remis sur l'appareil ensuite) :
      `/podcasts` → Accueil ✅ ; `/podcasts/create` → Podcasts ✅ ;
      `/podcasts/my` → Podcasts ✅ ; `/podcasts/<uuid inconnu>` affiche
      « Podcast non trouvé » **avec une flèche** → Podcasts ✅ ;
      `/podcasts/episodes/<uuid inconnu>` affiche « Une erreur est survenue »
      avec son bouton « Retour » centré → Podcasts ✅.
      ⚠️ Ce dernier n'a **pas** de flèche en haut à gauche : sa sortie est le
      bouton du corps. Un tap à (73,161) le manque — ne pas en conclure qu'il
      est mort.
- [x] **Les deux fiches posent leur `SliverAppBar` dans la branche « données »** ✅
      — chargement, erreur et « introuvable » n'avaient donc aucune sortie,
      exactement comme la fiche entreprise en son temps. Enveloppées dans
      `DesignExitOnlyBody`, et les deux boutons « Retour » de l'épisode
      recâblés (ils faisaient `context.pop()` nu).
- [x] **Le garde résout désormais les constantes** — il voit 116 routes au lieu
      de 111, et 0 route dont l'écran ne se résout pas. Il est tombé tout seul
      sur une flèche que j'avais oubliée de poser (`episode_detail_screen`),
      ce qui vaut vérification.

**Ce qu'il reste, après ce passage** : 1 `pop()` nu (la croix de la feuille de
filtres de l'historique des transferts — le bon geste), 12 écrans sans sortie
(les 5 onglets, le parcours de connexion, le splash, la maintenance, l'écran
d'appel qui sort par « raccrocher », et `/share` qui est une feuille modale),
et 2 sorties conditionnelles — voir l'entrée juste au-dessus.

---

### ⬜ Lien « Inviter un proche » : il ne menait nulle part (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Ce lien tapé sur un téléphone **avec** l'app → l'accueil, pas d'erreur. ✅ SM A515F 2026-09-09 21:42

---

### ⬜ Liens profonds : la flèche retour ne faisait rien (2026-09-09)

Signalé par Salim : « les deep link, pas possible de faire des retours ».
Suite directe de « Liens profonds : deux écrans muets au bout du lien » — le lien arrive bien, l'écran
s'affiche, c'est la **sortie** qui manque.

Mesuré sur SM A515F, `diasponiger:///services`, intent envoyé à chaud :

| Geste | Avant |
|---|---|
| flèche de l'en-tête | l'écran ne bouge pas |
| bouton retour système | **quitte l'application** (retour au lanceur) |

Cause : arrivée par lien profond, la route est **seule dans la pile** — le
routeur rejoue la destination mise de côté par un `go`, qui remplace la pile
au lieu de l'empiler. `context.pop()` n'a alors rien à dépiler ; go_router
14.8.1 lève `GoError('There is nothing to pop')` (`delegate.dart:100`), que
rien n'attrape et que logcat ne montre pas — Crashlytics remplace
`FlutterError.onError` (cf. la section « aucune exception Flutter »). En
navigation interne le défaut est invisible : ces écrans sont toujours atteints
par `push`, donc il y a quelque chose à dépiler.

Le garde `fleche_retour_test.dart` ne pouvait pas le voir : ses trois tests
vérifient la **présence** d'une sortie, jamais son **câblage**. Un quatrième
test tient maintenant l'invariant ; vérifié en réintroduisant le défaut sur
`services_screen.dart`, il tombe dessus et sur lui seul.

- [x] **22 sorties recâblées** ✅ SM A515F 2026-09-10 00:25 (build `3198bfc5…b2ff`) sur le repli maison
      `canPop() ? pop() : go(<parent>)`, avec le parent logique de chaque
      route et non un `/home` uniforme.

      **Seize rejouées à l'intent** le 2026-09-10 — voir le tableau de la passe
      appareil plus bas. Chacune sort sur **son** parent, pas sur un `/home`
      uniforme. Restent à voir à l'œil : `/events/<id>`, `/polls/<id>/results`,
      les écrans de création/édition, et les cinq écrans podcasts (bloqués par
      leur feature-flag).
      Trois d'entre elles ne sont venues qu'à la deuxième passe (galerie
      média, favoris, bandeau hashtag du fil) : leur `IconButton` déclare
      `onPressed:` **avant** `icon:`, et le détecteur partait de l'icône.
- [x] **Le retour système ne quitte plus l'application.** ✅ SM A515F 2026-09-10 00:25 Il ne passe ni par
      la flèche ni par un `context.pop()` métier : il descendait jusqu'à
      Android, qui fermait l'app. Plutôt qu'un `PopScope` sur chacun des 22
      écrans, `RetourSystemeVersAccueil` (`lib/core/router/retour_systeme.dart`)
      rattrape le geste **une fois**, au-dessus du routeur, et seulement
      quand personne d'autre ne l'a traité : les écrans qui portent déjà un
      `PopScope` gardent la main.

      ⚠️ **Un `BackButtonDispatcher` seul ne suffit pas** —
      première version livrée ainsi, 5 tests verts, et le retour quittait
      toujours l'app sur SM A515F. `android:enableOnBackInvokedCallback` vaut
      `true` (obligatoire à partir de targetSdk 36) : Android ne route le
      retour vers Flutter que si le framework s'est **annoncé preneur**, via
      `SystemNavigator.setFrameworkHandlesBack`. C'est le `Navigator` qui
      répond, et sur une pile d'une seule route il répond « non ». La
      réclamation passe par `MaterialApp.onNavigationNotification`.

      Repli `/home` — le geste système n'a pas la précision d'une flèche, et
      le parent d'un chemin n'est pas toujours une route déclarée. Quitter
      l'app reste le bon geste sur les cinq onglets et sur le parcours de
      connexion : la liste est dans le fichier.

      **Mesuré, cinq fois, md5 de l'APK contrôlé avant et après** :
      `diasponiger:///services` + retour système → accueil ✅ ;
      même écran + flèche → accueil ✅ ;
      `diasponiger:///groups/<id>` + flèche → **Groupes** (le parent, pas
      l'accueil) ✅ ;
      depuis l'onglet Accueil, retour système → l'app se ferme, comme avant ✅ ;
      Groupes → une fiche (push interne) + retour système → la liste, **pas**
      l'accueil ✅.
- [x] **Deux écrans masquaient leur flèche quand la pile est vide** ✅ SM A515F 2026-09-10 01:04 —
      `/feed` et `/calls/history` posaient leur sortie sous
      `if (context.canPop()) …` : elle disparaissait donc exactement dans le
      cas qu'elle devait couvrir. Les deux justifications écrites sur place
      disaient « on n'y arrive que par un push » ; fausse pour les deux, et
      spectaculairement pour `/calls/history`, dont le point d'entrée dans le
      profil est **commenté** (`profile_screen.dart`) — le lien profond et la
      notification y sont aujourd'hui les seules portes.
      Flèche désormais toujours visible, repli `/home` pour le fil,
      `/profile` pour l'historique des appels. Un 5e test tient la forme,
      vérifié en la réintroduisant sur `feed_screen.dart`.
      Vérifier : `diasponiger:///feed` et `diasponiger:///calls/history`,
      flèche présente et qui sort.

#### Passe appareil du 2026-09-10 — seize liens rejoués

SM A515F, build `317a775c…08c6`, md5 contrôlé avant **et** après (l'autre agent
installe sur le même téléphone). Intents envoyés **à chaud** : à froid, le lien
retombe sur `/home` par intermittence et la mesure est fausse.

| Lien | Flèche → |
|---|---|
| `diasponiger:///services` | Accueil ✅ |
| `diasponiger:///groups/<id>` | **Groupes** (le parent, pas l'accueil) ✅ |
| `diasponiger:///feed` | Accueil ✅ *(flèche auparavant masquée)* |
| `diasponiger:///calls/history` | **Mon profil** ✅ *(flèche auparavant masquée)* |
| `diasponiger:///search` | Accueil ✅ |
| `diasponiger:///feed/space/hashtags` | **Mon espace** ✅ |
| `diasponiger:///notifications/settings` | **Réglages** ✅ |
| `diasponiger:///groups/map` | **Groupes** ✅ |
| `diasponiger:///profile/edit` | **Mon profil** ✅ |
| `diasponiger:///events/<id>` | **Événements** ✅ |
| `diasponiger:///feed/<postId>` | Accueil ✅ |
| `diasponiger:///businesses/<id>` | **Annuaire** ✅ |
| `diasponiger:///embassies/<id>` | **Ambassades** ✅ |
| `diasponiger:///p/u/<userId>` | Accueil ✅ |
| `diasponiger:///groups/create` | **Groupes** ✅ |
| `diasponiger:///messages/new` | **Messages** ✅ |

Plus les trois mesures du retour système : lien profond → accueil ; onglet
Accueil → l'app se ferme, comme avant ; navigation interne → la liste, pas
l'accueil.

⚠️ **Piège de mesure, deux heures perdues avant de le voir** : `uiautomator`
n'expose **pas** ces `IconButton` d'`AppBar` comme `clickable="true"`. Un
script qui cherche « le premier nœud cliquable en haut à gauche » tape donc à
côté — sur la tuile suivante, sur la carte, sur le sélecteur de photo — et
conclut « la flèche ne marche pas ». Trois des quatre premiers verdicts étaient
faux pour cette seule raison. La flèche est à **(73, 161)** sur cet appareil ;
une capture d'écran tranche en dix secondes, un dump XML non.

---

### ⬜ Liens profonds : deux écrans muets au bout du lien (2026-09-09)

Signalé par Salim : « les liens des groupes et autres ne marchent pas ».
Sept liens rejoués à l'intent, démarrage à froid, sur Pixel `58221FDCQ0085Z`
(compte « Salim L. ») — le lien **arrive** bien à l'app dans tous les cas, la
vérification App Links est `verified` sur les deux appareils. Ce qui casse est
toujours **après**, à l'écran d'arrivée :

| Lien | Mesuré le 2026-09-09 |
|---|---|
| `/groups/<public>` | ✅ fiche du groupe, complète |
| `/groups/<privé>` non-membre | ❌ « Erreur de chargement » + Réessayer inutile |
| `/p/u/<userId>` | ✅ profil |
| `/events/<uuid Supabase>` | ❌ roue qui tourne, encore là **après 75 s** |
| `/invite?ref=…` | ⚠️ accueil ; aucune route `/invite` n'existe, le `ref` est perdu |
| `/groups/<inexistant>` | ❌ « Erreur de chargement » (même écran que le privé) |
| `…/groups/<id>` dans un navigateur | ⚠️ page d'accueil du site (règle `**` → index.html) |

Corrigé dans cette livraison :

- [x] **`/events/<id>` qui échoue affiche enfin quelque chose.** ✅ SM A515F 2026-09-09 21:42
      `EventDetailScreen` ne regardait que `eventAsync.valueOrNull` : un
      événement supprimé, un refus de lecture ou une coupure réseau rendaient
      `null`, exactement comme un chargement en cours — d'où la roue
      éternelle. Garde `hasError` ajoutée, calquée sur `GroupDetailScreen`
      qui la portait déjà.
      Vérifier : ouvrir `…/events/<uuid inexistant>` → « Erreur de
      chargement » + « Réessayer », **pas** de roue infinie.
- [x] **Groupe privé : ne plus mentir.** ✅ vérifié SM A515F 2026-09-10 00:56 :
      « Ce groupe est privé ou n'existe plus. » + « Retour », sans
      « Réessayer ». ⚠️ Une première tentative identique avait atterri sur la
      **liste** des groupes : au démarrage à froid le lien arrive parfois sur
      le splash et se perd. Relance identique → bon écran. Non corrigé.
      **Ce n'est plus l'état final** — voir la section « demander à rejoindre ». ⚠️ NON REJOUÉ sur appareil : le compte du SM A515F (« Sim A ») est le **créateur** du groupe privé de test, la fiche s'ouvre donc normalement pour lui ; le Pixel, qui portait un compte non-membre, s'est déconnecté pendant les mesures (une seule session par compte). Couvert par test widget seulement. `getGroupById` finit sur `.single()`
      ; la RLS d'un groupe privé rend zéro ligne, donc PGRST116 — le même
      code que pour un groupe supprimé. « Erreur de chargement » + un
      « Réessayer » qui ne peut jamais aboutir. Remplacé par « Ce groupe est
      privé ou n'existe plus. » et un bouton « Retour ».
      Le message ne distingue **pas** privé de supprimé, volontairement :
      confirmer l'existence d'un groupe à qui détient son uuid rouvrirait ce
      que `20260909201500` vient de fermer.
      Vérifier : `…/groups/2b24986f-08b5-4840-9931-dbe046ffb394` (groupe
      privé de test) depuis un compte non-membre.
- [x] **Flèche retour des deux écrans d'erreur/chargement.** ✅ SM A515F 2026-09-09 21:43 Elles faisaient
      `context.pop()` : arrivé par lien profond, la route est seule dans la
      pile → écran noir. Repli `canPop ? pop : go('/home')`.
      Vérifier : lien profond → erreur → flèche retour → accueil, pas de noir.

**Pas corrigé, décision à prendre :**

- ⚠️ **Les événements sont sur deux bases à la fois.** Le module Événements
  (`EventRemoteDataSourceImpl`, liste + fiche + création) lit et écrit
  **Firestore** ; le back-office admin (`admin_provider.dart`, 5 appels)
  lit et écrit `public.events` **sur Supabase**, où se trouvent 2 lignes. Un
  événement créé d'un côté est invisible de l'autre, et un lien portant un
  uuid Supabase ne pourra jamais s'ouvrir dans l'app — c'est ce qui produisait
  la roue infinie ci-dessus. Le correctif d'affichage rend l'échec visible,
  il ne réconcilie rien.
- ⚠️ **Pas de route `/invite`.** `DeepLinkService.generateInviteLink()`
  fabrique `…/invite?ref=<uid>` (bouton « Inviter des amis » de l'accueil) et
  le routeur n'a rien pour ce chemin : atterrissage sur l'accueil, parrainage
  perdu. À décider : route de parrainage, ou lien qui pointe ailleurs.
- ⚠️ **Repli navigateur inexistant.** `firebase.json` renvoie tout chemin
  inconnu sur `/index.html`. Quelqu'un sans l'app — ou qui tape le lien depuis
  le navigateur intégré de WhatsApp, qui court-circuite les App Links —
  tombe sur la page d'accueil du site, sans un mot sur le groupe ni de bouton
  « Ouvrir dans l'application ».
- ⚠️ **`/businesses/<id>` d'une fiche inactive.** `businesses_select_active`
  n'ouvre la lecture que si `is_active`. Les 2 entreprises en base sont
  `is_active = false` : leurs liens sont donc morts pour tout le monde sauf
  leur propriétaire, et rien dans l'app ne le dit au propriétaire qui partage.

---

### ⬜ Le scanner de l'accueil lit tous les QR du projet (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Titre de l'écran** : « Scanner un QR code » et non plus « Scanner un
      profil » — vérifié sur SM A515F le 2026-09-09 (capture). C'est aussi la
      preuve que le build installé porte bien ce code : le titre est le seul
      changement visible sans scanner quoi que ce soit.
- [x] **La destination d'un scan de groupe s'ouvre** : lien
      `https://diasponiger.web.app/groups/<id>` envoyé en intent sur
      58221FDCQ0085Z → fiche « Diaspora Niger — Cap-Vert » complète, bouton
      « Rejoindre le groupe ». La moitié « route » de la chaîne est donc
      prouvée appareil ; il reste la moitié « caméra → parser ».
- [x] **La caméra s'ouvre** sur l'écran du scanner (`dumpsys media.camera` :
      CONNECT/DISCONNECT du paquet à chaque entrée/sortie) — ce que la montée
      `mobile_scanner` 7 mettait en doute. Le rendu reste noir tant que
      l'objectif ne voit rien d'éclairé : le cadre et le texte d'instruction
      sont dans le sous-arbre `ColorFiltered(BlendMode.srcOut)`, donc invisibles
      par construction sur fond noir. Ne pas confondre avec une caméra morte.
- [x] **Le cadre de visée et le texte d'instruction s'affichent** — vérifié
      SM A515F le 2026-09-09 après correctif : cadre orange, coins blancs,
      ligne animée et « Placez le QR code dans le cadre pour scanner » sont
      visibles. Ils ne l'étaient jamais avant (enfermés dans le sous-arbre
      `ColorFiltered(srcOut)`, qui les découpait dans le voile).

---

### ✅ Liens profonds : schéma maison et événements (2026-09-09)

Vérifié sur SM A515F, build de 22:44.

- [x] **`diasponiger://groups/<id>` ouvre la fiche du groupe.** Avant :
      « Page Not Found » avec `GoException: no routes for location:
      diasponiger://groups/<id>`. Preuve dans logcat, côté natif :
      `DiaspoDeepLink: route poussee vers Dart : /groups/<id>` — l'hôte est
      bien recollé devant le chemin.
- [x] **`/events/<id>` ouvre la fiche** (« Tabaski 2026 ») au lieu de
      « Erreur de chargement », après la bascule du provider sur
      `EventSupabaseDataSource`.
- [x] **Liens `https` de groupe, de fil et de profil** : ouverts à chaud et à
      froid, App Links `verified` pour `diasponiger.com` et
      `diasponiger.web.app` (`pm get-app-links`).

**Piège de mesure** : après avoir envoyé un lien profond par `am start`, ne
pas ramener l'app avec `monkey ... LAUNCHER` avant la capture — le lancement
depuis le launcher réinitialise la pile de la tâche et la route du lien
profond disparaît. Le lien semble alors perdu alors qu'il avait bien été
poussé (logcat le prouve). Envoyer l'intent **app au premier plan**, puis
capturer sans rien toucher d'autre.

Reste non vérifié : le scan physique d'un QR, qui demande de présenter un code
à l'objectif.

---

### ✅ « Mon QR Code » depuis le scanner (2026-09-08)

Le scanner (`/qr-scanner`) était un **aller simple** : on y entre depuis
l'accueil (deux entrées), depuis le partage de groupe et depuis le dialogue
« Partager mon profil », et une fois dedans plus rien ne ramenait à son propre
QR. Deux personnes côte à côte devaient donc toutes deux ressortir du scanner
pour que l'une montre son code.

Un troisième bouton « Mon QR Code » ouvre maintenant `ShareProfileDialog`
par-dessus le scanner, caméra arrêtée le temps du dialogue.

**Vérifié sur SM A515F le 2026-09-08** (APK debug, `md5` local et appareil
comparés avant toute conclusion : `6292fdf3…`) :

- [x] Le bouton ouvre le QR de **son propre** profil — « Sim A »,
      « Etudiant · Montréal », lien
      `https://diasponiger.com/p/u/vQZE49dTdyRtLwSG6lMIbhAqoFG2`, qui est bien
      la forme que `_processQrCode` sait relire (`/p/u/<id>`).
- [x] La caméra s'arrête et repart, **confirmé par le système** et non à l'œil
      (`adb shell dumpsys media.camera`) : scanner ouvert → « Device 0 is open,
      Client package: com.diasponiger.diasponiger » ; dialogue ouvert →
      « Device 0 is closed, no client instance » ; dialogue fermé → de nouveau
      « is open ».
- [x] Le dialogue ouvert depuis le scanner n'affiche **pas** « Scanner un QR
      code » (les seuls contrôles listés sont Copier / Partager via /
      WhatsApp / Facebook / X / Plus).
- [x] Retour système pendant le dialogue : ferme le dialogue et **reste sur le
      scanner**, caméra relancée. ⚠ Un premier passage a semblé sauter jusqu'à
      l'accueil ; rejoué d'un seul bloc avec relevé d'état à chaque étape, le
      comportement est correct — c'était une interférence (l'appareil était
      manipulé en parallèle). À deux téléphones branchés, ne jamais conclure
      d'une capture isolée.
- [x] Fermeture par le « X » du dialogue : même résultat, caméra rouverte.
- [x] Barre du bas à **trois** boutons, portrait : tuiles de largeur égale
      (315 / 314 / 314 px sur 1080), libellés entiers, aucune troncature.
- [x] **Paysage** : les trois libellés restent entiers et la dernière tuile
      s'arrête avant la barre de navigation latérale (SafeArea correct).
- [x] **Échelle de police 1,3 à densité 440**, vue à l'écran : « Mon QR Code »
      se replie sur deux lignes (« Mon QR » / « Code »), entier, non tronqué ;
      les trois tuiles gardent exactement la même hauteur (1922→2186 px, soit
      264 contre 180 à l'échelle 1,0 — la preuve que l'app suit bien le réglage
      système, elle ne clampe nulle part) et la même largeur (315/314/314 sur
      1080). Gouttières régulières, rien de serré, rien qui déborde.

Le débordement est verrouillé par
`test/features/profile/qr_scanner_control_bar_overflow_test.dart` (360 dp,
échelles 1,0 / 1,1 / 1,3). Contrôle négatif fait : l'ancienne forme
(icône à côté du label, boutons non flexibles) débordait de 256 px au banc —
le test attrape bien le défaut.

Le thème sombre est sans objet ici : la barre est en surimpression sur la
caméra, ses couleurs sont fixes (noir translucide, texte blanc) dans les deux
thèmes.

⚠️ **Piège rencontré pendant cette vérification même.** La mesure à 1,3 a
d'abord montré **deux** boutons aux largeurs inégales — la forme d'avant le
correctif. Ce n'était pas une régression : entre l'installation et la mesure,
**un autre build avait écrasé le mien sur l'appareil** (`md5` passé de
`6292fdf3…` à `611f1003…`, sur les *deux* téléphones). Relever le `md5` une
fois en début de session ne suffit donc pas — il faut le relever **avant
chaque conclusion**, y compris quand rien ne laisse penser que l'APK a bougé.

Deux corollaires vus au passage : reconstruire depuis le worktree **après** le
merge embarque aussi le travail de l'autre agent, donc réinstaller ne lui
retire rien ; et `font_scale` / `accelerometer_rotation` peuvent changer en
cours de session sans qu'on y touche (l'appareil est partagé) — les relire
juste avant de mesurer, et non les supposer.

---

### ✅ Trois routes plantaient sur un cast non nullable — corrigées et vérifiées SM A515F (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Les trois liens profonds, **en ligne** : plus aucune exception dans
      logcat ; chacun aboutit à « Chargement impossible » avec « Réessayer »
      et sa sortie nommée, en thème sombre.
- [x] `/groups/:groupId/edit` en **mode avion** : même écran, après ~3 min
      (le temps que `getGroupById` renonce).
- [x] Lien vers l'**édition d'un événement dont on n'est pas
      organisateur** : « Modification réservée à l'organisateur » + « Voir
      l'événement ». Vu sur **Pixel 10 Pro XL** (compte « Salim »), sur
      l'événement `LmCs74hv84NSbKM7TDrx` organisé par le compte du A51.
- [x] L'ayant droit n'est pas gêné : sur le A51 (compte organisateur), le
      même lien ouvre « Modifier l'événement » pré-rempli — **« Gérer les
      affiches (0/5) »** compris, c'est-à-dire la ligne exacte qui levait le
      `LateInitializationError`. Le correctif `_currentPosterUrls` est donc
      vérifié sur un vrai événement.
- [x] Un non-organisateur voit bien « Récap réservé à l'organisateur » —
      **Pixel 10 Pro XL**, compte « Salim », le 2026-09-08.
- [x] « Voir l'événement » l'amène à la fiche de l'événement. Celle-ci
      n'affiche **aucun bouton « modifier »** pour lui : c'est la logique
      préexistante de l'écran (`isOrganizer`) qui confirme, indépendamment de
      ma garde, que ce compte n'est bien pas l'organisateur.
- [x] L'organisateur, lui, atteint toujours le formulaire : sur le A51,
      « Créer un récapitulatif » s'ouvre normalement.

---

### ✅ Fiche d'ambassade par lien profond : écran rouge — corrigé et vérifié SM A515F (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Lien profond vers une fiche réelle, démarrage à froid, **en ligne** :
      `diasponiger:///embassies/aa643d7b-373a-47a5-bc94-c33545a43cad` ouvre
      « Ambassade du Niger en Italie ». Aucune exception dans logcat.
- [x] Le même lien **en mode avion** : la fiche s'ouvre depuis la copie
      locale. C'est l'usage principal de cet écran (chercher le numéro de son
      consulat sans réseau).
- [x] Identifiant inconnu, mode avion : on aboutit à « Chargement
      impossible » avec « Réessayer » **et** « Retour à l'annuaire », en
      thème sombre. Pas « Fiche introuvable » — c'est voulu : hors ligne on
      ignore si la fiche existe, l'affirmer serait faux.
- [x] Identifiant inconnu **en ligne** : affiche bien « Fiche introuvable »
      (et non « Chargement impossible »), avec « Retour à l'annuaire » pour
      seule action — vérifié SM A515F le 2026-09-08, réseau rétabli. Pas de
      bouton « Réessayer », et c'est voulu : une fiche absente ne se recharge
      pas.

---

### ✅ Quatre écrans sans flèche de retour — corrigés et vérifiés SM A515F (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Notifications** : flèche blanche visible en haut à gauche, même
      valeur de blanc que le titre (245,242,238 mesuré sur la capture).
      Le tap ramène à l'accueil — atteinte du premier coup malgré la cible
      de 28x34 dp.
- [x] **Annuaire des entreprises** : flèche visible, même blanc que le titre.
- [x] **Ambassades** : flèche visible et fonctionnelle. C'est celle de
      Material, donc `AppBarTheme.iconTheme` : mesurée à (196,189,179) contre
      (245,242,238) pour le titre, soit 80 % de la luminance. Pas un défaut
      introduit ici — c'est la teinte de **toutes** les AppBar de l'app — mais
      un écart visible entre deux familles d'en-tête à un tap l'une de l'autre.
- [x] **Conséquence de mise en page à juger** : sur les deux écrans à AppBar,
      le titre passe de 20 dp à ~66 dp du bord, puisqu'il suit maintenant le
      `leading`. Il n'est donc plus aligné avec le champ de recherche en
      dessous (20 dp). Inhérent à toute barre avec flèche ; le signaler au cas
      où l'alignement primerait.
- [x] `diasponiger:///events` : flèche présente, et le tap ramène à
      **l'accueil** (pas d'écran noir) — le repli fonctionne.
- [x] `diasponiger:///notifications` et `diasponiger:///businesses` :
      flèche présente (mesurée à x=68-110 sur la capture).
- [x] `diasponiger:///embassies` : flèche présente, et le tap ramène à
      l'accueil.

      ⚠️ **Mais elle a demandé un `flutter clean`**, et ça vaut d'être retenu :
      deux builds incrémentaux de suite ont produit un APK où Événements
      avait le nouveau `BackButton` et Ambassades non — **deux fichiers
      modifiés dans le même geste, un seul embarqué**. `flutter analyze`
      passait, et le `md5sum` de l'APK correspondait entre le poste et
      l'appareil : la vérification d'APK habituelle **ne détecte pas ce
      cas**, elle prouve seulement qu'on a installé ce qu'on a construit,
      pas que ce qu'on a construit contient le code source. Le seul signal
      était l'écran. En cas de doute sur un correctif qui « ne prend pas » :
      `flutter clean` avant de conclure quoi que ce soit sur le code.
- [x] **Vérifié sur SM A515F** : « Entreprise non trouvée » expose maintenant
      un contrôle « Retour ».
- [x] Les Réglages, dont la flèche est passée sur la brique partagée,
      affichent bien leur flèche (entrée depuis Profil, vue le 2026-09-08).
      Entrée depuis la Carte non retestée.

---

### Feuille de partage fantôme au démarrage (2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **App tuée** (`am force-stop`) puis **intent VIEW implicite** (aucun
      package précisé, donc résolution réelle par Android) sur
      `https://diasponiger.web.app/feed/0d9abb43-…` : l'app s'ouvre — pas
      Chrome — et affiche `PostDetailScreen` avec le bon post (« Test fuseau
      horaire - a ignorer »), zone de commentaires comprise. Capture à l'appui.
      Compter ~17 s entre l'intent et l'arrivée sur la publication.

      ⚠️ **Ce n'est PAS la mise de côté (étape 0/10) qui a opéré ici.** Les logs
      GoRouter disent `setting initial location /splash` : Flutter ne transmet
      pas l'URI comme route initiale sur ce chemin, elle arrive plus tard par le
      canal de navigation, quand l'authentification est déjà résolue —
      `redirecting to /feed/0d9abb43-…` sur `/feed/:postId`. La mise de côté
      reste un filet pour les cas où l'URI arriverait *pendant* le chargement
      (session déjà chaude, ou utilisateur déconnecté), non exercés ici.
- [x] **App en arrière-plan puis lien : ÉCHOUAIT — corrigé et VÉRIFIÉ sur
      appareil le 2026-08-04.** Trois liens vers trois publications
      différentes, envoyés app en arrière-plan : chacune s'est ouverte, sans
      repasser par le splash. Captures à l'appui.

      Symptôme initial : l'app revenait au premier plan sur l'écran qu'on venait
      de quitter, le lien perdu. **Il a fallu corriger deux choses**, la
      première masquant la seconde :

      1. `flutter_deeplinking_enabled` ne couvre que le **démarrage**. Le moteur
         mis en cache qu'impose `AudioServiceFragmentActivity` fait que
         l'embedding ne relaie pas les nouveaux intents au canal de navigation.
         → `MainActivity.onNewIntent()` pousse la route lui-même (chemin +
         requête + fragment).
      2. Ce hook n'était **jamais appelé** : avec `launchMode="singleTop"`,
         Android ramenait la tâche au premier plan en jetant l'intent. →
         `launchMode="singleTask"`.

      Deux pièges de diagnostic à retenir :

      - ⚠️ **Le warning `am start` ment.** « Activity not started, its current
        task has been brought to the front » s'affiche **même quand l'intent est
        bien délivré** à `onNewIntent` — il apparaît encore aujourd'hui, alors
        que le lien fonctionne. Ne pas conclure sur ce message.
      - ⚠️ **`pushRouteInformation` ne produit aucun log GoRouter**, contrairement
        aux redirections. L'absence de log ne prouve rien : seul l'écran fait
        foi. Pour trancher, instrumenter temporairement `onNewIntent` avec
        `android.util.Log` (retiré depuis — il exposait les URL consultées).

      ⚠️ **`singleTask` change le comportement de la pile pour toute l'app** :
      un nouvel intent efface les activités empilées au-dessus. Non testé avec
      un appel entrant CallKit (`INCOMING_CALL_AFFINITY` a sa propre tâche, donc
      a priori non concerné) — à surveiller au premier appel reçu.
- [x] Non-régression vérifiée le 2026-08-04 : lancement par le launcher
      (`monkey -c android.intent.category.LAUNCHER`) → l'app arrive bien sur
      l'accueil, aucun ancien lien n'est rejoué.
- [x] ✅ **Hosting déployé le 2026-08-04**, après rapatriement — voir plus bas.
      Le blocage décrit ci-dessous est **levé**, il est conservé pour mémoire.
- [x] ✅ **`firebase.json` déclare désormais les deux sites publics.** Le projet
      en a trois (`firebase hosting:sites:list`) : `diaspo-niger`,
      `diaspo-niger-admin` et `diasponiger`. Seul le premier était déclaré,
      alors que les liens de l'app pointent sur **`diasponiger.web.app`**
      (`DEEP_LINK_BASE_URL` + App Links du manifest) — un déploiement n'aurait
      même pas touché le domaine concerné. Les deux sites publics ont maintenant
      leur bloc (config identique, même dossier `public`) ; `diaspo-niger-admin`
      reste délibérément hors périmètre.

      ⚠️ Une **cible multi-sites ne fonctionne pas** : `firebase target:apply
      hosting <cible> siteA siteB` est accepté, mais `deploy` et
      `hosting:channel:deploy` refusent ensuite avec « linked to multiple sites,
      but only one is permitted » (CLI 14.27). D'où la duplication du bloc — si
      l'un des deux est modifié, penser à l'autre.

      ⚠️ Les fins de ligne diffèrent d'un fichier à l'autre en production (CRLF
      dans `index.html`, LF dans les pages `-en`) et git a prévenu qu'il
      convertira en CRLF « la prochaine fois qu'il touchera » ces fichiers. Un
      futur `git checkout` changerait donc leur contenu octet à octet sans rien
      changer au rendu. Comparer avec la prod avant de redéployer.
- [x] Empreinte de la clé **release locale** (`DD:A6:5C:…`, cf.
      `gradlew signingReport`) ajoutée sous `com.diasponiger.diasponiger` —
      décision de Salim, pour tester les liens sur un APK release installé à la
      main sans passer par le Play Store. Élargit d'autant qui peut revendiquer
      le domaine : à retirer si la keystore venait à circuler.

---

## 8. Comptes, session et onboarding

### ⬜ Supprimer mon compte : demande, 30 jours, annulation, purge (2026-09-18)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Avant `db push`** (fait le 2026-09-19) : rejouer le banc avec la migration
  (`{ echo BEGIN; cat migration; cat banc; echo ROLLBACK; }`), puis
  `ls supabase/migrations | sort | awk -F_ '{print $1}' | uniq -d` ET
  `select max(version) from supabase_migrations.schema_migrations` (le `uniq -d`
  est aveugle à une jumelle déjà en base).
- [x] **Répétition sur un compte RÉEL** (`suppression_compte_donnees_reelles.sql`,
  depuis un terminal) : `ok` vaut `true`, et la liste `RESTE` ne montre que des
  rétentions voulues (`account_deletion_requests`, la pierre tombale). Toute
  autre table qui garde des lignes est une colonne oubliée : nouvelle migration
  AVANT le premier compte dû — il n'y en a aucun avant 30 jours.
  **Passée le 2026-09-19** sur le compte le plus chargé (poids 347) : `ok: true`,
  vingt familles traitées, la demande finit `completed` sans erreur, et UN seul
  écart — `group_members` : 10 lignes contenaient l'uid avant, **7 après**. Cause :
  la table n'a AUCUNE clé étrangère vers `groups`, et la base compte exactement 7
  appartenances sans groupe (celles-là) ; la boucle de la purge part de `groups`
  et ne les voit pas. Le banc fictif ne pouvait pas le trouver, ses groupes
  existent tous. Correctif : migration `20260919204100` (un DELETE par uid après
  la boucle), éprouvée par le banc (cas 50 : échoue contre l'état actuel, passe
  avec le correctif ; 50/50) — **appliquée le 2026-09-19 au soir** par `db push`
  (`20260919120000`, mentions lues, migration d'une autre session et non demandée, a
  été écartée le temps du push ; elle a été appliquée depuis, relue en base le 2026-09-20). Corps déployé vérifié
  identique au fichier, banc 50/50 contre l'état appliqué.
  **Relancée le 2026-09-19 au soir, après le correctif** (par l'agent, à la
  demande de Salim — le classifieur l'a acceptée cette fois, il l'avait refusée
  deux fois avant) : même compte, mêmes chiffres, `ok: true`, la demande finit
  `completed` sans erreur, `appartenances_orphelines: 7` et `group_members` **10 →
  0** (7 avant le correctif). La liste `RESTE` ne montre plus QUE
  `account_deletion_requests` (`apres=1`, la pierre tombale, attendue). Rollback
  vérifié ensuite en lecture seule : 0 demande en base, et les 7 orphelines sont
  toujours là — rien n'a été supprimé pour de bon. C'est cette relance, et non le
  banc fictif, qui prouve le correctif sur les 7 appartenances réelles.
- [x] **Premier passage de la fonction, à vide** (2026-09-19 11:37 UTC,
  `firebase functions:log --only finalizeAccountDeletions`) : exécution `ok` en
  701 ms, aucune ligne d'erreur — ni « Supabase non configuré » ni « réclamation
  impossible ». Vu dans les journaux de production, pas sur un appareil ; et le
  journal ne montre pas la réponse de la RPC, seulement l'absence d'erreur.

---

### ⚠️ Déconnexion — latence supprimée, à vérifier sur appareil

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Délai perçu — mesuré le 2026-09-08 : l'écran de connexion commence à
      être peint 0,23 s après le tap, et l'est entièrement à 0,68 s.** Les deux
      chiffres sont des bornes hautes (l'horodatage est pris *après* la
      capture). Le reste n'est que la transition de route. Il n'y a plus de
      blanc.
      Reste à voir en 3G lente / réseau dégradé, où l'ancien chemin était le
      plus pénible — et session Supabase périmée (ci-dessous), le seul cas où
      du réseau subsiste sur le chemin critique.

  <details><summary>Méthode (deux tentatives, la première nulle)</summary>

  **Ce qui n'a pas marché.** `uiautomator dump` attend que l'interface soit au
  repos : le premier sondage a duré 3,00 s en trouvant déjà l'écran de
  connexion — la méthode mesurait sa propre latence, borne inutile de « moins
  de 3 s ». Une rafale de `screencap -p` vers `/sdcard` ne fait guère mieux :
  ~950 ms par trame (encodage PNG + FUSE).

  **Ce qui marche.** Capture **brute** vers `/data/local/tmp` (pas d'encodage)
  et lecture de quelques octets sur l'appareil, sans rien rapatrier : ~200 ms
  par échantillon. En-tête de `screencap` = **16 octets** (largeur, hauteur,
  format, espace colorimétrique), donc l'offset du pixel (x,y) vaut
  `16 + (y*largeur + x)*4`, et `dd bs=4 skip=$((4 + y*largeur + x)) count=1 |
  od -An -tu1` le rend en RGBA. Vérifié contre un PNG de référence : valeurs
  identiques au pixel près.

  Pixel témoin sur ce Pixel 10 Pro XL : **(300, 1994)**, dans le bouton « Se
  connecter » — `(50,226,82)` sur l'écran de connexion, `(15,13,10)` dès qu'on
  est connecté.

  **Deux pièges rencontrés.** ⚠️ Une session ouverte ne donne qu'**une seule**
  déconnexion : l'instrument doit être prêt et calibré avant d'appuyer.
  ⚠️ Et un `adb pull /sdcard/` pour récupérer les trames rapatrie toute la
  mémoire de l'appareil — ne tirer que les fichiers visés.

  </details>

---

### ⬜ Déconnexion forcée « Connecté ailleurs » — trois trous refermés

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Jeton FCM réellement retiré** — vérifié le 2026-09-08. Le jeton de
      l'appareil (`shared_prefs/com.google.android.gms.appid.xml`, début
      `fcAFKu1JQ_au…`) ne figure plus dans `users.fcm_tokens` après la
      déconnexion ; le seul jeton restant sur la ligne du compte commence par
      `e0SXOkYhSfWg…`, c'est un autre appareil. C'était la partie la plus
      risquée du changement — elle est passée en tâche de fond, elle aboutit.
- [x] **Purge locale effective** — vérifié le 2026-09-08. Les sept boîtes Hive
      de cache sont retombées à 0 octet (`conversations_cache.hive` faisait
      2872 octets avant), et `currentUserId` / `currentUserDisplayName` ont
      disparu de `FlutterSharedPreferences.xml`. Mesuré au passage : ces
      boîtes ne dépassaient pas 267 Ko et l'index des pièces jointes comptait
      12 clés — la purge locale, restée bloquante, coûte des millisecondes,
      elle n'est pas un candidat au délai perçu.

---

### Sécurité / Comptes connectés

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Republication des prékeys — CORRIGÉ ET VÉRIFIÉ SUR APPAREIL** (`key_manager_service.dart`, 2026-08-03, SM A515F) : `e2ee_one_time_prekeys` contenait **0 ligne** en production alors que l'appareil en avait 50 en local. `checkAndRefillOneTimePreKeys` ne comparait le seuil de 20 qu'au compteur **local** : un appareil dont la publication initiale avait échoué (RLS, session absente) ne republiait donc jamais. Le contrôle porte désormais aussi sur le compte serveur, avec `null` = « comptage impossible » pour ne pas republier sur une simple coupure réseau.

  Déroulé de la vérification, build installé sur l'appareil : premier démarrage → `KeyManagerService: 50 prékeys en local mais 0 publiées — republication`, puis **0 → 100 lignes** en base. Second démarrage → aucune republication, table **stable à 100** : idempotent, pas de régénération en boucle.
- [x] **Suppression des prékeys d'autrui — CORRIGÉ ET VÉRIFIÉ** (migration `20260803190000`, appliquée en production le 2026-08-03) : la policy `e2ee_one_time_prekeys: authenticated delete` avait pour condition littéralement `true`, sans clause de propriété, alors que l'INSERT de la même table était bien restreint au propriétaire. N'importe quel compte pouvait vider le vivier de n'importe qui — pas une panne, mais une dégradation silencieuse : les sessions suivantes s'établissent alors sans DH4 (cf. audit du repli X3DH), donc sans la protection du message initial, sur une cible choisie.

  Vérifié dans les trois sens, transactions annulées, production intacte à 100 prékeys : un **tiers** qui tente de purger le vivier supprime désormais **0 ligne** ; le **propriétaire** en supprime bien **100**, ce qui préserve la republication de `_publishOneTimePreKeysToSupabase` ; et la RPC `consume_one_time_prekey`, appelée par l'expéditeur sur les clés du destinataire, **fonctionne toujours** — elle est `SECURITY DEFINER` et contourne RLS, ce qui avait été vérifié avant d'écrire la migration, puisque c'était le seul usage légitime de suppression par un tiers.

  Les autres tables E2EE ont été revues au passage et sont correctement cloisonnées : `e2ee_devices` et `e2ee_user_keys` restreignent l'écriture au propriétaire, `e2ee_sender_key_distributions` au destinataire. Seules les lectures de clés publiques sont ouvertes, ce qui est le principe même d'un vivier de prékeys.

  **Repli X3DH audité le 2026-08-03 — ça dégrade, ça ne casse pas.** La chaîne a été vérifiée de bout en bout : la RPC `consume_one_time_prekey` existe bien en production et renvoie proprement `NULL` sur vivier vide (testé, transaction annulée) — donc pas d'exception qui ferait échouer tout `getPreKeyBundle` via son `catch … return null` ; le bundle accepte une prékey nulle (`oneTimePreKeyId`/`oneTimePreKeyPublic` optionnels) ; et `messaging_e2ee_service.dart:212` ne calcule DH4 que `if (bundle.hasOneTimePreKey)`. La session s'établit donc avec DH1+DH2+DH3, ce qui est le comportement standard de X3DH.

  Ce qu'on perd, et c'est réel : la prékey à usage unique est ce qui protège le **message initial** contre une compromission ultérieure de la signed pre-key. Sans elle, quelqu'un qui obtiendrait plus tard la clé privée signed pre-key pourrait recalculer le secret partagé des sessions ouvertes pendant cette période, et le message initial devient rejouable. Ce n'est donc pas une panne à traiter en urgence, mais un affaiblissement de la confidentialité persistante qui dure tant que le vivier reste vide.

  Correctif suggéré, non implémenté : faire comparer `checkAndRefillOneTimePreKeys` au compte **serveur** (ou publier inconditionnellement si le serveur est à zéro) plutôt qu'au seul compteur local — sinon le parc installé ne se rattrapera jamais.
- [x] **Non-régression après la bascule d'identité**
      **✅ Prouvé en base le 2026-09-14, sans appareil** (identité de Sim A
      simulée par `request.jwt.claims` + `SET LOCAL ROLE authenticated`,
      chaque essai dans une transaction annulée — sans quoi `db query
      --linked` se connecte en `postgres` et contourne la RLS).
      **Lecture** : la base contient 9 conversations et 88 messages ;
      Sim A n'en voit que **5 et 58** — donc 4 conversations et 30 messages
      lui restent invisibles, et le témoin positif tient (il voit bien les
      siens, ce n'est pas un refus général). Les 37 profils lui sont
      visibles, ce qui est voulu : un profil non privé est public.
      **Écriture** : modifier le profil de Salim L. → **0 ligne** ;
      modifier le sien → **1 ligne** (témoin) ; insérer un message dans une
      conversation dont il n'est pas membre → **refusé, 42501**.
      ⚠️ **Ce que ça ne prouve pas** : tickets, transactions, abonnements
      podcast et stickers favoris sont **vides** pour ce compte (0 ligne
      côté `postgres`), donc un « 0 vu » n'y voudrait rien dire. Ces
      tables-là restent à vérifier quand elles auront des données. (même migration) : le risque miroir est d'ouvrir trop. Avec **deux** comptes, vérifier qu'on ne voit toujours pas les données de l'autre — ses favoris, ses tickets, ses transactions, son profil privé — et qu'on ne peut pas modifier son profil ni ses podcasts.

---

### Assistant de configuration du profil

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **« Terminer » ne sort pas de l'assistant** (vérifié sur SM A515F le
  2026-08-03, `lib/features/profile/presentation/screens/profile_config_screen.dart:172`).
  À l'étape 4/4, le tap est bien reçu et `_handleComplete` s'exécute, mais
  l'écran reste sur 4/4 indéfiniment. Il a fallu un `am force-stop` +
  relance pour atteindre `/home`. Deux causes enchaînées :
  - l'écriture Firestore `users/{uid}` est rejetée
    (`PERMISSION_DENIED — Missing or insufficient permissions`, visible
    uniquement dans logcat) ;
  - le cache offline de Firestore fait résoudre `updateProfile` **sans
    erreur**, donc le `catch` de `_handleComplete` ne se déclenche jamais et
    **aucun snackbar n'apparaît** — l'utilisateur n'a strictement aucun
    retour. Vérifié : trois taps consécutifs, zéro message à l'écran.

---

## 9. Fil, stories, salons audio et podcasts

### ⬜ Compteurs de Mon espace et du Profil : ils suivent enfin (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Abonnés / Abonnements** (deux comptes) : suivre le second compte depuis
  une carte du fil, ouvrir Mon espace → « Abonnements » a augmenté de 1 **sans
  redémarrer l'app** ; ne plus suivre → il redescend. C'est le cas qui ne
  marchait pas.
  ✅ SM A515F, build release `e5cb916c…`, 2026-09-14 11:16 : 0 → 1 après
  « Suivre » sur la carte de Salim, 1 → 0 après « Ne plus suivre », l'app
  n'ayant été redémarrée à aucun moment. Compte rendu à son état d'origine.

---

### ⬜ Fil : tirer pour rafraîchir partout, et pastille « N nouvelles publications » (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Tirer vers le bas sur un fil court** (filtrer par ville pour n'avoir
  qu'une ou deux publications) : l'indicateur circulaire apparaît et le fil se
  recharge. C'est le cas qui ne marchait pas — la liste ne débordait pas, donc
  il n'y avait rien à tirer.
  ✅ SM A515F, build release `e5cb916c…`, 2026-09-14 11:15 : l'indicateur circulaire orange apparaît sur un fil d'**une seule** publication et le fil se recharge. C'est exactement le cas qui ne marchait pas.
- [x] **Tirer sur un fil vide** (compte neuf, ou filtre sans résultat).
  ✅ SM A515F, build release `fbd02d9d…`, 2026-09-14 19:58, sur le fil vide du
  hashtag `zzzaucunresultat` : le geste déclenche bien le rechargement — la
  rafale de captures prend les squelettes (`isLoading` repassé à vrai) juste
  après le relâchement, puis le retour à l'état vide.
- [x] **Tirer sur l'écran d'échec** : même geste, même rechargement.
  ✅ SM A515F, build release `fbd02d9d…`, 2026-09-14 20:36 (mode avion posé
  par Salim) : l'écran affiche la **bonne cause** — icône wifi barré, « Pas de
  connexion », « Ton téléphone n'est relié à aucun réseau » — et non le message
  générique. Le geste part : la rafale prend les squelettes (`refresh()`
  appelé), puis l'échec revient, le réseau étant toujours coupé.
  À noter : dans ce cas **il n'y a pas de bouton « Réessayer »** (le texte dit
  que le fil se rechargera tout seul), donc le tiré-pour-rafraîchir est la
  seule main que l'utilisateur ait — et il ne partait pas avant.

  **Méthode, pour la prochaine fois** : couper le réseau ne suffit pas à
  atteindre cet écran. Le fil général se replie sur son cache et affiche les
  publications avec le bandeau « hors ligne ». Il faut un **hashtag jamais
  consulté** (`diasponiger://feed?hashtag=zzzhorsligne`) : sa page n'est pas en
  cache, l'échec n'a rien à replier dessus, et l'écran d'échec s'affiche.
- [x] **Pastille** : publier depuis le second téléphone ; sur le premier, la
  pastille descend en haut du fil avec l'avatar de l'auteur, sans déplacer la
  lecture en cours ; la toucher pose la publication en tête et remonte le fil.
  ✅ SM A515F, build release `fbd02d9d…`, 2026-09-14 20:27:37 : Salim publie
  « Bonjour » depuis le Pixel (compte « Test Appareil »), la pastille apparaît
  sur le fil du SM — galet orange, avatar « T » de l'auteur, flèche haute,
  « 1 nouvelle publication ». Détectée 40 s après le début de la veille ; **on
  ne sait pas par quel chemin** elle est arrivée (temps réel ou sondage), faute
  de connaître l'heure exacte de la publication — c'est ce que mesure l'entrée
  « Sans temps réel » ci-dessous. L'appui sur la pastille a été fait par Salim
  et vu par lui à l'écran, pas mesuré ici.
- [x] **Après une coupure réseau** : couper le Wi-Fi/les données, publier
  depuis l'autre téléphone, rétablir : la pastille apparaît sans aucun geste.
  ✅ SM A515F, build release `fbd02d9d…`, 2026-09-14 : coupure à 20:32:54,
  réseau revenu à 20:33:47, pastille à 20:33:57 — **10 s après le retour**. La
  publication est restée derrière la pastille sans s'insérer dans la liste.
  ⚠ **Ce test ne crédite pas le sondage.** 10 s, c'est le `rattrapage` du
  canal Postgres à sa reconnexion (`rattrapageAuRejoint`), qui existait avant.
  Le sondage, lui, tique à 60 s : sa minuterie était partie à 20:32:01, le tic
  de 20:33:01 est tombé pendant la coupure (écarté, `connectivityNotifier` à
  faux) et le suivant était à 20:34:01 — 4 s **après** la pastille.
- [x] **Thème sombre et `font_scale` 1.3** : la pastille reste lisible sur le
  fond sombre et son texte ne déborde pas du galet (voir « Fil sombre : même
  structure que le fil clair »).
  ✅ SM A515F, build release `fbd02d9d…`, 2026-09-14 20:40, `font_scale 1.3` +
  `cmd uimode night yes` (remis à 1.0 / no ensuite) : galet à l'accent violet
  du thème sombre, « 1 nouvelle publication » **en entier**, sans troncature ni
  bande de débordement, avatar cerclé lisible, galet dans la largeur de
  l'écran. Il recouvre la ligne d'auteur de la première carte — c'est voulu,
  il flotte au-dessus du fil.

---

### ⬜ Fil sombre : même structure que le fil clair (2026-09-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **SM A515F, thème Sombre choisi dans Réglages** (build `88e12b8`, md5
  `96e704a5…`) : titre serif « Le fil. » avec point d'accent, onglet actif
  plein, carte arrondie, « Suivre » en texte, bouton d'écriture plein —
  identique au clair, seules les couleurs changent. Thème remis sur « Système »
  après la capture. (2026-09-13 21:44)

---

### ⬜ Stories : ajouter, supprimer, audience, listes, 24 h (2026-09-12)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Supprimer** : ma story → ⋮ → « Supprimer cette story » → confirmer :
  elle disparaît du viewer et du rail ; s'il n'en reste aucune, le viewer se
  ferme. (`story_viewer_screen.dart`)
  ✅ SM A515F, build `dd38fda`, 2026-09-13 : menu à trois entrées, dialogue de confirmation, ligne effacée en
  base, viewer refermé, rail revenu à « Ajouter ».
- [x] **Audience à la publication** : feuille de création → « Qui peut voir »
  → Amis ; publier ; le viewer affiche « Amis » à côté du nombre de vues.
  ✅ SM A515F, build `dd38fda`, 2026-09-13, fait avec « Liste restreinte » (vide, donc invisible pour tous) :
  la feuille reprend le choix, `stories.audience = close` en base, le viewer
  affiche « Aucune vue · Liste restreinte ».

---

### ⬜ Compteurs de commentaires et de repartages justes (2026-09-12)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Commentaires d'autrui** : sur « In kwana » (2 commentaires, un de Salim,
  un de Sim), le détail en montre bien 2 sur les DEUX téléphones.
  (policy `post_comments_select_visible`)
  ✅ SM A515F, build `dd38fda`, 2026-09-13 : le commentaire de Sim avait été supprimé entre-temps (2026-09-12
  23:36, hors de ce correctif) ; il reste celui de Salim, que Sim lit
  désormais — « 1 commentaire(s) », compteur de la carte à 1, conforme à la
  base.

---

### ⬜ Supprimer une publication depuis le fil ne ramène plus à l'accueil (2026-09-12)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Fil (ouvert depuis l'accueil) → ⋯ d'une de mes publications → Supprimer
  → confirmer : le fil reste affiché, la carte disparaît, toast « Publication
  supprimée ». (`post_card.dart`)
  ✅ SM A515F, build `dd38fda`, 2026-09-13 : ouvert par lien profond, « Le fil. » reste affiché, carte partie,
  ligne effacée en base. Le toast n'a pas été capturé.

---

### Refonte Fil & Discussion — Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Viewer de stories** (`story_viewer_screen.dart`) : barre de progression segmentée, auto-avance 5s, tap gauche/droite (précédent/suivant), swipe vers le bas pour fermer, enchaînement automatique sur l'auteur suivant du rail. *(2026-08-03, SM A515F : l'image s'affiche, l'en-tête porte avatar / nom / « il y a moins d'une minute » / croix, le minuteur de 5 s tourne et ferme le viewer en fin de rail, et le glissement vers le bas ferme immédiatement. **Tap gauche/droite et enchaînement sur l'auteur suivant restent non vérifiés** : une seule story, un seul auteur — il faut un deuxième compte publiant une story.)*
- [x] **Création de story** (`story_rail.dart`) : permission caméra (première demande), permission galerie, upload, apparition dans le rail avec l'anneau correct. *(2026-08-03, SM A515F, bout en bout depuis la galerie : sélection → upload → la story apparaît dans le rail, l'avatar « + » cède la place à l'anneau accent, et le viewer la relit. **A d'abord échoué** en `unauthorized` : `storage.rules` n'avait pas de bloc `stories/`, corrigé et déployé (voir le bloc de session en tête de fichier). Aucune permission runtime n'est demandée pour la galerie — l'app passe par le photo picker système, qui n'en exige pas. **Le chemin caméra reste non testé** (permission caméra première demande).)*
- [x] **Rail de stories** : anneau dégradé (non vues) vs anneau gris (tout vu), avatar "+" quand pas de story active, défilement horizontal. *(2026-08-03, SM A515F : avatar « + » correct sans story, remplacé par l'anneau accent dès qu'une story est active. **L'anneau gris « tout vu » n'est toujours pas distinguable** — ma propre story ne bascule pas en gris après lecture, et il n'y a aucun autre auteur ; défilement horizontal multi-avatars idem. Un débordement de 6 px à `font_scale = 1.1` a été trouvé ici et corrigé.)*
- [x] **« Qui a vu » ma story** (ajouté 2026-07-31) : le tap « N vues » (visible seulement pour l'auteur) met la lecture en pause, ouvre la feuille avec la liste (avatar/nom/heure + emoji de réaction le cas échéant), la reprise de lecture à la fermeture de la feuille. *(2026-08-03, SM A515F : la pastille est bien réservée à l'auteur, le tap met la lecture en pause — le viewer reste ouvert bien au-delà des 5 s — la feuille liste avatar / nom / heure, et la fermeture relance le minuteur, qui va au bout et ferme le viewer. **Deux réserves** : la pastille continue d'afficher « Aucune vue » alors que la feuille liste une vue, et la vue de l'auteur lui-même est comptée. L'emoji de réaction dans la liste n'est pas vérifiable en solo.)*

---

## 10. Ambassades, démarches, carte, entreprises et événements

### ⚠️ Carte : bouton « Message » de la fiche membre et icône de la liste des membres proches — corrigés, vérifiés SM A515F (partiel, 2026-09-17)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Bouton Message (fiche membre, ami)** — SM A515F, build debug du
  correctif (`6dfa7e7`) : tap sur « Message » depuis la fiche de Salim L.
  ouvre bien la conversation existante.
- [x] **Icône bulle (liste des membres proches, ami)** — SM A515F, même
  build : tap sur l'icône dans la ligne de Salim L. ouvre directement la
  conversation (avant le correctif : rouvrait la fiche, sans effet visible).
- [x] **Ouverture depuis le cache (`61d3a06`)** — SM A515F, marqueurs logcat
  (captures peu fiables ici : « membres à proximité » change de hauteur entre
  deux taps, et un usage concurrent du téléphone a confirmé le piège
  documenté dans `project_device_testing.md`) : le chemin rapide (conversation
  déjà connue via `conversationsProvider`) pousse la route en 3 à 26 ms,
  contre l'aller-retour réseau complet observé avant ce correctif.

---

### ✅ Avis d'une entreprise : « Erreur de chargement », index Firestore manquant — corrigé, vérifié SM A515F (2026-09-15)

**Priorité P1** · importance 3/5 — Ouvrir les avis d'une entreprise
(`/businesses/<id>/reviews`) rendait « Erreur de chargement » à chaque fois :
`business_reviews` porte `where(businessId).where(status).orderBy(createdAt)`
(`review_remote_datasource.dart`), et aucun index composite ne couvrait cette
combinaison — jamais déclenché avant faute d'avis sur une entreprise.
Signalé par Salim, capture SM A515F du 2026-09-15 (la fiche « Sonda », 11 vues,
zéro avis, tombait dessus).

Deux index ajoutés à `firestore.indexes.json` (`businessId, status,
createdAt` et `userId, createdAt`, ce dernier pour `getUserReviews`, pas
encore relié à un écran mais qui aurait cassé pareil) et déployés
(`firebase deploy --only firestore:indexes`).

- [x] **Construction de l'index** — confirmée terminée par requête directe
  (SDK Admin, contournant l'app) ~10 min après le déploiement, sur une
  collection quasi vide.
- [x] **Écran** — SM A515F, fiche « Sonda », bouton « Réessayer » après
  construction : passe de l'erreur à « Aucun avis pour le moment ».

⚠️ Le premier essai après la fin de construction a encore montré l'erreur :
`businessReviewsNotifierProvider` ne réessaie pas de lui-même une fois entré
en état d'échec, il faut le bouton « Réessayer » (ou toucher `Erreur de
chargement`, sinon lire `firestore/indexes` : « that index is currently
building » signifie fait, pas cassé).

---

### ✅ Annuaire Business : texte et icônes quasi invisibles sur la carte — corrigé, vérifié SM A515F clair + sombre (2026-09-14)

**Priorité P2** · importance 2/5 — Sur l'écran `/businesses`, la ville, les
icônes de localisation, l'icône de remplacement (pas de photo) et le nombre
d'avis étaient posés en `theme.colorScheme.outline` — une couleur de
**bordure** (`AppColors.border`/`borderDark`, quasi confondue avec le fond de
carte dans les deux thèmes), pas une couleur de texte. Rendu quasi illisible,
signalé par Salim sur capture SM A515F.

**Corrigé** dans `business_card.dart` et `businesses_screen.dart` : bascule
vers `context.textSecondaryColor`/`context.textTertiaryColor`/
`context.iconTertiaryColor` (`AdaptiveColors`, déjà la source unique de ces
tons ailleurs dans l'app). `outlineVariant` reste en place là où c'est un
vrai trait de bordure (`businesses_screen.dart`, séparateur du filtre
localisation).

- [x] **Thème clair** — SM A515F, `/businesses` (lien profond
  `https://diasponiger.com/businesses`) : ville et icônes lisibles sur les
  trois cartes de la liste.
- [x] **Thème sombre** — même écran, `adb shell cmd uimode night yes` :
  toujours lisible, aucune régression du gris de bordure en clair sur fond
  sombre.

---

### ✅ Événements sur Supabase — BASCULÉ et vérifié SM A515F (2026-09-09 22:35)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le compteur de participants ne bougeait pas** — ✅ vérifié SM A515F 2026-09-09 23:05 : annulation → 0, réinscription → 1, en base comme à l'écran. (`event_attendees` à 1,
      `events.attendee_count` à 0). Ma faute dans `20260910010000` : j'ai
      réécrit le trigger sans `SECURITY DEFINER`. Il tourne donc sous
      l'identité du participant, et `events_manage_own` réserve l'UPDATE à
      l'organisateur — la RLS ne fait pas échouer l'UPDATE, elle lui donne
      **zéro ligne**. Aucune erreur nulle part. C'est la forme d'échec muet
      la mieux connue du projet, réintroduite par moi.
      `20260910023000` la remet en DEFINER et recale les compteurs.
      Vérifier : « Participer » depuis un compte non-organisateur → le
      nombre de participants augmente à l'écran.
- [x] **La notification disait « Un utilisateur participera à … »** — ✅ vérifié : la ligne de 23:05 dit « **Sim A** participera à "Tabaski 2026" », juste au-dessus des deux anciennes en « Un utilisateur » (dont une du 5 août).
      (signalé par Salim). `attendEvent` lisait le nom dans **Firestore**
      (`users/<uid>.displayName`) alors que les comptes vivent sur Supabase :
      le document n'existe pas, et le repli générique masquait la panne au
      lieu de la signaler. Lu depuis `public.users.display_name`.
      Vérifier : participer à l'événement de quelqu'un d'autre → il reçoit
      « <votre nom> participera à … ».
- [x] « testeur » (passé, resté `upcoming`) apparaît dans « Passés » — ✅ SM A515F 2026-09-10 00:45, avec « gh » (19 juil.) : les deux étaient invisibles avant.
- [x] « Tabaski 2026 » (annulé) : pastille rouge « Annulé » entre « Culturel »
      et « Gratuit », et bouton grisé « Annulé » à la place de « Participer » —
      ✅ SM A515F 2026-09-10 00:47.
- [x] Aucun événement absent des deux onglets — ✅ les 3 événements en base sont
      visibles. ⚠️ **Deuxième passe nécessaire** : la pastille de la carte
      disait « À venir » **dans l'onglet Passés** (elle lisait `status` brut).
      Corrigée en « Terminé » / « Annulé », revérifiée. Rendre visible sans
      corriger l'étiquette aurait déplacé la confusion, pas retirée.

---

### ✅ Annuaire d'entreprises branché sur Supabase (2026-09-09)

`/businesses/<uuid>` affichait « Entreprise non trouvée » quel que soit le
chemin d'accès. Même famille que les événements : le module lisait
**Firestore** alors que les entreprises vivent dans `public.businesses`.

Trois pièces livrées : `BusinessSupabaseDataSource` (21 méthodes), la table
`business_boosts` qui manquait, et `increment_business_view_count`.

**Deux fausses pistes écartées, à ne pas refaire :**

1. Les deux lignes étaient `is_active = false` — activées, sans aucun effet :
   la fiche ne regardait même pas cette table.
2. L'embed `users(display_name)` échouait en **PGRST200**. Cause :
   `businesses` n'avait **aucune clé étrangère**, alors que le schéma initial
   en déclare une. La table venait de l'import Firestore du 2026-04-12, donc
   le `CREATE TABLE IF NOT EXISTS` du schéma initial n'a rien créé — ni la
   clé, ni le `DEFAULT TRUE` de `is_active`, ce qui explique aussi le point 1.
   **Réflexe à garder : une table importée peut avoir traversé un
   `CREATE TABLE IF NOT EXISTS` sans rien en recevoir.**

- [x] **`/businesses/<uuid>` ouvre la fiche** — vérifié SM A515F, démarrage à
      froid : « Sonda », Restaurant, contact, Talladje/Niamey.

Non vérifiés faute de données : création d'une entreprise, boost, offres et
publications d'entreprise, recherche de proximité.

---

### ⚠️→✅ La garde d'organisateur refusait l'organisateur (2026-09-08)

Trouvé **en vérifiant autre chose** : le A51, compte organisateur, affichait
« Modification réservée à l'organisateur » sur un lien qui avait ouvert le
formulaire une minute plus tôt.

La cause est dans la garde que je venais d'écrire :
`ref.watch(currentUserProvider).valueOrNull` rend `null` aussi bien pour
« déconnecté » que pour « pas encore chargé », et je traitais les deux comme
un refus. Au démarrage à froid — précisément le cas du lien profond — la
session n'a pas encore émis : **la garde tranchait avant de savoir qui
regarde**. Défaut intermittent, et l'écran de refus n'offre rien à réessayer.

Corrigé dans les trois routes gardées : on attend que la session soit
*résolue* (valeur **ou** erreur) avant de décider ; en attendant, l'état de
chargement, qui a sa sortie. Le test porte sur l'absence de valeur et
d'erreur plutôt que sur `isLoading`, ce dernier étant aussi vrai pendant un
rafraîchissement — il ferait clignoter un écran déjà rendu.

- [x] A51 (organisateur), **démarrage à froid** : « Modifier l'événement »
      s'ouvre. C'est la condition exacte qui produisait le faux refus.
- [x] Pixel (non-organisateur) : « Modification réservée à l'organisateur »
      s'affiche toujours — la correction n'a pas ouvert la porte.
- [x] L'étiquette du champ description dit « Description » et non plus
      « La description est requise ».

À retenir : **`.valueOrNull` sur une session ne peut pas décider d'une
autorisation.** Le motif se lit bien, passe l'analyse, passe les tests qui
donnent une session immédiate, et ne se voit qu'au démarrage à froid sur
appareil. Les autres écrans s'en tirent parce qu'ils dégradent en douceur
(un bouton masqué) au lieu d'accuser.

---

### Postes diplomatiques sur la carte : 30 pins sur 32 (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Le bouton « Y aller » du détail** (et « Itinéraire » sur la carte de
      liste) est actif sur les postes placés, absent sur les autres.
      *Vérifié sur Pixel 10 Pro XL le 2026-09-08, sans réinstaller l'app :
      les coordonnées viennent de la base, l'APK en place suffit. Alger →
      « Appeler / Itinéraire / Détails » et « Y aller » actif sur la fiche ;
      Le Caire → « Appeler / Détails » seulement. Revérifié après la seconde
      migration : Le Caire affiche désormais « Itinéraire » et remonte de la
      zone « Autres » à « Afrique ».*
- [x] **Un poste sans pin reste visible dans la liste**, sous « Autres », avec
      son adresse — vu sur le Pixel le 2026-09-08, avant la seconde migration.
      Aucun ne tombe au point (0, 0) : le modèle ne convertit plus `null` en
      `0.0`.
- [x] **Dakar et Pretoria : divergence tranchée en faveur d'OSM.** Leur adresse
      publiée tombait à 5,2 km et 2,4 km du nœud ; Google y place une ambassade
      à 7 m et 14 m du nœud. C'est l'annuaire officiel qui est en retard.
- [x] **Regroupement par zone, corrigé dans la foulée** (`ZoneGeographique`,
      testé à froid) : Alger s'affichait sous **Europe** (constaté sur le
      Pixel : « Europe · 9 » contenait l'Algérie) et Riyad serait tombé en
      **Afrique**.
      *Vérifié sur Pixel 10 Pro XL le 2026-09-08, APK reconstruit et réinstallé
      (md5 du binaire local et de `base.apk` identiques) : Alger → **Afrique**,
      Riyad → **Asie**, Ankara → **Europe**, Khartoum (sans coordonnées) →
      **Autres**, toujours visible dans la liste. En-tête « Près de vous · 2 »
      et « Le plus proche · 538 km » sur la mission auprès des Nations unies,
      cohérents avec un profil situé au Canada.*
- [x] ⚠️ **Débordement en paysage, clavier ouvert** (`embassies_screen.dart`,
      vu sur Pixel 10 Pro XL le 2026-09-08) : dès que le clavier s'ouvre sur la
      recherche de l'annuaire en **paysage**, un bandeau
      « BOTTOM OVERFLOWED BY 69 PIXELS » barre l'écran sous le champ.
      *Corrigé le 2026-09-08 — et ce n'était **pas** la famille du panneau
      ancré des messages.* Aucun inset périmé, aucune animation, rien à relire
      dans `View.of(context)` : la `Column` posait le champ, la carte « le plus
      proche » et la ligne de comptage en hauteur fixe au-dessus d'un
      `Expanded`. Le clavier en paysage ne laisse que **42 dp** de `body`
      (392 dp d'écran à la densité forcée 440, moins la barre d'état,
      l'`AppBar` et 266 dp de Gboard) là où le seul champ en fait 60 à
      l'échelle de police 1.3 du testeur : l'`Expanded` tombait à 0 et le
      contenu fixe débordait du reste. Les deux chiffres constatés se
      recoupent — 69 px la carte masquée (recherche en cours), **188 px** carte
      affichée, reproduit ici. L'en-tête est devenu défilant
      (`CustomScrollView`), ce qui supprime la contrainte au lieu de l'ajuster :
      aucune hauteur seuil ne tiendrait, elle dépend de l'échelle de police et
      du clavier. Banc : `test/features/embassies/annuaire_clavier_paysage_test.dart`,
      aux métriques relevées à l'adb (rouge à 54 px / 67 px avant correctif).
      *Vérifié sur Pixel 10 Pro XL le 2026-09-08, APK debug reconstruit depuis
      le bout de la branche après `flutter clean` et réinstallé (md5 local et
      `base.apk` identiques — vérification obligatoire : entre deux passes, un
      autre build s'était installé sur l'appareil et le md5 ne correspondait
      plus).*
      **Paysage** : trois ouvertures du clavier, chacune instrumentée
      (`cur=2404x1080` relu à chaque fois, `mInputShown` passant de `false` à
      `true`), aucun bandeau ; carte « le plus proche » affichée (cas 188 px)
      comme masquée par une requête (cas 69 px) ; l'en-tête défile sous le doigt
      et la ligne de comptage remonte, clavier ouvert. **Portrait** : inchangé —
      champ, carte, comptage et liste tiennent tous au-dessus du clavier, les
      résultats filtrés restent lisibles pendant la frappe.
      **Trois pièges de méthode, tous rencontrés ici** : `input keyevent 111`
      (ÉCHAP) **ne ferme pas** le clavier — `mInputShown` reste à `true`, donc
      re-taper le champ ne prouve aucun second cycle ; `keyevent 4` le ferme
      mais **fait ensuite quitter l'application**, et les captures suivantes ne
      sont plus celles de l'app ; et quitter l'app **libère le verrou
      d'orientation**, si bien que le tap paysage tombe hors écran en portrait.
      La seule boucle fiable est de **relancer l'écran par lien profond** à
      chaque cycle, en relisant l'orientation *et* l'état du clavier avant de
      conclure. Sans cette mesure, trois captures byte-identiques se lisent
      comme « stable » alors qu'elles peuvent n'être qu'un seul et même état
      jamais rejoué.

---

### ⬜ Démarches consulaires : données réelles à la place des délais inventés (2026-09-07)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Vu sur SM A515F (2026-09-07).** Les 20 démarches sont bien là sous
      les 5 intertitres (IMMATRICULATION CONSULAIRE, ACTES D'ÉTAT CIVIL,
      DOCUMENTS DE VOYAGE, ACTES NOTARIÉS, NATIONALITÉ).
- [x] **Vu sur SM A515F (2026-09-07), thème sombre + compte orange.** Les
      intertitres ressortent en orange, nettement au-dessus du fond.
- [x] **Vu sur SM A515F (2026-09-07).** L'encadré « Au choix — une seule de
      ces pièces suffit » s'affiche avec le « ou » entre la pièce d'identité
      et les deux témoins, et le compteur annonce « 2 à réunir » (le groupe
      d'alternatives compte bien pour une).
- [x] **Partiellement vu sur SM A515F (2026-09-07).** Bandeaux orange
      confirmés sur « Carte consulaire » (1) et « Certificat de nationalité »
      (2). Le titre corrigé « Passeport — première demande ou renouvellement »
      apparaît bien dans le menu ; son bandeau n'a pas été ouvert.
- [x] **Vu sur SM A515F (2026-09-07).** Bandeau « ne se fait pas au
      consulat » avec les trois règles de juridiction, et « Timbre fiscal :
      1 500 F CFA » accentué — seule démarche à afficher un montant.
- [x] **Partiellement vu sur SM A515F (2026-09-07).** « Droits de
      chancellerie — montant non publié » confirmé sur la carte consulaire, et
      « Délai de traitement non communiqué par la source » partout où c'est
      passé — le délai inventé a bien disparu.
- [x] **Vu sur SM A515F (2026-09-07).** Les deux blocs s'affichent, et la
      règle des 2-16 ans (« un laissez-passer distinct par enfant ») apparaît
      en note sans case à cocher, comme voulu. Le préfixe de quantité
      fonctionne aussi (« 2 × Photo d'identité récente »).
- [x] **Origine serveur vue sur SM A515F (2026-09-07).** Le pied affiche la
      source et « consultée le 2026-09-07 », **sans** mention d'origine hors
      ligne : la chaîne Supabase répond donc de bout en bout sur l'appareil.
- [x] **L'écran entier s'affiche hors ligne, vu sur SM A515F (2026-09-08).**
      Protocole propre : chargement en ligne, **sans réinstaller**, puis mode
      avion. Le catalogue vient du cache, toutes les pièces s'affichent, et le
      bandeau « Formulaire pré-rempli » disparaît de lui-même puisque le
      profil n'est pas joignable — la dégradation voulue.
- [x] **Fait pour l'écran rouge de Flutter (2026-09-08)** :
      `ErrorWidget.builder` rend « Une erreur est survenue » à la place du
      message brut. ⚠️ Ne couvre PAS les états d'erreur que les écrans
      rendent eux-mêmes — voir la section « Annuaire » ci-dessous.

---

### ⛔ Annuaire des ambassades : deux défauts vus sur appareil (2026-09-07)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Vu sur SM A515F (2026-09-08).** L'annuaire affiche ses 30 postes
      après le retrait de `post_type`, en ligne comme hors ligne, sur cinq
      passages étalés entre 11h49 et 02h00.
- [x] **Fait le 2026-09-08 — et c'était bien plus large que l'annuaire.**
      Le défaut touchait **42 sites dans 30 fichiers** : transferts,
      marketplace, profil, admin, amis, paiements… tous de la forme
      `Text('Erreur: $e')`. Tous passent par `messageErreurUsager`
      (`lib/core/errors/message_erreur.dart`), qui classe la panne en trois
      familles — réseau, droits, le reste — pour que le conseil donné soit
      juste, sans jamais rendre le texte de l'exception.

      Deux tests le tiennent : `message_erreur_test.dart` rejoue les
      exceptions réellement observées et échoue si l'hôte, l'identifiant du
      compte ou le nom de l'exception ressortent ; `aucune_erreur_brute_test.dart`
      relit tout `lib/` et échoue si quelqu'un réintroduit le motif.
- [x] **L'écran d'erreur neutre a été vu, et il était FAUX.** Cache vidé par
      la réinstallation + mode avion : `construireEcranErreurNeutre` s'est
      affiché. Le message était bon — plus d'hôte Supabase ni d'identifiant
      de compte — mais le texte était peint **en chasse fixe, doublement
      souligné de jaune**. C'est le style de secours de Flutter : un
      `ErrorWidget` n'a aucun `Material` au-dessus de lui, donc rien ne
      fournit de `DefaultTextStyle`, et fixer couleur et taille ne suffit
      pas. Corrigé (`DefaultTextStyle` posé dans le widget) et épinglé par un
      cas de test. **Aucun test ne pouvait le voir** : ils ne regardaient que
      les couleurs, et le rendu rasterisé utilise une police de test.
- [x] **Boucle bornée — vu sur SM A515F (2026-09-08).** Le journal montre
      exactement six tentatives, en repli croissant (13 s, 13 s, 23 s… au lieu
      de ~5 s constant), puis « abandon après 6 tentatives — la session reste
      anon jusqu'au retour du réseau ». La cause était que
      `auth_remote_datasource` rappelle `syncWithFirebase` à chaque émission
      de `authStateChanges()`, ce qui court-circuitait le repli exponentiel
      déjà présent : `PolitiqueDeReprise` pose désormais une fenêtre de calme
      qui vaut pour **tous** les appelants.
- [x] **Spinner sans fin corrigé — vu sur SM A515F (2026-09-08).**
      `EmbassiesRepositoryImpl.getEmbassies` borne la lecture distante à 10 s
      et retombe sur la copie locale. Mode avion vérifié avant, pendant et
      après : l'annuaire se résout en ~16 s et affiche ses 30 postes, au lieu
      de tourner au-delà de 85 s.

      ⚠️ Réserve : ce parcours-là a pu emprunter la branche hors-ligne
      directe (`isConnected` à `false`) plutôt que le délai. C'est
      `annuaire_repli_hors_ligne_test.dart` qui prouve le délai lui-même —
      ses cas mettent exactement 10 s, avec un distant qui ne rend jamais la
      main.
- [x] **Corrigé et vu sur SM A515F (2026-09-08).** Le repli joue :
      réseau coupé, l'annuaire sert ses 30 postes depuis la copie locale
      (vérifié à 11h52, 12h25 et 02h00, sans réinstaller entre-temps). Ce
      point était par ailleurs faussé par un piège de méthode — voir le n°3
      ci-dessous, `adb install -r` vide le cache.
- [x] **Corrigé par l'auteur de l'annuaire (`fd0735e`), vu sur SM A515F
      (2026-09-08).** Sa correction traite les deux bouts : `valueOrNull` aux
      lignes 56 et 63, **et** un garde qui évite d'observer le profil quand
      il n'y a pas d'utilisateur.

      Mon propre essai, lui, avait été **annulé** : `valueOrNull` seul
      laissait le code atteindre `repository.getEmbassies()` et attendre
      l'expiration du délai réseau — écran en attente indéfinie, plus de 70 s
      mesurées, sans message ni « Réessayer ». Ce n'était pas mieux qu'une
      erreur. À garder en tête si quelqu'un refait le raccourci.

---

### ✅ Annuaire des ambassades : Firestore → Supabase, 32 postes chargés (2026-09-07)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **✅ SM A515F 2026-09-07** — la liste affiche **30** fiches (et non 32) :
      le compte de test n'a pas de pays renseigné, donc le filtre de
      juridiction masque Genève (Suisse/Autriche/Liechtenstein) et New York
      (Venezuela). Comportement du filtre déjà en place, rendu actif pour la
      première fois par le seed. **À trancher** : un usager sans pays connu
      devrait-il voir les missions permanentes ?
      `lib/features/embassies/presentation/screens/embassies_screen.dart`
- [x] **✅ SM A515F** — « Havane » → 1 résultat, groupé sous Cuba.
- [x] **✅ SM A515F 2026-09-07 — mode avion après un premier chargement** :
      « 30 ambassade(s) trouvée(s) » servies depuis `CACHED_EMBASSIES_V2`
      (32 fiches, `savedAt` 03:25), et la fiche de détail s'ouvre complète
      hors ligne (Pretoria : adresse, fax, réserve, « Y aller » grisé).
      `airplane_mode_on = 1` **et** `Active default network: none` — le VPN ne
      masquait pas l'état hors ligne.
      Il a fallu **trois** correctifs pour y arriver, cf. la liste ci-dessus.
- [x] **✅ Pixel 10 Pro XL, 2026-09-08, mode avion** — chemin d'erreur vérifié.
      SnackBar : « Impossible d'envoyer le message. Vérifiez votre connexion
      et réessayez. » Avant le correctif, cette même SnackBar aurait affiché
      `ServerFailure(… Failed host lookup: 'zyrfkcjjrhddpfxcgezo.supabase.co'
      … /rest/v1/users?select=*&id=eq.<UID>)`.

      Et le log nomme **quelle** erreur a été attrapée, ce qui prouve les deux
      moitiés du correctif d'un coup :

          sendMessageToEmbassy error: ServerException: The service is
          currently unavailable…

      C'est l'écriture Firestore qui a échoué, **pas** la lecture Supabase
      `users` — donc le flux est bien passé au-delà de la lecture du profil,
      qui l'aurait interrompu avec `.value`.

      `Active default network: none` relevé juste avant **et** juste après le
      tap : aucun changement d'état pendant la mesure. Rien n'a été envoyé.
- [x] **✅ SM A515F** — Berlin affiche « Autres lignes : +49 30 80 58 96 61 »
      et « Fax : +49 30 80 58 96 62 ».
- [x] **✅ SM A515F** — « Y aller » grisé sur Berlin et La Havane. Avant ce
      correctif, `toEntity()` remplaçait une latitude nulle par `0.0`, le
      bouton était actif sur les 32 postes et ouvrait le golfe de Guinée.
- [x] **✅ SM A515F** — « La Havane, Cuba », pas de virgule orpheline.

---

### Réglages/Carte — deux interrupteurs de partage de position désynchronisés (2026-08-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Activer « Ma localisation » dans Réglages **sans jamais ouvrir la
  carte** : vérifier en base que `latitude`/`longitude`/`location_updated_at`
  se peuplent dans les secondes qui suivent (permission GPS déjà accordée).
  **✅ 2026-09-11 18:34, SM A515F (Sim A), build 18, carte jamais ouverte.**
  Avant : `share_location = false`, `location_updated_at` figé à 21:06:58 UTC.
  Bascule de l'interrupteur dans Réglages → dans les 25 s : `share_location =
  true` et `location_updated_at = 22:34:30 UTC`. C'est exactement ce que
  l'ancien code ne faisait pas (seul le calque « Membres » de la carte
  démarrait la publication). Les coordonnées elles-mêmes n'ont pas changé —
  le téléphone n'a pas bougé.
- [x] Désactiver « Ma localisation » dans Réglages, app au premier plan :
  vérifier que `location_updated_at` cesse d'avancer (pas de battement de
  cœur résiduel).
  **✅ 2026-09-11 18:35 → 18:39, SM A515F (Sim A).** Coupure de l'interrupteur
  à 22:35:49 UTC, dernière publication à 22:34:30 ; **4 min 35 plus tard, à
  22:39:05, l'horodatage n'avait pas bougé** — alors que le battement est de
  2 min et que l'app est restée au premier plan tout du long (aucun
  `force-stop`, ce qui aurait vidé le test de son sens). Sim A est ainsi
  revenu à son état d'origine (`share_location = false`).

---

### Carte — délai d'affichage des membres autour (2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Déplacement visible sans attendre le sondage** ✅ **PROUVÉ le
  2026-08-05** sur SM A515F (captures `12_avant` / `13_apres`).

  Protocole : carte ouverte et immobile, `update users set latitude=45.6200,
  longitude=-73.6459` sur « Salim L. », validé à `23:10:12.650 UTC`, capture
  à `23:10:18.325 UTC` — **5,7 s après**.

  | | Avant | Après |
  |---|---|---|
  | Pin « SL » | ouest-sud-ouest | remonté au nord |
  | Ligne de liste | « 3,2 km » | « **4,4 km** » |
  | Fraîcheur de l'en-tête | « Il y a 24 s » | « **À l'instant** » |

  La distance affichée correspond au calcul pour la nouvelle position
  (4,41 km). **Le sondage est exclu par l'arithmétique** : il datait de 24 s
  avant la capture « avant », donc le suivant tombait vers `23:10:34` — le
  changement était à l'écran 16 s plus tôt. Et « À l'instant » prouve que
  `_lastMembersUpdate` a été réécrit, ce que fait `_onMemberLocationUpdate`.

  Le canal `users_location_updates` fonctionne donc de bout en bout :
  publication Postgres → RLS → websocket → `_onMemberLocationUpdate` →
  marqueurs et liste.
- [x] **Sortie de rayon — le verdict est prouvé, en test Dart** ✅
  (2026-08-05, `test/features/map/nearby_member_filter_test.dart`, 20 cas).

  La décision a été extraite dans `lib/features/map/domain/nearby_member_filter.dart`
  précisément pour ça. Les huit cas de la branche de retrait couvrent le
  déplacement à 230 km joué cinq fois sur l'appareil sans jamais pouvoir être
  observé, les deux bords à ±0,02 degré du seuil, le partage coupé, le profil
  devenu invisible et les coordonnées absentes.

  **Ce que ça ne prouve pas** : que le pin disparaisse *visuellement*. Le
  trajet websocket → `_onMemberLocationUpdate` est prouvé sur appareil (voir
  ci-dessus), et le verdict est prouvé ici ; reste le rendu, c'est-à-dire
  `setState` + `_updateMarkers`, qui est le même code que pour l'ajout — déjà
  vu fonctionner à l'écran. Le risque résiduel est faible mais non nul.
- [x] **Position publiée hors de l'écran carte** ✅ **vérifié le 2026-08-05**
  sur SM A515F, côté données. L'app était sur un écran de **conversation**
  (jamais sur la carte) et `users.location_updated_at` du compte « Sim A »
  avançait quand même : `22:37:28` → `22:39:28` → `22:42:23` UTC, relevé par
  `supabase db query --linked`. Avant le correctif, cet horodatage ne bougeait
  que pendant que l'écran carte était ouvert.
- [x] **Membre immobile toujours visible** ✅ **vérifié le 2026-08-05** par la
  même mesure : le téléphone n'a pas bougé, et le battement de cœur de 2 min
  réécrit quand même `location_updated_at`. La ligne reste donc dans la
  fenêtre de fraîcheur de 5 minutes du filtre de présence. (Reste à confirmer
  visuellement, sur la carte d'un second compte.)

---

## 11. Accueil, profil et réglages

### ⬜ L'écran des appareils ne promet plus ce qu'il ne fait pas (2026-09-16)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Thème sombre** sur les deux bandeaux (info et plafond).
  ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : bandeau d'information « Inscrits : 2 sur 5 » et notice
  du plafond lisibles sur le fond sombre, icônes comprises.

---

### ⬜ Noter l'application : bouton des Réglages et invitation automatique (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **La tuile est là** : Réglages → « Application », étoile, entre
      « Aide & FAQ » et « À propos », en clair **et** en sombre.
      (`settings_screen.dart`)
      ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff) : « Noter l'application · Votre avis compte, et il aide l'app à
      se faire connaître », étoile orange, entre « Aide & FAQ » et « À propos »,
      sur le SM A515F (Sim, clair, police 1,0) **et** sur le Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) (sous-titre sur deux lignes, sans
      coupure). Pas touchée.

---

### ⬜ Groupes en commun ouvrables depuis un profil (2026-09-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Profil ouvert depuis une discussion** : la section liste les groupes
      partagés — photo, nom, effectif réel. Vérifié SM A515F le 2026-09-13 :
      profil de Salim L. ouvert depuis l'en-tête de la discussion, puis
      « 3 groupes en commun » et ses trois lignes.
      (`profile_view_screen.dart`)
- [x] **Appui sur une ligne** : ouvre la discussion du groupe, avec son nom et
      sa photo dans l'en-tête. Vérifié le 2026-09-13 sur « Testeurs ».
- [x] **Effectif** : le nombre affiché est celui de `group_members`, pas
      « 0 membre » (voir « Fiche membres » au § 3 pour l'historique). Vérifié
      le 2026-09-13 : 3, 2 et 2 membres, conformes à la base.

---

### ⬜ Champ ville : recherche dans le référentiel (2026-09-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Sur appareil** : « À propos » (Profil → Réglages → À propos) affiche
  « Liste des villes : GeoNames (CC BY 4.0) » sous « Tous droits réservés ».
  C'est une obligation de la licence CC BY, pas un ornement. Vu le 2026-09-14
  en **clair ET en sombre** : le dialogue prend bien le fond sombre, et la
  mention reste lisible — `textTertiaryColor`, pas un jeton clair figé. Thème
  relevé (« Système ») et remis à l'identique après.
- [x] **Sur appareil** : taper « mont » avec le pays Canada propose Montréal
  en premier ; avec le pays Niger, ne le propose pas. Une ville choisie
  affiche la pastille verte, une ville retapée à la main la perd.
- [x] **Sur appareil** : changer de pays dans la liste déroulante vide le
  champ ville et éteint la pastille, immédiatement — pas seulement après
  enregistrement.
- [x] **Sur appareil, puis en base** : enregistrer avec une ville choisie, et
  vérifier que `users.ville_id` ET `users.city` sont posés ; enregistrer avec
  un texte libre (« Almoustapha ») et vérifier que `ville_id` est nul et que
  le texte a survécu. Le déclencheur écrase `city` avec le nom officiel dès
  qu'une ville est retenue : le champ doit le refléter au rechargement.
- [x] **Sur appareil, réseau coupé** : la ligne « Recherche impossible pour le
  moment » remplace la liste, et le champ reste saisissable — le texte libre
  doit continuer de partir dans `city`.
- [x] **Sur appareil, le compte « Montréal »** : le champ montre toujours
  « Montréal » SANS pastille. Ouvrir le champ doit proposer « Montréal,
  Québec » ; le choisir doit poser le Canada comme pays. C'est le seul
  chemin par lequel ce profil change de pays — vérifier qu'il ne l'a pas fait
  tout seul.

---

### ⬜ Page « Licences open source » dans les Réglages (2026-09-11)

**Priorité P3** · importance 3/5 — Les textes de licence des polices s'affichent parsemés de carrés ; la page reste présente et lisible.

Aucun écran ne menait à `showLicensePage` : ni les licences des polices
embarquées (`f6e85f4`, OFL) ni celles des paquets (MIT, BSD, Apache…) n'étaient
visibles dans l'app. Or MIT et BSD demandent en principe que leur notice
accompagne la distribution binaire — c'est le rôle de cette page.

[settings_screen.dart](lib/features/settings/presentation/screens/settings_screen.dart) :
nouvelle ligne « Licences open source » après « Code de conduite », avec la
tuile du kit (`DesignSettingsTile` — règle « Réglages : une seule source »).
Elle ouvre la page standard de Flutter, qui liste tous les paquets et, depuis
`f6e85f4`, les 8 familles de police ; la version de l'app est passée en
en-tête.

[licences_polices_test.dart](test/core/utils/licences_polices_test.dart) charge
réellement les 8 textes par le chemin qu'emprunte la page — une faute dans un
nom de `LICENCE-*.txt` et il échoue — et vérifie que les Réglages l'ouvrent.

Vérifié sur **SM A515F** le 2026-09-11, APK release `09932cfe…` (`874aa40`,
md5 local = md5 `pm path`) :

- [x] **Sur appareil** : Profil → Réglages → « Licences open source », juste
  sous « Code de conduite », même tuile que ses voisines. La page s'ouvre avec
  l'en-tête « Diaspo Niger / 1.2.1 (18) / Powered by Flutter ». Liste parcourue
  entière (338 entrées) : les **8 familles** y sont, une licence chacune, et la
  fiche Roboto Mono affiche bien le texte OFL.
- [x] **Thème sombre** : liste et fiche lisibles (texte clair sur fond sombre,
  en-tête dans la police de l'app). Thème remis sur « Système » après le test.
- [x] **Retour** : retour système fiche → liste → Réglages, et flèche de l'app
  liste → Réglages.

⚠️ **Défaut trouvé sur l'appareil, corrigé dans la foulée** : dans les huit
textes de licence de police, **chaque fin de ligne s'affichait comme un
carré** (« Version 1.1.▯ This license… »). Les `LICENCE-*.txt` portaient des
CRLF, **écrits ainsi par mon script d'import** : `write_text` de Python, en
mode texte sous Windows, transforme chaque saut de ligne en CRLF. Git a stocké
du LF (une copie fraîche n'en a aucun), mais la copie de travail qui a servi au
build a gardé les CRLF, et l'APK l'embarque telle quelle ; la page découpe sur
le saut de ligne et laisse le retour chariot. Mon test ne vérifiait que la
présence de « SIL OPEN FONT LICENSE » : il ne pouvait pas le voir.

Corrigé au chargement par une fonction pure (`texteLicenceAffichable`), testée
sur un texte CRLF écrit en dur — un test qui lirait les fichiers passerait sur
toute copie LF, donc serait aveugle.

- [x] **Rendu sans carré revu** le 2026-09-11 sur SM A515F, APK release
  `37708518…` (`24a3408`, md5 local = md5 `pm path`). Condition de preuve lue
  dans l'APK lui-même, et non sur le disque (dont les relevés ont varié) : la
  licence Roboto Mono **embarquée** contient 93 retours chariot. Fiche Roboto
  Mono : texte OFL affiché, **aucun carré**, aucun retour chariot dans le texte
  rendu. La normalisation tient sur une vraie entrée CRLF.

---

### ✅ Profil : la carte de statistiques débordait par la droite — corrigé et vérifié Pixel 10 Pro XL (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Profil : plus de bandeau jaune et noir à droite de la carte de
      statistiques, et `logcat | grep overflowed` reste vide sur tout le
      défilement de l'écran.
- [x] Les quatre libellés restent lisibles en entier (pas de troncature) et les
      quatre compteurs restent alignés.
- [x] Les libellés ne se touchent plus et ne chevauchent plus les filets.
- [x] Libellés de section (`DesignSectionLabel`) : « ACTIONS DU COMPTE » tient
      sur une ligne, sans débordement.

---

### Réglages — ligne « Devise d'affichage » mise en commentaire (2026-09-08)

Sur demande, la ligne *Devise d'affichage* de l'écran Réglages est commentée,
pas supprimée —
[settings_screen.dart:280](lib/features/settings/presentation/screens/settings_screen.dart:280).
Le sélecteur (`_CurrencySelectorModal`, ses 50 devises classées par région) et
les deux méthodes qui l'ouvrent restent en place, marquées
`// ignore: unused_element` : décommenter la tuile suffit à tout rétablir.

À noter, vérifié avant de masquer : `selectedDisplayCurrencyProvider` n'était
lu **nulle part ailleurs** dans `lib/` — le choix ne changeait l'affichage
d'aucun prix (marché, transferts, salons ont chacun leur propre devise par
article). Masquer la ligne ne retire donc aucun comportement.

- [x] **✅ SM A515F, 2026-09-08 : la ligne a bien disparu.** Section
      APPLICATION, « Langue › Français » est suivi directement de « Fond
      d'écran des conversations › Thème par défaut » — pas de trou, pas de
      filet en double (`DesignListCard` pose ses propres séparateurs).
- [x] **✅ Rien d'autre n'a bougé** : Notifications push, Notifications,
      Thème, Langue, Fond d'écran, Suppression du bruit, Aide & FAQ,
      À propos (1.2.1 (11)), Conditions d'utilisation — ordre et sous-titres
      intacts. APK debug `6672c96e…`, md5 confirmé identique sur les deux
      téléphones avant la capture.

⚠️ **Le vrai piège de cette session n'était pas le code.** La tuile est restée
visible après une livraison *réussie* : le commit était bien sur `origin`,
mais le **dépôt principal**, d'où part la compilation, était resté 7 commits
en arrière (`d62512c`). Un worktree pousse vers `origin`, il ne met pas à jour
la copie de travail principale. Avant de conclure qu'un correctif « ne marche
pas », vérifier `git log HEAD..origin/<branche>` dans le dépôt principal.

---

### Icônes des tuiles de services agrandies (2026-08-19)

Demande de Salim : icônes plus grandes sur les tuiles de services.
- Grille de l'accueil (`_ServiceTile`,
  [home_screen_widgets.dart](lib/features/home/presentation/screens/home_screen_widgets.dart)) :
  26 → 32.
- « Tous les services » (`QuickActionCard`,
  [quick_action_card.dart](lib/features/home/presentation/widgets/quick_action_card.dart),
  utilisé uniquement par cet écran) : 28 → 36.

Vérifié sur SM A515F le 2026-08-19 (thème sombre, captures dans la session) :
- [x] Pas de débordement des cartes « Tous les services » (grille 2 colonnes,
  `childAspectRatio: 1.1`) avec la font scale 1.1 du SM A515F — 5 tuiles
  affichées, icône 36 nette dans la pastille, aucune troncature.
- [x] Rendu de la grille accueil en 3 colonnes (icône 32 dans le carré) —
  le cas 4 colonnes reste à voir (il faut ≥ 4 tuiles actives).
- [x] Thème clair (basculé via `cmd uimode night no`, remis en sombre
  ensuite) : accueil et « Tous les services » propres, pastilles teintées
  lisibles, aucune troncature.

---

### Annuaire, Fil et Ambassades toujours actifs — plus de flag (2026-08-19)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Accueil et « Tous les services » montrent bien Annuaire + Ambassades
  même si le back-office les avait désactivés (c'était le symptôme de départ :
  seule « Ambassades » s'affichait). Accueil = Fil/Annuaire/Ambassades,
  « Tous les services » = + Événements + Amis.
- [x] `/businesses` s'ouvre (écran « Annuaire Business », vide de données
  mais fonctionnel — plus de redirection silencieuse vers /home).
- [x] Back-office → Fonctionnalités : les deux interrupteurs Annuaire et
  Ambassades verrouillés sur actif (sous-titre explicatif, les autres
  manœuvrables) — couvert par un test de widget plutôt qu'un test appareil :
  `test/features/admin/feature_flags_toujours_actifs_test.dart` (le serveur
  dit `false`, l'écran doit quand même les montrer actifs et non
  manœuvrables ; exactement 2 interrupteurs verrouillés).

---

### « Tous les services » complété : Fil, Événements, Amis (2026-08-19)

L'écran « Tous les services »
([services_screen.dart](lib/features/home/presentation/screens/services_screen.dart))
ne listait que 6 tuiles (Transfert, Marketplace, Annuaire, Ambassades, Salons
audio, Podcasts) — moins que la grille de l'accueil, qui a en plus « Le fil ».
Ajoutés : **Le fil** (`/feed`, sans flag, comme sur l'accueil), **Événements**
(`/events`, gaté `isEventsEnabledProvider` — le module avait un flag et une
route mais aucune tuile nulle part), **Amis** (`/friends`, sans flag).

Vérifié sur SM A515F le 2026-08-19 (thèmes sombre ET clair) :
- [x] Rendu de la grille 2 colonnes avec les tuiles de plus (5 affichées,
  pas de débordement, `childAspectRatio: 1.1`) — dans les deux thèmes.
- [x] Tap sur chaque nouvelle tuile : Fil (posts affichés), Événements
  (liste vide fonctionnelle), Amis (1 ami listé) s'ouvrent, et le retour
  système revient bien sur « Tous les services » à chaque fois.
- [x] Couleur `Colors.teal` de la tuile Événements lisible en thème sombre.

À noter (vu pendant la session, non corrigé ici) : si le back-office affiche
des fonctionnalités actives que l'app ne montre pas, l'écriture des flags a pu
être refusée en silence (règle Firestore `isSuperAdmin()` sur `app_config` +
famille « faux succès » des `set()` Firestore) — diagnostic en cours côté
prod.

---

### Doublons Profil / Réglages (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **L'engrenage de l'en-tête du Profil reste le seul chemin vers Réglages**
  — les trois raccourcis (Confidentialité, Apparence, Aide) ont disparu.
  Vérifier qu'on atteint toujours chaque section en faisant défiler.
  **✅ 2026-09-11, SM A515F** : en-tête du Profil = « Partager mon profil » +
  « Réglages » seulement ; par l'engrenage, toutes les sections défilent
  jusqu'au bout (qui vous voit, sauvegarde des clés, appareils connectés,
  thème, langue, aide, à propos « 1.2.1 (18) », légal, licences, export).
- [x] **Profil : un seul filet entre les lignes** (`profile_screen.dart`) —
  chaque séparation en affichait **trois** superposés : `DesignListCard` insère
  déjà un filet entre ses enfants (retrait 16) et l'écran lui passait en plus
  ses propres `_SettingsDivider` (retrait 72). Le défaut ne se voyait pas comme
  un bug mais comme un trait épais et flou. Vérifier à l'œil qu'il ne reste
  qu'un filet, aligné sur le texte, et que **Réglages n'a pas bougé d'un pixel**.
- [x] **Une bascule n'en écrase plus trois** (`settings_screen.dart`) —
  Réglages → couper **Ma localisation** seule → revenir → rouvrir Réglages :
  *Profil visible* et *Statut en ligne* doivent être restés dans leur état
  réel, pas remis à activé. C'est le scénario qui échouait.
- [x] **Le sous-titre du Profil suit** (`profile_screen.dart`) — couper
  *Profil visible* dans Réglages, revenir au Profil : « Confidentialité et
  sécurité » doit se mettre à jour **sans relancer l'app**.
- [x] **Les notifications se coupent vraiment** — réglages fins des
  notifications → couper l'interrupteur maître → vérifier en base que
  `public.users.notifications_enabled` est passé à `false`
  (`supabase db query --linked`). Avant, seul l'affichage local était coupé :
  le serveur continuait d'envoyer.
- [x] **« ZONE SENSIBLE » en couleur d'alerte** (`settings_screen.dart`) — le
  drapeau `isWarning` était passé mais ignoré, le libellé s'affichait à la
  couleur d'accent comme les trois autres sections. À vérifier en clair et en
  nocturne (le rouge doit rester lisible sur `#0F0D0A`).

---

## 12. Design, thème, langue et mise en page

### ⬜ L'en-tête d'un sondage effaçait son auteur dans une bulle — corrigé, à revoir (2026-09-15)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Bulle de sondage reçue** : le nom de l'auteur doit être **visible** en
  tête de la carte, et l'horodatage collé au bord droit, sans bande de
  débordement. Un sondage créé la veille donne la forme compacte (« 1 j »).
  ✅ SM A515F, 2026-09-15 02:52, APK debug `3bc84313...` du worktree `debordement-poll-card`, compte réel, groupe « Testeurs », sondage « Vert » (11 h). Carte mesurée à **317,7 dp** : le plafond de 320 dp de `poll_message_bubble.dart` est bien le contraignant.
  « Sim A » visible, « il y a 11 heures » collé au bord droit, aucune bande.
- [x] **À `font_scale` 1.3 et au-delà** : la bascule vers la forme compacte
  doit se déclencher aussi sur une carte large, puisque c'est la mesure qui
  décide et non la largeur.
  ✅ Même passe, quatre échelles : **1.0** et **1.3** gardent « il y a 11 heures » ; **1.6** et **2.0** basculent sur « 11 h ». Le nom reste visible et le libellé collé à droite aux quatre. C'est à 1.6 que le défaut de police de mesure a été pris.

---

### ⬜ Deux textes du fil que `font_scale` 1.3 abime — corrigés, à revoir (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Ligne d'auteur à `font_scale` 1.3** : `@nassirou · il y a 3 heures`
  doit s'afficher **en entier**, quitte à passer sur deux lignes (`maxLines`
  est passé de 1 à 2), et tenir sur une seule à l'échelle normale.
  ✅ SM A515F, 2026-09-14 21:18, APK debug construit par une session sœur
  depuis `d4245ea` (ancestralité et contenu vérifiés dans l'objet git avant la
  mesure) : à 1.3, `il y a environ 42 minutes` et `@nassirou · il y a 3 heures`
  s'affichent **en entier sur deux lignes** — c'était `31 minut…` et `3 he…`.
  À 1.0, les trois lignes de l'écran tiennent sur une seule. Reste à voir un
  pseudo très long, qu'aucun compte de test ne porte.

---

### ⬜ Une couleur par service dans les deux grilles (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **« Tous les services »** : cinq tuiles, cinq teintes distinctes — Fil
  orange, Annuaire teal, Ambassades bleu, Événements prune, Amis vert. Aucune
  paire voisine ne se ressemble.
  ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), sur les deux téléphones : Fil orange, Annuaire teal, Ambassades
  bleu, Événements prune, Amis vert — cinq teintes nettement distinctes.
- [x] **Grille de l'accueil** : le Fil, l'Annuaire et les Ambassades y portent
  la **même** couleur que dans « Tous les services » (c'est la régression la
  plus probable : deux écrans, une seule liste).
  ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : accueil → « Services » : Fil orange, Annuaire teal,
  Ambassades bleu, les mêmes que « Tous les services ». (Sur l'accueil les
  icônes sont posées sans pastille teintée ; dans « Tous les services », sur
  un aplat.)
- [x] **Thème sombre** : les cinq icônes restent lisibles sur leur aplat à
  15 % — en particulier le bleu des Ambassades, qui était le cas le pire.
  ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : les cinq icônes lisibles sur leur aplat ; le bleu des
  Ambassades se détache nettement.

---

### ⬜ Le sigle DN est le même partout (2026-09-13)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Écran de démarrage** : vert `#009600`, sigle en Playfair, halo —
      vérifié SM A515F le 2026-09-13. (`design_kit.dart` —
      `DesignBrandMark`, `splash_screen.dart`)
- [x] **Compte en thème Orange** : le sigle reste vert. Vérifié dans le pire
      cas — le compte du SM A515F **est** en thème Orange (boutons et onglets
      orange à l'écran), et c'est lui qui produisait le sigle orange.
- [x] **Thème sombre** : le vert et le blanc du sigle tiennent sur le fond
      sombre — la couleur est fixe, elle ne suit plus `onPrimaryColor`.
      ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : sur l'écran de démarrage, « DN » blanc sur le vert fixe,
      lisible sur le fond sombre.
- [x] **Échelle de police à 1,3** : le « DN » ne déborde pas de son carré
      (le corps est proportionnel au côté, pas à la taille système).
      ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) (1,3 **et** gras) : « DN » entier, centré dans sa pastille,
      aucune lettre coupée.

---

### ⬜ Teinte des notifications système en vert (2026-09-07)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Ressource compilée dans l'APK installé (2026-09-07).**
      `aapt2 dump resources` sur l'APK, dont le `md5sum` a été confronté à
      `base.apk` sur le SM A515F : `color/notification_accent` et
      `color/ic_launcher_background` valent tous deux `#ff009600`. Ça prouve
      la chaîne ressource → paquet installé, pas le rendu à l'écran.

---

### ⬜ Icône du lanceur repeinte en vert (2026-09-07)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Écran de lancement système, vu sur SM A515F (2026-09-07).** Icône
      verte `#009600`, sigle blanc net, aucun reste d'orange. C'est la preuve
      que le paquet installé porte bien la nouvelle icône ; le rendu dans le
      tiroir d'applications n'a pas été retrouvé (l'app n'était pas sur les
      pages parcourues) et reste donc à cocher ci-dessus.

---

### ⬜ Écran de démarrage repeint en vert (2026-09-07)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Splash au démarrage à froid, thème clair.** Tuer l'app, la relancer :
      pastille « DN » et cercle de progression verts, sigle blanc lisible sur
      le vert, ombre portée verte discrète.
      ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), SM A515F (Sim, clair, police 1,0) : rafale de captures à l'ouverture à froid — pastille
      « DN » verte, sigle blanc net, ombre verte discrète, cercle vert.
      ⚠️ Défaut de texte vu sur la même image : le sous-titre est
      « Connecter la diaspora nigerienne », **sans accent**, et écrit en dur
      (`splash_screen.dart:41`, hors ARB : il reste en français en anglais).
      Partout ailleurs l'app écrit « nigérienne ». Corrigé ensuite :
      clé ARB `splashTagline` (« Connecter la diaspora nigérienne » /
      « Connecting the Nigerien diaspora »), garde
      `test/features/auth/splash_sous_titre_test.dart`.
- [x] **Splash au démarrage à froid, thème sombre.** Même écran sur fond
      `surfaceVariantDark` (`#2D2820`) : vérifier que le vert `#009600` ne
      devient pas terne sur le fond foncé (aucune variante nocturne n'est
      prévue pour cette pastille, contrairement à `primaryGradientDark`).
      ✅ Passe du 2026-09-22 (~05:45–05:57), build Play 1.2.2+26 (f22aaff), Pixel 10 Pro XL (Salim, sombre, police 1,3 + texte en gras) : rafale à l'ouverture à froid — fond sombre, pastille
      verte franche, pas terne, cercle vert lisible.
- [x] **Sigle et arc du cercle verts, vus sur SM A515F** (thème Système/Orange,
      nuit, APK debug dont le `md5sum` a été confronté à `base.apk` sur
      l'appareil — la première installation avait posé un APK du dépôt
      principal, d'où un premier constat faussement orange).
- [x] **Filet du cercle, vu sur SM A515F (2026-09-07).** Il retombait sur
      `circularTrackColor` du thème, donc brun-orangé pour un compte en thème
      Orange ; épinglé à `secondary` à 20 %, l'anneau est maintenant vert
      sombre sur toute sa circonférence.

---

### ✅ Recolorisation orange/vert — vue sur appareil, partiellement (2026-08-25)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Thème Système/Orange, sombre, sur SM A515F (build debug réinstallé,
  `lastUpdateTime` confirmé postérieur au commit)** : splash `DN`, bouton
  « Ajouter mon pays », onglet actif « Messages », avatar « SL », icônes
  « Le fil »/« Annuaire » en `#FA7D00` — texte/icônes blancs bien lisibles
  dessus. Avatars de groupe et bulle de message envoyée en `#009600` — lisible
  aussi. Capture confirmée à l'œil, pas de risque de contraste constaté.

---

### ✅ Le thème choisi ne survivait jamais à un redémarrage — corrigé (2026-08-25)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Reconfirmé sur SM A515F, même cycle** : Réglages → Clair + Vert →
  `force-stop` + relance à froid → **accueil rendu en crème/vert**, pour la
  première fois (avant le correctif, ce cycle retombait toujours en
  sombre/orange, reproduit deux fois).
- [x] Pastille « DN » (`AuthBrandMark`, écran de connexion) vue en clair/vert
  sur l'appareil — capture envoyée à Salim. Les deux lettres tiennent dans
  le carré 46×46.

---

### Sigle « DN » corrigé + illustrations d'onboarding générées (2026-08-25)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Les 5 écrans d'onboarding — vérifié sur SM A515F le 2026-08-25 (thème
  sombre, accent orange, `font_scale` 1.0) : composition centrée dans le
  bloc rayé, aucun débordement, texte et pastilles lisibles sur les 5 écrans.
  Légendes sans « illustration — » reconfirmées après ce correctif, même
  passe device. Atteint sans toucher au compte : bascule temporaire et **non
  committée** de `initialLocation`/`redirect` dans `app_router.dart`
  (`kDebugMode` uniquement, revert + rebuild + réinstall juste après chaque
  capture — le dépôt et l'APK sur l'appareil sont repartis strictement sur
  le dernier commit poussé, `96cea66`).
  Encore ouvert : **thème clair** et **accent vert** (seule la combinaison
  sombre/orange du compte de test a pu être vue — `font_scale` 1.1 aussi,
  l'appareil était repassé à 1.0 depuis la dernière session).
- [x] Pastille « DN » de connexion/inscription (`AuthBrandMark`) : **vue sur
  SM A515F le 2026-09-09**, en thème clair et accent orange. Les deux lettres
  tiennent dans le carré, centrées, aucune coupe. L'occasion est venue d'une
  réinstallation en release (signature différente du debug → désinstallation
  obligatoire), qui a rendu l'appareil déconnecté : c'est bien la déconnexion
  que cette entrée disait rédhibitoire qui l'a débloquée, pas un contournement.
- [x] Écran « fête de la République » (onboarding 4/5) : les 3 pastilles
  orange/blanc/vert restent lisibles sur fond sombre, celle en blanc se
  détache bien grâce au cerclage `borderStrongColor`. Vu sur SM A515F.

---

### Recoloriage orange/vert de marque (2026-08-14)

Demande produit : `AppColors.primary` (orange) `#E07B39` → `#E05206`,
`AppColors.secondary` (vert) `#2D7D46` → `#0DB02B`, avec les variantes
claire/pastel/foncée dérivées en HSL (teinte + rapports de luminosité
préservés) dans `lib/core/constants/app_colors.dart`, plus 20 fichiers qui
recopiaient ces teintes en dur (bulles, avatars, badges, appels de groupe).
`AppColors.success`/`successLight`/`successDark` gardés inchangés
(coïncidaient en valeur avec l'ancien vert mais sont un token sémantique
distinct).

- [x] **Vérifié sur SM A515F le 2026-08-14** (rebuild + install de l'APK
  debug) : splash, accueil, fiche groupes — orange et vert nouveaux bien
  affichés. Confirmé par échantillonnage de pixels exact sur les captures
  (pas seulement à l'œil) : barre de progression `#9F3E0A`, icône filtre
  `#FA7E3B`, icône de groupe `#32E252`, bouton « Ouvrir » dans le nouveau
  vert vif — correspondance exacte aux valeurs dérivées, nettement
  distinctes des anciennes (vert forêt terne, orange terre cuite).

---

### Paysage — overflow quand le chrome dépasse la hauteur (2026-08-05)

Testé sur le SM A515F en forçant `user_rotation 1`. **L'app tourne bien** : elle
passe sur un rail de navigation latéral, et la conversation reste correcte.

**Vu et sain :**
- [x] Conversation en paysage, composeur vide : rien ne déborde, l'heure et
  « · Envoyé » restent sous la bulle.
- [x] Panneau émojis ouvert en paysage : pas de débordement, les pilules et la
  loupe tiennent sur la ligne. La liste des messages est réduite à zéro par
  l'`Expanded` — c'est le comportement attendu sur 392 dp de haut.

**Deux débordements, tous deux hors du périmètre des quatre lots :**

- [x] ⚠ **CORRIGÉ le 2026-08-13, vérifié sur appareil (0 px).**
  Conversation « Salim L. » en paysage : `BOTTOM OVERFLOWED BY 240 PIXELS`.
  Reproduit avec le bandeau « Restaurez vos clés de chiffrement »
  affiché **et** un brouillon de 6 lignes dans le composeur. La cause est
  `computeMessagePickerHeight` (`message_input.dart`) : elle réserve **176 dp
  de chrome en dur**, calibrés sur en-tête 58 + composeur 64 + bandeau épinglé
  44. Or le bandeau de restauration des clés (~90 dp) n'y est pas compté, et un
  composeur à 6 lignes fait ~150 dp au lieu de 64. Sur 392 dp de haut, le
  compte est dépassé de ~240.
  Le même écran **sans** ces deux conditions ne déborde pas.

  **Reconfirmé le 2026-08-13**, seuil plus bas qu'estimé : `BOTTOM OVERFLOWED
  BY 47 PIXELS` avec le même bandeau de restauration des clés mais un
  brouillon de **2 lignes seulement** (pas 6), pendant la frappe au clavier
  logiciel. L'overflow disparaît dès que le clavier se referme (texte
  entièrement visible, bouton d'envoi accessible) — le message part
  normalement et la bulle reçue se replie bien sur deux lignes. Donc rien à
  voir avec `message_bubble.dart` (agrandissement du texte des bulles à 17,
  commits `83ca2e4`/`a9b1fa5`) : l'overflow touche uniquement la barre de
  saisie, pas le rendu des bulles envoyées.

  **Corrigé partiellement le 2026-08-13** en activant enfin le garde-fou déjà
  écrit dans `message_input.dart` (`_buildColumn`/`panneau`, voir la section
  suivante) : `MessageInput` est désormais enveloppé dans un
  `ConstrainedBox(constraints: BoxConstraints(maxHeight: zoneCorps.maxHeight))`
  dans `conversation_screen.dart`, avec `zoneCorps` la contrainte déjà mesurée
  par le `LayoutBuilder` qui entoure le corps de la conversation (celui qui
  pilote aussi `placeRappelCles`). Sans ça `RenderFlex` donnait toujours
  `maxHeight: Infinity` à ce widget (enfant non-flexible de la `Column`), donc
  son propre `LayoutBuilder` interne voyait `bornee == false` en permanence et
  ne rétrécissait jamais ses panneaux. Volontairement **pas** de `Flexible`
  autour de `MessageInput` dans la `Column` externe (le piège documenté plus
  bas : ça se partagerait l'espace libre avec l'`Expanded` de la liste des
  messages et la raboterait même quand il y a largement la place). `flutter
  analyze` propre sur les deux fichiers.

  **Vérifié sur SM A515F, en vrai paysage clavier ouvert (pas seulement
  `flutter analyze`)** : le correctif réduit le débordement, il ne l'élimine
  pas.
  - Bandeau de restauration des clés affiché + brouillon vide (juste le
    placeholder « Votre message... ») : `BOTTOM OVERFLOWED BY 21 PIXELS`,
    contre 47 avant correctif avec un brouillon de 2 lignes — nette
    amélioration, mais pas zéro.
  - Fait rejouer ensuite avec un texte tapé dans le champ : l'overflow ne
    grandit plus avec la longueur du brouillon (c'est bien ce que corrige le
    `ConstrainedBox`), mais un cas minimal persiste : composeur vide, **sans
    aucune bannière visible** (juste l'en-tête), toujours en paysage clavier
    ouvert — `BOTTOM OVERFLOWED BY 12 PIXELS`.
  - Ce résidu n'est donc pas un débordement des *panneaux* de `MessageInput`
    (ce que le `ConstrainedBox` corrige) mais un **plancher irréductible** :
    sur cette géométrie (paysage + clavier logiciel), en-tête + hauteur
    minimale du composeur (une ligne + rangée de boutons + marge de sécurité
    bas d'écran) dépasse à elle seule la hauteur disponible de quelques
    pixels. Le `ConstrainedBox` ne peut rien y faire : il borne
    `MessageInput`, il ne le compresse pas en dessous de son contenu
    minimal.
  - **Plancher éliminé le 2026-08-13** en réduisant le padding vertical du
    composeur, spécifiquement en paysage (`MediaQuery.of(context).orientation
    == Orientation.landscape`), en deux temps :
    1. Marge extérieure de la barre (6→2 en haut, 8→2 en bas de la marge de
       sécurité) et padding interne de la pilule (6→3) : `21 PIXELS` → `5,1
       PIXELS` mesuré sur le même écran (bandeau restauration + composeur
       vide).
    2. `contentPadding` du `TextField` (12→9 haut/bas) et plancher
       `minHeight` de la ligne du champ (44→38) : `5,1 PIXELS` → **0**,
       revérifié sur appareil, clavier ouvert, bandeau épinglé + bandeau de
       restauration des clés tous deux affichés.
    Rien de touché en portrait (toutes les valeurs sont conditionnelles à
    `isLandscape`) — seule la géométrie paysage change.
  - Non revérifié : l'écran précis qui montrait `240 PIXELS` (bandeau +
    brouillon 6 lignes + panneau ouvert) — mais la cause de ce cas était la
    même famille (plancher du composeur + `ConstrainedBox` déjà posé), donc
    vraisemblablement également résolue ; à confirmer si le cas se
    représente.
- [x] ⚠ **Écran de recherche des messages en paysage, clavier levé :
  `OVERFLOWED BY 190`.** Cet écran n'a été touché par aucun des lots — c'est
  le même défaut structurel, ailleurs. **Corrigé le 2026-08-05, mais pas où
  on le croyait : le coupable n'est pas la colonne de l'écran de recherche.**
  Voir « Le « OVERFLOWED BY 190 » de la recherche venait du rail latéral ».

**Ce n'est donc pas une régression de la refonte** : c'est le motif « une
`Column` dont les enfants fixes dépassent la hauteur de l'écran », que le
paysage rend visible et que la réserve de chrome en dur ne peut pas suivre.
Un correctif honnête ne se limite pas au composeur — à trancher à part.

Pistes, par coût croissant :
1. Borner `maxLines` du champ en paysage (6 lignes sur 392 dp n'a pas de sens).
2. Compter le bandeau de restauration dans la réserve de chrome.
3. Remplacer la réserve en dur par une mesure réelle (`LayoutBuilder` autour du
   corps de la conversation), seule solution qui suive tous les bandeaux
   conditionnels.

#### Cause racine du 240 trouvée le 2026-08-05 : le garde-fou est inerte

La piste 3 a **déjà été écrite**, mais elle ne s'exécute jamais. `MessageInput`
s'enveloppe dans un `LayoutBuilder` et, *si* on lui donne une hauteur finie,
transforme ses panneaux en `Flexible` pour qu'ils se rétrécissent au lieu de
déborder (`message_input.dart`, `_buildColumn` / `panneau`). Un commentaire
affirmait « la conversation le fait ». **C'est faux.**

Dans `conversation_screen.dart` la structure est
`body > Container > Stack > Column[ …bandeaux…, Expanded(liste), MessageInput ]`.
`MessageInput` y est un enfant **non-flexible** de la `Column` — et `RenderFlex`
donne à ses enfants non-flexibles `maxHeight: Infinity`. Mesuré sur la
géométrie exacte de l'écran (392 dp, en-tête 58 + épinglé 44 + restauration 90
+ `Expanded`) :

```
CONTRAINTE RECUE PAR MessageInput : BoxConstraints(0.0<=w<=800.0, 0.0<=h<=Infinity)
maxHeight.isFinite = false
```

Donc `bornee == false`, `panneau()` renvoie l'enfant nu, et rien ne rétrécit.
Le débordement de 240 est inévitable dès que bandeaux + brouillon long +
panneau ouvert dépassent la hauteur.

**Attention au correctif évident, qui est un piège** : ajouter un
`Flexible` autour de `MessageInput` dans cette `Column` ne suffit pas — il se
partagerait l'espace libre avec l'`Expanded` de la liste des messages et
raboterait la liste (`RenderFlex` ne redistribue pas ce qu'un `Flexible` en
`loose` n'a pas consommé). Il faut mesurer la hauteur disponible du corps
(un `LayoutBuilder` autour de la `Column`) et passer une borne explicite au
composeur.

Non corrigé ici : `conversation_screen.dart` était en cours de modification
dans le worktree principal, et y toucher en parallèle aurait écrasé du travail
non committé. Le commentaire mensonger de `message_input.dart`, lui, a été
corrigé — c'est ce qui aurait fait perdre le plus de temps au prochain lecteur.

---

### Fiches d'écrans (Claude Design) — reprise écran par écran (2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **20b — « CET APPAREIL » : RÉSOLU, vérifié le 2026-08-04 à 18:22.** La
  liste affiche maintenant **3 appareils sur 5**, et le courant porte bien la
  pastille verte « CET APPAREIL » avec son empreinte et le bouton « Renommer ».
  Le bandeau d'avertissement a disparu.

  ⚠ **La cause n'était pas celle qu'on croyait.** Ce n'étaient pas les
  `adb install -r` : c'était la règle Storage `key_backups/` manquante, qui
  faisait sauter la génération des clés (voir « Passe pilotée du 2026-08-04 »). Sans génération,
  aucun enregistrement E2EE n'avait lieu, donc aucun appareil courant. La
  règle déployée ce matin a débloqué la chaîne, et l'entrée de cet appareil a
  été créée dans la foulée — d'où le passage de 2 à 3 appareils.
- [x] **Brouillons de publication multiples** (`preferences_service.dart`,
  `create_post_screen.dart`) — vérifié le 2026-08-04 sur SM A515F : rédiger un
  post puis « Annuler » écrit bien `flutter.post_drafts`, et la carte
  brouillon apparaît dans Mes publications après relance de l'app.
  ⚠ Le premier essai ne sauvegardait **rien** : `dispose()` appelait
  `ref.read(...)`, ce qui lève, et `main.dart` renvoyant `FlutterError.onError`
  vers Crashlytics, l'exception n'apparaissait **ni dans logcat ni à l'écran**.
  Corrigé en capturant le notifier à l'`initState` + autosave débounce 800 ms.
  Reste à vérifier à la main : 1) **deux** brouillons coexistent (le second
  n'écrase pas le premier) ; 2) « Reprendre » ouvre le bon texte ; 3) publier
  supprime le bon brouillon ; 4) la migration v1 → v2 sur une install qui
  possède un `post_draft` d'avant (⚠ `adb install -r` vide les données).
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

---

### Galerie design_v2 sur appareil (2026-08-03)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **L'accent est terracotta**, plus vert. `ThemeColorNotifier` retournait
  `AppThemeColor.green` par défaut, donc une installation neuve affichait
  toute la refonte dans la mauvaise couleur — sur les 40 écrans. Corrigé et
  constaté à l'écran (pastille « D », point du titre, bouton principal).
- [x] **Le thème sombre de l'écran de connexion (§15a) est lisible.** Aucun
  texte perdu, contrastes tenus. Le piège du commit `78b720e` n'a pas été
  réintroduit sur cet écran.
- [x] **La structure du §15a est conforme** à la maquette : titre serif à
  point d'accent, sous-titre, bouton Google, libellés au-dessus des champs,
  mention de chiffrement en pied.

---

### Refonte des maquettes d'authentification

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

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

---

### Thème sombre — jetons clairs codés en dur

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Écrans d'authentification en thème sombre** (`login_screen.dart`,
  `register_screen.dart`, `forgot_password_screen.dart`,
  `maintenance_screen.dart`, `splash_screen.dart`, `auth_button.dart`,
  2026-08-03) : vérifié sur le SM A515F en mode nuit — voir le bloc de session
  en tête de fichier. Seul l'écran de connexion a été capturé ; les quatre
  autres partagent le même correctif mais n'ont pas été ouverts.

---

### Accent orange du thème clair — `#E07B39` → `#B85E24` (2026-08-03)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Thèmes sombres non touchés** : vérifié sur l'appareil — l'accent
  nocturne reste `#F4A574` (pictogrammes, libellés de section, onglet actif).
  Aucun changement en mode nuit, comme attendu.

---

## 13. Backend, sécurité et observabilité

### ⬜ Balayage des invariants de données — 2 anomalies en production (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **🔴 Les 2 amitiés étaient des RESTES, et sont supprimées.** Firestore
  tranchait : les deux comptes d'en face ont **0 ami**, les entrées datent de
  février et avril, et les 8 documents Firestore correspondaient exactement aux
  8 lignes Postgres — le miroir était fidèle, le défaut était dans la source.
  Or seuls deux chemins écrivent cette sous-collection : le lot d'acceptation,
  **atomique depuis le premier commit** (2025-12-31), donc incapable de
  n'écrire qu'un côté ; et la suppression de compte, qui efface le miroir
  détenu par les autres — nettoyage **ajouté après coup**, dont le commentaire
  décrit précisément ce résidu. Compléter aurait fabriqué un lien que personne
  n'a exprimé. Les deux documents Firestore supprimés le 2026-09-14 (accord de
  Salim) : 6 documents restants, soit 3 amitiés réciproques.
- [x] **`mirrorFriendToSupabase` vu tourner sur une vraie amitié** — ce qui
  n'avait jamais été observé. Les 2 lignes Postgres sont parties seules après
  la suppression Firestore : 8 → 6, et l'invariant est à 0.
- [x] **🔴 Événement à audience vide — cause trouvée, corrigée en base.** Le
  formulaire valide bien (`_audience.erreur`, ligne 262) : la cause était dans
  la RPC. `set_event_audience` **filtre en silence** (`u.id = ANY(p_user_ids)
  AND u.id <> v_uid`), et quand il ne restait personne elle écrivait quand même
  `events.visibility` et rendait `VOID` — un **succès qui n'a rien fait**.
  L'organisateur est un compte de **12 minutes** (créé 04:49, événement 05:01),
  sans aucun ami ni discussion, donc avec un sélecteur vide.
  `20260914203000_audience_evenement_jamais_vide.sql` fait lever la RPC quand
  une demande « groups »/« people » aboutit à une audience vide — la fonction
  étant une seule transaction, la levée annule aussi ses `DELETE`, donc une
  audience existante n'est jamais perdue par une tentative ratée. Déployée et
  relue : garde présent, `anon` absent de l'ACL.
- [x] **Le message d'échec disait faux** : « il reste visible par sa discussion
  uniquement » alors qu'un événement créé **hors** discussion n'est visible de
  personne — exactement le cas trouvé. Corrigé (`_messageAudienceRatee`).
- [x] **🔴 L'audience était écrite une fois et plus jamais relue — corrigé.**
  En cherchant qui pouvait réparer l'événement fautif, la réponse était :
  **personne**. `EventAudiencePicker` ne vivait que dans l'écran de création,
  aucune ligne de l'app ne lisait `event_audience`, et `EventEntity` ne porte
  toujours pas `visibility`. Une limite du produit, indépendante du bug : on ne
  pouvait pas ajouter quelqu'un à un événement qu'on avait créé.
  Posé : `getEventAudience` de la base au dépôt, `eventAudienceProvider`
  (provider simple, sans codegen — `build_runner` réécrit ~120 fichiers pour
  rien ici), le sélecteur dans l'écran de modification avec pré-remplissage et
  la même garde d'audience vide qu'à la création, et un bandeau rouge sur la
  fiche vue par l'organisateur quand son événement n'est visible de personne.
  Ni l'entité ni le modèle ne bougent.

---

### ⚠️ Ce que dit vraiment la console Crashlytics (2026-09-10)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **`MissingPluginException` sur le canal `com.diasponiger.diaspo_niger/gsm_state`**
  — 3 occurrences. Un canal de plateforme écouté côté Dart sans implémentation
  native.
- [x] **`ForegroundServiceStartNotAllowedException` — NOUVEAU en 1.2.1**,
  `flutter_background_service` ne peut plus démarrer. 2 occurrences.

---

### ⬜ Les quatre défauts de la console, triés par appareil (2026-09-10)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Rapport de pré-lancement de la build 15 lu** (2026-09-11) : 1
  appareil virtuel Android 16, 0 problème de stabilité. Il n'est pas
  l'origine des plantages.
- [x] **`google_fonts` — le seul qui touche de vrais utilisateurs.**
  ✅ **Appliqué le 2026-09-11** (`f6e85f4`) : 24 variantes embarquées, voir
  la section « Polices embarquées ». `allowRuntimeFetching` est
  volontairement resté à `true`, en filet — c'est un test qui garantit
  qu'aucune variante ne manque. Le OnePlus 8 Pro qui porte 75 % de
  ces erreurs n'est pas identifié — voir plus bas. Analyse d'origine, conservée : Aucune
  police n'est embarquée (`pubspec.yaml` n'a pas de section `fonts:`, aucun
  `.ttf` dans `assets/`) et `GoogleFonts.config.allowRuntimeFetching` n'est pas
  réglé : **chaque appareil télécharge les polices depuis `fonts.gstatic.com` au
  démarrage**. Sur réseau instable, l'appel échoue. Le rendu retombe sur la
  police système — donc pas d'écran cassé, mais la typo de marque saute, et
  l'erreur remontait.
  Le correctif robuste est d'**embarquer les polices dans les assets** et de
  couper `allowRuntimeFetching`. Non appliqué : il faut choisir les fichiers
  `.ttf` et accepter les mégaoctets ajoutés à l'APK — c'est une décision, pas
  une correction évidente.

---

### ⬜ Journalisation : deux fuites en release et la garde du LoggerService (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Partage de position** — vérifié sur SM A515F le 2026-09-09, APK release
  `6dc726f453c70d23b0f94b100ac7e287` (md5 local = md5 `pm path`, et
  `flags=[ HAS_CODE ... ]` sans `DEBUGGABLE`). Conversation 1:1 « Salim L. »,
  pièce jointe → Position → « Envoyer cette position ». La bulle carte
  s'affiche avec « 3010 Boul Lévesque E, Laval, Canada » et passe à
  « À l'instant · Reçu ». Aucune régression fonctionnelle.
- [x] **Logcat d'une release** — vérifié le 2026-09-09, logcat vidé juste avant
  l'envoi. Les deux lignes sortent **au nouveau format** :

      📍 sendLocation: Adding optimistic message tempId=temp_location_1788994896202
      ✅ sendLocation: Success - real message id=9d35cb49-f82c-4ea0-9cc1-640c9a312a28

  Ni `lat=` ni `lng=`. Sur les 12 498 lignes capturées, aucune coordonnée dans
  une ligne de tag `flutter`. (Piège de mesure : un `grep '45\.[0-9]{3}'` naïf
  remonte les **secondes des horodatages** du pilote NFC — filtrer sur
  ` flutter ` avant de conclure.)

  Ce test tranche **deux** questions d'un coup. Que les lignes sortent du tout
  prouve que `debugPrint` écrit bien en release ; qu'elles sortent au nouveau
  format prouve que l'APK n'est pas périmé. L'ancien format aurait signifié un
  build stale, pas un correctif raté.

---

### ⬜ Les ~920 `debugPrint` restants neutralisés en release (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Logcat muet en release** — vérifié sur SM A515F le 2026-09-09, APK
  release `455a4c74b0bfc7a609a68ec6a3fb183d` (md5 local = md5 `pm path`, pas de
  flag `DEBUGGABLE`). Même démarrage à froid, même protocole que la mesure
  d'avant :

      AVANT (APK 6dc726f4) : 14 lignes de tag flutter
      APRÈS (APK 455a4c74) :  2 lignes de tag flutter

  Les 2 restantes sont
  `[IMPORTANT:flutter/shell/platform/android/android_context_gl_impeller.cc]` —
  du moteur natif, qui ne passe pas par `debugPrint`. Tout ce qui venait de
  Dart a disparu : `Encryption service initialized`, `SupabaseAuthBridge:
  session sync OK`, `SecureKeyStorage: Initialized`, `DerivedKeyStore`,
  `NativeCallService: Initialized`, `GoogleMapsService initialized`.
- [x] **Pas de casse au démarrage** — vérifié le 2026-09-09. Aucun
  `FATAL EXCEPTION` dans les 3 917 lignes capturées, l'app rend l'accueil
  session restaurée (« Bonjour, Sim », Montréal, badge notifications à 2), et
  l'onglet Messages charge la liste — dont l'aperçu déchiffré du message de
  position envoyé juste avant (« Vous: 📍 Position »). Supabase, realtime et
  déchiffrement E2EE fonctionnent donc toujours.
- [x] **Logcat muet pendant un USAGE réel** — vérifié le 2026-09-09, même APK
  `455a4c74…`. Le test au démarrage à froid ne couvrait que `main()` ; celui-ci
  couvre les 734 `debugPrint` de `core/services`. Parcours : ouvrir la
  conversation 1:1, saisir et envoyer un message texte, revenir à la liste,
  onglet Carte, retour Accueil. Puis un second passage isolé sur la Carte.

      usage complet : 7 740 lignes logcat → 0 ligne de tag flutter
      carte seule   :   695 lignes logcat → 0 ligne de tag flutter

  **Le contrôle qui rend ce zéro significatif** : « aucun log » ne prouve rien
  si l'app n'a rien fait. Ici le message « test-logs » s'affiche en
  « À l'instant · **Reçu** » — donc chiffrement E2EE, écriture Supabase et
  accusé de retour ont bien eu lieu pendant la capture. Toujours apporter cette
  preuve d'activité avec un résultat négatif.

---

### ⬜ Second verrou : `print` brut et paquets tiers (2026-09-09)

La neutralisation de l'entrée précédente ne visait que `debugPrint`. Elle
laissait passer deux choses :

- un **`print()` brut** ajouté par mégarde — `avoid_print` est bien actif
  (hérité de `flutter_lints`), mais au niveau *info* : ça n'échoue nulle part ;
- les **paquets tiers**, dont le code ne nous appartient pas et qui peuvent
  imprimer ce qu'ils veulent.

[logs_release.dart](lib/core/utils/logs_release.dart) — `main()` lance
désormais le démarrage dans une zone qui avale `print` :

```dart
void main() => demarrerSansLogsEnRelease(_demarrer);
```

`debugPrint` passant par `print`, la zone couvrirait déjà à elle seule la
réassignation de `debugPrint`. Les deux sont gardés : la réassignation évite le
travail (découpage, throttling), la zone garantit le résultat.

Piège évité au passage : `ensureInitialized()` et `runApp` doivent vivre dans
la **même** zone, sinon Flutter refuse de démarrer. Les deux sont à l'intérieur
de `_demarrer`, donc de la même zone dans les deux branches.

Couvert par [logs_release_test.dart](test/core/utils/logs_release_test.dart),
4 tests : `print` avalé, `debugPrint` avalé, **un témoin** qui vérifie que le
mécanisme de capture voit bien une sortie non protégée (sans lui, les deux
premiers passeraient avec une capture cassée), et un balayage de source qui
échoue si un `print(` brut réapparaît dans `lib/`.

- [x] **Logcat toujours muet après ce changement** — vérifié sur SM A515F le
  2026-09-09, APK release `e0924e531e7e0b0fcadffef3515121a3` (md5 local = md5
  `pm path`, pas de flag `DEBUGGABLE`).

      démarrage à froid : 6 291 lignes logcat → 2 lignes flutter (moteur natif)
      envoi d'un message : 1 417 lignes logcat → 0 ligne flutter

  L'envoi est la mesure qui compte, et elle est **contrôlée** : le message
  « zone-verif » s'affiche « À l'instant · Envoyé » dans la conversation, et
  18 lignes de la fenêtre mentionnent l'app/Supabase. L'app a donc chiffré,
  écrit et livré pendant que logcat ne disait rien.
- [x] **Le démarrage n'a pas régressé** — vérifié le 2026-09-09. Aucune erreur
  de zone, aucun `FATAL EXCEPTION` imputable à l'app, accueil rendu session
  restaurée (« Bonjour, Sim », badge notifications, « La carte · Il y a 10 s »
  — les services de fond tournent), liste de conversations chargée et
  déchiffrée.

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

⚠️ **La conversation « Salim L. » est utilisée par un autre banc de test** —
des messages « Hi » et « ECHO-DM-1947 » y sont arrivés à 19:46 et 19:47, hors
de toute action de cette session. Ne pas prendre son contenu pour un état
stable, et ne pas conclure d'un message qu'on n'a pas envoyé soi-même.

  Précision, apportée par la session qui les a produits : `ECHO-DM-1947` est
  un envoi de **test** depuis le SM A515F (vérification de l'écho temps réel,
  cf. la section sur les marqueurs de bulle) ; « Hi » venait du Pixel. Les
  deux appareils étaient pilotés en parallèle ce soir-là, l'un par un agent,
  l'autre à la main — d'où l'avertissement ci-dessus, qui reste valable.

---

### ⬜ Plugin Gradle Crashlytics : les piles n'étaient pas déchiffrables (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **L'app démarre toujours** — SM A515F, APK release
  `ea2db3cdb3c0153e9bc6107a16ce7f61` (md5 local = md5 `pm path`). Firebase et
  Crashlytics s'initialisent, aucun `FATAL EXCEPTION`, et la zone muette tient
  (2 lignes flutter, moteur natif). La montée de `google-services` n'a rien
  cassé au runtime.

---

### `MaÃ¯daoua` : l'échange de jeton Firebase corrompait le nom en base (2026-08-23)

**Cause enfin trouvée, et prouvée de bout en bout.**
`supabase/functions/auth-firebase-exchange/index.ts` décodait le JWT Firebase
avec `JSON.parse(atob(...))`. `atob` rend une chaîne **binaire** — un caractère
JS par octet, c'est-à-dire les octets UTF-8 relus comme du Latin-1. Le claim
`name` « Ibrahim Yacouba Maïdaoua » (`… 4d 61 c3 af 64 …`) devenait donc
« Ibrahim Yacouba MaÃ¯daoua », et la ligne `display_name: payload.name` de la
même fonction l'écrivait tel quel dans `users`.

Mesures prises pendant la session :

| Couche | État |
|---|---|
| Firebase Auth (source) | `4d61 c3af` — **propre** |
| Edge Function `auth-firebase-exchange` | produit `MaÃ¯daoua` |
| `users.display_name` en prod | `4d61 c383 c2af` — **corrompu** |
| Application (capture d'écran) | affiche « Ibrahim Yacouba MaÃ¯daoua » |

**Pourquoi c'était intermittent.** Deux écrivains se disputent la ligne :
`_upsertUserToSupabase` (Dart) écrit le nom CORRECT depuis le SDK Firebase,
l'Edge Function écrit le nom corrompu. Le dernier qui passe gagne. La même
ligne était propre en début de session et corrompue quelques heures plus tard,
sans que personne ne touche au profil — seulement une connexion.

Corrigé par `decodeJwtPart()`, qui repasse par `Uint8Array` + `TextDecoder`.
L'`atob` de la **signature** est laissé tel quel : là, l'interprétation octet
par octet est justement ce qu'on veut.

- [x] **DÉPLOYÉE** le 2026-08-23.
- [x] **DONNÉE RÉPARÉE** le 2026-08-23, après le déploiement. Requête utilisée :
      `UPDATE users SET display_name = convert_from(convert_to(display_name,'LATIN1'),'UTF8')
       WHERE id = 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2';`
      Vérifié ensuite dans l'application : « Ibrahim Yacouba Maïdaoua »
      s'affiche correctement.

---

### Bruit dans logcat — deux traces à ne pas re-diagnostiquer (2026-08-05)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Déployé le 2026-08-05** — `cleanupUserData(us-central1)`, mise à jour
  réussie. Déployé **seul** : `firebase deploy --only functions` s'arrête de
  lui-même parce que `sendMessagePush(europe-west1)` et
  `sendChatNotification(us-central1)` existent en production **sans source
  dans le dépôt**, et le CLI refuse de les supprimer en non-interactif. Les
  deux sont toujours en ligne après le déploiement ciblé.
- [x] **Vérifié de bout en bout le 2026-08-05**, avec deux comptes jetables
  créés puis supprimés par l'API Identity Toolkit (aucun compte réel touché) :
  A et B amis, suppression de A → l'entrée miroir `users/B/friends/A`
  **disparaît**, le profil de A et sa sous-collection aussi.
- [x] **🔴 Et la vérification a trouvé pire : le nettoyage ne tournait pas du
  tout.** Premier essai, rien n'était supprimé — pas même le profil du compte
  effacé. Les journaux :
  `Cannot use "undefined" as a Firestore value (found in field "userStats.createdAt")`.
  Le journal d'audit est écrit **en tête** de `cleanupUserData`, et son
  ternaire ne testait que l'existence du **document**, pas celle du **champ** :
  un profil sans `createdAt` renvoyait `undefined`, que Firestore refuse dans
  un `.add()`. L'exception partait avant la moindre suppression.
  **Supprimer un compte ne supprimait donc rien**, en silence — ni profil, ni
  sous-collections, ni notifications, ni conversations.
  **Corrigé** (`?? null` sur les deux champs **et** journal d'audit rendu non
  bloquant : il est utile, le nettoyage est obligatoire), déployé, puis rejoué
  avec un profil volontairement dépourvu de `createdAt` — le cas qui plantait.
- [x] **La même famille cherchée ailleurs le 2026-08-06** (suite de `8d769d3`).
  Deux motifs distincts : *(a)* un ternaire `.exists ? …data().champ : …` qui
  laisse passer `undefined` jusqu'à une écriture Firestore ; *(b)* une écriture
  accessoire placée avant du travail obligatoire, sans filet. Résultat :
  - `.exists ?` — **une seule** occurrence restante sans repli, corrigée :
    `onAudioRoomInviteCreated` (`functions/index.js`) posait
    `roomTitle = roomDoc.data().title` puis l'écrivait dans `data.roomTitle`.
    Un salon sans `title` faisait donc échouer le `.add()` ; le `catch` de la
    fonction avalait l'erreur et **l'invitation n'était jamais notifiée**.
    Les autres (`senderName`, `buyerName`, `cancellerName`, `likerName`,
    `displayName`…) ont déjà un `|| "…"` — rien à faire.
  - Assignations nues `x = doc.data().champ` : 7 occurrences, toutes vérifiées.
    Aucune n'atteint une écriture Firestore sauf dans `onPostLiked` /
    `onPostCommented`, **explicitement marquées MORTES** dans le fichier.
- [x] 🔴 **Le même défaut dans trois balayages périodiques — corrigé et
  DÉPLOYÉ le 2026-08-06 à 07:01 UTC.** En cherchant le motif « N opérations
  indépendantes sous un `try` unique » dans le reste de `functions/index.js` :
  `cleanupExpiredMessages`, `cleanupStaleParticipants` et
  `cleanupStaleGroupCalls` bouclaient sur des éléments **indépendants** sans
  filet par élément. Le premier qui lève arrêtait le balayage entier.
  Deux voisines, `cleanupExpiredMediaFiles` et `cleanupStaleCalls`, avaient
  **déjà** ce filet — le bon motif existait dans le fichier, il manquait juste
  à trois endroits. Les trois s'y alignent maintenant.
  - **Le plus grave est `cleanupExpiredMessages`** (toutes les heures) : c'est
    la seule chose qui fait disparaître les messages éphémères. Une
    conversation fautive et toutes les suivantes gardaient leurs messages
    expirés — et comme la fonction **relance l'erreur**, pub/sub la rejouait
    en retombant sur la même conversation, indéfiniment. La promesse « ce
    message disparaît » était rompue en silence et durablement. Un
    `console.error` récapitulatif compte désormais les conversations non
    balayées.
  - `cleanupStaleParticipants` : un salon fautif laissait tous les autres avec
    leurs participants fantômes, « en direct » indéfiniment.
  - `cleanupStaleGroupCalls` : idem, appels de groupe orphelins restés actifs.
  - Vérifié sans suite : `onReviewDeleted` (opération unique, rien à isoler).
  **Déployé** (`onAudioRoomInviteCreated` inclus) : les quatre en
  « Successful update operation », essai à blanc préalable sans orpheline.
  `cleanupUserData` **volontairement laissée de côté** — chantier de Jules
  (migration Firestore → Supabase, `2af0920`/`e3576a3`/`7337127`), et le
  nettoyage Firestore vise de toute façon la mauvaise base maintenant que la
  donnée est dans Supabase. Le correctif est commité (`d07d533`), pas déployé.
- [x] **Journaux relus après déploiement — et ils nuancent le diagnostic.**
  `cleanupExpiredMessages` tourne toutes les heures **à :24** et se terminait
  déjà `ok` à chaque exécution (02:24 → 06:24 vérifiées), « Deleted 0 messages
  and 0 files » à chaque fois. **Le scénario corrigé ne se produisait donc pas
  en production** : le correctif est préventif, il n'a réparé aucune panne en
  cours. À redire honnêtement si quelqu'un relit le commit.
- [x] **WARNING d'index disparu, vérifié dans les journaux.** Les exécutions de
  04:24, 05:24 et 06:24 portent toutes la ligne `FIREBASE WARNING: Using an
  unspecified index` entre « Starting » et « Cleanup complete ». Celle de
  **08:02, après déploiement, ne l'a plus** : « Starting » → « Cleanup
  complete », rien entre les deux. L'index est bien pris en compte.
  ⚠️ **Ne pas conclure à un gain de vitesse** : cette exécution a pris 3633 ms
  contre 1446 à 2112 ms avant. C'est un démarrage à froid (conteneur reconstruit
  au déploiement de 07:01 puis redescendu à zéro), et avec une seule
  conversation peuplée et 0 message à supprimer, la durée ne mesure de toute
  façon pas la requête. Le gain est structurel, pas encore observable.
  À noter aussi : l'horaire du balayage est passé de **:24 à :02** — redéployer
  une fonction planifiée réinitialise son job Cloud Scheduler. Aucune exécution
  n'a été perdue.
- [x] **Chemin 1 retenu et exécuté le 2026-08-06** (décision de Salim) :
  `firebase deploy --only database`, « rules syntax is valid » puis « released
  successfully ». Comparaison refaite juste après — **les règles en ligne sont
  désormais identiques au fichier du dépôt**, la dérive est soldée. Vérifiés
  un par un : l'index à trois entrées, `calls/.read` et `group_calls/.read`
  restreints, `admins` et `superAdmins` présents.
- [x] ⚠️ **CORRECTION DU 2026-08-06 — le diagnostic ci-dessous est FAUX.**
  Il est conservé tel quel parce que l'erreur est instructive, mais **ne pas
  s'y fier**. J'avais conclu que `callerId`/`calleeId` n'existaient nulle part
  dans RTDB à partir d'un `grep` **tronqué à 40 résultats** où
  `call_remote_datasource.dart` n'apparaissait pas. Or `createCall` **écrit
  bien ces deux champs dans le nœud RTDB**, avant toute signalisation, depuis
  `135ae92` (2026-08-03) — le commit qui a introduit les règles strictes les a
  introduits **ensemble**, elles étaient conçues pour aller de pair.
  **Mesuré en émulateur, sur la séquence réelle :**
  | | règles strictes | règles en ligne (permissives) |
  |---|---|---|
  | parcours nominal d'un appel (9 étapes) | **intact** | intact |
  | étanchéité | **fermée** | ouverte |
  | client d'un APK < 2026-08-03 | **cassé** | fonctionne |
  Donc les règles strictes ne cassent **pas** les appels : elles cassent
  uniquement les clients qui n'écrivent pas ces champs, c'est-à-dire les APK
  antérieurs au 2026-08-03. Le retour arrière était probablement inutile.
- [x] 🔴 **Et en voulant les redéployer, le banc a trouvé DEUX défauts de plus
  — dans les appels de GROUPE cette fois** (2026-08-06). Les règles strictes de
  `135ae92` n'avaient manifestement jamais été confrontées à l'app pour cette
  partie. Les deux sont corrigés :
  1. **La signalisation de groupe était entièrement refusée.** Le `.validate`
     posé sur `signaling/$fromId/$toId` exigeait un enfant `type`
     **directement** sous `$toId`, alors que l'app écrit
     `$toId/offer = {type, sdp}` (`group_call_service.dart`). Prouvé par sonde :
     écrire sur `$toId/offer` → 401, écrire sur `$toId` avec `type` → 200.
     **Correctif** : le `.validate` descend sur les enfants réels (`offer`,
     `answer`), avec `['type', 'sdp']` comme pour le 1:1.
  2. **La détection des arrivées serait morte.** `_listenForParticipants` était
     appelé **avant** `_registerParticipant` (lignes 145/157 et 234/246) : le
     client se mettait à l'écoute de `participants` avant d'en être un, ce que
     les règles strictes refusent — à raison. **Correctif** : inscription
     d'abord. Rien n'est perdu, `onChildAdded` émet aussi pour les enfants déjà
     présents. `flutter analyze` sur le fichier : aucun problème.
  Après correctifs, le banc passe intégralement contre les règles strictes :
  parcours nominal 1:1 **et** groupe intacts, étanchéité fermée des deux côtés.
- [x] **Correctif déployé le 2026-08-06** — le `.validate` descend sur les
  enfants réels (`offer`, `answer`, en `['type', 'sdp']`), les candidats ICE
  n'ont plus de contrainte de forme au mauvais niveau.
  **Aucune précondition sur le parc installé** : ce correctif ne fait que lever
  une validation qui refusait des écritures légitimes. C'est pourquoi il a pu
  partir tout de suite, contrairement au durcissement.
  Diff par rapport à la production exacte, vérifié champ par champ : **3
  changements, pas un de plus** — le `.validate` déplacé, la garde `auth` sur
  `e2ee_key`, et l'index déjà en place. En ligne == dépôt après coup.
- [x] ✅ **Règles strictes DÉPLOYÉES le 2026-08-06**, dans l'ordre imposé :
  1. **App rebâtie et réinstallée** sur le SM_A515F (`R58N91XBA7B`).
     ⚠️ **En debug, pas en release** : l'app présente était `DEBUGGABLE`, donc
     signée avec la clé de debug. Une APK release a une autre signature et ne
     s'installe pas par-dessus — il aurait fallu désinstaller, donc perdre la
     session, les brouillons et **les clés d'identité E2EE locales**. Refusé.
     L'APK release existe si besoin (`build/app/outputs/flutter-apk/`, 166,7 Mo)
     mais exige une désinstallation préalable.
     Preuve de l'installation : `lastUpdateTime` passé de 06:49:48 à 06:56:27.
  2. Banc rejoué contre la cible : « Parcours nominal : INTACT », étanchéité
     fermée sur le 1:1 **et** le groupe, clé E2EE hors de portée d'un anonyme
     comme d'un tiers.
  3. `firebase deploy --only database`, puis relecture des règles en ligne :
     **en ligne == dépôt == `database.rules.strict-cible.json`**.
- [x] 🔴🔴 ~~**ANNULÉ LE JOUR MÊME : ce déploiement cassait tous les appels.**~~
  Le test de non-régression a finalement été fait — pas avec deux téléphones,
  mais **en émulateur RTDB**, ce qui suffit largement pour des règles.
  Verdict : sur la forme réelle du nœud, 5 vérifications sur 6 échouaient.
  **Cause racine, et elle est nette :** les règles durcies testaient
  `data.child('callerId').val() === auth.uid` **sur le nœud RTDB**, alors que
  `callerId`/`calleeId` n'existent **que dans Firestore**. Vérifié dans le
  code : `webrtc_service.dart` et `call_remote_datasource.dart` n'écrivent
  jamais ces champs dans RTDB — le nœud `calls/<id>` ne reçoit que des enfants
  de signalisation (`offer`, `answer`, `callerCandidates`, `calleeCandidates`,
  `videoUpgrade`, `renegotiate_*`, `ice_restart_*`, `heartbeat`, `e2ee_key`).
  Le prédicat était donc **toujours faux** :
  - `.read` → refusé pour tout le monde, l'appelé ne pouvait plus lire l'offre ;
  - `.write` → seule la toute première écriture passait (`!data.exists()`),
    tout le reste refusé.
  Autrement dit : **plus rien ne sonnait**, sans une seule erreur nulle part.
  Exactement le mode d'échec silencieux annoncé.
  **Retour arrière déployé et vérifié** : les règles en ligne sont revenues à
  `auth != null` sur `calls` et `group_calls`, l'index RTDB est conservé.
  Comparaison refaite — en ligne == dépôt == sauvegarde + index.
- [x] **Test pérennisé** : `tools/rules_tests/signalisation_appels.mjs` rejoue
  le parcours réel d'un appel (offre, candidats ICE des deux côtés, réponse,
  passage vidéo) contre l'émulateur. Bloc `emulators` ajouté à `firebase.json`
  (port 9102, le 9000 étant pris sur cette machine). **Toute modification des
  règles `calls` doit le faire passer avant d'être déployée.**
  Deux pièges déjà payés, notés dans l'en-tête du fichier : `?auth=owner` ne
  donne pas les droits admin sur l'émulateur (il faut l'en-tête
  `Authorization: Bearer owner`, sinon la mise en place échoue en silence et le
  banc mesure un arbre vide — huit faux échecs avant de s'en apercevoir) ; et
  un candidat ICE partiel est refusé par le `.validate`, pas par le droit
  d'accès — ne pas confondre les deux en lisant un 401.
- [x] 🔴 **L'étanchéité de la signalisation est FERMÉE** — mesurée le
      2026-09-14 (voir « Appels WebRTC », même date : banc des règles passé,
      et règles de production identiques au fichier du dépôt, 88 contre 88,
      zéro écart). Le constat d'ouverture ci-dessous datait des règles
      permissives d'août ; il ne vaut plus. Texte d'origine conservé : Tout compte
  connecté peut lire et écrire la signalisation de n'importe quel appel dont il
  connaît l'identifiant. Le test le constate explicitement (deux lignes
  attendues « autorisé »), et **ces deux lignes échoueront le jour où ce sera
  fermé — c'est le signal voulu**.
  **Pour fermer sans casser** : il faut D'ABORD que l'app écrive `callerId` et
  `calleeId` dans le nœud RTDB au moment de créer l'appel. Tant que ce n'est
  pas fait, tout prédicat qui s'appuie dessus est toujours faux. L'ordre est :
  1) écrire les deux champs côté app, 2) déployer l'app, 3) attendre que le
  parc installé ait migré, 4) seulement ensuite durcir les règles.
- [x] 🔴 **Deux fonctions tournaient en production sans source dans le dépôt —
  sources retrouvées et réintégrées** (`a7db115`).
  `sendMessagePush(europe-west1)` était dans `stash@{3}` (2026-07-20), jamais
  commitée nulle part ; `sendChatNotification(us-central1)` dans `1bb0cca^`,
  retirée du dépôt sans être supprimée côté Firebase — et désactivée
  (`return null` en tête) depuis avant son retrait.
  `firebase deploy --only functions --dry-run` ne signale plus d'orpheline :
  un déploiement global redevient possible.
- [x] **Corrigé le 2026-08-05.** L'index `status ASC + startDate DESC` a été
  créé, il est `READY`, et plus aucun `FAILED_PRECONDITION` au démarrage.
- [x] **Vérifié avec une vraie donnée le 2026-08-05** : un événement
  `status: "completed"` daté de trois jours plus tôt a été créé, puis la
  requête exacte qui échouait — `events where status == completed order by
  startDate desc` — a été rejouée côté serveur. Elle renvoie **1 résultat** au
  lieu du `FAILED_PRECONDITION`. Événement supprimé après coup.

---

### Fuseau horaire — heures affichées en UTC (2026-08-04)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Discussion — le cas décisif.** Dernier message de la conversation
      « Salim L. » : base = `27/07 22:15:54` Toronto, soit **`28/07 02:15` UTC**.
      L'app affiche **22:15** sous le séparateur **« 27 juil. 2026 »**. Sans le
      correctif : `02:15` sous « 28 juil. » — mauvaise heure ET mauvais jour.
      C'est exactement le cas « message après 20:00 » qui basculait au lendemain.
- [x] Discussion — message précédent : base `26/07 12:06` Toronto (`16:06` UTC),
      app « 26 juil. 2026 » · **12:06**.
- [x] Liste des conversations : « 27 juil. » et non « 28 juil. ».
- [x] Mes publications : base `04/08 06:01:04` UTC = `02:01:04` Toronto, app
      **« Aujourd'hui · 02:01 »**. (Écran déjà corrigé avant : vaut comme
      non-régression, pas comme preuve du correctif.)
- [x] **Aller-retour serveur.** Publication « Test fuseau horaire - a ignorer »
      créée à `04:36:36` heure appareil ; stockée `08:36:36` **UTC** en base
      (= `04:36:36` Toronto). Après `am force-stop` et démarrage à froid, l'app
      relit depuis le serveur et affiche **« Aujourd'hui · 04:36 »**. Avec le
      bug : 08:36. La publication de test reste en ligne volontairement
      (décision de Salim), comme la précédente sur ce compte.
- [x] **Cache hors-ligne — le contenu est correct.** Le fichier
      `app_flutter/feed_cache.hive` a été extrait de l'appareil (`adb run-as`)
      et inspecté : chaque horodatage porte le suffixe `Z` et correspond
      exactement à la base — `2026-08-04T08:36:36.212535Z` (= 04:36 Toronto),
      `2026-08-04T06:01:04.327625Z` (= 02:01), `2026-05-26T19:08:23.377349Z`
      (= 15:08). Avant le correctif, `toIso8601String()` nu y aurait écrit
      `2026-08-04T04:36:36.212535`, sans fuseau. L'aller-retour est donc sûr.
      À noter : seul le **fil** consomme réellement le cache — les autres
      `CacheService.cacheXxx` ne sont branchées à aucun lecteur.

---

## 14. Publication et plateformes

### ⬜ Bloqueurs de publication — Play & iOS (état 2026-09-21)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

  - [x] La promesse « position approximative » est tenue par le code.
  - [x] **Non-régression du démarrage vérifiée sur SM-A515F le 2026-09-21**
    (APK debug +23) : avec le nouveau code UMP au démarrage, l'app démarre et
    rend l'accueil ; **aucune** erreur `ConsentInform`/`MobileAds`/UMP ni
    exception Flutter au logcat, **aucun** ANR enregistré côté système (dropbox
    vide pour le paquet). Un dialogue « ne répond pas » transitoire est apparu
    pendant les ~24 s de démarrage d'un build **debug** (JIT + crate Rust MLS +
    chargement lourd de l'accueil) ; l'init UMP est `unawaited` en canaux
    asynchrones et ne bloque pas le thread principal — non imputable au
    changement, à revoir en release (démarrage bien plus rapide).
  - [x] **Scoping vérifié sur SM-A515F le 2026-09-21** (APK debug +23) par
    résolution d'intent — indépendant de l'auto-vérification, marche en debug :
    `cmd package query-activities -a VIEW -c BROWSABLE -d <url>`. Les chemins de
    contenu (`/groups/`, `/profile/`, `/events/`, `/p/`) listent bien l'app
    comme candidate ; les pages web (`/delete-account`, `/privacy-policy`,
    `/terms-of-service`, `/forgot-password`, `/`) **non**. Le piège `/p/` vs
    `/privacy-policy` est confirmé évité par la barre finale.

---

### ⬜ Notice « une nouvelle version est disponible » (2026-09-14)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Poser la clé, puis voir le bandeau** : vu sur SM-A515F le 2026-09-14
      avec `1.9.9+99`. Le bandeau affiche **« Diaspo Niger 1.9.9 »** — le nom
      seul, sans le `+99`, comme voulu.
- [x] **« Pas maintenant » tient** : écarté, `am force-stop`, relance à
      froid — le bandeau n'est pas revenu. Secret passé ensuite à `2.0.0+100` :
      il a reparlé, en « 2.0.0 ». Les deux moitiés vérifiées.

---

### ⬜ Divulgation préalable de la localisation (refus Play du 2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Carte -> ACTIVER** : la feuille de divulgation s'ouvre, puis **et
      seulement ensuite** la boite systeme Android. Sequence conforme.
- [x] **Refus a la boite systeme** : la carte bascule sur « Localisation
      requise pour voir les membres » + repli par ville. Pas de plantage, pas
      d'ecran mort.
- [x] **Mode Voyage** (Profil -> Modifier le profil -> Previsualiser -> bas de
      page) : feuille « Partage de position en continu », portant la phrase
      exigee « meme lorsque l'application est fermee ou n'est pas utilisee ».
      « Non, merci » laisse l'interrupteur eteint et ne demande rien.
- [x] **Position dans une discussion** : la feuille s'ouvre a l'ouverture du
      selecteur, avant que la carte ne se construise, avec le texte propre au
      cas (« participants de la discussion »).
- [x] **Sous-titre localise du Mode Voyage** visible a l'ecran.
- [x] **Onboarding 5/5** — vu, via l'echappatoire routeur documentee dans
      [[project_device_testing]] (patch temporaire, jamais committe : un lien
      profond ne suffit pas, `has_seen_onboarding` est un booleen local indexe
      par userId et le routeur renvoie la route sur /home des qu'il est vrai).

      **La premiere mesure a trouve le defaut** : le bloc de divulgation
      tombait **sous la ligne de flottaison** — seul le sous-titre corrige de
      l'interrupteur etait visible, et c'est cette page que Google
      photographie. Corrige en aplatissant l'illustration du dernier ecran en
      bandeau (`illustrationAspectRatio: 3.2`), ce qui libere ~230 px : le
      paragraphe et le lien vers la politique tiennent desormais juste
      au-dessus de « Commencer ». Remesure sur l'appareil.

      La ligne « Vos messages sont chiffres de bout en bout », elle, passe
      maintenant sous la ligne de flottaison. Arbitrage assume : l'une est une
      exigence de Play, l'autre une reassurance.
- [x] **Theme sombre** sur la feuille et le bloc d'onboarding. — doublon de la
      case « Thème sombre » plus bas dans cette entrée : **feuille vérifiée le
      2026-09-11** sur SM A515F en thème sombre ; le bloc d'onboarding reste à
      voir.
- [x] **Parcours de l'examinateur** : passer l'onboarding (« Passer », puis
      « Plus tard, sans autorisations »), puis ouvrir l'Accueil et la Carte —
      la feuille doit apparaître là aussi, avant toute boîte système.
      **✅ Chemin ACCUEIL vérifié le 2026-09-11 18:47, SM A515F, build 18.**
      Les deux autorisations de localisation retirées par `adb` (état d'avant
      relevé pour être rétabli), app relancée à froid sur l'Accueil : c'est la
      feuille de l'app qui s'ouvre — « Comment Diaspo Niger utilise votre
      position », texte nommant la **collecte** (« Diaspo Niger collecte des
      données de localisation pour vous placer sur la carte des membres… »),
      lien « Lire la politique de confidentialité », « Accepter et continuer »
      et « Non, merci » — et **aucune boîte système avant elle**. Le chemin
      Carte avait déjà été vérifié le 2026-09-09.
      **« Non, merci » tient aussi sa promesse** : aucune boîte Android
      derrière (vérifié à l'écran et par `topResumedActivity`, qui reste sur
      l'app et non sur `permissioncontroller`), et l'Accueil s'ouvre
      normalement, utilisable — c'est très exactement le parcours reproché par
      l'examinateur.
- [x] **Thème sombre** sur la feuille et sur le bloc de l'onboarding (jetons
      adaptatifs, jamais `AppColors` en dur).
      **Feuille ✅ 2026-09-11 18:51, SM A515F** basculé en thème sombre
      (Réglages › Thème › Sombre), autorisations de localisation retirées, et
      feuille rappelée par Carte › ACTIVER : fond sombre, titre blanc, corps
      gris clair lisible, lien et bouton « Accepter et continuer » en orange,
      « Non, merci » en bouton bordé — aucun jeton clair figé. Le texte dit
      bien les quatre choses exigées : la collecte, la visibilité par les
      autres membres, la limitation à l'usage de l'app, et l'arrêt possible
      depuis Réglages. Thème et autorisations rétablis après le test.
      **Le bloc d'onboarding dans ce thème reste à voir** : il demande
      l'échappatoire routeur, jamais committée.

---

### ⛔ « Diaspo Niger s'arrête systématiquement » sur Android 15+ (2026-09-09)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] `adb install -r` du nouvel APK **ne fait plus planter** l'app
      (`MY_PACKAGE_REPLACED`) : `adb logcat -b crash` reste à 0
      `FATAL EXCEPTION` douze secondes après.
- [x] `am force-stop` puis lancement : pas de plantage, `MainActivity` au
      premier plan, toujours 0 `FATAL EXCEPTION`.
- [x] Preuve indépendante que la suppression a bien pris :
      `adb shell dumpsys package com.diasponiger.diasponiger | grep -i
      BootReceiver` ne rend **rien** — le receiver n'est plus enregistré chez
      Android. Il l'était avant.

---

### ⚠️ Rapatriement iOS : deux dépendances **Android** changent de version majeure (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **`flutter build apk --release`** passe encore (signature, R8,
      shrinking) — vérifié le 2026-09-09 sur SM A515F : `assembleRelease` en
      656 s, APK de 168 Mo, versionCode 17, signé par
      `android/app/diaspo-niger-release.jks` (`DD:A6:5C:3E…CF:5D`, l'empreinte
      que Play attend), R8 actif — le paquet installé n'a plus le flag
      `DEBUGGABLE`. Posé et lancé, md5 sur l'appareil identique au fichier
      local (`9ee1f712…`).
- [x] **Le bundle `.aab`** passe encore — vérifié le 2026-09-11 :
      `flutter build appbundle --release` en exit 0, `app-release.aab` de
      210,7 Mo.
      ⚠️ Un premier essai, le 2026-09-10, avait échoué sur
      `:app:mergeReleaseResources` (« merged.dir/values/values.xml — The
      system cannot find the path specified »). Cause : un démon Gradle de
      l'autre agent était `BUSY` dans le **même** `build/` au même moment.
      Même famille que l'APK périmé du 2026-08-13 — un échec pendant un build
      concurrent ne prouve rien sur la configuration. Rejoué après
      `rm -rf build`, aucun processus java en cours : il passe.
      Ce que pèse vraiment le bundle : 126,7 Mo de `BUNDLE-METADATA` (mapping
      R8, symboles natifs — jamais envoyés aux appareils), 19,4 Mo communs
      (dex, ressources, assets), et ~21 Mo de natif **par architecture**. Soit
      **~41 Mo téléchargés par un téléphone arm64** — pas 210, ni les 168 de
      l'APK local, qui empile trois architectures dont `x86_64` (émulateurs
      seulement).
- [x] **Alignement 16 Ko** toujours bon — 2026-09-11, sur ce même bundle :
      `python tools/verifie_alignement_16k.py build/app/outputs/bundle/release/app-release.aab`
      → 16 bibliothèques 64 bits examinées, **0 non conforme** (8 ignorées :
      32 bits ou non ELF64).

---

### ⬜ Publication Play Store 1.2.1+11 — build release à valider (2026-09-08)

Première préparation complète d'un téléversement : `pubspec.yaml` passe à
`1.2.1+11` et `targetSdk` est épinglé à 36 dans `android/app/build.gradle.kts`
(il suivait `flutter.targetSdkVersion`, donc le SDK Flutter installé). AAB
signé produit et vérifié : empreinte SHA256 identique à celle du keystore.

Tout ce qui suit demande le **build release**, pas un debug — R8 et
`shrinkResources` sont actifs uniquement en release, et c'est là que se voient
les règles ProGuard manquantes (écran blanc, réflexion cassée, plugin muet).

- ⬜ Démarrage à froid du **build release** sur SM A515F (Android 13) : pas
      d'écran blanc, pas de crash, connexion et messagerie fonctionnelles.

  ⚠️ **Toujours pas fait au 2026-09-08, et pas par oubli.** Les captures de
  la fiche ont été prises avec un build **debug** de l'arbre fusionné, parce
  que l'app déjà installée est signée `CN=Android Debug` : installer le
  release exige `adb uninstall`, qui efface les données et **déconnecte le
  compte**. Le rendu à l'écran est identique entre debug et release — c'est
  la même source — donc les captures sont valides. Ce qui reste **non
  couvert**, c'est tout ce que seul le release exerce : R8, `shrinkResources`,
  et les règles ProGuard manquantes (écran blanc, réflexion cassée, plugin
  muet). Rien de tout cela n'a été vu tourner.

  Pour le faire : `adb uninstall com.diasponiger.diasponiger`, installer
  `build/app/outputs/flutter-apk/app-release.apk`, **se reconnecter à la
  main**, puis parcourir messagerie, appel, caméra, carte.
- ⬜ Idem sur Pixel 10 Pro XL (**Android 17, API 37**) — c'est le seul appareil
      qui exerce réellement `targetSdk = 36`.
- ⬜ Permissions runtime en release : caméra, micro, localisation,
      notifications. R8 casse volontiers les plugins de permission.

#### ⚠️ `ACCESS_BACKGROUND_LOCATION` — à trancher avant de soumettre

Le manifeste déclare `ACCESS_BACKGROUND_LOCATION`, ce qui déclenche côté Play
un formulaire obligatoire **avec vidéo de démonstration**, et c'est la première
cause de refus sur ce type de fiche.

Or `LocationService.requestBackgroundLocationPermission()` et
`hasBackgroundLocationPermission()` sont **définies et appelées nulle part**
(`grep` sur tout `lib/`). Le partage continu passe par
`BackgroundLocationService`, un service de premier plan
(`foregroundServiceType="location"`) — or un service de premier plan obtient
la position avec la seule permission de premier plan.

- ⬜ Activer le partage de position depuis le Profil, mettre l'app en
      arrière-plan, et vérifier que la position **continue** de remonter alors
      que le réglage système est sur « Autoriser uniquement quand l'app est
      utilisée » (donc sans la permission d'arrière-plan).
- Si ça remonte : la permission est inutile, la retirer du manifeste supprime
  tout le dossier de déclaration Play.
- Si ça ne remonte pas : la permission est nécessaire, et il faut alors ajouter
  l'**information préalable** exigée par Google (écran explicite avant la
  demande système), qui n'existe pas aujourd'hui puisque la demande elle-même
  n'est jamais faite.

#### Captures de la fiche boutique

Les captures livrées sont composées en 1080×1920 : les deux appareils sont en
1080×2400 (2,22:1) et Google refuse un côté long supérieur au double du côté
court. Les copies d'écran intégrées viennent d'un build **debug** de l'arbre
fusionné — pas du release, voir l'encadré ci-dessus : le rendu est identique,
la source étant la même, mais ce n'est pas le binaire téléversé.

- ⬜ Relire les captures livrées : aucune donnée personnelle réelle visible
      (nom, numéro, adresse, photo d'un tiers) avant publication.
      À ce stade, `01_accueil.png` montre le prénom « Salim » et une distance
      « 1,2 km », et `07_profil.png` le pseudo « @sim » avec « Montréal » —
      données des comptes de test, à valider ou à masquer.
- [x] **Sept captures prises sur SM A515F le 2026-09-08** : accueil (défilé),
      annuaire des postes, liste des démarches, formulaire de demande, carte
      (mode privé), groupes « Découvrir », profil. Build de l'arbre fusionné,
      md5 local et appareil comparés avant chaque prise.
- ⚠️ **L'appareil a été basculé en thème Clair + accent Vert (Défaut)** pour
      ces prises, et **y est resté**. Les captures de la fiche Play en ligne
      sont en clair et en vert, et le vert est le défaut de l'app face à
      « Orange (Classique) ». Toute vérification ultérieure qui suppose
      « sombre + orange » doit d'abord rebasculer le réglage.
- La fiche d'un poste a été **capturée puis retirée** : après la mise en
      sommeil des horaires et du bandeau « Ouvert », elle ne montre plus
      qu'une adresse, un fax et quatre boutons, et son encart le plus visible
      signale un numéro de fax erroné.
- Trois choix de cadrage, chacun pour une raison vue à l'écran :
  l'accueil est **défilé** parce qu'en haut de page il ouvre sur
  « Complétez votre profil 3/5 » et « 0 membres · 0 groupes » ; la liste des
  démarches est rognée à 254 px du bas parce que la boîte de dialogue laisse
  voir l'écran sous-jacent coupé en pleine phrase ; et **12 px sont retirés de
  chaque côté** sur toutes, sinon la barre de défilement Android laisse un
  filet clair le long du bord gauche du visuel fini.
- Trois écrans écartés faute de contenu présentable, **et non corrigés** :
  l'annuaire des entreprises est vide, le fil ne porte que des publications de
  test (« a ignorer »), la liste des groupes affiche « Groupe de test prive ».
- ⬜ Le Pixel 10 Pro XL n'a pas pu être capturé : il redemande son code de
      verrouillage. À refaire déverrouillé si des captures Android 17 sont
      souhaitées.

---

### ⬜ Passage à targetSdk 36 (Android 16) — exigence Play (2026-09-08)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Bord à bord (edge-to-edge) imposé, sans dérogation possible.** L'app
      était déjà concernée en ciblant 35 ; en 36 l'échappatoire
      `windowOptOutEdgeToEdgeEnforcement` est ignorée. Revoir les écrans qui
      dessinent jusqu'en bas : barres d'onglets, champ de saisie de
      discussion, feuilles modales — vérifier qu'aucun contenu ne passe sous
      la barre de navigation gestuelle ni sous l'encoche.
      **✅ 2026-09-11 18:33, Pixel 10 Pro XL (Android 17, build 18, thème
      sombre, navigation gestuelle).** Les trois surfaces à risque sont
      au-dessus de la barre de gestes : champ de saisie d'une discussion
      (avec « + », émojis et micro), feuille de pièces jointes (Caméra,
      Photos, Documents, Position, Événement) et barre d'onglets de l'accueil.
      Rien sous l'encoche non plus — l'en-tête commence sous les icônes d'état.
      Reste à voir en **paysage** et sur une tablette / pliable.
- [x] **Alignement 16 Ko des bibliothèques natives.** Indépendant du
      targetSdk mais contrôlé au même endroit par Play. Mesuré sur l'AAB du
      jour : 6 des 8 `.so` arm64 sont conformes (dont `libflutter.so`,
      `libapp.so`, `libjingle_peerconnection_so.so`), **2 ne le sont pas**
      (`p_align` = 4096) — `libbarhopper_v3.so`
      (`com.google.mlkit:barcode-scanning:17.2.0`, tiré par `mobile_scanner`)
      et `libnoise.so` (`com.github.paramsen:noise:2.0.0`, transitive de
      `livekit_client`). NDK 27 aligne ce qui est compilé ici, pas les `.so`
      préconstruites d'un plugin. **Réglé le 2026-09-08** : les 8 `.so`
      arm64-v8a et les 8 x86_64 de l'AAB reconstruit sont à >= 16 Ko — voir
      la section « Deux bibliothèques natives réalignées sur 16 Ko » en tête
      de ce fichier, qui porte les deux vérifications appareil restantes
      (scanner QR, appel LiveKit).

---

### iOS : premier build réussi, sur simulateur (2026-09-01)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] `diaspo_niger/share_intent` → `getInstallationId` rendu par
      `identifierForVendor`, équivalent iOS du SSAID. Le garde Dart de
      `stableDeviceId` s'ouvre à iOS en conséquence. Sans ça, chaque
      régénération de clés créait une ligne de plus dans `e2ee_devices`, et
      tout message destiné au compte doit être chiffré pour chacune.
      `clearSharedIntent` répond sans rien faire : il manipule l'intent d'une
      activité Android, notion inexistante ici.
- [x] Délégué `UNUserNotificationCenter` posé — sans lui,
      `flutter_local_notifications` ne peut rien afficher au premier plan et
      iOS supprime la bannière en silence.
- [x] `diaspo_niger/lockscreen` — **volontairement non porté.** Il remplace
      `showWhenLocked`/`turnScreenOn` d'Android ; sur iOS c'est CallKit qui
      gouverne l'affichage d'un appel sur écran verrouillé.
      `LockScreenService._apply` sort déjà avant l'appel hors Android.
- [x] `diaspo_niger/deep_link` — **volontairement non porté.** Côté Android il
      contourne un défaut réel (le moteur mis en cache par `audio_service`
      empêche le canal de navigation d'aboutir). Ce montage n'existe pas sur
      iOS : `FlutterDeepLinkingEnabled` étant à `true`, `FlutterAppDelegate`
      relaie lui-même les liens. Le porter ferait **naviguer deux fois**.

---

### ⚠️ Simulateur : lancer DeviceHub AVANT de démarrer l'app (2026-09-01)

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

Une fois lancée, l'écran de connexion s'affiche immédiatement et correctement
(thème clair, fond crème). Écarté au passage comme régression de la parité
Swift : même comportement avec l'`AppDelegate` d'origine, test A/B fait.

- [x] Écran de connexion vérifié sur simulateur iPhone 17 (iOS 26.1).

---

### Supabase branché sur iOS — deux réserves (2026-09-01)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Initialisation Supabase vérifiée sur simulateur.

---

### Liens profonds iOS : la moitié testable est bonne (2026-09-01)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Schéma `diasponiger://` reconnu par iOS.** `simctl openurl` déclenche
      bien « Ouvrir dans Diaspo Niger ? » : la déclaration
      `CFBundleURLSchemes` d'`Info.plist` est correcte.
- [x] **Routage vérifié.** `diasponiger:///auth/register` amène bien sur
      « Créer un compte ». **Ça valide la décision de ne PAS porter le canal
      `diaspo_niger/deep_link` sur iOS** : la route est arrivée par le canal de
      navigation de l'embedding — aucune trace du gestionnaire
      `_bindNativeDeepLinks` dans les journaux — donc ajouter le canal aurait
      fait naviguer deux fois.

---

## 16. Journaux de passes appareil

### Passe pilotée du 2026-08-04 (15:25 → 16:05) — SM A515F, APK debug `54083d6`

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **Règle écrite le 2026-08-04** dans `storage.rules` :
      `match /key_backups/{userId}/{allPaths=**}`, lecture **et** écriture
      réservées à `isOwner(userId)` (contrairement aux médias chiffrés, un
      backup de clés ne doit pas être lisible par tout compte connecté : il est
      protégé par une passphrase, mais l'exposer offrirait le fichier à une
      attaque hors ligne). `create`/`update` séparés de `delete` car
      `request.resource` est nul sur une suppression — sans ça `deleteBackup()`
      serait refusé. Compilation vérifiée par l'émulateur Storage
      (`firebase emulators:exec --only storage`), avec témoin négatif : une
      règle volontairement cassée sort bien `token recognition error … :134`,
      le fichier réel n'en sort aucune.
- [x] **Déployé le 2026-08-04 à 16:07** (`firebase deploy --only storage`,
      projet `diaspo-niger`) : « rules file storage.rules compiled successfully »
      puis « released rules storage.rules to firebase.storage ».
- [x] **Vérifié sur appareil dans la foulée (16:08 → 16:11, SM A515F).** Plus
      aucun `unauthorized` au démarrage à froid, et **toute la chaîne E2EE s'est
      déroulée pour la première fois sur cet appareil** :

      ```
      KeyManagerService: Initializing keys for user vQZE49dT…
      SecureKeyStorage: Stored identity key pair
      SecureKeyStorage: Stored signed pre-key 954080014
      SecureKeyStorage: Stored 100 one-time pre-keys
      KeyManagerService: Published 100 one-time pre-keys
      KeyManagerService: Published keys to Supabase
      MessagingE2EEService: Initialized / key maintenance done
      ```

      Avant le correctif, la génération était sautée et rien de tout ceci
      n'apparaissait. Le repli AES global n'est donc plus la seule option.
- [x] **Le bandeau de sauvegarde s'affiche enfin** (« Sauvegardez vos clés de
      chiffrement… » / Pas maintenant · Sauvegarder), rendu correct en thème
      **nocturne**, sans débordement. Il n'avait jamais été atteignable.
- [x] `/settings/security/backup` s'ouvre et propose « Créer une sauvegarde »
      (générateur de passphrase, jauge de force, bouton inactif tant que la
      passphrase est faible) — donc la **lecture** du chemin `key_backups/`
      aboutit désormais.
- [x] **Branche écriture validée le 2026-08-04 à 18:21** — sauvegarde créée par
      Salim (la passphrase doit être consignée par un humain : une passphrase
      perdue laisse un futur appareil en `needsRestore` sans pouvoir restaurer,
      donc pire que pas de sauvegarde). L'écran affiche **« Sauvegarde active »**,
      « Créée le : 4/8/2026 à 18:21 », « Appareil : android Device », plus la
      section « Restaurer sur cet appareil ». `uploadBackup` **et** la lecture
      des métadonnées fonctionnent : la règle `key_backups/` est donc prouvée en
      **lecture et en écriture**, de bout en bout.
- [x] **Démarrage à froid propre** : `/splash` → `/home`, **0 exception Flutter,
      0 `RenderFlex overflowed`** sur deux démarrages complets. Compter ~25 s
      entre le lancement et l'accueil (Supabase, Maps, App Check, GoRouter).
- [x] **Les 5 onglets de la barre basse** (Accueil, Carte, Groupes, Messages,
      Profil) : navigation correcte, **aucun débordement** à `font_scale` 1.1 en
      thème clair. Écran Messages conforme (chips Tous/Non lus/Groupes/Archives,
      sur-titres « CETTE SEMAINE » / « PLUS ANCIEN », tuile « Mes notes »).
- [x] **§9b — le clavier de recherche se lève au premier tap.** Cas décisif
      prouvé par `dumpsys input_method` : `mInputShown=false` avant le tap,
      `mInputShown=true` + `mIsInputViewShown=true` après **un seul** tap. C'est
      le correctif `27f52a3` vérifié en vrai.
- [x] **§9b non-régression visuelle** : en-tête replié (← + champ), bordure
      accent orange, loupe orange, halo, puces de filtre escamotées, curseur
      dans le champ. Rien d'anormal au repos.
- [x] **Balayage nocturne des 5 onglets** : **0 débordement, 0 exception** dans
      logcat, à `font_scale` 1.1. Écran Groupes correct (onglets pleins, carte de
      groupe, puces Niger / 1 / Autre).
- [x] **Carte en nocturne** : les tuiles adoptent bien le **style sombre**.
      ⚪ **Fausse alerte évitée** : capturée 8 s après l'ouverture, la zone de
      carte est un **aplat crème** sans aucune rue — ce n'est pas un jeton clair
      figé, ce sont les tuiles pas encore chargées (`ClientParamsBlocking` dans
      logcat). Laisser ~30 s avant de conclure quoi que ce soit sur la carte.
- [x] **En-tête du panneau de la carte non tronqué** : « 1 membre autour · 50 km »
      puis « 0 membre autour · 50 km » s'affichent en entier, avec la ligne de
      fraîcheur résolue. Le défaut cosmétique « Memb… » n'est pas reproduit.
- [x] **Position de repli = Niamey** quand la localisation n'est pas disponible
      (constaté avec la demande de permission à l'écran). Cohérent pour l'app.
- [x] Le brouillon est restauré **et le bouton d'envoi bleu est là d'emblée**,
      sans toucher au champ. Correctif `20042b7` vérifié en vrai.
- [x] **Envoi direct du brouillon restauré**, sans toucher le champ au
      préalable : le message part et s'affiche dans le fil de la conversation.
- [x] **Non-régression** : après envoi, le composer revient au **micro**
      (conversation sans brouillon).
- [x] `am start -a VIEW -d …/feed/00000000-…-000000000999` sur app tuée →
      l'écran affiche **« Publication introuvable »**, « Elle a peut-être été
      supprimée par son auteur, ou le lien est incorrect. » et le bouton
      « Retour au fil ». **Plus aucun squelette, et plus de champ de
      commentaire.** Rendu correct en thème nocturne.
- [x] **Non-régression, une vraie publication** : le même chemin avec
      `d8888ee4-…` (« In kwana », id relevé via `supabase db query --linked`)
      charge la publication en entier — carte, barre d'engagement, commentaire
      « Cool », et le champ de commentaire bien présent. Aucune
      `PostgrestException`.
- [x] Le bouton fonctionne. ⚠ Il menait à `/home` alors qu'il dit « Retour au
      fil » : corrigé vers `/feed` **après** la vérification appareil, donc
      cette ligne-là n'est couverte que par `analyze` + les tests. Pas de
      seconde réinstallation pour si peu (chacune vide les données).
- [x] **Aucune feuille de partage** aux trois relances, et **aucun rejeu du
      lien** : l'app arrive sur `/home` à chaque fois. C'est le cas décisif de la
      purge `reset()` + de l'empreinte persistée.
- [x] Les seules traces « share » dans le journal sont bénignes (« Encryption
      service initialized with shared key », et la route `/share` dans la liste).
- [x] **Splash de ~2 min → NON.** `/splash` à 16:47:46, `/home` à 16:47:57 :
      **11 secondes**.
- [x] **Squelettes infinis dans le fil → NON.** « Le fil » affiche le bandeau
      **« 🕐 Fil hors ligne · dernière mise à jour Il y a 1 heure(s) »** puis
      rend les **trois publications en cache** en entier. Le repli annoncé par la
      maquette 2a fonctionne donc.
- [x] **Retour au splash → NON.** Un seul `setting initial location` sur toute la
      session, pid inchangé : aucun redémarrage.
- [x] Liste des conversations hors ligne : servie par le cache, « Mes notes »
      affiche bien son dernier message.
- [x] **0 `RenderFlex overflowed`, 0 exception Flutter** hors ligne. (Attention
      au faux positif : un `Select-String "EXCEPTION"` insensible à la casse
      remonte 102 lignes qui sont toutes des `SocketException` /
      `AuthRetryableFetchException` — filtrer sur `RenderFlex` et
      `EXCEPTION CAUGHT` uniquement.)
- [x] **Lien profond reçu app déjà lancée — RÉSOLU et vérifié le 2026-08-04 à
      22:45.** `singleTask` ne corrigeait que la moitié du problème.

      Instrumentation ajoutée pour trancher (et **conservée** : sans elle on ne
      peut pas distinguer « `onNewIntent` n'a pas été appelé » de « la route n'a
      pas été poussée », et le diagnostic repart de zéro — déjà perdu une fois).
      Elle a montré que `onNewIntent` **était bien appelé** avec la bonne URL,
      mais qu'aucune navigation GoRouter ne suivait : le
      `getNavigationChannel().pushRouteInformation(...)` de l'embedding
      n'aboutit pas dans ce montage, à cause du moteur mis en cache qu'impose
      `audio_service`.

      Correctif : la route passe désormais par un **canal explicite**
      (`diaspo_niger/deep_link`), reçu côté Dart au moment où le routeur est
      créé (`_bindNativeDeepLinks`), qui appelle `router.go()`. Journal complet
      vérifié sur appareil :

      ```
      DiaspoDeepLink: onNewIntent action=…VIEW data=…/feed/0d9abb43-…
      DiaspoDeepLink: route poussee vers Dart : /feed/0d9abb43-…
      flutter  : DeepLink: route reçue à chaud → /feed/0d9abb43-…
      GoRouter : going to /feed/0d9abb43-…
      ```

      Capture à l'appui : la bonne publication s'affiche, **sans repasser par le
      splash**.
- [x] **Brouillon long — vérifié le 2026-08-04 à 23:03.** Le champ est **plafonné
      à 2000** : impossible de dépasser en tapant, le compteur passe simplement
      en rouge « 2000 / 2000 » et le bouton d'envoi reste actif (correct à la
      limite exacte). Après bouton accueil + `am force-stop` + relance, le
      brouillon est restauré **avec son compteur rouge dès l'ouverture** : l'état
      dérivé est donc bien recalculé, pas seulement `_hasText`.

      ⚠ Le cas strict « **plus** de 2000 caractères → bouton d'envoi inactif »
      n'est **pas atteignable en tapant**. Il ne peut survenir que par un
      brouillon injecté (`controller.text = …` contourne `maxLength`), donc un
      brouillon enregistré quand la limite était plus haute. Pour le prouver il
      faudrait semer un brouillon > 2000 dans les préférences.

---

### Passe nocturne + carte vérifiée sur appareil (2026-08-04, SM A515F)

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] **6a — Fil Nocturne** : fond `#161826`, point d'accent violet sur
  « Le fil », onglet actif en **contour** (pas en fond plein), cartes de post
  radius 8, et le **FAB creux à contour net** en bas à droite. Le rail
  « Ma story » ne déborde plus.
- [x] **11d — Mon profil Nocturne** : fond `#0F0D0A`, cartes `#1A1714` à
  liseré `#2A241E`, puce métier teintée vert sur fond vert sombre, point
  d'accent orange après le nom. ⚠ Le **badge « vérifié » n'a pas pu être
  vu** : le compte de test n'est pas vérifié. À reprendre avec un compte qui
  l'est.
- [x] **11e — Réglages Nocturne** : « Supprimer mon compte » en rouge clair
  `#F87171`, « Déconnexion » en ambre, liseré de la zone sensible net. Avant
  le correctif, ces trois-là étaient sur les jetons du thème clair, donc
  sombres sur `#0F0D0A`.
- [x] **7d — Carte, panneau à trois positions** : recherche fixe, bouton
  calques, chips, feuille draggable. **Un défaut trouvé et corrigé sur place**
  (voir ci-dessous).
- [x] **8c — Carte sans localisation** : carte à pastille `location_off`,
  trois garanties à coche verte, bouton « Activer » plein + « Réglages de
  confidentialité » en contour, le tout décliné en nocturne.

---

### Session du 2026-08-03 (soir) — SM A515F, refonte enfin lancée

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Le titrage serif rend correctement (« Bonjour, **Sim** »).
- [x] Le bandeau de complétude (§11f) s'affiche : barre terracotta, « 2/5 »,
      message contextuel et action « Ajouter ma ville ».
- [x] La carte « POUR COMMENCER » rend ses trois amorces avec leurs
      sous-titres — c'est la localisation ARB de cette session, en vrai.
- [x] Grille de services, barre de navigation basse, ligne de contexte.
- [x] Le thème sombre est lisible partout sur cet écran : aucun jeton clair
      figé n'est ressorti.
- [x] `RenderFlex overflowed by 179 pixels on the right`
      (`map_screen.dart:3413`) : la rangée du volet des membres alignait deux
      libellés de temps relatif (« mis à jour il y a… ») côte à côte, sans
      possibilité de rétrécir. Les deux passent en `Flexible` + ellipse.
- [x] L'écran affichait trois valeurs incompatibles : sous-titre « 1 rejoint »,
      puce « Mes groupes · 0 », corps « Vous n'avez rejoint aucun groupe ».
      Une sonde temporaire a montré `joinedCount=0` de façon stable — donc
      c'était le **rendu** du pluriel qui mentait, pas la donnée.

      Cause : `=1{…}` dans l'ARB est compilé par `gen-l10n` en `one:`. Or en
      **français, la catégorie CLDR `one` couvre 0 et 1**. Toute clé dont la
      branche `=1` code le chiffre « 1 » en dur affiche donc « 1 … » quand le
      compte vaut zéro.

      7 clés étaient concernées ; toutes ont reçu un cas `=0` explicite.
      Vérifié sur appareil après correction : « 0 rejoint ».

      ⚠️ **Piège à retenir** : les pluriels en suffixe
      (`{count} message{…=1{} other{s}}`) ne sont **pas** touchés — en
      français zéro prend le singulier, « 0 message » est correct. Ne pas les
      « corriger ».
- [x] Les séparateurs rendent en pastille plate avec filet plein, sans
      dégradé ni ombre : le correctif de `_buildThreadSeparator` est vérifié
      sur appareil (« 26 juil. 2026 », « lundi »).
- [x] En-tête, sous-barre « Médias / ÉCO », composer et accusés de lecture
      rendent sans incident.
- [x] La `SliverAppBar` était figée sur `AppColors.primary` : une fois
      repliée, elle virait au terracotta plein sur toute la largeur, seul
      écran de l'app à le faire, et le jeton ne suivait pas le thème. Elle
      prend maintenant `context.backgroundColor` + `surfaceTintColor`
      transparent. Vérifié replié : fond sombre, seul « Enregistrer » reste
      terracotta — c'est l'action principale, elle doit l'être.

---

### Session appareil du 2026-08-03 — SM A515F, thème sombre, font_scale 1.1

*Entrée encore ouverte dans la liste : ici, seulement ses cases vérifiées.*

- [x] Puce de filtre des notifications : fond `adaptivePrimaryColor` (qui
  s'éclaircit en nuit) + texte `Colors.white` figé → blanc sur orange clair.
  Corrigé en `onPrimaryColor`. **Vérifié à l'écran après reconstruction.**
- [x] « Précédent » tronqué en « Précéd » à l'étape 3/4 de la configuration
  du profil : ratio 1:2 trop serré à font_scale 1.1. Passé à 3:4.

---
