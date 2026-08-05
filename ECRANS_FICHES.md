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
| 20a | Modifier mon profil | ✅ | ✅ | ✅ | `profile/presentation/screens/edit_profile_screen.dart` |
| 20b | Appareils connectés | ✅ | ✅ | ✅ | `settings/…/devices_screen.dart` |
| 20d | Réglages de notifications | ✅ | ✅ | ✅ | `notifications/…/notification_settings_screen.dart` |
| 13c | Appels — historique | ✅ | ✅ | ✅ | `calls/…/call_history_screen.dart` |
| 16e | Créer un événement | ✅ | ✅ | ✅ | `events/presentation/screens/create_event_screen.dart` |
| 8b | Carte — Nocturne | ✅ | ✅ | ✅ | `map/…/map_screen.dart`, `assets/map_styles/dark.json` |
| 8c | Carte — sans localisation | ✅ | ✅ | ✅ | `map/…/map_screen.dart` |
| 7d | Carte — couches, panneau 3 positions | ✅ | ✅ | ✅ | `map/…/map_screen.dart` |
| 6a | Fil — Nocturne | ✅ | ✅ | ✅ | `feed/…/feed_screen.dart`, `feed/…/theme/feed_tokens.dart` |
| 11d | Mon profil — Nocturne | ✅ | ✅ | ✅ | `profile/…/profile_screen.dart`, `core/theme/design_kit.dart` |
| 11e | Réglages — Nocturne | ✅ | ✅ | — | `settings/…/settings_screen.dart` |
| 11f | Profil incomplet | ✅ | ✅ | ✅ | `profile/…/profile_screen.dart` (état conditionnel de 10a) |
| 4a | Discussion cliquable | ◐ | ✅ | — | `messages/…/conversation_screen.dart` |
| 6b | Discussion — Nocturne | ✅ | ✅ | — | idem 4a |
| 9a | Messages — liste | ✅ | ✅ | — | `messages/…/messages_screen.dart` |
| 9b | Messages — recherche | ✅ | ✅ | — | idem 9a |
| 9c | Groupes — mes groupes, découverte | ✅ | ✅ | — | `groups/…/groups_screen.dart` |
| 9d | Groupe — fiche | ✅ | ✅ | — | `groups/…/group_detail_screen.dart` |
| 9e | Messages — état vide | ✅ | ✅ | — | idem 9a (`_buildEmptyState`) |

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

## 20a — Modifier mon profil

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

Puis, sur retour de Salim (« ça ne correspond pas »), le formulaire a été
**remis à plat** sur la fiche :

- Les cinq en-têtes de section (« INFORMATIONS DE BASE », « LOCALISATION »…)
  et les cartes qui les suivaient ont disparu. La fiche n'a pas de section :
  un libellé, un champ.
- Plus d'icône de préfixe dans les champs.
- Les deux sélecteurs (Profession, Pays) portent leur libellé **au-dessus**
  comme les champs texte, au lieu d'une étiquette flottante dans le contour.
- Ordre de la fiche : Nom → (poignée) → Bio → Profession → Langues →
  Centres d'intérêt → … → Origine au Niger → Téléphone.
- Le bloc téléphone est regroupé (`_buildPhoneBlock`) : numéro — carte en
  lecture seule s'il est vérifié, champ + « Vérifier » sinon — puis la ligne
  de visibilité, comme la carte à deux lignes de la maquette.

**Conservé volontairement, contre la lettre de la fiche :**
- Le champ **« Nom d'utilisateur »**, absent de la maquette : c'est lui qui
  alimente la ligne d'identité de « Mon espace » (5a).
- **Pays**, **Ville actuelle** et **Profil visible**, placés à la suite. Les
  retirer supprimerait des données, pas de la décoration.
- Le bouton d'aperçu (👁) de l'en-tête et le titre en **serif** : la fiche
  demande Inter 700/18, mais tout le reste de l'app est en serif — c'est une
  décision de design system, pas un détail d'écran.

**Langues et centres d'intérêt** (dernière passe) : les deux blocs sont
jumeaux dans la fiche, ils divergeaient sur tout dans le code.
- Les centres d'intérêt dépliaient le catalogue **sur place** — la page
  doublait de hauteur. Ils ouvrent la même feuille que les langues
  (`_choisirDansListe`, écrite une fois pour les deux).
- `_SelectableChip` et `_LanguageChip` divergeaient sur le rayon, la couleur
  d'accent et jusqu'à la coche de sélection. Une seule `_ProfileChip` :
  pilule rayon 999, encre pleine si retenue, contour sinon, code court de
  deux lettres en tête pour les langues.
- Rien de choisi n'affichait qu'un « +10 » nu, qui ne dit ni ce qu'on
  choisit ni qu'on peut le faire. La puce porte l'invitation en toutes
  lettres (`spokenLanguagesEmptyAction`, `interestsEmptyAction`).
- Un appui sur une puce retenue la retire, dans les deux blocs.

Non vérifié sur appareil : la carte du numéro **vérifié** — le compte de
test n'a pas de numéro vérifié, donc ni le masquage « +33 6 12 •• •• 47 »
ni la ligne « Vérifié par SMS » n'ont été rendus à l'écran.

## 11f — Profil incomplet

Ce n'est pas un écran mais un **état conditionnel de 10a** : le bandeau de
complétude de `profile_screen.dart`, affiché tant qu'il manque un champ.

