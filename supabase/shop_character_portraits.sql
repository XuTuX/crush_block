-- ============================================================
-- Link Your Area - Character / Portrait shop extension
-- Apply after shop_schema.sql
-- ============================================================

alter table public.user_shop_data
  add column if not exists owned_characters text[] not null
    default array[]::text[];

alter table public.user_shop_data
  alter column owned_characters set default array[]::text[];

alter table public.user_shop_data
  add column if not exists equipped_character text not null
    default '';

alter table public.user_shop_data
  alter column equipped_character set default '';

alter table public.user_shop_data
  add column if not exists owned_portraits text[] not null
    default array['slime_face']::text[];

alter table public.user_shop_data
  add column if not exists equipped_portrait text not null
    default 'slime_face';

alter table public.multiplayer_room_players
  add column if not exists character_id text;

alter table public.multiplayer_room_players
  add column if not exists portrait_id text;

create or replace function public.shop_normalize_character_id(p_item_id text)
returns text
language sql
immutable
as $$
  select case p_item_id
    when 'rocket_token' then 'rocket_token'
    when 'key_token' then 'key_token'
    when 'star_token' then 'star_token'
    when 'flare_captain' then 'rocket_token'
    when 'bloom_guardian' then 'rocket_token'
    when 'mist_mage' then 'key_token'
    when 'bolt_engineer' then 'star_token'
    else null
  end
$$;

create or replace function public.shop_character_price(p_item_id text)
returns int
language sql
immutable
as $$
  select case public.shop_normalize_character_id(p_item_id)
    when 'rocket_token' then 0
    when 'key_token' then 450
    when 'star_token' then 550
    else null
  end
$$;

create or replace function public.shop_portrait_price(p_item_id text)
returns int
language sql
immutable
as $$
  select case p_item_id
    when 'slime_face' then 0
    when 'knight_slime_face' then 500
    when 'wizard_slime_face' then 500
    when 'angel_slime_face' then 300
    when 'demon_slime_face' then 500
    else null
  end
$$;

create or replace function public.shop_portrait_character_id(p_item_id text)
returns text
language sql
immutable
as $$
  select case p_item_id
    when 'slime_face' then 'rocket_token'
    when 'knight_slime_face' then 'key_token'
    when 'wizard_slime_face' then 'star_token'
    when 'angel_slime_face' then 'rocket_token'
    when 'demon_slime_face' then 'key_token'
    else null
  end
$$;

create or replace function public.shop_default_portrait_id(p_character_id text)
returns text
language sql
immutable
as $$
  select case public.shop_normalize_character_id(p_character_id)
    when 'rocket_token' then 'slime_face'
    when 'key_token' then 'slime_face'
    when 'star_token' then 'slime_face'
    else 'slime_face'
  end
$$;

create or replace function public.shop_normalized_owned_characters(p_item_ids text[])
returns text[]
language sql
immutable
as $$
  select array(
    select id
    from (
      select distinct normalized_id as id
      from (
        select public.shop_normalize_character_id(raw_id) as normalized_id
        from unnest(
          coalesce(
            p_item_ids,
            array[]::text[]
          )
        ) raw_id
      ) normalized_items
      where normalized_id is not null
        and public.shop_character_price(normalized_id) is not null
    ) items
    order by case id
      when 'rocket_token' then 1
      when 'key_token' then 2
      when 'star_token' then 3
      else 999
    end
  )
$$;

create or replace function public.shop_normalized_owned_portraits(
  p_item_ids text[],
  p_owned_characters text[]
)
returns text[]
language sql
immutable
as $$
  select array(
    select id
    from (
      select distinct raw_id as id
      from unnest(coalesce(p_item_ids, array[]::text[])) raw_id
      where public.shop_portrait_price(raw_id) is not null
      union all
      select 'slime_face'
    ) items
    order by case id
      when 'slime_face' then 1
      when 'knight_slime_face' then 2
      when 'wizard_slime_face' then 3
      when 'angel_slime_face' then 4
      when 'demon_slime_face' then 5
      else 999
    end
  )
