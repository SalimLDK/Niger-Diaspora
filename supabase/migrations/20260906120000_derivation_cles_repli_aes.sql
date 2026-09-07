-- =============================================================================
-- Dérivation SQL des clés du repli AES (étape 5a)
--
-- Le repli AES chiffrait tout avec UNE clé globale, constante du binaire client.
-- Conséquence : qui extrait la clé de l'APK lit le trafic AES de tout le monde,
-- et changer la clé impose de republier l'application.
--
-- Le chantier remplace ça par des clés dérivées d'une racine qui reste côté
-- serveur. Cette migration apprend à Postgres à dériver la même clé que
-- l'Edge Function `crypto-keys`, pour qu'il puisse continuer à fabriquer les
-- aperçus de notification en clair — ce que l'E2EE Signal, lui, interdit par
-- construction.
--
-- Ce que cette migration NE fait PAS, volontairement
-- --------------------------------------------------
-- Elle ne touche ni au trigger `notify_recipients_on_message_insert`, ni à la
-- signature de `message_preview_for_notification`. Tant que l'identifiant de
-- conversation ne descend pas jusqu'ici (étape 5b), un message au NOUVEAU
-- format retombera sur l'aperçu générique « 🔒 Nouveau message » — jamais sur
-- du base64, et jamais sur une erreur. L'existant, lui, continue d'être
-- déchiffré exactement comme avant.
--
-- Cet ordre est délibéré : le client ne produit pas encore le nouveau format,
-- donc câbler le trigger maintenant reviendrait à modifier trois fonctions en
-- cascade pour un chemin que rien n'emprunte.
--
-- Deux règles que cette migration s'impose
-- ----------------------------------------
-- 1. **Racine absente = NULL**, jamais une clé de substitution. Une clé par
--    défaut remettrait deux clés en circulation, et le symptôme n'apparaîtrait
--    que des semaines plus tard, sous forme de contenu illisible.
-- 2. **Le schéma HKDF doit correspondre à l'octet près** à celui de
--    `supabase/functions/crypto-keys/index.ts`. Rien ne compare les deux à
--    l'exécution : un désaccord ne lève aucune erreur, le déchiffrement rend
--    simplement NULL. C'est exactement ainsi que la clé AES de Firebase
--    Functions a pu diverger pendant des mois. Le banc
--    `tools/crypto_tests/derivation_croisee.mjs` fige les vecteurs de
--    référence ; `tools/crypto_tests/verifier_derivation_sql.sql` confronte
--    cette implémentation à ces vecteurs.
-- =============================================================================

