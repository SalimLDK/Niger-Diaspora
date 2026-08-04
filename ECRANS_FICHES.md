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
| 5c | Enregistrés | ✅ | ✅ | ✅ | `feed/presentation/screens/saved_posts_screen.dart`, `widgets/saved_post_card.dart` |
| 5d | Abonnés / abonnements | ✅ | ✅ | ✅ | `feed/presentation/screens/follows_screen.dart` |
| 20a | Modifier mon profil | 🔨 | ✅ | — | `profile/presentation/screens/edit_profile_screen.dart` |
| 20b | Appareils connectés | — | — | — | à déterminer |
| 20d | Réglages de notifications | — | — | — | à déterminer |
| 13c | Appels — historique | — | — | — | `calls/…/call_history_screen.dart` |
| 16e | Créer un événement | ✅ | ✅ | — | `events/presentation/screens/create_event_screen.dart` |
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

## 5d — Mon réseau

En-tête « Mon réseau » (le titre l10n disait « Abonnés et abonnements »),
onglets pleins avec compteur permanent — extraits en `feed_pill_tabs.dart`,
partagés avec 5b comme la fiche le demande —, barre de recherche qui filtre
sur nom / ville / pays / poignée, lignes de contact au gabarit de la fiche
(avatar 44, nom 14.5/600, contexte 12/400, filet sous chaque ligne) et
pastille Suivre/Suivi.

Nouvelle variante `FollowButtonVariant.pill` : l'ancien bouton plein prenait
`Theme.of(context).primaryColor`, donc **l'accent choisi par l'utilisateur
écrasait la palette du fil**. La pastille prend ses couleurs de `FeedTokens`.

La ligne de contexte se déduit de l'onglet — sous Abonnés tout le monde
« vous suit », sous Abonnements « vous suivez » — ce qui évite une requête de
réciprocité par ligne.

Écarts assumés :
- **« 3 amis en commun », « 14 publications ce mois », « suivie par Fatouma »**
  ne sont pas affichés : aucune de ces données n'existe côté modèle.
- **« Suggestions pour vous » n'est pas implémenté** : il n'y a aucun
  fournisseur de suggestions dans le dépôt. Inventer une liste de comptes
  serait pire que l'absence.
- Les hashtags suivis apparaissent sous Abonnements (carré au glyphe tag,
  « Hashtag », pastille Suivi qui désabonne) mais **sans compteur de
  publications** — la donnée n'existe pas non plus.
- La pastille dit « Suivi » et non `l10n.unfollowUser` (« Ne plus suivre ») :
  elle indique un état, pas une action.

