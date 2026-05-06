-- Restrict multiplayer_room_players visibility to same-room participants
-- without recursive RLS checks, and expose public room occupancy through a
-- narrow RPC.

create or replace function public.multiplayer_is_room_participant(
  p_room_id uuid,
  p_game_key text default 'link_your_area'
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and exists (
      select 1
        from public.multiplayer_room_players self
        join public.multiplayer_rooms r
          on r.id = self.room_id
       where self.room_id = p_room_id
         and self.user_id = auth.uid()
         and r.game_key = p_game_key
    );
$$;

drop policy if exists "players_select_link_your_area"
on public.multiplayer_room_players;

create policy "players_select_link_your_area"
on public.multiplayer_room_players
for select
using (
  public.multiplayer_is_room_participant(
    multiplayer_room_players.room_id,
    'link_your_area'
  )
);

create or replace function public.multiplayer_get_room_player_counts(
  p_room_ids uuid[],
  p_game_key text default 'link_your_area'
)
returns table (
  room_id uuid,
  player_count bigint
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

  if coalesce(array_length(p_room_ids, 1), 0) = 0 then
    return;
  end if;

  return query
  select p.room_id,
         count(*)::bigint as player_count
    from public.multiplayer_room_players p
    join public.multiplayer_rooms r
      on r.id = p.room_id
   where r.game_key = p_game_key
     and p.room_id = any(p_room_ids)
   group by p.room_id;
end;
$$;

revoke all on function public.multiplayer_get_room_player_counts(uuid[], text)
  from public;
grant execute on function public.multiplayer_get_room_player_counts(uuid[], text)
  to authenticated;
grant execute on function public.multiplayer_is_room_participant(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
