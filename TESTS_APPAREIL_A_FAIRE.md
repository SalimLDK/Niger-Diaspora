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

## Passe pilotée du 2026-08-04 (15:25 → 16:05) — SM A515F, APK debug `54083d6`

Programme de test exécuté au pilotage `adb` (taps + `dumpsys` + logcat), thème
clair, `font_scale` 1.1, batterie sur secteur. **Aucune réinstallation** : l'APK
en place contenait déjà tout jusqu'à `54083d6`.

⚠️ **Une session concurrente tournait sur le même téléphone et le même dépôt.**
`lastUpdateTime` est passé de 15:18:51 → 15:25 → 15:41:59 (logcat :
`Killing … due to installPackageLI` en plein démarrage à froid), avec des
process Gradle/`dart`/`flutter_tester` actifs côté PC. **Tous les constats de la
première passe 0 ont été jetés** ; seuls figurent ci-dessous ceux obtenus après
15:47, fenêtre où plus rien n'installait. À retenir pour les prochaines fois :
vérifier `lastUpdateTime` **avant et après** chaque mesure.

### 🔴 Trouvé — sauvegarde des clés E2EE impossible, et ça bloque la génération

Reproduit à **3 démarrages à froid sur 3**, dans logcat :

```
KeyBackupService: backup presence unknown (FirebaseException):
[firebase_storage/unauthorized] User is not authorized to perform the desired action
```

Cause, vérifiée dans le dépôt : **`storage.rules` ne déclare aucune règle pour
`key_backups/`**. Le chemin `key_backups/{userId}/backup.enc` tombe donc dans le
`match /{allPaths=**} { allow read, write: if false; }` final — exactement le
même piège que celui déjà corrigé pour `/posts` et `/stories`.

Les cinq opérations de `key_backup_service.dart` sont concernées (`uploadBackup`,
`downloadBackup`, `checkBackupPresence`, `getBackupMetadata`, `deleteBackup`).

**La conséquence dépasse la sauvegarde.** Dans `e2ee_backup_coordinator.dart`,
`checkBackupPresence` renvoie `unknown` au lieu de `absent`, et le cas `unknown`
**saute délibérément la génération de clés** (pour ne pas écraser une identité
restaurable). Sur un appareil sans clés locales, aucune identité Signal n'est
donc jamais créée : la messagerie reste silencieusement sur le repli AES global,
et le bandeau de sauvegarde n'apparaît jamais. Le garde-fou est correct — c'est
la règle Storage manquante qui le déclenche à tort.

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
- [ ] ⚠ **La branche écriture n'est pas testée** : `uploadBackup` n'a pas été
      exercé. Créer une sauvegarde génère une passphrase que **Salim seul** doit
      consigner — sans elle, un futur appareil neuf verrait `needsRestore`, ne
      générerait aucune clé, et resterait bloqué. À faire par lui, en notant la
      passphrase. C'est le dernier point qui valide la règle en écriture.
- [ ] Sur un **second appareil** : vérifier que la restauration fonctionne
      (`needsRestore` + saisie de la passphrase).
- [ ] Une fois déployé : sur un appareil sans clés locales, vérifier que les
      clés sont bien générées et que le bandeau « sauvegarder » apparaît.
- [ ] **Piste à confirmer** : ceci explique peut-être le point ouvert 20b
      (« CET APPAREIL » absent de la liste des appareils) — sans génération de
      clés après un vidage de données, aucun enregistrement E2EE n'a lieu.

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

### ✅ Vérifié sur appareil pendant cette passe

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

### Deuxième tour (16:13 → 16:21) — passe nocturne, et un test avorté

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
- ⚠ **Demande de permission de localisation** rencontrée à l'écran : **laissée
      sans réponse volontairement**, accorder une permission système n'est pas
      une décision d'agent. À traiter par Salim.

**Conséquence bien réelle du bug `key_backups` — constatée dans « Mes notes ».**
Le message du 19 juil. s'affiche « 🔒 **Message chiffré** », avec le bandeau
« Restaurez vos clés de chiffrement pour lire vos messages chiffrés sur cet
appareil ». Les clés locales ont été perdues lors d'une réinstallation, et
**aucune sauvegarde n'existait** puisque la fonctionnalité était cassée : ce
message E2EE est donc définitivement illisible sur cet appareil. Les messages
partis en **repli AES** (« Note validee », « Verif citation 4a ») restent
lisibles, eux. C'est exactement le scénario que la sauvegarde doit empêcher —
raison de plus pour créer la sauvegarde maintenant que la règle est déployée.

- [ ] ⛔ **Brouillon restauré : test NON concluant, à refaire.** Deux tentatives
      avorties — mes taps sur le champ de saisie n'ont pas donné le focus
      (`mInputShown=false`), donc aucun texte n'a été saisi et il n'y avait aucun
      brouillon à restaurer. **Ce n'est pas un bug de l'app**, c'est un test raté.
      À refaire au doigt : taper du texte, bouton accueil, relancer, rouvrir la
      conversation, et vérifier que le bouton d'envoi est là **d'emblée**.

⚠️ **La session concurrente n'a pas cessé** : nouvelle réinstallation à 16:14:42
(`installPackageLI`), process de l'app redémarré à 16:18:42 puis 16:19:30, et une
navigation vers `/groups` que je n'ai pas déclenchée. **Les passes restantes
demandent l'appareil pour soi seul** — sinon chaque mesure est à jeter.

### Reste du programme, non exécuté faute de temps

- [ ] Brouillon restauré → bouton d'envoi (dépend des `SharedPreferences`, donc
      à faire **avant** toute réinstallation).
- [ ] Feuille de partage fantôme au démarrage + partage entrant réel.
- [ ] Lien profond reçu **app déjà lancée** (`onNewIntent` + `singleTask`) — le
      changement de `launchMode` est encore **non committé** dans l'arbre.
- [ ] Repli hors-ligne (splash de ~2 min + squelettes infinis, bug déjà ouvert).
- [ ] Admin : champ « Type * » à la création d'ambassade.
- [ ] Passe complète en **thème nocturne**.

---

## Recherche messagerie — le clavier demandait deux taps (§9b, 2026-08-04)

Bug constaté sur appareil (SM A515F, build debug, nocturne, reproduit 3 fois) :
le premier tap sur le champ de recherche ouvrait bien l'en-tête replié (← +
champ à bordure accent) et le champ **gardait** le focus, mais le clavier ne se
levait pas. Un second tap le faisait apparaître, et tout marchait ensuite.

Cause : **pas le focus** — c'est la `TextInputConnection` qui se fermait.
`EditableTextState.dispose()` ferme la connexion sans défocaliser le `FocusNode`
externe, et `initState()` n'en rouvre aucune (seul un *changement* de focus le
fait). Dès que l'élément du champ était démonté puis réinflaté alors que le
nœud était déjà focalisé, le clavier tombait et rien ne le rappelait. Le 2e tap
marchait via `requestKeyboard()`, qui rouvre la connexion explicitement.

