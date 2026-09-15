# Passer la messagerie à MLS — plan d'intégration (v2, 2026-09-14)

Plan d'intégration de l'architecture **Flutter + Rust/OpenMLS (via Flutter
Rust Bridge) + Supabase**, écrit sur l'état **mesuré** de la production, avec
la solution retenue pour les messages qui y sont déjà.

La v1 (commits `fe2f1f3`, `9eb5893`, même jour) posait le diagnostic et les
phases. Cette v2 la réorganise en plan d'intégration : correspondance élément
par élément entre l'architecture proposée et ce dépôt, schéma PostgreSQL et
RLS exacts, flux MLS sur ces tables, façade Rust et interfaces Dart, format du
payload, et le traitement complet des messages existants. Le diagnostic de la
v1 est conservé en § 10, parce qu'il commande une règle de conception.

---

# 0. Résumé

1. **Il n'y a rien à re-chiffrer.** Les 115 messages de production sont tous
   lisibles par le serveur par construction (repli AES à clé dérivée côté
   serveur, `decrypt_aes_fallback()` en Postgres). Le problème n'est pas
   cryptographique, c'est la **continuité d'affichage** de 9 conversations.
2. **Solution retenue : gel + coexistence.** `messages` devient un historique
   en lecture seule (`REVOKE INSERT`), une table `mls_messages` reçoit tout le
   trafic. Chaque conversation porte une date de bascule `mls_since` ; avant,
   on lit le legacy avec le lecteur existant figé ; après, MLS. Un séparateur
   visible marque la frontière dans le fil.
3. **Ré-encapsuler l'historique en MLS est écarté** : produire un ciphertext
   MLS exige d'être membre à l'epoch courant, donc un script serveur aurait
   les clés — exactement ce qu'on supprime.
4. **L'architecture proposée est adoptée dans ses principes** (appareil =
   participant cryptographique, Rust garde les secrets, Supabase = service de
   livraison hostile, push opaque) et **adaptée dans ses détails** : identifiants
   `TEXT` (uid Firebase, ids Firestore hérités) et non `uuid`, table `users` et
   non `profiles`, `participant_ids` conservé, pas de monorepo, pas de SQLite
   Dart, appels hors périmètre, pièces jointes avant MLS.
5. **Ce que MLS casse** : l'aperçu des notifications côté serveur (à
   reconstruire sur l'appareil, iOS sans Notification Service Extension
   aujourd'hui), l'aperçu en clair de la liste des discussions, la recherche
   serveur dans les messages, et la règle « une seule session par compte »
   qui rend le multi-appareil impossible tant qu'elle tient.
6. **Le risque numéro un n'est pas technique** : le chantier Signal précédent
   a livré 8 608 lignes et transporté **0 message**, à cause d'un cycle de vie
   Riverpod qui remettait le moteur à « non initialisé » sans que rien ne le
   rejoue. Chaque phase se termine donc par une preuve de vie **en base**.
7. **Ordre de grandeur** : 6 à 9 mois pour un développeur seul à temps
   partiel, si le spike de 2 semaines passe. Le gain le plus rapide reste
   hors MLS : chiffrer les pièces jointes avec le repli existant.
8. **Décisions actées le 2026-09-14** (§ 11) : toutes les recommandations,
   plus une métadonnée en ligne pour chaque fonctionnalité « locale » (J).
   Départ : spike et C4 en parallèle.

---

# 1. État mesuré de la production

Relevé le 2026-09-14 (soir) sur `zyrfkcjjrhddpfxcgezo`, en lecture seule, sans
lire le contenu d'un message.

| Mesure | Valeur |
|---|---|
| Messages | **115** (9 conversations sur 18, 14 auteurs, 2026-08-15 → 2026-09-14) |
| … en `encryptionLevel = 'e2ee'` (Signal) | **0** |
| … avec `e2eePayloads` ou `senderKeyPayload` | **0** |
| Conversations | 18 (12 individuelles, 6 de groupe) ; 10 lignes `groups` |
| Utilisateurs | 49, dont 33 avec un jeton push |
| Appareils Signal enregistrés (`e2ee_devices`) | 49 |
| Jeux de clés Signal (`e2ee_user_keys`) | 39 |
| Prékeys à usage unique | 4 581 |
| Lignes `e2ee_sender_key_distributions` | 0 |

## Les 115 messages, par type et par format de `data->>'content'`

| Type | Niveau | Format du contenu | Nombre | Conv. | Période |
|---|---|---|---|---|---|
| text | aes | `v<n>:iv:ct` — clé **dérivée** (`crypto-keys`) | 67 | 8 | 08-15 → 09-14 |
| text | aes | `iv:ct` — clé **globale** de l'APK | 14 | 3 | 09-07 → 09-11 |
| text | aes | vide | 2 | 1 | 09-09 → 09-14 |
| call | null | clair | 10 | 1 | 08-15 |
| poll | aes | clair (`pollId`, le sondage vit en Postgres) | 4 | 1 | 09-14 |
| video / file / image / voiceNote | aes | vide — URL Firebase Storage **en clair** dans `fileUrl` | 8 / 3 / 3 / 3 | — | 08-20 → 09-08 |
| location | aes | clair (`latitude`/`longitude`/adresse) | 1 | 1 | 09-09 |

Trois lecteurs distincts sont donc nécessaires pour cet historique, et **ils
existent tous les trois dans `MessageCryptoService.decrypt`** :
`_dechiffrerRepli` (clé dérivée via `DerivedKeyStore` → `crypto-keys`),
`EncryptionService` (clé globale), et le passage en clair. C'est ce lecteur,
figé, qui reste le lecteur du legacy.

Schéma réel (confirmé par `information_schema`, ces tables n'ont **aucun**
`CREATE TABLE` dans le dépôt) :

- `messages(id text, conversation_id text, sender_id text, type text,
  is_deleted bool, created_at timestamptz, data jsonb)` — tout le reste
  (contenu, reçus, réactions, réponses, payload E2EE) est dans `data`.
- `conversations(id text, type text, participant_ids text[], group_id text,
  last_message_at, data jsonb, created_by text, created_at, updated_at)`.
- `users.id text` = uid Firebase (28 caractères). `firebase_uid()` est le
  helper RLS ; `is_conversation_participant()` existe aussi.
- Policies `messages` : SELECT/UPDATE si `participant_ids @> [firebase_uid()]`,
  INSERT/DELETE si `sender_id = firebase_uid()`.

---

# 2. Les messages existants : la solution retenue

## 2.1 Ce qu'ils sont vraiment

Aucun des 115 n'est chiffré de bout en bout. Le repli AES à clé dérivée est du
**chiffrement au repos à clés gérées** : la racine `AES_ROOT_KEY_V1` vit dans
les secrets Edge Functions et dans le Vault Supabase, et Postgres possède
`decrypt_aes_fallback(p_content, p_conversation_id)` — écrite exprès pour que
le trigger `notify_recipients_on_message_insert` mette le vrai texte dans
`notifications.body`. Les 14 messages à clé globale sont lisibles par
quiconque a extrait la constante de l'APK.

**Il n'y a donc aucun corpus confidentiel à protéger pendant la migration.**
Il y a 115 bulles qui ne doivent pas disparaître de l'écran de 14 personnes.

## 2.2 Décision : gel + coexistence

Retenue parmi trois options :

| Option | Verdict | Pourquoi |
|---|---|---|
| **A1. Gel + coexistence** | **Retenue** | Historique préservé, garantie auditable (`REVOKE INSERT`), un seul flux vivant |
| A2. Purge (comme le 2026-08-14) | Repli | Gratuit et honnête, mais détruit 9 conversations réelles. À ressortir si la fusion de deux sources coûte plus que prévu à l'usage |
| A3. Ré-encapsulation en MLS | **Écartée définitivement** | Un serveur qui produit un ciphertext MLS possède les clés ; un client qui ré-émet l'historique fausse auteurs, horodatages et reçus. On détruirait l'historique en croyant le sauver |

Une quatrième forme, « une colonne `protocol` sur `messages` », est écartée
aussi : elle garderait `messages` ouverte en écriture, donc perdrait la
garantie auditable, et mélangerait deux modèles de reçus/réactions dans un
même JSONB.

## 2.3 Mécanique précise

### Côté base

1. **`conversations.mls_since timestamptz NULL`** et **`mls_group_id bytea
   NULL`** (nouvelles colonnes). Nulles = conversation legacy. Posées **une
   seule fois**, par le client qui crée le groupe MLS ; un trigger refuse tout
   retour à `NULL` ou toute modification ultérieure.
2. **Pendant la coexistence (phases 5 → 6)** : une conversation est dans un
   état ou dans l'autre, jamais les deux. `messages` refuse l'insertion dès
   que la conversation porte `mls_since` (trigger `BEFORE INSERT`), pour
   qu'un ancien build ne puisse pas glisser un message en clair dans une
   conversation basculée.
3. **Au gel (phase 6)** : `REVOKE INSERT ON public.messages FROM authenticated`.
   `UPDATE` et `DELETE` restent : supprimer pour soi, supprimer pour tous et
   retirer une réaction sur un vieux message doivent continuer de marcher. Les
   triggers d'insertion (`notify_recipients_on_message_insert`, `trg_notify_push`
   sur `messages`) deviennent morts de fait ; les retirer explicitement.
