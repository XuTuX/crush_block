-- ============================================================
-- Fix: Flutter ARGB color values exceed PostgreSQL integer range
-- Run this in Supabase SQL Editor when room creation fails with:
-- "value ... is out of range for type integer"
-- ============================================================

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
