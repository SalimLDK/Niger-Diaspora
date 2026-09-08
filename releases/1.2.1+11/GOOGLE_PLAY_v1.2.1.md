# Google Play — Diaspo Niger v1.2.1 (versionCode 11)

> Remplace `releases/1.2.0+14/GOOGLE_PLAY_v1.2.0.md`, dont la description
> mettait en avant deux modules **inaccessibles dans le binaire** (voir §0).

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
• Les 32 postes diplomatiques et consulaires du Niger
• 20 démarches consulaires détaillées : pièces à fournir, étapes, contacts
• Coordonnées, horaires et localisation de chaque poste

ANNUAIRE
• Les professionnels et entreprises de la diaspora
• Recherche par activité et par ville

ÉVÉNEMENTS
• Les rendez-vous de la communauté
• Créez et partagez les vôtres

Application en français, utilisable sur Android 7.0 et versions ultérieures.

Support : support@diasponiger.com
Confidentialité : https://www.diasponiger.com/privacy
```

## 4. Nouveautés (500 caractères max)

```
Première version publiée sur le Play Store.

• Annuaire des 32 postes diplomatiques et consulaires du Niger
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
| Public cible | 18 ans et plus (contenu généré par les utilisateurs) |
| Tarif | Gratuit, avec achats intégrés |
| Site web | https://www.diasponiger.com |
| Contact | support@diasponiger.com |
| Confidentialité | https://www.diasponiger.com/privacy |

---

## 6. Éléments graphiques — état

| Élément | Exigence Google | Fichier | État |
|---|---|---|---|
| Icône | 512×512, PNG 32 bits **avec** alpha, ≤1024 Ko | `assets/import_icons/dn_ultra_minimal_icon.png` | conforme (512×512 RGBA, 24 Ko) |
| Feature graphic | 1024×500, JPEG ou PNG 24 bits **sans** alpha | `releases/1.2.1+11/play/feature_graphic.png` | régénéré |
| Captures téléphone | côté long ≤ 2× côté court, sans alpha, 2 minimum | `releases/1.2.1+11/play/screenshots/` | régénérées |

**Pourquoi les captures ne sont pas des copies d'écran brutes :** les deux
appareils de test sont en 1080×2400, soit un rapport 2,22:1. Google impose que
le côté le plus long n'excède pas deux fois le plus court — une capture brute
est donc refusée. Les visuels livrés sont en 1080×1920 (9:16), le format
explicitement recommandé par Google, avec la copie d'écran réelle intégrée.

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
2. **Achats intégrés** à déclarer (RevenueCat présent).
3. **Sécurité des données** : position, contacts, photos, messages,
   identifiants — chaque poste à renseigner et à faire correspondre au code.
4. **Classification du contenu** : contenu généré par les utilisateurs +
   messagerie ⇒ questionnaire à remplir en conséquence, pas « Tout public ».
5. **Politique de confidentialité** : l'URL doit être vivante au moment de
   l'examen.

---

*Document établi le 2026-09-08 pour `1.2.1+11`.*
