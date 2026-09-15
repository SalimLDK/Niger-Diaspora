-- Banc des métadonnées en ligne MLS (migration 20260915200000).
--
--   supabase db query -f tools/mls_banc/metadonnees_en_ligne.sql --linked
--
-- Tout se joue dans une transaction annulée : la production ne garde rien,
-- et le banc peut donc tourner sur la vraie base. Aucune sortie = tout est
-- passé ; la première assertion fausse remonte en exception nommée (A1…D5).
--
-- POURQUOI EN `authenticated` ET PAS EN POSTGRES
-- `db query --linked` se connecte en postgres, qui CONTOURNE le RLS : un banc
-- écrit sans `SET LOCAL ROLE authenticated` passerait quoi qu'on mette dans
-- les policies. Les sections B, C et D changent donc de rôle et de
-- `request.jwt.claims` à chaque personnage.
--
-- CE QU'IL MESURE PLUTÔT QUE CE QU'IL AFFIRME
-- La section D mesure ce qu'une étrangère à la conversation LIT — 0 ligne,
-- pas une erreur. C'est la forme muette des refus Supabase : un banc qui
-- n'attendrait que des exceptions ne verrait jamais une fuite de lecture.
--
-- Vérifié le 2026-09-15 en cassant deux fois la migration à dessein :
-- sans le retrait de `data.lastMessage`, A5 tombe ; avec la lecture des
-- reçus ouverte à tous (`USING (true)`), D2 tombe.

BEGIN;

DO $banc$
DECLARE
  v_conv  text := 'conv_banc_metadonnees';
  v_alice text := 'u_banc_alice';
  v_bob   text := 'u_banc_bob';
  v_carol text := 'u_banc_carol';
  v_dev   uuid;
  v_msg   uuid := gen_random_uuid();
  v_ctrl  uuid := gen_random_uuid();
  v_n     bigint;
  v_txt   text;
  v_data  jsonb;
