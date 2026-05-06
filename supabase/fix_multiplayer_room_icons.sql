-- ============================================================
-- Link Your Area - Multiplayer Room Icon RPC Hotfix
-- Apply in Supabase SQL Editor.
-- ============================================================

create or replace function public.shop_get_room_equipped_icons(
  p_room_id uuid,
  p_game_key text default 'link_your_area'
)
returns table (
  user_id uuid,
  equipped_icon text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if not exists (
    select 1
      from public.multiplayer_room_players p
     where p.room_id = p_room_id
       and p.user_id = v_user_id
  ) then
    raise exception '같은 방 참가자만 조회할 수 있습니다.';
  end if;

  return query
  select p.user_id,
         coalesce(s.equipped_icon, 'default_face') as equipped_icon
    from public.multiplayer_room_players p
    left join public.user_shop_data s
      on s.user_id = p.user_id
     and s.game_key = p_game_key
   where p.room_id = p_room_id;
end;
$$;

revoke all on function public.shop_get_room_equipped_icons(uuid, text) from public;
grant execute on function public.shop_get_room_equipped_icons(uuid, text) to authenticated;

notify pgrst, 'reload schema';
