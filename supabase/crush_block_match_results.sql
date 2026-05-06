create table if not exists public.multiplayer_match_results (
  id uuid primary key default gen_random_uuid(),
  game_key text not null default 'crush_block',
  room_id text not null,
  winner_role text check (winner_role in ('player1', 'player2')),
  win_reason text,
  players jsonb not null default '[]'::jsonb,
  finished_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists multiplayer_match_results_game_key_idx
  on public.multiplayer_match_results (game_key);

create index if not exists multiplayer_match_results_room_id_idx
  on public.multiplayer_match_results (room_id);
