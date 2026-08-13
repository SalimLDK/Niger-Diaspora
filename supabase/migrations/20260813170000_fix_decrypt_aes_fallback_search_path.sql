-- =============================================================================
-- Corrige 20260813160000 : l'aperçu en clair du repli AES échouait en
-- silence dans le vrai flux (trigger), pas en requête ad hoc.
--
-- Constat : `decrypt_aes_fallback('bQpENo97WIJrZnzFqC1PCQ==:C4VA0h+1EHiFlYGwjEcqfw==')`
-- rend bien « Yo » appelée directement, et
-- `message_preview_for_notification('text', m.data)` aussi — mais un vrai
-- message envoyé par Salim (repli AES confirmé, encryptionLevel='aes') a
-- produit une notification avec le générique « 🔒 Nouveau message ».
--
-- Cause : `pgcrypto` est installé dans le schéma `extensions` sur ce projet
-- (pas `public`) — vérifié : `select decrypt_iv → extensions.decrypt_iv`.
-- Une session `db query` ordinaire a `search_path = "$user", public,
-- extensions` et trouve `decrypt_iv` sans réfléchir. Mais
-- `notify_recipients_on_message_insert` pose délibérément
-- `SET search_path = public` (durcissement standard contre l'injection de
-- search_path sur une fonction SECURITY DEFINER) — et cette restriction se
-- propage à tout ce qu'elle appelle : `message_preview_for_notification`
-- puis `decrypt_aes_fallback`, ni l'une ni l'autre n'ayant leur propre
-- `SET search_path`, héritent du `public` seul du trigger. `decrypt_iv`
-- devient donc introuvable **uniquement dans ce chemin d'appel** — et le
-- `EXCEPTION WHEN OTHERS THEN RETURN NULL` de `decrypt_aes_fallback`
-- avalait l'erreur en silence, retombant sur le générique. D'où l'écart
-- entre le test manuel (toujours réussi) et le vrai flux (toujours échoué).
--
-- Correctif : `decrypt_aes_fallback` fixe désormais explicitement son
-- propre `search_path` sur `public, extensions`, indépendamment de ce que
-- lui impose son appelant.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.decrypt_aes_fallback(p_content TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public, extensions
AS $$
DECLARE
  v_iv_b64 TEXT;
  v_ct_b64 TEXT;
  v_plain  TEXT;
BEGIN
  IF p_content IS NULL OR position(':' in p_content) = 0 THEN
    RETURN NULL;
  END IF;

  v_iv_b64 := split_part(p_content, ':', 1);
  v_ct_b64 := split_part(p_content, ':', 2);

  IF v_iv_b64 = '' OR v_ct_b64 = '' THEN
    RETURN NULL;
  END IF;

  BEGIN
    v_plain := convert_from(
      decrypt_iv(
        decode(v_ct_b64, 'base64'),
        'DiaspoNigerSecureKey2025ForApps!'::bytea,
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

REVOKE ALL ON FUNCTION public.decrypt_aes_fallback(TEXT) FROM PUBLIC, anon, authenticated;
