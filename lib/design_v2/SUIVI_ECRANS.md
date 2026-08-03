# Suivi des écrans — reprise du design

Un écran par ligne. À tenir à jour **dans le même commit** que le changement,
comme `TESTS_APPAREIL_A_FAIRE.md`.

Légende de l'état :

- **fait** — le nouveau design est appliqué sur la copie et `flutter analyze
  lib/design_v2` passe
- **copié** — le fichier est dans `design_v2` mais porte encore l'ancien
  habillage
- **prod** — le nouveau design est déjà dans `lib/features`, aucune copie
  n'a été faite (la copier n'apporterait rien)
- **à basculer** — validé sur la copie, prêt à écraser l'original

## Onboarding et entrée dans l'app

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 14a→14e | Onboarding 1/5 → 5/5 | `onboarding/…/onboarding_intro_screen.dart` | fait |
| — | Gabarit de page d'onboarding | `onboarding/…/widgets/onboarding_page.dart` | fait |
| 15a | Connexion | `auth/…/login_screen.dart` | fait |
| 15b | Inscription | `auth/…/register_screen.dart` | fait |
| — | Gabarit auth + boutons | `auth/…/widgets/auth_scaffold.dart`, `auth_button.dart` | fait |

## Configuration du profil

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 16f | Étape 1/4 — Faisons connaissance | `profile/…/profile_config_screen.dart` | fait |
| 15c | Étape 2/4 — Votre localisation | idem | fait |
| 15d | Étape 3/4 — Centres d'intérêt | idem | fait |
| 16g | Étape 4/4 — Thème | idem | fait |
| — | Champ `@handle` | `profile/…/widgets/handle_field.dart` | fait |

## Onglets principaux

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 8a | Accueil | `home/…/home_screen.dart` | fait |
| 8b, 8c | Carte (+ sans localisation) | — | prod (`map_screen.dart:2642`) |
| 9a | Messagerie — liste | `messages/…/messages_screen.dart` | fait |
| 9e | Messagerie — état vide | idem | fait |
| — | Tuile de conversation | `messages/…/widgets/conversation_item.dart` | fait |
| 9c | Groupes — mes groupes / découvrir | `groups/…/groups_screen.dart` | fait |
| 9f | Groupes — état vide | idem | fait |
| 9d | Fiche de groupe | `groups/…/group_detail_screen.dart` | fait |

## Profil, réglages et transverses

| Maquette | Écran | Fichier `design_v2` | État |
|---|---|---|---|
| 10a | Mon profil | `profile/…/profile_screen.dart` | fait |
| 10c | Profil d'un membre (vue publique) | `profile/…/profile_view_screen.dart` | fait |
| 10b | Réglages | `settings/…/settings_screen.dart` | fait |
| 12c | Notifications | `notifications/…/notifications_screen.dart` | fait |
| 12d | Recherche | `search/…/search_screen.dart` | fait |
| 11f | Profil incomplet — invitation à compléter | `profile/…/profile_screen.dart` | fait (bandeau `_buildCompletionBanner`) |

## Variantes nocturnes

Les maquettes 11a→11f sont les versions sombres des écrans ci-dessus, pas des
écrans distincts. Rien à implémenter séparément : la trousse passe par
`adaptive_colors.dart`, donc chaque écran fait a déjà sa version sombre.
Ce qui reste à faire est de **les regarder sur un vrai téléphone** — c'est
suivi dans `TESTS_APPAREIL_A_FAIRE.md`, pas ici.

## Localisation

Terminée. 140 clés ajoutées à `app_fr.arb` (template) et `app_en.arb`,
métadonnées `@clé` à parité des deux côtés — contrôlé automatiquement :
**0 écart de clé, 0 écart de `@clé`**.

Il reste 17 littéraux dans `design_v2`, tous délibérés :

