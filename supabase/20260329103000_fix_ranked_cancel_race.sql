drop function if exists public.multiplayer_ranked_queue_cancel(
  text,
  text
);

create function public.multiplayer_ranked_queue_cancel(
  p_game_key text,
  p_ranked_game_id text
)
returns table (
  cancel_action text,
  id uuid,
  room_code text,
  room_title text,
  status text,
  host_user_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_room_created_at timestamptz;
  v_room public.multiplayer_rooms%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      coalesce(p_game_key, '') || ':' ||
      coalesce(p_ranked_game_id, '') || ':ranked_queue_match',
      0
    )
  );

  select
    q.assigned_room_id,
    r.created_at
    into v_room_id, v_room_created_at
    from public.multiplayer_ranked_matchmaking_queue q
    left join public.multiplayer_rooms r
      on r.id = q.assigned_room_id
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and q.user_id = v_user_id
   for update of q;

  if not found then
    return query
    select
      'not_found'::text,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::timestamptz;
    return;
  end if;

  if v_room_id is null then
    delete from public.multiplayer_ranked_matchmaking_queue q
     where q.game_key = p_game_key
       and q.ranked_game_id = p_ranked_game_id
       and q.user_id = v_user_id;
    return query
    select
      'cancelled'::text,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::timestamptz;
    return;
  end if;

  if v_room_created_at is null then
    update public.multiplayer_ranked_matchmaking_queue q
       set assigned_room_id = null,
           status = 'searching'
     where q.game_key = p_game_key
       and q.ranked_game_id = p_ranked_game_id
       and q.assigned_room_id = v_room_id
       and q.user_id <> v_user_id;

    delete from public.multiplayer_ranked_matchmaking_queue q
     where q.game_key = p_game_key
       and q.ranked_game_id = p_ranked_game_id
       and q.user_id = v_user_id;
    return query
    select
      'cancelled'::text,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::timestamptz;
    return;
  end if;

  if v_room_created_at < timezone('utc', now()) - interval '8 seconds' or
      exists (
        select 1
          from public.multiplayer_game_states gs
         where gs.room_id = v_room_id
      ) then
    select r.*
      into v_room
      from public.multiplayer_rooms r
     where r.id = v_room_id
     limit 1;

    if found then
      return query
      select
        'matched'::text,
        v_room.id,
        v_room.room_code,
        coalesce(nullif(trim(v_room.room_title), ''), '방 ' || v_room.room_code),
        v_room.status,
        v_room.host_user_id,
        v_room.created_at;
    else
      return query
      select
        'cancelled'::text,
        null::uuid,
        null::text,
        null::text,
        null::text,
        null::uuid,
        null::timestamptz;
    end if;
    return;
  end if;

  update public.multiplayer_ranked_matchmaking_queue q
     set assigned_room_id = null,
         status = 'searching'
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and q.assigned_room_id = v_room_id
     and q.user_id <> v_user_id;

  delete from public.multiplayer_ranked_matchmaking_queue q
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and q.user_id = v_user_id;

  delete from public.multiplayer_room_players
   where room_id = v_room_id;

  delete from public.multiplayer_game_states
   where room_id = v_room_id;

  delete from public.multiplayer_rooms
   where id = v_room_id;

  return query
  select
    'cancelled'::text,
    null::uuid,
    null::text,
    null::text,
    null::text,
    null::uuid,
    null::timestamptz;
end;
$$;

revoke all on function public.multiplayer_ranked_queue_cancel(
  text,
  text
) from public;

grant execute on function public.multiplayer_ranked_queue_cancel(
  text,
  text
) to authenticated;