- Titre chiffré « Votre profil est complété à 40 % », fraction « 2/5 » en
  monospace 13/700 à l'accent, barre 8 px rayon 4.
- Phrase d'explication (« vous rend visible dans la recherche et sur la carte
  des membres ») : le bandeau disait quoi faire, pas pourquoi.
- Chaque champ manquant porte son **bouton « Ajouter »** — pastille pleine à
  l'accent — qui ouvre 20a sur le bon champ via `?focus=`. Avant, la seule
  sortie était « Compléter mon profil », qui ouvrait le formulaire en haut.
- Icône teintée par nature du champ, au lieu du même cercle vide pour tous.
- **Les champs déjà faits restent affichés**, atténués à 70 % avec une coche
  verte, sous les lignes actionnables. La fiche y tient : les effacer laisse
  une barre qui avance sans qu'on voie pourquoi.
- Sans photo, l'avatar passe en **contour pointillé** avec le glyphe « ajouter
  une photo » au lieu des initiales — rien n'invite à agir dans une case
  déjà pleine.

`?focus=` ouvre le sélecteur de photo, celui des langues, ou pose le curseur
dans « ville » / « bio ». **`job` n'est pas géré** : c'est un sélecteur, lui
donner le focus n'ouvrirait rien d'utile — le formulaire s'ouvre en haut.

Écart assumé : la fiche compte nom + pays de résidence parmi les cinq champs.
On garde les cinq déjà câblés (photo, ville, métier, langues, bio) : le nom
est obligatoire à l'inscription, il gonflerait le score sans rien dire.

Vérifié à l'écran le 2026-08-04 : titre chiffré, fraction « 2/5 », barre à
40 %, phrase d'explication, trois lignes à compléter avec leur bouton
« Ajouter », puis « Photo de profil » et « Votre métier » atténués avec la
coche verte. `?focus=languages` ouvre bien 20a **et** la feuille des langues.

Deux points non vus, faute d'un compte qui les produise : l'avatar en
**pointillés** (le compte de test a une photo, donc le contour plein) et le
focus sur « ville » / « bio ».

## 6a — Fil, Nocturne

Codé et vu par la session parallèle (`841d2a9` le FAB creux, `e6b58c6`
l'interlettrage du titre). Relu ici contre la fiche.

**Conforme** : fond #161826, cartes #232532 rayon 8, accent #9184D9, titre
« Le fil. » en Inter avec le point à l'accent, onglet actif en **contour**
1,5 px et non en fond plein, avatar d'en-tête, hashtags #D2CEFD, et le FAB
creux à contour net.

**Un écart de copie corrigé** : la fiche nomme l'onglet « Abonnements »,
l'app disait « Suivis » — et 5d appelle déjà « Abonnements » le même concept.

Ce simple renommage a fait **déborder le segment** : `FeedSegmentedControl`
posait son libellé dans un `Row` en `MainAxisSize.min`, sans rien pour le
contraindre. Le libellé est désormais `Flexible` + ellipsis, ce qui vaut pour
n'importe quelle langue et n'importe quel libellé long. Couvert par
`test/features/feed/feed_segmented_control_test.dart`, qui échoue bien sans
le correctif (« overflowed by 54 pixels »).

**Écarts assumés** : la fiche 6a demande que l'avatar d'en-tête ouvre Messages
(5f) ; il ouvre Mon espace, et la fiche 5a demande l'inverse — les deux se
contredisent, on garde le code. La ligne de date en sur-titre et les icônes
d'onglet viennent de 4g, que ce document ne couvre pas.

**Non revu à l'écran après le correctif** : le téléphone était piloté en
parallèle par l'autre session (ses formulaires de test s'ouvraient sous mes
gestes). Le correctif est prouvé par le test, pas par une capture.

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

## 20d — Réglages de notifications

**Branché** : Réglages (10b) → Application → « Notifications » ouvrait une
**feuille modale qui doublait cet écran** sur les mêmes préférences
(`_NotificationPreferencesModal`, ~130 lignes). La ligne pointe désormais sur
`/notifications/settings` et le doublon est supprimé.

