-- L'invité rejoignait le groupe sans jamais pouvoir ouvrir sa discussion.
--
-- `join_group_conversation()` (RPC SECURITY DEFINER) rattache l'appelant à
-- `conversations.participant_ids` -- c'est ce qui fait apparaître un groupe
-- rejoint dans l'onglet Messages. Mais le garde
-- `conversations_guard_admin_fields` (20260814000500) refuse TOUTE
-- modification de `participant_ids` par qui n'est pas administrateur du
-- groupe. Un invité qui vient d'accepter ne l'est pas.
--
-- Mesuré le 2026-09-09, identité réelle non privilégiée (`DfSyAW…`, membre
-- `role='member'` d'un groupe privé non officiel), en transaction annulée :
--
--   join_group_conversation(...) -> EXCEPTION 42501
--   « Seul un administrateur du groupe peut modifier les membres ou les
--     droits admin de cette conversation »
--   participant_ids : inchangé
--
-- Un premier test avait conclu l'inverse : le compte utilisé (`U64HK…`) est
-- superAdmin plateforme ET le groupe testé était officiel, donc le garde
-- l'acceptait par sa troisième branche. Deux privilèges qu'un invité normal
-- n'a pas. À retenir pour tout test de ce garde : prendre un compte
-- `users.is_admin = false` sur un groupe `is_official = false`.
--
-- ── Pourquoi l'exemption est adossée à l'INVITATION, et pas au simple fait
--    d'être membre ────────────────────────────────────────────────────────
--
-- « Retirer du groupe » (`removeUserFromGroup`,
-- message_supabase_datasource.dart:2045) ne retire la personne QUE de
-- `participant_ids` et de `data.adminIds` : sa ligne `group_members` reste.
-- Elle demeure donc membre du groupe au sens de la base -- elle apparaît
-- même encore dans la liste des membres de la fiche.
--
-- Une exemption formulée « un membre réel du groupe peut entrer dans la
-- conversation » rendrait donc à chaque exclu le droit de se remettre dans la
-- discussion en l'ouvrant, ce qui annulerait silencieusement toutes les
-- exclusions. C'est le garde qui, aujourd'hui, fait tenir l'exclusion -- par
-- effet de bord, pas par intention.
--
-- On s'adosse donc à `has_group_invite()` : une invitation existe, elle n'est
-- pas auto-décernée et n'est pas refusée (garanti par
-- 20260909201500). Un exclu n'en a aucune, il reste bloqué.
--
-- ⚠️ Reste donc ouvert, volontairement, et signalé plutôt que corrigé ici :
--   * un membre qui rejoint un groupe PUBLIC par « Rejoindre » n'a pas
--     d'invitation, donc son rattachement est toujours refusé -- même défaut,
--     autre porte ;
--   * « retirer du groupe » devrait supprimer la ligne `group_members` (il
--     n'existe aucune policy le permettant à un administrateur : il faudrait
--     une RPC dédiée). Tant que ce n'est pas fait, l'exemption ci-dessus ne
--     peut pas être élargie sans casser l'exclusion.

CREATE OR REPLACE FUNCTION public.conversations_guard_admin_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller text := firebase_uid();
  v_old_admins text[];
  v_new_admins text[];
  v_group_uuid uuid;
  v_is_privileged boolean;