| Ce que c'est | Où | Pourquoi ça reste |
|---|---|---|
| Séparateurs `' · '` et `' → '` | partout | ponctuation, pas du texte |
| Compositions `'$date · ${e.location}'` | accueil, groupes, profil, recherche | assemblage de valeurs déjà localisées |
| Sentinelles `_kProfileMissing`, `_kNotSignedIn` | config profil | servent à **reconnaître** le cas dans `e.toString()` : les traduire casserait la détection |
| Valeurs de centres d'intérêt (`'Santé'`…) | config profil | c'est ce que le profil **enregistre en base** ; seul le libellé affiché passe par `_interestLabel` |

Deux corrections de fond faites au passage :

- Les **mois abrégés** de l'accueil (`'fév'`, `'aoû'`, `'déc'`…) étaient une
  table française codée en dur. Ils passent par `DateFormat('d MMM', locale)`
  et suivent donc la langue.
- Les **énumérations** (« a, b et c ») ne concaténaient plus avec un `' et '`
  en dur : la liaison finale vient de l'ARB, elle n'est pas la même partout.

## Troisième vague de maquettes (fil, discussion, Mon espace, services)

Même constat que la deuxième vague : la **structure** de ces maquettes est
déjà en production (les fichiers citent `§5a`, `§5b`, `§4a`, `§7d`, `§12b`,
`§13a`, `§17a`, `§13c`…). Ce qui manque est le **langage visuel** — aucun
titre serif nulle part, et des dégradés qui subsistent dans la discussion,
le composer et la carte.

| Maquettes | Écran | Fichier de production | Taille | État |
|---|---|---|---|---|
| 3a, 4g, 6a | Le fil | `feed/…/feed_screen.dart` | 966 l. | **prod** — fuites de fonte corrigées |
| 5a, 5f | Mon espace | `feed/…/mon_espace_screen.dart` | 363 l. | **prod** — fuites de fonte corrigées |
| 5b, 5g, 6d | Mes publications | `feed/…/my_posts_screen.dart` | 180 l. | **prod** — système propre |
| 5c, 5e, 6e | Enregistrés | `feed/…/saved_posts_screen.dart` | 336 l. | **prod** — système propre |
| 5d, 5h, 6f | Mon réseau | `feed/…/follows_screen.dart` | 190 l. | **prod** — système propre |
| 3b, 3c, 4a, 6b | Discussion | `messages/…/conversation_screen.dart` | 3444 l. | à faire |
| 4c→4f, 6c | Composer et enregistrement vocal | `messages/…/widgets/message_input.dart` | 2188 l. | à faire |
| 7d, 7e | Carte : couches, bascule Carte/Liste | `map/…/map_screen.dart` | 3560 l. | à faire |
| 12a, 16c, 16i | Transferts : envoi, accueil, historique | `transfers/…` (3 écrans) | 1975 l. | fait (partiel — voir ci-dessous) |
| 12b, 16a, 16b, 16h | Boutique, détail produit, panier | `marketplace/…` (3 écrans) | 1741 l. | fait |
| 13a, 16e | Événements, création | `events/…` (2 écrans) | 2136 l. | fait |
| 13b, 16d, 17a, 17b | Ambassades, fiche, demande, contact | `embassies/…` (4 écrans) | 2420 l. | fait |
| 13c | Appels | `calls/…/call_history_screen.dart` | 748 l. | fait |
| 17c, 17d, 18a→18d | Annuaire, fiche, création, avis, mise en avant | `businesses/…` (5 écrans) | 3018 l. | fait |

### La famille « fil » a son propre système — ne pas lui appliquer la trousse

`lib/features/feed/presentation/theme/` définit `FeedTokens` et `FeedText`,
qui implémentent **exactement** les deux systèmes des maquettes :

- `nocturne` — sombre, accent indigo `#9184D9`, rayons serrés, titrage Inter.
  C'est littéralement ce que montrent 6a→6f.
- `organic` — clair, accent terracotta, rayons généreux, titrage **Caprasimo**.
  C'est le gros display des maquettes 3a, 5a→5h.

