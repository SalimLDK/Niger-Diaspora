-- Métadonnées en ligne des messages MLS (plan MLS, décision J, § 4).
--
-- POURQUOI DES TABLES PLUTÔT QUE « TOUT DANS LE CHIFFRÉ »
-- Neuf fonctionnalités de la messagerie ne sont pas des messages : réactions,
-- modification, suppression pour tous, suppression pour moi, reçus livré et
-- lu, compteurs de non-lus, mentions non lues, aperçu de la liste des
-- discussions, favoris. Le legacy les stockait dans `messages.data` en clair.
-- MLS chiffre le CONTENU (quel emoji, quel nouveau texte) et le fait voyager
-- en message de contrôle ; ce qui suit garde la MÉTADONNÉE — qui, quand — en
-- ligne, parce qu'un second appareil, une réinstallation et un compteur de
-- non-lus ne peuvent pas la reconstituer autrement.
--
-- CE QUE LE SERVEUR APPREND, ET QUI A ÉTÉ ACCEPTÉ (décision J)
-- Qui a réagi à quoi et avec quel emoji, qui a lu quoi et quand, qui a masqué
-- ou étoilé quoi, qui est mentionné. Jamais le contenu d'un message. La
-- colonne `emoji` est le seul fragment de contenu qui reste en clair : sans
-- elle, un appareil réinstallé ne pourrait pas reconstituer les réactions,
-- n'ayant rejoué aucun contrôle. C'est le prix du multi-appareil, et il a été
-- accepté explicitement.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS, ET POURQUOI
-- Elle n'écrit NI `data.unreadCount` NI `data.unreadMentions`. Ces deux
-- cartes sont incrémentées par le legacy et décrémentées par
-- `mark_messages_as_read`, qui ne connaît que `messages`. Les alimenter
-- depuis `mls_messages` donnerait un compteur qui ne sait que monter — la
-- vue `mls_unread_counts` en bas de fichier est la seule source pour MLS
-- (« Réglages : une seule source », CLAUDE.md). Le branchement Dart de cette
-- vue reste à faire ; d'ici là, une conversation basculée n'affiche pas de
-- pastille de non-lus.

-- ── Deux gardes, pour ne pas récrire la même sous-requête dix fois ─────────
-- Les cinq tables portent un `message_id`, pas un `conversation_id` : le
-- « participant » du plan doit passer par `mls_messages`. En SECURITY
-- DEFINER, la résolution ignore le RLS de `mls_messages` — sinon chaque
-- politique en déclencherait une autre, sur la même condition.

CREATE OR REPLACE FUNCTION public.mls_message_participant(p_message_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM mls_messages m
      JOIN conversations c ON c.id = m.conversation_id
     WHERE m.id = p_message_id
       AND public.firebase_uid() = ANY (c.participant_ids)
  );
$function$;

REVOKE ALL ON FUNCTION public.mls_message_participant(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mls_message_participant(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.mls_message_expediteur(p_message_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM mls_messages m
     WHERE m.id = p_message_id
       AND m.sender_id = public.firebase_uid()
  );
$function$;

REVOKE ALL ON FUNCTION public.mls_message_expediteur(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mls_message_expediteur(uuid) TO authenticated;

-- ── Reçus : livré et lu ────────────────────────────────────────────────────
-- `user_id` est un `text` sans clé étrangère, comme `mls_messages.sender_id` :
-- les identités viennent encore de Firebase et ne sont pas toutes des uuid.

CREATE TABLE IF NOT EXISTS public.mls_message_receipts (
  message_id   uuid NOT NULL REFERENCES public.mls_messages (id) ON DELETE CASCADE,
  user_id      text NOT NULL,
  delivered_at timestamptz,
  read_at      timestamptz,
  PRIMARY KEY (message_id, user_id)
);

-- Les compteurs ne cherchent que les non-lus : l'index partiel rétrécit avec
-- la lecture au lieu de grandir avec l'historique.
CREATE INDEX IF NOT EXISTS mls_message_receipts_non_lus_idx
  ON public.mls_message_receipts (user_id)
  WHERE read_at IS NULL;

ALTER TABLE public.mls_message_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_message_receipts: participants" ON public.mls_message_receipts;
CREATE POLICY "mls_message_receipts: participants" ON public.mls_message_receipts
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.mls_message_participant(message_id));

DROP POLICY IF EXISTS "mls_message_receipts: les siens" ON public.mls_message_receipts;
CREATE POLICY "mls_message_receipts: les siens" ON public.mls_message_receipts
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT firebase_uid())
    AND public.mls_message_participant(message_id)
  );

