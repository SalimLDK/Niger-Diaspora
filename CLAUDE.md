# Instructions du projet

## Branche partagée : travailler dans un worktree

Deux agents travaillent en parallèle sur `wip-jules-…`. **Le dépôt principal
n'est pas à vous.** Y travailler directement a coûté, en une seule journée :

- trois livraisons emportées dans des commits sans rapport (un correctif de
  débordement livré sous « garde Officiel appliquée », une note de traçabilité
  sous « revert RTDB ») — parce que l'autre agent committe l'index tel qu'il
  le trouve ;
- deux correctifs bloqués des heures sur un fichier tenu par du WIP non
  committé, impossible à stager sans emporter le travail d'autrui.

Un worktree a **son propre index et son propre arbre** : les deux problèmes
disparaissent.

```bash
git worktree add -b claude/<sujet> .claude/worktrees/<sujet> HEAD
W=.claude/worktrees/<sujet>
cp .env "$W/"                                  # ignorés par git, requis
cp functions/.env "$W/functions/"
mkdir -p "$W/supabase/.temp" && cp supabase/.temp/* "$W/supabase/.temp/"
cp android/key.properties "$W/android/"        # uniquement pour un build release
cp android/app/diaspo-niger-release.jks "$W/android/app/"
```

Sans le `.env` copié, toute commande Flutter échoue sur l'asset manquant.
Compter ~4 min au premier `flutter analyze` (résolution des paquets).

**Faire `flutter pub get` dans le worktree AVANT le premier `analyze`, et ne
pas y lancer `--no-pub` tant qu'il n'a pas son propre `.dart_tool`.** Le
worktree vit **dans** le dépôt principal (`.claude/worktrees/…`) : sans
`.dart_tool` à lui, l'analyseur remonte l'arborescence et trouve celui du
dépôt principal. `package:diaspo_niger/…` se résout alors vers le `lib/` du
**dépôt principal**, qui est sur un autre commit. Constaté le 2026-09-15, et
le diagnostic ment complètement :

- 23 erreurs, toutes dans des fichiers qu'on n'a pas touchés ;
- une méthode livrée la veille par l'autre agent annoncée « undefined »,
  alors qu'elle est bien dans le fichier du worktree — c'est la copie du
  dépôt principal, en retard d'un commit, qui était lue ;
- et `AppLocalizations` déclaré incompatible avec lui-même, les deux chemins
  absolus (worktree et dépôt principal) apparaissant dans le même message.

Après `flutter pub get` : « No issues found ». Aucune de ces 23 erreurs
n'existait.

**Même piège pour Node, et il ment autant** : faire `cd functions && npm
install` dans le worktree avant d'y lancer un banc ou un lint qui charge
`functions/index.js`. Sans `functions/node_modules` à lui, Node remonte
l'arborescence — le worktree vit **dans** le dépôt principal — et charge le
`firebase-functions` de la **racine** du dépôt principal (v7, API v2) au lieu
du 4.9 déclaré par `functions/package.json` (API v1). Constaté le 2026-09-21 :
l'erreur tombe sur `functions.firestore.document is not a function`, à la
ligne 366, dans un fichier qu'on n'a pas touché — rien n'indique que c'est une
histoire de résolution de modules. `node -p "require.resolve('firebase-functions')"`
donne la réponse en une ligne : le chemin rendu n'est pas celui du worktree.

`supabase/.temp/` porte le lien vers le projet distant (ignoré par git,
`.gitignore:80`). Sans lui, toute commande `--linked` — `db query`, `db push`,
`migration list` — échoue sur « Cannot find project ref. Have you run supabase
link? ». **Copier le dossier entier, pas seulement `project-ref`** : avec ce
seul fichier, l'erreur change sans que rien ne marche mieux, en « IPv6 is not
supported on your current network » — c'est `pooler-url` qui manque, et
l'invite à relancer `supabase link` est trompeuse, le lien n'ayant rien perdu.

Les deux derniers ne servent qu'à `flutter build apk --release`, mais leur
absence ne se voit qu'**au tout dernier moment** : `signingConfigs.release` lit
`key.properties` derrière un `if (storeFileVal != null)`, donc un fichier
manquant ne fait pas échouer la configuration — la compilation entière se
déroule, et c'est `:app:packageRelease` qui tombe sur
« SigningConfig "release" is missing required property "storeFile" ».
25 minutes de build perdues le 2026-08-06. Les deux fichiers sont couverts par
`android/.gitignore` (`key.properties`, `**/*.jks`) : les copier ne risque pas
de les faire committer.