Ces écrans sont donc **déjà à jour** sur la structure et les couleurs.
Leur appliquer `design_kit` (Playfair Display, jetons `adaptive_colors`)
serait une régression : ça écraserait la bascule Organic/Nocturne que les
maquettes elles-mêmes montrent. Aucune copie n'a été faite pour eux — ils
se corrigent **directement en production**.

#### Ce qui restait quand même à corriger (fait le 2026-08-03)

L'audit du fil et de Mon espace a trouvé une fuite que le mot « déjà à
jour » masquait : **13 libellés utilisaient un `TextStyle(` brut**. Leurs
couleurs étaient correctes (`tokens.*`), donc rien ne se voyait en
nocturne — mais un `TextStyle` brut n'hérite pas de la fonte de
`FeedText` : il prend celle du thème global de l'app.

Conséquence : en mode **organic**, ces libellés rendaient dans la police
de l'app au lieu de **Figtree**, à côté de titres en Caprasimo. C'est-à-dire
précisément dans le mode que montrent 3a et 5a. Les 13 sites passent
maintenant par `FeedText.body(tokens, …)`.

Deux exceptions volontaires :

- `fontFamily: 'monospace'` dans `feed_screen.dart` — c'est le libellé
  mono voulu par les maquettes, il ne doit pas passer par `FeedText` ;
- `Colors.transparent`, qui n'est pas une couleur de thème.

Reste ouvert, hors périmètre demandé : `saved_posts_screen.dart` peint son
fond de balayage en `Colors.red` avec une icône `Colors.white`. C'est
lisible et l'idiome est universel, mais aucune des deux palettes ne
contient ce rouge, et `FeedTokens` n'a pas de jeton `danger`. À trancher
avant de traiter « Enregistrés ».

### Transferts, ce qui reste

Les trois écrans ont l'en-tête plat, mais les maquettes 12a et 16c décrivent
aussi du **contenu** que je n'ai pas touché : le montant en très grand avec le
détail des frais et le taux garanti (12a), et la frise d'état
« Débité → En route → Disponible » de l'historique (16c). C'est du travail de
composition, pas d'habillage — à traiter à part.

Ordre d'attaque retenu, la famille « fil » étant hors périmètre :
services d'abord (annuaire 407 l., boutique 557 l., ambassades 594 l.,
appels 748 l., événements 1082 l.), puis discussion, composer et carte —
les trois plus gros fichiers du dépôt, 9 200 lignes à eux seuls.

## Quatrième vague (écrans secondaires, feuilles et états)

Cette vague descend d'un cran : ce ne sont plus les onglets, mais les écrans
où l'on va une fois, les **feuilles modales** posées par-dessus un écran
existant, et les **états** (vide, hors ligne, échec).

**12 des 44 sont déjà câblées** — les fichiers de production citent déjà
leur `§`, signe qu'une session précédente les a traitées. Comme pour la
troisième vague, cela vaut pour la **structure** : le langage visuel
(titre serif, fond crème, trousse) reste à appliquer partout.

Vérification faite par `grep -rl "§<num>" lib/features` : c'est ce grep,
et non une supposition, qui remplit la colonne « structure ».

### Réglages et compte

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 20a | Modifier mon profil | `profile/…/edit_profile_screen.dart` | 2400 l. | à faire |
| 20b | Appareils connectés | `settings/…/devices_screen.dart` | 550 l. | à faire |
| 20c | Sauvegarde des clés | `settings/…/security_backup_screen.dart` | 601 l. | à faire |
| 20d | Réglages de notifications | `notifications/…/notification_settings_screen.dart` | 525 l. | à faire |
| 21a | Partager mon profil (QR) | `profile/…/widgets/share_profile_modal.dart` | 825 l. | ✅ câblée |
| 21b | Comptes bloqués et mes signalements | `settings/…/widgets/blocked_users_modal.dart`, `reports/…/my_reports_screen.dart` | 402 l. | ✅ câblée |
| 21c | Apparence, langue, fond d'écran | `messages/…/widgets/chat_background_picker_modal.dart` | — | ✅ câblée |
| 21d | Aide et à propos (FAQ en accordéon) | `settings/…/settings_screen.dart` | 2286 l. | ✅ câblée |
| 26c | Document légal en lecture | `legal/…/legal_documents_screen.dart` + `legal_essentials_card.dart` | 75 l. | ✅ câblée |

