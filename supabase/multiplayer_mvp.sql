-- ============================================================
-- Link Your Area - Multiplayer MVP Schema (v2 - Hardened)
-- Apply in Supabase SQL Editor
-- 재실행 안전: IF NOT EXISTS / DROP IF EXISTS 사용
-- ============================================================

-- ============================================================
-- 0) TABLES
-- ============================================================

-- auth.users FK 제거 → RLS에서 auth.uid()로만 검증 (Supabase 권장)
create table if not exists public.multiplayer_rooms (
  id          uuid primary key default gen_random_uuid(),
  game_key    text not null default 'link_your_area',
  room_code   text not null,
  room_title  text not null default '랜덤 방',
  host_user_id uuid not null,                -- FK 없이, RLS로 보호
  status      text not null default 'waiting'
                check (status in ('waiting', 'playing', 'finished')),
  max_players int  not null default 2 check (max_players = 2),
  seed        bigint,                        -- 게임 시드 (양쪽 동일 맵용, 차후)
  host_block_color bigint,
  guest_block_color bigint,
  started_at  timestamptz,
  turn_started_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.multiplayer_room_players (
  id        uuid primary key default gen_random_uuid(),
  room_id   uuid not null references public.multiplayer_rooms(id) on delete cascade,
  user_id   uuid not null,                   -- FK 없이, RLS로 보호
  is_ready  boolean not null default false,
  block_color bigint,
  block_color_alt bigint,
  joined_at timestamptz not null default now(),
  unique(room_id, user_id)
);

-- ============================================================
-- 1) MIGRATION SAFETY (기존 스키마 호환)
-- ============================================================

-- game_key 컬럼이 없던 기존 테이블 대비
alter table public.multiplayer_rooms
  add column if not exists game_key text;

update public.multiplayer_rooms
set game_key = 'link_your_area'
where game_key is null;

alter table public.multiplayer_rooms
  alter column game_key set not null;

alter table public.multiplayer_rooms
  add column if not exists room_title text;

update public.multiplayer_rooms
set room_title = concat('방 ', room_code)
where room_title is null or trim(room_title) = '';

alter table public.multiplayer_rooms
  alter column room_title set default '랜덤 방';

alter table public.multiplayer_rooms
  alter column room_title set not null;

-- seed 컬럼 추가 (차후 동일 맵 공유용)
alter table public.multiplayer_rooms
  add column if not exists seed bigint;

alter table public.multiplayer_rooms
  add column if not exists turn_started_at timestamptz;

alter table public.multiplayer_rooms
  add column if not exists host_block_color bigint;

alter table public.multiplayer_rooms
  add column if not exists guest_block_color bigint;

alter table public.multiplayer_room_players
  add column if not exists block_color bigint;

alter table public.multiplayer_room_players
  add column if not exists block_color_alt bigint;

alter table public.multiplayer_rooms
  alter column host_block_color type bigint using host_block_color::bigint;

alter table public.multiplayer_rooms
  alter column guest_block_color type bigint using guest_block_color::bigint;

alter table public.multiplayer_room_players
  alter column block_color type bigint using block_color::bigint;

alter table public.multiplayer_room_players
  alter column block_color_alt type bigint using block_color_alt::bigint;

-- host_user_id에 auth.users FK가 걸려있으면 제거
do $$
declare
  _con text;
begin
  select conname into _con
  from pg_constraint
  where conrelid = 'public.multiplayer_rooms'::regclass
    and confrelid = 'auth.users'::regclass
    and contype = 'f'
  limit 1;

  if _con is not null then
    execute format('alter table public.multiplayer_rooms drop constraint %I', _con);
  end if;
end $$;

-- multiplayer_room_players에서도 auth.users FK 제거
do $$
declare
  _con text;
begin
  select conname into _con
  from pg_constraint
  where conrelid = 'public.multiplayer_room_players'::regclass
    and confrelid = 'auth.users'::regclass
    and contype = 'f'
  limit 1;

  if _con is not null then
    execute format('alter table public.multiplayer_room_players drop constraint %I', _con);
  end if;
end $$;

-- ============================================================
-- 2) INDEXES / CONSTRAINTS
-- ============================================================

create unique index if not exists ux_multiplayer_rooms_game_room_code
  on public.multiplayer_rooms(game_key, room_code);

create index if not exists idx_multiplayer_rooms_game_status
  on public.multiplayer_rooms(game_key, status);

create index if not exists idx_multiplayer_room_players_room_id
  on public.multiplayer_room_players(room_id);

-- legacy unique(room_code)가 있었다면 제거
alter table public.multiplayer_rooms
  drop constraint if exists multiplayer_rooms_room_code_key;

-- ============================================================
-- 3) TRIGGERS: updated_at 자동 갱신 + room_code 대문자 강제
-- ============================================================

-- updated_at 트리거 함수
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_multiplayer_rooms_updated_at on public.multiplayer_rooms;
create trigger trg_multiplayer_rooms_updated_at
before update on public.multiplayer_rooms
for each row execute function public.set_updated_at();

-- room_code 항상 대문자 저장 트리거
create or replace function public.normalize_room_code()
returns trigger
language plpgsql
as $$
begin
  new.room_code = upper(trim(new.room_code));
  return new;
end;
$$;

drop trigger if exists trg_normalize_room_code on public.multiplayer_rooms;
create trigger trg_normalize_room_code
before insert or update on public.multiplayer_rooms
for each row execute function public.normalize_room_code();

-- ============================================================
-- 4) 2명 제한 트리거 (DB 레벨 강제)
-- ============================================================