**⚠️ Le worktree isole l'arbre, PAS le cache Gradle. Ne jamais builder à deux.**
`~/.gradle/caches/8.13/transforms` est commun à tous les worktrees et à tous
les projets de la machine : avoir chacun son `build/` n'en protège en rien.
Deux builds Gradle simultanés y laissent des `metadata.bin` tronqués. Constaté
le 2026-09-14, et le diagnostic trompe à trois reprises :

- l'échec tombe sur `:app:mergeExtDexDebug`, « Could not read workspace
  metadata from …/metadata.bin », **99 fois** — ça ressemble à un cache à
  vider, pas à une course ; seul `--stacktrace` donne la vraie cause,
  `KryoException: Buffer underflow`, c'est-à-dire des écritures interrompues ;
- **la taille ne trahit rien** : un `metadata.bin` corrompu fait 110-112
  octets, comme un sain. Inutile de chercher des fichiers vides ;
- **supprimer les dossiers ne suffit pas** — Gradle cite encore les mêmes
  hashs, l'état vit dans le démon. `cd android && ./gradlew --stop`, puis
  rebuilder.

Avant de lancer un build, vérifier qu'aucun autre n'est en cours — un wrapper
`gradlew` en vie suffit à le dire :

```powershell
Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='dart.exe'" |
  Where-Object { $_.CommandLine -match 'gradlew|build apk' } |
  Select-Object ProcessId, CreationDate, CommandLine
```

Le chemin du worktree — donc à qui est le build — n'apparaît que dans la ligne
du **wrapper java**, au classpath du `gradle-wrapper.jar`. Le `dart.exe` ne le
porte pas : tombé sur lui seul, on ne sait pas de qui il est.

Un **démon** survivant (né avec un build précédent) est normal et n'est pas un
build en cours ; c'est le wrapper qu'on regarde.

Et si vous coupez un build : **arrêter la tâche ne tue pas le build.** Le
2026-09-14, un `TaskStop` sur un `flutter build apk --release` lancé en arrière-plan
a rendu la main en annonçant l'arrêt, pendant que le wrapper `gradlew` et le
`flutter build` continuaient, orphelins, à écrire dans le cache partagé. Tuer
les PID à la main, les vérifier morts, puis `./gradlew --stop` + `flutter
clean` avant de reconstruire — un build interrompu laisse un cache incrémental
partiel, et le suivant produit un APK périmé **en annonçant un succès**.

Pour livrer, pousser directement sur la branche partagée :

```bash
git push origin claude/<sujet>:wip-jules-2025-12-29T23-58-34-776Z
```

**Avant de livrer sur un fichier que l'autre agent a en cours**, vérifier que
vos zones ne se chevauchent pas :

```bash
git -C <depot-principal> diff -U0 -- <fichier> | grep '^@@'
```

Si elles se chevauchent, ne pas livrer : le conflit sera pour lui, au milieu
de son travail. Consigner dans `TESTS_APPAREIL_A_FAIRE.md` et attendre.

