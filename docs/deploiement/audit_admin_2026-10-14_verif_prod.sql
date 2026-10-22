-- Vérification en production des points laissés ouverts par
-- docs/deploiement/AUDIT_ADMIN_2026-10-14.md (§ 4, § 6, § 9).
--
-- Lecture seule. À lancer depuis la racine du dépôt (supabase/.temp porte le
-- lien vers « Diapo Niger », zyrfkcjjrhddpfxcgezo — vérifier le ref avant de
-- conclure à une dérive) :
--
--   supabase db query --linked -f docs/deploiement/audit_admin_2026-10-14_verif_prod.sql
--
-- Rend un seul JSON :
--   tables          colonnes réelles des 17 tables touchées par le back-office
--                   (comparer au tableau du § 4) ; une table absente n'y figure pas
--   is_admin,       corps actuel des deux helpers (le dépôt dit : `is_admin` seul,
--   is_super_admin  puis `is_admin AND admin_role = 'superAdmin'`)
--   admins          comptes par couple (is_admin, admin_role) : toute ligne avec
--                   un seul des deux renseignés est une divergence du § 2
--   users_triggers  doit contenir users_guard_admin_flags
--   rls             (rls, forced) des tables admin ; `policies` dit si une table
--                   sous RLS n'a AUCUNE policy (vide pour tout client, insert refusé)
--   reports_rows    volume de la file Supabase (les signalements de l'app sont
--                   dans Firestore, § 3)

select jsonb_pretty(jsonb_build_object(
  'tables', (
    select jsonb_object_agg(table_name, cols) from (
      select table_name, string_agg(column_name, ',' order by ordinal_position) cols
      from information_schema.columns
      where table_schema = 'public'
        and table_name in ('users','reports','transactions','orders','events','groups',
                           'businesses','products','admin_audit_logs','admin_notifications',
                           'error_logs','activity_logs','support_tickets','embassies',
                           'notifications','business_reviews','messages')
      group by 1) t),
  'is_admin', (
    select pg_get_functiondef(p.oid) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_admin' limit 1),
  'is_super_admin', (
    select pg_get_functiondef(p.oid) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_super_admin' limit 1),
  'profils_admin_exists', (to_regproc('public.profils_admin') is not null),
  'admins', (
    select jsonb_agg(jsonb_build_object('is_admin', is_admin, 'admin_role', admin_role, 'n', n))
    from (select is_admin, admin_role, count(*) n
          from public.users
          where coalesce(is_admin, false) or admin_role is not null
          group by 1, 2) a),
  'users_total', (select count(*) from public.users),
  'users_triggers', (
    select jsonb_agg(tgname) from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    where c.relname = 'users' and not tgisinternal),
  'reports_rows', (select count(*) from public.reports),
  'rls', (
    select jsonb_object_agg(c.relname, jsonb_build_object(
      'rls', c.relrowsecurity,
      'forced', c.relforcerowsecurity,
      'policies', (select count(*) from pg_policies p
                   where p.schemaname = 'public' and p.tablename = c.relname)))
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and c.relname in ('users','reports','transactions','orders','events','groups',
                        'businesses','products','admin_audit_logs','admin_notifications',
                        'error_logs','activity_logs','support_tickets','embassies'))
));