BEGIN
  -- Les conversations 1:1 n'ont pas de notion d'admin/exclusion.
  IF NEW.group_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_old_admins := ARRAY(
    SELECT jsonb_array_elements_text(COALESCE(OLD.data->'adminIds', '[]'::jsonb))
  );
  v_new_admins := ARRAY(
    SELECT jsonb_array_elements_text(COALESCE(NEW.data->'adminIds', '[]'::jsonb))
  );

  -- adminIds et participant_ids inchangés : rien à protéger ici (mute,
  -- épingle, nom, etc. passent librement, comme avant).
  IF v_old_admins = v_new_admins AND OLD.participant_ids = NEW.participant_ids THEN
    RETURN NEW;
  END IF;

  -- Un participant qui se retire lui-même (quitter le groupe) reste autorisé
  -- sans être admin -- seul SON id disparaît de participant_ids et adminIds.
  IF NEW.participant_ids = array_remove(OLD.participant_ids, v_caller)
     AND OLD.participant_ids @> ARRAY[v_caller]
     AND NEW.participant_ids <> OLD.participant_ids
     AND v_new_admins = array_remove(v_old_admins, v_caller) THEN
    RETURN NEW;
  END IF;

  -- group_id peut être un id hérité Firestore (non-UUID) : cast protégé, une
  -- valeur non-UUID retombe simplement sur "pas de groupe Supabase associé"
  -- plutôt que de faire échouer le trigger.
  BEGIN
    v_group_uuid := NULLIF(NEW.group_id, '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    v_group_uuid := NULL;
  END;

  -- NOUVEAU (2026-09-09) : l'entrée volontaire de l'invité, miroir exact du
  -- départ volontaire ci-dessus. L'appelant s'ajoute LUI SEUL, ne touche pas
  -- à adminIds, et détient une invitation valide pour ce groupe.
  --
  -- `array_remove(NEW, v_caller) = OLD` est la forme symétrique du départ :
  -- elle vaut vrai quelle que soit la position de l'id ajouté, et faux dès
  -- qu'un autre id bouge -- donc on ne peut ni ajouter, ni retirer personne
  -- d'autre par cette porte.
  IF v_caller IS NOT NULL
     AND v_new_admins = v_old_admins
     AND NOT (OLD.participant_ids @> ARRAY[v_caller])
     AND array_remove(NEW.participant_ids, v_caller) = OLD.participant_ids
     AND NEW.participant_ids <> OLD.participant_ids
     AND v_group_uuid IS NOT NULL
     AND has_group_invite(v_group_uuid) THEN
    RETURN NEW;
  END IF;

  v_is_privileged := v_caller = ANY(v_old_admins)
    OR (v_group_uuid IS NOT NULL AND is_group_admin(v_group_uuid))
    OR (
      v_group_uuid IS NOT NULL AND is_admin()
      AND EXISTS (SELECT 1 FROM groups g WHERE g.id = v_group_uuid AND g.is_official)
    );

  IF NOT v_is_privileged THEN
    RAISE EXCEPTION 'Seul un administrateur du groupe peut modifier les membres ou les droits admin de cette conversation'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Notifications : personne n'était prévenu de rien
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Côté app, le type `groupInvite` est câblé de bout en bout depuis toujours --
-- routage de l'appui (`/groups/<targetId>`), style, écran de détail, canal
-- Android, et `prefKeyFor('groupInvite') = 'groups'` dans `send-push` pour
-- respecter la bascule de l'utilisateur. Un INSERT dans `notifications`
-- déclenche `trg_notify_push`, qui appelle `send-push`.
--
-- Il ne manquait que la ligne : AUCUN code, client ou serveur, n'en créait
-- jamais pour un groupe. Ni pour une invitation, ni pour une demande
-- d'adhésion, ni pour sa réponse. L'invité devait ouvrir l'onglet Groupes de
-- lui-même pour découvrir qu'on l'attendait.
--
-- Le `type` est écrit en chameau (`groupInvite`), pas en serpent : c'est la
-- forme que lit `prefKeyFor` / `channelFor` dans `send-push`. Le client
-- normalise les deux (`_parseNotificationType`), la fonction de push non --
-- un `group_invite` retomberait sur « toujours envoyé, canal general ».
--
-- `data` porte `targetId` (le groupe -- c'est ce que le routage de l'appui
-- lit) et `senderId`, les deux clés que
-- `notification_supabase_datasource.fromRow` sait extraire.
--
-- Chaque déclencheur avale ses erreurs comme `notify_on_post_insert` le fait
-- déjà : une notification qui échoue ne doit jamais faire échouer
-- l'invitation, la demande ou l'approbation elle-même.

CREATE OR REPLACE FUNCTION public.notify_on_group_invite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_group_name   text;
  v_inviter_name text;
BEGIN
  -- Une réinvitation passe par un `upsert` : c'est un UPDATE, pas un INSERT.
  -- On prévient à chaque fois que l'invitation (re)devient « en attente », et
  -- jamais sur l'acceptation ou le refus.
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;
  -- `OLD` n'est pas assigné sur un INSERT, et PL/pgSQL ne garantit PAS
  -- l'ordre d'évaluation des deux membres d'un `AND` : écrit
  -- `TG_OP = 'UPDATE' AND OLD.status = …` sur une seule ligne, l'accès à
  -- `OLD.status` peut être évalué d'abord et lever « record old is not
  -- assigned yet » -- avalé par le EXCEPTION plus bas, donc AUCUNE
  -- notification sur le chemin principal, sans une trace visible. D'où le
  -- test imbriqué.
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'pending' THEN
      RETURN NEW;
    END IF;
  END IF;
  IF NEW.invitee_id IS NULL OR NEW.invitee_id = ''
     OR NEW.invitee_id = NEW.inviter_id THEN
    RETURN NEW;
  END IF;

  v_group_name := COALESCE(
    NULLIF(NEW.group_name, ''),
    (SELECT name FROM groups WHERE id = NEW.group_id),
    'un groupe'
  );
  v_inviter_name := COALESCE(
    NULLIF(NEW.inviter_name, ''),
    (SELECT display_name FROM users WHERE id = NEW.inviter_id),
    'Quelqu''un'
  );

  INSERT INTO notifications (user_id, type, title, body, data, is_read)
  VALUES (
    NEW.invitee_id,
    'groupInvite',
    'Invitation à un groupe',
    v_inviter_name || ' vous invite à rejoindre « ' || v_group_name || ' »',
    jsonb_build_object(
      'targetId', NEW.group_id, 'target_id', NEW.group_id,
      'groupId', NEW.group_id,
      'inviteId', NEW.id,
      'senderId', NEW.inviter_id, 'sender_id', NEW.inviter_id
    ),
    FALSE
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'notify_on_group_invite: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_group_invite ON public.group_invites;
CREATE TRIGGER trg_notify_on_group_invite
  AFTER INSERT OR UPDATE OF status ON public.group_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_group_invite();

-- Demande d'adhésion : elle n'était visible que par le badge du menu ⋮, donc
-- seulement pour un administrateur qui pensait à ouvrir la fiche du groupe.
-- L'autre moitié du même trou : un groupe privé se remplit par invitation OU
-- par demande, et personne n'était prévenu dans les deux sens.
CREATE OR REPLACE FUNCTION public.notify_on_group_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_group_name     text;
  v_requester_name text;
  v_admin_id       text;
BEGIN
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    -- Même raison que ci-dessus : `OLD` n'existe pas sur un INSERT.
    IF OLD.status = 'pending' THEN
      RETURN NEW;
    END IF;
  END IF;

  v_group_name := COALESCE(
    NULLIF(NEW.group_name, ''),
    (SELECT name FROM groups WHERE id = NEW.group_id),
    'votre groupe'
  );
  v_requester_name := COALESCE(
    NULLIF(NEW.requester_name, ''),
    (SELECT display_name FROM users WHERE id = NEW.requester_id),
    'Quelqu''un'
  );

  FOR v_admin_id IN
    SELECT gm.user_id FROM group_members gm
     WHERE gm.group_id = NEW.group_id
       AND gm.role IN ('admin', 'owner')
       AND gm.user_id <> NEW.requester_id
  LOOP
    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (
      v_admin_id,
      'groupJoinRequest',
      'Demande d''adhésion',
      v_requester_name || ' demande à rejoindre « ' || v_group_name || ' »',
      jsonb_build_object(
        'targetId', NEW.group_id, 'target_id', NEW.group_id,
        'groupId', NEW.group_id,
        'requestId', NEW.id,
        'senderId', NEW.requester_id, 'sender_id', NEW.requester_id
      ),
      FALSE
    );
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'notify_on_group_request: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_group_request ON public.group_requests;
CREATE TRIGGER trg_notify_on_group_request
  AFTER INSERT OR UPDATE OF status ON public.group_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_group_request();

-- Réponse à la demande. Les deux types existent déjà côté app
-- (`groupRequestApproved` / `groupRequestRejected`, même clé de préférence
-- `groups`), et le demandeur n'avait aucun moyen d'apprendre la décision :
-- « Demande en attente » restait affiché jusqu'à ce qu'il rouvre la fiche.
CREATE OR REPLACE FUNCTION public.notify_on_group_request_processed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_group_name text;
BEGIN
  IF NEW.status = OLD.status
     OR NEW.status NOT IN ('approved', 'rejected') THEN
    RETURN NEW;
  END IF;

  v_group_name := COALESCE(
    NULLIF(NEW.group_name, ''),
    (SELECT name FROM groups WHERE id = NEW.group_id),
    'un groupe'
  );

  INSERT INTO notifications (user_id, type, title, body, data, is_read)
  VALUES (
    NEW.requester_id,
    CASE WHEN NEW.status = 'approved'
         THEN 'groupRequestApproved' ELSE 'groupRequestRejected' END,
    CASE WHEN NEW.status = 'approved'
         THEN 'Adhésion acceptée' ELSE 'Adhésion refusée' END,
    CASE WHEN NEW.status = 'approved'
         THEN 'Vous faites maintenant partie de « ' || v_group_name || ' »'
         ELSE 'Votre demande pour « ' || v_group_name || ' » n''a pas été retenue'
    END,
    jsonb_build_object(
      'targetId', NEW.group_id, 'target_id', NEW.group_id,
      'groupId', NEW.group_id,
      'requestId', NEW.id
    ),
    FALSE
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'notify_on_group_request_processed: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_group_request_processed
  ON public.group_requests;
CREATE TRIGGER trg_notify_on_group_request_processed
  AFTER UPDATE OF status ON public.group_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_group_request_processed();
