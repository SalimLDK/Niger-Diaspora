-- =============================================================================
-- Mesure du taux de fallback AES dans la messagerie (diaspo_niger)
-- =============================================================================
-- À coller dans le SQL Editor Supabase (projet zyrfkcjjrhddpfxcgezo).
--
-- Rappel architecture :
--   encryptionLevel = 'e2ee'  → Signal (1:1 e2eePayloads / groupe senderKeyPayload)
--   encryptionLevel = 'aes'   → repli clé globale ENCRYPTION_KEY
--   encryptionLevel = NULL    → legacy (messages écrits avant le champ)
--
-- Seuls les messages TEXTE sont pertinents : la localisation est AES par
-- conception (pas un fallback), les médias ont leur propre chiffrement.
-- Le vrai « échec d'établissement de session » = 1:1 texte tombé en 'aes'.
-- =============================================================================


-- 1) HEADLINE : % de fallback AES sur le texte 1:1 des 30 derniers jours
--    (fenêtre récente = reflète le comportement actuel, pas l'historique)
select
  count(*)                                                              as total_1to1_text_30d,
  count(*) filter (where m.data->>'encryptionLevel' = 'e2ee')          as e2ee,
  count(*) filter (where m.data->>'encryptionLevel' = 'aes')           as aes_fallback,
  count(*) filter (where m.data->>'encryptionLevel' is null)           as legacy_null,
  round(100.0 * count(*) filter (where m.data->>'encryptionLevel' = 'aes')
        / nullif(count(*), 0), 1)                                      as pct_aes_fallback
from messages m
join conversations c on c.id = m.conversation_id
where c.type = 'individual'
  and m.type = 'text'
  and coalesce(m.is_deleted, false) = false
  and m.created_at >= now() - interval '30 days';


-- 2) VENTILATION complète par type de conversation × niveau (tout l'historique)
select
  c.type                                             as conversation_type,
  coalesce(m.data->>'encryptionLevel', 'legacy/null') as enc_level,
  count(*)                                           as n,
  round(100.0 * count(*) / sum(count(*)) over (partition by c.type), 1) as pct_within_type
from messages m
join conversations c on c.id = m.conversation_id
where m.type = 'text'
  and coalesce(m.is_deleted, false) = false
group by c.type, coalesce(m.data->>'encryptionLevel', 'legacy/null')
order by c.type, n desc;


-- 3) TENDANCE hebdomadaire du fallback 1:1 (voir si ça s'améliore avec le temps)
select
  date_trunc('week', m.created_at)::date              as week,
  count(*)                                            as total,
  round(100.0 * count(*) filter (where m.data->>'encryptionLevel' = 'aes')
        / nullif(count(*), 0), 1)                     as pct_aes
from messages m
join conversations c on c.id = m.conversation_id
where c.type = 'individual'
  and m.type = 'text'
  and coalesce(m.is_deleted, false) = false
  and m.created_at >= now() - interval '12 weeks'
group by 1
order by 1;
