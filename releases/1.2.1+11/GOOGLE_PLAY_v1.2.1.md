# Google Play — Diaspo Niger v1.2.1 (versionCode 11)

> Remplace `releases/1.2.0+14/GOOGLE_PLAY_v1.2.0.md`, dont la description
> mettait en avant deux modules **inaccessibles dans le binaire** (voir §0).

---

## 0bis. La fiche en ligne — relevée le 2026-09-08

`play.google.com/store/apps/details?id=com.diasponiger.diasponiger`, ouverte
dans le navigateur connecté : **la fiche existe et est publiée**.

| Élément | Valeur en ligne |
|---|---|
| Éditeur | Mirai Tech. |
| Téléchargements | 10+ |
| Dernière mise à jour | 17 février 2026 |
| Notes de version | v1.1.1 |
| Classification | Adolescents |
| Icône | **orange**, sigle DN blanc |

C'est donc une **mise à jour**, pas une première publication — les notes de
version ci-dessous ont été corrigées en conséquence.

⚠️ Un `curl` anonyme sur cette URL rend **404** dans les cinq pays testés. Ce
n'est pas une preuve d'absence : une petite fiche peut être restreinte par pays
ou filtrée comme requête robot. Seul le navigateur connecté tranche.

**Trois écarts entre la fiche en ligne et le binaire d'aujourd'hui :**

1. **L'icône du store est orange**, alors que l'icône du lanceur est passée au
   vert (`972835a`). Un utilisateur verrait une icône orange sur Play et une
   icône verte sur son écran d'accueil. À aligner — dans un sens ou dans
   l'autre, mais à aligner.
2. La description courte en ligne annonce « événements, **marché et
   transferts** » : les deux sont inaccessibles (§0).
3. La description longue affirme « **Gratuit et sans publicité** », alors que
   l'APK embarque `google_mobile_ads` **et** RevenueCat. Deux affirmations
   fausses, dont une — la publicité — touche à la déclaration obligatoire.

---

## 0. Ce qui a changé par rapport à la fiche précédente — à lire avant tout

La fiche v1.2.0 consacrait deux sections en tête de description aux
**transferts d'argent** et à la **marketplace**. Ces deux modules, ainsi que
les **salons audio** et les **podcasts**, sont commentés dans
`lib/features/home/presentation/screens/home_screen_widgets.dart` (commit
`1ee97dd` du 2026-08-23, puis 2026-08-30). Leurs tuiles ne sont affichées ni
sur l'accueil ni dans « Tous les services », et cette grille était leur
**unique** point d'entrée : `/transfers`, `/marketplace`, `/audio-rooms` et
`/podcasts` ne sont plus atteignables que par lien profond.

Le masquage est inconditionnel (code commenté), donc indépendant des drapeaux :
`app_config` ne porte d'ailleurs aucune surcharge `feature%`.

Annoncer ces fonctions violerait la règle Google sur les fiches trompeuses et
ferait échouer l'examen. **Elles sont retirées de la description ci-dessous.**

Pour la même raison, la mention « 100 % gratuit » de l'ancienne fiche est
supprimée : `purchases_flutter` (RevenueCat) est câblé dans
`lib/features/podcasts/presentation/screens/podcast_detail_screen.dart`, donc
l'app embarque un achat intégré et devra le déclarer.

---

## 1. Titre (30 caractères max)

```
Diaspo Niger
```

## 2. Description courte (80 caractères max — celle-ci : 65)

```
La communauté nigérienne : messagerie, groupes, carte, ambassades
```

## 3. Description complète (4000 caractères max)

```
Diaspo Niger réunit la communauté nigérienne, au pays comme à l'étranger.

RESTEZ EN LIEN
• Messagerie sécurisée : texte, photos, vidéos, messages vocaux, GIFs
• Appels audio et vidéo, en tête-à-tête comme en groupe
• Groupes par ville et par pays, avec sondages et messages épinglés
• Notifications en temps réel

LA COMMUNAUTÉ AUTOUR DE VOUS
• Carte des membres à proximité, avec filtres par profil
• Découvrez qui, près de chez vous, partage vos origines
• Vous restez maître de votre visibilité : le partage de position s'active
  et se coupe depuis votre profil

LE FIL
• Publications, photos et actualités de la communauté
• Commentaires et réactions
• Partagez un contenu hors de l'app en un geste

DÉMARCHES ET REPRÉSENTATIONS
• L'annuaire des représentations diplomatiques et consulaires du Niger
• 20 démarches consulaires détaillées : pièces à fournir, étapes, contacts
• Coordonnées, horaires et localisation de chaque poste

ANNUAIRE
• Référencez votre activité et trouvez celle des autres
• Recherche par catégorie et par ville

ÉVÉNEMENTS
• Les rendez-vous de la communauté
• Créez et partagez les vôtres

Application en français, utilisable sur Android 7.0 et versions ultérieures.

Support : support@diasponiger.com
Confidentialité : https://diasponiger.com/privacy-policy
```