create or replace function public.enforce_max_players()
returns trigger
language plpgsql
as $$
declare
  _current_count int;
  _max int;
begin
  select count(*) into _current_count
  from public.multiplayer_room_players
  where room_id = new.room_id;

  select max_players into _max
  from public.multiplayer_rooms
  where id = new.room_id;

  if _current_count >= coalesce(_max, 2) then
    raise exception '방이 가득 찼습니다. (최대 % 명)', _max;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_max_players on public.multiplayer_room_players;
create trigger trg_enforce_max_players
before insert on public.multiplayer_room_players
for each row execute function public.enforce_max_players();

-- ============================================================
-- 5) RLS POLICIES
-- ============================================================

alter table public.multiplayer_rooms enable row level security;
alter table public.multiplayer_room_players enable row level security;

-- ----- 기존 정책 정리 (재실행 안전) -----
drop policy if exists "rooms_select_authenticated" on public.multiplayer_rooms;
drop policy if exists "rooms_insert_host" on public.multiplayer_rooms;
drop policy if exists "rooms_update_host" on public.multiplayer_rooms;
drop policy if exists "rooms_delete_host" on public.multiplayer_rooms;
drop policy if exists "rooms_select_link_your_area" on public.multiplayer_rooms;
drop policy if exists "rooms_insert_link_your_area_host" on public.multiplayer_rooms;
drop policy if exists "rooms_update_link_your_area_host" on public.multiplayer_rooms;
drop policy if exists "rooms_delete_link_your_area_host" on public.multiplayer_rooms;

drop policy if exists "players_select_authenticated" on public.multiplayer_room_players;
drop policy if exists "players_insert_self" on public.multiplayer_room_players;
drop policy if exists "players_update_self" on public.multiplayer_room_players;
drop policy if exists "players_delete_self" on public.multiplayer_room_players;
drop policy if exists "players_select_link_your_area" on public.multiplayer_room_players;
drop policy if exists "players_insert_link_your_area_self" on public.multiplayer_room_players;
drop policy if exists "players_update_link_your_area_self" on public.multiplayer_room_players;
drop policy if exists "players_delete_link_your_area_self" on public.multiplayer_room_players;

-- ===== ROOMS 정책 =====

-- SELECT: 로그인 유저라면 누구나 우리 게임의 방 목록을 조회 가능 (빠른매칭용)
-- (조회 권한을 열어주어 플레이어 테이블과의 무한 재귀를 방지합니다)
create policy "rooms_select_link_your_area"
on public.multiplayer_rooms
for select
using (
  auth.uid() is not null
  and game_key = 'link_your_area'
);

-- INSERT: 자기 자신만 호스트로 방 생성 가능
create policy "rooms_insert_link_your_area_host"
on public.multiplayer_rooms
for insert
with check (
  auth.uid() = host_user_id
  and game_key = 'link_your_area'
);

-- UPDATE: 방에 참가한 플레이어라면 수정 가능 (턴 전환, 블록 업데이트 등)
create policy "rooms_update_link_your_area_host"
on public.multiplayer_rooms
for update
using (
  game_key = 'link_your_area'
  and exists (
    select 1
    from public.multiplayer_room_players p
    where p.room_id = multiplayer_rooms.id
      and p.user_id = auth.uid()
  )
)
with check (
  game_key = 'link_your_area'
  and exists (
    select 1
    from public.multiplayer_room_players p
    where p.room_id = multiplayer_rooms.id
      and p.user_id = auth.uid()
  )
);

-- DELETE: 호스트만 자기 방 삭제 가능
create policy "rooms_delete_link_your_area_host"
on public.multiplayer_rooms
for delete
using (
  auth.uid() = host_user_id
  and game_key = 'link_your_area'
);

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
       and r.game_key = 'link_your_area'
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
       and r.game_key = 'link_your_area'
  ) then
    raise exception '새 방 소유자는 같은 방 참가자여야 합니다.';
  end if;

  update public.multiplayer_rooms
     set host_user_id = p_new_host_user_id
   where id = p_room_id
     and game_key = 'link_your_area';
end;
$$;

-- ===== PLAYERS 정책 =====

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

-- SELECT: 같은 방에 속한 플레이어만 조회 가능
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

-- INSERT: 자기 자신만 참가 등록 가능 + 해당 방이 link_your_area 게임
create policy "players_insert_link_your_area_self"
on public.multiplayer_room_players
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.multiplayer_rooms r
    where r.id = multiplayer_room_players.room_id
      and r.game_key = 'link_your_area'
      and r.status = 'waiting'
  )
);

-- UPDATE: 자기 row만 수정 가능 (레디 상태 변경 등)
create policy "players_update_link_your_area_self"
on public.multiplayer_room_players
for update
using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.multiplayer_rooms r
    where r.id = multiplayer_room_players.room_id
      and r.game_key = 'link_your_area'
  )
)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.multiplayer_rooms r
    where r.id = multiplayer_room_players.room_id
      and r.game_key = 'link_your_area'
  )
);

-- DELETE: 자기 자신만 퇴장 가능
create policy "players_delete_link_your_area_self"
on public.multiplayer_room_players
for delete
using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.multiplayer_rooms r
    where r.id = multiplayer_room_players.room_id
      and r.game_key = 'link_your_area'
  )
);

grant execute on function public.multiplayer_get_room_player_counts(uuid[], text)
  to authenticated;
grant execute on function public.multiplayer_transfer_room_host(uuid, uuid)
  to authenticated;
grant execute on function public.multiplayer_is_room_participant(uuid, text)
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