Structure de la fiche : interrupteur maître isolé (« Notifications push » /
« Coupe tout d'un seul geste »), une seule liste « Ce qui vous alerte »,
cartes radius 18 à bordure, lignes 13.5/600 + 11.5/400, note de pied à
l'icône info — l'ancien pavé d'information teinté a disparu.

**Écart tranché par Salim** : la fiche verrouille « Messages système » (grisé,
non désactivable). **On ne l'a pas suivie** — la catégorie reste désactivable
comme les autres, plutôt que de retirer une capacité à l'utilisateur. La note
de pied de la fiche (« Les messages système restent toujours actifs »)
deviendrait fausse : elle dit maintenant que couper l'interrupteur maître
suspend toutes les catégories, messages système compris.

Cinq sous-titres hérités ne disaient rien et trois répétaient leur propre
titre (« Rappels d'événements » / « Rappels d'événements », « Son » et
« Vibration » partageant « Recevoir des notifications », « Demandes d'amis »
décrivant un écran). Réécrits dans le registre de la fiche : ils annoncent ce
qu'on va recevoir.

Écarts assumés :
- **« Mentions uniquement » et « Transferts » ne sont pas ajoutés** : aucune
  préférence ne les porte et rien ne les lirait — deux interrupteurs morts.
- Les catégories réelles que la fiche ne nomme pas (demandes d'amis, groupes,
  événements, rappels, son, vibration) sont **conservées** : la fiche n'en
  parle pas, ce n'est pas une raison pour retirer des réglages qui marchent.
- L'overline dit « Heures calmes » et non « Heures calmes · proposition » : le
  mot « proposition » tracé dans la maquette venait de ce que l'auteur n'avait
  pas confirmé le bloc dans le code — il y est.
- Le titre garde `DesignTitle` (Playfair + point d'accent) au lieu de
  l'Inter 18/700 de la maquette : c'est l'en-tête de tous les écrans de l'app.
- Les interrupteurs restent des `Switch` Material à la couleur d'accent de
  l'utilisateur, pas la pastille 46×27 verte de la maquette (accessibilité et
  comportement plateforme ; le vert #1B5E32 écraserait l'accent choisi).

Vérifié à l'écran : les deux vues de la liste, le verrou visible sur
« Messages système », et la ligne « De 22:00 à 08:00 » qui apparaît quand
« Silence la nuit » est actif.

Non vérifié : le tap Réglages → Notifications et le sélecteur d'heures — le
build est cassé depuis par une autre session (voir plus bas).

## 9e — Messages, état vide

État conditionnel de 9a, pas un écran séparé. La messagerie vide perd sa
barre de recherche et ses puces de filtre — il n'y a rien à chercher ni à
filtrer —, l'entrée « Archives » quitte l'en-tête, et le sous-titre annonce
« Aucune conversation ».

Les deux amorces nommées de la maquette sont désormais câblées, ce que la
version précédente refusait de faire faute de données :
- **Membre proche** : lit l'état déjà chargé par l'accueil
  (`nearbyProfilesNotifierProvider`) **sans redemander la localisation** —
  ouvrir la messagerie ne doit pas déclencher une demande de permission. La
  ligne ne s'affiche donc que si l'accueil a déjà été visité avec la
  localisation accordée.
- **Groupe de votre ville** : `groupsNotifierProvider` filtré sur la ville du
  profil (`currentCity`), groupes publics seulement. Sans ville renseignée, la
  ligne disparaît — la fiche promet un groupe *de votre ville*, pas un groupe
  au hasard.

Écarts assumés :
- **« 1,2 km »** n'est pas affiché : la distance demanderait la position
  courante, que cet écran n'a pas. La ligne dit « En ligne », sinon la ville,
  sinon « À proximité ».
- Le second bouton « Rejoindre un groupe » disparaît : la fiche n'a qu'un CTA,
  et la suggestion de groupe le remplace avantageusement.
- Le titre et la pastille restent ceux de `DesignEmptyState` (Playfair 21,
  icône 40) au lieu d'Inter 19 / icône 44 : c'est le kit partagé de toute
  l'app, le repeindre pour un écran désaccorderait tous les autres états vides.

**Vu le 2026-08-04.** Le compte de test a deux conversations, donc l'état vide
« réel » est hors d'atteinte sans détruire des données. Il a été rendu par le
filtre **« Non lus »** (aucun message non lu) : c'est le même
`_buildEmptyState`, au même endroit de l'arbre. Cercle, titre « Aucune
conversation », corps, bouton plein « Nouvelle conversation » et ligne de
chiffrement : tout est en place.

⚠️ **Les deux amorces ne se sont pas affichées** — et c'est le comportement
attendu : le compte n'a aucun profil proche chargé (localisation non
accordée) et aucun groupe public n'existe en base. Le widget rend donc du vide
au lieu d'inventer, ce qui est correct, mais **leur mise en page reste non
vérifiée**.

⚠️ **Jamais vu à l'écran** : le compte de test a des conversations, donc
l'état vide est inatteignable sans vider les données (`adb install -r`, qui
déconnecterait le compte). À vérifier sur un compte neuf.

## 13c — Appels

Les fonctions étaient là (filtres, groupement par jour, balayage, fusion des
appels consécutifs) ; c'est la **lecture** qui manquait.

- L'`AppBar` cède la place à un en-tête plat : « Appels » 26/700 et, dessous,
  **le nombre d'appels manqués en rouge** — l'alerte se lit sans ouvrir la
  liste ni changer de filtre.
- ⋯ passe en pastille 42×42 rayon 14 ; les `FilterChip` deviennent des
  pilules sans icône, l'active à l'encre pleine, et **« Manqués » porte son
  compteur** en badge rouge (masqué à 0 : un « 0 » rouge alerterait pour rien).
- Ligne refaite : avatar **carré arrondi 46/15** aux initiales et à la couleur
  déterministe du correspondant (`UserColorUtils`) ; nom en rouge si l'appel
  est à rattraper ; la sous-ligne rassemble sens + heure + durée en une
  phrase — « Sortant · 21:23 · 4 appels » — alors que l'heure vivait à droite.
- **Bouton de rappel teinté en vert** quand il y a quelque chose à rattraper.
- Carte d'astuce en fin de liste : le balayage n'avait aucune affordance.
- Durées compactes (« 12 min », « 1 h 05 ») au lieu du `mm:ss`.

Écarts assumés :
- **Pas de ligne d'appel de groupe** : `CallEntity` est strictement 1-à-1
  (`callerId`/`calleeId`), l'historique n'en enregistre aucun.
- **Le balayage garde sa confirmation**, absente de la maquette : un
  historique effacé par un geste involontaire ne se récupère pas.
