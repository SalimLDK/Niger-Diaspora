# Écrans repris sur les fiches Claude Design

Suivi de la reprise écran par écran du document **« Fiches d'écrans.dc.html »**
(projet Claude Design `79c21696-bb15-4f7b-bb62-a49968417d22`, 17 fiches).

Chaque fiche donne la maquette, la fiche technique (fichier cible, accès,
composants au pixel) et le contenu textuel exact. On valide **un écran à la
fois** avec Salim avant de passer au suivant.

Trois niveaux, à ne pas confondre :

| Niveau | Ce que ça veut dire |
|---|---|
| **Codé** | Écrit et `flutter analyze` propre. Rien de plus. |
| **Vu** | Rendu à l'écran sur le SM A515F et comparé à la maquette. |
| **Validé** | Salim a dit oui. |

---

## État

| Fiche | Écran | Codé | Vu | Validé | Fichier |
|---|---|:--:|:--:|:--:|---|
| 5a | Mon espace | ✅ | ✅ | ✅ | `feed/presentation/screens/mon_espace_screen.dart` |
| 5b | Mes publications (+ repartages) | ✅ | ✅ | ✅ | `feed/presentation/screens/my_posts_screen.dart`, `widgets/my_post_card.dart` |
| 5g | Mes publications — état vide | ✅ | ✅ | ✅ | idem 5b (`_FirstPostInvitation`) |
| 5c | Enregistrés | ✅ | ✅ | — | `feed/presentation/screens/saved_posts_screen.dart`, `widgets/saved_post_card.dart` |
| 5d | Abonnés / abonnements | — | — | — | `feed/presentation/screens/follows_screen.dart` |
| 20a | Modifier mon profil | — | — | — | `profile/presentation/screens/edit_profile_screen.dart` |
| 20b | Appareils connectés | — | — | — | à déterminer |
| 20d | Réglages de notifications | — | — | — | à déterminer |
| 13c | Appels — historique | — | — | — | `calls/…/call_history_screen.dart` |
| 16e | Créer un événement | — | — | — | à déterminer |
| 8b | Carte — Nocturne | — | — | — | déclinaison de 7d |
| 8c | Carte — sans localisation | — | — | — | déclinaison de 7d |
| 7d | Carte — couches, panneau 3 positions | — | — | — | à déterminer |
| 6a | Fil — Nocturne | — | — | — | `feed/presentation/screens/feed_screen.dart` |
| 11d | Mon profil — Nocturne | — | — | — | `profile/presentation/screens/profile_screen.dart` |
| 11e | Réglages — Nocturne | — | — | — | à déterminer |
| 11f | Profil incomplet | — | — | — | à déterminer |

---

## 5a — Mon espace

**Branché** : Accueil → « Le fil » → avatar de l'en-tête → Mon espace
(`/feed/space`). Vérifié au doigt le 2026-08-04.

Conforme à la fiche : en-tête 52 px (flèche 24 à 16 du bord, gap 10, titre
Caprasimo 22), avatar 64, nom 18/600, sous-ligne 13/400, trois cases de stats
radius 18, carte de navigation unique radius 22 à filets, pastilles 34×34
radius 11, compteurs 13/500, chevrons 20.

Écarts assumés :
- Le filet séparateur est à 10 % d'opacité (`tokens.hairline`) au lieu des 8 %
  de la fiche — 2 % d'alpha, pas de jeton créé pour ça.
- La fiche annonce que l'avatar du fil « ouvre Messages » : **faux dans le
  dépôt**, il pointait déjà sur `/feed/space`. La fiche 6a demande d'ailleurs
  l'inverse (avatar → Messages) : les deux fiches se contredisent, on a gardé
  le code existant.

## 5b — Mes publications