4. **`decrypt_aes_fallback()` sort des triggers** à ce moment-là, mais la
   fonction et **l'Edge Function `crypto-keys` restent en service** : c'est
   `crypto-keys` qui donne au client la clé de lecture des 67 messages à clé
   dérivée. Elles ne s'éteignent qu'avec la purge du legacy (§ 2.4).

### Côté client

5. **`LegacyMessageReader`** — nouveau nom pour un code existant : le
   déchiffrement actuel de `MessageCryptoService.decrypt` (dérivé, global,
   clair, et les placeholders Signal `undecryptable_placeholders.dart`),
   figé, en lecture seule, sans plus aucun chemin d'écriture.
6. **`MessageSourceMerger`** dans `message_repository_impl.dart` :
   `getMessagesPaginated` pagine d'abord `mls_messages` (plus récent → plus
   ancien) ; quand la page franchit `mls_since`, elle continue dans
   `messages`. Le flux temps réel (`getNewMessagesStream`, `.stream()` de
   Supabase ne sait pas joindre deux tables) ne porte **que** `mls_messages` :
   le legacy est statique, une lecture paginée suffit, mise en cache dans
   Hive comme aujourd'hui.
7. **Séparateur** dans le fil, rendu comme un message système :

   ```text
   ─────── Messages d'avant le chiffrement de bout en bout ───────
   ```

   Au-dessus du séparateur, le cadenas de l'en-tête (`conversation_screen.dart`
   § 4a) dit « chiffrement de bout en bout » ; en dessous, rien — le cadenas
   actuel ment déjà (il ne reflète pas le niveau réel), ce plan le corrige.
8. **Cache Hive inchangé** (`CacheService.cacheMessages` fusionne par id, les
   deux sources cohabitent sous le même `conversationId`). `MessageModel`
   gagne un champ `protocol` (`legacy` | `mls`) — remplace à terme
   `encryptionLevel`, qui n'a jamais dit la vérité.
9. **`conversations.data.lastMessage`** : aujourd'hui en clair par conception
   (8 valeurs non vides, 0 chiffrée). Le chemin MLS n'y écrit **plus jamais de
   texte** : seulement `lastMessageAt`, `lastMessageKind`, `lastMessageSenderId`.
   La liste des discussions affiche l'aperçu depuis le cache local déchiffré,
   sinon « Nouveau message ». **C'est une perte visible** (décision G, § 11).

### Ce que vit l'utilisateur

- Sur un build à jour : ses conversations continuent, avec le séparateur.
- Sur un ancien build, après bascule d'une conversation : il **lit** toujours
  l'historique, ne voit **pas** les nouveaux messages, et son envoi échoue
  (trigger du point 2). D'où la mise à jour minimale imposée (décision B) :
  `CoordinateurMiseAJour` (`lib/core/services/mise_a_jour_service.dart`)
  existe, à réutiliser, pas à réécrire.
- Après réinstallation : l'historique legacy revient (clé dérivée re-servie
  par `crypto-keys`), l'historique MLS **non** — c'est la propriété même du
  protocole. Prévoir l'écran qui le dit avant que le support ne le découvre.

## 2.4 Ce qui reste lisible par le serveur, et jusqu'à quand

| Donnée | Lisible par | Jusqu'à |
|---|---|---|
| 67 textes à clé dérivée | Supabase (racine Vault) | purge du legacy |
| 14 textes à clé globale | quiconque a l'APK | purge du legacy (rotation impossible sans les réécrire — pas la peine pour 14 lignes) |
| 17 médias (URL Firebase Storage en clair, lisibles par **tout compte connecté**, cf. `CHIFFREMENT_MEDIAS_PLAN.md`) | tout utilisateur | purge, ou restriction de `storage.rules` aux participants (gratuit, à faire de toute façon) |
| `lastMessage` en clair | Supabase | vidage à la bascule de chaque conversation |
| `notifications.body` des anciens messages | Supabase | 30 jours (rétention existante) ou purge ciblée |

**Recommandation (décision H)** : annoncer dans l'app une purge du legacy
**90 jours après le gel**, puis supprimer `messages`, ses médias Storage, les
`notifications` associées, et **enfin** `crypto-keys`, `decrypt_aes_fallback`,
`aes_root_key_v1` et `EncryptionService._sharedKeyString`. Sans purge, ces
trois clés restent load-bearing pour toujours.

---

# 3. Correspondance entre l'architecture proposée et le dépôt

