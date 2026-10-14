-- Une garde commune devant `notifications` : longueur bornée, blocage, quota.
--
-- Audit des notifications du 2026-10-14, constats n° 3, 4 et 6. Chaque source
-- de notification (une dizaine de déclencheurs, autant de fonctions) portait
-- — ou oubliait — ses propres contrôles. Trois oublis, une même forme :
--
-- 3. RÉACTIONS CHIFFRÉES. `mls_message_reactions.emoji` est un `text` sans
--    borne, modifiable par UPDATE. `mls_notifier_reaction` le met dans le
--    corps du push et, à chaque UPDATE, efface la notification non lue puis en
--    crée une neuve : une boucle `SET emoji = '<phrase d'hameçonnage>'`
--    envoyait autant de push qu'on voulait, même à quelqu'un qui avait bloqué
--    l'auteur. La voie en clair bornait l'emoji à 16 caractères, mais pas
--    plus le blocage que la cadence.
-- 4. INVITATIONS DE GROUPE. L'auteur d'une invitation peut repasser son
--    statut à `pending` : chaque aller-retour renotifiait l'invité, blocage
--    ignoré. Le dédoublonnage posé le jour même sur les demandes d'adhésion
--    manquait aux invitations.
-- 6. TAILLE. `send-push` prend toute réponse INVALID_ARGUMENT de FCM pour un
--    jeton mort et le RETIRE — or FCM répond aussi INVALID_ARGUMENT à un
--    message de plus de 4 Ko. Un nom de groupe ou un emoji démesuré effaçait
--    tous les jetons du destinataire. (`send-push` est corrigé aussi ; la
--    borne ici est la seconde ceinture.)
--
-- D'où un déclencheur BEFORE INSERT sur `notifications`, qui voit passer
-- toutes les sources sans qu'on ait à les réécrire une à une :
--
-- · titre ≤ 120 caractères, corps ≤ 300, pour TOUS les types ;
-- · une réaction dont l'« emoji » contient une lettre latine n'est pas
--   annoncée (un emoji n'en contient jamais ; une adresse, toujours) ;
-- · pour `messageReaction`, `messageEdited` et `groupInvite` : rien si le
--   destinataire a bloqué l'acteur, et au plus N par heure et par couple
--   (acteur, destinataire) — compté dans une table à part, que l'effacement
--   d'une notification non lue ne remet pas à zéro ;
-- · `groupInvite` : rien tant qu'une invitation non lue au même groupe
--   attend déjà.
--
-- Un refus ici est un `RETURN NULL` : la notification n'existe pas, et
-- l'écriture qui l'a provoquée (la réaction, l'invitation) passe quand même.
--
-- Banc : tools/rls_tests/notifications_garde_commune.sql

-- ── 1. L'emoji chiffré, borné comme celui en clair ──────────────────────────
-- 16 points de code : la séquence d'emoji la plus longue (familles, drapeaux
-- de sous-division) y tient. Et pas une lettre latine : aucun emoji n'en
-- contient (les drapeaux et les sous-divisions ont leurs propres points de
-- code), alors qu'en 16 caractères tient encore « evil.tld/compte ». Les
-- chiffres restent permis (« 1️⃣ »). NOT VALID : on ne réécrit pas
-- l'existant, on refuse le neuf.
ALTER TABLE public.mls_message_reactions
  DROP CONSTRAINT IF EXISTS mls_message_reactions_emoji_court;
ALTER TABLE public.mls_message_reactions
  ADD CONSTRAINT mls_message_reactions_emoji_court
  CHECK (emoji IS NULL OR (char_length(emoji) <= 16 AND emoji !~ '[A-Za-z]')) NOT VALID;

-- ── 2. Le compteur ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS private.notifications_comptees (
  acteur       text        NOT NULL,
  destinataire text        NOT NULL,
  type         text        NOT NULL,
  creee_le     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_comptees_couple_idx
  ON private.notifications_comptees (acteur, destinataire, type, creee_le);
REVOKE ALL ON private.notifications_comptees FROM PUBLIC, anon, authenticated;

-- ── 3. La garde ─────────────────────────────────────────────────────────────
-- SECURITY DEFINER : elle lit `blocked_users` et écrit son compteur quel que
-- soit l'appelant. Aucune décision ne dépend de `current_user`.
CREATE OR REPLACE FUNCTION private.garde_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_acteur  text;
  v_plafond int;
  v_n       int;
BEGIN
  NEW.title := left(NEW.title, 120);
  NEW.body  := left(NEW.body, 300);

  v_plafond := CASE NEW.type
    WHEN 'messageReaction' THEN 30
    WHEN 'messageEdited'   THEN 30
    WHEN 'groupInvite'     THEN 5
  END;
  IF v_plafond IS NULL THEN
    RETURN NEW;
  END IF;

  v_acteur := COALESCE(NULLIF(NEW.data->>'actor_id', ''),
                       NULLIF(NEW.data->>'senderId', ''),
                       NULLIF(NEW.data->>'sender_id', ''));
  IF v_acteur IS NULL OR v_acteur = NEW.user_id THEN
    RETURN NEW;
  END IF;

  IF EXISTS (SELECT 1 FROM blocked_users b
              WHERE b.blocker_id = NEW.user_id AND b.blocked_id = v_acteur) THEN
    RETURN NULL;
  END IF;

  -- La voie en clair (`set_message_reaction`) borne l'emoji à 16 caractères,
  -- sans regarder ce qu'ils sont : même règle que la contrainte ci-dessus.
  IF NEW.type = 'messageReaction' AND NEW.data->>'emoji' ~ '[A-Za-z]' THEN
    RETURN NULL;
  END IF;

  IF NEW.type = 'groupInvite' AND EXISTS (
       SELECT 1 FROM notifications n
        WHERE n.user_id = NEW.user_id
          AND n.type = 'groupInvite'
          AND NOT n.is_read
          AND n.data->>'groupId' = NEW.data->>'groupId') THEN
    RETURN NULL;
  END IF;

  DELETE FROM private.notifications_comptees
   WHERE acteur = v_acteur AND destinataire = NEW.user_id AND type = NEW.type
     AND creee_le < now() - interval '1 hour';
  SELECT count(*) INTO v_n
    FROM private.notifications_comptees
   WHERE acteur = v_acteur AND destinataire = NEW.user_id AND type = NEW.type;
  IF v_n >= v_plafond THEN
    RETURN NULL;
  END IF;
  INSERT INTO private.notifications_comptees (acteur, destinataire, type)
  VALUES (v_acteur, NEW.user_id, NEW.type);

  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION private.garde_notification() FROM PUBLIC, anon, authenticated;

-- Le nom commence par « a » : les déclencheurs BEFORE d'une table passent par
-- ordre alphabétique, et celui-ci doit passer avant tout autre qui lirait le
-- titre ou le corps.
DROP TRIGGER IF EXISTS a_garde_notification ON public.notifications;
CREATE TRIGGER a_garde_notification
  BEFORE INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION private.garde_notification();
