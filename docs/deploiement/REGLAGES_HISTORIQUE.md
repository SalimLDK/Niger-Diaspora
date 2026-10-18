# Déploiement : historique des réglages (panneau, puis règles Firestore)

**Rien n'est déployé.** Cette fiche prépare deux déploiements, dans cet ordre, et
chacun attend l'accord de Salim. Préparée le 2026-10-19.

## Ce qui est prêt

| Quoi | Où | État mesuré le 2026-10-19 |
|---|---|---|
| Code du panneau : chaque enregistrement d'une section de `app_config/settings` écrit son entrée d'historique dans la même transaction ; écran Historique + retour arrière | commit `7a16ae83` (poussé) | analyse propre, 5 tests Dart (`reglages_historique_test.dart`) |
| Construction web du panneau | `bash tools/build_admin_web.sh` | **construit** (116 s, code 0) ; le bundle contient `app_config_history` et `lastChangeId` ; `assets/.env` absent du dossier |
| Hachages CSP des scripts FlutterFire | `python tools/csp_hachages_firebasejs.py --verifier` | « hachages à jour » (aucun paquet `firebase_*` n'a bougé) |
| Règles Firestore cibles | `firestore.rules.cible-reglages-historique` | banc émulateur `tools/rules_tests/reglages_historique.mjs` : **30/30** |
| Règles actuellement en production | jeu `a18ed4d9-5772-41d2-9384-b8084ac7b6e5`, mis en ligne le 2026-10-14 20:03 UTC | relu à l'API : **0 ligne d'écart** avec `firestore.rules` |

La cible ne diffère de la production que par le bloc `app_config` (une ligne
retirée, un bloc `app_config_history` ajouté : 39 lignes en tout).

## Pourquoi cet ordre, et pas l'autre

Les règles cibles refusent tout changement de `app_config/settings` qui ne porte
pas `lastChangeId` et une entrée neuve dans le même lot. **L'ancien panneau
n'écrit ni l'un ni l'autre.** Donc :

1. panneau d'abord : avec les règles actuelles, le nouveau panneau fonctionne
   (il ajoute un champ et un document que les règles actuelles laissent passer) ;
2. règles ensuite : le seul client qui écrit les réglages écrit déjà l'historique.

Règles d'abord = plus aucun réglage enregistrable jusqu'au déploiement du panneau.

L'application mobile n'est pas concernée : elle lit `app_config`, n'y écrit pas.
Les Cloud Functions (SDK admin) ne passent pas par les règles.

## Avant de commencer (lecture seule)

```bash
# 1. La production n'a pas bougé depuis la préparation
node tools/lire_regles_firestore.cjs > /tmp/deployees.rules
diff <(sed 's/\r$//' /tmp/deployees.rules) <(sed 's/\r$//' firestore.rules)    # attendu : rien
#    stderr doit redonner le jeu a18ed4d9… ; un autre nom = quelqu'un a déployé : STOP, relire le diff

# 2. Le banc des règles cibles (émulateur Firestore)
cd test/rules && npm install && cd ../..          # une seule fois
firebase emulators:start --only firestore --project diaspo-niger &
node tools/rules_tests/reglages_historique.mjs     # attendu : TOUT PASSE (30 OK)

# 3. Le panneau
bash tools/build_admin_web.sh
python tools/csp_hachages_firebasejs.py --verifier
```

Le CLI Firebase n'est pas installé sur ce poste : `npm install -g firebase-tools`
puis `firebase login`, ou préfixer chaque commande `firebase` par
`npx firebase-tools@latest`. Le banc a aussi tourné avec l'émulateur déjà en
cache (`~/.cache/firebase/emulators/cloud-firestore-emulator-v1.22.0.jar`) lancé
à la main : `java -jar … --host=127.0.0.1 --port=8080`.

## Étape 1 — déployer le panneau

```bash
firebase deploy --only hosting:admin --project diaspo-niger
```

(procédure complète, en-têtes et consoles : `HEBERGEMENT_ADMIN.md`.)

Contrôles, panneau en ligne, avec un compte superAdmin (**les règles actuelles
sont encore en place**) :

1. Recharger la page (ETag → le nouveau `main.dart.js` arrive). Réglages →
   bouton horloge → l'historique s'ouvre, vide ou presque.
2. Changer une valeur sans importance (par exemple un frais, puis le remettre) :
   l'enregistrement réussit, et **l'entrée apparaît** dans l'historique avec
   l'ancienne et la nouvelle valeur.
3. « Restaurer l'ancienne valeur » : motif obligatoire, la section revient, une
   entrée « Retour arrière » s'ajoute.
4. Console Firestore : `app_config/settings` porte `lastChangeId`, et
   `app_config_history/<ce même identifiant>` existe.

Si l'une de ces vérifications échoue : **ne pas passer à l'étape 2.**

Retour arrière du panneau : console Firebase → Hosting → `diaspo-niger-admin` →
historique des versions → « Restaurer ».

## Étape 2 — déployer les règles

```bash
cp firestore.rules.cible-reglages-historique firestore.rules
node tools/lire_regles_firestore.cjs | sed 's/\r$//' | diff - <(sed 's/\r$//' firestore.rules) | grep -c '^<'   # attendu : 1 (la ligne `allow write` retirée)
firebase deploy --only firestore:rules --project diaspo-niger
git add firestore.rules && git commit -m "deploy(firestore): historique des réglages obligatoire (règles)"
```

(Après le déploiement, `firestore.rules` redevient le reflet exact de la
production ; le fichier `.cible-…` peut être supprimé dans le même commit.)

Contrôles :

1. Relire les règles déployées avec `tools/lire_regles_firestore.cjs` : nouveau
   nom de jeu, 0 ligne d'écart avec `firestore.rules`.
2. Panneau, rechargé : enregistrer un réglage **réussit** et crée son entrée.
3. Un compte non superAdmin n'a toujours accès à rien (Réglages absent du menu).
4. Un onglet resté ouvert sur l'**ancien** panneau : l'enregistrement échoue avec
   un refus de permission lisible — c'est le comportement voulu ; recharger.

## Retour arrière des règles

Le jeu précédent est `a18ed4d9-5772-41d2-9384-b8084ac7b6e5`.

- Le plus sûr : `git checkout <commit-avant> -- firestore.rules` puis
  `firebase deploy --only firestore:rules --project diaspo-niger` (c'est la copie
  exacte de la production d'avant, vérifiée à 0 ligne d'écart).
- Ou console Firebase → Firestore → Règles → historique → rétablir ce jeu.

Symptôme qui commande ce retour : « impossible d'enregistrer un réglage » chez le
superAdmin alors que le panneau est à jour. L'historique, lui, ne se perd pas :
`app_config_history` reste lisible et ajouté-seul.

## Ce qui n'est PAS couvert

- Aucun motif n'est demandé à un enregistrement ordinaire (seul le retour arrière
  en exige un) ; l'entrée porte l'auteur, l'heure et les valeurs.
- Aucune seconde approbation pour un réglage critique (référentiel § 13) :
  décision à prendre, non techniquement bloquée.
- Un réglage écrit hors panneau par un script en SDK admin n'est pas tracé (les
  règles ne s'appliquent pas au SDK admin).