| Élément proposé | Ce qui existe ici | Décision |
|---|---|---|
| Rust + OpenMLS 0.9 via **Flutter Rust Bridge** | Rien (Rust absent du poste, aucun FFI dans `pubspec.yaml`) | **Adopter.** Un crate `rust/` à la racine, pas de monorepo (C1) |
| Monorepo `apps/` + `packages/` + melos | `lib/features/…`, 81 fichiers dans `features/messages`, deux agents sur une branche partagée | **Écarter (C1).** Déplacer `lib/` rend tout merge impossible pendant des jours |
| `profiles(id uuid)` | `users(id text)` = uid Firebase, `firebase_uid()` en RLS | **Adapter :** `devices.user_id text references users(id)` |
| `devices` | `e2ee_devices` (Signal : `identity_key`, `signed_pre_key`, `device_id text`), plafond 5, `stable_device_id.dart` | **Nouvelle table `devices`** (§ 4). Réutiliser `stable_device_id.dart` et l'écran « appareils connectés ». `e2ee_devices` reste tant que le legacy vit |
| `mls_key_packages` | `e2ee_one_time_prekeys` (4 581 lignes, jamais consommées) | **Adopter**, avec un RPC de réclamation atomique et un paquet « de dernier recours » (§ 4) |
| `conversations(type direct/group)` | `conversations(type, participant_ids[], group_id)` + index « une par groupe » | **Garder** la table, ajouter `mls_since` et `mls_group_id`. `direct` ≙ `individual`, plus le self-chat « Mes notes » (groupe MLS des appareils d'un seul utilisateur) |
| `conversation_members` | `participant_ids` (array, base de toutes les policies), `group_members` pour les groupes | **Garder `participant_ids`.** Ne pas dupliquer la source d'autorisation |
| `conversation_devices` | Rien | **Adopter**, minimal : sert à voir les appareils **en attente** d'ajout (§ 5.4) |
| `messages(ciphertext, epoch, sender_device_id)` | `messages(data jsonb)` TEXT ids, tout dans `data` | **Nouvelle table `mls_messages`** ; `messages` gelée (§ 2) |
| MLS state en SQLite **côté Rust** | Rien | **Adopter** (`openmls_sqlite_storage`), chiffrée par une clé maître du Keystore/Keychain |
| SQLite **Dart** pour le cache d'affichage | Hive (`cache_service.dart`), lu par les 81 fichiers | **Écarter (C2).** Chantier séparé, légitime, pas ici |
| Clés privées dans Keychain/Keystore | `flutter_secure_storage` déjà en place (`secure_key_storage.dart`, `first_unlock_this_device`) | **Adopter** pour la clé maître ; les secrets MLS ne quittent pas Rust |
| Pièces jointes : clé aléatoire AES-GCM transportée dans le message MLS | `MediaEncryptionService` complet, **0 appelant** ; médias en clair sur Firebase Storage | **Avant MLS (C4)**, avec le repli AES ; puis déplacer la clé dans le payload MLS (phase 9) |
| Push minimal `{type, conversation_id, message_id}` | Android déjà **data-only** (`send-push/index.ts`), iOS `aps.alert` en clair | **Adopter** ; iOS demande une NSE (§ 8) |
| Appels WebRTC E2EE, SFU, clé dérivée de MLS | Firestore + RTDB + coturn, en pause côté UI | **Hors périmètre (C3).** Garder `exportSecret()` comme point d'extension, sans le câbler |
| Vérification d'identité (QR, safety number) | Transfert de clés par QR (`key_transfer_service.dart`), scanner `mobile_scanner` | **Adopter** en phase 7 ; réutiliser `QrCodeParser` |
| AAD liant le ciphertext à son contexte | Rien | **Adopter** (§ 6) |
| Payload structuré versionné | `data` JSONB camelCase, texte seul chiffré, annexes dans `encAnnexes` | **Adopter** : tout le contenu entre dans le payload, plus rien de lisible à côté (§ 6) |
| Edge Functions limitées (push, nettoyage, devices) | `send-push`, `crypto-keys` (à éteindre avec le legacy) | **Adopter** ; aucune Edge Function ne touche un ciphertext MLS |
| Multi-appareil (appareil = participant) | **Une seule session par compte** (`SessionService`, éjection « Connecté ailleurs ») ; groupes Signal cassés au 2e appareil | **Adopter en phase 7**, ce qui impose de **lever la règle** (décision E) |

---

# 4. Schéma PostgreSQL cible et RLS

Conventions du dépôt : ids utilisateurs et conversations en `text`,
`firebase_uid()` comme identité, policies réservées au rôle `authenticated`
(un `anon` lit 0 ligne **sans erreur** — 7e forme de
`project_supabase_echecs_muets` ; toujours `ensureAuthenticated()` avant).

```sql
-- Appareils : un par installation, matériel cryptographique public seulement.
create table devices (
  id            uuid primary key default gen_random_uuid(),
  user_id       text not null references users(id) on delete cascade,
  stable_id     text not null,              -- stable_device_id.dart
  name          text not null,              -- device_label.dart
  platform      text not null check (platform in ('android','ios')),
  signature_key bytea not null,             -- clé publique de signature MLS
  credential    bytea not null,             -- BasicCredential = uid || ':' || id
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz,
  revoked_at    timestamptz,
  unique (user_id, stable_id)
);

-- KeyPackages : consommables, sauf le « dernier recours ».
create table mls_key_packages (
  id             uuid primary key default gen_random_uuid(),
  device_id      uuid not null references devices(id) on delete cascade,
  key_package    bytea not null,
  cipher_suite   text not null,
  is_last_resort boolean not null default false,
  created_at     timestamptz not null default now(),
  expires_at     timestamptz not null,
  used_at        timestamptz
);
create index on mls_key_packages (device_id) where used_at is null;

-- Conversations : deux colonnes, posées une seule fois.
alter table conversations
  add column mls_since    timestamptz,
  add column mls_group_id bytea;
-- trigger : refuse toute modification de mls_since / mls_group_id une fois non nuls.

-- Appareils d'une conversation, vus par le service de livraison.
create table conversation_devices (
  conversation_id text not null references conversations(id) on delete cascade,
  device_id       uuid not null references devices(id) on delete cascade,
  status          text not null check (status in ('pending','active','removed')),
  epoch_added     bigint,
  epoch_removed   bigint,
  updated_at      timestamptz not null default now(),
  primary key (conversation_id, device_id)
);

-- Commits : UN par epoch et par conversation. La contrainte unique EST le
-- service de livraison : deux commits concurrents, un seul gagne, l'autre
-- reçoit 23505, traite le gagnant, et recommence.
create table mls_commits (
  conversation_id  text not null references conversations(id) on delete cascade,
  epoch            bigint not null,          -- epoch PRODUIT par ce commit
  sender_device_id uuid not null references devices(id),
  commit           bytea not null,           -- MlsMessageOut sérialisé
  group_info       bytea,                    -- pour les jointures externes (§ 5.7)
  created_at       timestamptz not null default now(),
  primary key (conversation_id, epoch)
);

-- Welcome : un par appareil ajouté.
create table mls_welcomes (
  id                  uuid primary key default gen_random_uuid(),
  conversation_id     text not null references conversations(id) on delete cascade,
  recipient_device_id uuid not null references devices(id) on delete cascade,
  epoch               bigint not null,
  welcome             bytea not null,
  created_at          timestamptz not null default now(),
  consumed_at         timestamptz
);

-- Messages : le serveur voit qui, quand, où, quelle taille. Jamais quoi.
create table mls_messages (
  id               uuid primary key,          -- généré client (≙ clientMessageId)
  conversation_id  text not null references conversations(id) on delete cascade,
  sender_id        text not null references users(id),
  sender_device_id uuid not null references devices(id),
  epoch            bigint not null,
  kind             text not null check (kind in ('content','control')),
  content_type     text not null check (content_type in
                     ('text','media','voice','location','poll','sticker','system')),
  ciphertext       bytea not null,
  aad_version      smallint not null default 1,
  reply_to_id      uuid references mls_messages(id),   -- métadonnée (J) ; l'extrait cité reste dans le payload
  is_deleted       boolean not null default false,     -- « pour tous » : le serveur cesse de servir le ciphertext
  deleted_at       timestamptz,
  edited_at        timestamptz,                        -- posé par l'expéditeur avec le contrôle `edit`
  expires_at       timestamptz,
  created_at       timestamptz not null default now()
);
create index on mls_messages (conversation_id, created_at desc);

-- Métadonnées en ligne des fonctionnalités « locales » (décision J) : ce qui
-- suit est visible du serveur — qui a réagi, lu, masqué, étoilé, été mentionné.
-- Le CONTENU (emoji, nouveau texte) voyage aussi en contrôle MLS ; la table
-- sert à la synchronisation entre appareils, à la réinstallation et aux
-- compteurs. Sans elle, un second appareil ne verrait ni réactions ni favoris.

-- Reçus : nécessaire aux compteurs de non-lus.
create table mls_message_receipts (
  message_id   uuid not null references mls_messages(id) on delete cascade,
  user_id      text not null references users(id) on delete cascade,
  delivered_at timestamptz,
  read_at      timestamptz,
  primary key (message_id, user_id)
);

-- Réactions : une par personne et par message, comme aujourd'hui.
create table mls_message_reactions (
  message_id uuid not null references mls_messages(id) on delete cascade,
  user_id    text not null references users(id) on delete cascade,
  emoji      text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

-- « Supprimer pour moi » : masqué pour cet utilisateur, sur tous ses appareils.
create table mls_message_hidden (
  message_id uuid not null references mls_messages(id) on delete cascade,
  user_id    text not null references users(id) on delete cascade,
  hidden_at  timestamptz not null default now(),
  primary key (message_id, user_id)
);

-- Favoris.
create table mls_message_stars (
  message_id uuid not null references mls_messages(id) on delete cascade,
  user_id    text not null references users(id) on delete cascade,
  starred_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

-- Mentions : écrites par l'expéditeur, lues pour le compteur « mentions non lues ».
create table mls_message_mentions (
  message_id uuid not null references mls_messages(id) on delete cascade,
  user_id    text not null references users(id) on delete cascade,
  primary key (message_id, user_id)
);

-- Aperçu de la liste des discussions : des métadonnées, jamais le texte.
alter table conversations
  add column last_message_id        uuid,
  add column last_message_kind      text,    -- content_type du dernier message
  add column last_message_sender_id text;
-- `last_message_at` existe déjà. Le texte de l'aperçu vient du cache local
-- déchiffré ; à défaut, l'UI dérive « Photo », « Note vocale », « Nouveau
-- message » de `last_message_kind`.

-- Non-lus et mentions non lues : calculés, pas stockés.
create view mls_unread_counts as
select m.conversation_id, u.user_id,
       count(*) filter (where r.read_at is null)                                      as unread,
       count(*) filter (where r.read_at is null and mn.user_id is not null)          as unread_mentions
  from mls_messages m
  join conversations c on c.id = m.conversation_id
  join unnest(c.participant_ids) as u(user_id) on u.user_id <> m.sender_id
  left join mls_message_receipts r  on r.message_id = m.id and r.user_id = u.user_id
  left join mls_message_mentions mn on mn.message_id = m.id and mn.user_id = u.user_id
  left join mls_message_hidden  h   on h.message_id = m.id and h.user_id = u.user_id
 where m.kind = 'content' and not m.is_deleted and h.message_id is null
 group by m.conversation_id, u.user_id;
-- Filtrée par RLS via `security_invoker = on` : chacun ne voit que ses lignes.

-- Diagnostics : le motif d'échec s'écrit EN BASE, jamais un plaintext.
create table mls_diagnostics (
  id         bigint generated always as identity primary key,
  user_id    text not null,
  device_id  uuid,
  event      text not null,     -- 'encrypt_failed', 'aad_mismatch', 'stale_epoch', 'engine_reopened', …
  detail     jsonb,             -- codes, epochs, compteurs. Jamais de contenu.
  created_at timestamptz not null default now()
);
```

Réclamation atomique d'un KeyPackage (sinon deux ajouts concurrents
consomment le même paquet et le second Welcome est indéchiffrable) :

```sql
create function claim_key_package(p_device_id uuid) returns mls_key_packages
language plpgsql security definer set search_path = public as $$
declare r mls_key_packages;
begin
  update mls_key_packages set used_at = now()
   where id = (select id from mls_key_packages
                where device_id = p_device_id and used_at is null
                  and not is_last_resort and expires_at > now()
                order by created_at limit 1 for update skip locked)
  returning * into r;
  if r.id is null then
    select * into r from mls_key_packages
     where device_id = p_device_id and is_last_resort and expires_at > now()
     order by created_at desc limit 1;
  end if;
  return r;
end $$;
```