- La flèche retour n'existe pas dans la maquette (elle suppose un onglet
  principal) ; ici la route est empilée, donc elle n'apparaît que si `canPop()`.

Vu en clair **et** en nocturne. Non vérifié : le rappel réel (il lancerait un
appel) et l'effacement de l'historique.

## 20b — Appareils connectés

- Bandeau unique : « 2 appareils sur 5 » **et** l'explication du chiffrement,
  dans le même bloc — le compteur vivait loin de la phrase qui lui donne son
  sens.
- Cartes rayon 18 sur fond blanc, pastille d'icône 42×42 rayon 13 ; celle de
  l'appareil courant a un **cadre vert 1,5 px** et le badge monospace
  « CET APPAREIL ».
- Empreinte de clé dans un bloc plein, **groupée par 4 et en majuscules**
  (« IIUE ZJKH UWBJ… ») : c'est le même préfixe de clé qu'avant, mais
  comparable à l'œil.
- **Renommer / Révoquer sortent du menu ⋯** et deviennent deux boutons
  visibles. Sur un écran de sécurité, ce qu'on peut faire à un appareil doit
  se voir.
- Avertissement de limite affiché en permanence : la contrainte des 5
  appareils se découvrait au moment d'en connecter un 6e, trop tard.
- Le bouton d'actualisation de l'en-tête devient un « tirer pour rafraîchir ».

**Deux trous de câblage trouvés en vérifiant à l'écran :**

- **« Renommer » n'avait aucun effet.** `renameDevice` écrivait
  `deviceName` dans Firestore `user_keys/{uid}/devices`, alors que
  `getMyDevices` lit Supabase `e2ee_devices` et dérivait le libellé de
  `platform`. La colonne `device_name` existait déjà — migration
  `20260720120200`, qui documente précisément ce bug — mais **le client n'a
  jamais été câblé dessus**. C'est fait : lecture et écriture pointent
  maintenant au même endroit, avec repli si la migration n'est pas déployée
  (sinon un PGRST204 viderait toute la liste au lieu du seul libellé).
- **Un renommage refusé affichait « Appareil renommé »** : `renameDevice`
  renvoie `false` au lieu de lever, et l'écran ne testait pas le retour.

⚠️ **Aucun appareil n'est marqué « CET APPAREIL »** sur le téléphone de test :
le `deviceId` local ne correspond à aucune ligne distante — plausiblement
parce que les `adb install -r` de la session ont vidé les données sans que
l'enregistrement E2EE se rejoue. Impossible de trancher « bug » ou « artefact
de test » sans y consacrer une passe dédiée. En attendant, l'écran **le dit**
au lieu de laisser deux cartes indiscernables : bandeau « Cet appareil n'a pas
pu être identifié dans la liste. Vérifiez l'empreinte avant de révoquer quoi
que ce soit. »

Non vérifié : le renommage réel et la révocation (écritures sur le compte).

## 9a — Messages, liste

La section fourre-tout « Autres » devient le découpage temporel de la fiche :
« Cette semaine » puis « Plus ancien », intertitres affichés dès qu'on est sur
la liste principale — pas seulement quand une conversation est épinglée. Ni
les archives ni les résultats de recherche ne se découpent ainsi ; les
conversations sans date tombent dans le plus ancien plutôt que de disparaître.

L'accusé de lecture passe du bleu WhatsApp au vert `#2D7D46` de la fiche : ce
bleu n'appartenait à aucune des cinq palettes du guide.

Le reste (en-tête à deux actions carrées, carte blanche des épinglées, avatars
50, micro pour les notes vocales, cloche coupée, badge rouge sur « Non lus »)
existait déjà et est conforme.

Vu à l'écran, en clair et en nocturne.

## 9b — Messages, recherche

⚠️ **Deux portées de la fiche sont irréalisables en l'état.** « Messages · 9 »
et « Fichiers · 2 » supposent une recherche dans le contenu ; or les messages
sont chiffrés de bout en bout et la seule recherche du dépôt,
`searchMessagesInConversation`, fait un `ILIKE` Postgres sur `data->>content`
— donc sur du texte chiffré. Elle ne peut structurellement rien trouver, et
elle est limitée à une seule conversation. Il n'existe aucun index local des
messages déchiffrés. Les rétablir demande un index de recherche côté appareil,
pas un écran.

Ce qui est livré : en-tête replié sur ← + champ actif (bordure accent, halo
3 px, loupe orange — nouveau drapeau `active` sur `DesignSearchField`), puces
de portée « Tout · N / Personnes · N / Conversations · N » qui ne comptent que
ce qui est réellement cherché, section **Personnes** (avatars ronds 56, via
`searchProfilesNotifierProvider`, débounce 350 ms), conversations trouvées avec
le terme surligné (`<mark>` de la fiche : fond `#F7E0CE`, texte `#8C491A`), et
une ligne qui dit à l'utilisateur que la recherche porte sur les noms parce que
le contenu est chiffré.

**Piège payé** : ouvrir la recherche déplaçait le champ dans un autre
sous-arbre, donc Flutter le reconstruisait, le focus tombait et **le clavier ne
s'ouvrait jamais** — l'utilisateur tapait dans le vide, sans aucune erreur.
Corrigé en gardant le champ au même rang d'enfant dans les deux états et en ne
faisant varier que ce qui l'entoure. `requestFocus` en post-frame ne suffisait
pas.

