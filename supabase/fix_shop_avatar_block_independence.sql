-- ============================================================
-- Link Your Area - Avatar / Block independence fix
-- Allows portrait (avatar) selection independently from block character.
-- Apply in Supabase SQL Editor for existing projects.
-- ============================================================

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

  if array_position(v_row.owned_characters, p_item_id) is null then
    raise exception '구매한 캐릭터만 장착할 수 있습니다.';
  end if;

  update public.user_shop_data
     set equipped_character = p_item_id,
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
  v_character_id text := public.shop_portrait_character_id(p_item_id);
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if v_price is null or v_character_id is null then
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
  v_character_id text := public.shop_portrait_character_id(p_item_id);
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if v_character_id is null then
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

update public.user_shop_data
set owned_portraits = public.shop_normalized_owned_portraits(
      owned_portraits,
      owned_characters
    ),
    equipped_portrait = public.shop_normalized_equipped_portrait(
      equipped_portrait,
      equipped_character,
      owned_portraits,
      owned_characters
    );
