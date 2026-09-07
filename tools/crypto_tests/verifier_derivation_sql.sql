-- Confronte la dérivation HKDF de Postgres aux vecteurs de référence.
--
--   supabase db query --linked "$(cat tools/crypto_tests/verifier_derivation_sql.sql)"
--
-- Toutes les lignes doivent afficher `concorde = true`. Une seule ligne à
-- `false` signifie que Postgres et l'Edge Function ne dérivent plus la même
-- clé — et ça ne se verrait autrement qu'à l'usage, sous la forme d'aperçus de
-- notification devenus génériques, sans la moindre erreur nulle part.
--
-- Les valeurs attendues viennent de `vecteurs_derivation.json`, produit par
-- `node tools/crypto_tests/derivation_croisee.mjs --ecrire`. Si ce fichier est
-- régénéré, reporter les nouvelles valeurs ici : rien ne synchronise les deux
-- automatiquement (le SQL ne sait pas lire le JSON).
--
-- La racine ci-dessous est FACTICE et ne doit jamais être celle de production :
-- ce test vérifie le schéma de dérivation, pas le secret.
--
-- Ce banc n'appelle volontairement PAS `public.derive_aes_key()` : celle-ci lit
-- la vraie racine dans le Vault, donc ne peut pas être exercée sur des vecteurs
-- publics. Il rejoue son calcul à l'identique — les deux doivent donc être
-- modifiés ensemble, et c'est le seul endroit du chantier où une copie subsiste.

WITH p AS (
  SELECT
    'racine-de-test-jamais-en-production--'::text AS racine,
    'diaspo-niger-repli-aes'::text               AS sel
),
prk AS (
  SELECT extensions.hmac(convert_to(racine, 'UTF8'), convert_to(sel, 'UTF8'), 'sha256') AS k
  FROM p
),
cas(info, attendu) AS (
  VALUES
    ('user:11111111-1111-4111-8111-111111111111', 'KQuq9ybZ5q02H7QVti8pfeUbchJ62piGWSJoIzIn8Bg='),
    ('user:22222222-2222-4222-8222-222222222222', 'QnA8vVhGSIuNWY9iZXXS05wHMCihc5B+RfNzysz49iI='),
    ('conv:33333333-3333-4333-8333-333333333333', 'hwlJ8pZUFWXjZuD+0HY0hSMnZFBmc0MFmNykRrj5FLo='),
    -- Id hérité de Firestore : 20 caractères, pas un uuid. Ces conversations
    -- existent encore, la dérivation ne doit faire aucune hypothèse de format.
    ('conv:AbCdEfGhIjKlMnOpQrSt',                 'ZNK1UIbX/HbS2kqjZYjfZOCa8v//q1U9YW7gQUA5fmQ='),
    -- Non-ASCII : les trois implémentations doivent s'accorder sur les octets
    -- UTF-8, pas sur les caractères.
    ('conv:Maïdaoua-Niamey-🔐',                   'FjL+ZJS8CkhK1jx4YllJ/YAsuoxl49mRwEZP9FP7hzM=')
)
SELECT
  cas.info,
  encode(
    extensions.hmac(convert_to(cas.info, 'UTF8') || '\x01'::bytea, prk.k, 'sha256'),
    'base64'
  ) = cas.attendu AS concorde
FROM cas, prk;
