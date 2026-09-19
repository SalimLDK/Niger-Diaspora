-- Suppression de compte : rejouer une suppression après une restauration.
--
-- POURQUOI (relecture du 2026-09-19 de `20260918224100`, déjà appliquée)
-- Une restauration de sauvegarde ramène la base à un instant passé. Tout ce qui
-- a été supprimé depuis réapparaît : le profil, les messages, les amitiés, les
-- appartenances de groupe — de personnes dont le compte Firebase, lui, n'existe
-- plus. Personne ne peut plus s'y connecter, mais leur contenu redevient visible
-- des autres : la suppression est défaite, sans erreur, par un geste
-- d'exploitation légitime.
--
-- Et `account_deletion_requests`, qui devait servir de pierre tombale, est
-- restaurée AVEC le reste : une suppression menée à terme APRÈS la sauvegarde y
-- est absente, ou encore `pending`. Une pierre tombale rangée dans la base
-- qu'on restaure ne protège de rien.
--
-- CE QUI EXISTE DÉSORMAIS
--   1. La pierre tombale vit HORS de Postgres : la Cloud Function
--      `finalizeAccountDeletions` écrit `deleted_accounts/<uid>` dans Firestore
--      (un uid et une date, ni nom ni e-mail) APRÈS avoir supprimé le compte
--      Firebase et AVANT de purger Supabase. Toute purge a donc sa pierre
--      tombale externe — l'inverse est refusé : si l'écriture échoue, la purge
--      n'a pas lieu à ce passage. Firestore n'est pas dans les sauvegardes de
--      Supabase : une restauration ne l'atteint pas.
--   2. `replay_account_deletion(uid)` : recrée la demande si elle a disparu et
--      rejoue la purge, qui est idempotente. Réservée à service_role.
--   3. `account_deletion_residue(uid)` : dit ce qui subsiste pour un uid, sans
--      rien modifier — de quoi décider, avant de rejouer, ce qu'une
--      restauration a ramené.
--   L'orchestration est dans `tools/rejouer_suppressions_apres_restauration.mjs`
--   (à lancer à la main après TOUTE restauration ; simulation par défaut).
--
-- CE QUE CETTE MIGRATION NE FAIT PAS
--   · Elle n'empêche pas une restauration de ramener les données pendant la
--     durée qui sépare la restauration du rejeu : le rejeu est une étape de la
--     procédure de restauration, pas un mécanisme automatique.
--   · Une suppression encore `pending` au moment de la sauvegarde puis perdue
--     par la restauration : la personne retrouve un compte actif et doit
--     redemander. Ce n'est pas une fuite, seulement une demande à refaire.
--
-- CORRECTIONS À `20260918224100` (déjà appliquée : sa lettre reste, cette
-- migration en corrige le sens)
--   · « la feuille de l'appareil supprimé reste dans l'arbre tant qu'un membre
--     ne commite pas » était trop pessimiste. Le client MLS a une
--     RÉCONCILIATION d'appartenance (`MlsGateway.appartenanceChangee` →
--     `reconcileMembership`) : elle retire du groupe les feuilles dont
--     l'identité n'est plus celle d'un appareil ACTIF d'un participant. La
--     purge y suffit — elle retire la personne de `participant_ids` (le signal)
--     et rend ses appareils inactifs (supprimés ou révoqués). Un membre en
--     ligne commite le retrait dans l'instant, les autres au prochain envoi.
--     Prouvé sur le vrai moteur par le banc MLS (`appareil révoqué : retiré au
--     prochain reconcile, il ne lit plus`) et par `mls_appartenance_test`
--     (`une exclusion réconcilie aussi`). Reste vrai : tant qu'aucun membre
--     n'est en ligne ni n'écrit, la feuille est dans l'arbre — mais l'appareil
--     supprimé n'a plus rien à lire côté serveur (plus participant, plus de
--     compte).
--   · Sauvegardes de Supabase, relevées le 2026-09-19 : `supabase backups list`
--     rend des sauvegardes physiques (WAL-G) ACTIVES et le PITR DÉSACTIVÉ, sans
--     date listée. La DURÉE DE CONSERVATION n'est pas lisible par la CLI : à
--     relever dans le tableau de bord (Database → Backups) et à consigner ici
--     et dans le texte de confidentialité.