**Le même piège, deux crans plus bas** (voir « deux taps » ci-dessous) : garder
le rang ne suffit pas non plus. Ce qui compte est que l'**élément** du champ
survive au rebuild — le rang n'y donne droit que si les frères sont stables.

**Vu et vérifié de bout en bout** (2026-08-04, SM A515F, nocturne) : puces
« Tout · 2 / Personnes · 1 / Conversations · 1 », section Personnes avec
l'avatar rond, « **Sal**im L. » surligné dans les conversations, et la ligne
d'explication sur le chiffrement.

Le surlignage a dû être décliné en nocturne : posées telles quelles sur le
fond sombre, les valeurs claires de la maquette (`#F7E0CE`) faisaient un pavé
beige lumineux. En sombre : fond `#3A2A1C`, texte `#F4A574`.

**Le « deux taps » du clavier — résolu (2026-08-04).** Le premier tap ouvrait
l'en-tête de recherche et le champ gardait le focus, mais le clavier ne se
levait qu'au second tap.

Ce n'était pas un problème de focus, et c'est pourquoi les trois pistes
tentées (`requestFocus` en post-frame,
`SystemChannels.textInput.invokeMethod('TextInput.show')`, maintien du rang
dans la `Row` et la `Column`) ne pouvaient pas marcher : le `FocusNode` ne
perdait jamais le focus. C'était la `TextInputConnection` qui se fermait.

Mécanique exacte : `EditableTextState.dispose()` ferme la connexion clavier
mais **ne défocalise pas** le `FocusNode` externe ; et `initState()` n'ouvre
aucune connexion — seul un *changement* de focus le fait. Donc dès que
l'élément du champ est démonté puis réinflaté alors que le nœud est déjà
focalisé, le clavier tombe et **plus rien ne le rappelle**. Le second tap
marchait parce que `TextField` appelle `requestKeyboard()`, qui rouvre la
connexion explicitement quand le focus est déjà là.

Deux endroits démontaient l'élément, il fallait corriger les deux :

1. `DesignSearchField` renvoyait `TextField` quand inactif et
   `DecoratedBox(child: TextField)` quand actif. Changer de type de widget au
   même rang force Flutter à réinflater. → le `DecoratedBox` est désormais
   permanent, `boxShadow: const []` quand inactif.
2. Dans la `Column` de l'écran, le bloc du champ n'avait pas de clé. À
   l'ouverture, l'en-tête (rang 0) change de type et les puces de filtre
   (rang 2) disparaissent : `updateChildren` n'apparie donc le bloc ni par le
   haut ni par le bas, il tombe dans la zone « milieu » — où tout enfant sans
   clé est démonté. → `ValueKey('messages-search-field')` sur le `Padding`.

À retenir pour les autres écrans : **garder un widget au même rang ne préserve
son élément que si ses frères sont stables**. Dès que des frères
apparaissent, disparaissent ou changent de type, seule une clé le sauve.

## 9d — Groupe, fiche

Identité au gabarit de la fiche : pastille 66 radius 22 au vert de groupe
(`#1B5E32`, la couleur qui identifie « groupe » dans toute la messagerie, pas
l'accent du compte), nom 20, ligne de méta « Privé · Ville · depuis AAAA » —
la catégorie en sort, elle dit moins que le lieu et l'ancienneté.

La description se lit en clair sous l'identité : ni intertitre « À propos » ni
carte. Le bloc de trois stats disparaît — la méta dit déjà l'accès, la section
Membres donne le compte.

« Ouvrir la discussion » remonte dans le contenu (pleine largeur, vert,
radius 13) avec la coupure des notifications à côté ; la barre du bas ne garde
que la sortie du groupe. Le mute agit sur `mutedBy` de la conversation du
groupe et **ne s'affiche pas** si cette conversation n'existe pas encore :
la créer juste pour afficher une cloche serait un effet de bord invisible.

Non fait : la carte info groupée (Épinglés / Médias / Prochaine rencontre en
une seule carte) et le bouton « J'y vais ». La carte d'événement existante est
plus riche que la ligne de la fiche (pastille de date, titre, lieu, heure) —
la replier ferait perdre de l'information.

⚠️ **Jamais vu à l'écran** : le compte de test a rejoint 0 groupe et l'onglet
« Découvrir » ne remonte aucun groupe public — le backend est vide. Ni
l'identité, ni la barre d'action membre, ni les badges de rôle n'ont été
rendus.

**Défaut repéré au passage** : l'onglet « Découvrir » de 9c affiche une zone
entièrement blanche quand il n'y a aucun groupe — pas de liste, pas d'état
vide, pas d'indicateur de chargement. *Corrigé depuis (commit `5ad0a49`), et
**vérifié à l'écran le 2026-08-04** : « Aucun groupe public pour l'instant /
Personne n'a encore créé de groupe public. Le premier, c'est peut-être le
vôtre. » avec le bouton « Créer un groupe ».*

Nouvelle tentative le 2026-08-04, même blocage : **la base ne contient aucun
groupe, ni public ni rejoint**. Il n'existe donc aucun chemin de navigation
vers cet écran. Le seul moyen de le rendre serait de créer un groupe de test
sur le compte — écriture persistante en production, à décider par Salim.

**Troisième tentative (2026-08-04, Salim ayant donné son accord)** : création
d'un groupe **privé** « Diaspora Paris » (localisation Paris) depuis
`/groups/create`. Le formulaire se remplit correctement — nom, description,
ville, bascule « Groupe privé » activée, tout vérifié à l'écran — mais
**l'appui sur « Créer le groupe » n'aboutit pas** : l'app saute sur un écran
de détail de publication et « Mes groupes » reste à 0.

Ce n'est pas un défaut de 9d. C'est le symptôme de l'**intent rejoué au
démarrage** : à chaque fois que l'app se stabilise, elle atterrit sur « Fil
d'actualité → détail de publication », y compris sans action de ma part.
L'écran est arraché sous les doigts en plein milieu d'un formulaire. C'est
exactement le bug traité en parallèle (« Vider l'intent de partage rejoué à
chaque démarrage »).

**Rien n'a été écrit** : aucun groupe créé, aucun commentaire posté (le post
« In kwana » avait déjà ses 2 commentaires avant). À reprendre une fois le
correctif d'intent en place — le chemin est connu et le formulaire tient en
quatre champs.

