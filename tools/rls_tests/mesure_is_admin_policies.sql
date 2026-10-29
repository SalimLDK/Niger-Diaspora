-- Policies qui s'ouvrent à tout administrateur sans permission nommée (catalogue seul, aucune donnée).
-- Lancer SEUL : `supabase db query --linked` n'affiche que le résultat de la dernière requête d'un fichier.
SELECT schemaname || '.' || tablename AS objet, cmd, policyname
  FROM pg_policies
 WHERE (coalesce(qual, '') || coalesce(with_check, '')) ~ 'is_admin\(\)'
   AND (coalesce(qual, '') || coalesce(with_check, '')) !~ 'admin_has_permission'
 ORDER BY (cmd = 'SELECT'), 1, 2, 3;
