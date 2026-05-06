-- ============================================================
-- Link Your Area - Byo-yomi Timer Support
-- Add main time and byoyomi columns to multiplayer_game_states.
-- ============================================================

alter table public.multiplayer_game_states
  add column if not exists main_time_seconds integer not null default 120,
  add column if not exists byoyomi_periods integer not null default 3;

alter table public.multiplayer_rooms
  add column if not exists turn_started_at timestamptz;