Deux endroits démontaient l'élément, corrigés tous les deux (commit `27f52a3`) :
le changement de type de widget dans `DesignSearchField` (`TextField` →
`DecoratedBox(child: TextField)` quand `active` bascule), et l'absence de clé
sur le bloc du champ dans la `Column` de `messages_screen.dart` — à l'ouverture
l'en-tête change de type et les puces de filtre disparaissent, donc le bloc
tombe dans la zone « milieu » de `updateChildren` où tout enfant sans clé est
démonté.

⚠ **Rien n'est prouvé hors appareil** : contrairement au cas « brouillon
restauré » ci-dessous, aucun test ne couvre ça — la remontée du clavier logiciel
n'est pas observable en test widget. `flutter analyze` propre, c'est tout.

- [ ] **Le cas décisif** : depuis la liste des messages, **un seul tap** sur le
      champ de recherche → le clavier doit monter immédiatement et **rester**.
- [ ] Enchaîner : saisir un terme sans re-toucher le champ, vérifier que le
      filtrage et les sections **Personnes** / **Conversations** répondent.
- [ ] Fermer par la flèche ←, puis rouvrir par un tap : le clavier doit remonter
      du premier coup **à chaque fois**, pas seulement la première.
- [ ] Non-régression visuelle (fiche 9b) : bordure accent, loupe orange et halo
      3 px toujours présents en recherche — et **aucune ombre** quand le champ
      est au repos (le `DecoratedBox` est désormais permanent).
- [ ] Refaire la passe en **clair et en nocturne** : le correctif touche
      `design_kit.dart`, donc tous les autres `DesignSearchField` du projet
      (boutique, groupes, carte) — vérifier qu'aucun n'a gagné d'ombre parasite.
- [ ] Boîte de réception **vide** : le champ n'est pas affiché dans cet état, la
      recherche n'y est donc pas ouvrable — confirmer que c'est bien voulu.

---

## Brouillon restauré — le composer restait sur le micro (2026-08-04)

Bug constaté sur appareil (SM A515F, build debug, conversation « Mes notes ») :
texte tapé sans envoyer, app quittée par le bouton accueil, puis relancée — le
brouillon est bien restauré dans le champ, **mais le bouton de droite affiche
le micro** au lieu du bouton d'envoi. Toucher le champ suffisait à le faire
réapparaître. Conséquence : on croit ne pas pouvoir envoyer son brouillon.

Cause : dans `message_input.dart`, `_loadDraft()` est appelé depuis `initState`
**avant** que le listener du contrôleur ne soit posé. L'écriture du brouillon
dans le contrôleur n'atteignait donc aucun listener, et `_hasText` restait à
`false` (comme `_isOverLimit` et le contrôleur de morphing). Corrigé en
recalculant l'état dérivé depuis `controller.text` au moment de l'injection,
sans animation à l'ouverture.

**Prouvé hors appareil** : cas ajouté à `message_input_composer_test.dart`
(brouillon semé dans `PreferencesService`, puis badge cadenas E2EE attendu sans
aucune frappe). Vérifié rouge sans le correctif, donc non vide de sens ;
14/14 au vert avec. Mais un test widget ne rejoue pas un vrai cycle de process.

- [ ] **Le cas décisif** : taper sans envoyer, **bouton accueil**, relancer
      l'app, rouvrir la conversation → le bouton d'envoi bleu doit être là
      **d'emblée**, sans toucher au champ.
- [ ] Envoyer directement ce brouillon restauré, sans toucher le champ au
      préalable : l'envoi doit aboutir.
- [ ] Le bouton doit être **présent immédiatement**, pas apparaître en fondu :
      le morphing est volontairement court-circuité à la restauration.
- [ ] Non-régression : une conversation **sans** brouillon doit toujours
      afficher le micro.