-- 1. La racine ----------------------------------------------------------------
--
-- Lue dans Supabase Vault, sous le nom `aes_root_key_v<version>`. La poser :
--
--   SELECT vault.create_secret('<valeur>', 'aes_root_key_v1',
--                              'Racine HKDF du repli AES');
--
-- Elle doit être IDENTIQUE au secret `AES_ROOT_KEY_V1` des Edge Functions —
-- c'est le seul point où les deux mondes doivent s'accorder, et rien ne le
-- vérifie automatiquement.
CREATE OR REPLACE FUNCTION public.aes_root_key(p_version INT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, vault, extensions
AS $$
DECLARE
  v_secret TEXT;
BEGIN
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'aes_root_key_v' || p_version::TEXT
  LIMIT 1;

  RETURN v_secret;  -- NULL si absente : l'appelant doit refuser, pas improviser.
EXCEPTION WHEN OTHERS THEN
  -- Vault indisponible ou droits insuffisants. Le seul comportement acceptable
  -- reste l'absence de clé.
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.aes_root_key(INT) FROM PUBLIC, anon, authenticated;

-- 2. HKDF-SHA256 --------------------------------------------------------------
--
-- RFC 5869, réduit au cas qui nous occupe : sortie de 32 octets, donc un seul
-- bloc d'expansion (T(1)), donc pas de boucle.
--
--   PRK = HMAC-SHA256(clé = sel,  données = racine)
--   OKM = HMAC-SHA256(clé = PRK,  données = info || 0x01)
--
-- Attention à `hmac(data, key, type)` : l'ordre des deux premiers arguments est
-- (données, clé), c'est-à-dire l'inverse de la façon dont on lit la RFC. Les
-- intervertir produit une clé parfaitement valide — et parfaitement fausse,
-- sans le moindre message d'erreur.
--
-- La racine est utilisée telle quelle, comme chaîne UTF-8. Elle n'est PAS
-- décodée depuis le base64, parce que l'Edge Function ne la décode pas non plus
-- (`new TextEncoder().encode(brute)`). Ce détail change entièrement la clé.
CREATE OR REPLACE FUNCTION public.derive_aes_key(p_info TEXT, p_version INT)
RETURNS BYTEA
LANGUAGE plpgsql
STABLE
SET search_path = public, extensions
AS $$
DECLARE
  -- Doit rester identique à SEL_HKDF dans crypto-keys/index.ts.
  c_sel  CONSTANT TEXT := 'diaspo-niger-repli-aes';
  v_root TEXT;
  v_prk  BYTEA;
BEGIN
  v_root := public.aes_root_key(p_version);
  IF v_root IS NULL OR p_info IS NULL THEN
    RETURN NULL;
  END IF;

  v_prk := extensions.hmac(convert_to(v_root, 'UTF8'), convert_to(c_sel, 'UTF8'), 'sha256');

  RETURN extensions.hmac(convert_to(p_info, 'UTF8') || '\x01'::BYTEA, v_prk, 'sha256');
END;
$$;

REVOKE ALL ON FUNCTION public.derive_aes_key(TEXT, INT) FROM PUBLIC, anon, authenticated;

-- 3. Déchiffrement, ancien et nouveau format ----------------------------------
--
-- La signature à un argument est remplacée par une signature à deux, dont le
-- second a une valeur par défaut : les appelants existants
-- (`message_preview_for_notification`) continuent de fonctionner sans être
-- modifiés.
--
-- Le DROP est indispensable. `CREATE OR REPLACE` ne remplace pas une fonction
-- dont la liste d'arguments diffère : les deux coexisteraient, et l'appel à un
-- seul argument deviendrait ambigu (42725) — ce qui casserait les notifications
-- de tout le monde, y compris pour des messages sans rapport avec ce chantier.
DROP FUNCTION IF EXISTS public.decrypt_aes_fallback(TEXT);
DROP FUNCTION IF EXISTS public.decrypt_aes_fallback(TEXT, TEXT);

CREATE FUNCTION public.decrypt_aes_fallback(
  p_content         TEXT,
  p_conversation_id TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public, extensions
AS $$
DECLARE
  v_iv_b64  TEXT;
  v_ct_b64  TEXT;
  v_version INT;
  v_key     BYTEA;
  v_plain   TEXT;
BEGIN
  IF p_content IS NULL OR position(':' in p_content) = 0 THEN
    RETURN NULL;
  END IF;

  -- Format hérité, clé globale : « <ivB64>:<ctB64> ».
  -- Le base64 ne contient jamais ':', donc compter les segments suffit à
  -- distinguer les formats sans ambiguïté.
  IF split_part(p_content, ':', 3) = '' THEN
    v_iv_b64 := split_part(p_content, ':', 1);
    v_ct_b64 := split_part(p_content, ':', 2);
    v_key    := 'DiaspoNigerSecureKey2025ForApps!'::BYTEA;

  -- Nouveau format, clé dérivée : « v<version>:<ivB64>:<ctB64> ».
  ELSIF left(p_content, 1) = 'v' THEN
    v_version := NULLIF(regexp_replace(split_part(p_content, ':', 1), '^v', ''), '')::INT;
    v_iv_b64  := split_part(p_content, ':', 2);
    v_ct_b64  := split_part(p_content, ':', 3);

    -- Sans identifiant de conversation, la clé ne peut pas être dérivée. C'est
    -- le cas tant que l'étape 5b n'a pas câblé le trigger : aperçu générique,
    -- pas d'erreur.
    IF p_conversation_id IS NULL OR v_version IS NULL THEN
      RETURN NULL;
    END IF;

    v_key := public.derive_aes_key('conv:' || p_conversation_id, v_version);
    IF v_key IS NULL THEN
      RETURN NULL;  -- racine absente : refuser, jamais improviser une clé.
    END IF;

  ELSE
    RETURN NULL;  -- « gcm:… » et tout autre format inconnu.
  END IF;

  IF v_iv_b64 = '' OR v_ct_b64 = '' THEN
    RETURN NULL;
  END IF;

  BEGIN
    v_plain := convert_from(
      extensions.decrypt_iv(
        decode(v_ct_b64, 'base64'),
        v_key,
        decode(v_iv_b64, 'base64'),
        'aes-cbc/pad:pkcs'
      ),
      'UTF8'
    );
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;

  RETURN v_plain;
END;
$$;

REVOKE ALL ON FUNCTION public.decrypt_aes_fallback(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.decrypt_aes_fallback(TEXT, TEXT) IS
  'Déchiffre le repli AES pour les aperçus de notification. Deux formats : '
  '« iv:ct » (clé globale héritée) et « v<n>:iv:ct » (clé dérivée par '
  'conversation, exige p_conversation_id). Rend NULL sur tout échec — jamais '
  'le ciphertext.';
