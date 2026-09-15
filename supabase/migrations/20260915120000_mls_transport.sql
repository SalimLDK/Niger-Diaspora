-- Transport MLS (plan MLS, phases 3 et 5) : commits, Welcome, messages.
--
-- CE QUE LE SERVEUR EST ICI
-- Un service de livraison, que le protocole considère comme hostile : il
-- peut observer, retarder, réordonner, rejouer. Il ne voit jamais un clair,
-- une clé privée ni un secret de groupe. Il voit qui écrit à qui, quand,
-- depuis quel appareil, quelle taille, quel type grossier (décision F).
--
-- CE QU'IL ARBITRE — ET C'EST SA SEULE INTELLIGENCE
-- Tous les membres d'un groupe doivent traiter les commits dans le MÊME
-- ordre. La clé primaire `(conversation_id, epoch)` de `mls_commits` est
-- cet arbitre : deux commits concurrents pour le même epoch, un seul entre
-- (l'autre reçoit 23505, jette son commit, traite le gagnant, recommence).
-- L'epoch 0 réserve la création du groupe de la même façon : deux appareils
-- qui créeraient le même groupe en même temps auraient deux secrets
-- différents, sans erreur nulle part.
--
-- COEXISTENCE
-- `conversations.mls_since` (posé une seule fois, jamais remis à NULL) dit
-- qu'une conversation est passée à MLS. À partir de là, `messages` (legacy)
-- refuse toute insertion pour elle — un ancien build ne peut pas glisser un
-- message en clair au milieu du fil chiffré.

-- ── Conversations : la bascule ─────────────────────────────────────────────

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS mls_since timestamptz;

CREATE OR REPLACE FUNCTION public.conversations_garde_mls_since()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF OLD.mls_since IS NOT NULL AND NEW.mls_since IS DISTINCT FROM OLD.mls_since THEN
    RAISE EXCEPTION 'mls_since ne se modifie pas une fois posé'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS conversations_garde_mls_since_trg ON public.conversations;
CREATE TRIGGER conversations_garde_mls_since_trg
  BEFORE UPDATE OF mls_since ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.conversations_garde_mls_since();

-- Le legacy refuse une conversation basculée.
CREATE OR REPLACE FUNCTION public.messages_refuse_conversation_mls()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.conversations c
     WHERE c.id = NEW.conversation_id AND c.mls_since IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'conversation passée au chiffrement de bout en bout : mettez l''application à jour'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS messages_refuse_conversation_mls_trg ON public.messages;
CREATE TRIGGER messages_refuse_conversation_mls_trg
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.messages_refuse_conversation_mls();

-- ── Commits ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.mls_commits (
  conversation_id  text NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  -- Epoch PRODUIT par ce commit. 0 = réservation de la création (commit vide).
  epoch            bigint NOT NULL CHECK (epoch >= 0),
  sender_device_id uuid NOT NULL REFERENCES public.mls_devices (id),
  commit           bytea NOT NULL,
  -- GroupInfo (arbre public) pour les jointures externes des groupes ouverts.
  group_info       bytea,
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, epoch)
);

ALTER TABLE public.mls_commits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_commits: participants" ON public.mls_commits;
CREATE POLICY "mls_commits: participants" ON public.mls_commits
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.is_conversation_participant(conversation_id));

DROP POLICY IF EXISTS "mls_commits: publier depuis son appareil" ON public.mls_commits;
CREATE POLICY "mls_commits: publier depuis son appareil" ON public.mls_commits
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    public.is_conversation_participant(conversation_id)
    AND EXISTS (
      SELECT 1 FROM public.mls_devices d
      WHERE d.id = sender_device_id AND d.user_id = (SELECT firebase_uid())
    )
  );

REVOKE ALL ON public.mls_commits FROM anon;
GRANT SELECT, INSERT ON public.mls_commits TO authenticated;

-- ── Welcome ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.mls_welcomes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id     text NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  recipient_device_id uuid NOT NULL REFERENCES public.mls_devices (id) ON DELETE CASCADE,
  epoch               bigint NOT NULL,
  welcome             bytea NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  consumed_at         timestamptz
);

CREATE INDEX IF NOT EXISTS mls_welcomes_destinataire_idx
  ON public.mls_welcomes (recipient_device_id)
  WHERE consumed_at IS NULL;

ALTER TABLE public.mls_welcomes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_welcomes: destinataire" ON public.mls_welcomes;
CREATE POLICY "mls_welcomes: destinataire" ON public.mls_welcomes
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.mls_devices d
    WHERE d.id = recipient_device_id AND d.user_id = (SELECT firebase_uid())
  ));