## 9c — Groupes

L'essentiel de la fiche existait déjà (onglets Mes groupes / Découvrir,
bannière d'invitations, badge ACTIF/CALME, filtres géographiques). Ce qui a
été repris :

**L'onglet « Découvrir » rendait un écran entièrement blanc**, et par trois
chemins qu'on ne pouvait pas distinguer : profil sans ville (la section
« Suggéré » se retirait en silence), aucun groupe public au backend, et
**erreur de chargement rendue en `SizedBox.shrink()`** — un échec réseau était
donc indiscernable de « rien à découvrir ». La décision est maintenant prise en
un seul endroit (`_buildDiscoverTab`), qui a toujours quelque chose à montrer :
squelettes en chargement, état d'erreur avec réessai, et un état vide dont le
texte change selon qu'un filtre géographique est actif (« rien ici, élargissez »)
ou non (« personne n'a encore créé de groupe public »).

Sur une carte de groupe rejoint, la pastille « Membre » — dont le seul effet
était de **quitter le groupe au tap**, sans confirmation — devient « Ouvrir »
et entre dans la discussion, comme la fiche le demande. La sortie du groupe
vit en 9d, où elle est délibérée. Si la conversation du groupe n'existe pas
encore (elle naît au premier message), « Ouvrir » bascule sur la fiche du
groupe plutôt que de rester sans effet.

Non fait, faute de donnée : la note épinglée en sous-carte (une requête par
carte, N+1 sur la liste), la pile d'avatars de membres, et « 14 messages
aujourd'hui » — aucun compteur de messages par jour n'existe.

**Vu et vérifié** (2026-08-04) : l'onglet « Découvrir » affiche bien l'état
vide « Aucun groupe public pour l'instant » avec la sortie « Créer un
groupe », là où il rendait une page blanche. L'onglet « Mes groupes » à zéro
affiche son propre état vide.

Non vérifié : la carte de groupe elle-même (badge ACTIF/CALME, « Ouvrir »),
faute d'un groupe rejoint sur le compte de test.

## 4a / 6b — Discussion, clair et nocturne

Ces deux fiches sont **déjà largement implémentées** par la refonte
précédente : le code porte des références `§4a` explicites (pastille de
présence sur l'avatar 38, cadenas de chiffrement à côté du statut, bulles,
lecteur vocal, composer). Ce lot n'a donc rien réécrit.

Les deltas que la fiche 6b nomme ont été vérifiés **statiquement**, un par un,
et sont tous en place :

| Delta 6b | État |
|---|---|
| Bulle sortante `#1B5E32` → `#2D7D46` | `_kSentBubbleLight` / `_kSentBubbleDark` |
| Bouton vocal plein | `_kVoiceGreen` / `_kVoiceGreenLight` |
| Forme d'onde inactive `#DDD3C4` → `#4A423A` | présent |
| Cadenas près du statut | `_buildStatusWithLock` |

Un écart délibéré : la fiche réserve le cadenas au nocturne (« absent en
clair »). L'app l'affiche dans les deux thèmes — retirer un rappel de
chiffrement en mode clair serait un recul, pas une conformité.

**Deux écarts trouvés en reprenant la fiche point par point, corrigés :**

- **La pastille de présence n'existait pas.** Le code portait bien la
  référence `§4a`, mais l'état n'était écrit qu'en toutes lettres sous le nom
  (« En ligne »). Le point de couleur bordé de la couleur d'en-tête, que la
  fiche pose sur l'avatar, était absent.
- **Le bloc de citation ne suivait pas la fiche.** Elle demande « bordure
  gauche blanche translucide » : un filet de 2 px, 9 px de retrait, sans aplat
  ni rayon. Il portait un liseré de 4 px opaque sur un fond translucide
  arrondi — une seconde bulle dans la bulle. L'aplat reste sur les bulles
  **reçues** : sur fond blanc, le filet seul n'a aucun contraste à exploiter.
- **6b : la bordure des bulles reçues en nocturne** venait de
  `context.borderColor` (`#2A241E`), invisible sur une bulle `#252119` posée
  sur un fond `#0F0D0A`. La fiche nomme `#3D352C` — ajoutée comme
  `AppColors.bubbleBorderDark` plutôt que figée dans le widget, pour ne pas
  refaire le coup de `_kRecvBorderDark`.

**Vu à l'écran le 2026-08-04**, clair et nocturne : pastille de présence,
citation au filet fin sur bulle verte (réponse réellement envoyée dans
« Mes notes »), bulles reçues nocturne dont la bordure se détache enfin du
fond, en-tête, bandeau épinglé, chips Médias/ÉCO, lecteur vocal, composer.

**Reste non conforme, non fait :** le bouton micro du composer. La fiche 4a le
veut en **pastille avec le mot « MAINTENIR »** (hauteur 44, rayon 22, fond
`#1B5E32`, libellé monospace 11/600) ; c'est un bouton rond à icône seule. Le
libellé enseigne le geste, que rien n'indique autrement — mais ce bouton porte
toute la gestuelle d'enregistrement (glisser pour annuler, glisser pour
verrouiller, cadenas flottant en position absolue) et il est couvert par
`message_input_composer_test.dart`. Le passer en pastille change sa géométrie
dans tous les états : c'est un chantier, pas un ajustement.

