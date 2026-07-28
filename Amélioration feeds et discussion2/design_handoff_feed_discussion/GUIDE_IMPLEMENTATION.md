# Guide d'implémentation — tours 8 à 28 + Salons audio & Podcasts

Ce guide explique **comment reproduire les maquettes dans le code Flutter**, écran par écran : quel fichier ouvrir, quoi remplacer, avec quelles valeurs exactes, et quels pièges éviter. Il complète le `README.md` (qui décrit *quoi* changer) en donnant le *comment*.

Ordre de lecture conseillé : la section **0** (règles communes) une fois pour toutes, puis la section de l'écran sur lequel vous travaillez.

---

## 0 — Règles communes, à appliquer partout

Ces sept règles expliquent 80 % des différences entre l'app actuelle et les maquettes. Les appliquer d'abord évite de refaire deux fois le même écran.

### 0.1 Ajouter les tokens manquants

Les maquettes utilisent quatre valeurs qui n'existent pas encore. À ajouter dans `lib/features/feed/presentation/theme/feed_tokens.dart`, en clair **et** en sombre :

| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `textStrong` | `#1C1815` | `#F5F2EE` | Titres, montants, noms — jamais le gris moyen |
| `actionLabel` | `#4A443C` | `#C4BDB3` | Libellé d'action au repos |
| `actionMuted` | `#847A6E` | `#8A8177` | Métadonnées, sous-titres |
| `hairline` | `#F3EDE3` | `#2A241E` | Séparateur entre deux lignes d'une même carte |

Pourquoi : aujourd'hui les titres et les métadonnées partagent souvent la même couleur, ce qui écrase la hiérarchie. La règle est **trois niveaux de gris maximum par écran**.

### 0.2 Les surfaces sont opaques, jamais des dégradés

Remplacer tous les `LinearGradient` d'en-tête par une couleur pleine :
- clair : fond d'écran `#FAF7F2`, carte `#FFFFFF`, bordure `1px #EFE7DB` ;
- sombre : fond `#0F0D0A`, carte `#1A1714`, bordure `1px #2A241E`.

En sombre, **aucune ombre portée** : les surfaces se distinguent par bordure + rayon. En clair, une seule ombre autorisée, celle des FAB : `0 14px 34px rgba(46,43,37,.28)`.

### 0.3 Échelle de rayons

`8` pastille · `11–12` bouton · `14` champ de saisie · `16` petite carte · `18` carte de liste · `20–22` carte de contenu · `26` feuille modale · `999` puce.

Ne pas inventer d'intermédiaire : si un rayon ne tombe pas dans cette liste, c'est une erreur de copie.

### 0.4 Cibles tactiles

**44 px minimum** sur tout ce qui se touche. Concrètement :
- boutons d'action de la barre de post : `IconButton` avec `constraints: BoxConstraints(minWidth: 44, minHeight: 44)` ;
- bouton lecture d'une note vocale : 44 px (il était à 36) ;
- lignes de liste : hauteur utile ≥ 48 px, obtenue par `padding: EdgeInsets.symmetric(vertical: 12)`.

### 0.5 Espacement par `gap`, pas par marges individuelles

Utiliser `Row`/`Column` + `spacing` (Flutter 3.27+) ou `Wrap(spacing:, runSpacing:)`. Éviter les `SizedBox` intercalés quand une liste peut être réordonnée : l'espacement doit survivre à un `reorder`.

Échelle : `4 · 6 · 8 · 10 · 12 · 14 · 16 · 20 · 22`.

### 0.6 Chaque état porte sa conséquence

C'est le changement de fond le plus important. Un interrupteur ou une action ne dit pas seulement *ce qu'il fait* mais *ce qui va se passer* :

- ❌ « Statut en ligne »
- ✅ « Statut en ligne — Masqué : vous ne verrez plus celui des autres »
- ❌ « Supprimer ? OK / Annuler »
- ✅ « Supprimer pour tous — Aïcha verra “message supprimé” »

Implémentation : `SwitchListTile(title:, subtitle:)` avec un `subtitle` **calculé selon la valeur courante**, pas un texte fixe.

### 0.7 Les états vides sont des écrans, pas des messages

Structure imposée : icône ou pastille 100 px → titre 18,5 px w700 → explication 14 px / 1,55 → **une à trois amorces cliquables** → CTA principal. Jamais un simple texte gris centré.

---

## 1 — Accueil (tour 8a)

**Fichier** : `lib/features/home/presentation/screens/home_screen.dart`