Non vérifié : les hashtags (le compte de test n'en suit aucun) et la
recherche.

## 20a — Modifier mon profil (partiel)

L'écran avait déjà été largement repris sur §20a par des sessions
précédentes (langues en feuille multi-choix, puces repliées, compteur de bio
sur la ligne du libellé, origine et visibilité en une ligne). Cette passe n'a
corrigé que ce qui s'écartait encore de la fiche **à l'écran** :

- **Le ✕ était invisible** : pastille blanche à 20 % et glyphe blanc, restes
  de l'époque où la barre était un hero terracotta. Sur le fond crème actuel,
  il n'y avait littéralement rien à voir en haut à gauche. Devenu un ✕ 24 px
  dans la couleur du texte.
- **Pastille appareil photo** : elle était un second aplat d'accent collé à
  l'avatar. Passée en pastille neutre 26 px cerclée du fond de page, glyphe
  sombre — l'accent reste sur « Modifier la photo ». Avatar 66/22 (fiche).
- **« Qui peut voir mon numéro ? » n'affichait aucune valeur** : le profil
  portait une chaîne absente de `phoneVisibilityOptions`, et le `?? ''` la
  remplaçait par du vide en silence. Les valeurs inconnues sont désormais
  ramenées sur la valeur par défaut, à la lecture comme à l'affichage.

**Reste à trancher — restructuration, pas restylage.** La fiche décrit un
formulaire nu : libellé au-dessus, champ 48 px radius 14, **aucune icône dans
les champs**, **aucun en-tête de section**, et un ordre différent
(Nom → Bio → Profession → Langues → Intérêts → Origine → Téléphone). L'écran
actuel a des en-têtes de section (« INFORMATIONS DE BASE »), des icônes de
préfixe, un champ « Nom d'utilisateur » que la fiche ne montre pas, et un
bouton d'aperçu (👁) absent de la maquette. Le titre est en serif alors que
la fiche demande Inter 700/18 — mais **tout le reste de l'app est en serif**,
c'est une décision de design system, pas un détail d'écran.

Rien de tout ça n'a été touché : ce sont des suppressions de fonctions
existantes (le champ poignée alimente 5a) ou des choix qui débordent de
l'écran. À arbitrer avec Salim.

## 16e — Créer un événement

Le formulaire existait déjà et portait la quasi-totalité des champs (le
`EventEntity` a `maxAttendees`, `price`, `isOnline`, `onlineLink`,
`posterUrls`) : la reprise a été une **restructuration**, pas un ajout de
fonctions.

- En-tête 48 px : ✕, « Nouvel événement » 18/700, mention « Brouillon ».
- **Zone d'affiche remontée en tête** (elle était tout en bas) : cadre
  pointillé 104 px — `_DashedBorderPainter`, Flutter n'ayant pas de bordure en
  pointillés —, « Ajouter une affiche » / « Recommandé · 3:2 ».
- Tous les champs au même gabarit : 50 px, rayon 14, libellé 12.5/600.
- Date et Heure côte à côte, icônes 17 px.
- **Le format devient un segment** « Sur place » / « En ligne » (actif à
  l'encre pleine) : c'était un interrupteur « Événement en ligne ».
- **Participants max et Prix côte à côte**, et « Gratuit » s'affiche en vert
  comme état par défaut du champ vide — pas comme une valeur à saisir.
- **Barre de pied fixe** « Aperçu » / « Publier l'événement » : le bouton
  unique était noyé en fin de liste.

Écarts assumés :
- **« Prévenir mes groupes » n'est pas implémenté.** La maquette montre un
  interrupteur qui diffuserait l'événement dans plusieurs groupes ; le modèle
  n'a qu'un `groupId`, et il n'existe aucun mécanisme de diffusion multi-groupes.
  Envoyer des messages dans les groupes de quelqu'un sur la foi d'une maquette
  n'est pas une décision à prendre ici. L'interrupteur affiché à cet endroit
  reste celui qui existe — visibilité publique — et seulement quand
  l'événement naît d'une discussion.
- **« Brouillon » n'est pas persisté** : rien n'est sauvegardé en sortant.
  Plutôt que de laisser le mot mentir, le ✕ demande confirmation dès que le
  formulaire contient quelque chose (`PopScope` + `_isDirty`).
- **« Aperçu » était « non maquetté »** : plutôt qu'un bouton mort, il valide
  le formulaire puis ouvre une feuille montrant les valeurs réellement
  saisies. Les champs vides n'y figurent pas.
- La fiche ne montre ni description, ni catégorie, ni date de fin. Ils sont
  conservés — la description est **obligatoire**, la reléguer hors champ
  ferait échouer la validation sans qu'on voie pourquoi.
- Le libellé de la description affichait « La description est requise » :
  `l10n.descriptionRequired` est un message d'erreur, pas un libellé.
- Le champ Participants max coupait son placeholder à « Laissez vide pou… » :
  passé à `maxAttendeesHint` (« Ex: 50 »).

Non vérifié : le sélecteur d'affiche (permission galerie), la feuille
« Aperçu » et la publication réelle.

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
- **Champs de recherche cerclés de blanc** : le thème global impose
  `filled: true` **et** un contour via `enabledBorder`. Dans un champ posé
  sur un conteneur déjà coloré (5b, 5d), il faut neutraliser `filled` **et**
  `enabledBorder`/`focusedBorder` — `border: InputBorder.none` seul ne fait
  rien, le thème gagne.
- **Bouton Suivre hors palette** : `FollowButtonVariant.filled` utilise
  `Theme.of(context).primaryColor`, donc l'accent choisi par l'utilisateur
  s'affichait au milieu du fil. Réglé par la variante `pill` pour 5d ; les
  autres usages de `filled` restent à revoir.
