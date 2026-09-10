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

## ⬜ Inviter des membres dans un groupe privé (2026-09-09)

Signalé par Salim : « pour les groupes privés j'arrive pas à ajouter d'autres
membres ». Il n'y arrivait pas parce que **l'app n'offrait nulle part de quoi
le faire** — `GroupInviteNotifier.inviteUser` existait, le datasource Supabase
écrivait bien `group_invites`, l'invité voyait l'invitation dans l'onglet
Groupes et l'acceptation l'inscrivait dans `group_members` : tout le chemin
était là, sauf l'écran qui l'appelle. Quatre traductions
(`inviteMember`/`inviteSent`/`inviteAlreadySent`/`inviteError`) attendaient
depuis le début, sans un seul usage dans le code.

Sur un groupe **public** le manque se contournait — on partage le lien, la
personne appuie sur « Rejoindre ». Sur un groupe **privé**, le lien ne produit
qu'une demande d'adhésion à approuver : l'administrateur n'avait donc aucun
moyen d'aller chercher quelqu'un.

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

**Sécurité fermée au passage — à rejouer après `supabase db push`.** La porte
d'entrée de `group_members` (20260806210000) laissait une porte latérale :
`group_invites_own` autorise à INSÉRER une invitation **dont on est soi-même
le destinataire**, pour n'importe quel groupe. Deux appels d'API suffisaient
donc pour entrer dans un groupe privé sans y avoir été invité — vérifié le
2026-09-09 sous une identité réelle, dans une transaction annulée. Fermé par
`20260909201500_invitations_groupe_porte_laterale.sql` (garde RESTRICTIVE à
l'INSERT, trigger qui fige `group_id`/`invitee_id`, et `has_group_invite()`
qui ne compte plus une invitation refusée).

Banc rejouable, transaction annulée, rien n'est écrit :

```bash
supabase db query --linked "$(cat supabase/diagnostics/2026-09-09_invitations_groupe.sql)"
```

Sortie attendue : « banc termine ». Tout « ECHEC n » interrompt le banc.

---

## ⬜ Aucun marqueur technique dans une bulle (2026-09-09)

Constaté sur SM A515F (capture du 2026-09-09, 19:02, groupe « Diaspora
Niger ») : un fil de groupe affichait trois bulles « *Message chiffré — clé de
groupe introuvable* » avec un bouton « Récupérer la clé de groupe », et une
quatrième « [Message illisible] ». Demande explicite de Salim : ne plus voir
ni l'un ni l'autre, et retrouver le texte précédent.

Deux choses corrigées, de nature différente.

**1. `[Message illisible]` échappait à toutes les gardes.** Écrit en dur dans
quatre fichiers et absent de `kUndecryptablePlaceholders`, il traversait les
trois protections qui s'appuient sur cette liste : le soin depuis le cache
(`_healUndecryptableMessages`), la fusion de l'écho temps réel
(`reconcileEchoContent`) et le bandeau de restauration. Pire, le soin le
prenait pour du **contenu valide** et le réécrivait par-dessus le texte déjà
déchiffré — le cache local perdait le clair, définitivement, le serveur ne
pouvant pas le rendre une seconde fois (ratchet Signal / Sender Key).
Quatrième trou de la même famille : `syncMessagesIncremental` écrivait en
cache **sans** passer par le soin.

**2. La bulle n'affiche plus de vocabulaire interne.** Les trois marqueurs
mènent désormais à `UndecryptableMessageBubble` — « *Message indisponible sur
cet appareil* », en gris, sans bouton. `E2EESessionRequiredBubble` (et son
bouton « Récupérer la clé de groupe ») n'est plus branchée nulle part ; le
remède reste porté **une seule fois** par le bandeau en tête de discussion
(`_buildE2eeRestoreBanner`), au lieu d'être répété sur chaque bulle.

Fichiers : `lib/core/services/e2ee/undecryptable_placeholders.dart`,
`lib/core/services/encryption_service.dart`,
`lib/core/services/e2ee/session_backup_service.dart`,
`lib/features/messages/data/repositories/message_repository_impl.dart`,
`lib/features/messages/presentation/widgets/message_bubble.dart`,
`lib/features/messages/presentation/widgets/undecryptable_message_bubble.dart`.

À vérifier **sur SM A515F** :

- [ ] Le fil de la capture n'affiche plus « Message chiffré — clé de groupe
      introuvable », ni le bouton « Récupérer la clé de groupe », ni
      « [Message illisible] » : une ligne grise « Message indisponible sur cet
      appareil » à la place.
- [ ] **Le vrai test du correctif** : ouvrir une discussion lisible, la
      quitter, y revenir, faire un pull-to-refresh, remonter d'une page. Le
      texte doit rester lisible — c'est le chemin où le soin depuis le cache
      opère. Avant, un message pouvait basculer en marqueur et ne plus jamais
      revenir.
- [ ] Envoyer un message dans un groupe et attendre l'écho temps réel : la
      bulle garde son texte (c'est `reconcileEchoContent`, désormais au
      courant du troisième marqueur).
- [ ] Une photo **sans légende** s'affiche normalement — la garde lit la
      LISTE, pas `isUndecryptableContent`, qui tient le vide pour illisible et
      masquerait chaque média sans légende.
- [ ] Thème sombre : la ligne grise reste lisible (jetons `textTertiaryColor`
      / `iconTertiaryColor`, pas de teinte figée).
- [ ] ⚠️ Le cache local **fusionne**, il ne se vide pas : un message déjà
      empoisonné par `[Message illisible]` avant ce correctif le reste. Pour
      juger, viser un message encore lisible aujourd'hui, ou vider la
      discussion.

**Build installé le 2026-09-09 à 19:18 (SM A515F) et 19:28 (Pixel 10 Pro XL).**
`1.2.1+17` release arm64, même certificat que l'installé
(`DD:A6:5C:…:CF:5D`) donc `install -r` sans désinstallation : session, clés et
cache conservés. APK vérifié avant installation — « Message indisponible sur
cet appareil » présent 1 fois dans `libapp.so`, et « Récupérer la clé de
groupe » **absent** (0 occurrence) : le tree-shaking a retiré
`E2EESessionRequiredBubble` du binaire, preuve indépendante qu'elle n'est plus
référencée.

Vérifié :
- [x] Une conversation 1:1 avec du contenu s'affiche normalement — texte en
      clair, note vocale, carte de position, aucun placeholder (Pixel, 19:31).
- [x] Les médias **sans légende** ne sont pas détournés par la garde : un fil
      de 4 vidéos s'affiche intact (SM A515F, 19:20). C'était le risque du
      choix « la LISTE plutôt qu'`isUndecryptableContent` ».

⛔ **Le symptôme d'origine n'a PAS pu être rejoué.** Le groupe « Diaspora
Niger — Canada » du signalement affiche maintenant « Aucun message » (3
membres) : les quatre bulles fautives ont disparu entre la capture de 19:02 et
la réouverture de 19:29. Piste, à confirmer : sur la capture de 19:02
elle-même, la **liste** des discussions annonçait déjà « Nouvelle
conversation » pour ce groupe — donc elle le tenait déjà pour vide pendant que
le fil ouvert montrait quatre bulles. Ces bulles venaient vraisemblablement du
cache local, sans rien derrière côté serveur ; au redémarrage, le fil a
re-interrogé le serveur et n'a rien trouvé. Le correctif ne peut pas supprimer
de message (il ne substitue qu'un texte et un widget), mais **cette
disparition n'est pas expliquée avec certitude** — à creuser si elle se
reproduit.

Reste donc à voir **au moins une fois** la nouvelle bulle, et surtout à
exercer le vrai chemin du correctif : envoyer un message dans un groupe,
quitter la discussion, y revenir, faire un pull-to-refresh.

---

## ⬜ Compte de test dédié : première connexion (2026-09-09)

`scripts/creer_compte_test.js` crée — ou réinitialise — un compte Firebase
Auth séparé du compte personnel (`test.diaspo@example.com`, mot de passe tiré
au hasard et affiché une seule fois à l'exécution).

Vérifié **hors appareil**, en rejouant la chaîne de la première connexion :
`signInWithPassword` accepte les identifiants, `auth-firebase-exchange` rend
une session, et la ligne `users` existe avec `display_name = "Compte Test"`.

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

⚠️ Constaté pendant la création : **le tout premier appel à
`auth-firebase-exchange` pour un compte neuf répondait 401 « Email link is
invalid or has expired »** — la tentative suivante réussissait. Dans l'app,
`_scheduleRetry()` repasse 5 s plus tard : le premier lancement d'un compte
neuf avait donc ~5 s de session anonyme avant que les données n'arrivent, et
ça touchait **tout compte neuf**, pas seulement celui-ci.

**Corrigé le 2026-09-09**, la cause n'était pas celle qu'on croyait : ce n'est
pas `updateUserById` qui invalidait le lien. `generateLink({type:'magiclink'})`
ne rend un lien `magiclink` que si l'utilisateur **existe déjà** ; sur un
compte neuf, gotrue le crée et rend un lien **`signup`**, dont le jeton part
dans `confirmation_token` — là où `verifyOtp({type:'magiclink'})` fouille
`recovery_token`. La fonction lit désormais le type dans la réponse
(`typeEmis()`) au lieu de l'écrire en dur.

Vérifié hors appareil par `tools/sonde_echange_auth.mjs`, qui rejoue la
séquence contre le gotrue de production : témoin (type figé) en échec,
correctif en session valide avec le claim `firebase_uid` dès la première
tentative. Confirmé bout-en-bout sur des comptes **Firebase** neufs
(`signInWithPassword` → Edge Function) : la version en production rendait 401
puis 200, la corrigée rend une session au premier coup.

Le même message d'erreur a une **seconde** cause, mesurée au passage : deux
`generateLink` de suite sur un compte existant écrivent dans la même colonne et
le second invalide le jeton du premier, donc deux échanges concurrents (deux
appareils, deux isolats Edge) se sabotent l'un l'autre — `_inFlightSync` ne
dédoublonne qu'au sein d'un processus. L'étape 5 retente donc **une** fois avec
un lien frais ; la 3e mesure du banc couvre ce cas.

✅ **Déployé le 2026-09-09** et vérifié contre la fonction réelle, sur un
compte Firebase créé pour l'occasion : le **premier** échange rend une session
(c'est exactement l'appel qui répondait 401), le JWT porte le claim
`firebase_uid`, et la ligne `users` se lit avec le jeton du compte. La
fonction est aussi épinglée à `supabase-js@2.116.0` depuis ce déploiement —
elle n'importe plus `@2`, qui rebundlait au dernier 2.x du jour.

La reprise de l'étape 5 ayant été écrite **après** ce premier déploiement, la
fonction a été redéployée dans la foulée : la production porte donc les deux
correctifs (mauvais type d'OTP **et** reprise sur refus). Revérifié après ce
second déploiement, encore sur un compte Firebase neuf, même résultat.

⚠️ Le déploiement d'une Edge Function est **fichier par fichier** : ce qui est
en ligne, c'est le dernier `deploy` de CE fichier, pas l'état de la branche.
Pour comparer sans supposer : `supabase functions download <nom>
--project-ref <ref>` — mais il **écrase la copie de travail** au lieu d'écrire
ailleurs, donc le faire sur un dépôt propre et relire par `git diff`.

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

## ⚠️ Rapatriement iOS : deux dépendances **Android** changent de version majeure (2026-09-08)

Le travail iOS de `claude/ios-support` — première compilation de la cible,
parité native Swift (identifiant d'appareil E2EE, notifications), et
« Se connecter avec Apple » — vivait sur sa branche depuis le 2026-09-02 sans
jamais être rapatrié. Il l'est maintenant. Il emporte deux montées de version
majeures qui **ne sont pas propres à iOS** : elles partent aussi dans l'APK
Android.

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

Le verrou `pubspec.lock` a été repris de la branche partagée puis résolu à
nouveau, pour que **seuls** ces trois paquets bougent : la fusion brute le
faisait régresser sur une quinzaine d'autres (et abaissait la contrainte SDK
à `dart >=3.10.0`), et un `pub upgrade` en déplaçait 136.

**Suite, le soir même : la montée cassait le build Android**, et ni
`flutter analyze` ni les 445 tests ne pouvaient le dire — seul
`flutter build apk` tombe. `mobile_scanner` 7.4.0 réclame `androidx.camera`
1.6.x, qui exige l'AGP 8.9.1+ quand le projet était en 8.7.0 :

    Dependency 'androidx.camera:camera-core:1.6.1' requires
    Android Gradle plugin 8.9.1 or higher.

Épingler `androidx.camera` en 1.4.2 (à la manière du `force(...)` mlkit déjà
en place) ne sauve rien : le plugin utilise alors des API absentes de cette
série et c'est lui qui ne compile plus. Corrigé en montant l'outillage —
**AGP 8.10.1** (l'API 36 déjà ciblée le demande de toute façon) et **Gradle
8.13** (l'AGP 8.10 exige au moins 8.11.1). Le build debug passe et tourne sur
les deux appareils (md5 `18e2a33a19fca981463e0f44d82966ff`).

Ce qu'une montée d'AGP peut changer sans prévenir, et qui ne se voit qu'au
dépôt en Play Console :

- [x] **`flutter build apk --release`** passe encore (signature, R8,
      shrinking) — vérifié le 2026-09-09 sur SM A515F : `assembleRelease` en
      656 s, APK de 168 Mo, versionCode 17, signé par
      `android/app/diaspo-niger-release.jks` (`DD:A6:5C:3E…CF:5D`, l'empreinte
      que Play attend), R8 actif — le paquet installé n'a plus le flag
      `DEBUGGABLE`. Posé et lancé, md5 sur l'appareil identique au fichier
      local (`9ee1f712…`).
- [ ] **Le bundle `.aab`** passe encore : non revérifié depuis la montée d'AGP.
      C'est lui que vise l'alignement 16 Ko ci-dessous.
- [ ] **Alignement 16 Ko** toujours bon :
      `python tools/verifie_alignement_16k.py build/app/outputs/bundle/release/app-release.aab`.
- [ ] **Le `force("com.google.mlkit:barcode-scanning:17.3.0")`** porte la note
      « à retirer quand mobile_scanner sera monté en 6.x/7.x » — c'est fait.
      À réévaluer, sans jamais sauter la vérification ci-dessus.

Les entrées iOS proprement dites — build simulateur, « Se connecter avec
Apple », liens profonds, Supabase — sont plus bas, dans les sections du
2026-09-01, telles qu'écrites à l'époque.

---

## ✅ « Mon QR Code » depuis le scanner (2026-09-08)

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
## ⬜ Transfert des clés par QR, sans passphrase (2026-09-08)

Reprise des clés d'un téléphone à l'autre sans rien à retenir : l'**ancien**
affiche un QR, le **neuf** le scanne, et l'export complet du stockage sécurisé
voyage chiffré en AES-256-GCM par une clé qui ne quitte jamais le canal
optique. Le serveur ne relaie qu'un blob.

⚠️ **Le sens a été inversé le 2026-09-08**, après essai sur les deux téléphones.
L'app n'autorise qu'**une session par compte** (`SessionService` écrit un
`session_id` neuf à chaque connexion, les autres appareils se déconnectent
seuls) : se connecter sur le téléphone neuf éjecte l'ancien à l'instant même.
La première version — le neuf affiche, l'ancien scanne et dépose — ne pouvait
donc **jamais** fonctionner : au moment du dépôt, l'ancien était déjà dehors.
Le dépôt vient maintenant en premier, tant que l'ancien a sa session ; le neuf
scanne **avant de se connecter**, retient le rendez-vous dans le stockage
sécurisé, et `E2EEBackupCoordinator` le reprend juste après la connexion. La
route du scanner est ouverte sans session (garde du routeur), et un lien
« Récupérer depuis mon ancien téléphone » figure sur l'écran de connexion.

Corollaire : plus d'accusé de réception ni d'effacement automatique — l'ancien
sera hors ligne au moment de l'import. L'effacement devient un geste explicite
(« Effacer les clés de cet appareil »), utile avant de donner le téléphone, et
la copie de secours de sept jours le couvre toujours.

La migration `20260908200000_e2ee_key_transfers.sql` **est appliquée** en
production (Salim l'a poussée le 2026-09-08 ; `db push --dry-run` répond
« Remote database is up to date »). La table existe donc, RLS et trigger de
purge compris.

Déjà vu sur SM A515F le 2026-09-08 (build debug
`c47898e6d9e78aedf333b93f751a76a9`), seul, sans second téléphone :

- la section « Changer de téléphone » s'affiche dans Réglages › Sécurité ›
  Sauvegarde des clés, au-dessus de la sauvegarde existante ;
- l'écran de récupération affiche le QR et « En attente de l'ancien
  téléphone… » ;
- l'écran de transfert ouvre bien la caméra (permission déjà accordée par le
  scanner de profil, donc aucune demande) et la **relâche** en sortant —
  vérifié par `dumpsys media.camera` ;
- le **QR se renouvelle** : deux captures du même écran à 90 s d'intervalle
  donnent deux codes différents (empreintes de la zone du QR comparées) ;
- l'écran du QR tient aussi en **police 1,3 / densité 440** : code entier,
  textes qui passent à la ligne, rien de coupé.

Raccourci utile pour y retourner sans naviguer :
`adb shell am start -a android.intent.action.VIEW -d "diasponiger:///settings/security/transfer/receive" com.diasponiger.diasponiger`
(le lien profond marche, testé).

Deux garde-fous ajoutés depuis, à vérifier eux aussi :

- le **QR se renouvelle toutes les 90 secondes** (le précédent reste accepté un
  tour de plus, sinon un scan tombant pile au renouvellement se perdrait) ;
- l'ancien téléphone **garde une copie de secours sept jours** avant
  d'effacer : si le nouveau tombe juste après l'accusé de réception, « Annuler
  le transfert » la remet en place depuis l'écran de sauvegarde.

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

⚠️ **Ce que ce chemin ne fait pas** : il remplace un téléphone, il n'en ajoute
pas un — et de toute façon la règle d'une seule session par compte l'interdit
déjà. Deux appareils portant la même identité ne peuvent donc pas se disputer
le ratchet en même temps ; c'est ce qui rend l'effacement facultatif.

---

## ⬜ Site web entièrement refait sur cahier des charges (2026-09-08)

Le site n'est plus la même page avec un autre thème : c'est une landing où
l'application est le sujet. Sept sections, trois pages nouvelles
(`/fonctionnalites`, `/a-propos`, `/telecharger`), une feuille de style
partagée (`public/assets/`) au lieu du CSS recopié dans chaque page.

Palette et typographie du cahier des charges : crème `#F8F5EF`, encre
`#111713`, orange d'action `#E87B2E`, vert `#159447`, vert profond `#0B3D2E`,
en **Plus Jakarta Sans + Inter**.

**Deux teintes de la marque sont assombries pour le texte** : `#E87B2E` et
`#159447` plafonnent entre 3,4 et 4,3:1 en petit corps sur crème. Le site
utilise `#A8500F` et `#0C6B33` là où elles portent du texte, et garde les
teintes pleines pour les aplats et les décors. L'audit de contraste tourne
dans le navigateur sur les dix-neuf pages : zéro défaut, hors bouton
« Supprimer définitivement » désactivé (2,9:1 — un contrôle inactif est hors
du champ de WCAG).

**Ce qui n'a pas pu être fait, faute de données** : le cahier des charges
demande des captures d'Événements, de Messagerie, de l'Annuaire et des
Notifications. Sur les deux appareils branchés, Événements et Annuaire sont
**vides**, le Fil et les Notifications ne contiennent que des messages de
test. Seule la liste des conversations était présentable ; elle est utilisée.
Les sections Événements et Annuaire décrivent donc ce que l'app permet, sans
capture — plutôt qu'une vitrine fabriquée.

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

**Mesure d'audience** : les événements (`download_android`, `click_features`,
`scroll_50`…) sont empilés dans `window.dnEvents`. **Aucun traceur tiers n'est
chargé** — brancher un fournisseur demande une décision (et probablement une
bannière de consentement), elle n'a pas été prise ici.

---

## ✅ Rappel des clés : « Ne plus me le rappeler » — vérifié SM A515F (2026-09-08)

Deux bandeaux répétaient le même message et un seul savait se taire. Celui de
`MainShell` se mettait en veille 7 jours sur « Pas maintenant » ; celui posé en
tête de conversation (`_buildE2eeRestoreBanner`, conversation_screen.dart)
n'avait **aucune** veille — il revenait à chaque ouverture d'un fil contenant un
message indéchiffrable, même juste après avoir écarté l'autre.

Désormais : un troisième bouton « Ne plus me le rappeler » (`dismissForever`)
écrit `-1` à la place de l'horodatage — une veille que le temps n'éteint plus —
et les deux bandeaux lisent le même `e2eeRestoreNudgeMutedProvider`.

Couvert par `test/core/services/e2ee/e2ee_backup_coordinator_test.dart`
(5 cas, veille / expiration à 7 jours / effacement / cloisonnement des deux
rappels). Vérifié sur SM A515F le 2026-09-08 (compte « Sim », sans clés
locales donc réellement en `needsRestore`, build debug md5
`3f780aa56b964976b0ba5c488f85c520`) :

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
- [ ] **Une vraie sauvegarde rend la parole.** Non vérifié : il aurait fallu
      créer ou restaurer une vraie sauvegarde (donc manipuler une passphrase
      réelle sur le compte). `clearSnooze` reste couvert par le test unitaire
      seul.

**Trouvé pendant le test — corrigé.** Le bandeau de conversation ne
s'affichait **jamais** sur un fil de groupe : `conversation_screen` gardait sa
propre copie du placeholder (« 🔐 Message chiffré ») alors que les groupes
posent l'autre placeholder de la liste partagée, « [🔐 E2EE — session
requise] ». Il lit désormais `kUndecryptablePlaceholders`
(`undecryptable_placeholders.dart`). Sans ce correctif, la moitié « fil » de
cette fiche n'aurait rien pu montrer.

**À juger sur pièce** : trois actions en français ne tiennent pas sur une
ligne, `MaterialBanner` les empile donc verticalement et le bandeau prend
~540 px sur 2400. Rien ne déborde, mais c'est lourd. Un libellé plus court
(« Ne plus afficher ») les remettrait probablement sur une seule ligne.

⚠️ Ce qu'il faut avoir en tête en testant : taire le rappel de restauration
laisse l'appareil sur le **repli AES** sans plus rien pour le signaler (le
coordinateur ne génère pas de clés quand une sauvegarde distante existe). La
sortie reste Réglages › Sécurité, qui n'a pas bougé.

---

## ⬜ Site web repeint sur la palette ① Organic du guide (2026-09-08)

Le « Guide de style » Claude Design assigne explicitement la palette ①
**Organic** au site web. Le site ne l'a jamais appliquée : il tournait sur un
fond `#0f0d0a` et un orange `#E97424` qui ne figurent dans **aucune** des cinq
palettes du guide, en Fraunces + Sora là où Organic dit Caprasimo + Figtree.
Un visiteur voyait donc une page noire et orange, puis installait une
application crème et verte.

Les seize pages sont passées sur les valeurs de
`lib/features/feed/presentation/theme/feed_tokens.dart` (`organic`) : sable
`#F5EAD8`, surface `#EBDDC5`, encre `#201E1D`, terre cuite `#C67139`, olive
`#7A8A5E`.

**Une valeur du guide n'est pas reprise telle quelle** : `mutedText #82796A`
donne 3,4:1 sur le sable, sous le seuil AA de 4,5:1 pour du texte courant. Le
site utilise `#5C5449`, même famille, un cran plus foncé. C'est la lisibilité
qui l'impose, pas une préférence.

Le contrôle n'est pas visuel : un audit exécuté dans le navigateur parcourt
chaque nœud de texte des seize pages, recompose le fond réel (superposition des
alphas) et calcule le rapport de contraste. Les seize pages sortent à zéro
défaut. Seul le bouton « Supprimer définitivement » **désactivé** reste à
2,7:1 — un contrôle inactif est explicitement hors du champ de WCAG, et c'est
son apparence voulue.

- [ ] **Lisibilité au soleil** : une page claire se comporte à l'inverse d'une
      page sombre en extérieur. À regarder dehors, pas seulement au bureau.
- [ ] **Rendu des captures sur fond clair** : les écrans de l'app sont crème,
      le cadre du téléphone reste sombre pour les détacher. À vérifier sur
      écran de téléphone, où le contraste perçu diffère.
- [ ] **Polices Caprasimo et Figtree** : elles ne sont chargées que depuis
      Google Fonts. Vérifier le rendu de repli si le réseau est lent
      (Caprasimo n'a qu'une graisse ; un faux gras serait visible).
- [ ] **`prefers-reduced-motion`** : toujours à vérifier avec « Réduire les
      animations » activé.
- [ ] **Barre système du navigateur** : `theme-color` est passé au sable ;
      à voir sur Chrome Android, thème clair et thème sombre.

---

## ⬜ Site web : page d'accueil refondue sur les captures réelles (2026-09-08)

La page d'accueil vendait une version plus ancienne de l'app : cinq cartes à
emoji (carte, groupes, événements, messagerie, annuaire), **aucune capture**,
une citation inventée signée par la plateforme elle-même, et trois chiffres
creux — dont « 100 % Gratuit », l'affirmation que
`releases/1.2.1+11/GOOGLE_PLAY_v1.2.1.md` signale comme fausse (l'APK embarque
`google_mobile_ads` et RevenueCat). Les **ambassades et les vingt démarches
consulaires**, c'est-à-dire ce que la fiche Play met en tête depuis 1.2.1,
n'étaient mentionnées nulle part.

La page est maintenant bâtie sur les sept captures Play (`releases/1.2.1+11/
play/screenshots/`, recadrées sur l'écran seul, servies en WebP), et ne
présente que ce qui est réellement atteignable dans le binaire — transferts,
marketplace, salons audio et podcasts restent hors de la page, comme dans la
fiche Play.

Les chiffres sont vérifiables : **20** démarches (`assets/data/
demarches_consulaires.json`), **30+** représentations (32 lignes dans
`embassies`), **4** continents. Le passage « dix-huit des vingt démarches
réclament la carte consulaire en première pièce » vient du champ `resume` de
la même source.

`index-en.html` est désormais **générée depuis `index.html`** : les deux
pages avaient des feuilles de style différentes, donc toute retouche était à
faire deux fois et le rendu divergeait.

- [ ] **Rendu des captures** sur un vrai navigateur de téléphone : le
      recadrage est détecté cadre par cadre (les sept visuels Play n'ont ni
      la même taille de téléphone ni la même position), à revoir sur écran.
- [ ] **La feuille « pièces à réunir »** chevauche l'écran de l'app en
      version large et se remet dessous sous 900 px : vérifier qu'elle reste
      lisible entre les deux, notamment en paysage.
- [ ] **Bande défilante et révélations au défilement** : un bloc
      `prefers-reduced-motion` a été ajouté (il n'y en avait aucun). À
      vérifier avec « Réduire les animations » activé dans Android.
- [ ] **Poids de la page** : sept captures WebP (~240 Ko au total) chargées
      en `loading="lazy"` sauf celle du hero. À mesurer en 3G.

---

## ⚠️ Déconnexion — latence supprimée, à vérifier sur appareil

Appuyer sur **Déconnexion** laissait l'écran figé plusieurs secondes, sans
aucun retour visuel. Le chemin enchaînait **sept allers-retours réseau en
série** avant que le routeur ne sorte, dont une moitié inutile :

- `AuthRepositoryImpl.signOut()` appelait `getCurrentUser()` — trois requêtes
  Supabase (échange du jeton Firebase, upsert du compte, lecture du profil) —
  uniquement pour obtenir un uid que `FirebaseAuth.currentUser` a en mémoire ;
- `removeTokenForUser()` était appelé **deux fois**, par l'écran de profil et
  par le repository : deux fois `ensureAuthenticated` + SELECT + UPDATE ;
- le datasource attendait l'init de Google Sign-In (Play Services, ~1 s même
  pour un compte e-mail qui n'y touchera jamais) puis la révocation gotrue,
  avant de faire le seul geste qui déconnecte vraiment — effacer le jeton
  Firebase local, quelques millisecondes.

Désormais `signOut()` rend la main dès que le jeton Firebase est effacé ; le
ménage distant (jeton FCM, révocation Supabase, compte Google) part en tâche
de fond, dans cet ordre car la révocation coupe la session dont le retrait du
jeton a besoin. La purge locale (Hive, préférences, pièces jointes en clair)
reste attendue : elle décide de ce dont le compte suivant hérite.

Fichiers : `lib/features/auth/data/repositories/auth_repository_impl.dart`,
`lib/features/auth/data/datasources/auth_remote_datasource.dart`,
`lib/features/profile/presentation/screens/profile_screen.dart`.

**Passe appareil du 2026-09-08, Pixel 10 Pro XL / Android 17**, APK debug
construit depuis ce worktree (`md5sum` local et `md5sum` du `pm path` sur
l'appareil identiques : `5dd681b4…` — le piège de l'APK périmé est écarté).

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

- [ ] **⚠️ Le dialogue « Connecté ailleurs » peut avaler le tap.** Rencontré le
      2026-09-08 : `SessionService._handleForceLogout()` a ouvert sa boîte
      par-dessus le dialogue de déconnexion, et le tap de confirmation a
      atterri dessus — première mesure perdue. À vérifier avant d'appuyer.

## ⬜ Déconnexion forcée « Connecté ailleurs » — trois trous refermés

Trouvée en mesurant la latence ci-dessus. Cette voie ne faisait que
`FirebaseAuth.signOut()` + `clearSessionId()`, d'où trois défauts :

- **ni purge des caches, ni des préférences personnelles, ni des pièces
  jointes en clair** — le compte suivant sur ce téléphone en héritait ;
- **ni retrait du jeton FCM** — l'appareil restait inscrit aux notifications
  du compte sorti ;
- **`AuthState` restait sur `authenticated`** alors que Firebase était sorti :
  le garde du routeur (« si non authentifié → /auth/login ») ne voyait rien,
  seule la navigation explicite du bouton OK masquait l'incohérence.

C'est la famille de défauts que le correctif de latence venait de traiter sur
la voie normale — la duplication garantissait la divergence. Elle délègue
désormais à la déconnexion complète d'`AuthNotifier`, via une fermeture posée
par le notifier (`SessionService.onForceLogout`), avec repli sur l'ancien
comportement si elle manque ou échoue : une sortie incomplète vaut mieux que
pas de sortie. Le dialogue passe aussi par l10n — les clés
`connectedElsewhere` / `connectedElsewhereMessage` existaient depuis toujours,
inutilisées, et le texte était en dur en français.

Verrouillé par `test/features/auth/deconnexion_forcee_test.dart` (câblage et
délégation, repli compris ; vérifié rouge en retirant le branchement).

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

---

## ✅ Profil : la carte de statistiques débordait par la droite — corrigé et vérifié Pixel 10 Pro XL (2026-09-08)

Signalé par Salim sur le Pixel 10 Pro XL, jamais vu sur le SM A515F — et pour
cause : le défaut ne dépend pas du modèle mais de **deux réglages** que ce
téléphone-là cumule, `wm density` surchargée à **440** (392 dp de large au lieu
de 411) et `settings get system font_scale` à **1.3**.

La rangée « Connexions / Groupes / Événements / Publications » posait ses
quatre colonnes à leur largeur naturelle dans une `Row` (`spaceEvenly`, aucun
`Expanded`). Les libellés tiennent tout juste dans les ~320 dp utiles de la
carte à l'échelle 1.0 ; à 1.3 ils débordent. Deux correctifs :

- les quatre colonnes se partagent la largeur (`Expanded`), et à l'intérieur le
  compteur et le libellé passent en `FittedBox(scaleDown)` — ils rétrécissent
  au lieu de déborder, sans jamais grossir (rendu inchangé à l'échelle 1.0) ;
- `DesignSectionLabel` (kit, donc **toute l'app**) rendait son libellé sans
  contrainte : `Flexible` sans `maxLines`, il se replie sur deux lignes au lieu
  de déborder. Trouvé au banc à l'échelle 2.0, pas signalé par Salim.

Verrouillé par `test/features/profile/profile_screen_overflow_test.dart`
(échelles 1.0 / 1.3 / 2.0, géométrie du Pixel). **Les deux correctifs sont
vérifiés par mutation** : sans le premier le banc échoue aux trois échelles,
sans le seul second il échoue à 2.0.

⚠️ **La police de banc rend chaque glyphe carré (1 em)** : les 300 px reproduits
ne sont pas les pixels vus à l'écran. Le banc prouve que la mise en page ne
dépend plus de la longueur des libellés, pas l'ampleur du défaut.

**Le banc ne voyait pas tout.** Une fois le débordement supprimé, la première
capture appareil a montré un second défaut qu'aucune assertion n'attrape :
les libellés remplissaient leur colonne **au pixel près**, donc « Connexions »
chevauchait le filet et « Événements » / « Publications » se touchaient. Une
gouttière de 6 dp par colonne (12 dp autour de chaque filet) règle ça — les
libellés rétrécissent d'autant, ils restent entiers.

**✅ Vérifié sur Pixel 10 Pro XL le 2026-09-08** (id `58221FDCQ0085Z`, thème
sombre, densité 440 + `font_scale` 1.3, APK debug du worktree — `md5sum` local
et `md5sum` sur l'appareil identiques, `9793305acf2ea0dc2478ec436b3a7bba`) :

- [x] Profil : plus de bandeau jaune et noir à droite de la carte de
      statistiques, et `logcat | grep overflowed` reste vide sur tout le
      défilement de l'écran.
- [x] Les quatre libellés restent lisibles en entier (pas de troncature) et les
      quatre compteurs restent alignés.
- [x] Les libellés ne se touchent plus et ne chevauchent plus les filets.
- [x] Libellés de section (`DesignSectionLabel`) : « ACTIONS DU COMPTE » tient
      sur une ligne, sans débordement.
- [ ] Un compteur à **trois chiffres** ne déforme pas sa colonne — pas
      vérifiable sur ce compte (4 / 2 / 0 / 1). Couvert au banc seulement.
- [ ] Rendu en thème **clair** : jamais regardé.


---

## ⬜ Site web : menu mobile, liens partagés, aperçus de partage (2026-09-08)

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

## ⬜ Deux bibliothèques natives réalignées sur 16 Ko (2026-09-08)

Google Play refuse au dépôt tout AAB qui cible l'API 35+ et embarque un `.so`
64 bits aligné sur 4 Ko. Sur l'AAB du 2026-09-08, 6 des 8 bibliothèques
arm64-v8a étaient conformes ; deux ne l'étaient pas, et **rien en local ne le
disait** — la compilation passe, l'installation passe, `flutter analyze` ne
regarde pas les `.so`. Le refus n'arrive qu'en Play Console.

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

- [ ] **Scanner QR** (`/qr-scanner`, atteint depuis l'accueil « Trouver des
      amis », la modale de partage de profil et celle de partage de groupe) :
      la caméra démarre, un QR de profil est décodé et ouvre la bonne fiche.
      C'est le seul consommateur de `libbarhopper_v3.so` — s'il se charge, la
      montée MLKit est bonne ; s'il échoue, ce sera un écran caméra noir ou
      un code jamais reconnu, pas une erreur Dart.
- [ ] **Appel audio de groupe** puis **appel vidéo** (LiveKit) : connexion,
      son dans les deux sens, caméra. `libnoise.so` n'est chargé que par le
      visualiseur audio natif de LiveKit (`createVisualizer`), que l'app
      n'appelle **nulle part** — le remplacement ne devrait donc rien changer,
      mais c'est une substitution de module au niveau Gradle : elle mérite un
      appel réel avant publication.
- [ ] **Salon audio** et **podcast en direct** : même moteur LiveKit, autres
      écrans d'entrée.

C'est la suite directe du point « Alignement 16 Ko » de l'entrée targetSdk 36
plus bas, qui chiffrait l'écart (6 conformes sur 8) et renvoyait à une session
dédiée.

## ⬜ Ambassades : « officiel / vérifié » **et** les horaires mis en sommeil (2026-09-08)

`lib/features/embassies/presentation/screens/embassy_detail_screen.dart` :
la pastille bleue `Icons.verified` collée au nom du poste (en-tête déroulant)
et le bandeau « **Compte Officiel Vérifié** » en tête de l'onglet *Infos* sont
**commentés**, en attendant confirmation auprès des postes. Les deux ne
tenaient qu'à `embassy.isVerified`, un drapeau de **modération interne**
(écran admin de vérification) : il ne dit pas que l'ambassade reconnaît la
fiche, alors que les deux affichages le laissaient croire — juste au-dessus
des coordonnées dont la fiche prévient elle-même, plus bas, qu'elles sont
parfois fautives.

Le code est conservé en commentaire, prêt à être rétabli. Rien d'autre n'a
bougé : le filtre `!e.isVerified || e.isSuspended` de
`embassies_provider.dart` continue de masquer les fiches non validées, et
l'écran admin de vérification est intact. Audit fait : `embassyOfficialVerified`
était la **seule** chaîne côté ambassades à affirmer une officialité (80 clés
l10n passées en revue).

`flutter analyze lib/features/embassies` : **No issues found**.

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

Le vert méritait de tomber avec les horaires : il ne mesurait rien. Il ne
lisait pas les horaires, il s'affichait dès que le drapeau de fermeture était
faux — et une requête sur la base le confirme :

```
select count(*) total,
       count(*) filter (where opening_hours::text not in ('{}','null')) avec_horaires,
       count(*) filter (where is_verified) verifiees,
       count(*) filter (where is_temporarily_closed) fermees
from embassies;
-- total 32 | avec_horaires 0 | verifiees 32 | fermees 0
```

Donc, avant ce commit : **les 32 fiches** affichaient « Compte Officiel
Vérifié » + la pastille bleue + un bandeau vert « Ouvert », et **aucune** ne
portait d'horaires. Les blocs horaires ne rendaient déjà rien ; les commenter
ne change rien à l'écran d'aujourd'hui, mais évite que la première donnée
saisie parte à l'écran sans relecture.

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

#### ✅ La capture Play de la fiche : soldé en la retirant

La capture livrée alors (« Adresse, contact et itinéraire de chaque poste »)
montrait le bandeau vert « Ouvert » en tête de l'onglet *Infos*, qui n'existe
plus. Elle a d'abord été reprise sur un build incluant ce commit, puis
**retirée de la série** : sans horaires ni bandeau, l'écran ne montre plus
qu'une adresse, un fax et quatre boutons, et son élément le plus visible est un
encart signalant un numéro de fax erroné — utile dans l'app, mauvais argument
sur une fiche boutique.

⚠️ **La liste, elle, affiche toujours « ● Ouvert »** sur sa carte « Le plus
proche » (`embassies_screen.dart`, `_NearestEmbassyCard`), en vert, calculé sur
le seul `isTemporarilyClosed` — sans lire le moindre horaire, exactement ce que
ce commit vient de retirer de la fiche de détail. La capture 2 de la série Play
le montre donc. Deux écrans, deux traitements du même drapeau.

- [ ] Trancher : soit la carte « Le plus proche » perd son état « Ouvert »
      comme la fiche, soit les deux le retrouvent quand des horaires existeront
      en base. En l'état, la fiche boutique affiche une mention qui ne repose
      sur rien.

## ⬜ Publication Play Store 1.2.1+11 — build release à valider (2026-09-08)

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

### ⚠️ `ACCESS_BACKGROUND_LOCATION` — à trancher avant de soumettre

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

### Captures de la fiche boutique

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
## ⬜ Passage à targetSdk 36 (Android 16) — exigence Play (2026-09-08)

Play Console refuse toute mise à jour à partir du **31/10/2026** si l'app ne
cible pas l'API 36. La 1.2.0 publiée cible 35.

La cause n'était pas dans le dépôt : `build.gradle.kts` disait
`targetSdk = flutter.targetSdkVersion`, une valeur qui **vient du SDK Flutter
installé sur le poste**, pas du code. Flutter 3.29 (le poste au moment de la
release) répond 35, Flutter 3.44.2 répond 36 — le même commit produit donc
deux binaires différents selon la machine, sans un mot dans les logs. La
valeur est maintenant épinglée à `36` en dur.

Ce que ce passage change au comportement Android — à regarder sur appareil,
`flutter analyze`/`flutter test` n'en voient rien :

- [ ] **Bord à bord (edge-to-edge) imposé, sans dérogation possible.** L'app
      était déjà concernée en ciblant 35 ; en 36 l'échappatoire
      `windowOptOutEdgeToEdgeEnforcement` est ignorée. Revoir les écrans qui
      dessinent jusqu'en bas : barres d'onglets, champ de saisie de
      discussion, feuilles modales — vérifier qu'aucun contenu ne passe sous
      la barre de navigation gestuelle ni sous l'encoche.
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

**Version portée à `1.2.1+11`.** ⚠️ Correction : j'avais écrit ici que la
1.2.0+10 était « en production ». C'est faux — la fiche publique renvoie 404
dans les cinq pays testés. Le bundle 1.2.0+10 a seulement été **téléversé**
(piste de test ou brouillon), ce qui suffit à déclencher l'avertissement de
la console. Le versionCode 10 est donc pris, mais aucune fiche publique
n'existe encore à mettre à jour.

---
## ⚠️→✅ La garde d'organisateur refusait l'organisateur (2026-09-08)

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

## ✅ Trois routes plantaient sur un cast non nullable — corrigées et vérifiées SM A515F (2026-09-08)

Même famille que la fiche d'ambassade ci-dessous, mais en plus brutal : là où
`/embassies/:id` faisait un `!`, ces trois-là transtypaient `state.extra` vers
un type **non nullable**, donc `TypeError` avant même le montage de l'écran.

- `/events/:eventId/edit` — `state.extra as EventEntity`
- `/events/:eventId/recap` — idem
- `/groups/:groupId/edit` — `state.extra as GroupEntity`

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
- [ ] L'équivalent pour un **groupe** dont on n'est pas administrateur :
      toujours pas vu (il faudrait un groupe partagé entre les deux comptes).

⚠️ **Trouvé au passage, corrigé** : `EditEventScreen._currentPosterUrls` est
`late` et n'était **jamais assigné**, alors qu'il est lu dès le premier
`build` (« Gérer les affiches (n/5) »). L'écran levait donc un
`LateInitializationError` à **chaque** ouverture, y compris par le bouton
« modifier » — modifier un événement était impossible pour tout le monde.
Aucun test ne montait cet écran ; il est apparu à la première tentative.
À rejouer sur appareil sur un vrai événement.

✅ **Tranché le 2026-09-08 : le récap est réservé à l'organisateur.**
`EventRecapScreen` est un **formulaire** (« Créer / Modifier le récap »,
description, dix photos, bouton d'enregistrement) sans mode lecture, et
l'accueil l'ouvrait pour tout le monde dès qu'un événement passé avait des
photos — n'importe qui pouvait donc réécrire le récapitulatif de l'événement
d'autrui. `EventRecapRoute` porte désormais la même garde que l'édition.

Deux précautions pour que la garde ne retire rien à personne :
- la sortie mène à `/events/:eventId`, **pas** à la liste : la fiche affiche
  déjà le récapitulatif (description + grille de photos), donc un
  non-organisateur voit toujours ce qu'il voyait ;
- la carte « rien de prévu » de l'accueil (`home_screen_widgets.dart`)
  n'envoie plus au formulaire que l'organisateur ; les autres vont à la fiche.
  Sans ça, la pastille « Photos » aurait mené tout le monde contre un mur.

- [x] Un non-organisateur voit bien « Récap réservé à l'organisateur » —
      **Pixel 10 Pro XL**, compte « Salim », le 2026-09-08.
- [x] « Voir l'événement » l'amène à la fiche de l'événement. Celle-ci
      n'affiche **aucun bouton « modifier »** pour lui : c'est la logique
      préexistante de l'écran (`isOrganizer`) qui confirme, indépendamment de
      ma garde, que ce compte n'est bien pas l'organisateur.
- [x] L'organisateur, lui, atteint toujours le formulaire : sur le A51,
      « Créer un récapitulatif » s'ouvre normalement.

**Méthode : aucun événement de test n'a été créé.** Le premier réflexe était
d'en écrire un en base de production ; c'était inutile. Les deux téléphones
portent **deux comptes différents** (« Sim » sur le A515F, « Salim » sur le
Pixel), donc n'importe quel événement existant est « le mien » d'un côté et
« celui d'autrui » de l'autre. À retenir pour toute garde d'autorisation à
vérifier.

⚠️ **Piège de mesure, retombé dessus** : le A51 s'est retrouvé avec un APK
qui n'était pas le mien (`3edc4fa6` au lieu de `a5326f74`) entre deux essais —
un autre build l'a écrasé en cours de session. L'écran d'erreur neutre que
j'y voyais n'était pas mon code. Comparer `md5sum` local/appareil **avant**
chaque conclusion, pas seulement après l'installation.

⚠️ **Trouvé en regardant l'écran d'édition, non corrigé** : le champ
description a pour étiquette « La description est requise »
(`l10n.descriptionRequired`, edit_event_screen.dart:410) au lieu de
« Description ». Le message de validation, lui, a sa propre clé
(`descriptionRequiredError`). Purement cosmétique, mais visible.

⚠️ **Trouvé en vérifiant ça, non corrigé** : la carte de l'accueil est le
**seul** chemin vers le récapitulatif, et elle ne s'y rend que si
`recapPhotoUrls.isNotEmpty`. Un organisateur dont l'événement passé n'a pas
encore de photos n'a donc **aucun moyen d'en créer un** — l'écran porte
pourtant un mode « Créer » (`eventCreateRecap`, `eventRecapCreateButton`).
Il manque une entrée depuis la fiche de l'événement. Antérieur à la garde.

⚠️ **Piège de méthode, revu deux fois aujourd'hui** : après avoir supprimé des
clés ARB, l'APK incrémental gardait l'ancien code compilé — la route affichait
l'écran d'erreur neutre, sans **aucune** trace dans logcat (`presentError` est
noyé par le bruit Supabase hors ligne). Deux reproductions à froid et un test
témoin sur une route non modifiée ont été nécessaires avant de penser au
`flutter clean`, qui a tout réglé. md5 local == md5 appareil ne prouve rien
ici : les deux portaient le même APK périmé.

---

## ✅ Fiche d'ambassade par lien profond : écran rouge — corrigé et vérifié SM A515F (2026-09-08)

`/embassies/:id` ne lisait que `state.extra` et terminait par
`EmbassyDetailScreen(embassy: embassy!)` — un `!` sur la valeur qu'elle venait
de tester nulle. `state.extra` étant nul par construction hors navigation
interne, l'écran rouge « Null check operator used on a null value » était
systématique. **Et pas seulement par lien profond** : le bouton de la fiche
d'ambassade sur la carte (`map_screen.dart:1521`) pousse la route sans objet,
donc il plantait depuis l'app elle-même.

La route résout maintenant l'identifiant (`EmbassyDetailRoute` +
`embassyByIdProvider`), avec un état de chargement et deux états nommés, tous
munis d'une sortie (`DesignExitOnlyBody` + bouton « Retour à l'annuaire »).

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
- [ ] Bouton « détails » de la fiche d'ambassade **sur la carte** : c'est le
      second chemin qui plantait, corrigé par ricochet mais jamais rejoué à
      la main sur appareil.
- [ ] Fiche hors de la juridiction de l'usager ouverte par lien partagé :
      elle doit s'afficher (le filtre de juridiction ne vaut que pour la
      liste). Couvert en test widget, pas sur appareil.

⚠️ **Découvert au passage, non corrigé** : `getEmbassies()` n'a aucun délai de
garde. Derrière un VPN persistant en mode avion, `networkInfo` se croit
connecté et la requête Supabase reste suspendue **~2 minutes** avant de servir
la copie locale. Ça retarde d'autant tout ce qui attend l'annuaire — la fiche
comme la liste. Le provider `embassyById` borne son propre appel à 8 s, mais
il ne peut rien contre celui qui le précède. Vérifier si l'écran de liste
mérite le même traitement.

⚠️ **Même famille, non corrigé** : trois autres routes castent `state.extra`
vers un type **non nullable**, donc plantent identiquement par lien profond ou
notification — `/events/:eventId/edit` et `/events/:eventId/recap`
(`state.extra as EventEntity`), `/groups/:groupId/edit`
(`state.extra as GroupEntity`). Elles n'ont pas été touchées : chacune demande
son propre état de chargement et d'introuvable.

---

## ✅ Quatre écrans sans flèche de retour — corrigés et vérifiés SM A515F (2026-09-08)

Notifications, Annuaire des entreprises, Événements et Ambassades sont
atteints par `push` depuis l'accueil, mais n'affichaient aucun moyen de
revenir. Deux causes, invisibles en lisant l'écran seul :

- `DesignScreenHeader.leading` est facultatif — les cinq onglets racines n'en
  veulent pas — donc un écran poussé qui recopie l'en-tête d'un onglet hérite
  de son absence de flèche (Notifications, Entreprises) ;
- `automaticallyImplyLeading: false` supprime la flèche que Flutter aurait
  posée seul ; le drapeau, justifié sur un onglet, avait été recopié sur deux
  écrans poussés (Événements, Ambassades).

La flèche des en-têtes plats est maintenant une brique unique du kit,
`DesignBackLeading` ; les Réglages la dessinaient à la main, ils sont passés
dessus. Verrouillé par `test/core/router/fleche_retour_test.dart`.

**Vérifié sur SM A515F le 2026-09-08**, thème sombre / accent orange, APK
debug construit depuis le worktree (`md5sum` local et
`pm path`+`md5sum` sur l'appareil identiques — le piège de l'APK périmé est
écarté) :

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

**Défaut trouvé À L'ÉCRAN, que l'analyse ne pouvait pas voir**, et corrigé
dans la foulée : `diasponiger:///events` en **démarrage à froid** affichait
Événements **sans aucune flèche**. La flèche implicite de l'AppBar
(`automaticallyImplyLeading`) n'est posée par Flutter que si
`Navigator.canPop()` est vrai ; par lien profond la pile ne contient que cet
écran. Les deux écrans à AppBar portent donc désormais un `BackButton`
explicite avec repli (`canPop() ? pop() : go('/home')`), qui garde les
métriques Material (cible de 48 dp).

Revérifié après ce correctif, en démarrage à froid :

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

Piège de test relevé au passage : en debug, ce téléphone met **plus d'une
minute** à peindre l'écran d'un lien profond à froid, et affiche entre-temps
un aplat gris-bleu vide. Une capture à 30 s montre le gris et se lit comme un
écran cassé. Rafale de `screencap` toutes les 15 s, garder la plus grosse.

**Les 38 autres routes ont été traitées dans la foulée.** Le même défaut de
lien profond touchait tout écran s'en remettant à la flèche implicite —
`/businesses/:businessId`, `/marketplace/:productId`, `/transfers/send`,
`/support/:ticketId`, `/payment-history`, `/friends`… 36 fichiers, 43 barres
(certains écrans ont une `AppBar` par état : vide, chargement, données — il
fallait les trois). Chacune reçoit un `BackButton` avec repli vers le parent
logique de la route (`/marketplace/cart` → `/marketplace`,
`/transfers/send` → `/transfers`…), et 9 fichiers ont gagné l'import
`go_router`.

Il ne reste **aucune** route poussée sans sortie explicite : le garde-fou
l'exige maintenant partout, avec deux exceptions nommées seulement
(`/calls/:callId`, qui sort par « raccrocher », et `/share`, feuille modale
présentée par `MainShell`).

Choix de style assumé : dans une `AppBar`, la flèche est le `BackButton` de
Flutter, pas `DesignBackLeading`. Les trois fiches à image de couverture
(entreprise, ambassade, produit) la reçoivent sans pastille — c'est déjà
ainsi que leurs actions `partager` / `modifier` sont posées sur l'image.

**Vu sur SM A515F le 2026-09-08 — 8 fichiers sur 36.** Méthode : l'arbre
d'accessibilité expose la flèche comme `content-desc="Retour"`
(`uiautomator dump`), ce qui est bien plus fiable que de lire des pixels.
Confirmés : `/friends`, `/support`, `/businesses/mine`, `/admin/support`,
`/messages/new`, `/profile/reposts`, `/settings/security/backup`,
`/embassies/employees`.

**Non vérifiables sur cet appareil — 18 fichiers sur 36.** Les familles
`/transfers`, `/marketplace`, `/payment-accounts`, `/payment-history`,
`/podcasts` et `/audio-rooms` sont derrière un feature-flag : le routeur les
renvoie sur `/home` (étape 9 du `redirect`). Aucun de leurs écrans n'est
atteignable tant que les drapeaux sont à false.

Reste à voir, par ordre d'intérêt :

- [ ] **La flèche est-elle lisible sur une image de couverture ?** C'est le
      seul endroit où le contraste n'est pas garanti par le thème :
      `/businesses/:id` et `/marketplace/:productId` posent une vraie photo
      (`CachedNetworkImage`). Non testable ici — l'annuaire est vide sur ce
      compte et la boutique est derrière un drapeau. `/embassies/:id` ne
      compte pas : son en-tête est un aplat teinté, pas une photo.
- [ ] **Les états vide et chargement** des écrans à plusieurs `AppBar` :
      `/marketplace/cart` panier vide, `/marketplace/my-listings`,
      `/payment-history`, `/payment-accounts`, `/marketplace/my-orders`.
      Tous derrière un drapeau aujourd'hui.
- [ ] Les ~10 écrans restants atteignables mais non atteints (voir le piège
      d'`am start` ci-dessous).

**Troisième forme du défaut, trouvée à l'écran le 2026-09-08 — corrigée.**
`/businesses/<id>` sur une entreprise absente affichait « Entreprise non
trouvée » **et rien pour revenir**. La fiche pose sa `SliverAppBar` *à
l'intérieur* de la branche « données » : son `Scaffold` n'a pas d'`appBar`,
donc les états chargement / erreur / « non trouvé » n'ont aucune sortie. Le
fichier contenait pourtant un `BackButton` — d'où l'aveuglement d'un garde
qui raisonne au fichier. Trois écrans avaient cette forme :
`business_detail_screen`, `product_detail_screen`, et le `Scaffold` de
chargement de `transfer_screen`. Tous passés sur une brique unique du kit,
`DesignExitOnlyBody`.

- [x] **Vérifié sur SM A515F** : « Entreprise non trouvée » expose maintenant
      un contrôle « Retour ».

**⛔ Défaut sans rapport, trouvé au passage et NON corrigé : `/embassies/<id>`
plante.** Le builder de la route lit `state.extra as EmbassyEntity?` puis
termine par `EmbassyDetailScreen(embassy: embassy!)` — un `!` sur la valeur
qu'il vient de tester nulle. `state.extra` étant toujours nul par lien
profond et par notification, **toute** entrée directe sur une fiche
ambassade donne l'écran rouge « Null check operator used on a null value »
(reproduit à l'identique sur appareil). Les commentaires du code admettent
que le repli n'est pas implémenté. Même famille que
`project_state_extra_not_authoritative`. Hors sujet de ce lot, laissé tel
quel : il faut charger l'ambassade par son id.

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
- [x] Les Réglages, dont la flèche est passée sur la brique partagée,
      affichent bien leur flèche (entrée depuis Profil, vue le 2026-09-08).
      Entrée depuis la Carte non retestée.

---

## ⬜ Démarches consulaires : données réelles à la place des délais inventés (2026-09-07)

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

`flutter analyze` propre, `test/features/dropdowns_overflow_test.dart` passe
(10/10, le cas sert maintenant le vrai catalogue embarqué). Rien de ce qui
suit n'a été vu sur un téléphone.

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
- [ ] Ouvrir « Passeport — première demande ou renouvellement » et vérifier
      son avertissement (la source la titrait « prorogation » à tort).
- [x] **Vu sur SM A515F (2026-09-07).** Bandeau « ne se fait pas au
      consulat » avec les trois règles de juridiction, et « Timbre fiscal :
      1 500 F CFA » accentué — seule démarche à afficher un montant.
- [x] **Partiellement vu sur SM A515F (2026-09-07).** « Droits de
      chancellerie — montant non publié » confirmé sur la carte consulaire, et
      « Délai de traitement non communiqué par la source » partout où c'est
      passé — le délai inventé a bien disparu.
- [ ] Vérifier « Aucun frais mentionné par la source » (déclarations de
      naissance et de mariage) et la mention conditionnelle des deux démarches
      de décès.
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

      **Pourquoi elle était introuvable — et c'est le vrai enseignement.**
      `main.dart` posait `FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterError` **sans condition**.
      Cette affectation remplace le gestionnaire par défaut de Flutter :
      aucune pile d'exception ne sortait donc jamais, ni dans `flutter run`
      ni dans logcat. Un écran rouge s'affichait sans le moindre indice sur
      son origine. Corrigé : en `kDebugMode`, on appelle aussi
      `FlutterError.presentError(details)` avant de transmettre à Crashlytics.

      **Ce que l'instrumentation a montré.** Toutes les défaillances hors
      ligne remontent à `ProfileSupabaseDataSource.getProfile`
      (`profile_supabase_datasource.dart:117`), atteinte par plusieurs
      chemins concurrents au démarrage :

      - `LocationPublisherService.start` (`location_publisher_service.dart:115`)
        → `_initServicesSecondaires` (`main.dart:160` et `:185`) ;
      - `ProfileSupabaseDataSource.updateLastLogin` (`:353`) ;
      - la sauvegarde du jeton FCM et `OnlineStatusService`.

      Toutes ces voies-là **sont traitées** : elles journalisent un
      avertissement et n'affichent rien. Aucune `EXCEPTION CAUGHT BY` n'est
      apparue pendant la campagne instrumentée.

      ⚠️ **L'écran rouge est donc INTERMITTENT, pas déterministe** : sur la
      session instrumentée, le même parcours a rendu l'écran des démarches
      correctement (capture à 01:17). C'est une course entre l'état du
      provider de profil et la lecture qui n'en tolère pas l'erreur, pas un
      chemin de code fixe.

**Quatre campagnes de reproduction, ~34 lancements à froid hors ligne, avec
l'instrumentation active : la course ne s'est JAMAIS reproduite.**

Une seule campagne est méthodologiquement valable, et c'est important de le
dire : les trois autres n'ont rien prouvé.

| # | Méthode | Verdict |
|---|---|---|
| 1 | Taps à l'aveugle (8 essais) | ❌ **invalide** — GoRouter ne montre aucun `/embassies/`, les taps n'ont jamais atteint l'écran |
| 2 | Lien profond direct vers la fiche, 10 essais | ✅ **valable** — route poussée vérifiée à chaque tour, **0 exception** |
| 3 | Lien profond vers la liste + tap « Détails » (10) | ❌ le tap n'ouvre jamais la fiche (`pushing /embassies/` = 0) |
| 4 | Idem, attentes portées à 75 s (6) | ❌ même échec, ce n'était donc pas un problème de timing |

**Ce qui est acquis** : sur la fiche atteinte directement, 10 démarrages à
froid hors ligne d'affilée, aucune exception. **Ce qui ne l'est pas** : les
deux occurrences réelles venaient du parcours par la liste, et je n'ai pas
réussi à automatiser ce parcours-là de façon vérifiable.

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

Couvert par `test/core/ecran_erreur_neutre_test.dart` (4 cas) : l'exception
réellement observée est rejouée et le test échoue si `supabase.co`,
l'identifiant du compte ou `SocketException` réapparaissent à l'écran. Les
deux autres cas couvrent les contraintes du widget — zone minuscule, absence
de `Directionality`/`Theme` au-dessus.

**Les deux thèmes sont vérifiés** (2026-09-08), par deux moyens qui se
complètent : des assertions déterministes sur les couleurs et le contraste
(`computeLuminance`), et un rendu rasterisé inspecté pour la mise en page.
Clair : fond `#F7F7F7`, titre `#1A1A1A`. Sombre : fond `#121212`, titre
`#F5F5F5`. Contenu centré, icône présente, seconde ligne plus pâle dans les
deux cas.

⚠️ Ce rendu suit la luminosité du **système**, pas le thème de l'app — un
`ErrorWidget` peut être posé au-dessus de `MaterialApp`, donc sans `Theme` à
interroger. Conséquence assumée : qui force dans l'app un thème contraire à
celui du système verra cet écran-là dans l'autre sens. C'est pourquoi les
tests exigent que **chacun des deux rendus soit lisible seul**.

- [ ] Reste à voir sur un vrai téléphone, pour les glyphes : `flutter test`
      dessine le texte avec sa police de test (chaque caractère devient un
      pavé plein), donc l'image prouve les couleurs et la mise en page, pas
      le texte. Suppose de provoquer une levée à la demande — et celle qu'on
      connaît ne se reproduit pas.
- [x] **Fait pour l'écran rouge de Flutter (2026-09-08)** :
      `ErrorWidget.builder` rend « Une erreur est survenue » à la place du
      message brut. ⚠️ Ne couvre PAS les états d'erreur que les écrans
      rendent eux-mêmes — voir la section « Annuaire » ci-dessous.
- [ ] Premier lancement **hors ligne, cache vide** : l'écran doit afficher la
      liste embarquée, pas un spinner ni une erreur. (Même blocage que
      ci-dessus.)
- [ ] Aucun débordement sur les libellés les plus longs à **échelle de police
      1.1** (le résumé de la carte consulaire fait trois lignes).
- [ ] Envoyer une demande, puis vérifier côté back-office que
      `additionalData` porte bien `demarcheId` / `demarcheTitre` : le
      `requestType` seul ne suffit pas à savoir laquelle des six démarches
      notariées a été demandée.

**Migration appliquée sur « Diapo Niger » (`zyrfkcjjrhddpfxcgezo`) le
2026-09-07** : `20260907180000_catalogue_demarches_consulaires.sql`. Vérifié
en base, en forçant `SET LOCAL ROLE anon` — sans quoi `db query --linked` se
connecte en `postgres` et contourne la RLS, faux positif garanti :

- 20 démarches, 5 rubriques, 18 exigeant la carte consulaire, 1 seul coût
  chiffré — les mêmes nombres que l'asset ;
- `get_demarches_catalogue()` rend les 20 démarches **en `anon`**
  (`current_user` relu à « anon » pour prouver que le rôle avait bien pris) :
  l'écran s'affiche donc avant toute connexion ;
- INSERT, UPDATE et DELETE en `anon` refusés en **42501**, au niveau TABLE,
  avant même la RLS ;
- la sortie de la RPC est identique à l'asset, champ par champ : les 38
  différences relevées sont la base qui remplit `estPrerequisDeToutLeReste`
  et `piecesConditionnelles` là où le fichier omet la clé, avec exactement
  les valeurs des `@Default` Dart.

Le pied d'écran doit donc afficher l'origine **serveur** (pas de mention de
liste hors ligne) dès que l'appareil a du réseau — c'est le point de
vérification le plus direct que la chaîne complète fonctionne.

---

## ⛔ Annuaire des ambassades : deux défauts vus sur appareil (2026-09-07)

Trouvés en testant l'écran des démarches sur SM A515F — ils sont dans
`embassies_supabase_datasource.dart` / `20260907190000_annuaire_postes_diplomatiques.sql`,
pas dans le catalogue des démarches. **Les deux bloquent le test hors ligne
des démarches**, l'annuaire étant le seul chemin vers cet écran.

**1. ✅ RÉSOLU — l'annuaire était vide pour TOUS les utilisateurs, en silence.**
`20260907190000` décrivait la colonne du type de poste sous le nom
`post_type`, et `EmbassiesSupabaseDataSource` la sélectionnait sous ce nom,
alors que la table qui tourne l'appelle `type`. Le `select` échouait en 42703,
l'exception devenait `ServerException`, le dépôt retombait sur un cache vide et
renvoyait `[]` : « Aucune ambassade disponible », sans une ligne d'erreur nulle
part. Trouvé sur SM A515F le 2026-09-07 en cherchant un chemin vers l'écran des
démarches.

Dépanné sur le moment par `20260907200000` (ajout de `post_type` recopiant
`type`), puis **tranché dans l'autre sens par l'auteur de l'annuaire**
(`01353ac`) : `type` fait foi, sa migration et son datasource la lisent
désormais. `20260907210000` retire donc la colonne `post_type` devenue
orpheline — deux colonnes décrivant la même chose divergeraient dès la
première fiche modifiée par le back-office.

- [x] **Vu sur SM A515F (2026-09-08).** L'annuaire affiche ses 30 postes
      après le retrait de `post_type`, en ligne comme hors ligne, sur cinq
      passages étalés entre 11h49 et 02h00.

**2. Hors ligne, l'écran affiche une exception brute — avec l'identifiant du
projet Supabase.** Réseau coupé, « Ambassades » montre :

```
Erreur: ServerFailure(RealtimeSubscribeException(status: channelError,
details: WebSocketChannelException: SocketException: Failed host lookup:
'zyrfkcjjrhddpfxcgezo.supabase.co' (OS Error: No address associated with
hostname, errno = 7)))
```

- [~] **À moitié seulement — attention à ne pas croire ce point réglé.**
      Il y a DEUX écrans d'erreur distincts, et un seul est traité :

      - l'**écran rouge de Flutter** (une exception pendant un `build`) est
        couvert depuis le 2026-09-08 par `ErrorWidget.builder`
        (`construireEcranErreurNeutre` dans `main.dart`) ;
      - l'**état d'erreur propre à l'écran** — celui de la capture ci-dessus,
        avec son bouton « Réessayer » — ne l'est PAS. Il affiche
        `error.toString()`, donc l'hôte et l'identifiant, et
        `ErrorWidget.builder` n'y peut rien : ce n'est pas une levée, c'est
        un `AsyncValue.error` rendu volontairement.

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

**Essayé sur SM A515F le 2026-09-08, et voici ce qui s'est réellement passé.**

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

- [ ] ⛔ **`messageErreurUsager` n'a PAS pu être vu sur appareil.** Ni l'un ni
      l'autre des deux états atteignables ne le déclenche :

      - cache peuplé + hors ligne → la copie locale est servie, pas d'erreur ;
      - cache vide + hors ligne → **attente infinie**, voir ci-dessous.

      À reprendre par un écran sans repli local. `Annuaire Business` a été
      essayé : il dégrade en état vide, pas en erreur.

**🆕 Hors ligne avec un cache vide, l'annuaire tourne indéfiniment.** Spinner
toujours présent après 85 s, sans message ni bouton. Le journal en donne la
cause : `SupabaseAuthBridge` réessaie le rafraîchissement du jeton **en
boucle, toutes les ~5 s, sans jamais abandonner** —

```
supabase.auth: WARNING: Notifying exception AuthRetryableFetchException(
  message: ClientException with SocketException: Failed host lookup: …
  uri=…/auth/v1/token?grant_type=refresh_token)
SupabaseAuthBridge: [firebase_auth/network-request-failed] …
```

— et l'annuaire attend derrière. C'est le cas du premier lancement hors ligne
après installation, donc celui d'un usager qui installe l'app dans le train.

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
- [x] **Corrigé et vu sur SM A515F (2026-09-08).** Le repli joue :
      réseau coupé, l'annuaire sert ses 30 postes depuis la copie locale
      (vérifié à 11h52, 12h25 et 02h00, sans réinstaller entre-temps). Ce
      point était par ailleurs faussé par un piège de méthode — voir le n°3
      ci-dessous, `adb install -r` vide le cache.

**3. La vraie cause du n°2 : `.value` sur un `AsyncValue` en erreur.**
Le cas propre a été refait le 2026-09-08 (chargement en ligne, **sans
réinstaller**, puis mode avion). Deux constats.

D'abord, un piège de méthode : **`adb install -r` vide la copie locale**.
Mon premier essai « hors ligne » avait été fait juste après une
réinstallation, donc sur un cache vide — d'où le « Aucune ambassade
disponible » que j'avais pris pour un défaut. Ce n'en était pas un. Sans
réinstaller, l'annuaire sert bien ses 30 postes hors ligne.

Ensuite le vrai défaut. `embassies_provider.dart` lignes 56 et 63 font
`userAsync.value` et `profileAsync.value` sur des providers **observés**. En
Riverpod 2, `AsyncValue.value` **relève** l'erreur au lieu de rendre `null`
quand l'état est `AsyncError`. Hors ligne, la lecture Supabase `users` échoue,
la levée remonte, et tout l'annuaire tombe — en affichant l'hôte Supabase et
l'identifiant du compte, alors que la copie locale attendait juste en dessous.

Le même défaut existait dans `administrative_request_screen.dart` (4
occurrences, dont deux dans `initState`, donc levée avant tout rendu) : **il y
est corrigé**, `.value` → `.valueOrNull`.

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

## ⚠️ Clés dérivées : premier test appareil (2026-09-07, SM A515F)

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

- [ ] **À revérifier après redéploiement de `crypto-keys`** : rouvrir la
      conversation `debef5f0…`, ses 2 messages rechiffrés doivent s'afficher.
- [ ] Puis envoyer un message : il doit partir au format `v1:…` en base.
## ⬜ Teinte des notifications système en vert (2026-09-07)

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

Au passage, ça **solde l'écart** signalé la veille : les deux chemins valaient
`#E07B39` et `#FA7D00`, soit deux orangés différents selon l'état de l'app.
Ils valent maintenant tous deux `#009600`.

Cinq `AndroidNotificationDetails` pointent sur la constante ; le
`general_channel` n'en avait **aucune** (le système ne teintait donc rien sur
ce canal), il en a une désormais.

- [x] **Ressource compilée dans l'APK installé (2026-09-07).**
      `aapt2 dump resources` sur l'APK, dont le `md5sum` a été confronté à
      `base.apk` sur le SM A515F : `color/notification_accent` et
      `color/ic_launcher_background` valent tous deux `#ff009600`. Ça prouve
      la chaîne ressource → paquet installé, pas le rendu à l'écran.
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

---

## ⬜ Icône du lanceur repeinte en vert (2026-09-07)

Suite de l'entrée ci-dessous : sur un vrai téléphone, l'orange qu'on voit en
premier au lancement n'est pas l'écran Flutter mais **l'écran de lancement du
système**, qui affiche l'icône du lanceur (vérifié sur SM A515F : ~15 s sur un
build debug avant que Flutter ne peigne quoi que ce soit).

Repeint : le dégradé orange `#E97424 → #F59942` devient `#009600 → #00C000`
dans `assets/import_icons/dn_ultra_minimal{_icon,_hd}.png` + son SVG source et
`dn_adaptive_background*`, le fond de l'icône adaptive
(`adaptive_icon_background` dans `pubspec.yaml`, `ic_launcher_background` dans
`android/app/src/main/res/values/colors.xml`) et les couleurs web
(`manifest.json`). Les PNG ont été repeints pixel par pixel — le sigle blanc,
son anticrénelage et les coins transparents sont préservés — puis
`dart run flutter_launcher_icons` a régénéré Android, iOS et web.

`dn_dark_mode*` (DN orange sur fond sombre) n'a **pas** été touché : aucun
chemin de l'app ne le lit, il n'est référencé que par le README du dossier.

- [ ] **Icône dans le tiroir d'applications et sur l'écran d'accueil.** Vert
      `#009600`, sigle blanc lisible, forme adaptive correcte (le lanceur
      découpe en cercle/squircle selon le thème du téléphone).
- [x] **Écran de lancement système, vu sur SM A515F (2026-09-07).** Icône
      verte `#009600`, sigle blanc net, aucun reste d'orange. C'est la preuve
      que le paquet installé porte bien la nouvelle icône ; le rendu dans le
      tiroir d'applications n'a pas été retrouvé (l'app n'était pas sur les
      pages parcourues) et reste donc à cocher ci-dessus.
- [ ] **Icône de notification.** Elle est indépendante
      (`ic_stat_notification` + `notification_accent`, toujours orange) : elle
      ne doit pas avoir changé.
- [ ] **iOS.** Icônes régénérées mais jamais compilées ni vues (aucun Mac dans
      la boucle) — cf. l'entrée « iOS : signature et conformité export ».

⚠️ Écart préexistant relevé au passage, **non corrigé** : le commentaire de
`colors.xml` dit que `notification_accent` doit valoir `AppColors.primary`,
or il vaut `#E07B39` alors que `AppColors.primary` vaut `#FA7D00` depuis le
2026-08-25. Deux orangés de notification selon le chemin d'envoi.

---

## ⬜ Écran de démarrage repeint en vert (2026-09-07)

Demande produit : sur l'écran d'attente `/splash` (le premier écran Flutter
affiché, `initialLocation` du routeur), la pastille « DN » et le cercle de
progression passent de l'orange primaire au vert `AppColors.secondary`
(`#009600`) / `secondaryGradient`. Fichier :
[splash_screen.dart](lib/features/auth/presentation/screens/splash_screen.dart).

La teinte est **fixe** : elle ne suit pas l'accent choisi par le compte
(orange ou vert). Un compte en thème Orange verra donc un splash vert puis une
app orange — c'est voulu, pas une dérive à corriger.

- [ ] **Splash au démarrage à froid, thème clair.** Tuer l'app, la relancer :
      pastille « DN » et cercle de progression verts, sigle blanc lisible sur
      le vert, ombre portée verte discrète.
- [ ] **Splash au démarrage à froid, thème sombre.** Même écran sur fond
      `surfaceVariantDark` (`#2D2820`) : vérifier que le vert `#009600` ne
      devient pas terne sur le fond foncé (aucune variante nocturne n'est
      prévue pour cette pastille, contrairement à `primaryGradientDark`).
- [ ] **Compte en thème Orange.** Confirmer que seul le splash est vert et que
      le reste de l'app reste orange (pas de contamination).
- [x] **Sigle et arc du cercle verts, vus sur SM A515F** (thème Système/Orange,
      nuit, APK debug dont le `md5sum` a été confronté à `base.apk` sur
      l'appareil — la première installation avait posé un APK du dépôt
      principal, d'où un premier constat faussement orange).
- [x] **Filet du cercle, vu sur SM A515F (2026-09-07).** Il retombait sur
      `circularTrackColor` du thème, donc brun-orangé pour un compte en thème
      Orange ; épinglé à `secondary` à 20 %, l'anneau est maintenant vert
      sombre sur toute sa circonférence.

---

## ⬜ Clés de repli dérivées, servies par `crypto-keys` (2026-09-06)

Chantier en cours : remplacer la clé AES globale (constante de l'APK, donc
lisible par tout utilisateur, donc **aucune confidentialité entre comptes**)
par des clés dérivées d'une racine qui ne quitte pas le serveur —
`K_conv(convId)` et `K_user(uid)`, HKDF-SHA256.

Livré à ce stade : le refus de dégrader en clair (`EncryptionUnavailableException`),
l'Edge Function `supabase/functions/crypto-keys/`, le banc de vecteurs
`tools/crypto_tests/derivation_croisee.mjs`, et le magasin client
`lib/core/services/crypto/derived_key_store.dart`.

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
- [ ] **Aperçu de notification** après le branchement : le corps doit rester le
      vrai texte (`decrypt_aes_fallback` devra dériver `K_conv`), pas du base64
      ni « Nouveau message ».
- [ ] **Changement de compte** sur le même téléphone : après déconnexion, les
      clés du compte précédent ne doivent plus être lisibles (`vider()`).
- [ ] **Après le rechiffrement de l'existant** (migration `20260907100000`) :
      rouvrir une conversation ancienne. Les 32 messages rechiffrés doivent
      s'afficher normalement. S'ils virent tous à « [Message illisible] »,
      c'est que le `conversationId` ne descend pas jusqu'au déchiffrement —
      exactement le défaut corrigé le 2026-09-07, à re-vérifier là.
- [ ] **Messages du datasource hérité** (RTDB) : ils restent sur la clé
      globale par choix. Vérifier qu'ils s'affichent toujours, eux aussi.

⚠️ La réponse rapide depuis notification (`background_reply_service`) chiffre
depuis un isolate séparé. Ce chemin est de toute façon inaccessible aujourd'hui
(boutons masqués depuis le 2026-08-14), mais s'il est réactivé un jour, il
devra lire le cache du keystore — l'isolate initialise déjà Supabase et les
plugins, donc c'est possible, mais non vérifié.

---

## ⬜ Clé AES de repli : Firebase Functions avait divergé (2026-09-06)

`functions/.env` portait une valeur de `ENCRYPTION_KEY` différente de celle du
client (`_sharedKeyString`, `lib/core/services/encryption_service.dart`). Les
deux font 32 octets, le format et le mode sont identiques (AES-256-CBC, PKCS7,
`ivB64:ctB64`) — seule la valeur divergeait, donc **rien ne le signalait** :
`decryptText` rend le texte chiffré tel quel quand la clé est fausse, sans
exception ni log.

État mesuré avant correction (SHA-256 des valeurs) :

| Emplacement | Verdict |
|---|---|
| Client Dart `_sharedKeyString` | référence — c'est lui qui chiffre |
| `decrypt_aes_fallback()` **en prod** (vérifié via `pg_proc`) | aligné |
| `functions/.env` → `functions/encryption.js` | **divergent** |
| Secret Supabase Edge Functions `ENCRYPTION_KEY` | **divergent** (dormant : aucune Edge Function ne le lit) |
| `.env` racine | divergent, mais **jamais lu** — variable retirée |

Corrigé : `functions/.env` aligné sur le Dart. Prouvé hors appareil par un
aller-retour réel (chiffrement au format client en Node → `decryptText`) :
texte restitué à l'identique après, base64 brut avant.

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

## ⬜ Les deux liens « noter l'app » étaient morts (2026-09-01)

`lib/core/services/support_service.dart` exposait deux constantes fausses,
utilisées ligne 130 selon la plateforme :

- `appStoreUrl` pointait sur `id123456789` — un identifiant inventé. Le vrai
  Apple ID est `6807607258` (fiche App Store Connect créée ce jour).
- `playStoreUrl` pointait sur `com.diasponiger.app`, alors que
  l'`applicationId` réel est `com.diasponiger.diasponiger`.

Autrement dit, l'action « noter l'app » ouvrait une page inexistante **sur
les deux plateformes**. Jamais remonté parce que le bouton s'ouvre dans un
navigateur externe : l'app ne voit pas le 404.

- ⬜ sur SM A515F : déclencher l'action et vérifier que le Play Store ouvre
      bien la fiche Diaspo Niger (et non une page « introuvable »)
- ⬜ côté iOS : invérifiable tant qu'aucun build n'existe, et la fiche App
      Store n'est de toute façon pas publiée — le lien ne résoudra qu'après
      la première mise en vente

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

## iOS : premier build réussi, sur simulateur (2026-09-01)

La cible iOS n'avait **jamais été compilée**. Elle l'est désormais :
`flutter build ios --simulator --debug` aboutit, l'app s'installe et démarre
sur un simulateur iPhone 17 (iOS 26.1), l'écran de connexion s'affiche
correctement et la demande d'autorisation de notifications apparaît — donc
Firebase s'initialise.

Quatre défauts bloquants trouvés et corrigés au passage :

1. **`ios/Podfile` n'avait jamais existé** (absent de tout l'historique git).
2. **`ios/Runner.xcodeproj/project.pbxproj` corrompu** : `GoogleService-Info.plist`
   figurait dans la phase *Resources* en `PBXFileReference` au lieu d'un
   `PBXBuildFile`, sous un UUID inventé (`ABCDEF1234567890ABCDEF12`). CocoaPods
   refusait de s'exécuter, et **le fichier de configuration Firebase n'était pas
   correctement embarqué dans le bundle**.
3. **`NSPhotoLibraryUsageDescription` absent d'`Info.plist`** — seule la variante
   `…AddUsageDescription` (écriture) était déclarée. iOS tue le processus à
   l'ouverture du sélecteur de photos. `NSCalendars…` ajoutées aussi
   (`add_2_calendar`).
4. **Conflit `GoogleDataTransport`** : `firebase_messaging` le veut en `~> 10.0`,
   `mobile_scanner` 5.2.3 en `< 10.0`. Résolu en montant `mobile_scanner` en
   7.4.0 (une signature de `errorBuilder` à adapter) et, dans la foulée,
   `purchases_flutter` 8 → 10.10.1 (RevenueCat 5.32.0 ne compile pas sous le
   Swift d'Xcode 27 ; `purchasePackage` → `purchase(PurchaseParams)`).

Cible de déploiement montée **iOS 12 → 15**, imposée par `GoogleMaps 9.x`.

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

**Parité native Swift — premier passage fait le 2026-09-01.** `AppDelegate.swift`
passe de 15 à 100 lignes. Après lecture de chacun des quatre canaux Android,
deux seulement méritaient d'être portés :

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
- [ ] À vérifier sur appareil : que les liens profonds arrivent bien par ce
      chemin natif iOS, l'hypothèse ci-dessus n'ayant pas pu être testée.

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

Une fois lancée, l'écran de connexion s'affiche immédiatement et correctement
(thème clair, fond crème). Écarté au passage comme régression de la parité
Swift : même comportement avec l'`AppDelegate` d'origine, test A/B fait.

- [x] Écran de connexion vérifié sur simulateur iPhone 17 (iOS 26.1).

## « Se connecter avec Apple » ajouté (2026-09-01)

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

## Supabase branché sur iOS — deux réserves (2026-09-01)

`SUPABASE_ANON_KEY` renseignée, `***** Supabase init completed *****` dans les
journaux, et GoRouter route normalement (`/splash` → `/auth/login`). Le
dialogue App Tracking Transparency s'affiche aussi, donc
`NSUserTrackingUsageDescription` est correcte.

- [x] Initialisation Supabase vérifiée sur simulateur.

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

**2. L'Edge Function `app-config` répond 404.** Le mécanisme de configuration
distante — celui qui permet de changer une clé sans republier — n'est donc pas
opérationnel. L'app retombe proprement sur le `.env` embarqué, rien n'est
cassé, mais rien n'est pilotable à distance non plus.

Vérifié au curl : `/auth/v1/settings` répond 200 (clé et projet valides),
`/rest/v1/` répond 401 sans session (conforme : les RLS bloquent), mais
**toutes** les Edge Functions répondent 404, `gif-proxy` compris. Ce n'est donc
pas propre à `app-config`, et pas propre à iOS non plus.

- [ ] Confirmer si les Edge Functions sont réellement déployées sur
      `zyrfkcjjrhddpfxcgezo` (`supabase functions list`). Si oui, le 404 vient
      d'ailleurs et mérite un examen ; si non, la config distante et le proxy
      GIF sont hors service sur les deux plateformes.

## Liens profonds iOS : la moitié testable est bonne (2026-09-01)

- [x] **Schéma `diasponiger://` reconnu par iOS.** `simctl openurl` déclenche
      bien « Ouvrir dans Diaspo Niger ? » : la déclaration
      `CFBundleURLSchemes` d'`Info.plist` est correcte.
- [x] **Routage vérifié.** `diasponiger:///auth/register` amène bien sur
      « Créer un compte ». **Ça valide la décision de ne PAS porter le canal
      `diaspo_niger/deep_link` sur iOS** : la route est arrivée par le canal de
      navigation de l'embedding — aucune trace du gestionnaire
      `_bindNativeDeepLinks` dans les journaux — donc ajouter le canal aurait
      fait naviguer deux fois.
- [ ] **Universal Links intestables sans compte développeur.**
      `https://diasponiger.web.app/auth/register` s'ouvre **dans Safari**, pas
      dans l'app : l'association de domaine exige une app signée portant
      l'entitlement Associated Domains, plus le fichier AASA validé par le CDN
      d'Apple. Rien à corriger côté code — à revérifier après la première
      signature.

À noter, sans lien avec iOS : les canaux `gsm_state`, `pip` et `proximity` ne
sont implémentés **sur aucune des deux plateformes** — le code Dart de
`proximity_service` et `pip_service` les appelle pourtant explicitement sur
iOS *et* Android. À trancher : implémenter ou retirer.

---

## Notification de message → « Utilisateur », écran bloqué (2026-08-30)

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

## Transfert, Boutique, Salons audio et Podcasts retirés de la grille d'accueil (2026-08-30)

Même traitement, à la demande, sur la seconde grille : les quatre tuiles de
`_ServicesGrid` dans
[home_screen_widgets.dart](lib/features/home/presentation/screens/home_screen_widgets.dart)
sont commentées (elles l'étaient déjà côté
[services_screen.dart](lib/features/home/presentation/screens/services_screen.dart)
depuis le 2026-08-23/27, voir plus bas). Restent trois tuiles inconditionnelles :
Fil, Annuaire, Ambassades.

⚠️ **Salons audio et Podcasts n'ont plus aucun point d'entrée dans l'app.**
Cette grille était leur seul chemin de navigation (ajouté le 2026-08-03 pour
corriger leur injoignabilité totale) ; les deux écrans restent accessibles
uniquement par lien profond direct vers `/audio-rooms` / `/podcasts`. À l'inverse,
Transfert et Boutique restent joignables via les encarts du fil
([internal_ad_card.dart](lib/features/feed/presentation/widgets/internal_ad_card.dart)).

`flutter analyze` propre sur le fichier et sa librairie parente
(`home_screen.dart`). **Non vérifié sur appareil** :
- la grille ne compte plus que 3 tuiles → `items.length >= 4 ? 4 : 3` retombe
  systématiquement sur 3 colonnes ; vérifier que l'alignement et les marges
  restent corrects avec exactement 3 tuiles (aucun trou, pas de tuile étirée) ;
- confirmer au doigt qu'aucun autre raccourci vers `/audio-rooms` ou
  `/podcasts` n'a été oublié ailleurs dans l'app avant de considérer ces deux
  modules comme volontairement injoignables.

**Correctif du même jour** : un audit du code a trouvé qu'un troisième accès
non commenté subsistait — l'encart « Sponsorisé » Salons audio dans le fil
([internal_ad_card.dart](lib/features/feed/presentation/widgets/internal_ad_card.dart)),
poussant vers `/audio-rooms` derrière le même flag. Aucun encart équivalent
n'existait pour Podcasts. L'encart Salons audio est désormais commenté aussi ;
`/audio-rooms` est maintenant dans le même état que `/podcasts` : injoignable
hors lien profond. Point non vérifié sur appareil : confirmer que le fil
n'affiche plus cet encart, et que les trois encarts restants (Transfert,
Groupes, Boutique) tournent normalement sans lui.

---

## ✅ Vidéos envoyées en messagerie traitées comme des documents (2026-08-30)

Bug signalé : une vidéo envoyée en conversation s'affichait et se comportait
comme un fichier générique (`DocumentBubble`), pas comme une vidéo
(`VideoBubble` avec vignette + bouton lecture). Cause : le callback
`onSendFile` de [message_input.dart](lib/features/messages/presentation/widgets/message_input.dart)
ne recevait qu'un booléen `isImage` — toute vidéo (caméra, galerie, sélecteur
dédié) passait donc `isImage: false` et [conversation_screen.dart](lib/features/messages/presentation/screens/conversation_screen.dart)
retombait sur `MessageType.file` faute d'alternative. Le pipeline d'envoi
(miniature blurhash, durée, `VideoBubble`, `VideoPlayerScreen`) existait déjà
et fonctionnait, mais n'était jamais atteint. Corrigé en propageant le vrai
`MessageType` (image/vidéo/fichier) de bout en bout, et en câblant `onTap` sur
`VideoBubble` (absent jusqu'ici) pour ouvrir `VideoPlayerScreen`.
`flutter analyze` propre, `flutter test test/features/messages/message_input_composer_test.dart`
propre.

⚠️ **Piège rencontré en vérifiant** : le premier `flutter install --debug`
(sans `flutter clean` préalable) a réinstallé « avec succès » mais produit un
APK **périmé** — deux vidéos envoyées via la caméra unifiée se sont encore
affichées en `DocumentBubble` malgré le correctif dans les sources. Seul un
`flutter clean` + rebuild complet a fait apparaître le vrai comportement
corrigé (déjà documenté §4 des pièges de build pour une cause différente —
démon Gradle tué — mais même symptôme : succès annoncé, APK pas à jour). Ce
rebuild complet a aussi déconnecté la session au moins une fois (retour à
l'écran de connexion, clés E2EE à restaurer).

- [x] **Envoyer une vidéo depuis la caméra unifiée (`CameraCaptureScreen`),
  mode vidéo explicite, sur SM A515F** : bulle `VideoBubble` correcte
  (cadre 16:9, bouton lecture), confirmée sur le build reconstruit à neuf.
- [x] **Taper sur une bulle vidéo reçue → `VideoPlayerScreen` en plein écran,
  sur SM A515F** : lecteur ouvert, barre de progression et minuteur actifs.
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
- [x] **Vérifier que l'onglet vidéos de la galerie média liste bien les
  nouvelles vidéos envoyées, sur SM A515F** : « Options de la conversation »
  → « Médias partagés » → onglet « Vidéos · 3 » affiche bien les 3 vidéos
  envoyées dans la conversation, en grille avec vignette + bouton lecture.

---

## ✅ Bulle de chargement d'une vidéo pendant l'upload (2026-08-30)

Suite du point précédent : demande produit de retoucher le design pendant
l'envoi. Avant ce correctif, l'upload d'une vidéo affichait le squelette
générique « document » (`_buildDocumentUpload` dans
[uploading_media_skeleton.dart](lib/features/messages/presentation/widgets/uploading_media_skeleton.dart)
— petite icône de fichier + nom + `%`), car `MediaUploadState` ne
transportait qu'un booléen `isImage`, jamais `true` pour une vidéo. Corrigé
en remplaçant ce booléen par le vrai `MessageType` (même schéma que le
correctif précédent) et en ajoutant une branche `_buildVideoUpload` : vraie
vignette extraite localement du fichier vidéo via `video_thumbnail`
(`_VideoThumbnailPreview`, package déjà présent pour le blurhash serveur),
assombrie + effet shimmer comme l'aperçu image, badge caméra en coin haut
gauche (même langage visuel que `VideoBubble`), anneau de progression +
bouton annuler, légende si saisie. `flutter analyze` propre sur tout le
dépôt.

- [x] **Envoyer une vidéo (caméra unifiée) et observer la bulle pendant
  l'upload, sur SM A515F** : vignette assombrie + badge caméra + anneau de
  progression affichés (capture prise pendant l'upload, avant la fin) ; la
  bulle finale devient bien `VideoBubble` à la fin, aucune régression.
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

---

## ✅ Badge de durée manquant sur les bulles vidéo (2026-08-30)

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

## ⬜ Configuration distante `app-config` (2026-08-27)

L'app va chercher sa configuration publique auprès de l'Edge Function
`app-config` au démarrage, avec le `.env` embarqué en filet.
Fichiers : `supabase/functions/app-config/index.ts`,
`lib/core/services/remote_config_service.dart`, `lib/core/constants/app_config.dart`.

`flutter analyze` propre, 330/330 tests passent — mais aucun test ne démarre
l'app réelle ni n'atteint le réseau. Les quatre chemins à voir sur appareil :

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

## ⬜ GIFs via `gif-proxy` — clés sorties de l'APK (2026-08-27)

`GIPHY_API_KEY` et `TENOR_API_KEY` ne sont plus dans le `.env` embarqué : les
appels passent par l'Edge Function `gif-proxy`, seule détentrice des clés.
Fichiers : `supabase/functions/gif-proxy/index.ts`,
`lib/features/gifs/data/datasources/{giphy,tenor}_datasource.dart`.

`flutter analyze` et les 11 tests GIF passent, mais aucun n'atteint le réseau —
rien n'est prouvé tant que ce n'est pas vu sur appareil :

- [ ] Onglet GIFs : les tendances se chargent (chemin `trending`)
- [ ] Recherche : taper un mot renvoie des résultats (chemin `search`)
- [ ] Onglet Stickers : fonds transparents (paramètre `type=sticker`)
- [ ] Repli : avec une seule clé posée côté serveur, l'autre fournisseur doit
      répondre 503 et le picker rester fonctionnel — c'est le seul chemin que
      les tests ne couvrent pas du tout
- [ ] Envoyer un GIF dans une conversation aboutit toujours

⚠️ Prérequis : `supabase functions deploy gif-proxy` **et** les deux clés
posées en secrets, sinon l'onglet reste vide.

---

## ✅ Recolorisation orange/vert — vue sur appareil, partiellement (2026-08-25)

Demande produit : `AppColors.primary`/`primaryDark` (orange) `#E05206`/`#9F3E0A`
→ `#FA7D00` unique (`#FC7C00` d'abord appliqué puis corrigé en cours de session),
`AppColors.secondary`/`secondaryDark` (vert) `#0DB02B`/`#06871D` → `#009600`
unique. Appliqué dans [app_colors.dart](lib/core/constants/app_colors.dart) et
propagé aux ~19 fichiers qui dupliquaient ces hex en dur (bulles de message,
accueil, groupes, événements, transferts, annuaire entreprises, ambassades...).
`flutter analyze` propre.

- [x] **Thème Système/Orange, sombre, sur SM A515F (build debug réinstallé,
  `lastUpdateTime` confirmé postérieur au commit)** : splash `DN`, bouton
  « Ajouter mon pays », onglet actif « Messages », avatar « SL », icônes
  « Le fil »/« Annuaire » en `#FA7D00` — texte/icônes blancs bien lisibles
  dessus. Avatars de groupe et bulle de message envoyée en `#009600` — lisible
  aussi. Capture confirmée à l'œil, pas de risque de contraste constaté.
- [ ] Thème clair (Orange et Vert) jamais vu avec ces valeurs.
- [ ] Thème Système/**Vert** (bascule complète primary↔secondary dans
  `app_theme.dart`, pas juste les bulles/avatars qui restent verts quel que
  soit le thème) jamais vu avec ces valeurs.
- [ ] Comparer visuellement `primary`/`primaryDark` maintenant identiques
  (plus de dégradé entre les deux dans les endroits qui s'appuyaient dessus,
  ex. `primaryGradient`) — pas vérifié à l'œil, juste déduit du code.

---

## ✅ Le thème choisi ne survivait jamais à un redémarrage — corrigé (2026-08-25)

Découvert en essayant de vérifier la pastille « DN » en clair/vert sur le
SM A515F (cf. entrée plus bas sur les illustrations d'onboarding). Réglages →
Thème → Clair + Vert s'écrivait correctement sur disque
(`FlutterSharedPreferences.xml` : `theme_mode=light`, `theme_color=green`),
mais après `am force-stop` + relance à froid, l'app retombait
systématiquement sur Système + Orange.

**Cause confirmée** : `ThemeModeNotifier.build()` / `ThemeColorNotifier.build()`
dans [theme_provider.dart](lib/core/theme/theme_provider.dart) appelaient
`_loadTheme()`/`_loadColor()`, des méthodes `async` **sans aucun `await`
interne** — Dart les exécute donc de façon synchrone à l'appel, et
`state = mode` s'exécutait bien mais *pendant* `build()`, juste avant que
`build()` n'écrase avec son propre retour `system`/`orange`. Corrigé en
faisant lire `build()` directement dans les préférences (commit `fc9ea35`).
Test de non-régression : [theme_provider_test.dart](test/core/theme/theme_provider_test.dart)
(confirmé qu'il échoue sur l'ancien code, passe sur le nouveau). Détails :
mémoire `project_theme_pref_not_restored`.

- [x] **Reconfirmé sur SM A515F, même cycle** : Réglages → Clair + Vert →
  `force-stop` + relance à froid → **accueil rendu en crème/vert**, pour la
  première fois (avant le correctif, ce cycle retombait toujours en
  sombre/orange, reproduit deux fois).
- [x] Pastille « DN » (`AuthBrandMark`, écran de connexion) vue en clair/vert
  sur l'appareil — capture envoyée à Salim. Les deux lettres tiennent dans
  le carré 46×46.
- [ ] Combinaison sombre + accent vert jamais vue à l'œil sur cet appareil
  (comportement attendu vu le correctif, mais pas observé).

Appareil laissé propre : réglages restaurés à `system`/`orange` (valeurs
d'origine) via l'IU avant de rendre la main.

---

## Bandeau « Restaurez vos clés » toujours répété malgré la mise en veille du 22/08 (2026-08-25)

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

## Sigle « DN » corrigé + illustrations d'onboarding générées (2026-08-25)

Demande de Salim : la pastille de marque affichait un seul « D » à deux
endroits au lieu de « DN » ; et les 5 écrans d'onboarding n'avaient jamais eu
de vraie illustration (juste un pictogramme Material générique sur fond
rayé, en attente explicite dans le commentaire du code).

- **Sigle** : [auth_scaffold.dart](lib/features/auth/presentation/widgets/auth_scaffold.dart)
  (`AuthBrandMark`, écrans de connexion/inscription) et
  [design_kit.dart](lib/core/theme/design_kit.dart) (`DesignIllustration`,
  repli `brandMark`) — `'D'` → `'DN'`, taille de police réduite (24→17 et
  32→21) pour que les deux lettres tiennent dans la même pastille.
- **Illustrations** : nouveau fichier
  [onboarding_illustrations.dart](lib/features/onboarding/presentation/widgets/onboarding_illustrations.dart),
  une composition par écran (cercle teinté + pictogramme + pastilles
  d'accent, en widgets Flutter — pas des PNG — pour rester adaptatif au
  thème sombre et à la couleur d'accent choisie). Écran « fête de la
  République » (onboarding 4/5) utilise les couleurs du drapeau (orange
  `AppColors.primary` / blanc / vert `AppColors.secondary`) en dur, volontairement
  indépendantes de la couleur d'accent du compte.
- `DesignIllustration` gagne un paramètre `illustration` (widget) qui prend le
  pas sur `icon`/`brandMark` ; `OnboardingPageData` ne porte plus `icon`ni
  `brandMark`, seulement `illustration`.
- **Légendes** (`onbWelcomeIllustration` etc., `app_fr.arb`/`app_en.arb`) :
  retiré le préfixe « illustration — » (« illustration — la diaspora » →
  « la diaspora »), redondant maintenant qu'une vraie composition existe.

`flutter analyze` propre.

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
- [ ] Pastille « DN » en **accent vert** et en **thème sombre** : toujours pas
  vue sur appareil (l'écran de connexion s'ouvre en clair/orange par défaut,
  et l'accent vert dépendait du compte de test dont la session est perdue).
- [x] Écran « fête de la République » (onboarding 4/5) : les 3 pastilles
  orange/blanc/vert restent lisibles sur fond sombre, celle en blanc se
  détache bien grâce au cerclage `borderStrongColor`. Vu sur SM A515F.

---

## Le sondage de groupe s'affiche enfin : bulle dans la discussion (2026-08-24)

Créer marchait (correctif RLS de la veille) mais **aucun écran n'affichait les
sondages de groupe** : `groupPollsProvider` n'était watché nulle part,
`PollCard` n'était montée que pour les posts du fil, et rien ne créait jamais
d'épingle de type `poll`. La ligne de `post_polls` existait, lisible, et
restait invisible partout. Vérifié sur appareil le 2026-08-24 : sondage créé
(« egggyy », 2 options), introuvable à l'écran.

Le sondage arrive maintenant comme **bulle dans la conversation** :
`MessageType.poll` + `pollId` sur le message, `PollMessageBubble` qui relit
`post_polls` et monte `PollCard` (vote intégré). La bulle ne porte que l'id :
voter ne réécrit jamais le message, c'est la carte qui se met à jour.

Côté base ([20260824010000_poll_message_realtime_et_apercu.sql](supabase/migrations/20260824010000_poll_message_realtime_et_apercu.sql),
appliqué en production) : `post_polls` et `post_poll_options` entrent dans la
publication `supabase_realtime` avec `REPLICA IDENTITY FULL` — sans ça le
`.stream()` de `PollCard` ne faisait que son chargement initial et aucun vote
n'apparaissait ; et `message_preview_for_notification` connaît le type `poll`,
sinon la notification affichait « 🔒 Nouveau message ». Vérifié en base :
`realtime: post_polls, post_poll_options` et `apercu poll = 📊 Sondage`.

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

⚠️ Non couvert, à savoir : la question du sondage est écrite **en clair** dans
`messages.data.content`, exactement comme l'adresse d'une position partagée —
le transport « structuré » de ce projet n'est pas chiffré. Si ça doit changer,
c'est un chantier commun position/sticker/sondage, pas propre au sondage.

## ⚠️ COLLISION DE MIGRATION — à lire par l'autre agent (2026-08-23)

**Le correctif RLS des sondages est déjà livré et déjà appliqué en production**
(`20260823180000_fix_post_poll_options_rls.sql`, commits `0514986` / `8a51664`
/ `ae7dfd5`).

Le worktree `.claude/worktrees/sondage-options-rls` porte, non committé, un
fichier `20260823180000_rls_post_poll_options_insert_et_compteurs.sql` — **le
même préfixe d'horodatage `20260823180000`**. Git ne verra jamais le conflit
(les noms diffèrent après le préfixe, la fusion passera sans broncher), mais
`supabase_migrations.schema_migrations` indexe par ce préfixe **seul** : la
version est déjà enregistrée, donc ce second fichier sera **ignoré en silence**
au `db push`. Le croire appliqué serait faux.

Ce qu'il faut faire avant de livrer dessus :

1. `git fetch && git merge origin/wip-jules-2025-12-29T23-58-34-776Z`, puis
   comparer le contenu — la politique `Poll owners can add options` et le
   passage des triggers `increment/decrement_poll_vote_count` en
   `SECURITY DEFINER` sont **déjà en production** (vérifié : `prosecdef=true`,
   politique présente dans `pg_policies`).
2. Si le fichier local n'apporte rien de plus : le supprimer.
3. S'il apporte autre chose : le **renuméroter** après `20260823180000`
   (jamais avant), et vérifier avec la commande de CLAUDE.md :
   `ls supabase/migrations | sort | awk -F_ '{print $1}' | uniq -d`.

Le datasource `lib/features/polls/data/datasources/poll_supabase_datasource.dart`
est modifié des deux côtés (ici : nettoyage de la question orpheline si les
options échouent). Comparer avant de livrer, la zone est la même.

## Créer un sondage était impossible pour tout le monde (2026-08-23)

`post_poll_options` a le RLS activé et **aucune politique INSERT** : la
création se fait en deux écritures (la question dans `post_polls`, puis ses
options), et la seconde était refusée `42501` pour tout le monde, depuis
toujours. Signature en production : 6 questions, **toutes sans une seule
option** — les tentatives successives d'un même utilisateur.

Corrigé par
[20260823180000_fix_post_poll_options_rls.sql](supabase/migrations/20260823180000_fix_post_poll_options_rls.sql),
**appliqué en production** le 2026-08-23. Même migration : les triggers de
comptage passent en `SECURITY DEFINER` (leur `UPDATE` sur
`post_poll_options` / `post_polls` était soumis au RLS de l'appelant, qui n'a
aucune politique UPDATE → 0 ligne touchée, sans erreur : le vote était
enregistré mais les compteurs restaient à 0).

Vérifié en base (transaction annulée, rôle `authenticated`, `request.jwt.claims`
posé) : création 2 options ✅, vote → `vote_count=1` / `total_votes=1` ✅,
retrait du vote → retour à 0 ✅, et un **non-propriétaire** reste refusé ✅.

À vérifier sur appareil :

- [ ] Groupe → trombone → **Sondage** : question + 2 options → « Publier ».
      La feuille se ferme sans erreur et le sondage apparaît **avec ses
      options** (avant : « Impossible de créer le sondage »).
- [ ] Voter : la barre et le compteur bougent (avant : figés à 0).
- [ ] Retirer/changer son vote : le compteur redescend.
- [ ] Fil → nouveau post → **Sondage** joint : le sondage s'affiche sous le
      post publié. En cas d'échec, le toast dit maintenant « Publication
      créée, mais le sondage n'a pas pu être joint »
      ([create_post_screen.dart](lib/features/feed/presentation/screens/create_post_screen.dart)).
- [ ] Message d'erreur : la feuille affiche désormais la cause réelle et non
      plus un texte générique
      ([create_poll_sheet.dart](lib/features/polls/presentation/widgets/create_poll_sheet.dart)).

Les **6 questions orphelines** (sans option) laissées par les tentatives
échouées ont été supprimées en base le 2026-08-23, sur accord — `post_polls`
est reparti de zéro. Il n'y a donc plus aucun sondage en production : le
premier créé après ce correctif est aussi le premier test.

## Transfert et Boutique retirés de « Tous les services » (2026-08-23)

Deux tuiles de la grille de
[services_screen.dart](lib/features/home/presentation/screens/services_screen.dart)
— « Transfert » (`/transfers`) et « Boutique » (`/marketplace`) — sont
commentées (`TODO(services)`), à la demande. Restent cinq entrées : Fil,
Annuaire et Ambassades (toujours affichées, décision produit 2026-08-19),
Salons audio et Podcasts (chacune derrière son drapeau).

`flutter analyze` propre sur le fichier. **Non vérifié sur appareil** :
- la grille 2 colonnes se réordonne (Annuaire remonte en première ligne à
  côté du Fil) — vérifier qu'il ne reste ni trou ni tuile orpheline, et que
  le cas « drapeaux salons/podcasts à faux » laisse une grille de 3 tuiles
  correctement alignée ;
- les deux routes restent joignables ailleurs (raccourcis de l'accueil dans
  [home_screen_widgets.dart](lib/features/home/presentation/screens/home_screen_widgets.dart),
  encarts du fil dans
  [internal_ad_card.dart](lib/features/feed/presentation/widgets/internal_ad_card.dart))
  — confirmer au doigt que ces chemins-là marchent toujours, sinon les deux
  modules deviennent inatteignables.

---

## E2EE réparé : la clé de signature est publiée avec le bundle (2026-08-23)

Suite de l'entrée « La signature de clé pré-signée ne peut JAMAIS vérifier ».

La signature est produite par une paire **Ed25519 dérivée de la clé privée
X25519 prise comme graine**. Sa publique n'a aucun rapport avec la publique
X25519, et le vérifieur — qui n'a pas la privée — ne peut pas la recalculer.
Elle est donc désormais **publiée avec le bundle**, dans le JSONB
`e2ee_devices.signed_pre_key` sous la clé `identitySigningKey`.

**Aucune migration** : la publication est rejouée à chaque `initialize`, et
`_ensurePublishedToSupabase` republie maintenant aussi quand ce qui est publié
est **incomplet** — pas seulement quand la ligne manque. Sans cette seconde
condition, les appareils déjà publiés n'auraient jamais repassé par la
publication et le correctif n'aurait rien changé pour eux. C'est le piège dans
lequel je suis tombé au premier essai : le code était bon, la clé n'était
jamais écrite.

Un appareil qui n'a pas encore republié n'a pas le champ : sa signature est
invérifiable, on n'établit pas de session, et le repli AES devient **visible**
grâce au cadenas ouvert. Plus de « SECURITY ALERT / Possible MITM » trompeur
pour ce cas — il est réservé à une vraie signature invalide.

### Vérifié sur SM A515F

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

### Ce qui reste, et qui ne peut pas être vérifié avec un seul téléphone

- [ ] **Une vraie session Signal de bout en bout.** Elle demande que les DEUX
      côtés aient republié. Un seul appareil a la nouvelle version : tous les
      autres comptes sont encore sans `identitySigningKey`, donc tout reste en
      AES. À revérifier quand un second téléphone aura la mise à jour — le
      signal attendu est un message dont `encryptionLevel` vaut `e2ee` **et**
      qui reste lisible des deux côtés.
- [ ] **Que ça suffise.** Le correctif débloque `establishSession`, mais ce
      chemin n'a jamais tourné en vrai : rien ne dit qu'il n'y a pas d'autre
      défaut en aval (X3DH, Double Ratchet, multi-appareils). Le premier
      échange réel entre deux appareils à jour est le seul juge.

### Décision toujours ouverte

Tant qu'aucun échange E2EE réel n'est constaté, l'app continue d'**affirmer**
le chiffrement de bout en bout dans son interface (phrase de l'écran de
recherche, « Message chiffré »). Ce n'est pas encore vrai. Soit on confirme que
le correctif suffit, soit on retire l'affirmation.

---

## La signature de clé pré-signée ne peut JAMAIS vérifier (2026-08-23)

Le « SECURITY ALERT — Possible MITM attack » du journal n'est ni une clé
corrompue ni une attaque : **les deux côtés n'utilisent pas la même clé
publique.**

- **Signature**, `KeyManagerService._sign` : l'Identity Key est une paire
  **X25519**, et sa clé **privée** sert de graine à une paire **Ed25519** qui
  produit la signature.
- **Vérification**, `MessagingE2EEService._verifySignedPreKeySignature` : elle
  vérifie avec les octets de l'Identity Key **publique X25519**, simplement
  réétiquetés `KeyPairType.ed25519`.

Or `Ed25519.newKeyPairFromSeed(privéeX25519).publicKey` n'a aucun rapport avec
`publiqueX25519` : les deux courbes dérivent la publique différemment. La
vérification est donc **structurellement impossible à passer, pour tout le
monde, depuis toujours**.

Prouvé par
[signed_pre_key_signature_test.dart](test/core/services/e2ee/signed_pre_key_signature_test.dart),
qui rejoue les deux fonctions de l'app : la vérification échoue, la même
signature passe avec la bonne clé Ed25519, et les deux publiques ne sont jamais
égales.

Le vrai Signal utilise XEdDSA — signer avec la privée X25519, vérifier avec la
publique X25519 convertie en Ed25519 par l'application birationnelle. Le paquet
`cryptography` ne fournit pas XEdDSA. Ce code ne fait ni l'un ni l'autre.

### Ce que ça entraîne, en cascade

`establishSession` **lève** dès qu'il vérifie → aucune session Signal ne peut
s'établir avec qui que ce soit → la distribution de Sender Key échoue toujours
→ les groupes restent en AES, et le 1-à-1 aussi (`encrypt1to1` rattrape
l'exception et retombe sur AES en silence).

Mesuré en base le 2026-08-23, sur toute la table `messages` :

| `encryptionLevel` | messages |
|---|---|
| `aes` | 33 |
| `null` (ancien, en clair) | 10 |
| `e2ee` | 3 |

Et les 3 `e2ee` sont exactement les messages de groupe **que personne ne peut
lire** (Sender Key jamais distribuée, cf. entrée dédiée). Autrement dit :
**aucun message lisible n'est chiffré de bout en bout aujourd'hui.** Tout passe
par la clé AES partagée, qui est embarquée dans l'APK *et* recopiée dans une
fonction Postgres (`decrypt_aes_fallback`) pour les aperçus de notification.

### Ce que ça veut dire pour l'utilisateur

L'app **affirme** le chiffrement de bout en bout : cadenas dans l'en-tête,
« Message chiffré » sur les bulles, et cette phrase dans la recherche — « Le
contenu des messages est chiffré de bout en bout : il ne peut pas être cherché
depuis le serveur ». Cette affirmation est fausse en l'état.

- [ ] **Décision à prendre** avant tout correctif : soit réparer le E2EE, soit
      cesser de l'affirmer dans l'interface. Les deux sont défendables ; laisser
      les deux en l'état ne l'est pas.
- [ ] **Non vérifié** : que réparer la signature suffise. Elle débloque
      `establishSession`, mais rien ne dit qu'il n'y a pas d'autre défaut en
      aval — le chemin n'a jamais tourné en vrai.

### Piste de correctif (non implémentée)

La signature est produite par une paire Ed25519 déterministe, dérivée de la
graine de l'Identity Key. Sa clé **publique** est donc calculable par le
publieur, mais pas par le vérifieur. Il faut donc la **publier** dans le
bundle, à côté de l'Identity Key, et vérifier contre elle.

Conséquences à trancher : une colonne de plus, une republication des clés par
tous les appareils, et une règle pour les bundles existants qui n'ont pas le
champ (les traiter comme « pas de E2EE » — repli AES, désormais visible grâce
au cadenas ouvert).

---

## Le repli AES d'un groupe est désormais signalé (2026-08-23)

Le trou laissé ouvert par le correctif Sender Key : un groupe pouvait tourner
en repli AES **indéfiniment, sans que rien ne le dise** — ni l'app, ni un
compteur. On ne pouvait le découvrir qu'en lisant `encryptionLevel` en base,
message par message.

Le cadenas de l'en-tête de conversation était **fermé en toutes
circonstances**. Il dit maintenant la vérité :

- Sender Key distribuée à tous → cadenas fermé, inchangé.
- Repli AES → **cadenas ouvert + « Chiffrement partagé »** en couleur
  d'avertissement, et l'appui ouvre une feuille qui explique ce que ça change
  et **nomme les membres concernés**.
- Tant que la distribution n'a pas répondu → rien n'est affirmé (`unknown`),
  cadenas fermé comme avant. Afficher un cadenas fermé *par défaut* était
  précisément ce qui masquait le problème ; le laisser pendant la mesure est un
  compromis assumé, la mesure prenant moins d'une seconde.

Deux causes distinctes de repli, deux textes différents — accuser un membre
quand c'est notre propre appareil qui n'a pas ses clés serait faux :

- des membres n'ont pas reçu la clé → ils sont nommés ;
- nos clés locales ne sont pas prêtes → renvoi vers Réglages › Sécurité.

**Un défaut trouvé en route, et corrigé** : `distributeSenderKey` **lève** quand
les clés publiées d'un membre ne vérifient pas. La boucle de
`distributeSenderKeyToGroup` avortait donc au premier membre fautif, les
suivants n'étaient jamais tentés, et l'exception remontait jusqu'au `catch` de
`MessageCryptoService` — qui rendait `null`, donc aucun compte rendu, donc
aucun signalement. Chaque membre est maintenant tenté indépendamment.

### ⚠️ À REGARDER : les clés du compte plateforme ne vérifient pas

Relevé dans logcat en ouvrant « Diaspora Niger — Canada » :

```
MessagingE2EEService: SECURITY ALERT — signed pre-key signature verification
FAILED for czk5UoUclLOFmbRtUIZ5XYLYKo52
MessageCryptoService: Sender Key setup failed: Bad state: Signed pre-key
signature verification failed. Possible MITM attack.
```

`czk5UoUclLOFmbRtUIZ5XYLYKo52` est le compte **`diaspo_ne`** (le compte
plateforme, créateur des groupes officiels). Sa clé pré-signée publiée ne passe
pas la vérification de signature. Conséquence directe : **aucun groupe
contenant ce compte ne pourra jamais activer le chiffrement de groupe** — la
distribution échouera toujours sur lui.

Confirmé côté base : `e2ee_sender_key_distributions` ne contient **aucune**
ligne pour ce groupe.

Cause non établie — clé réellement corrompue à la publication, ou défaut du
code de vérification. À trancher avant de conclure quoi que ce soit sur un
« MITM ».

### Vérifications

- [x] Logique couverte par
      [group_encryption_status_test.dart](test/features/messages/group_encryption_status_test.dart)
      (9 tests) : distribution complète / partielle / impossible, et le fait
      qu'un groupe sans autre membre ne compte pas comme « chiffré ».
- [x] **Rendu vérifié** le 2026-08-23 : « Diaspora Niger — Canada » affichait
      « 3 membres 🔓 Clé partagée » dans l'en-tête.
- ⚠️ **RETIRÉ le 2026-08-23**, à la demande de Salim : d'abord le libellé, puis
      le cadenas ouvert. L'en-tête ne signale donc plus rien — le cadenas §4a
      est de nouveau fermé en toutes circonstances, et la feuille explicative
      (qui nommait les membres sans clé) n'est plus atteignable.

      **Ce qui reste pour savoir où en est un groupe** : le provider
      `groupEncryptionStatusProvider`, toujours alimenté, et les journaux de
      `SenderKeyService` (« Sender Key remise à N/M membres — repli AES
      maintenu »). Rien dans l'interface.

      Le trou d'origine — « un groupe reste en AES sans que rien ne le dise » —
      est donc **rouvert côté utilisateur**, volontairement.
- [ ] Vérifier aussi le cas nominal : un groupe dont tous les membres ont des
      clés valides doit garder le cadenas fermé, sans mention.

---

## Sender Key : l'envoi fabriquait une clé que personne n'avait — RÉSOLU (2026-08-23)

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

## Le message de groupe illisible par son propre expéditeur — CAUSE TROUVÉE (2026-08-23)

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

## `MaÃ¯daoua` : l'échange de jeton Firebase corrompait le nom en base (2026-08-23)

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

## Mentions de groupe : vérifié sur SM A515F (2026-08-23)

Build debug installé sur l'appareil, compte `Sim A`, groupe « Diaspora
Niger — Canada » (3 membres).

**Défaut trouvé sur appareil, invisible aux tests : la liste de suggestions ne
s'ouvrait jamais.** `groupMentionCandidatesProvider` était un
`FutureProvider.autoDispose.family` **clé par `List<String>`**. Une `family`
Riverpod compare ses clés avec `==`, et deux `List` de même contenu ne sont
jamais égales en Dart : chaque `build` de l'écran créait donc une nouvelle
instance de provider, qui repartait en chargement, et `.valueOrNull` rendait
`null` indéfiniment. La clé est désormais l'identifiant du groupe, et ce n'est
plus un `FutureProvider` (il ne fait que lire d'autres providers).

Le prédécesseur `groupMemberNamesProvider` avait exactement la même forme :
**mentionner quelqu'un dans un groupe n'avait probablement jamais fonctionné**,
quelle que soit la forme du pseudo.

- [x] Taper `@sa` ouvre la liste — « Salim L. » en titre, `@SalimL` en
      sous-titre. Le filtre trouve bien par le **début d'un mot** du nom
      affiché, pas seulement par le début du nom complet.
- [x] Sélectionner insère `@SalimL ` — pseudo sans espace, espace après,
      curseur derrière, liste refermée. Le point de « Salim L. » est bien
      retiré.
- [x] Le membre `diaspo_ne` n'apparaît pas sur `@sa` : le filtrage est correct,
      il ne propose pas tout le monde.
- [ ] Coloration de la mention dans la bulle — **bloqué**, pas par les
      mentions : le message envoyé s'affiche « clé de groupe introuvable »
      (voir l'entrée E2EE ci-dessus). Le contenu n'est pas rendu comme du
      texte, donc rien à colorer.
- [ ] Tap sur la mention → ouvre le profil — bloqué par la même chose.
- [ ] Compte **avec** poignée : vérifier que c'est `@diaspo_ne` qui est inséré
      et non l'identifiant. Le filtre `@sa` ne le proposait pas ; à retenter
      avec `@dia`.
- [x] Le garde anti-e-mail fonctionne — trop bien, même : un `@` précédé d'un
      caractère de mot n'ouvre pas la liste. Rencontré pour de vrai, un
      brouillon `@sa` restant en place faisait que le second `@sa` tapé
      derrière n'ouvrait rien. C'est le comportement voulu, mais il surprend.

---

## Mentionner quelqu'un par son pseudo dans un groupe (2026-08-23)

Mentionner dans un groupe insérait le **nom affiché complet** :
`@Ibrahim Yacouba Maïdaoua`. Un jeton à espaces, que la détection ne savait pas
relire — `_detectMentionTrigger` abandonne dès qu'une espace apparaît dans la
saisie, donc seul le **premier mot** était cherchable, et taper `@Maï` ne
proposait personne.

Les messages passent au même pseudo que le fil
([mention_handle.dart](lib/core/utils/mention_handle.dart)) : la **poignée
publique** (`users.handle`) quand la personne en a choisi une, sinon le pseudo
dérivé du nom. Au 2026-08-23, 2 comptes sur 11 seulement avaient une poignée —
le repli est le cas courant, pas le cas limite.

Ce qui change :

- [group_pinned_providers.dart](lib/features/groups/presentation/providers/group_pinned_providers.dart) :
  `groupMemberNamesProvider` → `groupMentionCandidatesProvider`, qui porte
  aussi la poignée (nouveau type `MentionCandidate`).
- [message_input.dart](lib/features/messages/presentation/widgets/message_input.dart) :
  filtrage sur le pseudo **et sur chaque mot** du nom affiché, accents repliés
  (`@mai` trouve « Maïdaoua » — taper `ï` demande un appui long au clavier) ;
  insertion du pseudo ; un `@` collé à un caractère de mot n'ouvre plus la
  liste (adresse e-mail en cours de frappe).
- [mention_suggestion_overlay.dart](lib/features/messages/presentation/widgets/mention_suggestion_overlay.dart) :
  la ligne montre le nom **et** le `@pseudo` — on choisissait un `@` sans
  savoir à qui il correspondait.
- [message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart) :
  la mention devient **cliquable** (elle était colorée et c'est tout) et ouvre
  le profil, comme dans le fil ; les motifs de coloration sont triés du plus
  long au plus court, sinon `@Ali` placé avant `@Alichina` ne colorait que les
  trois premières lettres de la seconde.

Les messages déjà envoyés portent le nom affiché dans `mentionedUsers[].name` :
le rapprochement se fait sur ce qui est stocké, ils restent donc colorés et
cliquables tels quels.

14 tests dans
[mention_groupe_test.dart](test/features/messages/mention_groupe_test.dart).

**À vérifier sur appareil** (nécessite un groupe avec au moins deux membres) :

1. Dans un groupe, taper `@` puis `mai` → la personne doit apparaître, avec son
   nom en titre et `@pseudo` en dessous.
2. La sélectionner → le texte doit contenir `@<pseudo>` **sans espace**, suivi
   d'une espace, curseur juste après.
3. Envoyer → la mention doit être colorée en entier dans la bulle, chez
   l'expéditeur comme chez le destinataire.
4. **Taper sur la mention** → doit ouvrir le profil de la personne.
5. Sur un compte qui a choisi une poignée (`@…` dans Profil), vérifier que
   c'est bien elle qui est insérée, et pas le nom collé.
6. Taper une adresse e-mail (`a@b.com`) dans un groupe : la liste de
   suggestions ne doit **pas** s'ouvrir.
7. Ouvrir un ancien message qui contient une mention : elle doit rester colorée.

**Non traité** : mentionner quelqu'un dans un groupe ne produit pas de
notification distincte — le déclencheur SQL envoie déjà une notification de
message à tous les participants, une notification « mention » demanderait une
migration.

**Dette laissée en place** : les `TapGestureRecognizer` des liens, téléphones et
désormais mentions sont créés à chaque `build` sans être libérés. C'était déjà
le cas pour les liens ; corriger l'ensemble est un chantier à part.

---

## Le pseudo de mention mangeait les lettres accentuées (2026-08-23)

`_toMentionHandle` produisait le `@pseudo` avec
`replaceAll(RegExp(r'[^\w]'), '')`. En Dart, `\w` vaut `[A-Za-z0-9_]` — de
l'ASCII pur : mentionner « Ibrahim Yacouba Maïdaoua » écrivait
`@IbrahimYacoubaMadaoua`, le `ï` purement supprimé. Même effet sur « Aïcha »,
« Boubé », ou tout nom non latin (`李明` donnait une chaîne vide).

Quatre endroits partageaient la même limite ASCII et sont passés sur
[mention_handle.dart](lib/core/utils/mention_handle.dart) :

- génération, détection et remplacement du pseudo dans
  [mention_text_field.dart](lib/features/feed/presentation/widgets/mention_text_field.dart) ;
- coloration en direct dans le champ de saisie
  ([hashtag_highlighting_controller.dart](lib/features/feed/presentation/widgets/hashtag_highlighting_controller.dart)) ;
- reconnaissance de la mention à l'affichage
  ([rich_text_parser.dart](lib/core/utils/rich_text_parser.dart)) — le motif
  s'arrêtait au `ï`, la mention n'était donc ni colorée en entier ni cliquable ;
- résolution du profil au tap dans
  [post_card.dart](lib/features/feed/presentation/widgets/post_card.dart) et
  [comment_tile.dart](lib/features/feed/presentation/widgets/comment_tile.dart).

**Repli sur les deux formes.** Les publications et commentaires déjà en base
portent l'ancien pseudo, dans leur texte comme dans `mentioned_users[].name`,
et rien ne les réécrit. `mentionHandleMatches` compare les deux réduits à
l'ASCII, dans les deux sens, avec une garde pour que deux noms non latins (qui
se réduisent tous les deux au vide) ne se confondent pas.

Le `#hashtag` reste volontairement sur `\w` : c'est ce que `extractHashtags`
enregistre et recherche, l'élargir changerait la donnée stockée.

16 tests dans
[mention_handle_test.dart](test/core/utils/mention_handle_test.dart), dont un
test de widget qui construit vraiment la RegExp du contrôleur de coloration
(elle est `static final` : invalide, elle ne se verrait qu'à la première frappe
dans « nouvelle publication »).

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

## Neuf défauts signalés à l'usage — correctifs du 2026-08-22

Salim a remonté neuf symptômes après usage réel. Huit ont une cause trouvée et
corrigée, le neuvième attend un exemple. **Aucun n'est vérifié sur appareil.**

### 1. L'appui sur une notification ne faisait rien

Deux causes indépendantes, toutes deux corrigées :

- `NotificationService.createNotification`
  ([notification_service.dart](lib/core/services/notification_service.dart))
  n'écrivait que `target_id` dans `data`, quand le modèle ne lisait que
  `targetId`. Toutes les branches de navigation étant gardées par
  `if (targetId != null)`, l'appui était sans effet — demandes d'ami,
  participations aux événements, tout ce qui passe par cette RPC.
- Les types écrits par les déclencheurs SQL (`new_post`, `mentioned`,
  `group_mention`) et par le client (`report_resolved`, `groupCallInvitation`,
  `postCommented`, `commentReply`) n'existaient pas dans `NotificationType` :
  ils étaient repliés sur `general`, dont le `case` de navigation est vide.

**À vérifier sur appareil** : ouvrir la page Notifications sur un compte qui a
reçu (a) une demande d'ami, (b) une notification de publication du fil, (c) un
commentaire. Chacune doit ouvrir sa destination. Une notification sans
destination connue ouvre désormais sa fiche au lieu de ne rien faire.

### 2. « Erreur de chargement » intermittente sur les notifications

Le flux temps réel s'abonnait sans attendre la session Supabase (course avec le
pont Firebase vers Supabase : abonnement en `anon`, RLS muette), et une seule
ligne au `title`/`body` nul faisait échouer le `.map()` du flux ENTIER. Corrigé
dans [notification_supabase_datasource.dart](lib/features/notifications/data/datasources/notification_supabase_datasource.dart) :
attente de session, réessai avec conservation de la dernière liste connue, et
ligne illisible écartée au lieu de tout emporter.

**À vérifier** : ouvrir la page Notifications juste après un démarrage à froid
(le cas où la course se produit), puis couper/rétablir le réseau en restant sur
l'écran — la liste doit revenir seule, sans message d'erreur.

### 3. Le bandeau de restauration des clés revenait sans arrêt

`acknowledge()` ne vivait qu'en mémoire, et `bootstrap()` est appelé depuis
quatre endroits d'`AuthNotifier`. Le bandeau revenait donc à chaque démarrage et
à chaque rechargement de profil, indéfiniment (`needsRestore` reste vrai tant
que la sauvegarde n'est pas restaurée). Mise en veille désormais persistée
7 jours, et `bootstrap` ne tourne qu'une fois par compte et par session
([e2ee_backup_coordinator.dart](lib/core/services/e2ee/e2ee_backup_coordinator.dart)).

**À vérifier** : écarter le bandeau avec « Pas maintenant », tuer l'app, la
rouvrir — il ne doit pas revenir. Puis faire une vraie sauvegarde depuis
Sécurité : la veille est effacée.

### 4. Caractères spéciaux mal affichés — PARTIELLEMENT traité

Une cause identifiée et corrigée : le motif de mise en forme (gras, italique,
barré, code) de
[message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)
reconnaissait ses marqueurs au MILIEU d'un mot et les supprimait de
l'affichage — `taux_change_2026` perdait ses tirets bas et passait en italique.
Les délimiteurs doivent désormais être isolés (règle WhatsApp/Signal).

**Reste ouvert** : si le symptôme concerne d'autres caractères (emoji, accents,
caractères zarma/haoussa), il faut un exemple précis — quel caractère, à quel
endroit, et ce qui s'affiche à la place. Rien d'autre n'a été trouvé dans le
code (aucun mojibake dans le dépôt, apostrophes ICU correctes dans les ARB
générés).

### 5. La bulle « écrit… » ne s'affichait jamais

`typingIndicatorNotifierProvider` est `autoDispose` et n'était jamais observé :
chaque frappe le créait via `ref.read`, Riverpod le détruisait aussitôt, et sa
destruction appelait `_clearTypingStatus()`. La présence était donc posée puis
retirée dans le même tour de boucle. `ConversationScreen` l'observe désormais
dans son `build` ; `setTypingStatus` attend en plus que le canal realtime soit
rejoint avant de publier la présence.

**À vérifier — nécessite DEUX téléphones** : A tape, B doit voir la bulle
apparaître, et disparaître ~3 s après l'arrêt de la frappe puis à l'envoi. B
quitte la discussion : la présence doit s'effacer chez A.

### 6. Les messages vocaux ne partaient pas

`MessageSupabaseDataSource.sendAudioMessage` levait `UnimplementedError`, que le
repository attrapait dans son `catch (e)` générique : tout message vocal
échouait en silence. Implémenté (téléversement Firebase Storage, insertion
`messages` de type `voiceNote`, mise à jour du dernier message).

**À vérifier** : enregistrer un vocal, l'envoyer, vérifier qu'il arrive chez le
destinataire, qu'il se lit des deux côtés, que la forme d'onde et la durée sont
justes, et que l'aperçu de la conversation affiche « Message vocal ».

### 7. Les messages en échec disparaissaient au lieu d'être renvoyés

`retryFailedMessage` retirait la bulle **en tête de méthode**, avant le
`switch` — puis, pour un média, retournait `false` sans rien renvoyer : taper
« réessayer » était le moyen le plus sûr de perdre le message. Le retrait n'a
lieu que sur un chemin qui renvoie réellement, et un vocal en échec retient
désormais le chemin de son fichier local (`MessageEntity.localFilePath`) pour
pouvoir être retéléversé. En prime, `_loadNetworkData` remplaçait l'état entier
par la réponse serveur, ce qui effaçait aussi les messages en échec à chaque
rechargement.

**À vérifier** : couper le réseau, envoyer un texte et un vocal, attendre le
passage en échec, rétablir le réseau, taper « réessayer » sur chacun — les deux
doivent partir. Puis refaire un échec, changer d'écran et revenir : la bulle en
échec doit toujours être là. **Limite connue** : rien n'est persisté sur disque,
quitter l'app perd les messages en échec.

### 8. Un seul horodatage par rafale de messages envoyés

C'était volontaire (regroupement visuel des rafales, heure révélée par un tap),
mais illisible à l'usage. Chaque bulle porte désormais son heure, envoyée comme
reçue — le regroupement visuel (queue de bulle, nom, rayons) est inchangé.

**À vérifier** : envoyer trois messages d'affilée, les trois doivent afficher
leur heure ; vérifier que l'accusé « Envoyé / Lu » reste correct et que la mise
en page ne déborde pas avec des réactions.

### 9. L'app restait utilisable par-dessus l'écran de verrouillage — SÉCURITÉ

`android:showWhenLocked="true"` était posé sur `MainActivity` dans le manifeste
pour que l'écran d'appel s'affiche par-dessus le keyguard. Un attribut de
manifeste vaut pour toute la vie de l'activité : verrouiller le téléphone avec
Diaspo Niger au premier plan puis rallumer l'écran rouvrait l'application
entière — messages compris — sans demander le code. Le drapeau est retiré du
manifeste et demandé à l'exécution par l'écran d'appel seulement
([lock_screen_service.dart](lib/core/services/lock_screen_service.dart), canal
`diaspo_niger/lockscreen`).

**À vérifier sur appareil, en deux temps** :

1. App ouverte sur une discussion, verrouiller, rallumer l'écran : le keyguard
   DOIT demander le code, l'app ne doit pas être visible.
2. Recevoir un appel téléphone verrouillé, accepter depuis la bannière :
   l'écran d'appel doit s'afficher par-dessus le keyguard et l'écran s'allumer.
   Raccrocher, verrouiller à nouveau, puis revalider le point 1 (le privilège
   doit avoir été rendu).

---

## Icônes des tuiles de services agrandies (2026-08-19)

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

## Annuaire, Fil et Ambassades toujours actifs — plus de flag (2026-08-19)

Décision produit : ces trois services ne dépendent plus du back-office.
`isBusinessDirectoryEnabled`, `isEmbassiesEnabled` et `isFeedEnabled`
renvoient `true` en dur
([feature_flag_service.dart](lib/core/services/feature_flag_service.dart)),
`/businesses` est sorti du garde du routeur, les tuiles des deux grilles
(accueil + « Tous les services ») sont inconditionnelles, et les deux
interrupteurs du back-office sont affichés verrouillés sur « Toujours actif »
([admin_feature_flags_screen.dart](lib/features/admin/presentation/screens/admin_feature_flags_screen.dart)).

Vérifié sur SM A515F le 2026-08-19 — probant : la prod a `businessDirectory:
false` (lu le même jour, voir l'entrée ci-dessous), donc ces tuiles ne
peuvent venir que du « toujours actif » :
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
- [ ] Pins « entreprises » de la carte : **structurellement morts, pas juste
  faute de données** (constat 2026-08-19). `getNearbyBusinesses`
  ([business_remote_datasource.dart](lib/features/businesses/data/datasources/business_remote_datasource.dart))
  filtre sur `latitude`/`longitude`, mais ni la création ni l'édition
  d'entreprise ne renseignent ces champs — un doc créé par l'app est exclu
  par la range query, et le filtre longitude rejette les null. Même famille
  que les « champs jamais alimentés ». **Correctif livré le 2026-08-19
  (même jour, session worktree) : voir la section « Position des entreprises »
  ci-dessous pour les vérifications appareil.**

Bloqué pour la session du 2026-08-19 (agent seul avec le téléphone) :
- Le back-office est une app séparée (`lib/features/admin/main.dart`) dont
  l'écran de connexion n'a **aucune reprise de session** — login manuel
  obligatoire, donc test « sauvegarde → `lastUpdated` bouge » à faire par
  Salim avec le compte « Salim L. » (vérifié `adminRole=superAdmin` en base :
  la règle d'écriture passera ; le compte « Sim A » du téléphone est un autre
  compte). La sérialisation étant corrigée (voir entrée dédiée), les
  interrupteurs Salons/Podcasts devraient enfin agir.
- Le cas 4 colonnes de l'accueil : l'écriture directe du flag `audioRooms`
  en prod a été refusée par le classificateur de permissions de la session —
  à voir après une vraie sauvegarde back-office.

À savoir : les hash de `feature_flag_service.g.dart` n'ont pas été régénérés
(build_runner non relancé — signatures inchangées, seul le hot-reload debug
de ces 3 providers peut être moins fin).

---

## Position des entreprises : création/édition alimentent enfin latitude/longitude (2026-08-19)

Correctif de la couche « entreprises » morte de la carte (voir l'entrée
« Pins entreprises » ci-dessus). Ce qui a changé :

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

Aucune reprise de données à faire : l'annuaire est vide en prod au
2026-08-19 (constaté sur l'écran « Annuaire Business » le même jour).

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

## Flags Salons audio / Podcasts / Fil enfin sérialisés + maintenance sans écrasement (2026-08-19)

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

Couvert par `test/features/admin/feature_flags_maintenance_test.dart`
(aller-retour modèle, copyWith, écriture réelle du provider sur faux
datasource).

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
  toujours actif (voir l'entrée ci-dessus).
- [ ] Effacer le message de maintenance (vider le champ) puis sauvegarder →
  le message ne réapparaît pas à la réouverture de l'écran.

---

## « Tous les services » complété : Fil, Événements, Amis (2026-08-19)

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

## Un second appel qui arrive pendant qu'on est déjà en ligne était perdu en silence (2026-08-14)

Trouvé en rejouant le logcat d'un vrai test (deux comptes qui s'appelaient
quasi en même temps, 21:53-21:54) : `incomingCallProvider`
([call_provider.dart:1122](lib/features/calls/presentation/providers/call_provider.dart))
renvoie `null` dès que `state.call` est déjà occupé — y compris par un appel
que l'utilisateur vient de composer lui-même. L'évènement natif `accepted`
tombe alors dans le repli `_answerCallFromBackground`, qui appelle bien
`answerCall()` avec le BON callId, mais le garde anti-double-acceptation de
`answerCall()` ([call_provider.dart:436](lib/features/calls/presentation/providers/call_provider.dart))
le rejette silencieusement parce qu'un AUTRE appel est déjà dans `state.call`
— `return false`, aucun retour à l'appelant, aucun message à l'utilisateur.
Résultat observé : l'écran d'appel affiché reste celui du premier appel (le
sien), qui finit enregistré `cancelled` faute de réponse, et le second — celui
qu'on vient d'accepter — ne démarre jamais.

Correctif : dans ce cas précis (callId différent de celui déjà en cours),
`answerCall()` décline maintenant le second appel côté distant
(`declineCall`) et referme sa bannière CallKit spécifique
(`NativeCallService.endCallById`, nouveau — n'touche pas `_activeCallUuid` du
premier appel). L'appelant du second appel doit désormais recevoir un signal
« occupé » au lieu de sonner dans le vide. En même temps, ajout d'un plafond
de 15 s sur `initiateCall` (`_initiateCallTimeout`) : la même session a montré
`initiateCall` pendu ~62 s sans aucun retour visible, le temps qu'une session
Supabase invalide (`Session Supabase non établie`, pertes DNS ponctuelles) se
resynchronise — probablement un aléa réseau réel plutôt qu'un bug, mais sans
plafond le bouton d'appel semblait juste mort.

`flutter analyze` propre sur les deux fichiers touchés
([call_provider.dart](lib/features/calls/presentation/providers/call_provider.dart),
[native_call_service.dart](lib/core/services/native_call_service.dart)).
**Non vérifié en situation réelle** : il faudrait deux appareils qui
s'appellent l'un l'autre à quelques secondes d'écart pour confirmer que
l'appelant du second appel voit bien « occupé » plutôt que de sonner dans le
vide, et que le premier appel n'est pas perturbé au passage.

---

## Réponse rapide depuis la notification n'envoyait jamais rien (2026-08-13)

Deux bugs cumulés. (1) `currentUserId` dans SharedPreferences — lu par
[background_reply_service.dart](lib/core/services/background_reply_service.dart)
et 4 autres endroits de
[notification_service.dart](lib/core/services/notification_service.dart) pour
retrouver l'utilisateur courant depuis un isolate background — n'était écrit
**nulle part** dans le code : toujours `null`, donc la réponse rapide comme
la confirmation de livraison en arrière-plan (`mark_messages_as_delivered`)
étaient court-circuitées avant même de tenter quoi que ce soit. (2) même
quand ce cache aurait été renseigné, `BackgroundReplyService.sendReply`
écrivait dans Firebase Realtime Database (`messages/{conversationId}`), un
backend retiré depuis la migration vers Supabase — la conversation lit
`messages`/`conversations` sur Supabase, jamais RTDB, donc le message
n'apparaissait jamais, ni pour le destinataire ni au retour dans l'app.

Correctifs : `NotificationService.saveTokenForUser` (appelée à chaque login
et par `authStateChanges` au démarrage) alimente maintenant le cache
`currentUserId`/`currentUserDisplayName`/`currentUserPhotoUrl`, et le vide à
la déconnexion. `BackgroundReplyService` initialise un client Supabase propre
à l'isolate (même piège que `BackgroundLocationService` : singleton par
isolate) avec `SupabaseAuthBridge.ensureAuthenticated()`, écrit dans
`messages`/`conversations` avec le même schéma que
`MessageSupabaseDataSource` (chiffrement AES de repli — Signal Protocol est
hors de portée d'un isolate éphémère, pas de Hive), et la file d'attente
hors-ligne (`processPendingMessages`, jusqu'ici jamais appelée) se vide
maintenant à chaque connexion connue. `flutter analyze` propre, mais rien de
tout ça n'exerce le vrai réveil d'isolate Android ni Supabase.

- [x] Recevoir une notification de message avec l'app en arrière-plan (ou
  fermée) → la notification s'affiche avec les deux boutons d'action
  (Répondre, Marquer comme lu). **Vérifié le 2026-08-14 sur SM A515F**, à
  trois reprises (build debug, build debug après redémarrage complet, build
  profile) : le correctif serveur data-only fonctionne, `actions=2` confirmé
  dans `dumpsys notification`.
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

**Troisième bug, trouvé en vérifiant celui-ci sur appareil (2026-08-13) :**
même les deux correctifs ci-dessus posés, la notification reçue app en
arrière-plan n'affichait **aucun bouton d'action**. Cause : `send-push`
([supabase/functions/send-push/index.ts:324-338](supabase/functions/send-push/index.ts))
envoie un message FCM avec un bloc `notification` **et** un bloc `data`. Sur
Android, quand l'app est en arrière-plan, un bloc `notification` présent fait
que le système affiche lui-même la bannière **nativement**, sans jamais
invoquer `onBackgroundMessage`/`firebaseMessagingBackgroundHandler` côté
Dart — confirmé par `adb logcat` : la notification est postée par
`NotificationService` système (PID système) à l'horodatage du push, aucune
ligne Flutter ne s'exécute. `_showFallbackMessageNotification` (le repli qui
construit les actions Répondre/Marquer comme lu) ne sert donc que pour les
OEM qui suppriment activement le bloc `notification` — pas le cas ici, donc
jamais atteint. Corrigé côté client
([notification_service.dart](lib/core/services/notification_service.dart)) :
`_showFallbackMessageNotification` porte maintenant les mêmes actions que
`_showLocalNotification`, et son payload est du JSON valide (l'ancien
`'message:$conversationId'` aurait fait échouer même un simple tap). Mais
tant que `send-push` envoie encore le bloc `notification`, ce correctif
client ne s'exécute jamais dans le cas courant. **Correctif serveur fait et
déployé le 2026-08-13** (confirmation de Salim avant déploiement) :
[supabase/functions/send-push/index.ts](supabase/functions/send-push/index.ts)
envoie désormais les messages `type === 'message'` en pur `data`-only (pas
de bloc `notification` ni `android.notification`), avec `aps.alert`
reconstruit explicitement côté APNs pour ne pas perdre l'alerte iOS. Les
autres types de notification (amis, groupes, événements...) gardent le bloc
`notification` classique — comportement inchangé, aucune action requise pour
eux. **Confirmé en pratique le 2026-08-14** : `dumpsys notification` montre
`actions=2` sur la notification reçue app en arrière-plan.

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

Reproduit à l'identique sur **trois builds différents**, avec redémarrage
complet de l'app (`am force-stop` + relance) avant chacun : `flutter build
apk --debug`, le même après un redémarrage complet, puis `flutter build apk
--profile` — élimine à la fois « process resté sale » et « artefact du mode
JIT/debug » comme explications. Recherche dans les issues GitHub de
`flutter_local_notifications` (MaikuB/flutter_local_notifications#2011,
#2148) : catégorie de bug connue et non résolue côté mainteneurs, sans cause
racine publiée — `onDidReceiveBackgroundNotificationResponse` qui ne
s'exécute jamais malgré `@pragma('vm:entry-point')` correctement posé.

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
- [ ] Vérifier que la notification s'affiche toujours normalement (tap sur le
  corps → ouvre la conversation) avec les actions masquées — pas testé
  explicitement, seule l'absence des boutons a été vérifiée par `dumpsys`.

## Message d'appel : aperçu et badge non-lu ne se mettaient jamais à jour (2026-08-13)

Même famille de bug que la réponse rapide depuis une notification
ci-dessus. [call_message_service.dart](lib/core/services/call_message_service.dart)
écrivait l'aperçu de dernier message dans `conversations.data` avec des clés
snake_case (`last_message`, `last_message_sender_id`, `last_message_type`,
`unread_counts` à la création d'une conversation 1:1) alors que
`ConversationModel.fromJson`/`_convFromRow`
([message_supabase_datasource.dart](lib/features/messages/data/datasources/message_supabase_datasource.dart))
et tout le reste du pipeline d'envoi lisent des clés camelCase
(`lastMessage`, `lastMessageSenderId`, `lastMessageType`, `unreadCount`).
En plus de la casse, la colonne top-level `last_message_at` (celle qui
pilote le tri `.order('last_message_at', ...)` de la liste des
conversations) n'était jamais mise à jour — seule une copie morte dans
`data` l'était — et **aucun** compteur non lu n'était incrémenté après un
appel sur une conversation déjà existante (seule la création en écrivait
un, et en snake_case). Concrètement : après un appel, la conversation ne
remontait pas en tête de liste, l'aperçu affichait l'ancien dernier
message texte au lieu de « 📞 Appel manqué », et le badge non-lu du
destinataire ne s'incrémentait jamais.

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
- [ ] Passer un premier appel vers un contact sans conversation 1:1
  existante → une nouvelle conversation est créée et apparaît normalement
  dans la liste (aperçu + badge), pas seulement après l'envoi d'un
  message texte ultérieur.

## La bulle d'appel elle-même n'apparaissait jamais dans la conversation (2026-08-14)

Signalé par l'utilisateur : « les bulles des appels ne s'affiche jamais ».
Le correctif du 2026-08-13 ci-dessus a réparé l'aperçu de conversation et le
badge non-lu, mais pas le symptôme racine — même famille de bug que
« Réponse rapide depuis la notification » plus haut sur cette page.
`createCallMessage` dans
[call_message_service.dart](lib/core/services/call_message_service.dart)
écrivait le message d'appel (`type: 'call'`) dans Firebase Realtime Database
(`messages/{conversationId}` via `_database.ref()...push().set(...)`), un
backend que plus rien ne lit : `MessageSupabaseDataSource.getMessages`
([message_supabase_datasource.dart:445-453](lib/features/messages/data/datasources/message_supabase_datasource.dart))
— le seul datasource câblé dans `messageRemoteDataSourceProvider` — stream
uniquement la table Supabase `messages`. Le message était donc bien créé (les
logs `debugPrint('appel: ...')` le confirmaient), mais dans un endroit que
l'écran de conversation ne consulte jamais : aucune bulle, aucune erreur.

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

## Messages de groupe qui redeviennent indéchiffrables après réouverture (2026-08-13)

Signal (1:1) et Sender Key (groupes) avancent un ratchet à sens unique à
chaque déchiffrement réussi, sans conserver les clés de message déjà
consommées. `getMessagesPaginated` re-fetch pourtant le même ciphertext
depuis Supabase et retente `_crypto.decrypt` à chaque appel (réouverture
de conversation, pull-to-refresh, pagination) —
`SenderKeyService.decryptWithSenderKey` refuse alors tout `chainIndex`
déjà dépassé et renvoie le placeholder « session requise », qui écrasait
le texte clair déjà mis en cache. Correctif dans
[message_repository_impl.dart](lib/features/messages/data/repositories/message_repository_impl.dart)
(`_healUndecryptableMessages`) : on restaure depuis le cache local le
texte des messages qu'un rechargement réseau vient de rendre
indéchiffrables, avant d'écraser le cache — même principe que
`_reconcileEcho` (message_provider.dart) pour l'écho temps réel, mais
côté rechargement paginé. `flutter analyze` propre, mais rien de tout ça
n'exerce le vrai ratchet Signal ni Supabase.

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

## Réactions emoji : une par personne et par message (2026-08-13)

`MessageEntity.reactions` était une simple `List<String>` sans auteur : le
compteur affiché était juste le nombre d'emojis posés, mais rien ne
distinguait « la mienne » des autres, et retirer sa réaction pouvait retirer
celle de quelqu'un d'autre (premier élément de la liste égal à cet emoji).
Passé à `Map<String, String>` (userId -> emoji, une seule par personne) dans
[message_entity.dart](lib/features/messages/domain/entities/message_entity.dart),
[message_model.dart](lib/features/messages/data/models/message_model.dart),
les deux datasources (`message_supabase_datasource.dart`,
`message_remote_datasource.dart`) et
[message_provider.dart:601](lib/features/messages/presentation/providers/message_provider.dart:601)
(`toggleReaction` se basait sur *n'importe quel* utilisateur ayant déjà posé
cet emoji, pas sur l'utilisateur courant). L'onglet « Réactions » de la fiche
message ([message_info_sheet.dart](lib/features/messages/presentation/widgets/message_info_sheet.dart))
chargeait en plus depuis un service RTDB Firebase mort (`MessageActionService`)
que les vraies réactions Supabase n'ont jamais alimenté — toujours vide en
pratique ; il lit maintenant `message.reactions` directement.

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
- [ ] Deux comptes différents réagissant au même message avec le même emoji
  → le chip affiche bien un compteur à 2, et chacun ne peut retirer que sa
  propre réaction. **Pas vérifiable avec un seul appareil/compte** — nécessite
  un deuxième testeur ou compte connecté ailleurs.

---

## Retour à la ligne des bulles de discussion après l'agrandissement du texte (2026-08-13)

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

## Cartographie des accès `anon` réellement nécessaires (2026-08-13)

Suite à l'audit des RPC (section suivante) : `anon` a INSERT/UPDATE/DELETE/SELECT
au niveau table sur quasiment tout le schéma public par accident
(`ALTER DEFAULT PRIVILEGES`), et RLS (activée sur 100% des tables, vérifié)
est la seule barrière. Avant d'envisager un `REVOKE` généralisé, cartographie
de ce que l'app a réellement besoin en `anon` — c'est-à-dire avant qu'une
session Supabase authentifiée existe.

**L'app n'a aucun mode invité.** Le routeur ([app_router.dart:246-247](lib/core/router/app_router.dart:246))
redirige tout écran non technique vers `/auth/login` tant que Firebase n'est
pas authentifié — aucun aperçu public (profil, post, événement, groupe via
lien de partage) ne se construit avant connexion. Les pages légales (CGU,
confidentialité) sont servies depuis **Firestore**, pas Supabase.

**Besoins réels identifiés** (tous liés à la même fenêtre : `auth_provider.dart`
`_startFromLocalSession` (lignes 152-185) bascule l'utilisateur en
« authentifié » depuis la session Firebase locale **sans confirmer** que le
pont Supabase a abouti — le vrai bug de fond) :
- `users` SELECT — `profileNotifierProvider`/`nearbyProfilesNotifierProvider`
  au montage de `HomeScreen`, et `isHandleAvailable` pendant l'inscription
  ([handle_field.dart:81-91](lib/features/profile/presentation/widgets/handle_field.dart:81))
- `blocked_users` SELECT — `usersWhoBlockedMeProvider`
- `conversations` SELECT — `totalUnreadCountProvider`

~~`events` SELECT — `eventsNotifierProvider`~~ — **faux positif, corrigé le
2026-08-13** : `eventsNotifierProvider` lit en réalité **Firestore**
(`EventRemoteDataSourceImpl`, `event_remote_datasource.dart:36-46`), pas
Supabase. L'agent d'exploration précédent avait confondu la fonctionnalité
« événements » avec la table Supabase `events` — celle-ci existe bien et
`anon` y a SELECT/écriture, mais son seul lecteur applicatif est
`admin_provider.dart` (back-office, déjà réservé aux admins authentifiés,
hors de la fenêtre de démarrage). Rien à corriger côté code pour ce point.

**Aucune écriture n'est légitimement nécessaire en `anon`, nulle part** —
chaque écriture inspectée (`profile_supabase_datasource.dart` et consorts)
est déjà gardée par `ensureAuthenticated()`/`_requireAuth()` côté Dart et
échoue proprement sans le grant. Aucune lecture nécessaire sur les ~80
autres tables (`orders`, `payment_accounts`, `escrow_transactions`,
`e2ee_*`, `messages`, `posts`, `groups`, `businesses`, `podcasts`,
`admin_*`...).

**Angle mort** : `audio_rooms`, `businesses`, `calls`, `embassies`, `friends`,
`marketplace`, `payment_accounts`, `podcasts`, `reports`, `search`,
`stickers`, `support`, `transfers` n'ont pas le réflexe `ensureAuthenticated()`
présent dans `auth`/`feed`/`groups`/`messages`/`profile` — protégés
aujourd'hui uniquement par la garde du routeur, pas par le datasource
lui-même. Un `REVOKE` général sur les écritures `anon` serait le filet qui
les couvre si un futur chemin de code (deep link, tâche de fond) contournait
le routeur.

- [x] ~~Décision en attente~~ — Salim a choisi de fermer d'abord la fenêtre
  plutôt que d'ouvrir des SELECT en permanence. Fait le 2026-08-13 pour 3 des
  4 lectures :
  - Nouveau [`SupabaseAuthBridge.ensureReadableSession()`](lib/core/services/supabase_auth_bridge.dart)
    — variante **bornée** (3 s) d'`ensureAuthenticated()`. Contrairement à
    celle-ci, un timeout ne fait PAS échouer : la synchro continue en tâche
    de fond (dédupliquée) et profite au prochain appelant. Choix délibéré
    pour ne pas régresser le correctif du 2026-08-04 (splash bloqué 2 min) —
    `_startFromLocalSession` (auth_provider.dart) n'est PAS touchée, elle
    continue de débloquer `/home` sans réseau.
  - Câblé dans `profile_supabase_datasource.dart` : `getProfile`,
    `getNearbyProfiles` (lèvent désormais une `ServerException` déjà gérée
    par les écrans appelants au lieu d'interroger en anon), `isHandleAvailable`
    (se replie sur « disponible », comme pour une erreur réseau).
  - Callback injectable `_ensureReadableAuth`, même motif que `_ensureAuth`
    pour les écritures — 4 tests ajoutés dans
    `profile_supabase_datasource_test.dart` (13/13 passent).
  - `flutter analyze` propre sur `lib/features/profile`, `lib/features/auth`,
    `lib/core/services/supabase_auth_bridge.dart`.
  - **`conversations` fait le 2026-08-13, suite** — même mécanisme, câblé
    dans `getConversations` ([message_supabase_datasource.dart:339](lib/features/messages/data/datasources/message_supabase_datasource.dart:339)) :
    la fonction interne `fetch()` (appelée à l'abonnement initial ET à chaque
    événement realtime) vérifie désormais `_ensureReadableAuth()` avant
    d'interroger. Différence avec les lectures profil : c'est un
    `StreamController` de longue durée, pas un Future ponctuel — sans filet,
    un échec silencieux laisserait le flux bloqué sur son dernier état
    jusqu'au prochain événement realtime (potentiellement jamais). Un seul
    nouvel essai programmé 5 s plus tard comble ce trou, sans machinerie de
    retry plus lourde. Callback injectable `_ensureReadableAuth` ajouté à
    `MessageSupabaseDataSource`, même motif que `profile_supabase_datasource.dart`.
    `flutter analyze` propre. **Pas de test automatisé** : ce datasource n'a
    aucun harnais de test existant (contrairement à `profile`), et tester un
    `StreamController` + un `Timer` de 5 s proprement demanderait
    `fake_async` — pas fait, hors périmètre de cette session.
  - **`blocked_users` fait le 2026-08-13, suite** —
    [`watchBlockedBy`](lib/features/settings/data/datasources/blocked_by_supabase_datasource.dart:31)
    (`usersWhoBlockedMeProvider`, sens « qui m'a bloqué »). Plus simple que
    `conversations` : `.stream()` (le helper Supabase Flutter) gère déjà sa
    propre reconnexion, donc pas besoin d'un `Timer` de nouvel essai — la
    méthode devient un générateur `async*` qui attend la garde puis
    `yield*` le flux réel. Au-delà du délai borné (3 s), l'abonnement part
    quand même (comme avant), le repli `.handleError` du provider couvre le
    reste. Callback injectable, 2 tests ajoutés
    (`test/features/settings/blocked_by_supabase_datasource_test.dart`,
    pas de `fake_async` nécessaire ici). `flutter analyze` propre sur
    `lib/features/settings`.
    Au passage : `blockedUsersProvider` (sens direct, « qui j'ai bloqué »)
    est lui aussi un faux positif comme `events` — il lit **Firestore**
    (`BlockedUsersDataSourceImpl`), pas Supabase ; seule l'écriture miroir
    vers Supabase existe et est déjà gardée (`_refleterDansSupabase`,
    `ensureAuthenticated()`).
  - **Cartographie soldée** : les 4 lectures identifiées sont maintenant
    soit fermées côté code (`users`, `conversations`, `blocked_users`), soit
    de faux positifs (`events`, et la moitié de `blocked_users`). Plus rien
    en attente avant d'envisager le `REVOKE` général des droits table
    `anon`.
  - [x] **Vérifié sur appareil le 2026-08-13** (SM A515F, APK debug rebuild
    depuis ce worktree, `lastUpdateTime` confirmé postérieur aux 4 commits de
    correctif). Mode avion + Wi-Fi coupé par Salim, confirmé par
    `dumpsys connectivity` (`Active default network: none`, pas seulement
    `airplane_mode_on`, cf. le piège VPN déjà documenté) — puis app arrêtée
    (`am force-stop`) et relancée à froid.
    - Aucun crash (`E/flutter`, `FATAL EXCEPTION` : zéro occurrence sur toute
      la capture logcat). `/home`, Messages et Groupes s'affichent tous
      normalement, aucun écran bloqué sur `/splash`.
    - Le badge « 1 non lu » s'affiche correctement dès le démarrage à froid
      hors ligne (données en cache, cohérent avec le cache-first existant).
    - `markAsDelivered`/`mark_messages_as_read` échouent proprement
      (`AuthRetryableFetchException` catché et loggé, pas de crash) —
      confirme le comportement best-effort du correctif accusés livré/lu.
    - Reprise réseau confirmée propre : `SupabaseAuthBridge: session sync OK`
      dans les 2 s suivant le rétablissement, puis opérations Supabase
      réelles qui réussissent de nouveau (`MarkAsRead: Synced dismiss to
      other devices`).
    - **Nuance découverte** : `_startFromLocalSession` (le chemin de repli à
      8 s dans `auth_provider.dart`) ne s'est en fait jamais déclenché
      pendant ce test — son log dédié (« profil serveur injoignable ») est
      absent de toute la capture. `getCurrentUser()` a résolu plus vite que
      le timeout, via sa propre résilience interne, sans jamais passer par
      ce chemin précis. Les gardes `ensureReadableSession()` restent
      correctes indépendamment de ce détail (elles ne testent que
      `hasValidSession`, pas la raison de l'état d'authentification), mais
      ce test précis n'isole pas la fenêtre étroite (réseau bon mais pont pas
      encore confirmé) que ces gardes visent spécifiquement — seulement le
      cas plus large « pas de réseau du tout ».
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

## Accusés livré/lu séparés — sheet infos du message (2026-08-13)

`mark_messages_as_delivered` marquait `readBy`/`readAt` en même temps que
`deliveredTo`/`deliveredAt`, y compris depuis les handlers de notification
push (app en arrière-plan ou fermée) : un message passait à « lu » avant même
que le destinataire ouvre la conversation. Séparé en deux RPC —
`mark_messages_as_delivered` (livré seul) et `mark_messages_as_read` (lu,
appelée uniquement à l'ouverture réelle de la conversation) — voir
[20260813120000_split_delivered_from_read.sql](supabase/migrations/20260813120000_split_delivered_from_read.sql)
et [message_supabase_datasource.dart:1548](lib/features/messages/data/datasources/message_supabase_datasource.dart:1548).

`flutter analyze` propre. Les deux migrations sont **déployées** sur le
distant (Diapo Niger, `zyrfkcjjrhddpfxcgezo`) et vérifiées par requête directe
(`supabase db query --linked`, transaction annulée pour ne rien persister) :
`mark_messages_as_delivered` tourne sans erreur et ne touche plus `readBy`.
Mais rien de tout ça n'est vérifiable **dans l'app** sans deux comptes réels
échangeant un message :

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
- [ ] Envoyer un message depuis le compte A à un compte B **avec le compte B
  hors ligne** (notification push reçue, app fermée) : vérifier dans le sheet
  infos du message (appui long → Infos) que l'onglet « Livré à » liste B mais
  que « Lu par » reste vide tant que B n'a pas ouvert la conversation.
- [ ] Ouvrir la conversation côté B : vérifier que B apparaît alors dans « Lu
  par », et que le coche du message (côté A) passe au double-coche bleu à ce
  moment-là, pas avant.
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

## Bascule en anglais — ~1 600 chaînes branchées, rien vu à l'écran (2026-08-06)

Toute l'application vient d'être branchée sur `l10n` : l'admin (0 fichier sur
34 utilisait `l10n`), `businesses` (0/40), `embassies`, `transfers`,
`marketplace`, puis les 19 modules restants, `lib/shared/` et `lib/core/`.
`dart analyze` est propre et les **207 tests passent**, mais aucun de ces
contrôles ne regarde un écran.

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

## Scroll des notifications — mesuré, pas un défaut de l'écran (2026-08-06)

Signalé comme « le scroll a un problème ». Mesuré sur SM A515F avec une sonde
(deux builds), capture et mesure prises **dans la même frame** :

```
état non-lu :  liste bas = 866.3 dp   dernière carte bas = 929.5 dp
               maxScrollExtent = 87.2 dp   (63.2 de débordement + 24 de padding)
état lu     :  dernière carte bas = 670.5 dp   maxScrollExtent = 0
```

- [x] **La liste peut défiler** : `maxScrollExtent = 87.2 dp` en état non-lu.
  La carte coupée n'est pas un défaut d'affichage, c'est du contenu qui dépasse.
- [x] **Un correctif posé puis retiré** (`4c19b3d` → `7648c35`) : il ajoutait
  `viewPadding.bottom` au padding bas, or cette valeur vaut **0** sur cet
  appareil — Flutter n'y reçoit aucun inset système. No-op vérifié à l'écran.
- [ ] ⚠ **À refaire au doigt.** Aucun `adb input swipe` n'a fait défiler cette
  liste, et un glissement lent (1500 ms) a été interprété comme un **tap**.
  L'injection n'est pas fiable ici : je ne peux ni confirmer ni infirmer un
  défaut vécu au doigt. Le test : la liste doit remonter de ~87 dp et découvrir
  le bas de la dernière carte.
- **Piège de méthode à retenir** : le premier `maxScrollExtent = 0` venait de
  l'état *lu* (cartes courtes, contenu qui tient) et a été comparé à une capture
  prise en état *non-lu*. Deux écrans différents. Mesurer et capturer dans la
  même frame, sinon on conclut de travers — ça a coûté deux builds.

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

## Push FCM des messages — chaîne serveur rétablie (2026-08-05)

Audit de la base distante : **aucun push n'était envoyé pour un message de
chat** depuis le passage des messages à Supabase. Deux trous cumulés :

- `messages` n'avait aucun trigger sur le distant, et les fonctions de
  `20260720120000_notify_recipients_on_message_insert.sql` en étaient absentes
  — alors que la migration est inscrite comme appliquée. Aucune ligne
  `notifications` de type `message` n'a été créée depuis le 12/04/2026.
- La fonction `notify_push_on_notification` déployée court-circuitait
  `type = 'message'` en déléguant à la Cloud Function RTDB `onMessageCreated`
  ([functions/index.js:839](functions/index.js:839)), qui écoute
  `/messages/{conversationId}/{messageId}` — un chemin que l'app n'écrit plus
  (`MessageSupabaseDataSource`).

Correctifs : `20260805230000_fix_message_push_pipeline.sql` puis
`20260806090000_fix_push_trigger_schema.sql`.

**Appliqués et vérifiés côté serveur le 2026-08-06.** Le premier ne suffisait
pas : il faisait `CREATE OR REPLACE FUNCTION public.notify_push_on_notification`
alors que le trigger appelle celle du schéma **`private`**. Il a donc créé une
deuxième fonction homonyme sans toucher la bonne — appliqué, sans effet. Pour
savoir laquelle est branchée : joindre `pg_trigger` à `pg_namespace`,
`pg_proc` seul renvoie les deux sans dire laquelle sert.

Deux vérifications faites directement sur la base :

- **`messages` → `notifications`** : insertion d'un message dans une
  transaction volontairement annulée (`RAISE EXCEPTION` en fin de bloc, donc
  rien de persisté et aucun push envoyé) → 28 → 29 lignes, destinataire = le
  participant **autre** que l'expéditeur, titre = nom de l'expéditeur, corps =
  contenu. L'exclusion de l'expéditeur est donc bonne.
- **`notifications` → FCM** : une ligne de test insérée sur le compte Salim a
  produit `{"sent":1,"removed":0}` en HTTP 200 dans `net._http_response` — le
  push est réellement parti, le token était valide. Ligne supprimée depuis.
- **Filtre par type** : avec `notification_prefs = {"messages": false}`, la
  même insertion donne `{"skipped":"type disabled: messages"}` et la ligne
  in-app reste créée. Préférence remise à `{}` depuis.

Reste ce que seul un téléphone peut dire — le rendu, le groupement, les
doublons :

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

- [ ] **Message 1-à-1, app réellement tuée** (balayée des récents, pas
      `force-stop`) : reste à faire.
- [ ] **Message de groupe** : titre = nom du groupe, corps = `Nom: aperçu`.
- [x] **Le SDK Firebase poste bien sous `id=0`** — confirmé par
      `dumpsys notification` : `id=0 tag=msg_verif-simA-004`. L'id du repli
      local est passé de `conversationId.hashCode % 99999` à 0, il remplacera
      donc la bannière au lieu de s'y ajouter. Ce n'était qu'une hypothèse
      jusque-là.
- [ ] **Doublon en arrière-plan, build à jour** : à revérifier une fois l'APK
      reconstruit — le repli local n'a pas posté pendant l'essai, donc le cas
      « les deux chemins se déclenchent » n'a pas été observé.
- [ ] **Conversation ouverte au premier plan** : pas de notification système.
- [ ] **Conversation mutée** : rien n'arrive (le trigger filtre `data.mutedBy`).
- [ ] **« Mes notes »** : s'écrire à soi-même ne déclenche aucune notification.
- [ ] **Aperçu désactivé** (`show_message_preview = false`) : corps générique.
- [ ] **Bascule push du profil sur `off`** : plus rien n'arrive côté FCM alors
      que la cloche in-app continue de se remplir.

### Icône de barre d'état — corrigée ET vérifiée à l'écran (2026-08-06)

Chaîne complète refaite sur le SM A515F, build reconstruit et installé
(`adb install -r`, session Firebase et clés E2EE conservées).

**Un vector drawable ne convient pas comme petite icône de notification.**
Première tentative avec `res/drawable/ic_stat_notification.xml` : la
notification n'apparaissait **plus du tout** — 60 s de scrutation, rien, alors
que le build précédent l'affichait. Elle figurait bien un instant dans le
registre Samsung puis disparaissait, ce qui ressemble à un `Bad notification`
côté système. Aucune trace dans logcat.

Remplacé par de vrais PNG monochromes générés aux cinq densités
(`drawable-mdpi` → `drawable-xxxhdpi`, bulle de discussion blanche sur fond
transparent) : la bannière réapparaît **en 5 s**.

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

⚠️ **Ne pas revenir à un vector drawable** pour cette icône, même « parce que
c'est plus propre » : ça supprime silencieusement toutes les notifications.

### Deuxième défaut, indépendant : l'icône de barre d'état n'existait pas

`notification_service.dart` référence `@drawable/ic_stat_notification` six fois
— dont dans `_showLocalNotification` (ligne 1805), le chemin d'affichage de
**toute** notification au premier plan. Le fichier n'existait dans aucun
dossier `res/` : `getResources().getIdentifier()` renvoyait 0, et Android
refuse de poster une notification sans petite icône valide. Les `try/catch` du
service (tous leurs `debugPrint` commentés) avalaient l'exception.

Autrement dit : même une fois le SQL appliqué, aucune notification au premier
plan ne se serait affichée. Corrigé par un vector drawable monochrome
(`res/drawable/ic_stat_notification.xml`) et les deux `meta-data` FCM
(`default_notification_icon` / `default_notification_color`) qui manquaient au
manifeste. `:app:processDebugResources` passe.

- [ ] **Icône visible** : la barre d'état montre la cloche blanche, pas un
      carré blanc ni rien du tout — au premier plan **et** app tuée (deux
      chemins de rendu différents : le plugin et le SDK Firebase).
- [ ] **Filet orange** : la notification dépliée est teintée `#E97424`.
- [ ] **Résumé de groupe** (`_showGroupSummaryNotification`) et **notification
      de proximité** : mêmes chemins, même icône, à voir au moins une fois.
- [ ] **Réponse rapide depuis la notification** : la confirmation « Message
      envoyé » s'affiche (elle aussi utilisait l'icône manquante).

Le glyphe est le « notifications » de Material, posé comme placeholder : à
remplacer si une version blanche monochrome de la marque est produite.

### Trois fils débranchés, trouvés au passage — CORRIGÉS

**1. Personne n'émettait jamais vers un topic FCM.** Zéro occurrence de
`topic`, `sendToTopic` ou `/topics/` dans `functions/index.js`,
`functions/supabase.js` et `send-push` — cette dernière ne vise que des tokens
individuels. L'app s'abonnait pourtant à trois familles de topics : `general`
(interrupteur maître), `group_<id>` (adhésion), et un topic par événement
(« M'avertir du prochain »).

Les trois abonnements sont retirés. `subscribeToTopic` / `unsubscribeFromTopic`
restent dans `notification_service.dart`, documentées comme sans appelant, pour
le jour où un émetteur existera.

⚠️ **Reste ouvert** : la bascule « M'avertir du prochain » persiste toujours le
choix localement, mais rien ne l'honore — il n'y a pas d'émetteur à écrire sans
décider d'abord *qui* est notifié à la création d'un événement. À trancher :
émetteur serveur, ou retirer la bascule.

- [ ] Ne rien attendre de « M'avertir du prochain » tant que ce point est ouvert.

**2. Les préférences par type ne filtraient qu'au premier plan.**
`_shouldShowNotification` n'est appelée que depuis `_handleForegroundMessage`,
et nulle part ailleurs. App en arrière-plan ou tuée, c'est le système qui
affiche le bloc `notification` du push : la préférence n'était jamais lue.
Couper « Messages » ne coupait donc rien dès que l'app était fermée —
précisément le moment où ça compte.

Corrigé par une source serveur : colonne `users.notification_prefs` (JSONB,
migration `20260805233000`), écrite par chaque bascule
(`_syncTypePrefsToServer`) et lue par `send-push` (`prefKeyFor`). Convention :
**clé absente = autorisé**, seul un `false` explicite coupe — les comptes
existants gardent donc le comportement actuel.

⚠️ Les deux switch — `prefKeyFor` (TypeScript) et `_shouldShowNotification`
(Dart) — doivent bouger ensemble. Désynchronisés, une bascule coupe au premier
plan et laisse passer app fermée : exactement le défaut corrigé ici.

**`send-push` est déployée** (le déploiement des Edge Functions passe, seule
l'écriture SQL est bloquée). Elle lit `notification_prefs` par une requête
**séparée et tolérante à l'absence de la colonne** : la première version
nommait la colonne dans le select principal, et comme la migration n'est pas
encore appliquée, ce select échouait, `userRow` valait null, et **plus aucun
push ne partait** — y compris ceux qui marchaient. Corrigé et redéployé dans la
foulée, vérifié de l'extérieur (401 sans le secret partagé). Tant que la
migration n'est pas passée, la préférence par type est simplement ignorée :
personne ne perd de notification.

- [ ] **« Messages » sur `off`, app tuée** : plus aucune bannière.
- [ ] **« Demandes d'amis » sur `off`** : idem, et les messages continuent
      d'arriver (le filtrage est bien par type, pas global).
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

### Rappels planifiés — écrivaient dans une collection morte (2026-08-06)

Six émetteurs de notifications des Cloud Functions écrivaient dans la
collection **Firestore** `notifications`, que plus personne ne lit depuis que
l'app est passée à Supabase. Ils tournaient, ne levaient aucune erreur, et ne
produisaient rien :

| Fonction | Déclencheur | Notifications |
|---|---|---|
| `processReminders` | toutes les 15 min | rappels génériques (événement, transfert) |
| `sendEventReminders` | toutes les heures | « commence demain » |
| `sendTransferReminders` | tous les jours à 09:00 | transferts programmés |
| `onPodcastEpisodeCreated` | Firestore | nouvel épisode |
| `onAudioRoomStatusChanged` | Firestore | salon passé en direct |
| `notifyLocalEventCreated` | Firestore | événement dans ta ville |

Corrigé par un helper `createNotification` dans `functions/supabase.js` : il
accepte la forme Firestore historique (`userId`/`isRead`/`targetId`) et écrit
la ligne Supabase, ce qui rebranche `trg_notify_push` → send-push → FCM. Les
six appels ont été basculés, les fonctions déployées, et le helper exercé avec
l'environnement réel des Cloud Functions → `{"sent":1,"removed":0}` en HTTP 200.
Ligne de test supprimée.

⚠️ **`notifyLocalEventCreated` reste inerte, pour une autre raison.** Il
sélectionne ses destinataires sur la localisation, et sur le distant
`users.city` est **null ou vide pour tout le monde**, `country_code` ne contient
que des codes ISO-2 (`NE`, `BF`, `CA`) là où l'événement porte un nom de pays.
Aucun destinataire ne peut matcher — ni côté Firestore, ni côté Supabase. Je
n'ai pas porté la requête : ça n'aurait rien réparé tout en en donnant l'air.
Le vrai préalable est de peupler la localisation des profils.

- [ ] **Rappel d'événement** : créer un événement à ~24 h, s'y inscrire,
      attendre le passage horaire de `sendEventReminders`.
- [ ] **Salon audio passé en direct** : les abonnés reçoivent la bannière.
- [ ] **Nouvel épisode de podcast** : idem pour les abonnés du podcast.

### Les 28 écritures Firestore restantes — triées (2026-08-06)

Inventaire fait fonction par fonction, en croisant chaque déclencheur avec
l'endroit où sa donnée vit réellement aujourd'hui.

**15 écritures basculées vers Supabase et déployées** — leur déclencheur existe
encore, seule la destination était morte :

| Fonction | Pourquoi elle tourne encore |
|---|---|
| `onCallUpdated` | les appels sont restés dans Firestore |
| `onTransferStatusChanged` (×2) | les transferts aussi |
| `onOrderCreated`, `onOrderUpdated` (×4), `processOrderPayment` | la place de marché aussi |
| `stripeWebhook`, `stripeConnectWebhook`, `bankWebhook`, `processPayoutRequest` (×2), `checkEscrowTimeouts` | HTTPS / planifiées : elles tournent quoi qu'il arrive |

**Les 13 restantes, reprises le 2026-08-06.** Elles ne se réduisaient pas à un
changement de destination : chacune demandait de décider quoi en faire.

*Une seule capacité manquait vraiment* — `onNewPostCreated`, qui prévenait les
abonnés, les personnes mentionnées et les membres des groupes cités. Personne
ne le faisait à sa place. Portée en **trigger Postgres** sur `posts`
(`trg_notify_on_post_insert`, migration `20260806110000`), au plus près de la
donnée. Deux écarts assumés avec l'originale :

- pas de diffusion aux abonnés pour une publication de groupe ou non publique.
  L'originale mettait l'aperçu du contenu dans le corps de la notification —
  donc recopiait le texte d'un post de groupe privé à des gens qui n'y ont pas
  accès ;
- un destinataire n'est notifié qu'une **fois**. L'originale empilait trois
  notifications pour qui était à la fois abonné, mentionné et membre d'un
  groupe cité.

Vérifié dans une transaction annulée : 44 → 45 lignes, et le compte à la fois
abonné **et** mentionné n'en reçoit qu'une.

*Deux étaient des doublons* — `onPostLiked` et `onPostCommented`. L'app crée
déjà ces notifications côté client via la RPC `create_user_notification`
(`feed_provider.dart` : `postLiked`, `postCommented`, `commentReply`,
`postReposted`). Les rebrancher aurait doublé chaque « j'aime ». C'est
exactement la mise en garde laissée dans `index.js` à la suppression
d'`onCommentMention` — elle était juste.

*Deux n'ont plus de côté serveur du tout* — `onAudioRoomInviteCreated` (aucune
table d'invitations dans Supabase) et `onSupportMessageCreated` (les messages
de ticket vivent dans une colonne jsonb qu'aucun ticket ne remplit à ce jour).
Les porter reviendrait à deviner une forme de donnée que personne n'écrit.

*Le reste* : `sendNotificationOnCreate` et `sendChatNotification` sont
l'ancienne chaîne de push, l'une remplacée par `send-push`, l'autre désactivée
par un `return null` depuis longtemps. `onMessageDeleted` écoute un chemin RTDB
que l'app n'écrit plus.

Les cinq fonctions concernées portent désormais un en-tête `⚠️ MORTE` qui dit
pourquoi et ce qui les remplace. Elles restent **déployées mais inertes** :
leurs déclencheurs Firestore ne se produisent plus. Les retirer de Firebase
demande un `functions:delete` explicite — non fait, ça ne presse pas.

⚠️ **`cleanupUserData` n'a pas été touchée.** C'est du nettoyage Firestore de
bout en bout (conversations, messages, notifications) alors que ces données
sont dans Supabase — donc supprimer un compte y laisse tout en place. Mais
Jules a committé sur cette fonction le 2026-08-06 (`8d769d3`) : à traiter dans
son chantier, pas ici.

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

### Événements locaux + « M'avertir du prochain » — branchés (2026-08-06)

Les deux ne faisaient rien, pour deux raisons différentes. Ils partagent
désormais le même mécanisme.

**L'appariement se fait au rayon GPS, plus à la ville.** `users.city` est vide
pour les 10 comptes — le champ existe dans deux écrans de profil, personne ne
le remplit. La latitude/longitude, elle, est publiée par la carte « membres
autour » (5 comptes sur 10). Nouveau RPC `users_near_point(lat, lng, rayon)`
(migration `20260806100000`) : boîte englobante puis haversine, filtrage des
deux préférences inclus, `SECURITY DEFINER` et révoqué pour `anon` et
`authenticated`. Rayon retenu : **50 km**.

Vérifié sur la base **et** depuis l'environnement réel des Cloud Functions,
mêmes chiffres des deux côtés :

| Requête | Destinataires |
|---|---|
| Niamey, 50 km | 1 |
| Montréal, 50 km | 3 |
| Rayon 20 000 km | 5 (tous ceux qui ont des coordonnées) |
| Niamey, 1 km | 0 |

**« M'avertir du prochain » délègue au propriétaire du réglage.** Elle gardait
sa propre copie `bool` dans les SharedPreferences — une quatrième source pour
un réglage qui en avait déjà trop — et s'abonnait à un topic FCM que personne
n'alimente. Elle appelle maintenant
`NotificationPreferencesNotifier.setLocalEventsEnabled`, qui écrit la
préférence locale **et** `users.notify_local_events` : exactement la colonne
que lit `users_near_point`. Plus aucun champ `bool` local (cf. `CLAUDE.md`).
Le calcul de topic par pays et le paramètre `notifyTopic` de `_EventsPastCard`,
devenus sans objet, sont supprimés.

- [ ] **Créer un événement avec un lieu** à moins de 50 km d'un autre compte :
      celui-ci reçoit « Nouvel événement près de chez vous ».
- [ ] **L'organisateur ne reçoit rien** pour son propre événement.
- [ ] **Événement sans coordonnées** : rien n'est envoyé, et la fonction le
      journalise au lieu d'échouer.
- [ ] **Basculer « M'avertir du prochain »** : `users.notify_local_events`
      change côté serveur (la carte n'apparaît que s'il n'y a aucun événement
      à venir mais au moins un passé — état difficile à provoquer).

## Écrans de notifications — lot « une seule source » (2026-08-05)

`notification_settings_screen.dart` a rejoint `design_kit.dart` (c'était la
dernière exception de `reglages_sans_doublon_test.dart`) et l'en-tête de
`notifications_screen.dart` a gagné un menu ⋯. Le rendu change, `analyze` ne
le voit pas.

**Passe appareil du 2026-08-05 (14:36 → 14:41 PC), SM A515F, APK debug
`14b0343` installé par `adb install -r` — mise à jour en place, session et
données préservées. Thème système en NOCTURNE.**

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

### Refonte de la liste sur la maquette 12c (2026-08-05)

Deux registres, sections par jour, palette du thème. L'accordéon des groupes
est **conservé** (choix de Salim) : c'est le seul endroit d'où l'on voit les
notifications d'un groupe une par une.

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
- [ ] **Relevé au passage — le pilotage `adb` dérive sur cet écran.** Quand
  une notification change de registre, la carte perd sa hauteur et **tout ce
  qui est en dessous remonte** : un tap calculé sur une capture prise 3 s plus
  tôt tombe à côté (deux fois sur trois ici, dont une navigation involontaire
  dans une conversation, et une demande acceptée au lieu d'être refusée).
  Recapturer **juste avant chaque tap**, ou tester au doigt. Ce n'est pas un
  défaut de l'app — c'est une limite de la méthode.
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
- [ ] **Relevé au passage — la palette de familles rend deux teintes, pas
  quatre.** `groupInvite`, `eventReminder`, `newFollower` et `proximityAlert`
  ressortent toutes du **même vert** : `successColor` et
  `adaptiveSecondaryColor` sont trop proches sur ce thème. Seul l'or des
  commandes se distingue. À arbitrer — soit on assume deux familles visuelles,
  soit on écarte les deux teintes.
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

## Bruit dans logcat — deux traces à ne pas re-diagnostiquer (2026-08-05)

Relevées en fin de session. Aucune des deux n'a d'effet visible, mais elles
polluent logcat, et **c'est ce qui rend un vrai refus invisible** — il a fallu
vider logcat et retaper pour voir celui qui bloquait « Accepter ».

### `PERMISSION_DENIED` sur `conversations/883c9d96-…` — écoute fantôme

Ce n'est **pas** un défaut de droits. Enchaînement établi :

- l'id est un **UUID Supabase**, et la conversation existe bien côté Supabase
  (créée le 2026-07-17, vérifiée par `supabase db query --linked`) ;
- elle **n'a jamais existé dans Firestore** : la collection `conversations`
  n'y contient qu'un seul document, un id auto-généré appartenant à Salim L. ;
- la messagerie est câblée sur `MessageSupabaseDataSource`
  (`message_provider.dart`), donc plus rien ne devrait interroger Firestore ;
- le seul écouteur Firestore sur un document de conversation est
  `MessageRemoteDataSourceImpl.getConversationStream`
  (`message_remote_datasource.dart:518`), et il est **injoignable** : cette
  classe n'est instanciée que par la recherche, qui n'appelle d'elle que
  `searchConversations`.

Conclusion : c'est une **cible d'écoute rémanente**, enregistrée par un build
d'avant la migration et rejouée par la persistance locale de Firestore à
chaque démarrage. La règle refuse au lieu de renvoyer « vide » parce que
`resource` est nul sur un document absent — même faiblesse que celle corrigée
sur `users`, mais bénigne en lecture.

- [ ] Non prouvé faute de moyen non destructif : confirmer en vidant le cache
  Firestore de l'app. **Ça efface les données de l'app**, donc les clés E2EE —
  à ne faire que si la trace devient gênante.

### 🔴 Supprimer un compte laisse un ami fantôme chez tous ses amis

Trouvé en remontant l'incohérence relevée chez Salim L. (`friendIds` vide,
deux amis dans `friends/`).

L'amitié est écrite **des deux côtés** (`users/A/friends/B` et
`users/B/friends/A`), et c'est **cette sous-collection que l'app lit** —
`getFriends` et `areFriends` n'utilisent qu'elle. Le tableau `friendIds`, lui,
n'est lu par **aucun** écran : son seul lecteur est la fonction de suppression
de compte.

Or `deleteAccount` (`functions/index.js`) :
- efface les sous-collections **du compte supprimé** (`friends`,
  `blocked_users`, `cart`, `sessions`) ;
- retire l'utilisateur des `friendIds` des autres — un champ que personne ne
  lit ;
- et **ne touche jamais** aux entrées miroir `users/{autre}/friends/{supprimé}`.

Conséquence : le compte supprimé **reste indéfiniment dans la liste d'amis des
autres**, avec son nom et sa photo, et `areFriends` répond toujours « oui ».

**Correctif écrit** : la liste d'amis du compte donne exactement l'ensemble
des personnes ayant une entrée miroir ; on les supprime avant d'effacer la
liste. Pas de requête de groupe de collections, donc **aucun index
supplémentaire** à créer.

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
  **Garde-fou ajouté le 2026-08-06** : `tools/rules_tests/nettoyage_isole.mjs`
  vérifie que les 17 étapes `// 1.N` sont bien chacune dans un
  `await etape(…)`. 17 annoncées, 17 enveloppes. Contre-épreuve faite — pointé
  sur `git show 8d769d3:functions/index.js`, il sort 1 et liste les 16 étapes
  nues : **il sait échouer**.
  ⚠️ Ce banc prouve la **couverture**, pas le comportement à l'exécution. Le
  risque réel était qu'une étape soit ajoutée hors enveloppe, pas qu'un
  `try/catch` cesse de fonctionner — mais il ne remplace pas un vrai échec
  provoqué en conditions réelles, qui reste à faire.
  **À faire** : redéployer `cleanupUserData` **seul** (cf. l'entrée ci-dessus
  sur les orphelines, et ne jamais `--force`), puis rejouer le scénario à deux
  comptes jetables en forçant l'échec d'une étape intermédiaire — vérifier que
  les étapes suivantes s'exécutent quand même et que l'étape fautive apparaît
  nommée dans les journaux.
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
- [ ] 🔴 **Index RTDB manquant sur les deux balayages de messages** (trouvé
  dans les mêmes journaux, 2026-08-06, **non corrigé**) :
  `FIREBASE WARNING: Using an unspecified index … Consider adding
  ".indexOn": "expiresAt" at /messages/<convId>`.
  `database.rules.json` déclare bien un `.indexOn` sur `messages/$conversationId`,
  mais **uniquement `["createdAt"]`**. Or `cleanupExpiredMessages` interroge
  `orderByChild("expiresAt")` et `cleanupExpiredMediaFiles`
  `orderByChild("mediaExpiresAt")` — aucun des deux n'est indexé.
  Conséquence : à chaque passage, **tous** les messages de **chaque**
  conversation sont téléchargés puis filtrés côté fonction. Invisible
  aujourd'hui (une seule conversation a des messages en RTDB, 1,5 à 2 s par
  exécution), mais le coût croît avec l'historique — c'est exactement la
  fonction qu'on vient de fiabiliser qui deviendra lente et chère.
  **Index ajouté au fichier** le 2026-08-06 (`.indexOn` de
  `messages/$conversationId` passe à `["createdAt", "expiresAt",
  "mediaExpiresAt"]`, JSON revalidé), puis **déployé** — voir juste en dessous
  pour ce que ce déploiement a entraîné d'autre.
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

### 🔴 `database.rules.json` est en avance de 27 changements sur la production

Relevé le 2026-08-06 en voulant déployer le simple index ci-dessus. Les règles
en ligne se lisent avec :

```
MSYS_NO_PATHCONV=1 firebase database:get "/.settings/rules"
```

(`database:settings:get` ne sait pas lire `rules`, et sous Git Bash le chemin
`/.settings/rules` est mangé par la conversion MSYS — d'où `MSYS_NO_PATHCONV=1`.)

Comparées au fichier du dépôt : **18 chemins de règles existent dans le dépôt
et pas en ligne** (`admins`, `superAdmins`, `warnings` des salons, plusieurs
`.validate`, et les restrictions de signalisation) et **9 valeurs diffèrent
réellement** — aucune n'est une simple différence de mise en forme, vérifié en
normalisant les espaces.

Les quatre qui comptent :

| chemin | en ligne | dans le dépôt |
|---|---|---|
| `calls/$callId/.read` | `auth != null` | réservé à l'appelant/appelé |
| `calls/$callId/.write` | `auth != null` | idem |
| `group_calls/$callId/.read` | `auth != null` | réservé aux participants/hôte |
| `group_calls/$callId/.write` | `auth != null` | idem |

Le dépôt est donc **plus strict** que la production : c'est le durcissement de
la signalisation d'appel, écrit le 2026-08-03 et **volontairement laissé non
déployé** en attendant le test de non-régression à deux comptes (voir la
section « Appel 1:1 après restriction »).

⚠️ **Conséquence pratique : `firebase deploy --only database` n'est pas une
opération anodine.** Il embarquerait les 27 changements d'un coup, dont ce
durcissement jamais testé — et son mode d'échec est **silencieux** : l'appelé
ne verrait jamais l'offre, sans la moindre erreur. Un index de performance ne
justifie pas de risquer ça.

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
### 🔴 La signalisation des appels de groupe était refusée EN PRODUCTION

Trouvé le 2026-08-06 en passant le banc contre les règles **déployées**, pas
contre une hypothèse. Deux échecs du parcours nominal là où il ne devait y en
avoir aucun.

Le `.validate` posé sur `group_calls/$callId/signaling/$fromId/$toId` exigeait
un enfant `type` **directement** sous `$toId`. Or l'app écrit
`$toId/offer = {type, sdp}` et `$toId/candidates/<clé>`. Toute écriture de
signalisation de groupe était donc refusée — offres, réponses et candidats ICE
compris. **Introduit par `81ba52c` le 2026-08-03 et déployé depuis** : trois
jours pendant lesquels aucun appel de groupe ne pouvait établir sa connexion.
Sans erreur visible, comme toujours ici.

Rien à voir avec le durcissement d'aujourd'hui : le défaut est dans les règles
permissives comme dans les strictes.

- [x] **Correctif déployé le 2026-08-06** — le `.validate` descend sur les
  enfants réels (`offer`, `answer`, en `['type', 'sdp']`), les candidats ICE
  n'ont plus de contrainte de forme au mauvais niveau.
  **Aucune précondition sur le parc installé** : ce correctif ne fait que lever
  une validation qui refusait des écritures légitimes. C'est pourquoi il a pu
  partir tout de suite, contrairement au durcissement.
  Diff par rapport à la production exacte, vérifié champ par champ : **3
  changements, pas un de plus** — le `.validate` déplacé, la garde `auth` sur
  `e2ee_key`, et l'index déjà en place. En ligne == dépôt après coup.
- [ ] **À vérifier sur appareil** : un appel de groupe à deux comptes doit
  maintenant se connecter. C'est la seule preuve qui manque — le banc prouve
  que les règles laissent passer, pas que la connexion WebRTC aboutit.

### 🔴 La clé E2EE des appels est lisible et remplaçable par n'importe qui

Mesuré le 2026-08-06 contre les règles déployées, après une lecture de code
que je ne voulais pas vendre comme un fait. Le résultat est pire que la lecture.

| | avant | après le correctif du jour |
|---|---|---|
| un **anonyme** pose la clé absente (groupe) | AUTORISÉ | refusé |
| un **tiers** connecté pose la clé absente | AUTORISÉ | autorisé |
| un **tiers** remplace la clé existante | AUTORISÉ | **autorisé** |
| un **tiers** lit la clé | AUTORISÉ | **autorisé** |
| un anonyme / tiers pose la clé d'un 1:1 | anon refusé, tiers AUTORISÉ | idem |

La garde `auth != null` manquait sur `e2ee_key/.write` : `!data.exists()`
suffisait à accorder l'écriture. Elle est ajoutée et déployée — le trou
anonyme est fermé.

- [ ] 🔴 **Mais l'essentiel reste ouvert** : un compte connecté quelconque peut
  toujours **lire et remplacer** la clé E2EE de n'importe quel appel dont il
  connaît l'identifiant. La cause n'est pas la règle `e2ee_key` mais son
  **parent** `group_calls/$callId` (et `calls/$callId`) à `auth != null` : dans
  RTDB une autorisation accordée plus haut cascade vers le bas, donc la règle
  fille plus stricte ne sert à rien tant que le parent est permissif.
  **C'est exactement ce que le durcissement ferme** — vérifié : contre les
  règles strictes, anonyme et tiers sont tenus à l'écart sur les deux.
  Donc le chiffrement de bout en bout des appels **n'en est pas un** tant que
  le durcissement n'est pas déployé.
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
- [ ] 🔴 **À VÉRIFIER EN PRIORITÉ, ET C'EST LA SEULE CHOSE QUI MANQUE** : un
  appel 1:1 et un appel de groupe, à deux comptes. Le banc prouve que les
  règles laissent passer le parcours réel ; il ne prouve pas qu'un appel
  aboutit (FCM, CallKit, coturn, WebRTC).
  **Si ça ne sonne plus**, retour arrière immédiat :
  ```
  cp database.rules.prod-avant-2026-08-06.json database.rules.json
  firebase deploy --only database
  ```
  (ça annule aussi l'index et le correctif de signalisation de groupe — dans
  l'urgence c'est sans importance, on redéploiera proprement ensuite.)
- [ ] **`e2ee_key` des appels de groupe est écrite mais JAMAIS LUE.** Une seule
  occurrence dans tout `lib/` (`group_call_service.dart`, `_shareE2EEKey`), et
  c'est l'écriture. Personne ne récupère la clé en rejoignant. Le chiffrement
  de bout en bout des appels de groupe n'est donc pas câblé — la clé est
  publiée dans le vide. Même motif que les champs d'état jamais alimentés déjà
  rencontrés sur ce projet. Sans effet sur le durcissement (durcir la lecture
  de quelque chose que personne ne lit ne casse rien), mais à traiter. Le dépôt porte volontairement la version
  stricte corrigée ; la production reste permissive. Deux préconditions, toutes
  deux liées au parc installé :
  - l'APK doit écrire `callerId`/`calleeId` (acquis depuis `135ae92`,
    2026-08-03) ;
  - l'APK doit s'inscrire avant d'écouter (acquis **aujourd'hui seulement**,
    donc **aucun** build existant ne l'a).
  **Donc : rebâtir et réinstaller l'app d'abord, déployer les règles ensuite.**
  Vérifier entre les deux que `node tools/rules_tests/signalisation_appels.mjs`
  affiche « Parcours nominal : INTACT ».
  Le fichier cible est versionné à part : **`database.rules.strict-cible.json`**.
  `database.rules.json` reste donc le reflet exact de ce qui est **déployé** —
  c'est le seul moyen de ne pas refabriquer la dérive qui a coûté la journée.
  Pour déployer le jour venu : remplacer l'un par l'autre, relancer le banc,
  puis `firebase deploy --only database`.
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
- [ ] 🔴 **L'étanchéité de la signalisation reste donc OUVERTE.** Tout compte
  connecté peut lire et écrire la signalisation de n'importe quel appel dont il
  connaît l'identifiant. Le test le constate explicitement (deux lignes
  attendues « autorisé »), et **ces deux lignes échoueront le jour où ce sera
  fermé — c'est le signal voulu**.
  **Pour fermer sans casser** : il faut D'ABORD que l'app écrive `callerId` et
  `calleeId` dans le nœud RTDB au moment de créer l'appel. Tant que ce n'est
  pas fait, tout prédicat qui s'appuie dessus est toujours faux. L'ordre est :
  1) écrire les deux champs côté app, 2) déployer l'app, 3) attendre que le
  parc installé ait migré, 4) seulement ensuite durcir les règles.
- [ ] ~~**MAIS le test de non-régression des appels n'a PAS été fait avant
  le déploiement**~~ — il demande deux comptes sur deux téléphones. Le
  durcissement de la signalisation est donc **en production sans avoir jamais
  été exercé**, et son mode d'échec est silencieux : l'appelé ne voit jamais
  l'offre, aucune erreur, rien dans les journaux.
  **À faire en priorité, avant toute autre chose** : un appel 1:1 complet entre
  deux comptes — sonnerie, décroché, audio des deux côtés, passage en vidéo,
  raccrochage. Puis un appel de groupe.
  **Retour arrière si ça ne sonne plus** — les règles de production d'avant le
  déploiement sont conservées dans `database.rules.prod-avant-2026-08-06.json`
  (à la racine, versionné). C'est le **seul** enregistrement de cet état : le
  fichier du dépôt n'a jamais été ce qui tournait. Pour revenir :
  ```
  cp database.rules.prod-avant-2026-08-06.json database.rules.json
  firebase deploy --only database
  ```
  (ça annule aussi l'index, ce qui est sans importance dans l'urgence).
- [x] 🔴 **Deux fonctions tournaient en production sans source dans le dépôt —
  sources retrouvées et réintégrées** (`a7db115`).
  `sendMessagePush(europe-west1)` était dans `stash@{3}` (2026-07-20), jamais
  commitée nulle part ; `sendChatNotification(us-central1)` dans `1bb0cca^`,
  retirée du dépôt sans être supprimée côté Firebase — et désactivée
  (`return null` en tête) depuis avant son retrait.
  `firebase deploy --only functions --dry-run` ne signale plus d'orpheline :
  un déploiement global redevient possible.
- [ ] ⚠ **Réintégré ne veut pas dire vérifié.** Le code déployé n'est pas
  lisible : il peut différer de ces sources. Rien n'a été redéployé, et
  `sendMessagePush` reste **appelée par les APK déjà installés** — ne jamais
  accepter sa suppression ni utiliser `--force`.
- [ ] Le repliage de `handleNewMessagePush` dans `onMessageCreated` avait perdu
  le **contrôle de participation** (`callerUid`) : sans lui, le callable
  laisserait pousser une notification vers une conversation dont on ne fait pas
  partie. Réinjecté depuis le stash, mais **jamais exercé** — à tester si le
  callable redevient utilisé.

### 🔴 Le backend en production a dix-sept jours de retard

Relevé le 2026-08-05 en vérifiant si le garde-fou du webhook Stripe était
réellement en ligne. Dates de mise à jour lues par l'API Cloud Functions :

| fonction | déployée le |
|---|---|
| `stripeWebhook` | 2026-07-19 |
| `sendMessagePush` | 2026-07-19 |
| `sendChatNotification` | **2026-03-11** |
| `cleanupUserData` | 2026-08-05 (par ce lot) |

**Huit commits touchant `functions/` n'ont jamais atteint la production**, dont
plusieurs correctifs de fond :

- `ec07de4` — refus du secret Stripe laissé au placeholder. Le garde-fou est
  écrit et correct (500 explicite au lieu d'un 400 indistinguable d'une requête
  falsifiée), **mais il n'est pas en ligne** : la prod répond toujours 400 sur
  chaque webhook Stripe, donc aucun paiement n'est confirmé côté serveur ;
- `a82c6b5` — `dotenv` et `livekit-server-sdk` déclarés, ce qui réparait
  `onCallCreated` (la cause racine du « ça ne sonne pas ») ;
- `e94913f` — modules `partners/` restaurés ;
- `23fb3e4` — suppression d'un trigger Firestore mort ;
- `e9d5928` et `a7db115` — les deux correctifs de ce lot.

`sendChatNotification` déployée en **mars** explique aussi son hash de source
différent des autres : la version en ligne est antérieure à sa désactivation,
donc potentiellement encore active.

- [ ] Décider d'un déploiement global. Il est désormais possible (plus
  d'orpheline, `--dry-run` passe), mais il republierait `.env` tel quel —
  placeholder Stripe et secret coturn compromis compris. Corriger `.env`
  d'abord, cf. `docs/ops/secrets_production.md`.

### `FAILED_PRECONDITION` — index manquant sur les événements

`events where status == completed order by -startDate` échoue à chaque
démarrage : l'index composite n'existe pas.

- [x] **Corrigé le 2026-08-05.** L'index `status ASC + startDate DESC` a été
  créé, il est `READY`, et plus aucun `FAILED_PRECONDITION` au démarrage.
- [ ] ⚠ **Le fichier `firestore.indexes.json` est en retard sur la production
  — 47 entrées contre 71 déployées.** Même dérive que celle trouvée sur les
  règles. L'index a donc été créé **par l'API Firestore, pas par
  `firebase deploy --only firestore:indexes`** : déployer le fichier
  proposerait de supprimer 24 index en service. À resynchroniser depuis la
  prod avant tout déploiement d'index, comme on l'a fait pour les règles.
- [x] **Vérifié avec une vraie donnée le 2026-08-05** : un événement
  `status: "completed"` daté de trois jours plus tôt a été créé, puis la
  requête exacte qui échouait — `events where status == completed order by
  startDate desc` — a été rejouée côté serveur. Elle renvoie **1 résultat** au
  lieu du `FAILED_PRECONDITION`. Événement supprimé après coup.
- [ ] Le **rendu de la liste** dans l'écran Événements reste à voir au doigt :
  j'ai prouvé que la requête aboutit et que la donnée remonte, pas que l'onglet
  l'affiche.

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
- [x] **Branche écriture validée le 2026-08-04 à 18:21** — sauvegarde créée par
      Salim (la passphrase doit être consignée par un humain : une passphrase
      perdue laisse un futur appareil en `needsRestore` sans pouvoir restaurer,
      donc pire que pas de sauvegarde). L'écran affiche **« Sauvegarde active »**,
      « Créée le : 4/8/2026 à 18:21 », « Appareil : android Device », plus la
      section « Restaurer sur cet appareil ». `uploadBackup` **et** la lecture
      des métadonnées fonctionnent : la règle `key_backups/` est donc prouvée en
      **lecture et en écriture**, de bout en bout.
- [ ] Cosmétique relevé au passage : le libellé d'appareil est « android
      Device », peu lisible pour un utilisateur.
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

### Troisième tour (16:24 → 16:40), appareil enfin libre

**✅ Brouillon restauré — le cas décisif passe.** Prémisse établie par capture
(texte « BrouillonTest0804 » dans le champ, bouton d'envoi bleu à cadenas), puis
bouton accueil, `am force-stop`, relance à froid, réouverture de « Mes notes » :

- [x] Le brouillon est restauré **et le bouton d'envoi bleu est là d'emblée**,
      sans toucher au champ. Correctif `20042b7` vérifié en vrai.
- [x] **Envoi direct du brouillon restauré**, sans toucher le champ au
      préalable : le message part et s'affiche dans le fil de la conversation.
- [x] **Non-régression** : après envoi, le composer revient au **micro**
      (conversation sans brouillon).
- [ ] Reste le cas du brouillon de **plus de 2000 caractères** (état
      « dépassement » à restaurer) — tentative ratée, mon tap avait atterri sur
      le clavier. À refaire.

⚠ **Les deux échecs précédents n'étaient pas des bugs** : `mInputShown=false`
après le tap = le tap n'avait pas atteint le champ. Avec le clavier ouvert, le
composer remonte à ~1300 px et non ~2170 px — vérifier `mInputShown` avant de
conclure quoi que ce soit.

### 🔴 Trouvé — un lien vers une publication inexistante reste bloqué sur les squelettes

`am start -a VIEW -d https://diasponiger.web.app/feed/00000000-…-000000000999`
(app tuée au préalable). Le routage fonctionne — `/splash` puis redirection vers
`/feed/00000000-…`, donc la mise de côté du lien opère bien ici. Mais l'écran
d'arrivée ne dégrade pas proprement :

- des **squelettes de chargement permanents** à la place de la publication —
  toujours là à **105 s**, vérifié par deux captures espacées ;
- **aucun message d'erreur**, aucun « publication introuvable » ;
- pire, « Aucun commentaire pour le moment » s'affiche et **le champ de
  commentaire est actif** : on invite l'utilisateur à commenter une publication
  qui n'existe pas.

L'exception est pourtant bien levée et journalisée, puis avalée :
`PostgrestException(message: Cannot coerce the result to a single JSON object,
code: PGRST116)` — c'est le `.single()` sur un résultat vide.

**✅ Corrigé le 2026-08-04.** Trois couches touchées, car il y avait deux causes
enchaînées :

1. `feed_supabase_datasource.dart` traduit désormais `PostgrestException`
   PGRST116 en `NotFoundException` (avant, l'exception s'échappait de la couche
   data et, `_load` n'étant pas attendu, partait en erreur asynchrone non gérée
   — le `fold` n'était même jamais atteint) ;
2. `feed_repository_impl.dart` mappe `NotFoundException` → `NotFoundFailure`,
   avec un `catch` de dernier recours pour ne plus rien laisser s'échapper ;
3. `feed_provider.dart` remplace `PostEntity?` par un `PostDetailState`
   (`loading` / `loaded` / `notFound` / `failed`) — `null` ne peut plus vouloir
   dire deux choses.

L'écran affiche maintenant « Publication introuvable » (avec « Retour au fil »)
ou « Impossible d'afficher cette publication » (avec « Réessayer », qui n'a de
sens que sur une panne), et **le champ de commentaire est masqué** dans les deux
cas.

Couvert par `test/features/feed/post_detail_not_found_test.dart` (4 cas).
Le test du repository a été **vérifié rouge sans le correctif** (l'exception
traverse le repository), il n'est donc pas vide de sens. `flutter analyze`
propre, 17/17 sur `test/features/feed/`.

**✅ Vérifié sur appareil le 2026-08-04 à 17:50**, APK debug réinstallé
(`lastUpdateTime=17:48:20`) :

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
- [ ] Rejouer avec une publication **réellement supprimée** (pas seulement un id
      inventé) : c'est le cas que rencontrera un vrai utilisateur.

⚠️ **La réinstallation n'a PAS vidé les données cette fois** : session
conservée, ni `/consent` ni assistant de profil. Le piège documenté n'est donc
pas systématique — mais l'identité Signal générée dans la journée n'a toujours
**aucune sauvegarde**, et la passphrase reste à créer par Salim.

### ⚠ Empreinte mémoire à surveiller

`dumpsys meminfo` pendant la passe : **TOTAL PSS ≈ 1,0 Go** (Native Heap 100 Mo,
Dalvik 26 Mo), et le système tuait des process en arrière-plan au même moment
(`edgelighting`, `mobileservice`, `turbo:aab`). C'est un **build debug** avec
Impeller et la carte Google ouverte, donc non représentatif tel quel.

- [ ] Refaire la mesure sur un **build release**, carte fermée puis ouverte, pour
      savoir si le pic vient de la carte ou du mode debug.

### ✅ Feuille de partage fantôme — ne réapparaît plus (3 relances sur 3)

L'intent de tâche a d'abord été réarmé par un vrai lien profond
(`am start -a VIEW -d https://diasponiger.web.app/feed/…`), puis trois cycles
`am force-stop` + relance par le launcher :

- [x] **Aucune feuille de partage** aux trois relances, et **aucun rejeu du
      lien** : l'app arrive sur `/home` à chaque fois. C'est le cas décisif de la
      purge `reset()` + de l'empreinte persistée.
- [x] Les seules traces « share » dans le journal sont bénignes (« Encryption
      service initialized with shared key », et la route `/share` dans la liste).
- [ ] Reste à faire : un **vrai partage entrant** depuis Chrome ou Messages
      (image, vidéo, PDF, sélection multiple) — non testable en pilotage `adb`
      sans passer par le sélecteur système.

### ✅ Repli hors-ligne — le bug documenté NE se reproduit PAS (16:47, mode avion réel)

Mode avion activé par Salim. État vérifié avant de commencer :
`airplane_mode_on=1`, Wi-Fi désactivé, **`Active default network: none`**.
⚠ Un agent réseau **VPN reste « CONNECTED »** dans `dumpsys connectivity`, mais
il n'est plus le réseau par défaut — c'est probablement là toute la différence
avec la mesure précédente, où `connectivity_plus` voyait « connecté » et l'app
n'entrait donc jamais en mode hors-ligne. **Hypothèse, pas preuve.**

Aucun des trois symptômes décrits plus bas ne se reproduit :

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

**Le bug « repli hors-ligne » est donc à refermer**, sauf à le reproduire dans
les conditions exactes d'origine (VPN actif comme réseau par défaut).

### 🔴 Trouvé hors ligne — trois défauts distincts

- [ ] **Aucun indicateur « hors ligne » hors du fil.** L'accueil, la carte, les
      messages et le profil ne signalent rien : l'app a l'air normale alors que
      rien ne se charge. Seul « Le fil » a son bandeau. À uniformiser.
- [ ] **Le nom du correspondant retombe sur « Utilisateur »** dans la liste des
      conversations (« Salim L. » en ligne, « Utilisateur » + initiale « U »
      hors ligne). Le dernier message, lui, est bien en cache — c'est donc le
      profil du correspondant qui n'est pas mis en cache.
- [ ] **Boucle de rafraîchissement du jeton sans backoff.** Hors ligne,
      `SupabaseAuthBridge` rejoue le rafraîchissement **toutes les ~13 s**
      indéfiniment (16:47:53, 16:48:06, 16:48:19, 16:48:31…), chaque tour
      déclenchant plusieurs requêtes qui échouent en `Failed host lookup`.
      Coût batterie et bruit de journal. Prévoir un backoff, ou suspendre tant
      que `connectivity` annonce l'absence de réseau.
- [ ] « Autour de vous » (accueil) reste sur **4 avatars squelettes** hors ligne,
      sans état vide.

### Bilan du programme — ce qui reste, et pourquoi

- [ ] **Repli hors-ligne** (splash de ~2 min + squelettes infinis) — ⚠ **je ne
      peux pas le faire seul** : couper le réseau est une modification de réglage
      système. Bonne nouvelle, **le piège du VPN a disparu** : le réseau de l'app
      est `wlan0` avec la capacité `NOT_VPN`, donc un vrai état hors-ligne est
      atteignable, contrairement au 2026-07-28. **À faire par Salim** : activer
      le mode avion, puis me le dire — je démarre à froid et je chronomètre.
- [ ] **Admin, champ « Type * »** — ⚠ **inatteignable sur ce compte**. Le routeur
      conditionne `/admin/embassies/create` à `user.isAdmin`
      (`app_router.dart:193`), et aucune entrée « Administration » n'existe dans
      les Réglages. À reprendre avec un compte administrateur.
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
- [ ] ⚠ **`am start` ne prouve pas le clic réel.** Android répond « Activity not
      started, its current task has been brought to the front » — le cas a bien
      été exercé, mais un vrai clic vient d'une autre app (Chrome, Messages)
      avec sa propre tâche. À refaire au doigt depuis Chrome pour être complet.
- [ ] Même chemin **déconnecté** : la route doit être mise de côté puis rejouée
      après connexion (étapes 0 et 10 du `redirect`) — non exercé.
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
- [ ] 🧹 **Reste un brouillon de test de 2000 caractères dans « Mes notes »** :
      ma tentative de nettoyage par `input keycombination` n'a pas pris. À
      effacer à la main.

### ⚠ Partage entrant : non présenté par `am start` — à confirmer au doigt

`am start -a android.intent.action.SEND -t text/plain --es
android.intent.extra.TEXT … com.diasponiger.diasponiger` : l'app démarre bien
(l'intent est accepté, `pkg=com.diasponiger.diasponiger`) mais **atterrit sur
`/home`** — la feuille « Envoyer à… » ne s'ouvre pas.

Le tri côté Dart n'est pourtant pas en cause : un texte arrive en
`SharedMediaType.text` et n'est donc pas écarté par `_withoutDeepLinks`, et
l'empreinte persistée ne peut pas bloquer un contenu inédit.

**Je ne conclus pas à un bug.** Comme pour le lien profond, `am start` depuis le
shell n'est pas le chemin réel : un vrai partage vient d'une autre app, via le
sélecteur système, avec sa propre tâche. Trancher demanderait une troisième
passe d'instrumentation, et la réserve subsisterait.

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
- [ ] **Sauvegarde E2EE en écriture** — à faire par Salim, avec la passphrase
      notée (cf. plus haut).

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
- [x] ~~Brouillon de **plus de 2000 caractères** : l'état « dépassement »~~ —
      **caduc depuis le 2026-08-04.** L'état `_isOverLimit` a été supprimé : le
      `maxLength: 2000` du `TextField` tronque la saisie *et* le collé, donc le
      dépassement était inatteignable. Il reste à vérifier au doigt qu'un
      brouillon exactement à 2000 caractères se restaure sans casse.
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

## Storage — énumération des médias coupée (2026-08-04, DÉPLOYÉ)

`storage.rules` : `match /messages/{conversationId}/{allPaths=**}` passait
`allow read: if isAuthenticated()`. Or `read` couvre `get` ET `list` — connaître
un `conversationId` suffisait donc à énumérer puis télécharger tout le média de
la conversation, y compris pour un membre exclu d'un groupe. Séparé en
`allow get` / `allow list: if false`, **déployé sur `diaspo-niger`**.

Vérifié après déploiement : aucun plantage, aucune erreur Storage dans logcat,
la conversation et la liste s'affichent à l'identique.

- [ ] **Confirmer qu'un média s'affiche toujours.** Non vérifié : l'unique
      média du compte de test était déjà un rectangle noir *avant* le
      changement, donc la comparaison ne prouve rien. Envoyer une image dans
      une conversation et vérifier qu'elle s'affiche, en réception comme en
      envoi.
- [ ] Vérifier la galerie « Médias » d'une conversation (si elle liste des
      objets Storage plutôt que des lignes de base, elle casserait).

Rollback si besoin : remettre `allow read: if isAuthenticated();` dans
`storage.rules` puis `firebase deploy --only storage --project diaspo-niger`.

⚠️ Ce n'est PAS la restriction aux participants : les règles Storage ne savent
interroger que Firestore, or l'appartenance vit dans Supabase. Voir
CHIFFREMENT_MEDIAS_PLAN.md.

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
- [x] **20b — « CET APPAREIL » : RÉSOLU, vérifié le 2026-08-04 à 18:22.** La
  liste affiche maintenant **3 appareils sur 5**, et le courant porte bien la
  pastille verte « CET APPAREIL » avec son empreinte et le bouton « Renommer ».
  Le bandeau d'avertissement a disparu.

  ⚠ **La cause n'était pas celle qu'on croyait.** Ce n'étaient pas les
  `adb install -r` : c'était la règle Storage `key_backups/` manquante, qui
  faisait sauter la génération des clés (voir plus haut). Sans génération,
  aucun enregistrement E2EE n'avait lieu, donc aucun appareil courant. La
  règle déployée ce matin a débloqué la chaîne, et l'entrée de cet appareil a
  été créée dans la foulée — d'où le passage de 2 à 3 appareils.
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
- [ ] Les 3 entrées actuelles restent : à nettoyer à la main via « Révoquer ».

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

## Doublons Profil / Réglages (2026-08-05)

- [ ] **« Actions du compte » a changé d'écran** (`profile_screen.dart`,
  `settings_screen.dart`) — Déconnexion et Supprimer mon compte sont passées du
  bas de Réglages au bas du Profil, à la place du bloc « Réglages ». À
  vérifier : la carte d'alerte s'affiche bien en bas du Profil (ambre / rouge,
  bordure), **Réglages se termine maintenant sur « Exporter mes données »**, et
  surtout que **la suppression de compte va au bout** — toute sa chaîne
  (confirmation finale, invite de mot de passe, réauthentification) a été
  déplacée avec elle. Ne pas tester la suppression sur le compte réel :
  s'arrêter à l'invite de mot de passe.
- [ ] **L'engrenage de l'en-tête du Profil reste le seul chemin vers Réglages**
  — les trois raccourcis (Confidentialité, Apparence, Aide) ont disparu.
  Vérifier qu'on atteint toujours chaque section en faisant défiler.

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

**Vérifié sur SM A515F le 2026-08-05, en clair.** Les cinq points ci-dessus
sont passés, dont trois confirmés **en base** et pas seulement à l'écran :

| Colonne de `public.users` | Avant | Après « Ma localisation » coupée |
|---|---|---|
| `share_location` | true | **false** |
| `is_visible` | true | true |
| `show_online_status` | true | true |

C'est la preuve que cherchait le lot 4b : l'ancien code réécrivait les quatre
champs d'un coup. Couper l'interrupteur push a bien mis
`notifications_enabled` à `false` côté serveur, là où seule la préférence
locale changeait avant. **Les quatre valeurs ont été remises à leur état
d'origine après le test.**

L'ancrage des sections marche aussi : « Apparence et langue » ouvre Réglages
directement sur la section APPLICATION.

---

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
- [ ] **Accusé de réception « remis »** (`mark_messages_as_delivered`, commit `da21b24`) — bug capturé dans les logs d'un appareil réel puis corrigé côté SQL, jamais revalidé en conditions réelles depuis. Re-vérifié côté base le 2026-08-30 (`supabase db query --linked`, transactions annulées) : signature `(TEXT, TEXT)` unique, `SECURITY DEFINER`, `authenticated` seul autorisé (`anon` refusé), et un message réel du jour a bien `deliveredAt` peuplé pour le destinataire — la RPC tourne en prod. Test isolé (insert jetable + `ROLLBACK`) confirme l'idempotence d'un rappel séquentiel et que `readBy` n'est jamais touché. ⚠️ Trouvé en marge : sur ce même message réel, `deliveredTo` contient le destinataire **en double** dans le tableau JSON brut (probablement `initState` + `didChangeAppLifecycleState(resumed)` de `conversation_screen.dart:193,422` qui appellent `markAsDeliveredProvider.mark()` quasi simultanément à l'ouverture depuis une notification, créant une vraie course réseau) — sans impact visible : `_mergedReceipts` (`message_supabase_datasource.dart:123`) dédoublonne via `Set` à la lecture, donc `message.deliveredTo` et le badge « Reçu »/« Lu » restent corrects côté app. Reste seulement cosmétique en base. Ce qui reste réellement non vérifié : le scénario UI à deux comptes (voir section « Accusés livré/lu séparés » plus haut, ligne ~1947).
- [ ] **Statut en ligne (Firestore → Supabase)** (commit `b16dc88`) — bug de confidentialité corrigé (préférence `showOnlineStatus` ignorée), jamais vérifié à l'écran.

## Groupes & événements en conversation

- [ ] **Bulle `EventMessageCard` en conversation + différenciation groupe** (commit `267d7d3`) : visibilité « publier dans le fil » DM/groupe, badge Admin sur les bulles, « Vu par N » sur messages de groupe lus, boutons appel/vidéo de groupe dans l'app bar, auto-adhésion au groupe pays au chargement du profil — aucun sous-élément vérifié sur device.
- [x] **Alignement des bulles reçues dans une série de groupe — CORRIGÉ ET VÉRIFIÉ SUR APPAREIL** (`message_bubble.dart`, `conversation_screen.dart`, SM A515F, 2026-08-13). Deux défauts distincts trouvés sur le même chemin :
  1. Le padding gauche des messages reçus en groupe passait de 8 (avatar affiché sur le 1er message d'une série) à 16 (pas d'avatar sur les suivants) — saut de 28px, bulles non alignées verticalement dans une même série. Corrigé en réservant toujours la largeur de l'avatar (`SizedBox(width: 28)` en son absence) pour tout message reçu d'un groupe (`groupId` non nul).
  2. **Avatar dupliqué** — `conversation_screen.dart` enveloppait `MessageBubble` dans SA PROPRE colonne avatar (radius 12, gris, sans badge vérifié ni tap-profil) pour tout message de groupe reçu, en plus de l'avatar interne de `MessageBubble` (radius 14, coloré) : deux cercles « S » côte à côte sur chaque message montrant l'expéditeur. Les deux branches du ternaire `_isGroup && !isMe ? Row(...) : MessageBubble(...)` construisaient `MessageBubble` avec des paramètres strictement identiques — le wrapper était mort code redondant. Supprimé, un seul appel `MessageBubble(...)` désormais.

  Vérifié sur le groupe « teste » (messages réels de Salim L., série de 2 sur 18 juillet 2026) : un seul avatar par message, bulles alignées au même bord gauche que le message montre le nom/avatar ou non.

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

## 🔴 Appels 1-à-1 mis en PAUSE (2026-08-14) — répondre à un appel ne faisait rigoureusement rien

Trouvé en testant à deux appareils réels (SM A515F + émulateur) après un
signalement « les appels ne passent pas ». Trois bugs empilés, chacun
suffisant à lui seul pour expliquer le symptôme :

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

**Les trois premiers correctifs sont vérifiés fonctionnels sur device**
(appel décroché et connecté avec succès entre SM A515F et émulateur). Mais la
session de test a été chaotique (émulateur repris par une autre
activité/session en cours de route, plusieurs faux départs) — **pas assez de
cycles propres pour être confiant sur la fiabilité bout-en-bout**
(reconnexion ICE en particulier, jamais vue aboutir jusqu'au bout dans un
test propre). Décision : couper l'accès utilisateur à la fonctionnalité le
temps d'une vérification à deux VRAIS téléphones, sans contention.

**Ce qui a été commenté (code conservé, pas supprimé)** :
- `conversation_screen.dart` : les deux `IconButton` d'appel 1-à-1 dans
  l'AppBar (audio/vidéo — les boutons d'appel de GROUPE juste en dessous
  restent actifs, système différent/LiveKit, pas concerné) ; le rappel en un
  geste sur une bulle d'appel (`onCallBack: null`) ; les méthodes
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

## Discussion en paysage — débordement de 4,1 px (vu le 2026-08-05)

- [ ] ⛔ **Débordement bas sur l'écran de conversation en PAYSAGE.** Constaté
  **deux fois** sur SM A515F le 2026-08-05, avec deux ampleurs différentes :

  | Capture | Bas de l'écran occupé par | Débordement |
  |---|---|---|
  | 1 | panneau GIF / Émojis | `4.1 PIXELS` |
  | 2 | **clavier système** | `17 PIXELS` |

  Le second cas est le plus instructif : **ce n'est pas le panneau ancré qui
  est en cause**, puisque le défaut se produit aussi avec le clavier seul.
  C'est l'écran de conversation en paysage dès que l'espace vertical restant
  se réduit — et l'ampleur suit la hauteur de ce qui occupe le bas.

  Piste : en paysage, la hauteur disponible entre l'en-tête (avatar + nom +
  bandeau de message épinglé + bandeau « Restaurez vos clés ») et l'insert du
  bas ne suffit plus. Sur la capture 2, le bandeau rayé passe **juste sous le
  bandeau de restauration des clés**, ce qui désigne cette zone — mais
  attention, le bandeau signale une **position**, pas forcément le widget
  fautif.

  **Diagnostic fait, correctif écrit puis annulé (2026-08-05).** L'`Expanded`
  de la colonne extérieure ne peut pas déborder : le dépassement vient
  forcément des enfants **non flexibles**, c'est-à-dire les bandeaux. En
  paysage clavier ouvert il reste ~150 dp sous l'en-tête, et le bandeau
  épinglé plus le rappel de restauration des clés dépassent à eux seuls cette
  hauteur. Ça explique les deux ampleurs : le panneau émojis est plus court
  que le clavier, donc 4 px au lieu de 17.

  Correctif retenu : envelopper la colonne extérieure de `conversation_screen`
  dans un `LayoutBuilder` — seul moyen fiable de connaître la hauteur
  restante, `MediaQuery.viewInsets` valant 0 dans un `body` de `Scaffold` — et
  escamoter le rappel de restauration sous ~220 dp. Le bandeau épinglé, lui,
  reste toujours visible : c'est sa raison d'être.

  ⚠️ **LE CORRECTIF EST DANS LE CODE, MAIS PAS SOUS SON PROPRE COMMIT.**

  Il a été livré le 2026-08-06 à l'intérieur de
  **`af3485b fix(groupes): garde « Officiel » appliquée, et le REVOKE qui n'y
  servait à rien`** — un commit dont le message ne dit pas un mot du
  débordement. Il y est arrivé emporté : la version était dans l'index quand
  ce commit a été fait, sur une branche partagée avec un autre agent.

  Donc : `git log` sur ce fichier **ne mènera pas** au débordement en paysage.
  C'est cette entrée qui fait le lien. Chercher `zoneCorps` ou
  `placeRappelCles` dans `conversation_screen.dart` pour trouver le code.

  **Deux choses à savoir en le relisant :**

  - *L'indentation est volontairement fausse.* Les ~424 enfants de la colonne
    gardent leur indentation d'origine. Les réindenter aurait réécrit des
    centaines de lignes en cours de modification par ailleurs, et rendu la
    fusion ingérable ; sans réindentation, le correctif ne touche que trois
    lignes (1229, 1289, 1653), toutes hors des zones modifiées. **À passer au
    formateur quand le fichier sera libre** — le fichier n'est de toute façon
    pas conforme à `dart format`, même avant ce changement.
  - *Un correctif voisin existe peut-être.* Un « zone BORNEE » qui borne le
    composeur, et non les bandeaux, était en cours à côté. S'il a atterri
    depuis, une partie du symptôme a pu disparaître autrement.

### ⚠️ Vérifié sur appareil le 2026-08-06 — le correctif marche, il ne suffit pas

Build de HEAD installé sur SM A515F, conversation « Salim L. » (bandeau des
clés actif, brouillon de 3 lignes), rotation forcée en paysage.

| Situation | Bandeau des clés | Débordement |
|---|---|---|
| Paysage, **sans** clavier | visible | aucun |
| Paysage, **clavier levé** | **escamoté** ✅ | **`BOTTOM OVERFLOWED BY 73 PIXELS`** ❌ |

**Ce qui est prouvé** : le mécanisme fonctionne. `placeRappelCles` bascule
bien à faux quand la hauteur tombe — le bandeau est visible sans clavier,
escamoté avec. Le `LayoutBuilder` mesure ce qu'il faut.

**Ce qui est infirmé** : mon diagnostic était **incomplet**. Je pensais que
les deux bandeaux étaient la seule cause. Une fois le rappel des clés retiré,
c'est le **composeur** qui déborde à son tour — et de bien plus : 73 px ici,
contre 17 px avant correctif. L'ampleur suit la longueur du brouillon, ce qui
désigne le composeur sans ambiguïté.

**Ce qui manque donc** : borner le composeur, c'est-à-dire exactement ce que
vise le correctif « zone BORNEE » — qui n'était PAS dans ce build, puisque
j'ai construit HEAD et qu'il vivait encore dans un WIP non committé. Les deux
correctifs sont complémentaires, pas redondants : le mien retire les bandeaux
de l'équation, l'autre empêche le composeur de prendre sa taille naturelle.

**Pourquoi le reste ne peut PAS se corriger dans le composeur** (vérifié le
2026-08-06, pour éviter que quelqu'un le retente) : `message_input.dart` sait
déjà se rétrécir — `maxLignes = (borne / 2 / 22).floor().clamp(1, 6)`, et ses
panneaux passent en `Flexible`. Mais tout est conditionné à `borne.isFinite`,
et personne ne le borne : `RenderFlex` donne `maxHeight: Infinity` à ses
enfants non flexibles. Le garde-fou dort donc en production, ce que le
fichier documente lui-même.

Le calculer depuis la fenêtre plutôt que depuis les contraintes ne suffit
pas : on obtient ~194 dp en paysage clavier levé, donc 4 lignes autorisées,
alors que le brouillon qui déborde en fait 3. Ce qu'il faut, c'est la hauteur
restante **sous les bandeaux** — seul le parent la connaît. D'où la
conclusion, déjà écrite dans `message_input.dart` : le correctif appartient à
`conversation_screen`, pas au composeur.

- [ ] **Refaire ce test une fois « zone BORNEE » committé** — c'est la
  combinaison des deux qu'il faut mesurer, pas l'un ou l'autre.
- [ ] **Cas du panneau GIF/Émojis** (le 4 px d'origine) : non testé ici, le
  clavier ayant suffi à montrer que le problème subsistait.
- [ ] Si le débordement persiste même avec les deux, chercher plus bas : le
  bandeau épinglé et l'en-tête ne sont pas escamotables, et en paysage
  clavier levé il ne reste qu'une centaine de dp au total.

  Non lié aux correctifs de localisation de cette session.

---

## Blocage, sens inverse — RLS prouvée en base (2026-08-06)

Le sens « qui m'a bloqué » n'a jamais fonctionné : `blockUser` écrit bien
`blockedByUserIds` sur la cible, mais dans Firestore, alors que les profils
viennent de Supabase où `_mapProfile` code ce champ en dur à `[]`. Et les dix
sites de lecture testaient en plus la **mauvaise direction** — sauf
`conversation_screen`, seul à avoir le bon sens.

La politique RLS était le vrai verrou : `blocked_users_own` en `ALL` sur
`firebase_uid() = blocker_id` ne laissait lire que les lignes où l'on est le
**bloqueur**. La recherche inverse échouait **en silence** — requête réussie,
zéro ligne. Corrigé par la migration `20260806120000`.

✅ **Prouvé en base**, en simulant les trois identités via
`request.jwt.claims` (ce que lit `firebase_uid()`), chaque essai dans une
transaction annulée :

| Qui interroge | Lignes vues | Attendu |
|---|:--:|---|
| La personne **bloquée** (Sim A) | **1** | le sens qui était cassé |
| Un **tiers** quelconque | **0** | contrôle négatif |
| Le **bloqueur** (Salim L.) | **1** | le sens qui marchait déjà |

Sans le contrôle négatif, le premier résultat n'aurait rien voulu dire : une
politique trop permissive aurait donné 1 aussi. Table laissée à zéro ligne.

✅ **La livraison temps réel jusqu'à l'UI est vue à l'écran** (2026-08-06).
Blocage inséré en base pendant que la conversation était ouverte : quelques
secondes plus tard, la ligne « Vu il y a 4 heures » avait **disparu** de
l'en-tête. C'est `online_status_indicator` qui a réagi au provider. La chaîne
`blocked_users` → realtime → `usersWhoBlockedMeProvider` → UI fonctionne.
Blocage retiré aussitôt, table revenue à zéro ligne.

⚠️ **Correction d'une description fausse écrite plus haut dans ce fichier.**
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
  *Deux tentatives ont échoué non sur le code mais sur l'appareil : l'app est
  passée en arrière-plan au moment du tap. Aucun plantage — process vivant,
  ni `FATAL`, ni exception Dart, ni mise à mort `lmkd`.*
- [ ] **Vérifier aussi la carte, l'accueil et les notifications** sous
  blocage : la personne doit disparaître des quatre.
- [ ] **Débloquer** et vérifier que tout revient — la table est publiée en
  realtime avec `REPLICA IDENTITY FULL` précisément pour que la suppression
  soit livrée ; sans ça le déblocage n'aurait pris effet qu'au relancement.

---

## Podcasts — 5 écrans passés au système DN (2026-08-04)

`lib/design_v2/` a été supprimé. Avant de le retirer, cinq écrans podcasts
y portaient une migration vers le système de couleurs DN qui n'avait jamais
été rebasculée, et qui n'était visible nulle part (fichiers orphelins, hors
galerie). Ils ont été repris dans `features/podcasts/presentation/screens/`.

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

**Écart volontaire par rapport à la copie `design_v2`** : elle figeait deux
couleurs sur `DNColors.terra` (constante `0xFFC85A3A`), là où `features/`
suivait `colorScheme.primary`. La version adaptative a été conservée — le
terracotta en dur aurait cassé l'accent choisi par le compte. Si la maquette
veut vraiment du terracotta fixe à ces deux endroits, c'est à rétablir
explicitement (fiche podcast ligne 368, statistiques ligne 388).

---

## Carte — délai d'affichage des membres autour (2026-08-04)

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

⚠️ **Pourquoi « 0 membres autour » sur le compte de test, et ce n'est pas un
bug de code.** Relevé le 2026-08-05 : seuls **deux** comptes partagent leur
position, et un seul est exploitable.

| Compte | `share_location` | Position |
|---|---|---|
| Sim A (`vQZE49dT…`) | `true` | 45.58028 / −73.64590 |
| Salim L. (`U64HKfrj…`) | `true` *(mis à `true` en SQL le 2026-08-05 ; était `false`)* | 45.58028 / −73.64599 |

Les deux comptes sont à ~10 m l'un de l'autre. `getNearbyProfiles` filtre sur
`.eq('share_location', true)` : « Salim L. » était écarté à la source, et
« Sim A » est retiré par l'auto-exclusion — il ne restait personne.

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

### État préparé le 2026-08-05 (défait depuis, voir ci-dessus)

Le compte « Salim L. » a été **maquillé en membre voisin présent**, en SQL,
pour pouvoir tester avec un seul téléphone. Vérifié : il passe la requête de
proximité **et** le filtre de présence, à **1,97 km** du compte principal.

## Réglages/Carte — deux interrupteurs de partage de position désynchronisés (2026-08-13)

Signalé : « j'arrive pas à localiser certains users ». Diagnostic en base
(projet Supabase lié `Diapo Niger`) : sur 10 comptes, seuls 2 avaient
`share_location = true`, et un seul de ceux-là avait une position (l'autre,
« Ibrahim Yacouba Maïdaoua », avait activé « Ma localisation » dans Réglages
sans jamais avoir ouvert la carte pour activer son calque « Membres » — le
seul chemin qui déclenchait `LocationPublisherService`).

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

- [ ] Activer « Ma localisation » dans Réglages **sans jamais ouvrir la
  carte** : vérifier en base que `latitude`/`longitude`/`location_updated_at`
  se peuplent dans les secondes qui suivent (permission GPS déjà accordée).
- [ ] Désactiver « Ma localisation » dans Réglages, app au premier plan :
  vérifier que `location_updated_at` cesse d'avancer (pas de battement de
  cœur résiduel).
- [ ] Mettre l'app en arrière-plan puis la ressortir plusieurs fois de suite
  (volet de notifications, `inactive` transitoire) avec le partage désactivé :
  vérifier dans les logs qu'aucune requête profil réseau superflue n'est
  déclenchée à chaque aller-retour (le garde `_positionSubscription != null`
  doit court-circuiter).
- [ ] Compte préexistant en base avec `share_location = true` mais sans
  position (reproduire l'état d'Ibrahim) : relancer l'app et vérifier
  l'auto-guérison, sans toucher à aucun réglage.

## Onboarding — les drapeaux lisaient Firestore au lieu de Supabase (2026-08-13)

Repéré en corrigeant le point ci-dessus : `hasSeenOnboarding`,
`hasSeenCoachMarks`, `hasGivenConsent`, `hasCompletedProfileConfig`
(`OnboardingRemoteDataSourceImpl`) lisaient/écrivaient `users/{uid}` sur
**Cloud Firestore** — un reliquat pré-Supabase que rien d'autre dans l'app ne
touche. L'étage « serveur » de l'onboarding ne servait donc à rien : seul le
drapeau local (`OnboardingLocalDataSourceImpl`, effacé à chaque
réinstallation) faisait foi, d'où l'assistant de configuration de profil qui
revient à chaque réinstall même quand le profil réel est déjà complet.

Corrigé : `OnboardingRemoteDataSourceImpl` lit/écrit maintenant les colonnes
`has_seen_onboarding` / `has_seen_coach_marks` / `has_given_consent` /
`consent_date` / `profile_config_complete` sur `public.users` (Supabase) — ces
colonnes existaient déjà en production, jamais suivies en migration
(`20260813235500_document_onboarding_flags_drift.sql` corrige la dérive).

**Non vérifiable par `flutter analyze`/`flutter test` seuls** — nécessite un
vrai cycle désinstall/réinstall :

- [ ] Compte avec profil déjà complété : désinstaller puis réinstaller l'app
  (signature identique, sinon `INSTALL_FAILED_UPDATE_INCOMPATIBLE`) →
  l'assistant de configuration de profil en 4 étapes ne doit **pas**
  réapparaître, puisque `profile_config_complete = true` est lu depuis
  Supabase dès la case locale absente.
- [ ] Même vérification pour l'écran de consentement (`hasGivenConsent`) et
  les coach marks.

| Colonne | Valeur d'origine | Valeur posée |
|---|---|---|
| `share_location` | `false` | `true` |
| `latitude` | `45.5802795` | `45.5980` |
| `longitude` | `-73.6459928` | `-73.6459` |
| `location_updated_at` | `2026-08-04 18:32:45.536012+00` | `2026-08-05 22:53:53+00` |
| `is_online` | `false` | `true` |
| `last_seen_at` | — | `2026-08-05 22:55:06+00` |
| `show_online_status` | — | `true` |

⏳ **La présence tient une heure**, via la seconde porte du filtre
(`is_online` + `last_seen_at` de moins d'une heure). Passé ce délai, rejouer
`update users set last_seen_at = now() where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';`
La première porte (`location_updated_at` < 5 min) est trop courte pour un
test manuel.

✅ **La carte a été ouverte et elle fonctionne** (2026-08-05, SM A515F,
capture `09_carte_t7`). Sept secondes après le tap sur l'onglet Carte :
tuiles en style nocturne, marqueur rouge « vous êtes ici », **pin « SL » à
initiales avec pastille verte**, panneau « **1 membre autour · 50 km** »
(« À l'instant / À l'instant »), et la ligne « Salim L. — 2,0 km · en ligne ».
Toute la chaîne passe : requête → filtre de présence → génération des pins →
liste. La distance affichée (2,0 km) correspond au calcul serveur (1,97 km).

⚠️ **Correction** : une note antérieure affirmait que « Membres à proximité »
était désactivé sur le compte principal, déduit de la ligne « Activer la
carte des membres » de l'accueil. **C'est faux** — cette ligne est un élément
de la liste d'amorçage « Pour commencer », pas l'état du réglage. La preuve
que la préférence est à `true` : `LocationPublisherService.start()` et
`_publish()` sortent tous deux immédiatement quand elle est fausse, or la
position du compte principal est réécrite toutes les deux minutes.

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

✅ **Préconditions serveur du temps réel vérifiées au distant** (2026-08-05,
`supabase db query --linked` — pas le fichier de migration, la base réelle) :

| Contrôle | Résultat |
|---|---|
| `users` dans la publication `supabase_realtime` | ✅ présente |
| `pg_class.relreplident` sur `users` | ✅ `f` (FULL) |
| Politique RLS SELECT | `((NOT is_private) OR is_admin() OR (firebase_uid() = id))` |

La politique laisse lire **toute ligne non privée**, donc le canal livrera
bien les `UPDATE` des *autres* membres — et pas seulement les siens, ce qui
aurait tué la fonctionnalité en silence. Confirmé de fait : la carte a
affiché « Salim L. », donc sa ligne passe cette politique, et le realtime
applique exactement la même.

Il ne reste donc à prouver que le **bout client** : que le pin bouge sans
attendre le sondage.

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

- [ ] **Sortie de rayon, confirmation visuelle** (facultatif) : si l'occasion
  se présente — téléphone franchement au repos, carte ouverte — refaire le
  protocole en une seule commande. Ne pas y consacrer d'effort dédié : le
  rapport entre le coût et ce qui reste inconnu ne le justifie plus.
  ⏸️ **Cinq tentatives, aucune concluante (2026-08-05).** À chaque fois le
  déplacement SQL est parti, mais l'écran avait changé avant la capture :
  conversation, Réglages, écran de démarrage après un redémarrage de l'app,
  Notifications. La cause n'est pas le correctif — c'est que le téléphone
  était utilisé, et qu'un build debug avec Google Maps se fait tuer par
  `lmkd` (215 Mo libres sur 5,7 Go relevés pendant la session).

  **Ne pas se contenter de relancer le même protocole.** Deux voies plus
  sûres : soit un moment où le téléphone est franchement au repos, carte
  ouverte, en enchaînant `UPDATE` et `screencap` dans **une seule** commande
  (en deux appels séparés l'écart monte à ~23 s et ne prouve plus rien) ;
  soit un test Dart sur la branche `!keep` de `_onMemberLocationUpdate`, ce
  qui suppose d'extraire la décision `keep` dans une fonction testable —
  aujourd'hui elle lit `ref` et `FirebaseAuth`.

  C'est la seule branche du temps réel non vérifiée : celle qui **retire**
  une ligne. L'ajout et la mise à jour sont prouvés (voir ci-dessus).
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

---

## Zone de saisie des messages — barre multi-ligne (2026-08-04)

`lib/features/messages/presentation/widgets/message_input.dart`. Le champ
passait de `maxLines: 1` à `minLines: 1 / maxLines: 6`, plus trois correctifs
d'état et un alignement de couleurs. Le composer sert les **trois** cas depuis
le même écran (1-à-1, groupe, « Mes notes ») : tester au moins deux d'entre eux.
`flutter analyze` et les 7 tests de `message_input_composer_test.dart` passent.

**Passe appareil du 2026-08-04 (23:29 → 23:37), SM A515F, APK debug `6498773`,
thème sombre, font_scale 1.1, conversation « Mes notes ».** ⚠ Une session
concurrente a réinstallé l'app à **23:38:08** (`Killing … due to
installPackageLI`) : tout constat postérieur à cette heure a été jeté.

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
- [ ] **Brouillon tapé puis sortie immédiate** : taper quelques caractères et
  quitter l'écran **en moins d'une demi-seconde**. Au retour, le texte complet
  doit être là (la fin était perdue jusqu'ici). Non testé sur appareil — couvert
  seulement par un test unitaire. Deux tentatives abandonnées (voir plus bas).
- [x] **Compteur de caractères** — vérifié sur la seconde passe (2026-08-05,
  00:55 → 00:59, APK debug installé à 23:55:57). Pastille « 204 / 2000 » puis
  « 224 / 2000 » en bas à droite **dans** la pilule, sur le fond neutre
  `surfaceVariant`, la barre étant à son plafond de 6 lignes. Reste à voir
  l'orange (sous 100 restants) et le rouge (à 2000), non atteints.
- [x] **La barre redescend** : en effaçant, elle repasse de 6 lignes à 1 sans
  saut ni scintillement.

⚠ **Deux passes perdues, même cause : l'appareil n'était pas à moi seul.**
Une session concurrente a réinstallé l'app à 23:38:08 en plein test, puis
quelqu'un a utilisé le téléphone au doigt vers 00:19 (message « test pour
verifier 9c et 9d » envoyé dans Mes notes). S'ajoute un redémarrage du process
à 23:59:49 **sans crash** — pas de `FATAL EXCEPTION`, pas d'ANR, mais une
cascade de reclaim mémoire dans la même minute (Facebook, Samsung Pass, Play
Store, keychain tués aussi). C'est la pression mémoire du A51 déjà documentée.
Réflexe confirmé : relever `lastUpdateTime` **et** l'heure des captures avant
de conclure quoi que ce soit.
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

---

## Discussion — l'horodatage sort de la bulle (fiches 4a/6b, 2026-08-05)

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
- [ ] **Une heure par grappe** : trois messages consécutifs du même expéditeur
  ne doivent afficher qu'un seul horodatage, sous le dernier.
- [ ] **Chaque famille de bulle** : texte, note vocale (elle en a une pour la
  première fois), photo, photo floutée en mode ÉCO, vidéo, document, sticker,
  position, message transféré, message cité.
- [x] **Accusé de réception en toutes lettres** (vu 2026-08-05, SM A515F, nocturne) : « 22:15 · Envoyé » et
  « 12:06 · Envoyé » lus a l ecran, coches et pastille bleue disparues.
  Restent a voir « Reçu », « Lu » et « Vu par N » — il faut un second
  appareil. Ancien libelle :
  « · Reçu », puis « · Lu » (bleu) — et « · Vu par N » en groupe. Les trois
  coches cerclées et la pastille bleue ont disparu. Vérifier surtout que la
  ligne ne devient pas trop longue sur un message court à font_scale 1.1 : le
  libellé est nettement plus large qu'une coche de 18 px.
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

---

## Discussion — ÉCO rejoint la ligne épinglée (fiche 6b, 2026-08-05)

La sous-barre « Médias · ÉCO » sous le bandeau épinglé a disparu : la fiche 6b
pose la pastille ÉCO **à droite du bandeau**, sur la même ligne. Le raccourci
« Médias » n'est pas perdu, il est passé dans le menu ⋮ sous le libellé
« Médias partagés » (`sharedMedia`, clé déjà existante).

- [x] **Avec une épingle** (vu 2026-08-05, SM A515F, nocturne) : le bandeau « Message épinglé 1 · 1/3 » et la
  pastille « ⊕ ÉCO » tiennent bien sur une seule ligne, sans sous-barre.
  Reste a verifier avec un titre long :
  seule ligne, le bandeau prenant la place qui reste. Vérifier qu'un titre long
  s'ellipse au lieu de pousser la pastille hors de l'écran.
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

---

## Composeur — l'emoji est sorti du champ, puis y est revenu (2026-08-05)

**Décision arrêtée : l'emoji reste DANS la pilule.** L'argument de largeur est
retenu — en pastille autonome il coûtait 52 dp et faisait tomber la pilule à
55 % de la largeur de l'écran, contre ~73 % à l'intérieur. Layout retenu :
`[ + ]  [ champ … 🙂 ]  [ micro / envoi ]`. Le test et l'en-tête de
`message_input_composer_test.dart` disent maintenant la même chose que le code.

Ce qui suit décrit la tentative « pastille autonome » (fiche 26b), conservée
pour mémoire :

Le smiley était un `suffixIcon` dans la pilule ; la fiche 26b le pose en
pastille ronde à part, fond `#F7E9DE`, glyphe `#B85E24`. Le composeur comptait
désormais quatre commandes : `[ + ] [ champ ] [ 🙂 ] [ micro / envoi ]`.

- [ ] ⚠ **Non-régression prioritaire — gestes vocaux.** Une commande de plus
  dans la ligne : revérifier appui long → enregistrement, glisser à gauche →
  annulation, glisser vers le haut → verrouillage. La pastille emoji
  **disparaît** pendant l'enregistrement, vérifier que ça ne décale rien.
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

## Composeur — largeur de la pilule et « + » en clair (2026-08-05)

Deux retours de Salim sur le rendu, traités et vérifiés sur appareil (SM A515F,
APK `48ede47` puis le suivant, conversation « Salim L. » avec toute sa chrome,
champ à 6 lignes). Mesures au banc sur gabarit A51 (393 dp).

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
- [ ] ⚠ **Cause racine à trancher — `EnsureSelfNotesNotifier.ensure()`**
  (`message_provider.dart`, vers la ligne 1550) renvoie la conversation « Mes
  notes » trouvée dans la liste en cache **sans vérifier que son document
  existe encore**, et saute `getOrCreateSelfConversation`. Le commentaire assume
  le raccourci (« éviter un aller-retour »). Tant que la liste et le document
  sont d'accord ça tient ; dès qu'ils divergent, « Mes notes » s'ouvre sur un
  document fantôme et **tout envoi échoue**. Supprimer le raccourci coûte une
  requête par ouverture : arbitrage à faire.
- [ ] ⚠ **Débordement en paysage** trouvé le 2026-08-06 : conversation avec
  toute sa chrome (bandeau épinglé + bandeau de clés), clavier levé, appareil
  en paysage → « BOTTOM OVERFLOWED BY 17 PIXELS », et le composeur passe sous
  la ligne de flottaison. Le portrait est sain. Rien dans logcat, comme toujours
  (Crashlytics remplace `FlutterError.onError`) : seule la bannière rayée le
  prouve. Piste : la chrome fixe de la conversation n'est pas repliable, et en
  paysage il ne reste presque rien après le clavier.
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
- [ ] **Observation à part** : « Mes notes » affiche maintenant « Aucun
  message » et un bandeau **« Ce groupe a été supprimé »** à la place du
  composeur. Sans rapport avec les gestes vocaux (rien n'a été supprimé pendant
  la passe) — vraisemblablement le ménage des données de test. À vérifier : une
  auto-conversation ne devrait pas pouvoir tomber dans l'état « supprimé ».
- [ ] **font_scale 1.1 avec un texte réel** : les mesures ci-dessus sont à
  l'échelle 1.0 du banc. Vérifier qu'un vrai message long garde une largeur
  confortable sur l'appareil.

---

## Panneau stickers / GIF / émojis (fiche 26b, 2026-08-05)

Refonte complète : onglets en **pilules Stickers · GIF · Émojis** (l'ordre est
inversé par rapport à avant) suivis d'une loupe, **sections à en-tête**
(RÉCEMMENT UTILISÉS · FAVORIS · un par pack) au lieu des sous-onglets iconiques
horloge/cœur/vignette, grille à tuiles carrées à fond visible, et la note
« téléchargés une fois » descendue **en pied**.

Couvert statiquement par `emoji_sticker_picker_layout_test.dart` (ordre des
pilules, sections, 4 colonnes à 390 dp, pied présent/absent, filtre, nocturne)
et `emoji_sticker_picker_landscape_test.dart` (pas d'overflow à 160/200/260).
Ce que les tests ne voient pas :

- [x] ⚠ **Le smiley du composeur ouvre bien les ÉMOJIS** (vu 2026-08-05, SM A515F, nocturne) — le piege de
  l index est evite. Detail :
  devenu « Stickers » : le code est passé d'un index à une énumération
  (`MessagePickerTab`) exprès pour ça, mais c'est le premier geste à refaire.
- [ ] **Défilement continu** sections + grille, clavier réellement ouvert, sur
  le A51 — c'est un seul `CustomScrollView` désormais.
- [x] **Ligne d'info en pied** (vu 2026-08-05) : « ⓘ Téléchargés une fois,
  envoyés sans données » est bien SOUS la grille, avec son filet, sur
  l'onglet GIF ; absente de l'onglet Émojis. L'en-tête « TENDANCES » en
  terracotta porte la bascule GIFs/Stickers.
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

---

## Messages épinglés — le bandeau n'était pas temps réel (2026-08-05)

`group_pinned_items` n'a jamais été ajoutée à la publication
`supabase_realtime` (contrairement à `messages` et `conversations`, vérifié sur
le projet distant « Diapo Niger »). Le `.stream()` de
`getPinnedItemsStream` ne faisait donc que son chargement initial : le
`ref.invalidate` de `conversation_screen` masquait le trou pour l'action faite
sur CE téléphone, mais rien d'autre n'arrivait jamais. Migration
`supabase/migrations/20260805120000_realtime_group_pinned_items.sql`
(publication + `replica identity full`, nécessaire pour que les DELETE passent
le filtre serveur `group_id`/`conversation_id`).

**Vérifié le 2026-08-05 sur SM A515F**, conversation 1-à-1
`883c9d96-fbab-42bd-8501-a7c49def0e91`, sans second téléphone : le rôle de
« l'autre appareil » est tenu par une écriture SQL directe sur
`group_pinned_items` pendant que l'écran reste ouvert et **non touché**.

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

Restent à voir (demandent un second appareil, ou un build à jour installé) :

- [ ] **Suppression pour tous d'un message épinglé** par B : l'épingle tombe en
  cascade, le bandeau de A doit se vider tout seul.
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
- [x] **Repli illisible corrigé** (2026-08-05) : dans ce cas le bandeau
  affichait « Message épinglé » **sous** le libellé « Message épinglé 1 », soit
  deux fois la même chose. Il dit maintenant « 🔐 Message chiffré ». À revoir à
  l'écran sur un build à jour.

Et sur un seul appareil, après le correctif de `group_pinned_banner.dart` (la
pastille était perdue avec la ligne quand l'épingle n'était pas résoluble).
**Non testables sur le build actuellement installé** — il date d'avant le
correctif, et le réinstaller viderait les données de l'appareil :

- [ ] **Une seule épingle orpheline** (message supprimé avant la cascade) : le
  bandeau ne s'affiche pas, mais la **pastille ÉCO doit rester** à droite.
- [ ] **Épingle de sondage / d'événement pendant le chargement** : la pastille
  ne doit pas clignoter hors de l'écran le temps du fetch.

Inventaire des épingles en base (2026-08-05) : 5 au total, toutes de type
`message`, aucune de sondage ni d'événement. Deux étaient orphelines — leur
`item_id` était un id **optimiste** `temp_<millis>` (message épinglé avant que
le serveur ne confirme l'envoi), donc irrésolvable à jamais. Les deux ont été
supprimées le 2026-08-05 ; il reste 3 épingles, 0 orpheline. `_pinMessage`
refuse désormais un id `temp_…` (à vérifier sur un build à jour) :

- [ ] **Épingler un message en cours d'envoi** (couper le réseau, envoyer, puis
  appui long → Épingler) : doit afficher « Attendez l'envoi du message pour
  l'épingler » et ne rien écrire en base. Vérifier ensuite qu'une fois le
  message parti, l'épinglage fonctionne normalement.

### Second système mort trouvé le 2026-08-14 : la ligne « Épinglés » de la fiche groupe

`_GroupInfoCard` (`group_detail_screen.dart`, fiche 9d — la carte Épinglés /
Médias / Prochaine rencontre) lisait `groupPinnedItemsProvider(group.id)`,
filtré sur `group_pinned_items.group_id`. Depuis le contournement du
2026-08-05 ci-dessus, plus rien n'écrit jamais cette colonne — `_pinMessage`
ne pose que `conversation_id`. La ligne « Épinglés » restait donc **en
permanence vide et invisible** (`pinned.isNotEmpty` toujours faux) sur tous
les groupes, y compris ceux où le bandeau de conversation affichait bien des
épingles juste au-dessus — deux lectures divergentes de la même table.

Corrigé : `_GroupInfoCard` lit maintenant `conversationPinnedItemsProvider`
via l'id de conversation du groupe (déjà résolu pour la ligne Médias juste en
dessous). `groupPinnedItemsProvider` et la branche `groupId` de
`GroupPinnedBanner` sont supprimés (plus aucun appelant ne les utilisait).
`flutter analyze` propre sur les 3 fichiers touchés.

- [x] **Vérifié sur SM A515F le 2026-08-14.** Dans « Groupe de test privé »
  (0 épingle au départ) : épinglage d'un message via Autres actions →
  Épingler → bandeau de conversation affiche bien « Message épinglé » (donc
  le contournement RLS conversation_id du 2026-08-05 tient toujours) ; retour
  à la fiche groupe → la ligne « Épinglés · 1 message » apparaît, compte
  correct. Avant ce correctif elle n'aurait jamais pu s'afficher, quel que
  soit l'état des épingles.
- [ ] Groupe sans rien d'épinglé : la ligne doit rester absente (comme avant)
  — pas revérifié isolément mais découle du même code que la ligne Médias.

### Troisième bug trouvé le 2026-08-14 : aucun ordre stable entre plusieurs épingles

`group_pinned_items.sort_order` vaut `0` par défaut en base (vérifié via
`information_schema.columns` sur le projet lié) et `pinItem` ne l'a jamais
renseigné à l'insertion. `getPinnedItemsStream` triait dessus
(`.order('sort_order')`) — un tri qui ne départage donc rien entre deux
épingles ou plus : Postgres ne garantit **aucun** ordre stable entre des
lignes à égalité. Or le bandeau se re-souscrit souvent en pratique (clavier,
`ensureAuthenticated`, `autoDispose` du provider) — l'ordre pouvait donc
changer d'une re-souscription à l'autre, et comme l'index affiché dans le
bandeau (`i/n`) pointe une **position** dans la liste et non un id, l'item
réellement montré pouvait sauter vers un autre sans la moindre action de
l'utilisateur.

Corrigé : tri désormais sur `pinned_at` (seule colonne unique/stable du lot),
dans `getPinnedItemsStream`. `flutter analyze` propre ; racine du bug
confirmée en base (`sort_order` = `0` sur toutes les lignes, vu par
`information_schema.columns`) — mais **non vérifié sur appareil**, faute
d'avoir pu poser une 2e épingle dans la même conversation le 2026-08-14 (le
SM A515F a cessé de répondre aux `input tap`/`input text` scriptés à mi-passe
— navigation qui ne bouge plus, `input text` qui n'atteint pas le composeur,
alors que `input keyevent KEYCODE_HOME` fonctionnait toujours : signe d'une
app bloquée sur un état précis plutôt que d'un appareil mort. Cause la plus
probable, jamais confirmée : usage concurrent du même téléphone physique par
l'autre agent/session — cf. `lastUpdateTime` qui avait déjà bougé sous mes
pieds en tout début de passe. Pas conclu à un bug applicatif sur cette seule
base, voir la règle du doigt réel dans `project_device_testing`.

- [ ] Épingler 2-3 messages dans une même conversation, rouvrir l'écran
  plusieurs fois (ou faire apparaître/disparaître le clavier plusieurs fois) :
  l'ordre `1/n`, `2/n`… doit rester identique à chaque fois (le plus ancien
  épinglé en premier). « Groupe de test privé » porte déjà 1 épingle
  (message « Message de test pour verifier 9c et 9d ») posée pendant cette
  passe — il suffit d'en épingler un second pour tester.

---

## Paysage — overflow quand le chrome dépasse la hauteur (2026-08-05)

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
  Voir la section suivante.

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

### Cause racine du 240 trouvée le 2026-08-05 : le garde-fou est inerte

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

## Groupes — défauts trouvés en vérifiant les épingles (2026-08-05)

Les deux premiers constatés sur SM A515F en cherchant à épingler dans un
groupe, tous deux hors du lot « épingles » ; le troisième trouvé en corrigeant
le second. **Les trois sont corrigés** (2026-08-05), aucun n'est vérifié sur
appareil.

**1. Chaque ouverture de la discussion de groupe crée une NOUVELLE
conversation.** ✅ **Corrigé le 2026-08-05** (code ; doublons déjà en base non
encore fusionnés — décision en attente). « Groupe de test prive »
(`yflqsRLMMhTPpiW0NFHx`) a trois lignes dans `conversations` : une du 05/08 à
04:13 (1 message), puis une à 22:14 et une à 22:21 — les deux créées en ouvrant
simplement la discussion pendant la session. Conséquence visible : l'écran
affiche « Aucun message » alors qu'un message existe bel et bien, dans une
conversation précédente. L'historique du groupe se fragmente à chaque entrée.

Cause : `MessageSupabaseDataSource.findGroupConversationByGroupId` rendait
`null` **sans chercher** dès que le `group_id` n'était pas un UUID. Ce
court-circuit protège l'appel de la RPC `join_group_conversation`, qui casse le
`group_id` en `uuid` (`22P02`) — mais il faisait croire à
`createGroupConversation` qu'aucune conversation n'existait, donc il en
insérait une neuve à chaque ouverture. Les groupes hérités de Firestore ont un
id de 20 caractères (`yflqsRLMMhTPpiW0NFHx`), pas un UUID : ils étaient les
seuls touchés — ce que la base confirme, les 3 groupes à id UUID ont exactement
une conversation chacun, le groupe hérité en avait trois.

**CORRIGÉ (2026-08-05), non vérifié sur appareil.** Cause :
`findGroupConversationByGroupId` (`message_supabase_datasource.dart`) faisait
`if (!_isUuid(groupId)) return null;` — un court-circuit posé pour éviter le
`22P02` de la RPC `join_group_conversation` (qui caste `p_group_id::uuid`)
sur les groupes hérités de Firestore, dont l'id fait 20 caractères. Mais il
rendait `null` **avant toute recherche**, et l'appelant
`createGroupConversation` enchaîne sur un INSERT : d'où une conversation de
plus à chaque ouverture, y compris pour le créateur déjà participant. Le
court-circuit ne saute plus que la RPC : `_findLegacyGroupConversation()`
cherche la conversation par `conversations.group_id`, colonne **TEXT** (vérifié
en base), et retient la plus ancienne — celle qui porte l'historique.

État de la base au moment du correctif : plus aucun doublon
(`group_id` avec `count(*) > 1` → 0 ligne), et il ne reste qu'une conversation
pour `yflqsRLMMhTPpiW0NFHx`, celle du 05/08 04:13 qui contient le message. Les
deux doublons de 22:14 et 22:21 ont donc été nettoyés entre-temps — le code
fautif, lui, était toujours en place.

**Limite assumée, non corrigée :** la policy SELECT de `conversations` est
`participant_ids @> [firebase_uid()]`. Un membre d'un groupe hérité qui n'est
pas encore dans `participant_ids` ne verra donc rien et déclenchera quand même
une recréation. La RPC `SECURITY DEFINER` règle ce cas pour les groupes
Supabase en vérifiant `group_members` ; pour un groupe hérité cette table est
vide (appartenance restée côté Firestore), et une RPC qui ajouterait l'appelant
sans pouvoir vérifier son appartenance ouvrirait n'importe quelle conversation
de groupe hérité à n'importe qui. À traiter avec la migration des groupes
hérités.

Le garde `_isUuid` n'existe qu'à cet endroit, vérifié sur tout `lib/` — pas
d'autre occurrence du même piège à corriger.

**Verrou base proposé, non appliqué** :
`supabase/migrations/20260806230000_conversations_une_par_groupe.sql` (index
unique partiel sur `group_id` pour `type='group'`). Le correctif applicatif
supprime la cause, mais trois chemins peuvent encore dupliquer : les **APK déjà
installés** tournent avec l'ancien code, deux appareils du même compte peuvent
ouvrir la discussion simultanément, et un futur chemin d'insertion pourrait
oublier la recherche. ⚠ Changement de comportement à peser : une insertion en
trop échouera au lieu de réussir en silence — donc « Erreur à l'ouverture de la
discussion » plutôt qu'un historique fragmenté. Cas limite documenté dans la
migration : un membre d'un groupe hérité absent de `participant_ids` passera
d'un doublon vide à une erreur franche.

- [ ] Ouvrir deux fois de suite la discussion d'un groupe **hérité** (id de 20
  caractères, ex. `yflqsRLMMhTPpiW0NFHx`) et compter les lignes
  `conversations` pour ce `group_id` : il ne doit s'en créer aucune de plus.
  ```
  supabase db query --linked "select id, created_at from conversations where group_id = 'yflqsRLMMhTPpiW0NFHx' order by created_at;"
  ```
- [ ] Les messages déjà envoyés doivent réapparaître (l'écran affichait
  « Aucun message »).
- [ ] Non-régression sur un groupe **Supabase** (vrai UUID) : la RPC doit
  toujours être empruntée, et un membre ayant rejoint après la création doit
  continuer à retrouver la conversation.

**Deuxième filet ajouté (2026-08-06) :** quand la RPC rend `NULL` sur un groupe
à id UUID — soit qu'aucune conversation n'existe, soit que l'appelant ne soit
pas encore dans `group_members` —, on retombe sur la même recherche directe au
lieu de rendre `null` sec. Le RLS la borne aux conversations dont on est déjà
participant : si l'appelant en est un, sa conversation est réutilisée au lieu
d'être doublée ; sinon rien ne change.

- [ ] Non-régression du filet : un groupe UUID dont l'appelant est participant
  de la conversation mais absent de `group_members` doit ouvrir la conversation
  existante, pas en créer une seconde.

**Doublons en base : plus rien à fusionner.** Les deux conversations
surnuméraires (22:14 et 22:21) ont disparu **pendant** la session d'analyse,
sans intervention de ma part — la suppression que j'avais préparée a été
bloquée avant exécution. Le compte final est propre : les 4 groupes ont
exactement 1 conversation chacun, et `yflqsRLMMhTPpiW0NFHx` garde celle du
04:13 avec son message. Une sauvegarde des 3 lignes d'origine a été prise avant
(scratchpad de session, `conversations_yflqs_avant_fusion.json`) — elle
disparaîtra avec la session, à récupérer maintenant si elle a de la valeur.

**Message disparu : très probablement un ménage manuel.** Le message de la
conversation 22:21 (envoyé à 22:22:34) était présent au début de l'analyse,
absent quelques minutes plus tard, avant toute suppression de conversation.
Rien dans le système ne peut faire ça tout seul, vérifié :

- `pg_cron` a 3 tâches, toutes des `http_post` vers des Edge Functions de
  rappels — aucune ne supprime de données.
- Aucun déclencheur sur `messages` ; sur `conversations`, seulement
  `update_updated_at`.
- Pas de messages éphémères dans l'app (les occurrences « ephemeral » sont les
  clés X3DH de l'E2EE, sans rapport).
- `deleteMessageForEveryone` et `deleteMessageForMe` sont des suppressions
  **douces** (`is_deleted`, `data.deletedForEveryone`) : la ligne reste, elle
  serait encore comptée.
- **Aucun `from('messages').delete()` dans tout le code** — l'app n'a pas de
  chemin pour supprimer physiquement un message.

Conclusion : la ligne a été retirée hors de l'app (éditeur SQL ou dashboard).
Si ce n'était pas toi, alors rouvrir le sujet — mais il n'y a pas de mécanisme
applicatif à incriminer.

- [ ] **Défaut trouvé au passage — « supprimer pour tout le monde » laisse les
  messages orphelins.** `MessageSupabaseDataSource.deleteConversation`
  (ligne ~1676) fait `from('conversations').delete()` avec le commentaire
  « Hard delete (cascade deletes messages) ». **Il n'y a pas de cascade** :
  `messages.conversation_id` n'a aucune clé étrangère vers `conversations`
  (seules `events` et `group_pinned_items` en ont une, en CASCADE). Chaque
  suppression de conversation « pour tout le monde » abandonne donc en base
  tous ses messages — invisibles, et chiffrés E2EE, donc jamais récupérables ni
  purgés. Zéro orphelin aujourd'hui (les messages du groupe de test avaient été
  retirés avant), mais la prochaine suppression réelle en créera.

  Migration écrite, **non appliquée** :
  `supabase/migrations/20260806220000_messages_conversation_fk_cascade.sql`
  (clé étrangère `on delete cascade`, dans le sens de ce que le code croyait
  déjà). Prérequis vérifié : 0 message orphelin, types compatibles (`text` des
  deux côtés), index `messages_conversation_idx` déjà en tête sur
  `conversation_id`. À appliquer avec :
  ```
  supabase db push --linked
  ```

**2. Un lien profond vers une conversation de groupe la rend en 1-à-1.**
`app_router.dart:873` lit `isGroup` uniquement dans `state.extra`, absent d'un
lien profond ou d'une notification : `isGroup` retombe à `false`. Ouvrir
`https://diasponiger.web.app/messages/<id d'une conversation de groupe>` donne
un en-tête « Utilisateur » avec boutons d'appel, et le bandeau épinglé
interroge `conversationPinnedItemsProvider` — qui ne renvoie jamais rien pour
un groupe. `ConversationScreen` ne reconcilie jamais ce drapeau avec
`conversation.groupId`, pourtant disponible.

**CORRIGÉ (2026-08-05), non vérifié sur appareil.** `ConversationScreen` ne se
fie plus au seul paramètre de construction : `_syncConversationIdentity()`,
appelé depuis `build()`, aligne l'état local sur la conversation chargée
(`conversation.isGroup || conversation.groupId != null`), et les ~80 sites qui
lisaient `widget.isGroup` / `widget.groupId` passent par les accesseurs
`_isGroup` / `_effectiveGroupId`. `widget.isGroup` reste prioritaire, la
réconciliation ne fait que passer `false → true`. Comme ce basculement
survient APRÈS `initState`, le travail d'ouverture réservé aux groupes
(effacement des mentions non lues, filtre des groupes privés) est rejoué par
`_runGroupOpenWork()`, idempotent via deux drapeaux. Le repli sur
`conversation?.groupId` qui existait déjà en trois endroits est absorbé par
`_effectiveGroupId`.

⚠️ **Le symptôme « bandeau épinglé vide » de la description ci-dessus n'est
plus d'actualité** : il a été réglé indépendamment, et mieux, par le correctif
« l'épingle est toujours portée par la conversation, groupe compris »
(`_pinMessage`) — les épingles ne dépendent plus du tout de `isGroup` ni de
`groupId`. Ce qui restait faux par lien profond, et que le présent correctif
traite, c'est l'en-tête, les boutons d'appel, le nom et le mini-avatar de
l'expéditeur, le badge « Admin », les permissions sondage/événement et le
menu ⋮.

Le second défaut (écran noir au retour) est corrigé dans la foulée :
`_leaveConversation()` (flèche de l'en-tête + refus de requête) et un
`PopScope` (geste/bouton retour système) retombent sur `/messages` quand
`context.canPop()` est faux.

> ### 🔴 Trouvé pendant la vérification appareil : `groupStreamProvider` lit encore FIRESTORE
>
> `groupRemoteDataSourceProvider` (`group_provider.dart:16`) rend
> `GroupRemoteDataSourceImpl`, bâti sur `FirebaseFirestore.instance` — alors
> qu'un `GroupSupabaseDataSource` existe, complet, mais **n'est câblé nulle
> part**. Conséquence : `groupStreamProvider` rend `null` pour tout groupe créé
> dans Supabase, et comme `groupStream` avale l'erreur
> (`fold((failure) => null)`), ça ne se voit jamais dans les logs.
>
> Symptôme observé : l'en-tête du groupe « Diaspora Niger — Canada » affichait
> « Groupe » (repli `l10n.group`), tandis que le groupe **hérité de Firestore**
> affichait bien son nom et son compte de membres — ce qui prouve la cause.
>
> Contourné ici en lisant `conversation.name` (la conversation porte le nom du
> groupe dans `data->>'name'`, vérifié en base) AVANT `groupData`. Mais tout ce
> qui dépend vraiment de l'entité groupe reste vide pour les groupes Supabase :
> **permissions** (`canPostEvents`/`canPostPolls`/`canPin`), **rôle
> admin/modérateur**, **liste des membres** pour les mentions, image du groupe.
>
> ### ⛔ AGGRAVATION mesurée le 2026-08-06 : la fiche d'un groupe Supabase ne
> ### s'ouvre PAS DU TOUT
>
> Ce n'est pas seulement « le nom manque dans l'en-tête ». Ouvrir
> `https://diasponiger.web.app/groups/03077217-24d5-4cfa-9ec6-ed5b593c3cd2`
> (groupe « Diaspora Niger — Canada », bien présent dans Supabase) donne un
> écran **« Erreur de chargement » + « Réessayer »**, et rien d'autre.
> Reproduit deux fois, après relance à froid.
>
> Comparaison qui isole la cause : la fiche du groupe **hérité de Firestore**
> (`yflqsRLMMhTPpiW0NFHx`) s'affiche parfaitement — nom, description, « 1
> membre », créateur, bouton « Ouvrir la discussion ».
>
> Donc pour TOUT groupe créé dans Supabase, sont inaccessibles : l'ouverture de
> la discussion depuis la fiche, la liste des membres, quitter le groupe, le
> partager, et les réglages de notification du groupe. Seul le passage par la
> liste des messages (ou un lien profond vers la conversation) fonctionne
> encore, grâce au repli sur `conversation.name` posé plus haut.
>
> ### ✅ BASCULÉ le 2026-08-06, et vérifié sur appareil
>
> `groupRemoteDataSourceProvider` rend désormais `GroupSupabaseDataSource`.
> Celui-ci implémentait déjà l'intégralité de l'interface (le projet n'aurait
> pas compilé sinon) — il n'était simplement câblé nulle part.
>
> Avant / après, mesuré :
> - fiche d'un groupe Supabase : « Erreur de chargement » → **s'ouvre**
>   (nom, visibilité, description, membres, créateur, partage, menu) ;
> - onglet « Mes groupes » : les groupes Supabase étaient **invisibles**
>   (« 1 rejoint », le seul groupe Firestore) → « 2 rejoints », les deux
>   groupes Supabase ;
> - `_joinGroup` vérifié sur « teste » : `group_members` 0 → 1 ;
> - `_leaveGroup` vérifié dans la foulée : 1 → 0 (état restauré). La boîte de
>   confirmation s'ouvre, ce qui prouve au passage que le correctif « bouton
>   mort » de ces deux méthodes fonctionne — elles n'étaient pas testables
>   jusqu'ici.
>
> - [x] **Migration des groupes hérités : PASSÉE le 2026-08-06.**
>   `yflqsRLMMhTPpiW0NFHx` → `2b24986f-08b5-4840-9931-dbe046ffb394`, avec sa
>   conversation (1), son message (1) et son membre (Sim A, rôle `admin`).
>   Contrôles : 0 conversation orpheline, garde-fou réactivé. Vérifié sur
>   appareil : « Groupe de test prive » réapparaît dans « Mes groupes », servi
>   cette fois par Supabase.
>
>   Deux corrections apportées au script AVANT de le lancer :
>   1. `select distinct … gen_random_uuid()` calculait l'uuid **par ligne** :
>      un groupe portant deux conversations aurait reçu deux identifiants
>      différents. Remplacé par un `GROUP BY` en amont.
>   2. Le réalignement se faisait par **nom** — deux groupes homonymes
>      l'auraient cassé. L'ancien identifiant est désormais conservé dans la
>      description (`[migré de <id>]`) et sert de clé de rapprochement.
>
>   Et un obstacle rencontré à l'exécution : le trigger
>   `enforce_group_creator_trigger` refuse tout insert sans `firebase_uid` dans
>   le JWT (il force `creator_id` depuis le jeton vérifié — c'est ce qui
>   empêche de créer un groupe au nom d'autrui). Une migration passe par un
>   rôle admin, sans JWT utilisateur. Il est donc désactivé **dans la
>   transaction** puis réactivé : `ALTER TABLE` étant transactionnel, un échec
>   le rétablit par ROLLBACK — aucune fenêtre sans garde-fou. Vérifié après
>   coup : `tgenabled = 'O'`.
> - [x] **`member_count` recalé** (`tools/recount_group_members.sql`). Il valait
>   0 alors que `group_members` avait des lignes : la fiche affichait
>   « Membres · 0 » tout en listant le créateur, et proposait « Rejoindre » à
>   quelqu'un déjà membre. Le trigger `group_members_count_trigger` existe mais
>   n'avait jamais rattrapé les lignes antérieures à sa création. Script
>   idempotent, contrôle à 0 ligne d'écart.
> - [x] ✅ **Le « décalage » 1 groupe vs 2 N'EXISTAIT PAS.** Instrumentation :
>   la RPC `get_my_groups` rendait bien **3 lignes**, et l'écran les affiche
>   toutes — « 3 rejoints ». Mes relevés précédents étaient pris **trop tôt**,
>   avant la fin d'un chargement asynchrone. Leçon : sur cet écran, lire l'état
>   APRÈS une capture d'écran qui montre la liste peuplée, pas au bout d'un
>   délai fixe.
> - [x] **Marqueur de migration retiré de la description.** La description est
>   affichée à l'utilisateur sous le nom du groupe : le
>   `[migré de yflqsRLMMhTPpiW0NFHx]` que le script y posait apparaissait en
>   clair dans la liste (constaté sur appareil). Il est désormais effacé en fin
>   de migration — il ne servait qu'au rapprochement interne.
> ### `country_code` : sources corrigées, données à normaliser (2026-08-06)
>
> Les DEUX tables mélangeaient codes ISO et libellés — `users.country_code`
> contenait `Niger` à côté de `NE`, `BF`, `CA` ; `groups.country_code` avait
> `Canada` à côté de `CA`. Toute comparaison d'égalité échouait donc en
> silence : filtre par pays de la liste des groupes, et
> `availableGroupCountriesProvider` qui dérive de cette colonne.
>
> **Les deux sources d'écriture sont corrigées** — la base ne se salira plus :
> - `profile_supabase_datasource` écrivait `currentCountry`, qui vient du
>   géocodage inverse sous forme de libellé (« Canada ») ;
> - `create_group_screen` écrivait un libellé de sa liste `_hostCountries`
>   codée en dur (« Niger », « États-Unis »…).
> Les deux passent maintenant par `CountryExtension.toIsoCode()`, qui a été
> ajouté. `Country.fromString` reconnaît désormais aussi le **libellé** (il ne
> comparait que le code et le nom d'énumération, donc aucun nom composé) et
> ignore accents et ponctuation — sans quoi « États-Unis » ne correspondait pas
> à `Etats-Unis`, et « Côte d'Ivoire » pas à `Cote d'Ivoire`.
>
> ⛔ **Trouvé en tentant la normalisation : DEUX groupes officiels pour le
> Canada.** « Diaspora Niger — Canada » (`Canada`, 16/07, 1 membre, 5 messages)
> et « Diaspora Niger — CA » (`CA`, 20/07, totalement vide). L'index unique
> partiel `uniq_official_group_per_country` aurait dû l'empêcher, mais les deux
> écritures différaient. C'est le MÊME enchaînement que le défaut n°1 :
> `ensureOfficialGroup` a cherché par `CA`, n'a pas trouvé le groupe rangé sous
> `Canada`, et en a créé un second.
>
> - [x] **Données normalisées le 2026-08-06.** Le script complet ayant été
>   refusé par le garde-fou de sécurité (son `UPDATE` conditionnel), les
>   opérations ont été passées une par une, en clair :
>   `groups.Canada→CA`, `groups.Niger→NE`, `users.Niger→NE`,
>   `users.''→NULL`, et déclassement du doublon.
>   **Contrôle : plus aucune valeur de plus de 2 caractères** dans les deux
>   tables. État final — un seul groupe officiel par pays :
>
>   | Groupe | code | officiel | membres |
>   |---|---|---|---|
>   | Diaspora Niger — Canada | `CA` | ✅ | 1 |
>   | Diaspora Niger — CA | `CA` | déclassé | 0 |
>   | teste | `NE` | — | 1 |
>   | Testeurs | `NE` | — | 1 |
>   | Groupe de test prive | `null` | — | 1 |
>
>   `tools/normalize_country_codes.sql` reste au dépôt : il est idempotent et
>   couvre bien plus de libellés que les trois rencontrés ici — il servira si
>   d'autres apparaissent.
>
> - [x] **Le repli du filtre est démontré par la donnée** (l'appareil est resté
>   débranché, mais ce cas se prouve sans lui). `availableGroupCountries` dérive
>   de `groups.country_code` : il vaut désormais `['CA', 'NE']` là où il valait
>   `['CA', 'Canada', 'Niger']`. Or `_loadDefaultCountryFilter` teste
>   `availableCountries.contains('NE')` — le test était donc **toujours faux**,
>   et le repli sur le Niger ne se déclenchait jamais. C'est mot pour mot ce
>   que le commentaire du code annonçait ; il est maintenant vrai.
>   Le profil de test a `country_code = null` (il portait `''`, sans effet : le
>   code testait déjà `!= null && isNotEmpty`), donc c'est bien la branche de
>   repli qui s'applique.
> - [x] **VÉRIFIÉ À L'ÉCRAN le 2026-08-06**, sur un APK construit depuis l'état
>   fusionné et poussé.
>   - Les puces de pays affichent « 🇨🇦 Canada » et « 🇳🇪 Niger » — drapeau et
>     libellé. C'est la preuve que les codes sont reconnus de bout en bout :
>     avec l'ancien mélange (`CA` / `Canada` / `Niger`), l'app ne pouvait pas
>     les convertir.
>   - Le filtre **discrimine** correctement : sur « Niger », le groupe `NE`
>     (« teste ») s'affiche ; sur « Canada », plus rien et le message
>     « Aucun groupe ne correspond à ces filtres » apparaît ; retour à « Tous »,
>     il revient.
>   - Le badge de « Diaspora Niger — Canada » affiche désormais `CA` et non
>     plus `Canada`.
>   - Le groupe migré est là, sa description est vide (marqueur `[migré de …]`
>     bien retiré), et le doublon supprimé n'apparaît plus nulle part.
> - [x] **La normalisation À L'ÉCRITURE est vérifiée de bout en bout** — par le
>   chemin normal de l'app, pas en SQL. Un groupe créé depuis « Créer un
>   groupe » avec le pays affiché « **Niger** » arrive en base avec
>   `country_code = '**NE**'`. Sans le correctif, la base aurait reçu le
>   libellé, comme les groupes « teste » et « Testeurs » créés avant. Le groupe
>   de test a été supprimé après contrôle.
> - [ ] Détail sans gravité relevé au passage : à l'ouverture, la puce active
>   est « Tous » et non « NE ». `_loadDefaultCountryFilter` lit
>   `availableGroupCountries` avant que les groupes ne soient chargés — la
>   liste est alors vide, donc aucune branche ne s'applique. Même famille que
>   les autres lectures trop précoces, mais ici le défaut est bénin : « Tous »
>   est un défaut raisonnable et le filtre reste utilisable.

> ### 🔴 `member_count` est incrémenté DEUX FOIS à la création d'un groupe
>
> Trouvé le 2026-08-06 en créant un groupe de test : `member_count = 2` pour un
> groupe qui n'a qu'une seule ligne dans `group_members` (son créateur).
>
> Deux mécanismes comptent le même membre :
> - la RPC `insert_group` pose un `member_count` initial dans la ligne
>   `groups` ;
> - le trigger `group_members_count_trigger` fait
>   `member_count = GREATEST(member_count + 1, 0)` à chaque INSERT dans
>   `group_members` — donc aussi pour le créateur que la RPC vient d'insérer.
>
> C'est l'autre face de l'incohérence déjà vue (« Membres · 0 » sur un groupe
> peuplé) : le compteur n'est jamais recalculé, il dérive dans les deux sens.
>
> En relisant la fonction, le défaut est double — et la seconde moitié était
> invisible : `RETURNING * INTO v_row` capture la ligne **avant** l'insertion du
> membre, donc avant que le trigger n'agisse. La fonction renvoyait `1` pendant
> que la base contenait `2`. L'écran de création affichait donc un troisième
> chiffre, différent des deux autres.
>
> - [x] **Migration écrite** :
>   `supabase/migrations/20260806150000_insert_group_member_count.sql`.
>   Elle pose `member_count = 0` (le trigger compte le créateur juste après) et
>   relit la ligne après l'insertion du membre. Signature, `SECURITY DEFINER`
>   et garde `firebase_uid` inchangés.
> - [x] **APPLIQUÉE le 2026-08-06** par `supabase db push --linked
>   --include-all`. Le drapeau était nécessaire — et sûr : `migration list`
>   montrait une seule migration en attente (celle-ci), mais son horodatage
>   (15:00) est antérieur à une migration déjà appliquée (17:00), ce que
>   Supabase refuse par défaut.
>
>   ⚠️ **Premier essai en échec, et l'erreur était juste** :
>   `cannot remove parameter defaults from existing function` (42P13). La
>   fonction en place a des valeurs par défaut sur neuf de ses dix paramètres ;
>   ma réécriture ne les reproduisait pas, ce qui aurait cassé tout appelant
>   omettant un paramètre. Relevées via `pg_get_function_arguments` et
>   réintégrées à l'identique. PostgreSQL a évité la régression.
>
> - [x] **Vérifié sur appareil** : un groupe créé depuis l'app sort avec
>   `member_count = 1` pour 1 membre réel — juste dès la création, sans
>   recompte. `country_code = NE` au passage, la normalisation tient. Groupe de
>   test supprimé.
> - [x] Contournement en place en attendant :
>   `tools/recount_group_members.sql`, idempotent, relancé après ce test. Tous
>   les groupes sont à leur compte réel.
> - [x] **Doublon supprimé** (2026-08-06, sur décision explicite de Salim).
>   `25463f01-a148-4304-8f35-a38e6d7efcfb` — « Diaspora Niger — CA », créé le
>   20/07 par la recherche qui échouait. Avant suppression, les **neuf** tables
>   portant un `group_id` ont été contrôlées, pas seulement les trois évidentes :
>   `conversations`, `e2ee_sender_key_distributions`, `events`,
>   `group_invites`, `group_members`, `group_pinned_items`, `group_requests`,
>   `post_polls`, `posts` — **toutes à 0**. La ligne a été relevée avant
>   l'ordre, elle figure dans l'historique de la session si besoin de la
>   recréer.
>
>   Inventaire final — 4 groupes, un seul officiel par pays :
>
>   | Groupe | code | officiel | membres |
>   |---|---|---|---|
>   | Diaspora Niger — Canada | `CA` | ✅ | 1 |
>   | teste | `NE` | — | 1 |
>   | Testeurs | `NE` | — | 1 |
>   | Groupe de test prive | `null` | — | 1 |

### VÉRIFIÉ SUR APPAREIL le 2026-08-05 (SM A515F, APK debug de cette branche)

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

Complément de vérification, 2026-08-06 :

- [x] **Menu ⋮ sur la conversation de groupe** → options de conversation
  (recherche, médias, sourdine, éphémères, archiver, fond, favoris, exporter,
  signaler) et **pas** l'option « Bloquer », qui est gardée par
  `!isGroup && otherUserId != null` dans `ConversationOptionsModal`. C'est la
  preuve que le drapeau est correct sur ce chemin.
- [x] **Flèche de l'en-tête depuis un lien profond** → ramène à la liste des
  messages, pas d'écran noir. Les trois sorties du retour sont donc couvertes
  (bouton système, flèche ; le geste de bord emprunte le même `PopScope`).

- [ ] Même conversation, ouverte par NOTIFICATION (`state.extra` également nul) :
  même en-tête. Non testé — pas de push déclenchable simplement depuis le poste.
- [ ] Nom de l'expéditeur + mini-avatar sur les messages REÇUS d'un tiers, et
  badge « Admin ». Non testé : les deux groupes de test n'ont qu'un membre, donc
  aucun message entrant. **Script SQL prêt** (`scratchpad/donnees_test.sql`) —
  l'écriture en base de production a été refusée par le garde-fou de sécurité,
  elle doit être lancée à la main.
- [ ] Épingler puis détacher un message depuis ce chemin.
- ⛔ **Menu « + » du composer (sondage / événement) : NON TESTABLE en l'état.**
  `canCreateEvent` et `canCreatePoll` dérivent de `groupData?.permissions`,
  donc de `groupStreamProvider` — câblé sur Firestore. Pour un groupe Supabase
  `groupData` est null, les deux sont donc `false` par construction. Cette case
  ne pourra être vérifiée qu'après le basculement du datasource des groupes.
- ⛔ **Bouton « Ouvrir la discussion » sur un groupe Supabase : NON TESTABLE.**
  On ne peut même pas atteindre le bouton — la fiche du groupe affiche
  « Erreur de chargement » (voir l'encadré Firestore plus haut).
- [x] **Recréation par le VRAI chemin — PROUVÉ le 2026-08-05.** Le lien profond
  ouvre la conversation par son id et ne passe PAS par
  `createGroupConversation` ; le compte inchangé ne prouvait donc rien. Refait
  par le vrai chemin (fiche du groupe → « Ouvrir la discussion »), **deux fois
  de suite** sur `yflqsRLMMhTPpiW0NFHx` : la même conversation se rouvre avec
  son historique, `count(*)` = 8 avant / 8 après, groupe hérité 1 / 1.

  ⚠️ Ce test a d'abord été **impossible** : le bouton « Ouvrir la discussion »
  était MORT (voir ci-dessous).

**4. « Ouvrir la discussion » était un bouton mort** (défaut pré-existant,
trouvé en voulant prouver le n°1, corrigé le 2026-08-05).
`ConversationNotifier.createGroup` lisait
`_ref.read(currentUserAsyncProvider).valueOrNull` — or c'est un StreamProvider
**autoDispose** que cet appel ne regarde jamais : la lecture démarrait
l'abonnement à l'instant du tap et rendait `AsyncLoading`, donc `null`, d'où un
`return null` **avant même** de toucher au dépôt. Comme `state` n'était jamais
mis en erreur, l'écran affichait « Erreur lors de l'ouverture de la
discussion » *sans la moindre cause*, et rien ne sortait dans logcat.
Exactement le piège déjà rencontré et commenté dans `_createGroup` de
`create_group_screen.dart`. Correctif : `await read(...future)` + une vraie
erreur dans `state`.

- [x] Vérifié sur appareil : le bouton ouvre bien la discussion, deux fois de
  suite, sur le groupe hérité.
- [ ] Refaire sur un groupe **Supabase** (`03077217-…`), non testé.
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
- [ ] Non testés faute de jeu de données ou de droits : les 6 `_save` de
  l'admin (compte admin requis), bloquer/débloquer, join/leave de groupe,
  galerie média, appels de groupe, salons audio.
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

- [x] **Un seul vrai défaut trouvé, corrigé** :
  `profile_config_screen._handleComplete` levait `Exception(_kProfileMissing)`
  quand le cache était vide, donc **l'enregistrement du profil échouait au
  premier essai** sur « Profil introuvable » ; il fallait toucher
  « Réessayer », le second essai trouvant le cache chaud. Le profil est
  maintenant chargé depuis le dépôt avant d'abandonner.
  - [ ] À vérifier sur appareil : reprendre l'assistant de configuration de
    profil et enregistrer du premier coup, sans passer par « Réessayer ».

- [ ] Ce filon est donc **épuisé pour l'essentiel**. Ce qui reste
  (`monetization_provider` ×11, sans aucun abandon silencieux ; les 4 méthodes
  non `async` laissées volontairement ; les 2 de `call_provider`) n'a pas
  d'impact utilisateur démontré. Ne pas y retourner sans un défaut constaté.
  ⚠️ `call_provider` (2) reste délibérément intact : `initiateCall` **pose**
  une erreur (« Utilisateur non connecté ») donc n'est pas silencieux, et son
  `build()` amorce l'abonnement via `_cleanupStaleCalls()` bien avant qu'on
  puisse taper « appeler ». Le vérifier demande de passer un vrai appel.

> Note d'exécution : un ANR (« Diaspo Niger ne répond pas ») a été observé UNE
> fois juste après une installation à chaud par-dessus l'app en cours
> d'exécution, sur ce même écran. Non reproduit après `force-stop` puis
> relance — le mute a alors fonctionné du premier coup. Probablement un artefact
> de la réinstallation à chaud (la 6e de la session), pas du correctif ; à
> resurveiller quand même.

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

---

## Le « OVERFLOWED BY 190 » de la recherche venait du rail latéral (2026-08-05)

Le bandeau rayé se voit **depuis** l'écran de recherche de la messagerie, mais
le `RenderFlex` fautif est au-dessus de cet écran dans l'arbre : c'est
`TabletNavigationRail` (`lib/shared/widgets/tablet_navigation_rail.dart`).

La chaîne :

1. `MainShell` bascule sur le layout « tablette » dès **700 dp de large**
   (`_kTabletBreakpoint`). Un SM A515F en paysage fait `2400 / 2.625 = 914 dp`
   de large pour seulement **411 dp de haut** : le téléphone en paysage passe
   donc par le rail latéral, pas par la barre du bas.
2. Le rail est une `Column` de cinq items à hauteur intrinsèque (~68 dp
   chacun, **~352 dp** au total), sans défilement, premier enfant d'une `Row` :
   il est borné par la hauteur du corps.
3. `resizeToAvoidBottomInset` (défaut) réduit le corps à ~170 dp quand le
   clavier monte. `352 − 170 ≈ 190`. Le clavier ne monte sur cet écran qu'en
   mode recherche — d'où la corrélation trompeuse avec la recherche.

Pourquoi le bandeau paraît « au milieu, à gauche » : pour un débordement en
bas, Flutter dessine l'étiquette au centre horizontal du widget fautif (le
rail : 43 dp) et à mi-hauteur de la zone débordée. Ça tombe sur le bord gauche,
à hauteur de la zone de résultats — d'où la fausse piste.

**Correctif** : le rail défile (`SingleChildScrollView` + `mainAxisSize.min`)
au lieu de forcer sa hauteur. Tant qu'il y a la place, rien ne change à
l'écran (les items étaient déjà alignés en haut).

**La colonne de l'écran de recherche n'a pas été touchée** : en mode recherche
elle n'a que ~65 dp d'incompressible (l'en-tête et les puces de filtre sont
retirés, la zone de résultats est déjà `Expanded` + `ListView`). Elle ne peut
pas produire 190. Et ses deux gardes anti « deux taps pour lever le clavier »
(la `ValueKey` sur le bloc du champ, le type de widget constant) interdisent de
la restructurer sans raison.

Couvert par `test/features/shell/tablet_navigation_rail_landscape_test.dart`
(sans le correctif : `overflowed by 170 pixels` à 172 dp, `222` à 120 dp).

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

Restent ouverts, même famille : le `BOTTOM OVERFLOWED BY 240` de la
conversation (ci-dessus), et le `PodcastMiniPlayer` (hauteur fixe 64, hors
`Expanded` dans la branche paysage de `MainShell`) qui déborderait si le corps
tombait sous 64 dp — non observé, non corrigé.

---

## Groupes — « Découvrir » lisait le mauvais backend (2026-08-06)

**Cause trouvée, et ce n'était pas dans `loadGroups()`.** L'onglet annonçait
« Aucun groupe public » alors que `public.groups` en contient trois
(`Diaspora Niger — CA`, `Diaspora Niger — Canada`, `teste`, tous
`is_private = false`). `loadGroups()` faisait exactement ce qu'on lui
demandait : il interrogeait **Firestore**, dont la collection `groups` est
vide depuis la migration.

`groupRemoteDataSourceProvider` (`group_provider.dart`) rendait
`GroupRemoteDataSourceImpl` (Firestore) **depuis le commit initial, sans une
seule modification**. C'est le seul point de câblage de toute la
fonctionnalité : liste, découverte, fiche, création, adhésion, recherche.
Tout le travail accumulé sur `GroupSupabaseDataSource` — session avant
lecture, appartenance lue dans `group_members`, garde « Officiel » — portait
donc sur une classe que rien n'instanciait.

Deux autres symptômes s'expliquent par le même câblage :

- **Le groupe officiel du pays n'était jamais rejoint.**
  `GroupRemoteDataSourceImpl.ensureOfficialGroup` lève `UnimplementedError`,
  que `GroupRepositoryImpl` convertit en `Left(...)`, que
  `ProfileNotifier._joinOfficialGroup` avale (`(failure) async {}`).
- **La recherche ne remontait aucun groupe** (`search_provider.dart`,
  `search_remote_datasource.dart`, qui instanciaient la même classe).

`loadGroups()` est désormais instrumenté (`[groupes] loadGroups source=… /
cache=… / réseau=…`, `kDebugMode`) : les quatre issues indistinguables
jusqu'ici — cache servi, réseau vide, échec avalé, mauvais backend — se lisent
en une ligne de logcat.

⚠️ **Le même correctif existe déjà sur `claude/silly-liskov-1e9d62`**
(commit `c803893`, 2026-08-06), avec 15 autres commits que cette branche n'a
jamais reçus. Voir la section « Deux branches » plus bas.

À vérifier sur l'appareil :

- [ ] **« Découvrir »** : les trois groupes publics apparaissent. Filtrer sur
      « Tous » les pays d'abord — le filtre pays par défaut se pose sur le pays
      du profil, ou sur `NE` à défaut, et ne laisserait qu'un seul groupe.
- [ ] **Journal** : `adb logcat | grep "\[groupes\]"` affiche
      `source=GroupSupabaseDataSource` puis `réseau=3 groupes`.
- [ ] **Recherche de groupes** (loupe de l'écran Groupes) : taper « niger »
      remonte bien les deux groupes « Diaspora Niger ».
- [ ] **Groupe officiel du pays à l'inscription** : renseigner un pays dans le
      profil doit désormais faire apparaître son groupe officiel dans
      « Mes groupes » (chemin `ensureOfficialGroup`, jamais exécuté jusqu'ici).

### §9c — le nom du groupe était rogné par les pastilles de sa carte

Sur un écran de 360 dp, la colonne de texte de `_GroupCard` ne fait que
~140 dp : écran 360 − marge 32 − padding de carte 28 − avatar 52 − écart 14 −
écart 8 − bouton « Rejoindre » ~86. L'ancienne ligne de titre y logeait, en
plus du nom, un cadenas (13), une pastille « Officiel », une épingle (14) et
une pastille ACTIF/CALME — **les deux pastilles à largeur libre, et le nom
seul `Flexible`**. Il cédait donc toujours en premier ; et quand les pastilles
dépassaient à elles seules les 140 dp, la ligne débordait carrément (mesuré :
`RenderFlex overflowed by 88 pixels`).

Correctif : les deux pastilles descendent dans la ligne de méta, passée de
`Row` à `Wrap` (elles y restent entières et vont à la ligne au lieu de rogner
le nom de ville) ; la ligne de titre ne garde que le nom, le cadenas et
l'épingle ; et le nom passe à `maxLines: 2`, sans quoi « Diaspora Niger —
Canada » (~175 dp) ne tiendrait toujours pas dans les ~101 dp restants.

Verrouillé par `test/features/groups/group_card_title_truncation_test.dart`
(6 cas, dont deux de régression qui prouvent le débordement d'avant).

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

⚠️ **Défaut repéré au passage, non corrigé** : le corps de 9e dit « Aucune
conversation / Commencez à discuter » même quand la vérité est « aucune
conversation **non lue** » ou « aucun **groupe** ». Le message ment sur le
filtre actif. Hors périmètre des quatre points traités ici.

### Deux branches, seize commits d'écart

`claude/silly-liskov-1e9d62` porte 16 commits que `wip-jules-2025-12-29T23-58-34-776Z`
n'a jamais reçus, dont plusieurs déjà considérés comme « faits » :

| Commit | Sujet |
|---|---|
| `c803893` | bascule des groupes vers Supabase (le correctif ci-dessus) |
| `21b5200` | migration du groupe hérité Firestore |
| `c960ec4` | recalage de `member_count` |
| `6627217`, `a1a7190` | normalisation `country_code` en ISO-2 |
| `988f2c1`, `009c0d9`, `b9d94f3`, `12d1549`, `4283cdd` | actions mortes / sessions manquantes |
| `96d2711` | enregistrement du profil au premier essai |
| `6a1fef2`, `d59f785`, `074043d` | liens profonds de groupe, « Mes notes » |

La branche courante n'a qu'un commit propre en face (`6ff6438`). **Décider
explicitement d'un rapatriement** — sinon chaque correctif sera retrouvé une
troisième fois. Non fait ici : c'est une fusion de 16 commits sur une branche
qu'un agent tiers réécrit en parallèle.

✅ **Rapatriement fait le 2026-08-06** — pas par la fusion préparée ici mais
par une session parallèle, dans l'autre sens (`098414c`, `7d0758c` : la
branche partagée fusionnée dans `claude/silly-liskov-1e9d62`, puis ramenée).
Vérifié : `git merge-base --is-ancestor claude/silly-liskov-1e9d62 HEAD` répond
oui. La branche de fusion préparée est devenue **en retard de 511 lignes** sur
HEAD et aurait annulé la passe l10n de Jules ; elle a été supprimée (locale,
distante, worktree). Leçon retenue en mémoire : deux sessions sur la même
branche doivent avoir des périmètres disjoints.

---

## Messagerie — un filtre sans résultat n'est pas une messagerie vide (2026-08-06)

`_buildConversationList` branchait sur `filtered.isEmpty`, c'est-à-dire la
liste **après** application de la puce de filtre, et rendait alors la fiche 9e :
« Aucune conversation », « Commencez à discuter avec les membres de la
diaspora », le bouton « Nouvelle conversation », la ligne sur le chiffrement.

Sur la puce **« Non lus »** d'un compte dont tout est lu, les trois phrases
étaient fausses et l'action ne répondait pas au problème : il n'y avait rien à
commencer, il fallait revenir à « Tous ». Idem pour **« Groupes »** sur un
compte sans conversation de groupe — et c'est le cas du compte de test.

Les libellés justes existaient déjà dans les **deux** `.arb` —
`noUnreadMessages`, `noGroupConversations`, `showAllConversations` — mais
**aucun n'était référencé nulle part dans `lib/`**. La branche avait été prévue
puis oubliée. Aucun `.arb` n'a donc été touché (donc aucune collision avec la
passe l10n en cours).

Verrouillé par `test/features/messages/etat_vide_filtre_test.dart` (6 cas,
dont l'ordre des gardes et la non-mort des trois clés). Test de structure,
comme `reglages_sans_doublon_test.dart` : monter `MessagesScreen` exigerait
l10n, GoRouter, une session Supabase et une dizaine de providers, et
`_buildConversationList` est privée.

- [ ] **Puce « Non lus », tout étant lu** : « Aucun message non lu » + le lien
      « Afficher toutes les conversations », et **pas** la fiche 9e. Le lien
      doit ramener sur « Tous » avec la liste complète.
- [ ] **Puce « Groupes » sur un compte sans groupe** : « Aucune conversation de
      groupe », même sortie.
- [ ] **Messagerie réellement vide** (compte neuf) : la fiche 9e s'affiche
      toujours, elle — c'est elle qu'on ne voulait pas perdre.
- [ ] **Archives vides** et **recherche sans résultat** : inchangés, ils ont
      leurs propres états vides depuis toujours.
- [ ] **Thème sombre** sur les deux nouveaux états : l'icône est posée à
      `textTertiaryColor` à 50 %, le texte à `textSecondaryColor` — vérifier
      qu'ils restent lisibles.

### Le `country_code` n'est plus un problème (vérifié en base le 2026-08-06)

Signalé plus haut comme défaut ouvert « les codes pays mélangent ISO et noms ».
**C'est faux depuis la fusion** : `6627217` normalise à l'écriture et `a1a7190`
a repris l'existant. Relevé en base ce jour :

| table | valeurs |
|---|---|
| `groups.country_code` | `NE` ×3, `CA` ×1, `null` ×1 |
| `users.country_code` | `null` ×5, `CA` ×2, `NE` ×2, `BF` ×1 |

Et le mappage du profil est cohérent des deux côtés :
`profile_supabase_datasource.dart` lit `'currentCountry': row['country_code']`
et écrit via `CountryExtension.toIsoCode(...)`. Rien à corriger.

**Arête tranchée le 2026-08-06 : un groupe sans pays vaut désormais `NE`.**

Un groupe dont `country_code` est `null` est invisible dans « Découvrir » dès
qu'un filtre pays est actif — et l'app en pose un **toute seule** au premier
affichage (`_loadDefaultCountryFilter`). `_applyFilters` fait `g.country ==
_selectedCountry`, ce qui écarte les nuls sans que l'utilisateur ait rien
demandé, et rien à l'écran ne le dit. Un groupe était dans ce cas
(`2b24986f-08b5-4840-9931-dbe046ffb394`, « Groupe de test prive »).

Le défaut vit en une seule constante, `kDefaultCountryCode`
(`lib/core/models/country.dart`), qui remplace aussi les deux `'NE'` en dur de
`groups_screen.dart` — trois endroits décidaient du Niger séparément.

| Verrou | Où | Couvre |
|---|---|---|
| `kDefaultCountryCode` | `GroupSupabaseDataSource.createGroup` | toute création passant par l'app |
| idem | `create_group_screen.dart` | l'affichage immédiat, avant l'aller-retour |
| `UPDATE` | migration | le groupe déjà nul en base |
| `SET DEFAULT 'NE'` | migration | colonne omise à l'insertion |
| déclencheur `trg_groups_country_code_defaut` | migration | colonne fournie **nulle ou vide** — ce que `insert_group` fait, puisqu'il passe toujours `p_country_code` |

Le déclencheur plutôt qu'un `COALESCE` dans `insert_group` : la fonction est
`SECURITY DEFINER`, et la reproduire depuis `pg_proc` pour n'y changer qu'une
ligne fait courir un risque de dérive sans rapport avec le sujet.

✅ **Migration appliquée le 2026-08-06**, et inscrite dans
`supabase_migrations.schema_migrations` — elle est passée par
`db query --file` et non par `db push`, donc sans cette inscription
`supabase migration list` l'aurait montrée « en attente » pour toujours.

Relevé avant / après sur `public.groups` :

| `country_code` | avant | après |
|---|---|---|
| `NE` | 2 | **3** |
| `CA` | 1 | 1 |
| *(null)* | **1** | **0** |

Le groupe visé (`2b24986f-08b5-4840-9931-dbe046ffb394`, « Groupe de test
prive ») porte bien `NE`, et le `CA` n'a pas bougé — la reprise ne touche que
les nuls et les vides.

Les deux autres verrous sont vérifiés en base : `column_default` vaut
`'NE'::text`, et `trg_groups_country_code_defaut` existe.

**Le déclencheur est prouvé, pas seulement présent.** Il n'a pas pu être
éprouvé sur `public.groups` : un autre déclencheur, `enforce_group_creator()`,
refuse toute insertion sans JWT applicatif (« firebase_uid introuvable »), et
la session d'administration n'en a pas. La fonction a donc été montée sur une
table jetable, dans une transaction annulée — quatre cas, dont un contrôle
négatif :

| entrée | résultat |
|---|---|
| `NULL` (ce que passe `insert_group`) | `NE` |
| `''` | `NE` |
| `'   '` | `NE` |
| `'CA'` | **`CA`** — non écrasé |

Vérifié aussi par `test/core/models/pays_defaut_test.dart` (6 cas : le défaut
vaut bien `Country.niger.code`, c'est un code ISO-2 et pas un libellé, les deux
chemins de création le posent, plus aucun `'NE'` en dur dans l'écran des
groupes, et la migration est versionnée).

Reste à voir à l'écran — c'est tout ce que la base ne peut pas prouver :

- [ ] **Créer un groupe sans choisir de pays** : il doit apparaître dans
      « Découvrir » avec le filtre `NE`, et la fiche doit afficher « Niger ».
- [ ] **« Groupe de test prive » est de nouveau atteignable** : c'est un groupe
      **privé**, donc à chercher dans « Mes groupes » côté créateur, pas dans
      « Découvrir ».
- [ ] **Un groupe créé AVEC un pays** garde bien le sien à l'écran aussi.

---

## Notification push — le ciphertext AES sortait en clair dans l'aperçu (2026-08-13)

Signalé : « les pushnotifications affiche les messages crypté ».

**Cause.** `message_preview_for_notification` (SQL) ne masquait le contenu que
si `encryptionLevel = 'e2ee'` ou si `content` commençait par le préfixe legacy
`gcm:`. Mais le repli AES réellement utilisé aujourd'hui côté client
(`MessageCryptoService.encrypt1to1`/`encryptGroup`, quand aucune session
Signal n'est établie) écrit `encryptionLevel: 'aes'` et un `content` au format
`iv:base64ciphertext` (`EncryptionService.encryptText`) — qui ne matche pas
`gcm:%`. Ces messages tombaient dans la branche ELSE et exposaient le
ciphertext brut comme corps de la notification push, envoyé tel quel via FCM.

**Correctif** (`supabase/migrations/20260813140000_fix_push_preview_leaks_aes_ciphertext.sql`) :
toute valeur de `encryptionLevel` ('aes' OU 'e2ee') déclenche désormais le
preview générique par type (🔒 Nouveau message / 📸 Photo / …), comme c'était
déjà le cas pour 'e2ee' seul.

- [x] **Migration appliquée** (`supabase db push`, 2026-08-13, approuvée par
      Salim). `migration list` confirme les deux versions Local = Remote.

⚠️ **Pour Jules — j'ai touché ton fichier `20260813130000_fix_receipts_uuid_type_and_anon_grant.sql`.**
`db push` s'arrêtait dessus (42723 « mark_messages_as_delivered already
exists with same argument types ») et bloquait toute la file, ma migration
comprise. Cause : ton fichier `DROP`e bien la surcharge
`mark_messages_as_delivered(UUID, TEXT)` avant de recréer, mais pas la
surcharge `(TEXT, TEXT)` — celle-là existe depuis `20260720120300`, avant
`20260813120000`. J'ai ajouté le `DROP FUNCTION IF EXISTS
public.mark_messages_as_delivered(TEXT, TEXT);` manquant (même motif que les
deux `DROP` déjà là pour `mark_messages_as_read`), poussé, puis relancé
`db push` — passé, sans autre incident. Le fichier a maintenant un
paragraphe 3) dans son commentaire d'en-tête qui explique l'ajout. Si tu
avais une raison de ne PAS dropper cette surcharge (une autre fonction encore
dessus, un appelant qui en dépend), vérifie — je n'ai vu que l'échec du push,
pas ton intention complète sur ce fichier.

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
- [ ] Les lignes `notifications` déjà en base avant ce correctif gardent leur
      `body` en ciphertext (une UPDATE de rattrapage n'a pas été tentée — trop
      de risque de mal cibler les lignes) : à purger ou ignorer selon la
      politique de rétention choisie.

### Bug sans rapport trouvé en vérifiant : les icônes d'action de notif n'existent pas

`DrawableResourceAndroidBitmap('@drawable/ic_reply')` et
`'@drawable/ic_mark_read'` ([notification_service.dart:1790](lib/core/services/notification_service.dart:1790),
[:1802](lib/core/services/notification_service.dart:1802)) référencent des
ressources absentes de `android/app/src/main/res/` (`find` : aucun fichier
`ic_reply*`/`ic_mark_read*`, aucune densité). Résultat mesuré sur l'appareil :
`IllegalArgumentException: Drawable resource ID must not be 0` dans
`FlutterLocalNotificationsPlugin.getIconFromSource` →
`showNotification` échoue **pour toute notification de type message** (ces
deux actions ne sont ajoutées que si `type == 'message' && conversationId !=
null` — donc pratiquement tous les messages de chat), silencieusement, sans
crash visible côté utilisateur.

Pas su si ça touche aussi le cas app tuée/arrière-plan (où Android peut
afficher directement le champ `notification` FCM sans passer par ce code) —
seul le premier plan (`onMessage` → `_showLocalNotification`) a été exercé.

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

## Aperçu de notification en clair (2026-08-13)

Demande de Salim, en suite directe du correctif ci-dessus : « je veux que les
messages soient en clair » — précisé par lui-même : l'aperçu de notification,
pas le chiffrement des messages en base (confirmé explicitement avant de
toucher au code).

**Repli AES** (`encryptionLevel: 'aes'`, cas majoritaire) : déchiffré
**côté serveur** via `pgcrypto` (`decrypt_aes_fallback`,
`20260813160000_real_plaintext_push_preview.sql`) — même clé partagée que
`EncryptionService` côté client, déjà dans l'APK, pas un nouveau secret.

- [x] **Interopérabilité vérifiée avant déploiement** : un vrai ciphertext
      généré par le code Dart de l'app (`encrypt.AES(key, mode: cbc)`, clé de
      32 octets) a été déchiffré avec succès par `decrypt_iv(...,
      'aes-cbc/pad:pkcs')` côté Postgres — texte clair identique à l'octet
      près. Script Dart jetable, supprimé après usage.

**E2EE Signal réel** (`e2eePayloads`/`senderKeyPayload`) : le serveur ne peut
toujours pas déchiffrer — la ligne `notifications` transporte désormais le
vrai payload chiffré (au lieu du placeholder `'[E2EE]'`) pour un
déchiffrement côté client. **Trouvaille en marge** : `setE2EEDecryptionCallback`
n'était appelé **nulle part** dans l'app (vérifié par grep sur tout le
dépôt) — le déchiffrement foreground n'avait donc jamais fonctionné, même
avant ce correctif. Câblé maintenant dans `app.dart`. Ne fonctionnera qu'au
premier plan ; l'arrière-plan nécessiterait de charger tout le magasin de
sessions Signal dans un isolate séparé — non fait, hors périmètre.

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

---

## Demandes d'adhésion — brancher Supabase n'avait pas suffi (2026-08-06)

`c7f4141` a fait pointer `GroupRequestDataSource` vers Supabase au lieu d'une
collection Firestore restée vide. La plomberie était juste — 12 méthodes sur
12, tables, colonnes et index uniques vérifiés en base — mais **le parcours
restait impraticable de bout en bout**, pour trois raisons que seule la base
pouvait dire :

- La seule policy sur `group_requests` était
  `firebase_uid() = requester_id OR firebase_uid() = processed_by`. Une demande
  en attente a `processed_by` NULL et `requester_id` = le demandeur :
  **l'admin ne correspondait à aucune des deux branches**. Sa liste de demandes
  en attente était vide, et l'UPDATE d'approbation ne touchait aucune ligne —
  sans erreur, PostgREST rendant 200 sur un update qui ne matche rien.
- `processed_by` recevait `auth.currentUser.id`, l'uid **Supabase** (un uuid),
  là où la colonne et les policies parlent en uid **Firebase**. La seule ligne
  existante le montre : `processed_by = '1b313b0d-…'` face à
  `requester_id = 'U64HKfrjM5Nw…'`. Cette branche ne pouvait jamais matcher.
- L'approbation inscrivait le nouveau membre dans `groups.member_ids` — colonne
  **vide sur les 4 groupes**, et systématiquement recalculée depuis
  `group_members` au chargement. Approuver n'ajoutait personne.
- Enfin, ni `group_requests` ni `group_invites` n'appartenaient à la
  publication `supabase_realtime` : les `.stream()` ne faisaient que leur
  chargement initial. Même trou que `group_pinned_items` (20260805120000).

Corrigé : policies admin sur `group_requests` / `group_invites`, fonctions
`approve_group_request` / `reject_group_request` (SECURITY DEFINER, statut +
appartenance en une transaction, identité résolue par `firebase_uid()`), et
`acceptGroupInvite` qui écrit dans `group_members` comme `joinGroup`
(migration `20260806180000_group_requests_admin_access.sql`).

Rien de tout ça n'est prouvable sans **deux comptes** :

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
- [ ] **A refuse** une deuxième demande : elle disparaît de la liste et B ne
      devient pas membre.
- [ ] **B redemande alors qu'il est déjà membre** : message « Vous êtes déjà
      membre de ce groupe » (le garde lisait une colonne vide, il ne se
      déclenchait jamais).
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

- [ ] **Refus d'invitation** (`declineGroupInvite`) : même chemin RLS que
      l'acceptation, débloqué par la même migration, mais jamais exercé.
- [ ] **Un non-admin ne voit pas** les demandes du groupe, et l'appel RPC lui
      est refusé (« Réservé aux administrateurs du groupe »).

### Le corollaire : un groupe privé ne montrait qu'un seul membre

`group_members_select` valait `firebase_uid() = user_id OR
is_group_public(group_id)`. Dans un groupe **privé**, aucune des deux branches
ne couvre les autres membres. Comme `_membershipFor` reconstruit `member_ids`
et `admin_ids` depuis cette table et que `GroupEntity.memberCount` dérive de
`memberIds.length`, un groupe privé de cinq personnes se serait affiché
« 1 membre » pour chacune, avec une liste de membres réduite à soi-même.

Le défaut était **invisible jusqu'ici** : les deux groupes privés de la base
n'ont qu'un membre chacun. Il devient observable dès qu'un second membre
arrive — donc dès que l'approbation ci-dessus fonctionne. Corrigé dans la
foulée par `20260806190000_group_members_visible_aux_membres.sql`, qui ajoute
`is_group_member(group_id)` — l'idiome déjà retenu sur `groups`
(`groups_select_public`).

Relu en base après application : pas de récursion, et une session sans
identité ne voit que les 2 lignes des groupes publics (les privés restent
masqués).

- [x] **Groupe privé à 2 membres** — vérifié sur SM A515F le 2026-08-06, du
      côté du membre non-administrateur : « Testeurs » affiche bien **2**
      après l'entrée de Sim. Avant la migration il aurait affiché 1.
      Vérifié depuis ce seul compte ; la vue de l'administrateur n'a pas été
      regardée (elle passait déjà, `firebase_uid() = user_id` couvrant sa
      propre ligne).
- [ ] **Un non-membre ne voit toujours rien** d'un groupe privé.

Deux effets de bord relevés pendant ce test, aucun bloquant :

- **`groups.member_count` reste à 1** alors que le groupe a 2 membres. Le
  trigger `update_group_member_count` n'est pas `SECURITY DEFINER` : son
  `UPDATE groups` tombe sur `groups_update_admin` (`is_group_admin`), faux pour
  quelqu'un qui vient de rejoindre. L'écran affiche quand même 2, parce que
  `GroupEntity.memberCount` dérive de `group_members` et jamais de cette
  colonne — la colonne est fausse, l'affichage est juste. À corriger si un jour
  un tri ou une requête s'appuie sur `member_count` (`getGroups` l'utilise déjà
  en `order by`).
- **La liste ne s'est pas rafraîchie après l'acceptation** : l'invitation
  disparaît bien, mais « Testeurs » n'apparaît qu'après un redémarrage à froid,
  malgré le `ref.invalidate(myGroupsNotifierProvider)` de `_accept`.
  (L'écran des demandes, lui, se vide immédiatement après une approbation.)

### La fiche du groupe ment selon le chemin par lequel on l'ouvre

Trouvé en cherchant l'écran des demandes, le 2026-08-06. Sur **le même groupe**,
avec **le même compte** — Sim, créateur et administrateur :

| Ouverte depuis | Membres | Bouton du bas | Menu « Demandes » |
|---|---|---|---|
| la liste « Mes groupes » | 1 | « Ouvrir la discussion » | présent, pastille 1 |
| l'en-tête de la conversation | **0** | **« Demander à rejoindre »** | **absent** |

L'écran calcule tout depuis l'entité :
`isAdmin = group.adminIds.contains(me)` et
`isMember = group.memberIds.contains(me)`
([group_detail_screen.dart:132](lib/features/groups/presentation/screens/group_detail_screen.dart:132)).
Par le second chemin ces deux listes arrivent vides, donc l'administrateur se
voit proposer de rejoindre son propre groupe et **perd l'accès à l'écran
d'approbation**.

Ce n'est pas la base : la requête d'appartenance rejouée sous l'identité de Sim
rend bien sa ligne `role = 'admin'`. Et `getGroupById` applique pourtant
`_membershipFor` — son commentaire décrit même ce symptôme comme déjà corrigé.
La cause exacte côté app n'a pas été trouvée ; `_membershipFor` avale ses
erreurs (`catch (_) { return const {}; }`), ce qui rend un échec indiscernable
d'un groupe sans membres.

À noter pour qui reprendra : `getMyGroups` masque le même trou avec un
rattrapage explicite (« on s'y ajoute quand même, sinon Mes groupes proposerait
Rejoindre sur ses propres groupes »). Le rattrapage soigne le symptôme sur un
écran et laisse l'autre à découvert — donc le « 1 » de la liste ne prouve pas
que la lecture d'appartenance ait réussi.

- [ ] **Vérifier après correction** : ouvrir la fiche depuis la conversation
      doit donner exactement le même écran que depuis la liste.

---

## La porte d'entrée des groupes était grande ouverte (2026-08-06)

`group_members_own` est une policy `FOR ALL` dont le `USING` vaut
`firebase_uid() = user_id`, **sans `WITH CHECK` explicite** — la même expression
sert donc au contrôle d'insertion. Elle vérifie qu'on s'inscrit *soi-même*, et
rien d'autre : ni le groupe, ni une invitation, ni une approbation.

Mesuré sous une vraie identité avant correction : l'insertion d'une ligne
d'appartenance est **acceptée pour un groupe inexistant** (`group_id` n'a
d'ailleurs aucune clé étrangère — 7 lignes orphelines dorment déjà dans la
table). A fortiori pour un groupe privé dont on n'a jamais reçu d'invitation :
il suffit d'en connaître l'uuid et d'appeler l'API. Les uuid des groupes privés
ne sont pas listés, mais c'est de l'obscurité, pas un contrôle.

Fermé par `20260806210000_group_members_porte_d_entree.sql` : une policy
**RESTRICTIVE `FOR INSERT`**, qui s'ajoute en ET aux permissives sans toucher au
reste. `SELECT` / `UPDATE` / `DELETE` gardent `group_members_own` — quitter un
groupe privé reste possible, ce qu'une condition sur l'invitation aurait cassé.

Mesures après application, sous l'identité réelle du compte de test :

| Cas | Attendu | Obtenu |
|---|---|---|
| groupe inexistant (ou privé sans invitation) | refusé | `42501` refusé |
| groupe **public** (`joinGroup`) | accepté | accepté |
| groupe privé **avec invitation** | accepté | `23505` doublon — la policy a laissé passer, `has_group_invite` = `t` |
| quitter un groupe (`DELETE`) | accepté | 1 ligne supprimée |

Et dans l'app, sur SM A515F : « Découvrir » → « Rejoindre » sur un groupe
public fonctionne toujours — c'est le chemin que cette policy aurait pu casser,
et il a été exercé pour de vrai, pas seulement en SQL. Adhésion retirée après
coup.

- [ ] **Reste à voir** : rejoindre un groupe public depuis un compte qui n'y a
      jamais mis les pieds (le test l'a fait avec le compte administrateur d'un
      autre groupe), et vérifier qu'un groupe privé sans invitation ne propose
      bien que « Demander à rejoindre ».

Deux voisins **non corrigés**, repérés en lisant ces policies :

- **`removeMember` ne peut pas fonctionner** :
  [group_supabase_datasource.dart:337](lib/features/groups/data/datasources/group_supabase_datasource.dart:337)
  délègue à `leaveGroup`, donc un `DELETE` sur la ligne de *quelqu'un d'autre*,
  que `group_members_own` (`firebase_uid() = user_id`) refuse. Un
  administrateur ne peut pas exclure un membre.
- **Aucune clé étrangère sur `group_members.group_id`** : supprimer un groupe
  laisse ses membres derrière (7 orphelins sur 11 lignes aujourd'hui).

---

## Fiche membres de groupe bloquée / vide (2026-08-13)

Signalé par Salim : « problème sur les infos des membres de groupes ». L'appareil
était **surpris en flagrant délit** — écran « Membres » figé sur un spinner
indéfini au moment où j'ai capturé le premier screenshot de la session.

**Cause n°1 — spinner indéfini.** `GroupMembersScreen`
([group_members_screen.dart](lib/features/groups/presentation/screens/group_members_screen.dart))
est un `ConsumerWidget` qui ne charge jamais lui-même son groupe : il lit
`group` (passé par la navigation) puis, à défaut, l'état déjà présent dans
`groupDetailNotifierProvider` — un provider **partagé**, pas une famille par
id, jamais peuplé par cet écran. Le lien « Tout voir » de la fiche groupe
([group_detail_screen.dart:705](lib/features/groups/presentation/screens/group_detail_screen.dart:705))
ne passait pas `extra: group`, contrairement au bouton du bas qui le passait
déjà. Sans lui, si l'écran précédent n'avait pas déjà peuplé le provider pour
CE groupe, `groupEntity` restait `null` pour toujours.

Corrigé : `GroupMembersScreen` devient `ConsumerStatefulWidget`, déclenche
`loadGroup(groupId)` en `initState` quand `group` est absent, et n'accepte la
valeur en cache que si son id correspond à l'écran ouvert (le provider partagé
peut porter les données d'un AUTRE groupe visité juste avant). Le lien
« Tout voir » passe désormais `extra: group` en plus, pour l'aller vite sans
round-trip réseau.

**Cause n°2 — fiche affichant « Membres · 0 » / « Rejoindre le groupe » à un
membre réel.** Repérée en vérifiant le correctif n°1 sur appareil, par un
AUTRE chemin de navigation (en-tête de la conversation de groupe → fiche,
sans `initialGroup`) :
`getGroupStream` ([group_supabase_datasource.dart:184](lib/features/groups/data/datasources/group_supabase_datasource.dart:184))
lit la ligne `groups` brute sans jamais appliquer `_withMembership` —
contrairement à `getGroupById`/`getGroups`/`getMyGroups`. Comme
`groups.member_ids`/`admin_ids` sont NULL en base (seule `group_members` fait
foi), le flux temps réel écrasait en permanence la lecture ponctuelle
correcte de `groupDetailNotifierProvider` via le `??` de `GroupDetailScreen`.
Corrigé : `getGroupStream` applique désormais `_membershipFor`/`_withMembership`
comme les autres lectures.

- [x] **Vérifié sur SM A515F**, groupe « Diaspora Niger — Canada » (2 membres,
  compte Sim A) : par le chemin en-tête de conversation → fiche → Tout voir —
  celui qui reproduisait les DEUX défauts — la fiche affiche « Membres · 2 »,
  « Ouvrir la discussion », les deux membres nommés (Sim A · Créateur, Salim
  L.), et « Tout voir » ouvre la liste immédiatement au lieu de tourner dans
  le vide.

**Cause n°3 — signalée par Salim en relisant le screenshot ci-dessus** : la
ligne « Créateur » affichait « Sim A · Étudiant », alors que le bas de la même
fiche affiche « Créé par Diaspo Niger ». Vérifié en base
(`supabase db query --linked`) : pour ce groupe `is_official=true`,
`creator_id` pointe en fait vers le compte perso de Sim A
(`vQZE49dTdyRtLwSG6lMIbhAqoFG2`) avec `creator_name` forcé à « Diaspo Niger »
— contrainte de la base, pas un vrai compte plateforme séparé. La ligne
« Créateur » suivait le profil réel lié à `creator_id` au lieu de l'identité
`creator_name` déjà affichée ailleurs sur la fiche.

Corrigé côté affichage uniquement (la réassignation en base d'un vrai compte
plateforme pour les groupes officiels reste à discuter séparément) :
`_MemberListItem` (`group_detail_screen.dart` et `group_members_screen.dart`)
affiche `group.creatorName` — et masque la profession — pour la ligne
créateur quand `group.isOfficial` est vrai.

- [x] **Vérifié sur SM A515F** : la ligne créateur affiche désormais
  « Diaspo Niger · Créateur » (sans profession) sur la fiche ET sur l'écran
  « Tout voir », cohérent avec « Créé par Diaspo Niger » en bas de fiche.

**Réassignation en base faite le 2026-08-13** (voir
`docs/ops/GROUPES_OFFICIELS.md`) : Salim a créé un vrai compte plateforme
(`czk5UoUclLOFmbRtUIZ5XYLYKo52`, email `support@diasponiger.com`), connecté
une fois dans l'app pour amorcer le pont Supabase standard. Ensuite, en SQL :
`users.display_name = 'Diaspo Niger'` + `is_verified = true`,
`groups.creator_id` réassigné dessus pour le groupe officiel, et une ligne
`group_members` `role='owner'` — lui seul, aucun compte perso ne garde de
droit de gestion implicite (décision explicite de Salim). `member_count`
recalé à 3 (le trigger `group_members_count_trigger` ne s'est pas déclenché
sur cet insert direct, même symptôme que documenté plus haut dans ce fichier
pour la migration des groupes hérités).

- [x] **Vérifié sur SM A515F, connecté en Sim A** (donc point de vue d'un
  membre normal, pas du compte plateforme) : la fiche affiche « Membres · 3 »,
  la ligne « Diaspo Niger · Créateur » sans chevron ni tap possible, et
  « Salim L. » apparaît comme 3e membre (compte déjà présent en base,
  simplement jamais vu résolu avant ce test).

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

- [x] **Testé en base (pas sur appareil — aucun compte de test n'a de pays
  encore sans groupe officiel)** : rejoué sous une identité non-admin réelle
  (`U64HKfrjM5NwR6HO00XPKo6168z2`), dans une transaction annulée par
  `ROLLBACK` (`SET LOCAL request.jwt.claims`). Cas nouveau pays (France,
  simulé) : plus d'exception, `creator_id` = compte plateforme,
  `member_count = 1`, aucune trace laissée par le ROLLBACK, les 4 triggers de
  `groups` réactivés après coup. Cas pays déjà couvert (Canada) : retour
  identique à avant, aucun INSERT déclenché.
- [ ] **Vérification sur appareil demandée par Salim** : dès qu'un vrai
  compte renseigne pour la première fois un pays sans groupe officiel
  existant, confirmer sur cet appareil que le groupe apparaît normalement
  (nom, « Créé par Diaspo Niger », membre compté) — la transaction annulée
  ci-dessus prouve la logique SQL, pas le chemin réel `ProfileNotifier` →
  RPC → écran groupe de bout en bout. Repérable via
  `select id, name, country_code, created_at from groups where is_official
  order by created_at desc;` (un nouveau pays = une ligne de plus).

---

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

## Groupes officiels — organisation de la gestion au quotidien (2026-08-13)

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

## Modération des membres de groupe : trou RLS fermé + bug de départ trouvé (2026-08-14)

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

## Heure/accusé masqués au tap sur une rafale envoyée (2026-08-14)

> **Obsolète depuis le 2026-08-23** : la bascule décrite ci-dessous a été
> supprimée, l'heure s'affiche désormais sur tous les messages. Voir
> « Heure et accusé sur tous les messages » plus bas.

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

## Avertissement Android « pages de 16 Ko » — une seule vraie cause, correctif bloqué en cascade (2026-08-14)

Popup système sur appareil (build **debuggable** uniquement, en français :
« Cette appli n'est pas compatible avec les pages de 16 Ko ») citant 4
bibliothèques : `libflutter.so`, `libdatastore_shared_counter.so`,
`libVkLayer_khronos_validation.so`, `libnoise.so`.

Vérifié en extrayant les 4 `.so` de l'APK (debug **et** release,
`build/app/outputs/apk/`) et en lisant leurs en-têtes ELF
(`llvm-readelf -l`, NDK r27 déjà installé) : **seule `libnoise.so` est
réellement mal alignée** (segment LOAD à 4 Ko au lieu de 16). Les 3 autres
sont déjà à 16 Ko ou 64 Ko — le popup les signale par erreur (« erreur
inconnue », pas un vrai défaut d'alignement).

`libnoise.so` vient de `com.github.paramsen:noise:2.0.0`, tirée par le
`build.gradle` Android de **`livekit_client`** (pas `flutter_webrtc`, malgré
l'intuition de départ) — une petite lib FFT utilisée pour la détection de
niveau audio en temps réel (indicateur « parle en ce moment » des salons
audio / appels de groupe, cf [[project_widgets_alimentes_en_dur]]). LiveKit
l'a corrigée en la republiant `io.livekit:noise:2.0.0` (vérifié : LOAD à
16 Ko dans l'AAR téléchargé depuis Maven Central), correctif présent à partir
de `livekit_client 2.6.0`.

**Le correctif n'est pas accessible sans remonter toute une chaîne.**
`livekit_client ≥2.6.0` épingle une version exacte de `flutter_webrtc`
(1.2.1 → 1.6.0 selon la sous-version, jamais notre `^0.12.12` actuel), qui
entraîne `connectivity_plus ^7.0.0` (exige AGP ≥8.12.1 et Gradle ≥8.13 —
projet en 8.7.0 / 8.10.2), et selon la sous-version exacte de
`livekit_client` :
- 2.6.0–2.6.4 : `device_info_plus ^12.2.0` (projet en `^11.4.0`, probablement
  anodin) ;
- ≥2.6.5 : `dart_jsonwebtoken ^3.3.2` → `pointycastle ^4.0.0`, **incompatible
  avec `encrypt: ^5.0.3`** (`pointycastle ^3.6.2`) — `encrypt` sert au repli
  AES de l'E2EE (cf [[project_e2ee_status]]), donc pas un paquet à bumper à
  la légère pour un warning de debug.

Décision prise le 2026-08-14 : reporter. Pas de preuve de crash réel en
production (le popup ne s'affiche qu'en build debuggable), et le correctif
complet toucherait WebRTC + connectivité + outillage Android + potentiellement
la crypto — un chantier à part entière, pas un fix ponctuel.

- [ ] Si repris : bump couplé `livekit_client` + `flutter_webrtc` +
  `connectivity_plus` (+ AGP/Gradle, + vérifier `encrypt`/`pointycastle`),
  puis tester au doigt sur SM A515F : appels 1:1, appels de groupe, salons
  audio (indicateur de parole en particulier, puisque c'est lui qui dépend de
  la lib corrigée), et un parcours E2EE complet si `encrypt` a bougé.
- [ ] Revérifier l'alignement après coup avec la même méthode
  (`llvm-readelf -l` sur les `.so` extraits de l'APK, chercher `LOAD` et
  vérifier que `p_align` ≥ `0x4000`).

---

## Supprimer un groupe ne supprimait que la ligne `groups` (2026-08-14)

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

## Recoloriage orange/vert de marque (2026-08-14)

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

## Fonctionnalité épingle mise en pause (2026-08-14)

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
- `lib/features/groups/data/datasources/group_supabase_datasource.dart` et
  `group_pinned_providers.dart` : le paramètre `groupId` de `pinItem`/
  `getPinnedItemsStream` (déjà mort avant la pause, jamais alimenté par le
  seul appelant réel) commenté au même moment.

`flutter analyze` propre (aucun avertissement de code mort/import inutilisé)
après ce commentage — les nombreux items `[ ]` ci-dessus datant d'avant le
2026-08-14 portent sur une fonctionnalité désormais désactivée : les
retester n'a de sens qu'après réactivation.

- [ ] **Bascule ÉCO toujours visible** sur une conversation (1:1 et groupe),
  malgré la pause : c'est le point de vigilance le plus probable de casser
  en silence (elle partage la ligne avec le bandeau épinglé disparu).
- [ ] **Aucun bouton Épingler/Détacher** dans le menu contextuel d'un
  message, 1:1 comme groupe.
- [ ] **Aucune ligne « Épinglés »** sur la fiche groupe, même sur un groupe
  qui avait des épingles avant la pause.
- [ ] Build + install pas encore faits sur SM A515F depuis ce changement
  (travail réalisé dans un worktree isolé, dépôt principal occupé par une
  autre session au moment de l'écriture).


## Pseudo (@handle) — ligne d'appel sur son propre profil

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

## Page Notifications à plat + heure sur le seul dernier message d'une rafale (2026-08-23)

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
- [ ] **Accepter / Refuser** d'une demande d'ami : **invérifiable sur ce
  compte**, pour deux raisons cumulées — la seule notification « Nouvelle
  demande d'ami » (13 août) est **lue**, or `_InlineActions` n'est rendu que
  dans `_UnreadCard` ; et `friend_requests` ne contient **aucune** ligne pour
  ce compte, tous statuts confondus, donc `_FriendRequestActions` ne rendrait
  rien même sur une carte non lue (il exige une demande en attente — c'est le
  comportement voulu). Le chemin de code est cependant le même que celui des
  boutons d'événement ci-dessus : même `_UnreadCard`, même `_InlineActions`,
  seul le `case` du switch diffère. À refaire avec une vraie demande d'ami
  entrante.
- [ ] La **pagination au défilement** tient toujours avec beaucoup de lignes
  (le compte d'éléments affichés n'est plus réduit par le regroupement).
- [ ] Les **tranches de temps** restent correctes et ne se répètent pas.

**2. Dans une rafale, seul le dernier message affiche son heure**
([message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)).
La règle existait pour les messages *envoyés* ; elle vaut désormais aussi pour
les messages *reçus* (`showTimeInfo = _isLastInGroup || _metaRevealed`).

⚠️ Ce changement **annule `92326fe` (« chaque bulle porte son heure »)**, poussé
quelques heures plus tôt sur la branche partagée, qui avait retiré ce masquage
en jugeant qu'il se lisait comme un défaut. Le masquage est rétabli à la
demande explicite, et étendu aux messages reçus. Si le rendu déplaît à
l'usage, c'est ce commit-là qu'il faut relire avant de trancher à nouveau.

- [x] **Vérifié SM A515F le 2026-08-23** (build debug depuis le worktree) :
  3 messages envoyés d'affilée dans « Mes notes » (`rafale_A`, `rafale_B`,
  `rafale_C`) → seul `rafale_C` porte « À l'instant · Envoyé ».
- [ ] Le même cas sur des messages **reçus** : **pas vérifié**, aucun message
  reçu disponible sur le compte de test (les deux conversations ne contiennent
  que des messages envoyés ; celle du groupe est en « clé de groupe
  introuvable »). C'est pourtant la moitié de la demande — à refaire avec un
  second compte.
- [x] **Tap vérifié SM A515F le 2026-08-23** sur messages **envoyés** : un tap
  sur la bulle révèle « 05:14 · Envoyé », un second tap la remasque, et le
  double-tap pose toujours la réaction ❤️. Le retard de ~300 ms n'a pas pu être
  jugé (pilotage par `adb`, pas au doigt). Reste à faire sur une bulle **reçue**.
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
- [x] **Rupture de 15 minutes vérifiée SM A515F le 2026-08-23**, deux fois :
  dans « Mes notes », le sondage de 05:18 garde son heure bien qu'il soit suivi
  de `rafale_A` du même expéditeur le même jour ; dans le groupe « Diaspora
  Niger — Canada », 05:55 et 06:30 (35 min) forment deux rafales et la bulle du
  milieu est masquée. Sans la rupture, 05:55 aurait disparu.
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
- [ ] Build + install pas encore faits sur SM A515F depuis ce changement
  (travail réalisé dans un worktree isolé).

---

## ⚠️ L'appareil porte une RELEASE depuis le 2026-08-23

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

### Re-vérifié sur la release, après reconnexion et restauration des clés

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

## Discussion — heure absente/dupliquée sur les bulles média (2026-08-30)

Deux défauts distincts sous le même symptôme rapporté (« l'horodatage
persiste ») :

- **Dupliquée sur les appels — diagnostic initial faux, corrigé après test
  sur appareil.** `CallMessageBubble` affiche sa propre heure inline
  (« Pas de réponse - 23:40 »). Ça ressemblait à un doublon avec
  `_buildMetaRow` posée juste en dessous, donc retirée dans un premier
  temps — mais `MessageBubble.build()` retourne tôt pour
  `widget.message.isCall` (avant le `Column` qui pose `_buildMetaRow`) :
  un appel ne passe **jamais** par cette ligne de méta. La retirer de
  `CallMessageBubble` a fait disparaître l'heure de tous les messages
  d'appel, sans exception — repéré en ouvrant une vraie conversation sur
  le SM A515F (rien sous « Pas de réponse » / « Appel sortant »), écarté
  l'hypothèse d'un APK périmé par un `flutter clean` complet (même
  résultat), puis retrouvé le retour anticipé en relisant `build()`.
  Heure remise dans `call_message_bubble.dart` — c'est la SEULE heure
  qu'un appel affiche, pas un doublon. Le commentaire de `_buildMetaRow`
  documente maintenant cette exception explicitement.
- **Irrécupérable sur toute bulle média.** Le masquage « une heure par
  rafale, tap pour révéler » (`_metaRevealed`) posait son `GestureDetector`
  sur la bulle générique, mais une bulle média (image, vidéo, document,
  audio, note vocale, position, sticker, appel) a **son propre**
  `GestureDetector` pour ouvrir/rappeler, posé plus profond dans l'arbre —
  il gagne toujours l'arène de gestes. Le tap cité comme solution dans
  `874e964` ne fonctionne donc que sur le texte simple ; sur tout le reste,
  un message masqué (pas le dernier de sa rafale) n'avait **aucun** moyen
  pratique de révéler son heure (la bande de repli de 48×16 sous la bulle
  est quasi invisible).

**Suite dans la même session : demande explicite de Salim de retirer le
masquage entièrement** (« plus besoin du système de tap pour afficher,
juste affiche ça tout le temps »). `_metaRevealed`, `_isLastInGroup`,
`_canMaskTime` (le correctif intermédiaire ci-dessus qui limitait le
masquage au texte) et `_onTapRevelerHeure` sont supprimés de
`message_bubble.dart` — `_buildMetaRow` affiche désormais l'heure de
façon inconditionnelle, sur tout type de message, dans une rafale ou non.
Troisième aller-retour sur cette fonctionnalité (`8db5215` l'introduit,
`92326fe`/`dc54282` la retirent, `874e964` la remet ; ce commit la retire
pour de bon) — ne pas la réintroduire sans redemander à Salim.

Couvert par `flutter analyze` (propre) et `message_meta_row_test.dart`
(inchangé, passe toujours — il ne testait déjà que `groupPosition: single`,
qui affichait déjà l'heure). Ce que le test ne peut pas voir :

- [ ] **Rafale de messages texte, images, vidéos, documents, notes vocales,
  positions, stickers** du même expéditeur : chaque bulle doit désormais
  porter son heure, y compris celles qui n'étaient pas le dernier message
  de la rafale.
- [x] **Message d'appel** ✅ **vérifié 2026-08-30 sur SM A515F, deux fois** :
  rafale de 6 appels consécutifs (manqués sortants/entrants + un décroché
  15 s), chacun affiche sa propre heure dans la ligne de statut (« Pas de
  réponse - 23:40 », « Appel terminé - 23:44 »…) — jamais deux fois la
  même, jamais absente. Reconfirmé sur un second `flutter run` tout frais
  (pas un hot reload de la même session) pour écarter un état résiduel.
  Restent non vérifiés sur appareil : appel de groupe, et le cas décliné
  (`isDeclined`, libellé orange).

## ✅ Annuaire des ambassades : Firestore → Supabase, 32 postes chargés (2026-09-07)

L'écran « Ambassades » lisait la collection Firestore `embassies`, **vide
depuis toujours** : la liste n'a jamais rien affiché. L'annuaire passe sur
Supabase (`20260907180000_annuaire_postes_diplomatiques.sql`) avec les 32
postes publiés par diplomatie.gouv.ne, relevés et corrigés le 2026-09-07.

Rien de tout cela n'est vérifié sur appareil — `flutter analyze` ne dit pas si
la liste s'affiche.

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
- [ ] **Mode avion sans jamais avoir chargé** : liste vide, pas de plantage.
      (Non testé : le cache était déjà peuplé, et le vider demande de
      désinstaller — ce qui coûte la session Firebase.)

**`embassy_message_screen.dart` corrigé** (2026-09-08) — `.value` →
`.valueOrNull` sur les lignes 60 et 66, plus deux choses trouvées en ouvrant
le fichier : la chaîne « Message envoyé avec succès! » était en dur alors que
la clé `embassyMessageSent` existait déjà avec exactement ce texte, et
`'Erreur: ${e.toString()}'` aurait affiché l'hôte Supabase dans une SnackBar
(3ᵉ occurrence du motif ce jour).

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

⚠️ **Reste ouvert, même famille** : `administrative_request_screen.dart`
(lignes 103, 107, 141, 145). Non corrigé ici volontairement — l'autre agent
l'avait en cours sur exactement ces lignes, avec le même diagnostic, au moment
où j'ai trouvé le défaut.
- [x] **✅ SM A515F** — Berlin affiche « Autres lignes : +49 30 80 58 96 61 »
      et « Fax : +49 30 80 58 96 62 ».
- [ ] La réserve `data_notes` s'affiche sur les fiches concernées (Abidjan,
      Ankara, Cotonou, Doha, La Havane, Berlin, Copenhague, Rome, Kano,
      Paris, Pretoria, Rabat, Riyad, Washington, Genève, Pékin, Khartoum,
      Le Caire, New York, Paris/UNESCO) et reste lisible en **thème sombre**
      (`surfaceContainerHighest` / `onSurfaceVariant`).
      **✅ SM A515F** — carte « Réserve sur cette fiche » vue sur Berlin et
      La Havane, lisible en sombre.
- [x] **✅ SM A515F** — « Y aller » grisé sur Berlin et La Havane. Avant ce
      correctif, `toEntity()` remplaçait une latitude nulle par `0.0`, le
      bouton était actif sur les 32 postes et ouvrait le golfe de Guinée.
- [x] **✅ SM A515F** — « La Havane, Cuba », pas de virgule orpheline.
- [ ] Admin : vérifier / suspendre un poste (`admin_embassy_verification_screen`)
      écrit bien dans Supabase, et l'échec RLS non-admin remonte un message
      au lieu d'un faux succès.
- [ ] Admin : créer un poste (`admin_create_embassy_screen`) le fait
      apparaître dans la liste — l'écran écrivait dans Firestore, donc dans
      une collection que plus personne ne lit.

**Position douteuse : « Y aller » grisé** (2026-09-08, ✅ vérifié sur Pixel).
Copenhague portait des coordonnées ET une réserve disant qu'elles sont à 5 km
d'une autre source — le bouton restait pourtant actif et orange, comme sur une
fiche sûre. `latitude != null` ne suffisait plus à décider : « on a une
position » et « on lui fait confiance » sont deux choses différentes. Colonne
`position_uncertain` (migration `20260908183500`), getter `canNavigate`, et les
**deux** boutons d'itinéraire s'y réfèrent — celui de la fiche et celui de la
carte de liste, qui disparaît complètement. Verrouillé par
`test/features/embassies/position_douteuse_test.dart`.

Bilan : 29 fiches navigables, 3 non — Djeddah et Khartoum faute de
coordonnées, Copenhague faute de confiance.

**Épingle distincte sur la carte** (2026-09-08) — la carte plaçait toujours une
épingle ordinaire pour Copenhague. Elle y reste (la retirer ferait disparaître
l'ambassade) mais se signale : **bordure discontinue et ambre** au lieu du
cercle bleu plein, convention cartographique du tracé approximatif.

⚠ Piège évité : la clé de cache des épingles était `embassy_circular_$isSelected`,
**partagée par toutes les ambassades**. Sans y ajouter le drapeau, la première
épingle dessinée aurait été resservie aux 29 autres.

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

**Trois défauts trouvés PAR ce test appareil**, invisibles à `flutter analyze` :

1. **Ville doublée** — « Machnower Str. 24, **Berlin, Berlin**, Allemagne ».
   Les adresses postales portent la ville, que la fiche rajoutait. Corrigé par
   `_formatLocation` (n'ajoute un fragment que s'il n'est pas déjà présent).
   **✅ vérifié** : Pretoria affiche « … Hatfield, Pretoria, Afrique du Sud »,
   une seule fois. Restent Rome/Roma, Pékin/Beijing et Copenhague/København,
   que la comparaison ne peut pas reconnaître — traités par la migration
   `20260907203000`, **pas encore appliquée** (elle attend que l'autre agent
   pousse `20260907200000`, appliquée en base mais absente du dépôt).
2. **`AsyncValue.value` relance l'erreur en Riverpod 2** (c'est `valueOrNull`
   qui rend `null`). Hors ligne, le flux du profil échoue, l'exception
   traversait tout `embassiesListProvider`, et l'écran affichait la trace
   brute — **avec l'hôte Supabase et l'UID de l'usager en clair, plein
   écran**. Le dépôt n'était jamais appelé, donc le cache jamais lu.
3. **L'annuaire était conditionné à une session.** Hors ligne, la session
   Supabase ne peut plus se rafraîchir, l'usager est vu comme déconnecté, et
   `if (user == null) return []` court-circuitait tout — 32 fiches en cache
   sur l'appareil, écran vide. Or la table est en lecture publique par
   conception : l'annuaire ne dépend plus d'une session.

**Quatre défauts d'affichage de la fiche, trouvés en regardant l'écran**
(2026-09-08, Pixel, thème sombre) — aucun ne sort de `flutter analyze`, et
aucun ne lève de `RenderFlex overflowed` :

1. **Onglet actif illisible.** `TabBar(labelColor: Colors.black87)` était figé :
   noir sur fond noir en thème sombre. Même famille que les 48 jetons clairs
   corrigés le 2026-08-04. Passé aux jetons `colorScheme`.
2. **Titre tronqué** — « Ambassade du Niger … ». Deux causes cumulées : les
   noms officiels du seed sont longs (36 caractères), et `FlexibleSpaceBar`
   agrandit encore le titre de 1,5× quand l'en-tête est déplié. Deux lignes,
   facteur ramené à 1,25.
3. **200 px de bandeau vide.** `expandedHeight: 200` réserve la place d'une
   image de couverture, or `imageUrl` est nul sur les 32 fiches ; le gabarit
   (`primaryColor` à 10 %, icône à 50 %) disparaissait sous le dégradé noir.
   Ramené à 140 px avec des couleurs réellement visibles.
4. **Icône du gabarit sous la barre d'état**, puis par-dessus le titre :
   le bandeau s'étend sous le statut, il faut décaler de
   `MediaQuery.paddingOf(context).top`.

✅ Vérifié après correction sur Pixel (capture `fiche_finale.png`).

**Deux troncatures de plus sur l'écran de LISTE** (2026-09-08, Pixel) —
distinctes des quatre ci-dessus, qui portaient sur la fiche :

5. **« Ambassades & consul… »** — le titre de l'AppBar. `DesignTitle` est une
   brique partagée du design kit, donc corrigé au point d'appel par un
   `FittedBox(fit: scaleDown)` plutôt qu'en touchant au kit. À noter : ça
   rentrait sur le SM A515F et débordait sur le Pixel — la police système est
   plus large. Un écran validé sur un seul appareil ne prouve pas grand-chose.
6. **« Rechercher par nom, pays o… »** — invite du champ de recherche,
   raccourcie en « Nom, pays ou ville » ; l'icône loupe dit déjà qu'on cherche.

Les deux chaînes étaient en **français figé** dans un écran par ailleurs
traduit : passées en l10n au passage (`embassiesAndConsulates` existait déjà,
`embassySearchHint` ajoutée).

✅ Vérifié sur Pixel (capture `liste_corrigee.png`) **et sur SM A515F**
(`a515f_liste.png`, `a515f_havane.png`) — les six correctifs d'affichage
tiennent sur les deux appareils, polices système différentes comprises.

**Découvert en repassant sur le SM A515F** : l'autre agent a **géocodé 21 des
32 fiches** le 2026-09-08 à 09:51. Conséquence directe sur le correctif n° 4
du lot précédent (`latitude ?? 0.0`) — il ne s'agit plus d'un bouton
uniformément grisé, mais d'une vraie distinction :

- les **21 fiches géocodées** affichent « Itinéraire » actif, et la carte
  « Le plus proche · 792 km — Ambassade du Niger aux États-Unis » apparaît en
  tête de liste (compte situé à Montréal) ;
- les **11 sans coordonnées** (Addis-Abeba, Djeddah, Doha, Dubaï, Khartoum,
  Koweït, La Havane, Le Caire, New Delhi, Pékin, Rabat) gardent « Y aller »
  grisé.

Sans le correctif, les 32 auraient toutes pointé sur (0, 0). Vérifié des deux
côtés : La Havane grisée, Washington active.

### Géocodage des 11 restantes : ce que j'ai conclu trop vite (2026-09-08)

> ⚠️ **Ce constat était faux dans sa portée.** Il concluait « aucune source
> publique ne les contient » et « ne pas refaire sans source nouvelle ». Le
> même jour, l'autre agent en a géocodé **neuf sur onze** avec la Geocoding API
> de Google (migration `20260908150000_coordonnees_postes_google.sql`) — il ne
> reste que Djeddah et Khartoum. **30 des 32 postes ont désormais des
> coordonnées.**
>
> **Ce qui m'a manqué n'est pas une source, c'est une reformulation.** Je
> cherchais par *adresse postale*, en français ; il a cherché par **nom du
> poste, dans la langue du pays d'accueil** — Le Caire ne répond qu'à l'arabe,
> La Havane qu'à l'espagnol. Et j'avais écarté la piste payante en reprenant
> l'argument du script d'origine (« disproportionné pour 32 lignes ») sans le
> réexaminer, alors que c'était le seul verrou réel.
>
> **La leçon à garder** : « la source ne contient pas la donnée » et « ma
> requête ne la trouve pas » sont deux constats différents. Avant de conclure
> à l'absence, faire varier la formulation — langue locale, nom de
> l'institution plutôt qu'adresse — et rouvrir explicitement les pistes
> écartées pour des raisons de coût.
>
> Trois résultats de Google recoupent l'adresse du ministère, ce qui les
> confirme mutuellement : Le Caire (101 Al Haram = avenue des Pyramides),
> Rabat (Av. Al Haour) et Dubaï — où « Abu Hail » explique le « Abau Hain
> Street » que je n'arrivais pas à situer.

Ce qui suit reste exact, et documente ce que les sources **gratuites**
contiennent — utile si l'API payante venait à être coupée.

**OpenStreetMap n'a aucun nœud** pour le poste du Niger dans 10 de ces 11
villes — vérifié en interrogeant Overpass sur `country=NE` puis, plus large,
par nom : 36 nœuds dans le monde, aucun à moins de 80 km de Djeddah, Doha,
Dubaï, Khartoum, Koweït, La Havane, Le Caire, New Delhi, Pékin ni Rabat. La
seule exception est **Addis-Abeba**, et c'est la *résidence de l'ambassadeur*,
que le script écarte à raison : envoyer un usager au domicile privé plutôt
qu'à la chancellerie est pire que de ne rien afficher.

**Le géocodage d'adresse échoue aussi**, y compris en reformulant en anglais
et en arabe. Ce que Nominatim renvoie n'est jamais le poste :

| Ville | Meilleur résultat obtenu | Verdict |
|---|---|---|
| Le Caire | « Cairo Pyramids Hotel », puis une maison au 101 rue des Pyramides | un hôtel ; le n° 101 est plausible mais invérifiable |
| Rabat | un **arrêt de bus** à Hay Riad | non |
| Dubaï | une salle à Bur Dubaï | mauvais quartier (l'adresse dit Deira) |
| Addis-Abeba, Koweït | centroïdes de district | non |
| New Delhi, Pékin | rien | — |

Et quatre postes n'ont **rien à géocoder** : Doha et La Havane ne publient
aucune adresse, Djeddah et Khartoum n'ont qu'une boîte postale — qui ne
désigne aucun bâtiment.

**Écrire un de ces points serait un défaut, pas un progrès** : « Y aller »
deviendrait actif et ouvrirait la carte au mauvais endroit, la carte « Le plus
proche » calculerait une distance depuis un point faux, et rien à l'écran ne
distinguerait cette coordonnée d'une vraie. C'est exactement ce que le refus
du centre-ville, dans `tools/geocode_postes_diplomatiques.mjs`, protège.

Voies qui marcheraient vraiment : demander la position aux postes eux-mêmes
(la donnée leur appartient), ou la relever une fois puis la contribuer à OSM —
ce qui profiterait aussi à tout le monde.

**État au 2026-09-08 après le géocodage Google** — deux postes seulement
restent sans coordonnées, et pour eux la demande par courriel garde tout son
sens (`docs/ops/DEMANDE_POSITIONS_POSTES.md`, §2 et §5) :

- **Djeddah** : le seul résultat est à 22 km au nord du centre et n'est pas
  typé `embassy` — trop faible pour être écrit en base.
- **Khartoum** : Google ne connaît aucun lieu d'ambassade dans la ville.

Et deux questions se sont **ouvertes** avec ce géocodage, à trancher :

- **Copenhague** : OSM place l'ambassade à Rosbækvej/Østerbro, l'annuaire
  publie « Niels Juels Gade 5 » — **5,1 km d'écart**, rien pour départager.
  Écrire à `ambassade@niger.dk`.
- **Abuja** : le point a été déplacé de Diplomatic Drive à Maitama, où
  l'annuaire et Google se rejoignent. Une confirmation serait prudente —
  `embniger@yahoo.fr`.

Contribuer les positions confirmées à OpenStreetMap reste souhaitable : le
script gratuit les retrouverait seul, et l'information servirait au-delà de
cette application.

**Migration appliquée en production le 2026-09-07** (`supabase db push
--linked`). Vérifié par l'API : 32 lignes en base — 25 ambassades, 4 consulats,
2 missions permanentes, 1 délégation ; 27 fiches avec fax, 20 avec réserve.
La liste ne devrait donc plus être vide.

Deux découvertes du push, à connaître avant de toucher à cette table :

- **La table `embassies` existait déjà en production**, créée hors du dossier
  `supabase/migrations` — aucun fichier du dépôt ne la mentionnait. D'où la
  forme de la migration (création *puis* `ADD COLUMN IF NOT EXISTS`). La
  colonne du type de poste s'appelle `type`, pas `post_type`.
- **Elle n'avait aucune politique RLS et RLS n'y était pas activé**, alors que
  `anon` dispose des privilèges d'écriture au niveau table : n'importe qui
  pouvait écrire dans l'annuaire diplomatique officiel. Refermé et vérifié —
  l'INSERT anonyme renvoie désormais 401/42501.

---

## Second appareil : Pixel 10 Pro XL (2026-09-08)

Un **Pixel 10 Pro XL** (`58221FDCQ0085Z`) est apparu à côté du SM A515F. Il
porte le compte **Salim L.**, qui est **administrateur** — donc complémentaire
du SM A515F (compte « Sim A », non-admin, sans pays renseigné).

Utile : les deux branches du filtre de juridiction se vérifient enfin
séparément. Sur l'annuaire, **32 fiches sur le Pixel** (contournement admin)
contre **30 sur le SM A515F** (Genève et New York masqués faute de pays connu).

⚠️ Deux pièges rencontrés :
- `pm path` a renvoyé un chemin `/data/app/…` pour une app **pas installée** —
  un reliquat. Vérifier avec `pm list packages --user 0`, pas avec `pm path`.
- Le compte y étant réel (pas un compte de test), toute action sortante doit
  être faite hors ligne ou pas du tout.

---

## Postes diplomatiques sur la carte : 30 pins sur 32 (2026-09-08)

Les 32 fiches importées le 2026-09-07 sont arrivées **sans latitude ni
longitude** : `diplomatie.gouv.ne` ne publie que des adresses postales, dont
huit sont de simples boîtes postales. Depuis l'import, aucun poste n'a jamais
eu de pin — `map_screen.dart` saute toute fiche sans coordonnées, et le bouton
« voir sur la carte » du détail est masqué par `hasCoordinates`.

Deux migrations, dans cet ordre. `20260908120000_coordonnees_postes_diplomatiques.sql`
place 21 postes avec les seules sources ouvertes : 19 relevés dans
OpenStreetMap (au bâtiment), 2 par géocodage de l'adresse officielle
(Paris/UNESCO et Kano). `20260908150000_coordonnees_postes_google.sql` en
ajoute 9 via la Geocoding API de Google — activée pour l'occasion — et
**corrige Abuja**, dont le pin était à 5,7 km. Le script est rejouable :
`tools/geocode_postes_diplomatiques.mjs`.

Ce qui a débloqué les 9 : chercher le poste **par son nom, dans la langue du
pays d'accueil**. Le Caire ne répond qu'à l'arabe, La Havane qu'à l'espagnol,
l'anglais couvre le reste — le français presque rien. Et le nom vaut mieux que
l'adresse : à Addis-Abeba, « Kirkos Sub-city, Kebele 02/03 » rend un point
quelconque du quartier, à 5,7 km du lieu que Google connaît comme une
ambassade.

- [ ] **Les pins bleus d'ambassade apparaissent** sur la carte principale, à
      côté des membres — vérifier au moins un poste (Paris, Cotonou, Abuja
      selon la position du testeur), et que la bascule « Ambassades » du menu
      de filtres les fait bien disparaître/réapparaître.
- [ ] **Le tap sur un pin** ouvre la fiche flottante (nom, adresse, tél, mail,
      services) et « Voir la fiche complète » mène au détail.
- [x] **Le bouton « Y aller » du détail** (et « Itinéraire » sur la carte de
      liste) est actif sur les postes placés, absent sur les autres.
      *Vérifié sur Pixel 10 Pro XL le 2026-09-08, sans réinstaller l'app :
      les coordonnées viennent de la base, l'APK en place suffit. Alger →
      « Appeler / Itinéraire / Détails » et « Y aller » actif sur la fiche ;
      Le Caire → « Appeler / Détails » seulement. Revérifié après la seconde
      migration : Le Caire affiche désormais « Itinéraire » et remonte de la
      zone « Autres » à « Afrique ».*
- [ ] **Écart à confirmer auprès du poste** : Copenhague (OSM place
      l'ambassade Rosbaeksvej/Østerbro, l'annuaire publie « Niels Juels Gade
      5 » — 5,1 km) et Dakar (OSM « Voie de Dégagement Nord, Point E » contre
      « 8 avenue Léopold Sédar Senghor » — 5,2 km). Position OSM retenue : le
      nœud porte le nom du poste. À trancher par un appel ou une photo.
- [x] **Un poste sans pin reste visible dans la liste**, sous « Autres », avec
      son adresse — vu sur le Pixel le 2026-09-08, avant la seconde migration.
      Aucun ne tombe au point (0, 0) : le modèle ne convertit plus `null` en
      `0.0`.
- [ ] **2 postes restent sans pin, et c'est délibéré.** Khartoum : aucune
      source ne le connaît. Djeddah : le seul résultat (Al Kausar, 22 km au
      nord du centre) n'est pas typé `embassy` par Google, contrairement aux
      neuf autres — une position fausse enverrait l'usager à 22 km. À
      confirmer auprès des deux postes.
- [ ] **Abuja a bougé de 5,7 km** : le nœud OSM (« 305 Diplomatic Drive »,
      quartier des affaires) est contredit par l'annuaire officiel
      (« Maitama District ») **et** par le lieu typé `embassy` de Google, tous
      deux à Maitama. Vérifier que le pin d'Abuja est bien à Maitama.
- [x] **Dakar et Pretoria : divergence tranchée en faveur d'OSM.** Leur adresse
      publiée tombait à 5,2 km et 2,4 km du nœud ; Google y place une ambassade
      à 7 m et 14 m du nœud. C'est l'annuaire officiel qui est en retard.
- [ ] **Copenhague reste ouvert** : nœud OSM (Rosbæksvej, Østerbro) contre
      adresse publiée (Niels Juels Gade 5), 5,1 km, et Google n'y connaît aucun
      lieu typé `embassy` pour départager. Position OSM retenue en attendant.
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
- [ ] ⚠️ **En anglais**, le repli des postes sans coordonnées valait
      « Others » alors que l'écran n'affiche que les zones de sa liste
      française : **tout poste sans coordonnées disparaissait de l'annuaire**
      (le compteur, lui, les comptait). Corrigé par une constante partagée,
      mais **vérifié en français seulement** — à revoir en basculant la langue
      du téléphone.
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

⚠️ Découverte au passage, non corrigée : **aucune API Google Maps n'est activée
sur le projet Cloud** hormis le SDK de la carte. `Geocoding API`, `Places API`
et `Places API (New)` répondent toutes `REQUEST_DENIED` /
`SERVICE_DISABLED` — donc `PlaceSearchService` (barre de recherche de la carte,
sélecteur de position des entreprises et du partage de lieu) tombe **toujours**
sur son repli `geocoding` côté appareil, sans que rien ne le signale. À vérifier
sur appareil : la recherche de lieu renvoie-t-elle des résultats utilisables ?

## Réglages — ligne « Devise d'affichage » mise en commentaire (2026-09-08)

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

## ⬜ Heure et accusé sur tous les messages, bascule supprimée (2026-08-23)

[message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)
`_buildMetaRow` : le regroupement visuel des rafales ne masque plus rien de la
ligne méta. Chaque message — envoyé comme reçu, isolé comme au milieu d'une
rafale — affiche son heure et, côté envoyé, son accusé. Le champ
`_metaRevealed`, le getter `_isLastInGroup` et la zone de tap invisible de
48×16 px sous la bulle ont été supprimés.

Deux raisons : la zone tapable n'avait aucune affordance (indevinable), et
elle masquait aussi le libellé « Échec · Réessayer » d'un envoi raté qui
n'était pas le dernier de sa rafale — le seul chemin pour relancer l'envoi.

⚠️ **Cette note a bien failli disparaître.** Le code est en place depuis le
2026-08-23, mais sa justification vivait dans un commit resté sur une branche
locale (`claude/heure-partout-base-1744c25`) : le comportement, lui, a été
refait autrement sur `wip-jules`, sans reprendre l'explication. Récupérée le
2026-09-09 juste avant la suppression de cette branche. Vérifié à cette
occasion sur le fichier courant : plus une seule occurrence de `_metaRevealed`
ni de `_isLastInGroup`, et l'appel `Text(_formatTime(...))` de `_buildMetaRow`
n'est enveloppé d'aucune condition.

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

## ⬜ Journalisation : deux fuites en release et la garde du LoggerService (2026-09-09)

`debugPrint` écrit **aussi en release** — la doc du SDK le dit noir sur blanc
(`packages/flutter/lib/src/foundation/print.dart:37` : « logs to console even
in release mode », avec la convention de l'entourer d'un `kDebugMode`). Le
dépôt compte 922 appels actifs, dont 12 gardés. Rien de tout ça ne se voit en
développement : ça se voit sur l'APK de production, avec un simple `adb logcat`.

Trois corrections ici ; le reste du chantier (~900 appels) reste ouvert.

[native_call_service.dart](lib/core/services/native_call_service.dart)
`actionDidUpdateDevicePushTokenVoip` imprimait la **valeur complète du jeton
VoIP**. Le log garde son intérêt (savoir que la mise à jour a eu lieu), la
valeur part.

[message_provider.dart](lib/features/messages/presentation/providers/message_provider.dart)
`sendLocation` imprimait `lat=` / `lng=` du partage de position — de la donnée
personnelle, dans les logs. **Deux fois** : à la pose du message optimiste
(l. 1327) et à la confirmation d'envoi (l. 1350). La seconde s'était fait
oublier lors du repérage — un `grep | head -25` avait mangé la ligne, et
corriger une seule des deux n'aurait rien fermé du tout.

[message_remote_datasource.dart:2180](lib/features/messages/data/datasources/message_remote_datasource.dart:2180)
Même `lat=` / `lng=`, troisième occurrence, trouvée encore après — celle-ci
écrivait `${data['latitude']}`, une forme que deux balayages successifs
avaient manquée parce qu'ils cherchaient un identifiant (`$latitude`), pas un
accès map. **Chemin non actif** : la messagerie passe par
`MessageSupabaseDataSource`, et `MessageRemoteDataSourceImpl` n'est instancié
que par la recherche, qui n'envoie jamais de position. Corrigé quand même —
la ligne se réveillerait au premier recâblage.

⚠️ **La leçon d'outillage** : ne jamais conclure un audit de logs sur un motif
qui suppose la forme de l'interpolation. Le balayage qui a fini par tout
trouver cherche dans le **texte** du message (`lat=`, `token`, `phone`…),
indépendamment de la façon dont la valeur est injectée.

[logger_service.dart](lib/core/services/logger_service.dart)
Le garde `kDebugMode` ne couvrait que le niveau `debug` : `i`, `w` et `e`
parlaient en release. Il couvre maintenant `_log` en entier, tous niveaux.

**Suite (2026-09-09) — les erreurs remontent maintenant à Crashlytics.**
Le garde laissait les 9 appels `LoggerService.w/e` (carte, publication de
position, profil) totalement muets en production. `_log` remonte désormais le
**seul** niveau `error` à `FirebaseCrashlytics.recordError(..., fatal: false)`,
avec `reason` = le message. Les autres niveaux restent debug-only.

⚠️ **Correction d'un diagnostic que j'avais donné de travers** : j'avais désigné
`error_handler.dart:185` comme « la bonne porte ». C'est faux — `logError` de
`ErrorHandler` n'est **appelé nulle part** dans `lib/` (`grep 'logError('` ne
remonte que sa propre déclaration et l'homonyme d'`AnalyticsService`).
Décommenter cette ligne seule n'aurait rien changé au runtime. Elle est
décommentée quand même (le jour où la méthode sert, elle sera correcte), mais
ce qui rétablit vraiment la traçabilité, c'est le branchement dans
`LoggerService`.

Deux détails de mise en œuvre : l'appel est encadré d'un `try/catch` — un
journal ne doit jamais faire tomber l'appelant si Firebase n'est pas encore
initialisé — et il n'y a pas de `kReleaseMode` explicite, la branche étant
déjà celle du `!kDebugMode`.

- [ ] **Aucune régression d'appel** : passer un appel 1:1, sonnerie et bulle
  d'appel comme avant. Le jeton VoIP est toujours propagé à
  `onVoipTokenUpdated` — seul son affichage a changé — mais c'est le chemin
  iOS/CallKit, donc à revalider le jour où un appareil iOS est disponible.
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

---

## ⬜ Les ~920 `debugPrint` restants neutralisés en release (2026-09-09)

Suite directe de l'entrée ci-dessus. Après les trois fuites nommées, il restait
**922 appels actifs dans 115 fichiers**, dont 12 gardés — tous bavards dans
logcat sur un APK de production (734 sous `core/services`, dont 140 pour le
seul `webrtc_service.dart`).

[main.dart](lib/main.dart) — une ligne, en tête de `main()` :

```dart
if (kReleaseMode) {
  debugPrint = (String? message, {int? wrapWidth}) {};
}
```

`debugPrint` est une **variable** du SDK (`DebugPrintCallback debugPrint =
debugPrintThrottled;`), pas une fonction : la réassigner neutralise les 922
appels d'un coup, sans en toucher un seul.

Pourquoi pas les 922 réécritures : sur une branche partagée où l'autre agent
travaille en parallèle, un diff de 922 lignes sur 115 fichiers lui coûte des
conflits pour un résultat identique. Même raisonnement que l'interdiction de
`dart format` dans le CLAUDE.md.

⚠️ **Ce que ça ne fait pas.** Les chaînes restent dans le binaire de l'APK et
leurs arguments sont toujours évalués — seule la **sortie** disparaît. Un log
qui ne doit pas exister du tout (valeur de jeton, coordonnées) se supprime à la
source ; c'est pour ça que les trois fuites ont été traitées séparément avant.
Le mode **profile** n'est pas couvert (`kReleaseMode` y est faux), volontairement :
un APK de profilage ne se distribue pas.

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
- [ ] **Rien n'a changé en debug** : `flutter run` et vérifier que les logs
  habituels sortent toujours (la neutralisation est derrière `kReleaseMode`).
  Non vérifié — la session n'a construit que des release.
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
- [ ] **Appel WebRTC sur la release** : non parcouru. `webrtc_service.dart`
  porte 140 `debugPrint` à lui seul — c'est le plus gros bloc encore non
  observé.
- [ ] **Carte avec partage de position actif** : l'onglet Carte a bien été
  ouvert, mais le compte est en « Mode privé activé » : l'écran s'arrête sur
  sa carte d'invitation (et la liste par ville, qui charge bien les ambassades).
  Le rendu cartographique et les positions temps réel des membres — donc les
  logs de `location_publisher_service` et du canal realtime — n'ont pas été
  exercés.

---

## ⬜ Second verrou : `print` brut et paquets tiers (2026-09-09)

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

- [ ] **Logcat toujours muet après ce changement** : refaire la mesure de
  l'entrée précédente sur un APK release reconstruit — démarrage à froid puis
  usage réel, `grep " flutter "` doit rester à zéro hors les 2 lignes du moteur
  natif au démarrage.
- [ ] **Le démarrage n'a pas régressé** : c'est le point sensible. `main()` a
  été restructuré (corps déplacé dans `_demarrer`, exécuté dans une zone).
  Vérifier que l'app démarre, que la session est restaurée et que la messagerie
  charge — une erreur de zone se verrait immédiatement au lancement.

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