BEGIN
  -- ── Fixtures, posées en postgres ────────────────────────────────────────
  INSERT INTO public.conversations (id, type, participant_ids, created_by, created_at, data)
  VALUES (v_conv, 'individual', ARRAY[v_alice, v_bob], v_alice, now(),
          jsonb_build_object('lastMessage', 'aperçu en clair du legacy',
                             'lastMessageType', 'text',
                             'lastMessageReadBy', jsonb_build_array(v_alice, v_bob)));

  INSERT INTO public.mls_devices (user_id, stable_id, name, platform, mls_identity,
                                  signature_key, credential)
  VALUES (v_alice, 'banc-alice', 'Banc', 'android', v_alice || ':banc-alice',
          decode('00', 'hex'), decode('00', 'hex'))
  RETURNING id INTO v_dev;

  -- ════════════════════════════════════════════════════════════════════════
  -- A. Le déclencheur d'aperçu
  -- ════════════════════════════════════════════════════════════════════════

  INSERT INTO public.mls_messages (id, conversation_id, sender_id, sender_device_id,
                                   epoch, kind, content_type, ciphertext)
  VALUES (v_msg, v_conv, v_alice, v_dev, 1, 'content', 'media', decode('01', 'hex'));

  SELECT data INTO v_data FROM public.conversations WHERE id = v_conv;

  IF (SELECT last_message_id FROM public.conversations WHERE id = v_conv) IS DISTINCT FROM v_msg THEN
    RAISE EXCEPTION 'A1 ÉCHEC: last_message_id non posé';
  END IF;
  IF (SELECT last_message_kind FROM public.conversations WHERE id = v_conv) <> 'media' THEN
    RAISE EXCEPTION 'A2 ÉCHEC: last_message_kind = %',
      (SELECT last_message_kind FROM public.conversations WHERE id = v_conv);
  END IF;
  IF (SELECT last_message_sender_id FROM public.conversations WHERE id = v_conv) <> v_alice THEN
    RAISE EXCEPTION 'A3 ÉCHEC: last_message_sender_id non posé';
  END IF;
  IF (SELECT last_message_at FROM public.conversations WHERE id = v_conv) IS NULL THEN
    RAISE EXCEPTION 'A4 ÉCHEC: last_message_at non posé';
  END IF;
  IF v_data ? 'lastMessage' THEN
    RAISE EXCEPTION 'A5 ÉCHEC: l''aperçu en clair du legacy a survécu à la bascule';
  END IF;
  IF v_data->>'lastMessageType' <> 'file' THEN
    RAISE EXCEPTION 'A6 ÉCHEC: lastMessageType = % (attendu file pour media)',
      v_data->>'lastMessageType';
  END IF;
  IF v_data->'lastMessageReadBy' <> jsonb_build_array(v_alice) THEN
    RAISE EXCEPTION 'A7 ÉCHEC: lastMessageReadBy non remis à l''expéditeur seul: %',
      v_data->'lastMessageReadBy';
  END IF;

  -- Un contrôle ne remonte pas la conversation dans la liste.
  SELECT last_message_id INTO v_txt FROM public.conversations WHERE id = v_conv;
  INSERT INTO public.mls_messages (id, conversation_id, sender_id, sender_device_id,
                                   epoch, kind, content_type, ciphertext)
  VALUES (v_ctrl, v_conv, v_alice, v_dev, 1, 'control', 'text', decode('02', 'hex'));
  IF (SELECT last_message_id FROM public.conversations WHERE id = v_conv)::text <> v_txt THEN
    RAISE EXCEPTION 'A8 ÉCHEC: un message de contrôle a bougé l''aperçu';
  END IF;

  -- ════════════════════════════════════════════════════════════════════════
  -- B. Le RLS, joué en `authenticated` — jamais en postgres, qui le contourne
  -- ════════════════════════════════════════════════════════════════════════

  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid', v_bob))::text, true);
  SET LOCAL ROLE authenticated;

  IF public.firebase_uid() <> v_bob THEN
    RAISE EXCEPTION 'B0 ÉCHEC: firebase_uid() = % au lieu de %', public.firebase_uid(), v_bob;
  END IF;

  -- B1 — Bob pose son reçu de livraison, puis de lecture.
  INSERT INTO public.mls_message_receipts (message_id, user_id, delivered_at)
  VALUES (v_msg, v_bob, now());

  -- B2 — Bob ne pose pas le reçu d'Alice.
  BEGIN
    INSERT INTO public.mls_message_receipts (message_id, user_id, delivered_at)
    VALUES (v_msg, v_alice, now());
    RAISE EXCEPTION 'B2 ÉCHEC: Bob a posé le reçu d''Alice';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- B3 — Bob réagit, étoile et masque pour lui seul.
  INSERT INTO public.mls_message_reactions (message_id, user_id, emoji) VALUES (v_msg, v_bob, '👍');
  INSERT INTO public.mls_message_stars (message_id, user_id) VALUES (v_msg, v_bob);

  -- B4 — Bob n'est pas l'expéditeur : il ne pose pas de mention.
  BEGIN
    INSERT INTO public.mls_message_mentions (message_id, user_id) VALUES (v_msg, v_bob);
    RAISE EXCEPTION 'B4 ÉCHEC: un non-expéditeur a posé une mention';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- ── C. La vue, vue par Bob ──────────────────────────────────────────────
  SELECT unread INTO v_n FROM public.mls_unread_counts
   WHERE conversation_id = v_conv AND user_id = v_bob;
  IF COALESCE(v_n, -1) <> 1 THEN
    RAISE EXCEPTION 'C1 ÉCHEC: non-lus de Bob = % (attendu 1)', COALESCE(v_n, -1);
  END IF;

  -- ── Alice, expéditrice : elle pose la mention, et ne se compte pas ───────
  RESET ROLE;
  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid', v_alice))::text, true);
  SET LOCAL ROLE authenticated;

  INSERT INTO public.mls_message_mentions (message_id, user_id) VALUES (v_msg, v_bob);

  SELECT count(*) INTO v_n FROM public.mls_unread_counts WHERE conversation_id = v_conv;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'C2 ÉCHEC: l''expéditrice se compte % non-lus', v_n;
  END IF;

  -- Alice ne voit ni le masquage, ni les favoris de Bob.
  SELECT count(*) INTO v_n FROM public.mls_message_stars;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'C3 ÉCHEC: Alice voit % favori(s) de Bob', v_n;
  END IF;
  -- Mais elle voit sa réaction : c'est le contrat des réactions.
  SELECT count(*) INTO v_n FROM public.mls_message_reactions WHERE message_id = v_msg;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'C4 ÉCHEC: Alice voit % réaction(s), attendu 1', v_n;
  END IF;

  -- ── Retour chez Bob : mention comptée, puis lecture, puis masquage ───────
  RESET ROLE;
  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid', v_bob))::text, true);
  SET LOCAL ROLE authenticated;

  SELECT unread_mentions INTO v_n FROM public.mls_unread_counts
   WHERE conversation_id = v_conv AND user_id = v_bob;
  IF COALESCE(v_n, -1) <> 1 THEN
    RAISE EXCEPTION 'C5 ÉCHEC: mentions non lues = % (attendu 1)', COALESCE(v_n, -1);
  END IF;

  UPDATE public.mls_message_receipts SET read_at = now()
   WHERE message_id = v_msg AND user_id = v_bob;
  SELECT unread INTO v_n FROM public.mls_unread_counts
   WHERE conversation_id = v_conv AND user_id = v_bob;
  IF COALESCE(v_n, -1) <> 0 THEN
    RAISE EXCEPTION 'C6 ÉCHEC: après lecture, non-lus = % (attendu 0)', COALESCE(v_n, -1);
  END IF;

  INSERT INTO public.mls_message_hidden (message_id, user_id) VALUES (v_msg, v_bob);
  SELECT count(*) INTO v_n FROM public.mls_unread_counts WHERE conversation_id = v_conv;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'C7 ÉCHEC: un message masqué compte encore (% ligne(s))', v_n;
  END IF;

  -- ── D. Carol, étrangère à la conversation, ne lit RIEN ───────────────────
  -- Le refus est muet : ce sont des 0 lignes, pas des erreurs (7e forme des
  -- échecs muets Supabase). C'est exactement pour ça qu'on le mesure.
  RESET ROLE;
  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid', v_carol))::text, true);
  SET LOCAL ROLE authenticated;

  SELECT count(*) INTO v_n FROM public.mls_message_reactions WHERE message_id = v_msg;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'D1 ÉCHEC: une étrangère lit % réaction(s)', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.mls_message_receipts WHERE message_id = v_msg;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'D2 ÉCHEC: une étrangère lit % reçu(s)', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.mls_message_mentions WHERE message_id = v_msg;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'D3 ÉCHEC: une étrangère lit % mention(s)', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.mls_unread_counts;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'D4 ÉCHEC: une étrangère lit % ligne(s) de compteurs', v_n;
  END IF;

  -- D5 — et elle ne pose pas de réaction sur un message qui ne la regarde pas.
  BEGIN
    INSERT INTO public.mls_message_reactions (message_id, user_id, emoji)
    VALUES (v_msg, v_carol, '🔥');
    RAISE EXCEPTION 'D5 ÉCHEC: une étrangère a réagi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  RESET ROLE;
END
$banc$;

ROLLBACK;
