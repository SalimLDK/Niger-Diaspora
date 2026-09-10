-- =============================================================================
-- `group_link_preview` était joignable en ANONYME. Correctif de ma propre
-- migration `20260910060000`.
--
-- Elle disait « réservée à `authenticated` » et faisait :
--
--     REVOKE ALL ON FUNCTION group_link_preview(UUID) FROM PUBLIC;
--     GRANT EXECUTE ON FUNCTION group_link_preview(UUID) TO authenticated;
--
-- Ça ne suffit pas. Supabase pose un `ALTER DEFAULT PRIVILEGES` qui accorde
-- EXECUTE **nommément** à `anon`, `authenticated` et `service_role` sur toute
-- nouvelle fonction du schéma `public`. Révoquer `PUBLIC` ne touche pas ces
-- trois-là : le privilège d'`anon` survivait.
--
-- Mesuré en production le 2026-09-10, avec la clé publique du `.env` :
--
--     POST /rest/v1/rpc/group_link_preview  →  200
--     [{"name":"Groupe de test prive","member_count":1,"is_private":true}]
--
-- Autrement dit, le nom d'un groupe privé était lisible **sans compte**. Le
-- choix assumé était : qui détient l'uuid ET possède un compte peut voir le
-- nom pour demander à rejoindre. Pas : n'importe qui sur Internet.
--
-- ⚠️ À retenir pour toute fonction SECURITY DEFINER ajoutée ici : vérifier
-- `proacl` après coup, `REVOKE ... FROM PUBLIC` ne dit rien des rôles Supabase.
--
--     SELECT proname, proacl FROM pg_proc WHERE proname = '<la fonction>';
-- =============================================================================

REVOKE EXECUTE ON FUNCTION group_link_preview(UUID) FROM anon;

NOTIFY pgrst, 'reload schema';