**`git rebase` est refusé par le classificateur de permissions de Claude Code
dans ce dépôt** (bloqué avant même que git ne s'exécute). **Depuis le
2026-09-14, `git merge` l'est aussi depuis l'outil Bash** — motif
`[Out-of-Place Publication]`. La même commande, mot pour mot, **passe depuis
l'outil PowerShell** : même worktree, même dépôt, même branche. C'est la seule
voie de sortie connue, et elle est indispensable — sans elle la boucle
ci-dessous se bloque à son deuxième pas.

Pour intégrer les commits distants : stasher son propre WIP de
façon **ciblée** (jamais `-A` sur tout l'index — voir la règle
`--` ci-dessus), `git merge origin/<branche> --no-edit` **par l'outil
PowerShell**, résoudre les conflits à la main, puis `git stash pop`. `git
push` peut se faire rejeter une seconde fois si l'autre agent pousse pendant
l'opération : refaire fetch/merge/push jusqu'à ce que ça passe, jamais de
force. Compter deux tours plutôt qu'un — le 2026-09-14 le tip a bougé entre
le merge et le push, deux fois de suite.

Le conflit à attendre à chaque merge est `TESTS_APPAREIL_A_FAIRE.md`, et il
est bénin : il ne porte que sur la **ligne de compteurs du sommaire**, qui est
générée. Prendre un côté au hasard, puis relancer
`python tools/index_tests_appareil.py` — il recompte depuis le contenu réel,
et les cases cochées d'en face comme les entrées ajoutées des deux côtés se
retrouvent dans le total. Ne jamais résoudre cette ligne à la main.

## Rust dans le build : `rust/` (OpenMLS) compilé par cargokit

Depuis la phase 2 du plan MLS (2026-09-15), l'app embarque un crate Rust
(`rust/`, moteur OpenMLS) relié par Flutter Rust Bridge. **Tout `flutter
build` / `flutter run` compile ce crate** via `rust_builder/` (cargokit, dans
Gradle et Xcode). Ce que ça impose :

- **Rust sur le poste** : `rustup` (installé par winget le 2026-09-14),
  cibles `aarch64-linux-android`, `armv7-linux-androideabi`,
  `x86_64-linux-android`. Sous Git Bash, `~/.cargo/bin` n'est pas dans le
  PATH : `export PATH="$HOME/.cargo/bin:$PATH"` **avant** `flutter build`,
  sinon cargokit échoue dans Gradle avec un message qui parle de `cargo`
  introuvable. Compter ~6 min de plus au premier build (trois ABI), puis le
  cache de cargokit prend le relais.
- **Regénérer les liaisons** après tout changement de `rust/src/api/` :

  ```bash
  flutter_rust_bridge_codegen generate --no-build-runner --no-dart-format
  ```

  Les deux drapeaux ne sont pas optionnels. Sans `--no-build-runner`, le
  générateur lance `build_runner` sur tout le projet et a **supprimé 129
  `.g.dart` suivis par git** le 2026-09-15 (restaurer : `git ls-files -d |
  xargs git checkout --`). Sans `--no-dart-format`, c'est `dart format` sur
  tout `lib/`.
- **Banc Rust** : `cd rust && cargo test` (≈ 10 min la première fois, puis
  < 1 min). C'est le banc de la phase 3 ; il doit passer avant toute
  livraison qui touche `rust/`.
- **Alignement 16 Ko** des `.so` : cargokit + NDK 27 le produisent sans
  drapeau ; vérifier quand même dans l'APK, pas dans `target/` :
  `python tools/verifie_alignement_16k.py <lib/arm64-v8a/libdiaspo_mls.so>`.
- `RustLib.init()` ne se fait qu'**une fois par isolate** (second appel :
  `StateError`). Passer par `initialiserRustUneFois()`
  (`lib/core/crypto/mls/mls_rust_init.dart`), jamais l'appeler soi-même —
  un test balaie `lib/` pour l'interdire. Deux gardes séparées ont suffi tant
  que chaque appelant avait son isolate ; le jour où l'aperçu de notification
  a été reconstruit **au premier plan**, dans l'isolate de l'app, son
  `RustLib.init()` a levé, le `catch` a rendu `null`, et la bannière a affiché
  « Nouveau message » — indiscernable d'un déchiffrement impossible, et muet
  dans le journal.

## Migrations Supabase sur la branche partagée

Le worktree isole l'index et l'arbre, mais **pas le contenu une fois fusionné
sur la branche partagée** — deux pièges de `db push` restent possibles même
en travaillant proprement dans un worktree.

**1. Collision d'horodatage.** Deux agents qui créent une migration la même
plage horaire choisissent parfois le même préfixe à 14 chiffres. Git ne le
voit pas — les noms de fichiers diffèrent après le préfixe, la fusion passe
sans conflit — mais `supabase_migrations.schema_migrations` indexe par ce
préfixe seul : `db push` échoue dessus, en silence côté git. Détecter avant
de pousser :

```bash
ls supabase/migrations | sort | awk -F_ '{print $1}' | uniq -d
```

Sortie vide = ok. Sinon, renuméroter **celle qui n'a jamais été appliquée**
(le message de commit le dit en général), après la dernière migration
existante — jamais avant, sinon désordre d'ordonnancement.

**2. Un `GRANT` ne restreint rien : il faut `REVOKE`.** Supabase pose
`ALTER DEFAULT PRIVILEGES … GRANT ALL ON TABLES TO anon, authenticated` :
toute table neuve du schéma `public` naît avec **tous** les droits pour ces
deux rôles. Écrire

```sql
GRANT SELECT, INSERT ON public.ma_table TO authenticated;   -- n'enlève RIEN
```

