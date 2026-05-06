-- Ranked quick-match latency improvements
-- 1) Add a few supporting indexes for repeated waiting-room lookups
-- 2) Move "find joinable room or create one" into a single RPC

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create index if not exists idx_multiplayer_rooms_waiting_created_at
  on public.multiplayer_rooms(game_key, status, created_at);

create index if not exists idx_multiplayer_rooms_host_waiting
  on public.multiplayer_rooms(host_user_id, game_key, status);

create index if not exists idx_multiplayer_room_players_room_user
  on public.multiplayer_room_players(room_id, user_id);

create index if not exists idx_multiplayer_room_players_user_room
  on public.multiplayer_room_players(user_id, room_id);

create index if not exists idx_scores_user_game
  on public.scores(user_id, game_id);

create table if not exists public.multiplayer_ranked_matchmaking_queue (
  id uuid primary key default gen_random_uuid(),
  game_key text not null,
  ranked_game_id text not null,
  user_id uuid not null,
  grade_bucket int not null,
  ranked_points int not null default 0,
  block_color bigint,
  block_color_alt bigint,
  assigned_room_id uuid references public.multiplayer_rooms(id) on delete set null,
  status text not null default 'searching'
    check (status in ('searching', 'matched', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (game_key, ranked_game_id, user_id)
);

create index if not exists idx_multiplayer_ranked_queue_search
  on public.multiplayer_ranked_matchmaking_queue(
    game_key,
    ranked_game_id,
    status,
    created_at
  );

create index if not exists idx_multiplayer_ranked_queue_assigned
  on public.multiplayer_ranked_matchmaking_queue(assigned_room_id);

alter table public.multiplayer_ranked_matchmaking_queue enable row level security;

drop trigger if exists trg_multiplayer_ranked_queue_updated_at
  on public.multiplayer_ranked_matchmaking_queue;
create trigger trg_multiplayer_ranked_queue_updated_at
before update on public.multiplayer_ranked_matchmaking_queue
for each row execute function public.set_updated_at();

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

create or replace function public.multiplayer_ranked_queue_match(
  p_game_key text,
  p_ranked_game_id text,
  p_room_code_prefix text,
  p_room_title text,
  p_block_color bigint,
  p_block_color_alt bigint,
  p_grade_bucket int,
  p_ranked_points int
)
returns table (
  id uuid,
  room_code text,
  room_title text,
  status text,
  host_user_id uuid,
  created_at timestamptz,
  match_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_queue public.multiplayer_ranked_matchmaking_queue%rowtype;
  v_candidate public.multiplayer_ranked_matchmaking_queue%rowtype;
  v_room public.multiplayer_rooms%rowtype;
  v_room_code text;
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_target_bucket int := greatest(0, least(8, p_grade_bucket));
  v_allowed_gap int := 1;
  v_waited interval;
  v_host_user_id uuid;
  v_host_color bigint;
  v_host_color_alt bigint;
  v_guest_user_id uuid;
  v_guest_color bigint;
  v_guest_color_alt bigint;
  v_seed int;
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

  delete from public.multiplayer_ranked_matchmaking_queue q
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and (
       (q.assigned_room_id is null and q.created_at < timezone('utc', now()) - interval '2 minutes')
       or (
         q.assigned_room_id is not null
         and not exists (
           select 1
             from public.multiplayer_rooms r
            where r.id = q.assigned_room_id
              and r.status in ('waiting', 'playing')
         )
       )
     );

  select *
    into v_queue
    from public.multiplayer_ranked_matchmaking_queue q
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and q.user_id = v_user_id
   limit 1;

  if found and v_queue.assigned_room_id is not null then
    select r.*
      into v_room
      from public.multiplayer_rooms r
     where r.id = v_queue.assigned_room_id
       and r.status in ('waiting', 'playing')
     limit 1;

    if found then
      return query
      select
        v_room.id,
        v_room.room_code,
        coalesce(nullif(trim(v_room.room_title), ''), '방 ' || v_room.room_code),
        v_room.status,
        v_room.host_user_id,
        v_room.created_at,
        'matched'::text;
      return;
    end if;

    delete from public.multiplayer_ranked_matchmaking_queue q
     where q.game_key = p_game_key
       and q.ranked_game_id = p_ranked_game_id
       and q.user_id = v_user_id;
  end if;

  insert into public.multiplayer_ranked_matchmaking_queue (
    game_key,
    ranked_game_id,
    user_id,
    grade_bucket,
    ranked_points,
    block_color,
    block_color_alt,
    status
  )
  values (
    p_game_key,
    p_ranked_game_id,
    v_user_id,
    v_target_bucket,
    coalesce(p_ranked_points, 0),
    p_block_color,
    coalesce(p_block_color_alt, p_block_color),
    'searching'
  )
  on conflict (game_key, ranked_game_id, user_id) do update
    set grade_bucket = excluded.grade_bucket,
        ranked_points = excluded.ranked_points,
        block_color = excluded.block_color,
        block_color_alt = excluded.block_color_alt,
        status = case
          when public.multiplayer_ranked_matchmaking_queue.assigned_room_id is null
            then 'searching'
          else public.multiplayer_ranked_matchmaking_queue.status
        end
  returning *
    into v_queue;

  v_waited := timezone('utc', now()) - v_queue.created_at;
  v_allowed_gap := case
    when v_waited >= interval '8 seconds' then 99
    when v_waited >= interval '3 seconds' then 3
    else 1
  end;

  select q.*
    into v_candidate
    from public.multiplayer_ranked_matchmaking_queue q
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and q.status = 'searching'
     and q.assigned_room_id is null
     and q.user_id <> v_user_id
     and abs(q.grade_bucket - v_target_bucket) <= greatest(
       v_allowed_gap,
       case
         when timezone('utc', now()) - q.created_at >= interval '8 seconds' then 99
         when timezone('utc', now()) - q.created_at >= interval '3 seconds' then 3
         else 1
       end
     )
   order by
     abs(q.grade_bucket - v_target_bucket) asc,
     q.created_at asc
   limit 1
   for update;

  if not found then
    return query
    select
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::timestamptz,
      'queued'::text;
    return;
  end if;

  if v_candidate.created_at <= v_queue.created_at then
    v_host_user_id := v_candidate.user_id;
    v_host_color := coalesce(v_candidate.block_color, p_block_color);
    v_host_color_alt := coalesce(v_candidate.block_color_alt, v_host_color);
    v_guest_user_id := v_queue.user_id;
    v_guest_color := coalesce(v_queue.block_color, p_block_color);
    v_guest_color_alt := coalesce(v_queue.block_color_alt, v_guest_color);
  else
    v_host_user_id := v_queue.user_id;
    v_host_color := coalesce(v_queue.block_color, p_block_color);
    v_host_color_alt := coalesce(v_queue.block_color_alt, v_host_color);
    v_guest_user_id := v_candidate.user_id;
    v_guest_color := coalesce(v_candidate.block_color, p_block_color);
    v_guest_color_alt := coalesce(v_candidate.block_color_alt, v_guest_color);
  end if;

  loop
    v_room_code := p_room_code_prefix;
    for i in 1..5 loop
      v_room_code := v_room_code ||
          substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    end loop;

    exit when not exists (
      select 1
        from public.multiplayer_rooms r
       where r.game_key = p_game_key
         and r.room_code = v_room_code
    );
  end loop;

  v_seed := floor(random() * 999999999)::int;

  insert into public.multiplayer_rooms (
    game_key,
    room_code,
    room_title,
    host_user_id,
    status,
    max_players,
    seed,
    turn_number,
    current_turn_user_id,
    started_at,
    turn_started_at,
    host_block_color,
    guest_block_color
  )
  values (
    p_game_key,
    v_room_code,
    coalesce(nullif(trim(p_room_title), ''), '랜덤 방'),
    v_host_user_id,
    'playing',
    2,
    v_seed,
    1,
    v_host_user_id,
    now(),
    now() + interval '3 seconds',
    v_host_color,
    v_guest_color
  )
  returning *
    into v_room;

  insert into public.multiplayer_room_players (
    room_id,
    user_id,
    is_ready,
    block_color,
    block_color_alt
  )
  values
    (
      v_room.id,
      v_host_user_id,
      true,
      v_host_color,
      v_host_color_alt
    ),
    (
      v_room.id,
      v_guest_user_id,
      true,
      v_guest_color,
      v_guest_color_alt
    )
  on conflict (room_id, user_id) do update
    set is_ready = excluded.is_ready,
        block_color = excluded.block_color,
        block_color_alt = excluded.block_color_alt;

  update public.multiplayer_ranked_matchmaking_queue q
     set assigned_room_id = v_room.id,
         status = 'matched'
   where q.game_key = p_game_key
     and q.ranked_game_id = p_ranked_game_id
     and q.user_id in (v_user_id, v_candidate.user_id);

  return query
  select
    v_room.id,
    v_room.room_code,
    coalesce(nullif(trim(v_room.room_title), ''), '방 ' || v_room.room_code),
    v_room.status,
    v_room.host_user_id,
    v_room.created_at,
    'matched'::text;
end;
$$;

revoke all on function public.multiplayer_ranked_queue_match(
  text,
  text,
  text,
  text,
  bigint,
  bigint,
  int,
  int
) from public;

grant execute on function public.multiplayer_ranked_queue_match(
  text,
  text,
  text,
  text,
  bigint,
  bigint,
  int,
  int
) to authenticated;

create or replace function public.multiplayer_ranked_quick_match(
  p_game_key text,
  p_ranked_game_id text,
  p_room_code_prefix text,
  p_room_title text,
  p_block_color bigint,
  p_block_color_alt bigint,
  p_grade_bucket int
)
returns table (
  id uuid,
  room_code text,
  room_title text,
  status text,
  host_user_id uuid,
  created_at timestamptz,
  match_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.multiplayer_rooms%rowtype;
  v_room_code text;
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_target_bucket int := greatest(0, least(8, p_grade_bucket));
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      coalesce(p_game_key, '') || ':' ||
      coalesce(p_room_code_prefix, '') || ':ranked_quick_match',
      0
    )
  );

  select r.*
    into v_room
    from public.multiplayer_rooms r
    join public.multiplayer_room_players p
      on p.room_id = r.id
     and p.user_id = v_user_id
   where r.game_key = p_game_key
     and r.status = 'waiting'
     and r.room_code like p_room_code_prefix || '%'
   order by r.created_at asc
   limit 1;

  if found then
    return query
    select
      v_room.id,
      v_room.room_code,
      coalesce(nullif(trim(v_room.room_title), ''), '방 ' || v_room.room_code),
      v_room.status,
      v_room.host_user_id,
      v_room.created_at,
      'existing'::text;
    return;
  end if;

  select r.*
    into v_room
    from public.multiplayer_rooms r
    join public.multiplayer_room_players host_p
      on host_p.room_id = r.id
     and host_p.user_id = r.host_user_id
    left join public.multiplayer_room_players me
      on me.room_id = r.id
     and me.user_id = v_user_id
    left join lateral (
      select max(s.score) as score
        from public.scores s
       where s.user_id = r.host_user_id
         and s.game_id = p_ranked_game_id
    ) host_score on true
   where r.game_key = p_game_key
     and r.status = 'waiting'
     and r.room_code like p_room_code_prefix || '%'
     and r.host_user_id <> v_user_id
     and me.id is null
     and host_p.is_ready = true
     and (
       select count(*)
         from public.multiplayer_room_players rp
        where rp.room_id = r.id
     ) = 1
     and abs(
       greatest(0, least(8, coalesce(host_score.score, 0) / 10)) - v_target_bucket
     ) <= case
       when timezone('utc', now()) - r.created_at >= interval '10 seconds' then 8
       when timezone('utc', now()) - r.created_at >= interval '4 seconds' then 2
       else 1
     end
   order by
     abs(greatest(0, least(8, coalesce(host_score.score, 0) / 10)) - v_target_bucket) asc,
     r.created_at asc
   limit 1
   for update skip locked;

  if found then
    insert into public.multiplayer_room_players (
      room_id,
      user_id,
      is_ready,
      block_color,
      block_color_alt
    )
    values (
      v_room.id,
      v_user_id,
      true,
      p_block_color,
      coalesce(p_block_color_alt, p_block_color)
    )
    on conflict (room_id, user_id) do update
      set is_ready = excluded.is_ready,
          block_color = excluded.block_color,
          block_color_alt = excluded.block_color_alt;

    return query
    select
      v_room.id,
      v_room.room_code,
      coalesce(nullif(trim(v_room.room_title), ''), '방 ' || v_room.room_code),
      v_room.status,
      v_room.host_user_id,
      v_room.created_at,
      'joined'::text;
    return;
  end if;

  loop
    v_room_code := p_room_code_prefix;
    for i in 1..5 loop
      v_room_code := v_room_code ||
          substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    end loop;

    exit when not exists (
      select 1
        from public.multiplayer_rooms r
       where r.game_key = p_game_key
         and r.room_code = v_room_code
    );
  end loop;

  insert into public.multiplayer_rooms (
    game_key,
    room_code,
    room_title,
    host_user_id,
    status,
    max_players
  )
  values (
    p_game_key,
    v_room_code,
    coalesce(nullif(trim(p_room_title), ''), '랜덤 방'),
    v_user_id,
    'waiting',
    2
  )
  returning *
    into v_room;

  insert into public.multiplayer_room_players (
    room_id,
    user_id,
    is_ready,
    block_color,
    block_color_alt
  )
  values (
    v_room.id,
    v_user_id,
    true,
    p_block_color,
    coalesce(p_block_color_alt, p_block_color)
  )
  on conflict (room_id, user_id) do update
    set is_ready = excluded.is_ready,
        block_color = excluded.block_color,
        block_color_alt = excluded.block_color_alt;

  return query
  select
    v_room.id,
    v_room.room_code,
    coalesce(nullif(trim(v_room.room_title), ''), '방 ' || v_room.room_code),
    v_room.status,
    v_room.host_user_id,
    v_room.created_at,
    'created'::text;
end;
$$;

revoke all on function public.multiplayer_ranked_quick_match(
  text,
  text,
  text,
  text,
  bigint,
  bigint,
  int
) from public;

grant execute on function public.multiplayer_ranked_quick_match(
  text,
  text,
  text,
  text,
  bigint,
  bigint,
  int
) to authenticated;

notify pgrst, 'reload schema';