$$;

create or replace function public.shop_normalized_equipped_portrait(
  p_equipped_portrait text,
  p_equipped_character text,
  p_owned_portraits text[],
  p_owned_characters text[]
)
returns text
language sql
immutable
as $$
  with normalized_portraits as (
    select public.shop_normalized_owned_portraits(
      p_owned_portraits,
      p_owned_characters
    ) as ids
  )
  select case
    when array_position((select ids from normalized_portraits), p_equipped_portrait) is not null
      then p_equipped_portrait
    else (select ids[1] from normalized_portraits)
  end
$$;

create or replace function public.shop_state_json(
  p_coins int,
  p_owned_icons text[],
  p_owned_block_skins text[],
  p_equipped_icon text,
  p_equipped_block_skin text,
  p_equipped_block_skins text[] default null,
  p_owned_characters text[] default null,
  p_equipped_character text default '',
  p_owned_portraits text[] default null,
  p_equipped_portrait text default 'slime_face'
)
returns jsonb
language sql
immutable
as $$
  with normalized as (
    select public.shop_normalized_owned_block_skins(p_owned_block_skins) as owned_block_ids,
           public.shop_normalized_equipped_block_skins(
             coalesce(p_equipped_block_skins, array[p_equipped_block_skin]::text[]),
             p_owned_block_skins,
             p_equipped_block_skin
           ) as equipped_block_ids,
           public.shop_normalized_owned_characters(p_owned_characters) as owned_character_ids
  ),
  normalized_portraits as (
    select public.shop_normalized_owned_portraits(
      p_owned_portraits,
      (select owned_character_ids from normalized)
    ) as owned_portrait_ids
  ),
  resolved_character as (
    select case
      when p_equipped_character = '' then ''
      when array_position(
             (select owned_character_ids from normalized),
             public.shop_normalize_character_id(p_equipped_character)
           ) is not null
        then public.shop_normalize_character_id(p_equipped_character)
      else coalesce((select owned_character_ids[1] from normalized), '')
    end as id
  ),
  resolved_portrait as (
    select public.shop_normalized_equipped_portrait(
      p_equipped_portrait,
      (select id from resolved_character),
      (select owned_portrait_ids from normalized_portraits),
      (select owned_character_ids from normalized)
    ) as id
  )
  select jsonb_build_object(
    'coins', p_coins,
    'owned_icons', to_jsonb(p_owned_icons),
    'owned_block_skins', to_jsonb((select owned_block_ids from normalized)),
    'equipped_icon', p_equipped_icon,
    'equipped_block_skin', (select equipped_block_ids[1] from normalized),
    'equipped_block_skins', to_jsonb((select equipped_block_ids from normalized)),
    'owned_characters', to_jsonb((select owned_character_ids from normalized)),
    'equipped_character', (select id from resolved_character),
    'owned_portraits', to_jsonb((select owned_portrait_ids from normalized_portraits)),
    'equipped_portrait', (select id from resolved_portrait)
  )
$$;

update public.user_shop_data
set owned_characters = public.shop_normalized_owned_characters(owned_characters),
    equipped_character = case
      when equipped_character = '' then ''
      when array_position(
             public.shop_normalized_owned_characters(owned_characters),
             public.shop_normalize_character_id(equipped_character)
           ) is not null
        then public.shop_normalize_character_id(equipped_character)
      else coalesce(
        (public.shop_normalized_owned_characters(owned_characters))[1],
        ''
      )
    end,
    owned_portraits = public.shop_normalized_owned_portraits(
      owned_portraits,
      owned_characters
    ),
    equipped_portrait = public.shop_normalized_equipped_portrait(
      equipped_portrait,
      public.shop_normalize_character_id(equipped_character),
      owned_portraits,
      owned_characters
    )
where game_key = 'link_your_area';