DROP POLICY IF EXISTS "mls_welcomes: emis par un participant" ON public.mls_welcomes;
CREATE POLICY "mls_welcomes: emis par un participant" ON public.mls_welcomes
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_conversation_participant(conversation_id));

DROP POLICY IF EXISTS "mls_welcomes: consomme par le destinataire" ON public.mls_welcomes;
CREATE POLICY "mls_welcomes: consomme par le destinataire" ON public.mls_welcomes
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.mls_devices d
    WHERE d.id = recipient_device_id AND d.user_id = (SELECT firebase_uid())
  ));

REVOKE ALL ON public.mls_welcomes FROM anon;
GRANT SELECT, INSERT, UPDATE (consumed_at) ON public.mls_welcomes TO authenticated;

-- ── Appareils d'une conversation, vus par le service de livraison ─────────

CREATE TABLE IF NOT EXISTS public.conversation_devices (
  conversation_id text NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  device_id       uuid NOT NULL REFERENCES public.mls_devices (id) ON DELETE CASCADE,
  status          text NOT NULL CHECK (status IN ('pending', 'active', 'removed')),
  epoch_added     bigint,
  epoch_removed   bigint,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, device_id)
);

ALTER TABLE public.conversation_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversation_devices: participants" ON public.conversation_devices;
CREATE POLICY "conversation_devices: participants" ON public.conversation_devices
  AS PERMISSIVE FOR ALL TO authenticated
  USING (public.is_conversation_participant(conversation_id))
  WITH CHECK (public.is_conversation_participant(conversation_id));

REVOKE ALL ON public.conversation_devices FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversation_devices TO authenticated;

-- ── Messages ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.mls_messages (
  id               uuid PRIMARY KEY,
  conversation_id  text NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  sender_id        text NOT NULL,
  sender_device_id uuid NOT NULL REFERENCES public.mls_devices (id),
  epoch            bigint NOT NULL,
  kind             text NOT NULL CHECK (kind IN ('content', 'control')),
  content_type     text NOT NULL CHECK (content_type IN
                     ('text', 'media', 'voice', 'location', 'poll', 'sticker', 'system')),
  ciphertext       bytea NOT NULL,
  aad_version      smallint NOT NULL DEFAULT 1,
  reply_to_id      uuid REFERENCES public.mls_messages (id),
  is_deleted       boolean NOT NULL DEFAULT false,
  deleted_at       timestamptz,
  edited_at        timestamptz,
  expires_at       timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mls_messages_conversation_idx
  ON public.mls_messages (conversation_id, created_at DESC);

ALTER TABLE public.mls_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_messages: participants" ON public.mls_messages;
CREATE POLICY "mls_messages: participants" ON public.mls_messages
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.is_conversation_participant(conversation_id));

DROP POLICY IF EXISTS "mls_messages: emettre depuis son appareil" ON public.mls_messages;
CREATE POLICY "mls_messages: emettre depuis son appareil" ON public.mls_messages
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = (SELECT firebase_uid())
    AND public.is_conversation_participant(conversation_id)
    AND EXISTS (
      SELECT 1 FROM public.mls_devices d
      WHERE d.id = sender_device_id AND d.user_id = (SELECT firebase_uid())
    )
  );

DROP POLICY IF EXISTS "mls_messages: l'expediteur retouche" ON public.mls_messages;
CREATE POLICY "mls_messages: l'expediteur retouche" ON public.mls_messages
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (sender_id = (SELECT firebase_uid()))
  WITH CHECK (sender_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_messages: l'expediteur supprime" ON public.mls_messages;
CREATE POLICY "mls_messages: l'expediteur supprime" ON public.mls_messages
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (sender_id = (SELECT firebase_uid()));

REVOKE ALL ON public.mls_messages FROM anon;
GRANT SELECT, INSERT, DELETE ON public.mls_messages TO authenticated;
-- Le ciphertext ne se réécrit jamais : seules les métadonnées de retouche.
GRANT UPDATE (is_deleted, deleted_at, edited_at, expires_at) ON public.mls_messages TO authenticated;

-- ── Temps réel ─────────────────────────────────────────────────────────────
-- `.stream()` ne sait ni joindre ni lire deux tables : un canal par table.

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'mls_messages') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.mls_messages;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'mls_commits') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.mls_commits;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'mls_welcomes') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.mls_welcomes;
    END IF;
  END IF;
END
$do$;