## Policies (toutes `TO authenticated`)

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `devices` | tous (il faut voir les appareils d'autrui pour les ajouter) | `user_id = firebase_uid()` | idem (nom, `last_seen_at`, `revoked_at`) | idem |
| `mls_key_packages` | tous | appareil possédé (`exists devices d where d.id = device_id and d.user_id = firebase_uid()`) | **aucune** (passer par `claim_key_package`) | appareil possédé |
| `conversation_devices` | participant | participant | participant | — |
| `mls_commits` | participant | participant **et** `sender_device_id` possédé | — | — |
| `mls_welcomes` | destinataire (`recipient_device_id` possédé) | participant | destinataire (`consumed_at`) | destinataire |
| `mls_messages` | participant | `sender_id = firebase_uid()` **et** participant **et** appareil possédé | expéditeur, colonnes `is_deleted`, `deleted_at`, `edited_at`, `expires_at` seulement (`GRANT UPDATE (…)`) | expéditeur |
| `mls_message_receipts` | participant | `user_id = firebase_uid()` | idem | — |
| `mls_message_reactions` | participant | `user_id = firebase_uid()` **et** participant | idem | idem |
| `mls_message_hidden` | `user_id = firebase_uid()` (personne d'autre n'a à savoir ce que je masque) | idem | — | idem |
| `mls_message_stars` | `user_id = firebase_uid()` | idem | — | idem |
| `mls_message_mentions` | participant | expéditeur du message (`exists mls_messages m where m.id = message_id and m.sender_id = firebase_uid()`) | — | expéditeur |
| `conversations.last_message_*` | participant (déjà) | — | participant, par le trigger de `mls_messages` | — |
| `mls_diagnostics` | `user_id = firebase_uid()` ou admin | `user_id = firebase_uid()` | — | — |

« participant » = `exists (select 1 from conversations c where c.id =
conversation_id and c.participant_ids @> array[firebase_uid()])`, comme
aujourd'hui. `mls_messages`, `mls_commits`, `mls_welcomes` entrent dans la
publication `supabase_realtime`.

**Ce que le RLS garantit et ce qu'il ne garantit pas.** Il empêche un
non-participant de lire des ciphertexts ; il n'empêche pas Supabase de
substituer un KeyPackage (confiance au premier usage). La vérification
hors bande (phase 7) est la seule réponse à ce risque.

## Triggers

- `mls_messages` `AFTER INSERT` (kind = `content`) → une ligne `notifications`
  par destinataire avec un `body` **générique** (« Nouveau message »,
  « Photo », selon `content_type`) et `data = {type:'message', protocol:'mls',
  conversationId, messageId}`, puis `trg_notify_push` existant → `send-push`.
  `send-push` envoie déjà en data-only pour `type = 'message'`.
- `mls_messages` `AFTER INSERT` → `conversations.last_message_at`, et
  `data.lastMessageKind/lastMessageSenderId` — **jamais** `lastMessage`.
- `messages` `BEFORE INSERT` → refus si la conversation porte `mls_since`.
- `conversations` `BEFORE UPDATE` → refus si `mls_since` ou `mls_group_id`
  changent après avoir été posés.

---

# 5. Flux MLS sur ces tables

Toute la cryptographie est dans Rust (§ 7). Dart orchestre les tables.

## 5.1 Enregistrement d'un appareil (à chaque connexion)

```text
stable_device_id → devices (upsert, last_seen_at)
Rust: identité + clé de signature (si absentes) → devices.signature_key/credential
Rust: N KeyPackages + 1 « dernier recours » → mls_key_packages
```

Réapprovisionnement : quand `count(used_at is null) < 10`, en regénérer 50.
Expiration à 90 jours. Un appareil dont `revoked_at` est posé n'a plus de
paquets valides (trigger de nettoyage).

## 5.2 Création d'une conversation 1:1 (Alice → Bob)

```text
Alice : Rust createGroup(conversationId) → mls_group_id, epoch 0
        conversations.mls_since = now(), mls_group_id (une seule fois)
        pour chaque appareil actif de Bob ET chaque autre appareil d'Alice :
            claim_key_package(device) → KeyPackage
        Rust addMembers(keyPackages) → commit (epoch 1) + welcome(s)
        INSERT mls_commits (conversationId, 1)          ← unique : Alice gagne
        INSERT mls_welcomes × appareils
        INSERT conversation_devices (status active, epoch_added 1)
        Rust mergePendingCommit()
Bob   : Realtime mls_welcomes → Rust processWelcome → groupe à l'epoch 1
        UPDATE mls_welcomes.consumed_at
```

Si `claim_key_package` ne rend rien (appareil sans paquet) : l'appareil est
inscrit en `conversation_devices.status = 'pending'`, et l'envoi **part quand
même** vers les appareils joignables. L'appareil en attente sera ajouté par
le premier membre en ligne qui voit un `pending` avec un paquet disponible
(§ 5.4). Il ne lit pas ce qui a été envoyé avant son ajout — propriété du
protocole, à dire à l'utilisateur.

## 5.3 Envoi et réception d'un message

```text
Envoi     : payload (§ 6) → JSON → Rust encrypt(conversationId, plaintext, AAD)
            INSERT mls_messages (id, epoch = epoch courant, ciphertext, kind, content_type)
            — refus visible si Rust échoue. Aucun repli. mls_diagnostics.
Réception : Realtime mls_messages → recompose l'AAD depuis les COLONNES de la ligne
            → Rust processIncoming(conversationId, ciphertext, AAD)
            → payload → MessageModel → cache Hive → UI / notification locale
```

Un message d'un epoch **antérieur** à l'epoch courant est encore déchiffrable
(OpenMLS garde les secrets des epochs passés dans une fenêtre configurable —
`max_past_epochs`, à régler ≥ 3 au spike) ; au-delà, placeholder explicite +
`mls_diagnostics('stale_epoch')`. Un message d'un epoch **futur** signifie un
commit pas encore traité : mettre en attente, traiter d'abord `mls_commits`.

**Ordre de traitement, non négociable** : pour une conversation, les
`mls_commits` se traitent par `epoch` croissant, **avant** tout `mls_messages`
d'epoch supérieur. Le rattrapage à la reconnexion (≈ 15 s, vérifié appareil)
fait la même chose depuis le dernier epoch connu localement.

## 5.4 Ajout d'un membre (et le commit concurrent)

```text
Membre en ligne voit : participant_ids contient X, mais aucun appareil actif de X
                       dans le groupe (snapshot Rust) ou un conversation_devices.pending
→ claim_key_package(chaque appareil de X) → Rust addMembers → commit epoch n+1
→ INSERT mls_commits (conv, n+1)
     ├─ succès  → INSERT welcomes, conversation_devices active, mergePendingCommit
     └─ 23505   → un autre membre a commité n+1 : clearPendingCommit,
                  traiter mls_commits(n+1), puis recommencer (X y est peut-être déjà)
```

Qui commite ? **Le premier qui voit.** C'est la contrainte unique qui arbitre,
pas une élection. Sur un groupe officiel de 200 membres, la rafale au
lancement est absorbée par les 23505 ; à mesurer au banc (phase 3).

Les chemins d'appartenance existants restent la **source d'autorisation**
(`join_group_conversation`, invitations, groupe officiel selon la ville,
`get_or_create_official_group`) : ils écrivent `participant_ids` comme
aujourd'hui, et le client MLS **suit**. Rien côté serveur ne touche MLS.

## 5.5 Retrait d'un membre, appareil perdu

```text
Départ / exclusion : participant_ids mis à jour (chemin existant)
→ n'importe quel membre restant : Rust removeMembers(feuilles de X) → commit n+1
→ conversation_devices.status = removed, epoch_removed
Appareil perdu     : devices.revoked_at (depuis un autre appareil du compte)
→ chaque conversation où il siège : removeMembers par un membre en ligne
```

Un membre retiré peut encore **lire** les ciphertexts des epochs où il
siégeait (RLS : il n'est plus participant, donc plus rien) et ne déchiffre
rien après. Le retrait est effectif dès que le commit est traité par
l'expéditeur suivant — pas avant. Entre les deux, un message peut partir vers
l'appareil retiré : fenêtre inhérente, à documenter, pas à cacher.

## 5.6 Rattrapage, réinstallation, moteur recréé

- **Reconnexion** : depuis le dernier epoch local, rejouer `mls_commits` puis
  `mls_messages`, dans cet ordre. `syncMessagesIncremental` existe déjà pour
  le legacy ; même squelette.
- **Réinstallation** : l'état MLS est perdu. L'appareil (même `stable_id`)
  redevient un appareil **neuf** : nouvelle identité, nouveaux paquets,
  `conversation_devices.pending` partout, historique MLS **illisible**. Écran
  explicite « Vos anciens messages chiffrés sont sur votre ancienne
  installation ». Le transfert par QR (`key_transfer_service.dart`) peut porter
  la base Rust chiffrée d'un appareil à l'autre — c'est la seule continuité
  possible, et elle vaut plus avec MLS qu'avec Signal.
- **Moteur recréé en cours de session** : `encrypt` et `processIncoming`
  rouvrent la base eux-mêmes s'ils trouvent le moteur fermé, et écrivent
  `mls_diagnostics('engine_reopened')`. Jamais de « non initialisé » silencieux
  (§ 10).

## 5.7 Groupes ouverts : jointure externe

Le groupe officiel d'une ville se rejoint **automatiquement**, souvent sans
qu'aucun membre ne soit en ligne. Attendre un membre pour être ajouté est
inacceptable là. RFC 9420 prévoit l'**External Commit** : le committeur publie
un `GroupInfo` (arbre public, pas de secret) dans `mls_commits.group_info`, et
le nouvel arrivant s'ajoute lui-même.

- Réservé aux conversations `type = 'group'` dont le groupe est public ou
  officiel ; les 1:1 et groupes privés restent en ajout par un membre.
- Le `GroupInfo` est protégé par le RLS (participants seulement) : le serveur
  reste l'autorité d'appartenance, MLS reste l'autorité cryptographique.
- Les membres qui reçoivent un External Commit **vérifient** que l'identité de
  la credential est dans `participant_ids` avant de le fusionner — c'est la
  « validation du credential par le service d'authentification » que la doc
  OpenMLS laisse à l'application.

À valider au spike : OpenMLS 0.9 expose la jointure externe
(`join_by_external_commit`, nom à confirmer) et la publication du `GroupInfo`
avec arbre.

---

# 6. Format du payload et devenir de chaque fonctionnalité

## 6.1 AAD

```text
AAD = "dn-mls/1" || conversation_id || message_id || sender_device_id || kind
```

Recomposé par le récepteur depuis les **colonnes** de `mls_messages`, jamais
depuis le payload. Un ciphertext déplacé vers une autre conversation, un
autre id ou un autre expéditeur échoue à l'authentification →
`mls_diagnostics('aad_mismatch')` et placeholder. `epoch` est déjà dans le
cadre MLS, inutile de le répéter.

## 6.2 Payload (plaintext, JSON UTF-8, versionné)

```json
{
  "v": 1,
  "id": "uuid — égal à mls_messages.id",
  "type": "text | image | video | file | voiceNote | location | poll | sticker | call | system",
  "sentAt": 1789420000,
  "body": {
    "content": "…",
    "fileName": "…", "fileSize": 0, "mimeType": "…",
    "storagePath": "…", "sha256": "…",
    "fileKey": "base64", "fileNonce": "base64",
    "thumbnail": "…", "blurhash": "…", "duration": 0, "waveform": [],
    "latitude": 0, "longitude": 0, "address": "…",
    "pollId": "…", "stickerPackId": "…", "stickerId": "…"
  },
  "replyTo": { "id": "…", "excerpt": "…", "senderId": "…" },
  "mentions": [], "forwarded": false, "expiresIn": null
}
```

Messages de contrôle (`kind = 'control'`, mêmes tables, même ordre) :

```json
{ "v": 1, "op": "reaction", "target": "uuid", "emoji": "❤️" }
{ "v": 1, "op": "edit",     "target": "uuid", "body": { "content": "…" } }
{ "v": 1, "op": "delete",   "target": "uuid" }
```

Tout ce qui fuyait à côté d'un `content` chiffré (légendes, `fileName`,
position, `replyToMessageData`, cartes de partage, `editHistory`) est
maintenant **dans** le payload. `encAnnexes` disparaît avec le legacy.

## 6.3 Devenir de chaque fonctionnalité de message

| Fonctionnalité | Aujourd'hui | Avec MLS |
|---|---|---|
| Texte, réponse, transfert, mentions | `data` (texte chiffré, reste en clair) | payload |
| Image, vidéo, fichier, note vocale | URL Firebase Storage en clair | blob chiffré (AES-GCM, clé dans le payload) — dépend de la phase 9 / C4 |
| Localisation | clair | payload |
| Sondage | `pollId`, contenu en Postgres, vote par `cast_poll_vote` | inchangé : le sondage est serveur par conception (dit dans l'UI) |
| Sticker, GIF | ids de pack / URL Tenor | ids dans le payload ; l'URL Tenor reste une requête réseau visible |
| Réactions | `data.reactions` en clair, modifiable par tout participant | contrôle `reaction` (contenu, ordonné avec les messages) **+ `mls_message_reactions`** (métadonnée : qui, quel emoji — synchronisation multi-appareil et réinstallation) |
| Modification | réécrit `data.content` | contrôle `edit` (nouveau texte, chiffré) **+ `edited_at`** sur la ligne ; le serveur garde le ciphertext d'origine, l'UI affiche « modifié » même sans le contrôle |
| Supprimer pour tous | `is_deleted` + réécriture | **`is_deleted` + `deleted_at`** (le serveur cesse de servir le ciphertext) **+** contrôle `delete` |
| Supprimer pour moi | `deletedFor[]` en base | **`mls_message_hidden`** (visible de moi seul, appliqué sur tous mes appareils) ; le cache Hive suit |
| Reçus livré / lu | `data.readBy`, RPC `mark_messages_as_delivered` | **`mls_message_receipts`** (métadonnée acceptée, décision F) |
| Non-lus, mentions non lues | `conversations.data.unreadCount` map | **vue `mls_unread_counts`** depuis reçus + **`mls_message_mentions`** (écrite par l'expéditeur) + masqués ; le serveur sait qui est mentionné — accepté (J) |
| Aperçu liste des discussions | `lastMessage` en clair | **`last_message_id` / `last_message_kind` / `last_message_sender_id`** en ligne ; le **texte** vient du cache local déchiffré, sinon « Photo », « Note vocale », « Nouveau message » d'après `last_message_kind` (décision G) |
| Réponse à un message | `replyToId` + `replyToMessageData` en clair | `replyTo` dans le payload (extrait chiffré) **+ `reply_to_id`** en ligne (fil de réponses, navigation) |
| Recherche dans une conversation | `searchMessagesInConversation` serveur | **locale** sur le cache Hive — le serveur n'a que du ciphertext, aucune métadonnée ne peut aider ici |
| Messages favoris | `starredBy[]` en base | **`mls_message_stars`** (visible de moi seul) |
| Expiration | `expiresAt` | `expires_at` colonne (le serveur purge) + `expiresIn` payload |
| Épinglés (en pause) | `group_pinned_items` | `group_pinned_items` reste utilisable tel quel (il référence un id de message) ; contrôle `pin` plus tard |
| Frappe en cours | canal Realtime broadcast | inchangé, en clair (éphémère, non stocké) |
| Bulle d'appel | `type = 'call'` | `type = 'call'` dans le payload, `content_type = 'system'` |
| Multi-appareil | 1:1 oui, groupes cassés, une session par compte | appareil = membre MLS, phase 7 |

---

# 7. Couche Rust et interfaces Dart

## 7.1 Crate, versions, cibles

```text
rust/                      ← crate unique « diaspo_mls », à la racine du dépôt
├── Cargo.toml             ← openmls 0.9, openmls_rust_crypto, openmls_basic_credential,
│                            openmls_sqlite_storage, flutter_rust_bridge 2.13, zeroize
├── src/api/…              ← façade exposée à Dart (FRB), rien d'autre n'est public
├── src/mls/…              ← moteur, credentials, storage
└── src/attachments.rs     ← AES-GCM pour les fichiers (remplace MediaEncryptionService à terme)
lib/core/crypto/mls/       ← Dart : frb_generated/ + services
flutter_rust_bridge.yaml
```

Les versions citées (OpenMLS 0.9.0, MSRV Rust 1.91, FRB 2.13.0) sont celles
de la proposition ; **elles se figent dans `Cargo.lock` au spike**, pas ici.
Cibles : `aarch64-linux-android`, `armv7-linux-androideabi`,
`x86_64-linux-android` (émulateur), `aarch64-apple-ios`,
`aarch64-apple-ios-sim`. `flutter_rust_bridge_codegen integrate` installe
cargokit, qui compile le crate depuis Gradle et Xcode.

Contraintes propres à ce dépôt :

- **Rust n'est pas installé sur le poste.** Prérequis du spike : rustup,
  cibles ci-dessus, NDK 27.0.12077973 déjà épinglé dans `build.gradle`.
- **Alignement 16 Ko** : NDK 27 ne l'impose pas par défaut ; passer
  `-Wl,-z,max-page-size=16384` au lien et vérifier par
  `tools/verifie_alignement_16k.py`. Le projet a déjà payé ce problème.
- iOS : un Mac est nécessaire (xcframework, NSE, App Group).
- Une `.so` OpenMLS + provider + SQLite par ABI : **peser l'APK** au spike.

## 7.2 Façade Rust (signatures conceptuelles)

À adapter aux noms réels de l'API OpenMLS 0.9 (`MlsGroup::new`, `load`,
`add_members`, `commit_builder`, `create_message`, `process_message`, …) —
volontairement pas de faux code compilable ici.

```rust
pub struct MlsEngine { /* provider, storage SQLite, credential, signer */ }

impl MlsEngine {
    pub fn open(db_path: String, storage_key: Vec<u8>, device_id: String, user_id: String)
        -> Result<MlsEngine, MlsError>;                       // idempotent
    pub fn identity(&self) -> DeviceIdentity;                 // clé de signature + credential (publics)
    pub fn create_key_packages(&mut self, n: u32, last_resort: bool) -> Result<Vec<Vec<u8>>, MlsError>;

    pub fn create_group(&mut self, conversation_id: String) -> Result<GroupSnapshot, MlsError>;
    pub fn add_members(&mut self, conversation_id: String, key_packages: Vec<Vec<u8>>)
        -> Result<CommitOut, MlsError>;                       // commit + welcome(s) + group_info
    pub fn remove_members(&mut self, conversation_id: String, identities: Vec<Vec<u8>>)
        -> Result<CommitOut, MlsError>;
    pub fn merge_pending_commit(&mut self, conversation_id: String) -> Result<GroupSnapshot, MlsError>;
    pub fn clear_pending_commit(&mut self, conversation_id: String) -> Result<(), MlsError>;

    pub fn process_welcome(&mut self, welcome: Vec<u8>) -> Result<GroupSnapshot, MlsError>;
    pub fn join_by_external_commit(&mut self, conversation_id: String, group_info: Vec<u8>)
        -> Result<CommitOut, MlsError>;
    pub fn process_incoming(&mut self, conversation_id: String, message: Vec<u8>, aad: Vec<u8>)
        -> Result<Processed, MlsError>;                       // Application(bytes) | Commit(snapshot) | Proposal

    pub fn encrypt(&mut self, conversation_id: String, plaintext: Vec<u8>, aad: Vec<u8>)
        -> Result<Vec<u8>, MlsError>;
    pub fn snapshot(&self, conversation_id: String) -> Result<GroupSnapshot, MlsError>; // epoch, membres
    pub fn export_secret(&self, conversation_id: String, label: String, len: u32)
        -> Result<Vec<u8>, MlsError>;                         // point d'extension appels, non câblé
    pub fn safety_code(&self, conversation_id: String, other_identity: Vec<u8>) -> Result<String, MlsError>;

    pub fn encrypt_file(path_in: String, path_out: String) -> Result<FileKey, MlsError>; // flux, par morceaux
    pub fn decrypt_file(path_in: String, path_out: String, key: FileKey) -> Result<(), MlsError>;
}
```

`MlsError` est une énumération **sans message libre** : un code, un epoch, un
compteur — de quoi remplir `mls_diagnostics.detail` sans jamais y mettre un
octet de contenu. `zeroize` sur tout tampon de plaintext.

## 7.3 Interfaces Dart

```dart
// Moteur : objet opaque FRB. Une instance par session utilisateur.
abstract class MlsEngineHandle { … }   // généré

// Registre d'appareils : devices + mls_key_packages, réapprovisionnement.
abstract class MlsDeviceRegistry {
  Future<DeviceRecord> ensureRegistered();          // à chaque connexion
  Future<void> replenishKeyPackages();
  Future<List<DeviceRecord>> activeDevicesOf(String userId);
  Future<void> revoke(String deviceId);
}

// Transport : les tables, rien que les tables. Aucune crypto.
abstract class MlsDelivery {
  Future<void> publishCommit(String conv, int epoch, Uint8List commit, {Uint8List? groupInfo}); // lève EpochConflict
  Future<void> publishWelcomes(String conv, int epoch, Map<String, Uint8List> byDevice);
  Future<void> publishMessage(MlsMessageRow row);
  Stream<MlsCommitRow>  commits(String conv, {required int afterEpoch});
  Stream<MlsWelcomeRow> welcomesForMe();
  Stream<MlsMessageRow> messages(String conv, {required DateTime after});
  Future<KeyPackageRow?> claimKeyPackage(String deviceId);
}

// Orchestration : le seul service que la couche messages appelle.
abstract class MlsConversationService {
  Future<void> ensureGroup(String conversationId);            // crée ou rejoint ; pose mls_since
  Future<void> reconcileMembership(String conversationId);    // participant_ids ↔ membres MLS
  Future<MessageModel> send(String conversationId, MlsPayload payload);   // lève, ne replie jamais
  Stream<MessageModel> incoming(String conversationId);       // commits d'abord, puis messages
  Future<void> catchUp(String conversationId);                // reconnexion
}

// Codec : payload ↔ MessageModel, AAD.
abstract class MlsPayloadCodec {
  Uint8List encode(MlsPayload p);  MlsPayload decode(Uint8List bytes);
  Uint8List aad({required String conversationId, required String messageId,
                 required String senderDeviceId, required String kind});
}

// Legacy, figé : l'actuel MessageCryptoService.decrypt, en lecture seule.
abstract class LegacyMessageReader { Future<MessageModel> read(Map<String, dynamic> row); }

// Fusion des deux sources dans le repository.
abstract class MessageSourceMerger { Future<PaginatedMessages> page(String conv, Cursor c); }
```

Trois règles de conception, tirées du chantier Signal (§ 10) :

1. **Le moteur n'est pas un `Provider` qui en observe d'autres.** Un
   `Provider` à durée de vie session, qui ne dépend que de l'identifiant
   utilisateur ; et `send`/`incoming` rouvrent le moteur eux-mêmes s'il est
   fermé (rattrapage au point d'usage, comme
   `EncryptionService._ensureInitialized`).
2. **Aucun repli.** `send` lève ; l'UI montre l'échec ; `mls_diagnostics`
   reçoit le motif. Il n'existe **pas** de chemin « en clair si MLS échoue ».
3. **Le motif s'écrit en base.** `debugPrint` ne remonte pas dans logcat sur
   un build release — vérifié. Sans `mls_diagnostics`, la prochaine panne
   sera aussi invisible que la précédente.

## 7.4 Stockage local

| Donnée | Où | Protégé par |
|---|---|---|
| État MLS (groupes, arbres, secrets d'epoch, clés de signature, paquets non consommés) | SQLite **côté Rust** (`openmls_sqlite_storage`), fichier dans le répertoire privé de l'app — et dans l'**App Group** sur iOS (§ 8) | clé maître de 32 octets, générée par Rust au premier lancement, conservée par `flutter_secure_storage` (Keystore / Keychain, `first_unlock_this_device`), passée à `open()` et zéroïsée. Chiffrement du fichier : SQLCipher ou chiffrement des valeurs par le provider — **à trancher au spike** |
| Cache d'affichage (messages déchiffrés) | Hive, inchangé | rien de plus qu'aujourd'hui — compromis UX assumé, comme dans la proposition |
| Clé maître | Keystore / Keychain | matériel |

Dart tient la clé maître **en transit** entre le stockage sécurisé et `open()`.
Ce n'est pas un secret MLS ; c'est le prix d'éviter un accès direct au
Keystore depuis Rust. À documenter, pas à cacher.

---

# 8. Notifications

C'est la plus grosse perte fonctionnelle du chantier, et elle est structurelle :
**aujourd'hui, Postgres déchiffre** dans le trigger et le vrai texte part dans
le push. Après MLS, l'aperçu se reconstruit sur l'appareil.

| | Android | iOS |
|---|---|---|
| Aujourd'hui | data-only déjà (`send-push/index.ts`, vérifié SM A515F : avec un bloc `notification`, Dart ne s'exécute jamais) ; `onBackgroundMessage` invoqué | `aps.alert` en clair, affiché par le système sans code applicatif |
| Après MLS | isolate background → ouvre la lib Rust → déchiffre → notification locale | **Notification Service Extension à créer** (`ios/` n'a que `Runner` et `RunnerTests`) + lib Rust embarquée + App Group pour la base + Keychain access group pour la clé maître |
| Budget | aperçu affiché < 2 s après le push, **mesuré sur SM A515F** | idem, sur iPhone réel ; l'extension a ~30 s et une mémoire limitée |

**Le piège qui peut rendre une conversation illisible sans un seul journal :
deux processus ne peuvent pas faire avancer le même cliquet.** Déchiffrer
consomme une génération dans l'arbre de secrets. Si l'extension (ou l'isolate
background) déchiffre **et persiste**, puis que l'app déchiffre le même message
depuis un état devenu périmé, les deux états divergent.

Conception, à valider au spike, pas à découvrir en production :

- **un seul écrivain** de l'état MLS : le processus principal de l'app ;
- l'extension / l'isolate ouvre la base en **copie de travail jetable**
  (fichier temporaire ou transaction annulée), déchiffre, écrit seulement un
  **cache d'aperçu** en clair (`{messageId → texte}`) que l'app relit, et ne
  touche pas à l'état qui fait foi ;
- l'app, au réveil, retraite le message et fait foi. Coût : un double
  déchiffrement. La divergence d'état, non ;
- Android : même règle entre isolate background et isolate UI, qui peuvent
  tourner en même temps — verrou de fichier autour de l'écriture.

Côté serveur : le trigger de `mls_messages` écrit un `body` générique dans
`notifications` ; `send-push` n'a rien à savoir de MLS. Le réglage
`show_message_preview = false` (déjà géré) devient simplement « ne pas
déchiffrer localement ».

**Cette phase précède l'ouverture du flag.** Sinon chaque conversation
basculée perd son aperçu en silence, et personne ne saura dire quand ça a
commencé.

---

# 9. Phases, dépendances, preuves

Chaque phase se termine par une **preuve de vie** : une requête SQL sur la
production, ou une case cochée dans `TESTS_APPAREIL_A_FAIRE.md` (domaine
« 4. Chiffrement de bout en bout et clés », « 6. Notifications et push »).
Pas « le code est écrit ».

```text
0 Décider ──► 1 Spike ──► 2 Registre ──► 3 Banc ──► 4 Notifs ──► 5 1:1 (flag) ──► 6 Gel ──► 7 Multi-appareil ──► 8 Groupes ──► 9 PJ ──► 10 Démantèlement
                 │                                                    ▲
0b Signal (option, indépendant)          C4 pièces jointes (repli AES, indépendant) ──┘
```

| Phase | Contenu | Preuve de vie | Ordre de grandeur |
|---|---|---|---|
| **0 — Décider** | Trancher A → H (§ 11), les écrire en tête de ce fichier | ce fichier, committé | quelques jours |
| **0b — Réparer Signal (option, décision D)** | rattrapage au point d'usage dans `encrypt1to1`/`encryptGroup` quand `!isInitialized` ; 1 à 2 jours | `count(*) where data->>'encryptionLevel' = 'e2ee'` > 0 sur deux comptes réels. Ne change rien au plan : le lecteur legacy lit déjà Signal ; le gel l'arrête aussi | 2 jours |
| **1 — Spike jetable** | branche à jeter, aucun code de prod. Cinq questions : la chaîne de build (cargokit, `.so` par ABI, **alignement 16 Ko**, build **signé qui démarre** sur SM A515F) ; le poids de l'APK ; les **ms à froid** dans l'isolate background ; la **NSE iOS** avec App Group et copie de travail ; la jointure externe dans OpenMLS 0.9 | GO/NO-GO écrit, avec des chiffres | 2 semaines |
| **2 — Registre d'appareils** | `devices`, `mls_key_packages`, `claim_key_package`, RLS ; écran « Mes appareils » (réutiliser l'existant), révocation | `select count(*) from devices where last_seen_at > now() - interval '7 days'` > 0 sur des comptes réels | 2–3 semaines |
| **3 — Banc bout en bout, sans écran** — **code livré le 2026-09-15**, exécution en attente de la migration de transport | migration `20260915120000_mls_transport.sql` (`mls_commits` avec `(conversation, epoch)` en clé primaire, `mls_welcomes`, `mls_messages`, `conversation_devices`, `conversations.mls_since` + refus du legacy), validée en transaction annulée ; `MlsDelivery` (transport, aucune crypto), `MlsPayloadCodec` (AAD + payload v1), `MlsConversationService` (créer/rejoindre avec réservation de l'epoch 0, réconciliation des membres avec `claim_key_package` et commit perdant jeté, envoi sans repli, rattrapage commits-puis-messages) ; identité MLS par **installation** (suffixe aléatoire : une réinstallation est un appareil neuf) ; banc `test/banc/mls_banc_test.dart` — trois appareils contre la vraie base, RLS réel, moteur Rust chargé dans `flutter test` — 12 cas dont : reçu deux fois, AAD déplacé, hors ordre, moteur détruit et recréé, epoch passé après commit, réinstallation, commit concurrent, révocation, rattrapage après coupure | le banc passe sur la base de production et **échoue quand on casse un cas exprès** — pas encore exécuté (§ 4 de `TESTS_APPAREIL_A_FAIRE.md` pour le protocole) | 3–4 semaines |
| **4 — Notifications** | § 8 : isolate Android, NSE iOS, écrivain unique, trigger `mls_messages` à `body` générique | SM A515F **et** iPhone, app tuée, push reçu, aperçu réel affiché — deux cases cochées | 3–4 semaines |
| **5 — 1:1 derrière un flag** | `mls_messages`, `mls_commits`, `mls_welcomes`, `mls_message_receipts`, `mls_diagnostics`, `mls_since` ; `MlsConversationService`, `MessageSourceMerger`, séparateur, `protocol` sur `MessageModel` ; flag fermé par défaut (`app-config`, déjà déployée) | `select count(*) from mls_messages` > 0 entre deux comptes réels sur deux appareils réels ; et `mls_diagnostics` vide d'`encrypt_failed` | 4–6 semaines |
| **6 — Gel** (point de non-retour) | délai de mise à jour minimale expiré (B) ; `REVOKE INSERT` ; triggers d'insertion retirés de `messages` ; `decrypt_aes_fallback` hors triggers ; annonce de purge (H) | un `insert` dans `messages` sous `SET LOCAL ROLE authenticated` échoue (sans `SET LOCAL ROLE`, `db query --linked` tourne en `postgres` et le test ment) | 1 semaine |
| **7 — Multi-appareil** | lever « une session par compte » (E) ; ajout d'un second appareil, vérification par QR (`safety_code`), retrait d'un appareil perdu → Remove + commit | deux appareils d'un même compte affichent la même conversation ; un troisième révoqué ne déchiffre plus les suivants | 3–4 semaines |
| **8 — Groupes** | ajout/retrait par membre, jointure externe pour les groupes ouverts, groupe officiel (rafale de 23505 mesurée), chaque chemin d'appartenance suivi d'un commit rattrapable | `select count(*) from mls_messages m join conversations c on c.id = m.conversation_id where c.type = 'group'` > 0 | 5–8 semaines |
| **9 — Pièces jointes** | si C4 fait : déplacer `fileKey` dans le payload, `encrypt_file`/`decrypt_file` Rust en flux (la vidéo demande le mode par morceaux, cf. `CHIFFREMENT_MEDIAS_PLAN.md`) | un média envoyé n'a plus d'URL lisible en base | 2 semaines si C4, 6 sinon |
| **10 — Démantèlement** | après **100 % du trafic en MLS pendant plusieurs semaines** et la purge (H) : `lib/core/services/e2ee/` (8 608 lignes), `e2ee_*` (5 tables), `crypto-keys`, `decrypt_aes_fallback`, `EncryptionService._sharedKeyString`, `encAnnexes` | `select count(*) from messages` = 0 puis `drop table` | 1–2 semaines |

**Total : 6 à 9 mois** pour un développeur seul, à temps partiel. Ordre de
grandeur, pas engagement, et il ne vaut que si 1 → 4 sont faites dans cet
ordre. Le chemin le plus court vers un gain réel reste **C4** : chiffrer les
pièces jointes avec le repli existant — deux semaines, et le transport d'une
clé dans le corps du message est validé pour la suite.

---

# 10. Ce que le chantier Signal enseigne, et les règles de chantier

## Le compteur qui compte vaut 0

`lib/core/services/e2ee/` fait 8 608 lignes : X3DH, Double Ratchet, Sender
Keys, sauvegarde, transfert par QR. L'infrastructure serveur est déployée et
peuplée — 49 appareils, 39 jeux de clés, 4 581 prékeys. **Aucun message n'est
jamais passé par Signal.**

Établi par instrumentation sur appareil (commit `7bb2e78`, motif écrit en
base) : `encrypt1to1` rapporte `e2ee_non_initialise`. `messagingE2EEServiceProvider`
est un `Provider` simple qui **observe** `keyManagerServiceProvider` et
`secureKeyStorageProvider` ; l'invalidation de l'un reconstruit le service,
`_isInitialized` repart à `false`, et personne ne le rejoue —
`E2EEBackupCoordinator.bootstrap` pose son garde **avant** son `try` et sort
aux appels suivants. Le chiffrement n'a pas échoué : **il n'a jamais été
appelé**, et tout marchait, en clair. Aucun test unitaire ne pouvait le voir ;
`debugPrint` ne remonte pas dans logcat en release.

C'est le risque numéro un du chantier MLS : construire, en plus gros et en
Rust, une seconde infrastructure que le chemin réel contournera. D'où les
trois règles du § 7.3 et les preuves de vie du § 9.

## Métadonnées, à accepter consciemment

Le serveur continue de voir qui écrit à qui, quand, depuis quel appareil,
quelle taille, quel type grossier, qui a lu quoi. Pour une application de
diaspora, ce graphe social horodaté est souvent plus sensible que le contenu.
MLS ne le résout pas, ce plan non plus. Ce qui est demandé : **l'écrire**, et
ne pas présenter le résultat comme une confidentialité totale dans l'interface.

## Journaux

~920 appels `debugPrint` écrivent dans logcat en release. **Aucune ligne de
journal ne doit approcher un plaintext, une clé, un paquet ou un état de
groupe.** Un chiffrement de bout en bout qui recopie le message clair dans
logcat ment.

## Règles propres à ce dépôt

- **Worktree obligatoire** ; avant chaque livraison sur `features/messages`,
  `git -C <dépôt-principal> diff -U0 -- <fichier> | grep '^@@'` ; si les zones
  se chevauchent, consigner et attendre. `git merge` passe par PowerShell.
- **Jamais `dart format`.** **`uniq -d`** sur les préfixes de migration après
  chaque merge. **`SET LOCAL ROLE authenticated`** pour tester le RLS.
- **`ensureAuthenticated()`** avant toute lecture ET écriture Supabase — la
  lecture sous `anon` rend 0 ligne sans erreur, c'est ce qui a caché la panne
  des prékeys.
- Une Edge Function ne met **jamais** une colonne récente dans son select
  principal ; déployer la fonction avant d'annoncer la migration.
- **`TESTS_APPAREIL_A_FAIRE.md` au fil de l'eau**, dans le même commit.
- Aucun secret dans le `.env` racine (il part dans l'APK).

---

# 11. Décisions — actées par Salim le 2026-09-14

Toutes les recommandations ci-dessous sont **retenues**, avec une décision
supplémentaire (J) : les fonctionnalités que la v2 mettait « en local
seulement » gardent une **métadonnée en ligne** (§ 4, § 6.3), pour que
réactions, favoris, masquages, mentions et aperçus suivent l'utilisateur d'un
appareil à l'autre et survivent à une réinstallation. Le contenu reste dans
MLS ; ce qui est en ligne dit *qui, quoi, quand* — jamais le texte.

Ordre de départ : **spike (phase 1) et C4 en parallèle**, comme en I.

| # | Question | Décision |
|---|---|---|
| **A** | Messages existants : gel + coexistence, purge, ou ré-encapsulation ? | **Gel + coexistence.** Ré-encapsulation écartée pour de bon |
| **B** | Mise à jour minimale imposée avant le gel ? | **Oui**, via `CoordinateurMiseAJour` existant ; le gel ne précède pas l'expiration du délai |
| **C1–C4** | Monorepo, SQLite Dart, appels, pièces jointes dans MLS ? | **Non, non, hors périmètre, avant MLS** |
| **D** | Réparer l'initialisation Signal en attendant (2 jours) ? | **Oui** : c'est peu cher, ça prouve la chaîne de mesure, et ça ne change rien au plan. Pas un substitut |
| **E** | Lever la règle « une seule session par compte » ? | **Oui, en phase 7** — sans elle, le multi-appareil MLS est fictif. À motiver côté produit (elle protège peut-être contre le partage de compte) |
| **F** | Métadonnées acceptées : `content_type` grossier, reçus serveur, frappe en clair ? | **Oui** pour une première version ; les écrire dans l'aide de l'app |
| **G** | Aperçu de la liste des discussions depuis le cache local seulement (« Nouveau message » sinon) ? | **Oui** ; c'est le compromis fondamental de l'E2EE |
| **H** | Purge du legacy 90 jours après le gel, puis extinction de `crypto-keys` et de la clé globale ? | **Oui**, annoncée dans l'app. Sans purge, trois clés restent load-bearing pour toujours |
| **I** | Commencer par C4 (pièces jointes) ou par le spike ? | **Les deux en parallèle** : C4 ne dépend de rien, le spike ne touche pas la prod |
| **J** | Réactions, modification, suppressions, reçus, non-lus, mentions, aperçu, favoris, réponses : local seulement, ou métadonnée en ligne aussi ? | **En ligne aussi** (tables `mls_message_*`, colonnes `last_message_*`, vue `mls_unread_counts`). Coût accepté : le serveur voit qui réagit, lit, masque, étoile, est mentionné — pas le contenu |

---

# 12. Journal du spike (phase 1) — 2026-09-14, premier jour

Branche jetable `claude/spike-mls` (poussée telle quelle, **pas** sur la
branche partagée), crate `rust/`. Ce qui est établi, avec des chiffres ; ce
qui reste à établir, avec ce qu'il faut pour le faire.

## Établi

| Question du spike | Résultat |
|---|---|
| OpenMLS 0.9 tient-il le parcours complet sur SQLite ? | **Oui.** Façade `MlsEngine` (identité par appareil, KeyPackages, création, ajout, retrait, Welcome, jointure externe, chiffrement avec AAD, traitement entrant) sur `openmls_sqlite_storage 0.3` + `RustCrypto`. Banc de **8 cas, 8 passent** : nominal 1:1, AAD déplacé refusé, rejeu refusé, message d'un epoch passé encore lisible (`max_past_epochs = 3`), membre retiré aveugle, **moteur fermé et rouvert** sur la même base, jointure externe par GroupInfo, commit perdant jeté proprement (`clear_pending_commit` puis traitement du gagnant) |
| Chaîne de build Android | **Oui.** rustc 1.98.1, cargo-ndk 4.1.2, NDK 27.0.12077973, `rusqlite` en `bundled`. `.so` release (opt-level z, LTO, strip) : **arm64-v8a 4,2 Mo, armeabi-v7a 3,1 Mo**. **Alignement 16 Ko vérifié** par `tools/verifie_alignement_16k.py`, sans drapeau de lien supplémentaire |
| Poids | ≈ 4 Mo par ABI, donc ≈ 4 Mo de plus sur un APK découpé par ABI, ≈ 7 Mo sur un APK universel — avant FRB, dont la couche générée ajoute peu. Le poids de l'APK actuel n'a pas été relevé dans cette session |
| Ordre de grandeur à froid | Sur le poste : ouverture de la base **7,5 ms**, ouverture + déchiffrement **18 ms**. Ce n'est pas l'appareil ; deux symboles C (`diaspo_mls_spike_parcours`, `diaspo_mls_spike_reouverture`) sont exportés pour le mesurer sur SM A515F |

Versions figées dans `Cargo.lock` : openmls 0.9.0, openmls_traits 0.6.0,
openmls_rust_crypto 0.6.0, openmls_basic_credential 0.6.0,
openmls_sqlite_storage 0.3.0, rusqlite 0.37.0.

## Trois pièges d'API, à reporter dans le moteur de production

1. **L'AAD est remis à vide après chaque `MlsMessageOut`.** Un commit produit
   par `add_members` juste après un `create_message` part donc avec un AAD
   vide, pas celui du message. Le moteur doit poser un AAD **de commit**
   explicite (`dn-mls/1|conv|commit|epoch`) avant chaque commit, et le
   récepteur le recomposer depuis `mls_commits`. Sans ça, § 6.1 ne tient
   pas pour les commits.
2. `MlsMessageIn::into_verifiable_group_info()` n'existe qu'en `test-utils` :
   passer par `extract()` et la variante `MlsMessageBodyIn::GroupInfo`.
3. `openmls_sqlite_storage` ne réexporte pas `refinery` : l'erreur de
   migration se convertit en code, pas en type.

Et une décision de configuration : `MIXED_CIPHERTEXT_WIRE_FORMAT_POLICY`
(sortant chiffré, entrant mixte), parce qu'un commit externe arrive
forcément en clair. `PURE_CIPHERTEXT` le refuserait sans dire pourquoi.

## Deuxième jour (2026-09-15) — Flutter Rust Bridge intégré, APK signé produit

| Question du spike | Résultat |
|---|---|
| FRB 2.13 sur ce projet | **Oui.** `integrate` (cargokit, sans `dart fix` ni `dart format`) + crate conservé + surface `api/mls.rs` : `Moteur` opaque (`#[frb(opaque)]`, le verrou de FRB sérialise les méthodes `&mut self` — la règle « un seul écrivain »), DTO plats, erreurs en codes. Bindings générés dans `lib/src/rust/`, `cargo check` et `flutter analyze` propres |
| Build release **signé** | **Oui.** `flutter build apk --release --dart-define=SPIKE_MLS=true` : 519 s de Gradle, cargokit compile le crate pour arm64-v8a, armeabi-v7a et x86_64 ; APK universel de **131,6 Mo**, signé V2 avec le certificat de production (CN=Diaspo Niger) |
| Lib dans l'APK | `libdiaspo_mls.so` : **4,4 Mo (arm64), 3,3 Mo (armv7), 5,1 Mo (x86_64)** ; les deux 64 bits **alignées 16 Ko** (vérifié dans l'APK, pas seulement dans `target/`) |
| Démarre sur l'appareil, ms à froid | **Oui, mesuré sur SM A515F (release, 2026-09-15 00:28).** Le harnais `lib/spike_mls/spike_app.dart` (activé par le `dart-define`) joue le parcours et affiche les chiffres à l'écran, lus par `adb exec-out screencap` : ouverture de deux moteurs neufs **206 ms** ; création + ajout + Welcome **137 ms** ; chiffrer + déchiffrer **5 ms** ; **réouverture à froid 6 ms, réouverture + déchiffrement 15 ms** (le chemin « notification en arrière-plan », budget 2 s : tenu avec deux ordres de grandeur de marge) ; AAD déplacé **refusé** (`aad_mismatch`) ; base SQLite de Bob 147 Ko après un parcours |

Installé **à côté** de l'app, sous `com.diasponiger.diasponiger.spike` (plugins
google-services et crashlytics commentés sur la branche du spike) : l'app en
place sur ce téléphone est signée avec une autre clé que celle du dépôt, et la
remplacer aurait coûté ses clés Signal locales. `adb uninstall
com.diasponiger.diasponiger.spike` pour le retirer.

Deux pièges d'outillage, payés :

- **`flutter_rust_bridge_codegen generate` lance `build_runner`** dès qu'un
  enum à données (freezed) est exposé. Ici il a **supprimé 129 `.g.dart`
  suivis par git** dans l'arbre de travail, et le premier build a cassé
  dessus. Restaurer par `git ls-files -d | xargs git checkout --`, puis
  passer `--no-build-runner` (et toujours `--no-dart-format`).
- `--no-write-lib` évite le `lib/main.dart` d'exemple mais ne crée alors
  **ni crate, ni `flutter_rust_bridge.yaml`** : les écrire soi-même.

## Reste à établir

| Question | Ce qu'il faut |
|---|---|
| ms à froid **dans l'isolate background** (pas seulement au premier plan) | un `onBackgroundMessage` jetable qui ouvre le moteur : même code, autre isolate — 15 ms au premier plan laissent 130× de marge sur le budget, le risque est ailleurs (réveil du processus, pas la crypto) |
| **NSE iOS** avec App Group et copie de travail | un Mac. Rien de ce spike ne l'aborde |

**Verdict : GO côté Rust, Android, chaîne de build et appareil.** Reste iOS.
Aucun NO-GO rencontré. Le spike Android peut être considéré comme clos ; la
phase 2 (registre d'appareils) peut commencer.