update public.multiplayer_room_players
set character_id = public.shop_normalize_character_id(character_id)
where character_id is null
   or public.shop_normalize_character_id(character_id) is distinct from character_id;

create or replace function public.shop_get_state(
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key;

  return public.shop_state_json(
    v_row.coins,
    v_row.owned_icons,
    v_row.owned_block_skins,
    v_row.equipped_icon,
    v_row.equipped_block_skin,
    v_row.equipped_block_skins,
    v_row.owned_characters,
    v_row.equipped_character,
    v_row.owned_portraits,
    v_row.equipped_portrait
  );
end;
$$;

create or replace function public.shop_purchase_character(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item_id text := public.shop_normalize_character_id(p_item_id);
  v_price int := public.shop_character_price(p_item_id);
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if v_item_id is null or v_price is null then
    raise exception '아이템을 찾지 못했습니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if array_position(
       public.shop_normalized_owned_characters(v_row.owned_characters),
       v_item_id
     ) is not null then
    raise exception '이미 소유한 캐릭터입니다.';
  end if;
  if v_row.coins < v_price then
    raise exception '코인이 부족합니다.';
  end if;

  update public.user_shop_data
     set coins = coins - v_price,
         owned_characters = public.shop_normalized_owned_characters(
           array_append(v_row.owned_characters, v_item_id)
         )
   where user_id = v_user_id
     and game_key = p_game_key;

  return public.shop_get_state(p_game_key);
end;
$$;

create or replace function public.shop_equip_character(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item_id text := case
    when coalesce(p_item_id, '') = '' then ''
    else public.shop_normalize_character_id(p_item_id)
  end;
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if v_item_id is null then
    raise exception '아이템을 찾지 못했습니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if v_item_id <> '' and array_position(
       public.shop_normalized_owned_characters(v_row.owned_characters),
       v_item_id
     ) is null then
    raise exception '구매한 캐릭터만 장착할 수 있습니다.';
  end if;

  update public.user_shop_data
     set equipped_character = v_item_id,
         owned_portraits = public.shop_normalized_owned_portraits(
           v_row.owned_portraits,
           v_row.owned_characters
         )
   where user_id = v_user_id
     and game_key = p_game_key;

  return public.shop_get_state(p_game_key);
end;
$$;

create or replace function public.shop_purchase_portrait(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_price int := public.shop_portrait_price(p_item_id);
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if v_price is null then
    raise exception '아이템을 찾지 못했습니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if array_position(
       public.shop_normalized_owned_portraits(
         v_row.owned_portraits,
         v_row.owned_characters
       ),
       p_item_id
     ) is not null then
    raise exception '이미 소유한 초상입니다.';
  end if;
  if v_row.coins < v_price then
    raise exception '코인이 부족합니다.';
  end if;

  update public.user_shop_data
     set coins = coins - v_price,
         owned_portraits = public.shop_normalized_owned_portraits(
           array_append(v_row.owned_portraits, p_item_id),
           v_row.owned_characters
         )
   where user_id = v_user_id
     and game_key = p_game_key;

  return public.shop_get_state(p_game_key);
end;
$$;

create or replace function public.shop_equip_portrait(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if array_position(
       public.shop_normalized_owned_portraits(
         v_row.owned_portraits,
         v_row.owned_characters
       ),
       p_item_id
     ) is null then
    raise exception '구매한 초상만 장착할 수 있습니다.';
  end if;

  update public.user_shop_data
     set owned_portraits = public.shop_normalized_owned_portraits(
           v_row.owned_portraits,
           v_row.owned_characters
         ),
         equipped_portrait = p_item_id
   where user_id = v_user_id
     and game_key = p_game_key;

  return public.shop_get_state(p_game_key);
end;
$$;

grant execute on function public.shop_purchase_character(text, text) to authenticated;
grant execute on function public.shop_equip_character(text, text) to authenticated;
grant execute on function public.shop_purchase_portrait(text, text) to authenticated;
grant execute on function public.shop_equip_portrait(text, text) to authenticated;