donne l'illusion d'une restriction et n'en pose aucune. Le motif juste est
`REVOKE ALL … FROM authenticated;` **puis** les `GRANT` voulus — et le faire
pour `authenticated` autant que pour `anon`, qu'on pense plus souvent à
révoquer.

Ce que ça a coûté, trouvé par un banc le 2026-09-15 : `mls_messages` portait
en commentaire « le ciphertext ne se réécrit jamais : seules les métadonnées
de retouche », avec le `GRANT UPDATE (…)` colonne par colonne juste en
dessous. En production, l'expéditeur pouvait **réécrire le ciphertext de son
propre message**, des heures après. Le RLS n'y pouvait rien : il filtre des
lignes, jamais des colonnes ni des verbes.

Et `TRUNCATE`, accordé par le même défaut sur **101 tables** à
`authenticated` (84 à `anon`), **ignore le RLS** — aucune policy ne le
retient. PostgREST ne l'expose pas, donc ce n'est pas une porte ouverte
aujourd'hui ; ça le deviendrait au premier `security invoker` qui tronque.

**3. `db push` s'arrête à la première migration en échec**, et bloque tout ce
qui suit dans la file — y compris une migration sans rapport, à quelqu'un
d'autre. Un fichier qui recrée une fonction (`CREATE FUNCTION` sans
`OR REPLACE`) doit `DROP` **toutes** ses surcharges existantes, pas seulement
celle qu'il vise à remplacer, sinon 42723 « already exists with same argument
types ». Avant de corriger et retenter : `supabase db push --dry-run` pour
confirmer que la transaction en échec a bien annulé proprement (rien resté à
moitié appliqué).

## Suivi des tests appareil

`TESTS_APPAREIL_A_FAIRE.md` (racine du repo) recense tout ce qui n'a jamais
été vérifié sur un vrai téléphone — le rendu visuel, les gestes, les
permissions runtime (caméra/localisation), le thème sombre, et tout ce que
`flutter analyze`/`flutter test` ne peut pas couvrir.

**Chaque session doit le tenir à jour** :
- Si le code modifié pendant la session touche à l'un de ces points, ajouter
  une entrée (courte, avec le fichier concerné).
- Si un appareil est connecté et qu'un point de la liste est effectivement
  vérifié pendant la session (pas juste `flutter run` sans device réel),
  cocher l'entrée correspondante.

Ne pas attendre la fin de la tâche pour le faire : l'ajouter au fil de
l'eau, dans le même commit que le changement concerné si possible.

Le fichier est classé par domaine (titres `# N.`) : une nouvelle entrée va
**en tête de son domaine**, jamais en tête du fichier, porte sous son titre sa
ligne `**Priorité P0…P3** · importance n/5` (barème dans le préambule du
fichier), et renvoie aux autres entrées par leur titre, pas par « plus haut /
plus bas ». Après un ajout ou des cases cochées,
`python tools/index_tests_appareil.py` régénère le sommaire, trié par priorité.

## Règles RTDB : jamais de déploiement sans le banc

`firebase deploy --only database` envoie **tout le fichier d'un coup**, et une
règle d'accès rate en silence : l'appelé ne voit jamais l'offre, aucune erreur
n'apparaît nulle part. Trois choses sont obligatoires, dans cet ordre.

**1. Lire ce qui tourne avant de toucher au fichier.** Le dépôt peut être en
avance *comme* en retard sur la production.

```bash
MSYS_NO_PATHCONV=1 firebase database:get "/.settings/rules"
```

(`database:settings:get` ne sait pas lire `rules` ; sous Git Bash, sans
`MSYS_NO_PATHCONV=1`, le chemin est mangé par la conversion de chemins.)

**2. Passer le banc**, qui rejoue le parcours réel d'un appel — 1:1 et groupe,
signalisation, clé E2EE :

```bash
firebase emulators:start --only database --project diaspo-niger
node tools/rules_tests/signalisation_appels.mjs
```

« Parcours nominal : INTACT » est la condition de déploiement. Le reste du banc
**mesure** (étanchéité, client périmé, exposition de la clé) au lieu de figer
une opinion en assertion.

**3. `database.rules.json` doit rester le reflet exact de ce qui est déployé.**
Une cible non encore déployable vit dans un fichier à part —
`database.rules.strict-cible.json` aujourd'hui.

Ce que la violation a coûté le 2026-08-06, en une journée :

- un durcissement déployé sans banc a **cassé tous les appels**, annulé dans
  l'heure — et le diagnostic de l'annulation était lui-même faux, bâti sur un
  `grep` tronqué à 40 résultats ;
