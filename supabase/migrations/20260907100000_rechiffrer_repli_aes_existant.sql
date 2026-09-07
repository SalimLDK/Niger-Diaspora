-- =============================================================================
-- Rechiffrement de l'existant avec les cles derivees (etape 6)
--
-- Les messages deja en base sont chiffres avec la cle globale, celle qui est
-- une constante du binaire client. La lecture a deux cles les garde lisibles,
-- donc rien n'est casse -- mais tant qu'ils restent dans cet etat, ils sont
-- lisibles par QUICONQUE possede l'APK. Les rechiffrer avec la cle derivee de
-- leur conversation est ce qui rend la confidentialite effective sur le passe,
-- pas seulement sur les nouveaux messages.
--
-- Le moment est choisi : 32 messages concernes aujourd'hui. Dans six mois ce
-- sera un tout autre chantier, avec un vrai risque de rechiffrement partiel.
--
-- Valide AVANT ecriture, sur les donnees reelles, en lecture seule :
-- l'aller-retour complet (dechiffrer avec la cle globale -> rechiffrer avec la
-- cle derivee -> redechiffrer) rendait le texte d'origine pour 32 messages
-- sur 32.
--
-- Ce qui est volontairement HORS PERIMETRE
-- ----------------------------------------
-- SEUL `data->>'content'` des messages est rechiffre. Les autres champs
-- chiffres avec la meme cle globale -- `lastMessage` des conversations, la
-- latitude/longitude/adresse des messages de position, les comptes de paiement
-- -- sont lus cote client par `decryptText`, un chemin qui ne connait QUE la
-- cle globale. Les rechiffrer ici les rendrait illisibles dans l'application,
-- sans la moindre erreur : juste des champs vides ou « [Message illisible] ».
-- Ils suivront quand leur chemin de lecture saura lire les deux formats.
--
-- Trois garde-fous
-- ----------------
-- 1. Un message dont le dechiffrement echoue n'est PAS touche. Mieux vaut le
--    laisser sur l'ancienne cle que d'ecrire un contenu qu'on n'a pas su lire.
-- 2. Idempotent : le filtre exclut ce qui est deja au format « v<n>: ». Rejouer
--    la migration ne double-chiffre rien.
-- 3. Un IV aleatoire PAR MESSAGE (`gen_random_bytes`). Reutiliser un IV en CBC
--    laisse fuir l'egalite des prefixes entre messages.
-- =============================================================================

DO $mig$
DECLARE
  v_version  CONSTANT INT := 1;  -- doit valoir AES_KEY_VERSION des Edge Functions
  v_traites  INT := 0;
  v_restants INT := 0;
BEGIN
  -- La racine doit etre lisible, sinon `derive_aes_key` rend NULL et
  -- `encrypt_iv` echouerait sur toute la table. Sortir proprement vaut mieux
  -- que faire echouer `db push` et bloquer la file de migrations derriere soi.
  IF public.aes_root_key(v_version) IS NULL THEN
    RAISE WARNING
      'Rechiffrement ignore : racine aes_root_key_v% absente du Vault. '
      'La poser puis rejouer ce bloc -- la migration est idempotente.',
      v_version;
    RETURN;
  END IF;

  WITH candidats AS (
    SELECT
      m.id,
      m.conversation_id,
      public.decrypt_aes_fallback(m.data->>'content') AS texte
    FROM messages m
    WHERE m.data->>'encryptionLevel' = 'aes'
      AND m.conversation_id IS NOT NULL
      AND position(':' in COALESCE(m.data->>'content', '')) > 0
      -- Exactement deux segments = format herite « iv:ct ». Ecarte du meme coup
      -- « v<n>:iv:ct » (deja fait) et « gcm:… » (illisible par construction).
      AND split_part(m.data->>'content', ':', 3) = ''
  ),
  lisibles AS (
    SELECT
      c.id,
      c.texte,
      public.derive_aes_key('conv:' || c.conversation_id, v_version) AS cle,
      extensions.gen_random_bytes(16) AS iv
    FROM candidats c
    WHERE c.texte IS NOT NULL AND c.texte <> ''
  ),
  maj AS (
    UPDATE messages m
    SET data = jsonb_set(
      m.data,
      '{content}',
      to_jsonb(
        'v' || v_version || ':' ||
        encode(l.iv, 'base64') || ':' ||
        encode(
          extensions.encrypt_iv(convert_to(l.texte, 'UTF8'), l.cle, l.iv, 'aes-cbc/pad:pkcs'),
          'base64'
        )
      )
    )
    FROM lisibles l
    WHERE m.id = l.id AND l.cle IS NOT NULL
    RETURNING m.id
  )
  SELECT count(*) INTO v_traites FROM maj;

  SELECT count(*) INTO v_restants
  FROM messages m
  WHERE m.data->>'encryptionLevel' = 'aes'
    AND position(':' in COALESCE(m.data->>'content', '')) > 0
    AND split_part(m.data->>'content', ':', 3) = '';

  RAISE NOTICE 'Rechiffrement : % message(s) passe(s) en cle derivee, % encore sur la cle globale.',
    v_traites, v_restants;

  -- Ce qui reste n'est pas une anomalie en soi : message sans conversation, ou
  -- contenu que la cle globale ne dechiffre pas (ecrit avec une autre cle, ou
  -- corrompu). Le signaler suffit -- y toucher serait pire.
  IF v_restants > 0 THEN
    RAISE WARNING 'Ces % message(s) restent lisibles (lecture a deux cles), mais avec la cle de l''APK.',
      v_restants;
  END IF;
END $mig$;
