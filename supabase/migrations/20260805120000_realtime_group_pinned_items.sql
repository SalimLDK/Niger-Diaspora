-- Bandeau des éléments épinglés : le rendre réellement temps réel.
--
-- `GroupSupabaseDataSource.getPinnedItemsStream` s'abonne à un `.stream()`
-- Supabase sur `group_pinned_items`. Or la table n'a jamais été ajoutée à la
-- publication `supabase_realtime` (contrairement à `messages` et
-- `conversations`) : le stream ne faisait donc que son chargement initial et
-- ne recevait plus jamais rien ensuite. Conséquences observées :
--   * une épingle posée par un AUTRE membre (ou depuis un autre appareil)
--     n'apparaît qu'à la réouverture de la conversation ;
--   * un désépinglage distant laisse une épingle fantôme à l'écran.
-- Le `ref.invalidate` du bandeau (conversation_screen) ne masquait le trou que
-- pour l'action faite sur CE téléphone.
--
-- `replica identity full` est nécessaire en plus de la publication : le
-- `.stream()` filtre côté serveur sur `group_id` / `conversation_id`, et sous
-- l'identité par défaut un DELETE ne transporte que la clé primaire — la ligne
-- supprimée ne passerait donc jamais le filtre, et le retrait d'une épingle ne
-- serait pas propagé.

alter table public.group_pinned_items replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_pinned_items'
  ) then
    alter publication supabase_realtime add table public.group_pinned_items;
  end if;
end
$$;