**Ce n'est pas une passe complète** : les ~6 500 lignes de
`conversation_screen.dart` + `message_bubble.dart` n'ont pas été comparées
ligne à ligne. Seuls les points que les fiches désignent ont été contrôlés.

---

## 8c — Carte sans localisation, repli par ville

La carte d'explication (réciprocité, trois garanties, « Activer » / « Réglages
de confidentialité ») est **vue** sur l'appareil, service de localisation
coupé.

Le panneau bas « Sans localisation, explorez par ville » est codé
(`_buildExploreByCityPanel`) mais **n'a pas pu être vu** : il n'y a aucune
ambassade en base (`/embassies` affiche « Aucune ambassade disponible ») et le
compte de test n'a aucun groupe. Le garde `cities.isEmpty` l'escamote — c'est
le bon comportement, mais ça veut dire que sa mise en page reste non vérifiée.

Trois défauts corrigés en le reprenant sur la fiche :
- **les groupes privés y étaient listés**, nom et nombre de membres compris,
  sous l'étiquette « groupe privé » — une porte fermée proposée en découverte,
  et une fuite pour qui n'a pas le droit d'entrer ;
- la ligne d'ambassade ouvrait la liste `/embassies` au lieu de la fiche ;
- « 1 membres ».

La sélection des villes et des lieux est sortie dans
`map/domain/city_fallback.dart` et couverte par
`test/features/map/city_fallback_test.dart` : l'exclusion des groupes privés
est une règle de confidentialité, elle doit casser un test si quelqu'un la
retire. Une ville qui n'a que des groupes privés ne reçoit pas de chip, sinon
il mènerait à une liste vide.

Écart assumé : pas de « ouvert » calculé sur les ambassades. Le format de
`openingHours` n'est pas garanti côté back — c'est déjà la règle retenue sur
la fiche ambassade. Seul `isTemporarilyClosed` est fiable.

Pour rendre ce panneau vérifiable il faut au moins une ambassade en base :
collection **Firestore** `embassies`, lecture publique, écriture réservée à
`isAdmin()`, via l'écran `/admin/embassies/create`. C'est une **écriture en
production visible par tous les utilisateurs** — à ne pas faire pour tester.

---

## Bouton « Créer le groupe » — mort, et pourquoi

Signalé par Salim, reproduit à l'écran : appuyer sur « Créer le groupe » ne
produisait **rien** — ni indicateur de chargement, ni message, ni navigation —
et `logcat` restait muet.

Cause : `create_group_screen` faisait
`ref.read(currentUserAsyncProvider).valueOrNull`. Or `currentUserAsync` est un
**StreamProvider autoDispose** que cet écran ne regarde jamais. Le `ref.read`
démarrait donc l'abonnement à l'instant du tap et rendait `AsyncLoading` :
`valueOrNull` valait `null`, et la méthode sortait sur un `return` nu, avant
même de poser `_isLoading`. D'où l'absence totale de signe extérieur.

Corrigé en attendant la première émission (`.future`), et en disant à
l'utilisateur si la session a réellement expiré.

Deux filets posés au passage, sur le même chemin :
- Le dépôt ne rattrapait que `ServerException`. Un `PostgrestException` (RLS,
  RPC absente…) traversait dépôt, notifier et écran sans être vu. Un `catch`
  large renvoie désormais un `ServerFailure` porteur du message.
- L'abonnement au topic FCM et la création de la conversation de groupe se
  faisaient **après** l'insertion, sans protection : leur échec faisait
  échouer une création pourtant réussie côté serveur. Ils sont maintenant
  isolés — le groupe existe, le reste est accessoire.

Le motif d'échec remonte enfin jusqu'au toast (`lastError` sur le notifier) :
« Erreur lors de la création du groupe » n'apprenait rien à personne.

Vérifié : le groupe se crée, apparaît dans « Mes groupes » avec le cadenas
privé, et 9c/9d sont enfin observables.

## 9d — correction vue à l'écran

Le libellé « Ouvrir la discussion » était **rogné par le bas** : le bouton
avait une hauteur figée de 44 px, insuffisante dès que l'appareil dépasse
font_scale 1 (le SM A515F est à 1.1). La hauteur devient un minimum, le bouton
grandit avec le texte.

---

## 8b — l'utilisateur se voyait dans ses propres « membres autour »

Repéré par Salim à la validation. La requête de proximité renvoie aussi
l'utilisateur courant : il apparaissait dans sa propre liste à
« 0 m · en ligne », et son marqueur était dessiné **deux fois** sur la carte —
une fois comme position, une fois comme membre, l'un par-dessus l'autre.