### Support

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 22a | Nous contacter — nouveau ticket | `support/…/create_ticket_screen.dart` | 266 l. | à faire |
| 22b | Mes demandes | `support/…/support_tickets_screen.dart` | 300 l. | à faire |
| 22c | Suivi d'une demande | `support/…/ticket_detail_screen.dart` | 421 l. | à faire |
| 22d | Aucune demande en cours | idem (état vide) | — | à faire |

### Fil, discussion et appels

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 23a | Appel en cours 1-à-1 | `calls/…/call_screen.dart` | 2031 l. | à faire |
| 23b | Appel de groupe | `group_calls/…/group_call_screen.dart` | 852 l. | à faire |
| 23c | Détail d'un post et commentaires | `feed/…/post_detail_screen.dart` | 357 l. | famille « fil » |
| 23d | Créer une publication | `feed/…/create_post_screen.dart` | 823 l. | famille « fil » |
| 24a | Galerie de la conversation | `messages/…/media_gallery_screen.dart` | 895 l. | à faire |
| 24b | Messages favoris | `messages/…/starred_messages_screen.dart` | 313 l. | à faire |
| 24c | Nouvelle conversation | `messages/…/new_conversation_screen.dart` | 1042 l. | à faire |
| 24d | Résultats d'un sondage | `polls/…/poll_results_screen.dart` | 257 l. | à faire |
| 26b | Stickers et GIF du composer | `messages/…/widgets/gif_picker_content.dart`, `emoji_sticker_picker.dart` | 579 l. | ✅ câblée |

### Services

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 19a | Annuaire Business — nocturne (= 17c) | `businesses/…/businesses_screen.dart` | 407 l. | à faire |
| 19b | Ambassades — nocturne (= 17a) | `embassies/…/embassies_screen.dart` | 594 l. | à faire |
| 19c | Mes entreprises (propriétaire) | `businesses/…/my_businesses_screen.dart` | 487 l. | ✅ câblée |
| 25a | Fiche d'un événement | `events/…/event_detail_screen.dart` | 1084 l. | ✅ câblée |
| 25b | Ma boutique — annonces et commandes | `marketplace/…/my_products_screen.dart` (119 l.), `my_orders_screen.dart` | 745 l. | à faire |
| 25c | Détail d'un transfert et moyens de paiement | `transfers/…/transaction_detail_screen.dart` | 797 l. | à faire |
| 26a | Mes amis et demandes | `friends/…/friends_screen.dart` + `widgets/friend_request_item.dart` | 236 l. | ✅ câblée |

### Feuilles modales et confirmations

Ces sept maquettes ne sont pas des écrans : ce sont des feuilles posées
sur un écran existant. Elles se traitent **avec l'écran qui les ouvre**,
pas séparément.

| Maquette | Feuille | Fichier | Structure |
|---|---|---|---|
| 27a | Actions sur un message | discussion | à faire |
| 27b | Confirmation destructive | `messages/…/widgets/delete_message_modal.dart` | ✅ câblée |
| 27c | Signaler un contenu | `reports/…/widgets/report_content_modal.dart` | ✅ câblée |
| 27d | Joindre un média | `messages/…/media_batch_preview_screen.dart` | ✅ câblée |
| 28a | Actions sur une publication | fil | famille « fil » |
| 28b | Qui peut voir cette publication | créer une publication | famille « fil » |
| 28c | Confirmer un transfert | transferts | à faire |
| 28d | Partager dans l'app | fil, discussion | à faire |

### États — la partie la plus utile de la vague

