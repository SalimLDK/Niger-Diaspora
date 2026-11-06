-- « Contacter un membre » : message administratif individuel, motivé, tracé. NON APPLIQUÉE.
-- À répéter par tools/rls_tests/contacter_un_membre.sql avant toute application.
--
-- PRINCIPE. Pas de messagerie libre. Un contact est un TICKET DE SUPPORT ouvert au nom du membre, dont le premier
-- message vient de « Support Diaspo Niger » : le membre le voit déjà dans l'aide de l'application et peut y
-- RÉPONDRE, sans que l'application change. Il reçoit une notification dont le texte est fixé par le serveur et ne
-- reprend JAMAIS le message (rien de confidentiel sur un écran de verrouillage).
--
-- GARDE-FOUS (tous côté serveur)
--   • permission `community.members.contact` (nouvelle) — contentMod ; superAdmin a tout le catalogue. L'agent de support
--     ne l'a pas : il n'a pas non plus la lecture des membres, et il répond déjà aux tickets ;
--   • motif normalisé obligatoire, sujet et message bornés ;
--   • pas de contact avec soi-même ; un administrateur ne se contacte que par un superAdmin (member_cible_check) ;
--   • au plus 3 contacts par membre et par 24 h, et 30 par administrateur et par 24 h (pas de harcèlement) ;
--   • l'audit nomme l'administrateur, le motif et le ticket, jamais le texte du message ;
--   • le ticket garde `opened_by_admin` et `contact_reason` : l'historique d'un membre se relit.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS : pas de pièce jointe, pas de contact en masse (c'est le rôle des campagnes),
-- pas de lecture des conversations privées. La durée de conservation des échanges reste à décider (politique de
-- rétention non définie) ; les tickets ne sont pas purgés ici.

SET lock_timeout = '5s';

-- ── 1. La permission ────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description)
VALUES ('community.members.contact', 'community', 'Contacter un membre (message administratif motivé)')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission)
SELECT r, 'community.members.contact' FROM (VALUES ('contentMod')) AS t(r)
ON CONFLICT DO NOTHING;

-- ── 2. Mémoire du contact sur le ticket ─────────────────────────────────────
ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS opened_by_admin text,
  ADD COLUMN IF NOT EXISTS contact_reason  text;

CREATE INDEX IF NOT EXISTS support_tickets_contacts_idx
  ON public.support_tickets (user_id, created_at DESC) WHERE opened_by_admin IS NOT NULL;

-- ── 3. La fonction ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.member_admin_contact(text, text, text, text);

CREATE FUNCTION public.member_admin_contact(
  p_member_id text,
  p_reason    text,
  p_subject   text,
  p_body      text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller   text := (SELECT public.firebase_uid());
  u          public.users%ROWTYPE;
  v_id       uuid;
  v_category text;
  v_msg_id   text;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'contact : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.members.contact');

  IF p_reason IS NULL OR p_reason NOT IN
     ('info_request', 'account_issue', 'profile_update', 'admin_notice', 'decision', 'other') THEN
    RAISE EXCEPTION 'contact : motif normalisé requis' USING ERRCODE = '22023';
  END IF;
  IF p_subject IS NULL OR length(btrim(p_subject)) NOT BETWEEN 5 AND 120 THEN
    RAISE EXCEPTION 'contact : sujet requis (5 à 120 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_body IS NULL OR length(btrim(p_body)) NOT BETWEEN 10 AND 4000 THEN
    RAISE EXCEPTION 'contact : message requis (10 à 4000 caractères)' USING ERRCODE = '22023';
  END IF;

  u := public.member_cible_check(p_member_id, v_caller);   -- verrouille la ligne : deux contacts ne se doublent pas

  IF (SELECT count(*) FROM public.support_tickets
       WHERE user_id = p_member_id AND opened_by_admin IS NOT NULL
         AND created_at > now() - interval '24 hours') >= 3 THEN
    RAISE EXCEPTION 'contact : ce membre a déjà reçu 3 messages en 24 h' USING ERRCODE = '55000';
  END IF;
  IF (SELECT count(*) FROM public.support_tickets
       WHERE opened_by_admin = v_caller AND created_at > now() - interval '24 hours') >= 30 THEN
    RAISE EXCEPTION 'contact : limite de 30 contacts par 24 h atteinte' USING ERRCODE = '55000';
  END IF;

  v_category := CASE p_reason WHEN 'account_issue' THEN 'account' WHEN 'profile_update' THEN 'account' ELSE 'other' END;
  v_msg_id   := 'msg_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint;

  PERFORM set_config('app.support_rpc', 'on', true);
  INSERT INTO public.support_tickets
    (user_id, subject, status, messages, user_name, user_email, description, category,
     has_unread_support_messages, assigned_to, assigned_at, opened_by_admin, contact_reason)
  VALUES
    (p_member_id, btrim(p_subject), 'in_progress',
     jsonb_build_array(jsonb_build_object(
       'id', v_msg_id,
       'senderId', v_caller,
       'senderName', 'Support Diaspo Niger',
       'isFromSupport', true,
       'content', btrim(p_body),
       'createdAt', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))),
     coalesce(u.display_name, ''), '', '', v_category,
     true, v_caller, now(), v_caller, p_reason)
  RETURNING id INTO v_id;
  PERFORM set_config('app.support_rpc', 'off', true);

  -- Titre et corps écrits ICI : la notification ne reprend pas le message et ne peut pas se faire passer pour autre chose.
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_member_id, 'system', 'Message de l''équipe Diaspo Niger',
          'Vous avez un nouveau message. Ouvrez l''aide de l''application pour le lire.',
          jsonb_build_object('support_ticket', v_id::text));

  PERFORM public.write_admin_audit(
    'MEMBER_CONTACTED', 'user', p_member_id, 'success', p_reason, v_id::text,
    jsonb_build_object('ticket', v_id::text));
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.member_admin_contact(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.member_admin_contact(text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