### Ce qui disparaît
1. L'`AppBar` en dégradé orange → un `SliverAppBar` transparent sur `#FAF7F2`, ou simplement une `Column` en tête de `CustomScrollView`.
2. Les **trois cartes de statistiques** (membres / groupes / événements) → une seule **ligne de contexte**.
3. Le carrousel horizontal de services → une **grille 4 colonnes**.

### Ce qui apparaît
**En-tête** : `Row` avec avatar 52 px rayon 16, puis `Column` (« Bonjour, » 13,5 px `actionMuted` / prénom 22 px w700 `textStrong`), puis deux tuiles 44 px rayon 14 fond `#F5F0E8` (QR, notifications). Le badge de notifications : cercle 18 px `#C23E2D`, bordure 2 px de la couleur de fond, texte 10 px w700.

**Ligne de contexte** — remplace les trois cartes :
```
Row(children: [
  icon_location 15px  (couleur #B85E24)
  Text('Paris, France', w600 13px textStrong)
  Expanded(Text('· 318 membres · 12 groupes',
    style: 13px actionMuted, overflow: ellipsis))
])
```

**Bloc « Aujourd'hui »** (nouveau, c'est le cœur de l'écran) : carte blanche rayon 20, en-tête monospace 10,5 px `letterSpacing: .1em` en majuscules, puis **trois lignes actionnables séparées par `hairline`** :
1. messages non lus → sous-titre = les noms, tronqué ;
2. prochain événement → bouton « J'y vais » (pastille 11 px de rayon, fond `#B85E24`) ;
3. nouveaux membres proches → chevron.

Chaque ligne : pastille d'icône 34 px rayon 11 (fond `#E8F0EA` / `#F7E9DE` / `#F5F0E8` selon le type), titre 14 px w600, sous-titre 12 px `actionMuted`.

**Services** : `GridView.count(crossAxisCount: 4, childAspectRatio: 1)` — tuiles carrées rayon 18, icône 24 px, libellé 11 px sous la tuile. Raison : le carrousel masquait la moitié des entrées.

**Autour de vous** : `Row` scrollable d'avatars 58 px + prénom 11 px + distance 10,5 px ; dernière tuile en pointillés `+9 / Voir tout`.

### Piège
La ligne de contexte doit **ellipser**, pas passer à la ligne : sur un petit écran « · 318 membres · 12 groupes » se tronque, le nom de ville reste toujours lisible (`flex: none` sur la ville, `Expanded` sur le reste).

---

## 2 — Carte (tours 7d, 8b, 8c)

**Fichier** : `lib/features/map/presentation/screens/map_screen.dart`