Les maquettes 2a→3d ne décrivent aucun écran neuf : elles décrivent **ce
qui s'affiche quand ça se passe mal**, et elles distinguent des cas que
l'app confond aujourd'hui. C'est là que le gain fonctionnel est le plus
fort, indépendamment du visuel.

| Maquette | Ce qu'elle exige |
|---|---|
| 2a | Le fil garde son cache hors ligne, avec la date du dernier chargement |
| 2b | **Quatre échecs distincts** : pas de réseau, panne serveur, réseau lent, action refusée — aujourd'hui traités comme un seul |
| 2c | Carte sans repère : dire que la position est active mais la zone vide |
| 3a | **Transfert en quatre états** selon où est l'argent : refusé avant débit, incertain, débité non reçu, remboursé |
| 3b | Reconnexion : file d'attente par ordre d'importance, et ce qui est arrivé pendant l'absence |
| 3c | Boutique : trois vides différents (rien en vente, rien commandé, recherche sans résultat) |
| 3d | Groupes : trois vides différents (aucun rejoint, rien dans ma ville, recherche vide) |

⚠️ La maquette 3a laisse trois trous explicites — « délai à définir »,
« schéma à définir », « frais remboursés en cas d'échec ? À trancher ».
Ce sont des **décisions produit**, pas du design : elles doivent être
tranchées avant d'implémenter cet écran, sinon on affichera des délais
inventés.

## Cinquième vague — salons audio et podcasts

Les deux features audio, qui étaient jusqu'ici la principale zone sans
maquette. Quatre documents, 22 maquettes.

**5 des 22 sont déjà câblées** (`grep -rl "§" lib/features/audio_rooms
lib/features/podcasts` remonte §1a, §1c, §1d, §1e, §1h). Comme pour les
vagues précédentes, cela vaut pour la **structure** : le langage visuel
reste à appliquer partout.

### Document 1 — écouter

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 1a | Salons audio — liste | `audio_rooms/…/audio_rooms_list_screen.dart` | 849 l. | ✅ câblée |
| 1b | Salon en direct | `audio_rooms/…/audio_room_screen.dart` | 1528 l. | à faire |
| 1c | Bibliothèque du patrimoine | `audio_rooms/…/heritage_library_screen.dart` | 1432 l. | ✅ câblée |
| 1d | Podcasts — accueil | `podcasts/…/podcasts_home_screen.dart` | 704 l. | ✅ câblée |
| 1e | Lecteur d'épisode | `podcasts/…/episode_detail_screen.dart` | 996 l. | ✅ câblée |
| — | Lecteur de replay (même gabarit que 1e) | `audio_rooms/…/replay_player_screen.dart` | 771 l. | à faire |
| 1f | Revenus créateur | `audio_rooms/…/creator_earnings_screen.dart` | 545 l. | à faire |
| 1g | Envoyer un don | `audio_rooms/…/widgets/send_tip_bottom_sheet.dart` | 340 l. | à faire |
| 1h | Acheter un billet | `audio_rooms/…/widgets/buy_ticket_bottom_sheet.dart` | 336 l. | ✅ câblée |

### Document 2 — créer et publier

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 2a | Ouvrir un salon | `audio_rooms/…/create_audio_room_screen.dart` | 638 l. | à faire |
| 2b | Programmer — multi-fuseaux | `audio_rooms/…/widgets/timezone_display_widget.dart` | 536 l. | à faire |
| 2c | Publier en podcast | `audio_rooms/…/save_as_podcast_screen.dart` | 366 l. | à faire |
| 2d | Enregistrer un épisode | `podcasts/…/record_episode_screen.dart` | 718 l. | à faire |
| 2e | Aucun salon en direct | `audio_rooms_list_screen.dart` (état vide) | — | à faire |
| 2f | Podcasts — aucun abonnement | `podcasts_home_screen.dart` (état vide) | — | à faire |
| 2g | Salons — nocturne | `audio_rooms_list_screen.dart` | — | à faire |

### Documents 3 et 4 — gérer, modérer, mesurer