DROP POLICY IF EXISTS "mls_message_receipts: avancer les siens" ON public.mls_message_receipts;
CREATE POLICY "mls_message_receipts: avancer les siens" ON public.mls_message_receipts
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (user_id = (SELECT firebase_uid()))
  WITH CHECK (user_id = (SELECT firebase_uid()));

REVOKE ALL ON public.mls_message_receipts FROM anon;
-- Pas de DELETE : un reçu ne se retire pas, il n'existe qu'une fois posé.
GRANT SELECT, INSERT, UPDATE ON public.mls_message_receipts TO authenticated;

-- ── Réactions ──────────────────────────────────────────────────────────────
-- Une par personne et par message, comme aujourd'hui. Le contrôle MLS porte
-- l'emoji chiffré et ordonné avec les messages ; cette ligne sert au second
-- appareil et à la réinstallation, qui n'ont pas rejoué les contrôles.

CREATE TABLE IF NOT EXISTS public.mls_message_reactions (
  message_id uuid NOT NULL REFERENCES public.mls_messages (id) ON DELETE CASCADE,
  user_id    text NOT NULL,
  emoji      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

ALTER TABLE public.mls_message_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_message_reactions: participants" ON public.mls_message_reactions;
CREATE POLICY "mls_message_reactions: participants" ON public.mls_message_reactions
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.mls_message_participant(message_id));

DROP POLICY IF EXISTS "mls_message_reactions: reagir soi-meme" ON public.mls_message_reactions;
CREATE POLICY "mls_message_reactions: reagir soi-meme" ON public.mls_message_reactions
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT firebase_uid())
    AND public.mls_message_participant(message_id)
  );