## 4. Nouveautés (500 caractères max)

```
• Annuaire des représentations diplomatiques et consulaires
• 20 démarches consulaires détaillées
• Messagerie chiffrée : vidéos, sondages, messages épinglés
• Carte des membres à proximité, en temps réel
• Thème sombre sur l'ensemble de l'application
• Navigation revue : sortie explicite depuis chaque écran
```

---

## 5. Fiche boutique

| Champ | Valeur |
|---|---|
| Catégorie | Social |
| Type | Application |
| Public cible | **Adolescents** — c'est la classification déjà en vigueur sur la fiche en ligne ; à conserver sauf raison de la changer |
| Tarif | Gratuit, avec achats intégrés |
| Site web | https://diasponiger.com |
| Contact | support@diasponiger.com |
| Confidentialité | https://diasponiger.com/privacy-policy |
| Suppression de compte | https://diasponiger.com/delete-account |

---

## 6. Éléments graphiques — état

| Élément | Exigence Google | Fichier | État |
|---|---|---|---|
| Icône | 512×512, PNG 32 bits **avec** alpha, ≤1024 Ko | `assets/import_icons/dn_ultra_minimal_icon.png` | conforme (512×512 RGBA, 24 Ko) |
| Feature graphic | 1024×500, JPEG ou PNG 24 bits **sans** alpha | `releases/1.2.1+11/play/feature_graphic.png` | régénéré, **même système que les captures** |
| Captures téléphone | côté long ≤ 2× côté court, sans alpha, 2 minimum | `releases/1.2.1+11/play/screenshots/` | **7**, 1080×1920 |

**Pourquoi les captures ne sont pas des copies d'écran brutes :** les deux
appareils de test sont en 1080×2400, soit un rapport 2,22:1. Google impose que
le côté le plus long n'excède pas deux fois le plus court — une capture brute
est donc refusée. Les visuels livrés sont en 1080×1920 (9:16), le format
explicitement recommandé par Google, avec la copie d'écran réelle intégrée.

Les sept visuels reprennent **le style de la fiche déjà en ligne**, relevé sur
ses six captures : fond en dégradé doux avec une teinte par visuel, titre gras
sans-serif et sous-titre centrés, texte vert sur fond clair et blanc sur fond
saturé, maquette de téléphone à cadre noir, formes floues en arrière-plan.

| # | Fichier | Titre | Fond |
|---|---|---|---|
| 1 | `01_accueil.png` | Votre diaspora, au même endroit | crème |
| 2 | `02_ambassades.png` | Ambassades et consulats | vert |
| 3 | `03_demarches.png` | Vingt démarches consulaires | sarcelle |
| 4 | `04_dossier.png` | Les pièces à réunir | menthe |
| 5 | `05_carte.png` | La carte des membres | orange→ambre |
| 6 | `06_groupes.png` | Rejoignez des groupes | vert |
| 7 | `07_profil.png` | Gérez votre profil | menthe |

**L'app y est en thème clair, accent vert.** Les captures de référence le sont,
et le vert est le défaut de l'app (« Vert (Défaut) » contre « Orange
(Classique) » dans Réglages → Thème). Le compte de test était en sombre et en
orange : les deux ont été basculés avant la prise.

**Trois écrans écartés, et pourquoi.** Le fil ne porte que des publications de
test (« a ignorer »). L'annuaire des entreprises est vide. La fiche d'un poste
a été retirée après la mise en sommeil des horaires et du bandeau « Ouvert » :
il n'y reste qu'une adresse, un fax et quatre boutons, et l'élément le plus
visible y est un encart signalant un numéro erroné. Aucun contenu n'a été
fabriqué pour combler ces trous.

⚠️ Le visuel 2 affiche « ● Ouvert » sur la carte « Le plus proche ». Cet état
ne lit **aucun horaire** : il vaut « vert » dès que `isTemporarilyClosed` est
faux (`embassies_screen.dart`, `_NearestEmbassyCard`). C'est ce que l'amont
vient de retirer de la fiche de détail, mais la liste est restée inchangée.

L'ancien `feature_graphic.png` de la racine faisait **1024×1024** : il aurait
été refusé tel quel.

---

## 7. Caractéristiques techniques réelles

| Élément | Valeur | Source |
|---|---|---|
| applicationId | `com.diasponiger.diasponiger` | `android/app/build.gradle.kts` |
| versionName | 1.2.1 | `pubspec.yaml` |
| versionCode | 11 | `pubspec.yaml` |
| minSdk | **24** (Android 7.0) | défaut Flutter 3.44 |
| targetSdk | **36** | épinglé dans `build.gradle.kts` |
| compileSdk | 36 | défaut Flutter 3.44 |
| Signature | `diaspo-niger-release.jks`, alias `diaspo-niger` | `android/key.properties` |
| Minification | R8 + `shrinkResources` actifs | `buildTypes.release` |
| Symboles natifs | `debugSymbolLevel = FULL` | idem |

