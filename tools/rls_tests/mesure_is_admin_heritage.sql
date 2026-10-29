-- Mesure, en LECTURE SEULE (catalogue uniquement, aucune donnée), de ce que les nouveaux rôles
-- d'administration hériteraient d'un `is_admin()` seul. À lancer AVANT d'attribuer le moindre rôle.
--
--   supabase db query --linked -f tools/rls_tests/mesure_is_admin_heritage.sql
--
-- Lecture : chaque ligne de la 1re requête est un droit que recevra un auditeur ou un analyste ; une ligne
-- INSERT / UPDATE / DELETE / ALL contredit leur « lecture seule » et doit être fermée avant l'attribution.

-- 1. Policies qui s'ouvrent à tout administrateur, sans permission nommée.
SELECT schemaname || '.' || tablename AS objet, cmd, policyname
  FROM pg_policies
 WHERE (coalesce(qual, '') || coalesce(with_check, '')) ~ 'is_admin\(\)'
   AND (coalesce(qual, '') || coalesce(with_check, '')) !~ 'admin_has_permission'
 ORDER BY (cmd = 'SELECT'), 1, 2, 3;

-- 2. Fonctions du schéma public qui testent is_admin() sans jamais exiger de permission nommée.
SELECT p.oid::regprocedure AS fonction, p.prosecdef AS security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
 WHERE p.prosrc ~ 'is_admin\(\)'
   AND p.prosrc !~ 'admin_has_permission|admin_require_permission'
   AND p.proname NOT IN ('is_admin', 'is_super_admin')
 ORDER BY 1;
