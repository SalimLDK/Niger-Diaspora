-- Notifications de groupe : personne n'etait prevenu de rien.
--
-- ── Ce fichier a d'abord contenu autre chose ───────────────────────────────
--
-- Il corrigeait aussi le garde `conversations_guard_admin_fields`, qui refuse
-- toute modification de `participant_ids` a qui n'est pas administrateur du
-- groupe -- et bloque donc `join_group_conversation()`, dont tout le travail
-- est justement d'y ajouter un membre qui a rejoint apres la creation de la
-- conversation. Mesure sous identite reelle non privilegiee le 2026-09-09 :
-- `EXCEPTION 42501`, `participant_ids` inchange.
--
-- L'autre agent l'avait trouve en meme temps, depuis un appareil, et corrige
-- dans `20260909210500_membre_non_admin_peut_rejoindre_sa_conversation.sql`.
-- Sa version est plus large que ce qui etait ecrit ici -- elle exempte tout membre REEL du groupe qui s'ajoute lui-meme,
-- donc aussi celui qui rejoint un groupe PUBLIC, cas que cette migration-ci
-- laissait de cote -- et elle traite un ecart que je n'avais pas vu : le
-- garde identifie l'appelant par `firebase_uid()` la ou la RPC ajoute
-- `current_user_id()`.
--
-- Mon `CREATE OR REPLACE FUNCTION` aurait donc REMPLACE sa correction par une
-- version moins bonne, sans conflit git et sans un mot : les deux fichiers ont
-- des noms differents, et `CREATE OR REPLACE` ne previent jamais qu'il ecrase.
-- Retire. Ce fichier ne porte plus que les declencheurs de notification.
--
-- ⚠️ NI SA MIGRATION NI CELLE-CI N'ETAIENT APPLIQUEES au moment d'ecrire ces
-- lignes (2026-09-09). La fonction deployee ne porte aucune des deux
-- exemptions -- verifie sur `pg_proc.prosrc` -- et `db push` est bloque par
-- une version orpheline dans `supabase_migrations.schema_migrations`
-- (`20260909210000`, sans fichier local). Non repare ici : c'est de l'etat
-- partage au milieu du travail de l'autre agent. Tant que ce n'est pas fait,
-- l'invite rejoint bien le groupe mais ne peut pas ouvrir sa discussion.
--
-- ⚠️ Et une consequence de sa version, MESUREE le 2026-09-09 en appliquant sa
-- migration dans une transaction annulee : « retirer du groupe »
-- (`removeUserFromGroup`) ne supprime pas la ligne `group_members`, donc un
-- exclu reste membre du groupe -- et l'exemption « tout membre reel peut
-- s'ajouter » lui rend le droit de se remettre dans la discussion en
-- l'ouvrant. Mesure : `exclu_de_retour = true`. Consigne dans
-- TESTS_APPAREIL_A_FAIRE.md, non corrige : le vrai correctif est que
-- l'exclusion supprime l'appartenance, ce qui demande une RPC dediee (aucune
-- policy ne permet a un administrateur de supprimer la ligne d'un autre).

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
