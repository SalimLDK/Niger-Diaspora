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
cp android/key.properties "$W/android/"        # uniquement pour un build release
cp android/app/diaspo-niger-release.jks "$W/android/app/"
```

Sans le `.env` copié, toute commande Flutter échoue sur l'asset manquant.
Compter ~4 min au premier `flutter analyze` (résolution des paquets).

Les deux derniers ne servent qu'à `flutter build apk --release`, mais leur
absence ne se voit qu'**au tout dernier moment** : `signingConfigs.release` lit
`key.properties` derrière un `if (storeFileVal != null)`, donc un fichier
manquant ne fait pas échouer la configuration — la compilation entière se
déroule, et c'est `:app:packageRelease` qui tombe sur
« SigningConfig "release" is missing required property "storeFile" ».
25 minutes de build perdues le 2026-08-06. Les deux fichiers sont couverts par
`android/.gitignore` (`key.properties`, `**/*.jks`) : les copier ne risque pas
de les faire committer.

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
dans ce dépôt** (bloqué avant même que git ne s'exécute), alors que `git
merge` passe. Pour intégrer les commits distants : stasher son propre WIP de
façon **ciblée** (jamais `-A` sur tout l'index — voir la règle
`--` ci-dessus), `git merge origin/<branche> --no-edit`, résoudre les
conflits à la main, puis `git stash pop`. `git push` peut se faire rejeter
une seconde fois si l'autre agent pousse pendant l'opération : refaire
fetch/merge/push jusqu'à ce que ça passe, jamais de force.

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

**2. `db push` s'arrête à la première migration en échec**, et bloque tout ce
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
