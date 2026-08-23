# Tests à faire sur appareil physique

Récapitulatif de **tout le projet**, toutes sessions confondues, jamais
vérifié sur un vrai téléphone — les sessions ont quasi toujours tourné sans
émulateur ni appareil détecté de façon fiable (`adb devices` vide, ou
téléphone déconnecté en cours de route). `flutter analyze` et `flutter test`
sont propres partout, mais ça ne couvre ni le rendu visuel, ni les gestes,
ni les permissions runtime (caméra, localisation), ni le comportement réseau
réel (TURN/WebRTC, E2EE bout-en-bout).

Coché = vérifié sur appareil. Non coché = jamais testé. La partie 1 couvre la
refonte design Fil & Discussion (28 tours + salons/podcasts) ; la partie 2
couvre tout le reste du projet (E2EE, appels, admin, sécurité...).

---

## Le message de groupe illisible par son propre expéditeur — CAUSE TROUVÉE (2026-08-23)

Constaté sur SM A515F : le message qu'on vient d'envoyer dans un groupe
s'affiche **« 🔒 Message chiffré — clé de groupe introuvable »**, à son propre
auteur, une seconde après l'envoi. Il porte pourtant « Vu par 1 ».

**Ce n'est pas un défaut de chiffrement.** Signal (1:1) comme Sender Key
(groupes) font avancer le ratchet à l'émission et ne conservent pas la clé du
message envoyé : le texte clair de NOS messages n'existe que localement, par
construction. C'est un choix du protocole, pas un accident. Deux endroits le
laissaient filer.

**1. L'écho temps réel écrasait le texte clair.** `_reconcileEcho` gardait bien
la copie locale quand l'écho revenait illisible — mais son filtre ne
connaissait QUE `🔐 Message chiffré`. Les groupes remontent l'autre
placeholder, `[🔐 E2EE — session requise]` : l'écho passait au travers. La
liste existait en double, ici et dans `_undecryptablePlaceholders` du
repository — qui, lui, connaissait les deux — et elle avait divergé. Elle vit
désormais dans
[undecryptable_placeholders.dart](lib/core/services/e2ee/undecryptable_placeholders.dart),
avec la règle de fusion sous forme de fonction pure, testée.

**2. Le cache était empoisonné.** `getNewMessagesStream` mettait en cache les
messages du serveur tels quels, placeholder compris, et `cacheMessages`
fusionne par id avec la nouvelle version qui l'emporte. Le texte clair de
l'expéditeur n'était donc **jamais persisté** : à la réouverture de la
discussion, `_healUndecryptable` n'avait plus rien de bon à récupérer. Le flux
passe maintenant par le même soin que la pagination, et `sendTextMessage` met
le texte clair en cache dès l'envoi.

- [x] **Point 1 vérifié sur appareil** : « essai after fix » reste lisible
      douze secondes après l'envoi, là où il basculait en placeholder.
- [ ] **Point 2 NON vérifié** : l'automatisation de l'écran a dérapé (un tap a
      ouvert le composeur téléphonique — aucun appel passé) et j'ai arrêté là.
      Scénario à rejouer, trois gestes : envoyer un message dans un groupe,
      quitter la discussion, la rouvrir. Le texte doit rester lisible.

**Ce qui reste vrai, et n'est pas corrigé** : les messages envoyés AVANT ce
correctif restent illisibles pour toujours — leur texte clair n'a jamais été
persisté nulle part, et le chiffré ne se relit pas. Trois d'entre eux traînent
dans « Diaspora Niger — Canada ».

**Non exploré** : pourquoi la Sender Key n'est-elle pas établie au moment du
premier envoi ? `distributeGroupSenderKey` part en « fire and forget » au
chargement de la conversation (message_provider.dart) ; un envoi qui le précède
chiffre avec une clé que l'appareil ne sait pas relire. Le correctif ci-dessus
rend le symptôme invisible, il ne change pas ça.

---

## `MaÃ¯daoua` : l'échange de jeton Firebase corrompait le nom en base (2026-08-23)

**Cause enfin trouvée, et prouvée de bout en bout.**
`supabase/functions/auth-firebase-exchange/index.ts` décodait le JWT Firebase
avec `JSON.parse(atob(...))`. `atob` rend une chaîne **binaire** — un caractère
JS par octet, c'est-à-dire les octets UTF-8 relus comme du Latin-1. Le claim
`name` « Ibrahim Yacouba Maïdaoua » (`… 4d 61 c3 af 64 …`) devenait donc
« Ibrahim Yacouba MaÃ¯daoua », et la ligne `display_name: payload.name` de la
même fonction l'écrivait tel quel dans `users`.

Mesures prises pendant la session :

| Couche | État |
|---|---|
| Firebase Auth (source) | `4d61 c3af` — **propre** |
| Edge Function `auth-firebase-exchange` | produit `MaÃ¯daoua` |
| `users.display_name` en prod | `4d61 c383 c2af` — **corrompu** |
| Application (capture d'écran) | affiche « Ibrahim Yacouba MaÃ¯daoua » |

**Pourquoi c'était intermittent.** Deux écrivains se disputent la ligne :
`_upsertUserToSupabase` (Dart) écrit le nom CORRECT depuis le SDK Firebase,
l'Edge Function écrit le nom corrompu. Le dernier qui passe gagne. La même
ligne était propre en début de session et corrompue quelques heures plus tard,
sans que personne ne touche au profil — seulement une connexion.

Corrigé par `decodeJwtPart()`, qui repasse par `Uint8Array` + `TextDecoder`.
L'`atob` de la **signature** est laissé tel quel : là, l'interprétation octet
par octet est justement ce qu'on veut.

- [x] **DÉPLOYÉE** le 2026-08-23.
- [x] **DONNÉE RÉPARÉE** le 2026-08-23, après le déploiement. Requête utilisée :
      `UPDATE users SET display_name = convert_from(convert_to(display_name,'LATIN1'),'UTF8')
       WHERE id = 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2';`
      Vérifié ensuite dans l'application : « Ibrahim Yacouba Maïdaoua »
      s'affiche correctement.

---

## Mentions de groupe : vérifié sur SM A515F (2026-08-23)

Build debug installé sur l'appareil, compte `Sim A`, groupe « Diaspora
Niger — Canada » (3 membres).

**Défaut trouvé sur appareil, invisible aux tests : la liste de suggestions ne
s'ouvrait jamais.** `groupMentionCandidatesProvider` était un
`FutureProvider.autoDispose.family` **clé par `List<String>`**. Une `family`
Riverpod compare ses clés avec `==`, et deux `List` de même contenu ne sont
jamais égales en Dart : chaque `build` de l'écran créait donc une nouvelle
instance de provider, qui repartait en chargement, et `.valueOrNull` rendait
`null` indéfiniment. La clé est désormais l'identifiant du groupe, et ce n'est
plus un `FutureProvider` (il ne fait que lire d'autres providers).

Le prédécesseur `groupMemberNamesProvider` avait exactement la même forme :
**mentionner quelqu'un dans un groupe n'avait probablement jamais fonctionné**,
quelle que soit la forme du pseudo.

- [x] Taper `@sa` ouvre la liste — « Salim L. » en titre, `@SalimL` en
      sous-titre. Le filtre trouve bien par le **début d'un mot** du nom
      affiché, pas seulement par le début du nom complet.
- [x] Sélectionner insère `@SalimL ` — pseudo sans espace, espace après,
      curseur derrière, liste refermée. Le point de « Salim L. » est bien
      retiré.
- [x] Le membre `diaspo_ne` n'apparaît pas sur `@sa` : le filtrage est correct,
      il ne propose pas tout le monde.
- [ ] Coloration de la mention dans la bulle — **bloqué**, pas par les
      mentions : le message envoyé s'affiche « clé de groupe introuvable »
      (voir l'entrée E2EE ci-dessus). Le contenu n'est pas rendu comme du
      texte, donc rien à colorer.
- [ ] Tap sur la mention → ouvre le profil — bloqué par la même chose.
- [ ] Compte **avec** poignée : vérifier que c'est `@diaspo_ne` qui est inséré
      et non l'identifiant. Le filtre `@sa` ne le proposait pas ; à retenter
      avec `@dia`.
- [x] Le garde anti-e-mail fonctionne — trop bien, même : un `@` précédé d'un
      caractère de mot n'ouvre pas la liste. Rencontré pour de vrai, un
      brouillon `@sa` restant en place faisait que le second `@sa` tapé
      derrière n'ouvrait rien. C'est le comportement voulu, mais il surprend.

---

## Mentionner quelqu'un par son pseudo dans un groupe (2026-08-23)

Mentionner dans un groupe insérait le **nom affiché complet** :
`@Ibrahim Yacouba Maïdaoua`. Un jeton à espaces, que la détection ne savait pas
relire — `_detectMentionTrigger` abandonne dès qu'une espace apparaît dans la
saisie, donc seul le **premier mot** était cherchable, et taper `@Maï` ne
proposait personne.

Les messages passent au même pseudo que le fil
([mention_handle.dart](lib/core/utils/mention_handle.dart)) : la **poignée
publique** (`users.handle`) quand la personne en a choisi une, sinon le pseudo
dérivé du nom. Au 2026-08-23, 2 comptes sur 11 seulement avaient une poignée —
le repli est le cas courant, pas le cas limite.

Ce qui change :

- [group_pinned_providers.dart](lib/features/groups/presentation/providers/group_pinned_providers.dart) :
  `groupMemberNamesProvider` → `groupMentionCandidatesProvider`, qui porte
  aussi la poignée (nouveau type `MentionCandidate`).
- [message_input.dart](lib/features/messages/presentation/widgets/message_input.dart) :
  filtrage sur le pseudo **et sur chaque mot** du nom affiché, accents repliés
  (`@mai` trouve « Maïdaoua » — taper `ï` demande un appui long au clavier) ;
  insertion du pseudo ; un `@` collé à un caractère de mot n'ouvre plus la
  liste (adresse e-mail en cours de frappe).
- [mention_suggestion_overlay.dart](lib/features/messages/presentation/widgets/mention_suggestion_overlay.dart) :
  la ligne montre le nom **et** le `@pseudo` — on choisissait un `@` sans
  savoir à qui il correspondait.
- [message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart) :
  la mention devient **cliquable** (elle était colorée et c'est tout) et ouvre
  le profil, comme dans le fil ; les motifs de coloration sont triés du plus
  long au plus court, sinon `@Ali` placé avant `@Alichina` ne colorait que les
  trois premières lettres de la seconde.

Les messages déjà envoyés portent le nom affiché dans `mentionedUsers[].name` :
le rapprochement se fait sur ce qui est stocké, ils restent donc colorés et
cliquables tels quels.

14 tests dans
[mention_groupe_test.dart](test/features/messages/mention_groupe_test.dart).

**À vérifier sur appareil** (nécessite un groupe avec au moins deux membres) :

1. Dans un groupe, taper `@` puis `mai` → la personne doit apparaître, avec son
   nom en titre et `@pseudo` en dessous.
2. La sélectionner → le texte doit contenir `@<pseudo>` **sans espace**, suivi
   d'une espace, curseur juste après.
3. Envoyer → la mention doit être colorée en entier dans la bulle, chez
   l'expéditeur comme chez le destinataire.
4. **Taper sur la mention** → doit ouvrir le profil de la personne.
5. Sur un compte qui a choisi une poignée (`@…` dans Profil), vérifier que
   c'est bien elle qui est insérée, et pas le nom collé.
6. Taper une adresse e-mail (`a@b.com`) dans un groupe : la liste de
   suggestions ne doit **pas** s'ouvrir.
7. Ouvrir un ancien message qui contient une mention : elle doit rester colorée.

**Non traité** : mentionner quelqu'un dans un groupe ne produit pas de
notification distincte — le déclencheur SQL envoie déjà une notification de
message à tous les participants, une notification « mention » demanderait une
migration.

**Dette laissée en place** : les `TapGestureRecognizer` des liens, téléphones et
désormais mentions sont créés à chaque `build` sans être libérés. C'était déjà
le cas pour les liens ; corriger l'ensemble est un chantier à part.

---

## Le pseudo de mention mangeait les lettres accentuées (2026-08-23)

`_toMentionHandle` produisait le `@pseudo` avec
`replaceAll(RegExp(r'[^\w]'), '')`. En Dart, `\w` vaut `[A-Za-z0-9_]` — de
l'ASCII pur : mentionner « Ibrahim Yacouba Maïdaoua » écrivait
`@IbrahimYacoubaMadaoua`, le `ï` purement supprimé. Même effet sur « Aïcha »,
« Boubé », ou tout nom non latin (`李明` donnait une chaîne vide).

Quatre endroits partageaient la même limite ASCII et sont passés sur
[mention_handle.dart](lib/core/utils/mention_handle.dart) :

- génération, détection et remplacement du pseudo dans
  [mention_text_field.dart](lib/features/feed/presentation/widgets/mention_text_field.dart) ;
- coloration en direct dans le champ de saisie
  ([hashtag_highlighting_controller.dart](lib/features/feed/presentation/widgets/hashtag_highlighting_controller.dart)) ;
- reconnaissance de la mention à l'affichage
  ([rich_text_parser.dart](lib/core/utils/rich_text_parser.dart)) — le motif
  s'arrêtait au `ï`, la mention n'était donc ni colorée en entier ni cliquable ;
- résolution du profil au tap dans
  [post_card.dart](lib/features/feed/presentation/widgets/post_card.dart) et
  [comment_tile.dart](lib/features/feed/presentation/widgets/comment_tile.dart).

**Repli sur les deux formes.** Les publications et commentaires déjà en base
portent l'ancien pseudo, dans leur texte comme dans `mentioned_users[].name`,
et rien ne les réécrit. `mentionHandleMatches` compare les deux réduits à
l'ASCII, dans les deux sens, avec une garde pour que deux noms non latins (qui
se réduisent tous les deux au vide) ne se confondent pas.

Le `#hashtag` reste volontairement sur `\w` : c'est ce que `extractHashtags`
enregistre et recherche, l'élargir changerait la donnée stockée.

16 tests dans
[mention_handle_test.dart](test/core/utils/mention_handle_test.dart), dont un
test de widget qui construit vraiment la RegExp du contrôleur de coloration
(elle est `static final` : invalide, elle ne se verrait qu'à la première frappe
dans « nouvelle publication »).

**À vérifier sur appareil** :

1. Nouvelle publication → taper `@Maï` : la personne doit apparaître dans les
   suggestions, et la sélectionner doit insérer `@IbrahimYacoubaMaïdaoua`
   **avec le tréma**, coloré en entier pendant la frappe.
2. Publier, puis taper sur la mention dans le fil : elle doit ouvrir le profil.
3. **Le cas du repli** : ouvrir une publication ou un commentaire **ancien**
   qui contient déjà une mention (forme ASCII), taper dessus — elle doit
   toujours ouvrir le bon profil.
4. Même chose dans les commentaires (`comment_tile`).

Non couvert par les tests : le rendu réel de la liste de suggestions et le
comportement du clavier pendant la saisie du `@`.

---

## Neuf défauts signalés à l'usage — correctifs du 2026-08-22

Salim a remonté neuf symptômes après usage réel. Huit ont une cause trouvée et
corrigée, le neuvième attend un exemple. **Aucun n'est vérifié sur appareil.**

### 1. L'appui sur une notification ne faisait rien

Deux causes indépendantes, toutes deux corrigées :

- `NotificationService.createNotification`
  ([notification_service.dart](lib/core/services/notification_service.dart))
  n'écrivait que `target_id` dans `data`, quand le modèle ne lisait que
  `targetId`. Toutes les branches de navigation étant gardées par
  `if (targetId != null)`, l'appui était sans effet — demandes d'ami,
  participations aux événements, tout ce qui passe par cette RPC.
- Les types écrits par les déclencheurs SQL (`new_post`, `mentioned`,
  `group_mention`) et par le client (`report_resolved`, `groupCallInvitation`,
  `postCommented`, `commentReply`) n'existaient pas dans `NotificationType` :
  ils étaient repliés sur `general`, dont le `case` de navigation est vide.

**À vérifier sur appareil** : ouvrir la page Notifications sur un compte qui a
reçu (a) une demande d'ami, (b) une notification de publication du fil, (c) un
commentaire. Chacune doit ouvrir sa destination. Une notification sans
destination connue ouvre désormais sa fiche au lieu de ne rien faire.

### 2. « Erreur de chargement » intermittente sur les notifications

Le flux temps réel s'abonnait sans attendre la session Supabase (course avec le
pont Firebase vers Supabase : abonnement en `anon`, RLS muette), et une seule
ligne au `title`/`body` nul faisait échouer le `.map()` du flux ENTIER. Corrigé
dans [notification_supabase_datasource.dart](lib/features/notifications/data/datasources/notification_supabase_datasource.dart) :
attente de session, réessai avec conservation de la dernière liste connue, et
ligne illisible écartée au lieu de tout emporter.

**À vérifier** : ouvrir la page Notifications juste après un démarrage à froid
(le cas où la course se produit), puis couper/rétablir le réseau en restant sur
l'écran — la liste doit revenir seule, sans message d'erreur.

### 3. Le bandeau de restauration des clés revenait sans arrêt

`acknowledge()` ne vivait qu'en mémoire, et `bootstrap()` est appelé depuis
quatre endroits d'`AuthNotifier`. Le bandeau revenait donc à chaque démarrage et
à chaque rechargement de profil, indéfiniment (`needsRestore` reste vrai tant
que la sauvegarde n'est pas restaurée). Mise en veille désormais persistée
7 jours, et `bootstrap` ne tourne qu'une fois par compte et par session
([e2ee_backup_coordinator.dart](lib/core/services/e2ee/e2ee_backup_coordinator.dart)).

**À vérifier** : écarter le bandeau avec « Pas maintenant », tuer l'app, la
rouvrir — il ne doit pas revenir. Puis faire une vraie sauvegarde depuis
Sécurité : la veille est effacée.

### 4. Caractères spéciaux mal affichés — PARTIELLEMENT traité

Une cause identifiée et corrigée : le motif de mise en forme (gras, italique,
barré, code) de
[message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)
reconnaissait ses marqueurs au MILIEU d'un mot et les supprimait de
l'affichage — `taux_change_2026` perdait ses tirets bas et passait en italique.
Les délimiteurs doivent désormais être isolés (règle WhatsApp/Signal).

**Reste ouvert** : si le symptôme concerne d'autres caractères (emoji, accents,
caractères zarma/haoussa), il faut un exemple précis — quel caractère, à quel
endroit, et ce qui s'affiche à la place. Rien d'autre n'a été trouvé dans le
code (aucun mojibake dans le dépôt, apostrophes ICU correctes dans les ARB
générés).

### 5. La bulle « écrit… » ne s'affichait jamais

`typingIndicatorNotifierProvider` est `autoDispose` et n'était jamais observé :
chaque frappe le créait via `ref.read`, Riverpod le détruisait aussitôt, et sa
destruction appelait `_clearTypingStatus()`. La présence était donc posée puis
retirée dans le même tour de boucle. `ConversationScreen` l'observe désormais
dans son `build` ; `setTypingStatus` attend en plus que le canal realtime soit
rejoint avant de publier la présence.

**À vérifier — nécessite DEUX téléphones** : A tape, B doit voir la bulle
apparaître, et disparaître ~3 s après l'arrêt de la frappe puis à l'envoi. B
quitte la discussion : la présence doit s'effacer chez A.

### 6. Les messages vocaux ne partaient pas

`MessageSupabaseDataSource.sendAudioMessage` levait `UnimplementedError`, que le
repository attrapait dans son `catch (e)` générique : tout message vocal
échouait en silence. Implémenté (téléversement Firebase Storage, insertion
`messages` de type `voiceNote`, mise à jour du dernier message).

**À vérifier** : enregistrer un vocal, l'envoyer, vérifier qu'il arrive chez le
destinataire, qu'il se lit des deux côtés, que la forme d'onde et la durée sont
justes, et que l'aperçu de la conversation affiche « Message vocal ».

### 7. Les messages en échec disparaissaient au lieu d'être renvoyés

`retryFailedMessage` retirait la bulle **en tête de méthode**, avant le
`switch` — puis, pour un média, retournait `false` sans rien renvoyer : taper
« réessayer » était le moyen le plus sûr de perdre le message. Le retrait n'a
lieu que sur un chemin qui renvoie réellement, et un vocal en échec retient
désormais le chemin de son fichier local (`MessageEntity.localFilePath`) pour
pouvoir être retéléversé. En prime, `_loadNetworkData` remplaçait l'état entier
par la réponse serveur, ce qui effaçait aussi les messages en échec à chaque
rechargement.

**À vérifier** : couper le réseau, envoyer un texte et un vocal, attendre le
passage en échec, rétablir le réseau, taper « réessayer » sur chacun — les deux
doivent partir. Puis refaire un échec, changer d'écran et revenir : la bulle en
échec doit toujours être là. **Limite connue** : rien n'est persisté sur disque,
quitter l'app perd les messages en échec.

### 8. Un seul horodatage par rafale de messages envoyés

C'était volontaire (regroupement visuel des rafales, heure révélée par un tap),
mais illisible à l'usage. Chaque bulle porte désormais son heure, envoyée comme
reçue — le regroupement visuel (queue de bulle, nom, rayons) est inchangé.

**À vérifier** : envoyer trois messages d'affilée, les trois doivent afficher
leur heure ; vérifier que l'accusé « Envoyé / Lu » reste correct et que la mise
en page ne déborde pas avec des réactions.

### 9. L'app restait utilisable par-dessus l'écran de verrouillage — SÉCURITÉ

`android:showWhenLocked="true"` était posé sur `MainActivity` dans le manifeste
pour que l'écran d'appel s'affiche par-dessus le keyguard. Un attribut de
manifeste vaut pour toute la vie de l'activité : verrouiller le téléphone avec
Diaspo Niger au premier plan puis rallumer l'écran rouvrait l'application
entière — messages compris — sans demander le code. Le drapeau est retiré du
manifeste et demandé à l'exécution par l'écran d'appel seulement
([lock_screen_service.dart](lib/core/services/lock_screen_service.dart), canal
`diaspo_niger/lockscreen`).

**À vérifier sur appareil, en deux temps** :

1. App ouverte sur une discussion, verrouiller, rallumer l'écran : le keyguard
   DOIT demander le code, l'app ne doit pas être visible.
2. Recevoir un appel téléphone verrouillé, accepter depuis la bannière :
   l'écran d'appel doit s'afficher par-dessus le keyguard et l'écran s'allumer.
   Raccrocher, verrouiller à nouveau, puis revalider le point 1 (le privilège
   doit avoir été rendu).

---

## Icônes des tuiles de services agrandies (2026-08-19)

Demande de Salim : icônes plus grandes sur les tuiles de services.
- Grille de l'accueil (`_ServiceTile`,
  [home_screen_widgets.dart](lib/features/home/presentation/screens/home_screen_widgets.dart)) :
  26 → 32.
- « Tous les services » (`QuickActionCard`,
  [quick_action_card.dart](lib/features/home/presentation/widgets/quick_action_card.dart),
  utilisé uniquement par cet écran) : 28 → 36.

Vérifié sur SM A515F le 2026-08-19 (thème sombre, captures dans la session) :
- [x] Pas de débordement des cartes « Tous les services » (grille 2 colonnes,
  `childAspectRatio: 1.1`) avec la font scale 1.1 du SM A515F — 5 tuiles
  affichées, icône 36 nette dans la pastille, aucune troncature.
- [x] Rendu de la grille accueil en 3 colonnes (icône 32 dans le carré) —
  le cas 4 colonnes reste à voir (il faut ≥ 4 tuiles actives).
- [x] Thème clair (basculé via `cmd uimode night no`, remis en sombre
  ensuite) : accueil et « Tous les services » propres, pastilles teintées
  lisibles, aucune troncature.

---

## Annuaire, Fil et Ambassades toujours actifs — plus de flag (2026-08-19)

Décision produit : ces trois services ne dépendent plus du back-office.
`isBusinessDirectoryEnabled`, `isEmbassiesEnabled` et `isFeedEnabled`
renvoient `true` en dur
([feature_flag_service.dart](lib/core/services/feature_flag_service.dart)),
`/businesses` est sorti du garde du routeur, les tuiles des deux grilles
(accueil + « Tous les services ») sont inconditionnelles, et les deux
interrupteurs du back-office sont affichés verrouillés sur « Toujours actif »
([admin_feature_flags_screen.dart](lib/features/admin/presentation/screens/admin_feature_flags_screen.dart)).

Vérifié sur SM A515F le 2026-08-19 — probant : la prod a `businessDirectory:
false` (lu le même jour, voir l'entrée ci-dessous), donc ces tuiles ne
peuvent venir que du « toujours actif » :
- [x] Accueil et « Tous les services » montrent bien Annuaire + Ambassades
  même si le back-office les avait désactivés (c'était le symptôme de départ :
  seule « Ambassades » s'affichait). Accueil = Fil/Annuaire/Ambassades,
  « Tous les services » = + Événements + Amis.
- [x] `/businesses` s'ouvre (écran « Annuaire Business », vide de données
  mais fonctionnel — plus de redirection silencieuse vers /home).
- [x] Back-office → Fonctionnalités : les deux interrupteurs Annuaire et
  Ambassades verrouillés sur actif (sous-titre explicatif, les autres
  manœuvrables) — couvert par un test de widget plutôt qu'un test appareil :
  `test/features/admin/feature_flags_toujours_actifs_test.dart` (le serveur
  dit `false`, l'écran doit quand même les montrer actifs et non
  manœuvrables ; exactement 2 interrupteurs verrouillés).
- [ ] Pins « entreprises » de la carte : **structurellement morts, pas juste
  faute de données** (constat 2026-08-19). `getNearbyBusinesses`
  ([business_remote_datasource.dart](lib/features/businesses/data/datasources/business_remote_datasource.dart))
  filtre sur `latitude`/`longitude`, mais ni la création ni l'édition
  d'entreprise ne renseignent ces champs — un doc créé par l'app est exclu
  par la range query, et le filtre longitude rejette les null. Même famille
  que les « champs jamais alimentés ». **Correctif livré le 2026-08-19
  (même jour, session worktree) : voir la section « Position des entreprises »
  ci-dessous pour les vérifications appareil.**

Bloqué pour la session du 2026-08-19 (agent seul avec le téléphone) :
- Le back-office est une app séparée (`lib/features/admin/main.dart`) dont
  l'écran de connexion n'a **aucune reprise de session** — login manuel
  obligatoire, donc test « sauvegarde → `lastUpdated` bouge » à faire par
  Salim avec le compte « Salim L. » (vérifié `adminRole=superAdmin` en base :
  la règle d'écriture passera ; le compte « Sim A » du téléphone est un autre
  compte). La sérialisation étant corrigée (voir entrée dédiée), les
  interrupteurs Salons/Podcasts devraient enfin agir.
- Le cas 4 colonnes de l'accueil : l'écriture directe du flag `audioRooms`
  en prod a été refusée par le classificateur de permissions de la session —
  à voir après une vraie sauvegarde back-office.

À savoir : les hash de `feature_flag_service.g.dart` n'ont pas été régénérés
(build_runner non relancé — signatures inchangées, seul le hot-reload debug
de ces 3 providers peut être moins fin).

---

## Position des entreprises : création/édition alimentent enfin latitude/longitude (2026-08-19)

Correctif de la couche « entreprises » morte de la carte (voir l'entrée
« Pins entreprises » ci-dessus). Ce qui a changé :

- [create_business_screen.dart](lib/features/businesses/presentation/screens/create_business_screen.dart)
  gagne une tuile « Position sur la carte » (section Localisation) qui ouvre
  le `LocationPickerModal` de la messagerie (GPS, tap carte, recherche de
  lieu) ; à défaut de choix explicite, l'adresse saisie est géocodée à la
  soumission (meilleur effort, 5 s, jamais bloquant).
- Le même écran devient l'écran d'édition (`/businesses/:id/edit`) : **cette
  route n'existait pas** — le menu « Modifier » de la fiche poussait dans le
  vide depuis toujours.
- `getNearbyBusinesses` : le calcul du delta de longitude utilisait une
  fonction `_cos` qui convertissait en radians **sans jamais appliquer le
  cosinus** (à Niamey, fenêtre ~4× trop large). Corrigé avec `dart:math`.
- `updateBusiness` (datasource) n'écrase plus les champs serveur
  (`createdAt`, compteurs, boost, `isVerified`) — sinon la première édition
  aurait retapé `createdAt` en chaîne ISO et cassé les tris.

Aucune reprise de données à faire : l'annuaire est vide en prod au
2026-08-19 (constaté sur l'écran « Annuaire Business » le même jour).

À vérifier sur appareil (rien de tout ceci n'a tourné sur un vrai téléphone) :
- [ ] Créer une entreprise avec position choisie sur la carte (permission
  localisation runtime, gestes du modal dans le bottom sheet, thème sombre
  de la tuile et du modal), puis vérifier que le **pin apparaît sur la
  carte** (couche entreprises activée) et que son tap ouvre la fiche.
- [ ] Créer une entreprise **sans** toucher la carte mais avec une adresse
  réelle : le géocodage de repli doit poser lat/lng (à vérifier en base ou
  par le pin) ; hors ligne ou adresse introuvable, la création doit passer
  quand même, juste sans pin.
- [ ] Menu « Modifier » de la fiche (propriétaire) : l'écran s'ouvre
  prérempli (photos existantes supprimables, pays, téléphone re-séparé
  indicatif/numéro), la position existante s'affiche et se modifie, et la
  fiche détail montre les changements au retour.
- [ ] `viewCount`/`averageRating`/`isBoosted` inchangés en base après une
  édition (garde anti-écrasement du datasource).

---

## Flags Salons audio / Podcasts / Fil enfin sérialisés + maintenance sans écrasement (2026-08-19)

Deux bugs de la même famille que les préférences profil (reconstruction
partielle) corrigés dans le module admin :

1. `FeatureFlagsModel`
   ([app_settings_model.dart](lib/features/admin/data/models/app_settings_model.dart))
   ne sérialisait **pas du tout** `audioRooms`, `podcasts`, `feed` : les
   interrupteurs « Salons audio » et « Podcasts » du back-office étaient
   perdus à l'écriture, et la lecture retombait toujours sur les défauts de
   l'entité (salons/podcasts désactivés) quoi que contienne Firestore. C'est
   une cause plus simple que la piste « écriture refusée en silence » notée
   le 2026-08-19 ci-dessous : même acceptée, l'écriture ne contenait pas ces
   clés.
2. `toggleMaintenanceMode`
   ([app_settings_provider.dart](lib/features/admin/presentation/providers/app_settings_provider.dart))
   reconstruisait l'entité champ par champ (6 flags sur 9) : basculer la
   maintenance aurait écrasé `audioRooms`/`podcasts`/`feed` avec les défauts.
   Réécrit en `copyWith`, avec sentinelle dans
   [app_settings_entity.dart](lib/features/admin/domain/entities/app_settings_entity.dart)
   pour que `maintenanceMessage: null` efface vraiment le message (l'écran
   admin passait déjà `null` pour effacer — no-op silencieux avant).

Couvert par `test/features/admin/feature_flags_maintenance_test.dart`
(aller-retour modèle, copyWith, écriture réelle du provider sur faux
datasource).

**État prod lu le 2026-08-19** (admin SDK, lecture seule) : `featureFlags` =
audioRooms `false`, podcasts `false`, businessDirectory `false`, marketplace
`false`, moneyTransfer `false`, events/groups/embassies `true`, pas de clé
`feed` ; **`lastUpdated` = 2026-05-22** → aucune sauvegarde du back-office
n'a abouti depuis 3 mois. La règle déployée exige
`users/{uid}.adminRole == 'superAdmin'` pour écrire `app_config/*`, et la
famille « faux succès » des `set()` Firestore masquerait un refus : le test
appareil ci-dessous doit donc se juger sur le **document** (le `lastUpdated`
doit bouger), pas sur l'absence d'erreur à l'écran.

**Non vérifié sur appareil** :
- [ ] Back-office : activer « Salons audio » et « Podcasts », sauvegarder,
  relancer l'app → `/audio-rooms` et `/podcasts` ne redirigent plus sur
  `/home` (première fois que ces interrupteurs peuvent réellement agir).
- [ ] Back-office : basculer le mode maintenance ON puis OFF → les
  interrupteurs Salons audio/Podcasts gardent leur état (avant le correctif
  ils seraient retombés à désactivé). Le flag `feed` est lui aussi préservé
  dans Firestore, même s'il n'agit plus sur l'app depuis que le Fil est
  toujours actif (voir l'entrée ci-dessus).
- [ ] Effacer le message de maintenance (vider le champ) puis sauvegarder →
  le message ne réapparaît pas à la réouverture de l'écran.

---

## « Tous les services » complété : Fil, Événements, Amis (2026-08-19)

L'écran « Tous les services »
([services_screen.dart](lib/features/home/presentation/screens/services_screen.dart))
ne listait que 6 tuiles (Transfert, Marketplace, Annuaire, Ambassades, Salons
audio, Podcasts) — moins que la grille de l'accueil, qui a en plus « Le fil ».
Ajoutés : **Le fil** (`/feed`, sans flag, comme sur l'accueil), **Événements**
(`/events`, gaté `isEventsEnabledProvider` — le module avait un flag et une
route mais aucune tuile nulle part), **Amis** (`/friends`, sans flag).

Vérifié sur SM A515F le 2026-08-19 (thèmes sombre ET clair) :
- [x] Rendu de la grille 2 colonnes avec les tuiles de plus (5 affichées,
  pas de débordement, `childAspectRatio: 1.1`) — dans les deux thèmes.
- [x] Tap sur chaque nouvelle tuile : Fil (posts affichés), Événements
  (liste vide fonctionnelle), Amis (1 ami listé) s'ouvrent, et le retour
  système revient bien sur « Tous les services » à chaque fois.
- [x] Couleur `Colors.teal` de la tuile Événements lisible en thème sombre.

À noter (vu pendant la session, non corrigé ici) : si le back-office affiche
des fonctionnalités actives que l'app ne montre pas, l'écriture des flags a pu
être refusée en silence (règle Firestore `isSuperAdmin()` sur `app_config` +
famille « faux succès » des `set()` Firestore) — diagnostic en cours côté
prod.

---

## Carte « Pour commencer » : chaque ligne gagne son propre critère (2026-08-14)

Les 3 lignes de `_PourCommencerCard`
([home_screen_widgets.dart](lib/features/home/presentation/screens/home_screen_widgets.dart))
restaient toutes affichées tant que le *profil* était incomplet (photo/ville/
pays/profession/bio), même si l'utilisateur avait déjà rejoint des groupes ou
discuté avec quelqu'un — aucune des 3 actions n'était suivie individuellement.
Chaque ligne se masque désormais sur son propre signal, calculé dans
[home_screen.dart](lib/features/home/presentation/screens/home_screen.dart) :
- « Trouver des proches » : `conversationsProvider` contient une conversation
  individuelle qui n'est pas « Mes notes » (`isIndividual && !isSelfNotesFor`) ;
- « Rejoindre un groupe » : `myGroupsNotifierProvider` non vide ;
- « Activer la carte » : `_locationError == null` (même signal que la ligne
  « membres proches » du bloc « Aujourd'hui », déjà en prod).

`flutter analyze` propre sur les deux fichiers touchés. **Non vérifié sur
appareil** : il faudrait un compte avec profil incomplet MAIS déjà dans un
groupe (ou déjà en conversation) pour confirmer que la ligne correspondante
disparaît bien sans faire disparaître les deux autres, et que la carte entière
se masque quand les 3 sont accomplies pendant que le profil reste incomplet.

---

## Un second appel qui arrive pendant qu'on est déjà en ligne était perdu en silence (2026-08-14)

Trouvé en rejouant le logcat d'un vrai test (deux comptes qui s'appelaient
quasi en même temps, 21:53-21:54) : `incomingCallProvider`
([call_provider.dart:1122](lib/features/calls/presentation/providers/call_provider.dart))
renvoie `null` dès que `state.call` est déjà occupé — y compris par un appel
que l'utilisateur vient de composer lui-même. L'évènement natif `accepted`
tombe alors dans le repli `_answerCallFromBackground`, qui appelle bien
`answerCall()` avec le BON callId, mais le garde anti-double-acceptation de
`answerCall()` ([call_provider.dart:436](lib/features/calls/presentation/providers/call_provider.dart))
le rejette silencieusement parce qu'un AUTRE appel est déjà dans `state.call`
— `return false`, aucun retour à l'appelant, aucun message à l'utilisateur.
Résultat observé : l'écran d'appel affiché reste celui du premier appel (le
sien), qui finit enregistré `cancelled` faute de réponse, et le second — celui
qu'on vient d'accepter — ne démarre jamais.

Correctif : dans ce cas précis (callId différent de celui déjà en cours),
`answerCall()` décline maintenant le second appel côté distant
(`declineCall`) et referme sa bannière CallKit spécifique
(`NativeCallService.endCallById`, nouveau — n'touche pas `_activeCallUuid` du
premier appel). L'appelant du second appel doit désormais recevoir un signal
« occupé » au lieu de sonner dans le vide. En même temps, ajout d'un plafond
de 15 s sur `initiateCall` (`_initiateCallTimeout`) : la même session a montré
`initiateCall` pendu ~62 s sans aucun retour visible, le temps qu'une session
Supabase invalide (`Session Supabase non établie`, pertes DNS ponctuelles) se
resynchronise — probablement un aléa réseau réel plutôt qu'un bug, mais sans
plafond le bouton d'appel semblait juste mort.

`flutter analyze` propre sur les deux fichiers touchés
([call_provider.dart](lib/features/calls/presentation/providers/call_provider.dart),
[native_call_service.dart](lib/core/services/native_call_service.dart)).
**Non vérifié en situation réelle** : il faudrait deux appareils qui
s'appellent l'un l'autre à quelques secondes d'écart pour confirmer que
l'appelant du second appel voit bien « occupé » plutôt que de sonner dans le
vide, et que le premier appel n'est pas perturbé au passage.

---

## Réponse rapide depuis la notification n'envoyait jamais rien (2026-08-13)

Deux bugs cumulés. (1) `currentUserId` dans SharedPreferences — lu par
[background_reply_service.dart](lib/core/services/background_reply_service.dart)
et 4 autres endroits de
[notification_service.dart](lib/core/services/notification_service.dart) pour
retrouver l'utilisateur courant depuis un isolate background — n'était écrit
**nulle part** dans le code : toujours `null`, donc la réponse rapide comme
la confirmation de livraison en arrière-plan (`mark_messages_as_delivered`)
étaient court-circuitées avant même de tenter quoi que ce soit. (2) même
quand ce cache aurait été renseigné, `BackgroundReplyService.sendReply`
écrivait dans Firebase Realtime Database (`messages/{conversationId}`), un
backend retiré depuis la migration vers Supabase — la conversation lit
`messages`/`conversations` sur Supabase, jamais RTDB, donc le message
n'apparaissait jamais, ni pour le destinataire ni au retour dans l'app.

Correctifs : `NotificationService.saveTokenForUser` (appelée à chaque login
et par `authStateChanges` au démarrage) alimente maintenant le cache
`currentUserId`/`currentUserDisplayName`/`currentUserPhotoUrl`, et le vide à
la déconnexion. `BackgroundReplyService` initialise un client Supabase propre
à l'isolate (même piège que `BackgroundLocationService` : singleton par
isolate) avec `SupabaseAuthBridge.ensureAuthenticated()`, écrit dans
`messages`/`conversations` avec le même schéma que
`MessageSupabaseDataSource` (chiffrement AES de repli — Signal Protocol est
hors de portée d'un isolate éphémère, pas de Hive), et la file d'attente
hors-ligne (`processPendingMessages`, jusqu'ici jamais appelée) se vide
maintenant à chaque connexion connue. `flutter analyze` propre, mais rien de
tout ça n'exerce le vrai réveil d'isolate Android ni Supabase.

- [x] Recevoir une notification de message avec l'app en arrière-plan (ou
  fermée) → la notification s'affiche avec les deux boutons d'action
  (Répondre, Marquer comme lu). **Vérifié le 2026-08-14 sur SM A515F**, à
  trois reprises (build debug, build debug après redémarrage complet, build
  profile) : le correctif serveur data-only fonctionne, `actions=2` confirmé
  dans `dumpsys notification`.
- [ ] Taper « Répondre », taper du texte, envoyer → la confirmation
  « Message envoyé » s'affiche, ET le message apparaît réellement dans la
  conversation. **Reste bloqué — voir « Quatrième bug » ci-dessous, action
  masquée en attendant.**
- [ ] Même test avec le téléphone en mode avion au moment de la réponse →
  le message part en file d'attente, puis rouvrir l'app une fois reconnecté
  doit l'envoyer automatiquement (pas besoin de le retaper). Bloqué par le
  même « Quatrième bug ».
- [ ] Action « Marquer comme lu » depuis une notification → le compteur non
  lu de la conversation redescend à 0 dans la liste des conversations.
  Bloqué par le même « Quatrième bug » (même mécanisme de dispatch).

**Troisième bug, trouvé en vérifiant celui-ci sur appareil (2026-08-13) :**
même les deux correctifs ci-dessus posés, la notification reçue app en
arrière-plan n'affichait **aucun bouton d'action**. Cause : `send-push`
([supabase/functions/send-push/index.ts:324-338](supabase/functions/send-push/index.ts))
envoie un message FCM avec un bloc `notification` **et** un bloc `data`. Sur
Android, quand l'app est en arrière-plan, un bloc `notification` présent fait
que le système affiche lui-même la bannière **nativement**, sans jamais
invoquer `onBackgroundMessage`/`firebaseMessagingBackgroundHandler` côté
Dart — confirmé par `adb logcat` : la notification est postée par
`NotificationService` système (PID système) à l'horodatage du push, aucune
ligne Flutter ne s'exécute. `_showFallbackMessageNotification` (le repli qui
construit les actions Répondre/Marquer comme lu) ne sert donc que pour les
OEM qui suppriment activement le bloc `notification` — pas le cas ici, donc
jamais atteint. Corrigé côté client
([notification_service.dart](lib/core/services/notification_service.dart)) :
`_showFallbackMessageNotification` porte maintenant les mêmes actions que
`_showLocalNotification`, et son payload est du JSON valide (l'ancien
`'message:$conversationId'` aurait fait échouer même un simple tap). Mais
tant que `send-push` envoie encore le bloc `notification`, ce correctif
client ne s'exécute jamais dans le cas courant. **Correctif serveur fait et
déployé le 2026-08-13** (confirmation de Salim avant déploiement) :
[supabase/functions/send-push/index.ts](supabase/functions/send-push/index.ts)
envoie désormais les messages `type === 'message'` en pur `data`-only (pas
de bloc `notification` ni `android.notification`), avec `aps.alert`
reconstruit explicitement côté APNs pour ne pas perdre l'alerte iOS. Les
autres types de notification (amis, groupes, événements...) gardent le bloc
`notification` classique — comportement inchangé, aucune action requise pour
eux. **Confirmé en pratique le 2026-08-14** : `dumpsys notification` montre
`actions=2` sur la notification reçue app en arrière-plan.

**Quatrième bug, trouvé en testant le tap réel sur « Répondre » (2026-08-14),
bloquant :** les trois bugs ci-dessus posés et vérifiés (currentUserId,
écriture Supabase, boutons visibles), taper « Répondre » ouvre bien le champ
de saisie inline par-dessus la notification (comportement Android correct,
confirmé par capture), taper du texte et valider ferme bien ce champ — mais
**aucun message n'atteint jamais la base**, et strictement aucun code Dart ne
s'exécute ensuite. Isolé précisément par `adb logcat` :
- Android délivre bien le broadcast à notre récepteur (confirmé à chaque
  tentative) :
  `ActivityManager: Received BROADCAST intent … act=com.dexterous.
  flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED
  cmp=com.diasponiger.diasponiger/com.dexterous.flutterlocalnotifications.
  ActionBroadcastReceiver … sent=0` ;
- `RemoteInputQuickSettingsDisabler: setRemoteInputActive : false` juste
  après le tap confirme que le texte a bien été capturé côté système ;
- mais après ce broadcast, **zéro ligne de log Flutter**, y compris une
  ligne ajoutée spécifiquement comme diagnostic dans
  `notificationActionBackgroundHandler` pour le cas où l'input serait
  vide/null (elle ne s'est jamais déclenchée non plus — le handler Dart ne
  s'exécute donc pas du tout, ce n'est pas juste une branche de code
  manquante).

Reproduit à l'identique sur **trois builds différents**, avec redémarrage
complet de l'app (`am force-stop` + relance) avant chacun : `flutter build
apk --debug`, le même après un redémarrage complet, puis `flutter build apk
--profile` — élimine à la fois « process resté sale » et « artefact du mode
JIT/debug » comme explications. Recherche dans les issues GitHub de
`flutter_local_notifications` (MaikuB/flutter_local_notifications#2011,
#2148) : catégorie de bug connue et non résolue côté mainteneurs, sans cause
racine publiée — `onDidReceiveBackgroundNotificationResponse` qui ne
s'exécute jamais malgré `@pragma('vm:entry-point')` correctement posé.

**Décision avec Salim (2026-08-14) :** masquer les deux boutons (Répondre
**et** Marquer comme lu — même mécanisme de dispatch, donc même panne, même
si seul Répondre a été testé bouton par bouton) plutôt que de laisser une
action qui échoue en silence. Un seul commutateur,
`kNotificationQuickActionsEnabled` dans
[notification_service.dart](lib/core/services/notification_service.dart),
contrôle les deux emplacements où les actions Android sont construites
(`_showLocalNotification` et `_showFallbackMessageNotification`). iOS non
touché — mécanisme de dispatch différent (délégué `UNUserNotificationCenter`,
pas de `ActionBroadcastReceiver`), jamais mis en cause par ce diagnostic.

- [ ] Avant de remettre `kNotificationQuickActionsEnabled` à `true` : relancer
  ce test bout-en-bout sur appareil réel, pas seulement `flutter analyze`.
- [ ] Vérifier que la notification s'affiche toujours normalement (tap sur le
  corps → ouvre la conversation) avec les actions masquées — pas testé
  explicitement, seule l'absence des boutons a été vérifiée par `dumpsys`.

## Message d'appel : aperçu et badge non-lu ne se mettaient jamais à jour (2026-08-13)

Même famille de bug que la réponse rapide depuis une notification
ci-dessus. [call_message_service.dart](lib/core/services/call_message_service.dart)
écrivait l'aperçu de dernier message dans `conversations.data` avec des clés
snake_case (`last_message`, `last_message_sender_id`, `last_message_type`,
`unread_counts` à la création d'une conversation 1:1) alors que
`ConversationModel.fromJson`/`_convFromRow`
([message_supabase_datasource.dart](lib/features/messages/data/datasources/message_supabase_datasource.dart))
et tout le reste du pipeline d'envoi lisent des clés camelCase
(`lastMessage`, `lastMessageSenderId`, `lastMessageType`, `unreadCount`).
En plus de la casse, la colonne top-level `last_message_at` (celle qui
pilote le tri `.order('last_message_at', ...)` de la liste des
conversations) n'était jamais mise à jour — seule une copie morte dans
`data` l'était — et **aucun** compteur non lu n'était incrémenté après un
appel sur une conversation déjà existante (seule la création en écrivait
un, et en snake_case). Concrètement : après un appel, la conversation ne
remontait pas en tête de liste, l'aperçu affichait l'ancien dernier
message texte au lieu de « 📞 Appel manqué », et le badge non-lu du
destinataire ne s'incrémentait jamais.

Correctif : nouvelle méthode privée `_updateConversationLastMessage`
dans `call_message_service.dart`, calquée sur celle de
`MessageSupabaseDataSource`/`BackgroundReplyService` (mêmes clés
camelCase, même colonne top-level `last_message_at`, incrément
`unreadCount` pour tous les participants sauf l'auteur de l'appel). La
création de conversation 1:1 (`_getOrCreateConversation`) écrit
maintenant `unreadCount`/`requestStatus` comme
`createIndividualConversation`, sans plus dupliquer `created_by`/
`last_message_at` (colonnes top-level) dans `data`. `flutter analyze`
propre, mais rien de tout ça n'exerce un vrai appel WebRTC/coturn ni
Supabase.

- [x] Passer ou recevoir un appel (audio ou vidéo), le laisser sonner sans
  décrocher puis raccrocher → dans la liste des conversations, la
  conversation remonte en tête et l'aperçu affiche « 📞 Appel {audio/vidéo}
  manqué/refusé/sortant » (pas l'ancien dernier message texte). **Vérifié le
  2026-08-14 sur SM A515F (compte Sim) ↔ Pixel 10 Pro XL (compte Salim L.),
  vrai appel audio 1:1 non décroché** : côté Sim, « Salim L. / Vous : Appel
  audio manqué » remonte en tête de liste ; seul le variant manqué/pas de
  réponse a été exercé, pas refusé/occupé/sortant annulé.
- [x] Depuis le téléphone qui n'a **pas** initié l'appel, vérifier que le
  badge non-lu de cette conversation s'incrémente après l'appel (et
  redescend à 0 en rouvrant la conversation). **Vérifié le 2026-08-14** :
  côté Salim L. (non-initiateur), badge rouge « 1 » sur la conversation
  « Sim A » après l'appel manqué. Redescente à 0 à la réouverture non
  contrôlée séparément (la conversation a été ouverte dans la foulée).
- [ ] Passer un premier appel vers un contact sans conversation 1:1
  existante → une nouvelle conversation est créée et apparaît normalement
  dans la liste (aperçu + badge), pas seulement après l'envoi d'un
  message texte ultérieur.

## La bulle d'appel elle-même n'apparaissait jamais dans la conversation (2026-08-14)

Signalé par l'utilisateur : « les bulles des appels ne s'affiche jamais ».
Le correctif du 2026-08-13 ci-dessus a réparé l'aperçu de conversation et le
badge non-lu, mais pas le symptôme racine — même famille de bug que
« Réponse rapide depuis la notification » plus haut sur cette page.
`createCallMessage` dans
[call_message_service.dart](lib/core/services/call_message_service.dart)
écrivait le message d'appel (`type: 'call'`) dans Firebase Realtime Database
(`messages/{conversationId}` via `_database.ref()...push().set(...)`), un
backend que plus rien ne lit : `MessageSupabaseDataSource.getMessages`
([message_supabase_datasource.dart:445-453](lib/features/messages/data/datasources/message_supabase_datasource.dart))
— le seul datasource câblé dans `messageRemoteDataSourceProvider` — stream
uniquement la table Supabase `messages`. Le message était donc bien créé (les
logs `debugPrint('appel: ...')` le confirmaient), mais dans un endroit que
l'écran de conversation ne consulte jamais : aucune bulle, aucune erreur.

Correctif : `createCallMessage` insère maintenant dans la table Supabase
`messages` avec le même schéma `data` JSONB (camelCase) que
`sendTextMessage`, précédé d'un `SupabaseAuthBridge.ensureAuthenticated()`
comme partout ailleurs où l'app écrit dans Supabase. `_ensureParticipantsInRTDB`
(RTDB) est conservée telle quelle — sert aux règles de permission des appels,
sans rapport avec l'affichage du message. `flutter analyze` propre, mais rien
de tout ça n'exerce un vrai appel WebRTC/coturn ni Supabase.

- [x] Passer ou recevoir un appel (audio ou vidéo), raccrocher → une bulle
  d'appel apparaît dans la conversation (pas seulement l'aperçu en liste),
  avec la bonne icône/couleur selon le statut (terminé, manqué, refusé,
  occupé, sortant annulé) et la durée si décroché. **Vérifié le 2026-08-14
  sur SM A515F (Sim) ↔ Pixel 10 Pro XL (Salim L.), vrai appel audio 1:1** :
  bulle rouge « Appel manqué / Pas de réponse - HH:MM » visible des deux
  côtés (alignée à droite chez l'appelant Sim, à gauche chez Salim L.),
  icône téléphone barré rouge, callback icon présent. Seul le statut
  manqué/pas de réponse a été exercé (deux tentatives, l'app de Salim L.
  n'étant pas au premier plan) ; terminé/refusé/occupé/sortant annulé
  restent à vérifier.
- [ ] Taper sur la bulle → rappelle le contact. Appui long → menu contextuel
  (rappeler / infos / supprimer si auteur ou admin).

## Messages de groupe qui redeviennent indéchiffrables après réouverture (2026-08-13)

Signal (1:1) et Sender Key (groupes) avancent un ratchet à sens unique à
chaque déchiffrement réussi, sans conserver les clés de message déjà
consommées. `getMessagesPaginated` re-fetch pourtant le même ciphertext
depuis Supabase et retente `_crypto.decrypt` à chaque appel (réouverture
de conversation, pull-to-refresh, pagination) —
`SenderKeyService.decryptWithSenderKey` refuse alors tout `chainIndex`
déjà dépassé et renvoie le placeholder « session requise », qui écrasait
le texte clair déjà mis en cache. Correctif dans
[message_repository_impl.dart](lib/features/messages/data/repositories/message_repository_impl.dart)
(`_healUndecryptableMessages`) : on restaure depuis le cache local le
texte des messages qu'un rechargement réseau vient de rendre
indéchiffrables, avant d'écraser le cache — même principe que
`_reconcileEcho` (message_provider.dart) pour l'écho temps réel, mais
côté rechargement paginé. `flutter analyze` propre, mais rien de tout ça
n'exerce le vrai ratchet Signal ni Supabase.

- [ ] Ouvrir une conversation de groupe avec un historique de messages
  texte de plusieurs membres, vérifier qu'ils se déchiffrent tous, puis
  **quitter et rouvrir la conversation** (ou tirer pour rafraîchir) → les
  mêmes messages doivent rester lisibles, pas basculer sur
  « 🔐 Message chiffré » / « session requise ».
- [ ] Faire défiler vers le haut pour charger une page plus ancienne
  (pagination `loadMore`) dans un groupe déjà ouvert → les messages
  récents déjà affichés restent lisibles pendant le chargement de la
  page suivante.
- [ ] Même scénario sur une conversation **1:1** (pas seulement groupe) —
  la cause racine (ratchet Signal à sens unique) s'applique aussi aux
  messages reçus en 1:1, pas seulement à l'écho de ses propres messages
  déjà couvert par `_reconcileEcho`.
- [ ] Redémarrer l'app à froid sur une conversation de groupe déjà lue →
  le cache local (Hive) doit resservir le texte déchiffré, pas une
  nouvelle tentative de déchiffrement en échec.

---

## Réactions emoji : une par personne et par message (2026-08-13)

`MessageEntity.reactions` était une simple `List<String>` sans auteur : le
compteur affiché était juste le nombre d'emojis posés, mais rien ne
distinguait « la mienne » des autres, et retirer sa réaction pouvait retirer
celle de quelqu'un d'autre (premier élément de la liste égal à cet emoji).
Passé à `Map<String, String>` (userId -> emoji, une seule par personne) dans
[message_entity.dart](lib/features/messages/domain/entities/message_entity.dart),
[message_model.dart](lib/features/messages/data/models/message_model.dart),
les deux datasources (`message_supabase_datasource.dart`,
`message_remote_datasource.dart`) et
[message_provider.dart:601](lib/features/messages/presentation/providers/message_provider.dart:601)
(`toggleReaction` se basait sur *n'importe quel* utilisateur ayant déjà posé
cet emoji, pas sur l'utilisateur courant). L'onglet « Réactions » de la fiche
message ([message_info_sheet.dart](lib/features/messages/presentation/widgets/message_info_sheet.dart))
chargeait en plus depuis un service RTDB Firebase mort (`MessageActionService`)
que les vraies réactions Supabase n'ont jamais alimenté — toujours vide en
pratique ; il lit maintenant `message.reactions` directement.

- [x] **Poser une réaction (appui long → sélecteur rapide), la voir
  apparaître avec la bonne surbrillance — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  compte « Sim A », groupe « Groupe de test privé ». Le chip ❤️ apparaît avec
  bordure/fond teintés (couleur d'accent), et un appui long ultérieur montre
  bien l'émoji comme sélectionné dans la rangée rapide.
- [x] **Reposer la même réaction → elle disparaît (toggle off) — VÉRIFIÉ SUR
  SM A515F (2026-08-13)** : re-sélectionner 😂 depuis la rangée rapide retire
  le chip.
- [x] **Poser un emoji différent sur un message déjà réagi par soi →
  remplace l'ancien, ne l'additionne pas — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  ❤️ posé, puis 😂 sélectionné → un seul chip (😂) reste affiché, pas deux.
- [x] **Fiche message (appui sur l'accusé « Envoyé ») → onglet Réactions liste
  qui a réagi et avec quel emoji — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  « Réactions · 1 » dans les onglets, détail « Sim A — ❤️ » correct. Avant le
  correctif cet onglet était toujours vide (service RTDB mort) ; confirmé
  qu'il lit maintenant la vraie donnée.
- [ ] Deux comptes différents réagissant au même message avec le même emoji
  → le chip affiche bien un compteur à 2, et chacun ne peut retirer que sa
  propre réaction. **Pas vérifiable avec un seul appareil/compte** — nécessite
  un deuxième testeur ou compte connecté ailleurs.

---

## Retour à la ligne des bulles de discussion après l'agrandissement du texte (2026-08-13)

`fontSize` du texte des bulles porté à 17 (texte, liens, mentions) et padding
interne desserré (14/10/8) dans
[message_bubble.dart:2156](lib/features/messages/presentation/widgets/message_bubble.dart:2156)
— la taille précédente (15, puis 16) était jugée trop petite. Vérifié sur
SM A515F : les bulles existantes (messages courts « Salut », « Yo », « Hi »)
s'affichent sans overflow, mais un essai d'envoi d'un message long depuis
l'appareil (`adb shell input text`) n'a pas abouti — le champ ne recevait pas
le texte tapé — donc le retour à la ligne sur un message qui remplit toute la
largeur de la bulle n'a jamais été vu en vrai à cette taille de police.

- [x] **Envoyer un vrai message long, `font_scale` par défaut — VÉRIFIÉ SUR SM A515F (2026-08-13)** :
  - **1:1** (conversation « Salim L. ») : message réel envoyé par Salim
    (« Ceci est un message test assez long pour verifier que le texte se
    replie bien dans la bulle sans depasser ni tronquer quoi qui arrive. »)
    — se replie proprement sur 5 lignes, aucun débordement.
  - **Groupe** (« Diaspora Niger — Canada ») : le message de stress-test
    existant (~2000 caractères, alternant texte et segments de type
    téléphone auto-liés) se replie entièrement dans la largeur de la bulle,
    y compris aux frontières des segments liés, sans dépassement horizontal.
  - Tentative d'envoi d'un nouveau message dans un troisième groupe
    (« Groupe de test privé ») interrompue par des redémarrages concurrents
    de l'app (rebuilds/réinstalls de Salim en parallèle sur le même
    appareil) puis un état « Connexion en cours... » resté bloqué >40s —
    observation isolée, pas reproduite volontairement, probablement liée au
    nombre de kill/reinstall consécutifs plutôt qu'au correctif de police.
- [x] **`font_scale` à 1.1 — VÉRIFIÉ SUR SM A515F (2026-08-13)** : réglé via
      `adb shell settings put system font_scale 1.1` (déjà actif au moment du
      test, probablement réglé par Salim). Vérifié en paysage (l'appareil a
      basculé d'orientation plusieurs fois pendant le test, hors de mon
      contrôle) :
  - **1:1** (« Salim L. ») : le même message test se replie proprement sur
    2 lignes (largeur plus grande en paysage), toujours aucun débordement.
  - **Groupe** (« Diaspora Niger — Canada ») : la fin du message de
    stress-test s'affiche sur 2 lignes, entièrement contenue dans la bulle
    envoyée, aucun débordement.
  - ⚠ **Débordement réel observé, mais ailleurs** : `BOTTOM OVERFLOWED BY
    43 PIXELS` sur l'**aperçu du brouillon du composer** (pas une bulle
    envoyée) quand un brouillon très long (le brouillon de stress-test
    existant, 224/2000 caractères) est combiné au clavier ouvert en
    paysage. Correspond au défaut déjà loggé par Salim (commit
    `a9b1fa5`/`6d86b58`, « reconfirme overflow paysage 47px avec brouillon
    de 2 lignes ») — reproduit indépendamment ici à 43px, même famille de
    bug, pas un nouveau défaut de ce correctif-ci.

---

## Cartographie des accès `anon` réellement nécessaires (2026-08-13)

Suite à l'audit des RPC (section suivante) : `anon` a INSERT/UPDATE/DELETE/SELECT
au niveau table sur quasiment tout le schéma public par accident
(`ALTER DEFAULT PRIVILEGES`), et RLS (activée sur 100% des tables, vérifié)
est la seule barrière. Avant d'envisager un `REVOKE` généralisé, cartographie
de ce que l'app a réellement besoin en `anon` — c'est-à-dire avant qu'une
session Supabase authentifiée existe.

**L'app n'a aucun mode invité.** Le routeur ([app_router.dart:246-247](lib/core/router/app_router.dart:246))
redirige tout écran non technique vers `/auth/login` tant que Firebase n'est
pas authentifié — aucun aperçu public (profil, post, événement, groupe via
lien de partage) ne se construit avant connexion. Les pages légales (CGU,
confidentialité) sont servies depuis **Firestore**, pas Supabase.

**Besoins réels identifiés** (tous liés à la même fenêtre : `auth_provider.dart`
`_startFromLocalSession` (lignes 152-185) bascule l'utilisateur en
« authentifié » depuis la session Firebase locale **sans confirmer** que le
pont Supabase a abouti — le vrai bug de fond) :
- `users` SELECT — `profileNotifierProvider`/`nearbyProfilesNotifierProvider`
  au montage de `HomeScreen`, et `isHandleAvailable` pendant l'inscription
  ([handle_field.dart:81-91](lib/features/profile/presentation/widgets/handle_field.dart:81))
- `blocked_users` SELECT — `usersWhoBlockedMeProvider`
- `conversations` SELECT — `totalUnreadCountProvider`

~~`events` SELECT — `eventsNotifierProvider`~~ — **faux positif, corrigé le
2026-08-13** : `eventsNotifierProvider` lit en réalité **Firestore**
(`EventRemoteDataSourceImpl`, `event_remote_datasource.dart:36-46`), pas
Supabase. L'agent d'exploration précédent avait confondu la fonctionnalité
« événements » avec la table Supabase `events` — celle-ci existe bien et
`anon` y a SELECT/écriture, mais son seul lecteur applicatif est
`admin_provider.dart` (back-office, déjà réservé aux admins authentifiés,
hors de la fenêtre de démarrage). Rien à corriger côté code pour ce point.

**Aucune écriture n'est légitimement nécessaire en `anon`, nulle part** —
chaque écriture inspectée (`profile_supabase_datasource.dart` et consorts)
est déjà gardée par `ensureAuthenticated()`/`_requireAuth()` côté Dart et
échoue proprement sans le grant. Aucune lecture nécessaire sur les ~80
autres tables (`orders`, `payment_accounts`, `escrow_transactions`,
`e2ee_*`, `messages`, `posts`, `groups`, `businesses`, `podcasts`,
`admin_*`...).

**Angle mort** : `audio_rooms`, `businesses`, `calls`, `embassies`, `friends`,
`marketplace`, `payment_accounts`, `podcasts`, `reports`, `search`,
`stickers`, `support`, `transfers` n'ont pas le réflexe `ensureAuthenticated()`
présent dans `auth`/`feed`/`groups`/`messages`/`profile` — protégés
aujourd'hui uniquement par la garde du routeur, pas par le datasource
lui-même. Un `REVOKE` général sur les écritures `anon` serait le filet qui
les couvre si un futur chemin de code (deep link, tâche de fond) contournait
le routeur.

- [x] ~~Décision en attente~~ — Salim a choisi de fermer d'abord la fenêtre
  plutôt que d'ouvrir des SELECT en permanence. Fait le 2026-08-13 pour 3 des
  4 lectures :
  - Nouveau [`SupabaseAuthBridge.ensureReadableSession()`](lib/core/services/supabase_auth_bridge.dart)
    — variante **bornée** (3 s) d'`ensureAuthenticated()`. Contrairement à
    celle-ci, un timeout ne fait PAS échouer : la synchro continue en tâche
    de fond (dédupliquée) et profite au prochain appelant. Choix délibéré
    pour ne pas régresser le correctif du 2026-08-04 (splash bloqué 2 min) —
    `_startFromLocalSession` (auth_provider.dart) n'est PAS touchée, elle
    continue de débloquer `/home` sans réseau.
  - Câblé dans `profile_supabase_datasource.dart` : `getProfile`,
    `getNearbyProfiles` (lèvent désormais une `ServerException` déjà gérée
    par les écrans appelants au lieu d'interroger en anon), `isHandleAvailable`
    (se replie sur « disponible », comme pour une erreur réseau).
  - Callback injectable `_ensureReadableAuth`, même motif que `_ensureAuth`
    pour les écritures — 4 tests ajoutés dans
    `profile_supabase_datasource_test.dart` (13/13 passent).
  - `flutter analyze` propre sur `lib/features/profile`, `lib/features/auth`,
    `lib/core/services/supabase_auth_bridge.dart`.
  - **`conversations` fait le 2026-08-13, suite** — même mécanisme, câblé
    dans `getConversations` ([message_supabase_datasource.dart:339](lib/features/messages/data/datasources/message_supabase_datasource.dart:339)) :
    la fonction interne `fetch()` (appelée à l'abonnement initial ET à chaque
    événement realtime) vérifie désormais `_ensureReadableAuth()` avant
    d'interroger. Différence avec les lectures profil : c'est un
    `StreamController` de longue durée, pas un Future ponctuel — sans filet,
    un échec silencieux laisserait le flux bloqué sur son dernier état
    jusqu'au prochain événement realtime (potentiellement jamais). Un seul
    nouvel essai programmé 5 s plus tard comble ce trou, sans machinerie de
    retry plus lourde. Callback injectable `_ensureReadableAuth` ajouté à
    `MessageSupabaseDataSource`, même motif que `profile_supabase_datasource.dart`.
    `flutter analyze` propre. **Pas de test automatisé** : ce datasource n'a
    aucun harnais de test existant (contrairement à `profile`), et tester un
    `StreamController` + un `Timer` de 5 s proprement demanderait
    `fake_async` — pas fait, hors périmètre de cette session.
  - **`blocked_users` fait le 2026-08-13, suite** —
    [`watchBlockedBy`](lib/features/settings/data/datasources/blocked_by_supabase_datasource.dart:31)
    (`usersWhoBlockedMeProvider`, sens « qui m'a bloqué »). Plus simple que
    `conversations` : `.stream()` (le helper Supabase Flutter) gère déjà sa
    propre reconnexion, donc pas besoin d'un `Timer` de nouvel essai — la
    méthode devient un générateur `async*` qui attend la garde puis
    `yield*` le flux réel. Au-delà du délai borné (3 s), l'abonnement part
    quand même (comme avant), le repli `.handleError` du provider couvre le
    reste. Callback injectable, 2 tests ajoutés
    (`test/features/settings/blocked_by_supabase_datasource_test.dart`,
    pas de `fake_async` nécessaire ici). `flutter analyze` propre sur
    `lib/features/settings`.
    Au passage : `blockedUsersProvider` (sens direct, « qui j'ai bloqué »)
    est lui aussi un faux positif comme `events` — il lit **Firestore**
    (`BlockedUsersDataSourceImpl`), pas Supabase ; seule l'écriture miroir
    vers Supabase existe et est déjà gardée (`_refleterDansSupabase`,
    `ensureAuthenticated()`).
  - **Cartographie soldée** : les 4 lectures identifiées sont maintenant
    soit fermées côté code (`users`, `conversations`, `blocked_users`), soit
    de faux positifs (`events`, et la moitié de `blocked_users`). Plus rien
    en attente avant d'envisager le `REVOKE` général des droits table
    `anon`.
  - [x] **Vérifié sur appareil le 2026-08-13** (SM A515F, APK debug rebuild
    depuis ce worktree, `lastUpdateTime` confirmé postérieur aux 4 commits de
    correctif). Mode avion + Wi-Fi coupé par Salim, confirmé par
    `dumpsys connectivity` (`Active default network: none`, pas seulement
    `airplane_mode_on`, cf. le piège VPN déjà documenté) — puis app arrêtée
    (`am force-stop`) et relancée à froid.
    - Aucun crash (`E/flutter`, `FATAL EXCEPTION` : zéro occurrence sur toute
      la capture logcat). `/home`, Messages et Groupes s'affichent tous
      normalement, aucun écran bloqué sur `/splash`.
    - Le badge « 1 non lu » s'affiche correctement dès le démarrage à froid
      hors ligne (données en cache, cohérent avec le cache-first existant).
    - `markAsDelivered`/`mark_messages_as_read` échouent proprement
      (`AuthRetryableFetchException` catché et loggé, pas de crash) —
      confirme le comportement best-effort du correctif accusés livré/lu.
    - Reprise réseau confirmée propre : `SupabaseAuthBridge: session sync OK`
      dans les 2 s suivant le rétablissement, puis opérations Supabase
      réelles qui réussissent de nouveau (`MarkAsRead: Synced dismiss to
      other devices`).
    - **Nuance découverte** : `_startFromLocalSession` (le chemin de repli à
      8 s dans `auth_provider.dart`) ne s'est en fait jamais déclenché
      pendant ce test — son log dédié (« profil serveur injoignable ») est
      absent de toute la capture. `getCurrentUser()` a résolu plus vite que
      le timeout, via sa propre résilience interne, sans jamais passer par
      ce chemin précis. Les gardes `ensureReadableSession()` restent
      correctes indépendamment de ce détail (elles ne testent que
      `hasValidSession`, pas la raison de l'état d'authentification), mais
      ce test précis n'isole pas la fenêtre étroite (réseau bon mais pont pas
      encore confirmé) que ces gardes visent spécifiquement — seulement le
      cas plus large « pas de réseau du tout ».
    - **Trouvaille incidente, hors périmètre** : `setState() called after
      dispose()` dans `_startGroupConversation`
      (`group_detail_screen.dart:632`), capturé par Crashlytics. Pas un
      crash, mais une fuite mémoire potentielle. Tâche séparée créée.

---

## Accusés livré/lu séparés — sheet infos du message (2026-08-13)

`mark_messages_as_delivered` marquait `readBy`/`readAt` en même temps que
`deliveredTo`/`deliveredAt`, y compris depuis les handlers de notification
push (app en arrière-plan ou fermée) : un message passait à « lu » avant même
que le destinataire ouvre la conversation. Séparé en deux RPC —
`mark_messages_as_delivered` (livré seul) et `mark_messages_as_read` (lu,
appelée uniquement à l'ouverture réelle de la conversation) — voir
[20260813120000_split_delivered_from_read.sql](supabase/migrations/20260813120000_split_delivered_from_read.sql)
et [message_supabase_datasource.dart:1548](lib/features/messages/data/datasources/message_supabase_datasource.dart:1548).

`flutter analyze` propre. Les deux migrations sont **déployées** sur le
distant (Diapo Niger, `zyrfkcjjrhddpfxcgezo`) et vérifiées par requête directe
(`supabase db query --linked`, transaction annulée pour ne rien persister) :
`mark_messages_as_delivered` tourne sans erreur et ne touche plus `readBy`.
Mais rien de tout ça n'est vérifiable **dans l'app** sans deux comptes réels
échangeant un message :

- [x] ~~Migration à déployer~~ — fait le 2026-08-13, en deux temps :
  [20260813120000_split_delivered_from_read.sql](supabase/migrations/20260813120000_split_delivered_from_read.sql)
  puis [20260813130000_fix_receipts_uuid_type_and_anon_grant.sql](supabase/migrations/20260813130000_fix_receipts_uuid_type_and_anon_grant.sql)
  — la première utilisait un paramètre `UUID` copié de l'ancienne RPC alors que
  `messages.conversation_id` est en réalité `TEXT` sur le distant (jamais
  `UUID`, malgré ce qu'affirmait `20260727180000`) : la RPC livrée existait
  mais plantait à chaque appel (`operator does not exist: text = uuid`),
  avalé en silence par le `catch` Dart. Bonus découvert au passage : une
  `mark_messages_as_read(TEXT, TEXT)` orpheline traînait déjà côté distant,
  sans vérification de participant et **accessible à `anon`** — remplacée par
  la version correcte. Cause structurelle notée dans la migration : le
  `REVOKE ALL ... FROM PUBLIC` classique ne retire pas l'accès `anon`, accordé
  directement par `ALTER DEFAULT PRIVILEGES` sur ce projet — probablement vrai
  pour d'autres RPC du projet, **non auditées ici**.
- [ ] Envoyer un message depuis le compte A à un compte B **avec le compte B
  hors ligne** (notification push reçue, app fermée) : vérifier dans le sheet
  infos du message (appui long → Infos) que l'onglet « Livré à » liste B mais
  que « Lu par » reste vide tant que B n'a pas ouvert la conversation.
- [ ] Ouvrir la conversation côté B : vérifier que B apparaît alors dans « Lu
  par », et que le coche du message (côté A) passe au double-coche bleu à ce
  moment-là, pas avant.
- [x] ~~Auditer les autres RPC `SECURITY DEFINER` du projet pour le même trou
  `anon`~~ — fait le 2026-08-13. ~45 fonctions `SECURITY DEFINER` accessibles
  à `anon` passées en revue (corps + appelants Dart). Sept avaient un vrai
  trou (aucune vérification d'appelant, pas seulement le grant par défaut) :
  - 🔴 **`lock_escrow_for_release(uuid, text)`** — libère l'escrow d'une
    commande marketplace (déclenche le virement Stripe). `p_caller_id = NULL`
    contournait entièrement le contrôle d'appartenance ; même renseigné,
    c'était une valeur fournie par l'appelant, jamais vérifiée contre une
    session. Seul appelant légitime : l'Edge Function
    `process-escrow-release`, qui valide déjà le JWT et appelle en
    `service_role`. Corrigé en fermant l'accès direct anon/authenticated
    (`service_role` uniquement) et en rendant le contrôle NULL strict.
  - 🟠 **`e2ee_add_active_device`/`e2ee_remove_active_device(text, text)`** —
    zéro vérification : n'importe qui pouvait ajouter/retirer un appareil de
    la liste des appareils actifs E2EE **de n'importe quel utilisateur**
    (risque d'écoute via un appareil injecté, ou déni de service en retirant
    les appareils d'une victime). Corrigé : `p_user_id` doit désormais
    matcher `firebase_uid()`.
  - 🟠 **`consume_one_time_prekey(text, text)`** — cross-utilisateur par
    conception (Alice consomme une clé de Bob), mais accessible sans compte
    du tout, ce qui rend l'épuisement du stock de clés gratuit et anonyme.
    Relevé à « authentifié » minimum.
  - 🟡 **`increment_column`** — allowlist déjà en place (compteurs Heritage),
    mais aucune vérification d'appelant. Relevé à « authentifié ».
  - Voir [20260813150000_close_anon_rpc_holes.sql](supabase/migrations/20260813150000_close_anon_rpc_holes.sql).
    Testé sur le distant en transaction annulée (rien persisté) : le bug
    NULL de l'escrow est bien fermé (preuve indirecte — l'appel avec le bon
    buyer_id n'aurait pas pu réussir si un appel précédent avait déjà fait
    passer `escrow_status` à `releasing`).
  - ~15 RPC de compteurs vanité (likes/vues/partages posts, podcasts,
    produits) : anon peut gonfler des métriques, aucun impact
    données/argent — **non corrigées**, laissées telles quelles.
  - `delete_group`, `accept_friend_request`, `insert_group`,
    `join_group_conversation`, `create_user_notification`,
    `get_or_create_official_group`, `get_feed_reposts` : déjà correctement
    gardées en interne (ou lecture de contenu déjà public) malgré le grant
    `anon` inutile — pas des trous réels.
  - 🔴 **Découverte plus large, non corrigée** : `anon` a en fait
    INSERT/UPDATE/DELETE au niveau **table** sur quasiment tout le schéma
    public (`users`, `messages`, `orders`, `payment_accounts`,
    `transactions`, `escrow_transactions`, `e2ee_user_keys`,
    `admin_audit_logs`...) — même `ALTER DEFAULT PRIVILEGES` que pour les
    fonctions, mais sur les tables. RLS est donc la **seule** barrière,
    projet entier, sans aucun filet au niveau des droits. Conséquence
    directe : `array_append_unique`/`array_remove_element` (mutateurs
    génériques sans allowlist, appelés aujourd'hui seulement sur
    `audio_rooms`) restent exploitables sur n'importe quelle table si sa RLS
    a un trou — non auditée table par table, périmètre bien plus large
    qu'une session. **Prochain audit à faire : lister les accès anon
    réellement nécessaires (signup, vérif téléphone, lecture profils
    publics...) avant d'envisager un `REVOKE` généralisé — risque réel de
    casser des parcours anonymes légitimes si fait à l'aveugle.**

---

## Bascule en anglais — ~1 600 chaînes branchées, rien vu à l'écran (2026-08-06)

Toute l'application vient d'être branchée sur `l10n` : l'admin (0 fichier sur
34 utilisait `l10n`), `businesses` (0/40), `embassies`, `transfers`,
`marketplace`, puis les 19 modules restants, `lib/shared/` et `lib/core/`.
`dart analyze` est propre et les **207 tests passent**, mais aucun de ces
contrôles ne regarde un écran.

**Comment basculer** : Réglages → choix de la langue
([settings_screen.dart:721](lib/features/settings/presentation/screens/settings_screen.dart:721),
`localeNotifierProvider.setLocale`). Les deux locales sont `fr` et `en`.

### Ce qui n'a jamais été vu en anglais

- [ ] **Le back-office en entier.** C'est le plus gros risque : 432 chaînes
  d'un coup, et il affichait du français en dur à un anglophone jusqu'ici.
  Parcourir les 18 écrans, en cherchant les libellés restés français.
- [ ] **Les écrans de profil**, notamment `edit_profile_screen` et
  `profile_config_screen` : les listes profession / région / ville viennent de
  `lib/core/constants/profile_options.dart` et restent **en français dans les
  deux langues** (ce sont des valeurs persistées, pas des libellés). Vérifier
  surtout que choisir « Autre » ouvre bien le champ libre — c'est exactement ce
  que ma régression `l10n.other` cassait, corrigée en `66248d2`.
- [ ] **Les 5 écrans qui utilisent `ErrorView`** : son « Réessayer » était en
  dur jusqu'à `4d6bc1b`.
- [ ] **La barre de navigation et le rail paysage** : leurs libellés sont
  passés sur `l10n` et c'est ce qui a cassé les tests du rail.

### Ce qui change aussi en français

- [ ] **141 accents restaurés** : « Reessayer » → « Réessayer », « Systeme » →
  « Système », « Echoue » → « Échoué », « Evenements par Categorie »… Séquelles
  de la réparation d'encodage CP850, invisibles jusqu'ici parce que ces chaînes
  n'étaient pas branchées. Un coup d'œil sur l'admin et les transferts suffit.

### Deux corrections de comportement, invisibles à l'analyse

- [ ] **Suppression de compte** : la demande de ré-authentification était
  détectée en cherchant « mot de passe » dans le message d'erreur — donc jamais
  en anglais, et à tort sur « Email ou mot de passe incorrect ». Elle se fie
  maintenant au code Firebase `requires-recent-login` (`9b7e69d`). Tester le
  parcours complet de suppression, en français **et** en anglais.
- [ ] **Compte supprimé** : `displayName == l10n.deletedUser` ne pouvait être
  vrai qu'en français. Passé sur `DeletedAccount.storedName`, le marqueur que
  le backend écrit réellement (`af44df0`, `4c32c01`). Vérifier qu'une
  conversation avec un compte supprimé affiche bien l'état « compte supprimé »
  et bloque le chat, dans les deux langues.

### Connu, non corrigé

- Les messages d'erreur voyagent comme **texte** dans `Failure(...)` : ils
  resteront en français en anglais. 207 sites de construction, 327 de lecture.
  ⚠ `lib/core/errors/app_error_messages.dart` contient **déjà** des messages
  FR/EN avec un `setLocale` — l'infrastructure existe, elle n'est simplement
  reliée à rien. C'est un raccordement, pas une création.
- Des libellés d'affichage vivent dans les entités (`requestTypeLabel`, statut
  de transaction, moyen de paiement) : pas de `context`, donc pas traduits.
- ~30 chaînes affichées n'ont aucune clé ARB, dont plusieurs ne doivent pas
  être traduites (séparateurs ` · `, gabarit `+227 XX XX XX XX`, badge `ÉCO`).

---

## Scroll des notifications — mesuré, pas un défaut de l'écran (2026-08-06)

Signalé comme « le scroll a un problème ». Mesuré sur SM A515F avec une sonde
(deux builds), capture et mesure prises **dans la même frame** :

```
état non-lu :  liste bas = 866.3 dp   dernière carte bas = 929.5 dp
               maxScrollExtent = 87.2 dp   (63.2 de débordement + 24 de padding)
état lu     :  dernière carte bas = 670.5 dp   maxScrollExtent = 0
```

- [x] **La liste peut défiler** : `maxScrollExtent = 87.2 dp` en état non-lu.
  La carte coupée n'est pas un défaut d'affichage, c'est du contenu qui dépasse.
- [x] **Un correctif posé puis retiré** (`4c19b3d` → `7648c35`) : il ajoutait
  `viewPadding.bottom` au padding bas, or cette valeur vaut **0** sur cet
  appareil — Flutter n'y reçoit aucun inset système. No-op vérifié à l'écran.
- [ ] ⚠ **À refaire au doigt.** Aucun `adb input swipe` n'a fait défiler cette
  liste, et un glissement lent (1500 ms) a été interprété comme un **tap**.
  L'injection n'est pas fiable ici : je ne peux ni confirmer ni infirmer un
  défaut vécu au doigt. Le test : la liste doit remonter de ~87 dp et découvrir
  le bas de la dernière carte.
- **Piège de méthode à retenir** : le premier `maxScrollExtent = 0` venait de
  l'état *lu* (cartes courtes, contenu qui tient) et a été comparé à une capture
  prise en état *non-lu*. Deux écrans différents. Mesurer et capturer dans la
  même frame, sinon on conclut de travers — ça a coûté deux builds.

- [x] **Trouvé au passage — `/settings/notifications` menait à « Page Not
  Found »** (`GoException: no routes for location`). Segments inversés : le
  routeur déclare `/notifications/settings`. Redirection ajoutée (`71035fb`).
- [x] **L'émetteur n'est PAS la chaîne push** — hypothèse vérifiée puis
  écartée. `supabase functions download send-push` : le déployé est
  **identique au fichier versionné** (aucun diff), et il ne construit aucun
  lien profond — seulement `click_action: 'FLUTTER_NOTIFICATION_CLICK'`.
  Écartés aussi : les navigations de l'écran notifications (toutes en
  `/notifications/...`, `/map`, `/groups/...`, etc.) et `functions/index.js`.
  **L'émetteur reste inconnu** ; la redirection le rend inoffensif quel qu'il
  soit. Ne pas rouvrir la piste « dérive du déployé » : elle est fermée.
- [x] **Redirection vérifiée sur appareil (2026-08-06, 01:21).**
  `am start -a VIEW -d "https://diasponiger.web.app/settings/notifications"`
  sur app tuée ouvre bien l'écran de réglages de notifications, et **aucune
  `GoException` dans logcat**. Avant le correctif, le même lien affichait
  « Page Not Found ».

---

## Push FCM des messages — chaîne serveur rétablie (2026-08-05)

Audit de la base distante : **aucun push n'était envoyé pour un message de
chat** depuis le passage des messages à Supabase. Deux trous cumulés :

- `messages` n'avait aucun trigger sur le distant, et les fonctions de
  `20260720120000_notify_recipients_on_message_insert.sql` en étaient absentes
  — alors que la migration est inscrite comme appliquée. Aucune ligne
  `notifications` de type `message` n'a été créée depuis le 12/04/2026.
- La fonction `notify_push_on_notification` déployée court-circuitait
  `type = 'message'` en déléguant à la Cloud Function RTDB `onMessageCreated`
  ([functions/index.js:839](functions/index.js:839)), qui écoute
  `/messages/{conversationId}/{messageId}` — un chemin que l'app n'écrit plus
  (`MessageSupabaseDataSource`).

Correctifs : `20260805230000_fix_message_push_pipeline.sql` puis
`20260806090000_fix_push_trigger_schema.sql`.

**Appliqués et vérifiés côté serveur le 2026-08-06.** Le premier ne suffisait
pas : il faisait `CREATE OR REPLACE FUNCTION public.notify_push_on_notification`
alors que le trigger appelle celle du schéma **`private`**. Il a donc créé une
deuxième fonction homonyme sans toucher la bonne — appliqué, sans effet. Pour
savoir laquelle est branchée : joindre `pg_trigger` à `pg_namespace`,
`pg_proc` seul renvoie les deux sans dire laquelle sert.

Deux vérifications faites directement sur la base :

- **`messages` → `notifications`** : insertion d'un message dans une
  transaction volontairement annulée (`RAISE EXCEPTION` en fin de bloc, donc
  rien de persisté et aucun push envoyé) → 28 → 29 lignes, destinataire = le
  participant **autre** que l'expéditeur, titre = nom de l'expéditeur, corps =
  contenu. L'exclusion de l'expéditeur est donc bonne.
- **`notifications` → FCM** : une ligne de test insérée sur le compte Salim a
  produit `{"sent":1,"removed":0}` en HTTP 200 dans `net._http_response` — le
  push est réellement parti, le token était valide. Ligne supprimée depuis.
- **Filtre par type** : avec `notification_prefs = {"messages": false}`, la
  même insertion donne `{"skipped":"type disabled: messages"}` et la ligne
  in-app reste créée. Préférence remise à `{}` depuis.

Reste ce que seul un téléphone peut dire — le rendu, le groupement, les
doublons :

- [x] **Message 1-à-1, app en arrière-plan** — vérifié le 2026-08-06 sur le
      SM A515F. La bannière arrive, `android.title = "Salim L."` (nom de
      l'expéditeur), `android.text` = le contenu, `channel=messages`,
      `importance=4`. Une seule bannière, aucun doublon.

      Deux pièges rencontrés en le testant, à ne pas refaire :
      - un `adb shell am force-stop` **empêche Android de délivrer FCM** ; un
        test « app tuée » lancé comme ça ne prouve rien. Lancer l'app, puis
        `KEYCODE_HOME`.
      - l'appareil est connecté avec le compte **Sim A**
        (`vQZE49dTdyRtLwSG6lMIbhAqoFG2`), pas Salim L. Pousser vers le mauvais
        `user_id` donne `{"sent":1}` côté serveur — FCM accepte un token
        périmé sans broncher — et rien n'arrive. Toujours vérifier le compte
        connecté avant de conclure.

- [ ] **Message 1-à-1, app réellement tuée** (balayée des récents, pas
      `force-stop`) : reste à faire.
- [ ] **Message de groupe** : titre = nom du groupe, corps = `Nom: aperçu`.
- [x] **Le SDK Firebase poste bien sous `id=0`** — confirmé par
      `dumpsys notification` : `id=0 tag=msg_verif-simA-004`. L'id du repli
      local est passé de `conversationId.hashCode % 99999` à 0, il remplacera
      donc la bannière au lieu de s'y ajouter. Ce n'était qu'une hypothèse
      jusque-là.
- [ ] **Doublon en arrière-plan, build à jour** : à revérifier une fois l'APK
      reconstruit — le repli local n'a pas posté pendant l'essai, donc le cas
      « les deux chemins se déclenchent » n'a pas été observé.
- [ ] **Conversation ouverte au premier plan** : pas de notification système.
- [ ] **Conversation mutée** : rien n'arrive (le trigger filtre `data.mutedBy`).
- [ ] **« Mes notes »** : s'écrire à soi-même ne déclenche aucune notification.
- [ ] **Aperçu désactivé** (`show_message_preview = false`) : corps générique.
- [ ] **Bascule push du profil sur `off`** : plus rien n'arrive côté FCM alors
      que la cloche in-app continue de se remplir.

### Icône de barre d'état — corrigée ET vérifiée à l'écran (2026-08-06)

Chaîne complète refaite sur le SM A515F, build reconstruit et installé
(`adb install -r`, session Firebase et clés E2EE conservées).

**Un vector drawable ne convient pas comme petite icône de notification.**
Première tentative avec `res/drawable/ic_stat_notification.xml` : la
notification n'apparaissait **plus du tout** — 60 s de scrutation, rien, alors
que le build précédent l'affichait. Elle figurait bien un instant dans le
registre Samsung puis disparaissait, ce qui ressemble à un `Bad notification`
côté système. Aucune trace dans logcat.

Remplacé par de vrais PNG monochromes générés aux cinq densités
(`drawable-mdpi` → `drawable-xxxhdpi`, bulle de discussion blanche sur fond
transparent) : la bannière réapparaît **en 5 s**.

- [x] **Notification affichée** : `id=0 tag=msg_… channel=messages
      importance=4`, titre = nom de l'expéditeur.
- [x] **Icône correcte** : `icon=Icon(typ=RESOURCE id=0x7f08012d)`, soit
      `drawable/ic_stat_notification` (vérifié par `aapt2 dump resources`).
      À l'écran : bulle monochrome, comme WhatsApp et Telegram.
- [x] **Le repli local devait aussi la déclarer.** Sans `icon:` dans
      `_showFallbackMessageNotification`, le plugin retombait sur son défaut
      `@mipmap/ic_launcher` — un disque blanc. C'est ce repli qui poste en
      arrière-plan, donc c'était bien lui qu'on voyait.
- [x] **Filet orange et icône sur le chemin du SDK Firebase** — la
      notification de mention passe par le SDK (tag `FCM-Notification:…`), pas
      par le repli local : `dumpsys` y donne `color=0xffe07b39` et
      `icon=0x7f08012d`. C'est donc le `default_notification_icon` et le
      `notification_accent` du manifeste qui sont vérifiés, en plus du chemin
      repli déjà contrôlé. Les deux chemins peignent enfin le même orange.

⚠️ **Ne pas revenir à un vector drawable** pour cette icône, même « parce que
c'est plus propre » : ça supprime silencieusement toutes les notifications.

### Deuxième défaut, indépendant : l'icône de barre d'état n'existait pas

`notification_service.dart` référence `@drawable/ic_stat_notification` six fois
— dont dans `_showLocalNotification` (ligne 1805), le chemin d'affichage de
**toute** notification au premier plan. Le fichier n'existait dans aucun
dossier `res/` : `getResources().getIdentifier()` renvoyait 0, et Android
refuse de poster une notification sans petite icône valide. Les `try/catch` du
service (tous leurs `debugPrint` commentés) avalaient l'exception.

Autrement dit : même une fois le SQL appliqué, aucune notification au premier
plan ne se serait affichée. Corrigé par un vector drawable monochrome
(`res/drawable/ic_stat_notification.xml`) et les deux `meta-data` FCM
(`default_notification_icon` / `default_notification_color`) qui manquaient au
manifeste. `:app:processDebugResources` passe.

- [ ] **Icône visible** : la barre d'état montre la cloche blanche, pas un
      carré blanc ni rien du tout — au premier plan **et** app tuée (deux
      chemins de rendu différents : le plugin et le SDK Firebase).
- [ ] **Filet orange** : la notification dépliée est teintée `#E97424`.
- [ ] **Résumé de groupe** (`_showGroupSummaryNotification`) et **notification
      de proximité** : mêmes chemins, même icône, à voir au moins une fois.
- [ ] **Réponse rapide depuis la notification** : la confirmation « Message
      envoyé » s'affiche (elle aussi utilisait l'icône manquante).

Le glyphe est le « notifications » de Material, posé comme placeholder : à
remplacer si une version blanche monochrome de la marque est produite.

### Trois fils débranchés, trouvés au passage — CORRIGÉS

**1. Personne n'émettait jamais vers un topic FCM.** Zéro occurrence de
`topic`, `sendToTopic` ou `/topics/` dans `functions/index.js`,
`functions/supabase.js` et `send-push` — cette dernière ne vise que des tokens
individuels. L'app s'abonnait pourtant à trois familles de topics : `general`
(interrupteur maître), `group_<id>` (adhésion), et un topic par événement
(« M'avertir du prochain »).

Les trois abonnements sont retirés. `subscribeToTopic` / `unsubscribeFromTopic`
restent dans `notification_service.dart`, documentées comme sans appelant, pour
le jour où un émetteur existera.

⚠️ **Reste ouvert** : la bascule « M'avertir du prochain » persiste toujours le
choix localement, mais rien ne l'honore — il n'y a pas d'émetteur à écrire sans
décider d'abord *qui* est notifié à la création d'un événement. À trancher :
émetteur serveur, ou retirer la bascule.

- [ ] Ne rien attendre de « M'avertir du prochain » tant que ce point est ouvert.

**2. Les préférences par type ne filtraient qu'au premier plan.**
`_shouldShowNotification` n'est appelée que depuis `_handleForegroundMessage`,
et nulle part ailleurs. App en arrière-plan ou tuée, c'est le système qui
affiche le bloc `notification` du push : la préférence n'était jamais lue.
Couper « Messages » ne coupait donc rien dès que l'app était fermée —
précisément le moment où ça compte.

Corrigé par une source serveur : colonne `users.notification_prefs` (JSONB,
migration `20260805233000`), écrite par chaque bascule
(`_syncTypePrefsToServer`) et lue par `send-push` (`prefKeyFor`). Convention :
**clé absente = autorisé**, seul un `false` explicite coupe — les comptes
existants gardent donc le comportement actuel.

⚠️ Les deux switch — `prefKeyFor` (TypeScript) et `_shouldShowNotification`
(Dart) — doivent bouger ensemble. Désynchronisés, une bascule coupe au premier
plan et laisse passer app fermée : exactement le défaut corrigé ici.

**`send-push` est déployée** (le déploiement des Edge Functions passe, seule
l'écriture SQL est bloquée). Elle lit `notification_prefs` par une requête
**séparée et tolérante à l'absence de la colonne** : la première version
nommait la colonne dans le select principal, et comme la migration n'est pas
encore appliquée, ce select échouait, `userRow` valait null, et **plus aucun
push ne partait** — y compris ceux qui marchaient. Corrigé et redéployé dans la
foulée, vérifié de l'extérieur (401 sans le secret partagé). Tant que la
migration n'est pas passée, la préférence par type est simplement ignorée :
personne ne perd de notification.

- [ ] **« Messages » sur `off`, app tuée** : plus aucune bannière.
- [ ] **« Demandes d'amis » sur `off`** : idem, et les messages continuent
      d'arriver (le filtrage est bien par type, pas global).
- [ ] **Rebasculer sur `on`** : les notifications reviennent sans redémarrage.

**3. iOS : aucun push possible, à deux niveaux.**

- `aps-environment` ajouté à `ios/Runner/Runner.entitlements`. Sans lui,
  l'enregistrement APNs échouait, `getAPNSToken()` renvoyait nil et
  `_getToken()` sortait avant même d'appeler `getToken()` : aucun token FCM
  n'était jamais enregistré sur iOS.
  ⚠️ **La clé seule ne suffit pas** : il faut activer la capability « Push
  Notifications » sur l'App ID **et** régénérer le profil de provisionnement,
  sinon la signature échoue. Ça se fait dans Xcode, pas ici.
- `saveVoipTokenForUser` est enfin appelée : `_bindVoipTokenTo` branche
  `onVoipTokenUpdated` à la connexion (et rattrape un jeton déjà reçu), et la
  déconnexion vide `users.voip_token`. Sans ça, la colonne restait vide et les
  appels CallKit iOS ne pouvaient pas sonner.

Rien de tout ça n'est vérifiable depuis Windows — aucune de ces cases ne sera
cochée sans un Mac et un appareil iOS.

- [ ] Token FCM enregistré sur iOS après connexion (ligne `users.fcm_tokens`).
- [ ] `users.voip_token` renseigné, et vidé à la déconnexion.

### Rappels planifiés — écrivaient dans une collection morte (2026-08-06)

Six émetteurs de notifications des Cloud Functions écrivaient dans la
collection **Firestore** `notifications`, que plus personne ne lit depuis que
l'app est passée à Supabase. Ils tournaient, ne levaient aucune erreur, et ne
produisaient rien :

| Fonction | Déclencheur | Notifications |
|---|---|---|
| `processReminders` | toutes les 15 min | rappels génériques (événement, transfert) |
| `sendEventReminders` | toutes les heures | « commence demain » |
| `sendTransferReminders` | tous les jours à 09:00 | transferts programmés |
| `onPodcastEpisodeCreated` | Firestore | nouvel épisode |
| `onAudioRoomStatusChanged` | Firestore | salon passé en direct |
| `notifyLocalEventCreated` | Firestore | événement dans ta ville |

Corrigé par un helper `createNotification` dans `functions/supabase.js` : il
accepte la forme Firestore historique (`userId`/`isRead`/`targetId`) et écrit
la ligne Supabase, ce qui rebranche `trg_notify_push` → send-push → FCM. Les
six appels ont été basculés, les fonctions déployées, et le helper exercé avec
l'environnement réel des Cloud Functions → `{"sent":1,"removed":0}` en HTTP 200.
Ligne de test supprimée.

⚠️ **`notifyLocalEventCreated` reste inerte, pour une autre raison.** Il
sélectionne ses destinataires sur la localisation, et sur le distant
`users.city` est **null ou vide pour tout le monde**, `country_code` ne contient
que des codes ISO-2 (`NE`, `BF`, `CA`) là où l'événement porte un nom de pays.
Aucun destinataire ne peut matcher — ni côté Firestore, ni côté Supabase. Je
n'ai pas porté la requête : ça n'aurait rien réparé tout en en donnant l'air.
Le vrai préalable est de peupler la localisation des profils.

- [ ] **Rappel d'événement** : créer un événement à ~24 h, s'y inscrire,
      attendre le passage horaire de `sendEventReminders`.
- [ ] **Salon audio passé en direct** : les abonnés reçoivent la bannière.
- [ ] **Nouvel épisode de podcast** : idem pour les abonnés du podcast.

### Les 28 écritures Firestore restantes — triées (2026-08-06)

Inventaire fait fonction par fonction, en croisant chaque déclencheur avec
l'endroit où sa donnée vit réellement aujourd'hui.

**15 écritures basculées vers Supabase et déployées** — leur déclencheur existe
encore, seule la destination était morte :

| Fonction | Pourquoi elle tourne encore |
|---|---|
| `onCallUpdated` | les appels sont restés dans Firestore |
| `onTransferStatusChanged` (×2) | les transferts aussi |
| `onOrderCreated`, `onOrderUpdated` (×4), `processOrderPayment` | la place de marché aussi |
| `stripeWebhook`, `stripeConnectWebhook`, `bankWebhook`, `processPayoutRequest` (×2), `checkEscrowTimeouts` | HTTPS / planifiées : elles tournent quoi qu'il arrive |

**Les 13 restantes, reprises le 2026-08-06.** Elles ne se réduisaient pas à un
changement de destination : chacune demandait de décider quoi en faire.

*Une seule capacité manquait vraiment* — `onNewPostCreated`, qui prévenait les
abonnés, les personnes mentionnées et les membres des groupes cités. Personne
ne le faisait à sa place. Portée en **trigger Postgres** sur `posts`
(`trg_notify_on_post_insert`, migration `20260806110000`), au plus près de la
donnée. Deux écarts assumés avec l'originale :

- pas de diffusion aux abonnés pour une publication de groupe ou non publique.
  L'originale mettait l'aperçu du contenu dans le corps de la notification —
  donc recopiait le texte d'un post de groupe privé à des gens qui n'y ont pas
  accès ;
- un destinataire n'est notifié qu'une **fois**. L'originale empilait trois
  notifications pour qui était à la fois abonné, mentionné et membre d'un
  groupe cité.

Vérifié dans une transaction annulée : 44 → 45 lignes, et le compte à la fois
abonné **et** mentionné n'en reçoit qu'une.

*Deux étaient des doublons* — `onPostLiked` et `onPostCommented`. L'app crée
déjà ces notifications côté client via la RPC `create_user_notification`
(`feed_provider.dart` : `postLiked`, `postCommented`, `commentReply`,
`postReposted`). Les rebrancher aurait doublé chaque « j'aime ». C'est
exactement la mise en garde laissée dans `index.js` à la suppression
d'`onCommentMention` — elle était juste.

*Deux n'ont plus de côté serveur du tout* — `onAudioRoomInviteCreated` (aucune
table d'invitations dans Supabase) et `onSupportMessageCreated` (les messages
de ticket vivent dans une colonne jsonb qu'aucun ticket ne remplit à ce jour).
Les porter reviendrait à deviner une forme de donnée que personne n'écrit.

*Le reste* : `sendNotificationOnCreate` et `sendChatNotification` sont
l'ancienne chaîne de push, l'une remplacée par `send-push`, l'autre désactivée
par un `return null` depuis longtemps. `onMessageDeleted` écoute un chemin RTDB
que l'app n'écrit plus.

Les cinq fonctions concernées portent désormais un en-tête `⚠️ MORTE` qui dit
pourquoi et ce qui les remplace. Elles restent **déployées mais inertes** :
leurs déclencheurs Firestore ne se produisent plus. Les retirer de Firebase
demande un `functions:delete` explicite — non fait, ça ne presse pas.

⚠️ **`cleanupUserData` n'a pas été touchée.** C'est du nettoyage Firestore de
bout en bout (conversations, messages, notifications) alors que ces données
sont dans Supabase — donc supprimer un compte y laisse tout en place. Mais
Jules a committé sur cette fonction le 2026-08-06 (`8d769d3`) : à traiter dans
son chantier, pas ici.

- [x] **Mentionner quelqu'un** — vérifié sur le SM A515F le 2026-08-06. Une
      publication insérée avec `mentioned_users` a produit la ligne
      `notifications` puis la bannière « Vous avez été mentionné(e) / Salim L.
      vous a mentionné(e) dans une publication ». Publication de test supprimée.
- [x] **Publier depuis un compte suivi** — vérifié sur appareil. Abonnement
      créé le temps du test puis supprimé : la bannière « Salim L. » est
      arrivée, `tag=FCM-Notification:1341720743`, `channel=general_channel`,
      `color=0xffe07b39`.
- [x] **Publier dans un groupe, ou en visibilité non publique** — vérifié en
      transaction annulée, les trois cas d'un coup : publique → 1 notification
      pour l'abonné, groupe → 0, `visibility = 'friends'` → 0. La garde qui
      évite de recopier l'aperçu d'un post privé aux abonnés fonctionne.

### Événements locaux + « M'avertir du prochain » — branchés (2026-08-06)

Les deux ne faisaient rien, pour deux raisons différentes. Ils partagent
désormais le même mécanisme.

**L'appariement se fait au rayon GPS, plus à la ville.** `users.city` est vide
pour les 10 comptes — le champ existe dans deux écrans de profil, personne ne
le remplit. La latitude/longitude, elle, est publiée par la carte « membres
autour » (5 comptes sur 10). Nouveau RPC `users_near_point(lat, lng, rayon)`
(migration `20260806100000`) : boîte englobante puis haversine, filtrage des
deux préférences inclus, `SECURITY DEFINER` et révoqué pour `anon` et
`authenticated`. Rayon retenu : **50 km**.

Vérifié sur la base **et** depuis l'environnement réel des Cloud Functions,
mêmes chiffres des deux côtés :

| Requête | Destinataires |
|---|---|
| Niamey, 50 km | 1 |
| Montréal, 50 km | 3 |
| Rayon 20 000 km | 5 (tous ceux qui ont des coordonnées) |
| Niamey, 1 km | 0 |

**« M'avertir du prochain » délègue au propriétaire du réglage.** Elle gardait
sa propre copie `bool` dans les SharedPreferences — une quatrième source pour
un réglage qui en avait déjà trop — et s'abonnait à un topic FCM que personne
n'alimente. Elle appelle maintenant
`NotificationPreferencesNotifier.setLocalEventsEnabled`, qui écrit la
préférence locale **et** `users.notify_local_events` : exactement la colonne
que lit `users_near_point`. Plus aucun champ `bool` local (cf. `CLAUDE.md`).
Le calcul de topic par pays et le paramètre `notifyTopic` de `_EventsPastCard`,
devenus sans objet, sont supprimés.

- [ ] **Créer un événement avec un lieu** à moins de 50 km d'un autre compte :
      celui-ci reçoit « Nouvel événement près de chez vous ».
- [ ] **L'organisateur ne reçoit rien** pour son propre événement.
- [ ] **Événement sans coordonnées** : rien n'est envoyé, et la fonction le
      journalise au lieu d'échouer.
- [ ] **Basculer « M'avertir du prochain »** : `users.notify_local_events`
      change côté serveur (la carte n'apparaît que s'il n'y a aucun événement
      à venir mais au moins un passé — état difficile à provoquer).

## Écrans de notifications — lot « une seule source » (2026-08-05)

`notification_settings_screen.dart` a rejoint `design_kit.dart` (c'était la
dernière exception de `reglages_sans_doublon_test.dart`) et l'en-tête de
`notifications_screen.dart` a gagné un menu ⋯. Le rendu change, `analyze` ne
le voit pas.

**Passe appareil du 2026-08-05 (14:36 → 14:41 PC), SM A515F, APK debug
`14b0343` installé par `adb install -r` — mise à jour en place, session et
données préservées. Thème système en NOCTURNE.**

- [x] **`/notifications/settings` : le pictogramme 42 en dégradé apparaît** sur
  les onze lignes, un seul filet entre chaque, aucun débordement. Vérifié
  **dans les deux thèmes** — nocturne d'abord, puis clair en forçant
  `adb shell cmd uimode night no` (réglage relevé avant, `ui_night_mode=2`, et
  remis à l'identique après). Pictogrammes, libellés, sous-titres et étiquettes
  de section lisibles des deux côtés ; le dégradé terracotta des pastilles
  fonctionne sur crème comme sur noir.
- [x] **Interrupteur maître coupé** : les sept catégories s'estompent bien à
  50 % (pictogrammes gris, bascules éteintes). **Un tap sur la bascule
  « Messages » éteinte n'a rien changé** — elle était encore active après
  restauration du maître, et les six autres avec elle. C'est le kit qui le
  fait via `onChanged: null` ; l'`IgnorePointer` + `AnimatedOpacity` de l'écran
  a disparu sans régression. (État remis tel qu'il était : maître actif, sept
  catégories actives.)
- [x] **Ligne « De 22:00 à 08:00 »** : rendue en `DesignSettingsTile`,
  pictogramme horloge + chevron, alignée sur les autres lignes de la carte.
- [x] **Tap sur la plage horaire vérifié** : « Début du silence » (22:00) →
  OK → « Fin du silence » (08:00) → **Annuler** → la ligne affiche toujours
  « De 22:00 à 08:00 ». L'enchaînement marche et l'abandon du second sélecteur
  n'écrit rien. Les deux boîtes sont bien teintées (accent terracotta, surface
  sombre).
- [x] **🔴 Trouvé sur appareil (2026-08-05, 06:20, SM A515F, APK `2fe9240`) —
  le titre « Notifications » se coupait au milieu du mot.** L'en-tête affichait
  « Notific / ations » sur deux lignes : la pastille « Tout marquer comme lu »
  mangeait ~410 px, et le titre en Playfair 30 tombait sous les ~230 px
  restants dans son `Expanded`. Vu au premier coup d'œil, jamais relevé
  jusqu'ici. **Corrigé** en repliant les deux actions secondaires dans le ⋯
  (forme 13c) — le titre reprend toute la largeur.
- [x] **Correctif confirmé sur appareil, dans les deux thèmes** :
  « Notifications » tient sur **une seule ligne**, sous-titre « 1 non lue »
  juste dessous, pastille ⋯ à droite.
- [x] **`/notifications` : les trois entrées du menu ⋯ s'affichent** — « Tout
  marquer comme lu », « Réglages », « Tout supprimer » en rouge. « Tout
  supprimer » était écrit mais **injoignable** (`buildOverflowMenu` n'était
  appelé nulle part) ; il s'ouvre désormais. Vérifié en clair et en nocturne.

### Refonte de la liste sur la maquette 12c (2026-08-05)

Deux registres, sections par jour, palette du thème. L'accordéon des groupes
est **conservé** (choix de Salim) : c'est le seul endroit d'où l'on voit les
notifications d'un groupe une par une.

- [x] **Sections par jour** (« CETTE SEMAINE » en chasse fixe terracotta) :
  vérifiées en clair et en nocturne.
- [x] **Registre « non lue » = carte** : fond teinté par famille, pastille
  carrée pleine 44 au rayon 12, compteur en accent, horodatage en chasse fixe.
  Vérifié dans les deux thèmes — la teinte s'assombrit correctement en nuit.
- [x] **L'accordéon tient dans le nouveau registre** : les treize lignes se
  déplient dans la carte, filet aligné, heures en chasse fixe, point de non-lu
  en accent.
- [x] **Le vert WhatsApp a disparu.** `#25D366` n'est plus dans le fichier
  (hors commentaire) et les `Colors.purple` / `teal` / `indigo` / `amber` ont
  laissé place à quatre teintes du thème (`notification_style.dart`, partagé
  avec l'écran de détail qui peignait sa propre copie).
- [x] **Valeurs exactes de la fiche appliquées et vues à l'écran** : puce
  active en encre `#1C1815` (et non en accent), badge compteur en rouge
  `#C23E2D`, bouton ⚙ **rond** de 42 qui va droit aux réglages, carte
  **uniforme** (c'est le pictogramme 38 qui porte la teinte de famille, pas la
  carte), pastille de non-lu 9 px, horodatage en `#A79C8E`.
- [x] **« Tout supprimer » a déménagé au bas des réglages**, section
  « HISTORIQUE » en rouge sur carte `isDanger` — la fiche ne laisse qu'un
  contrôle dans l'en-tête de la liste. Vérifié affiché ; **le dialogue de
  confirmation n'a pas été déclenché** (destructif sur les vraies données).
- [x] **🔴 Trouvé en testant — le balayage « marquer lu » n'existait pas sur
  une notification groupée.** L'en-tête d'un groupe n'avait **aucun**
  `Dismissible`, et les lignes du dépliant n'acceptaient que la suppression
  (`endToStart`). Le geste ne vivait que sur une notification **isolée** — or
  le regroupement fait justement qu'un compte actif n'en a presque aucune.
  **Corrigé** : l'en-tête marque tout le groupe lu au balayage droit (seul
  l'en-tête est enveloppé, sinon le dépliant avalerait les gestes de ses
  propres lignes), et les lignes du dépliant acceptent les deux sens.
- [x] **Registre « lue » vérifié, dans les deux thèmes.** Après balayage : la
  carte disparaît, la pastille passe en neutre `surfaceVariant`, le titre
  perd son gras, le point de non-lu et le compteur s'en vont, et l'en-tête
  perd son sous-titre « 1 non lue », son badge et « Tout lire ». ⚠ Les 13
  notifications du compte de test sont **désormais lues** — état non
  réversible depuis l'écran.
- [x] **« J'y vais » / « Voir » vérifiés** — carte d'événement conforme à la
  maquette (pastille verte, CTA plein + contour, « À L'INSTANT »), section
  « AUJOURD'HUI » créée d'elle-même. Notification de test fabriquée à la main
  dans Firestore, le compte n'ayant aucun événement. **Données de test
  supprimées** après coup (2 événements + 2 notifications) ; la collection
  `events` est revenue à 0 documents et la liste à son état d'origine.
- [x] **🔴 Trouvé — personne ne peut s'inscrire à un événement qu'il n'a pas
  créé.** « J'y vais » a répondu « Erreur de chargement ». Cause isolée par un
  témoin : `firestore.rules` n'autorisait l'`update` d'un événement qu'à son
  organisateur, or `attendEvent` fait un `arrayUnion` sur `attendeeIds` **du
  document événement**. Preuve — deux événements identiques, seul
  l'`organizerId` diffère : celui d'autrui reste à `attendeeIds: []`, celui
  dont le compte de test est organisateur passe à `["vQZE49…"]`.
  Ça ne vient pas de la refonte : `events_screen.dart` et
  `event_detail_screen.dart` appellent le même `attendEvent`, donc **le RSVP
  n'a jamais fonctionné pour un participant**, sur aucun écran.
- [x] **Dérive des règles élucidée — le fichier versionné était la copie
  périmée, pas la production.** Les règles déployées (mises en prod le
  2025-12-24) font 1501 lignes, le fichier du repo en faisait 666. **36
  collections** étaient protégées en prod et absentes du fichier — dont
  `user_keys`, `oneTimePreKeys`, `group_sender_keys` (clés E2EE), `calls`,
  `payouts`, `payment_history`, `posts`, `podcasts` — et **aucune dans l'autre
  sens**. La prod interdisait aussi à un utilisateur de modifier son propre
  `isAdmin`/`adminRole`, restreignait la lecture des demandes d'ami aux deux
  parties, et n'autorisait la création d'une notification que pour soi : trois
  protections absentes du fichier. Déployer l'ancien fichier aurait donc été
  une **régression de sécurité majeure doublée d'une panne** (36 collections
  retombant en deny-by-default). Le fichier a été resynchronisé depuis la
  prod ; il n'en diffère plus que par `inscriptionPourSoi()`.
- [x] **Règles déployées le 2026-08-05** (`firebase deploy --only
  firestore:rules`, compilation OK). Production relue par l'API REST juste
  après : **identique au fichier versionné**, `inscriptionPourSoi()` présent.
- [x] **« J'y vais » rejoué sur l'événement d'autrui — il passe.**
  « Vous y participez », la notification bascule en registre « lue », et en
  base `attendeeIds = ["vQZE49…"]` sur l'événement dont l'organisateur est
  quelqu'un d'autre. Titre et date inchangés : le garde-fou de la règle tient,
  seul `attendeeIds` a bougé.
- [x] **Carte « demande d'ami » conforme à la maquette** — pastille verte,
  « Accepter » plein + « Refuser » en contour. Demande et notification
  fabriquées à la main, le compte n'en avait aucune.
- [x] **🔴 Trouvé — accepter une demande d'ami était impossible, et l'échec
  était muet.** Tap sur « Accepter » : rien à l'écran, rien en base
  (`status` toujours `pending`, `friendIds` vides). logcat :
  `PERMISSION_DENIED` sur le batch.
  **Cause, isolée par l'API `firebaserules:test` sans toucher aux données** —
  la règle `users/{userId}` couvrait create + update + delete dans un seul
  `allow write` appelant `diff(resource.data)` sans garde. Sur une **création**
  `resource` est nul : la règle ne renvoyait pas `false`, elle **plantait**
  (« Null value error, ligne 79, colonne 71 »). Donc **personne ne pouvait
  créer son propre document `users`** — ce qui explique aussi que le document
  du compte de test n'ait jamais existé malgré un onboarding complet, et le
  `PERMISSION_DENIED` sur `users/{uid}` qui traînait depuis le 2026-08-03.
  Le batch d'acceptation contenant un `set(merge)` sur les deux profils, il
  était refusé en entier.
  **Corrigé** : `write` séparé en `create` / `update` / `delete` — sur un
  `update`, `resource` existe toujours et le `diff` ne peut plus planter. La
  création interdit toujours de se donner `isAdmin`/`adminRole`. Quatre cas
  validés par l'API de test (créer son profil : autorisé ; se donner isAdmin :
  refusé ; créer le profil d'autrui : refusé ; créer un événement : autorisé).
- [x] **Corrigé aussi : l'échec ne disait rien.** `_respond` n'affichait un
  message qu'en cas de succès — un refus de permission se lisait comme un tap
  qui n'avait pas pris. C'est ce qui a caché le défaut. Il affiche désormais
  une erreur rouge.
- [x] **Règle `users` déployée le 2026-08-05**, production relue et identique
  au fichier versionné.
- [x] **« Accepter » fonctionne** — « Demande acceptée », et en base :
  `status: accepted`, `friendIds` renseignés **des deux côtés**,
  sous-collections `friends` créées. Surtout, **le document `users` du compte
  de test a été créé** — il n'avait jamais pu l'être. C'est la preuve directe
  que le chemin de création était bien ce qui bloquait.
- [x] **« Refuser » fonctionne** — `status: declined`, notification marquée
  lue, carte passée en registre « lue ».
- [ ] **Relevé au passage — le pilotage `adb` dérive sur cet écran.** Quand
  une notification change de registre, la carte perd sa hauteur et **tout ce
  qui est en dessous remonte** : un tap calculé sur une capture prise 3 s plus
  tôt tombe à côté (deux fois sur trois ici, dont une navigation involontaire
  dans une conversation, et une demande acceptée au lieu d'être refusée).
  Recapturer **juste avant chaque tap**, ou tester au doigt. Ce n'est pas un
  défaut de l'app — c'est une limite de la méthode.
- [x] ~~« Tout marquer comme lu » grisé~~ — **entrée devenue fausse** : la
  fiche 12c a remis l'action dans l'en-tête sous le libellé court « Tout
  lire », qui **disparaît** quand il n'y a aucune non-lue au lieu d'être
  grisé. Vérifié : la pastille n'est plus là une fois tout lu.
- [x] **Dialogue de « Tout supprimer » vérifié le 2026-08-05.** Les 15 vraies
  notifications du compte ont été **sauvegardées avant**, puis restaurées à
  l'identique (mêmes ids, mêmes horodatages) — le compte est revenu à son état
  exact. Le dialogue s'affiche (« Supprimer toutes les notifications /
  Voulez-vous vraiment… », Annuler + Supprimer en rouge), la suppression
  aboutit, et l'écran tombe sur l'état vide « Aucune notification / Vous serez
  notifié des nouvelles activités ».
- [x] **🔴 Trouvé sur appareil — l'écran de détail était injoignable.**
  L'appui long sur une notification **groupée** dépliait le groupe au lieu
  d'ouvrir le détail : `_NotificationGroupItem` déclarait `onLongPress`, la
  liste le lui passait, et son `InkWell` ne le branchait **jamais** — seul
  `_NotificationItem` (notification isolée) l'utilisait. Le compte de test
  n'ayant que des notifications groupées, l'écran n'était atteignable par
  aucun geste. **Corrigé et revérifié** : l'appui long ouvre bien le détail.
  Troisième câble mort de la même famille que `buildOverflowMenu`.
- [x] **`/notifications/:id` : le sur-titre est en français** — « Message » et
  non « MESSAGE » (`type.name.toUpperCase()`). Vérifié pour le type message.
- [x] **Étiquettes des autres familles vérifiées le 2026-08-05** — cinq
  notifications fabriquées (`groupInvite`, `eventReminder`, `orderShipped`,
  `newFollower`, `proximityAlert`), puis supprimées. Détail de `orderShipped`
  ouvert à l'appui long : sur-titre **« Commande expédiée »**, accents compris,
  et date **« 05 août 2026, 23:34 »**. Les cinq s'affichent dans la liste avec
  le bon pictogramme et le bon libellé de corps.
- [ ] **Relevé au passage — la palette de familles rend deux teintes, pas
  quatre.** `groupInvite`, `eventReminder`, `newFollower` et `proximityAlert`
  ressortent toutes du **même vert** : `successColor` et
  `adaptiveSecondaryColor` sont trop proches sur ce thème. Seul l'or des
  commandes se distingue. À arbitrer — soit on assume deux familles visuelles,
  soit on écarte les deux teintes.
- [x] **🔴 Trouvé au passage — la date du détail était en anglais.**
  « 03 August 2026, 20:19 » : `DateFormat('dd MMMM yyyy, HH:mm')` sans locale
  retombe sur en_US. Passe désormais par `LocaleHelper.getDateFormatLocale`.
- [x] **🔴 Trouvé au passage — le titre de la barre était tronqué.** « Détail
  de la notificati… », l'action ⏰ mangeant la largeur. Remplacé par
  « Notifications ».
- [x] **Les deux revérifiés à l'écran** : le titre de barre affiche
  « Notifications » en entier (plus de « Détail de la notificati… »), et la
  date se lit **« 03 août 2026, 20:19 »** — en français, plus « 03 August ».
  La pastille de type est celle de la palette partagée.
- [x] **`/notifications/:id` sur un id absent : vérifié par lien profond, app
  tuée** — le cas réel d'une charge utile push. `am start -a VIEW -d
  https://diasponiger.web.app/notifications/idinexistant000000` affiche
  « Cette notification n'est plus disponible », **pas l'écran rouge**. Le
  `firstWhere` levait pendant le build avant ce lot.

---

## Bruit dans logcat — deux traces à ne pas re-diagnostiquer (2026-08-05)

Relevées en fin de session. Aucune des deux n'a d'effet visible, mais elles
polluent logcat, et **c'est ce qui rend un vrai refus invisible** — il a fallu
vider logcat et retaper pour voir celui qui bloquait « Accepter ».

### `PERMISSION_DENIED` sur `conversations/883c9d96-…` — écoute fantôme

Ce n'est **pas** un défaut de droits. Enchaînement établi :

- l'id est un **UUID Supabase**, et la conversation existe bien côté Supabase
  (créée le 2026-07-17, vérifiée par `supabase db query --linked`) ;
- elle **n'a jamais existé dans Firestore** : la collection `conversations`
  n'y contient qu'un seul document, un id auto-généré appartenant à Salim L. ;
- la messagerie est câblée sur `MessageSupabaseDataSource`
  (`message_provider.dart`), donc plus rien ne devrait interroger Firestore ;
- le seul écouteur Firestore sur un document de conversation est
  `MessageRemoteDataSourceImpl.getConversationStream`
  (`message_remote_datasource.dart:518`), et il est **injoignable** : cette
  classe n'est instanciée que par la recherche, qui n'appelle d'elle que
  `searchConversations`.

Conclusion : c'est une **cible d'écoute rémanente**, enregistrée par un build
d'avant la migration et rejouée par la persistance locale de Firestore à
chaque démarrage. La règle refuse au lieu de renvoyer « vide » parce que
`resource` est nul sur un document absent — même faiblesse que celle corrigée
sur `users`, mais bénigne en lecture.

- [ ] Non prouvé faute de moyen non destructif : confirmer en vidant le cache
  Firestore de l'app. **Ça efface les données de l'app**, donc les clés E2EE —
  à ne faire que si la trace devient gênante.

### 🔴 Supprimer un compte laisse un ami fantôme chez tous ses amis

Trouvé en remontant l'incohérence relevée chez Salim L. (`friendIds` vide,
deux amis dans `friends/`).

L'amitié est écrite **des deux côtés** (`users/A/friends/B` et
`users/B/friends/A`), et c'est **cette sous-collection que l'app lit** —
`getFriends` et `areFriends` n'utilisent qu'elle. Le tableau `friendIds`, lui,
n'est lu par **aucun** écran : son seul lecteur est la fonction de suppression
de compte.

Or `deleteAccount` (`functions/index.js`) :
- efface les sous-collections **du compte supprimé** (`friends`,
  `blocked_users`, `cart`, `sessions`) ;
- retire l'utilisateur des `friendIds` des autres — un champ que personne ne
  lit ;
- et **ne touche jamais** aux entrées miroir `users/{autre}/friends/{supprimé}`.

Conséquence : le compte supprimé **reste indéfiniment dans la liste d'amis des
autres**, avec son nom et sa photo, et `areFriends` répond toujours « oui ».

**Correctif écrit** : la liste d'amis du compte donne exactement l'ensemble
des personnes ayant une entrée miroir ; on les supprime avant d'effacer la
liste. Pas de requête de groupe de collections, donc **aucun index
supplémentaire** à créer.

- [x] **Déployé le 2026-08-05** — `cleanupUserData(us-central1)`, mise à jour
  réussie. Déployé **seul** : `firebase deploy --only functions` s'arrête de
  lui-même parce que `sendMessagePush(europe-west1)` et
  `sendChatNotification(us-central1)` existent en production **sans source
  dans le dépôt**, et le CLI refuse de les supprimer en non-interactif. Les
  deux sont toujours en ligne après le déploiement ciblé.
- [x] **Vérifié de bout en bout le 2026-08-05**, avec deux comptes jetables
  créés puis supprimés par l'API Identity Toolkit (aucun compte réel touché) :
  A et B amis, suppression de A → l'entrée miroir `users/B/friends/A`
  **disparaît**, le profil de A et sa sous-collection aussi.
- [x] **🔴 Et la vérification a trouvé pire : le nettoyage ne tournait pas du
  tout.** Premier essai, rien n'était supprimé — pas même le profil du compte
  effacé. Les journaux :
  `Cannot use "undefined" as a Firestore value (found in field "userStats.createdAt")`.
  Le journal d'audit est écrit **en tête** de `cleanupUserData`, et son
  ternaire ne testait que l'existence du **document**, pas celle du **champ** :
  un profil sans `createdAt` renvoyait `undefined`, que Firestore refuse dans
  un `.add()`. L'exception partait avant la moindre suppression.
  **Supprimer un compte ne supprimait donc rien**, en silence — ni profil, ni
  sous-collections, ni notifications, ni conversations.
  **Corrigé** (`?? null` sur les deux champs **et** journal d'audit rendu non
  bloquant : il est utile, le nettoyage est obligatoire), déployé, puis rejoué
  avec un profil volontairement dépourvu de `createdAt` — le cas qui plantait.
- [x] **La même famille cherchée ailleurs le 2026-08-06** (suite de `8d769d3`).
  Deux motifs distincts : *(a)* un ternaire `.exists ? …data().champ : …` qui
  laisse passer `undefined` jusqu'à une écriture Firestore ; *(b)* une écriture
  accessoire placée avant du travail obligatoire, sans filet. Résultat :
  - `.exists ?` — **une seule** occurrence restante sans repli, corrigée :
    `onAudioRoomInviteCreated` (`functions/index.js`) posait
    `roomTitle = roomDoc.data().title` puis l'écrivait dans `data.roomTitle`.
    Un salon sans `title` faisait donc échouer le `.add()` ; le `catch` de la
    fonction avalait l'erreur et **l'invitation n'était jamais notifiée**.
    Les autres (`senderName`, `buyerName`, `cancellerName`, `likerName`,
    `displayName`…) ont déjà un `|| "…"` — rien à faire.
  - Assignations nues `x = doc.data().champ` : 7 occurrences, toutes vérifiées.
    Aucune n'atteint une écriture Firestore sauf dans `onPostLiked` /
    `onPostCommented`, **explicitement marquées MORTES** dans le fichier.
- [ ] 🔴 **Le nettoyage était encore tout-ou-rien après le correctif — corrigé
  le 2026-08-06, NON déployé.** Le commit `8d769d3` a isolé le journal d'audit,
  mais les **17 étapes** du bloc Firestore restaient dans un `try` **unique** :
  la première qui levait (index composite manquant, document malformé, valeur
  inattendue) sautait droit au `catch` final et **toutes les suivantes étaient
  ignorées en silence**. Casser sur les demandes d'ami (1.3) laissait derrière
  elle notifications, conversations, groupes, produits, transactions,
  signalements. Les sections 2 (RTDB) et 3 (Storage) avaient déjà leur filet ;
  `results.firestore.errors` était déclaré et journalisé mais **jamais
  alimenté** — impossible de savoir où le nettoyage s'était arrêté.
  Chaque étape est désormais enveloppée par un helper `etape(nom, travail)` qui
  journalise et pousse dans `results.firestore.errors`, puis continue.
  **Garde-fou ajouté le 2026-08-06** : `tools/rules_tests/nettoyage_isole.mjs`
  vérifie que les 17 étapes `// 1.N` sont bien chacune dans un
  `await etape(…)`. 17 annoncées, 17 enveloppes. Contre-épreuve faite — pointé
  sur `git show 8d769d3:functions/index.js`, il sort 1 et liste les 16 étapes
  nues : **il sait échouer**.
  ⚠️ Ce banc prouve la **couverture**, pas le comportement à l'exécution. Le
  risque réel était qu'une étape soit ajoutée hors enveloppe, pas qu'un
  `try/catch` cesse de fonctionner — mais il ne remplace pas un vrai échec
  provoqué en conditions réelles, qui reste à faire.
  **À faire** : redéployer `cleanupUserData` **seul** (cf. l'entrée ci-dessus
  sur les orphelines, et ne jamais `--force`), puis rejouer le scénario à deux
  comptes jetables en forçant l'échec d'une étape intermédiaire — vérifier que
  les étapes suivantes s'exécutent quand même et que l'étape fautive apparaît
  nommée dans les journaux.
- [x] 🔴 **Le même défaut dans trois balayages périodiques — corrigé et
  DÉPLOYÉ le 2026-08-06 à 07:01 UTC.** En cherchant le motif « N opérations
  indépendantes sous un `try` unique » dans le reste de `functions/index.js` :
  `cleanupExpiredMessages`, `cleanupStaleParticipants` et
  `cleanupStaleGroupCalls` bouclaient sur des éléments **indépendants** sans
  filet par élément. Le premier qui lève arrêtait le balayage entier.
  Deux voisines, `cleanupExpiredMediaFiles` et `cleanupStaleCalls`, avaient
  **déjà** ce filet — le bon motif existait dans le fichier, il manquait juste
  à trois endroits. Les trois s'y alignent maintenant.
  - **Le plus grave est `cleanupExpiredMessages`** (toutes les heures) : c'est
    la seule chose qui fait disparaître les messages éphémères. Une
    conversation fautive et toutes les suivantes gardaient leurs messages
    expirés — et comme la fonction **relance l'erreur**, pub/sub la rejouait
    en retombant sur la même conversation, indéfiniment. La promesse « ce
    message disparaît » était rompue en silence et durablement. Un
    `console.error` récapitulatif compte désormais les conversations non
    balayées.
  - `cleanupStaleParticipants` : un salon fautif laissait tous les autres avec
    leurs participants fantômes, « en direct » indéfiniment.
  - `cleanupStaleGroupCalls` : idem, appels de groupe orphelins restés actifs.
  - Vérifié sans suite : `onReviewDeleted` (opération unique, rien à isoler).
  **Déployé** (`onAudioRoomInviteCreated` inclus) : les quatre en
  « Successful update operation », essai à blanc préalable sans orpheline.
  `cleanupUserData` **volontairement laissée de côté** — chantier de Jules
  (migration Firestore → Supabase, `2af0920`/`e3576a3`/`7337127`), et le
  nettoyage Firestore vise de toute façon la mauvaise base maintenant que la
  donnée est dans Supabase. Le correctif est commité (`d07d533`), pas déployé.
- [x] **Journaux relus après déploiement — et ils nuancent le diagnostic.**
  `cleanupExpiredMessages` tourne toutes les heures **à :24** et se terminait
  déjà `ok` à chaque exécution (02:24 → 06:24 vérifiées), « Deleted 0 messages
  and 0 files » à chaque fois. **Le scénario corrigé ne se produisait donc pas
  en production** : le correctif est préventif, il n'a réparé aucune panne en
  cours. À redire honnêtement si quelqu'un relit le commit.
- [ ] 🔴 **Index RTDB manquant sur les deux balayages de messages** (trouvé
  dans les mêmes journaux, 2026-08-06, **non corrigé**) :
  `FIREBASE WARNING: Using an unspecified index … Consider adding
  ".indexOn": "expiresAt" at /messages/<convId>`.
  `database.rules.json` déclare bien un `.indexOn` sur `messages/$conversationId`,
  mais **uniquement `["createdAt"]`**. Or `cleanupExpiredMessages` interroge
  `orderByChild("expiresAt")` et `cleanupExpiredMediaFiles`
  `orderByChild("mediaExpiresAt")` — aucun des deux n'est indexé.
  Conséquence : à chaque passage, **tous** les messages de **chaque**
  conversation sont téléchargés puis filtrés côté fonction. Invisible
  aujourd'hui (une seule conversation a des messages en RTDB, 1,5 à 2 s par
  exécution), mais le coût croît avec l'historique — c'est exactement la
  fonction qu'on vient de fiabiliser qui deviendra lente et chère.
  **Index ajouté au fichier** le 2026-08-06 (`.indexOn` de
  `messages/$conversationId` passe à `["createdAt", "expiresAt",
  "mediaExpiresAt"]`, JSON revalidé), puis **déployé** — voir juste en dessous
  pour ce que ce déploiement a entraîné d'autre.
- [x] **WARNING d'index disparu, vérifié dans les journaux.** Les exécutions de
  04:24, 05:24 et 06:24 portent toutes la ligne `FIREBASE WARNING: Using an
  unspecified index` entre « Starting » et « Cleanup complete ». Celle de
  **08:02, après déploiement, ne l'a plus** : « Starting » → « Cleanup
  complete », rien entre les deux. L'index est bien pris en compte.
  ⚠️ **Ne pas conclure à un gain de vitesse** : cette exécution a pris 3633 ms
  contre 1446 à 2112 ms avant. C'est un démarrage à froid (conteneur reconstruit
  au déploiement de 07:01 puis redescendu à zéro), et avec une seule
  conversation peuplée et 0 message à supprimer, la durée ne mesure de toute
  façon pas la requête. Le gain est structurel, pas encore observable.
  À noter aussi : l'horaire du balayage est passé de **:24 à :02** — redéployer
  une fonction planifiée réinitialise son job Cloud Scheduler. Aucune exécution
  n'a été perdue.

### 🔴 `database.rules.json` est en avance de 27 changements sur la production

Relevé le 2026-08-06 en voulant déployer le simple index ci-dessus. Les règles
en ligne se lisent avec :

```
MSYS_NO_PATHCONV=1 firebase database:get "/.settings/rules"
```

(`database:settings:get` ne sait pas lire `rules`, et sous Git Bash le chemin
`/.settings/rules` est mangé par la conversion MSYS — d'où `MSYS_NO_PATHCONV=1`.)

Comparées au fichier du dépôt : **18 chemins de règles existent dans le dépôt
et pas en ligne** (`admins`, `superAdmins`, `warnings` des salons, plusieurs
`.validate`, et les restrictions de signalisation) et **9 valeurs diffèrent
réellement** — aucune n'est une simple différence de mise en forme, vérifié en
normalisant les espaces.

Les quatre qui comptent :

| chemin | en ligne | dans le dépôt |
|---|---|---|
| `calls/$callId/.read` | `auth != null` | réservé à l'appelant/appelé |
| `calls/$callId/.write` | `auth != null` | idem |
| `group_calls/$callId/.read` | `auth != null` | réservé aux participants/hôte |
| `group_calls/$callId/.write` | `auth != null` | idem |

Le dépôt est donc **plus strict** que la production : c'est le durcissement de
la signalisation d'appel, écrit le 2026-08-03 et **volontairement laissé non
déployé** en attendant le test de non-régression à deux comptes (voir la
section « Appel 1:1 après restriction »).

⚠️ **Conséquence pratique : `firebase deploy --only database` n'est pas une
opération anodine.** Il embarquerait les 27 changements d'un coup, dont ce
durcissement jamais testé — et son mode d'échec est **silencieux** : l'appelé
ne verrait jamais l'offre, sans la moindre erreur. Un index de performance ne
justifie pas de risquer ça.

- [x] **Chemin 1 retenu et exécuté le 2026-08-06** (décision de Salim) :
  `firebase deploy --only database`, « rules syntax is valid » puis « released
  successfully ». Comparaison refaite juste après — **les règles en ligne sont
  désormais identiques au fichier du dépôt**, la dérive est soldée. Vérifiés
  un par un : l'index à trois entrées, `calls/.read` et `group_calls/.read`
  restreints, `admins` et `superAdmins` présents.
- [x] ⚠️ **CORRECTION DU 2026-08-06 — le diagnostic ci-dessous est FAUX.**
  Il est conservé tel quel parce que l'erreur est instructive, mais **ne pas
  s'y fier**. J'avais conclu que `callerId`/`calleeId` n'existaient nulle part
  dans RTDB à partir d'un `grep` **tronqué à 40 résultats** où
  `call_remote_datasource.dart` n'apparaissait pas. Or `createCall` **écrit
  bien ces deux champs dans le nœud RTDB**, avant toute signalisation, depuis
  `135ae92` (2026-08-03) — le commit qui a introduit les règles strictes les a
  introduits **ensemble**, elles étaient conçues pour aller de pair.
  **Mesuré en émulateur, sur la séquence réelle :**
  | | règles strictes | règles en ligne (permissives) |
  |---|---|---|
  | parcours nominal d'un appel (9 étapes) | **intact** | intact |
  | étanchéité | **fermée** | ouverte |
  | client d'un APK < 2026-08-03 | **cassé** | fonctionne |
  Donc les règles strictes ne cassent **pas** les appels : elles cassent
  uniquement les clients qui n'écrivent pas ces champs, c'est-à-dire les APK
  antérieurs au 2026-08-03. Le retour arrière était probablement inutile.
- [x] 🔴 **Et en voulant les redéployer, le banc a trouvé DEUX défauts de plus
  — dans les appels de GROUPE cette fois** (2026-08-06). Les règles strictes de
  `135ae92` n'avaient manifestement jamais été confrontées à l'app pour cette
  partie. Les deux sont corrigés :
  1. **La signalisation de groupe était entièrement refusée.** Le `.validate`
     posé sur `signaling/$fromId/$toId` exigeait un enfant `type`
     **directement** sous `$toId`, alors que l'app écrit
     `$toId/offer = {type, sdp}` (`group_call_service.dart`). Prouvé par sonde :
     écrire sur `$toId/offer` → 401, écrire sur `$toId` avec `type` → 200.
     **Correctif** : le `.validate` descend sur les enfants réels (`offer`,
     `answer`), avec `['type', 'sdp']` comme pour le 1:1.
  2. **La détection des arrivées serait morte.** `_listenForParticipants` était
     appelé **avant** `_registerParticipant` (lignes 145/157 et 234/246) : le
     client se mettait à l'écoute de `participants` avant d'en être un, ce que
     les règles strictes refusent — à raison. **Correctif** : inscription
     d'abord. Rien n'est perdu, `onChildAdded` émet aussi pour les enfants déjà
     présents. `flutter analyze` sur le fichier : aucun problème.
  Après correctifs, le banc passe intégralement contre les règles strictes :
  parcours nominal 1:1 **et** groupe intacts, étanchéité fermée des deux côtés.
### 🔴 La signalisation des appels de groupe était refusée EN PRODUCTION

Trouvé le 2026-08-06 en passant le banc contre les règles **déployées**, pas
contre une hypothèse. Deux échecs du parcours nominal là où il ne devait y en
avoir aucun.

Le `.validate` posé sur `group_calls/$callId/signaling/$fromId/$toId` exigeait
un enfant `type` **directement** sous `$toId`. Or l'app écrit
`$toId/offer = {type, sdp}` et `$toId/candidates/<clé>`. Toute écriture de
signalisation de groupe était donc refusée — offres, réponses et candidats ICE
compris. **Introduit par `81ba52c` le 2026-08-03 et déployé depuis** : trois
jours pendant lesquels aucun appel de groupe ne pouvait établir sa connexion.
Sans erreur visible, comme toujours ici.

Rien à voir avec le durcissement d'aujourd'hui : le défaut est dans les règles
permissives comme dans les strictes.

- [x] **Correctif déployé le 2026-08-06** — le `.validate` descend sur les
  enfants réels (`offer`, `answer`, en `['type', 'sdp']`), les candidats ICE
  n'ont plus de contrainte de forme au mauvais niveau.
  **Aucune précondition sur le parc installé** : ce correctif ne fait que lever
  une validation qui refusait des écritures légitimes. C'est pourquoi il a pu
  partir tout de suite, contrairement au durcissement.
  Diff par rapport à la production exacte, vérifié champ par champ : **3
  changements, pas un de plus** — le `.validate` déplacé, la garde `auth` sur
  `e2ee_key`, et l'index déjà en place. En ligne == dépôt après coup.
- [ ] **À vérifier sur appareil** : un appel de groupe à deux comptes doit
  maintenant se connecter. C'est la seule preuve qui manque — le banc prouve
  que les règles laissent passer, pas que la connexion WebRTC aboutit.

### 🔴 La clé E2EE des appels est lisible et remplaçable par n'importe qui

Mesuré le 2026-08-06 contre les règles déployées, après une lecture de code
que je ne voulais pas vendre comme un fait. Le résultat est pire que la lecture.

| | avant | après le correctif du jour |
|---|---|---|
| un **anonyme** pose la clé absente (groupe) | AUTORISÉ | refusé |
| un **tiers** connecté pose la clé absente | AUTORISÉ | autorisé |
| un **tiers** remplace la clé existante | AUTORISÉ | **autorisé** |
| un **tiers** lit la clé | AUTORISÉ | **autorisé** |
| un anonyme / tiers pose la clé d'un 1:1 | anon refusé, tiers AUTORISÉ | idem |

La garde `auth != null` manquait sur `e2ee_key/.write` : `!data.exists()`
suffisait à accorder l'écriture. Elle est ajoutée et déployée — le trou
anonyme est fermé.

- [ ] 🔴 **Mais l'essentiel reste ouvert** : un compte connecté quelconque peut
  toujours **lire et remplacer** la clé E2EE de n'importe quel appel dont il
  connaît l'identifiant. La cause n'est pas la règle `e2ee_key` mais son
  **parent** `group_calls/$callId` (et `calls/$callId`) à `auth != null` : dans
  RTDB une autorisation accordée plus haut cascade vers le bas, donc la règle
  fille plus stricte ne sert à rien tant que le parent est permissif.
  **C'est exactement ce que le durcissement ferme** — vérifié : contre les
  règles strictes, anonyme et tiers sont tenus à l'écart sur les deux.
  Donc le chiffrement de bout en bout des appels **n'en est pas un** tant que
  le durcissement n'est pas déployé.
- [x] ✅ **Règles strictes DÉPLOYÉES le 2026-08-06**, dans l'ordre imposé :
  1. **App rebâtie et réinstallée** sur le SM_A515F (`R58N91XBA7B`).
     ⚠️ **En debug, pas en release** : l'app présente était `DEBUGGABLE`, donc
     signée avec la clé de debug. Une APK release a une autre signature et ne
     s'installe pas par-dessus — il aurait fallu désinstaller, donc perdre la
     session, les brouillons et **les clés d'identité E2EE locales**. Refusé.
     L'APK release existe si besoin (`build/app/outputs/flutter-apk/`, 166,7 Mo)
     mais exige une désinstallation préalable.
     Preuve de l'installation : `lastUpdateTime` passé de 06:49:48 à 06:56:27.
  2. Banc rejoué contre la cible : « Parcours nominal : INTACT », étanchéité
     fermée sur le 1:1 **et** le groupe, clé E2EE hors de portée d'un anonyme
     comme d'un tiers.
  3. `firebase deploy --only database`, puis relecture des règles en ligne :
     **en ligne == dépôt == `database.rules.strict-cible.json`**.
- [ ] 🔴 **À VÉRIFIER EN PRIORITÉ, ET C'EST LA SEULE CHOSE QUI MANQUE** : un
  appel 1:1 et un appel de groupe, à deux comptes. Le banc prouve que les
  règles laissent passer le parcours réel ; il ne prouve pas qu'un appel
  aboutit (FCM, CallKit, coturn, WebRTC).
  **Si ça ne sonne plus**, retour arrière immédiat :
  ```
  cp database.rules.prod-avant-2026-08-06.json database.rules.json
  firebase deploy --only database
  ```
  (ça annule aussi l'index et le correctif de signalisation de groupe — dans
  l'urgence c'est sans importance, on redéploiera proprement ensuite.)
- [ ] **`e2ee_key` des appels de groupe est écrite mais JAMAIS LUE.** Une seule
  occurrence dans tout `lib/` (`group_call_service.dart`, `_shareE2EEKey`), et
  c'est l'écriture. Personne ne récupère la clé en rejoignant. Le chiffrement
  de bout en bout des appels de groupe n'est donc pas câblé — la clé est
  publiée dans le vide. Même motif que les champs d'état jamais alimentés déjà
  rencontrés sur ce projet. Sans effet sur le durcissement (durcir la lecture
  de quelque chose que personne ne lit ne casse rien), mais à traiter. Le dépôt porte volontairement la version
  stricte corrigée ; la production reste permissive. Deux préconditions, toutes
  deux liées au parc installé :
  - l'APK doit écrire `callerId`/`calleeId` (acquis depuis `135ae92`,
    2026-08-03) ;
  - l'APK doit s'inscrire avant d'écouter (acquis **aujourd'hui seulement**,
    donc **aucun** build existant ne l'a).
  **Donc : rebâtir et réinstaller l'app d'abord, déployer les règles ensuite.**
  Vérifier entre les deux que `node tools/rules_tests/signalisation_appels.mjs`
  affiche « Parcours nominal : INTACT ».
  Le fichier cible est versionné à part : **`database.rules.strict-cible.json`**.
  `database.rules.json` reste donc le reflet exact de ce qui est **déployé** —
  c'est le seul moyen de ne pas refabriquer la dérive qui a coûté la journée.
  Pour déployer le jour venu : remplacer l'un par l'autre, relancer le banc,
  puis `firebase deploy --only database`.
- [x] 🔴🔴 ~~**ANNULÉ LE JOUR MÊME : ce déploiement cassait tous les appels.**~~
  Le test de non-régression a finalement été fait — pas avec deux téléphones,
  mais **en émulateur RTDB**, ce qui suffit largement pour des règles.
  Verdict : sur la forme réelle du nœud, 5 vérifications sur 6 échouaient.
  **Cause racine, et elle est nette :** les règles durcies testaient
  `data.child('callerId').val() === auth.uid` **sur le nœud RTDB**, alors que
  `callerId`/`calleeId` n'existent **que dans Firestore**. Vérifié dans le
  code : `webrtc_service.dart` et `call_remote_datasource.dart` n'écrivent
  jamais ces champs dans RTDB — le nœud `calls/<id>` ne reçoit que des enfants
  de signalisation (`offer`, `answer`, `callerCandidates`, `calleeCandidates`,
  `videoUpgrade`, `renegotiate_*`, `ice_restart_*`, `heartbeat`, `e2ee_key`).
  Le prédicat était donc **toujours faux** :
  - `.read` → refusé pour tout le monde, l'appelé ne pouvait plus lire l'offre ;
  - `.write` → seule la toute première écriture passait (`!data.exists()`),
    tout le reste refusé.
  Autrement dit : **plus rien ne sonnait**, sans une seule erreur nulle part.
  Exactement le mode d'échec silencieux annoncé.
  **Retour arrière déployé et vérifié** : les règles en ligne sont revenues à
  `auth != null` sur `calls` et `group_calls`, l'index RTDB est conservé.
  Comparaison refaite — en ligne == dépôt == sauvegarde + index.
- [x] **Test pérennisé** : `tools/rules_tests/signalisation_appels.mjs` rejoue
  le parcours réel d'un appel (offre, candidats ICE des deux côtés, réponse,
  passage vidéo) contre l'émulateur. Bloc `emulators` ajouté à `firebase.json`
  (port 9102, le 9000 étant pris sur cette machine). **Toute modification des
  règles `calls` doit le faire passer avant d'être déployée.**
  Deux pièges déjà payés, notés dans l'en-tête du fichier : `?auth=owner` ne
  donne pas les droits admin sur l'émulateur (il faut l'en-tête
  `Authorization: Bearer owner`, sinon la mise en place échoue en silence et le
  banc mesure un arbre vide — huit faux échecs avant de s'en apercevoir) ; et
  un candidat ICE partiel est refusé par le `.validate`, pas par le droit
  d'accès — ne pas confondre les deux en lisant un 401.
- [ ] 🔴 **L'étanchéité de la signalisation reste donc OUVERTE.** Tout compte
  connecté peut lire et écrire la signalisation de n'importe quel appel dont il
  connaît l'identifiant. Le test le constate explicitement (deux lignes
  attendues « autorisé »), et **ces deux lignes échoueront le jour où ce sera
  fermé — c'est le signal voulu**.
  **Pour fermer sans casser** : il faut D'ABORD que l'app écrive `callerId` et
  `calleeId` dans le nœud RTDB au moment de créer l'appel. Tant que ce n'est
  pas fait, tout prédicat qui s'appuie dessus est toujours faux. L'ordre est :
  1) écrire les deux champs côté app, 2) déployer l'app, 3) attendre que le
  parc installé ait migré, 4) seulement ensuite durcir les règles.
- [ ] ~~**MAIS le test de non-régression des appels n'a PAS été fait avant
  le déploiement**~~ — il demande deux comptes sur deux téléphones. Le
  durcissement de la signalisation est donc **en production sans avoir jamais
  été exercé**, et son mode d'échec est silencieux : l'appelé ne voit jamais
  l'offre, aucune erreur, rien dans les journaux.
  **À faire en priorité, avant toute autre chose** : un appel 1:1 complet entre
  deux comptes — sonnerie, décroché, audio des deux côtés, passage en vidéo,
  raccrochage. Puis un appel de groupe.
  **Retour arrière si ça ne sonne plus** — les règles de production d'avant le
  déploiement sont conservées dans `database.rules.prod-avant-2026-08-06.json`
  (à la racine, versionné). C'est le **seul** enregistrement de cet état : le
  fichier du dépôt n'a jamais été ce qui tournait. Pour revenir :
  ```
  cp database.rules.prod-avant-2026-08-06.json database.rules.json
  firebase deploy --only database
  ```
  (ça annule aussi l'index, ce qui est sans importance dans l'urgence).
- [x] 🔴 **Deux fonctions tournaient en production sans source dans le dépôt —
  sources retrouvées et réintégrées** (`a7db115`).
  `sendMessagePush(europe-west1)` était dans `stash@{3}` (2026-07-20), jamais
  commitée nulle part ; `sendChatNotification(us-central1)` dans `1bb0cca^`,
  retirée du dépôt sans être supprimée côté Firebase — et désactivée
  (`return null` en tête) depuis avant son retrait.
  `firebase deploy --only functions --dry-run` ne signale plus d'orpheline :
  un déploiement global redevient possible.
- [ ] ⚠ **Réintégré ne veut pas dire vérifié.** Le code déployé n'est pas
  lisible : il peut différer de ces sources. Rien n'a été redéployé, et
  `sendMessagePush` reste **appelée par les APK déjà installés** — ne jamais
  accepter sa suppression ni utiliser `--force`.
- [ ] Le repliage de `handleNewMessagePush` dans `onMessageCreated` avait perdu
  le **contrôle de participation** (`callerUid`) : sans lui, le callable
  laisserait pousser une notification vers une conversation dont on ne fait pas
  partie. Réinjecté depuis le stash, mais **jamais exercé** — à tester si le
  callable redevient utilisé.

### 🔴 Le backend en production a dix-sept jours de retard

Relevé le 2026-08-05 en vérifiant si le garde-fou du webhook Stripe était
réellement en ligne. Dates de mise à jour lues par l'API Cloud Functions :

| fonction | déployée le |
|---|---|
| `stripeWebhook` | 2026-07-19 |
| `sendMessagePush` | 2026-07-19 |
| `sendChatNotification` | **2026-03-11** |
| `cleanupUserData` | 2026-08-05 (par ce lot) |

**Huit commits touchant `functions/` n'ont jamais atteint la production**, dont
plusieurs correctifs de fond :

- `ec07de4` — refus du secret Stripe laissé au placeholder. Le garde-fou est
  écrit et correct (500 explicite au lieu d'un 400 indistinguable d'une requête
  falsifiée), **mais il n'est pas en ligne** : la prod répond toujours 400 sur
  chaque webhook Stripe, donc aucun paiement n'est confirmé côté serveur ;
- `a82c6b5` — `dotenv` et `livekit-server-sdk` déclarés, ce qui réparait
  `onCallCreated` (la cause racine du « ça ne sonne pas ») ;
- `e94913f` — modules `partners/` restaurés ;
- `23fb3e4` — suppression d'un trigger Firestore mort ;
- `e9d5928` et `a7db115` — les deux correctifs de ce lot.

`sendChatNotification` déployée en **mars** explique aussi son hash de source
différent des autres : la version en ligne est antérieure à sa désactivation,
donc potentiellement encore active.

- [ ] Décider d'un déploiement global. Il est désormais possible (plus
  d'orpheline, `--dry-run` passe), mais il republierait `.env` tel quel —
  placeholder Stripe et secret coturn compromis compris. Corriger `.env`
  d'abord, cf. `docs/ops/secrets_production.md`.

### `FAILED_PRECONDITION` — index manquant sur les événements

`events where status == completed order by -startDate` échoue à chaque
démarrage : l'index composite n'existe pas.

- [x] **Corrigé le 2026-08-05.** L'index `status ASC + startDate DESC` a été
  créé, il est `READY`, et plus aucun `FAILED_PRECONDITION` au démarrage.
- [ ] ⚠ **Le fichier `firestore.indexes.json` est en retard sur la production
  — 47 entrées contre 71 déployées.** Même dérive que celle trouvée sur les
  règles. L'index a donc été créé **par l'API Firestore, pas par
  `firebase deploy --only firestore:indexes`** : déployer le fichier
  proposerait de supprimer 24 index en service. À resynchroniser depuis la
  prod avant tout déploiement d'index, comme on l'a fait pour les règles.
- [x] **Vérifié avec une vraie donnée le 2026-08-05** : un événement
  `status: "completed"` daté de trois jours plus tôt a été créé, puis la
  requête exacte qui échouait — `events where status == completed order by
  startDate desc` — a été rejouée côté serveur. Elle renvoie **1 résultat** au
  lieu du `FAILED_PRECONDITION`. Événement supprimé après coup.
- [ ] Le **rendu de la liste** dans l'écran Événements reste à voir au doigt :
  j'ai prouvé que la requête aboutit et que la donnée remonte, pas que l'onglet
  l'affiche.

---

## Passe pilotée du 2026-08-04 (15:25 → 16:05) — SM A515F, APK debug `54083d6`

Programme de test exécuté au pilotage `adb` (taps + `dumpsys` + logcat), thème
clair, `font_scale` 1.1, batterie sur secteur. **Aucune réinstallation** : l'APK
en place contenait déjà tout jusqu'à `54083d6`.

⚠️ **Une session concurrente tournait sur le même téléphone et le même dépôt.**
`lastUpdateTime` est passé de 15:18:51 → 15:25 → 15:41:59 (logcat :
`Killing … due to installPackageLI` en plein démarrage à froid), avec des
process Gradle/`dart`/`flutter_tester` actifs côté PC. **Tous les constats de la
première passe 0 ont été jetés** ; seuls figurent ci-dessous ceux obtenus après
15:47, fenêtre où plus rien n'installait. À retenir pour les prochaines fois :
vérifier `lastUpdateTime` **avant et après** chaque mesure.

### 🔴 Trouvé — sauvegarde des clés E2EE impossible, et ça bloque la génération

Reproduit à **3 démarrages à froid sur 3**, dans logcat :

```
KeyBackupService: backup presence unknown (FirebaseException):
[firebase_storage/unauthorized] User is not authorized to perform the desired action
```

Cause, vérifiée dans le dépôt : **`storage.rules` ne déclare aucune règle pour
`key_backups/`**. Le chemin `key_backups/{userId}/backup.enc` tombe donc dans le
`match /{allPaths=**} { allow read, write: if false; }` final — exactement le
même piège que celui déjà corrigé pour `/posts` et `/stories`.

Les cinq opérations de `key_backup_service.dart` sont concernées (`uploadBackup`,
`downloadBackup`, `checkBackupPresence`, `getBackupMetadata`, `deleteBackup`).

**La conséquence dépasse la sauvegarde.** Dans `e2ee_backup_coordinator.dart`,
`checkBackupPresence` renvoie `unknown` au lieu de `absent`, et le cas `unknown`
**saute délibérément la génération de clés** (pour ne pas écraser une identité
restaurable). Sur un appareil sans clés locales, aucune identité Signal n'est
donc jamais créée : la messagerie reste silencieusement sur le repli AES global,
et le bandeau de sauvegarde n'apparaît jamais. Le garde-fou est correct — c'est
la règle Storage manquante qui le déclenche à tort.

- [x] **Règle écrite le 2026-08-04** dans `storage.rules` :
      `match /key_backups/{userId}/{allPaths=**}`, lecture **et** écriture
      réservées à `isOwner(userId)` (contrairement aux médias chiffrés, un
      backup de clés ne doit pas être lisible par tout compte connecté : il est
      protégé par une passphrase, mais l'exposer offrirait le fichier à une
      attaque hors ligne). `create`/`update` séparés de `delete` car
      `request.resource` est nul sur une suppression — sans ça `deleteBackup()`
      serait refusé. Compilation vérifiée par l'émulateur Storage
      (`firebase emulators:exec --only storage`), avec témoin négatif : une
      règle volontairement cassée sort bien `token recognition error … :134`,
      le fichier réel n'en sort aucune.
- [x] **Déployé le 2026-08-04 à 16:07** (`firebase deploy --only storage`,
      projet `diaspo-niger`) : « rules file storage.rules compiled successfully »
      puis « released rules storage.rules to firebase.storage ».
- [x] **Vérifié sur appareil dans la foulée (16:08 → 16:11, SM A515F).** Plus
      aucun `unauthorized` au démarrage à froid, et **toute la chaîne E2EE s'est
      déroulée pour la première fois sur cet appareil** :

      ```
      KeyManagerService: Initializing keys for user vQZE49dT…
      SecureKeyStorage: Stored identity key pair
      SecureKeyStorage: Stored signed pre-key 954080014
      SecureKeyStorage: Stored 100 one-time pre-keys
      KeyManagerService: Published 100 one-time pre-keys
      KeyManagerService: Published keys to Supabase
      MessagingE2EEService: Initialized / key maintenance done
      ```

      Avant le correctif, la génération était sautée et rien de tout ceci
      n'apparaissait. Le repli AES global n'est donc plus la seule option.
- [x] **Le bandeau de sauvegarde s'affiche enfin** (« Sauvegardez vos clés de
      chiffrement… » / Pas maintenant · Sauvegarder), rendu correct en thème
      **nocturne**, sans débordement. Il n'avait jamais été atteignable.
- [x] `/settings/security/backup` s'ouvre et propose « Créer une sauvegarde »
      (générateur de passphrase, jauge de force, bouton inactif tant que la
      passphrase est faible) — donc la **lecture** du chemin `key_backups/`
      aboutit désormais.
- [x] **Branche écriture validée le 2026-08-04 à 18:21** — sauvegarde créée par
      Salim (la passphrase doit être consignée par un humain : une passphrase
      perdue laisse un futur appareil en `needsRestore` sans pouvoir restaurer,
      donc pire que pas de sauvegarde). L'écran affiche **« Sauvegarde active »**,
      « Créée le : 4/8/2026 à 18:21 », « Appareil : android Device », plus la
      section « Restaurer sur cet appareil ». `uploadBackup` **et** la lecture
      des métadonnées fonctionnent : la règle `key_backups/` est donc prouvée en
      **lecture et en écriture**, de bout en bout.
- [ ] Cosmétique relevé au passage : le libellé d'appareil est « android
      Device », peu lisible pour un utilisateur.
- [ ] Sur un **second appareil** : vérifier que la restauration fonctionne
      (`needsRestore` + saisie de la passphrase).
- [ ] Une fois déployé : sur un appareil sans clés locales, vérifier que les
      clés sont bien générées et que le bandeau « sauvegarder » apparaît.
- [ ] **Piste à confirmer** : ceci explique peut-être le point ouvert 20b
      (« CET APPAREIL » absent de la liste des appareils) — sans génération de
      clés après un vidage de données, aucun enregistrement E2EE n'a lieu.

### 🔴 Trouvé — Firebase App Check refuse l'attestation à chaque démarrage

À chaque démarrage à froid (3/3) :

```
⚠️ Erreur lors de la récupération du debug token: [firebase_app_check/unknown]
FirebaseException: Error returned from API. code: 403 body: App attestation failed.
```

- [ ] Sans conséquence visible tant qu'App Check n'est pas en *enforcement* —
      mais si un backend Firebase passe en enforcement, tous les appels de cet
      appareil seront rejetés. Vérifier l'état d'enforcement côté console, et
      enregistrer le jeton de debug pour les builds debug.

### ✅ Vérifié sur appareil pendant cette passe

- [x] **Démarrage à froid propre** : `/splash` → `/home`, **0 exception Flutter,
      0 `RenderFlex overflowed`** sur deux démarrages complets. Compter ~25 s
      entre le lancement et l'accueil (Supabase, Maps, App Check, GoRouter).
- [x] **Les 5 onglets de la barre basse** (Accueil, Carte, Groupes, Messages,
      Profil) : navigation correcte, **aucun débordement** à `font_scale` 1.1 en
      thème clair. Écran Messages conforme (chips Tous/Non lus/Groupes/Archives,
      sur-titres « CETTE SEMAINE » / « PLUS ANCIEN », tuile « Mes notes »).
- [x] **§9b — le clavier de recherche se lève au premier tap.** Cas décisif
      prouvé par `dumpsys input_method` : `mInputShown=false` avant le tap,
      `mInputShown=true` + `mIsInputViewShown=true` après **un seul** tap. C'est
      le correctif `27f52a3` vérifié en vrai.
- [x] **§9b non-régression visuelle** : en-tête replié (← + champ), bordure
      accent orange, loupe orange, halo, puces de filtre escamotées, curseur
      dans le champ. Rien d'anormal au repos.

### ⚠ À confirmer au doigt — intermittence du clavier de recherche

Sur 7 cycles ouverture/fermeture enchaînés par script (tap champ → `dumpsys` →
tap ←), le clavier est monté **5 fois sur 7**. Les deux échecs sont survenus
juste après une fermeture, donc probablement pendant l'animation de repli — mon
automatisation retape plus vite qu'un humain. **Ce n'est pas un bug établi.**

- [ ] Refaire une dizaine d'ouvertures/fermetures **au doigt**, à rythme normal :
      si le clavier monte à chaque fois, clore le point ; sinon, le §9b n'est
      qu'à moitié corrigé.

### ⚪ Fausses alertes — ne pas les rouvrir

- Le **liseré blanc au bord gauche**, visible à la même hauteur sur trois
  captures d'écrans différents, est la surcouche Samsung « Edge panel »
  (`com.samsung.android.app.cocktailbarservice`), **pas** un widget qui déborde.
- Une navigation spontanée vers `/profile` observée une fois n'est **pas**
  reproductible (0 navigation en 70 s puis en 30 s d'observation immobile) :
  c'était un tap extérieur sur le téléphone, pas l'app.

### À arbitrer

- [ ] Depuis l'onglet Messages, le **retour Android quitte l'app** au lieu de
      revenir sur Accueil. Comportement courant, mais à trancher.

### Deuxième tour (16:13 → 16:21) — passe nocturne, et un test avorté

- [x] **Balayage nocturne des 5 onglets** : **0 débordement, 0 exception** dans
      logcat, à `font_scale` 1.1. Écran Groupes correct (onglets pleins, carte de
      groupe, puces Niger / 1 / Autre).
- [x] **Carte en nocturne** : les tuiles adoptent bien le **style sombre**.
      ⚪ **Fausse alerte évitée** : capturée 8 s après l'ouverture, la zone de
      carte est un **aplat crème** sans aucune rue — ce n'est pas un jeton clair
      figé, ce sont les tuiles pas encore chargées (`ClientParamsBlocking` dans
      logcat). Laisser ~30 s avant de conclure quoi que ce soit sur la carte.
- [x] **En-tête du panneau de la carte non tronqué** : « 1 membre autour · 50 km »
      puis « 0 membre autour · 50 km » s'affichent en entier, avec la ligne de
      fraîcheur résolue. Le défaut cosmétique « Memb… » n'est pas reproduit.
- [x] **Position de repli = Niamey** quand la localisation n'est pas disponible
      (constaté avec la demande de permission à l'écran). Cohérent pour l'app.
- ⚠ **Demande de permission de localisation** rencontrée à l'écran : **laissée
      sans réponse volontairement**, accorder une permission système n'est pas
      une décision d'agent. À traiter par Salim.

**Conséquence bien réelle du bug `key_backups` — constatée dans « Mes notes ».**
Le message du 19 juil. s'affiche « 🔒 **Message chiffré** », avec le bandeau
« Restaurez vos clés de chiffrement pour lire vos messages chiffrés sur cet
appareil ». Les clés locales ont été perdues lors d'une réinstallation, et
**aucune sauvegarde n'existait** puisque la fonctionnalité était cassée : ce
message E2EE est donc définitivement illisible sur cet appareil. Les messages
partis en **repli AES** (« Note validee », « Verif citation 4a ») restent
lisibles, eux. C'est exactement le scénario que la sauvegarde doit empêcher —
raison de plus pour créer la sauvegarde maintenant que la règle est déployée.

- [ ] ⛔ **Brouillon restauré : test NON concluant, à refaire.** Deux tentatives
      avorties — mes taps sur le champ de saisie n'ont pas donné le focus
      (`mInputShown=false`), donc aucun texte n'a été saisi et il n'y avait aucun
      brouillon à restaurer. **Ce n'est pas un bug de l'app**, c'est un test raté.
      À refaire au doigt : taper du texte, bouton accueil, relancer, rouvrir la
      conversation, et vérifier que le bouton d'envoi est là **d'emblée**.

⚠️ **La session concurrente n'a pas cessé** : nouvelle réinstallation à 16:14:42
(`installPackageLI`), process de l'app redémarré à 16:18:42 puis 16:19:30, et une
navigation vers `/groups` que je n'ai pas déclenchée. **Les passes restantes
demandent l'appareil pour soi seul** — sinon chaque mesure est à jeter.

### Troisième tour (16:24 → 16:40), appareil enfin libre

**✅ Brouillon restauré — le cas décisif passe.** Prémisse établie par capture
(texte « BrouillonTest0804 » dans le champ, bouton d'envoi bleu à cadenas), puis
bouton accueil, `am force-stop`, relance à froid, réouverture de « Mes notes » :

- [x] Le brouillon est restauré **et le bouton d'envoi bleu est là d'emblée**,
      sans toucher au champ. Correctif `20042b7` vérifié en vrai.
- [x] **Envoi direct du brouillon restauré**, sans toucher le champ au
      préalable : le message part et s'affiche dans le fil de la conversation.
- [x] **Non-régression** : après envoi, le composer revient au **micro**
      (conversation sans brouillon).
- [ ] Reste le cas du brouillon de **plus de 2000 caractères** (état
      « dépassement » à restaurer) — tentative ratée, mon tap avait atterri sur
      le clavier. À refaire.

⚠ **Les deux échecs précédents n'étaient pas des bugs** : `mInputShown=false`
après le tap = le tap n'avait pas atteint le champ. Avec le clavier ouvert, le
composer remonte à ~1300 px et non ~2170 px — vérifier `mInputShown` avant de
conclure quoi que ce soit.

### 🔴 Trouvé — un lien vers une publication inexistante reste bloqué sur les squelettes

`am start -a VIEW -d https://diasponiger.web.app/feed/00000000-…-000000000999`
(app tuée au préalable). Le routage fonctionne — `/splash` puis redirection vers
`/feed/00000000-…`, donc la mise de côté du lien opère bien ici. Mais l'écran
d'arrivée ne dégrade pas proprement :

- des **squelettes de chargement permanents** à la place de la publication —
  toujours là à **105 s**, vérifié par deux captures espacées ;
- **aucun message d'erreur**, aucun « publication introuvable » ;
- pire, « Aucun commentaire pour le moment » s'affiche et **le champ de
  commentaire est actif** : on invite l'utilisateur à commenter une publication
  qui n'existe pas.

L'exception est pourtant bien levée et journalisée, puis avalée :
`PostgrestException(message: Cannot coerce the result to a single JSON object,
code: PGRST116)` — c'est le `.single()` sur un résultat vide.

**✅ Corrigé le 2026-08-04.** Trois couches touchées, car il y avait deux causes
enchaînées :

1. `feed_supabase_datasource.dart` traduit désormais `PostgrestException`
   PGRST116 en `NotFoundException` (avant, l'exception s'échappait de la couche
   data et, `_load` n'étant pas attendu, partait en erreur asynchrone non gérée
   — le `fold` n'était même jamais atteint) ;
2. `feed_repository_impl.dart` mappe `NotFoundException` → `NotFoundFailure`,
   avec un `catch` de dernier recours pour ne plus rien laisser s'échapper ;
3. `feed_provider.dart` remplace `PostEntity?` par un `PostDetailState`
   (`loading` / `loaded` / `notFound` / `failed`) — `null` ne peut plus vouloir
   dire deux choses.

L'écran affiche maintenant « Publication introuvable » (avec « Retour au fil »)
ou « Impossible d'afficher cette publication » (avec « Réessayer », qui n'a de
sens que sur une panne), et **le champ de commentaire est masqué** dans les deux
cas.

Couvert par `test/features/feed/post_detail_not_found_test.dart` (4 cas).
Le test du repository a été **vérifié rouge sans le correctif** (l'exception
traverse le repository), il n'est donc pas vide de sens. `flutter analyze`
propre, 17/17 sur `test/features/feed/`.

**✅ Vérifié sur appareil le 2026-08-04 à 17:50**, APK debug réinstallé
(`lastUpdateTime=17:48:20`) :

- [x] `am start -a VIEW -d …/feed/00000000-…-000000000999` sur app tuée →
      l'écran affiche **« Publication introuvable »**, « Elle a peut-être été
      supprimée par son auteur, ou le lien est incorrect. » et le bouton
      « Retour au fil ». **Plus aucun squelette, et plus de champ de
      commentaire.** Rendu correct en thème nocturne.
- [x] **Non-régression, une vraie publication** : le même chemin avec
      `d8888ee4-…` (« In kwana », id relevé via `supabase db query --linked`)
      charge la publication en entier — carte, barre d'engagement, commentaire
      « Cool », et le champ de commentaire bien présent. Aucune
      `PostgrestException`.
- [x] Le bouton fonctionne. ⚠ Il menait à `/home` alors qu'il dit « Retour au
      fil » : corrigé vers `/feed` **après** la vérification appareil, donc
      cette ligne-là n'est couverte que par `analyze` + les tests. Pas de
      seconde réinstallation pour si peu (chacune vide les données).
- [ ] Rejouer avec une publication **réellement supprimée** (pas seulement un id
      inventé) : c'est le cas que rencontrera un vrai utilisateur.

⚠️ **La réinstallation n'a PAS vidé les données cette fois** : session
conservée, ni `/consent` ni assistant de profil. Le piège documenté n'est donc
pas systématique — mais l'identité Signal générée dans la journée n'a toujours
**aucune sauvegarde**, et la passphrase reste à créer par Salim.

### ⚠ Empreinte mémoire à surveiller

`dumpsys meminfo` pendant la passe : **TOTAL PSS ≈ 1,0 Go** (Native Heap 100 Mo,
Dalvik 26 Mo), et le système tuait des process en arrière-plan au même moment
(`edgelighting`, `mobileservice`, `turbo:aab`). C'est un **build debug** avec
Impeller et la carte Google ouverte, donc non représentatif tel quel.

- [ ] Refaire la mesure sur un **build release**, carte fermée puis ouverte, pour
      savoir si le pic vient de la carte ou du mode debug.

### ✅ Feuille de partage fantôme — ne réapparaît plus (3 relances sur 3)

L'intent de tâche a d'abord été réarmé par un vrai lien profond
(`am start -a VIEW -d https://diasponiger.web.app/feed/…`), puis trois cycles
`am force-stop` + relance par le launcher :

- [x] **Aucune feuille de partage** aux trois relances, et **aucun rejeu du
      lien** : l'app arrive sur `/home` à chaque fois. C'est le cas décisif de la
      purge `reset()` + de l'empreinte persistée.
- [x] Les seules traces « share » dans le journal sont bénignes (« Encryption
      service initialized with shared key », et la route `/share` dans la liste).
- [ ] Reste à faire : un **vrai partage entrant** depuis Chrome ou Messages
      (image, vidéo, PDF, sélection multiple) — non testable en pilotage `adb`
      sans passer par le sélecteur système.

### ✅ Repli hors-ligne — le bug documenté NE se reproduit PAS (16:47, mode avion réel)

Mode avion activé par Salim. État vérifié avant de commencer :
`airplane_mode_on=1`, Wi-Fi désactivé, **`Active default network: none`**.
⚠ Un agent réseau **VPN reste « CONNECTED »** dans `dumpsys connectivity`, mais
il n'est plus le réseau par défaut — c'est probablement là toute la différence
avec la mesure précédente, où `connectivity_plus` voyait « connecté » et l'app
n'entrait donc jamais en mode hors-ligne. **Hypothèse, pas preuve.**

Aucun des trois symptômes décrits plus bas ne se reproduit :

- [x] **Splash de ~2 min → NON.** `/splash` à 16:47:46, `/home` à 16:47:57 :
      **11 secondes**.
- [x] **Squelettes infinis dans le fil → NON.** « Le fil » affiche le bandeau
      **« 🕐 Fil hors ligne · dernière mise à jour Il y a 1 heure(s) »** puis
      rend les **trois publications en cache** en entier. Le repli annoncé par la
      maquette 2a fonctionne donc.
- [x] **Retour au splash → NON.** Un seul `setting initial location` sur toute la
      session, pid inchangé : aucun redémarrage.
- [x] Liste des conversations hors ligne : servie par le cache, « Mes notes »
      affiche bien son dernier message.
- [x] **0 `RenderFlex overflowed`, 0 exception Flutter** hors ligne. (Attention
      au faux positif : un `Select-String "EXCEPTION"` insensible à la casse
      remonte 102 lignes qui sont toutes des `SocketException` /
      `AuthRetryableFetchException` — filtrer sur `RenderFlex` et
      `EXCEPTION CAUGHT` uniquement.)

**Le bug « repli hors-ligne » est donc à refermer**, sauf à le reproduire dans
les conditions exactes d'origine (VPN actif comme réseau par défaut).

### 🔴 Trouvé hors ligne — trois défauts distincts

- [ ] **Aucun indicateur « hors ligne » hors du fil.** L'accueil, la carte, les
      messages et le profil ne signalent rien : l'app a l'air normale alors que
      rien ne se charge. Seul « Le fil » a son bandeau. À uniformiser.
- [ ] **Le nom du correspondant retombe sur « Utilisateur »** dans la liste des
      conversations (« Salim L. » en ligne, « Utilisateur » + initiale « U »
      hors ligne). Le dernier message, lui, est bien en cache — c'est donc le
      profil du correspondant qui n'est pas mis en cache.
- [ ] **Boucle de rafraîchissement du jeton sans backoff.** Hors ligne,
      `SupabaseAuthBridge` rejoue le rafraîchissement **toutes les ~13 s**
      indéfiniment (16:47:53, 16:48:06, 16:48:19, 16:48:31…), chaque tour
      déclenchant plusieurs requêtes qui échouent en `Failed host lookup`.
      Coût batterie et bruit de journal. Prévoir un backoff, ou suspendre tant
      que `connectivity` annonce l'absence de réseau.
- [ ] « Autour de vous » (accueil) reste sur **4 avatars squelettes** hors ligne,
      sans état vide.

### Bilan du programme — ce qui reste, et pourquoi

- [ ] **Repli hors-ligne** (splash de ~2 min + squelettes infinis) — ⚠ **je ne
      peux pas le faire seul** : couper le réseau est une modification de réglage
      système. Bonne nouvelle, **le piège du VPN a disparu** : le réseau de l'app
      est `wlan0` avec la capacité `NOT_VPN`, donc un vrai état hors-ligne est
      atteignable, contrairement au 2026-07-28. **À faire par Salim** : activer
      le mode avion, puis me le dire — je démarre à froid et je chronomètre.
- [ ] **Admin, champ « Type * »** — ⚠ **inatteignable sur ce compte**. Le routeur
      conditionne `/admin/embassies/create` à `user.isAdmin`
      (`app_router.dart:193`), et aucune entrée « Administration » n'existe dans
      les Réglages. À reprendre avec un compte administrateur.
- [x] **Lien profond reçu app déjà lancée — RÉSOLU et vérifié le 2026-08-04 à
      22:45.** `singleTask` ne corrigeait que la moitié du problème.

      Instrumentation ajoutée pour trancher (et **conservée** : sans elle on ne
      peut pas distinguer « `onNewIntent` n'a pas été appelé » de « la route n'a
      pas été poussée », et le diagnostic repart de zéro — déjà perdu une fois).
      Elle a montré que `onNewIntent` **était bien appelé** avec la bonne URL,
      mais qu'aucune navigation GoRouter ne suivait : le
      `getNavigationChannel().pushRouteInformation(...)` de l'embedding
      n'aboutit pas dans ce montage, à cause du moteur mis en cache qu'impose
      `audio_service`.

      Correctif : la route passe désormais par un **canal explicite**
      (`diaspo_niger/deep_link`), reçu côté Dart au moment où le routeur est
      créé (`_bindNativeDeepLinks`), qui appelle `router.go()`. Journal complet
      vérifié sur appareil :

      ```
      DiaspoDeepLink: onNewIntent action=…VIEW data=…/feed/0d9abb43-…
      DiaspoDeepLink: route poussee vers Dart : /feed/0d9abb43-…
      flutter  : DeepLink: route reçue à chaud → /feed/0d9abb43-…
      GoRouter : going to /feed/0d9abb43-…
      ```

      Capture à l'appui : la bonne publication s'affiche, **sans repasser par le
      splash**.
- [ ] ⚠ **`am start` ne prouve pas le clic réel.** Android répond « Activity not
      started, its current task has been brought to the front » — le cas a bien
      été exercé, mais un vrai clic vient d'une autre app (Chrome, Messages)
      avec sa propre tâche. À refaire au doigt depuis Chrome pour être complet.
- [ ] Même chemin **déconnecté** : la route doit être mise de côté puis rejouée
      après connexion (étapes 0 et 10 du `redirect`) — non exercé.
- [x] **Brouillon long — vérifié le 2026-08-04 à 23:03.** Le champ est **plafonné
      à 2000** : impossible de dépasser en tapant, le compteur passe simplement
      en rouge « 2000 / 2000 » et le bouton d'envoi reste actif (correct à la
      limite exacte). Après bouton accueil + `am force-stop` + relance, le
      brouillon est restauré **avec son compteur rouge dès l'ouverture** : l'état
      dérivé est donc bien recalculé, pas seulement `_hasText`.

      ⚠ Le cas strict « **plus** de 2000 caractères → bouton d'envoi inactif »
      n'est **pas atteignable en tapant**. Il ne peut survenir que par un
      brouillon injecté (`controller.text = …` contourne `maxLength`), donc un
      brouillon enregistré quand la limite était plus haute. Pour le prouver il
      faudrait semer un brouillon > 2000 dans les préférences.
- [ ] 🧹 **Reste un brouillon de test de 2000 caractères dans « Mes notes »** :
      ma tentative de nettoyage par `input keycombination` n'a pas pris. À
      effacer à la main.

### ⚠ Partage entrant : non présenté par `am start` — à confirmer au doigt

`am start -a android.intent.action.SEND -t text/plain --es
android.intent.extra.TEXT … com.diasponiger.diasponiger` : l'app démarre bien
(l'intent est accepté, `pkg=com.diasponiger.diasponiger`) mais **atterrit sur
`/home`** — la feuille « Envoyer à… » ne s'ouvre pas.

Le tri côté Dart n'est pourtant pas en cause : un texte arrive en
`SharedMediaType.text` et n'est donc pas écarté par `_withoutDeepLinks`, et
l'empreinte persistée ne peut pas bloquer un contenu inédit.

**Je ne conclus pas à un bug.** Comme pour le lien profond, `am start` depuis le
shell n'est pas le chemin réel : un vrai partage vient d'une autre app, via le
sélecteur système, avec sa propre tâche. Trancher demanderait une troisième
passe d'instrumentation, et la réserve subsisterait.

- [ ] **À faire au doigt** : partager un texte depuis Chrome ou Messages, et
      vérifier que la feuille s'ouvre. Puis `am force-stop` + relance : elle ne
      doit PAS revenir (c'est le test de l'empreinte persistée).

### Deux pièges de pilotage `adb` à connaître

- `adb shell input text` **perd des morceaux** au-delà de quelques centaines de
  caractères : 2400 caractères envoyés en 8 fois n'en ont produit que 1561.
  Vérifier le compteur à l'écran plutôt que de supposer.
- Les arguments contenant des **espaces** sont découpés par le shell : un
  `--es … "Partage de test" com.diasponiger…` a donné `pkg=de`. Utiliser un
  texte sans espace, ou quoter côté appareil.
- [ ] **Sauvegarde E2EE en écriture** — à faire par Salim, avec la passphrase
      notée (cf. plus haut).

---

## Recherche messagerie — le clavier demandait deux taps (§9b, 2026-08-04)

Bug constaté sur appareil (SM A515F, build debug, nocturne, reproduit 3 fois) :
le premier tap sur le champ de recherche ouvrait bien l'en-tête replié (← +
champ à bordure accent) et le champ **gardait** le focus, mais le clavier ne se
levait pas. Un second tap le faisait apparaître, et tout marchait ensuite.

Cause : **pas le focus** — c'est la `TextInputConnection` qui se fermait.
`EditableTextState.dispose()` ferme la connexion sans défocaliser le `FocusNode`
externe, et `initState()` n'en rouvre aucune (seul un *changement* de focus le
fait). Dès que l'élément du champ était démonté puis réinflaté alors que le
nœud était déjà focalisé, le clavier tombait et rien ne le rappelait. Le 2e tap
marchait via `requestKeyboard()`, qui rouvre la connexion explicitement.

Deux endroits démontaient l'élément, corrigés tous les deux (commit `27f52a3`) :
le changement de type de widget dans `DesignSearchField` (`TextField` →
`DecoratedBox(child: TextField)` quand `active` bascule), et l'absence de clé
sur le bloc du champ dans la `Column` de `messages_screen.dart` — à l'ouverture
l'en-tête change de type et les puces de filtre disparaissent, donc le bloc
tombe dans la zone « milieu » de `updateChildren` où tout enfant sans clé est
démonté.

⚠ **Rien n'est prouvé hors appareil** : contrairement au cas « brouillon
restauré » ci-dessous, aucun test ne couvre ça — la remontée du clavier logiciel
n'est pas observable en test widget. `flutter analyze` propre, c'est tout.

- [ ] **Le cas décisif** : depuis la liste des messages, **un seul tap** sur le
      champ de recherche → le clavier doit monter immédiatement et **rester**.
- [ ] Enchaîner : saisir un terme sans re-toucher le champ, vérifier que le
      filtrage et les sections **Personnes** / **Conversations** répondent.
- [ ] Fermer par la flèche ←, puis rouvrir par un tap : le clavier doit remonter
      du premier coup **à chaque fois**, pas seulement la première.
- [ ] Non-régression visuelle (fiche 9b) : bordure accent, loupe orange et halo
      3 px toujours présents en recherche — et **aucune ombre** quand le champ
      est au repos (le `DecoratedBox` est désormais permanent).
- [ ] Refaire la passe en **clair et en nocturne** : le correctif touche
      `design_kit.dart`, donc tous les autres `DesignSearchField` du projet
      (boutique, groupes, carte) — vérifier qu'aucun n'a gagné d'ombre parasite.
- [ ] Boîte de réception **vide** : le champ n'est pas affiché dans cet état, la
      recherche n'y est donc pas ouvrable — confirmer que c'est bien voulu.

---

## Brouillon restauré — le composer restait sur le micro (2026-08-04)

Bug constaté sur appareil (SM A515F, build debug, conversation « Mes notes ») :
texte tapé sans envoyer, app quittée par le bouton accueil, puis relancée — le
brouillon est bien restauré dans le champ, **mais le bouton de droite affiche
le micro** au lieu du bouton d'envoi. Toucher le champ suffisait à le faire
réapparaître. Conséquence : on croit ne pas pouvoir envoyer son brouillon.

Cause : dans `message_input.dart`, `_loadDraft()` est appelé depuis `initState`
**avant** que le listener du contrôleur ne soit posé. L'écriture du brouillon
dans le contrôleur n'atteignait donc aucun listener, et `_hasText` restait à
`false` (comme `_isOverLimit` et le contrôleur de morphing). Corrigé en
recalculant l'état dérivé depuis `controller.text` au moment de l'injection,
sans animation à l'ouverture.

**Prouvé hors appareil** : cas ajouté à `message_input_composer_test.dart`
(brouillon semé dans `PreferencesService`, puis badge cadenas E2EE attendu sans
aucune frappe). Vérifié rouge sans le correctif, donc non vide de sens ;
14/14 au vert avec. Mais un test widget ne rejoue pas un vrai cycle de process.

- [ ] **Le cas décisif** : taper sans envoyer, **bouton accueil**, relancer
      l'app, rouvrir la conversation → le bouton d'envoi bleu doit être là
      **d'emblée**, sans toucher au champ.
- [ ] Envoyer directement ce brouillon restauré, sans toucher le champ au
      préalable : l'envoi doit aboutir.
- [ ] Le bouton doit être **présent immédiatement**, pas apparaître en fondu :
      le morphing est volontairement court-circuité à la restauration.
- [ ] Non-régression : une conversation **sans** brouillon doit toujours
      afficher le micro.
- [x] ~~Brouillon de **plus de 2000 caractères** : l'état « dépassement »~~ —
      **caduc depuis le 2026-08-04.** L'état `_isOverLimit` a été supprimé : le
      `maxLength: 2000` du `TextField` tronque la saisie *et* le collé, donc le
      dépassement était inatteignable. Il reste à vérifier au doigt qu'un
      brouillon exactement à 2000 caractères se restaure sans casse.
- [ ] ⚠ **Ne pas réinstaller entre les deux étapes** : `adb install -r` vide les
      données, donc les `SharedPreferences` — le brouillon disparaît et le test
      ne prouve rien. Relancer l'app déjà installée (`am start` / icône).

---

## Menus déroulants bornés partout (`isExpanded`, 2026-08-04)

Balayage des 16 menus restants, même cause que le champ « Type * » ci-dessous.
Un seul écran débordait réellement à l'échelle 1.0 ; le reste est du
durcissement, donc à regarder surtout **à `font_scale` 1.1 et plus**.

- [ ] **Ambassade → « Demande administrative »** : le champ « Type de demande »
  ne déborde plus. C'est le cas le plus visible (débordait de 234 px en test).
- [ ] **Boutique → « Vendre un produit »** : l'en-tête de carte « Paramètres de
  taxe » ne déborde plus, et les menus Devise / Catégorie / État / Pays sont
  lisibles.
- [ ] **Transferts → « Ajouter un bénéficiaire »** : choisir le type **compte
  bancaire** (les menus « banque » et « ville » n'existent que dans ce mode —
  aucun test ne les couvre), puis vérifier les trois menus.
- [ ] **Recherche d'employés d'une ambassade** : filtre « Département » —
  désormais monté par `test/features/embassies/employee_search_overflow_test.dart`,
  mais ce test ne prouve **pas** le correctif (vérifié par mutation : il passe
  aussi sans `isExpanded`, l'ellipse sur l'élément masquant le débordement).
  L'écran reste donc à regarder pour de vrai.
- [ ] Créer une entreprise, créer un podcast, fiche entreprise (feuille « Type
  de publication ») : vérifier qu'aucun libellé n'est tronqué à tort.

### Ellipse sur les éléments eux-mêmes (complément, 2026-08-04)

Durcissement récupéré d'une session parallèle : `maxLines: 1` + ellipse sur les
libellés des éléments, en plus d'`isExpanded` sur le champ. Le risque n'est plus
le débordement mais la **troncature abusive** — un « … » là où le libellé tenait.

- [ ] **Créer un podcast → « Langue » et « Fréquence de publication »** : les
  libellés traduits (haoussa, zarma) s'affichent en entier, pas en « … ».
- [ ] **Boutique → « Vendre un produit », menu « Pays »** : les deux listes
  (pays prioritaires **et** le reste, sous le séparateur) — le drapeau reste
  collé au nom et aucun nom de pays n'est coupé à l'échelle 1.0.
- [ ] Les mêmes à `font_scale` 1.1 : là, une ellipse est normale.

---

## Débordement du champ « Type * » — création d'ambassade (2026-08-04)

Corrigé à l'aveugle (pas d'appareil branché pendant la correction), couvert
par `test/features/admin/admin_create_embassy_overflow_test.dart`.

- [ ] **/admin/embassies/create, champ « Type * »** : plus de bandeau
  « RIGHT OVERFLOWED BY 54 PIXELS ». Vérifier aussi que le libellé
  « Ambassade » reste lisible et que la flèche du menu est à sa place.
- [ ] **Menu déroulant ouvert** : les quatre types (dont « Mission
  diplomatique », le plus long) s'affichent en entier, sans ellipse.
- [ ] **Même écran à `font_scale` 1.1** : les six en-têtes de section
  (« Localisation GPS (optionnel) » est le plus long) passent à la ligne au
  lieu de déborder.

---

## Passe nocturne + carte vérifiée sur appareil (2026-08-04, SM A515F)

Cinq fiches regardées d'affilée en thème sombre, build debug installé sur
l'appareil de référence.

- [x] **6a — Fil Nocturne** : fond `#161826`, point d'accent violet sur
  « Le fil », onglet actif en **contour** (pas en fond plein), cartes de post
  radius 8, et le **FAB creux à contour net** en bas à droite. Le rail
  « Ma story » ne déborde plus.
- [x] **11d — Mon profil Nocturne** : fond `#0F0D0A`, cartes `#1A1714` à
  liseré `#2A241E`, puce métier teintée vert sur fond vert sombre, point
  d'accent orange après le nom. ⚠ Le **badge « vérifié » n'a pas pu être
  vu** : le compte de test n'est pas vérifié. À reprendre avec un compte qui
  l'est.
- [x] **11e — Réglages Nocturne** : « Supprimer mon compte » en rouge clair
  `#F87171`, « Déconnexion » en ambre, liseré de la zone sensible net. Avant
  le correctif, ces trois-là étaient sur les jetons du thème clair, donc
  sombres sur `#0F0D0A`.
- [x] **7d — Carte, panneau à trois positions** : recherche fixe, bouton
  calques, chips, feuille draggable. **Un défaut trouvé et corrigé sur place**
  (voir ci-dessous).
- [x] **8c — Carte sans localisation** : carte à pastille `location_off`,
  trois garanties à coche verte, bouton « Activer » plein + « Réglages de
  confidentialité » en contour, le tout décliné en nocturne.

**Défaut trouvé pendant la passe** : l'en-tête du panneau de la carte
affichait « 0 membre a… » tronqué, avec du vide à sa droite. Le titre était
dans un `Flexible` et la rangée contenait un `Spacer()` — tous deux `flex: 1`,
donc l'espace libre était partagé en deux au lieu d'aller au titre. Titre et
rayon regroupés dans un `Expanded` ; vérifié réparé sur l'appareil.

**Fausse alerte notée pour mémoire** : la ligne de fraîcheur du panneau
affiche deux « Chargement… » tant que la position n'est pas acquise. Ce n'est
pas un champ mort — au bout des 15 s de `timeLimit`, en intérieur sans fix
GPS, l'écran bascule sur 8c. Ne pas rouvrir ce faux bug.

**Complément 7d, même session** : une fois la position obtenue (Montréal), le
panneau affiche « 1 membre autour · 50 km » en entier, la ligne de fraîcheur
se résout en « À l'instant / Il y a 49 s », et la ligne de membre s'affiche
avec son bouton 💬. En-tête, fraîcheur et ligne de membre sont donc vérifiés.

**Reste à vérifier sur ces fiches :**
- [ ] 8c — le panneau bas « Sans localisation, explorez par ville » **existe**
  (`_buildExploreByCityPanel`) mais **n'a pas pu être vu** : il n'y a
  aucune ambassade en base (`/embassies` affiche « Aucune ambassade
  disponible ») et le compte de test n'a aucun groupe. Le panneau s'escamote
  correctement au lieu d'afficher une coquille vide. À revérifier dès qu'une
  ambassade ou un groupe public existe avec une ville renseignée.
- [ ] 7d — cluster de pins et les trois crans de la feuille (18/45/92 %) non
  exercés : un seul membre autour, donc pas de cluster.
- [ ] 11d — badge « vérifié ».

---

## Feuille de partage fantôme au démarrage (2026-08-04)

Bug constaté sur appareil (SM A515F) : la feuille « Envoyer à… / Partagé
depuis une autre app », pastille « 1 texte », se rouvrait par-dessus l'accueil
à **chaque** démarrage à froid, sans qu'aucun partage n'ait été fait.

Cause : `receive_sharing_intent` traduit tout `ACTION_VIEW` sans type MIME en
élément `SharedMediaType.url`, et Android redonne à l'activité racine l'intent
d'origine de sa tâche à chaque relance. Une seule ouverture par lien profond
(`diasponiger://`, `diasponiger.web.app`) suffisait donc à faire revenir le
faux « 1 texte » indéfiniment. Corrigé en écartant les éléments `url` (l'app ne
déclare aucun filtre `ACTION_SEND`), en purgeant l'état natif via `reset()`, et
en attendant la réponse du canal natif avant de marquer le contenu consommé.

Rien de tout ça n'est vérifiable sans appareil :

- [ ] Ouvrir un lien profond (`https://diasponiger.web.app/feed/<id>`) pour
      réarmer l'intent de tâche, puis `am force-stop` + relance : **la feuille
      ne doit plus apparaître**. C'est le cas décisif.
- [ ] Répéter la relance 3 ou 4 fois de suite — le symptôme était systématique.
- [ ] Fermer la feuille sans envoyer puis relancer : le contenu ne doit pas
      revenir.

### Partage entrant activé le même jour

Les `intent-filter ACTION_SEND` / `SEND_MULTIPLE` ont été ajoutés au manifest
dans la foulée (text, image, video, `*/*`) : jusque-là l'app n'apparaissait pas
dans le sélecteur « Partager » et `ShareToConversationScreen` n'était
atteignable par aucun partage réel.

⚠️ **Ça remet le bug ci-dessus en jeu pour de vrai** : un partage devient
l'intent d'origine de la tâche, qu'Android redonne à chaque relance — et un
`text/plain` légitime n'est plus filtrable comme l'était le faux `url`. Deux
barrières ajoutées : `MainActivity.clearSharedIntent()` (neutralise
`activity.getIntent()`, couvre rotation et retour depuis les récents) et une
**empreinte SHA-256 persistée** du dernier partage présenté, seule protection
qui survive au redémarrage du process. Aucune des deux n'a tourné sur appareil.

- [ ] Partager un texte depuis Chrome ou Messages : Diaspo Niger doit
      apparaître dans le sélecteur, la feuille s'ouvrir, l'envoi aboutir.
- [ ] **Puis `am force-stop` + relance : la feuille ne doit PAS revenir.**
      C'est le cas décisif de l'empreinte persistée.
- [ ] Idem avec une image, une vidéo, un PDF, et une sélection multiple
      d'images (`SEND_MULTIPLE`).
- [ ] Partager pendant que l'app tourne déjà (flux temps réel, pas le contenu
      initial) — vérifier qu'une seule feuille s'ouvre, sans doublon.
- [ ] Tourner l'écran feuille ouverte, puis revenir depuis les récents : pas de
      seconde feuille.
- [ ] Limite assumée : partager **exactement** le même contenu deux fois de
      suite en tuant l'app entre les deux est ignoré la 2ᵉ fois. Vérifier que
      ça reste supportable en usage réel.
- [ ] `launchMode` est resté `singleTop` (le README du plugin conseille
      `singleTask`) : non changé pour ne pas perturber CallKit et
      `showWhenLocked`. Surveiller qu'un partage ne crée pas une **seconde
      instance** de MainActivity — le FlutterEngine est mis en cache par
      audio_service, deux activités branchées dessus poseraient problème.

### Liens profonds routés vers `/feed/:id` (2026-08-04)

Ouvrir un lien de publication lançait l'app sur l'accueil : rien ne consommait
l'URI. Deux causes, corrigées ensemble :

1. `flutter_deeplinking_enabled` n'était pas déclaré au manifest — Flutter
   ignorait l'URI et la route initiale restait « / ». Les liens générés par
   `DeepLinkService` sont déjà des chemins d'app (`/feed/<id>`), donc GoRouter
   sait les router tels quels une fois l'URI transmise.
2. Même transmise, la destination était **perdue** : au démarrage à froid
   l'authentification n'est pas résolue, le `redirect` renvoyait sur `/splash`
   puis `/home`. Elle est maintenant mise de côté (étape 0) et rejouée une fois
   l'utilisateur prêt (étape 10).

⚠️ **Le clic sur un lien n'ouvre l'app que si sa signature est déclarée.**
`assetlinks.json` couvre maintenant Play App Signing **et la clé release
locale** (`DD:A6:5C:…`), et il est **déployé** depuis le 2026-08-04 sur
`diasponiger.web.app` comme sur `diaspo-niger.web.app` — donc un APK release
installé à la main vérifie ses liens. La clé **debug** (`87:32:AD:…`) n'y est
pas : sur un build debug, Android ouvrira Chrome.

**Constaté le 2026-08-04** sur l'APK debug installé (signature `87:32:AD:…`) :
`pm verify-app-links --re-verify` **ne peut pas aboutir**, l'état reste `1024`
(échec) sur les deux domaines — le serveur ne déclare pas cette empreinte. Ce
n'est pas un problème de fichier ni de cache, c'est la signature.

Contournement retenu, **déjà appliqué sur le téléphone de test** : approuver
les domaines à la main, ce qui court-circuite la vérification serveur (le
`Selection state` passe à `Enabled`, `Verification link handling allowed:
true`). À refaire après chaque réinstallation :

```
adb shell pm set-app-links-user-selection --user 0 --package com.diasponiger.diasponiger true diasponiger.web.app
adb shell pm set-app-links-user-selection --user 0 --package com.diasponiger.diasponiger true diasponiger.com
adb shell pm get-app-links --user 0 com.diasponiger.diasponiger
```

À défaut, un intent explicite contourne aussi la résolution — mais il ne teste
alors plus le chemin réel d'un clic sur un lien :

```
adb shell am start -a android.intent.action.VIEW -d "https://diasponiger.web.app/feed/<postId>" com.diasponiger.diasponiger
```

**Vérifié sur appareil le 2026-08-04** (SM A515F, Android 13, APK debug de
14:25 contenant bien `flutter_deeplinking_enabled` — vérifié par
`aapt2 dump xmltree` sur l'APK tiré du téléphone) :

- [x] **App tuée** (`am force-stop`) puis **intent VIEW implicite** (aucun
      package précisé, donc résolution réelle par Android) sur
      `https://diasponiger.web.app/feed/0d9abb43-…` : l'app s'ouvre — pas
      Chrome — et affiche `PostDetailScreen` avec le bon post (« Test fuseau
      horaire - a ignorer »), zone de commentaires comprise. Capture à l'appui.
      Compter ~17 s entre l'intent et l'arrivée sur la publication.

      ⚠️ **Ce n'est PAS la mise de côté (étape 0/10) qui a opéré ici.** Les logs
      GoRouter disent `setting initial location /splash` : Flutter ne transmet
      pas l'URI comme route initiale sur ce chemin, elle arrive plus tard par le
      canal de navigation, quand l'authentification est déjà résolue —
      `redirecting to /feed/0d9abb43-…` sur `/feed/:postId`. La mise de côté
      reste un filet pour les cas où l'URI arriverait *pendant* le chargement
      (session déjà chaude, ou utilisateur déconnecté), non exercés ici.
- [x] **App en arrière-plan puis lien : ÉCHOUAIT — corrigé et VÉRIFIÉ sur
      appareil le 2026-08-04.** Trois liens vers trois publications
      différentes, envoyés app en arrière-plan : chacune s'est ouverte, sans
      repasser par le splash. Captures à l'appui.

      Symptôme initial : l'app revenait au premier plan sur l'écran qu'on venait
      de quitter, le lien perdu. **Il a fallu corriger deux choses**, la
      première masquant la seconde :

      1. `flutter_deeplinking_enabled` ne couvre que le **démarrage**. Le moteur
         mis en cache qu'impose `AudioServiceFragmentActivity` fait que
         l'embedding ne relaie pas les nouveaux intents au canal de navigation.
         → `MainActivity.onNewIntent()` pousse la route lui-même (chemin +
         requête + fragment).
      2. Ce hook n'était **jamais appelé** : avec `launchMode="singleTop"`,
         Android ramenait la tâche au premier plan en jetant l'intent. →
         `launchMode="singleTask"`.

      Deux pièges de diagnostic à retenir :

      - ⚠️ **Le warning `am start` ment.** « Activity not started, its current
        task has been brought to the front » s'affiche **même quand l'intent est
        bien délivré** à `onNewIntent` — il apparaît encore aujourd'hui, alors
        que le lien fonctionne. Ne pas conclure sur ce message.
      - ⚠️ **`pushRouteInformation` ne produit aucun log GoRouter**, contrairement
        aux redirections. L'absence de log ne prouve rien : seul l'écran fait
        foi. Pour trancher, instrumenter temporairement `onNewIntent` avec
        `android.util.Log` (retiré depuis — il exposait les URL consultées).

      ⚠️ **`singleTask` change le comportement de la pile pour toute l'app** :
      un nouvel intent efface les activités empilées au-dessus. Non testé avec
      un appel entrant CallKit (`INCOMING_CALL_AFFINITY` a sa propre tâche, donc
      a priori non concerné) — à surveiller au premier appel reçu.
- [ ] **Déconnecté** puis lien : doit passer par la connexion et **arriver sur
      la publication** une fois connecté.
- [x] Non-régression vérifiée le 2026-08-04 : lancement par le launcher
      (`monkey -c android.intent.category.LAUNCHER`) → l'app arrive bien sur
      l'accueil, aucun ancien lien n'est rejoué.
- [ ] Lien vers un post supprimé ou un id inexistant : vérifier que
      `PostDetailScreen` dégrade proprement au lieu de planter.
- [ ] Lien de profil `https://diasponiger.com/p/u/<uid>` : la route de
      redirection existe déjà, vérifier qu'elle mène bien au profil.
- [ ] Limite connue : le schéma `diasponiger://feed/<id>` **ne marchera pas**
      (Flutter ne lit que le chemin de l'URI, et « feed » y est l'hôte). Les
      liens partagés étant en `https://`, ça ne bloque rien — mais le raccourci
      `diasponiger://design-v2` du README de `design_v2` ne fonctionne pas non
      plus, pour la même raison.

**À faire hors appareil :**

- [x] ✅ **Hosting déployé le 2026-08-04**, après rapatriement — voir plus bas.
      Le blocage décrit ci-dessous est **levé**, il est conservé pour mémoire.
- [ ] ⛔ *(historique)* **`public/` était un vestige** : la production n'avait
      **jamais** été déployée depuis ce dépôt. Les 8 fichiers versionnés étaient
      plus pauvres que ceux en ligne (contenu comparé hors fins de ligne) :

      | Fichier | Dépôt | En ligne |
      |---|---|---|
      | `privacy-policy.html` | 3 917 car. | 32 342 |
      | `terms-of-service.html` | 14 263 | 43 082 |
      | `child-safety-standards.html` | 20 140 | 34 798 |
      | `delete-account.html` | 16 108 | 24 550 |
      | `index.html` | 14 319 | 36 483 |
      | `contact.html` | 6 072 | 18 658 |
      | `forgot-password.html` | 4 608 | 14 067 |
      | `.well-known/apple-app-site-association` | 158 | 508 |

      Un déploiement remplacerait la politique de confidentialité, les CGU, la
      page de suppression de compte et la page sécurité des enfants — toutes
      exigées par le Play Store — par des versions courtes et obsolètes, et
      amputerait l'AASA (Universal Links iOS). Le déploiement Firebase est
      atomique : impossible de n'envoyer que `assetlinks.json`.

      S'y ajoutaient **9 fichiers servis en production et totalement absents du
      dépôt** — toutes les versions anglaises (`*-en.html`) et le code de
      conduite (`code-of-conduct.html`, `code-of-conduct-en.html`) — ainsi que
      les 9 rewrites sans extension correspondants, absents de `firebase.json`.

      Résolu : les 21 fichiers réellement servis ont été récupérés depuis
      `diasponiger.web.app` (contenu identique sur les deux sites, vérifié
      fichier par fichier) et versionnés, `assetlinks.json` réappliqué
      par-dessus, rewrites complétés. Avant déploiement, `public/` ne s'écartait
      de la production que par ce seul fichier.
- [x] ✅ **`firebase.json` déclare désormais les deux sites publics.** Le projet
      en a trois (`firebase hosting:sites:list`) : `diaspo-niger`,
      `diaspo-niger-admin` et `diasponiger`. Seul le premier était déclaré,
      alors que les liens de l'app pointent sur **`diasponiger.web.app`**
      (`DEEP_LINK_BASE_URL` + App Links du manifest) — un déploiement n'aurait
      même pas touché le domaine concerné. Les deux sites publics ont maintenant
      leur bloc (config identique, même dossier `public`) ; `diaspo-niger-admin`
      reste délibérément hors périmètre.

      ⚠️ Une **cible multi-sites ne fonctionne pas** : `firebase target:apply
      hosting <cible> siteA siteB` est accepté, mais `deploy` et
      `hosting:channel:deploy` refusent ensuite avec « linked to multiple sites,
      but only one is permitted » (CLI 14.27). D'où la duplication du bloc — si
      l'un des deux est modifié, penser à l'autre.

      ⚠️ Les fins de ligne diffèrent d'un fichier à l'autre en production (CRLF
      dans `index.html`, LF dans les pages `-en`) et git a prévenu qu'il
      convertira en CRLF « la prochaine fois qu'il touchera » ces fichiers. Un
      futur `git checkout` changerait donc leur contenu octet à octet sans rien
      changer au rendu. Comparer avec la prod avant de redéployer.
- [ ] Après déploiement, **forcer la revérification** : Android ne contrôle les
      App Links qu'à l'installation, un fichier corrigé plus tard ne change rien
      pour une app déjà installée.

      ```
      adb shell pm verify-app-links --re-verify com.diasponiger.diasponiger
      adb shell pm get-app-links com.diasponiger.diasponiger
      ```

      La seconde commande doit afficher `verified` pour `diasponiger.web.app` et
      `diasponiger.com`.
- [x] Empreinte de la clé **release locale** (`DD:A6:5C:…`, cf.
      `gradlew signingReport`) ajoutée sous `com.diasponiger.diasponiger` —
      décision de Salim, pour tester les liens sur un APK release installé à la
      main sans passer par le Play Store. Élargit d'autant qui peut revendiquer
      le domaine : à retirer si la keystore venait à circuler.

---

## Storage — énumération des médias coupée (2026-08-04, DÉPLOYÉ)

`storage.rules` : `match /messages/{conversationId}/{allPaths=**}` passait
`allow read: if isAuthenticated()`. Or `read` couvre `get` ET `list` — connaître
un `conversationId` suffisait donc à énumérer puis télécharger tout le média de
la conversation, y compris pour un membre exclu d'un groupe. Séparé en
`allow get` / `allow list: if false`, **déployé sur `diaspo-niger`**.

Vérifié après déploiement : aucun plantage, aucune erreur Storage dans logcat,
la conversation et la liste s'affichent à l'identique.

- [ ] **Confirmer qu'un média s'affiche toujours.** Non vérifié : l'unique
      média du compte de test était déjà un rectangle noir *avant* le
      changement, donc la comparaison ne prouve rien. Envoyer une image dans
      une conversation et vérifier qu'elle s'affiche, en réception comme en
      envoi.
- [ ] Vérifier la galerie « Médias » d'une conversation (si elle liste des
      objets Storage plutôt que des lignes de base, elle casserait).

Rollback si besoin : remettre `allow read: if isAuthenticated();` dans
`storage.rules` puis `firebase deploy --only storage --project diaspo-niger`.

⚠️ Ce n'est PAS la restriction aux participants : les règles Storage ne savent
interroger que Firestore, or l'appartenance vit dans Supabase. Voir
CHIFFREMENT_MEDIAS_PLAN.md.

---

## Fuseau horaire — heures affichées en UTC (2026-08-04)

Bug constaté sur appareil (SM A515F, `America/Toronto` = UTC-4) : une
publication créée à 02:01 s'affichait « 06:01 ». Les dates étaient
désérialisées avec `DateTime.parse` sur des chaînes ISO terminées par `Z`,
donc en UTC, et `DateFormat` imprime les composantes telles quelles.

Corrigé en normalisant **à la désérialisation** (tout `DateTime` sortant d'un
modèle est local, cf. `lib/core/utils/date_parsing.dart`) et en réencodant
en UTC explicite à la sérialisation. 21 tests unitaires couvrent la
régression, mais rien de tout cela ne prouve le rendu réel : à vérifier sur
appareil, **hors du fuseau UTC**.

**Vérifié sur appareil le 2026-08-04** (SM A515F, `America/Toronto`, APK du
04:13 qui contient bien le correctif — symboles `parseLocalDate` /
`LocalDateTimeConverter` retrouvés dans `kernel_blob.bin`). Chaque affichage a
été comparé à la valeur réelle en base via `supabase db query --linked` :

- [x] **Discussion — le cas décisif.** Dernier message de la conversation
      « Salim L. » : base = `27/07 22:15:54` Toronto, soit **`28/07 02:15` UTC**.
      L'app affiche **22:15** sous le séparateur **« 27 juil. 2026 »**. Sans le
      correctif : `02:15` sous « 28 juil. » — mauvaise heure ET mauvais jour.
      C'est exactement le cas « message après 20:00 » qui basculait au lendemain.
- [x] Discussion — message précédent : base `26/07 12:06` Toronto (`16:06` UTC),
      app « 26 juil. 2026 » · **12:06**.
- [x] Liste des conversations : « 27 juil. » et non « 28 juil. ».
- [x] Mes publications : base `04/08 06:01:04` UTC = `02:01:04` Toronto, app
      **« Aujourd'hui · 02:01 »**. (Écran déjà corrigé avant : vaut comme
      non-régression, pas comme preuve du correctif.)
- [ ] Commentaires, notifications, événements (début/fin), appels (journal),
      stories : mêmes vérifications — pas de données sur le compte de test.
- [x] **Aller-retour serveur.** Publication « Test fuseau horaire - a ignorer »
      créée à `04:36:36` heure appareil ; stockée `08:36:36` **UTC** en base
      (= `04:36:36` Toronto). Après `am force-stop` et démarrage à froid, l'app
      relit depuis le serveur et affiche **« Aujourd'hui · 04:36 »**. Avec le
      bug : 08:36. La publication de test reste en ligne volontairement
      (décision de Salim), comme la précédente sur ce compte.
- [x] **Cache hors-ligne — le contenu est correct.** Le fichier
      `app_flutter/feed_cache.hive` a été extrait de l'appareil (`adb run-as`)
      et inspecté : chaque horodatage porte le suffixe `Z` et correspond
      exactement à la base — `2026-08-04T08:36:36.212535Z` (= 04:36 Toronto),
      `2026-08-04T06:01:04.327625Z` (= 02:01), `2026-05-26T19:08:23.377349Z`
      (= 15:08). Avant le correctif, `toIso8601String()` nu y aurait écrit
      `2026-08-04T04:36:36.212535`, sans fuseau. L'aller-retour est donc sûr.
      À noter : seul le **fil** consomme réellement le cache — les autres
      `CacheService.cacheXxx` ne sont branchées à aucun lecteur.

⚠️ **Bug distinct trouvé au passage — le repli hors-ligne ne fonctionne pas.**
Rien à voir avec le fuseau. En mode avion réel (vérifié : `airplane_mode=1`,
`wlan0` coupée) :

- le démarrage à froid reste **~2 min sur le splash** avant d'atteindre
  l'accueil ;
- l'écran « Le fil » affiche des **squelettes de chargement indéfiniment**
  au lieu des publications en cache, alors que le cache est bien présent et
  valide ;
- l'app finit par revenir au splash (redémarrage).

Le repli annoncé (maquette 2a : « si une page est en cache, on l'affiche
plutôt qu'un fil vide ») ne se déclenchait donc pas.

**Corrigé le 2026-08-04, couvert par 6 tests unitaires.** Cause commune aux
deux symptômes : des attentes réseau **sans borne**. Un socket qui *pend* au
lieu d'échouer ne rend jamais la main, donc le chemin de repli n'était jamais
atteint.

- Fil (`feed_provider`) : cache affiché **avant** d'interroger le réseau, plus
  10 s de borne sur la page (`loadInitial`/`loadMore`) et 5 s sur les
  enrichissements — cf. `test/features/feed/feed_offline_fallback_test.dart`.
- Démarrage (`auth_provider`) : 8 s de borne sur `getCurrentUser()`, puis
  démarrage sur la session Firebase locale plutôt qu'un renvoi vers
  `/auth/login` (se reconnecter exige le réseau, précisément ce qui manque)
  — cf. `test/features/auth/auth_offline_start_test.dart`.

⚠️ **Vérifié en test unitaire uniquement — jamais sur appareil.** Décision
prise avec Salim le 2026-08-04 : l'essai réel imposerait de reconstruire
l'APK, ce qui vide les données du téléphone (re-onboarding, session Firebase
perdue, reconnexion par SSO Google). À refaire le jour où une réinstallation
est de toute façon nécessaire :

- [ ] mode avion + démarrage à froid : l'accueil s'affiche en quelques
      secondes, plus en ~2 min
- [ ] mode avion + « Le fil » : les publications en cache s'affichent, avec le
      bandeau « contenu hors ligne », au lieu des squelettes
- [ ] retour du réseau : le contenu frais remplace le cache sans action
- [ ] réseau lent mais fonctionnel : vérifier que les bornes (8 s / 10 s) ne
      dégradent pas un chargement légitime

Sans objet : le fil principal (`post_card`) affiche un temps **relatif** via
`timeago`, calculé sur l'epoch — il n'a jamais été affecté, et rien n'y est à
vérifier.

**Données déjà en base : audité le 2026-08-04, rien à reprendre.**
Les écritures antérieures partaient parfois sans suffixe de fuseau, et Postgres
les a enregistrées comme de l'UTC. Audit exécuté sur le projet
`zyrfkcjjrhddpfxcgezo` via `supabase db query --linked`, en comparant chaque
colonne écrite par le client à un `created_at` posé par le serveur :

| colonne | lignes fautives | total |
|---|---|---|
| `group_requests.processed_at` | **1** | 1 |
| les 11 autres colonnes auditées | 0 | — |

L'unique ligne fautive date du 2026-05-26, avec un écart de 3 h 15 —
signature d'un `processed_at` écrit 45 min après la création avec les
composantes locales de Toronto (UTC−4). Aucun horodatage dans le futur, donc
aucune trace d'écriture depuis un fuseau à l'est d'UTC.

Décision : **on ne répare pas**. Une seule ligne de test concernée, et le
décalage n'est enregistré nulle part — il n'existe pas de correction uniforme
applicable à des utilisateurs répartis sur plusieurs fuseaux.

---

## Fiches d'écrans (Claude Design) — reprise écran par écran (2026-08-04)

Reprise des écrans sur le document `Fiches d'écrans.dc.html` (17 fiches),
validées une par une avec Salim avant branchement.

- [ ] **20b — renommer un appareil** (`device_sync_service.dart`) : le
  renommage écrivait dans Firestore alors que la liste lit Supabase — il
  n'avait donc **aucun effet visible**. Câblé sur `e2ee_devices.device_name`.
  À vérifier : renommer un appareil, revenir, le nouveau nom persiste après
  un « tirer pour rafraîchir » **et** après relance de l'app. Vérifier aussi
  qu'un échec affiche bien une erreur (l'écran affichait « Appareil renommé »
  quoi qu'il arrive). ⚠ La migration `20260720120200` doit être appliquée au
  distant, sinon le repli garde la liste mais ignore le nom.
- [x] **20b — « CET APPAREIL » : RÉSOLU, vérifié le 2026-08-04 à 18:22.** La
  liste affiche maintenant **3 appareils sur 5**, et le courant porte bien la
  pastille verte « CET APPAREIL » avec son empreinte et le bouton « Renommer ».
  Le bandeau d'avertissement a disparu.

  ⚠ **La cause n'était pas celle qu'on croyait.** Ce n'étaient pas les
  `adb install -r` : c'était la règle Storage `key_backups/` manquante, qui
  faisait sauter la génération des clés (voir plus haut). Sans génération,
  aucun enregistrement E2EE n'avait lieu, donc aucun appareil courant. La
  règle déployée ce matin a débloqué la chaîne, et l'entrée de cet appareil a
  été créée dans la foulée — d'où le passage de 2 à 3 appareils.
**✅ Accumulation d'appareils corrigée le 2026-08-04.** L'identifiant était un
`Uuid().v4()` rangé dans le stockage sécurisé : perdu au moindre vidage de
données, donc chaque régénération de clés créait une **nouvelle** ligne dans
`e2ee_devices`. Il dérive désormais du **SSAID Android**, propre au triplet
(clé de signature, utilisateur, appareil) depuis Android 8 — il survit au
vidage de données et à une réinstallation signée de la même clé. Lu par une
méthode ajoutée au canal natif déjà existant, donc **sans nouvelle
dépendance**. Le SSAID n'est jamais transmis : on publie un condensé SHA-256
salé par l'identifiant de compte, de sorte que deux comptes sur le même
téléphone restent incomparables côté serveur. Couvert par
`test/core/services/stable_device_id_test.dart` (4 cas).

- [ ] **Pas vérifiable sur cet appareil sans repartir de zéro** : les clés
  locales existent, donc `initializeKeys` sort tôt et l'identifiant en place
  (aléatoire) est conservé — c'est voulu, aucune session n'est cassée. Pour
  prouver le correctif il faut un compte ou un appareil neuf : générer des
  clés, vider les données, régénérer, et vérifier qu'**aucune 4ᵉ ligne**
  n'apparaît.
- [ ] Les 3 entrées actuelles restent : à nettoyer à la main via « Révoquer ».

### 🔴 Le plafond de 5 appareils n'est appliqué nulle part

Vérifié sur la base distante (`pg_get_functiondef`) : `e2ee_add_active_device`
se contente d'un `ARRAY(SELECT DISTINCT unnest(active_devices || ARRAY[...]))`,
**sans aucun contrôle de nombre**. Et le seul test de plafond côté client vit
dans `DeviceSyncService.registerCurrentDevice`, qui **n'est pas sur le chemin
vivant** — la publication réelle passe par
`KeyManagerService._publishKeysToSupabase`, qui fait l'upsert et appelle la RPC
directement.

Donc « 3 appareils sur 5 » et « au-delà de 5, il faudra en révoquer un » sont
des promesses que le backend ne tient pas : la liste peut croître sans limite,
et chaque message destiné au compte doit être chiffré pour **chaque** entrée.

- [ ] **Décision en attente de Salim** : faire appliquer le plafond par la RPC
  (modifie une fonction déployée, donc production) et brancher le parcours
  « révoquer un appareil », ou retirer la promesse de l'interface.
- [ ] **20d — Réglages → Notifications** (`settings_screen.dart`,
  `notification_settings_screen.dart`) : la ligne « Notifications » de
  Réglages → Application ouvrait une feuille modale doublant l'écran ; elle
  pointe maintenant sur `/notifications/settings` et la modale est supprimée.
  À vérifier au doigt : le tap ouvre bien le nouvel écran (l'écran lui-même a
  été vu, mais pas ce chemin — build cassé par une session concurrente).
- [ ] **20d — sélecteur d'heures calmes** : le tap sur « De 22:00 à 08:00 »
  doit enchaîner deux sélecteurs (début puis fin) et n'enregistrer que si les
  deux sont confirmés. Jamais ouvert sur appareil.
- [ ] **20d — « Messages système » désactivable** : le verrou de la fiche a
  été abandonné (choix de Salim). L'interrupteur doit se couper et se
  rallumer normalement, et l'état doit survivre à une relance.

- [ ] **5a « Mon espace »** (`lib/features/feed/presentation/screens/mon_espace_screen.dart`) —
  refait sur la fiche : ligne d'identité `@poignée · Origine → Ville`, **trois**
  cases de stats (Publications / Abonnés / Abonnements) au lieu de deux, les
  cinq raccourcis regroupés dans **une seule carte** à filets au lieu de cinq
  cartes séparées, compteurs à droite de chaque ligne, pastilles d'icône
  34×34, et carte « Brouillons » réduite à une ligne avec chevron (les boutons
  Reprendre/Supprimer sont partis en 5b). À vérifier à l'œil : la trajectoire
  ville s'affiche bien quand `originCity`/`currentCity` sont renseignés, les
  compteurs ne restent pas bloqués sur « — », et le rendu en nocturne (rayons
  serrés) reste cohérent.
- [x] **Brouillons de publication multiples** (`preferences_service.dart`,
  `create_post_screen.dart`) — vérifié le 2026-08-04 sur SM A515F : rédiger un
  post puis « Annuler » écrit bien `flutter.post_drafts`, et la carte
  brouillon apparaît dans Mes publications après relance de l'app.
  ⚠ Le premier essai ne sauvegardait **rien** : `dispose()` appelait
  `ref.read(...)`, ce qui lève, et `main.dart` renvoyant `FlutterError.onError`
  vers Crashlytics, l'exception n'apparaissait **ni dans logcat ni à l'écran**.
  Corrigé en capturant le notifier à l'`initState` + autosave débounce 800 ms.
  Reste à vérifier à la main : 1) **deux** brouillons coexistent (le second
  n'écrase pas le premier) ; 2) « Reprendre » ouvre le bon texte ; 3) publier
  supprime le bon brouillon ; 4) la migration v1 → v2 sur une install qui
  possède un `post_draft` d'avant (⚠ `adb install -r` vide les données).
- [ ] **5b « Mes publications »** (`my_posts_screen.dart`, `my_post_card.dart`)
  — en-tête sur mesure + loupe (filtre local), onglets pleins
  « Publications · N » / « Repartages · N », carte de post compacte (méta,
  vignette 56×56, barre d'engagement, « Modifier », menu ⋯). **Jamais vue avec
  une vraie publication** : le compte de test en a zéro, seules la carte
  brouillon et l'état vide ont été rendus à l'écran. À revoir sur un compte
  qui publie : la ligne de méta (« Hier · 18:40 · Public »), la vignette
  média, le compteur de repartages qui disparaît à 0, et la recherche.
- [x] **5g « Votre première publication »** — vérifié le 2026-08-04 : cercle
  104, titre Caprasimo, deux amorces, bouton plein et FAB. Les deux amorces
  ouvrent l'éditeur pré-configuré (`?compose=photo|poll`) : **non testées**,
  la photo demande la permission galerie sur l'appareil.
- [x] **5c « Enregistrés »** (`saved_posts_screen.dart`, `saved_post_card.dart`)
  — vérifié le 2026-08-04 avec un post enregistré : en-tête + compteur, chips,
  sur-titre « CETTE SEMAINE », carte courte avec Retirer / Partager.
  Restent à vérifier : les filtres **Photos** et **Vidéos** (le compte de test
  n'a qu'un post texte, donc la vignette 72×72 n'a jamais affiché d'image), la
  feuille **Partager**, et le glissement latéral pour retirer.
- [x] **5d « Mon réseau »** (`follows_screen.dart`, `feed_pill_tabs.dart`,
  `follow_button.dart`) — vérifié le 2026-08-04 : en-tête, onglets à compteur
  permanent, barre de recherche, ligne de contact et pastille « Suivi ».
  Restent à vérifier : la **recherche** (le compte n'a qu'un abonnement), les
  **lignes de hashtag** sous Abonnements (aucun hashtag suivi sur ce compte),
  et le basculement Suivre → Suivi au doigt.
- [x] **20a « Modifier le profil »** — vérifié le 2026-08-04 : ✕ enfin
  visible, pastille photo neutre, et « Qui peut voir mon numéro ? » affiche
  « Tout le monde » (elle n'affichait rien). Restent à vérifier : la carte
  du numéro **vérifié** (le compte de test n'a pas de numéro vérifié, donc
  ni le masquage « +33 6 12 •• •• 47 » ni « Vérifié par SMS » n'ont été vus),
  et le sélecteur de visibilité au doigt.
- ⚠ **Piège de build** : après une dizaine d'`adb install -r` d'affilée, un
  APK est sorti avec un **paquet d'assets corrompu** — toutes les icônes
  Material rendues en idéogrammes CJK, les SVG absents, et des écrans en
  erreur. Ce n'était **pas** une régression de code : le même build cassait
  aussi des écrans non modifiés. `flutter clean` + rebuild règle le
  problème. Vérifier sur un second écran avant d'accuser son propre
  changement.
- ⚠ **Publication de test à supprimer** : un post public « Publication de test
  pour verifier l affichage de Mes publications - a ignorer #DiasporaNiger » a
  été publié le 2026-08-04 depuis le compte `Sim A.` pour valider 5b/5c. Il
  est **toujours en ligne** et visible dans le fil de la diaspora.

## Doublons Profil / Réglages (2026-08-05)

- [ ] **« Actions du compte » a changé d'écran** (`profile_screen.dart`,
  `settings_screen.dart`) — Déconnexion et Supprimer mon compte sont passées du
  bas de Réglages au bas du Profil, à la place du bloc « Réglages ». À
  vérifier : la carte d'alerte s'affiche bien en bas du Profil (ambre / rouge,
  bordure), **Réglages se termine maintenant sur « Exporter mes données »**, et
  surtout que **la suppression de compte va au bout** — toute sa chaîne
  (confirmation finale, invite de mot de passe, réauthentification) a été
  déplacée avec elle. Ne pas tester la suppression sur le compte réel :
  s'arrêter à l'invite de mot de passe.
- [ ] **L'engrenage de l'en-tête du Profil reste le seul chemin vers Réglages**
  — les trois raccourcis (Confidentialité, Apparence, Aide) ont disparu.
  Vérifier qu'on atteint toujours chaque section en faisant défiler.

- [x] **Profil : un seul filet entre les lignes** (`profile_screen.dart`) —
  chaque séparation en affichait **trois** superposés : `DesignListCard` insère
  déjà un filet entre ses enfants (retrait 16) et l'écran lui passait en plus
  ses propres `_SettingsDivider` (retrait 72). Le défaut ne se voyait pas comme
  un bug mais comme un trait épais et flou. Vérifier à l'œil qu'il ne reste
  qu'un filet, aligné sur le texte, et que **Réglages n'a pas bougé d'un pixel**.
- [x] **Une bascule n'en écrase plus trois** (`settings_screen.dart`) —
  Réglages → couper **Ma localisation** seule → revenir → rouvrir Réglages :
  *Profil visible* et *Statut en ligne* doivent être restés dans leur état
  réel, pas remis à activé. C'est le scénario qui échouait.
- [x] **Le sous-titre du Profil suit** (`profile_screen.dart`) — couper
  *Profil visible* dans Réglages, revenir au Profil : « Confidentialité et
  sécurité » doit se mettre à jour **sans relancer l'app**.
- [x] **Les notifications se coupent vraiment** — réglages fins des
  notifications → couper l'interrupteur maître → vérifier en base que
  `public.users.notifications_enabled` est passé à `false`
  (`supabase db query --linked`). Avant, seul l'affichage local était coupé :
  le serveur continuait d'envoyer.
- [x] **« ZONE SENSIBLE » en couleur d'alerte** (`settings_screen.dart`) — le
  drapeau `isWarning` était passé mais ignoré, le libellé s'affichait à la
  couleur d'accent comme les trois autres sections. À vérifier en clair et en
  nocturne (le rouge doit rester lisible sur `#0F0D0A`).

---

**Vérifié sur SM A515F le 2026-08-05, en clair.** Les cinq points ci-dessus
sont passés, dont trois confirmés **en base** et pas seulement à l'écran :

| Colonne de `public.users` | Avant | Après « Ma localisation » coupée |
|---|---|---|
| `share_location` | true | **false** |
| `is_visible` | true | true |
| `show_online_status` | true | true |

C'est la preuve que cherchait le lot 4b : l'ancien code réécrivait les quatre
champs d'un coup. Couper l'interrupteur push a bien mis
`notifications_enabled` à `false` côté serveur, là où seule la préférence
locale changeait avant. **Les quatre valeurs ont été remises à leur état
d'origine après le test.**

L'ancrage des sections marche aussi : « Apparence et langue » ouvre Réglages
directement sur la section APPLICATION.

---

---

## Session du 2026-08-03 (soir) — SM A515F, refonte enfin lancée

**Première exécution de la refonte sur appareil.** Build `assembleDebug` en
90 s, installation et lancement sans incident, **zéro exception Flutter**
au démarrage (`E/flutter`, `EXCEPTION CAUGHT`, `RenderFlex overflowed` :
aucun).

**Vérifié sur l'écran d'accueil, en thème sombre :**

- [x] Le titrage serif rend correctement (« Bonjour, **Sim** »).
- [x] Le bandeau de complétude (§11f) s'affiche : barre terracotta, « 2/5 »,
      message contextuel et action « Ajouter ma ville ».
- [x] La carte « POUR COMMENCER » rend ses trois amorces avec leurs
      sous-titres — c'est la localisation ARB de cette session, en vrai.
- [x] Grille de services, barre de navigation basse, ligne de contexte.
- [x] Le thème sombre est lisible partout sur cet écran : aucun jeton clair
      figé n'est ressorti.

**Défaut trouvé et corrigé dans la foulée** — puce orpheline en tête de la
ligne de contexte (« · 0 membres · 0 groupes ») pendant la fenêtre où la
géolocalisation n'a pas encore résolu. La puce ne sert qu'à séparer du lieu ;
sans lieu, elle s'affichait seule. Corrigé dans `home_screen_widgets.dart`.
Une fois Montréal résolu, la ligne est correcte.

**Ni analyze ni relecture ne pouvaient trouver ça** : il fallait le premier
lancement d'un compte sans ville renseignée.

**Carte (§7d) — trois incidents à l'ouverture, deux traités**

- [x] `RenderFlex overflowed by 179 pixels on the right`
      (`map_screen.dart:3413`) : la rangée du volet des membres alignait deux
      libellés de temps relatif (« mis à jour il y a… ») côte à côte, sans
      possibilité de rétrécir. Les deux passent en `Flexible` + ellipse.
- [ ] `RenderFlex overflowed` en bas : **cause racine trouvée le 2026-08-03**,
      correctif non appliqué faute d'arbitrage.

      Le widget est enfin identifié — `Column` à `map_screen.dart:3379` —
      mais seulement après avoir soldé le débordement horizontal : Flutter
      n'imprime le détail que de la **première** erreur de rendu par frame.
      Tant que la ligne des horodatages débordait, celui-ci restait réduit à
      « Another exception was thrown ».

      Cette colonne est le contenu du `DraggableScrollableSheet`, replié à
      `initialChildSize: 0.18` — **18 % de la hauteur d'écran, trop court
      pour son propre en-tête**. Ce n'est pas un défaut de mise en page mais
      un dimensionnement : le volet replié ne peut pas contenir ce qu'on lui
      demande d'afficher.

      ✅ **Soldé le 2026-08-03 — plus aucun débordement sur la carte.**
      Trois changements, vérifiés ensemble sur le SM A515F : le tri passe de
      « Les plus proches » à « Proximité » (et cesse d'être en dur), le titre
      du volet prend `maxLines: 1` + ellipse, et `minChildSize` monte de 0.18
      à 0.38. Journal de lancement : **0 `overflowed`**.

      ⚠️ **Un défaut cosmétique subsiste** : le titre s'affiche « Memb… ».
      La rangée d'en-tête reste trop étroite pour lui — les trois contrôles
      de droite (« Aucun membre », « Liste », « Proximité ») occupent
      légitimement les deux tiers de la largeur. Ce n'est plus une erreur de
      rendu, juste une mise en page à revoir : **déplacer les contrôles sur
      une seconde ligne sous le titre** est la seule vraie solution, et c'est
      une restructuration, pas un réglage.

      Historique conservé ci-dessous, il documente deux impasses.

      🔴 **`minChildSize` relevé le 2026-08-03 : essayé, mesuré, annulé.**
      0.18 → 0.35 ramène le débordement de 146 px à 14 ; 0.38 le supprime
      complètement. Mais le volet, enfin assez haut pour montrer son en-tête,
      **révèle un défaut bien pire** : « Membres à proximité » s'affiche
      **une lettre par ligne**, en colonne le long du bord gauche.

      Le titre est écrasé à une largeur quasi nulle par ses voisins de
      rangée (« Aucun membre », « Liste », « Les plus proches »), qui
      prennent toute la place. C'est le même défaut que le débordement
      horizontal de 12 px encore ouvert — la rangée d'en-tête du volet
      distribue mal sa largeur.

      Le volet trop court **masquait** ce problème. Les deux ne peuvent donc
      pas être traités séparément : relever la hauteur sans corriger la
      répartition de largeur remplace un débordement invisible par un titre
      illisible. `map_screen.dart` est revenu à son état committé.

      ⚠️ **Correction de mon propre diagnostic** : j'avais écrit « mettre le
      titre en `Expanded` ». C'est faux — **il l'est déjà** (ligne 3401). Ne
      pas perdre de temps là-dessus.

      La cause est l'inverse : ce sont les trois contrôles de droite — puce
      « Aucun membre », bascule « Liste », tri « Les plus proches » — qui
      imposent leur largeur intrinsèque. L'`Expanded` ne reçoit que le reste,
      quasi nul, et le titre se replie caractère par caractère.

      **Ordre à respecter** :
      1. faire céder les contrôles de droite — le candidat le plus probable
         est « Les plus proches », le plus long : `Flexible` + ellipse, ou
         icône seule quand la place manque ;
      2. vérifier sur appareil que le titre tient sur une ligne ;
      3. **puis** relever `minChildSize` à 0.38 — valeur déjà mesurée, elle
         supprime le débordement vertical.

      ⚠️ **Deux corrections possibles, toutes deux des décisions de design :**
      relever `minChildSize` / `initialChildSize` (le volet couvre alors plus
      de carte), ou alléger l'en-tête du volet. À trancher avant d'agir.

      Piste écartée en cours de route : passer la ligne des horodatages sur
      deux lignes supprime bien le débordement horizontal, mais **aggrave le
      vertical de 23 px** (146 → 169). Un `Wrap` ne convient pas non plus —
      il donne une largeur non bornée à ses enfants, donc `Flexible` y est
      sans effet et le débordement se déplace à l'intérieur de l'enfant.
- [ ] ⛔ **`assets/map_styles/light.json` et `dark.json` n'existent pas.**
      Ni les fichiers, ni le dossier, ni la déclaration dans `pubspec.yaml` —
      seul l'appel `rootBundle.loadString` existe (`map_screen.dart:228-229`).
      La carte tourne donc **sans style**, en rendu Google Maps par défaut,
      alors que la maquette 8b montre explicitement un style nuit.
      L'échec est attrapé et journalisé, donc rien ne casse — mais la
      fonctionnalité est morte depuis toujours. Créer ces styles est une
      **décision de design** (quelles couleurs, quels POI masqués) : à ne pas
      inventer.

**Groupes (§9c/§9f) — un bug de pluriel français, trouvé par contradiction**

- [x] L'écran affichait trois valeurs incompatibles : sous-titre « 1 rejoint »,
      puce « Mes groupes · 0 », corps « Vous n'avez rejoint aucun groupe ».
      Une sonde temporaire a montré `joinedCount=0` de façon stable — donc
      c'était le **rendu** du pluriel qui mentait, pas la donnée.

      Cause : `=1{…}` dans l'ARB est compilé par `gen-l10n` en `one:`. Or en
      **français, la catégorie CLDR `one` couvre 0 et 1**. Toute clé dont la
      branche `=1` code le chiffre « 1 » en dur affiche donc « 1 … » quand le
      compte vaut zéro.

      7 clés étaient concernées ; toutes ont reçu un cas `=0` explicite.
      Vérifié sur appareil après correction : « 0 rejoint ».

      ⚠️ **Piège à retenir** : les pluriels en suffixe
      (`{count} message{…=1{} other{s}}`) ne sont **pas** touchés — en
      français zéro prend le singulier, « 0 message » est correct. Ne pas les
      « corriger ».

**Discussion (§3b/§4a) — le correctif visuel tient, mais l'E2EE ne dit rien**

- [x] Les séparateurs rendent en pastille plate avec filet plein, sans
      dégradé ni ombre : le correctif de `_buildThreadSeparator` est vérifié
      sur appareil (« 26 juil. 2026 », « lundi »).
- [x] En-tête, sous-barre « Médias / ÉCO », composer et accusés de lecture
      rendent sans incident.
- [ ] ⛔ **Cinq bulles affichent « 🔒 Message chiffré » sans explication.**
      Ce sont des messages que l'appareil n'a pas pu déchiffrer — très
      probablement parce que les réinstallations de cette session ont effacé
      les clés locales (comportement déjà connu de `adb install -r`).

      Le problème n'est donc pas la perte de clés, attendue en test, mais ce
      que la personne voit : **cinq fois le même libellé, aucune cause,
      aucune issue**. Or l'ARB contient déjà exactement le bon message —
      `e2eeRestoreNudgeMessage`, « Restaurez vos clés de chiffrement pour
      lire vos messages chiffrés sur cet appareil. »

      ✅ **Câblé le 2026-08-03.** `_buildE2eeRestoreBanner` affiche le
      bandeau dès qu'un message du fil porte le placeholder, avec l'action
      « Restaurer » vers `/settings/security/backup`. Les deux chaînes —
      `e2eeRestoreNudgeMessage` et `e2eeRestoreNudgeAction` — avaient été
      écrites ensemble et n'étaient branchées ni l'une ni l'autre.
      Vérifié sur appareil : le bandeau apparaît au-dessus des messages
      illisibles, et seulement dans les fils concernés.

      Reste à vérifier : que « Restaurer » mène bien à un parcours qui
      **restaure effectivement** les clés. Le bandeau ouvre l'écran de
      sauvegarde ; ce que cet écran sait faire n'a pas été exercé.

**Modifier le profil (§20a) — barre d'en-tête repliée**

- [x] La `SliverAppBar` était figée sur `AppColors.primary` : une fois
      repliée, elle virait au terracotta plein sur toute la largeur, seul
      écran de l'app à le faire, et le jeton ne suivait pas le thème. Elle
      prend maintenant `context.backgroundColor` + `surfaceTintColor`
      transparent. Vérifié replié : fond sombre, seul « Enregistrer » reste
      terracotta — c'est l'action principale, elle doit l'être.

**Sélecteur multi-choix des langues (§20a)** — écrit, **jamais lancé**

- [ ] Le téléphone s'est déconnecté avant que je puisse l'ouvrir. `flutter
      analyze` passe, mais rien n'a été vu. À vérifier :
  - la puce « +N langues » ouvre bien une feuille, et ne déplie plus la
    liste sur place ;
  - cocher/décocher met à jour le compteur « N sélectionné(s) » en tête de
    feuille **en direct** ;
  - **fermer la feuille sans « Terminer » ne modifie rien** — c'est le point
    le plus important, la sélection travaille sur une copie ;
  - « Terminer » reporte le choix sur les puces de la carte ;
  - quand les 7 langues sont choisies, la puce « +N » **disparaît** au lieu
    d'afficher « +0 langues » ;
  - à `font_scale = 1.1`, la feuille reste utilisable et le bouton
    « Terminer » atteignable (elle est en `isScrollControlled`).

**Reste à exercer sur cet appareil** : tous les autres écrans basculés
(profil, config profil, réglages, carte, notifications, recherche,
messagerie), le mode Éco en réception, le brouillon d'épisode, et
`font_scale = 1.1`.

---

## Session du 2026-08-03 — SM A515F, build de `118b61e`

Ce qui a été réellement exercé sur l'appareil, et ce que ça a révélé.

**Défauts trouvés, corrigés et vérifiés**

- **Aucun média ne pouvait être envoyé sur Storage** — `storage.rules` ne
  déclarait aucun bloc pour `stories/`, `posts/` ni `encrypted_media/` : les
  trois tombaient dans le `deny all` final. Donc **création de story
  impossible, média de publication impossible, pièce jointe E2EE impossible**,
  tous en `unauthorized`. Les trois blocs ont été ajoutés et déployés
  (`firebase deploy --only storage`), après quoi la story part et s'affiche.
- **Débordement de 6 px du rail de stories** à `font_scale = 1.1` (le libellé
  « Ajouter » était coupé) : hauteur figée à 96 px, désormais calculée depuis
  le `textScaler`.
- **Écran de connexion illisible quand le système est en thème sombre** — il
  n'y avait pas deux sources de vérité sur la luminosité, mais un fond figé.
  Le `Scaffold` prenait `AppColors.surfaceVariant` (crème, valeur claire
  codée en dur) pendant que les textes et les champs suivaient normalement le
  thème sombre : titre et libellés clairs posés sur un fond clair, donc
  invisibles. Même schéma sur 15 fichiers, 48 occurrences de jetons clairs
  (`textPrimary`, `textSecondary`, `textTertiary`, `background`,
  `surfaceVariant`, `border`) remplacées par les accesseurs de
  `adaptive_colors.dart`. `AuthButton` figeait en plus son fond sur blanc :
  fond et texte passent au thème par défaut. **Vérifié sur le SM A515F en
  mode nuit** : capture après correction, écran entièrement sombre,
  « Bienvenue », « Email » et le bouton Google tous lisibles.

**Défauts trouvés, non corrigés**

- **L'échec d'upload est totalement silencieux** : `_createPhotoStory`
  (`story_rail.dart`) n'attrape rien autour de `uploadImage`. La feuille se
  referme, aucun message, l'exception ne ressort que dans Crashlytics —
  l'utilisateur croit avoir publié.
- **Le compteur de vues d'une story ne bouge pas** : la feuille « qui a vu »
  liste bien la vue enregistrée, mais la pastille du viewer continue
  d'afficher « Aucune vue ». Deux sources qui ne concordent pas. Accessoirement
  la vue de l'auteur lui-même est comptée.
- **Le nom d'auteur vient de Firebase Auth, pas du profil** : story et écran
  d'accueil affichent « Sim A » (`user.displayName`) alors que le profil
  applicatif est « Salim L. ». Même inversion de priorité dans
  `profile_config_screen.dart:90` — relancer l'assistant renomme donc le profil
  avec la valeur Firebase Auth.
- **Les drapeaux d'onboarding ne survivent pas à une réinstallation** :
  `hasGivenConsent` / `profileConfigComplete` sont lus dans Firestore
  `users/{uid}`, où ils n'existent pas pour ce compte. Toute réinstallation
  (ou tout nouvel appareil) repasse donc par consentement **et** assistant de
  profil complet.
- **Accents manquants dans les coach marks** : « Appuyez ici pour acceder a
  votre profil et le completer ».
- L'écran d'introduction (`onboarding_intro_screen`) est en orange quel que
  soit le thème choisi à l'étape précédente de l'assistant.

**Interrompu** — la session Firebase du compte de test s'est invalidée en cours
de route (le routeur redirige vers `/auth/login`). Tout ce qui suit la partie
Stories n'a donc **pas** pu être exercé cette session : salons, podcasts,
messagerie, hors-ligne, écrans divers.

---

# 1. Refonte Fil & Discussion (28 tours + salons/podcasts)

## Priorité haute — gestes, minuteurs, permissions (le plus susceptible de casser)

- [x] **Viewer de stories** (`story_viewer_screen.dart`) : barre de progression segmentée, auto-avance 5s, tap gauche/droite (précédent/suivant), swipe vers le bas pour fermer, enchaînement automatique sur l'auteur suivant du rail. *(2026-08-03, SM A515F : l'image s'affiche, l'en-tête porte avatar / nom / « il y a moins d'une minute » / croix, le minuteur de 5 s tourne et ferme le viewer en fin de rail, et le glissement vers le bas ferme immédiatement. **Tap gauche/droite et enchaînement sur l'auteur suivant restent non vérifiés** : une seule story, un seul auteur — il faut un deuxième compte publiant une story.)*
- [x] **Création de story** (`story_rail.dart`) : permission caméra (première demande), permission galerie, upload, apparition dans le rail avec l'anneau correct. *(2026-08-03, SM A515F, bout en bout depuis la galerie : sélection → upload → la story apparaît dans le rail, l'avatar « + » cède la place à l'anneau accent, et le viewer la relit. **A d'abord échoué** en `unauthorized` : `storage.rules` n'avait pas de bloc `stories/`, corrigé et déployé (voir le bloc de session en tête de fichier). Aucune permission runtime n'est demandée pour la galerie — l'app passe par le photo picker système, qui n'en exige pas. **Le chemin caméra reste non testé** (permission caméra première demande).)*
- [x] **Rail de stories** : anneau dégradé (non vues) vs anneau gris (tout vu), avatar "+" quand pas de story active, défilement horizontal. *(2026-08-03, SM A515F : avatar « + » correct sans story, remplacé par l'anneau accent dès qu'une story est active. **L'anneau gris « tout vu » n'est toujours pas distinguable** — ma propre story ne bascule pas en gris après lecture, et il n'y a aucun autre auteur ; défilement horizontal multi-avatars idem. Un débordement de 6 px à `font_scale = 1.1` a été trouvé ici et corrigé.)*
- [ ] **Repli du rail au défilement** (`feed_screen.dart`/`story_rail.dart`, ajouté 2026-07-31) : `AnimatedCrossFade` déclenché à `scrollOffset > 24`, bascule vers la barre compacte (3 avatars superposés + « N récits aujourd'hui » + « Afficher »), tap sur « Afficher » qui scrolle en haut et redéplie. *(2026-08-03 : **non atteignable en l'état, faute de données** — le fil du compte de test ne contient qu'une seule publication sur les trois onglets, donc la liste ne défile pas et `scrollOffset` ne dépasse jamais 24. Il faut un fil d'au moins un écran et demi.)*
- [ ] **Story vidéo** (ajouté 2026-07-31) : sélection galerie (max 30s), upload + compression + génération de miniature, lecture avec `video_player` dans le viewer (autoplay, barre de progression synchronisée sur la position réelle au lieu du minuteur fixe 5s, passage automatique à la story suivante en fin de lecture). *(2026-08-03 : non testé, mais le blocage Storage qui l'aurait fait échouer — `stories/…/video_*.mp4` — est levé.)*
- [x] **« Qui a vu » ma story** (ajouté 2026-07-31) : le tap « N vues » (visible seulement pour l'auteur) met la lecture en pause, ouvre la feuille avec la liste (avatar/nom/heure + emoji de réaction le cas échéant), la reprise de lecture à la fermeture de la feuille. *(2026-08-03, SM A515F : la pastille est bien réservée à l'auteur, le tap met la lecture en pause — le viewer reste ouvert bien au-delà des 5 s — la feuille liste avatar / nom / heure, et la fermeture relance le minuteur, qui va au bout et ferme le viewer. **Deux réserves** : la pastille continue d'afficher « Aucune vue » alors que la feuille liste une vue, et la vue de l'auteur lui-même est comptée. L'emoji de réaction dans la liste n'est pas vérifiable en solo.)*
- [ ] **Réactions sur une story** (ajouté 2026-07-31) : barre de 6 emojis en bas du viewer (stories des autres uniquement), tap = pose la réaction, retaper le même emoji la retire (toggle), l'emoji actif doit rester visuellement mis en évidence. *(2026-08-03 : **non testable en solo par construction** — la barre n'est rendue que sur la story d'un autre auteur. Demande un deuxième compte.)*
- [ ] **Envoi groupé de médias en message** (`media_batch_preview_screen.dart`, ajouté 2026-07-31, §27d) : sélection multiple dans la galerie → pellicule de revue avec case à cocher par média, poids total qui se recalcule au décochage, bascule « qualité réduite » qui compresse réellement à l'envoi, CTA qui nomme le nombre. Le cas 1 seul média doit toujours passer par l'éditeur mono-fichier existant (non touché) — vérifier qu'aucune régression n'est apparue là.
- [ ] **Composer un sondage sur un post** (`create_post_screen.dart` → icône Sondage) : ouverture du sheet, saisie, publication du post d'abord puis création du sondage — vérifier que le sondage apparaît bien après coup sur le post publié.
- [ ] **Composer un lieu sur un post** : `LocationPickerModal` (permission localisation, recherche d'adresse, sélection sur carte), aperçu de la carte statique sur `post_card.dart`.
- [ ] **Vote sur un sondage de post** (`poll_card.dart` réutilisé) : sélection d'option, soumission, affichage des résultats après vote/expiration.
- [ ] **Panneau membres carte** (`map_screen.dart`) : `DraggableScrollableSheet` à 3 positions (18/45/92%), glisser pour changer de position.
- [ ] **Stepper de transfert d'argent** (`send_money_screen.dart`) : indicateur 1 ligne, montants rapides, changement de devise.
- [ ] **États d'échec détaillés d'un transfert** (`transaction_detail_screen.dart` + `transfer_failure_kind.dart`, ajouté 2026-08-03, maquette 3a) : **actuellement intestable**, et pas seulement faute d'appareil — aucun producteur ne remplit `failureReason` (les fonctions Cloud du dépôt ne l'écrivent pas, et MyNita n'existe que comme valeur d'enum côté client). Tous les échecs retombent donc sur le cas générique. À revérifier quand l'intégration du prestataire de paiement écrira un motif : vérifier que le classement tombe sur le bon cas, que la phrase sur l'état du débit est juste, et surtout que « Réessayer » n'apparaît **pas** sur un doublon évité ni sur un débit incertain.
- [ ] **Contrôles d'appel** (`call_screen.dart`, `group_call_screen.dart`) : 4 boutons nommés 64px, bouton raccrocher pleine largeur, grille 2×2 en appel de groupe.
- [ ] **"Proches de vous"** (`new_conversation_screen.dart`) : n'apparaît que si permission localisation déjà accordée — vérifier l'affichage et le calcul de distance.
- [ ] **Coloration hashtags en direct** (composer post + commentaire) : `HashtagHighlightingController`, surtout pendant la composition IME (clavier téléphone).
- [ ] **Glisser-pour-répondre** sur une bulle de message : seuil 52px, translation bornée à 90px.
- [ ] **Enregistrement vocal** : 3 états (en cours / annulation armée / verrouillé), gestes de glissement.
- [ ] **Enregistrement micro d'un épisode de podcast** (`record_episode_screen.dart`, ajouté 2026-08-03) : permission micro (première demande), chrono, niveau d'entrée qui bouge vraiment, pause/reprise (le chrono doit repartir au bon endroit), « Terminer » qui produit un fichier lisible avec la bonne durée, « Annuler » qui supprime le fichier partiel, et sortie de l'écran en cours d'enregistrement qui libère bien le micro. Le service `AudioRecordingService` est partagé avec les messages vocaux : vérifier qu'enchaîner les deux ne casse rien.
- [ ] **Bilan de reprise après coupure** (`reconnection_summary.dart` + `offline_sync_service.dart`, ajouté 2026-08-03, maquette 3b) : mettre des actions en file hors ligne, couper longtemps, puis rebrancher → une feuille doit s'ouvrir avec « Envoyé en priorité » (une ligne par action, avec son sort), l'avertissement rouge si des actions ont été abandonnées après 3 tentatives, et « Reçu pendant votre absence » (messages non lus + notifications). Vérifier aussi qu'elle **ne s'ouvre pas** quand rien n'était en attente, et qu'elle ne s'empile pas si deux synchros s'enchaînent. Réserve : les lignes n'affichent que le nom de la collection Firestore, la file d'attente ne stocke pas de libellé lisible.
- [ ] **Fil hors ligne et 4 échecs distingués** (`feed_provider.dart`, `feed_error_state.dart`, ajouté 2026-08-03, maquettes 2a/2b) : couper la donnée réellement (pas le VPN) après avoir chargé le fil une fois → les publications en cache doivent réapparaître avec le bandeau « Fil hors ligne · dernière mise à jour … », et non l'écran d'erreur. Vérifier aussi les 4 cas d'échec : pas de connexion (pas de bouton Réessayer, c'est voulu), panne serveur (compte à rebours 15 s qui relance tout seul), réseau lent, et publication non envoyée (carte en tête du fil avec Réessayer/Abandonner, le texte saisi doit être conservé). Les cas « panne serveur » et « réseau lent » dépendent de la classification par sous-chaîne du message d'erreur — à confronter aux vrais messages Supabase.
- [ ] **Bandeau de reconnexion salon audio** (`audio_room_screen.dart`, ajouté 2026-08-03) : couper la donnée en plein salon doit afficher le bandeau « Reconnexion en cours… » puis « Connexion audio perdue » avec le bouton Réessayer, et le bouton doit réellement redemander un jeton LiveKit et remettre le son. Non vérifiable sans deux appareils et une vraie coupure réseau.

## Priorité moyenne — layout & responsive

- [ ] **Rail de navigation tablette 86px** (`tablet_navigation_rail.dart`, seuil 700px) : bascule téléphone/tablette, badges non lus.
- [ ] **Filtres rapides événements** (Près de moi/En ligne/Gratuits) : calcul de distance réel avec ma position.
- [ ] **En-tête carte unifié** (`map_screen.dart`, §7d) : recherche + bouton calques sur une ligne, chips profession en dessous — zone à risque de chevauchement avec l'overlay Google Maps.
- [ ] **`font_scale` élevé** (accessibilité système) : plusieurs `SizedBox` à hauteur fixe ont déjà débordé par le passé (ex. `BOTTOM OVERFLOWED BY 4px` à `font_scale=1.1`) — revérifier sur les écrans récents (checklist pièces à joindre, puces sondage/lieu, carte "plus proche" ambassade). *(2026-08-03 : l'appareil de test est en permanence à `font_scale = 1.1`, donc **toutes** les captures de cette session sont déjà à cette échelle. Un nouveau débordement trouvé et corrigé : `BOTTOM OVERFLOWED BY 6.0 PIXELS` sur le rail de stories du fil. Deux zones à surveiller, vues serrées sans bandeau d'erreur : la 3ᵉ carte de l'écran de consentement, coupée en pleine phrase par le bouton « Continuer », et les pastilles de couleur de la dernière étape de l'assistant de profil, dont seule la moitié haute est visible. Les écrans nommés ci-dessus n'ont pas été atteints.)*
- [ ] **Cinq contrôles morts recâblés** (2026-08-03) : **⚙ Réglages** du pied de salon (les 3 interrupteurs doivent écrire pour de vrai dans Supabase et revenir en arrière si l'écriture échoue — à tester en coupant la donnée), **📊 Statistiques** du pied de salon, **+ Inviter** du panneau de modération (le participant choisi doit apparaître dans la rangée des co-hôtes), **🪙 Pourboire** du replay (destinataire = hôte du replay ; vérifier que la puce disparaît si le replay n'a pas d'hôte), et le **CTA de l'encart publicitaire** du fil (chaque encart doit mener à sa section). Vérifier aussi qu'un admin qui rejoint en mode fantôme ne fait **plus** grossir la rangée de modérateurs vue par l'hôte.
- [ ] **Mini-lecteur podcast enfin affiché** (`main_shell.dart` + `podcast_mini_player.dart`, 2026-08-03) : la classe existait mais n'était montée nulle part — une lecture lancée depuis un épisode devenait invisible dès qu'on quittait l'écran. Il apparaît maintenant au-dessus de la barre de navigation, en **sombre même en thème clair**. À vérifier : qu'il apparaît bien au lancement d'une lecture et disparaît au Stop, que le tap ouvre l'épisode en cours, que la barre de progression avance, et surtout **que le dernier élément des listes reste atteignable** (la réserve basse passe de 110 à 174 px quand il est présent). Vérifier aussi le rendu tablette (il est sous la colonne centrale, à droite du rail) et que la barre sombre ne détonne pas trop sur les écrans clairs — c'est le compromis assumé.
- [ ] **Lecteur d'épisode forcé en sombre** (`episode_detail_screen.dart`, 2026-08-03, maquettes 1e/4b) : l'écran est sombre **même en thème clair**. À vérifier en mode clair : fond, cartes, curseur de progression, pastilles de chapitres, chips de statistiques, bandeau « depuis un salon live » (violet éclairci pour rester lisible), et surtout que la feuille de minuterie et celle de signalement s'ouvrent bien en sombre au lieu de flasher en clair. Vérifier aussi les icônes de la barre de statut au retour vers un écran clair, et la palette orange (le lecteur reprend `orangeDarkTheme` si ce thème est choisi).
- [ ] **Nocturne (thème sombre)** : ombres conditionnées récemment sur `map_screen.dart`, `profile_view_screen.dart`, `group_detail_screen.dart`, `groups_screen.dart` — vérifier qu'elles sont bien invisibles/neutres en sombre, pas juste "sans erreur de compilation".
- [ ] **QR code partage profil** 196px (`share_profile_modal.dart`) : vérifier qu'il tient bien dans la carte sans débordement après l'agrandissement (était 160px).
- [ ] **Regroupement des ambassades par zone géographique** (`embassies_screen.dart`, ajouté 2026-07-31) : zones calculées depuis lat/lng (pas le nom de pays, jugé trop fragile) — vérifier que les zones sont cohérentes avec de vraies données (une ambassade au Maroc doit tomber en Afrique, pas en Europe par ex.), que « Près de vous » apparaît en tête si la position du profil est connue, et que le pliage/dépliage de chaque zone + sous-section pays fonctionne.

## Priorité basse — cosmétique, faible risque

- [ ] Badge panier boutique (nombre d'articles) + badge icône commandes (commandes vendeur en attente).
- [ ] Filtre pays fusionné dans la barre de recherche boutique (bouton compact drapeau).
- [ ] Checklist de pièces à joindre + délai indicatif (demande administrative).
- [ ] Carte "ambassade la plus proche" + badge "Fermé" sur la liste.
- [ ] **Drapeau par pays sur la liste des ambassades** (ajouté 2026-07-31) : correspondance normalisée (accents/casse ignorés) sur `ProfileOptions.countries` — vérifier le taux de correspondance réel sur les données de prod (repli silencieux si aucune correspondance, donc un drapeau manquant n'est pas un bug, juste à surveiller si ça arrive trop souvent).
- [ ] Bandeau conséquences du blocage (comptes bloqués).
- [ ] Écrans légaux fusionnés en onglets (CGU/confidentialité/code de conduite).
- [ ] Mon espace : carte Brouillons (sauvegarde/reprise/suppression), tuile Hashtags suivis + bouton Suivre/Suivi sur le bandeau de filtre hashtag du fil.
- [ ] Chip "groupes en commun" sur les cartes de demande d'ami.
- [ ] Filtre "Archives" unifié dans la liste des messages (4e puce).
- [ ] En-tête de discussion 58px, avatar 38px/rayon 13, cadenas E2EE.
- [ ] Écran de réglages dédié (`/settings`) accessible depuis les 3 entrées condensées du profil.
- [ ] **Bandeau hors-ligne sur le fil** (`feed_screen.dart` + `offline_banner.dart`, ajouté 2026-08-03) : couper la donnée réellement (pas le VPN — il masque la coupure, cf. sessions précédentes) et vérifier que le bandeau apparaît en haut du fil, que le compteur d'actions en attente s'affiche, et qu'il disparaît au retour du réseau.
- [ ] **Titre d'un salon programmé** (`schedule_room_screen.dart`, corrigé 2026-08-03) : le titre était figé à « Nouveau salon » pour tous les salons programmés. Vérifier que le champ titre apparaît, qu'il arrive pré-rempli quand on vient de « Ouvrir un salon » → « Plus tard », et que le salon créé porte bien ce nom dans l'onglet Programmés. Vérifier aussi que le bouton du bas affiche la date choisie et se met à jour quand on change de jour/heure.
- [ ] **Rappel local d'un salon programmé** (`schedule_room_screen.dart`, ajouté 2026-08-03) : l'interrupteur « Me le rappeler » doit réellement programmer une notification 15 min avant. À vérifier en programmant un salon à ~20 min et en laissant le téléphone. Écart assumé avec la maquette, qui dit « Prévenir mes abonnés » : notifier d'autres utilisateurs demanderait un push serveur qui n'existe pas, l'interrupteur ne rappelle donc que l'hôte.
- [ ] **Nouveau CTA de la liste des salons** (`audio_rooms_list_screen.dart`, 2026-08-03) : le FAB rond a été remplacé par une pilule large « Ouvrir un salon » + bouton 📅 sur la même ligne, en bas. Vérifier qu'ils ne recouvrent pas la dernière carte de la liste et qu'ils tiennent à `font_scale` élevé.
- [ ] **Durée du salon en direct** (`audio_room_screen.dart`, ajouté 2026-08-03) : l'en-tête doit afficher « N MIN · N auditeurs » et la durée doit avancer toute seule (rafraîchie toutes les 30 s) — à laisser tourner quelques minutes pour le confirmer.
- [ ] **États vides complétés le 2026-08-03 (2e lot)** : « aucun salon en direct » avec les deux cartes d'action (Ouvrir un salon / Patrimoine oral), « aucun abonnement » podcasts avec les 3 populaires et leurs boutons S'abonner (vérifier que le bouton s'abonne vraiment et devient une coche), puces catégories de « Mes produits » vide (elles doivent pré-cocher la catégorie sur l'écran de création via `?category=`), note séquestre sur « aucune commande », lien « Voir les N groupes suggérés », et « Créer « X » » de la recherche groupes (le nom saisi doit arriver pré-rempli via `?name=`). La recherche boutique respecte maintenant les filtres actifs : vérifier que « Chercher partout · N » apparaît bien quand des résultats existent hors filtre, et qu'il les révèle.
- [ ] **États vides ajoutés le 2026-08-03** : « rien dans ma région » sur l'onglet Groupes (profil renseigné + aucun groupe correspondant), recherche sans résultat (boutique et groupes — pistes + boutons), carte « zone vide » (`map_screen.dart`, boutons Dézoomer / Voir les ambassades). Le cas carte demande de se placer sur une zone réellement déserte ; le bouton « Dézoomer » doit recharger des marqueurs.
- [ ] **Thème sombre bibliothèque Héritage** (`heritage_library_screen.dart`, ajouté 2026-08-03) : couleurs codées en dur remplacées par les couleurs adaptatives — vérifier l'écran entier en nocturne (fond, cartes de catégorie, tuiles, feuille lecteur), c'était totalement clair avant.
- [ ] **Écran Statistiques d'un podcast** (`podcast_stats_screen.dart`, ajouté 2026-08-03, maquette 4a) : ouvert depuis « Mes podcasts » → menu → Statistiques. Vérifier sur un podcast ayant réellement plusieurs épisodes publiés que les totaux, la moyenne par épisode, le classement des plus écoutés et l'intervalle moyen de publication sont cohérents avec les données. Un podcast sans épisode publié doit afficher le message dédié, pas des zéros.
- [ ] **Métriques d'engagement podcast réellement alimentées** (`podcast_supabase_datasource.dart` + migration `20260803160000`, 2026-08-03) : avant, « J'aime », « Partages » et « Téléchargements » affichaient 0 en permanence — les colonnes n'existaient pas, le mapper ne les lisait pas, et rien ne les incrémentait. **Exige la migration poussée.** Vérifier qu'un partage puis un téléchargement d'épisode font bien monter les compteurs dans les statistiques du créateur, qu'un « j'aime » retiré redescend le compteur (recalcul, pas incrément — retaper plusieurs fois ne doit pas gonfler), et qu'un épisode publié apparaît avec une date dans « Rythme de publication ».
- [ ] **Écoutes après définition de la RPC** (migration `20260803160000`) : `increment_podcast_play` était appelée sans être définie nulle part dans le dépôt. Vérifier qu'écouter un épisode incrémente bien à la fois `play_count` de l'épisode et `total_play_count` du podcast.
- [ ] **Pickers « Lié à » de « Ouvrir un salon »** (`create_audio_room_screen.dart`, ajouté 2026-08-03) : les trois puces Événement / Groupe / Ambassade ouvrent bien leur feuille de sélection, le nom choisi remplace le libellé de la puce, et l'ID part avec la création du salon.

---

# 2. Reste du projet (hors refonte Fil & Discussion)

Extrait de l'historique git complet (235 commits) + des fichiers mémoire du
projet. Les commits antérieurs à mi-juillet 2026 ne documentent quasiment
jamais leur statut de test device — cette liste ne peut donc pas prétendre
remonter à l'origine du projet (déc. 2025), seulement à ce qui est
explicitement tracé.

## E2EE & chiffrement (priorité haute — sécurité)

- [ ] **Initialisation de `MessagingE2EEService`** (commit `91ef606`) : elle était appelée nulle part avant ce fix ; l'init démarre (100 puis 50 paires X25519 séquentielles) mais rien ne confirme qu'elle se termine en temps raisonnable sur device réel.
- [ ] **Garde `isE2EEInitialized` retirée avant l'envoi de texte** (commit `26aeb0d`) — jamais revérifié, le téléphone s'est déconnecté avant le test final.
- [ ] **`KeyBackupService.checkBackupPresence`** (commit `19b092c`) — logique de génération de clés à la connexion changée, pas de re-test device après coup.
- [ ] **Sauvegarde/restauration de clés E2EE bout-en-bout** — nécessite DEUX appareils sur le même build (le destinataire doit republier ses clés depuis SON device) ; seule la republication des clés propres a été validée jusqu'ici.
- [ ] **Self-chat « Mes notes » : policy RLS Supabase pour l'INSERT d'une conversation à un seul participant** — jamais testée au runtime.
- [ ] **Déchiffrement réel du bandeau épinglé** (messages) — seul le repli « 🔐 Message chiffré » a été vu à l'écran (clés E2EE perdues sur un build debug réinstallé), jamais le contenu déchiffré effectif.

## Appels WebRTC

- [ ] **⚠ ORDRE DE DÉPLOIEMENT — règles de signalisation** (`database.rules.json` + `call_remote_datasource.dart`, 2026-08-03) : les règles restreignent désormais `calls/$callId` aux deux participants, en lisant `callerId`/`calleeId` **écrits par l'app** à la création. Déployer les règles **avant** que la nouvelle version de l'app soit installée couperait les appels 1:1 de tout client existant (ses lectures seraient refusées, en silence). Ordre obligatoire : livrer l'app d'abord, laisser le parc se mettre à jour, **puis** `firebase deploy --only database`.

  **Mesuré le 2026-08-03, avant tout déploiement** — la contrainte est confirmée, pas théorique : `/calls` contenait **20 nœuds** écrits par des clients, donc les règles en ligne autorisent bien l'écriture aujourd'hui, et les resserrer casserait ces clients. En regard, `/admins`, `/superAdmins`, `/audioRooms` et `/group_calls` étaient **vides** : rien d'autre dans ce fichier n'est urgent (la faille d'escalade RTDB porte sur un nœud inexistant, et la modération fantôme attend de toute façon l'amorçage manuel). Le déploiement a donc été **volontairement reporté**.

  ⚠ Contrepartie assumée pendant l'attente : les règles actuellement en ligne laissent tout compte connecté lire et écrire la signalisation de n'importe quel appel dont il connaît l'identifiant. Plus la sortie de l'app tarde, plus cette fenêtre reste ouverte.
- [ ] **Appel 1:1 après restriction** (2026-08-03) : un appel complet entre deux comptes doit fonctionner à l'identique — sonnerie, décroché, audio des deux côtés, passage en vidéo, raccrochage. C'est le test de non-régression du changement de règles ; tout échec se manifestera par une signalisation muette (l'appelé ne voit jamais l'offre) plutôt que par une erreur explicite.
- [ ] **Étanchéité de la signalisation** (2026-08-03) : avec un **troisième** compte, vérifier qu'il ne peut ni lire ni écrire le nœud d'un appel auquel il ne participe pas. Se teste depuis la console Firebase (simulateur de règles) avec l'UID du tiers sur `calls/<id>` — doit refuser lecture et écriture.
- [ ] **Appel de groupe après restriction** (2026-08-03) : entrer dans un appel de groupe écrit d'abord `participants/<uid>` (autorisé pour soi-même) puis lit le reste — vérifier que rejoindre, voir les autres arriver et repartir, et l'audio de bout en bout fonctionnent toujours. La signalisation est maintenant limitée aux couples émetteur/destinataire dont on fait partie, et `hostId`/`status`/`mode` restent lisibles avant d'avoir rejoint.
- [ ] **Relais TURN coturn en production** — à valider par un vrai appel en 4G/5G **sans wifi** (cas NAT symétrique, celui que TURN est censé résoudre) ; vérifier aussi que `grep -ci allocation` augmente dans les logs coturn pendant l'appel. Jamais confirmé depuis la rotation de secret du 16/07.

## Messagerie (hors refonte Fil & Discussion)

- [ ] **En-tête hero de la liste des messages** (dégradé + puces de filtre, commit `65c1852`) — jamais vu à l'écran, l'APK était cassé (toolchain JDK 17) au moment du commit.
- [ ] **Accusé de réception « remis »** (`mark_messages_as_delivered`, commit `da21b24`) — bug capturé dans les logs d'un appareil réel puis corrigé côté SQL, jamais revalidé en conditions réelles depuis.
- [ ] **Statut en ligne (Firestore → Supabase)** (commit `b16dc88`) — bug de confidentialité corrigé (préférence `showOnlineStatus` ignorée), jamais vérifié à l'écran.

## Groupes & événements en conversation

- [ ] **Bulle `EventMessageCard` en conversation + différenciation groupe** (commit `267d7d3`) : visibilité « publier dans le fil » DM/groupe, badge Admin sur les bulles, « Vu par N » sur messages de groupe lus, boutons appel/vidéo de groupe dans l'app bar, auto-adhésion au groupe pays au chargement du profil — aucun sous-élément vérifié sur device.
- [x] **Alignement des bulles reçues dans une série de groupe — CORRIGÉ ET VÉRIFIÉ SUR APPAREIL** (`message_bubble.dart`, `conversation_screen.dart`, SM A515F, 2026-08-13). Deux défauts distincts trouvés sur le même chemin :
  1. Le padding gauche des messages reçus en groupe passait de 8 (avatar affiché sur le 1er message d'une série) à 16 (pas d'avatar sur les suivants) — saut de 28px, bulles non alignées verticalement dans une même série. Corrigé en réservant toujours la largeur de l'avatar (`SizedBox(width: 28)` en son absence) pour tout message reçu d'un groupe (`groupId` non nul).
  2. **Avatar dupliqué** — `conversation_screen.dart` enveloppait `MessageBubble` dans SA PROPRE colonne avatar (radius 12, gris, sans badge vérifié ni tap-profil) pour tout message de groupe reçu, en plus de l'avatar interne de `MessageBubble` (radius 14, coloré) : deux cercles « S » côte à côte sur chaque message montrant l'expéditeur. Les deux branches du ternaire `_isGroup && !isMe ? Row(...) : MessageBubble(...)` construisaient `MessageBubble` avec des paramètres strictement identiques — le wrapper était mort code redondant. Supprimé, un seul appel `MessageBubble(...)` désormais.

  Vérifié sur le groupe « teste » (messages réels de Salim L., série de 2 sur 18 juillet 2026) : un seul avatar par message, bulles alignées au même bord gauche que le message montre le nom/avatar ou non.

## Sécurité / Comptes connectés

- [ ] **⚠ E2EE, réactions, sondages, épinglage, patrimoine — débloqués côté base** (migration `20260803180000`, appliquée en production le 2026-08-03) : 34 policies supplémentaires, sur 17 tables absentes du dépôt, étaient restées sur l'ancienne identité. RLS y était **actif sans aucune policy saine** — donc refus total, sans recours. Le plus lourd est l'E2EE : `e2ee_devices`, `e2ee_user_keys`, `e2ee_one_time_prekeys` et `e2ee_sender_key_distributions` refusaient l'enregistrement d'appareil et la publication des clés. À vérifier en priorité sur deux appareils : qu'un **nouvel** appareil s'enregistre, publie ses clés, et qu'une conversation chiffrée s'établit des deux côtés. Puis : réagir à un post, reposter, aimer un commentaire, créer un sondage et voter, épingler un message en conversation, ouvrir la bibliothèque du patrimoine, enregistrer une préférence, mettre quelqu'un en sourdine.

  **RLS E2EE vérifié sur la base de production le 2026-08-03** (SM A515F branché, compte `vQZE49dT…`). En simulant la session applicative (`request.jwt.claims` + rôle `authenticated`), dans des transactions annulées : `firebase_uid()` résout bien vers le Firebase UID du compte ; la lecture de `e2ee_devices` et `e2ee_user_keys` fonctionne ; l'insertion d'une prékey **pour soi est acceptée**, et la même insertion **pour autrui est refusée** (`42501: new row violates row-level security policy`). Le correctif est donc concluant dans les deux sens — il autorise sans ouvrir.

- [x] **Republication des prékeys — CORRIGÉ ET VÉRIFIÉ SUR APPAREIL** (`key_manager_service.dart`, 2026-08-03, SM A515F) : `e2ee_one_time_prekeys` contenait **0 ligne** en production alors que l'appareil en avait 50 en local. `checkAndRefillOneTimePreKeys` ne comparait le seuil de 20 qu'au compteur **local** : un appareil dont la publication initiale avait échoué (RLS, session absente) ne republiait donc jamais. Le contrôle porte désormais aussi sur le compte serveur, avec `null` = « comptage impossible » pour ne pas republier sur une simple coupure réseau.

  Déroulé de la vérification, build installé sur l'appareil : premier démarrage → `KeyManagerService: 50 prékeys en local mais 0 publiées — republication`, puis **0 → 100 lignes** en base. Second démarrage → aucune republication, table **stable à 100** : idempotent, pas de régénération en boucle.

- [x] **Suppression des prékeys d'autrui — CORRIGÉ ET VÉRIFIÉ** (migration `20260803190000`, appliquée en production le 2026-08-03) : la policy `e2ee_one_time_prekeys: authenticated delete` avait pour condition littéralement `true`, sans clause de propriété, alors que l'INSERT de la même table était bien restreint au propriétaire. N'importe quel compte pouvait vider le vivier de n'importe qui — pas une panne, mais une dégradation silencieuse : les sessions suivantes s'établissent alors sans DH4 (cf. audit du repli X3DH), donc sans la protection du message initial, sur une cible choisie.

  Vérifié dans les trois sens, transactions annulées, production intacte à 100 prékeys : un **tiers** qui tente de purger le vivier supprime désormais **0 ligne** ; le **propriétaire** en supprime bien **100**, ce qui préserve la republication de `_publishOneTimePreKeysToSupabase` ; et la RPC `consume_one_time_prekey`, appelée par l'expéditeur sur les clés du destinataire, **fonctionne toujours** — elle est `SECURITY DEFINER` et contourne RLS, ce qui avait été vérifié avant d'écrire la migration, puisque c'était le seul usage légitime de suppression par un tiers.

  Les autres tables E2EE ont été revues au passage et sont correctement cloisonnées : `e2ee_devices` et `e2ee_user_keys` restreignent l'écriture au propriétaire, `e2ee_sender_key_distributions` au destinataire. Seules les lectures de clés publiques sont ouvertes, ce qui est le principe même d'un vivier de prékeys.

  **Repli X3DH audité le 2026-08-03 — ça dégrade, ça ne casse pas.** La chaîne a été vérifiée de bout en bout : la RPC `consume_one_time_prekey` existe bien en production et renvoie proprement `NULL` sur vivier vide (testé, transaction annulée) — donc pas d'exception qui ferait échouer tout `getPreKeyBundle` via son `catch … return null` ; le bundle accepte une prékey nulle (`oneTimePreKeyId`/`oneTimePreKeyPublic` optionnels) ; et `messaging_e2ee_service.dart:212` ne calcule DH4 que `if (bundle.hasOneTimePreKey)`. La session s'établit donc avec DH1+DH2+DH3, ce qui est le comportement standard de X3DH.

  Ce qu'on perd, et c'est réel : la prékey à usage unique est ce qui protège le **message initial** contre une compromission ultérieure de la signed pre-key. Sans elle, quelqu'un qui obtiendrait plus tard la clé privée signed pre-key pourrait recalculer le secret partagé des sessions ouvertes pendant cette période, et le message initial devient rejouable. Ce n'est donc pas une panne à traiter en urgence, mais un affaiblissement de la confidentialité persistante qui dure tant que le vivier reste vide.

  Correctif suggéré, non implémenté : faire comparer `checkAndRefillOneTimePreKeys` au compte **serveur** (ou publier inconditionnellement si le serveur est à zéro) plutôt qu'au seul compteur local — sinon le parc installé ne se rattrapera jamais.
- [ ] **Identité des policies RLS réparée** (migration `20260803170000`, 2026-08-03) : 48 policies comparaient `current_user_id()` (identifiant Supabase Auth) à des colonnes contenant des Firebase UID — mesuré en production, **0 correspondance sur 1247 comptes**. Tout ce qui est « à moi » était donc refusé en silence, les échecs étant avalés par des `catch { debugPrint }`. Après `supabase db push`, vérifier sur un compte réel que ces actions **fonctionnent enfin** : modifier son profil, s'abonner à un podcast, suivre quelqu'un, mettre un post en favori, publier une story et y réagir, ouvrir un ticket de support, signaler un contenu, consulter son historique de transactions. Vérifier aussi qu'un profil passé en privé redevient visible à son propriétaire.
- [ ] **Non-régression après la bascule d'identité** (même migration) : le risque miroir est d'ouvrir trop. Avec **deux** comptes, vérifier qu'on ne voit toujours pas les données de l'autre — ses favoris, ses tickets, ses transactions, son profil privé — et qu'on ne peut pas modifier son profil ni ses podcasts.
- [ ] **Appareils connectés (#10) migrés vers Supabase `e2ee_devices`** (commit `267d7d3`) — la liste « s'affiche enfin » côté code, jamais confirmé à l'écran.
- [ ] **Flux caméra/galerie/éditeur + permissions manifest** (`WRITE_EXTERNAL_STORAGE`/`READ_MEDIA_IMAGES`/`VIDEO`, réintroduites après une perte accidentelle, commit `9ea9b45`) — jamais revalidées par un flux caméra/galerie réel.

## Admin (back-office)

- [ ] **Migration des 18 écrans admin + `admin_app` vers `AdminColors`** — jamais vérifiée à l'écran ; en particulier la couleur bleu d'action (jamais orange) jamais confirmée visuellement.
- [ ] **Modérateur fantôme — Muet / Exclure / Bloquer** (`ghost_moderator_screen.dart`, ajouté 2026-08-03) : les trois boutons ouvrent une feuille de sélection de participant puis appliquent l'action. Trois choses ne peuvent être vérifiées que sur un salon réel avec deux comptes : que la feuille liste bien les participants visibles (les fantômes doivent en être exclus), que l'action passe réellement les règles RTDB (nécessite `/admins/<uid>: true` dans la Realtime Database — sinon échec silencieux côté règles), et que le SnackBar d'erreur remonte quand ça échoue.
- [ ] **Ouverture et fermeture de la session fantôme** (`ghost_moderator_screen.dart`, 2026-08-03) : l'écran appelle maintenant `joinAsGhostModerator()` à l'ouverture — auparavant il ne rejoignait jamais le salon, donc `isGhostMode` restait faux, les compteurs affichaient 0 et les trois actions ne trouvaient aucune cible. À vérifier sur un salon réel avec deux comptes : que les compteurs se remplissent, que l'admin **n'apparaît pas** dans la liste des participants côté hôte, que la durée s'incrémente (rafraîchie toutes les 30 s), et surtout qu'en quittant l'écran l'admin est bien retiré du salon (`leaveRoom` n'est appelé que si c'est cet écran qui a ouvert la session — un admin déjà présent dans le salon ne doit pas en être éjecté).
- [ ] **Point d'entrée de la vue fantôme** (`audio_rooms_list_screen.dart`, 2026-08-03) : icône œil barré sur chaque carte de salon, visible **uniquement** pour un compte admin. Vérifier qu'elle est absente pour un compte normal, et que le tap dessus n'ouvre pas le salon en même temps (elle est imbriquée dans le `GestureDetector` de la carte).
- [ ] **États d'échec de la vue fantôme** (`ghost_moderator_screen.dart`, 2026-08-03) : salon inexistant ou compte non autorisé doivent afficher l'écran d'erreur avec le motif, plus l'écran vide à zéro d'avant.
- [ ] **Garde d'accès à la vue fantôme** (`app_router.dart`, ajouté 2026-08-03) : ouvrir `/audio-rooms/<id>/ghost` avec un compte **non** admin doit rediriger vers le salon. Jamais testé avec deux comptes de rôles différents.
- [ ] **Promotion d'un admin propagée aux 3 backends** (`role_management_provider.dart`, ajouté 2026-08-03) : promouvoir un utilisateur depuis l'écran de gestion des rôles doit écrire Firestore **et** `users.is_admin`/`admin_role` dans Postgres **et** `/admins/<uid>` en RTDB. Nécessite la migration `20260803120000_admin_can_manage_admin_flags.sql` poussée, et l'amorçage manuel du premier admin en SQL. Le message d'erreur de désynchronisation n'a jamais été vu à l'écran.

## Salons audio — monétisation

- [ ] **Mention du code PIN conditionnelle** (`buy_ticket_bottom_sheet.dart`, 2026-08-03) : « Code PIN demandé pour confirmer » ne doit apparaître que sous Wave et Mynita, jamais sous Carte bancaire — elle était affichée en pied de feuille quel que soit le moyen choisi. Les lignes de paiement sont maintenant encadrées et cliquables en entier (l'ancien `RadioMenuButton` a été remplacé) : vérifier la zone de tap et le rond de sélection.
- [ ] **Prix dans la devise réelle du salon** (`buy_ticket_bottom_sheet.dart`, `send_tip_bottom_sheet.dart`, 2026-08-03) : le `€` était codé en dur. Un salon facturé en XOF doit afficher « FCFA » (symbole après le montant) partout : prix du billet, commission, part de l'hôte, montants de don, libellé du bouton.
- [ ] **Feuille de don — deux lignes de montant** (`send_tip_bottom_sheet.dart`, 2026-08-03) : « Vous envoyez » puis « <nom> reçoit … (85 %) » — la part annoncée est passée de 95 % à 85 %, le serveur prélevant 15 %. Le sous-titre du destinataire affiche désormais le titre du salon : vérifier l'ellipse sur un titre long.

### Chemin de paiement recâblé (2026-08-03) — à retester de bout en bout

Ce bloc n'est **pas** du cosmétique : l'app appelait deux Edge Functions qui
n'existent pas (`purchase-room-ticket`, `send-tip` au lieu de
`process-room-ticket`, `process-tip`), envoyait les montants dans la mauvaise
unité et relisait la commission dans le mauvais type. **Aucun achat ni
pourboire n'a jamais pu aboutir** — il n'y a donc aucun historique de
référence, tout est à vérifier pour la première fois.

- [ ] **Achat d'un billet, bout en bout** (`monetization_supabase_datasource.dart`, `process-room-ticket`) : sur un salon payant en EUR, l'achat doit créer un PaymentIntent Stripe du bon montant et une ligne `room_tickets` en `pending`. Vérifier que le montant débité correspond au prix affiché — l'ancien code aurait facturé **100 fois trop cher**.
- [ ] **Envoi d'un pourboire, bout en bout** (`process-tip`) : idem sur `tips`, avec `commission_amount` = 15 % en unité mineure, entier.
- [ ] **Le même en XOF** : c'est le cas qui casse. Le FCFA n'a pas de subdivision — un billet à 5 000 FCFA doit s'afficher « 5 000 FCFA » (et non « 50 FCFA ») et débiter 5 000 FCFA. Vérifier l'affichage **et** le montant Stripe.
- [ ] **Part de l'hôte / du destinataire** : les feuilles annonçaient 5 % de commission pour un prélèvement réel de 15 %. Confronter la ligne « commission » de la feuille au `commission_amount` réellement écrit en base.
- [ ] ⚠ **Les deux Edge Functions doivent être redéployées** avant ce test (`supabase functions deploy process-tip process-room-ticket`) : leur logique de montant a changé. Tester l'app contre les anciennes fonctions déployées donnerait un débit 100× trop faible.
- [ ] **Réglages salons audio chargés depuis le backend** (`audio_rooms_settings_model.dart`, nouveau) : `AppSettingsModel` n'avait aucun champ `audioRooms`, les réglages retombaient donc toujours sur leurs valeurs par défaut. Modifier un montant de pourboire proposé ou une borne min/max en back-office et vérifier que la feuille de don le reflète.
- [ ] **Bouton Stripe Connect des moyens de paiement** (`add_payment_account_screen.dart`, 2026-08-03) : pointait sur `/audio-rooms/monetization`, route inexistante qui ouvrait un salon vide nommé « monetization ». Doit maintenant ouvrir l'écran des revenus créateur.
- [ ] **Prix du billet dans la liste des salons** (`audio_rooms_list_screen.dart`, `_PricePill`, 2026-08-03) : la pastille ocre affichait `€` en dur alors que la feuille d'achat respectait déjà `ticketCurrency`. Sur un salon facturé en XOF, la liste et la feuille doivent maintenant annoncer le même montant dans la même devise (« FCFA » après le montant).
- [ ] **Barre de collecte — devise et contributeurs** (`collection_progress_bar.dart`, 2026-08-03) : l'objectif et le montant courant étaient suffixés « € » en dur, et le nombre de contributeurs était `0` en dur aux deux points de montage (liste des salons et salon en direct). Le compte vient maintenant de `roomTipsProvider`, en donateurs **distincts** et **paiements aboutis seulement** : envoyer deux pourboires depuis le même compte doit afficher « 1 contrib. », pas « 2 ».

## Salons audio & appels de groupe — indicateur « parle en ce moment »

Ce bloc demande **deux comptes sur deux téléphones** : l'anneau ne s'allume que
sur une voix réellement captée par le SFU.

- [ ] **Anneau vert des intervenants** (`audio_room_screen.dart`, `audio_room_provider.dart`, 2026-08-03) : les tuiles `SpeakerTile` recevaient `talking: false` en dur — l'anneau ne s'est jamais allumé depuis l'écriture de l'écran. Il est maintenant piloté par `audioRoomSpeakingProvider` (flux `ActiveSpeakersChangedEvent` de LiveKit). Vérifier **les deux dispositions** : la grille (salon vidéo, tuiles 88 px) et le `Wrap` (salon audio seul, tuiles 52 px). Contrôler aussi l'extinction : l'anneau doit retomber quand la personne se tait, pas rester allumé.
- [ ] **Bordure de participant actif en appel de groupe** (`group_call_provider.dart`, 2026-08-03) : `speakingParticipantIds` était déclaré dans l'état et lu par l'écran, mais jamais alimenté. ⚠ **Ne se voit qu'à partir de 5 participants** (`meshToSfuThreshold`) : en dessous l'appel est en mesh, LiveKit n'est pas dans la boucle et le set reste vide — c'est le comportement attendu, pas une régression. Vérifier aussi qu'après avoir quitté l'appel aucune bordure ne reste collée.

## Lecteur de replay — valeurs inventées retirées (2026-08-03)

- [ ] **Replay sans chapitres** (`replay_player_screen.dart`) : cinq chapitres fictifs (« Introduction », « Actualités », « Diaspora & politique », « Q&R », « Conclusion ») s'affichaient quand l'entité n'en portait aucun, et le tap sautait à `i/5` de la piste. Sur un replay sans chapitre, la ligne « Chapitre n/N » et la pastille « Chapitres » doivent maintenant **disparaître**, et le grand titre afficher le nom du salon. Vérifier aussi le cas inverse : un replay **avec** chapitres réels doit toujours les lister avec leurs horodatages, et le tap sauter au bon endroit.
- [ ] **Compteur de temps en vidéo** (`replay_player_screen.dart`) : le temps écoulé et la durée totale dérivaient d'un `Duration(hours: 1, minutes: 14)` codé en dur — le compteur n'avait aucun rapport avec le fichier lu. Il vient maintenant du `VideoPlayerController`. Vérifier que la durée affichée correspond à la vraie, et que le compteur **avance** pendant la lecture (un écouteur a dû être ajouté, il n'y en avait aucun).
- [ ] **Glisser sur la forme d'onde en vidéo** : le geste ne faisait que déplacer le curseur à l'écran, la lecture continuait à sa position d'origine. Il doit maintenant vraiment chercher dans le flux.

## Version de l'app et téléphone du support (2026-08-03)

- [ ] **Numéro de version** (`app_version_service.dart`, nouveau) : « 1.2.0 » était écrit en dur dans Réglages (×2) et Profil. Il est maintenant lu sur le paquet installé via `package_info_plus` (nouvelle dépendance directe, déjà présente en transitive). Vérifier les trois emplacements — Réglages > À propos, la boîte « À propos », et Profil > Aide & à propos — et qu'ils affichent bien `1.2.0 (10)`, build compris. Si la lecture échoue, seul le libellé « Version » doit rester, sans numéro.
- [ ] **Ligne « Téléphone » du support** (`transaction_detail_screen.dart`) : elle affichait le gabarit « +33 1 XX XX XX XX » et composait `+33100000000` au tap. Elle est désormais masquée tant qu'aucun `supportPhone` n'est configuré dans les réglages — donc **elle ne doit plus apparaître du tout** en l'état. À revérifier si un vrai numéro est renseigné un jour.

## Appels 1-à-1 (correctifs du 2026-08-03)

Tout ce bloc demande **deux comptes sur deux téléphones** : rien n'est vérifiable
en solo.

- [ ] **Raccrochage réseau coupé** (`call_provider.dart`, 2026-08-03) : `endCall()`
  libère maintenant WebRTC, l'UI native et l'état local **avant** d'archiver
  l'appel dans Firestore (le distant est best effort, plafonné à 10 s). Le test
  qui compte : se mettre en mode avion **pendant** un appel connecté puis
  raccrocher — l'écran d'appel doit se fermer immédiatement et un nouvel appel
  doit redevenir possible. Avant le correctif l'écran restait bloqué pour de bon.
- [ ] **Refus avec réseau dégradé** (`call_provider.dart`) : même scénario sur
  `declineCall()` — la bannière CallKit doit s'éteindre tout de suite.
- [ ] **Double acceptation** (`call_provider.dart`) : appuyer sur « Accepter »
  dans l'app pendant que la bannière CallKit est encore affichée (ou l'inverse).
  WebRTC ne doit démarrer qu'une fois — avant, le même appel pouvait être
  répondu deux fois.
- [ ] **Appel reçu app tuée** (`native_call_service.dart`, `notification_service.dart`) :
  l'UUID CallKit est désormais dérivé du `callId` (v5) des deux côtés. À vérifier :
  (a) une seule bannière, pas deux empilées, quand l'app revient au premier plan ;
  (b) si l'appelant raccroche pendant la sonnerie, la bannière s'éteint bien
  (avant, l'app ne connaissait pas l'UUID généré par l'isolate d'arrière-plan et
  la sonnerie continuait).
- [ ] **Acceptation depuis l'écran verrouillé** (`AndroidManifest.xml`) :
  `showWhenLocked` + `turnScreenOn` ajoutés à `MainActivity`. Accepter un appel
  téléphone verrouillé doit allumer l'écran et afficher l'écran d'appel
  par-dessus le keyguard, pas juste derrière.
- [ ] **Routage audio** (`AndroidManifest.xml`) : `MODIFY_AUDIO_SETTINGS` et
  `BLUETOOTH_CONNECT` ajoutés. Vérifier le basculement écouteur ↔ haut-parleur
  en cours d'appel, et un casque Bluetooth appairé.
- [ ] **Accents dans les messages d'erreur** (7 fichiers du module appels,
  2026-08-03) : les chaînes étaient doublement encodées et s'affichaient
  « Utilisateur non connecté », « Échec de la connexion », « X est déjà en
  appel ». À relire à l'écran : historique d'appels, écran d'appel, overlay
  d'appel entrant.

## 🔴 Appels 1-à-1 mis en PAUSE (2026-08-14) — répondre à un appel ne faisait rigoureusement rien

Trouvé en testant à deux appareils réels (SM A515F + émulateur) après un
signalement « les appels ne passent pas ». Trois bugs empilés, chacun
suffisant à lui seul pour expliquer le symptôme :

- [x] **`callNotificationHandlerProvider` n'était jamais lu** (`lib/app.dart`) —
  Riverpod est paresseux : sans un `ref.watch` quelque part, ce `Notifier` ne
  se construit jamais, donc `_listenToNativeCallEvents()` et
  `_checkPendingCallsOnStart()` ne tournaient JAMAIS. Confirmé par
  `git log -S` sur tout l'historique : ce provider n'a été lu nulle part
  depuis sa création (`fcf821b`). Conséquence : accepter un appel depuis la
  bannière CallKit native (écran verrouillé ou app tuée) n'invoquait jamais
  `answerCall()` — la bannière se refermait, rien d'autre ne se passait.
  Explique pourquoi les vérifications « Acceptation depuis l'écran verrouillé »
  du bloc précédent (2026-08-03) n'ont jamais pu être concluantes : le
  réglage manifest était correct, mais rien en dessous n'écoutait.
  Correctif : `ref.watch(callNotificationHandlerProvider)` ajouté dans
  `_NigerDiasporaAppState.build()`. **Vérifié sur device (SM A515F +
  émulateur, 2026-08-14) : décroché, connecté.**
- [x] **Second appel pendant qu'un premier est en cours** (`call_provider.dart`,
  commit `6f572a9`) : `answerCall()` refusait en silence tout appel entrant
  différent de celui déjà suivi par `state.call` — y compris quand ce
  `state.call` était son PROPRE appel sortant en cours de composition.
  Décline désormais explicitement (occupé) et referme la bannière CallKit du
  second appel via `NativeCallService.endCallById` (nouveau).
- [x] **La reconnexion ICE ne retentait jamais réellement**
  (`webrtc_service.dart`) : `_attemptReconnection()` posait
  `WebRTCConnectionState.reconnecting` puis s'auto-rappelait en cas d'échec —
  mais son propre garde anti-doublon (basé sur ce même état) bloquait la
  relance. Un seul échec de signalisation transitoire (ex. jeton Firebase en
  cours de renouvellement pendant l'écriture RTDB de `ice_restart_offer`)
  achevait l'appel au bout du timeout de 30 s au lieu d'épuiser ses 3
  tentatives. Logique de relance extraite dans `_retryIceRestart()`, séparée
  du garde d'état.
- [x] Confusion « appel manqué » côté appelant (`call_message_service.dart`,
  `call_message_bubble.dart`, `conversation_item.dart`) : le même aperçu de
  message est vu par les deux côtés d'un appel sans réponse ; « manqué »
  sous-entend « vous avez manqué cet appel », faux pour l'appelant. Libellé
  neutre (« Pas de réponse ») des deux côtés.

**Les trois premiers correctifs sont vérifiés fonctionnels sur device**
(appel décroché et connecté avec succès entre SM A515F et émulateur). Mais la
session de test a été chaotique (émulateur repris par une autre
activité/session en cours de route, plusieurs faux départs) — **pas assez de
cycles propres pour être confiant sur la fiabilité bout-en-bout**
(reconnexion ICE en particulier, jamais vue aboutir jusqu'au bout dans un
test propre). Décision : couper l'accès utilisateur à la fonctionnalité le
temps d'une vérification à deux VRAIS téléphones, sans contention.

**Ce qui a été commenté (code conservé, pas supprimé)** :
- `conversation_screen.dart` : les deux `IconButton` d'appel 1-à-1 dans
  l'AppBar (audio/vidéo — les boutons d'appel de GROUPE juste en dessous
  restent actifs, système différent/LiveKit, pas concerné) ; le rappel en un
  geste sur une bulle d'appel (`onCallBack: null`) ; les méthodes
  `_startCall`/`_handleCallBack` et leurs imports (`call_entity.dart`,
  `call_provider.dart`, `call_screen.dart`) devenus inutilisés.
- `profile_screen.dart` : l'entrée « Historique des appels » (menu Profil).

**Pour réactiver** : décommenter ces blocs (cherchez « Appels 1-à-1 mis en
pause » dans les deux fichiers), puis reprendre EXACTEMENT ce test avant de
relivrer — deux téléphones réels, pas d'émulateur, personne d'autre dessus :
1. Appel connecté normalement des deux côtés.
2. Couper le wifi ~10 s côté appelé en pleine communication (force une
   coupure ICE réelle) : l'appel doit survivre via `_retryIceRestart()`, pas
   raccrocher après le timeout de 30 s.
3. Appeler B depuis A pendant que A a déjà un appel sortant en cours vers un
   tiers : B doit recevoir un refus « occupé » propre, pas un plantage muet.
- [ ] **Sonnerie côté appelé (push d'appel entrant)** — *le test le plus
  important* : le trigger `onCallCreated` était **mort au chargement** depuis le
  2026-07-19 (`require("dotenv")` et `require("livekit-server-sdk")` absents des
  dépendances de `functions/package.json` — ça passait en local, pas dans le
  conteneur). Trigger enregistré, fonction jamais exécutée, donc aucun push
  d'appel entrant pendant six semaines. Corrigé et redéployé le 2026-08-03
  (commit `a82c6b5`, démarrage à froid propre). À confirmer sur appareil :
  téléphone B en arrière-plan puis app tuée, appeler depuis A → B doit sonner
  avec la bannière plein écran. Puis `firebase functions:log --only onCallCreated`
  doit montrer « Successfully sent 1/1 call notifications ».
- [ ] **Relais TURN en 4G/5G sans wifi** (report du 2026-07-16) : coturn répond
  bien sur 3478/5349 et `getTurnCredentials` est déployée et appelée avec succès,
  mais le relais n'a jamais été validé sur un NAT symétrique réel.
- [ ] **Enchaîner deux appels après un raccrochage en réseau dégradé**
  (`webrtc_service.dart`, 2026-08-03) : `hangUp()` n'avait pas de try/finally et
  posait `_isEndingCall` avant une suppression RÉSEAU en RTDB. Une exception en
  route laissait le singleton WebRTC coincé pour toute la session — plus aucun
  raccrochage, et `startCall` levant « Already in a call » sur tous les appels
  suivants. Le test qui compte : couper la donnée en plein appel, raccrocher,
  rétablir, puis **passer un second appel** — il doit partir normalement.
- [ ] **Micro refusé au moment de décrocher** (`call_provider.dart`, 2026-08-03) :
  révoquer la permission micro dans les réglages Android, puis accepter un appel.
  L'écran doit échouer **immédiatement** avec « Micro ou caméra inaccessible »
  au lieu de rester sur « Connexion… » pendant 30 s. Vérifier aussi le chemin
  inverse : accepter depuis la bannière CallKit (l'échec n'était capturé nulle
  part sur ce chemin).
- [ ] **Service de localisation en arrière-plan**
  (`background_location_service.dart`, 2026-08-03) : la classe portait ses
  `@pragma('vm:entry-point')` sur les méthodes statiques mais pas sur la classe
  elle-même, que le natif traverse pour les atteindre — le VM refusait au
  démarrage et le service ne pouvait jamais tourner. À vérifier : activer le
  partage de position, mettre l'app en arrière-plan, et confirmer que la
  notification persistante du service apparaît et que la position remonte.

## Lecture audio en arrière-plan (podcasts)

- [ ] **Câblage `audio_service`** (`MainActivity.java` + `AndroidManifest.xml`,
  2026-08-03) : `MainActivity` étendait `FlutterFragmentActivity` au lieu de
  `AudioServiceFragmentActivity`, et le manifeste ne déclarait ni le service
  `com.ryanheise.audioservice.AudioService` ni `MediaButtonReceiver` (le plugin
  ne déclare rien lui-même). `AudioService.init()` échouait donc à chaque
  démarrage — la lecture en arrière-plan n'a jamais pu fonctionner. Corrigé et
  vérifié sur le SM A515F : plus d'erreur d'init au lancement, service et
  receiver bien enregistrés dans le paquet installé. **Reste à tester en vrai** :
  lancer un épisode, quitter l'app, vérifier que le son continue et que la
  notification média apparaît avec les contrôles ; puis les boutons du casque et
  ceux de l'écran verrouillé (`MediaButtonReceiver`), et que la reprise depuis la
  notification ramène bien sur le lecteur.

## Galerie design_v2 sur appareil (2026-08-03)

Premier passage réel sur le SM A515F. Trois choses ont été **vérifiées**,
et il faut le noter parce que la plupart des points de ce fichier ne l'ont
jamais été :

- [x] **L'accent est terracotta**, plus vert. `ThemeColorNotifier` retournait
  `AppThemeColor.green` par défaut, donc une installation neuve affichait
  toute la refonte dans la mauvaise couleur — sur les 40 écrans. Corrigé et
  constaté à l'écran (pastille « D », point du titre, bouton principal).
- [x] **Le thème sombre de l'écran de connexion (§15a) est lisible.** Aucun
  texte perdu, contrastes tenus. Le piège du commit `78b720e` n'a pas été
  réintroduit sur cet écran.
- [x] **La structure du §15a est conforme** à la maquette : titre serif à
  point d'accent, sous-titre, bouton Google, libellés au-dessus des champs,
  mention de chiffrement en pied.

### Ce qui reste à faire, et le chemin pour y arriver

L'accès à la galerie **par deep link ne fonctionne pas**. Deux tentatives,
documentées pour ne pas les refaire :

1. `diasponiger://design-v2` — l'intent lance bien l'activité, mais l'URI
   n'atteint jamais Dart : le log montre `setting initial location /splash`.
2. `flutter_deeplinking_enabled` dans le manifeste — **casse le démarrage**,
   le moteur Dart ne se lance plus du tout. Probablement parce que
   `MainActivity` étend `AudioServiceFragmentActivity` (héritage CallKit).
   Le drapeau a été retiré, l'APK reconstruit et l'app vérifiée comme
   redémarrant.

**Le seul chemin encore crédible est Réglages → Refonte → Galerie design
v2**, qui ne dépend d'aucun intent — mais demande d'être connecté, et
`adb install -r` vide les données à chaque pose d'APK.

- [ ] Se connecter une fois, puis ouvrir la galerie par les réglages.
- [ ] Parcourir les **19 écrans**, en **clair et en sombre** (le thème suit
  le système : basculer depuis le volet Android).
- [ ] Regarder en priorité l'**onboarding** et la **configuration du profil**,
  les deux écrans les plus restructurés, donc les plus susceptibles de
  déborder sur un écran réel.
- [ ] Vérifier les **bulles de message** : le poids du fichier s'ajoute à une
  ligne déjà chargée (durée, point « non écouté », erreur éventuelle).

### Méthode, pour la prochaine fois

- **Toujours `adb shell am force-stop` avant un deep link.** Sur un démarrage
  à chaud, l'intent est livré sans que le routeur rejoue sa redirection.
- **Le signal fiable est `GoRouter: INFO` dans `adb logcat -s flutter`**, pas
  la capture d'écran. Un écran noir peut être le splash (bénin) ou un moteur
  Dart mort (grave) — seule l'absence de log distingue les deux. J'ai
  confondu les deux pendant cette session.
- L'arbre de routes que go_router imprime au démarrage liste **toutes** les
  routes déclarées. Y voir `/design-v2` ne prouve **pas** qu'on y est.

## Profil & Accueil (avant la refonte design)

## Reprise du design (2026-08-03, suite) — Éco, accueil, carte, discussion

⚠️ **Distinction à faire avant de tester.** L'essentiel du travail de design
de cette session vit dans `lib/design_v2/`, **qui n'est câblé à aucune
route** : ces écrans ne s'affichent pas dans l'app et ne sont donc **pas
testables** tant que la bascule vers `lib/features/` n'a pas eu lieu. Seuls
les trois blocs ci-dessous touchent la production et sont exerçables tout de
suite.

### Testable maintenant (production)

- [ ] **Mode données réduites appliqué à la réception** (`data_saver_gate.dart`
  nouveau, `message_bubble.dart`, 2 sites image + vidéo). C'est le point le
  plus important à vérifier de la session, et le seul qui change un
  comportement réseau. À exercer :
  - activer ÉCO (puce `⊙ Éco` de la sous-barre d'une discussion, ou Réglages
    → « Mode données réduites ») puis **recevoir une image et une vidéo** :
    la bulle doit montrer l'aperçu flou, la légende « aperçu flouté · N Ko »
    et un bouton « Télécharger », **sans consommer de données** ;
  - confirmer que rien ne part avant l'appui — idéalement en coupant les
    données mobiles après réception du message : le média doit rester masqué
    sans erreur de chargement ;
  - appuyer sur « Télécharger » → le média apparaît ;
  - **défiler loin puis revenir** : le média dévoilé doit le rester (le
    dévoilement est mémorisé par identifiant de message, en mémoire) ;
  - **relancer l'app** : le média doit être **de nouveau masqué**, c'est
    voulu ;
  - vérifier qu'un média **que j'envoie** n'est jamais masqué ;
  - vérifier qu'un message sans `fileSize` affiche « aperçu flouté » **sans**
    « 0 Ko ».
  - Test le plus parlant : **en 2G réelle ou en bridant le réseau**, comparer
    la consommation avec et sans ÉCO sur une conversation riche en médias.

- [ ] **Squelette pendant l'élargissement du rayon** (`home_screen.dart`,
  `home_screen_widgets.dart`). Depuis l'accueil, état « Personne à moins de
  50 km », appuyer sur « Élargir à 200 km » : le squelette (4 avatars gris)
  doit remplacer la carte vide **pendant** la recherche. Le défaut corrigé
  était que « Personne à moins de 50 km » restait affiché tout du long.
  Vérifier aussi que le **rafraîchissement automatique des 60 s** ne fait
  **pas** clignoter la liste — il doit garder les résultats affichés.

- [ ] **Carte — libellés sur l'accent en thème sombre** (`map_screen.dart`,
  `map_legend.dart`). Cinq libellés étaient figés sur `Colors.white` alors
  qu'ils sont posés sur la couleur d'accent : trois boutons et deux puces
  sélectionnées (rayon, filtre). **À regarder en mode nuit** — le texte doit
  rester lisible sur la puce sélectionnée. Vérifier aussi la pastille de la
  légende, passée d'un dégradé à un aplat.

- [ ] **Brouillon d'épisode de podcast** (`record_episode_screen.dart`,
  `podcast_provider.dart`, §2d). Le chemin est neuf de bout en bout, et rien
  ici n'est vérifiable sans base réelle :
  - enregistrer un épisode puis appuyer sur **« Brouillon »** : la
    confirmation doit dire « enregistré en brouillon », **pas** « publié » ;
  - vérifier en base que la ligne a bien `status = 'draft'` **et**
    `published_at` **nul** — c'est le point le plus facile à casser, le
    provider posait la date dès qu'il n'y avait pas de programmation ;
  - le brouillon **ne doit pas apparaître** comme épisode publié dans la
    fiche du podcast (§3b) ni pour un abonné ;
  - il **ne doit pas compter** dans la section « Rythme de publication » des
    statistiques (§4a) — c'est exactement à quoi sert `published_at` nul ;
  - contre-test : « Terminer et publier » doit toujours produire
    `status = 'published'` avec une date. Une régression ici rendrait la
    publication silencieusement inopérante.

- [ ] **Note « muet en silence » de la modération fantôme** (§3c,
  `ghost_moderator_screen.dart`). Vérifier que la phrase apparaît bien sous
  la grille des quatre actions et reste lisible — elle est en chasse fixe
  taille 9. C'est la seule chose qui distingue cette action d'un mute
  ordinaire : si elle déborde ou passe inaperçue à `font_scale = 1.1`, elle
  ne remplit pas son rôle.

### Non testable tant que `design_v2` n'est pas basculé

Pour mémoire, ce qui attend la bascule : onboarding 5 écrans, configuration
du profil en 4 étapes (identité / localisation / intérêts + notifications /
thème), séparateurs plats de la discussion, bouton d'envoi du composer en
aplats (4 états, avec variantes claires en thème sombre), pastille de vitesse
en contour et poids du fichier de la note vocale.

Deux points à regarder **en priorité au moment de la bascule**, parce qu'ils
sont invisibles à `flutter analyze` :

- le **thème sombre** de tous ces écrans — c'est la famille de défauts la
  plus récurrente du projet ;
- l'onboarding à `font_scale = 1.1`, où les titres serif sur deux lignes et
  les puces de réassurance peuvent déborder.

## Session appareil du 2026-08-03 — SM A515F, thème sombre, font_scale 1.1

Premier passage réel sur téléphone de toute la reprise du design. Le
téléphone était déjà dans les deux conditions les plus risquées : nuit et
échelle de police 1.1.

**Cinq défauts trouvés, aucun visible à `flutter analyze`.**

- [x] Puce de filtre des notifications : fond `adaptivePrimaryColor` (qui
  s'éclaircit en nuit) + texte `Colors.white` figé → blanc sur orange clair.
  Corrigé en `onPrimaryColor`. **Vérifié à l'écran après reconstruction.**
- [x] « Précédent » tronqué en « Précéd » à l'étape 3/4 de la configuration
  du profil : ratio 1:2 trop serré à font_scale 1.1. Passé à 3:4.
- [ ] Empreinte de clé quasi invisible (écran des appareils) : le texte
  utilisait `theme.colorScheme.outline`, une couleur de **bordure**.
  Corrigé vers `textSecondaryColor` — **non vérifié à l'écran**, l'app a
  redémarré avant que j'y revienne. À confirmer.
- [ ] Texte codé en dur et sans accents sur ce même écran (« jusqu'a 5
  appareils connectes simultanement ») alors que la clé localisée existait
  et n'était pas utilisée. Corrigé — **non vérifié à l'écran**.

### ✅ Anomalie du thème : élucidée, ce n'était pas un bug

L'écran de configuration du profil, puis l'annuaire Business, se sont
affichés en crème alors que je croyais le téléphone en thème sombre.

**Cause réelle : le téléphone était passé en mode clair.** `settings get
secure ui_night_mode` renvoyait `1` au moment des captures, contre `2` au
début de la session — mes séquences de `adb shell input tap` à l'aveugle
ont dû basculer le réglage système en passant par le volet de
notifications.

Confirmé en remettant `cmd uimode night yes` : le même écran de
configuration s'est immédiatement affiché entièrement en sombre, jetons,
puces et bascules compris. **Il n'y a pas de bug de thème, ni sur cet
écran ni sur l'annuaire.** Les deux suivent correctement `adaptive_colors`.

À retenir pour les prochaines sessions : vérifier `ui_night_mode` **avant
et après** chaque série de captures. Piloter l'app par taps aveugles peut
modifier des réglages système et fabriquer de faux défauts visuels.

### ⚠ Redémarrages de l'app pendant les tests : mémoire, pas crash

L'app redémarrait à répétition pendant la navigation. `logcat` montre des
kills `lmkd` et `/proc/meminfo` donnait **122 Mo libres sur 5,7 Go**.
L'APK debug pèse 317 Mo. Après `am kill-all` (612 Mo libres), la
navigation a tenu. Ce n'est pas un crash applicatif.

### ⚠ Ouvert : « Précédent » toujours tronqué

Le passage du ratio 1:2 à 3:4 n'a pas suffi — le bouton affiche encore
« Précéd », sans points de suspension, donc coupé et non ellipsé. Le
routeur pointe pourtant bien sur le fichier corrigé et l'ARB contient
« Précédent » en entier.

Correctif appliqué en second recours : le libellé des boutons de la
trousse est enveloppé dans un `FittedBox(scaleDown)`, pour qu'un mot trop
long **rétrécisse** au lieu d'être coupé. **Non vérifié sur appareil** —
à confirmer au prochain passage.

### ⚠ Encore des accents manquants

« Aucune entreprise trouvee · Soyez le premier a ajouter votre
entreprise ! » sur l'annuaire Business. Même famille que le texte en dur
de l'écran des appareils. Un balayage des littéraux français sans accents
reste à faire sur tout le dépôt.

## Quatrième vague — écrans repris en production (2026-08-03)

Contrairement au bloc ci-dessus, **tout ce qui suit est dans
`lib/features/` et donc exerçable tout de suite**. Aucun de ces écrans n'a
été vu tourner : les jetons de thème ont été raisonnés, pas observés.

### À vérifier en thème sombre en priorité

C'est la famille de défauts la plus récurrente du projet, et cette vague a
converti une centaine de couleurs figées en jetons adaptatifs.

- [ ] **Appareils connectés** (`devices_screen.dart`) et **Sauvegarde des
  clés** (`security_backup_screen.dart`) — 26 couleurs routées, dont des
  fonds `shade50` presque blancs. Ce sont les écrans qu'on ouvre dans le
  noir après avoir perdu son téléphone : vérifier que la carte « sauvegarde
  active », l'avertissement de passphrase et le bouton « Révoquer » restent
  lisibles.
- [ ] **Détail d'un transfert** (`transaction_detail_screen.dart`) — les 20
  couleurs d'état, dont celles qui distinguent « débité mais bloqué » de
  « refusé avant débit ». Provoquer au moins un échec pour voir la couleur
  réelle, pas seulement le cas nominal.
- [ ] **Mes commandes** (`my_orders_screen.dart`) — 9 statuts routés ;
  **teal et violet sont restés figés** faute de jeton équivalent. Regarder
  s'ils jurent en nuit.
- [ ] **Modifier le profil**, **Réglages de notifications**, **Messages
  favoris**, **Nouvelle conversation** — mêmes conversions.

### Les trois blancs volontairement conservés (`edit_profile_screen.dart`)

Ils sont posés sur un aplat saturé et **doivent** rester blancs. Le
raisonnement dit qu'ils passent ; seul l'écran le prouve.

- [ ] SnackBar de succès après enregistrement du profil — glyphe blanc sur
  le vert de succès, en clair **et** en nuit.
- [ ] Pastille de code langue (FR, HA…) dans « Langues parlées », état
  sélectionné et non sélectionné.

### Les voiles de contraste laissés en place

Trois écrans gardent des noirs semi-transparents parce qu'ils sont posés
sur du contenu arbitraire. À vérifier **sur une image claire**, cas où un
voile trop faible devient illisible :

- [ ] **Galerie de conversation** — la durée d'une vidéo (« 0:12 ») sur une
  vignette surexposée.
- [ ] **Écrans d'appel** — les commandes blanches sur un flux vidéo clair.
- [ ] **Carte** — les épingles et cercles de rayon, laissés en couleurs
  fixes parce qu'ils se lisent sur le fond Google Maps et non sur le fond
  de l'app.

### Points qui ne se voient qu'à l'exécution

- [ ] **Mention « CHIFFRÉ DE BOUT EN BOUT » de l'appel 1-à-1.** Elle est
  conditionnée à `E2EEService.instance.isE2EEEnabled`. Vérifier les deux
  sens : qu'elle **apparaît** sur un appel réellement chiffré, et qu'elle
  **n'apparaît pas** si la clé n'est pas posée. Un badge qui ment sur le
  chiffrement est pire que pas de badge.
- [ ] **Fil et Mon espace en thème clair (mode « organic »).** 13 libellés
  sont passés de la police de l'app à **Figtree** via `FeedText`. Le défaut
  était invisible en nuit et ne se voit qu'en clair, à côté des titres
  Caprasimo. Prévoir un premier lancement **avec réseau** : `google_fonts`
  télécharge les fontes.
- [ ] **Modifier le profil — l'avatar a changé de place.** Il quitte
  l'en-tête héros pour rejoindre le formulaire. Vérifier que l'animation
  `Hero` (tag `profile_avatar`) depuis l'écran de profil ne saute pas, et
  que la barre repliée reste lisible au défilement.
- [ ] **Réglages de notifications** — les libellés de section sont passés en
  chasse fixe capitales. À `font_scale = 1.1`, vérifier qu'ils ne coupent
  pas (« CE QUI VOUS ALERTE » est long).

### Non testable — reste dans `design_v2`

Feuille d'actions sur un message ramenée à cinq entrées avec révélateur
« Autres actions » et rangée de réactions rapides ; états d'enregistrement
vocal (« Glisser ‹ pour annuler · ↑ pour verrouiller », « Relâcher pour
annuler », « Mains libres ») ; deux familles de couleur dans la grille du
composer.

Au moment de la bascule, tester en priorité **les trois états vocaux avec
le doigt**, seule façon de vérifier que le bon libellé s'affiche au bon
moment : le seuil d'annulation est à ~70 px et le verrouillage se fait
vers le haut.

## Refonte des maquettes d'authentification

- [x] **Connexion et inscription refaites sur les maquettes** (`auth_scaffold.dart`
  nouveau, `login_screen.dart`, `register_screen.dart`, `auth_button.dart`,
  `assets/icons/icon_google.svg`, 2026-08-03) : vérifié sur le SM A515F, les
  deux écrans rendent la structure des maquettes — pastille de marque en haut
  à gauche, titre serif terminé par un point d'accent, bouton Google avec le
  vrai logo multicolore, libellés au-dessus des champs, « Oublié ? » sur la
  ligne du libellé, texte d'aide, bouton pleine largeur, lien de bas de page,
  mention de chiffrement épinglée en bas. L'accent apparaît **vert** et non
  terracotta : c'est la couleur d'accent choisie sur ce compte, pas un défaut.
  **Piège rencontré** : un `Spacer` dans la colonne défilante d'`AuthScaffold`
  donnait un écran entièrement noir, sans aucune exception dans `logcat` — le
  pied de page est désormais hors du défilement.

- [ ] **Configuration du profil : écrite, pas encore testable.** Les 4 étapes
  des maquettes (identité « Faisons connaissance » avec photo, nom
  d'utilisateur et vérification de disponibilité, profession ; localisation ;
  centres d'intérêt fusionnés avec « Ce que vous recevrez » ; thème) sont
  implémentées — mais dans `lib/design_v2/profile/…/profile_config_screen.dart`,
  **qui n'est câblé à aucune route**. Rien n'est vérifiable sur appareil avant
  la bascule vers `lib/features/`. Restent non écrites : nouvelle demande
  d'ambassade, création d'événement, panier vide, état vide des transferts.

- [ ] **Sous-titre chiffré de l'inscription non implémenté** : la maquette
  annonce « Rejoignez la communauté : 318 membres à Paris, 12 groupes actifs ».
  Aucune source ne peut fournir ces nombres avant authentification (les
  compteurs de `home_remote_datasource` demandent une session), et les inventer
  irait contre l'audit « widgets alimentés en dur ». Le sous-titre générique est
  conservé en attendant un compteur public.

## Thème sombre — jetons clairs codés en dur

- [x] **Écrans d'authentification en thème sombre** (`login_screen.dart`,
  `register_screen.dart`, `forgot_password_screen.dart`,
  `maintenance_screen.dart`, `splash_screen.dart`, `auth_button.dart`,
  2026-08-03) : vérifié sur le SM A515F en mode nuit — voir le bloc de session
  en tête de fichier. Seul l'écran de connexion a été capturé ; les quatre
  autres partagent le même correctif mais n'ont pas été ouverts.

- [ ] **Les 9 autres fichiers de la même passe** : 4 écrans de transferts,
  3 écrans de profil, la carte et `friend_list_item` — non atteignables sans
  session, la réinstallation déconnecte l'app. À rouvrir en mode nuit une fois
  reconnecté.

- [ ] **Blancs bruts restants** : ~587 `Colors.white` / `AppColors.white` et
  184 `Colors.black*` subsistent dans `lib/features`. La grande majorité est
  légitime (texte blanc sur surface colorée, écrans immersifs comme l'appel ou
  le viewer de stories, fond blanc obligatoire des QR codes) — seuls 14 sont
  des `backgroundColor`, dont 3 méritent un examen
  (`admin_create_admin_screen.dart:41`, `transfer_screen.dart:86`,
  `share_profile_modal.dart:447`). À trancher au cas par cas, pas en masse.

## Guide de style — alignement des jetons (2026-08-03)

- [ ] **11 couleurs d'`AppColors` réalignées sur le guide de style**
  (`lib/core/constants/app_colors.dart`) : bordure `#E8DFD4`→`#EFE7DB`,
  bordure forte `#C9BBAB`→`#E0D6C6`, texte désactivé `#B8AFA3`→`#A79C8E`,
  bordure nocturne `#3D352C`→`#2A241E`, succès `#2D7D46`→`#1B5E32`, erreur
  `#C53030`→`#C23E2D`, info `#2563EB`→`#1976D2`, et les quatre fonds pastel
  réchauffés. Ces jetons irriguent **toute** l'app via `adaptive_colors.dart` :
  c'est le changement le plus large de la session. **À vérifier sur le
  téléphone** : la bordure forte s'éclaircit nettement — contrôler que les
  puces de filtre et de centres d'intérêt au repos (`DesignFilterChip`,
  `DesignSelectableChip`, accueil / messagerie / groupes) restent visibles sur
  le fond crème, et qu'en nocturne les cartes se détachent encore avec la
  bordure plus sombre.

- [ ] **Texte sur accent en nocturne** (`lib/core/theme/adaptive_colors.dart`) :
  `onPrimaryColor` rendait du noir pur en mode nuit, le guide impose l'encre
  inverse `#1C1815`. Touche tous les boutons pleins et les pastilles d'accent.
  **À vérifier** : ouvrir un écran d'onboarding et un bouton principal en mode
  nuit, confirmer que le libellé reste franc (le changement est subtil, un
  rendu délavé signalerait une erreur de jeton).

- [ ] **État désactivé des boutons du kit**
  (`lib/design_v2/kit/design_kit.dart`) : `DesignPrimaryButton` et
  `DesignPillButton` passaient l'accent à 55 % d'opacité ; ils prennent
  désormais l'aplat sable + libellé éteint du guide. Le **chargement** garde
  volontairement la couleur d'accent. **À vérifier** : sur l'inscription et la
  configuration du profil, enchaîner champ vide → bouton grisé → champ rempli →
  bouton coloré → soumission → pilule colorée avec spinner clair.

- [ ] **Bouton secondaire** (idem) : contour passé de `borderColor` à
  `borderStrongColor` et libellé de `textPrimary` à `textSecondary`, comme le
  guide. **À vérifier** : le « Précédent » de la configuration du profil ne
  doit pas s'effacer sur le fond crème.

- [ ] **`DesignBadge` — jamais rendu** (idem) : les quatre pastilles de statut
  du guide (vérifié / en examen / échoué / archivé) sont écrites mais aucun
  écran ne les appelle encore. À regarder dès le premier usage, dans les deux
  thèmes.

- [ ] **Indicateur d'étapes du transfert** (`transfers/…/send_money_screen.dart`,
  les deux copies) : `_kStepUpcoming` recopiait l'ancienne bordure `#E8DFD4`
  et restait donc en beige clair en nocturne ; l'étape à venir passe par
  `colorScheme.outline`. **À vérifier** : ouvrir « Envoyer de l'argent » en
  mode nuit — le rond et la barre des étapes non atteintes deviennent
  nettement plus discrets (`#2A241E` sur `#0F0D0A`). Confirmer qu'on distingue
  encore la piste ; si elle disparaît, basculer sur `outlineVariant`.

- [ ] **Bordure des bulles reçues** (`messages/…/message_bubble.dart`, les deux
  copies) : `_kRecvBorderLight/Dark` figeaient `#EFE7DB` / `#3D352C` ; passe
  par `context.borderColor`. Seul le nocturne change (`#2A241E`). **À
  vérifier** : dans une conversation en mode nuit, la bulle reçue doit encore
  se détacher du fond.

- [ ] **Le tunnel de transfert suit désormais l'accent du compte**
  (`transfers/…/send_money_screen.dart`, les deux copies) : `_kTransferAccent`
  figeait `#B85E24` sur les 5 points d'accent (rond d'étape actif, barre
  franchie, bouton principal, puce de montant rapide), toujours avec du
  `Colors.white` en dur. Tout passe par `colorScheme.primary` /
  `colorScheme.onPrimary`. **C'est un changement de comportement assumé, pas
  seulement un correctif** — trois choses à regarder :
  1. **Compte en accent vert** : le tunnel devient vert. C'était orange pour
     tout le monde jusqu'ici. Vérifier que rien ne jure avec le reste de
     l'écran.
  2. **Compte en accent orange** : ~~la teinte glisse de `#B85E24` à
     `#E07B39`~~ — plus vrai. `colorScheme.primary` du thème orange est
     passé à `#B85E24` juste après (voir la section suivante), donc en clair
     le tunnel garde exactement sa teinte d'avant. Rien à vérifier ici.
  3. **Mode nuit** : l'accent s'éclaircit et le texte dessus devient de l'encre
     foncée au lieu du blanc — c'est la règle du guide. Confirmer sur le rond
     d'étape (chiffre + coche), le bouton « Continuer » et son spinner.

## Accent orange du thème clair — `#E07B39` → `#B85E24` (2026-08-03)

- [ ] **L'orange d'action de toute l'app change de teinte**
  (`lib/core/theme/app_theme.dart`) : les 17 liaisons qui exprimaient l'accent
  orange pointaient sur `AppColors.primary` (`#E07B39`) ; le guide de style
  désigne `#B85E24` (`primaryDark`) comme « Orange — action ». Elles passent
  toutes sur `primaryDark`, dans les deux thèmes clairs — accent du thème
  orange, et orange secondaire du thème vert. **C'est le changement le plus
  visible de la session** : il touche boutons pleins et contour, boutons
  texte, FAB, barre de navigation basse, onglets, interrupteurs, cases à
  cocher, radios, barres de progression et bordure de champ au focus.
  **Vérifié sur SM A515F le 2026-08-03** (build de `ebc3716`, thème orange,
  mode clair forcé en adb puis restauré). Couleurs relevées au pixel sur les
  captures, pas jugées à l'œil — `#B85E24` exactement sur : bouton plein
  « Compléter ma bio », barre de progression du profil, onglet actif de la
  navigation basse, bouton composer de la messagerie, icône d'information,
  bordure de champ **au focus**. Fond `#FAF7F2` et surface `#FFFFFF`
  conformes au guide.
  1. [x] **Le blanc sur l'accent** : franc, et mesurable — le contraste blanc
     sur `#B85E24` est de **4,50:1** (AA pour le texte courant), contre
     **2,97:1** sur l'ancien `#E07B39`, qui échouait même au seuil du grand
     texte. C'est le vrai gain du changement.
  2. [x] **Bordure de champ au focus** : nette, ~4 px réels de `#B85E24` sur
     le crème. Ma crainte que les traits fins s'assombrissent de trop ne se
     confirme pas.
  3. [ ] **Coche, piste d'interrupteur, indicateur d'onglet** : pas atteints
     pendant la session. Même jeton que les éléments ci-dessus, donc même
     valeur — mais l'épaisseur du trait n'a pas été jugée.
  4. [ ] **Thème vert** : non vérifié, le compte de test est en accent
     orange.
- [ ] **Dégradés inchangés, volontairement** : `AppColors.primary`
  (`#E07B39`) reste la teinte claire de la famille orange et continue
  d'ouvrir `primaryGradient` (`#E07B39` → `#B85E24`). Un dégradé qui part
  d'un ton plus clair que l'accent est normal, mais si un bandeau paraît
  désormais désaccordé avec les boutons, c'est là qu'il faut regarder. Aucun
  écran à dégradé n'a été ouvert pendant la session.
- [x] **Thèmes sombres non touchés** : vérifié sur l'appareil — l'accent
  nocturne reste `#F4A574` (pictogrammes, libellés de section, onglet actif).
  Aucun changement en mode nuit, comme attendu.
- [ ] **Bordure forte `#E0D6C6` sur les puces au repos** : c'est le point que
  j'avais désigné comme le plus à risque, et il **n'a pas été atteint**
  (`DesignSelectableChip` vit dans la configuration du profil,
  `DesignSecondaryButton` dans ses barres de navigation). Les puces de filtre
  de la messagerie, elles, utilisent la bordure fine `#EFE7DB` : visible sur
  la capture, leur contour est très discret, la puce ne tient que par son
  aplat blanc sur le fond crème. À trancher en voyant la configuration du
  profil.

## Feature flags & accès aux écrans

- [ ] **Déblocage des routes gardées par les flags** (`lib/core/router/app_router.dart`,
  `lib/core/services/feature_flag_service.dart`,
  `lib/features/admin/presentation/screens/admin_feature_flags_screen.dart`,
  2026-08-03) : `FeatureFlagService.isFeatureEnabled` lisait un
  `ProviderContainer()` neuf, donc toujours les valeurs par défaut de
  `FeatureFlagsEntity` — `/transfers`, `/marketplace`, `/podcasts`,
  `/payment-accounts`, `/payment-history` et `/audio-rooms` étaient renvoyés
  sur `/home` quoi qu'en dise le back-office. Le gating ne s'appliquait en
  plus qu'aux valeurs par défaut au démarrage à froid, et le back-office
  n'exposait aucun interrupteur pour `audioRooms`/`podcasts`. **À vérifier sur
  le téléphone** : ouvrir Salons audio et Podcasts depuis l'accueil et
  confirmer qu'on n'est plus rejeté sur l'accueil ; basculer les deux nouveaux
  interrupteurs dans Admin → Feature flags et confirmer que l'accès s'ouvre et
  se referme sans redémarrer l'app ; enfin, tuer et relancer l'app pour
  vérifier qu'on n'est pas éjecté d'un de ces écrans pendant le chargement des
  réglages.

- [ ] **Points d'entrée créés vers trois modules injoignables**
  (`lib/features/home/presentation/screens/home_screen_widgets.dart`,
  `lib/features/home/presentation/screens/services_screen.dart`,
  `lib/features/profile/presentation/screens/profile_screen.dart`,
  2026-08-03) : `/audio-rooms`, `/podcasts` et `/calls/history` n'étaient
  référencés par aucun écran de l'app — seuls des liens internes à ces modules
  pointaient vers eux. Les écrans existaient et les routes étaient déclarées,
  mais aucun chemin de navigation n'y menait. Tuiles « Salons » et
  « Podcasts » ajoutées à la grille de l'accueil et à « Tous les services »,
  entrée « Historique d'appels » ajoutée à la section Compte du profil.
  **À vérifier sur le téléphone** : les deux tuiles apparaissent bien sur
  l'accueil une fois les flags activés (et disparaissent quand on les
  désactive), la grille ne casse pas son passage 3↔4 colonnes avec deux tuiles
  de plus, et les trois destinations s'ouvrent réellement.

## Bascule design_v2 → production, famille 2 : les services (2026-08-03)

Onze écrans sont passés de `lib/design_v2/` à `lib/features/` : annuaire
Business (5), ambassades (4), événements (2). Ils étaient jusqu'ici
inatteignables autrement que par la galerie `/design-v2` ; ils sont
maintenant **ceux que l'app ouvre pour de bon**. Rien n'a été vu tourner.

- [ ] **Annuaire Business** (§17c, §17d, §18a→18d) : liste, fiche, création,
  avis et mise en avant. Vérifier surtout la **fiche** (`business_detail`),
  qui empile en-tête, posts, avis et actions — c'est là qu'un débordement à
  `font_scale = 1.1` est le plus probable.
- [ ] **Ambassades** (§13b, §16d, §17a, §17b) : liste, fiche, demande
  administrative, message. Le statut ouvert/fermé est passé aux jetons
  `errorColor`/`successColor` : **regarder en thème sombre**, c'est
  exactement ce que ce changement corrige.
- [ ] **Événements** (§13a, §16e) : liste et création. La création est le
  formulaire le plus long des trois features (sélection de médias,
  localisation, date) — vérifier qu'aucun champ ne passe sous le clavier.
- [ ] **Thème sombre des onze écrans**, en priorité. C'est la famille de
  défauts la plus récurrente du projet, et ces écrans n'ont jamais été
  affichés ailleurs que dans la galerie de debug.

## Bascule design_v2 → production, famille 3 : boutique, support, transferts, appels (2026-08-03)

Dix écrans de plus dans `lib/features/`, jamais vus tourner :

- [ ] **Boutique** (§12b, §16a, §16b, §16h) : liste, fiche produit, panier.
- [ ] **Support** (§22a→22d) : nouveau ticket, mes demandes, suivi, état vide.
- [ ] **Transferts — accueil et historique** (§16i, §16c). La **frise
  « Débité → En route → Disponible »** de l'historique est le point à
  regarder : elle ne doit apparaître que sur les transferts qui ont un
  trajet, pas sur un échec ou un remboursement.
- [ ] **Historique d'appels** (§13c) et **création de podcast** (§2c).
- [ ] ⚠️ **`send_money_screen` n'est pas dans ce lot** : il attend une fusion,
  pas une copie. Ne pas conclure d'un tunnel d'envoi correct que la bascule
  des transferts est complète.

## Bascule design_v2 → production, famille 4 : messagerie, groupes, recherche, profil (2026-08-03)

Onze fichiers, dont toute la discussion. C'est le lot le plus visible des
quatre familles, et **trois écrans y perdent leur en-tête** — c'est voulu,
mais c'est exactement ce qu'il faut regarder en premier :

- [ ] **Messagerie — liste** (§9a, §9e) : l'en-tête dégradé et ses cercles
  décoratifs ont disparu au profit d'un en-tête plat. Vérifier que le compteur
  de non-lus reste lisible et que la liste ne commence pas collée au haut de
  l'écran.
- [ ] **Mon profil** (§10a) : l'écran n'a plus de `SliverAppBar`. Il ne se
  replie donc plus au défilement — plus d'avatar+nom qui apparaît en haut.
  Vérifier que le retour et les actions restent atteignables tout en bas de
  page, puisqu'il n'y a plus de barre épinglée.
- [ ] **Recherche** (§12d) : plus de titre d'écran, le champ **est**
  l'en-tête. Ouvrir la recherche depuis les groupes et depuis les
  discussions : le contexte doit rester visible dans le **placeholder**
  (« Rechercher un groupe… ») — c'est le seul endroit où il subsiste.
- [ ] **Discussion complète** (§3b, §3c, §4a→4f, §6b, §6c) : écran, composer,
  bulles texte et bulles audio sont maintenant tous en v2. À regarder
  ensemble — les trois états d'enregistrement vocal avec leurs libellés
  (« Glisser ‹ pour annuler », « Relâcher pour annuler », « Mains libres »),
  la pastille de vitesse en contour, le poids du fichier.
- [ ] **Non-régression du mode « données réduites »** : `DataSaverGate` a
  traversé la bascule (vérifié dans le fichier). Confirmer sur l'appareil
  qu'un média reçu reste flouté avec son bouton « Télécharger » quand le mode
  est actif.
- [ ] **Groupes** (§9c, §9d, §9f) et **notifications** (§12c).

## Bascule design_v2 → production, famille 5 : accueil et envoi d'argent (2026-08-03)

- [ ] **Accueil** (§8a) : c'est l'écran d'ouverture de l'app, donc le plus vu
  de tous. Vérifier le squelette de chargement au moment d'« Élargir à
  200 km » — il doit remplacer la carte « Personne à moins de 50 km » pendant
  la recherche, jamais la laisser affichée.
- [ ] **Envoi d'argent** (§12a) : la barre de titre passe en serif plat. Le
  reste de l'écran (montant en très grand, frais, total, taux) était déjà en
  production — vérifier qu'il n'a pas bougé.
- [ ] **Accents du tunnel d'envoi** (2026-08-03) : 15 chaînes réparées —
  « Réinitialiser », « Ajouter un bénéficiaire », « Récapitulatif », « Montant
  envoyé », « Total débité », « conditions générales », « Transfert initié
  avec succès ». À relire **sur l'appareil**, aux trois étapes du parcours :
  un accent qui sort en tofu (□) ou en mojibake ne se voit pas dans le code,
  seulement au rendu. Vérifier au passage que « Récapitulatif » et « Montant
  à recevoir » tiennent toujours sur une ligne à `font_scale = 1.1` — un
  accent ajoute de la hauteur, pas de la largeur, mais les libellés
  s'allongent d'un caractère.
- [ ] **Accents du choix et de l'ajout de bénéficiaire** (2026-08-03) :
  32 chaînes de plus sur `add_recipient_screen` et `recipient_select_screen`.
  Les libellés de champs (« Numéro de téléphone \* », « Opérateur mobile \* »)
  et les messages de validation sont les plus exposés — un `labelText` trop
  long passe en ellipse sans prévenir. Vérifier aussi les trois SnackBars
  (« Bénéficiaire ajouté/modifié/supprimé avec succès »).
- [ ] **La ville reste sans accent, exprès** : « Tillaberi » dans la liste de
  `add_recipient_screen` alimente le champ `city` enregistré en base.
  Vérifier au passage qu'un bénéficiaire créé avant aujourd'hui affiche
  toujours sa ville correctement.

## Bascule design_v2 → production : la carte (§7e, 2026-08-03)

Le §7e entre en production. C'est le lot le plus testable de la session,
parce qu'il change un **comportement**, pas seulement un habillage :

- [ ] **Bascule Carte / Liste** dans l'en-tête du panneau. En mode liste la
  carte n'est **pas chargée du tout** (un aplat la remplace) : vérifier
  qu'aucune tuile ne se télécharge, et que revenir en mode carte la recharge
  correctement.
- [ ] **Démarrage en mode liste si « données réduites » est actif** dans les
  réglages. C'est le point le plus facile à casser sans le voir : couper le
  réglage, rouvrir la carte, elle doit démarrer en mode carte ; le rallumer,
  elle doit démarrer en liste.
- [ ] **Badge « tuiles allégées »** et bouton **« Plein écran »**.
- [ ] **Tri « Les plus proches » ⇄ « Par nom »**. Le tri par distance ne
  s'applique que si la position est connue — vérifier **position coupée** :
  l'ordre d'arrivée doit être conservé, pas un classement inventé.
- [ ] **Non-régression des couleurs** : les deux passes de jetons adaptatifs
  (`94d721c`, `bdcd795`) sont dans le fichier basculé. Regarder la carte en
  **thème sombre** — libellés sur l'accent, puces de rayon et de filtre
  sélectionnées, pastille de la légende.

- [ ] **Réglages de notifications** (§20d) : seul le titre de la barre a
  changé (serif, barre plate). Vérifier que les **étiquettes de section en
  chasse fixe** et le bandeau d'information sont restés tels quels — c'est
  précisément ce qu'une bascule du fichier aurait annulé.
- [ ] **Titres serif portés sans bascule** — appareils connectés (§20b),
  sauvegarde des clés (§20c), appel 1-à-1 (§23a). Dans les trois cas seul le
  titre a bougé. Ce qu'il faut vérifier est donc l'**absence** de changement
  ailleurs : les pastilles d'état (vert/orange/rouge) des appareils et des
  clés doivent rester celles des jetons adaptatifs — les regarder en **thème
  sombre**, c'est là qu'une régression se verrait.
- [ ] **Appel 1-à-1** (§23a) : le nom passe en serif blanc sur le fond
  sombre. Vérifier qu'il reste lisible **par-dessus le flux vidéo**, et
  qu'un nom long ne déborde pas à `font_scale = 1.1` — le serif est plus
  large que la fonte précédente à taille égale.

## Profil & Accueil (avant la refonte design)

- [ ] **Réalignement Profil/Accueil pré-refonte** (commit `7110929`) : 4ᵉ stat « posts », sections COMPTE/CONFIDENTIALITÉ/SÉCURITÉ/APPELS/PRÉFÉRENCES/AIDE réintroduites, `FollowsScreen`, bouton QR de l'accueil réactivé, service « Fil d'actualité » — aucune vérification device mentionnée.

## Assistant de configuration du profil

- [x] **« Terminer » ne sort pas de l'assistant** (vérifié sur SM A515F le
  2026-08-03, `lib/features/profile/presentation/screens/profile_config_screen.dart:172`).
  À l'étape 4/4, le tap est bien reçu et `_handleComplete` s'exécute, mais
  l'écran reste sur 4/4 indéfiniment. Il a fallu un `am force-stop` +
  relance pour atteindre `/home`. Deux causes enchaînées :
  - l'écriture Firestore `users/{uid}` est rejetée
    (`PERMISSION_DENIED — Missing or insufficient permissions`, visible
    uniquement dans logcat) ;
  - le cache offline de Firestore fait résoudre `updateProfile` **sans
    erreur**, donc le `catch` de `_handleComplete` ne se déclenche jamais et
    **aucun snackbar n'apparaît** — l'utilisateur n'a strictement aucun
    retour. Vérifié : trois taps consécutifs, zéro message à l'écran.
- [ ] **Remontée des échecs Firestore à l'UI** (correctif du 2026-08-03,
  `profile_remote_datasource.dart` + les deux `profile_config_screen.dart` et
  `settings_screen.dart`) — **non vérifié sur appareil**, la validation
  demande une réinstallation. Trois cas à couvrir :
  - **refus serveur** (le cas actuel, `PERMISSION_DENIED`) : « Terminer »
    doit maintenant afficher un snackbar rouge avec action « Réessayer », et
    l'assistant **ne doit pas** se marquer comme terminé ;
  - **hors ligne** : aucun message d'erreur ne doit apparaître — l'écriture
    est en file d'attente, ce n'est pas un échec. ⚠️ le VPN persistant du
    téléphone rend ce cas difficile à provoquer (cf. bas de page) ;
  - **cas nominal** : l'enregistrement doit rester fluide, sans latence
    ajoutée perceptible (une lecture serveur supplémentaire a été ajoutée
    après chaque écriture de profil).
- [ ] **Persistance des valeurs saisies dans l'assistant** : après la
  relance, l'accueil affiche toujours « Complétez votre profil 2/5 » et
  « Ajouter ma ville » — les champs de l'assistant (nom, pays/ville,
  centres d'intérêt) ne semblent pas avoir été enregistrés côté serveur, ce
  qui est cohérent avec le `PERMISSION_DENIED` ci-dessus. À revérifier une
  fois le rejet Firestore corrigé.
- [ ] **Étape 3/4 « Choisissez-en au moins deux »** : le bouton « Suivant »
  reste actif et laisse passer avec « Aucun sélectionné ». Soit la contrainte
  est réelle et il faut la faire respecter, soit la copie est fausse.

---

## Discussion en paysage — débordement de 4,1 px (vu le 2026-08-05)

- [ ] ⛔ **Débordement bas sur l'écran de conversation en PAYSAGE.** Constaté
  **deux fois** sur SM A515F le 2026-08-05, avec deux ampleurs différentes :

  | Capture | Bas de l'écran occupé par | Débordement |
  |---|---|---|
  | 1 | panneau GIF / Émojis | `4.1 PIXELS` |
  | 2 | **clavier système** | `17 PIXELS` |

  Le second cas est le plus instructif : **ce n'est pas le panneau ancré qui
  est en cause**, puisque le défaut se produit aussi avec le clavier seul.
  C'est l'écran de conversation en paysage dès que l'espace vertical restant
  se réduit — et l'ampleur suit la hauteur de ce qui occupe le bas.

  Piste : en paysage, la hauteur disponible entre l'en-tête (avatar + nom +
  bandeau de message épinglé + bandeau « Restaurez vos clés ») et l'insert du
  bas ne suffit plus. Sur la capture 2, le bandeau rayé passe **juste sous le
  bandeau de restauration des clés**, ce qui désigne cette zone — mais
  attention, le bandeau signale une **position**, pas forcément le widget
  fautif.

  **Diagnostic fait, correctif écrit puis annulé (2026-08-05).** L'`Expanded`
  de la colonne extérieure ne peut pas déborder : le dépassement vient
  forcément des enfants **non flexibles**, c'est-à-dire les bandeaux. En
  paysage clavier ouvert il reste ~150 dp sous l'en-tête, et le bandeau
  épinglé plus le rappel de restauration des clés dépassent à eux seuls cette
  hauteur. Ça explique les deux ampleurs : le panneau émojis est plus court
  que le clavier, donc 4 px au lieu de 17.

  Correctif retenu : envelopper la colonne extérieure de `conversation_screen`
  dans un `LayoutBuilder` — seul moyen fiable de connaître la hauteur
  restante, `MediaQuery.viewInsets` valant 0 dans un `body` de `Scaffold` — et
  escamoter le rappel de restauration sous ~220 dp. Le bandeau épinglé, lui,
  reste toujours visible : c'est sa raison d'être.

  ⚠️ **LE CORRECTIF EST DANS LE CODE, MAIS PAS SOUS SON PROPRE COMMIT.**

  Il a été livré le 2026-08-06 à l'intérieur de
  **`af3485b fix(groupes): garde « Officiel » appliquée, et le REVOKE qui n'y
  servait à rien`** — un commit dont le message ne dit pas un mot du
  débordement. Il y est arrivé emporté : la version était dans l'index quand
  ce commit a été fait, sur une branche partagée avec un autre agent.

  Donc : `git log` sur ce fichier **ne mènera pas** au débordement en paysage.
  C'est cette entrée qui fait le lien. Chercher `zoneCorps` ou
  `placeRappelCles` dans `conversation_screen.dart` pour trouver le code.

  **Deux choses à savoir en le relisant :**

  - *L'indentation est volontairement fausse.* Les ~424 enfants de la colonne
    gardent leur indentation d'origine. Les réindenter aurait réécrit des
    centaines de lignes en cours de modification par ailleurs, et rendu la
    fusion ingérable ; sans réindentation, le correctif ne touche que trois
    lignes (1229, 1289, 1653), toutes hors des zones modifiées. **À passer au
    formateur quand le fichier sera libre** — le fichier n'est de toute façon
    pas conforme à `dart format`, même avant ce changement.
  - *Un correctif voisin existe peut-être.* Un « zone BORNEE » qui borne le
    composeur, et non les bandeaux, était en cours à côté. S'il a atterri
    depuis, une partie du symptôme a pu disparaître autrement.

### ⚠️ Vérifié sur appareil le 2026-08-06 — le correctif marche, il ne suffit pas

Build de HEAD installé sur SM A515F, conversation « Salim L. » (bandeau des
clés actif, brouillon de 3 lignes), rotation forcée en paysage.

| Situation | Bandeau des clés | Débordement |
|---|---|---|
| Paysage, **sans** clavier | visible | aucun |
| Paysage, **clavier levé** | **escamoté** ✅ | **`BOTTOM OVERFLOWED BY 73 PIXELS`** ❌ |

**Ce qui est prouvé** : le mécanisme fonctionne. `placeRappelCles` bascule
bien à faux quand la hauteur tombe — le bandeau est visible sans clavier,
escamoté avec. Le `LayoutBuilder` mesure ce qu'il faut.

**Ce qui est infirmé** : mon diagnostic était **incomplet**. Je pensais que
les deux bandeaux étaient la seule cause. Une fois le rappel des clés retiré,
c'est le **composeur** qui déborde à son tour — et de bien plus : 73 px ici,
contre 17 px avant correctif. L'ampleur suit la longueur du brouillon, ce qui
désigne le composeur sans ambiguïté.

**Ce qui manque donc** : borner le composeur, c'est-à-dire exactement ce que
vise le correctif « zone BORNEE » — qui n'était PAS dans ce build, puisque
j'ai construit HEAD et qu'il vivait encore dans un WIP non committé. Les deux
correctifs sont complémentaires, pas redondants : le mien retire les bandeaux
de l'équation, l'autre empêche le composeur de prendre sa taille naturelle.

**Pourquoi le reste ne peut PAS se corriger dans le composeur** (vérifié le
2026-08-06, pour éviter que quelqu'un le retente) : `message_input.dart` sait
déjà se rétrécir — `maxLignes = (borne / 2 / 22).floor().clamp(1, 6)`, et ses
panneaux passent en `Flexible`. Mais tout est conditionné à `borne.isFinite`,
et personne ne le borne : `RenderFlex` donne `maxHeight: Infinity` à ses
enfants non flexibles. Le garde-fou dort donc en production, ce que le
fichier documente lui-même.

Le calculer depuis la fenêtre plutôt que depuis les contraintes ne suffit
pas : on obtient ~194 dp en paysage clavier levé, donc 4 lignes autorisées,
alors que le brouillon qui déborde en fait 3. Ce qu'il faut, c'est la hauteur
restante **sous les bandeaux** — seul le parent la connaît. D'où la
conclusion, déjà écrite dans `message_input.dart` : le correctif appartient à
`conversation_screen`, pas au composeur.

- [ ] **Refaire ce test une fois « zone BORNEE » committé** — c'est la
  combinaison des deux qu'il faut mesurer, pas l'un ou l'autre.
- [ ] **Cas du panneau GIF/Émojis** (le 4 px d'origine) : non testé ici, le
  clavier ayant suffi à montrer que le problème subsistait.
- [ ] Si le débordement persiste même avec les deux, chercher plus bas : le
  bandeau épinglé et l'en-tête ne sont pas escamotables, et en paysage
  clavier levé il ne reste qu'une centaine de dp au total.

  Non lié aux correctifs de localisation de cette session.

---

## Blocage, sens inverse — RLS prouvée en base (2026-08-06)

Le sens « qui m'a bloqué » n'a jamais fonctionné : `blockUser` écrit bien
`blockedByUserIds` sur la cible, mais dans Firestore, alors que les profils
viennent de Supabase où `_mapProfile` code ce champ en dur à `[]`. Et les dix
sites de lecture testaient en plus la **mauvaise direction** — sauf
`conversation_screen`, seul à avoir le bon sens.

La politique RLS était le vrai verrou : `blocked_users_own` en `ALL` sur
`firebase_uid() = blocker_id` ne laissait lire que les lignes où l'on est le
**bloqueur**. La recherche inverse échouait **en silence** — requête réussie,
zéro ligne. Corrigé par la migration `20260806120000`.

✅ **Prouvé en base**, en simulant les trois identités via
`request.jwt.claims` (ce que lit `firebase_uid()`), chaque essai dans une
transaction annulée :

| Qui interroge | Lignes vues | Attendu |
|---|:--:|---|
| La personne **bloquée** (Sim A) | **1** | le sens qui était cassé |
| Un **tiers** quelconque | **0** | contrôle négatif |
| Le **bloqueur** (Salim L.) | **1** | le sens qui marchait déjà |

Sans le contrôle négatif, le premier résultat n'aurait rien voulu dire : une
politique trop permissive aurait donné 1 aussi. Table laissée à zéro ligne.

✅ **La livraison temps réel jusqu'à l'UI est vue à l'écran** (2026-08-06).
Blocage inséré en base pendant que la conversation était ouverte : quelques
secondes plus tard, la ligne « Vu il y a 4 heures » avait **disparu** de
l'en-tête. C'est `online_status_indicator` qui a réagi au provider. La chaîne
`blocked_users` → realtime → `usersWhoBlockedMeProvider` → UI fonctionne.
Blocage retiré aussitôt, table revenue à zéro ligne.

⚠️ **Correction d'une description fausse écrite plus haut dans ce fichier.**
Une version précédente de ce point disait « le composeur se ferme ». **C'est
faux**, et la capture l'a montré : `isBlockedByOther` ne masque pas le
composeur. Le champ de saisie reste visible et éditable ; ce sont les
**actions** qui sont refusées (six branches, toutes dans des gestionnaires
d'envoi, pas dans le rendu). Ce qui masque le composeur, c'est `isBlocked` —
l'autre sens, quand c'est *vous* qui avez bloqué.

Ne pas chercher un composeur qui disparaît : il ne disparaîtra pas.

- [ ] **Ce qui reste à vérifier : le refus effectif de l'envoi.** Conversation
  ouverte avec un compte qui vous a bloqué, taper un message, appuyer sur
  envoyer — l'envoi doit être refusé avec un message, et rien ne doit partir.
  C'est le seul maillon non prouvé de toute la chaîne.
  *Deux tentatives ont échoué non sur le code mais sur l'appareil : l'app est
  passée en arrière-plan au moment du tap. Aucun plantage — process vivant,
  ni `FATAL`, ni exception Dart, ni mise à mort `lmkd`.*
- [ ] **Vérifier aussi la carte, l'accueil et les notifications** sous
  blocage : la personne doit disparaître des quatre.
- [ ] **Débloquer** et vérifier que tout revient — la table est publiée en
  realtime avec `REPLICA IDENTITY FULL` précisément pour que la suppression
  soit livrée ; sans ça le déblocage n'aurait pris effet qu'au relancement.

---

## Podcasts — 5 écrans passés au système DN (2026-08-04)

`lib/design_v2/` a été supprimé. Avant de le retirer, cinq écrans podcasts
y portaient une migration vers le système de couleurs DN qui n'avait jamais
été rebasculée, et qui n'était visible nulle part (fichiers orphelins, hors
galerie). Ils ont été repris dans `features/podcasts/presentation/screens/`.

**Leur apparence change** : titres en serif `DNText.serif(22)`, barre du haut
à plat sur `context.dn.surface`, icônes et textes sur les jetons `context.dn`
au lieu de `Theme.of(context)` brut. Aucun changement fonctionnel — la
migration ne touchait que des couleurs et des styles de texte.

- [ ] **Accueil podcasts** (`podcasts_home_screen.dart`) : titre serif, barre
  de recherche, listes — en clair **et** en nocturne.
- [ ] **Mes podcasts** (`my_podcasts_screen.dart`) : titre serif, état vide
  (icône 80 sur `onSurface4`), boutons « + ».
- [ ] **Fiche podcast** (`podcast_detail_screen.dart`) : en-tête, bouton
  d'abonnement — sa couleur suit **l'accent du compte**, pas le terracotta.
- [ ] **Statistiques** (`podcast_stats_screen.dart`) : cartes de stats et
  barre de progression (accent du compte également).
- [ ] **Enregistrer un épisode** (`record_episode_screen.dart`) : barre du
  haut, sélecteur audio/vidéo, bouton « Brouillon » toujours présent.
- [ ] ⚠️ **Vérifier le nocturne en priorité** : `context.dn` gère les deux
  thèmes, mais ces cinq écrans n'ont jamais été vus en nocturne sur appareil.

**Écart volontaire par rapport à la copie `design_v2`** : elle figeait deux
couleurs sur `DNColors.terra` (constante `0xFFC85A3A`), là où `features/`
suivait `colorScheme.primary`. La version adaptative a été conservée — le
terracotta en dur aurait cassé l'accent choisi par le compte. Si la maquette
veut vraiment du terracotta fixe à ces deux endroits, c'est à rétablir
explicitement (fiche podcast ligne 368, statistiques ligne 388).

---

## Carte — délai d'affichage des membres autour (2026-08-04)

`map_screen.dart` : trois changements qui ne se voient que sur un vrai GPS et
un vrai cache d'images, `flutter analyze` n'en dit rien.

- [ ] **Ouverture à froid de la carte** : la dernière position connue doit
  peupler la carte **tout de suite** (marqueur rouge + liste des membres),
  sans attendre le point GPS frais. Mesurer le délai entre le tap sur
  l'onglet Carte et le premier pin visible — avant, le spinner tenait 3 à
  15 s. Refaire l'essai après `adb shell am force-stop` pour être sûr que
  le cache de position est bien froid.
- [ ] **Première ouverture après installation** (aucune position connue) :
  vérifier que le spinner reste puis cède la place à la carte normale, et
  **pas** au bandeau « accès restreint par réciprocité ».
- [ ] **GPS coupé pendant que la carte est ouverte** : le bandeau de
  restriction ne doit apparaître que si aucune position n'a jamais été
  obtenue ; sinon la carte garde la dernière position et continue le suivi.
- [ ] **Pins générés en parallèle** : avec plusieurs membres autour et le
  cache d'avatars vidé (réinstallation), tous les pins doivent apparaître
  d'un coup après ~3 s max, pas un par un.

- [ ] **Accueil, section « membres autour »** (même correctif que la carte,
  `home_screen.dart`) : au lancement à froid, la section doit se remplir dès
  la dernière position connue, sans attendre le point GPS. Et si le GPS
  n'aboutit pas alors qu'une position connue existait, **aucun** message
  d'erreur de localisation ne doit s'afficher.

### Temps réel des positions (nécessite **deux** comptes)

Ces points ne se vérifient qu'avec deux téléphones (ou un téléphone + un
compte piloté depuis le SQL Supabase, en modifiant `latitude`/`longitude`/
`location_updated_at` de la ligne `users`).

⚠️ **Pourquoi « 0 membres autour » sur le compte de test, et ce n'est pas un
bug de code.** Relevé le 2026-08-05 : seuls **deux** comptes partagent leur
position, et un seul est exploitable.

| Compte | `share_location` | Position |
|---|---|---|
| Sim A (`vQZE49dT…`) | `true` | 45.58028 / −73.64590 |
| Salim L. (`U64HKfrj…`) | `true` *(mis à `true` en SQL le 2026-08-05 ; était `false`)* | 45.58028 / −73.64599 |

Les deux comptes sont à ~10 m l'un de l'autre. `getNearbyProfiles` filtre sur
`.eq('share_location', true)` : « Salim L. » était écarté à la source, et
« Sim A » est retiré par l'auto-exclusion — il ne restait personne.

### ↩️ Compte restauré le 2026-08-05 — à re-préparer avant tout nouveau test

Le maquillage décrit ci-dessous **a été défait** : « Salim L. » est revenu à
`share_location = false`, position `45.5802795 / -73.6459928`,
`location_updated_at = 2026-08-04 18:32:45+00`, `is_online = false`. Plus
aucune fausse donnée en base. Pour retester, rejouer la préparation :

```sql
update users
   set share_location = true,
       latitude  = 45.5980,
       longitude = -73.6459,
       is_online = true,
       last_seen_at = now(),
       show_online_status = true
 where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';
```

### État préparé le 2026-08-05 (défait depuis, voir ci-dessus)

Le compte « Salim L. » a été **maquillé en membre voisin présent**, en SQL,
pour pouvoir tester avec un seul téléphone. Vérifié : il passe la requête de
proximité **et** le filtre de présence, à **1,97 km** du compte principal.

## Réglages/Carte — deux interrupteurs de partage de position désynchronisés (2026-08-13)

Signalé : « j'arrive pas à localiser certains users ». Diagnostic en base
(projet Supabase lié `Diapo Niger`) : sur 10 comptes, seuls 2 avaient
`share_location = true`, et un seul de ceux-là avait une position (l'autre,
« Ibrahim Yacouba Maïdaoua », avait activé « Ma localisation » dans Réglages
sans jamais avoir ouvert la carte pour activer son calque « Membres » — le
seul chemin qui déclenchait `LocationPublisherService`).

Cause : `share_location` (écrit par Réglages/Profil, `profile_preferences_provider.dart`)
et `nearbyMembersEnabled` (préférence locale du calque « Membres » de la
carte, `map_screen.dart`) sont deux réglages distincts qui devraient être un
seul. `LocationPublisherService.start()` ne se fiait qu'au second.

Corrigé (`lib/core/services/location_publisher_service.dart`,
`lib/features/profile/presentation/providers/profile_preferences_provider.dart`) :
`start()` relit désormais `share_location` depuis le profil serveur à chaque
démarrage (auto-guérison des comptes déjà désynchronisés, sans action de leur
part), et `ProfilePreferences.set` déclenche `start()`/`stop()` immédiatement
quand on bascule « Ma localisation ». Le calque « Membres » de la carte reste
inchangé (c'est un filtre d'affichage, pas un consentement).

**Rien de ceci n'est vérifiable par `flutter analyze`/`flutter test` seuls**
(permission GPS réelle, cycle de vie `resumed`/`paused` de l'app) :

- [ ] Activer « Ma localisation » dans Réglages **sans jamais ouvrir la
  carte** : vérifier en base que `latitude`/`longitude`/`location_updated_at`
  se peuplent dans les secondes qui suivent (permission GPS déjà accordée).
- [ ] Désactiver « Ma localisation » dans Réglages, app au premier plan :
  vérifier que `location_updated_at` cesse d'avancer (pas de battement de
  cœur résiduel).
- [ ] Mettre l'app en arrière-plan puis la ressortir plusieurs fois de suite
  (volet de notifications, `inactive` transitoire) avec le partage désactivé :
  vérifier dans les logs qu'aucune requête profil réseau superflue n'est
  déclenchée à chaque aller-retour (le garde `_positionSubscription != null`
  doit court-circuiter).
- [ ] Compte préexistant en base avec `share_location = true` mais sans
  position (reproduire l'état d'Ibrahim) : relancer l'app et vérifier
  l'auto-guérison, sans toucher à aucun réglage.

## Onboarding — les drapeaux lisaient Firestore au lieu de Supabase (2026-08-13)

Repéré en corrigeant le point ci-dessus : `hasSeenOnboarding`,
`hasSeenCoachMarks`, `hasGivenConsent`, `hasCompletedProfileConfig`
(`OnboardingRemoteDataSourceImpl`) lisaient/écrivaient `users/{uid}` sur
**Cloud Firestore** — un reliquat pré-Supabase que rien d'autre dans l'app ne
touche. L'étage « serveur » de l'onboarding ne servait donc à rien : seul le
drapeau local (`OnboardingLocalDataSourceImpl`, effacé à chaque
réinstallation) faisait foi, d'où l'assistant de configuration de profil qui
revient à chaque réinstall même quand le profil réel est déjà complet.

Corrigé : `OnboardingRemoteDataSourceImpl` lit/écrit maintenant les colonnes
`has_seen_onboarding` / `has_seen_coach_marks` / `has_given_consent` /
`consent_date` / `profile_config_complete` sur `public.users` (Supabase) — ces
colonnes existaient déjà en production, jamais suivies en migration
(`20260813235500_document_onboarding_flags_drift.sql` corrige la dérive).

**Non vérifiable par `flutter analyze`/`flutter test` seuls** — nécessite un
vrai cycle désinstall/réinstall :

- [ ] Compte avec profil déjà complété : désinstaller puis réinstaller l'app
  (signature identique, sinon `INSTALL_FAILED_UPDATE_INCOMPATIBLE`) →
  l'assistant de configuration de profil en 4 étapes ne doit **pas**
  réapparaître, puisque `profile_config_complete = true` est lu depuis
  Supabase dès la case locale absente.
- [ ] Même vérification pour l'écran de consentement (`hasGivenConsent`) et
  les coach marks.

| Colonne | Valeur d'origine | Valeur posée |
|---|---|---|
| `share_location` | `false` | `true` |
| `latitude` | `45.5802795` | `45.5980` |
| `longitude` | `-73.6459928` | `-73.6459` |
| `location_updated_at` | `2026-08-04 18:32:45.536012+00` | `2026-08-05 22:53:53+00` |
| `is_online` | `false` | `true` |
| `last_seen_at` | — | `2026-08-05 22:55:06+00` |
| `show_online_status` | — | `true` |

⏳ **La présence tient une heure**, via la seconde porte du filtre
(`is_online` + `last_seen_at` de moins d'une heure). Passé ce délai, rejouer
`update users set last_seen_at = now() where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';`
La première porte (`location_updated_at` < 5 min) est trop courte pour un
test manuel.

✅ **La carte a été ouverte et elle fonctionne** (2026-08-05, SM A515F,
capture `09_carte_t7`). Sept secondes après le tap sur l'onglet Carte :
tuiles en style nocturne, marqueur rouge « vous êtes ici », **pin « SL » à
initiales avec pastille verte**, panneau « **1 membre autour · 50 km** »
(« À l'instant / À l'instant »), et la ligne « Salim L. — 2,0 km · en ligne ».
Toute la chaîne passe : requête → filtre de présence → génération des pins →
liste. La distance affichée (2,0 km) correspond au calcul serveur (1,97 km).

⚠️ **Correction** : une note antérieure affirmait que « Membres à proximité »
était désactivé sur le compte principal, déduit de la ligne « Activer la
carte des membres » de l'accueil. **C'est faux** — cette ligne est un élément
de la liste d'amorçage « Pour commencer », pas l'état du réglage. La preuve
que la préférence est à `true` : `LocationPublisherService.start()` et
`_publish()` sortent tous deux immédiatement quand elle est fausse, or la
position du compte principal est réécrite toutes les deux minutes.

**Pour tout remettre en état après le test** :

```sql
update users
   set share_location = false,
       latitude  = 45.5802795,
       longitude = -73.6459928,
       location_updated_at = '2026-08-04 18:32:45.536012+00',
       is_online = false
 where id = 'U64HKfrjM5NwR6HO00XPKo6168z2';
```

⚠️ `share_location` est la colonne **serveur**. Si l'app tourne sur le second
compte et enregistre son profil, elle peut la réécrire depuis son état local
— revérifier la colonne après coup (même piège que l'interrupteur push, voir
`CLAUDE.md`, « Réglages : une seule source »).

✅ **Préconditions serveur du temps réel vérifiées au distant** (2026-08-05,
`supabase db query --linked` — pas le fichier de migration, la base réelle) :

| Contrôle | Résultat |
|---|---|
| `users` dans la publication `supabase_realtime` | ✅ présente |
| `pg_class.relreplident` sur `users` | ✅ `f` (FULL) |
| Politique RLS SELECT | `((NOT is_private) OR is_admin() OR (firebase_uid() = id))` |

La politique laisse lire **toute ligne non privée**, donc le canal livrera
bien les `UPDATE` des *autres* membres — et pas seulement les siens, ce qui
aurait tué la fonctionnalité en silence. Confirmé de fait : la carte a
affiché « Salim L. », donc sa ligne passe cette politique, et le realtime
applique exactement la même.

Il ne reste donc à prouver que le **bout client** : que le pin bouge sans
attendre le sondage.

- [x] **Déplacement visible sans attendre le sondage** ✅ **PROUVÉ le
  2026-08-05** sur SM A515F (captures `12_avant` / `13_apres`).

  Protocole : carte ouverte et immobile, `update users set latitude=45.6200,
  longitude=-73.6459` sur « Salim L. », validé à `23:10:12.650 UTC`, capture
  à `23:10:18.325 UTC` — **5,7 s après**.

  | | Avant | Après |
  |---|---|---|
  | Pin « SL » | ouest-sud-ouest | remonté au nord |
  | Ligne de liste | « 3,2 km » | « **4,4 km** » |
  | Fraîcheur de l'en-tête | « Il y a 24 s » | « **À l'instant** » |

  La distance affichée correspond au calcul pour la nouvelle position
  (4,41 km). **Le sondage est exclu par l'arithmétique** : il datait de 24 s
  avant la capture « avant », donc le suivant tombait vers `23:10:34` — le
  changement était à l'écran 16 s plus tôt. Et « À l'instant » prouve que
  `_lastMembersUpdate` a été réécrit, ce que fait `_onMemberLocationUpdate`.

  Le canal `users_location_updates` fonctionne donc de bout en bout :
  publication Postgres → RLS → websocket → `_onMemberLocationUpdate` →
  marqueurs et liste.
- [x] **Sortie de rayon — le verdict est prouvé, en test Dart** ✅
  (2026-08-05, `test/features/map/nearby_member_filter_test.dart`, 20 cas).

  La décision a été extraite dans `lib/features/map/domain/nearby_member_filter.dart`
  précisément pour ça. Les huit cas de la branche de retrait couvrent le
  déplacement à 230 km joué cinq fois sur l'appareil sans jamais pouvoir être
  observé, les deux bords à ±0,02 degré du seuil, le partage coupé, le profil
  devenu invisible et les coordonnées absentes.

  **Ce que ça ne prouve pas** : que le pin disparaisse *visuellement*. Le
  trajet websocket → `_onMemberLocationUpdate` est prouvé sur appareil (voir
  ci-dessus), et le verdict est prouvé ici ; reste le rendu, c'est-à-dire
  `setState` + `_updateMarkers`, qui est le même code que pour l'ajout — déjà
  vu fonctionner à l'écran. Le risque résiduel est faible mais non nul.

- [ ] **Sortie de rayon, confirmation visuelle** (facultatif) : si l'occasion
  se présente — téléphone franchement au repos, carte ouverte — refaire le
  protocole en une seule commande. Ne pas y consacrer d'effort dédié : le
  rapport entre le coût et ce qui reste inconnu ne le justifie plus.
  ⏸️ **Cinq tentatives, aucune concluante (2026-08-05).** À chaque fois le
  déplacement SQL est parti, mais l'écran avait changé avant la capture :
  conversation, Réglages, écran de démarrage après un redémarrage de l'app,
  Notifications. La cause n'est pas le correctif — c'est que le téléphone
  était utilisé, et qu'un build debug avec Google Maps se fait tuer par
  `lmkd` (215 Mo libres sur 5,7 Go relevés pendant la session).

  **Ne pas se contenter de relancer le même protocole.** Deux voies plus
  sûres : soit un moment où le téléphone est franchement au repos, carte
  ouverte, en enchaînant `UPDATE` et `screencap` dans **une seule** commande
  (en deux appels séparés l'écart monte à ~23 s et ne prouve plus rien) ;
  soit un test Dart sur la branche `!keep` de `_onMemberLocationUpdate`, ce
  qui suppose d'extraire la décision `keep` dans une fonction testable —
  aujourd'hui elle lit `ref` et `FirebaseAuth`.

  C'est la seule branche du temps réel non vérifiée : celle qui **retire**
  une ligne. L'ajout et la mise à jour sont prouvés (voir ci-dessus).
- [x] **Position publiée hors de l'écran carte** ✅ **vérifié le 2026-08-05**
  sur SM A515F, côté données. L'app était sur un écran de **conversation**
  (jamais sur la carte) et `users.location_updated_at` du compte « Sim A »
  avançait quand même : `22:37:28` → `22:39:28` → `22:42:23` UTC, relevé par
  `supabase db query --linked`. Avant le correctif, cet horodatage ne bougeait
  que pendant que l'écran carte était ouvert.
- [x] **Membre immobile toujours visible** ✅ **vérifié le 2026-08-05** par la
  même mesure : le téléphone n'a pas bougé, et le battement de cœur de 2 min
  réécrit quand même `location_updated_at`. La ligne reste donc dans la
  fenêtre de fraîcheur de 5 minutes du filtre de présence. (Reste à confirmer
  visuellement, sur la carte d'un second compte.)
- [ ] **Retour d'arrière-plan** : A met l'app en arrière-plan puis revient —
  le canal temps réel doit se reprendre (vérifier qu'un déplacement de B est
  de nouveau vu tout de suite, et pas seulement au sondage).
- [ ] **Coupure du réglage** : A désactive « Membres à proximité » →
  l'app cesse d'écrire sa position (vérifier que `location_updated_at` de A
  ne bouge plus dans Supabase).
- [ ] ⛔ **Suivi en arrière-plan → Supabase** : le service de fond écrivait
  dans Firestore, la carte lit Supabase — ses mises à jour n'arrivaient donc
  jamais. Activer le suivi en arrière-plan, fermer l'app, se déplacer, et
  vérifier dans Supabase que `users.latitude` / `location_updated_at` de A
  bougent bien. Surveiller aussi logcat : `Background Location: Supabase
  indisponible` signale que l'isolate n'a pas pu initialiser son client (le
  `.env` n'est peut-être pas lisible depuis l'isolate d'arrière-plan).
- [ ] **Pas de double session Supabase** : après un tour de suivi en fond,
  vérifier que la session du premier plan tient toujours (aucun 401 dans
  logcat, les messages arrivent encore). L'isolate utilise une clé de session
  distincte (`supabase.background.session`) précisément pour ça.

---

## Zone de saisie des messages — barre multi-ligne (2026-08-04)

`lib/features/messages/presentation/widgets/message_input.dart`. Le champ
passait de `maxLines: 1` à `minLines: 1 / maxLines: 6`, plus trois correctifs
d'état et un alignement de couleurs. Le composer sert les **trois** cas depuis
le même écran (1-à-1, groupe, « Mes notes ») : tester au moins deux d'entre eux.
`flutter analyze` et les 7 tests de `message_input_composer_test.dart` passent.

**Passe appareil du 2026-08-04 (23:29 → 23:37), SM A515F, APK debug `6498773`,
thème sombre, font_scale 1.1, conversation « Mes notes ».** ⚠ Une session
concurrente a réinstallé l'app à **23:38:08** (`Killing … due to
installPackageLI`) : tout constat postérieur à cette heure a été jeté.

- [x] **Croissance de la barre** — vérifié. 1 ligne → 6 lignes, la barre monte
  ligne après ligne ; à 12 lignes elle a **exactement la même hauteur** qu'à 6 et
  affiche L7–L12, donc le champ défile en interne en suivant le curseur. Le
  « + » et l'emoji restent collés en bas, le bouton rond ne bouge pas.
  Mesures au banc de test (échelle 1.0) : 23 px par ligne, plafond 162 px pour
  le champ / 190 px pour le composer.
- [x] **Retour à la ligne** — vérifié au `keyevent 66`. Entrée insère bien un
  saut de ligne et **n'envoie pas** (aucun message n'est parti dans la
  conversation). Reste à confirmer avec un **clavier physique**.
- [x] **Rendu en nocturne** à 6 lignes : la pilule reste une carte aux coins
  arrondis lisible, pas un rectangle mou. Rien à redire.
- [x] **Le panneau pièces jointes se ferme au clavier** — vérifié. « + » →
  grille ouverte, `mInputShown=false`, glyphe en « × » ; tap sur le champ →
  grille disparue, `mInputShown=true`, retour au « + ». Le bug est corrigé.
- [x] ⚠ **Débordement au « + » — trouvé par Salim, que mes captures avaient
  manqué, corrigé.** Symptôme : champ sur plusieurs lignes, appui sur « + », et
  l'overflow apparaît **au moment où le clavier disparaît**. Mes cinq captures
  ne le montraient pas parce qu'elles étaient prises dans « Mes notes », qui n'a
  presque pas de chrome fixe — le bug demande une conversation chargée.
  Mécanisme : `_toggleAttachPanel` baisse le clavier **puis insère le panneau
  aussitôt** ; pendant les ~250 ms de repli, l'inset du clavier vaut encore sa
  pleine valeur *et* le panneau est déjà dans la colonne. Avec la chrome de la
  conversation 1-à-1 (bandeau épinglé + chips Médias/ÉCO + bandeau de clés
  ≈ 240 dp) et le champ à 6 lignes : `RenderFlex overflowed by 85 pixels`,
  reproduit au banc. Le passage au multi-ligne n'a pas créé le défaut, il a
  rendu le composer assez haut pour qu'une mise en page déjà juste bascule.
  Correctif : les panneaux (pièces jointes **et** emoji) prennent désormais *la
  place* du clavier — leur fraction visible suit son retrait, donc la hauteur
  totale ne varie jamais. Piège au passage : `MediaQuery.viewInsets.bottom` vaut
  déjà 0 dans le `body` d'un `Scaffold` (il l'a consommé pour rétrécir) ; il
  faut lire `View.of(context).viewInsets`. Couvert par le 8ᵉ test du fichier.
  **Vérifié sur appareil le 2026-08-05 (06:07 → 06:12), thème clair, APK
  `2fe9240` bâti depuis un worktree isolé.** Conversation « Salim L. » (celle
  qui a toute la chrome), champ à 6 lignes, appui sur « + » : la frame
  transitoire montre le clavier qui descend, le panneau pas encore révélé et le
  composer stable — **aucune bannière rayée**, et zéro `RenderFlex … overflowed`
  dans le tampon. Trois cycles ouverture/fermeture d'affilée : le panneau
  s'affiche les trois fois.
- [x] ⚠ **Régression intermédiaire — le panneau ne s'affichait plus DU TOUT.**
  Signalée par Salim (« le modal du + ne s'affiche pas ») sur le premier
  correctif. Cause : le créneau clavier lit `View.of(context).viewInsets` pour
  contourner le `Scaffold`, mais **cette lecture ne crée aucune dépendance** —
  rien ne redemandait de build quand le clavier finissait de se replier, donc la
  fraction visible restait à 0. Le panneau n'apparaissait que si un autre
  `setState` (flux de messages) passait par là au bon moment : d'où
  l'intermittence, et d'où ma capture faussement rassurante. Corrigé par un
  `WidgetsBindingObserver` (`didChangeMetrics` → redessin tant qu'un panneau est
  ouvert). **Leçon** : une capture unique ne distingue pas « ça marche » de
  « ça a marché cette fois-ci » — pour tout ce qui dépend d'une animation, faire
  au moins trois cycles.
- [x] **Aucun autre débordement** à font_scale 1.1 : aucune bannière rayée
  jaune/noir sur les cinq captures (1 ligne, 6, 12, panneau ouvert, panneau
  fermé), et zéro `RenderFlex … overflowed by` dans le tampon logcat. ⚠ Le
  logcat seul ne suffit pas à conclure (Crashlytics remplace
  `FlutterError.onError`, cf. fiche « erreurs Flutter silencieuses ») — et le
  cas ci-dessus prouve qu'une capture sur le mauvais écran ne prouve rien non
  plus.
- [x] **Brouillon restauré** : à l'ouverture de « Mes notes », le brouillon
  laissé s'affiche déjà sur 2 lignes **et** le bouton est en mode envoi (bleu +
  cadenas) sans toucher au champ.
- [ ] **Brouillon tapé puis sortie immédiate** : taper quelques caractères et
  quitter l'écran **en moins d'une demi-seconde**. Au retour, le texte complet
  doit être là (la fin était perdue jusqu'ici). Non testé sur appareil — couvert
  seulement par un test unitaire. Deux tentatives abandonnées (voir plus bas).
- [x] **Compteur de caractères** — vérifié sur la seconde passe (2026-08-05,
  00:55 → 00:59, APK debug installé à 23:55:57). Pastille « 204 / 2000 » puis
  « 224 / 2000 » en bas à droite **dans** la pilule, sur le fond neutre
  `surfaceVariant`, la barre étant à son plafond de 6 lignes. Reste à voir
  l'orange (sous 100 restants) et le rouge (à 2000), non atteints.
- [x] **La barre redescend** : en effaçant, elle repasse de 6 lignes à 1 sans
  saut ni scintillement.

⚠ **Deux passes perdues, même cause : l'appareil n'était pas à moi seul.**
Une session concurrente a réinstallé l'app à 23:38:08 en plein test, puis
quelqu'un a utilisé le téléphone au doigt vers 00:19 (message « test pour
verifier 9c et 9d » envoyé dans Mes notes). S'ajoute un redémarrage du process
à 23:59:49 **sans crash** — pas de `FATAL EXCEPTION`, pas d'ANR, mais une
cascade de reclaim mémoire dans la même minute (Facebook, Samsung Pass, Play
Store, keychain tués aussi). C'est la pression mémoire du A51 déjà documentée.
Réflexe confirmé : relever `lastUpdateTime` **et** l'heure des captures avant
de conclure quoi que ce soit.
- [ ] ⚠ **Non-régression prioritaire — gestes vocaux.** Le bouton d'action doit
  rester dans l'arbre en permanence pour que le push-to-talk fonctionne :
  appui long → enregistrement, glisser à gauche → annulation, glisser vers le
  haut → verrouillage. Rien dans ce lot ne le démonte, mais c'est le premier
  point à retester.
- [ ] **Sheet de repli (appui long sur « + »)** : la section « Caméra » en
  doublon a été supprimée (Photo/Vidéo dédiées, redondantes avec la tuile
  Caméra unifiée). Vérifier qu'il ne manque rien d'utile, et que les tuiles
  suivent maintenant le code couleur du panneau ancré — médias en accent
  primaire, Position/Sondage/Événement en secondaire (fini le violet, l'orange
  et le bleu Material bruts).
- [ ] **Bandeau d'enregistrement en nocturne** : le rouge d'annulation passe par
  `errorColor` au lieu de `Colors.red`. Armer l'annulation (glisser à gauche
  sans relâcher) en mode nuit et vérifier que le bandeau reste lisible.

---

## Discussion — l'horodatage sort de la bulle (fiches 4a/6b, 2026-08-05)

L'heure et l'accusé de réception étaient rendus à **sept endroits** : en fin de
ligne dans le texte, incrustés sur l'image et la vidéo, dans la ligne du
document, sur la carte de position, sous le lecteur audio, sous le sticker — et
**nulle part** sur les notes vocales. Ils sont désormais posés une seule fois,
sous la bulle, par `_buildMetaRow` de `message_bubble.dart`.

Couvert statiquement par `test/features/messages/message_meta_row_test.dart`
(l'heure n'est plus un descendant de la bulle, elle est sous le texte, la
réaction partage sa ligne, la note vocale en a une). Ce que le test ne peut pas
voir :

- [ ] **Lisibilité de l'heure sur fond de conversation**, en clair et en
  nocturne. Elle était blanche sur l'aplat vert des messages envoyés ; elle est
  maintenant `textTertiaryColor` sur le fond de l'écran.
- [ ] ⚠ **Sur fond d'écran personnalisé** (`ChatWallpaper` + les 8 couleurs de
  `chat_background_colors.dart`) : c'est le cas le plus risqué, l'heure n'a plus
  d'aplat sombre derrière elle comme l'incrustation des médias en avait un.
- [ ] **Une heure par grappe** : trois messages consécutifs du même expéditeur
  ne doivent afficher qu'un seul horodatage, sous le dernier.
- [ ] **Chaque famille de bulle** : texte, note vocale (elle en a une pour la
  première fois), photo, photo floutée en mode ÉCO, vidéo, document, sticker,
  position, message transféré, message cité.
- [x] **Accusé de réception en toutes lettres** (vu 2026-08-05, SM A515F, nocturne) : « 22:15 · Envoyé » et
  « 12:06 · Envoyé » lus a l ecran, coches et pastille bleue disparues.
  Restent a voir « Reçu », « Lu » et « Vu par N » — il faut un second
  appareil. Ancien libelle :
  « · Reçu », puis « · Lu » (bleu) — et « · Vu par N » en groupe. Les trois
  coches cerclées et la pastille bleue ont disparu. Vérifier surtout que la
  ligne ne devient pas trop longue sur un message court à font_scale 1.1 : le
  libellé est nettement plus large qu'une coche de 18 px.
- [ ] **Le tap sur l'accusé** ouvre toujours le détail par destinataire.
- [ ] **États transitoires** : « · Envoi… » pendant l'envoi, « · En attente »
  en orange quand le message est dans la file hors-ligne, et
  « · Non envoyé · Réessayer » en cas d'échec (seul état à garder une icône,
  parce qu'il appelle une action).
- [ ] **« Non envoyé · Réessayer »** : le libellé d'échec est passé sous la
  bulle avec le reste ; vérifier qu'il reste lisible et cliquable.
- [ ] **Le cadenas de chiffrement par message a disparu.** Il n'était posé que
  sur les messages « emoji seul » — une incohérence. Le rappel de chiffrement
  reste dans l'en-tête, à côté de « En ligne ». Confirmer que rien ne manque.

---

## Discussion — ÉCO rejoint la ligne épinglée (fiche 6b, 2026-08-05)

La sous-barre « Médias · ÉCO » sous le bandeau épinglé a disparu : la fiche 6b
pose la pastille ÉCO **à droite du bandeau**, sur la même ligne. Le raccourci
« Médias » n'est pas perdu, il est passé dans le menu ⋮ sous le libellé
« Médias partagés » (`sharedMedia`, clé déjà existante).

- [x] **Avec une épingle** (vu 2026-08-05, SM A515F, nocturne) : le bandeau « Message épinglé 1 · 1/3 » et la
  pastille « ⊕ ÉCO » tiennent bien sur une seule ligne, sans sous-barre.
  Reste a verifier avec un titre long :
  seule ligne, le bandeau prenant la place qui reste. Vérifier qu'un titre long
  s'ellipse au lieu de pousser la pastille hors de l'écran.
- [ ] **Sans épingle** : la ligne se réduit à la seule pastille ÉCO, alignée à
  droite — elle ne doit pas disparaître.
- [ ] **Avec le compteur `i/n`** (plusieurs épingles) : le compteur et la
  pastille cohabitent sans se marcher dessus, à font_scale 1.1.
- [ ] **« Mes notes » et demande de message en attente** : pas de pastille ÉCO
  (rien à réduire), et le bandeau seul doit rester correct.
- [ ] **La bascule fonctionne toujours** : appuyer sur ÉCO, revenir, vérifier
  que l'aperçu flouté des médias s'active bien.
- [ ] **« Médias partagés » dans le menu ⋮** ouvre bien la galerie de la
  conversation.
- [ ] ⚠ **Gain de hauteur** : ~40 dp libérés sous l'en-tête. La réserve de
  chrome de `computeMessagePickerHeight` n'a **pas** été rebaissée (le fichier
  était en cours de modification par ailleurs) — le panneau émoji a donc un peu
  moins de place qu'il ne pourrait. À reprendre si l'écran paraît serré.

---

## Composeur — l'emoji est sorti du champ, puis y est revenu (2026-08-05)

**Décision arrêtée : l'emoji reste DANS la pilule.** L'argument de largeur est
retenu — en pastille autonome il coûtait 52 dp et faisait tomber la pilule à
55 % de la largeur de l'écran, contre ~73 % à l'intérieur. Layout retenu :
`[ + ]  [ champ … 🙂 ]  [ micro / envoi ]`. Le test et l'en-tête de
`message_input_composer_test.dart` disent maintenant la même chose que le code.

Ce qui suit décrit la tentative « pastille autonome » (fiche 26b), conservée
pour mémoire :

Le smiley était un `suffixIcon` dans la pilule ; la fiche 26b le pose en
pastille ronde à part, fond `#F7E9DE`, glyphe `#B85E24`. Le composeur comptait
désormais quatre commandes : `[ + ] [ champ ] [ 🙂 ] [ micro / envoi ]`.

- [ ] ⚠ **Non-régression prioritaire — gestes vocaux.** Une commande de plus
  dans la ligne : revérifier appui long → enregistrement, glisser à gauche →
  annulation, glisser vers le haut → verrouillage. La pastille emoji
  **disparaît** pendant l'enregistrement, vérifier que ça ne décale rien.
- [x] **Largeur du champ** (2026-08-05) : c'est ce point qui a fait revenir
  l'emoji dans la pilule. Verrouillé par un test — la pilule garde plus des
  deux tiers de la largeur du composer. Reste à confirmer à font_scale 1.1.
- [x] **Bascule emoji ↔ clavier** (vu 2026-08-05, SM A515F, nocturne) : la pastille passe bien au glyphe
  clavier a l ouverture du panneau. Detail :
  d'intensité de fond quand le panneau est ouvert ; en nocturne le fond pastel
  est remplacé par l'accent teinté (`#F4A574` à 18/28 %) — vérifier qu'il ne
  fait pas un pavé lumineux.
- [x] ⚠ **« Plus rien dans la pilule à part le texte » n'est plus vrai** — la
  pastille emoji y est retournée le 2026-08-05, sur demande de Salim (« la
  pilule est trop étroite »). Voir la section suivante : les quatre commandes en
  ligne coûtaient 176 dp de chrome sur 393. La contrainte technique du lot C
  tient toujours (la pastille reste entièrement à droite du champ, elle
  n'empiète pas dessus) et son test passe, **mais l'intention « pastille
  autonome » de la fiche 26b est entamée**. À arbitrer avec Salim si la fiche
  l'exige explicitement.

---

## Composeur — largeur de la pilule et « + » en clair (2026-08-05)

Deux retours de Salim sur le rendu, traités et vérifiés sur appareil (SM A515F,
APK `48ede47` puis le suivant, conversation « Salim L. » avec toute sa chrome,
champ à 6 lignes). Mesures au banc sur gabarit A51 (393 dp).

- [x] **La pilule était trop étroite.** Trois pastilles autonomes de 44 plus
  quatre écarts = 176 dp de chrome : il ne restait que 217 dp de pilule (55 % de
  l'écran) et 51 % pour le texte. Un message qui tenait en 4 lignes en prenait 6.
  Corrigé en rendant la pastille emoji à la pilule et en resserrant la géométrie
  (marges 10 → 6, écarts 8 → 6, « + » et emoji 44 → 40 ; le bouton d'envoi garde
  44, c'est l'action principale). **Pilule 55 % → 73 %, champ 51 % → 58 %.**
- [x] **Le « + » était invisible en thème clair.** Relevé au pixel sur la
  capture : l'aplat du bouton et le fond de page donnaient **la même valeur**,
  `#F2E5D9` — l'accent à 12 % posé sur le crème, ce sont deux teintes
  identiques. Il n'y avait pas de bouton à l'écran, juste un glyphe orange.
  Il reprend désormais la surface de la pilule (blanc `#FFFFFF`, même liseré,
  même ombre) : relevé après correctif, disque `#FFFFFF` contre page `#F2EEE8`.
  Effet de bord utile : l'état « ouvert » passe au pêche `#EBD5C5` et devient
  franc, alors qu'il glissait avant de 12 % à 20 % d'un aplat déjà invisible.
  **Le thème sombre n'est pas touché** — le disque brun y ressortait déjà.
- [x] **Les deux thèmes vérifiés à l'écran**, barre recadrée et agrandie ×2 : la
  pastille emoji pêche sur la pilule blanche se détache bien (ma crainte qu'elle
  s'y noie était infondée), le badge cadenas n'est pas rogné par le bord, la
  pastille ne touche pas l'angle arrondi. Zéro `RenderFlex … overflowed` dans le
  tampon. ⚠ Le mode nuit du téléphone a été basculé en `no` pour le test puis
  **remis sur `yes` / `ui_night_mode=2`**, son état d'origine.
- [x] **Gestes vocaux — 3 sur 4 vérifiés** (2026-08-05, 06:05 → 06:11, « Mes
  notes », thème sombre, font_scale 1.1). Injection d'un vrai flux tactile via
  `input motionevent DOWN/MOVE/UP` chaîné dans **une seule** commande shell —
  Flutter le traite comme un doigt. La méthode par `input tap` successifs ne
  marche pas : l'écran bouge entre la capture et l'action.
  - **Appui long → enregistrement** : bandeau, minuterie, waveform, indicateur
    de verrouillage. Fonctionne.
  - **Glisser à gauche → annulation** : bandeau rouge, poubelle, et au
    relâchement **rien n'est envoyé**. Fonctionne.
  - **Glisser vers le haut → verrouillage** : « Relâchez pour verrouiller »,
    puis « Verrouillé — Mains libres, vous pouvez lâcher l'écran », minuterie
    qui continue sans le doigt. Fonctionne.
  - **Envoi depuis l'état verrouillé** : bulle audio verte, lecteur, durée
    1:15, contrôle de vitesse. Fonctionne. ⚠ Un vocal de test de 1:15 traîne
    dans « Mes notes », à supprimer.
  - [x] **Appui long puis simple relâchement** (sans glissement) — vérifié le
    2026-08-06 à 07:20. Le geste fonctionne : bulle audio de 0:02 créée. ⚠ Mais
    l'envoi a **échoué** (« À l'instant · Non envoyé · Réessayer »), alors que
    l'envoi depuis l'état verrouillé avait réussi une heure plus tôt. Entre les
    deux, « Mes notes » était passé par l'état « Ce groupe a été supprimé ».
    C'est la conséquence concrète du raccourci de `EnsureSelfNotesNotifier`
    (voir ci-dessous) : la conversation renvoyée par le cache pointe sur un
    document absent, donc toute écriture échoue. À noter au crédit de l'app :
    l'échec est **affiché** avec une action « Réessayer », il n'est pas avalé.
- [ ] ⚠ **Cause racine à trancher — `EnsureSelfNotesNotifier.ensure()`**
  (`message_provider.dart`, vers la ligne 1550) renvoie la conversation « Mes
  notes » trouvée dans la liste en cache **sans vérifier que son document
  existe encore**, et saute `getOrCreateSelfConversation`. Le commentaire assume
  le raccourci (« éviter un aller-retour »). Tant que la liste et le document
  sont d'accord ça tient ; dès qu'ils divergent, « Mes notes » s'ouvre sur un
  document fantôme et **tout envoi échoue**. Supprimer le raccourci coûte une
  requête par ouverture : arbitrage à faire.
- [ ] ⚠ **Débordement en paysage** trouvé le 2026-08-06 : conversation avec
  toute sa chrome (bandeau épinglé + bandeau de clés), clavier levé, appareil
  en paysage → « BOTTOM OVERFLOWED BY 17 PIXELS », et le composeur passe sous
  la ligne de flottaison. Le portrait est sain. Rien dans logcat, comme toujours
  (Crashlytics remplace `FlutterError.onError`) : seule la bannière rayée le
  prouve. Piste : la chrome fixe de la conversation n'est pas repliable, et en
  paysage il ne reste presque rien après le clavier.
- [x] ⚠ **Défaut trouvé pendant ce test — libellés tronqués dans le bandeau
  d'enregistrement**, à font_scale 1.1 sur le A51 : « Relâc… » au lieu de
  « Relâcher pour annuler », « L'enregi… » au lieu de « L'enregistrement sera
  supprimé », et « Glisser ‹… » en permanence. L'utilisateur ne pouvait pas lire
  ce qui allait lui arriver au moment où il annule — précisément le moment où il
  faudrait qu'il comprenne.
  **Cause** : le libellé partageait sa ligne avec la minuterie et le waveform et
  n'en recevait que 2/5 (`Expanded(flex: 2)` contre `flex: 3` au waveform).
  **Correctif** : le libellé a sa propre ligne, pleine largeur, sous la ligne
  minuterie + waveform ; les textes passent à `maxLines: 2` pour encaisser les
  fortes échelles au lieu de se couper.
  **Vérifié à l'écran le 2026-08-05 (06:44 → 06:47)**, APK `255dd2f`, thème
  sombre, font_scale 1.1 : « Glisser ‹ pour annuler · ↑ pour verrouiller » puis
  « Relâcher pour annuler » / « L'enregistrement sera supprimé » s'affichent en
  entier. Le relâchement annule bien (aucun vocal envoyé), zéro `RenderFlex`
  dans le tampon.
- [ ] **Observation à part** : « Mes notes » affiche maintenant « Aucun
  message » et un bandeau **« Ce groupe a été supprimé »** à la place du
  composeur. Sans rapport avec les gestes vocaux (rien n'a été supprimé pendant
  la passe) — vraisemblablement le ménage des données de test. À vérifier : une
  auto-conversation ne devrait pas pouvoir tomber dans l'état « supprimé ».
- [ ] **font_scale 1.1 avec un texte réel** : les mesures ci-dessus sont à
  l'échelle 1.0 du banc. Vérifier qu'un vrai message long garde une largeur
  confortable sur l'appareil.

---

## Panneau stickers / GIF / émojis (fiche 26b, 2026-08-05)

Refonte complète : onglets en **pilules Stickers · GIF · Émojis** (l'ordre est
inversé par rapport à avant) suivis d'une loupe, **sections à en-tête**
(RÉCEMMENT UTILISÉS · FAVORIS · un par pack) au lieu des sous-onglets iconiques
horloge/cœur/vignette, grille à tuiles carrées à fond visible, et la note
« téléchargés une fois » descendue **en pied**.

Couvert statiquement par `emoji_sticker_picker_layout_test.dart` (ordre des
pilules, sections, 4 colonnes à 390 dp, pied présent/absent, filtre, nocturne)
et `emoji_sticker_picker_landscape_test.dart` (pas d'overflow à 160/200/260).
Ce que les tests ne voient pas :

- [x] ⚠ **Le smiley du composeur ouvre bien les ÉMOJIS** (vu 2026-08-05, SM A515F, nocturne) — le piege de
  l index est evite. Detail :
  devenu « Stickers » : le code est passé d'un index à une énumération
  (`MessagePickerTab`) exprès pour ça, mais c'est le premier geste à refaire.
- [ ] **Défilement continu** sections + grille, clavier réellement ouvert, sur
  le A51 — c'est un seul `CustomScrollView` désormais.
- [x] **Ligne d'info en pied** (vu 2026-08-05) : « ⓘ Téléchargés une fois,
  envoyés sans données » est bien SOUS la grille, avec son filet, sur
  l'onglet GIF ; absente de l'onglet Émojis. L'en-tête « TENDANCES » en
  terracotta porte la bascule GIFs/Stickers.
- [ ] **Padding bas de la ligne d'info** face à la barre de navigation
  gestuelle (la fiche prévoit 26 px pour l'indicateur iOS, on en met 8).
- [ ] **La loupe sur l'onglet Émojis** ouvre la vue de recherche interne du
  paquet `emoji_picker_flutter` (elle est plein cadre, avec son propre retour).
- [ ] **La loupe sur Stickers** filtre sur place. ⚠ Elle cherche dans
  `sticker.emoji` et le nom du pack ; si `emoji` est vide en base pour la
  plupart des stickers, seul le nom du pack remontera. À confirmer sur les
  vraies données.
- [ ] **Grille en paysage** : 4 colonnes à 390 dp, davantage au-delà (sinon les
  tuiles feraient 180 dp). Non vu : aucun pack en base, l'onglet Stickers ne
  s'affiche pas.
- [ ] **Chrome resserré sous 190 dp** : en paysage la ligne d'info disparaît et
  la barre d'onglets se tasse. Vérifier que ça reste lisible.
- [ ] **Nocturne** : pilule sélectionnée sur `textPrimary`, contours sur
  `borderStrong`, en-têtes de section sur le repère `#F4A574`.
- [ ] **Les favoris n'ont plus d'onglet cœur** : ils sont une section, affichée
  seulement si non vide. L'appui long sur un sticker propose toujours
  « Ajouter aux favoris ».
- [ ] ⚠ **« No Recents » est en anglais** dans l'onglet Émojis : c'est la
  chaîne interne de `emoji_picker_flutter`, pas une des nôtres. Elle n'est
  pas localisée par le paquet — à traiter à part (option de config, ou vue
  personnalisée), ce n'est pas un oubli de nos ARB.
- [ ] **L'onglet Stickers reste absent sans pack Supabase** (les packs sont
  vides en base) : dans ce cas le panneau s'ouvre sur GIF ou Émojis.

---

## Messages épinglés — le bandeau n'était pas temps réel (2026-08-05)

`group_pinned_items` n'a jamais été ajoutée à la publication
`supabase_realtime` (contrairement à `messages` et `conversations`, vérifié sur
le projet distant « Diapo Niger »). Le `.stream()` de
`getPinnedItemsStream` ne faisait donc que son chargement initial : le
`ref.invalidate` de `conversation_screen` masquait le trou pour l'action faite
sur CE téléphone, mais rien d'autre n'arrivait jamais. Migration
`supabase/migrations/20260805120000_realtime_group_pinned_items.sql`
(publication + `replica identity full`, nécessaire pour que les DELETE passent
le filtre serveur `group_id`/`conversation_id`).

**Vérifié le 2026-08-05 sur SM A515F**, conversation 1-à-1
`883c9d96-fbab-42bd-8501-a7c49def0e91`, sans second téléphone : le rôle de
« l'autre appareil » est tenu par une écriture SQL directe sur
`group_pinned_items` pendant que l'écran reste ouvert et **non touché**.

- [x] **Épinglage distant** (INSERT serveur, écran ouvert) : compteur passé de
  `1/3` à `1/4` tout seul.
- [x] **Désépinglage distant** (DELETE serveur, écran ouvert) : `1/4` → `1/3`
  tout seul — c'est le cas qui dépend de `replica identity full`.
- [x] **Bandeau + pastille ÉCO sur une seule ligne** (fiche 6b) : libellé à
  gauche, compteur `i/n` puis pastille à droite, sans chevauchement.
- [x] **Tap = défilement Telegram + saut au message** : `1/3` → `2/3`, libellé
  « Message épinglé 2 », et la liste a bien sauté au message ciblé.
- [x] **Bandeau au clavier ouvert** : reste visible, aucun débordement, la
  pastille est conservée.

Restent à voir (demandent un second appareil, ou un build à jour installé) :

- [ ] **Suppression pour tous d'un message épinglé** par B : l'épingle tombe en
  cascade, le bandeau de A doit se vider tout seul.
- [x] **Chemin groupe — testé le 2026-08-05, il ne marche pas**, et pas à cause
  du temps réel : dans « Groupe de test prive », appui long → Autres actions →
  **Épingler** répond **« Impossible d'épingler ce message »**. Cause établie en
  base : `group_pinned_items.group_id` porte une clé étrangère vers
  `groups(id)`, or ce groupe a pour id `yflqsRLMMhTPpiW0NFHx` — un **id de
  document Firestore**, absent de `public.groups` (0 ligne). L'insertion viole
  donc la contrainte, `pinItem` lève, et le message d'échec s'affiche. Tant que
  les groupes vivent dans Firestore et les épingles dans Supabase, **aucun
  message de groupe ne peut être épinglé**. Le filtre `group_id` du bandeau
  reste donc non prouvé — il n'y a rien à afficher.
- [ ] **Contournement posé le 2026-08-05** : les épingles passent désormais
  **toutes** par `conversation_id`, groupe compris (`_pinMessage`,
  `_unpinMessage`, le bandeau et `pinnedMessageIds`). La colonne
  `conversation_id` pointe sur une table réellement peuplée dans les deux cas,
  donc l'épinglage de groupe doit marcher sans migrer les groupes.
  ⚠ **Ce que ça change côté droits** : les policies RLS appliquées sont
  « Conversation participants… », qui n'exigent que d'être dans
  `participant_ids`. La permission de groupe « qui peut épingler »
  (`who_can_pin`, rôles owner/admin/moderator) **n'est plus vérifiée par la
  base** — seul le filtre `canPin` de l'écran subsiste. À reprendre quand les
  groupes vivront dans Supabase.
  - [ ] Épingler dans un groupe : ne doit plus dire « Impossible d'épingler ».
  - [ ] Le bandeau doit apparaître dans le groupe, et le menu basculer sur
    « Détacher ».
  - [ ] **Non-régression 1-à-1** : rien ne doit changer, c'est le chemin qui
    servait déjà.
  - [ ] **Visibilité entre membres** : un second membre du groupe doit voir
    l'épingle — ça dépend de `conversations.participant_ids`, qui doit donc
    contenir tous les membres du groupe (à vérifier, ce n'est pas garanti).
- [ ] ⚠ **Contenu déchiffré dans le bandeau** : toujours pas vu. Les clés E2EE
  sont perdues sur ce build (bandeau « Restaurez vos clés » présent, bulles
  « 🔐 Message chiffré ») et les 3 épingles de test pointent toutes sur du
  texte chiffré (`gcm:` ou `iv:ciphertext`, vérifié en base). Ce point ne
  pourra se solder qu'après restauration des clés.
- [x] **Repli illisible corrigé** (2026-08-05) : dans ce cas le bandeau
  affichait « Message épinglé » **sous** le libellé « Message épinglé 1 », soit
  deux fois la même chose. Il dit maintenant « 🔐 Message chiffré ». À revoir à
  l'écran sur un build à jour.

Et sur un seul appareil, après le correctif de `group_pinned_banner.dart` (la
pastille était perdue avec la ligne quand l'épingle n'était pas résoluble).
**Non testables sur le build actuellement installé** — il date d'avant le
correctif, et le réinstaller viderait les données de l'appareil :

- [ ] **Une seule épingle orpheline** (message supprimé avant la cascade) : le
  bandeau ne s'affiche pas, mais la **pastille ÉCO doit rester** à droite.
- [ ] **Épingle de sondage / d'événement pendant le chargement** : la pastille
  ne doit pas clignoter hors de l'écran le temps du fetch.

Inventaire des épingles en base (2026-08-05) : 5 au total, toutes de type
`message`, aucune de sondage ni d'événement. Deux étaient orphelines — leur
`item_id` était un id **optimiste** `temp_<millis>` (message épinglé avant que
le serveur ne confirme l'envoi), donc irrésolvable à jamais. Les deux ont été
supprimées le 2026-08-05 ; il reste 3 épingles, 0 orpheline. `_pinMessage`
refuse désormais un id `temp_…` (à vérifier sur un build à jour) :

- [ ] **Épingler un message en cours d'envoi** (couper le réseau, envoyer, puis
  appui long → Épingler) : doit afficher « Attendez l'envoi du message pour
  l'épingler » et ne rien écrire en base. Vérifier ensuite qu'une fois le
  message parti, l'épinglage fonctionne normalement.

### Second système mort trouvé le 2026-08-14 : la ligne « Épinglés » de la fiche groupe

`_GroupInfoCard` (`group_detail_screen.dart`, fiche 9d — la carte Épinglés /
Médias / Prochaine rencontre) lisait `groupPinnedItemsProvider(group.id)`,
filtré sur `group_pinned_items.group_id`. Depuis le contournement du
2026-08-05 ci-dessus, plus rien n'écrit jamais cette colonne — `_pinMessage`
ne pose que `conversation_id`. La ligne « Épinglés » restait donc **en
permanence vide et invisible** (`pinned.isNotEmpty` toujours faux) sur tous
les groupes, y compris ceux où le bandeau de conversation affichait bien des
épingles juste au-dessus — deux lectures divergentes de la même table.

Corrigé : `_GroupInfoCard` lit maintenant `conversationPinnedItemsProvider`
via l'id de conversation du groupe (déjà résolu pour la ligne Médias juste en
dessous). `groupPinnedItemsProvider` et la branche `groupId` de
`GroupPinnedBanner` sont supprimés (plus aucun appelant ne les utilisait).
`flutter analyze` propre sur les 3 fichiers touchés.

- [x] **Vérifié sur SM A515F le 2026-08-14.** Dans « Groupe de test privé »
  (0 épingle au départ) : épinglage d'un message via Autres actions →
  Épingler → bandeau de conversation affiche bien « Message épinglé » (donc
  le contournement RLS conversation_id du 2026-08-05 tient toujours) ; retour
  à la fiche groupe → la ligne « Épinglés · 1 message » apparaît, compte
  correct. Avant ce correctif elle n'aurait jamais pu s'afficher, quel que
  soit l'état des épingles.
- [ ] Groupe sans rien d'épinglé : la ligne doit rester absente (comme avant)
  — pas revérifié isolément mais découle du même code que la ligne Médias.

### Troisième bug trouvé le 2026-08-14 : aucun ordre stable entre plusieurs épingles

`group_pinned_items.sort_order` vaut `0` par défaut en base (vérifié via
`information_schema.columns` sur le projet lié) et `pinItem` ne l'a jamais
renseigné à l'insertion. `getPinnedItemsStream` triait dessus
(`.order('sort_order')`) — un tri qui ne départage donc rien entre deux
épingles ou plus : Postgres ne garantit **aucun** ordre stable entre des
lignes à égalité. Or le bandeau se re-souscrit souvent en pratique (clavier,
`ensureAuthenticated`, `autoDispose` du provider) — l'ordre pouvait donc
changer d'une re-souscription à l'autre, et comme l'index affiché dans le
bandeau (`i/n`) pointe une **position** dans la liste et non un id, l'item
réellement montré pouvait sauter vers un autre sans la moindre action de
l'utilisateur.

Corrigé : tri désormais sur `pinned_at` (seule colonne unique/stable du lot),
dans `getPinnedItemsStream`. `flutter analyze` propre ; racine du bug
confirmée en base (`sort_order` = `0` sur toutes les lignes, vu par
`information_schema.columns`) — mais **non vérifié sur appareil**, faute
d'avoir pu poser une 2e épingle dans la même conversation le 2026-08-14 (le
SM A515F a cessé de répondre aux `input tap`/`input text` scriptés à mi-passe
— navigation qui ne bouge plus, `input text` qui n'atteint pas le composeur,
alors que `input keyevent KEYCODE_HOME` fonctionnait toujours : signe d'une
app bloquée sur un état précis plutôt que d'un appareil mort. Cause la plus
probable, jamais confirmée : usage concurrent du même téléphone physique par
l'autre agent/session — cf. `lastUpdateTime` qui avait déjà bougé sous mes
pieds en tout début de passe. Pas conclu à un bug applicatif sur cette seule
base, voir la règle du doigt réel dans `project_device_testing`.

- [ ] Épingler 2-3 messages dans une même conversation, rouvrir l'écran
  plusieurs fois (ou faire apparaître/disparaître le clavier plusieurs fois) :
  l'ordre `1/n`, `2/n`… doit rester identique à chaque fois (le plus ancien
  épinglé en premier). « Groupe de test privé » porte déjà 1 épingle
  (message « Message de test pour verifier 9c et 9d ») posée pendant cette
  passe — il suffit d'en épingler un second pour tester.

---

## Paysage — overflow quand le chrome dépasse la hauteur (2026-08-05)

Testé sur le SM A515F en forçant `user_rotation 1`. **L'app tourne bien** : elle
passe sur un rail de navigation latéral, et la conversation reste correcte.

**Vu et sain :**
- [x] Conversation en paysage, composeur vide : rien ne déborde, l'heure et
  « · Envoyé » restent sous la bulle.
- [x] Panneau émojis ouvert en paysage : pas de débordement, les pilules et la
  loupe tiennent sur la ligne. La liste des messages est réduite à zéro par
  l'`Expanded` — c'est le comportement attendu sur 392 dp de haut.

**Deux débordements, tous deux hors du périmètre des quatre lots :**

- [x] ⚠ **CORRIGÉ le 2026-08-13, vérifié sur appareil (0 px).**
  Conversation « Salim L. » en paysage : `BOTTOM OVERFLOWED BY 240 PIXELS`.
  Reproduit avec le bandeau « Restaurez vos clés de chiffrement »
  affiché **et** un brouillon de 6 lignes dans le composeur. La cause est
  `computeMessagePickerHeight` (`message_input.dart`) : elle réserve **176 dp
  de chrome en dur**, calibrés sur en-tête 58 + composeur 64 + bandeau épinglé
  44. Or le bandeau de restauration des clés (~90 dp) n'y est pas compté, et un
  composeur à 6 lignes fait ~150 dp au lieu de 64. Sur 392 dp de haut, le
  compte est dépassé de ~240.
  Le même écran **sans** ces deux conditions ne déborde pas.

  **Reconfirmé le 2026-08-13**, seuil plus bas qu'estimé : `BOTTOM OVERFLOWED
  BY 47 PIXELS` avec le même bandeau de restauration des clés mais un
  brouillon de **2 lignes seulement** (pas 6), pendant la frappe au clavier
  logiciel. L'overflow disparaît dès que le clavier se referme (texte
  entièrement visible, bouton d'envoi accessible) — le message part
  normalement et la bulle reçue se replie bien sur deux lignes. Donc rien à
  voir avec `message_bubble.dart` (agrandissement du texte des bulles à 17,
  commits `83ca2e4`/`a9b1fa5`) : l'overflow touche uniquement la barre de
  saisie, pas le rendu des bulles envoyées.

  **Corrigé partiellement le 2026-08-13** en activant enfin le garde-fou déjà
  écrit dans `message_input.dart` (`_buildColumn`/`panneau`, voir la section
  suivante) : `MessageInput` est désormais enveloppé dans un
  `ConstrainedBox(constraints: BoxConstraints(maxHeight: zoneCorps.maxHeight))`
  dans `conversation_screen.dart`, avec `zoneCorps` la contrainte déjà mesurée
  par le `LayoutBuilder` qui entoure le corps de la conversation (celui qui
  pilote aussi `placeRappelCles`). Sans ça `RenderFlex` donnait toujours
  `maxHeight: Infinity` à ce widget (enfant non-flexible de la `Column`), donc
  son propre `LayoutBuilder` interne voyait `bornee == false` en permanence et
  ne rétrécissait jamais ses panneaux. Volontairement **pas** de `Flexible`
  autour de `MessageInput` dans la `Column` externe (le piège documenté plus
  bas : ça se partagerait l'espace libre avec l'`Expanded` de la liste des
  messages et la raboterait même quand il y a largement la place). `flutter
  analyze` propre sur les deux fichiers.

  **Vérifié sur SM A515F, en vrai paysage clavier ouvert (pas seulement
  `flutter analyze`)** : le correctif réduit le débordement, il ne l'élimine
  pas.
  - Bandeau de restauration des clés affiché + brouillon vide (juste le
    placeholder « Votre message... ») : `BOTTOM OVERFLOWED BY 21 PIXELS`,
    contre 47 avant correctif avec un brouillon de 2 lignes — nette
    amélioration, mais pas zéro.
  - Fait rejouer ensuite avec un texte tapé dans le champ : l'overflow ne
    grandit plus avec la longueur du brouillon (c'est bien ce que corrige le
    `ConstrainedBox`), mais un cas minimal persiste : composeur vide, **sans
    aucune bannière visible** (juste l'en-tête), toujours en paysage clavier
    ouvert — `BOTTOM OVERFLOWED BY 12 PIXELS`.
  - Ce résidu n'est donc pas un débordement des *panneaux* de `MessageInput`
    (ce que le `ConstrainedBox` corrige) mais un **plancher irréductible** :
    sur cette géométrie (paysage + clavier logiciel), en-tête + hauteur
    minimale du composeur (une ligne + rangée de boutons + marge de sécurité
    bas d'écran) dépasse à elle seule la hauteur disponible de quelques
    pixels. Le `ConstrainedBox` ne peut rien y faire : il borne
    `MessageInput`, il ne le compresse pas en dessous de son contenu
    minimal.
  - **Plancher éliminé le 2026-08-13** en réduisant le padding vertical du
    composeur, spécifiquement en paysage (`MediaQuery.of(context).orientation
    == Orientation.landscape`), en deux temps :
    1. Marge extérieure de la barre (6→2 en haut, 8→2 en bas de la marge de
       sécurité) et padding interne de la pilule (6→3) : `21 PIXELS` → `5,1
       PIXELS` mesuré sur le même écran (bandeau restauration + composeur
       vide).
    2. `contentPadding` du `TextField` (12→9 haut/bas) et plancher
       `minHeight` de la ligne du champ (44→38) : `5,1 PIXELS` → **0**,
       revérifié sur appareil, clavier ouvert, bandeau épinglé + bandeau de
       restauration des clés tous deux affichés.
    Rien de touché en portrait (toutes les valeurs sont conditionnelles à
    `isLandscape`) — seule la géométrie paysage change.
  - Non revérifié : l'écran précis qui montrait `240 PIXELS` (bandeau +
    brouillon 6 lignes + panneau ouvert) — mais la cause de ce cas était la
    même famille (plancher du composeur + `ConstrainedBox` déjà posé), donc
    vraisemblablement également résolue ; à confirmer si le cas se
    représente.
- [x] ⚠ **Écran de recherche des messages en paysage, clavier levé :
  `OVERFLOWED BY 190`.** Cet écran n'a été touché par aucun des lots — c'est
  le même défaut structurel, ailleurs. **Corrigé le 2026-08-05, mais pas où
  on le croyait : le coupable n'est pas la colonne de l'écran de recherche.**
  Voir la section suivante.

**Ce n'est donc pas une régression de la refonte** : c'est le motif « une
`Column` dont les enfants fixes dépassent la hauteur de l'écran », que le
paysage rend visible et que la réserve de chrome en dur ne peut pas suivre.
Un correctif honnête ne se limite pas au composeur — à trancher à part.

Pistes, par coût croissant :
1. Borner `maxLines` du champ en paysage (6 lignes sur 392 dp n'a pas de sens).
2. Compter le bandeau de restauration dans la réserve de chrome.
3. Remplacer la réserve en dur par une mesure réelle (`LayoutBuilder` autour du
   corps de la conversation), seule solution qui suive tous les bandeaux
   conditionnels.

### Cause racine du 240 trouvée le 2026-08-05 : le garde-fou est inerte

La piste 3 a **déjà été écrite**, mais elle ne s'exécute jamais. `MessageInput`
s'enveloppe dans un `LayoutBuilder` et, *si* on lui donne une hauteur finie,
transforme ses panneaux en `Flexible` pour qu'ils se rétrécissent au lieu de
déborder (`message_input.dart`, `_buildColumn` / `panneau`). Un commentaire
affirmait « la conversation le fait ». **C'est faux.**

Dans `conversation_screen.dart` la structure est
`body > Container > Stack > Column[ …bandeaux…, Expanded(liste), MessageInput ]`.
`MessageInput` y est un enfant **non-flexible** de la `Column` — et `RenderFlex`
donne à ses enfants non-flexibles `maxHeight: Infinity`. Mesuré sur la
géométrie exacte de l'écran (392 dp, en-tête 58 + épinglé 44 + restauration 90
+ `Expanded`) :

```
CONTRAINTE RECUE PAR MessageInput : BoxConstraints(0.0<=w<=800.0, 0.0<=h<=Infinity)
maxHeight.isFinite = false
```

Donc `bornee == false`, `panneau()` renvoie l'enfant nu, et rien ne rétrécit.
Le débordement de 240 est inévitable dès que bandeaux + brouillon long +
panneau ouvert dépassent la hauteur.

**Attention au correctif évident, qui est un piège** : ajouter un
`Flexible` autour de `MessageInput` dans cette `Column` ne suffit pas — il se
partagerait l'espace libre avec l'`Expanded` de la liste des messages et
raboterait la liste (`RenderFlex` ne redistribue pas ce qu'un `Flexible` en
`loose` n'a pas consommé). Il faut mesurer la hauteur disponible du corps
(un `LayoutBuilder` autour de la `Column`) et passer une borne explicite au
composeur.

Non corrigé ici : `conversation_screen.dart` était en cours de modification
dans le worktree principal, et y toucher en parallèle aurait écrasé du travail
non committé. Le commentaire mensonger de `message_input.dart`, lui, a été
corrigé — c'est ce qui aurait fait perdre le plus de temps au prochain lecteur.

---

## Groupes — défauts trouvés en vérifiant les épingles (2026-08-05)

Les deux premiers constatés sur SM A515F en cherchant à épingler dans un
groupe, tous deux hors du lot « épingles » ; le troisième trouvé en corrigeant
le second. **Les trois sont corrigés** (2026-08-05), aucun n'est vérifié sur
appareil.

**1. Chaque ouverture de la discussion de groupe crée une NOUVELLE
conversation.** ✅ **Corrigé le 2026-08-05** (code ; doublons déjà en base non
encore fusionnés — décision en attente). « Groupe de test prive »
(`yflqsRLMMhTPpiW0NFHx`) a trois lignes dans `conversations` : une du 05/08 à
04:13 (1 message), puis une à 22:14 et une à 22:21 — les deux créées en ouvrant
simplement la discussion pendant la session. Conséquence visible : l'écran
affiche « Aucun message » alors qu'un message existe bel et bien, dans une
conversation précédente. L'historique du groupe se fragmente à chaque entrée.

Cause : `MessageSupabaseDataSource.findGroupConversationByGroupId` rendait
`null` **sans chercher** dès que le `group_id` n'était pas un UUID. Ce
court-circuit protège l'appel de la RPC `join_group_conversation`, qui casse le
`group_id` en `uuid` (`22P02`) — mais il faisait croire à
`createGroupConversation` qu'aucune conversation n'existait, donc il en
insérait une neuve à chaque ouverture. Les groupes hérités de Firestore ont un
id de 20 caractères (`yflqsRLMMhTPpiW0NFHx`), pas un UUID : ils étaient les
seuls touchés — ce que la base confirme, les 3 groupes à id UUID ont exactement
une conversation chacun, le groupe hérité en avait trois.

**CORRIGÉ (2026-08-05), non vérifié sur appareil.** Cause :
`findGroupConversationByGroupId` (`message_supabase_datasource.dart`) faisait
`if (!_isUuid(groupId)) return null;` — un court-circuit posé pour éviter le
`22P02` de la RPC `join_group_conversation` (qui caste `p_group_id::uuid`)
sur les groupes hérités de Firestore, dont l'id fait 20 caractères. Mais il
rendait `null` **avant toute recherche**, et l'appelant
`createGroupConversation` enchaîne sur un INSERT : d'où une conversation de
plus à chaque ouverture, y compris pour le créateur déjà participant. Le
court-circuit ne saute plus que la RPC : `_findLegacyGroupConversation()`
cherche la conversation par `conversations.group_id`, colonne **TEXT** (vérifié
en base), et retient la plus ancienne — celle qui porte l'historique.

État de la base au moment du correctif : plus aucun doublon
(`group_id` avec `count(*) > 1` → 0 ligne), et il ne reste qu'une conversation
pour `yflqsRLMMhTPpiW0NFHx`, celle du 05/08 04:13 qui contient le message. Les
deux doublons de 22:14 et 22:21 ont donc été nettoyés entre-temps — le code
fautif, lui, était toujours en place.

**Limite assumée, non corrigée :** la policy SELECT de `conversations` est
`participant_ids @> [firebase_uid()]`. Un membre d'un groupe hérité qui n'est
pas encore dans `participant_ids` ne verra donc rien et déclenchera quand même
une recréation. La RPC `SECURITY DEFINER` règle ce cas pour les groupes
Supabase en vérifiant `group_members` ; pour un groupe hérité cette table est
vide (appartenance restée côté Firestore), et une RPC qui ajouterait l'appelant
sans pouvoir vérifier son appartenance ouvrirait n'importe quelle conversation
de groupe hérité à n'importe qui. À traiter avec la migration des groupes
hérités.

Le garde `_isUuid` n'existe qu'à cet endroit, vérifié sur tout `lib/` — pas
d'autre occurrence du même piège à corriger.

**Verrou base proposé, non appliqué** :
`supabase/migrations/20260806230000_conversations_une_par_groupe.sql` (index
unique partiel sur `group_id` pour `type='group'`). Le correctif applicatif
supprime la cause, mais trois chemins peuvent encore dupliquer : les **APK déjà
installés** tournent avec l'ancien code, deux appareils du même compte peuvent
ouvrir la discussion simultanément, et un futur chemin d'insertion pourrait
oublier la recherche. ⚠ Changement de comportement à peser : une insertion en
trop échouera au lieu de réussir en silence — donc « Erreur à l'ouverture de la
discussion » plutôt qu'un historique fragmenté. Cas limite documenté dans la
migration : un membre d'un groupe hérité absent de `participant_ids` passera
d'un doublon vide à une erreur franche.

- [ ] Ouvrir deux fois de suite la discussion d'un groupe **hérité** (id de 20
  caractères, ex. `yflqsRLMMhTPpiW0NFHx`) et compter les lignes
  `conversations` pour ce `group_id` : il ne doit s'en créer aucune de plus.
  ```
  supabase db query --linked "select id, created_at from conversations where group_id = 'yflqsRLMMhTPpiW0NFHx' order by created_at;"
  ```
- [ ] Les messages déjà envoyés doivent réapparaître (l'écran affichait
  « Aucun message »).
- [ ] Non-régression sur un groupe **Supabase** (vrai UUID) : la RPC doit
  toujours être empruntée, et un membre ayant rejoint après la création doit
  continuer à retrouver la conversation.

**Deuxième filet ajouté (2026-08-06) :** quand la RPC rend `NULL` sur un groupe
à id UUID — soit qu'aucune conversation n'existe, soit que l'appelant ne soit
pas encore dans `group_members` —, on retombe sur la même recherche directe au
lieu de rendre `null` sec. Le RLS la borne aux conversations dont on est déjà
participant : si l'appelant en est un, sa conversation est réutilisée au lieu
d'être doublée ; sinon rien ne change.

- [ ] Non-régression du filet : un groupe UUID dont l'appelant est participant
  de la conversation mais absent de `group_members` doit ouvrir la conversation
  existante, pas en créer une seconde.

**Doublons en base : plus rien à fusionner.** Les deux conversations
surnuméraires (22:14 et 22:21) ont disparu **pendant** la session d'analyse,
sans intervention de ma part — la suppression que j'avais préparée a été
bloquée avant exécution. Le compte final est propre : les 4 groupes ont
exactement 1 conversation chacun, et `yflqsRLMMhTPpiW0NFHx` garde celle du
04:13 avec son message. Une sauvegarde des 3 lignes d'origine a été prise avant
(scratchpad de session, `conversations_yflqs_avant_fusion.json`) — elle
disparaîtra avec la session, à récupérer maintenant si elle a de la valeur.

**Message disparu : très probablement un ménage manuel.** Le message de la
conversation 22:21 (envoyé à 22:22:34) était présent au début de l'analyse,
absent quelques minutes plus tard, avant toute suppression de conversation.
Rien dans le système ne peut faire ça tout seul, vérifié :

- `pg_cron` a 3 tâches, toutes des `http_post` vers des Edge Functions de
  rappels — aucune ne supprime de données.
- Aucun déclencheur sur `messages` ; sur `conversations`, seulement
  `update_updated_at`.
- Pas de messages éphémères dans l'app (les occurrences « ephemeral » sont les
  clés X3DH de l'E2EE, sans rapport).
- `deleteMessageForEveryone` et `deleteMessageForMe` sont des suppressions
  **douces** (`is_deleted`, `data.deletedForEveryone`) : la ligne reste, elle
  serait encore comptée.
- **Aucun `from('messages').delete()` dans tout le code** — l'app n'a pas de
  chemin pour supprimer physiquement un message.

Conclusion : la ligne a été retirée hors de l'app (éditeur SQL ou dashboard).
Si ce n'était pas toi, alors rouvrir le sujet — mais il n'y a pas de mécanisme
applicatif à incriminer.

- [ ] **Défaut trouvé au passage — « supprimer pour tout le monde » laisse les
  messages orphelins.** `MessageSupabaseDataSource.deleteConversation`
  (ligne ~1676) fait `from('conversations').delete()` avec le commentaire
  « Hard delete (cascade deletes messages) ». **Il n'y a pas de cascade** :
  `messages.conversation_id` n'a aucune clé étrangère vers `conversations`
  (seules `events` et `group_pinned_items` en ont une, en CASCADE). Chaque
  suppression de conversation « pour tout le monde » abandonne donc en base
  tous ses messages — invisibles, et chiffrés E2EE, donc jamais récupérables ni
  purgés. Zéro orphelin aujourd'hui (les messages du groupe de test avaient été
  retirés avant), mais la prochaine suppression réelle en créera.

  Migration écrite, **non appliquée** :
  `supabase/migrations/20260806220000_messages_conversation_fk_cascade.sql`
  (clé étrangère `on delete cascade`, dans le sens de ce que le code croyait
  déjà). Prérequis vérifié : 0 message orphelin, types compatibles (`text` des
  deux côtés), index `messages_conversation_idx` déjà en tête sur
  `conversation_id`. À appliquer avec :
  ```
  supabase db push --linked
  ```

**2. Un lien profond vers une conversation de groupe la rend en 1-à-1.**
`app_router.dart:873` lit `isGroup` uniquement dans `state.extra`, absent d'un
lien profond ou d'une notification : `isGroup` retombe à `false`. Ouvrir
`https://diasponiger.web.app/messages/<id d'une conversation de groupe>` donne
un en-tête « Utilisateur » avec boutons d'appel, et le bandeau épinglé
interroge `conversationPinnedItemsProvider` — qui ne renvoie jamais rien pour
un groupe. `ConversationScreen` ne reconcilie jamais ce drapeau avec
`conversation.groupId`, pourtant disponible.

**CORRIGÉ (2026-08-05), non vérifié sur appareil.** `ConversationScreen` ne se
fie plus au seul paramètre de construction : `_syncConversationIdentity()`,
appelé depuis `build()`, aligne l'état local sur la conversation chargée
(`conversation.isGroup || conversation.groupId != null`), et les ~80 sites qui
lisaient `widget.isGroup` / `widget.groupId` passent par les accesseurs
`_isGroup` / `_effectiveGroupId`. `widget.isGroup` reste prioritaire, la
réconciliation ne fait que passer `false → true`. Comme ce basculement
survient APRÈS `initState`, le travail d'ouverture réservé aux groupes
(effacement des mentions non lues, filtre des groupes privés) est rejoué par
`_runGroupOpenWork()`, idempotent via deux drapeaux. Le repli sur
`conversation?.groupId` qui existait déjà en trois endroits est absorbé par
`_effectiveGroupId`.

⚠️ **Le symptôme « bandeau épinglé vide » de la description ci-dessus n'est
plus d'actualité** : il a été réglé indépendamment, et mieux, par le correctif
« l'épingle est toujours portée par la conversation, groupe compris »
(`_pinMessage`) — les épingles ne dépendent plus du tout de `isGroup` ni de
`groupId`. Ce qui restait faux par lien profond, et que le présent correctif
traite, c'est l'en-tête, les boutons d'appel, le nom et le mini-avatar de
l'expéditeur, le badge « Admin », les permissions sondage/événement et le
menu ⋮.

Le second défaut (écran noir au retour) est corrigé dans la foulée :
`_leaveConversation()` (flèche de l'en-tête + refus de requête) et un
`PopScope` (geste/bouton retour système) retombent sur `/messages` quand
`context.canPop()` est faux.

> ### 🔴 Trouvé pendant la vérification appareil : `groupStreamProvider` lit encore FIRESTORE
>
> `groupRemoteDataSourceProvider` (`group_provider.dart:16`) rend
> `GroupRemoteDataSourceImpl`, bâti sur `FirebaseFirestore.instance` — alors
> qu'un `GroupSupabaseDataSource` existe, complet, mais **n'est câblé nulle
> part**. Conséquence : `groupStreamProvider` rend `null` pour tout groupe créé
> dans Supabase, et comme `groupStream` avale l'erreur
> (`fold((failure) => null)`), ça ne se voit jamais dans les logs.
>
> Symptôme observé : l'en-tête du groupe « Diaspora Niger — Canada » affichait
> « Groupe » (repli `l10n.group`), tandis que le groupe **hérité de Firestore**
> affichait bien son nom et son compte de membres — ce qui prouve la cause.
>
> Contourné ici en lisant `conversation.name` (la conversation porte le nom du
> groupe dans `data->>'name'`, vérifié en base) AVANT `groupData`. Mais tout ce
> qui dépend vraiment de l'entité groupe reste vide pour les groupes Supabase :
> **permissions** (`canPostEvents`/`canPostPolls`/`canPin`), **rôle
> admin/modérateur**, **liste des membres** pour les mentions, image du groupe.
>
> ### ⛔ AGGRAVATION mesurée le 2026-08-06 : la fiche d'un groupe Supabase ne
> ### s'ouvre PAS DU TOUT
>
> Ce n'est pas seulement « le nom manque dans l'en-tête ». Ouvrir
> `https://diasponiger.web.app/groups/03077217-24d5-4cfa-9ec6-ed5b593c3cd2`
> (groupe « Diaspora Niger — Canada », bien présent dans Supabase) donne un
> écran **« Erreur de chargement » + « Réessayer »**, et rien d'autre.
> Reproduit deux fois, après relance à froid.
>
> Comparaison qui isole la cause : la fiche du groupe **hérité de Firestore**
> (`yflqsRLMMhTPpiW0NFHx`) s'affiche parfaitement — nom, description, « 1
> membre », créateur, bouton « Ouvrir la discussion ».
>
> Donc pour TOUT groupe créé dans Supabase, sont inaccessibles : l'ouverture de
> la discussion depuis la fiche, la liste des membres, quitter le groupe, le
> partager, et les réglages de notification du groupe. Seul le passage par la
> liste des messages (ou un lien profond vers la conversation) fonctionne
> encore, grâce au repli sur `conversation.name` posé plus haut.
>
> ### ✅ BASCULÉ le 2026-08-06, et vérifié sur appareil
>
> `groupRemoteDataSourceProvider` rend désormais `GroupSupabaseDataSource`.
> Celui-ci implémentait déjà l'intégralité de l'interface (le projet n'aurait
> pas compilé sinon) — il n'était simplement câblé nulle part.
>
> Avant / après, mesuré :
> - fiche d'un groupe Supabase : « Erreur de chargement » → **s'ouvre**
>   (nom, visibilité, description, membres, créateur, partage, menu) ;
> - onglet « Mes groupes » : les groupes Supabase étaient **invisibles**
>   (« 1 rejoint », le seul groupe Firestore) → « 2 rejoints », les deux
>   groupes Supabase ;
> - `_joinGroup` vérifié sur « teste » : `group_members` 0 → 1 ;
> - `_leaveGroup` vérifié dans la foulée : 1 → 0 (état restauré). La boîte de
>   confirmation s'ouvre, ce qui prouve au passage que le correctif « bouton
>   mort » de ces deux méthodes fonctionne — elles n'étaient pas testables
>   jusqu'ici.
>
> - [x] **Migration des groupes hérités : PASSÉE le 2026-08-06.**
>   `yflqsRLMMhTPpiW0NFHx` → `2b24986f-08b5-4840-9931-dbe046ffb394`, avec sa
>   conversation (1), son message (1) et son membre (Sim A, rôle `admin`).
>   Contrôles : 0 conversation orpheline, garde-fou réactivé. Vérifié sur
>   appareil : « Groupe de test prive » réapparaît dans « Mes groupes », servi
>   cette fois par Supabase.
>
>   Deux corrections apportées au script AVANT de le lancer :
>   1. `select distinct … gen_random_uuid()` calculait l'uuid **par ligne** :
>      un groupe portant deux conversations aurait reçu deux identifiants
>      différents. Remplacé par un `GROUP BY` en amont.
>   2. Le réalignement se faisait par **nom** — deux groupes homonymes
>      l'auraient cassé. L'ancien identifiant est désormais conservé dans la
>      description (`[migré de <id>]`) et sert de clé de rapprochement.
>
>   Et un obstacle rencontré à l'exécution : le trigger
>   `enforce_group_creator_trigger` refuse tout insert sans `firebase_uid` dans
>   le JWT (il force `creator_id` depuis le jeton vérifié — c'est ce qui
>   empêche de créer un groupe au nom d'autrui). Une migration passe par un
>   rôle admin, sans JWT utilisateur. Il est donc désactivé **dans la
>   transaction** puis réactivé : `ALTER TABLE` étant transactionnel, un échec
>   le rétablit par ROLLBACK — aucune fenêtre sans garde-fou. Vérifié après
>   coup : `tgenabled = 'O'`.
> - [x] **`member_count` recalé** (`tools/recount_group_members.sql`). Il valait
>   0 alors que `group_members` avait des lignes : la fiche affichait
>   « Membres · 0 » tout en listant le créateur, et proposait « Rejoindre » à
>   quelqu'un déjà membre. Le trigger `group_members_count_trigger` existe mais
>   n'avait jamais rattrapé les lignes antérieures à sa création. Script
>   idempotent, contrôle à 0 ligne d'écart.
> - [x] ✅ **Le « décalage » 1 groupe vs 2 N'EXISTAIT PAS.** Instrumentation :
>   la RPC `get_my_groups` rendait bien **3 lignes**, et l'écran les affiche
>   toutes — « 3 rejoints ». Mes relevés précédents étaient pris **trop tôt**,
>   avant la fin d'un chargement asynchrone. Leçon : sur cet écran, lire l'état
>   APRÈS une capture d'écran qui montre la liste peuplée, pas au bout d'un
>   délai fixe.
> - [x] **Marqueur de migration retiré de la description.** La description est
>   affichée à l'utilisateur sous le nom du groupe : le
>   `[migré de yflqsRLMMhTPpiW0NFHx]` que le script y posait apparaissait en
>   clair dans la liste (constaté sur appareil). Il est désormais effacé en fin
>   de migration — il ne servait qu'au rapprochement interne.
> ### `country_code` : sources corrigées, données à normaliser (2026-08-06)
>
> Les DEUX tables mélangeaient codes ISO et libellés — `users.country_code`
> contenait `Niger` à côté de `NE`, `BF`, `CA` ; `groups.country_code` avait
> `Canada` à côté de `CA`. Toute comparaison d'égalité échouait donc en
> silence : filtre par pays de la liste des groupes, et
> `availableGroupCountriesProvider` qui dérive de cette colonne.
>
> **Les deux sources d'écriture sont corrigées** — la base ne se salira plus :
> - `profile_supabase_datasource` écrivait `currentCountry`, qui vient du
>   géocodage inverse sous forme de libellé (« Canada ») ;
> - `create_group_screen` écrivait un libellé de sa liste `_hostCountries`
>   codée en dur (« Niger », « États-Unis »…).
> Les deux passent maintenant par `CountryExtension.toIsoCode()`, qui a été
> ajouté. `Country.fromString` reconnaît désormais aussi le **libellé** (il ne
> comparait que le code et le nom d'énumération, donc aucun nom composé) et
> ignore accents et ponctuation — sans quoi « États-Unis » ne correspondait pas
> à `Etats-Unis`, et « Côte d'Ivoire » pas à `Cote d'Ivoire`.
>
> ⛔ **Trouvé en tentant la normalisation : DEUX groupes officiels pour le
> Canada.** « Diaspora Niger — Canada » (`Canada`, 16/07, 1 membre, 5 messages)
> et « Diaspora Niger — CA » (`CA`, 20/07, totalement vide). L'index unique
> partiel `uniq_official_group_per_country` aurait dû l'empêcher, mais les deux
> écritures différaient. C'est le MÊME enchaînement que le défaut n°1 :
> `ensureOfficialGroup` a cherché par `CA`, n'a pas trouvé le groupe rangé sous
> `Canada`, et en a créé un second.
>
> - [x] **Données normalisées le 2026-08-06.** Le script complet ayant été
>   refusé par le garde-fou de sécurité (son `UPDATE` conditionnel), les
>   opérations ont été passées une par une, en clair :
>   `groups.Canada→CA`, `groups.Niger→NE`, `users.Niger→NE`,
>   `users.''→NULL`, et déclassement du doublon.
>   **Contrôle : plus aucune valeur de plus de 2 caractères** dans les deux
>   tables. État final — un seul groupe officiel par pays :
>
>   | Groupe | code | officiel | membres |
>   |---|---|---|---|
>   | Diaspora Niger — Canada | `CA` | ✅ | 1 |
>   | Diaspora Niger — CA | `CA` | déclassé | 0 |
>   | teste | `NE` | — | 1 |
>   | Testeurs | `NE` | — | 1 |
>   | Groupe de test prive | `null` | — | 1 |
>
>   `tools/normalize_country_codes.sql` reste au dépôt : il est idempotent et
>   couvre bien plus de libellés que les trois rencontrés ici — il servira si
>   d'autres apparaissent.
>
> - [x] **Le repli du filtre est démontré par la donnée** (l'appareil est resté
>   débranché, mais ce cas se prouve sans lui). `availableGroupCountries` dérive
>   de `groups.country_code` : il vaut désormais `['CA', 'NE']` là où il valait
>   `['CA', 'Canada', 'Niger']`. Or `_loadDefaultCountryFilter` teste
>   `availableCountries.contains('NE')` — le test était donc **toujours faux**,
>   et le repli sur le Niger ne se déclenchait jamais. C'est mot pour mot ce
>   que le commentaire du code annonçait ; il est maintenant vrai.
>   Le profil de test a `country_code = null` (il portait `''`, sans effet : le
>   code testait déjà `!= null && isNotEmpty`), donc c'est bien la branche de
>   repli qui s'applique.
> - [x] **VÉRIFIÉ À L'ÉCRAN le 2026-08-06**, sur un APK construit depuis l'état
>   fusionné et poussé.
>   - Les puces de pays affichent « 🇨🇦 Canada » et « 🇳🇪 Niger » — drapeau et
>     libellé. C'est la preuve que les codes sont reconnus de bout en bout :
>     avec l'ancien mélange (`CA` / `Canada` / `Niger`), l'app ne pouvait pas
>     les convertir.
>   - Le filtre **discrimine** correctement : sur « Niger », le groupe `NE`
>     (« teste ») s'affiche ; sur « Canada », plus rien et le message
>     « Aucun groupe ne correspond à ces filtres » apparaît ; retour à « Tous »,
>     il revient.
>   - Le badge de « Diaspora Niger — Canada » affiche désormais `CA` et non
>     plus `Canada`.
>   - Le groupe migré est là, sa description est vide (marqueur `[migré de …]`
>     bien retiré), et le doublon supprimé n'apparaît plus nulle part.
> - [x] **La normalisation À L'ÉCRITURE est vérifiée de bout en bout** — par le
>   chemin normal de l'app, pas en SQL. Un groupe créé depuis « Créer un
>   groupe » avec le pays affiché « **Niger** » arrive en base avec
>   `country_code = '**NE**'`. Sans le correctif, la base aurait reçu le
>   libellé, comme les groupes « teste » et « Testeurs » créés avant. Le groupe
>   de test a été supprimé après contrôle.
> - [ ] Détail sans gravité relevé au passage : à l'ouverture, la puce active
>   est « Tous » et non « NE ». `_loadDefaultCountryFilter` lit
>   `availableGroupCountries` avant que les groupes ne soient chargés — la
>   liste est alors vide, donc aucune branche ne s'applique. Même famille que
>   les autres lectures trop précoces, mais ici le défaut est bénin : « Tous »
>   est un défaut raisonnable et le filtre reste utilisable.

> ### 🔴 `member_count` est incrémenté DEUX FOIS à la création d'un groupe
>
> Trouvé le 2026-08-06 en créant un groupe de test : `member_count = 2` pour un
> groupe qui n'a qu'une seule ligne dans `group_members` (son créateur).
>
> Deux mécanismes comptent le même membre :
> - la RPC `insert_group` pose un `member_count` initial dans la ligne
>   `groups` ;
> - le trigger `group_members_count_trigger` fait
>   `member_count = GREATEST(member_count + 1, 0)` à chaque INSERT dans
>   `group_members` — donc aussi pour le créateur que la RPC vient d'insérer.
>
> C'est l'autre face de l'incohérence déjà vue (« Membres · 0 » sur un groupe
> peuplé) : le compteur n'est jamais recalculé, il dérive dans les deux sens.
>
> En relisant la fonction, le défaut est double — et la seconde moitié était
> invisible : `RETURNING * INTO v_row` capture la ligne **avant** l'insertion du
> membre, donc avant que le trigger n'agisse. La fonction renvoyait `1` pendant
> que la base contenait `2`. L'écran de création affichait donc un troisième
> chiffre, différent des deux autres.
>
> - [x] **Migration écrite** :
>   `supabase/migrations/20260806150000_insert_group_member_count.sql`.
>   Elle pose `member_count = 0` (le trigger compte le créateur juste après) et
>   relit la ligne après l'insertion du membre. Signature, `SECURITY DEFINER`
>   et garde `firebase_uid` inchangés.
> - [x] **APPLIQUÉE le 2026-08-06** par `supabase db push --linked
>   --include-all`. Le drapeau était nécessaire — et sûr : `migration list`
>   montrait une seule migration en attente (celle-ci), mais son horodatage
>   (15:00) est antérieur à une migration déjà appliquée (17:00), ce que
>   Supabase refuse par défaut.
>
>   ⚠️ **Premier essai en échec, et l'erreur était juste** :
>   `cannot remove parameter defaults from existing function` (42P13). La
>   fonction en place a des valeurs par défaut sur neuf de ses dix paramètres ;
>   ma réécriture ne les reproduisait pas, ce qui aurait cassé tout appelant
>   omettant un paramètre. Relevées via `pg_get_function_arguments` et
>   réintégrées à l'identique. PostgreSQL a évité la régression.
>
> - [x] **Vérifié sur appareil** : un groupe créé depuis l'app sort avec
>   `member_count = 1` pour 1 membre réel — juste dès la création, sans
>   recompte. `country_code = NE` au passage, la normalisation tient. Groupe de
>   test supprimé.
> - [x] Contournement en place en attendant :
>   `tools/recount_group_members.sql`, idempotent, relancé après ce test. Tous
>   les groupes sont à leur compte réel.
> - [x] **Doublon supprimé** (2026-08-06, sur décision explicite de Salim).
>   `25463f01-a148-4304-8f35-a38e6d7efcfb` — « Diaspora Niger — CA », créé le
>   20/07 par la recherche qui échouait. Avant suppression, les **neuf** tables
>   portant un `group_id` ont été contrôlées, pas seulement les trois évidentes :
>   `conversations`, `e2ee_sender_key_distributions`, `events`,
>   `group_invites`, `group_members`, `group_pinned_items`, `group_requests`,
>   `post_polls`, `posts` — **toutes à 0**. La ligne a été relevée avant
>   l'ordre, elle figure dans l'historique de la session si besoin de la
>   recréer.
>
>   Inventaire final — 4 groupes, un seul officiel par pays :
>
>   | Groupe | code | officiel | membres |
>   |---|---|---|---|
>   | Diaspora Niger — Canada | `CA` | ✅ | 1 |
>   | teste | `NE` | — | 1 |
>   | Testeurs | `NE` | — | 1 |
>   | Groupe de test prive | `null` | — | 1 |

### VÉRIFIÉ SUR APPAREIL le 2026-08-05 (SM A515F, APK debug de cette branche)

- [x] **Conversation de GROUPE par lien profond** → en-tête « Diaspora Niger
  … », avatar vert à icône groupe, sous-titre « Groupe », appels de groupe.
  Commande :
  ```
  adb shell am start -a android.intent.action.VIEW -d "https://diasponiger.web.app/messages/0ce4c63f-ef7a-4616-8d52-88f22444a4ca" -p com.diasponiger.diasponiger
  ```
- [x] **Groupe hérité Firestore par lien profond** (`68672ea9-…`,
  `yflqsRLMMhTPpiW0NFHx`) → « Groupe de test prive », « 1 membre », historique
  présent (plus de « Aucun message »).
- [x] **Retour depuis un lien profond** (bouton retour système) → liste des
  messages, plus d'écran noir.
- [x] **Non-régression 1-à-1** → « Salim L. », « En ligne », avatar terracotta,
  appels 1-à-1, bandeau épinglé « 1/3 ». Le nom du correspondant ne s'affichait
  PAS avant (« Utilisateur ») : `otherUserId` n'était pas réconcilié non plus,
  corrigé dans la même passe.
- [x] **Bandeau épinglé** visible et fonctionnel sur le DM (correctif « épingle
  portée par la conversation »).
- [x] **Liste des messages** : les deux groupes réapparaissent avec leur nom, et
  la tuile « Mes notes » a retrouvé son sous-titre « Notes, brouillons et
  sondages ». Avant le correctif, les deux groupes étaient absorbés par la tuile
  « Mes notes » et absents du flux (« 2 groupes actifs » sans aucun groupe
  visible).
- [x] **Pas de recréation de conversation** : `count(*)` sur `conversations`
  inchangé (8 avant / 8 après), `yflqsRLMMhTPpiW0NFHx` toujours à 1 ligne.

Complément de vérification, 2026-08-06 :

- [x] **Menu ⋮ sur la conversation de groupe** → options de conversation
  (recherche, médias, sourdine, éphémères, archiver, fond, favoris, exporter,
  signaler) et **pas** l'option « Bloquer », qui est gardée par
  `!isGroup && otherUserId != null` dans `ConversationOptionsModal`. C'est la
  preuve que le drapeau est correct sur ce chemin.
- [x] **Flèche de l'en-tête depuis un lien profond** → ramène à la liste des
  messages, pas d'écran noir. Les trois sorties du retour sont donc couvertes
  (bouton système, flèche ; le geste de bord emprunte le même `PopScope`).

- [ ] Même conversation, ouverte par NOTIFICATION (`state.extra` également nul) :
  même en-tête. Non testé — pas de push déclenchable simplement depuis le poste.
- [ ] Nom de l'expéditeur + mini-avatar sur les messages REÇUS d'un tiers, et
  badge « Admin ». Non testé : les deux groupes de test n'ont qu'un membre, donc
  aucun message entrant. **Script SQL prêt** (`scratchpad/donnees_test.sql`) —
  l'écriture en base de production a été refusée par le garde-fou de sécurité,
  elle doit être lancée à la main.
- [ ] Épingler puis détacher un message depuis ce chemin.
- ⛔ **Menu « + » du composer (sondage / événement) : NON TESTABLE en l'état.**
  `canCreateEvent` et `canCreatePoll` dérivent de `groupData?.permissions`,
  donc de `groupStreamProvider` — câblé sur Firestore. Pour un groupe Supabase
  `groupData` est null, les deux sont donc `false` par construction. Cette case
  ne pourra être vérifiée qu'après le basculement du datasource des groupes.
- ⛔ **Bouton « Ouvrir la discussion » sur un groupe Supabase : NON TESTABLE.**
  On ne peut même pas atteindre le bouton — la fiche du groupe affiche
  « Erreur de chargement » (voir l'encadré Firestore plus haut).
- [x] **Recréation par le VRAI chemin — PROUVÉ le 2026-08-05.** Le lien profond
  ouvre la conversation par son id et ne passe PAS par
  `createGroupConversation` ; le compte inchangé ne prouvait donc rien. Refait
  par le vrai chemin (fiche du groupe → « Ouvrir la discussion »), **deux fois
  de suite** sur `yflqsRLMMhTPpiW0NFHx` : la même conversation se rouvre avec
  son historique, `count(*)` = 8 avant / 8 après, groupe hérité 1 / 1.

  ⚠️ Ce test a d'abord été **impossible** : le bouton « Ouvrir la discussion »
  était MORT (voir ci-dessous).

**4. « Ouvrir la discussion » était un bouton mort** (défaut pré-existant,
trouvé en voulant prouver le n°1, corrigé le 2026-08-05).
`ConversationNotifier.createGroup` lisait
`_ref.read(currentUserAsyncProvider).valueOrNull` — or c'est un StreamProvider
**autoDispose** que cet appel ne regarde jamais : la lecture démarrait
l'abonnement à l'instant du tap et rendait `AsyncLoading`, donc `null`, d'où un
`return null` **avant même** de toucher au dépôt. Comme `state` n'était jamais
mis en erreur, l'écran affichait « Erreur lors de l'ouverture de la
discussion » *sans la moindre cause*, et rien ne sortait dans logcat.
Exactement le piège déjà rencontré et commenté dans `_createGroup` de
`create_group_screen.dart`. Correctif : `await read(...future)` + une vraie
erreur dans `state`.

- [x] Vérifié sur appareil : le bouton ouvre bien la discussion, deux fois de
  suite, sur le groupe hérité.
- [ ] Refaire sur un groupe **Supabase** (`03077217-…`), non testé.
- [x] **Audit ciblé mené le 2026-08-06.** Critère retenu : occurrence suivie
  d'un abandon silencieux (`return`, `return null`, `return false`) dans un
  fichier qui ne `watch` pas ce provider. Point structurel confirmé : **aucun
  `watch(currentUserAsyncProvider)` au niveau racine/shell** — il n'est
  maintenu vivant que par 24 sites dispersés, donc rien ne le garde chaud. Et
  `currentUserProvider` est un provider **différent** : le watcher ne maintient
  pas l'autre (c'est ce qui piégeait la fiche de groupe).
- [x] **`conversation_actions_provider` (6 méthodes) — CORRIGÉ ET VÉRIFIÉ.**
  `muteConversation`, `archiveConversation`, `deleteConversation`,
  `reportConversation`, `reportMessage`, `reportGroup` rendaient toutes `false`
  sans rien faire — et les appelants **ignorent ce booléen**, donc aucune
  erreur n'était affichée. Preuve sur appareil avec la cloche « Couper les
  notifications » de la fiche de groupe : avant, `data->'mutedBy'` restait
  `null` malgré le tap ; après, il passe à
  `{"vQZE49…": "forever"}`, et le re-tap le vide (`{}`). Les deux sens
  vérifiés.
- [x] **`group_detail_screen` (3 méthodes) — CORRIGÉ, non testé.**
  `_requestToJoin`, `_joinGroup`, `_leaveGroup` sortaient sur un `return` nu.
  C'est le même écran où « Ouvrir la discussion » était prouvé mort, donc le
  provider y est bien éteint. Non testés faute de jeu de données : il faut un
  groupe non rejoint (join) et accepter de quitter un groupe (leave).
  ⚠️ `_leaveGroup` a reçu un `if (!mounted) return;` après l'attente —
  l'analyzer signalait un `BuildContext` traversant un saut asynchrone.
- [x] **Deuxième passe le 2026-08-06 — 8 fichiers, 41 sites corrigés.**
  `admin_settings_screen` (6 × `_save`/`_saveUrls`/`_saveIntervals`),
  `groups_screen` (3), `blocked_users_provider` (2),
  `notification_provider` (2), `media_gallery_provider` (2),
  `group_request_provider` (2), `group_call_provider` (6),
  `audio_room_provider` (18).

  Trois sites **volontairement laissés** en lecture synchrone, leurs méthodes
  n'étant pas `async` : `groups_screen._loadDefaultCountryFilter`,
  `group_call_provider._checkIfLastParticipant`,
  `audio_room_provider.retryAudioConnection`. Y mettre un `await` ne
  compilerait pas.

  Deux pièges rencontrés, à connaître avant toute nouvelle passe :
  - **précédence** : `read(p).valueOrNull?.id` devient
    `(await read(p.future))?.id` — sans les parenthèses le `await` porte sur
    la mauvaise expression (1 cas, `group_call_provider`) ;
  - **`BuildContext` après saut asynchrone** : `groups_screen._leaveGroup` a
    dû recevoir un `if (!mounted) return;` (l'analyzer l'attrape).

- [x] **Vérifié sur appareil** : « Tout lire » de l'écran Notifications
  (`markAllAsRead`). Avant : « 7 non lues », badge 7 sur la puce, bouton
  présent. Après : compteur, badge, bouton et pastilles disparus, icônes en
  état lu.
- [ ] Non testés faute de jeu de données ou de droits : les 6 `_save` de
  l'admin (compte admin requis), bloquer/débloquer, join/leave de groupe,
  galerie média, appels de groupe, salons audio.
- [x] **Troisième passe — `message_provider` (15 sites), le plus gros
  gisement.** Il avait 16 occurrences pour 16 abandons silencieux, et seul
  `createGroup` avait été traité. Corrigés : `toggleStar`, `editMessage`,
  `forwardMessage`, `deleteForMe`, `createIndividual`, `ensure` (Mes notes),
  les deux `mark` (lu / distribué), `acceptRequest`, `declineRequest` et les
  cinq envois à paramètres nommés. `_preEstablishE2EESessions` (ligne 157)
  reste en lecture synchrone : méthode non `async`.

  **Vérifié sur appareil — c'est le plus parlant du lot** : la conversation
  `883c9d96-…` affichait **4 non lus**. Elle avait déjà été ouverte à 10:56
  pendant le test de non-régression du DM, et le compteur était **resté à 4** :
  `markAsRead.mark()` ne faisait donc rien. Après correctif, une simple
  ouverture le remet à `0`. Autrement dit, **les messages ne se marquaient pas
  comme lus** — le badge de la liste et celui de la barre de navigation
  restaient donc allumés indéfiniment.

- [x] **Quatrième passe — 15 sites** : `heritage_provider` (8),
  `notification_preferences_provider` (3), `create_event_screen` (1),
  `add_payment_account_screen` (1), `typing_indicator_provider` (1),
  `create_business_screen` (1). `create_event_screen._prefillLocation` laissé
  synchrone (non `async`). `create_event_screen._createEvent` a reçu un
  `if (!mounted) return;`.

- [x] 🔴 **Découverte : le piège n'est pas propre à `currentUserAsyncProvider`.**
  En vérifiant l'interrupteur maître des notifications, l'UI basculait mais
  `users.notifications_enabled` ne bougeait pas. Cause : un **second garde de
  la même famille** juste en dessous —
  `ref.read(profileNotifierProvider(userId)).valueOrNull`, sur un
  `StateNotifierProvider.autoDispose` dont le `_loadProfile()` ne pose `state`
  de façon synchrone que s'il trouve un cache. Sans cache, l'étage serveur
  était sauté en silence : la bascule n'éteignait que l'affichage local, et
  **le back-end continuait de pousser** alors que l'interrupteur affichait
  « désactivé » — exactement ce que le commentaire du code disait vouloir
  éviter. Un `StateNotifierProvider` n'a pas de `.future` : le correctif
  retombe explicitement sur le dépôt (`_loadProfileFor`).

  Vérifié sur appareil : `enabled=false` → `profile=ok` →
  `users.notifications_enabled = false`, puis remis à `true`.

  ⚠️ **Leçon de méthode** : deux mesures intermédiaires ont été jetées avant
  celle-ci. La préférence **locale** et la colonne **serveur** s'étaient
  désynchronisées à force d'essais, si bien que le tap rejouait parfois la
  valeur déjà en base — l'absence de changement ne prouvait alors rien. Il faut
  lire l'état des DEUX côtés avant de taper, et instrumenter plutôt que de
  déduire.

- [x] **Cinquième passe — audit des AUTRES providers, et révision à la baisse.**
  L'estimation « 24 sites suspects » de la passe précédente était **fausse** :
  le filtre portait sur la mauvaise ligne du `grep -A 1`. Mesure refaite :

  - Providers non-family lus en `.valueOrNull` avec abandon
    (`currentUserProvider` ×25, `appSettingsNotifierProvider` ×5,
    `blockedUsersProvider`, `activeStoriesProvider`, …) : **zéro** site sans
    `watch` local. Le provider est chaud partout où il est lu — rien à faire.
  - Providers **family** (que le regex précédent ratait, d'où l'angle mort qui
    avait laissé passer `profileNotifierProvider`) : `profileNotifierProvider`
    est lu sans `watch` local dans 7 fichiers. En les lisant un par un, la
    plupart sont des **pré-remplissages avec repli gracieux**
    (`profile?.currentCountry`) dans des méthodes non `async` — dégradation
    acceptable, pas un blocage : `business_provider._loadUserLocation`,
    `create_product_screen._initUserCountry`,
    `create_event_screen._prefillLocation`, `story_rail`,
    `marketplace_provider`. `edit_profile_screen` a déjà un `else` de repli.

- [x] **Un seul vrai défaut trouvé, corrigé** :
  `profile_config_screen._handleComplete` levait `Exception(_kProfileMissing)`
  quand le cache était vide, donc **l'enregistrement du profil échouait au
  premier essai** sur « Profil introuvable » ; il fallait toucher
  « Réessayer », le second essai trouvant le cache chaud. Le profil est
  maintenant chargé depuis le dépôt avant d'abandonner.
  - [ ] À vérifier sur appareil : reprendre l'assistant de configuration de
    profil et enregistrer du premier coup, sans passer par « Réessayer ».

- [ ] Ce filon est donc **épuisé pour l'essentiel**. Ce qui reste
  (`monetization_provider` ×11, sans aucun abandon silencieux ; les 4 méthodes
  non `async` laissées volontairement ; les 2 de `call_provider`) n'a pas
  d'impact utilisateur démontré. Ne pas y retourner sans un défaut constaté.
  ⚠️ `call_provider` (2) reste délibérément intact : `initiateCall` **pose**
  une erreur (« Utilisateur non connecté ») donc n'est pas silencieux, et son
  `build()` amorce l'abonnement via `_cleanupStaleCalls()` bien avant qu'on
  puisse taper « appeler ». Le vérifier demande de passer un vrai appel.

> Note d'exécution : un ANR (« Diaspo Niger ne répond pas ») a été observé UNE
> fois juste après une installation à chaud par-dessus l'app en cours
> d'exécution, sur ce même écran. Non reproduit après `force-stop` puis
> relance — le mute a alors fonctionné du premier coup. Probablement un artefact
> de la réinstallation à chaud (la 6e de la session), pas du correctif ; à
> resurveiller quand même.

**3. `isSelfNotes` avait exactement le même défaut** (trouvé en corrigeant le
n°2, corrigé dans la foulée le 2026-08-05). `app_router.dart` lisait
`extra?['isSelfNotes'] as bool? ?? false` : ouvrir « Mes notes » par lien
profond la rendait comme un fil ordinaire — titre tiré du profil au lieu de
« Mes notes », avatar sans le marque-page, boutons d'appel présents, et menu
« + » sans le brouillon de sondage. Même correctif : `_isSelfNotes` dérivé de
`ConversationEntity.isSelfNotesFor(currentUserId)` (participant unique = moi).
Tant que l'utilisateur courant n'est pas chargé, la valeur connue est
conservée plutôt que de conclure « non » à tort (sinon le titre clignote).

- [ ] Ouvrir « Mes notes » par lien profond : titre « Mes notes », avatar
  marque-page, aucun bouton d'appel, pas d'indicateur de présence.
- [ ] Menu « + » du composer dans ce cas : le brouillon de sondage doit être
  proposé (et pas l'événement).
- [ ] Non-régression : depuis la tuile épinglée de la liste des messages, rien
  ne doit changer.

---

## Le « OVERFLOWED BY 190 » de la recherche venait du rail latéral (2026-08-05)

Le bandeau rayé se voit **depuis** l'écran de recherche de la messagerie, mais
le `RenderFlex` fautif est au-dessus de cet écran dans l'arbre : c'est
`TabletNavigationRail` (`lib/shared/widgets/tablet_navigation_rail.dart`).

La chaîne :

1. `MainShell` bascule sur le layout « tablette » dès **700 dp de large**
   (`_kTabletBreakpoint`). Un SM A515F en paysage fait `2400 / 2.625 = 914 dp`
   de large pour seulement **411 dp de haut** : le téléphone en paysage passe
   donc par le rail latéral, pas par la barre du bas.
2. Le rail est une `Column` de cinq items à hauteur intrinsèque (~68 dp
   chacun, **~352 dp** au total), sans défilement, premier enfant d'une `Row` :
   il est borné par la hauteur du corps.
3. `resizeToAvoidBottomInset` (défaut) réduit le corps à ~170 dp quand le
   clavier monte. `352 − 170 ≈ 190`. Le clavier ne monte sur cet écran qu'en
   mode recherche — d'où la corrélation trompeuse avec la recherche.

Pourquoi le bandeau paraît « au milieu, à gauche » : pour un débordement en
bas, Flutter dessine l'étiquette au centre horizontal du widget fautif (le
rail : 43 dp) et à mi-hauteur de la zone débordée. Ça tombe sur le bord gauche,
à hauteur de la zone de résultats — d'où la fausse piste.

**Correctif** : le rail défile (`SingleChildScrollView` + `mainAxisSize.min`)
au lieu de forcer sa hauteur. Tant qu'il y a la place, rien ne change à
l'écran (les items étaient déjà alignés en haut).

**La colonne de l'écran de recherche n'a pas été touchée** : en mode recherche
elle n'a que ~65 dp d'incompressible (l'en-tête et les puces de filtre sont
retirés, la zone de résultats est déjà `Expanded` + `ListView`). Elle ne peut
pas produire 190. Et ses deux gardes anti « deux taps pour lever le clavier »
(la `ValueKey` sur le bloc du champ, le type de widget constant) interdisent de
la restructurer sans raison.

Couvert par `test/features/shell/tablet_navigation_rail_landscape_test.dart`
(sans le correctif : `overflowed by 170 pixels` à 172 dp, `222` à 120 dp).

À vérifier sur l'appareil :

- [ ] **Paysage + clavier** (`adb shell settings put system user_rotation 1`),
      messagerie → taper dans le champ de recherche : **aucun bandeau rayé**,
      et zéro `RenderFlex … overflowed` dans logcat.
- [ ] **Les cinq items du rail restent atteignables** clavier levé : faire
      défiler le rail du doigt et taper « Profil » — la navigation doit partir.
      Vérifier aussi que ce défilement ne vole pas le geste au contenu à droite.
- [ ] **Portrait + clavier**, même écran : le rail ne doit pas apparaître du
      tout (largeur < 700 dp), la barre du bas reste en place, rien ne déborde.
- [ ] **font_scale 1.1** en paysage clavier levé : toujours aucun bandeau, et
      les libellés du rail ne sont pas coupés en plein mot.
- [ ] **Retour au portrait** après avoir fait défiler le rail : pas d'état de
      défilement résiduel qui décalerait la barre du bas.

### Le paysage fait basculer TROIS bascules « large », pas une

À 914 dp de large, le téléphone en paysage franchit trois seuils indépendants.
Il faut donc lire tout bug de paysage comme un bug de **mode tablette** :

| Seuil | Où | Ce qui bascule | État |
|---|---|---|---|
| 700 dp | `main_shell.dart` (`_kTabletBreakpoint`) | rail latéral au lieu de la barre du bas | **débordait — corrigé** |
| 700 dp | `feed_screen.dart:179` | rail droit (filtres villes + hashtags), FAB 64 au lieu de 52 | sain : le rail droit est une `ListView` |
| 600 dp | `responsive_service.dart` (`isTablet`) | `profile_screen` passe en largeurs tablette | sain : ce ne sont que des `maxWidth` dans des slivers |

Le seuil admin (`admin_dashboard_screen.dart:226`, 1200 dp) n'est pas franchi
en paysage. Vérifier quand même à l'œil, une fois, que le fil et le profil en
paysage ne sont pas juste « non débordants » mais **utilisables** :

- [ ] **Fil en paysage** : le rail droit de 330 dp ne mange pas la colonne
      centrale (elle passe de 640 à ~498 dp), et le FAB à 64 ne recouvre pas le
      dernier post.
- [ ] **Profil en paysage** : contenu centré, pas collé au rail de gauche.

Restent ouverts, même famille : le `BOTTOM OVERFLOWED BY 240` de la
conversation (ci-dessus), et le `PodcastMiniPlayer` (hauteur fixe 64, hors
`Expanded` dans la branche paysage de `MainShell`) qui déborderait si le corps
tombait sous 64 dp — non observé, non corrigé.

---

## Groupes — « Découvrir » lisait le mauvais backend (2026-08-06)

**Cause trouvée, et ce n'était pas dans `loadGroups()`.** L'onglet annonçait
« Aucun groupe public » alors que `public.groups` en contient trois
(`Diaspora Niger — CA`, `Diaspora Niger — Canada`, `teste`, tous
`is_private = false`). `loadGroups()` faisait exactement ce qu'on lui
demandait : il interrogeait **Firestore**, dont la collection `groups` est
vide depuis la migration.

`groupRemoteDataSourceProvider` (`group_provider.dart`) rendait
`GroupRemoteDataSourceImpl` (Firestore) **depuis le commit initial, sans une
seule modification**. C'est le seul point de câblage de toute la
fonctionnalité : liste, découverte, fiche, création, adhésion, recherche.
Tout le travail accumulé sur `GroupSupabaseDataSource` — session avant
lecture, appartenance lue dans `group_members`, garde « Officiel » — portait
donc sur une classe que rien n'instanciait.

Deux autres symptômes s'expliquent par le même câblage :

- **Le groupe officiel du pays n'était jamais rejoint.**
  `GroupRemoteDataSourceImpl.ensureOfficialGroup` lève `UnimplementedError`,
  que `GroupRepositoryImpl` convertit en `Left(...)`, que
  `ProfileNotifier._joinOfficialGroup` avale (`(failure) async {}`).
- **La recherche ne remontait aucun groupe** (`search_provider.dart`,
  `search_remote_datasource.dart`, qui instanciaient la même classe).

`loadGroups()` est désormais instrumenté (`[groupes] loadGroups source=… /
cache=… / réseau=…`, `kDebugMode`) : les quatre issues indistinguables
jusqu'ici — cache servi, réseau vide, échec avalé, mauvais backend — se lisent
en une ligne de logcat.

⚠️ **Le même correctif existe déjà sur `claude/silly-liskov-1e9d62`**
(commit `c803893`, 2026-08-06), avec 15 autres commits que cette branche n'a
jamais reçus. Voir la section « Deux branches » plus bas.

À vérifier sur l'appareil :

- [ ] **« Découvrir »** : les trois groupes publics apparaissent. Filtrer sur
      « Tous » les pays d'abord — le filtre pays par défaut se pose sur le pays
      du profil, ou sur `NE` à défaut, et ne laisserait qu'un seul groupe.
- [ ] **Journal** : `adb logcat | grep "\[groupes\]"` affiche
      `source=GroupSupabaseDataSource` puis `réseau=3 groupes`.
- [ ] **Recherche de groupes** (loupe de l'écran Groupes) : taper « niger »
      remonte bien les deux groupes « Diaspora Niger ».
- [ ] **Groupe officiel du pays à l'inscription** : renseigner un pays dans le
      profil doit désormais faire apparaître son groupe officiel dans
      « Mes groupes » (chemin `ensureOfficialGroup`, jamais exécuté jusqu'ici).

### §9c — le nom du groupe était rogné par les pastilles de sa carte

Sur un écran de 360 dp, la colonne de texte de `_GroupCard` ne fait que
~140 dp : écran 360 − marge 32 − padding de carte 28 − avatar 52 − écart 14 −
écart 8 − bouton « Rejoindre » ~86. L'ancienne ligne de titre y logeait, en
plus du nom, un cadenas (13), une pastille « Officiel », une épingle (14) et
une pastille ACTIF/CALME — **les deux pastilles à largeur libre, et le nom
seul `Flexible`**. Il cédait donc toujours en premier ; et quand les pastilles
dépassaient à elles seules les 140 dp, la ligne débordait carrément (mesuré :
`RenderFlex overflowed by 88 pixels`).

Correctif : les deux pastilles descendent dans la ligne de méta, passée de
`Row` à `Wrap` (elles y restent entières et vont à la ligne au lieu de rogner
le nom de ville) ; la ligne de titre ne garde que le nom, le cadenas et
l'épingle ; et le nom passe à `maxLines: 2`, sans quoi « Diaspora Niger —
Canada » (~175 dp) ne tiendrait toujours pas dans les ~101 dp restants.

Verrouillé par `test/features/groups/group_card_title_truncation_test.dart`
(6 cas, dont deux de régression qui prouvent le débordement d'avant).

- [ ] **Carte d'un groupe officiel, épinglé, actif** : le nom complet est
      lisible (sur deux lignes si besoin), les pastilles « Officiel » et
      ACTIF/CALME sont visibles en bas de carte, **aucun bandeau rayé**.
- [ ] **font_scale 1.1**, même carte : toujours aucun débordement, la ligne de
      méta passe à deux rangs si nécessaire.
- [ ] **Nom très long** (créer un groupe au nom de 60 caractères) : il s'élide
      proprement au bout de la 2ᵉ ligne, sans pousser le bouton hors carte.

### §9e — pourquoi il paraissait inatteignable, et comment l'atteindre

L'item « Messagerie — état vide » était noté inatteignable parce que la
messagerie du compte n'est plus vide. **C'est vrai pour une moitié seulement**
de la fiche. En lisant `messages_screen.dart`, il y a deux déclencheurs
distincts :

| Partie de 9e | Condition | Atteignable aujourd'hui |
|---|---|---|
| **Le corps** (pastille ronde, titre, amorces nommées, CTA, ligne chiffrement) — `_buildEmptyState` | la liste **filtrée** est vide | **oui** |
| **Le chrome** (ni champ de recherche, ni puces de filtre, ni entrée « Archives ») — `isEmptyInbox` | la liste **entière** est vide | non |

Le corps se déclenche donc sans compte neuf :

- [ ] **Puce « Non lus » alors que rien n'est non lu** → le corps de 9e
      s'affiche. C'est le chemin le plus rapide.
- [ ] **Puce « Groupes » sur un compte sans conversation de groupe** → idem.
- [ ] **Archiver toutes les conversations** puis revenir sur « Tous » → idem,
      avec la tuile « Mes notes » conservée au-dessus.

Le chrome de 9e, lui, demande une liste `conversations` réellement vide :
**archiver ne suffit pas**, `isEmptyInbox` lit la liste avant filtrage. Il faut
un compte neuf.

- [ ] **Compte neuf, messagerie jamais utilisée** : vérifier l'absence du champ
      de recherche, des puces de filtre et de l'entrée « Archives » dans
      l'en-tête.

⚠️ **Défaut repéré au passage, non corrigé** : le corps de 9e dit « Aucune
conversation / Commencez à discuter » même quand la vérité est « aucune
conversation **non lue** » ou « aucun **groupe** ». Le message ment sur le
filtre actif. Hors périmètre des quatre points traités ici.

### Deux branches, seize commits d'écart

`claude/silly-liskov-1e9d62` porte 16 commits que `wip-jules-2025-12-29T23-58-34-776Z`
n'a jamais reçus, dont plusieurs déjà considérés comme « faits » :

| Commit | Sujet |
|---|---|
| `c803893` | bascule des groupes vers Supabase (le correctif ci-dessus) |
| `21b5200` | migration du groupe hérité Firestore |
| `c960ec4` | recalage de `member_count` |
| `6627217`, `a1a7190` | normalisation `country_code` en ISO-2 |
| `988f2c1`, `009c0d9`, `b9d94f3`, `12d1549`, `4283cdd` | actions mortes / sessions manquantes |
| `96d2711` | enregistrement du profil au premier essai |
| `6a1fef2`, `d59f785`, `074043d` | liens profonds de groupe, « Mes notes » |

La branche courante n'a qu'un commit propre en face (`6ff6438`). **Décider
explicitement d'un rapatriement** — sinon chaque correctif sera retrouvé une
troisième fois. Non fait ici : c'est une fusion de 16 commits sur une branche
qu'un agent tiers réécrit en parallèle.

✅ **Rapatriement fait le 2026-08-06** — pas par la fusion préparée ici mais
par une session parallèle, dans l'autre sens (`098414c`, `7d0758c` : la
branche partagée fusionnée dans `claude/silly-liskov-1e9d62`, puis ramenée).
Vérifié : `git merge-base --is-ancestor claude/silly-liskov-1e9d62 HEAD` répond
oui. La branche de fusion préparée est devenue **en retard de 511 lignes** sur
HEAD et aurait annulé la passe l10n de Jules ; elle a été supprimée (locale,
distante, worktree). Leçon retenue en mémoire : deux sessions sur la même
branche doivent avoir des périmètres disjoints.

---

## Messagerie — un filtre sans résultat n'est pas une messagerie vide (2026-08-06)

`_buildConversationList` branchait sur `filtered.isEmpty`, c'est-à-dire la
liste **après** application de la puce de filtre, et rendait alors la fiche 9e :
« Aucune conversation », « Commencez à discuter avec les membres de la
diaspora », le bouton « Nouvelle conversation », la ligne sur le chiffrement.

Sur la puce **« Non lus »** d'un compte dont tout est lu, les trois phrases
étaient fausses et l'action ne répondait pas au problème : il n'y avait rien à
commencer, il fallait revenir à « Tous ». Idem pour **« Groupes »** sur un
compte sans conversation de groupe — et c'est le cas du compte de test.

Les libellés justes existaient déjà dans les **deux** `.arb` —
`noUnreadMessages`, `noGroupConversations`, `showAllConversations` — mais
**aucun n'était référencé nulle part dans `lib/`**. La branche avait été prévue
puis oubliée. Aucun `.arb` n'a donc été touché (donc aucune collision avec la
passe l10n en cours).

Verrouillé par `test/features/messages/etat_vide_filtre_test.dart` (6 cas,
dont l'ordre des gardes et la non-mort des trois clés). Test de structure,
comme `reglages_sans_doublon_test.dart` : monter `MessagesScreen` exigerait
l10n, GoRouter, une session Supabase et une dizaine de providers, et
`_buildConversationList` est privée.

- [ ] **Puce « Non lus », tout étant lu** : « Aucun message non lu » + le lien
      « Afficher toutes les conversations », et **pas** la fiche 9e. Le lien
      doit ramener sur « Tous » avec la liste complète.
- [ ] **Puce « Groupes » sur un compte sans groupe** : « Aucune conversation de
      groupe », même sortie.
- [ ] **Messagerie réellement vide** (compte neuf) : la fiche 9e s'affiche
      toujours, elle — c'est elle qu'on ne voulait pas perdre.
- [ ] **Archives vides** et **recherche sans résultat** : inchangés, ils ont
      leurs propres états vides depuis toujours.
- [ ] **Thème sombre** sur les deux nouveaux états : l'icône est posée à
      `textTertiaryColor` à 50 %, le texte à `textSecondaryColor` — vérifier
      qu'ils restent lisibles.

### Le `country_code` n'est plus un problème (vérifié en base le 2026-08-06)

Signalé plus haut comme défaut ouvert « les codes pays mélangent ISO et noms ».
**C'est faux depuis la fusion** : `6627217` normalise à l'écriture et `a1a7190`
a repris l'existant. Relevé en base ce jour :

| table | valeurs |
|---|---|
| `groups.country_code` | `NE` ×3, `CA` ×1, `null` ×1 |
| `users.country_code` | `null` ×5, `CA` ×2, `NE` ×2, `BF` ×1 |

Et le mappage du profil est cohérent des deux côtés :
`profile_supabase_datasource.dart` lit `'currentCountry': row['country_code']`
et écrit via `CountryExtension.toIsoCode(...)`. Rien à corriger.

**Arête tranchée le 2026-08-06 : un groupe sans pays vaut désormais `NE`.**

Un groupe dont `country_code` est `null` est invisible dans « Découvrir » dès
qu'un filtre pays est actif — et l'app en pose un **toute seule** au premier
affichage (`_loadDefaultCountryFilter`). `_applyFilters` fait `g.country ==
_selectedCountry`, ce qui écarte les nuls sans que l'utilisateur ait rien
demandé, et rien à l'écran ne le dit. Un groupe était dans ce cas
(`2b24986f-08b5-4840-9931-dbe046ffb394`, « Groupe de test prive »).

Le défaut vit en une seule constante, `kDefaultCountryCode`
(`lib/core/models/country.dart`), qui remplace aussi les deux `'NE'` en dur de
`groups_screen.dart` — trois endroits décidaient du Niger séparément.

| Verrou | Où | Couvre |
|---|---|---|
| `kDefaultCountryCode` | `GroupSupabaseDataSource.createGroup` | toute création passant par l'app |
| idem | `create_group_screen.dart` | l'affichage immédiat, avant l'aller-retour |
| `UPDATE` | migration | le groupe déjà nul en base |
| `SET DEFAULT 'NE'` | migration | colonne omise à l'insertion |
| déclencheur `trg_groups_country_code_defaut` | migration | colonne fournie **nulle ou vide** — ce que `insert_group` fait, puisqu'il passe toujours `p_country_code` |

Le déclencheur plutôt qu'un `COALESCE` dans `insert_group` : la fonction est
`SECURITY DEFINER`, et la reproduire depuis `pg_proc` pour n'y changer qu'une
ligne fait courir un risque de dérive sans rapport avec le sujet.

✅ **Migration appliquée le 2026-08-06**, et inscrite dans
`supabase_migrations.schema_migrations` — elle est passée par
`db query --file` et non par `db push`, donc sans cette inscription
`supabase migration list` l'aurait montrée « en attente » pour toujours.

Relevé avant / après sur `public.groups` :

| `country_code` | avant | après |
|---|---|---|
| `NE` | 2 | **3** |
| `CA` | 1 | 1 |
| *(null)* | **1** | **0** |

Le groupe visé (`2b24986f-08b5-4840-9931-dbe046ffb394`, « Groupe de test
prive ») porte bien `NE`, et le `CA` n'a pas bougé — la reprise ne touche que
les nuls et les vides.

Les deux autres verrous sont vérifiés en base : `column_default` vaut
`'NE'::text`, et `trg_groups_country_code_defaut` existe.

**Le déclencheur est prouvé, pas seulement présent.** Il n'a pas pu être
éprouvé sur `public.groups` : un autre déclencheur, `enforce_group_creator()`,
refuse toute insertion sans JWT applicatif (« firebase_uid introuvable »), et
la session d'administration n'en a pas. La fonction a donc été montée sur une
table jetable, dans une transaction annulée — quatre cas, dont un contrôle
négatif :

| entrée | résultat |
|---|---|
| `NULL` (ce que passe `insert_group`) | `NE` |
| `''` | `NE` |
| `'   '` | `NE` |
| `'CA'` | **`CA`** — non écrasé |

Vérifié aussi par `test/core/models/pays_defaut_test.dart` (6 cas : le défaut
vaut bien `Country.niger.code`, c'est un code ISO-2 et pas un libellé, les deux
chemins de création le posent, plus aucun `'NE'` en dur dans l'écran des
groupes, et la migration est versionnée).

Reste à voir à l'écran — c'est tout ce que la base ne peut pas prouver :

- [ ] **Créer un groupe sans choisir de pays** : il doit apparaître dans
      « Découvrir » avec le filtre `NE`, et la fiche doit afficher « Niger ».
- [ ] **« Groupe de test prive » est de nouveau atteignable** : c'est un groupe
      **privé**, donc à chercher dans « Mes groupes » côté créateur, pas dans
      « Découvrir ».
- [ ] **Un groupe créé AVEC un pays** garde bien le sien à l'écran aussi.

---

## Notification push — le ciphertext AES sortait en clair dans l'aperçu (2026-08-13)

Signalé : « les pushnotifications affiche les messages crypté ».

**Cause.** `message_preview_for_notification` (SQL) ne masquait le contenu que
si `encryptionLevel = 'e2ee'` ou si `content` commençait par le préfixe legacy
`gcm:`. Mais le repli AES réellement utilisé aujourd'hui côté client
(`MessageCryptoService.encrypt1to1`/`encryptGroup`, quand aucune session
Signal n'est établie) écrit `encryptionLevel: 'aes'` et un `content` au format
`iv:base64ciphertext` (`EncryptionService.encryptText`) — qui ne matche pas
`gcm:%`. Ces messages tombaient dans la branche ELSE et exposaient le
ciphertext brut comme corps de la notification push, envoyé tel quel via FCM.

**Correctif** (`supabase/migrations/20260813140000_fix_push_preview_leaks_aes_ciphertext.sql`) :
toute valeur de `encryptionLevel` ('aes' OU 'e2ee') déclenche désormais le
preview générique par type (🔒 Nouveau message / 📸 Photo / …), comme c'était
déjà le cas pour 'e2ee' seul.

- [x] **Migration appliquée** (`supabase db push`, 2026-08-13, approuvée par
      Salim). `migration list` confirme les deux versions Local = Remote.

⚠️ **Pour Jules — j'ai touché ton fichier `20260813130000_fix_receipts_uuid_type_and_anon_grant.sql`.**
`db push` s'arrêtait dessus (42723 « mark_messages_as_delivered already
exists with same argument types ») et bloquait toute la file, ma migration
comprise. Cause : ton fichier `DROP`e bien la surcharge
`mark_messages_as_delivered(UUID, TEXT)` avant de recréer, mais pas la
surcharge `(TEXT, TEXT)` — celle-là existe depuis `20260720120300`, avant
`20260813120000`. J'ai ajouté le `DROP FUNCTION IF EXISTS
public.mark_messages_as_delivered(TEXT, TEXT);` manquant (même motif que les
deux `DROP` déjà là pour `mark_messages_as_read`), poussé, puis relancé
`db push` — passé, sans autre incident. Le fichier a maintenant un
paragraphe 3) dans son commentaire d'en-tête qui explique l'ajout. Si tu
avais une raison de ne PAS dropper cette surcharge (une autre fonction encore
dessus, un appelant qui en dépend), vérifie — je n'ai vu que l'échec du push,
pas ton intention complète sur ce fichier.

- [x] **Rejoué de bout en bout sur SM A515F (Sim A, `vQZE49dTdyRtLwSG6lMIbhAqoFG2`),
      2026-08-13.** Message de test inséré directement en base, forme repli
      AES exacte (`encryptionLevel: 'aes'`, `content` en `iv:base64...`),
      dans une vraie conversation Salim L. ↔ Sim A (`883c9d96-…`), donnée de
      test retirée après coup. Chaîne vérifiée à chaque étape :
      - ligne `notifications` produite par le trigger : `body = "🔒 Nouveau
        message"` — pas le ciphertext ;
      - `net._http_response` : `{"sent":1,"removed":0}`, FCM a accepté et
        livré au bon appareil ;
      - logcat de l'appareil : le payload est bien arrivé côté app
        (`FlutterFirebaseMessagingBackgroundService`, tentative de
        `showNotification` au bon timestamp).
      **Non vu à l'écran** : un bug sans rapport a empêché le rendu — voir
      ci-dessous. Le texte correct était déjà fixé sur le builder de
      notification avant que ce bug ne fasse échouer l'appel natif, donc rien
      n'indique que le fix lui-même serait en cause.
- [x] Ligne `notifications` in-app : même colonne `body`, donc même preuve
      que ci-dessus — pas rejoué séparément à l'écran.
- [ ] Les lignes `notifications` déjà en base avant ce correctif gardent leur
      `body` en ciphertext (une UPDATE de rattrapage n'a pas été tentée — trop
      de risque de mal cibler les lignes) : à purger ou ignorer selon la
      politique de rétention choisie.

### Bug sans rapport trouvé en vérifiant : les icônes d'action de notif n'existent pas

`DrawableResourceAndroidBitmap('@drawable/ic_reply')` et
`'@drawable/ic_mark_read'` ([notification_service.dart:1790](lib/core/services/notification_service.dart:1790),
[:1802](lib/core/services/notification_service.dart:1802)) référencent des
ressources absentes de `android/app/src/main/res/` (`find` : aucun fichier
`ic_reply*`/`ic_mark_read*`, aucune densité). Résultat mesuré sur l'appareil :
`IllegalArgumentException: Drawable resource ID must not be 0` dans
`FlutterLocalNotificationsPlugin.getIconFromSource` →
`showNotification` échoue **pour toute notification de type message** (ces
deux actions ne sont ajoutées que si `type == 'message' && conversationId !=
null` — donc pratiquement tous les messages de chat), silencieusement, sans
crash visible côté utilisateur.

Pas su si ça touche aussi le cas app tuée/arrière-plan (où Android peut
afficher directement le champ `notification` FCM sans passer par ce code) —
seul le premier plan (`onMessage` → `_showLocalNotification`) a été exercé.

- [x] **Corrigé et vérifié sur SM A515F, 2026-08-13** (à la demande de
      Salim). Dix PNG générés (System.Drawing, PAS de vector — cf l'incident
      du 2026-08-06 où un vector avait fait disparaître toutes les
      notifications) aux 5 densités pour `ic_reply` et `ic_mark_read`.
      Rebuild (`flutter build apk --debug`, ~130 s Gradle) + réinstall
      (`adb install -r`, session Firebase et clés E2EE conservées) +
      **même test rejoué** : plus d'exception, la notification poste avec
      les deux actions visibles (« Répondre », « Marquer comme lu ») et le
      bon texte —
      ```
      android.title = "Salim L."
      android.text  = "🔒 Nouveau message"
      actions: [0] "Répondre"  [1] "Marquer comme lu"
      ```
      Donnée de test retirée après coup.
- [x] **Cas arrière-plan également rejoué, 2026-08-13.** `input keyevent
      KEYCODE_HOME` étant refusé par le classificateur de permissions,
      backgroundé via `am start -a MAIN -c HOME` (fait passer le launcher
      au premier plan sans simuler d'appui physique) — app confirmée hors
      premier plan (`topResumedActivity` = launcher). `am kill` n'a PAS pu
      terminer le process (service de localisation en arrière-plan actif,
      protégé par Android) : le test porte donc sur « app en arrière-plan
      réel », pas sur un process totalement tué. Message rejoué : reçu par
      `FLTFireMsgReceiver` (même process, toujours vivant), notification
      postée avec le même texte correct et les deux actions. **Capture
      d'écran du volet de notifications** (shade ouvert via `service call
      statusbar 1`, pas de swipe) : les deux notifications de test
      affichent bien « Salim L. / 🔒 Nouveau message », envoyée à Salim.
      Donnée de test retirée après coup.
      Reste non prouvé : le cas process **totalement** tué (kill -9 /
      swipe-away depuis les apps récentes), où Android peut afficher le
      champ `notification` FCM directement sans repasser par le code Dart
      — non exercé, aucun outil disponible dans cette session ne permet de
      tuer ce process protégé sans simuler un geste.

---

## Aperçu de notification en clair (2026-08-13)

Demande de Salim, en suite directe du correctif ci-dessus : « je veux que les
messages soient en clair » — précisé par lui-même : l'aperçu de notification,
pas le chiffrement des messages en base (confirmé explicitement avant de
toucher au code).

**Repli AES** (`encryptionLevel: 'aes'`, cas majoritaire) : déchiffré
**côté serveur** via `pgcrypto` (`decrypt_aes_fallback`,
`20260813160000_real_plaintext_push_preview.sql`) — même clé partagée que
`EncryptionService` côté client, déjà dans l'APK, pas un nouveau secret.

- [x] **Interopérabilité vérifiée avant déploiement** : un vrai ciphertext
      généré par le code Dart de l'app (`encrypt.AES(key, mode: cbc)`, clé de
      32 octets) a été déchiffré avec succès par `decrypt_iv(...,
      'aes-cbc/pad:pkcs')` côté Postgres — texte clair identique à l'octet
      près. Script Dart jetable, supprimé après usage.

**E2EE Signal réel** (`e2eePayloads`/`senderKeyPayload`) : le serveur ne peut
toujours pas déchiffrer — la ligne `notifications` transporte désormais le
vrai payload chiffré (au lieu du placeholder `'[E2EE]'`) pour un
déchiffrement côté client. **Trouvaille en marge** : `setE2EEDecryptionCallback`
n'était appelé **nulle part** dans l'app (vérifié par grep sur tout le
dépôt) — le déchiffrement foreground n'avait donc jamais fonctionné, même
avant ce correctif. Câblé maintenant dans `app.dart`. Ne fonctionnera qu'au
premier plan ; l'arrière-plan nécessiterait de charger tout le magasin de
sessions Signal dans un isolate séparé — non fait, hors périmètre.

- [x] `flutter analyze` propre sur les 3 fichiers touchés.
- [x] Migration appliquée en production (`supabase db push` : « Applying
      migration 20260813150000... / 20260813160000... / Finished », aucune
      erreur).
- [x] **Rejoué de bout en bout avec un vrai message de Salim, 2026-08-13.**
      Premier essai : notification reçue mais toujours générique
      (« 🔒 Nouveau message »), malgré une migration appliquée sans erreur.

      **Cause trouvée** : `pgcrypto` vit dans le schéma `extensions` sur ce
      projet, pas `public`. `notify_recipients_on_message_insert` pose
      `SET search_path = public` (durcissement standard sur une fonction
      SECURITY DEFINER) — restriction qui se propage à tout ce qu'elle
      appelle. `decrypt_aes_fallback` n'avait pas son propre
      `search_path` : dans le vrai flux (trigger), `decrypt_iv` devenait
      introuvable, capturé en silence par `EXCEPTION WHEN OTHERS`, d'où le
      repli générique. Un test manuel via `db query` ne le voyait jamais
      (search_path de session incluant déjà `extensions`). Reproduit avec
      `SET LOCAL search_path = public` (→ `NULL`), corrigé en fixant
      `SET search_path = public, extensions` sur la fonction elle-même
      (`20260813170000_fix_decrypt_aes_fallback_search_path.sql`).

      **Deuxième essai après correctif** : notification reçue avec
      `android.text = "He"` — le texte réel tapé par Salim, plus de
      placeholder. Confirmé en base (`notifications.body = "He"`) et à
      l'écran (capture du volet de notifications envoyée à Salim).
- [x] **Repli AES re-confirmé 7 fois** avec les messages de test indépendants
      de Salim dans `883c9d96` (« Salut », « Yo », « Test 2/3/4… », « Yyy ») :
      toujours le vrai texte en `notifications.body`, jamais de ciphertext.
- [ ] **Cas E2EE Signal établi (au premier plan) : session réelle obtenue,
      rendu à l'écran non capturé en direct.** En envoyant dans « Diaspora
      Niger — Canada » (`0ce4c63f`, Salim + Sim vrais membres), une session
      Sender Key s'est établie à la volée — vérifié en base :
      `encryptionLevel = 'e2ee'`, `senderKeyPayload` présent dans les deux
      côtés (`messages.data` ET `notifications.data`, donc le cablage SQL qui
      transporte le vrai payload au lieu du placeholder `'[E2EE]'`
      fonctionne), `notifications.body` resté générique côté serveur (jamais
      de fuite). Trois tentatives de capture en direct ont échoué pour des
      raisons de timing/navigation (app repassée en arrière-plan entre
      l'envoi et la vérification, conversation ouverte qui supprime la
      notification, messages de test envoyés par erreur vers `883c9d96` au
      lieu du groupe visé) — jamais une preuve que le déchiffrement échoue.
      Rejeu impossible avec le même message (clé Signal à usage unique,
      supprimée après un déchiffrement réussi — pas une clé « rejouable »
      comme le repli AES). Le code manquant pour ce cas
      (`NotificationDecryptionService` → `MessageCryptoService.decrypt`) est
      le même chemin déjà exercé pour afficher les vrais messages dans une
      conversation ouverte — `flutter analyze` propre, mais pas vu rendre à
      l'écran pour une notification.

---

## Demandes d'adhésion — brancher Supabase n'avait pas suffi (2026-08-06)

`c7f4141` a fait pointer `GroupRequestDataSource` vers Supabase au lieu d'une
collection Firestore restée vide. La plomberie était juste — 12 méthodes sur
12, tables, colonnes et index uniques vérifiés en base — mais **le parcours
restait impraticable de bout en bout**, pour trois raisons que seule la base
pouvait dire :

- La seule policy sur `group_requests` était
  `firebase_uid() = requester_id OR firebase_uid() = processed_by`. Une demande
  en attente a `processed_by` NULL et `requester_id` = le demandeur :
  **l'admin ne correspondait à aucune des deux branches**. Sa liste de demandes
  en attente était vide, et l'UPDATE d'approbation ne touchait aucune ligne —
  sans erreur, PostgREST rendant 200 sur un update qui ne matche rien.
- `processed_by` recevait `auth.currentUser.id`, l'uid **Supabase** (un uuid),
  là où la colonne et les policies parlent en uid **Firebase**. La seule ligne
  existante le montre : `processed_by = '1b313b0d-…'` face à
  `requester_id = 'U64HKfrjM5Nw…'`. Cette branche ne pouvait jamais matcher.
- L'approbation inscrivait le nouveau membre dans `groups.member_ids` — colonne
  **vide sur les 4 groupes**, et systématiquement recalculée depuis
  `group_members` au chargement. Approuver n'ajoutait personne.
- Enfin, ni `group_requests` ni `group_invites` n'appartenaient à la
  publication `supabase_realtime` : les `.stream()` ne faisaient que leur
  chargement initial. Même trou que `group_pinned_items` (20260805120000).

Corrigé : policies admin sur `group_requests` / `group_invites`, fonctions
`approve_group_request` / `reject_group_request` (SECURITY DEFINER, statut +
appartenance en une transaction, identité résolue par `firebase_uid()`), et
`acceptGroupInvite` qui écrit dans `group_members` comme `joinGroup`
(migration `20260806180000_group_requests_admin_access.sql`).

Rien de tout ça n'est prouvable sans **deux comptes** :

- [x] **La demande apparaît chez l'administrateur** — vérifié sur SM A515F le
      2026-08-06. La demande a été **créée en base** (pas depuis un second
      téléphone) : c'est donc l'affichage qui est prouvé, pas l'émission. Le
      menu du groupe porte « Demandes d'adhésion · 1 » avec sa pastille, et
      l'écran liste bien le demandeur. Avant la migration, cette liste était
      vide — c'était le blocage principal.
- [x] **L'approbation fait entrer le demandeur** — vérifié le 2026-08-06, les
      trois anomalies d'origine tombant d'un coup :
      `status = 'approved'`, `processed_by = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'`
      (l'uid **Firebase**, plus l'uuid Supabase), et le demandeur présent dans
      `group_members` — le groupe passe de 1 à 2 membres. SnackBar
      « Demande approuvée », liste vidée immédiatement.
      Donnée de test retirée après coup.
      Reste non vu, faute d'un second appareil : que le groupe apparaisse dans
      « Mes groupes » du demandeur et qu'il accède aux messages.
- [ ] **A refuse** une deuxième demande : elle disparaît de la liste et B ne
      devient pas membre.
- [ ] **B redemande alors qu'il est déjà membre** : message « Vous êtes déjà
      membre de ce groupe » (le garde lisait une colonne vide, il ne se
      déclenchait jamais).
- [x] **Invitation acceptée** — vérifié sur SM A515F le 2026-08-06, compte
      « Sim » acceptant une vraie invitation à « Testeurs » (groupe privé).
      `group_members` gagne bien la ligne `role = 'member'`, le groupe entre
      dans « Mes groupes » (« 2 rejoints » → « 3 rejoints »).

      Deux choses valent d'être retenues de ce test :

      **Le bouton semblait mort.** Deux captures prises 6 et 7 s après le tap
      montraient un écran inchangé. La SnackBar d'erreur dure ~4 s : c'est la
      fenêtre de capture qui était trop lente, pas le bouton qui ne répondait
      pas. En capturant à 1 s, « Action impossible pour le moment, réessayez. »
      apparaît. Ne jamais conclure « bouton mort » sans une capture immédiate.

      **La cause était une cinquième anomalie, antérieure et jamais vue.**
      `group_invites_own` avait un `USING` (inviter OU invité) et un
      `WITH CHECK` (inviter **seulement**) asymétriques : l'invité pouvait lire
      son invitation mais pas écrire sa réponse — `42501`. `acceptGroupInvite`
      **et** `declineGroupInvite` étaient donc morts pour le destinataire
      depuis toujours. Corrigé par
      `20260806200000_invite_repondre_par_l_invite.sql`.
      L'audit initial n'avait lu que les `USING` des policies : sur une table
      en écriture, lire le `WITH CHECK` est la moitié qui manque.

- [ ] **Refus d'invitation** (`declineGroupInvite`) : même chemin RLS que
      l'acceptation, débloqué par la même migration, mais jamais exercé.
- [ ] **Un non-admin ne voit pas** les demandes du groupe, et l'appel RPC lui
      est refusé (« Réservé aux administrateurs du groupe »).

### Le corollaire : un groupe privé ne montrait qu'un seul membre

`group_members_select` valait `firebase_uid() = user_id OR
is_group_public(group_id)`. Dans un groupe **privé**, aucune des deux branches
ne couvre les autres membres. Comme `_membershipFor` reconstruit `member_ids`
et `admin_ids` depuis cette table et que `GroupEntity.memberCount` dérive de
`memberIds.length`, un groupe privé de cinq personnes se serait affiché
« 1 membre » pour chacune, avec une liste de membres réduite à soi-même.

Le défaut était **invisible jusqu'ici** : les deux groupes privés de la base
n'ont qu'un membre chacun. Il devient observable dès qu'un second membre
arrive — donc dès que l'approbation ci-dessus fonctionne. Corrigé dans la
foulée par `20260806190000_group_members_visible_aux_membres.sql`, qui ajoute
`is_group_member(group_id)` — l'idiome déjà retenu sur `groups`
(`groups_select_public`).

Relu en base après application : pas de récursion, et une session sans
identité ne voit que les 2 lignes des groupes publics (les privés restent
masqués).

- [x] **Groupe privé à 2 membres** — vérifié sur SM A515F le 2026-08-06, du
      côté du membre non-administrateur : « Testeurs » affiche bien **2**
      après l'entrée de Sim. Avant la migration il aurait affiché 1.
      Vérifié depuis ce seul compte ; la vue de l'administrateur n'a pas été
      regardée (elle passait déjà, `firebase_uid() = user_id` couvrant sa
      propre ligne).
- [ ] **Un non-membre ne voit toujours rien** d'un groupe privé.

Deux effets de bord relevés pendant ce test, aucun bloquant :

- **`groups.member_count` reste à 1** alors que le groupe a 2 membres. Le
  trigger `update_group_member_count` n'est pas `SECURITY DEFINER` : son
  `UPDATE groups` tombe sur `groups_update_admin` (`is_group_admin`), faux pour
  quelqu'un qui vient de rejoindre. L'écran affiche quand même 2, parce que
  `GroupEntity.memberCount` dérive de `group_members` et jamais de cette
  colonne — la colonne est fausse, l'affichage est juste. À corriger si un jour
  un tri ou une requête s'appuie sur `member_count` (`getGroups` l'utilise déjà
  en `order by`).
- **La liste ne s'est pas rafraîchie après l'acceptation** : l'invitation
  disparaît bien, mais « Testeurs » n'apparaît qu'après un redémarrage à froid,
  malgré le `ref.invalidate(myGroupsNotifierProvider)` de `_accept`.
  (L'écran des demandes, lui, se vide immédiatement après une approbation.)

### La fiche du groupe ment selon le chemin par lequel on l'ouvre

Trouvé en cherchant l'écran des demandes, le 2026-08-06. Sur **le même groupe**,
avec **le même compte** — Sim, créateur et administrateur :

| Ouverte depuis | Membres | Bouton du bas | Menu « Demandes » |
|---|---|---|---|
| la liste « Mes groupes » | 1 | « Ouvrir la discussion » | présent, pastille 1 |
| l'en-tête de la conversation | **0** | **« Demander à rejoindre »** | **absent** |

L'écran calcule tout depuis l'entité :
`isAdmin = group.adminIds.contains(me)` et
`isMember = group.memberIds.contains(me)`
([group_detail_screen.dart:132](lib/features/groups/presentation/screens/group_detail_screen.dart:132)).
Par le second chemin ces deux listes arrivent vides, donc l'administrateur se
voit proposer de rejoindre son propre groupe et **perd l'accès à l'écran
d'approbation**.

Ce n'est pas la base : la requête d'appartenance rejouée sous l'identité de Sim
rend bien sa ligne `role = 'admin'`. Et `getGroupById` applique pourtant
`_membershipFor` — son commentaire décrit même ce symptôme comme déjà corrigé.
La cause exacte côté app n'a pas été trouvée ; `_membershipFor` avale ses
erreurs (`catch (_) { return const {}; }`), ce qui rend un échec indiscernable
d'un groupe sans membres.

À noter pour qui reprendra : `getMyGroups` masque le même trou avec un
rattrapage explicite (« on s'y ajoute quand même, sinon Mes groupes proposerait
Rejoindre sur ses propres groupes »). Le rattrapage soigne le symptôme sur un
écran et laisse l'autre à découvert — donc le « 1 » de la liste ne prouve pas
que la lecture d'appartenance ait réussi.

- [ ] **Vérifier après correction** : ouvrir la fiche depuis la conversation
      doit donner exactement le même écran que depuis la liste.

---

## La porte d'entrée des groupes était grande ouverte (2026-08-06)

`group_members_own` est une policy `FOR ALL` dont le `USING` vaut
`firebase_uid() = user_id`, **sans `WITH CHECK` explicite** — la même expression
sert donc au contrôle d'insertion. Elle vérifie qu'on s'inscrit *soi-même*, et
rien d'autre : ni le groupe, ni une invitation, ni une approbation.

Mesuré sous une vraie identité avant correction : l'insertion d'une ligne
d'appartenance est **acceptée pour un groupe inexistant** (`group_id` n'a
d'ailleurs aucune clé étrangère — 7 lignes orphelines dorment déjà dans la
table). A fortiori pour un groupe privé dont on n'a jamais reçu d'invitation :
il suffit d'en connaître l'uuid et d'appeler l'API. Les uuid des groupes privés
ne sont pas listés, mais c'est de l'obscurité, pas un contrôle.

Fermé par `20260806210000_group_members_porte_d_entree.sql` : une policy
**RESTRICTIVE `FOR INSERT`**, qui s'ajoute en ET aux permissives sans toucher au
reste. `SELECT` / `UPDATE` / `DELETE` gardent `group_members_own` — quitter un
groupe privé reste possible, ce qu'une condition sur l'invitation aurait cassé.

Mesures après application, sous l'identité réelle du compte de test :

| Cas | Attendu | Obtenu |
|---|---|---|
| groupe inexistant (ou privé sans invitation) | refusé | `42501` refusé |
| groupe **public** (`joinGroup`) | accepté | accepté |
| groupe privé **avec invitation** | accepté | `23505` doublon — la policy a laissé passer, `has_group_invite` = `t` |
| quitter un groupe (`DELETE`) | accepté | 1 ligne supprimée |

Et dans l'app, sur SM A515F : « Découvrir » → « Rejoindre » sur un groupe
public fonctionne toujours — c'est le chemin que cette policy aurait pu casser,
et il a été exercé pour de vrai, pas seulement en SQL. Adhésion retirée après
coup.

- [ ] **Reste à voir** : rejoindre un groupe public depuis un compte qui n'y a
      jamais mis les pieds (le test l'a fait avec le compte administrateur d'un
      autre groupe), et vérifier qu'un groupe privé sans invitation ne propose
      bien que « Demander à rejoindre ».

Deux voisins **non corrigés**, repérés en lisant ces policies :

- **`removeMember` ne peut pas fonctionner** :
  [group_supabase_datasource.dart:337](lib/features/groups/data/datasources/group_supabase_datasource.dart:337)
  délègue à `leaveGroup`, donc un `DELETE` sur la ligne de *quelqu'un d'autre*,
  que `group_members_own` (`firebase_uid() = user_id`) refuse. Un
  administrateur ne peut pas exclure un membre.
- **Aucune clé étrangère sur `group_members.group_id`** : supprimer un groupe
  laisse ses membres derrière (7 orphelins sur 11 lignes aujourd'hui).

---

## Fiche membres de groupe bloquée / vide (2026-08-13)

Signalé par Salim : « problème sur les infos des membres de groupes ». L'appareil
était **surpris en flagrant délit** — écran « Membres » figé sur un spinner
indéfini au moment où j'ai capturé le premier screenshot de la session.

**Cause n°1 — spinner indéfini.** `GroupMembersScreen`
([group_members_screen.dart](lib/features/groups/presentation/screens/group_members_screen.dart))
est un `ConsumerWidget` qui ne charge jamais lui-même son groupe : il lit
`group` (passé par la navigation) puis, à défaut, l'état déjà présent dans
`groupDetailNotifierProvider` — un provider **partagé**, pas une famille par
id, jamais peuplé par cet écran. Le lien « Tout voir » de la fiche groupe
([group_detail_screen.dart:705](lib/features/groups/presentation/screens/group_detail_screen.dart:705))
ne passait pas `extra: group`, contrairement au bouton du bas qui le passait
déjà. Sans lui, si l'écran précédent n'avait pas déjà peuplé le provider pour
CE groupe, `groupEntity` restait `null` pour toujours.

Corrigé : `GroupMembersScreen` devient `ConsumerStatefulWidget`, déclenche
`loadGroup(groupId)` en `initState` quand `group` est absent, et n'accepte la
valeur en cache que si son id correspond à l'écran ouvert (le provider partagé
peut porter les données d'un AUTRE groupe visité juste avant). Le lien
« Tout voir » passe désormais `extra: group` en plus, pour l'aller vite sans
round-trip réseau.

**Cause n°2 — fiche affichant « Membres · 0 » / « Rejoindre le groupe » à un
membre réel.** Repérée en vérifiant le correctif n°1 sur appareil, par un
AUTRE chemin de navigation (en-tête de la conversation de groupe → fiche,
sans `initialGroup`) :
`getGroupStream` ([group_supabase_datasource.dart:184](lib/features/groups/data/datasources/group_supabase_datasource.dart:184))
lit la ligne `groups` brute sans jamais appliquer `_withMembership` —
contrairement à `getGroupById`/`getGroups`/`getMyGroups`. Comme
`groups.member_ids`/`admin_ids` sont NULL en base (seule `group_members` fait
foi), le flux temps réel écrasait en permanence la lecture ponctuelle
correcte de `groupDetailNotifierProvider` via le `??` de `GroupDetailScreen`.
Corrigé : `getGroupStream` applique désormais `_membershipFor`/`_withMembership`
comme les autres lectures.

- [x] **Vérifié sur SM A515F**, groupe « Diaspora Niger — Canada » (2 membres,
  compte Sim A) : par le chemin en-tête de conversation → fiche → Tout voir —
  celui qui reproduisait les DEUX défauts — la fiche affiche « Membres · 2 »,
  « Ouvrir la discussion », les deux membres nommés (Sim A · Créateur, Salim
  L.), et « Tout voir » ouvre la liste immédiatement au lieu de tourner dans
  le vide.

**Cause n°3 — signalée par Salim en relisant le screenshot ci-dessus** : la
ligne « Créateur » affichait « Sim A · Étudiant », alors que le bas de la même
fiche affiche « Créé par Diaspo Niger ». Vérifié en base
(`supabase db query --linked`) : pour ce groupe `is_official=true`,
`creator_id` pointe en fait vers le compte perso de Sim A
(`vQZE49dTdyRtLwSG6lMIbhAqoFG2`) avec `creator_name` forcé à « Diaspo Niger »
— contrainte de la base, pas un vrai compte plateforme séparé. La ligne
« Créateur » suivait le profil réel lié à `creator_id` au lieu de l'identité
`creator_name` déjà affichée ailleurs sur la fiche.

Corrigé côté affichage uniquement (la réassignation en base d'un vrai compte
plateforme pour les groupes officiels reste à discuter séparément) :
`_MemberListItem` (`group_detail_screen.dart` et `group_members_screen.dart`)
affiche `group.creatorName` — et masque la profession — pour la ligne
créateur quand `group.isOfficial` est vrai.

- [x] **Vérifié sur SM A515F** : la ligne créateur affiche désormais
  « Diaspo Niger · Créateur » (sans profession) sur la fiche ET sur l'écran
  « Tout voir », cohérent avec « Créé par Diaspo Niger » en bas de fiche.

**Réassignation en base faite le 2026-08-13** (voir
`docs/ops/GROUPES_OFFICIELS.md`) : Salim a créé un vrai compte plateforme
(`czk5UoUclLOFmbRtUIZ5XYLYKo52`, email `support@diasponiger.com`), connecté
une fois dans l'app pour amorcer le pont Supabase standard. Ensuite, en SQL :
`users.display_name = 'Diaspo Niger'` + `is_verified = true`,
`groups.creator_id` réassigné dessus pour le groupe officiel, et une ligne
`group_members` `role='owner'` — lui seul, aucun compte perso ne garde de
droit de gestion implicite (décision explicite de Salim). `member_count`
recalé à 3 (le trigger `group_members_count_trigger` ne s'est pas déclenché
sur cet insert direct, même symptôme que documenté plus haut dans ce fichier
pour la migration des groupes hérités).

- [x] **Vérifié sur SM A515F, connecté en Sim A** (donc point de vue d'un
  membre normal, pas du compte plateforme) : la fiche affiche « Membres · 3 »,
  la ligne « Diaspo Niger · Créateur » sans chevron ni tap possible, et
  « Salim L. » apparaît comme 3e membre (compte déjà présent en base,
  simplement jamais vu résolu avant ce test).

**Bug structurel trouvé en vérifiant qu'aucun autre groupe officiel n'avait
été oublié** : la RPC `get_or_create_official_group` (déclenchée
automatiquement à chaque profil qui renseigne un pays) reproduisait le même
défaut pour tout NOUVEAU pays — et depuis le 2026-08-06
(`groups_guard_official`), échouait carrément en silence (42501 avalé côté
app), donc plus aucun groupe officiel n'était créé pour un pays inédit.
Corrigé par migration (`20260813233000_fix_official_group_creator_and_admin.sql`) :
la RPC désactive les deux triggers concernés le temps de son propre INSERT,
pose le compte plateforme comme `creator_id`, et ajoute la ligne
`group_members role='owner'` manquante. Détail dans
`docs/ops/GROUPES_OFFICIELS.md`.

- [x] **Testé en base (pas sur appareil — aucun compte de test n'a de pays
  encore sans groupe officiel)** : rejoué sous une identité non-admin réelle
  (`U64HKfrjM5NwR6HO00XPKo6168z2`), dans une transaction annulée par
  `ROLLBACK` (`SET LOCAL request.jwt.claims`). Cas nouveau pays (France,
  simulé) : plus d'exception, `creator_id` = compte plateforme,
  `member_count = 1`, aucune trace laissée par le ROLLBACK, les 4 triggers de
  `groups` réactivés après coup. Cas pays déjà couvert (Canada) : retour
  identique à avant, aucun INSERT déclenché.
- [ ] **Vérification sur appareil demandée par Salim** : dès qu'un vrai
  compte renseigne pour la première fois un pays sans groupe officiel
  existant, confirmer sur cet appareil que le groupe apparaît normalement
  (nom, « Créé par Diaspo Niger », membre compté) — la transaction annulée
  ci-dessus prouve la logique SQL, pas le chemin réel `ProfileNotifier` →
  RPC → écran groupe de bout en bout. Repérable via
  `select id, name, country_code, created_at from groups where is_official
  order by created_at desc;` (un nouveau pays = une ligne de plus).

---

- [x] **Accusé « Envoyé » sur rafale de messages (`conversation_screen.dart`,
  `_getMessageGroupPositionReversed`)** : `first`/`last` étaient inversés —
  dans une liste inversée (index 0 = plus récent), le message le plus ANCIEN
  d'une rafale du même expéditeur héritait de `MessageGroupPosition.last`,
  donc de l'accusé « Envoyé » porté par `_isLastInGroup`
  ([message_bubble.dart:230](lib/features/messages/presentation/widgets/message_bubble.dart:230)),
  à la place du plus récent — symptôme rapporté : « j'envoie deux messages
  d'affilée, je ne vois "Envoyé" que sur le 1er ». Corrigé en échangeant les
  deux branches.
  **Vérifié sur SM A515F le 2026-08-13** (compte Sim A, conversation « Mes
  notes », 2 messages envoyés coup sur coup) : seul le 2e message porte
  « À l'instant · Envoyé », le 1er n'en porte aucun. La queue de bulle
  (`_getBorderRadius`) suit aussi la correction attendue — petit rayon en
  bas à droite sur la bulle du bas (fin de rafale) au lieu du haut. Pas
  d'erreur en logcat.
  **`showSenderInfo` vérifié le 2026-08-13** dans le groupe « Testeurs »,
  côté réception (Sim A regarde une rafale de « Salim L. ») : rafale de 3
  lignes insérée directement en base (`messages`, même `sender_id`, +5 s
  et +10 s, nettoyée juste après par un `DELETE` sur leurs ids) pour
  simuler une rafale de l'autre membre sans dépendre d'un 2e appareil. Le
  nom « Salim L. » + badge « Admin » ne s'affichent que sur la bulle du
  HAUT (la plus ancienne) ; les 2 bulles suivantes n'ont ni nom ni badge —
  comportement attendu confirmé côté réception aussi, pas seulement côté
  émission.
  **Tap-to-reveal vérifié le 2026-08-13** dans la conversation « Salim L. »
  (1:1, 2 messages envoyés coup sur coup « bvvgc »/« bvvgcv ») : le message
  précédent (« bvvgc ») n'affiche rien par défaut, un tap sur la ligne
  méta (sous la bulle) révèle « 19:55 · Lu » — confirmé via
  `uiautomator dump` (content-desc passe de `"bvvgc"` à `"bvvgc\n19:55"`)
  et capture d'écran. Les messages reçus (rafale de 5 dans la conversation
  « Salim L. ») affichent chacun leur heure individuellement sans tap,
  comme attendu (`showTimeInfo = _isLastInGroup || !isMe || _metaRevealed`).
  ⚠️ Piège rencontré en testant : un premier build (`flutter build apk
  --debug`) avait son démon Gradle tué en cours (autre agent qui buildait
  en parallèle) — le retry a réussi mais a silencieusement produit un APK
  au comportement incohérent avec le code source (rafales reçues
  n'affichant l'heure que sur le dernier message, contredisant le code
  lu). Un `flutter clean` + rebuild complet a résolu l'incohérence. Ne pas
  faire confiance à un build qui a suivi un échec de démon Gradle, même
  si le retry annonce un succès — repartir d'un `flutter clean`.

---

## Groupes officiels — organisation de la gestion au quotidien (2026-08-13)

Suite du correctif creator_id/RPC pays : Salim est déjà superAdmin plateforme
mais n'avait aucun droit RLS sur un groupe officiel sans ligne
`group_members` dédiée — impraticable au quotidien (aurait fallu se
reconnecter comme le compte plateforme à chaque action). Corrigé par
migration `20260813234500_superadmin_manages_official_groups.sql` :
`groups_update_admin` accepte désormais `is_group_admin(id) OR (is_official
AND is_admin())`, portée volontairement limitée aux groupes officiels (pas
un accès superAdmin global à `groups`). Détail complet dans
`docs/ops/GROUPES_OFFICIELS.md`.

⚠️ **Piège de méthode découvert en vérifiant ce correctif** : `supabase db
query --linked` se connecte en `postgres` (`rolbypassrls = true`) —
contourne RLS entièrement, quel que soit `request.jwt.claims` posé avec `SET
LOCAL`. Un premier test « groupe privé refusé » avait silencieusement réussi
alors qu'il aurait dû échouer — faux positif pur, RLS jamais évalué.
Refait avec `SET LOCAL ROLE authenticated;` en plus (rôle sans
`BYPASSRLS`, celui que PostgREST utilise réellement) : les fonctions
`SECURITY DEFINER` (`get_or_create_official_group`) n'étaient pas affectées
par ce piège — elles s'exécutent avec les privilèges de leur propriétaire
quel que soit l'appelant — mais toute vérification directe d'une policy sur
une table (`UPDATE`/`DELETE` brut) l'est.

- [x] **Testé en base avec la méthode corrigée** (transaction annulée par
  `ROLLBACK`, `SET LOCAL ROLE authenticated` + `request.jwt.claims`) :
  Salim (superAdmin, son propre compte) peut modifier le groupe officiel ;
  le même compte reste bloqué (0 ligne) sur un groupe privé de Sim A dont il
  n'est ni créateur ni membre. Pas testé sur appareil — nécessiterait de
  construire un écran de modification de groupe officiel côté app, qui
  n'existe pas encore (le bouton « Modifier » existant n'a jamais été
  vérifié bout en bout, cf plus haut dans ce fichier).

---

## Modération des membres de groupe : trou RLS fermé + bug de départ trouvé (2026-08-14)

`conversations_update` (`participant_ids @> [firebase_uid()]`) autorisait
n'importe quel participant à écrire `data.adminIds`/`participant_ids` sans
vérification de rôle — n'importe quel membre pouvait s'auto-promouvoir admin
ou exclure quelqu'un via une écriture directe, dans n'importe quel groupe
(pas seulement officiel). Fermé par un trigger `BEFORE UPDATE`
(`20260814000500_guard_conversation_admin_fields.sql`), pas par une policy
RLS seule (comparaison OLD/NEW propre, cf [[project_rls_testing_bypass_pitfall]]
pour la méthode de vérification utilisée). Détail dans
`docs/ops/GROUPES_OFFICIELS.md`.

- [x] **Testé en base** (`SET LOCAL ROLE authenticated` + `request.jwt.claims`,
  transaction annulée) : promotion par un non-admin refusée (42501),
  promotion par un admin existant acceptée, champ sans rapport (`mutedBy`)
  toujours modifiable par un simple participant, superAdmin accepté sur le
  groupe officiel sans être dans `adminIds` ni `group_members`.

**Corrigé aussi** : `leaveGroup()` (`group_supabase_datasource.dart:343`) ne
supprimait que la ligne `group_members` — ne touchait jamais
`conversations.participant_ids`. Un membre qui quittait un groupe restait
participant de sa conversation, avec accès en lecture aux messages envoyés
après son départ (`conversations_select` se fie à `participant_ids`). RPC
`SECURITY DEFINER` dédiée (`leave_group_conversation`,
`20260814001500_leave_group_removes_conversation_participant.sql`) — un
simple `UPDATE` échoue de toute façon sur `conversations_update`, qui exige
implicitement que l'appelant reste participant après l'update.

- [x] **Testé en base** (même méthode) : le départ retire bien l'appelant de
  `participant_ids` (et de `adminIds` s'il y était), un appel sur un groupe
  dont on n'est pas membre ne fait rien sans erreur. ⚠️ Piège de test :
  une fonction `SECURITY DEFINER` créée **après** `SET LOCAL ROLE
  authenticated` appartient à `authenticated`, pas `postgres` — elle reste
  soumise à RLS malgré son mot-clé (deux faux échecs avant de comprendre).
- [x] **Vérifié sur SM A515F le 2026-08-14** (compte Sim A, groupe « Testeurs »,
  2 membres). Fiche groupe → menu ⋮ → « Quitter » → confirmation : bandeau
  « Vous avez quitté le groupe » dans la discussion, aucun plantage. Confirmé
  en base dans la foulée : `group_members` et `conversations.participant_ids`
  ne portent plus que Salim. Accès en lecture testé en insérant un message
  comme Salim juste après (`SET ROLE authenticated` + JWT de Sim A) : `select`
  rend **0 ligne** — avant le correctif, Sim A l'aurait encore lu. Message de
  test supprimé, Sim A rejoint le groupe ensuite pour restaurer l'état
  antérieur (`group_members` + `participant_ids`).

---

## Heure/accusé masqués au tap sur une rafale envoyée (2026-08-14)

[message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart) :
un message envoyé qui n'est pas le dernier d'une rafale masquait déjà son
heure par regroupement visuel, mais sans aucun moyen de la consulter
individuellement. Un tap sur la ligne meta (zone masquée sous la bulle) la
révèle, un second tap la remasque. Les messages reçus ne sont pas concernés.

- [x] **Testé sur SM A515F** (build debug fraîchement compilé) : conversation
  avec deux messages envoyés consécutifs (« bvvgc » puis « bvvgcv »). Le
  premier n'affiche aucune heure par défaut ; un tap sur la zone sous la
  bulle révèle « 19:55 · Lu » ; un second tap la remasque. Le dernier message
  de la rafale (« bvvgcv ») et tous les messages reçus affichent leur heure
  en permanence, sans interaction, comme attendu.

---

## Avertissement Android « pages de 16 Ko » — une seule vraie cause, correctif bloqué en cascade (2026-08-14)

Popup système sur appareil (build **debuggable** uniquement, en français :
« Cette appli n'est pas compatible avec les pages de 16 Ko ») citant 4
bibliothèques : `libflutter.so`, `libdatastore_shared_counter.so`,
`libVkLayer_khronos_validation.so`, `libnoise.so`.

Vérifié en extrayant les 4 `.so` de l'APK (debug **et** release,
`build/app/outputs/apk/`) et en lisant leurs en-têtes ELF
(`llvm-readelf -l`, NDK r27 déjà installé) : **seule `libnoise.so` est
réellement mal alignée** (segment LOAD à 4 Ko au lieu de 16). Les 3 autres
sont déjà à 16 Ko ou 64 Ko — le popup les signale par erreur (« erreur
inconnue », pas un vrai défaut d'alignement).

`libnoise.so` vient de `com.github.paramsen:noise:2.0.0`, tirée par le
`build.gradle` Android de **`livekit_client`** (pas `flutter_webrtc`, malgré
l'intuition de départ) — une petite lib FFT utilisée pour la détection de
niveau audio en temps réel (indicateur « parle en ce moment » des salons
audio / appels de groupe, cf [[project_widgets_alimentes_en_dur]]). LiveKit
l'a corrigée en la republiant `io.livekit:noise:2.0.0` (vérifié : LOAD à
16 Ko dans l'AAR téléchargé depuis Maven Central), correctif présent à partir
de `livekit_client 2.6.0`.

**Le correctif n'est pas accessible sans remonter toute une chaîne.**
`livekit_client ≥2.6.0` épingle une version exacte de `flutter_webrtc`
(1.2.1 → 1.6.0 selon la sous-version, jamais notre `^0.12.12` actuel), qui
entraîne `connectivity_plus ^7.0.0` (exige AGP ≥8.12.1 et Gradle ≥8.13 —
projet en 8.7.0 / 8.10.2), et selon la sous-version exacte de
`livekit_client` :
- 2.6.0–2.6.4 : `device_info_plus ^12.2.0` (projet en `^11.4.0`, probablement
  anodin) ;
- ≥2.6.5 : `dart_jsonwebtoken ^3.3.2` → `pointycastle ^4.0.0`, **incompatible
  avec `encrypt: ^5.0.3`** (`pointycastle ^3.6.2`) — `encrypt` sert au repli
  AES de l'E2EE (cf [[project_e2ee_status]]), donc pas un paquet à bumper à
  la légère pour un warning de debug.

Décision prise le 2026-08-14 : reporter. Pas de preuve de crash réel en
production (le popup ne s'affiche qu'en build debuggable), et le correctif
complet toucherait WebRTC + connectivité + outillage Android + potentiellement
la crypto — un chantier à part entière, pas un fix ponctuel.

- [ ] Si repris : bump couplé `livekit_client` + `flutter_webrtc` +
  `connectivity_plus` (+ AGP/Gradle, + vérifier `encrypt`/`pointycastle`),
  puis tester au doigt sur SM A515F : appels 1:1, appels de groupe, salons
  audio (indicateur de parole en particulier, puisque c'est lui qui dépend de
  la lib corrigée), et un parcours E2EE complet si `encrypt` a bougé.
- [ ] Revérifier l'alignement après coup avec la même méthode
  (`llvm-readelf -l` sur les `.so` extraits de l'APK, chercher `LOAD` et
  vérifier que `p_align` ≥ `0x4000`).

---

## Supprimer un groupe ne supprimait que la ligne `groups` (2026-08-14)

Signalement de Salim (« la gestion des groupes se passe pas bien ») en
creusant le comportement de « Quitter »/« Supprimer » un groupe. `delete_group()`
(bouton « Supprimer le groupe » de la fiche d'édition, admin/créateur
seulement) ne supprimait que la ligne `groups`. Contrairement à
`events`/`post_polls`/`group_pinned_items` (déjà `ON DELETE CASCADE` depuis
`groups.id`), `group_members` et `conversations` n'ont **aucune** contrainte
de clé étrangère vers `groups` : `group_members` restait avec des lignes
orphelines, et **la conversation + tous ses messages restaient intacts et
lisibles indéfiniment** par tous les anciens membres — « supprimer le
groupe » ne supprimait pas la discussion du tout.

Décision de Salim : supprimer un groupe doit le dissoudre pour **tout le
monde**, comme quitter mais appliqué à tous les membres d'un coup — pas
seulement pour l'admin qui agit. Corrigé (migration
`20260814003000_delete_group_cascades_membership_and_conversation.sql`) :
`delete_group()` supprime aussi `conversations` (cascade déjà en place vers
`messages`/`group_pinned_items`/`events` liés à la conversation) et
`group_members` avant de supprimer `groups`. Autorisation inchangée
(`creator_id = v_uid` uniquement) — pas étendue au superAdmin comme
`groups_update_admin` l'a été : la suppression reste une action plus lourde,
réservée au compte plateforme pour un groupe officiel.

- [x] **Testé en base** (groupe/membres/conversation/message jetables créés
  dans une transaction annulée par `ROLLBACK`) : avant suppression — 1
  groupe, 2 membres, 1 conversation, 1 message ; tentative par un
  non-créateur — bloquée (`not_authorized`) ; suppression par le vrai
  créateur — les quatre compteurs tombent à 0. Rien laissé en base.
- [x] **Vérifié sur SM A515F le 2026-08-14** (compte Sim A, groupe « A
  supprimer (test) » créé pour l'occasion : Sim A créateur, Salim membre, un
  message échangé). Fiche groupe → menu ⋮ → « Modifier » → icône poubelle →
  « Voulez-vous vraiment supprimer ce groupe ? Cette action est
  irréversible. » → confirmation : bandeau « Groupe supprimé », retour propre
  à la liste (3 → 2 groupes rejoints), aucun plantage. Confirmé en base dans
  la foulée : `groups`, `group_members`, `conversations` et `messages`
  retombent tous à 0 ligne pour ce groupe.

---

## Recoloriage orange/vert de marque (2026-08-14)

Demande produit : `AppColors.primary` (orange) `#E07B39` → `#E05206`,
`AppColors.secondary` (vert) `#2D7D46` → `#0DB02B`, avec les variantes
claire/pastel/foncée dérivées en HSL (teinte + rapports de luminosité
préservés) dans `lib/core/constants/app_colors.dart`, plus 20 fichiers qui
recopiaient ces teintes en dur (bulles, avatars, badges, appels de groupe).
`AppColors.success`/`successLight`/`successDark` gardés inchangés
(coïncidaient en valeur avec l'ancien vert mais sont un token sémantique
distinct).

- [x] **Vérifié sur SM A515F le 2026-08-14** (rebuild + install de l'APK
  debug) : splash, accueil, fiche groupes — orange et vert nouveaux bien
  affichés. Confirmé par échantillonnage de pixels exact sur les captures
  (pas seulement à l'œil) : barre de progression `#9F3E0A`, icône filtre
  `#FA7E3B`, icône de groupe `#32E252`, bouton « Ouvrir » dans le nouveau
  vert vif — correspondance exacte aux valeurs dérivées, nettement
  distinctes des anciennes (vert forêt terne, orange terre cuite).

---

## Fonctionnalité épingle mise en pause (2026-08-14)

Sur demande, le bouton Épingler/Détacher (menu contextuel d'un message), le
bandeau épinglé (`GroupPinnedBanner`) et la ligne « Épinglés » de la fiche
groupe (`_GroupInfoCard`) ont été désactivés — commentés, pas supprimés, pour
réactivation future :
- `lib/features/messages/presentation/screens/conversation_screen.dart` :
  `canPin` figé à `false` ; `_pinMessage`/`_unpinMessage`/
  `_refreshPinnedBanner`/`pinnedMessageIds` commentés.
- `lib/features/groups/presentation/widgets/group_pinned_banner.dart` :
  `_GroupPinnedBannerState.build` ne rend plus que la pastille `trailing`
  (bascule ÉCO — **doit rester visible**, elle n'a rien à voir avec
  l'épinglage) ; `_PinnedRow` et son bloc de rendu commentés en entier.
- `lib/features/groups/presentation/screens/group_detail_screen.dart` :
  la ligne « Épinglés » et `_pinnedSummary` commentées dans `_GroupInfoCard`.
- `lib/features/groups/data/datasources/group_supabase_datasource.dart` et
  `group_pinned_providers.dart` : le paramètre `groupId` de `pinItem`/
  `getPinnedItemsStream` (déjà mort avant la pause, jamais alimenté par le
  seul appelant réel) commenté au même moment.

`flutter analyze` propre (aucun avertissement de code mort/import inutilisé)
après ce commentage — les nombreux items `[ ]` ci-dessus datant d'avant le
2026-08-14 portent sur une fonctionnalité désormais désactivée : les
retester n'a de sens qu'après réactivation.

- [ ] **Bascule ÉCO toujours visible** sur une conversation (1:1 et groupe),
  malgré la pause : c'est le point de vigilance le plus probable de casser
  en silence (elle partage la ligne avec le bandeau épinglé disparu).
- [ ] **Aucun bouton Épingler/Détacher** dans le menu contextuel d'un
  message, 1:1 comme groupe.
- [ ] **Aucune ligne « Épinglés »** sur la fiche groupe, même sur un groupe
  qui avait des épingles avant la pause.
- [ ] Build + install pas encore faits sur SM A515F depuis ce changement
  (travail réalisé dans un worktree isolé, dépôt principal occupé par une
  autre session au moment de l'écriture).


## Pseudo (@handle) — ligne d'appel sur son propre profil

Contexte : la ligne `@handle` disparaît purement et simplement quand le champ
est vide, et 9 comptes sur 11 en prod n'en ont aucun — rien n'indiquait que
la fonctionnalité existait. Une ligne d'appel prend désormais la place du
`@handle` manquant, **uniquement sur son propre profil**.

- [ ] Onglet **Profil** avec un compte sans pseudo : la ligne
  « Choisir mon pseudo » (icône @) s'affiche sous le nom
  (`lib/features/profile/presentation/screens/profile_screen.dart`).
- [ ] Le tap ouvre l'édition **avec le curseur dans le champ**, donc le champ
  défilé à l'écran (`/profile/edit?focus=handle`,
  `edit_profile_screen.dart` + `widgets/handle_field.dart`).
- [ ] Avec un compte **qui a** un pseudo (`sim`, `diaspo_ne`) :
  c'est bien `@sim` qui s'affiche, pas l'appel.
- [ ] Profil de **quelqu'un d'autre** sans pseudo : **aucune** ligne
  d'appel (on ne peut rien y faire)
  — `profile_view_screen.dart`, garde `_isCurrentUser`.
- [ ] Son propre profil ouvert par `/profile/<son id>` (lien profond, QR,
  liste de membres) : même appel que sur l'onglet Profil.
- [ ] Lisibilité en **thème sombre** (couleur `adaptivePrimaryColor`) et à
  `font_scale 1.1` : la ligne est dans un `Flexible`, vérifier l'absence de
  débordement à côté du nom.

---

## Page Notifications à plat + heure sur le seul dernier message d'une rafale (2026-08-23)

Deux changements distincts, aucun couvert par `flutter test`.

**1. Le regroupement de la page Notifications est retiré**
([notifications_screen.dart](lib/features/notifications/presentation/screens/notifications_screen.dart)).
Les tuiles pliées « 3 nouveaux messages » / « 2 demandes d'ami »
(`_NotificationGroup`, `_NotificationGroupItem`, `_CompactNotificationItem`,
et les helpers `_groupNotifications`/`_autoGenerateGroupKey`) sont supprimées :
une notification = une ligne. Les tranches de temps (« AUJOURD'HUI », « CETTE
SEMAINE »…) et les trois filtres (Tout / Non lues / Mentions) sont conservés.
Le résumé des notifications **push** Android (`setAsGroupSummary`, InboxStyle
dans `notification_service.dart`) n'est pas touché — c'est un autre système.

- [ ] ⚠️ **Rien n'a pu être vérifié le 2026-08-23** : la page affiche
  « Erreur de chargement » sur le compte de test, alors que le badge de la
  cloche annonce 19 notifications. Le message vient de la branche `error:` de
  `notificationsAsync` — donc **le chargement échoue en amont**, dans
  `watchNotifications` (flux Supabase `notifications`, qui réessaie 4 fois puis
  laisse remonter l'erreur), et non dans l'affichage retouché ici. À
  diagnostiquer séparément ; tant que ça dure, la mise à plat reste
  invérifiable à l'écran.
- [ ] Une conversation qui a envoyé 3 messages produit **3 lignes séparées**
  dans la page, plus une tuile dépliable.
- [ ] Le **balayage** (supprimer / marquer comme lu) fonctionne sur ces
  lignes redevenues individuelles.
- [ ] Les **actions en ligne** (Accepter/Refuser une demande d'ami, les
  boutons d'événement) s'affichent toujours — elles vivaient aussi dans les
  tuiles compactes du groupe, qui viennent de disparaître.
- [ ] La **pagination au défilement** tient toujours avec beaucoup de lignes
  (le compte d'éléments affichés n'est plus réduit par le regroupement).
- [ ] Les **tranches de temps** restent correctes et ne se répètent pas.

**2. Dans une rafale, seul le dernier message affiche son heure**
([message_bubble.dart](lib/features/messages/presentation/widgets/message_bubble.dart)).
La règle existait pour les messages *envoyés* ; elle vaut désormais aussi pour
les messages *reçus* (`showTimeInfo = _isLastInGroup || _metaRevealed`).

⚠️ Ce changement **annule `92326fe` (« chaque bulle porte son heure »)**, poussé
quelques heures plus tôt sur la branche partagée, qui avait retiré ce masquage
en jugeant qu'il se lisait comme un défaut. Le masquage est rétabli à la
demande explicite, et étendu aux messages reçus. Si le rendu déplaît à
l'usage, c'est ce commit-là qu'il faut relire avant de trancher à nouveau.

- [x] **Vérifié SM A515F le 2026-08-23** (build debug depuis le worktree) :
  3 messages envoyés d'affilée dans « Mes notes » (`rafale_A`, `rafale_B`,
  `rafale_C`) → seul `rafale_C` porte « À l'instant · Envoyé ».
- [ ] Le même cas sur des messages **reçus** : **pas vérifié**, aucun message
  reçu disponible sur le compte de test (les deux conversations ne contiennent
  que des messages envoyés ; celle du groupe est en « clé de groupe
  introuvable »). C'est pourtant la moitié de la demande — à refaire avec un
  second compte.
- [x] **Tap vérifié SM A515F le 2026-08-23** sur messages **envoyés** : un tap
  sur la bulle révèle « 05:14 · Envoyé », un second tap la remasque, et le
  double-tap pose toujours la réaction ❤️. Le retard de ~300 ms n'a pas pu être
  jugé (pilotage par `adb`, pas au doigt). Reste à faire sur une bulle **reçue**.
- [ ] Un **tap sur la bulle** (reçue comme envoyée) révèle son heure ; un
  second tap la remasque. ⚠️ Signalé cassé à l'usage le 2026-08-23 : le
  `GestureDetector` de la bulle ne portait que `onLongPress`/`onDoubleTap`,
  donc le tap ne déclenchait **rien** — la seule cible était une bande
  *invisible* de 48×16 dp posée sous la bulle, introuvable. Corrigé par
  `_onTapRevelerHeure`. À vérifier en priorité, avec trois sous-points :
  - le tap ne vole pas les gestes voisins (ouvrir une image, relancer un
    envoi en échec, sélection multiple, appui long, swipe pour répondre) ;
  - le double-tap pose toujours la réaction ❤️ ;
  - le tap simple accuse ~300 ms de retard (Flutter attend d'écarter le
    double-tap) — dire si c'est perceptible au point de gêner.
- [ ] ⚠️ **Scintillement observé le 2026-08-23** : juste après avoir posé une
  réaction ❤️, **toutes** les bulles de la conversation ont affiché leur heure
  d'un coup (le regroupement s'était défait), puis c'est rentré dans l'ordre à
  la réouverture. Piste : pendant le rebuild qui suit l'écriture, la liste passe
  par un état où les voisins d'index ne sont plus les voisins chronologiques, ce
  qui fait échouer `memeRafale`. Sans conséquence durable, mais à confirmer — et
  à corriger si ça se voit à chaque réaction.
- [ ] L'accusé de réception (« Envoyé »/« Lu »/« Vu par N ») reste sur les
  seuls messages envoyés.
- [x] **Rupture de 15 minutes vérifiée SM A515F le 2026-08-23**, deux fois :
  dans « Mes notes », le sondage de 05:18 garde son heure bien qu'il soit suivi
  de `rafale_A` du même expéditeur le même jour ; dans le groupe « Diaspora
  Niger — Canada », 05:55 et 06:30 (35 min) forment deux rafales et la bulle du
  milieu est masquée. Sans la rupture, 05:55 aurait disparu.
- [ ] **Rupture de 15 minutes** (`kDureeRafale`,
  [message_grouping.dart](lib/features/messages/presentation/utils/message_grouping.dart)) :
  deux messages du même expéditeur espacés de plus de 15 min ne forment plus
  une rafale — celui du matin retrouve son heure. La rupture casse aussi le
  regroupement **visuel** (queue de bulle, nom de l'expéditeur en groupe) :
  c'est voulu, mais c'est le point à regarder en premier au téléphone. Le
  seuil est une constante, facile à retoucher si 15 min tombe mal.
  Comportement verrouillé par
  [rafale_position_test.dart](test/features/messages/rafale_position_test.dart)
  (7 cas), mais aucun test ne couvre le **rendu**.
- [ ] Build + install pas encore faits sur SM A515F depuis ce changement
  (travail réalisé dans un worktree isolé).

---

## Comment tester (rappel de la config utilisée précédemment)

- Appareil de référence : Samsung SM A515F (Galaxy A51), id `R58N91XBA7B`.
- `adb` : `C:\Users\danko\AppData\Local\Android\Sdk\platform-tools\adb.exe` (pas dans le PATH).
- Après `flutter run`, l'app repasse en arrière-plan (le process se détache) : la ramener avec
  ```
  adb shell monkey -p com.diasponiger.diasponiger -c android.intent.category.LAUNCHER 1
  ```
  puis attendre ~12s (splash).
- Capture d'écran : capturer sur l'appareil puis `pull` (la redirection PowerShell `>` corrompt le PNG) :
  ```
  adb shell screencap -p /sdcard/s.png
  adb pull /sdcard/s.png <destination>
  adb shell rm /sdcard/s.png
  ```
- Piège connu : un VPN persistant sur le téléphone masque l'état hors-ligne réel (transport VPN toujours "connecté" même en mode avion).
