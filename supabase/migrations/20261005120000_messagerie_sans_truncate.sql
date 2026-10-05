-- Messagerie : `TRUNCATE`, `REFERENCES` et `TRIGGER` retirés aux rôles clients.
--
-- LE DÉFAUT
-- Supabase pose `ALTER DEFAULT PRIVILEGES … GRANT ALL ON TABLES TO anon,
-- authenticated` : toute table du schéma `public` naît avec les sept verbes
-- pour les deux rôles. Les passes précédentes ont resserré ce que l'app
-- utilise (`UPDATE` de `messages`, 20260916210000 ; tout `mls_*` pour
-- `authenticated`, 20260915230000), et laissé le reste ouvert :
--   · `TRUNCATE` IGNORE la RLS — aucune policy ne le retient. Un seul
--     `TRUNCATE messages` vide la messagerie de tout le monde. PostgREST ne
--     l'expose pas : la porte est fermée aujourd'hui, elle s'ouvrirait au
--     premier `SECURITY INVOKER` qui tronque, ou au premier accès SQL direct ;
--   · `REFERENCES` permet de créer une clé étrangère vers la table, donc de
--     bloquer ses suppressions ; `TRIGGER` d'y attacher un déclencheur.
-- L'app n'emploie aucun des trois (audit du 2026-10-03, P2).
--
-- LE CORRECTIF
-- Retrait de ces trois verbes, aux deux rôles, sur chaque table de la
-- messagerie qui existe. SELECT, INSERT, UPDATE et DELETE ne bougent pas :
-- ils portent l'app, et la RLS les borne.
--
-- Banc : tools/rls_tests/messagerie_sans_truncate.sql

DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'messages', 'conversations', 'group_members', 'group_pinned_items',
    'conversation_devices',
    'mls_messages', 'mls_commits', 'mls_welcomes', 'mls_devices',
    'mls_key_packages', 'mls_diagnostics',
    'mls_message_hidden', 'mls_message_mentions', 'mls_message_reactions',
    'mls_message_receipts', 'mls_message_stars'
  ] LOOP
    -- Une table absente (environnement partiel) n'arrête pas la migration :
    -- `db push` bloquerait sinon tout ce qui suit dans la file.
    CONTINUE WHEN to_regclass('public.' || v_table) IS NULL;
    EXECUTE format(
      'REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.%I FROM anon, authenticated',
      v_table);
  END LOOP;
END;
$$;