### Le problème actuel
Trois couches empilées en `Positioned` absolu (`top: 16` recherche, `top: 76` chips, légende à `bottom: 130` ou `290` selon l'état du panneau). Résultat : chevauchements, et les filtres se masquent dans certains cas.

### La correction
**Un seul bloc d'en-tête** en `Positioned(top: 0, left: 0, right: 0)`, contenant :
```
Column(children: [
  SizedBox(height: statusBarHeight + 8),
  Row(children: [ Expanded(searchField), layersButton44 ]),
  SizedBox(height: 10),
  SingleChildScrollView(scrollDirection: horizontal, child: Row(chips)),
])
```
Le champ de recherche : fond blanc opaque, rayon 16, ombre légère — il doit rester lisible sur la carte.

**La légende quitte la carte** : elle devient un bouton « ? » 44 px dans la colonne d'actions de droite, avec le recentrage (`my_location`). Cela supprime tout le calcul de `bottom:` conditionnel.

**Le panneau membres** devient une feuille à trois positions (`DraggableScrollableSheet`, `snapSizes: [0.18, 0.45, 0.92]`) avec une poignée 40×4 `#D8CCB8`. Chaque membre : avatar 44, nom w600 14, sous-titre « métier · distance · présence », bouton message 40 px.

**Marqueurs** : membre 44 px bordure blanche 3 px ; cluster 52 px ; ambassade carré 36 px `#1976D2` ; position propre = point bleu 16 px dans un halo 44 px `rgba(25,118,210,.18)`.

**8c — sans localisation** : ne pas afficher un bandeau d'avertissement par-dessus une carte inutilisable. Écran dédié : explication de la réciprocité, **trois garanties** (position approximative / désactivable à tout moment / invisible pour les comptes bloqués), CTA « Activer la localisation », puis repli « explorer par ville » avec l'ambassade et le groupe local.

---

## 3 — Messages (tours 9a, 9b, 9e)

**Fichiers** : `messages_screen.dart`, `widgets/conversation_item.dart`

### Structure
Deux sections : **Épinglées** (dans une carte blanche rayon 18, les lignes séparées par `hairline`) puis « Cette semaine » (lignes à plat sur le fond, séparées par un filet).

### La ligne de conversation, en détail
- avatar **50 px rayon 17** (pas un cercle) ; pastille de présence 13 px `#2D7D46`, bordure 2,5 px de la couleur du fond ;
- nom : 15 px, **w700 si non lu**, w600 sinon ;
- heure : monospace 11,5 px — `#B85E24` w600 si non lu, `#A79C8E` w400 sinon ;
- **l'aperçu dit son type** : c'est le point clé. Selon `lastMessage.type` :
  - texte → le texte ;
  - image → `📎 Photo · <légende>` ;
  - audio → icône `icon_mic` 14 px + « Note vocale · 0:34 » ;
  - vos envois → `icon_done_all` 14 px (vert si lu, gris si envoyé) + « Vous : … » ;
  - mention → `@vous` en `#B85E24` w700 devant l'aperçu ;
- badge non-lus : 22 px de haut, rayon 11, fond `#B85E24`, texte 11,5 px w700 blanc ;
- silencieux → `notifications_off` 16 px à droite de l'aperçu.

**Filtres** : Tous / Non lus (avec badge) / Groupes / Archives, en puces 999 — l'actif en `#1C1815` texte blanc.

### 9b — Recherche
Compteurs par catégorie dans les puces (`Tout · 14`, `Messages · 9`…), personnes en rangée d'avatars 56 px, extraits avec le terme surligné : `RichText` avec un `TextSpan` de fond `#F7E0CE` et couleur `#8C491A`. Fichiers avec poids et date.

### 9e — État vide
Rappel du chiffrement + **deux amorces** : « écrire à un membre proche » et « rejoindre un groupe de votre ville ». Pas de texte gris seul.

---

## 4 — Groupes (tours 9c, 9d, 9f)

**Fichiers** : `groups_screen.dart`, `group_detail_screen.dart`

**Badge d'activité** — la nouveauté utile : calculer l'activité à partir de la date du dernier message.
- < 24 h → `ACTIF`, fond `#E8F0EA`, texte `#1B5E32`, point 6 px ;
- sinon → `CALME`, fond `#F5F0E8`, texte `#847A6E`.

**Carte de groupe** : icône 48 px rayon 16 (couleur dérivée du groupe), nom w700 15 + cadenas 13 px si privé, « ville · N membres », puis **l'épinglé visible** dans une sous-carte `#F5F0E8` rayon 14 avec `icon_pinned_message`, puis avatars empilés (26 px, chevauchement −9, bordure 2 px) + « 14 messages aujourd'hui » + bouton Ouvrir.

**Invitations** : bandeau `#FBF1E9` bordure `#F0DCCB` en tête de liste, avec le nombre et les noms tronqués.

**9d — fiche** : identité (privé · ville · année), description, actions primaires, trois raccourcis (Épinglés / Médias / Prochaine rencontre avec « J'y vais »), membres avec badges `ADMIN` / `MODÉ`.

---

## 5 — Profil (tours 10a, 10b, 10c, 11f, 20a)

**Fichiers** : `profile_screen.dart`, `profile_view_screen.dart`, `edit_profile_screen.dart`, `profile_options.dart`

### 10a — Mon profil : ce qui change
L'écran actuel mélange identité et réglages (~30 lignes). Nouvelle structure :
1. **identité** : avatar 84 rayon 28 + pastille appareil photo 28 px ; nom 20 w700 + badge vérifié 18 px `#1976D2` ; ligne « Paris, France 🇫🇷 » (`currentCity` + drapeau depuis `ProfileOptions.countries`) ; deux puces `originCity → currentCity` et `profession`. **L'e-mail disparaît** — il n'a rien à faire sur un profil.
2. bio 14 px / 1,55 en `textStrong`.
3. deux boutons pleine largeur (Modifier / Partager).
4. **une seule** carte de statistiques, 4 colonnes séparées par des filets verticaux 1 px.
5. « Mon espace » : Mes publications, Enregistrés, Mon réseau.
6. **les 7 sections de réglages deviennent 3 entrées**, chacune avec son état en sous-titre : « Confidentialité et sécurité — Profil visible · localisation activée », « Apparence et langue — Système · Français », « Aide et à propos — Version 1.2.0 ».

### 10b — Réglages (écran dédié)
Sections « Qui vous voit », « Sécurité », « Application », puis **zone sensible isolée** : carte bordée `#F0D9CE`, en-tête rouge, déconnexion puis « Supprimer mon compte — Définitif · 30 jours de délai ».

### 20a — Modifier le profil
Champs dans cet ordre : photo, **nom complet**, **bio avec compteur** (`118/160`), profession (liste fermée `ProfileOptions.professions` + option « Autre » qui ouvre un champ libre), **langues** en puces multi-sélection (Français, Anglais, Haoussa, Zarma, Arabe, Fulfulde, Tamashek), **centres d'intérêt** en puces, origine au Niger en une ligne cliquable, puis la carte de contact : **numéro de téléphone masqué** (`+33 6 12 •• •• 47`) + « Vérifié par SMS » + action Modifier (qui déclenche la vérification par code), et « Qui peut voir mon numéro ? · Amis ».

### 11f — Profil incomplet
Barre de progression (40 %, « 2/5 ») puis **trois champs manquants nommés avec leur bénéfice** :
- ville actuelle → « Vous apparaîtrez auprès des membres proches » ;
- métier → liste fermée ;
- langues → « Utile pour l'entraide et les démarches ».

Champs déjà remplis en `icon_check_circle` grisés. CTA « Compléter mon profil » + « Plus tard » discret.

### ⚠️ Deux champs à créer côté modèle
`ProfileEntity` n'a **ni poignée publique `@handle` ni compteur de groupes en commun**. Les maquettes 16f les montrent (nom d'utilisateur avec vérification de disponibilité) : à ajouter au modèle **avant** d'implémenter, ou à retirer de l'écran.

---

## 6 — Transfert d'argent (tours 12a, 16c, 25c, 28c)

**Fichiers** : `send_money_screen.dart`, `transaction_history_screen.dart`, `transaction_detail_screen.dart`

### La règle
**Le montant est le héros, et les frais se lisent avant la confirmation.** Jamais un total découvert dans une boîte de dialogue finale.

### 12a — Saisie
- stepper **sur une seule ligne** : rond 22 px + libellé 12 px, barre 2 px entre les étapes (`#B85E24` faite, `#E8DFD4` à venir) ;
- bénéficiaire en carte avec **moyen de paiement masqué** (`Orange Money · ***4721`) et « Changer » ;
- **montant en 44 px w700** `letterSpacing: -1.5`, devise 22 px `actionMuted`, sélecteur de devise en pastille ;
- 4 montants rapides (25 / 50 / 100 / 200), l'actif plein `#B85E24` ;
- **carte verte** `#F0F4EA` bordure `#DCE6CE` : « Hadiza recevra » + `32 790 FCFA` en 30 px `#1B5E32` + taux et durée de garantie en monospace ;
- récapitulatif frais / total débité **au-dessus** du bouton ;
- bouton portant le total : « Continuer · 51,50 € ».

### 16c — Historique
Filtres alignés sur l'enum `TransactionStatus` : En attente, En cours, Terminé, Échoué, Remboursé, Annulé. Ne pas inventer d'autres libellés.

Transfert en cours en carte avec **suivi en trois étapes** (Débité → En route → Disponible) : trois ronds 11 px reliés par des barres 2 px, libellés 10,5 px sous chaque étape, puis « Arrivée estimée aujourd'hui avant 18 h ». *Ce suivi est une proposition : vérifier que l'API le permet.*

Historique groupé par mois ; chaque ligne affiche le montant **en euros et en FCFA** ; un échec est barré et suivi de « Remboursé ».

### 28c — Modale de confirmation
Répète bénéficiaire, montant, frais, contre-valeur, **total débité**, moyen de paiement changeable, délai et durée de garantie du taux, et la phrase « un transfert envoyé ne peut pas être annulé ». Bouton : « Envoyer 51,50 € ».

---

## 7 — Boutique (tours 12b, 16a, 16b, 16h, 25b)

**Fichiers** : `marketplace_screen.dart`, `product_detail_screen.dart`, `cart_screen.dart`, `my_products_screen.dart`

- **Grille 2 colonnes**, image 118 px, puis **prix en premier** (15 px w700), titre, et vendeur (avatar 20 px) + ville. L'ordre compte : sur une place de marché on compare des prix.
- Filtre pays **fusionné dans la barre de recherche** (drapeau + chevron), pas une ligne séparée.
- **16a détail** : galerie 280 px avec pagination en pastilles, prix 26 px, compteur de vues, deux statistiques (vues / publié il y a), carte vendeur avec « Voir le profil », barre fixe « Contacter » + « Ajouter au panier ». Les libellés viennent du code : ne pas inventer « 8 ventes » ni « répond en 1 h ».
- **16b panier** : titre « Panier (2) » + « Vider », articles **groupés par vendeur** (une commande par vendeur), sélecteur de quantité 44 px, total, CTA « Commander · 69,00 € ».
- **25b mes annonces** : statut `EN LIGNE` / `VENDU`, vues et messages, actions Modifier / Marquer vendu ; commandes avec statut et action de suite (« Noter »).

---

## 8 — Notifications & recherche (tours 12c, 12d, 20d)

**`notifications_screen.dart`** : les **six onglets deviennent trois filtres** (Tout / Non lues + badge / Mentions). Les non-lues sont regroupées par jour, en cartes `#FBF1E9` bordure `#F0DCCB`, et surtout **actionnables sur place** : « J'y vais » pour un événement, « Accepter / Refuser » pour une demande d'ami. Les lues passent en lignes calmes avec la date en monospace.

**`search_screen.dart`** : recherches récentes en puces avec `icon_clock` + « Effacer » ; filtres **avec compteurs** (`Tout · 21`, `Membres · 12`…) ; résultats groupés en cartes, terme surligné, action directe par ligne (Suivre / Voir).

**`notification_settings_screen.dart`** : interrupteur maître, puis catégories dont chaque sous-titre dit la conséquence. Seuls « Événements locaux » et « Messages système » existent dans le code — le reste (Messages, Mentions uniquement, Transferts, **Heures calmes**) est une proposition à valider.

---

## 9 — Événements & ambassades (tours 13a, 13b, 16d, 17a, 17b, 25a)

**Événements** : pastille de date 52×56 flottante sur l'image (`02` 19 px `#B85E24` + `AOÛT` 10 px), badges d'état (`Gratuit` vert, `En ligne` `#E3EDF7`/`#1976D2`, `Complet` `#FBE9E5`/`#C23E2D`), participants en avatars empilés, et **un bouton par carte** — « Participer », ou « M'avertir » si complet. Regroupement « Cette semaine » / « Plus tard ».

**Ambassade** : bandeau d'état vert (ouvert / ferme à 16 h + adresse + distance), rouge pour « Temporairement fermé » avec date de réouverture ; badge « Compte officiel vérifié » ; **quatre actions** (Demande plein `#1976D2`, Contacter, Appeler, Y aller) ; onglets Infos / Activités / Actualités ; services consulaires **avec délai annoncé** ; horaires en monospace + juridiction.

**17b — contacter** : les cinq types réels en puces (Question générale, Demande de service, Réclamation, Renseignement, Suivi de dossier), Objet et Message marqués `*` avec leur règle sous le champ, pièce jointe optionnelle, et la mention de transmission **au-dessus** du bouton.

**16d — demande administrative** : ⚠️ `administrative_request_screen.dart` n'a pas été relu ; délais, tarifs et liste de pièces sont des propositions.

---

## 10 — Annuaire business (tours 17c, 17d, 18a–18d, 19c)

**Fichiers** : `businesses_screen.dart`, `business_detail_screen.dart`

- Carte entreprise : badges **Vérifié** (`icon_check_circle` `#1976D2`) et **Premium** (`#F7E9DE`/`#8C491A`), note + nombre d'avis, état `OUVERT` / `FERMÉ`, et l'**offre en cours** mise en avant dans une sous-carte `#FBF1E9`.
- Fiche : note · vues · état sur **une seule ligne**, quatre actions, offre avec **code promo** en pastille monospace et date de validité, horaires avec le jour courant en tête, dernier avis, « Écrire un avis » en barre fixe.
- **18c avis** : note moyenne 34 px, répartition par étoiles en barres, **réponse du gérant** en encart bordé à gauche.
- **19c mes entreprises** : trois compteurs (vues, avis, **à répondre**), compte à rebours de mise en avant, et la carte « en attente de vérification » qui dit l'action attendue.
- ⚠️ `create_business_screen.dart` et `boost_business_screen.dart` non relus : catégories, forfaits et prix sont des propositions.

---

## 11 — Support (tour 22)

**Fichiers** : `create_ticket_screen.dart`, `support_tickets_screen.dart`, `ticket_detail_screen.dart`

Trois idées à retenir :
1. **rattacher l'objet du problème** : depuis un transfert en cours, la demande de support embarque la transaction (carte avec bénéficiaire, montant, statut) ;
2. **joindre le contexte technique automatiquement** : bloc `#F7F3EC` « Joint automatiquement — Diaspo Niger 1.2.0 · Android 14 · Pixel 7 · FR ». Cela supprime un aller-retour systématique ;
3. **le ticket est une conversation** : vos messages en bulles vertes à droite, le support en cartes bordées à gauche avec l'avatar `support_agent`, et un composer identique au reste de l'app.

État vide : trois amorces typées (transfert bloqué / accès au compte / bug) qui **pré-remplissent le sujet**.

---

## 12 — Appels (tours 13c, 23a, 23b)

**Fichiers** : `call_history_screen.dart`, `call_screen.dart`, `group_call_screen.dart`

**Historique** : manqués annoncés dès le sous-titre de l'en-tête (`#C23E2D`), filtres avec compteur, et chaque ligne dit **type · heure · durée** avec l'icône directionnelle (`call_missed` / `call_made` / `call_received`) ; appels répétés regroupés (« 2 appels ») ; bouton de rappel audio ou vidéo 40 px à droite.

**En appel** : fond sombre dédié `#151210` avec un halo radial, badge de chiffrement, avatar 132 px avec halo 10 px, chrono 15 px monospace, qualité de ligne, **quatre contrôles nommés** de 64 px (le libellé sous l'icône évite l'ambiguïté du pictogramme seul), et Raccrocher pleine largeur 68 px.

**Groupe** : grille 2×2, vignettes `aspectRatio: .82`, **orateur actif encadré 2 px `#5BA674`**, micro coupé visible par vignette (`mic_off` rouge), badge `VIDÉO` si la caméra est active, et invitation à ajouter des membres.

---

## 13 — Fil : détail, création, sondage (tours 23c, 23d, 24d)

**`post_detail_screen.dart`** : le post en entier, **compteurs nommés** (« 24 j'aime », pas juste « 24 »), commentaires avec réponses **indentées à 42 px** et avatar réduit à 30 px, actions « J'aime · 4 » et « Répondre » sous chaque commentaire, composer fixe en bas avec votre avatar.

**`create_post_screen.dart`** : audience dans l'**en-tête** (puce « Public » avec icône + chevron), saisie 17 px / 1,55 avec les hashtags colorés `#8C491A` w600 et trois suggestions en puces, médias avec compteur `1/4`, options Sondage / Lieu, et le rappel « Les publications publiques sont visibles par toute la diaspora ».

**`poll_results_screen.dart`** : barres **remplies proportionnellement** (un `Stack` : fond `#EBDDC5`, remplissage `rgba(122,138,94,.35)` en largeur `%`), option gagnante encadrée 1,5 px `#7A8A5E` avec « votre choix », pourcentage + nombre de votes, liste des votants, rappel de visibilité.

---

## 14 — Discussion : galerie, favoris, nouvelle conversation (tour 24)

- **Galerie** : filtres avec compteurs (Photos · 36 / Vidéos · 2 / Documents · 4), grille 3 colonnes `gap: 4` groupée par mois, durée en pastille sur les vidéos, documents en lignes avec poids et téléchargement, et le rappel « conservés 15 jours sur le serveur ».
- **Favoris** : chaque favori porte **son origine** (conversation ou groupe + auteur), son extrait typé (texte, ou bloc note vocale), sa date, et « Aller au message ».
- **Nouvelle conversation** : champ « À : », raccourcis Nouveau groupe / Mes notes, puis **« Proches de vous »** (distance + présence) avant les contacts récents — c'est la valeur propre de l'app.

---

## 15 — Onboarding & entrée (tours 14, 15, 16f, 16g)

**Tokens Organic** : fond `#F5EAD8`, surface `#EBDDC5`, encre `#201E1D`, accent `#C67139`, texte secondaire `#5E564A` / `#82796A`, vert `#7A8A5E`. Titres en **Caprasimo** 30 px, corps en **Figtree**.

**Cinq écrans**, une promesse chacun : Bienvenue, Découvrez les membres, Rejoignez des groupes, Participez aux événements, Restez connectés. Illustration placeholder 300 px rayon 28, deux bénéfices cochés, indicateur à **puce active allongée** (26×8), « Passer » en haut à droite, « Suivant » en pilule 52 px.

**Le 5ᵉ écran demande les autorisations** (notifications + localisation, avec la réciprocité expliquée) plutôt que de les demander à froid plus tard, et propose « Plus tard, sans autorisations ».

**15a/15b connexion & inscription** : promesse avant le formulaire, Google en premier puis séparateur « ou », **libellés au-dessus** des champs, aide sous le champ, et surtout des **erreurs en langage clair** : « Il manque la fin de l'adresse, par exemple .com » — pas « Email invalide ». Jauge de mot de passe en 3 segments.

**Configuration du profil, 4 étapes** : 1/4 photo + nom + nom d'utilisateur + profession · 2/4 localisation (chaque champ dit ce qu'il débloque) · 3/4 centres d'intérêt + notifications · 4/4 thème en **aperçus miniatures** + couleur d'accent + récapitulatif « profil complété à 100 % ».

---

## 16 — Modales (tours 27, 28)

**Cinq règles, valables pour toutes les feuilles :**
1. **poignée 40×4** `#D8CCB8` centrée, marge basse 12–14 px ;
2. titre seulement s'il apporte quelque chose (une liste d'actions n'en a pas besoin) ;
3. **lignes de 48 px minimum** : `padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13)` ;
4. **action destructive isolée en bas**, après un filet `hairline`, jamais en premier ;
5. le bouton **nomme son action** : « Supprimer pour tous », « Envoyer 51,50 € », « Envoyer à Aïcha » — jamais « OK ».

**27a actions sur un message** : barre de réactions 46 px en tête (dont un « + »), puis Répondre / Copier / Transférer / Favoris, Supprimer isolé en rouge.

**27b confirmation destructive** : icône 48 px dans une pastille `#FBE9E5`, **délai rappelé** (« envoyé il y a 4 minutes »), **deux portées explicitées** — « Supprimer pour tous — Aïcha verra “message supprimé” » et « Supprimer pour moi — Reste visible chez Aïcha » — et Annuler en simple texte.

**27d joindre un média** : pellicule horizontale avec case cochée, **poids annoncé** (« 1 photo · 1,2 Mo ») et bascule « Qualité réduite » — indispensable en mode données réduites.

**28b audience** : chaque portée affiche **son volume réel** (86 personnes, 318 membres proches), et « un groupe précis » ouvre une sous-navigation.

---

## 17 — Salons audio & Podcasts (document séparé)

**Palette DNColors** (`lib/core/theme/dn_colors.dart`, existante) : encre `#1A1410` / `#3D342B` / `#7A6F64` / `#B8AC9D`, papier `#FAF6EF` / `#F0E8D8`, sable `#E8DCC4`, terracotta `#C85A3A` / `#9A3A20`, ocre `#D9A441`, teal `#2D6E6A`, feuille `#5A7A3A`, danger `#C23E2D`.

### Liste des salons (`audio_rooms_list_screen` + `audio_room_card`)
La carte **reprend le widget existant**, ne pas la réinventer : badge `EN DIRECT` (point 8 px + texte 10 px), titre 16, sous-titre 13, hôte en avatar rayon 14 + nom 13, tags `#tag` en puces 11 px, puis la ligne de métriques — « N participants » et `speakerCount/maxSpeakers` avec leurs icônes — et le prix du billet avec sa devise si le salon est payant.

Le salon **en direct** est mis en avant sur fond encre `#1A1410` ; les autres sur carte blanche. Salon programmé : pastille de date + heure **dans deux fuseaux** (« 18:30 Paris · 17:30 Niamey ») + « Me le rappeler ».

### Salon en direct (`audio_room_screen`)
Scène séparée des auditeurs. Pastilles de rôle reprises de `_RolePill` : **SPEAKER** (`#5A7A3A`) et **GHOST** (`#C85A3A`), 9 px monospace w700. L'orateur actif porte un anneau `boxShadow: 0 0 0 3px #5A7A3A` et une pastille micro 24 px ; un muet affiche `mic_off` sur fond `#3D342B`. Main levée = badge ocre 18 px avec ✋. Bandeau patrimoine (`Patrimoine · langue · région`) quand `isHeritageContent`, avec « ce salon sera archivé ».

### Création (`create_audio_room_screen`)
Quatre **modes** (Normal / Cérémonie / Radio / Patrimoine) en segments ; contenu patrimoine → puces de langue (Zarma, Hausa, Tamasheq, Kanouri, Peul, Arabe, Français) ; salon payant → prix + « Estimation reversée : ~95 % après commission » ; capacité « 10 intervenants · 1 000 auditeurs » ; collecte optionnelle (Aide urgence / Projet communautaire / Autre) ; deux sorties : « Programmer » et « 🎙 Commencer maintenant ».

### Don et billet (`send_tip_bottom_sheet`, `buy_ticket_bottom_sheet`)
- **Don** : paliers exacts **1 / 2 / 5 / 10 / 20 / 50 €** en grille 3×2, récapitulatif « le bénéficiaire reçoit **95 %** », mot optionnel, bouton « 🪙 Envoyer €5,00 ».
- **Billet** : prix, commission, reversement à l'hôte, puis les trois moyens réels — **Carte bancaire** (`stripe`), **Wave Mobile Money**, **Mynita** — les deux derniers avec « Code PIN demandé pour confirmer ». Le billet ouvre aussi le replay.

### Podcasts
- **Accueil** : bandeau « Reprendre » avec progression, abonnements en pochettes, nouveaux épisodes dont les payants sont **verrouillés** (cadenas + prix).
- **Lecteur** (`replay_player_screen`) : **chapitres réels** en puces (Introduction, Actualités, Diaspora & politique, Q&R, Conclusion), co-hôtes, vitesse, ±10 s / +30 s, minuteur de sommeil, téléchargement hors ligne.
- **Ligne d'épisode** (`episode_tile`, à respecter) : pochette 56 px avec le numéro en repli, badge « ÉPISODE N », badge **Premium** (et cadenas **à la place du bouton** quand l'accès manque), titre, description sur 2 lignes, durée, `playCount` précédé de `play_arrow`, **icône casque si l'épisode vient d'un salon** (`sourceRoomId`), et l'état de téléchargement `download_for_offline` → `download_done` **en vert**.
- **Revenus créateur** (`creator_earnings_screen`) : solde, versement programmé, répartition selon les **clés du code** (`tips`, `tickets`, `subscriptions`, `replays`, `total`) et historique avec les vrais `PayoutStatus` (en attente, en traitement, terminé, échoué, annulé). ⚠️ Les montants sont stockés **en centimes** : diviser par 100 à l'affichage. Aucun taux de commission n'est fixé dans le code hors les 95 % du don — ne pas en afficher un sans décision produit.
- **Modération fantôme** (`ghost_moderator_screen`) : bandeau d'invisibilité assumé, compteurs `visibleListeners` / `visibleSpeakers` + chrono, quatre actions (🔇 muet en silence, 👢 exclure, 🚫 bloquer partout, ⚠ avertir l'hôte) et fermeture forcée tracée. Préciser dans l'UI que « muet en silence » ne prévient pas la personne.