| Maquette | Écran | Fichier de production | Taille | Structure |
|---|---|---|---|---|
| 3a | Mes podcasts (créateur) | `podcasts/…/my_podcasts_screen.dart` | 525 l. | à faire |
| 3b | Fiche d'un podcast | `podcasts/…/podcast_detail_screen.dart` | 531 l. | à faire |
| 3c | Modération fantôme (admin) | `audio_rooms/…/ghost_moderator_screen.dart` | 508 l. | à faire |
| — | Tuile d'épisode (portée par 3a et 3b) | `podcasts/…/widgets/episode_tile.dart` | 545 l. | à faire |
| 4a | Statistiques d'un podcast | `podcasts/…/podcast_stats_screen.dart` | 406 l. | à faire |
| 4b | Lecteur — nocturne | même écran que 1e | — | à faire |
| 4c | Patrimoine oral — nocturne | même écran que 1c | — | à faire |

### ⚠️ Ces maquettes reposent sur de l'argent qui ne circule pas encore

Les documents 1 à 4 affichent des prix d'entrée, des abonnements mensuels,
des dons, des replays payants et un solde créateur retirable. Deux réserves
avant de traiter ces écrans :

1. **Ne pas inventer de chiffres.** Les maquettes elles-mêmes marquent leurs
   montants « propositions à valider » : paliers de don, tarif des épisodes
   payants, montants de revenus, et surtout **le taux de commission hors
   don** — le code ne fixe explicitement que les 95 % reversés sur un don.
   Tant que ce n'est pas tranché, afficher un taux serait une invention.
2. **Vérifier l'état réel du backend** (abonnements, replays payants,
   versements) avant de dessiner un écran qui promet une opération que
   l'app ne sait pas encore exécuter. C'est le piège déjà rencontré sur ces
   mêmes écrans : une interface complète posée sur un chemin de paiement
   qui n'aboutissait pas.

## États vides et nocturne de l'accueil (1a→1c, 2d)

Cette série ne décrit pas de nouvel écran : c'est l'accueil déjà repris dans
`design_v2`, vu **en situation de vide**. Elle confirme les trois causes
distinctes qui y sont implémentées (position active mais personne autour,
position coupée, et les trois vides d'événements).

### Squelette de chargement (1b · CAS 3) — traité

⚠️ J'avais d'abord noté ici « pas de squelette de chargement ». **C'était
faux** : mon `grep` ne cherchait que `Skeleton`/`Shimmer`, alors que le code
les nomme `_NearbyAvatarLoading` et `HomeEventCardLoading`. Les deux
sections de l'accueil en avaient déjà un, et `NearbyProfilesNotifier`
démarre bien en `AsyncValue.loading()` — jamais sur une liste vide.

Il restait en revanche un **vrai** trou, dans le scénario exact que la
maquette illustre (CAS 1 → « Élargir à 200 km » → CAS 3) :

`nearbyProfiles.when(skipLoadingOnRefresh: true, …)` garde volontairement
les résultats précédents pendant un rafraîchissement de fond. Mais il
gardait aussi la carte vide « Personne à moins de 50 km » à l'écran pendant
toute la recherche à 200 km — donc un texte « vide » affiché pendant un
chargement, ce que la maquette interdit noir sur blanc.

Corrigé : `_widenRadius()` lève `_nearbySearching` le temps de la recherche,
et le squelette (`NearbyLoadingRow`) passe devant les résultats précédents
pour ce cas-là seulement. Le rafraîchissement automatique des 60 s garde son
comportement d'origine — il ne doit pas faire clignoter la liste.

Appliqué **des deux côtés** : la copie `design_v2` et la production
`lib/features/home/…` portent le même correctif, vérifié identique. Ce point
ne créera donc pas d'écart à la bascule.

## Écrans hors maquettes

Reste sans maquette à ce jour, et hors périmètre annoncé : le back-office
admin (19 écrans). Ces écrans gardent leur habillage actuel.