- le banc, écrit ensuite, a trouvé que la signalisation des appels de groupe
  était **refusée en production depuis trois jours** (`81ba52c`) : un
  `.validate` exigeait `type` directement sous `$toId` alors que l'app écrit
  `$toId/offer` ;
- et qu'un **anonyme** pouvait poser la clé E2EE d'un appel de groupe, faute de
  `auth != null` devant un `!data.exists()`.

**Deux pièges de RTDB à connaître avant de raisonner sur ces règles :**

- **L'autorisation cascade vers le bas.** Une règle fille plus stricte ne sert
  à rien tant que le parent accorde. C'est pourquoi `e2ee_key` reste lisible
  par tous tant que `group_calls/$callId` est à `auth != null`.
- **`.validate` remonte.** Écrire `$toId/offer` fait évaluer le `.validate` de
  `$toId`. Poser la contrainte au bon niveau, sur l'enfant réellement écrit.

## Règles Firestore : le banc aussi, et un piège de `set(merge)`

Même discipline que pour RTDB, avec son propre banc :

```bash
firebase emulators:start --only firestore --project diaspo-niger
cd test/rules && npm install     # une seule fois
node tools/rules_tests/acceptation_ami.mjs
```

Lire ce qui tourne avant de toucher au fichier vaut ici aussi : l'API
`firebaserules` rend les règles réellement déployées (le compte de service du
dépôt a `firebase.readonly`, mais **pas** `firebaserules.rulesets.test` — la
simulation passe donc par l'émulateur, pas par l'API).

**Le piège qui a coûté deux pannes au même endroit.** `set(..., SetOptions(
merge: true))` n'est pas une méthode : c'est un `create` quand le document est
absent, un `update` quand il existe. Une règle qui autorise l'un sans l'autre
donne une fonction qui marche avec certains comptes et pas avec d'autres.

Et un lot (`WriteBatch`) est **atomique** : un seul refus annule tout le reste.
Un lot qui touche le document de quelqu'un d'autre met donc toute la
fonctionnalité à la merci de la règle la plus stricte qu'il croise.

Ce que ça a coûté :

- 2026-08-05 : `users/{userId}` couvrait create+update+delete dans un seul
  `allow write` appelant `diff(resource.data)` sans garde. Sur une création,
  `resource` est nul : la règle **plantait** au lieu de renvoyer `false`.
  Personne ne pouvait créer son propre document `users`.
- 2026-09-14 : la création du document **d'autrui** restait refusée, et le lot
  d'acceptation d'une demande d'ami en contenait une (`friendIds`). Accepter
  était impossible dès que l'expéditeur n'avait pas de document `users` — donc
  presque toujours, plus rien n'en créant depuis la migration vers Supabase.

Dans les deux cas l'échec était **muet ou illisible** : « Erreur de
chargement », ou rien du tout. Un écran qui n'affiche un message que sur succès
transforme un refus de permission en « le tap n'a pas pris ».

## Réglages : une seule source

Une ligne de réglage n'existe qu'au singulier — **sa brique visuelle est dans
`lib/core/theme/design_kit.dart`, sa valeur dans un provider**.

Un écran ne déclare ni widget de tuile, ni carte, ni filet de réglages, ni
champ `bool _…` qui recopie une valeur de provider.

Cette règle n'est pas une préférence de style : sa violation a déjà coûté trois
défauts, dont deux invisibles à la relecture.

- Trois écrans avaient chacun réécrit `_SettingsCard` / `_SettingsTile` /
  `_SettingsSwitchTile` / `_SettingsDivider`. Comme `DesignListCard` pose déjà
  ses filets, le Profil en affichait **trois superposés** entre chaque ligne —
  ça se lisait comme un trait épais, pas comme un bug.
- Les préférences du profil vivaient en copies `bool` locales rafraîchies par
  un `ref.listen` qui ne se déclenchait jamais. **Toucher une bascule remettait
  les trois autres à `true`** par-dessus les vraies valeurs serveur.
- L'interrupteur push n'écrivait que la préférence locale, qui décide de
  l'*affichage* ; la colonne serveur, qui décide de l'*envoi*, restait à `true`.

Vérifié par `test/core/theme/reglages_sans_doublon_test.dart` (structure) et
`test/features/profile/profile_preferences_provider_test.dart` (comportement).
Le premier porte une liste d'exceptions nommées : elle ne doit que rétrécir.