DROP POLICY IF EXISTS "mls_message_reactions: changer la sienne" ON public.mls_message_reactions;
CREATE POLICY "mls_message_reactions: changer la sienne" ON public.mls_message_reactions
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (user_id = (SELECT firebase_uid()))
  WITH CHECK (user_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_message_reactions: retirer la sienne" ON public.mls_message_reactions;
CREATE POLICY "mls_message_reactions: retirer la sienne" ON public.mls_message_reactions
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (user_id = (SELECT firebase_uid()));

REVOKE ALL ON public.mls_message_reactions FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mls_message_reactions TO authenticated;

-- ── « Supprimer pour moi » ─────────────────────────────────────────────────
-- Personne d'autre n'a à savoir ce que je masque : la lecture est réservée à
-- son auteur, contrairement aux reçus et aux réactions.

CREATE TABLE IF NOT EXISTS public.mls_message_hidden (
  message_id uuid NOT NULL REFERENCES public.mls_messages (id) ON DELETE CASCADE,
  user_id    text NOT NULL,
  hidden_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS mls_message_hidden_user_idx
  ON public.mls_message_hidden (user_id);

ALTER TABLE public.mls_message_hidden ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_message_hidden: les siens" ON public.mls_message_hidden;
CREATE POLICY "mls_message_hidden: les siens" ON public.mls_message_hidden
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (user_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_message_hidden: masquer pour soi" ON public.mls_message_hidden;
CREATE POLICY "mls_message_hidden: masquer pour soi" ON public.mls_message_hidden
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT firebase_uid())
    AND public.mls_message_participant(message_id)
  );

DROP POLICY IF EXISTS "mls_message_hidden: demasquer pour soi" ON public.mls_message_hidden;
CREATE POLICY "mls_message_hidden: demasquer pour soi" ON public.mls_message_hidden
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (user_id = (SELECT firebase_uid()));

REVOKE ALL ON public.mls_message_hidden FROM anon;
GRANT SELECT, INSERT, DELETE ON public.mls_message_hidden TO authenticated;

-- ── Favoris ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.mls_message_stars (
  message_id uuid NOT NULL REFERENCES public.mls_messages (id) ON DELETE CASCADE,
  user_id    text NOT NULL,
  starred_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- L'écran des favoris les liste du plus récent au plus ancien.
CREATE INDEX IF NOT EXISTS mls_message_stars_user_idx
  ON public.mls_message_stars (user_id, starred_at DESC);

ALTER TABLE public.mls_message_stars ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_message_stars: les siens" ON public.mls_message_stars;
CREATE POLICY "mls_message_stars: les siens" ON public.mls_message_stars
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (user_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_message_stars: etoiler pour soi" ON public.mls_message_stars;
CREATE POLICY "mls_message_stars: etoiler pour soi" ON public.mls_message_stars
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT firebase_uid())
    AND public.mls_message_participant(message_id)
  );

DROP POLICY IF EXISTS "mls_message_stars: retirer pour soi" ON public.mls_message_stars;
CREATE POLICY "mls_message_stars: retirer pour soi" ON public.mls_message_stars
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (user_id = (SELECT firebase_uid()));

REVOKE ALL ON public.mls_message_stars FROM anon;
GRANT SELECT, INSERT, DELETE ON public.mls_message_stars TO authenticated;

-- ── Mentions ───────────────────────────────────────────────────────────────
-- Écrites par l'expéditeur au moment de l'envoi, lues par le compteur
-- « mentions non lues ». Le serveur apprend donc qui est mentionné : accepté
-- (décision J), c'est le seul moyen de faire sonner une mention dans un
-- groupe muet sans déchiffrer côté serveur.

CREATE TABLE IF NOT EXISTS public.mls_message_mentions (
  message_id uuid NOT NULL REFERENCES public.mls_messages (id) ON DELETE CASCADE,
  user_id    text NOT NULL,
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS mls_message_mentions_user_idx
  ON public.mls_message_mentions (user_id);

ALTER TABLE public.mls_message_mentions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_message_mentions: participants" ON public.mls_message_mentions;
CREATE POLICY "mls_message_mentions: participants" ON public.mls_message_mentions
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.mls_message_participant(message_id));

DROP POLICY IF EXISTS "mls_message_mentions: posees par l'expediteur" ON public.mls_message_mentions;
CREATE POLICY "mls_message_mentions: posees par l'expediteur" ON public.mls_message_mentions
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (public.mls_message_expediteur(message_id));

DROP POLICY IF EXISTS "mls_message_mentions: retirees par l'expediteur" ON public.mls_message_mentions;
CREATE POLICY "mls_message_mentions: retirees par l'expediteur" ON public.mls_message_mentions
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (public.mls_message_expediteur(message_id));

REVOKE ALL ON public.mls_message_mentions FROM anon;
GRANT SELECT, INSERT, DELETE ON public.mls_message_mentions TO authenticated;

-- ── Aperçu de la liste des discussions ─────────────────────────────────────
-- Des métadonnées, jamais le texte (décision G). Le libellé affiché vient du
-- cache local déchiffré ; à défaut, l'UI le dérive du type.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS last_message_id        uuid,
  ADD COLUMN IF NOT EXISTS last_message_kind      text,
  ADD COLUMN IF NOT EXISTS last_message_sender_id text;

CREATE OR REPLACE FUNCTION public.mls_messages_apercu_conversation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  -- Un contrôle (réaction, édition, suppression) ne remonte pas la
  -- conversation dans la liste : seul un message de contenu le fait.
  IF NEW.kind <> 'content' THEN
    RETURN NEW;
  END IF;

  UPDATE conversations c
     SET last_message_at        = NEW.created_at,
         last_message_id        = NEW.id,
         last_message_kind      = NEW.content_type,
         last_message_sender_id = NEW.sender_id,
         updated_at             = now(),
         -- `lastMessage` est RETIRÉ, pas laissé : sans ça, une conversation
         -- qui bascule garderait pour toujours l'aperçu en clair de son
         -- dernier message legacy, figé sous des messages chiffrés récents.
         data = (COALESCE(c.data, '{}'::jsonb) - 'lastMessage')
                || jsonb_build_object(
                     'lastMessageSenderId', NEW.sender_id,
                     -- `content_type` est grossier par conception : le
                     -- serveur ne distingue pas une photo d'une vidéo ni
                     -- d'un document. `file` (« 📎 Document ») est le libellé
                     -- neutre ; écrire `media` tel quel tomberait en silence
                     -- sur `MessageType.text` dans le parseur Dart, et une
                     -- photo s'afficherait comme un message vide.
                     'lastMessageType', CASE NEW.content_type
                                          WHEN 'media'    THEN 'file'
                                          WHEN 'voice'    THEN 'voiceNote'
                                          WHEN 'location' THEN 'location'
                                          WHEN 'poll'     THEN 'poll'
                                          WHEN 'sticker'  THEN 'sticker'
                                          WHEN 'system'   THEN 'system'
                                          ELSE 'text'
                                        END,
                     -- Remise à zéro des reçus de l'aperçu : personne n'a
                     -- encore vu CE message. Sans elle, les deux coches
                     -- bleues du message précédent resteraient affichées.
                     'lastMessageStatus', 'sent',
                     'lastMessageReadBy', jsonb_build_array(NEW.sender_id),
                     'lastMessageDeliveredTo', jsonb_build_array(NEW.sender_id)
                   )
   WHERE c.id = NEW.conversation_id;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS mls_messages_apercu_conversation_trg ON public.mls_messages;
CREATE TRIGGER mls_messages_apercu_conversation_trg
  AFTER INSERT ON public.mls_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.mls_messages_apercu_conversation();

-- ── Non-lus et mentions non lues : calculés, jamais stockés ────────────────
-- La vue ne rend QUE les lignes de l'appelant. Le plan la voulait par
-- participant, filtrée par le RLS ; mais `unnest(participant_ids)` n'est pas
-- une table et aucun RLS ne s'y applique — chacun aurait lu le compteur de
-- non-lus des autres. `firebase_uid()` à la place de l'unnest ferme ça et
-- supprime au passage un produit cartésien par la taille du groupe.
--
-- `firebase_uid()` est nul pour `service_role` (aucune revendication JWT) :
-- la vue est vide côté serveur, et c'est voulu — rien côté serveur n'a
-- besoin de ces compteurs.

CREATE OR REPLACE VIEW public.mls_unread_counts
WITH (security_invoker = on) AS
SELECT m.conversation_id,
       moi.user_id,
       count(*) FILTER (WHERE r.read_at IS NULL)                             AS unread,
       count(*) FILTER (WHERE r.read_at IS NULL AND mn.user_id IS NOT NULL)  AS unread_mentions
  FROM public.mls_messages m
  JOIN public.conversations c ON c.id = m.conversation_id
  CROSS JOIN LATERAL (SELECT public.firebase_uid() AS user_id) moi
  LEFT JOIN public.mls_message_receipts r  ON r.message_id  = m.id AND r.user_id  = moi.user_id
  LEFT JOIN public.mls_message_mentions mn ON mn.message_id = m.id AND mn.user_id = moi.user_id
  LEFT JOIN public.mls_message_hidden h    ON h.message_id  = m.id AND h.user_id  = moi.user_id
 WHERE m.kind = 'content'
   AND NOT m.is_deleted
   AND h.message_id IS NULL
   AND moi.user_id IS NOT NULL
   AND moi.user_id <> m.sender_id
   AND moi.user_id = ANY (c.participant_ids)
 GROUP BY m.conversation_id, moi.user_id;

REVOKE ALL ON public.mls_unread_counts FROM anon;
GRANT SELECT ON public.mls_unread_counts TO authenticated;

-- ── Temps réel ─────────────────────────────────────────────────────────────
-- Seuls les reçus entrent dans la publication. Une réaction, une édition, un
-- masquage arrivent déjà par un message de contrôle MLS, donc par le canal
-- de `mls_messages` : les diffuser une seconde fois par leur table ferait
-- appliquer deux fois le même changement. Un reçu, lui, n'a pas de contrôle —
-- sans ce canal, les coches de lecture ne bougeraient qu'au rechargement.

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND tablename = 'mls_message_receipts'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.mls_message_receipts;
    END IF;
  END IF;
END
$do$;