- [ ] Brouillon de **plus de 2000 caractères** : l'état « dépassement » doit
      être restauré lui aussi (bouton d'envoi inactif), pas seulement `_hasText`.
- [ ] ⚠ **Ne pas réinstaller entre les deux étapes** : `adb install -r` vide les
      données, donc les `SharedPreferences` — le brouillon disparaît et le test
      ne prouve rien. Relancer l'app déjà installée (`am start` / icône).

---

## Menus déroulants bornés partout (`isExpanded`, 2026-08-04)

Balayage des 16 menus restants, même cause que le champ « Type * » ci-dessous.
Un seul écran débordait réellement à l'échelle 1.0 ; le reste est du
durcissement, donc à regarder surtout **à `font_scale` 1.1 et plus**.

- [ ] **Ambassade → « Demande administrative »** : le champ « Type de demande »
  ne déborde plus. C'est le cas le plus visible (débordait de 234 px en test).
- [ ] **Boutique → « Vendre un produit »** : l'en-tête de carte « Paramètres de
  taxe » ne déborde plus, et les menus Devise / Catégorie / État / Pays sont
  lisibles.
- [ ] **Transferts → « Ajouter un bénéficiaire »** : choisir le type **compte
  bancaire** (les menus « banque » et « ville » n'existent que dans ce mode —
  aucun test ne les couvre), puis vérifier les trois menus.
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
- [ ] **Boutique → « Vendre un produit », menu « Pays »** : les deux listes
  (pays prioritaires **et** le reste, sous le séparateur) — le drapeau reste
  collé au nom et aucun nom de pays n'est coupé à l'échelle 1.0.
- [ ] Les mêmes à `font_scale` 1.1 : là, une ellipse est normale.

---

## Débordement du champ « Type * » — création d'ambassade (2026-08-04)

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

## Passe nocturne + carte vérifiée sur appareil (2026-08-04, SM A515F)

Cinq fiches regardées d'affilée en thème sombre, build debug installé sur
l'appareil de référence.

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

**Défaut trouvé pendant la passe** : l'en-tête du panneau de la carte
affichait « 0 membre a… » tronqué, avec du vide à sa droite. Le titre était
dans un `Flexible` et la rangée contenait un `Spacer()` — tous deux `flex: 1`,
donc l'espace libre était partagé en deux au lieu d'aller au titre. Titre et
rayon regroupés dans un `Expanded` ; vérifié réparé sur l'appareil.

**Fausse alerte notée pour mémoire** : la ligne de fraîcheur du panneau
affiche deux « Chargement… » tant que la position n'est pas acquise. Ce n'est
pas un champ mort — au bout des 15 s de `timeLimit`, en intérieur sans fix
GPS, l'écran bascule sur 8c. Ne pas rouvrir ce faux bug.

**Complément 7d, même session** : une fois la position obtenue (Montréal), le
panneau affiche « 1 membre autour · 50 km » en entier, la ligne de fraîcheur
se résout en « À l'instant / Il y a 49 s », et la ligne de membre s'affiche
avec son bouton 💬. En-tête, fraîcheur et ligne de membre sont donc vérifiés.

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

---

## Feuille de partage fantôme au démarrage (2026-08-04)

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
- [ ] `launchMode` est resté `singleTop` (le README du plugin conseille
      `singleTask`) : non changé pour ne pas perturber CallKit et
      `showWhenLocked`. Surveiller qu'un partage ne crée pas une **seconde
      instance** de MainActivity — le FlutterEngine est mis en cache par
      audio_service, deux activités branchées dessus poseraient problème.

### Liens profonds routés vers `/feed/:id` (2026-08-04)

Ouvrir un lien de publication lançait l'app sur l'accueil : rien ne consommait
l'URI. Deux causes, corrigées ensemble :

1. `flutter_deeplinking_enabled` n'était pas déclaré au manifest — Flutter
   ignorait l'URI et la route initiale restait « / ». Les liens générés par
   `DeepLinkService` sont déjà des chemins d'app (`/feed/<id>`), donc GoRouter
   sait les router tels quels une fois l'URI transmise.
2. Même transmise, la destination était **perdue** : au démarrage à froid
   l'authentification n'est pas résolue, le `redirect` renvoyait sur `/splash`
   puis `/home`. Elle est maintenant mise de côté (étape 0) et rejouée une fois
   l'utilisateur prêt (étape 10).

⚠️ **Le clic sur un lien n'ouvre l'app que si sa signature est déclarée.**
`assetlinks.json` couvre maintenant Play App Signing **et la clé release
locale** (`DD:A6:5C:…`), et il est **déployé** depuis le 2026-08-04 sur
`diasponiger.web.app` comme sur `diaspo-niger.web.app` — donc un APK release
installé à la main vérifie ses liens. La clé **debug** (`87:32:AD:…`) n'y est
pas : sur un build debug, Android ouvrira Chrome.

**Constaté le 2026-08-04** sur l'APK debug installé (signature `87:32:AD:…`) :
`pm verify-app-links --re-verify` **ne peut pas aboutir**, l'état reste `1024`
(échec) sur les deux domaines — le serveur ne déclare pas cette empreinte. Ce
n'est pas un problème de fichier ni de cache, c'est la signature.

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

**Vérifié sur appareil le 2026-08-04** (SM A515F, Android 13, APK debug de
14:25 contenant bien `flutter_deeplinking_enabled` — vérifié par
`aapt2 dump xmltree` sur l'APK tiré du téléphone) :

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
- [ ] **Déconnecté** puis lien : doit passer par la connexion et **arriver sur
      la publication** une fois connecté.
- [x] Non-régression vérifiée le 2026-08-04 : lancement par le launcher
      (`monkey -c android.intent.category.LAUNCHER`) → l'app arrive bien sur
      l'accueil, aucun ancien lien n'est rejoué.
- [ ] Lien vers un post supprimé ou un id inexistant : vérifier que
      `PostDetailScreen` dégrade proprement au lieu de planter.
- [ ] Lien de profil `https://diasponiger.com/p/u/<uid>` : la route de
      redirection existe déjà, vérifier qu'elle mène bien au profil.
- [ ] Limite connue : le schéma `diasponiger://feed/<id>` **ne marchera pas**
      (Flutter ne lit que le chemin de l'URI, et « feed » y est l'hôte). Les
      liens partagés étant en `https://`, ça ne bloque rien — mais le raccourci
      `diasponiger://design-v2` du README de `design_v2` ne fonctionne pas non
      plus, pour la même raison.

**À faire hors appareil :**

- [x] ✅ **Hosting déployé le 2026-08-04**, après rapatriement — voir plus bas.
      Le blocage décrit ci-dessous est **levé**, il est conservé pour mémoire.
- [ ] ⛔ *(historique)* **`public/` était un vestige** : la production n'avait
      **jamais** été déployée depuis ce dépôt. Les 8 fichiers versionnés étaient
      plus pauvres que ceux en ligne (contenu comparé hors fins de ligne) :

      | Fichier | Dépôt | En ligne |
      |---|---|---|
      | `privacy-policy.html` | 3 917 car. | 32 342 |
      | `terms-of-service.html` | 14 263 | 43 082 |
      | `child-safety-standards.html` | 20 140 | 34 798 |
      | `delete-account.html` | 16 108 | 24 550 |
      | `index.html` | 14 319 | 36 483 |
      | `contact.html` | 6 072 | 18 658 |
      | `forgot-password.html` | 4 608 | 14 067 |
      | `.well-known/apple-app-site-association` | 158 | 508 |

      Un déploiement remplacerait la politique de confidentialité, les CGU, la
      page de suppression de compte et la page sécurité des enfants — toutes
      exigées par le Play Store — par des versions courtes et obsolètes, et
      amputerait l'AASA (Universal Links iOS). Le déploiement Firebase est
      atomique : impossible de n'envoyer que `assetlinks.json`.

      S'y ajoutaient **9 fichiers servis en production et totalement absents du
      dépôt** — toutes les versions anglaises (`*-en.html`) et le code de
      conduite (`code-of-conduct.html`, `code-of-conduct-en.html`) — ainsi que
      les 9 rewrites sans extension correspondants, absents de `firebase.json`.

      Résolu : les 21 fichiers réellement servis ont été récupérés depuis
      `diasponiger.web.app` (contenu identique sur les deux sites, vérifié
      fichier par fichier) et versionnés, `assetlinks.json` réappliqué
      par-dessus, rewrites complétés. Avant déploiement, `public/` ne s'écartait
      de la production que par ce seul fichier.
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
- [ ] Après déploiement, **forcer la revérification** : Android ne contrôle les
      App Links qu'à l'installation, un fichier corrigé plus tard ne change rien
      pour une app déjà installée.

      ```
      adb shell pm verify-app-links --re-verify com.diasponiger.diasponiger
      adb shell pm get-app-links com.diasponiger.diasponiger
      ```

      La seconde commande doit afficher `verified` pour `diasponiger.web.app` et
      `diasponiger.com`.
- [x] Empreinte de la clé **release locale** (`DD:A6:5C:…`, cf.
      `gradlew signingReport`) ajoutée sous `com.diasponiger.diasponiger` —
      décision de Salim, pour tester les liens sur un APK release installé à la
      main sans passer par le Play Store. Élargit d'autant qui peut revendiquer
      le domaine : à retirer si la keystore venait à circuler.

---

## Fuseau horaire — heures affichées en UTC (2026-08-04)

Bug constaté sur appareil (SM A515F, `America/Toronto` = UTC-4) : une
publication créée à 02:01 s'affichait « 06:01 ». Les dates étaient
désérialisées avec `DateTime.parse` sur des chaînes ISO terminées par `Z`,
donc en UTC, et `DateFormat` imprime les composantes telles quelles.

Corrigé en normalisant **à la désérialisation** (tout `DateTime` sortant d'un
modèle est local, cf. `lib/core/utils/date_parsing.dart`) et en réencodant
en UTC explicite à la sérialisation. 21 tests unitaires couvrent la
régression, mais rien de tout cela ne prouve le rendu réel : à vérifier sur
appareil, **hors du fuseau UTC**.

**Vérifié sur appareil le 2026-08-04** (SM A515F, `America/Toronto`, APK du
04:13 qui contient bien le correctif — symboles `parseLocalDate` /
`LocalDateTimeConverter` retrouvés dans `kernel_blob.bin`). Chaque affichage a
été comparé à la valeur réelle en base via `supabase db query --linked` :

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
- [ ] Commentaires, notifications, événements (début/fin), appels (journal),
      stories : mêmes vérifications — pas de données sur le compte de test.
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

⚠️ **Vérifié en test unitaire uniquement — jamais sur appareil.** Décision
prise avec Salim le 2026-08-04 : l'essai réel imposerait de reconstruire
l'APK, ce qui vide les données du téléphone (re-onboarding, session Firebase
perdue, reconnexion par SSO Google). À refaire le jour où une réinstallation
est de toute façon nécessaire :

- [ ] mode avion + démarrage à froid : l'accueil s'affiche en quelques
      secondes, plus en ~2 min
- [ ] mode avion + « Le fil » : les publications en cache s'affichent, avec le
      bandeau « contenu hors ligne », au lieu des squelettes
- [ ] retour du réseau : le contenu frais remplace le cache sans action
- [ ] réseau lent mais fonctionnel : vérifier que les bornes (8 s / 10 s) ne
      dégradent pas un chargement légitime

Sans objet : le fil principal (`post_card`) affiche un temps **relatif** via
`timeago`, calculé sur l'epoch — il n'a jamais été affecté, et rien n'y est à
vérifier.

**Données déjà en base : audité le 2026-08-04, rien à reprendre.**
Les écritures antérieures partaient parfois sans suffixe de fuseau, et Postgres
les a enregistrées comme de l'UTC. Audit exécuté sur le projet
`zyrfkcjjrhddpfxcgezo` via `supabase db query --linked`, en comparant chaque
colonne écrite par le client à un `created_at` posé par le serveur :

| colonne | lignes fautives | total |
|---|---|---|
| `group_requests.processed_at` | **1** | 1 |
| les 11 autres colonnes auditées | 0 | — |

L'unique ligne fautive date du 2026-05-26, avec un écart de 3 h 15 —
signature d'un `processed_at` écrit 45 min après la création avec les
composantes locales de Toronto (UTC−4). Aucun horodatage dans le futur, donc
aucune trace d'écriture depuis un fuseau à l'est d'UTC.

Décision : **on ne répare pas**. Une seule ligne de test concernée, et le
décalage n'est enregistré nulle part — il n'existe pas de correction uniforme
applicable à des utilisateurs répartis sur plusieurs fuseaux.

---

## Fiches d'écrans (Claude Design) — reprise écran par écran (2026-08-04)

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
- [ ] **20b — « CET APPAREIL » absent** : sur le SM A515F, aucun des deux
  appareils listés n'est reconnu comme l'appareil courant (`getCurrentDevice`
  renvoie null ou un id absent de la liste). Probablement les `adb install -r`
  qui vident les données sans rejouer l'enregistrement E2EE — à confirmer sur
  une installation qui n'a pas été écrasée. Un bandeau d'avertissement le
  signale en attendant.
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
  ⚠ Le premier essai ne sauvegardait **rien** : `dispose()` appelait
  `ref.read(...)`, ce qui lève, et `main.dart` renvoyant `FlutterError.onError`
  vers Crashlytics, l'exception n'apparaissait **ni dans logcat ni à l'écran**.
  Corrigé en capturant le notifier à l'`initState` + autosave débounce 800 ms.
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
- ⚠ **Piège de build** : après une dizaine d'`adb install -r` d'affilée, un
  APK est sorti avec un **paquet d'assets corrompu** — toutes les icônes
  Material rendues en idéogrammes CJK, les SVG absents, et des écrans en
  erreur. Ce n'était **pas** une régression de code : le même build cassait
  aussi des écrans non modifiés. `flutter clean` + rebuild règle le
  problème. Vérifier sur un second écran avant d'accuser son propre
  changement.
- ⚠ **Publication de test à supprimer** : un post public « Publication de test
  pour verifier l affichage de Mes publications - a ignorer #DiasporaNiger » a
  été publié le 2026-08-04 depuis le compte `Sim A.` pour valider 5b/5c. Il
  est **toujours en ligne** et visible dans le fil de la diaspora.

---

## Session du 2026-08-03 (soir) — SM A515F, refonte enfin lancée

**Première exécution de la refonte sur appareil.** Build `assembleDebug` en
90 s, installation et lancement sans incident, **zéro exception Flutter**
au démarrage (`E/flutter`, `EXCEPTION CAUGHT`, `RenderFlex overflowed` :
aucun).

**Vérifié sur l'écran d'accueil, en thème sombre :**

- [x] Le titrage serif rend correctement (« Bonjour, **Sim** »).
- [x] Le bandeau de complétude (§11f) s'affiche : barre terracotta, « 2/5 »,
      message contextuel et action « Ajouter ma ville ».
- [x] La carte « POUR COMMENCER » rend ses trois amorces avec leurs
      sous-titres — c'est la localisation ARB de cette session, en vrai.
- [x] Grille de services, barre de navigation basse, ligne de contexte.
- [x] Le thème sombre est lisible partout sur cet écran : aucun jeton clair
      figé n'est ressorti.

**Défaut trouvé et corrigé dans la foulée** — puce orpheline en tête de la
ligne de contexte (« · 0 membres · 0 groupes ») pendant la fenêtre où la
géolocalisation n'a pas encore résolu. La puce ne sert qu'à séparer du lieu ;
sans lieu, elle s'affichait seule. Corrigé dans `home_screen_widgets.dart`.
Une fois Montréal résolu, la ligne est correcte.

**Ni analyze ni relecture ne pouvaient trouver ça** : il fallait le premier
lancement d'un compte sans ville renseignée.

**Carte (§7d) — trois incidents à l'ouverture, deux traités**

- [x] `RenderFlex overflowed by 179 pixels on the right`
      (`map_screen.dart:3413`) : la rangée du volet des membres alignait deux
      libellés de temps relatif (« mis à jour il y a… ») côte à côte, sans
      possibilité de rétrécir. Les deux passent en `Flexible` + ellipse.
- [ ] `RenderFlex overflowed` en bas : **cause racine trouvée le 2026-08-03**,
      correctif non appliqué faute d'arbitrage.

      Le widget est enfin identifié — `Column` à `map_screen.dart:3379` —
      mais seulement après avoir soldé le débordement horizontal : Flutter
      n'imprime le détail que de la **première** erreur de rendu par frame.
      Tant que la ligne des horodatages débordait, celui-ci restait réduit à
      « Another exception was thrown ».

      Cette colonne est le contenu du `DraggableScrollableSheet`, replié à
      `initialChildSize: 0.18` — **18 % de la hauteur d'écran, trop court
      pour son propre en-tête**. Ce n'est pas un défaut de mise en page mais
      un dimensionnement : le volet replié ne peut pas contenir ce qu'on lui
      demande d'afficher.

      ✅ **Soldé le 2026-08-03 — plus aucun débordement sur la carte.**
      Trois changements, vérifiés ensemble sur le SM A515F : le tri passe de
      « Les plus proches » à « Proximité » (et cesse d'être en dur), le titre
      du volet prend `maxLines: 1` + ellipse, et `minChildSize` monte de 0.18
      à 0.38. Journal de lancement : **0 `overflowed`**.

      ⚠️ **Un défaut cosmétique subsiste** : le titre s'affiche « Memb… ».
      La rangée d'en-tête reste trop étroite pour lui — les trois contrôles
      de droite (« Aucun membre », « Liste », « Proximité ») occupent
      légitimement les deux tiers de la largeur. Ce n'est plus une erreur de
      rendu, juste une mise en page à revoir : **déplacer les contrôles sur
      une seconde ligne sous le titre** est la seule vraie solution, et c'est
      une restructuration, pas un réglage.

      Historique conservé ci-dessous, il documente deux impasses.

      🔴 **`minChildSize` relevé le 2026-08-03 : essayé, mesuré, annulé.**
      0.18 → 0.35 ramène le débordement de 146 px à 14 ; 0.38 le supprime
      complètement. Mais le volet, enfin assez haut pour montrer son en-tête,
      **révèle un défaut bien pire** : « Membres à proximité » s'affiche
      **une lettre par ligne**, en colonne le long du bord gauche.

      Le titre est écrasé à une largeur quasi nulle par ses voisins de
      rangée (« Aucun membre », « Liste », « Les plus proches »), qui
      prennent toute la place. C'est le même défaut que le débordement
      horizontal de 12 px encore ouvert — la rangée d'en-tête du volet
      distribue mal sa largeur.

      Le volet trop court **masquait** ce problème. Les deux ne peuvent donc
      pas être traités séparément : relever la hauteur sans corriger la
      répartition de largeur remplace un débordement invisible par un titre
      illisible. `map_screen.dart` est revenu à son état committé.

      ⚠️ **Correction de mon propre diagnostic** : j'avais écrit « mettre le
      titre en `Expanded` ». C'est faux — **il l'est déjà** (ligne 3401). Ne
      pas perdre de temps là-dessus.

      La cause est l'inverse : ce sont les trois contrôles de droite — puce
      « Aucun membre », bascule « Liste », tri « Les plus proches » — qui
      imposent leur largeur intrinsèque. L'`Expanded` ne reçoit que le reste,
      quasi nul, et le titre se replie caractère par caractère.

      **Ordre à respecter** :
      1. faire céder les contrôles de droite — le candidat le plus probable
         est « Les plus proches », le plus long : `Flexible` + ellipse, ou
         icône seule quand la place manque ;
      2. vérifier sur appareil que le titre tient sur une ligne ;
      3. **puis** relever `minChildSize` à 0.38 — valeur déjà mesurée, elle
         supprime le débordement vertical.

      ⚠️ **Deux corrections possibles, toutes deux des décisions de design :**
      relever `minChildSize` / `initialChildSize` (le volet couvre alors plus
      de carte), ou alléger l'en-tête du volet. À trancher avant d'agir.

      Piste écartée en cours de route : passer la ligne des horodatages sur
      deux lignes supprime bien le débordement horizontal, mais **aggrave le
      vertical de 23 px** (146 → 169). Un `Wrap` ne convient pas non plus —
      il donne une largeur non bornée à ses enfants, donc `Flexible` y est
      sans effet et le débordement se déplace à l'intérieur de l'enfant.
- [ ] ⛔ **`assets/map_styles/light.json` et `dark.json` n'existent pas.**
      Ni les fichiers, ni le dossier, ni la déclaration dans `pubspec.yaml` —
      seul l'appel `rootBundle.loadString` existe (`map_screen.dart:228-229`).
      La carte tourne donc **sans style**, en rendu Google Maps par défaut,
      alors que la maquette 8b montre explicitement un style nuit.
      L'échec est attrapé et journalisé, donc rien ne casse — mais la
      fonctionnalité est morte depuis toujours. Créer ces styles est une
      **décision de design** (quelles couleurs, quels POI masqués) : à ne pas
      inventer.

**Groupes (§9c/§9f) — un bug de pluriel français, trouvé par contradiction**

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

**Discussion (§3b/§4a) — le correctif visuel tient, mais l'E2EE ne dit rien**

- [x] Les séparateurs rendent en pastille plate avec filet plein, sans
      dégradé ni ombre : le correctif de `_buildThreadSeparator` est vérifié
      sur appareil (« 26 juil. 2026 », « lundi »).
- [x] En-tête, sous-barre « Médias / ÉCO », composer et accusés de lecture
      rendent sans incident.
- [ ] ⛔ **Cinq bulles affichent « 🔒 Message chiffré » sans explication.**
      Ce sont des messages que l'appareil n'a pas pu déchiffrer — très
      probablement parce que les réinstallations de cette session ont effacé
      les clés locales (comportement déjà connu de `adb install -r`).

      Le problème n'est donc pas la perte de clés, attendue en test, mais ce
      que la personne voit : **cinq fois le même libellé, aucune cause,
      aucune issue**. Or l'ARB contient déjà exactement le bon message —
      `e2eeRestoreNudgeMessage`, « Restaurez vos clés de chiffrement pour
      lire vos messages chiffrés sur cet appareil. »

      ✅ **Câblé le 2026-08-03.** `_buildE2eeRestoreBanner` affiche le
      bandeau dès qu'un message du fil porte le placeholder, avec l'action
      « Restaurer » vers `/settings/security/backup`. Les deux chaînes —
      `e2eeRestoreNudgeMessage` et `e2eeRestoreNudgeAction` — avaient été
      écrites ensemble et n'étaient branchées ni l'une ni l'autre.
      Vérifié sur appareil : le bandeau apparaît au-dessus des messages
      illisibles, et seulement dans les fils concernés.

      Reste à vérifier : que « Restaurer » mène bien à un parcours qui
      **restaure effectivement** les clés. Le bandeau ouvre l'écran de
      sauvegarde ; ce que cet écran sait faire n'a pas été exercé.

**Modifier le profil (§20a) — barre d'en-tête repliée**

- [x] La `SliverAppBar` était figée sur `AppColors.primary` : une fois
      repliée, elle virait au terracotta plein sur toute la largeur, seul
      écran de l'app à le faire, et le jeton ne suivait pas le thème. Elle
      prend maintenant `context.backgroundColor` + `surfaceTintColor`
      transparent. Vérifié replié : fond sombre, seul « Enregistrer » reste
      terracotta — c'est l'action principale, elle doit l'être.

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

**Reste à exercer sur cet appareil** : tous les autres écrans basculés
(profil, config profil, réglages, carte, notifications, recherche,
messagerie), le mode Éco en réception, le brouillon d'épisode, et
`font_scale = 1.1`.

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

## Galerie design_v2 sur appareil (2026-08-03)

Premier passage réel sur le SM A515F. Trois choses ont été **vérifiées**,
et il faut le noter parce que la plupart des points de ce fichier ne l'ont
jamais été :

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

### Ce qui reste à faire, et le chemin pour y arriver

L'accès à la galerie **par deep link ne fonctionne pas**. Deux tentatives,
documentées pour ne pas les refaire :

1. `diasponiger://design-v2` — l'intent lance bien l'activité, mais l'URI
   n'atteint jamais Dart : le log montre `setting initial location /splash`.
2. `flutter_deeplinking_enabled` dans le manifeste — **casse le démarrage**,
   le moteur Dart ne se lance plus du tout. Probablement parce que
   `MainActivity` étend `AudioServiceFragmentActivity` (héritage CallKit).
   Le drapeau a été retiré, l'APK reconstruit et l'app vérifiée comme
   redémarrant.

**Le seul chemin encore crédible est Réglages → Refonte → Galerie design
v2**, qui ne dépend d'aucun intent — mais demande d'être connecté, et
`adb install -r` vide les données à chaque pose d'APK.

- [ ] Se connecter une fois, puis ouvrir la galerie par les réglages.
- [ ] Parcourir les **19 écrans**, en **clair et en sombre** (le thème suit
  le système : basculer depuis le volet Android).
- [ ] Regarder en priorité l'**onboarding** et la **configuration du profil**,
  les deux écrans les plus restructurés, donc les plus susceptibles de
  déborder sur un écran réel.
- [ ] Vérifier les **bulles de message** : le poids du fichier s'ajoute à une
  ligne déjà chargée (durée, point « non écouté », erreur éventuelle).

### Méthode, pour la prochaine fois

- **Toujours `adb shell am force-stop` avant un deep link.** Sur un démarrage
  à chaud, l'intent est livré sans que le routeur rejoue sa redirection.
- **Le signal fiable est `GoRouter: INFO` dans `adb logcat -s flutter`**, pas
  la capture d'écran. Un écran noir peut être le splash (bénin) ou un moteur
  Dart mort (grave) — seule l'absence de log distingue les deux. J'ai
  confondu les deux pendant cette session.
- L'arbre de routes que go_router imprime au démarrage liste **toutes** les
  routes déclarées. Y voir `/design-v2` ne prouve **pas** qu'on y est.

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

## Session appareil du 2026-08-03 — SM A515F, thème sombre, font_scale 1.1

Premier passage réel sur téléphone de toute la reprise du design. Le
téléphone était déjà dans les deux conditions les plus risquées : nuit et
échelle de police 1.1.

**Cinq défauts trouvés, aucun visible à `flutter analyze`.**

- [x] Puce de filtre des notifications : fond `adaptivePrimaryColor` (qui
  s'éclaircit en nuit) + texte `Colors.white` figé → blanc sur orange clair.
  Corrigé en `onPrimaryColor`. **Vérifié à l'écran après reconstruction.**
- [x] « Précédent » tronqué en « Précéd » à l'étape 3/4 de la configuration
  du profil : ratio 1:2 trop serré à font_scale 1.1. Passé à 3:4.
- [ ] Empreinte de clé quasi invisible (écran des appareils) : le texte
  utilisait `theme.colorScheme.outline`, une couleur de **bordure**.
  Corrigé vers `textSecondaryColor` — **non vérifié à l'écran**, l'app a
  redémarré avant que j'y revienne. À confirmer.
- [ ] Texte codé en dur et sans accents sur ce même écran (« jusqu'a 5
  appareils connectes simultanement ») alors que la clé localisée existait
  et n'était pas utilisée. Corrigé — **non vérifié à l'écran**.

### ✅ Anomalie du thème : élucidée, ce n'était pas un bug

L'écran de configuration du profil, puis l'annuaire Business, se sont
affichés en crème alors que je croyais le téléphone en thème sombre.

**Cause réelle : le téléphone était passé en mode clair.** `settings get
secure ui_night_mode` renvoyait `1` au moment des captures, contre `2` au
début de la session — mes séquences de `adb shell input tap` à l'aveugle
ont dû basculer le réglage système en passant par le volet de
notifications.

Confirmé en remettant `cmd uimode night yes` : le même écran de
configuration s'est immédiatement affiché entièrement en sombre, jetons,
puces et bascules compris. **Il n'y a pas de bug de thème, ni sur cet
écran ni sur l'annuaire.** Les deux suivent correctement `adaptive_colors`.

À retenir pour les prochaines sessions : vérifier `ui_night_mode` **avant
et après** chaque série de captures. Piloter l'app par taps aveugles peut
modifier des réglages système et fabriquer de faux défauts visuels.

### ⚠ Redémarrages de l'app pendant les tests : mémoire, pas crash

L'app redémarrait à répétition pendant la navigation. `logcat` montre des
kills `lmkd` et `/proc/meminfo` donnait **122 Mo libres sur 5,7 Go**.
L'APK debug pèse 317 Mo. Après `am kill-all` (612 Mo libres), la
navigation a tenu. Ce n'est pas un crash applicatif.

### ⚠ Ouvert : « Précédent » toujours tronqué

Le passage du ratio 1:2 à 3:4 n'a pas suffi — le bouton affiche encore
« Précéd », sans points de suspension, donc coupé et non ellipsé. Le
routeur pointe pourtant bien sur le fichier corrigé et l'ARB contient
« Précédent » en entier.

Correctif appliqué en second recours : le libellé des boutons de la
trousse est enveloppé dans un `FittedBox(scaleDown)`, pour qu'un mot trop
long **rétrécisse** au lieu d'être coupé. **Non vérifié sur appareil** —
à confirmer au prochain passage.

### ⚠ Encore des accents manquants

« Aucune entreprise trouvee · Soyez le premier a ajouter votre
entreprise ! » sur l'annuaire Business. Même famille que le texte en dur
de l'écran des appareils. Un balayage des littéraux français sans accents
reste à faire sur tout le dépôt.

## Quatrième vague — écrans repris en production (2026-08-03)

Contrairement au bloc ci-dessus, **tout ce qui suit est dans
`lib/features/` et donc exerçable tout de suite**. Aucun de ces écrans n'a
été vu tourner : les jetons de thème ont été raisonnés, pas observés.

### À vérifier en thème sombre en priorité

C'est la famille de défauts la plus récurrente du projet, et cette vague a
converti une centaine de couleurs figées en jetons adaptatifs.

- [ ] **Appareils connectés** (`devices_screen.dart`) et **Sauvegarde des
  clés** (`security_backup_screen.dart`) — 26 couleurs routées, dont des
  fonds `shade50` presque blancs. Ce sont les écrans qu'on ouvre dans le
  noir après avoir perdu son téléphone : vérifier que la carte « sauvegarde
  active », l'avertissement de passphrase et le bouton « Révoquer » restent
  lisibles.
- [ ] **Détail d'un transfert** (`transaction_detail_screen.dart`) — les 20
  couleurs d'état, dont celles qui distinguent « débité mais bloqué » de
  « refusé avant débit ». Provoquer au moins un échec pour voir la couleur
  réelle, pas seulement le cas nominal.
- [ ] **Mes commandes** (`my_orders_screen.dart`) — 9 statuts routés ;
  **teal et violet sont restés figés** faute de jeton équivalent. Regarder
  s'ils jurent en nuit.
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

### Non testable — reste dans `design_v2`

Feuille d'actions sur un message ramenée à cinq entrées avec révélateur
« Autres actions » et rangée de réactions rapides ; états d'enregistrement
vocal (« Glisser ‹ pour annuler · ↑ pour verrouiller », « Relâcher pour
annuler », « Mains libres ») ; deux familles de couleur dans la grille du
composer.

Au moment de la bascule, tester en priorité **les trois états vocaux avec
le doigt**, seule façon de vérifier que le bon libellé s'affiche au bon
moment : le seuil d'annulation est à ~70 px et le verrouillage se fait
vers le haut.

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

- [ ] **Indicateur d'étapes du transfert** (`transfers/…/send_money_screen.dart`,
  les deux copies) : `_kStepUpcoming` recopiait l'ancienne bordure `#E8DFD4`
  et restait donc en beige clair en nocturne ; l'étape à venir passe par
  `colorScheme.outline`. **À vérifier** : ouvrir « Envoyer de l'argent » en
  mode nuit — le rond et la barre des étapes non atteintes deviennent
  nettement plus discrets (`#2A241E` sur `#0F0D0A`). Confirmer qu'on distingue
  encore la piste ; si elle disparaît, basculer sur `outlineVariant`.

- [ ] **Bordure des bulles reçues** (`messages/…/message_bubble.dart`, les deux
  copies) : `_kRecvBorderLight/Dark` figeaient `#EFE7DB` / `#3D352C` ; passe
  par `context.borderColor`. Seul le nocturne change (`#2A241E`). **À
  vérifier** : dans une conversation en mode nuit, la bulle reçue doit encore
  se détacher du fond.

- [ ] **Le tunnel de transfert suit désormais l'accent du compte**
  (`transfers/…/send_money_screen.dart`, les deux copies) : `_kTransferAccent`
  figeait `#B85E24` sur les 5 points d'accent (rond d'étape actif, barre
  franchie, bouton principal, puce de montant rapide), toujours avec du
  `Colors.white` en dur. Tout passe par `colorScheme.primary` /
  `colorScheme.onPrimary`. **C'est un changement de comportement assumé, pas
  seulement un correctif** — trois choses à regarder :
  1. **Compte en accent vert** : le tunnel devient vert. C'était orange pour
     tout le monde jusqu'ici. Vérifier que rien ne jure avec le reste de
     l'écran.
  2. **Compte en accent orange** : ~~la teinte glisse de `#B85E24` à
     `#E07B39`~~ — plus vrai. `colorScheme.primary` du thème orange est
     passé à `#B85E24` juste après (voir la section suivante), donc en clair
     le tunnel garde exactement sa teinte d'avant. Rien à vérifier ici.
  3. **Mode nuit** : l'accent s'éclaircit et le texte dessus devient de l'encre
     foncée au lieu du blanc — c'est la règle du guide. Confirmer sur le rond
     d'étape (chiffre + coche), le bouton « Continuer » et son spinner.

## Accent orange du thème clair — `#E07B39` → `#B85E24` (2026-08-03)

- [ ] **L'orange d'action de toute l'app change de teinte**
  (`lib/core/theme/app_theme.dart`) : les 17 liaisons qui exprimaient l'accent
  orange pointaient sur `AppColors.primary` (`#E07B39`) ; le guide de style
  désigne `#B85E24` (`primaryDark`) comme « Orange — action ». Elles passent
  toutes sur `primaryDark`, dans les deux thèmes clairs — accent du thème
  orange, et orange secondaire du thème vert. **C'est le changement le plus
  visible de la session** : il touche boutons pleins et contour, boutons
  texte, FAB, barre de navigation basse, onglets, interrupteurs, cases à
  cocher, radios, barres de progression et bordure de champ au focus.
  **Vérifié sur SM A515F le 2026-08-03** (build de `ebc3716`, thème orange,
  mode clair forcé en adb puis restauré). Couleurs relevées au pixel sur les
  captures, pas jugées à l'œil — `#B85E24` exactement sur : bouton plein
  « Compléter ma bio », barre de progression du profil, onglet actif de la
  navigation basse, bouton composer de la messagerie, icône d'information,
  bordure de champ **au focus**. Fond `#FAF7F2` et surface `#FFFFFF`
  conformes au guide.
  1. [x] **Le blanc sur l'accent** : franc, et mesurable — le contraste blanc
     sur `#B85E24` est de **4,50:1** (AA pour le texte courant), contre
     **2,97:1** sur l'ancien `#E07B39`, qui échouait même au seuil du grand
     texte. C'est le vrai gain du changement.
  2. [x] **Bordure de champ au focus** : nette, ~4 px réels de `#B85E24` sur
     le crème. Ma crainte que les traits fins s'assombrissent de trop ne se
     confirme pas.
  3. [ ] **Coche, piste d'interrupteur, indicateur d'onglet** : pas atteints
     pendant la session. Même jeton que les éléments ci-dessus, donc même
     valeur — mais l'épaisseur du trait n'a pas été jugée.
  4. [ ] **Thème vert** : non vérifié, le compte de test est en accent
     orange.
- [ ] **Dégradés inchangés, volontairement** : `AppColors.primary`
  (`#E07B39`) reste la teinte claire de la famille orange et continue
  d'ouvrir `primaryGradient` (`#E07B39` → `#B85E24`). Un dégradé qui part
  d'un ton plus clair que l'accent est normal, mais si un bandeau paraît
  désormais désaccordé avec les boutons, c'est là qu'il faut regarder. Aucun
  écran à dégradé n'a été ouvert pendant la session.
- [x] **Thèmes sombres non touchés** : vérifié sur l'appareil — l'accent
  nocturne reste `#F4A574` (pictogrammes, libellés de section, onglet actif).
  Aucun changement en mode nuit, comme attendu.
- [ ] **Bordure forte `#E0D6C6` sur les puces au repos** : c'est le point que
  j'avais désigné comme le plus à risque, et il **n'a pas été atteint**
  (`DesignSelectableChip` vit dans la configuration du profil,
  `DesignSecondaryButton` dans ses barres de navigation). Les puces de filtre
  de la messagerie, elles, utilisent la bordure fine `#EFE7DB` : visible sur
  la capture, leur contour est très discret, la puce ne tient que par son
  aplat blanc sur le fond crème. À trancher en voyant la configuration du
  profil.

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

## Bascule design_v2 → production, famille 2 : les services (2026-08-03)

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

## Bascule design_v2 → production, famille 3 : boutique, support, transferts, appels (2026-08-03)

Dix écrans de plus dans `lib/features/`, jamais vus tourner :

- [ ] **Boutique** (§12b, §16a, §16b, §16h) : liste, fiche produit, panier.
- [ ] **Support** (§22a→22d) : nouveau ticket, mes demandes, suivi, état vide.
- [ ] **Transferts — accueil et historique** (§16i, §16c). La **frise
  « Débité → En route → Disponible »** de l'historique est le point à
  regarder : elle ne doit apparaître que sur les transferts qui ont un
  trajet, pas sur un échec ou un remboursement.
- [ ] **Historique d'appels** (§13c) et **création de podcast** (§2c).
- [ ] ⚠️ **`send_money_screen` n'est pas dans ce lot** : il attend une fusion,
  pas une copie. Ne pas conclure d'un tunnel d'envoi correct que la bascule
  des transferts est complète.

## Bascule design_v2 → production, famille 4 : messagerie, groupes, recherche, profil (2026-08-03)

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
- [ ] **Non-régression du mode « données réduites »** : `DataSaverGate` a
  traversé la bascule (vérifié dans le fichier). Confirmer sur l'appareil
  qu'un média reçu reste flouté avec son bouton « Télécharger » quand le mode
  est actif.
- [ ] **Groupes** (§9c, §9d, §9f) et **notifications** (§12c).

## Bascule design_v2 → production, famille 5 : accueil et envoi d'argent (2026-08-03)

- [ ] **Accueil** (§8a) : c'est l'écran d'ouverture de l'app, donc le plus vu
  de tous. Vérifier le squelette de chargement au moment d'« Élargir à
  200 km » — il doit remplacer la carte « Personne à moins de 50 km » pendant
  la recherche, jamais la laisser affichée.
- [ ] **Envoi d'argent** (§12a) : la barre de titre passe en serif plat. Le
  reste de l'écran (montant en très grand, frais, total, taux) était déjà en
  production — vérifier qu'il n'a pas bougé.
- [ ] **Accents du tunnel d'envoi** (2026-08-03) : 15 chaînes réparées —
  « Réinitialiser », « Ajouter un bénéficiaire », « Récapitulatif », « Montant
  envoyé », « Total débité », « conditions générales », « Transfert initié
  avec succès ». À relire **sur l'appareil**, aux trois étapes du parcours :
  un accent qui sort en tofu (□) ou en mojibake ne se voit pas dans le code,
  seulement au rendu. Vérifier au passage que « Récapitulatif » et « Montant
  à recevoir » tiennent toujours sur une ligne à `font_scale = 1.1` — un
  accent ajoute de la hauteur, pas de la largeur, mais les libellés
  s'allongent d'un caractère.
- [ ] **Accents du choix et de l'ajout de bénéficiaire** (2026-08-03) :
  32 chaînes de plus sur `add_recipient_screen` et `recipient_select_screen`.
  Les libellés de champs (« Numéro de téléphone \* », « Opérateur mobile \* »)
  et les messages de validation sont les plus exposés — un `labelText` trop
  long passe en ellipse sans prévenir. Vérifier aussi les trois SnackBars
  (« Bénéficiaire ajouté/modifié/supprimé avec succès »).
- [ ] **La ville reste sans accent, exprès** : « Tillaberi » dans la liste de
  `add_recipient_screen` alimente le champ `city` enregistré en base.
  Vérifier au passage qu'un bénéficiaire créé avant aujourd'hui affiche
  toujours sa ville correctement.

## Bascule design_v2 → production : la carte (§7e, 2026-08-03)

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
- [ ] **Non-régression des couleurs** : les deux passes de jetons adaptatifs
  (`94d721c`, `bdcd795`) sont dans le fichier basculé. Regarder la carte en
  **thème sombre** — libellés sur l'accent, puces de rayon et de filtre
  sélectionnées, pastille de la légende.

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

## Profil & Accueil (avant la refonte design)

- [ ] **Réalignement Profil/Accueil pré-refonte** (commit `7110929`) : 4ᵉ stat « posts », sections COMPTE/CONFIDENTIALITÉ/SÉCURITÉ/APPELS/PRÉFÉRENCES/AIDE réintroduites, `FollowsScreen`, bouton QR de l'accueil réactivé, service « Fil d'actualité » — aucune vérification device mentionnée.

## Assistant de configuration du profil

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
- [ ] **Remontée des échecs Firestore à l'UI** (correctif du 2026-08-03,
  `profile_remote_datasource.dart` + les deux `profile_config_screen.dart` et
  `settings_screen.dart`) — **non vérifié sur appareil**, la validation
  demande une réinstallation. Trois cas à couvrir :
  - **refus serveur** (le cas actuel, `PERMISSION_DENIED`) : « Terminer »
    doit maintenant afficher un snackbar rouge avec action « Réessayer », et
    l'assistant **ne doit pas** se marquer comme terminé ;
  - **hors ligne** : aucun message d'erreur ne doit apparaître — l'écriture
    est en file d'attente, ce n'est pas un échec. ⚠️ le VPN persistant du
    téléphone rend ce cas difficile à provoquer (cf. bas de page) ;
  - **cas nominal** : l'enregistrement doit rester fluide, sans latence
    ajoutée perceptible (une lecture serveur supplémentaire a été ajoutée
    après chaque écriture de profil).
- [ ] **Persistance des valeurs saisies dans l'assistant** : après la
  relance, l'accueil affiche toujours « Complétez votre profil 2/5 » et
  « Ajouter ma ville » — les champs de l'assistant (nom, pays/ville,
  centres d'intérêt) ne semblent pas avoir été enregistrés côté serveur, ce
  qui est cohérent avec le `PERMISSION_DENIED` ci-dessus. À revérifier une
  fois le rejet Firestore corrigé.
- [ ] **Étape 3/4 « Choisissez-en au moins deux »** : le bouton « Suivant »
  reste actif et laisse passer avec « Aucun sélectionné ». Soit la contrainte
  est réelle et il faut la faire respecter, soit la copie est fausse.

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