Le filtre calculait pourtant déjà `currentUserId`, mais ne s'en servait que
pour écarter ceux qui vous ont bloqué. Une ligne manquait.

Corrigé et vérifié : « 0 membre autour », « Aucun membre à proximité », et un
seul marqueur sur la carte.

## 7d — Carte : couches et panneau à trois positions

Le panneau des membres déclarait bien ses trois crans (18 / 45 / 92 %, avec
`snap`), **mais il était figé**. `DraggableScrollableSheet` ne réagit qu'aux
glissements qui traversent le `scrollController` de sa liste ; or la poignée et
l'en-tête sont posés au-dessus de cette liste, hors du défilement. Attraper la
barrette — le geste que tout le monde fait — ne produisait rien, et avec
« Aucun membre à proximité » il n'y avait même pas de liste à saisir.

La poignée et l'en-tête pilotent désormais la feuille par un
`DraggableScrollableController` : glissement suivi au doigt, puis accrochage au
cran le plus proche au relâcher. Un **tap** sur la poignée passe au cran
suivant et revient au plus bas depuis le haut — une porte de sortie pour qui ne
devine pas le geste.

Les trois crans vérifiés au doigt par Salim. Panneau de couches (« Calques » :
Membres, Ambassades) vu à l'écran.

## Carte — on se voyait dans ses propres « membres autour »

Repéré en validant 8b : le compte courant figurait dans sa propre liste, à
« 0 m · en ligne », et son marqueur était dessiné deux fois — une fois comme
position, une fois comme membre. La requête de proximité renvoie l'utilisateur
courant, et le filtre ne l'excluait pas : `currentUserId` ne servait qu'à
écarter ceux qui l'ont bloqué. Corrigé, le compteur passe de « 1 membre
autour » à « 0 membre autour » — ce qui est la vérité.

---

## 6a — Le fil en Nocturne

Delta conforme : titre Inter 24/500 avec point d'accent (pas Caprasimo),
onglet actif en contour 1.5 px et non en fond plein, cartes de post au rayon 8,
FAB creux à contour indigo. C'est bien la palette Nocturne du fil, pas le mode
clair assombri.

Deux défauts corrigés à la validation :

- **« Abonnements » se tronquait en « Abonnem… ».** À trois segments,
  l'icône laisse désormais la place au libellé : sur 360 dp, icône (16) +
  écart (6) + marges ne laissaient que ~62 dp au texte qui en demande ~75 ;
  sans l'icône il en reste 84. La règle vit dans `FeedSegmentedControl`, donc
  deux segments gardent leurs pictogrammes.
- **On entrait dans le fil sans pouvoir en sortir.** Il s'ouvre en `push`
  depuis Accueil, donc hors de la barre de navigation, et son en-tête n'avait
  pas de flèche de retour — la maquette n'en met pas parce qu'elle le suppose
  onglet. La flèche n'apparaît que si la route peut se dépiler : elle
  s'effacera d'elle-même si le fil devient un onglet.

Fausse alerte de ma part au passage : j'avais signalé que le rail de stories
débordait toujours de 2 px. **C'était déjà corrigé** — le libellé impose son
interligne et `_railHeight` arrondit au pixel supérieur. Signalé de mémoire
sans revérifier la capture.

---

## 11d — Mon profil en Nocturne

Conforme : fond `#0F0D0A`, cartes `#1A1714` bordées, sur-titre `COMPTE` en
monospace cuivré, pastille de profession verte, nom serif au point d'accent,
chevrons en pastille.

Un seul défaut corrigé : « **1 enregistrés** ». La clé `savedPostsCountLabel`
était un mot figé concaténé à un nombre. Remplacée par un vrai pluriel ICU
(`savedPostsCount`), qui traite aussi le zéro — appliqué aux deux écrans de
profil (production et `design_v2`).

Deux écarts à la fiche, **assumés** :

- **La rangée de stats alterne terracotta et vert.** La fiche 11d ne montre
  que deux statistiques, toutes deux en `#F5F2EE` : elle n'a jamais eu à
  résoudre une rangée de quatre. L'alternance est un choix délibéré et
  documenté dans le code (elle a remplacé un bleu Material figé, insensible au
  thème). Uniformiser aplatirait la rangée et retirerait l'indice qu'elle est
  cliquable.
- **« Modifier le profil » reste une ligne de la carte Compte**, là où la fiche
  demande un bouton plein `#F4A574` sous l'identité. Sur un profil incomplet,
  la carte « Compléter mon profil » occupe déjà la place de l'action
  principale ; un second bouton plein juste au-dessus lui ferait concurrence.
  **À reprendre quand le profil est complet** — la carte disparaît alors, et le
  bouton de la fiche retrouve sa place.

---

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
- **Bouton Suivre hors palette** : `FollowButtonVariant.filled` utilisait
  `Theme.of(context).primaryColor`, donc l'accent choisi par l'utilisateur
  s'affichait au milieu du fil. Réglé par la variante `pill` pour 5d, puis
  **la variante `filled` a été supprimée** : son dernier usage
  (`reposters_screen`, une liste du fil) avait le même défaut, et garder une
  variante dont le seul comportement est de casser la palette, c'était la
  laisser à portée de main. `pill` devient le défaut, il ne reste que `pill`
  et `text`.
