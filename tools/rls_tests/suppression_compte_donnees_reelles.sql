-- Répétition de la purge d'un compte SUR DES DONNÉES RÉELLES, transaction ANNULÉE.
--
--   supabase db query --linked -o csv -f tools/rls_tests/suppression_compte_donnees_reelles.sql
--
-- ⚠️ CE FICHIER EXÉCUTE LA PURGE D'UN VRAI COMPTE DE PRODUCTION. Rien n'en
-- survit : tout est entre le `BEGIN;` du haut et le `ROLLBACK;` du bas, et un
-- échec en cours de route annule aussi. NE JAMAIS retirer le `ROLLBACK;`, ni
-- le remplacer par un `COMMIT;` : ce serait la suppression réelle et
-- irréversible du compte choisi (le compte Firebase resterait, la ligne
-- `users` non).
--
-- Elle exige la migration 20260918224100 APPLIQUÉE (les fonctions existent).
--
-- POURQUOI CE FICHIER EXISTE
-- Le banc `suppression_compte.sql` prouve la purge sur un monde FICTIF ; il ne
-- peut pas prouver qu'elle va au bout sur les formes réelles de la base (un
-- tableau JSON qui serait un objet, une colonne dont le type a dérivé, une
-- clé étrangère oubliée). Ici la purge tourne sur le compte le plus chargé —
-- celui qui a le plus de messages, de notifications et de groupes — hors
-- compte plateforme.
--
-- Le classifieur de permissions de Claude Code refuse de la lancer (« Modify
-- Shared Resources »), même annulée et même sur votre accord donné dans la
-- conversation : à lancer depuis VOTRE terminal.
--
-- CE QU'ON LIT DANS LA SORTIE
--   RESULTAT     `ok` doit valoir true. `summary` donne, par famille, le nombre
--                de lignes traitées. Si `ok` vaut false, `error` dit pourquoi :
--                c'est exactement ce que la vraie purge rencontrerait — à
--                corriger par une nouvelle migration AVANT le premier compte
--                dû (il n'y en a aucun avant 30 jours).
--   RESTE        toutes les tables dont au moins une ligne CONTIENT encore
--                l'uid, en texte, avant et après. Une table qui garde des
--                lignes après la purge est soit une rétention voulue, soit une
--                colonne oubliée — c'est la mesure que le banc fictif ne peut
--                pas faire. Attendu : `account_deletion_requests` (la pierre
--                tombale, qui porte l'uid par construction).
--   ACCOUNT_REQ  la demande à l'issue de la purge : `completed`, sans erreur.
--
-- Aucun uid n'est imprimé : seulement des noms de tables et des compteurs.

BEGIN;

CREATE TEMP TABLE _cible AS
SELECT s.uid, s.poids FROM (
  SELECT u.id AS uid,
         (SELECT count(*) FROM public.messages m WHERE m.sender_id = u.id)
       + (SELECT count(*) FROM public.mls_messages m WHERE m.sender_id = u.id)
       + (SELECT count(*) FROM public.notifications n WHERE n.user_id = u.id)
       + (SELECT count(*) FROM public.group_members gm WHERE gm.user_id = u.id) * 10 AS poids
    FROM public.users u
   WHERE NOT EXISTS (SELECT 1 FROM public.groups g WHERE g.creator_id = u.id AND g.is_official)
) s ORDER BY s.poids DESC LIMIT 1;

-- Comptage, par table, des lignes dont la représentation texte contient l'uid
-- (attrape colonnes text/uuid, tableaux et jsonb d'un coup).
CREATE TEMP TABLE _avant AS
SELECT t.table_name AS tbl,
       (xpath('/row/c/text()', query_to_xml(
          format('select count(*) as c from public.%I t where t::text like %L', t.table_name, '%' || (SELECT uid FROM _cible) || '%'),
          false, true, '')))[1]::text::int AS n
  FROM information_schema.tables t
 WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE';

-- La demande est posée à la main, comme le ferait `claim_due_account_deletions`.
INSERT INTO public.account_deletion_requests (user_id, status, execute_at, started_at, attempts)
SELECT uid, 'deleting', now(), now(), 1 FROM _cible;

CREATE TEMP TABLE _res AS SELECT public.complete_account_deletion((SELECT uid FROM _cible)) AS j;

CREATE TEMP TABLE _apres AS
SELECT t.table_name AS tbl,
       (xpath('/row/c/text()', query_to_xml(
          format('select count(*) as c from public.%I t where t::text like %L', t.table_name, '%' || (SELECT uid FROM _cible) || '%'),
          false, true, '')))[1]::text::int AS n
  FROM information_schema.tables t
 WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE';

SELECT 0 AS ordre, 'RESULTAT' AS k, (SELECT 'poids=' || poids::text FROM _cible) AS a,
       (SELECT j::text FROM _res) AS b, '' AS c
UNION ALL
SELECT 1, 'RESTE', a.tbl, 'avant=' || a.n::text, 'apres=' || p.n::text
  FROM _avant a JOIN _apres p USING (tbl)
 WHERE a.n > 0 OR p.n > 0
UNION ALL
SELECT 2, 'ACCOUNT_REQ', status, COALESCE(last_error, 'aucune erreur'), ''
  FROM public.account_deletion_requests WHERE user_id = (SELECT uid FROM _cible)
ORDER BY 1, 2, 3;

ROLLBACK;