> L'ancienne fiche annonçait « SDK minimum : Android 6.0 (API 23) » et
> « SDK cible : Android 14 (API 34) ». Les deux étaient faux.

---

## 8. Permissions — liste réelle et justification

| Permission | Justification |
|---|---|
| INTERNET | Accès aux serveurs |
| ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION | Carte des membres à proximité |
| **ACCESS_BACKGROUND_LOCATION** | Partage de position continu, **optionnel**, activé depuis le profil — voir §9 |
| CAMERA | Photos et vidéos dans la messagerie, photo de profil |
| RECORD_AUDIO | Messages vocaux, appels audio et vidéo |
| READ_MEDIA_IMAGES / READ_MEDIA_VIDEO | Envoi depuis la galerie |
| READ_EXTERNAL_STORAGE (`maxSdkVersion=32`) | Idem, avant Android 13 |
| WRITE_EXTERNAL_STORAGE (`maxSdkVersion=29`) | Enregistrement de fichiers, avant Android 10 |
| POST_NOTIFICATIONS | Notifications, Android 13+ |
| FOREGROUND_SERVICE (+ `_LOCATION`, `_MEDIA_PLAYBACK`) | Service de position, lecture audio |
| MODIFY_AUDIO_SETTINGS, BLUETOOTH_CONNECT | Routage audio pendant un appel |
| WAKE_LOCK | Réception des notifications |

---

## 9. Points bloquants à traiter dans la console

1. **Déclaration « accès à la position en arrière-plan ».** Obligatoire dès que
   `ACCESS_BACKGROUND_LOCATION` figure au manifeste : formulaire + **vidéo de
   démonstration** montrant l'information préalable affichée à l'utilisateur et
   l'usage réel. C'est la première cause de refus sur ce type de fiche.
   À vérifier avant : l'app doit afficher un écran d'information explicite
   *avant* la demande système. `requestBackgroundLocationPermission()` existe
   dans `lib/core/services/location_service.dart` mais **n'est appelée nulle
   part** — le partage continu passe par un service de premier plan
   (`foregroundServiceType="location"`). S'il fonctionne sans cette permission,
   la retirer du manifeste supprime toute cette procédure.

   **Bonne nouvelle constatée sur appareil le 2026-09-08 :** l'écran Carte
   affiche déjà, *avant* toute demande système, un panneau « Mode privé
   activé » qui énonce « position approximative, jamais votre adresse
   exacte », « désactivable à tout moment » et « invisible pour les comptes
   que vous bloquez », avec un bouton ACTIVER explicite. C'est exactement
   l'information préalable que Google exige, et elle filme bien : c'est le
   plan d'ouverture de la vidéo de démonstration. Capture livrée en
   `play/screenshots/05_carte.png`.
2. **Achats intégrés** à déclarer (RevenueCat présent).
3. **Sécurité des données** : position, contacts, photos, messages,
   identifiants — chaque poste à renseigner et à faire correspondre au code.
4. **Classification du contenu** : contenu généré par les utilisateurs +
   messagerie ⇒ questionnaire à remplir en conséquence, pas « Tout public ».
5. **Politique de confidentialité** : vérifiée le 2026-09-08,
   `https://diasponiger.com/privacy-policy` répond **200**. Attention, la
   variante `www.diasponiger.com/privacy` — qui figurait dans une première
   version de cette fiche — **ne résout pas** (erreur de connexion). Les CGU
   (`/terms-of-service`) et la page de **suppression de compte**
   (`/delete-account`, exigée par Play dès qu'il y a des comptes) répondent
   200 elles aussi.

---

## 10. Chiffres vérifiés en base, et deux écarts à connaître

Mesuré le 2026-09-08 sur le projet `zyrfkcjjrhddpfxcgezo` :

| Donnée | En base | Affiché par l'app |
|---|---|---|
| Postes diplomatiques (`embassies`) | **32** (25 ambassades, 4 consulats, 2 missions, 1 délégation) | **30** |
| Démarches consulaires (`demarches_consulaires`) | **20** | 20 |

**Écart 1 — 30 au lieu de 32.** L'écran annonce « 30 ambassade(s) trouvée(s) » ;
les deux entrées de type `mission` n'apparaissent pas. Non élucidé (filtre
délibéré ou type non géré). **Conséquence pour la fiche : aucun chiffre n'est
annoncé** — un examinateur qui compte trouverait 30 là où la description dirait
32. Le chiffre « 20 démarches », lui, est exact et peut rester.

**Écart 2 — l'annuaire des entreprises est vide.** Écran capturé :
« Aucune entreprise trouvée — Soyez le premier à ajouter votre entreprise ! ».
La fonction existe et marche, mais son contenu est utilisateur. La description
a été reformulée en conséquence (« référencez votre activité » plutôt que
« les professionnels de la diaspora », qui laisserait attendre un annuaire
peuplé), et **aucune capture ne montre cet écran**.

---

*Document établi le 2026-09-08 pour `1.2.1+11`.*