Carte de post compacte dédiée (`my_post_card.dart`), distincte de celle du
fil : pas d'en-tête d'auteur, ligne de méta, vignette 56×56, barre
d'engagement, « Modifier » et menu ⋯. Onglets pleins, en-tête avec loupe
(filtre local sur la liste chargée), cartes brouillon dans la liste.

Vérifié à l'écran avec une vraie publication et un brouillon.

Écarts assumés, tous parce que le modèle ne porte pas la donnée :
- La méta affiche toujours « Public ». **Aucune portée de publication
  n'existe** (`create_post_screen` le documente) : afficher « Abonnés » comme
  la maquette serait inventer une audience.
- Le menu ⋯ n'a ni « épingler » ni « changer l'audience », pour la même
  raison — Enregistrer / Modifier / Supprimer seulement.
- L'onglet Repartages garde la carte du fil : ce sont les posts d'autrui,
  « Modifier » et « Supprimer » n'y auraient aucun sens.
- Le raccourci « créer une publication » a quitté l'en-tête (la fiche n'y met
  que retour + loupe). La création reste au FAB du fil et à l'état vide.

## 5g — Votre première publication

État de 5b quand il n'y a ni publication ni brouillon. Cercle 104, titre
Caprasimo 21, deux amorces (photo / sondage) qui ouvrent l'éditeur
pré-configuré via `?compose=photo|poll`, bouton plein et FAB.

Le FAB suit **l'invitation**, pas le compte : il reste affiché même si
l'onglet Repartages, lui, n'est pas vide.

Non vérifié : les deux amorces (la photo demande la permission galerie).

## 5c — Enregistrés

Les filtres et le regroupement Cette semaine / Plus ancien existaient déjà ;
ce qui manquait, c'est la **carte** : `saved_post_card.dart` remplace la carte
du fil par le format court de la fiche — vignette 72×72 à gauche, ligne
d'auteur (avatar 22, nom 13/600, ancienneté compacte « 15 min »), texte clampé
à deux lignes, puis « Retirer » / « Partager ».

En-tête sur mesure avec le compteur à droite, chips au gabarit exact
(pilule 6/12, gap 7, actif à l'encre pleine), sur-titres monospace au nouveau
jeton `overline`.

Écarts assumés :
- La fiche écrit « Tout », l'app affiche « Tous » (clé l10n `all`, partagée
  avec d'autres écrans — pas touchée pour un mot).
- Le glissement pour retirer est conservé **en plus** du lien « Retirer » :
  la fiche ne le mentionne pas, mais c'est un geste existant, on ne retire pas
  une capacité sans raison.
- Sans média, la vignette 72×72 porte un glyphe de type (texte, lieu). La
  maquette montre un sondage — les posts-sondages n'ont pas de marqueur
  distinct au modèle, donc pas d'icône dédiée.

Non vérifié : les filtres Photos / Vidéos (le compte de test n'a qu'un post
texte) et la feuille « Partager ».

---

## Ce que la reprise a fait tomber au passage

- **Brouillons multiples** : le brouillon de publication était unique, un
  second écrasait le premier en silence. Devenu une liste (`post_drafts`,
  migration SharedPreferences v1 → v2), couverte par 7 tests.
- **Brouillons jamais sauvegardés** : `dispose()` appelait `ref.read(...)`,
  ce qui lève — et `main.dart` renvoyant `FlutterError.onError` vers
  Crashlytics, l'exception n'apparaissait ni dans logcat ni à l'écran.
  Notifier capturé à l'`initState` + autosave débounce 800 ms + sauvegarde au
  passage en arrière-plan.
- **Dates affichées en UTC** : `PostModel.parseDate` renvoie un `DateTime`
  UTC, que `DateFormat` imprime tel quel — 4 h d'écart constatées en EDT.
  Contourné dans `formatPostMeta` (`toLocal()`) ; **le fond du problème
  touche tout le fil** (`timeAgo`, `formatMessageDate`) et reste ouvert.
- **Rail de stories** : débordement de 2 px sous « Ma story » (corrigé à part).
