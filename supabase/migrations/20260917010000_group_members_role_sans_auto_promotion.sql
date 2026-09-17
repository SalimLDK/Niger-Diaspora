-- Un simple membre pouvait se nommer owner de son propre groupe.
--
-- FAILLE MESURÉE en production le 2026-09-17, transaction annulée
-- (`supabase db query --linked -f`, `SET LOCAL ROLE authenticated` +
-- `request.jwt.claims` avec `app_metadata.firebase_uid`) :
--
--   UPDATE group_members SET role = 'owner'
--    WHERE group_id = '90a2baa1-3927-4b21-97ac-5907002ed75d'
--      AND user_id = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'   -- lui-même, simple membre
--
-- → 1 ligne modifiée, puis is_group_admin(groupe) = true pour ce compte.
-- Tout ce qui s'appuie sur is_group_admin() en hérite : groups_update_admin
-- (modifier le groupe), conversations_guard_admin_fields (exclure/promouvoir
-- dans la conversation du groupe), l'accès admin à group_requests /
-- group_invites (20260806180000), etc. Une auto-promotion suffit à prendre le
-- groupe entier.
--
-- CAUSE
-- `group_members_own` (20260522223150, identité migrée en 20260803170000)
-- est une policy FOR ALL :
--
--   USING ((SELECT firebase_uid()) = user_id)
--
-- sans WITH CHECK distinct — la même expression sert donc de WITH CHECK par
-- défaut. Elle ne dit qu'une chose : « c'est ma propre ligne », que ce soit
-- avant ou après l'écriture. Elle ne dit RIEN sur la colonne `role`, et
-- `authenticated` a UPDATE sur toute la table (droits par défaut Supabase,
-- CLAUDE.md « Migrations Supabase sur la branche partagée », point 2).
--
-- UN SECOND TROU, MÊME CAUSE : L'INSERT
-- `group_members_insert_gate` (20260806210000, RESTRICTIVE FOR INSERT) exige
-- `is_group_public(group_id) OR has_group_invite(group_id)`, mais ne dit rien
-- non plus du rôle. Combinée à `group_members_own` (permissive), un compte
-- authentifié peut aujourd'hui INSÉRER SA PROPRE LIGNE avec role = 'owner'
-- dans n'importe quel groupe PUBLIC — jamais exploité en dehors de ce banc,
-- mais la même faille, par la porte d'entrée plutôt que par la mise à jour.
--
-- UN TROISIÈME EFFET, SANS RAPPORT AVEC L'ATTAQUE : LA RÉTROGRADATION SILENCIEUSE
-- `GroupSupabaseDataSource.joinGroup` et l'acceptation d'invitation
-- (`group_request_supabase_datasource.dart:183`) écrivent :
--
--   INSERT INTO group_members (group_id, user_id, role)
--   VALUES (…, …, 'member')
--   ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member'
--
-- Un INSERT … ON CONFLICT DO UPDATE est un UPDATE dès que la ligne existe.
-- Un administrateur ou propriétaire qui « rejoint » à nouveau son propre
-- groupe (bouton dupliqué, retry réseau, invitation reçue alors qu'il est
-- déjà membre) se retrouve donc rétrogradé à `member`, sans qu'aucun code
-- n'ait voulu ça. Vérifié : rien dans le client ne s'attend à ce que ce
-- upsert change un rôle existant — il sert uniquement à créer la ligne
-- manquante. Le correctif ci-dessous ferme ce trou en même temps que la
-- faille, par le même mécanisme.
--
-- CE QUE LE CORRECTIF DOIT LAISSER PASSER (contraintes du produit)
--   · joinGroup / acceptGroupInvite : upsert role='member', PREMIÈRE fois
--     (INSERT) — doit réussir ;
--   · le même upsert, rejoue sur une ligne déjà 'member' (UPDATE role='member'
--     vers 'member', pas de changement réel) — doit réussir ;
--   · leaveGroup : DELETE de sa propre ligne — doit rester permis, aucune
--     policy ni déclencheur ci-dessous ne touche au DELETE ;
--   · création de groupe (`insert_group`), groupes officiels
--     (`get_or_create_official_group`, `get_or_create_ville_group`),
--     approbation d'une demande (`approve_group_request`) : toutes SECURITY
--     DEFINER, posent des rôles 'owner'/'member' pour un compte qui n'est
--     PAS encore admin du groupe au moment de l'écriture (le tout premier
--     membre, ou le compte plateforme) — doivent continuer de fonctionner ;
--   · une future RPC de promotion/rétrogradation (nommer_admin_du_groupe /
--     retirer_admin_du_groupe, en préparation ailleurs), elle aussi SECURITY
--     DEFINER — doit pouvoir écrire `role` sans ce garde dans ses pattes.
--
-- Ces quatre fonctions SECURITY DEFINER sont créées par des migrations
-- exécutées en tant que propriétaire de la base (rôle `postgres`, superuser
-- sur ce projet) : à l'intérieur d'une fonction SECURITY DEFINER,
-- `current_user` devient le PROPRIÉTAIRE de la fonction pour la durée de son
-- exécution, jamais `authenticated` ni `anon` — quel que soit le compte
-- réellement connecté (`firebase_uid()` continue, lui, de désigner
-- l'appelant réel : c'est une variable de session, pas de rôle). C'est
-- exactement ce que `REVOKE UPDATE (is_official) … FROM authenticated`
-- (20260806130000) exploite déjà pour bloquer le client sans toucher aux
-- fonctions SECURITY DEFINER, propriétaires de la table. On ne peut pas
-- reprendre cette forme ici : `REVOKE UPDATE (role)` bloquerait la colonne
-- pour TOUT `UPDATE` émis en tant que `authenticated` — y compris
-- `INSERT … ON CONFLICT DO UPDATE SET role = 'member'`, dont le privilège
-- se vérifie sur le texte de la requête, avant même de savoir si une ligne
-- existe. Ça aurait cassé `joinGroup` et l'acceptation d'invitation, que la
-- contrainte du correctif exige de laisser passer.
--
-- CORRECTIF : UN DÉCLENCHEUR, PAS UNE POLICY
-- RLS ne sait comparer NEW à OLD que via USING/WITH CHECK sur la MÊME ligne
-- logique, sans distinguer « ce champ a changé » de « ce champ est réécrit
-- avec sa valeur actuelle ». Un déclencheur BEFORE le sait. Même motif que
-- `guard_admin_flags` (20260803150000) pour `users.is_admin` /
-- `users.admin_role` — la même classe de bug (auto-promotion par écriture
-- directe d'une colonne de rôle), le même remède.
--
-- Le déclencheur ne s'applique qu'aux rôles RLS du client
-- (`authenticated`, `anon`) : c'est la même distinction que
-- `current_user NOT IN ('authenticated', 'anon')`, qui vaut TRUE pour toute
-- fonction SECURITY DEFINER de ce schéma, sans avoir à les énumérer ni à
-- introduire un drapeau de session que le client pourrait tenter de poser
-- lui-même (une session applicative peut faire SET ROLE, jamais se prétendre
-- SECURITY DEFINER).
--
-- Règles posées, pour authenticated/anon seulement :
--   1. INSERT : role doit être 'member'. Ferme le second trou (INSERT direct
--      en 'owner' dans un groupe public).
--   2. UPDATE : role, group_id et user_id ne peuvent pas changer. Ferme la
--      faille mesurée (auto-promotion par UPDATE) ET la rétrogradation
--      silencieuse (le upsert réécrit 'member' → 'member', valeur inchangée,
--      donc autorisé ; il ne peut plus écraser 'admin'/'owner' existant).
--      group_id/user_id : empêche de faire glisser sa propre ligne
--      d'appartenance vers un autre groupe par UPDATE — chemin que
--      `group_members_insert_gate` ne couvre pas, lui qui ne porte que sur
--      INSERT.
--
-- Aucune migration de données : aucune ligne group_members ne change de
-- valeur ici, seule l'écriture future est gardée.

CREATE OR REPLACE FUNCTION public.guard_group_members_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- SECURITY DEFINER (insert_group, get_or_create_official_group,
  -- get_or_create_ville_group, approve_group_request, et la future
  -- nommer_admin_du_groupe / retirer_admin_du_groupe) : current_user est le
  -- propriétaire de la fonction, jamais authenticated/anon. Ces fonctions
  -- portent leur propre garde ; ce déclencheur ne les concerne pas.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.role <> 'member' THEN
      RAISE EXCEPTION
        'Seul le rôle member peut être posé par une écriture directe'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- TG_OP = 'UPDATE'
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION
      'Le rôle ne se change pas par écriture directe — passer par la RPC de promotion/rétrogradation'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.group_id IS DISTINCT FROM OLD.group_id
     OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION
      'group_id et user_id sont la clé de group_members, ils ne se réécrivent pas'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS group_members_guard_role ON public.group_members;
CREATE TRIGGER group_members_guard_role
  BEFORE INSERT OR UPDATE ON public.group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_group_members_role();
