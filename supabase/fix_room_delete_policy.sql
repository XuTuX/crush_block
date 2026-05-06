-- ============================================================
-- Fix: Allow room participants to delete empty/stale rooms
-- Also allow host to delete rooms during cleanup
-- ============================================================

-- Drop old delete policy
drop policy if exists "rooms_delete_crush_block_host" on public.multiplayer_rooms;

-- New DELETE policy: host can always delete their room,
-- OR any participant can delete a room if it has 0-1 players (cleanup scenario)
create policy "rooms_delete_crush_block_host"
on public.multiplayer_rooms
for delete
using (
  game_key = 'crush_block'
  and (
    -- Host can always delete
    auth.uid() = host_user_id
    -- OR: any authenticated user can delete empty rooms (ghost cleanup)
    or (
      auth.uid() is not null
      and not exists (
        select 1
        from public.multiplayer_room_players p
        where p.room_id = multiplayer_rooms.id
      )
    )
  )
);

-- ============================================================
-- Verify Realtime publication includes all required tables
-- (safe to re-run; will no-op if already added)
-- ============================================================
do $$
begin
  -- multiplayer_rooms
  begin
    alter publication supabase_realtime add table public.multiplayer_rooms;
  exception when duplicate_object then
    null; -- already added
  end;

  -- multiplayer_room_players
  begin
    alter publication supabase_realtime add table public.multiplayer_room_players;
  exception when duplicate_object then
    null; -- already added
  end;

  -- multiplayer_game_states
  begin
    alter publication supabase_realtime add table public.multiplayer_game_states;
  exception when duplicate_object then
    null; -- already added
  end;
end $$;
