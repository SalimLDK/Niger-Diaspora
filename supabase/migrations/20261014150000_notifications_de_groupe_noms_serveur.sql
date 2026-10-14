-- Notifications de groupe : les noms viennent du serveur, et une demande
-- d'adhésion ne se répète pas en boucle.
--
-- LE DÉFAUT
-- `notify_on_group_request` et `notify_on_group_invite` (20260909223000)
-- composent leur texte avec `NEW.group_name` et `NEW.requester_name` /
-- `NEW.inviter_name` — des colonnes que le client écrit lui-même — et ne
-- reviennent aux vrais noms (`groups.name`, `users.display_name`) qu'en
-- secours. Une demande d'adhésion envoyait donc à tous les administrateurs du
-- groupe le texte de son choix :
--
--   « Service client Diaspo Niger demande à rejoindre « Vérifiez votre
--     compte sur … » »
--
-- et chaque retour du statut à 'pending' en renvoyait une, à chacun.
--
-- LA CORRECTION
-- Les deux fonctions, recopiées de 20260909223000 : les noms du serveur
-- d'abord, ceux de la ligne en secours seulement (ligne marquée « 20261014 »).
-- La demande d'adhésion ne notifie pas un administrateur qui a déjà, pour
-- cette même demande, une notification non lue.
--
-- Banc : tools/rls_tests/notifications_de_groupe_noms_serveur.sql

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

  -- 20261014 : les noms du serveur d'abord ; ceux de la ligne, écrits par le
  -- client, ne servent plus qu'en secours.
  v_group_name := COALESCE(
    NULLIF((SELECT name FROM groups WHERE id = NEW.group_id), ''),
    NULLIF(NEW.group_name, ''),
    'un groupe'
  );
  v_inviter_name := COALESCE(
    NULLIF((SELECT display_name FROM users WHERE id = NEW.inviter_id), ''),
    NULLIF(NEW.inviter_name, ''),
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

  -- 20261014 : les noms du serveur d'abord ; ceux de la ligne, écrits par le
  -- demandeur, ne servent plus qu'en secours.
  v_group_name := COALESCE(
    NULLIF((SELECT name FROM groups WHERE id = NEW.group_id), ''),
    NULLIF(NEW.group_name, ''),
    'votre groupe'
  );
  v_requester_name := COALESCE(
    NULLIF((SELECT display_name FROM users WHERE id = NEW.requester_id), ''),
    NULLIF(NEW.requester_name, ''),
    'Quelqu''un'
  );

  FOR v_admin_id IN
    SELECT gm.user_id FROM group_members gm
     WHERE gm.group_id = NEW.group_id
       AND gm.role IN ('admin', 'owner')
       AND gm.user_id <> NEW.requester_id
       -- 20261014 : une seule notification non lue par demande et par
       -- administrateur. Repasser le statut à « en attente » en boucle ne
       -- renvoie plus rien tant que la précédente n'a pas été lue.
       AND NOT EXISTS (
         SELECT 1 FROM notifications n
          WHERE n.user_id = gm.user_id
            AND n.type = 'groupJoinRequest'
            AND n.is_read = FALSE
            AND n.data->>'requestId' = NEW.id::text
       )
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
