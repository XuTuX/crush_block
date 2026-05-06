-- ============================================================
-- Crush Block - Multiplayer Game State Hotfix
-- Apply when multiplayer_game_states is missing newer columns.
-- ============================================================

alter table public.multiplayer_game_states
  add column if not exists owner_grid jsonb not null default '[]'::jsonb;

alter table public.multiplayer_game_states
  add column if not exists won_by_connection boolean not null default false;
