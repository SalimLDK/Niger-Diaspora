# Chiffrer les médias de message — état des lieux et plan (2026-08-04)

## Constat

Les médias de message ne sont chiffrés **à aucun moment** : ni avant l'envoi,
ni au repos sur l'appareil. Seul le **texte** passe par Signal.

Vérifié dans le code, pas déduit :

- `MessageE2EEHelper.encryptAndUploadMedia` → **0 appelant**
- `MessageE2EEHelper.downloadAndDecryptMedia` → **0 appelant**
- chemin réellement emprunté : `message_repository_impl:289` →
  `uploadMediaFile` → `ref.putFile(file)`, fichier brut sur Firebase Storage,
  puis `getDownloadURL()` stocké tel quel dans `data->>'fileUrl'`.

`MediaEncryptionService` est complet et fonctionnel (AES-256-GCM par fichier,
clé aléatoire par média). Il n'a simplement jamais été branché — même famille
que les autres câblages morts du projet.

## Les trois obstacles

### 1. Aucun mode flux, et un plafond à 100 Mo

`downloadAndDecryptFile` fait `ref.getData()` : le fichier **entier** en
mémoire, puis déchiffré en mémoire. `storage.rules` autorise les vidéos
jusqu'à 100 Mo → cohabitation de ~100 Mo chiffrés et ~100 Mo clairs en RAM.
Plantage mémoire probable sur un appareil milieu de gamme (SM A515F, 4 Go).

Conséquence : la vidéo passerait aussi de « démarre en streaming » à
« télécharge tout, puis lit ».

**→ La vidéo demande un déchiffrement par morceaux avant d'être incluse.**

### 2. Rupture de compatibilité, sans échappatoire

Un média chiffré n'a plus d'URL en clair. Un appareil resté sur l'ancien build
verra une pièce jointe cassée. Publier les deux versions annulerait le bénéfice.

**→ Chiffrer les médias impose une mise à jour forcée.** C'est une décision
produit, pas technique.

### 3. Surface d'affichage

- **38** consommations d'URL réseau (`Image.network`, `CachedNetworkImage`,
  contrôleurs vidéo) réparties sur **21** fichiers.
- Chacune doit basculer sur un `File` local **et** conserver le chemin actuel :
  tous les médias déjà envoyés resteront en clair, indéfiniment.
- `MessageModel` n'a aucun champ pour `fileKey` / `storagePath` / `iv`.

## Transport de la clé

`EncryptedMediaResult.fileKeyBase64` est renvoyé **en clair** par le service :
c'est à l'appelant de le faire voyager dans le corps chiffré. Sinon le serveur
peut déchiffrer et l'exercice ne sert à rien.

Deux options, à trancher :

- **a.** encapsuler `{text, media}` dans le plaintext passé à
  `_encryptContent` — simple, mais change le format pour *tous* les messages ;
  un ancien client afficherait du JSON en guise de texte ;
- **b.** un second champ chiffré dédié au média, `content` inchangé — plus de
  code, mais aucun risque sur le texte.

**Recommandation : (b).** Le texte est la fonction critique ; il ne doit pas
dépendre d'un changement de format lié aux médias.

## Découpage proposé

1. **Images, documents, notes vocales** — pas de contrainte de flux, couvre la
   majorité des médias en volume. Chemin double : déchiffrer si les
   métadonnées sont présentes, URL en clair sinon.
2. **Vidéo** — seulement après un déchiffrement par morceaux.

## À trancher avant d'écrire du code

1. Acceptes-tu la **mise à jour forcée** qu'implique le chiffrement des médias ?
2. On commence par la tranche 1 (sans vidéo), ou on attend le morcelage pour
   tout faire d'un coup ?
3. Transport de la clé : option (a) ou (b) ci-dessus ?

## Moins cher, et à faire de toute façon

`storage.rules` : `match /messages/{conversationId}/{allPaths=**}` autorise la
lecture à **tout compte connecté**, sans vérifier l'appartenance à la
conversation — un membre exclu d'un groupe conserve donc l'accès. Restreindre
aux participants ne chiffre rien, mais ferme cet accès, et ne demande aucun
changement client ni mise à jour forcée.

⚠️ Les règles **déployées** n'ont pas pu être vérifiées : la CLI Firebase
n'expose aucune commande de lecture, et une sonde HTTP non authentifiée renvoie
403 aussi bien pour « refusé » que pour « objet absent » (vérifié par témoin).
Ce qui précède décrit le `storage.rules` **du dépôt**.
