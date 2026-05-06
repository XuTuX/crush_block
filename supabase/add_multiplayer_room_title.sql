-- Add room_title to multiplayer rooms for title-based friendly lobbies.
-- Run this in Supabase SQL Editor for existing databases.

alter table public.multiplayer_rooms
  add column if not exists room_title text;

update public.multiplayer_rooms
set room_title = concat('방 ', room_code)
where room_title is null or trim(room_title) = '';

alter table public.multiplayer_rooms
  alter column room_title set default '랜덤 방';

alter table public.multiplayer_rooms
  alter column room_title set not null;

notify pgrst, 'reload schema';
