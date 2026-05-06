-- ============================================================
-- Link Your Area - Multiplayer Game State Schema
-- Apply AFTER multiplayer_mvp.sql in Supabase SQL Editor
-- ============================================================

-- 1) Add turn/block columns to rooms
alter table public.multiplayer_rooms
  add column if not exists current_turn_user_id uuid;

alter table public.multiplayer_rooms
  add column if not exists turn_number int not null default 0;

alter table public.multiplayer_rooms
  add column if not exists turn_started_at timestamptz;

alter table public.multiplayer_rooms
  add column if not exists shared_blocks jsonb;

alter table public.multiplayer_rooms
  add column if not exists shared_block_colors jsonb;

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

-- 2) Game state per player
create table if not exists public.multiplayer_game_states (
  id               uuid primary key default gen_random_uuid(),
  room_id          uuid not null references public.multiplayer_rooms(id) on delete cascade,
  user_id          uuid not null,
  filled_grid      jsonb not null default '[]'::jsonb,
  dropped_positions jsonb not null default '[]'::jsonb,
  region_grid      jsonb not null default '[]'::jsonb,
  owner_grid       jsonb not null default '[]'::jsonb,
  score            int not null default 0,
  block_score      int not null default 0,
  region_score     int not null default 0,
  is_game_over     boolean not null default false,
  won_by_connection boolean not null default false,
  updated_at       timestamptz not null default now(),
  unique(room_id, user_id)
);

alter table public.multiplayer_game_states
  add column if not exists owner_grid jsonb not null default '[]'::jsonb;

alter table public.multiplayer_game_states
  add column if not exists won_by_connection boolean not null default false;

-- 3) Indexes
create index if not exists idx_mp_game_states_room
  on public.multiplayer_game_states(room_id);

-- 4) updated_at trigger
drop trigger if exists trg_mp_game_states_updated on public.multiplayer_game_states;
create trigger trg_mp_game_states_updated
before update on public.multiplayer_game_states
for each row execute function public.set_updated_at();

-- 5) RLS
alter table public.multiplayer_game_states enable row level security;

-- Drop old policies if re-running
drop policy if exists "gs_select_room_player" on public.multiplayer_game_states;
drop policy if exists "gs_insert_self" on public.multiplayer_game_states;
drop policy if exists "gs_update_self" on public.multiplayer_game_states;
drop policy if exists "gs_delete_self" on public.multiplayer_game_states;

-- SELECT: only players in the same room can see game states
create policy "gs_select_room_player"
on public.multiplayer_game_states
for select
using (
  auth.uid() is not null
  and exists (
    select 1
    from public.multiplayer_room_players p
    where p.room_id = multiplayer_game_states.room_id
      and p.user_id = auth.uid()
  )
);

-- INSERT: only yourself
create policy "gs_insert_self"
on public.multiplayer_game_states
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.multiplayer_room_players p
    where p.room_id = multiplayer_game_states.room_id
      and p.user_id = auth.uid()
  )
);

-- UPDATE: only your own state
create policy "gs_update_self"
on public.multiplayer_game_states
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- DELETE: only your own state
create policy "gs_delete_self"
on public.multiplayer_game_states
for delete
using (auth.uid() = user_id);
