-- Le badge « Officiel » d'un groupe n'était gardé par rien.
--
-- Constat en base (2026-08-06) :
--   • `authenticated` détient les droits INSERT et UPDATE sur la colonne
--     `groups.is_official` ;
--   • la policy `groups_update_admin` vaut `USING (is_group_admin(id))` sans
--     `WITH CHECK` — donc l'administrateur d'un groupe, c'est-à-dire son
--     créateur, peut réécrire n'importe quelle colonne de sa propre ligne ;
--   • la policy `groups_insert` ne vérifie que `auth.uid() IS NOT NULL` ;
--   • le trigger `enforce_group_creator` impose bien `creator_id` depuis le
--     JWT, mais ne dit rien de `is_official` ;
--   • ni les migrations, ni les Cloud Functions, ni l'application ne
--     mentionnent `is_official` : aucun chemin admin n'était censé l'accorder.
--
-- Conséquence : n'importe quel utilisateur authentifié pouvait faire passer
-- son propre groupe pour officiel, à la création comme après coup, par un
-- simple appel PostgREST. Le badge affiché dans la liste des groupes et sur
-- la carte n'était donc pas un signal de confiance.
--
-- On reprend le motif déjà en place sur `users.is_admin`
-- (`guard_admin_flags`) : la colonne ne bouge que pour un admin plateforme,
-- et l'absence de session applicative (SQL Editor, service_role, migration)
-- reste le chemin d'amorçage.

CREATE OR REPLACE FUNCTION public.guard_group_official()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller TEXT;
  v_was BOOLEAN;
BEGIN
  v_was := CASE WHEN TG_OP = 'INSERT' THEN FALSE ELSE OLD.is_official END;

  IF NEW.is_official IS NOT DISTINCT FROM v_was THEN
    RETURN NEW;
  END IF;

  v_caller := (SELECT firebase_uid());

  -- Pas de session applicative : SQL Editor, service_role, migration.
  -- C'est le chemin par lequel un groupe est réellement adoubé aujourd'hui.
  IF v_caller IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT is_admin() THEN
    RAISE EXCEPTION
      'Seul un administrateur de la plateforme peut marquer un groupe comme officiel'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS groups_guard_official ON public.groups;

CREATE TRIGGER groups_guard_official
  BEFORE INSERT OR UPDATE ON public.groups
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_group_official();

-- Ceinture et bretelles : même si une future policy s'ouvrait, le rôle
-- applicatif n'a plus le droit d'écrire la colonne.
REVOKE UPDATE (is_official) ON public.groups FROM authenticated;
REVOKE INSERT (is_official) ON public.groups FROM authenticated;
