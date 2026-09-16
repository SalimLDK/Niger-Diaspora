-- `messages` : un participant ne réécrit plus le message d'un autre.
--
-- Constaté en production le 2026-09-16 (projet `zyrfkcjjrhddpfxcgezo`), et
-- reproduit avant d'écrire une ligne : en rôle `authenticated`, avec le
-- `firebase_uid` d'un simple participant d'une conversation de 24 membres, un
-- `UPDATE messages SET data = jsonb_set(data,'{content}', …)` sur le message de
-- QUELQU'UN D'AUTRE a été accepté, et la relecture rendait le texte réécrit.
-- La policy `messages_update` (20260715120000) a deux branches :
--
--   (SELECT firebase_uid()) = sender_id          -- l'expéditeur
--   OR EXISTS (… c.participant_ids @> ARRAY[…])  -- N'IMPORTE QUEL participant
--
-- La seconde couvre toutes les lignes de la conversation. Et la RLS ne peut
-- rien y faire : elle filtre des LIGNES, jamais des colonnes ni des verbes.
--
-- ---------------------------------------------------------------------------
-- POURQUOI LA RECETTE DE `notifications` NE SE TRANSPOSE PAS ICI
-- ---------------------------------------------------------------------------
-- `notifications` s'est réglé la veille (20260916180000) au `GRANT UPDATE
-- (is_read, read_at)` : une colonne par usage, et le privilège de colonne fait
-- le tri. `messages` n'a pas cette forme. La table a SEPT colonnes —
-- `id, conversation_id, sender_id, type, is_deleted, created_at, data` — et
-- tout ce qui bouge après l'envoi vit dans une seule, `data` (jsonb) :
--
--   à l'expéditeur seul     content, editedAt, editHistory, e2eePayloads,
--                           senderKeyPayload, fileUrl, thumbnailUrl, …
--   aux autres participants readBy, readAt, deliveredTo, deliveredAt,
--                           reactions, starredBy, deletedFor, reportedBy
--
-- Un `GRANT UPDATE (data)` rend donc exactement le droit qu'on cherche à
-- retirer : le privilège de colonne ne descend pas dans un jsonb. Et un
-- `WITH CHECK` de policy ne peut pas non plus trancher, faute de voir l'ANCIENNE
-- ligne — seul un déclencheur voit OLD et NEW à la fois.
--
-- D'où trois pièces, complémentaires et aucune suffisante seule :
--
--   1. Les droits de table, pour ce que la colonne SAIT protéger : plus
--      personne ne réécrit `sender_id`, `conversation_id`, `type` ni
--      `created_at`. C'est la vraie fuite que le grain de colonne attrape, et
--      elle n'était pas dans le signalement : la policy n'ayant pas de
--      `WITH CHECK`, Postgres réutilise le `USING` — un participant pouvait
--      donc changer le `sender_id` d'un message, c'est-à-dire en attribuer un
--      à quelqu'un qui ne l'a jamais écrit.
--   2. Le déclencheur, pour ce qu'elle ne sait pas : le grain des clés de
--      `data`.
--   3. La policy, laissée telle quelle. Sa seconde branche RESTE nécessaire —
--      `starredBy`, `deletedFor` et `reportedBy` s'écrivent en direct par
--      PostgREST, et sans elle la ligne serait invisible à l'UPDATE.
--
-- ---------------------------------------------------------------------------
-- CE QUI NE PASSE PAS PAR LÀ, ET NE CASSE DONC PAS
-- ---------------------------------------------------------------------------
-- Relevé dans `message_supabase_datasource.dart` avant d'écrire, pas deviné.
-- Les accusés et les réactions ne touchent PAS la table en direct : ils passent
-- par des fonctions `SECURITY DEFINER` qui vérifient elles-mêmes la
-- participation (`mark_messages_as_read`, `mark_messages_as_delivered`,
-- `set_message_reaction`). Une fonction `SECURITY DEFINER` s'exécute sous son
-- propriétaire — `current_user` y vaut `postgres`, pas `authenticated` : ni le
-- REVOKE ni le déclencheur ne les concernent. Le « Lu » n'a rien à craindre
-- d'ici.
--
-- Les épingles sont dans `group_pinned_items`, une autre table. Vérifié aussi.
--
-- `mls_messages` n'est pas concernée : c'est une autre table, avec ses propres
-- colonnes et ses propres droits.
--
-- UN EFFET DE BORD ASSUMÉ. Côté client, `_mergeMsgData` relit `data`, change
-- une clé, et réécrit le blob ENTIER. Si l'expéditeur modifie son texte entre
-- la relecture et la réécriture, le blob réexpédié porte l'ANCIEN `content` :
-- le garde le voit et refuse (42501), là où avant l'écriture passait et
-- annulait silencieusement la modification de l'expéditeur. Un favori ou un
-- signalement peut donc désormais échouer visiblement, dans une fenêtre de
-- quelques millisecondes. C'est le bon sens de l'échange : une erreur qu'on
-- voit vaut mieux qu'une perte de donnée qu'on ne voit pas.
--
-- ---------------------------------------------------------------------------
-- 1. Les droits.
-- ---------------------------------------------------------------------------
-- REVOKE d'abord : Supabase pose `ALTER DEFAULT PRIVILEGES … GRANT ALL ON
-- TABLES TO anon, authenticated`, donc un GRANT seul n'enlève rien. Relevé en
-- production : les deux rôles avaient bien les sept verbes.
--
-- Périmètre volontairement tenu à UPDATE : SELECT/INSERT/DELETE portent la
-- messagerie et ne sont pas en cause ici. `TRUNCATE`, accordé par le même
-- défaut et que la RLS n'arrête pas, reste ouvert sur cette table comme sur
-- ~100 autres — c'est une passe à part, pas un effet de bord de celle-ci.
REVOKE UPDATE ON TABLE public.messages FROM anon;
REVOKE UPDATE ON TABLE public.messages FROM authenticated;

-- `anon` ne récupère rien : les trois policies comparent à `firebase_uid()`,
-- nul pour lui. Il n'écrivait déjà aucune ligne — le droit était nominal.

-- Les deux seules colonnes que le client modifie après l'envoi. `is_deleted`
-- sert à « supprimer pour tout le monde ».
GRANT UPDATE (data, is_deleted) ON TABLE public.messages TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Le déclencheur : le grain des clés de `data`.
-- ---------------------------------------------------------------------------
-- Qui peut modérer cette conversation. `SECURITY DEFINER` parce que le garde,
-- lui, ne l'est pas (voir plus bas) : sans ça la lecture de `conversations`
-- repasserait par la RLS, et un refus de lecture se lirait « pas admin ».
CREATE OR REPLACE FUNCTION public.est_admin_conversation(p_conversation_id text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid        text := public.firebase_uid();
  v_conv       record;
  v_group_uuid uuid;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RETURN false;
  END IF;

  SELECT c.group_id,
         c.created_by,
         COALESCE(c.data->'adminIds', '[]'::jsonb) AS admin_ids
    INTO v_conv
    FROM conversations c
   WHERE c.id = p_conversation_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Conversations sans groupe (1:1, héritées) : l'instantané figé à la
  -- création, qui est tout ce qu'elles ont.
  IF v_conv.created_by = v_uid OR v_conv.admin_ids ? v_uid THEN
    RETURN true;
  END IF;

  -- `group_id` peut être un identifiant hérité de Firestore (non-UUID) : cast
  -- protégé, une valeur non-UUID retombe sur « pas de groupe Supabase
  -- associé » plutôt que de faire échouer le garde. Même précaution que
  -- `conversations_guard_admin_fields`.
  BEGIN
    v_group_uuid := NULLIF(v_conv.group_id, '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN false;
  END;

  -- Pour un groupe, `group_members.role` fait foi — pas `data->'adminIds'`,
  -- qui n'est jamais mis à jour lors d'une promotion. C'est aussi la source
  -- que l'écran de discussion interroge pour afficher l'entrée de menu.
  RETURN v_group_uuid IS NOT NULL AND public.is_group_admin(v_group_uuid);
END;
$$;

-- `SECURITY INVOKER` — c'est-à-dire le défaut, et ici c'est le fond du sujet.
-- Sous `SECURITY DEFINER`, `current_user` vaut déjà le PROPRIÉTAIRE dès la
-- première ligne du corps : le test d'exemption ci-dessous serait toujours
-- vrai et le garde ne refuserait jamais rien. Essayé, et le banc l'a dit —
-- les quatre cas d'abus passaient encore. En invoker, `current_user` est le
-- rôle réel de l'appelant : `authenticated` quand l'ordre vient de PostgREST,
-- `postgres` quand il vient d'une fonction `SECURITY DEFINER` (les RPC
-- d'accusés). C'est exactement la ligne de partage qu'on cherche.
CREATE OR REPLACE FUNCTION public.messages_garde_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid          text;
  -- Les seules clés de `data` qu'un NON-expéditeur peut faire bouger. Tirées
  -- une à une des écritures réelles de l'app, pas d'une intuition :
  --   readBy/readAt, deliveredTo/deliveredAt  mark_messages_as_{read,delivered}
  --   reactions                                set_message_reaction, et le repli
  --                                            direct `_setReactionLegacy`
  --   starredBy                                toggleStarMessage
  --   deletedFor                               deleteMessageForMe
  --   reportedBy                               reportMessage
  v_cles_autrui  constant text[] := ARRAY[
    'readBy', 'readAt', 'deliveredTo', 'deliveredAt',
    'reactions', 'starredBy', 'deletedFor', 'reportedBy'
  ];
BEGIN
  -- Chemins de confiance : `postgres` (migrations, déclencheurs, et toute
  -- fonction SECURITY DEFINER — dont les trois RPC d'accusés et de réactions)
  -- et `service_role` (Edge Functions). Seul ce qui arrive par PostgREST sous
  -- l'identité d'un utilisateur est filtré ici.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  v_uid := public.firebase_uid();

  -- L'expéditeur garde la main pleine sur son message : c'est « Modifier le
  -- message » (refait le 2026-09-16) et « supprimer pour tout le monde ».
  IF v_uid IS NOT NULL AND v_uid = OLD.sender_id THEN
    RETURN NEW;
  END IF;

  -- À partir d'ici : quelqu'un d'autre que l'expéditeur.

  -- L'identité et le rattachement du message sont figés. Le REVOKE ci-dessus
  -- le dit déjà au grain de la colonne ; on le redit ici pour que la règle
  -- tienne même si un GRANT plus large revenait un jour.
  IF NEW.id              IS DISTINCT FROM OLD.id
     OR NEW.sender_id       IS DISTINCT FROM OLD.sender_id
     OR NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
     OR NEW.type            IS DISTINCT FROM OLD.type
     OR NEW.created_at      IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'messages: seul l''expéditeur peut modifier l''identité de son message'
      USING ERRCODE = '42501';
  END IF;

  -- Modération : un administrateur du groupe peut supprimer le message d'un
  -- membre pour tout le monde. C'est une porte offerte par l'interface
  -- (`DeleteMessageModal`, `isAdmin ||`), donc elle doit rester ouverte — mais
  -- bornée à une SUPPRESSION, pas à une réécriture : on exige le drapeau posé
  -- et le contenu vidé. Un admin ne peut pas mettre ses mots dans la bouche
  -- d'un membre.
  --
  -- `NOT OLD.is_deleted` n'est pas cosmétique : sans lui, la porte reste
  -- ouverte pour toujours une fois le message supprimé. Le banc l'a montré —
  -- un message déjà supprimé a un `content` vide, donc la condition
  -- « contenu vidé » était vraie à chaque UPDATE suivant, et un admin
  -- retrouvait la main libre sur `data`. Exigé ici : la TRANSITION, c'est-à-
  -- dire le geste de suppression lui-même, une fois.
  IF NEW.is_deleted
     AND NOT OLD.is_deleted
     AND COALESCE(NEW.data->>'deletedForEveryone', 'false') = 'true'
     AND COALESCE(NEW.data->>'content', '') = ''
     AND public.est_admin_conversation(OLD.conversation_id)
  THEN
    RETURN NEW;
  END IF;

  -- Le cas courant : `is_deleted` ne bouge pas, et `data` ne bouge que sur les
  -- clés destinées aux autres participants. `jsonb - text[]` retire les clés :
  -- ce qui reste de part et d'autre doit être identique, à l'ajout comme au
  -- retrait comme à la modification.
  IF NEW.is_deleted IS DISTINCT FROM OLD.is_deleted THEN
    RAISE EXCEPTION 'messages: seul l''expéditeur ou un administrateur du groupe peut supprimer ce message'
      USING ERRCODE = '42501';
  END IF;

  IF (COALESCE(NEW.data, '{}'::jsonb) - v_cles_autrui)
     IS DISTINCT FROM
     (COALESCE(OLD.data, '{}'::jsonb) - v_cles_autrui)
  THEN
    RAISE EXCEPTION 'messages: un participant ne peut pas modifier le contenu du message d''un autre'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.messages_garde_update() IS
  'Borne ce qu''un non-expéditeur peut changer dans `messages`. Nécessaire '
  'parce que tout vit dans la colonne `data` (jsonb) : ni le privilège de '
  'colonne ni la RLS ne savent y descendre.';

-- `est_admin_conversation` doit vivre dans `public` : le garde est INVOKER,
-- donc son corps s'exécute en `authenticated`, qui n'a pas `USAGE` sur le
-- schéma `private` (vérifié) et ne saurait pas résoudre le nom. Elle devient
-- de ce fait une RPC PostgREST — d'où les droits au plus juste. Elle ne dit
-- rien de plus que « suis-je admin de cette conversation », sur une
-- conversation que l'appelant voit déjà.
REVOKE EXECUTE ON FUNCTION public.est_admin_conversation(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.est_admin_conversation(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.est_admin_conversation(text) TO authenticated;

DROP TRIGGER IF EXISTS messages_garde_update_trg ON public.messages;
CREATE TRIGGER messages_garde_update_trg
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_garde_update();
