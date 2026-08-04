-- Audit des horodatages écrits sans suffixe de fuseau (2026-08-04)
--
-- Contexte : jusqu'au correctif `fix(dates)`, plusieurs écritures client
-- sérialisaient un `DateTime` **local** avec `toIso8601String()` nu, donc sans
-- suffixe de fuseau. Postgres interprète une telle chaîne dans le fuseau de la
-- session (UTC chez Supabase) : l'heure locale de l'appareil a été enregistrée
-- comme si c'était de l'UTC. La valeur en base est décalée du décalage horaire
-- de l'utilisateur au moment de l'écriture.
--
-- À exécuter dans l'éditeur SQL Supabase (rôle `postgres`, RLS contournée).
-- Tout est en LECTURE SEULE : aucun UPDATE, aucun DELETE.

-- ═══════════════════════════════════════════════════════════════════
-- 1. Confirmer la prémisse
-- ═══════════════════════════════════════════════════════════════════
-- Si `TimeZone` vaut UTC, une chaîne nue est bien lue comme de l'UTC et tout
-- ce qui suit s'applique. Sinon, le décalage constaté sera différent.
SHOW timezone;

-- Preuve directe : les deux formes doivent donner le MÊME instant. Si elles
-- diffèrent, c'est exactement le bug (la première est la forme qui était
-- envoyée, la seconde la forme correcte).
SELECT
  '2026-08-04T02:01:00'::timestamptz   AS chaine_nue_telle_qu_envoyee,
  '2026-08-04T06:01:00Z'::timestamptz  AS instant_reel_a_toronto,
  '2026-08-04T06:01:00Z'::timestamptz
    - '2026-08-04T02:01:00'::timestamptz AS ecart;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Lignes logiquement impossibles
-- ═══════════════════════════════════════════════════════════════════
-- Méthode : comparer une colonne écrite par le CLIENT (donc suspecte) à une
-- colonne posée par le SERVEUR sur la même ligne (`DEFAULT NOW()`, fiable).
-- Une action ne peut pas précéder la création de sa propre ligne : chaque
-- ligne trouvée est une preuve directe de corruption, et l'écart mesure le
-- décalage horaire de l'utilisateur.
--
-- Limite importante : ne détecte que les utilisateurs à l'OUEST d'UTC
-- (Amériques). À l'est (Paris, Niamey), le décalage pousse la valeur vers
-- l'avant et ne viole aucun ordre — invisible par cette méthode.
--
-- Les tables absentes sont ignorées (le schéma distant a dérivé du dépôt).

-- `pg_temp.` explicite : sans lui, un `DROP TABLE IF EXISTS resultat_audit_fuseau`
-- se résout via le search_path et pourrait viser une table réelle de `public`.
DROP TABLE IF EXISTS pg_temp.resultat_audit_fuseau;
CREATE TEMP TABLE resultat_audit_fuseau (
  cible          text,
  lignes_ko      bigint,
  ecarts_heures  text
);

DO $$
DECLARE
  n       bigint;
  ecarts  text;
  cibles  constant text[][] := ARRAY[
    -- [table,                colonne client,         colonne serveur]
    ['group_invites',        'responded_at',          'created_at'],
    ['group_requests',       'processed_at',          'created_at'],
    ['podcast_episodes',     'published_at',          'created_at'],
    ['user_sticker_packs',   'added_at',              'created_at'],
    ['payment_accounts',     'updated_at',            'created_at'],
    ['support_tickets',      'updated_at',            'created_at'],
    ['reports',              'reviewed_at',           'created_at'],
    ['conversations',        'last_message_at',       'created_at'],
    ['post_polls',           'ends_at',               'created_at'],
    ['users',                'last_seen_at',          'created_at'],
    ['users',                'last_active_at',        'created_at'],
    ['users',                'location_updated_at',   'created_at'],
    ['users',                'banned_at',             'created_at'],
    ['users',                'verified_at',           'created_at']
  ];
BEGIN
  FOR i IN 1 .. array_length(cibles, 1) LOOP
    -- Table ou colonnes absentes : on passe sans faire échouer l'audit.
    CONTINUE WHEN to_regclass('public.' || cibles[i][1]) IS NULL;
    CONTINUE WHEN NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = cibles[i][1]
        AND column_name IN (cibles[i][2], cibles[i][3])
      GROUP BY table_name HAVING count(*) = 2
    );

    EXECUTE format(
      'SELECT count(*),
              coalesce(string_agg(DISTINCT h::text, '', '' ORDER BY h::text), ''-'')
       FROM (SELECT round(extract(epoch FROM (%2$I - %1$I)) / 3600) AS h
             FROM public.%3$I
             WHERE %1$I IS NOT NULL AND %2$I IS NOT NULL AND %1$I < %2$I) s',
      cibles[i][2], cibles[i][3], cibles[i][1]
    ) INTO n, ecarts;

    IF n > 0 THEN
      INSERT INTO resultat_audit_fuseau
      VALUES (cibles[i][1] || '.' || cibles[i][2], n, ecarts);
    END IF;
  END LOOP;
END $$;

-- Résultat de l'étape 2. Zéro ligne = aucune preuve directe — ce qui ne veut
-- pas dire « aucune corruption » : voir la limite est/ouest ci-dessus.
SELECT * FROM resultat_audit_fuseau ORDER BY lignes_ko DESC;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Signature statistique (détecte aussi l'est d'UTC)
-- ═══════════════════════════════════════════════════════════════════
-- Un décalage de fuseau tombe TOUJOURS sur un multiple de 15 minutes, et en
-- pratique sur une heure pleine. Un écart légitime, lui, est réparti au
-- hasard. Si les écarts se concentrent sur des valeurs entières (-5, -4, +1,
-- +2…) plutôt que d'être étalés, c'est la signature du bug.
--
-- Adapter le nom de table selon ce que l'étape 2 a signalé.
SELECT
  round(extract(epoch FROM (created_at - last_seen_at)) / 3600) AS ecart_heures,
  count(*)                                                      AS lignes
FROM public.users
WHERE last_seen_at IS NOT NULL
  AND created_at IS NOT NULL
GROUP BY 1
ORDER BY lignes DESC
LIMIT 30;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Ce qui n'est PAS touché — ne pas corriger par erreur
-- ═══════════════════════════════════════════════════════════════════
-- - Toute colonne alimentée par `DEFAULT NOW()` : posée par le serveur, juste
--   depuis toujours. C'est le cas de `posts.created_at` — la publication de
--   02:01 affichée « 06:01 » était un bug d'AFFICHAGE, pas de donnée.
-- - `messages.created_at` : le datasource Supabase utilisait déjà `.toUtc()`.
-- - Firestore et RTDB : les `DateTime` y partent en objets `Timestamp`, qui
--   stockent un instant absolu. Aucun décalage possible.
