-- Keep multiplayer room gameplay updates available to participants,
-- but block direct takeover of privileged columns such as host_user_id.

create or replace function public.multiplayer_transfer_room_host(
  p_room_id uuid,
  p_new_host_user_id uuid
)
returns void
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

  if p_room_id is null or p_new_host_user_id is null then
    raise exception 'room_id 와 new_host_user_id 가 필요합니다.';
  end if;

  if not exists (
    select 1
      from public.multiplayer_rooms r
     where r.id = p_room_id
       and r.host_user_id = v_user_id
       and r.game_key = 'crush_block'
  ) then
    raise exception '현재 방을 넘길 권한이 없습니다.';
  end if;

  if not exists (
    select 1
      from public.multiplayer_room_players p
      join public.multiplayer_rooms r
        on r.id = p.room_id
     where p.room_id = p_room_id
       and p.user_id = p_new_host_user_id
       and r.game_key = 'crush_block'
  ) then
    raise exception '새 방 소유자는 같은 방 참가자여야 합니다.';
  end if;

  update public.multiplayer_rooms
     set host_user_id = p_new_host_user_id
   where id = p_room_id
     and game_key = 'crush_block';
end;
$$;

revoke all on function public.multiplayer_transfer_room_host(uuid, uuid)
  from public;
grant execute on function public.multiplayer_transfer_room_host(uuid, uuid)
  to authenticated;

revoke update on public.multiplayer_rooms from authenticated;
grant update (
  status,
  started_at,
  turn_started_at,
  seed,
  current_turn_user_id,
  turn_number,
  shared_blocks,
  shared_block_colors,
  host_block_color,
  guest_block_color
) on public.multiplayer_rooms to authenticated;

notify pgrst, 'reload schema';