---

## 18 — Ordre de travail conseillé

Regroupé pour éviter les allers-retours :

1. **Tokens** (§0.1) + suppression des dégradés (§0.2) — une passe transverse.
2. **Fil et discussion** (tours 4–6) : c'est la demande initiale et le socle visuel.
3. **Messages / Groupes** (§3, §4).
4. **Accueil et Carte** (§1, §2) — la carte est le plus gros chantier structurel.
5. **Profil et réglages** (§5).
6. **Argent** (§6) — à traiter d'un bloc, la cohérence frais/total y est critique.
7. **Boutique, notifications, recherche** (§7, §8).
8. **Événements, ambassades, annuaire** (§9, §10).
9. **Support, appels** (§11, §12).
10. **Onboarding et entrée** (§15) — en dernier côté produit, mais à tester tôt côté autorisations.
11. **Modales** (§16) — une passe transverse une fois les écrans en place.
12. **Salons audio & Podcasts** (§17), puis le **back-office admin** (document séparé).

## 19 — À trancher avant implémentation

| Sujet | Décision attendue |
|---|---|
| `@handle` public | Ajouter au `ProfileEntity` ou retirer des écrans |
| Groupes en commun | Idem |
| Suivi de transfert en 3 étapes | L'API expose-t-elle ces étapes ? |
| Heures calmes (notifications) | Fonctionnalité à créer ou à retirer |
| Tarifs et délais consulaires | Relire `administrative_request_screen` |
| Catégories et forfaits business | Relire `create_business_screen`, `boost_business_screen` |
| Taux de commission (hors don) | Décision contractuelle |
| Statuts de commande boutique | Confirmer contre l'entité commande |