CREATE OR REPLACE FUNCTION public.account_deletion_residue(p_uid text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  -- Des COMPTAGES, jamais un contenu. Les tables choisies sont celles qui
  -- montrent qu'une personne « supprimée » est de retour : son profil, son
  -- identité Supabase, ses appartenances, ce qu'elle a écrit, ses appareils.
  SELECT jsonb_build_object(
    'users',         (SELECT count(*) FROM public.users WHERE id = p_uid),
    'auth_mappings', (SELECT count(*) FROM public.auth_mappings WHERE firebase_uid = p_uid),
    'group_members', (SELECT count(*) FROM public.group_members WHERE user_id = p_uid),
    'messages',      (SELECT count(*) FROM public.messages WHERE sender_id = p_uid),
    'mls_devices',   (SELECT count(*) FROM public.mls_devices WHERE user_id = p_uid),
    'notifications', (SELECT count(*) FROM public.notifications WHERE user_id = p_uid),
    'friends',       (SELECT count(*) FROM public.friends WHERE user_id = p_uid OR friend_id = p_uid),
    'conversations', (SELECT count(*) FROM public.conversations WHERE participant_ids @> ARRAY[p_uid])
  );
$function$;

CREATE OR REPLACE FUNCTION public.replay_account_deletion(p_uid text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_blocage text;
BEGIN
  IF p_uid IS NULL OR p_uid = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'uid_manquant');
  END IF;

  -- Les refus d'une demande valent aussi pour un rejeu : le compte plateforme
  -- ne se purge pas, quoi que dise une pierre tombale.
  v_blocage := private.suppression_bloquee_pour(p_uid);
  IF v_blocage IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', v_blocage);
  END IF;

  -- La pierre tombale externe a dit que ce compte est supprimé ; la base, elle,
  -- l'a peut-être oublié (restauration) ou le croit `pending`. On la remet
  -- `deleting`, y compris si elle était `completed` : c'est précisément le cas
  -- d'une restauration qui a ramené des données sous une demande achevée.
  -- Une purge déjà en vol (`deleting`) n'est pas piétinée : `complete_...`
  -- prend un verrou de ligne, les deux s'exécutent l'une après l'autre.
  INSERT INTO public.account_deletion_requests AS r
         (user_id, status, execute_at, started_at, attempts)
  VALUES (p_uid, 'deleting', now(), now(), 1)
  ON CONFLICT (user_id) DO UPDATE
     SET status = 'deleting',
         started_at = now(),
         attempts = r.attempts + 1,
         last_error = NULL,
         completed_at = NULL
   WHERE r.status <> 'deleting';

  RETURN public.complete_account_deletion(p_uid);
END;
$function$;

-- Un GRANT n'enlève rien : `authenticated` et `anon` ont EXECUTE nommément sur
-- toute fonction neuve de `public`. Ni l'un ni l'autre ne doit pouvoir purger un
-- compte, ni sonder ce qui subsiste pour un uid.
REVOKE ALL ON FUNCTION public.account_deletion_residue(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.account_deletion_residue(text) TO service_role;

REVOKE ALL ON FUNCTION public.replay_account_deletion(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.replay_account_deletion(text) TO service_role;

COMMENT ON FUNCTION public.account_deletion_residue(text) IS
  'service_role : ce qui subsiste pour un uid (comptages seulement). Sert à décider d''un rejeu après restauration.';
COMMENT ON FUNCTION public.replay_account_deletion(text) IS
  'service_role : rejoue la purge d''un compte dont la pierre tombale externe (Firestore deleted_accounts) dit qu''il est supprimé. Idempotente ; refuse le compte plateforme et l''historique financier.';

NOTIFY pgrst, 'reload schema';
