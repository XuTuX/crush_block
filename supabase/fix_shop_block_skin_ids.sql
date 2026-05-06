-- ============================================================
-- Link Your Area - Shop color slot migration
-- Existing deployments: run this in Supabase SQL Editor.
-- ============================================================

alter table public.user_shop_data
  add column if not exists equipped_block_skins text[] not null default array['red', 'blue']::text[];

alter table public.user_shop_data
  alter column owned_block_skins set default array['red', 'blue']::text[],
  alter column equipped_block_skin set default 'red',
  alter column equipped_block_skins set default array['red', 'blue']::text[];

create or replace function public.shop_normalize_block_skin_id(p_item_id text)
returns text
language sql
immutable
as $$
  select case p_item_id
    when 'starter' then 'red'
    when 'peach_soda' then 'red'
    when 'warm' then 'red'
    when 'red' then 'red'
    when 'mint_navy' then 'blue'
    when 'sunset_gold' then 'blue'
    when 'cool' then 'blue'
    when 'blue' then 'blue'
    when 'green' then 'green'
    when 'yellow' then 'yellow'
    when 'purple' then 'purple'
    when 'orange' then 'orange'
    when 'teal' then 'teal'
    when 'pink' then 'pink'
    else null
  end
$$;

create or replace function public.shop_normalized_owned_block_skins(p_item_ids text[])
returns text[]
language sql
immutable
as $$
  select array(
    select skin_id
      from (
        select distinct normalized.skin_id
          from (
            select public.shop_normalize_block_skin_id(raw_id) as skin_id
              from unnest(coalesce(p_item_ids, array[]::text[])) as raw_id
            union all
            select 'red'
            union all
            select 'blue'
          ) normalized
         where normalized.skin_id is not null
      ) items
     order by case skin_id
       when 'red' then 1
       when 'blue' then 2
       when 'green' then 3
       when 'yellow' then 4
       when 'purple' then 5
       when 'orange' then 6
       when 'teal' then 7
       when 'pink' then 8
       else 999
     end
  )
$$;

create or replace function public.shop_normalized_equipped_block_skins(
  p_item_ids text[],
  p_owned_item_ids text[],
  p_fallback_item_id text default 'red'
)
returns text[]
language sql
immutable
as $$
  with owned as (
    select public.shop_normalized_owned_block_skins(p_owned_item_ids) as ids
  ),
  ordered_candidates as (
    select public.shop_normalize_block_skin_id(raw_id) as skin_id,
           ord::int as ord
      from unnest(coalesce(p_item_ids, array[]::text[])) with ordinality as items(raw_id, ord)
    union all
    select public.shop_normalize_block_skin_id(p_fallback_item_id), 1000
    union all
    select 'blue', 1001
    union all
    select 'red', 1002
    union all
    select owned_item_id, (2000 + ord)::int
      from owned,
           unnest(ids) with ordinality as owned_items(owned_item_id, ord)
  ),
  filtered as (
    select candidate.skin_id,
           min(candidate.ord) as ord
      from ordered_candidates candidate,
           owned
     where candidate.skin_id is not null
       and array_position(owned.ids, candidate.skin_id) is not null
     group by candidate.skin_id
  )
  select array(
    select skin_id
      from filtered
     order by ord
     limit 2
  )
$$;

create or replace function public.shop_block_skin_price(p_item_id text)
returns int
language sql
immutable
as $$
  select case public.shop_normalize_block_skin_id(p_item_id)
    when 'red' then 0
    when 'blue' then 0
    when 'green' then 500
    when 'yellow' then 500
    when 'purple' then 500
    when 'orange' then 500
    when 'teal' then 500
    when 'pink' then 500
    else null
  end
$$;

create or replace function public.shop_state_json(
  p_coins int,
  p_owned_icons text[],
  p_owned_block_skins text[],
  p_equipped_icon text,
  p_equipped_block_skin text,
  p_equipped_block_skins text[] default null
)
returns jsonb
language sql
immutable
as $$
  with normalized as (
    select public.shop_normalized_owned_block_skins(p_owned_block_skins) as owned_ids,
           public.shop_normalized_equipped_block_skins(
             coalesce(p_equipped_block_skins, array[p_equipped_block_skin]::text[]),
             p_owned_block_skins,
             p_equipped_block_skin
           ) as equipped_ids
  )
  select jsonb_build_object(
    'coins', p_coins,
    'owned_icons', to_jsonb(p_owned_icons),
    'owned_block_skins', to_jsonb((select owned_ids from normalized)),
    'equipped_icon', p_equipped_icon,
    'equipped_block_skin', (select equipped_ids[1] from normalized),
    'equipped_block_skins', to_jsonb((select equipped_ids from normalized))
  )
$$;

update public.user_shop_data
   set owned_block_skins = public.shop_normalized_owned_block_skins(owned_block_skins),
       equipped_block_skins = public.shop_normalized_equipped_block_skins(
         coalesce(equipped_block_skins, array[equipped_block_skin]::text[]),
         owned_block_skins,
         equipped_block_skin
       ),
       equipped_block_skin = (
         public.shop_normalized_equipped_block_skins(
           coalesce(equipped_block_skins, array[equipped_block_skin]::text[]),
           owned_block_skins,
           equipped_block_skin
         )
       )[1]
 where game_key = 'link_your_area';

create or replace function public.shop_purchase_block_skin(
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
  v_item_id text;
  v_price int;
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_item_id := public.shop_normalize_block_skin_id(p_item_id);
  v_price := public.shop_block_skin_price(v_item_id);
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

  if array_position(public.shop_normalized_owned_block_skins(v_row.owned_block_skins), v_item_id) is not null then
    return public.shop_state_json(
      v_row.coins,
      v_row.owned_icons,
      v_row.owned_block_skins,
      v_row.equipped_icon,
      v_row.equipped_block_skin,
      v_row.equipped_block_skins
    );
  end if;

  if v_row.coins < v_price then
    raise exception '코인이 부족합니다.';
  end if;

  update public.user_shop_data
     set coins = v_row.coins - v_price,
         owned_block_skins = public.shop_normalized_owned_block_skins(
           array_append(v_row.owned_block_skins, v_item_id)
         )
   where id = v_row.id
  returning * into v_row;

  return public.shop_state_json(
    v_row.coins,
    v_row.owned_icons,
    v_row.owned_block_skins,
    v_row.equipped_icon,
    v_row.equipped_block_skin,
    v_row.equipped_block_skins
  );
end;
$$;

create or replace function public.shop_equip_block_skin(
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
  v_item_id text;
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_item_id := public.shop_normalize_block_skin_id(p_item_id);
  if public.shop_block_skin_price(v_item_id) is null then
    raise exception '아이템을 찾지 못했습니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if array_position(public.shop_normalized_owned_block_skins(v_row.owned_block_skins), v_item_id) is null then
    raise exception '구매한 아이템만 장착할 수 있습니다.';
  end if;

  update public.user_shop_data
     set owned_block_skins = public.shop_normalized_owned_block_skins(v_row.owned_block_skins),
         equipped_block_skins = public.shop_normalized_equipped_block_skins(
           array[
             v_item_id,
             coalesce(v_row.equipped_block_skins[2], 'blue')
           ]::text[],
           v_row.owned_block_skins,
           v_item_id
         ),
         equipped_block_skin = (
           public.shop_normalized_equipped_block_skins(
             array[
               v_item_id,
               coalesce(v_row.equipped_block_skins[2], 'blue')
             ]::text[],
             v_row.owned_block_skins,
             v_item_id
           )
         )[1]
   where id = v_row.id
  returning * into v_row;

  return public.shop_state_json(
    v_row.coins,
    v_row.owned_icons,
    v_row.owned_block_skins,
    v_row.equipped_icon,
    v_row.equipped_block_skin,
    v_row.equipped_block_skins
  );
end;
$$;

create or replace function public.shop_equip_block_skin_slot(
  p_item_id text,
  p_slot_index int,
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item_id text;
  v_row public.user_shop_data%rowtype;
  v_slots text[];
  v_other_slot_index int;
  v_previous_slot_value text;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_slot_index not in (1, 2) then
    raise exception '잘못된 컬러 슬롯입니다.';
  end if;

  v_item_id := public.shop_normalize_block_skin_id(p_item_id);
  if public.shop_block_skin_price(v_item_id) is null then
    raise exception '아이템을 찾지 못했습니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if array_position(public.shop_normalized_owned_block_skins(v_row.owned_block_skins), v_item_id) is null then
    raise exception '구매한 아이템만 장착할 수 있습니다.';
  end if;

  v_slots := public.shop_normalized_equipped_block_skins(
    coalesce(v_row.equipped_block_skins, array[v_row.equipped_block_skin]::text[]),
    v_row.owned_block_skins,
    v_row.equipped_block_skin
  );
  v_other_slot_index := case when p_slot_index = 1 then 2 else 1 end;
  v_previous_slot_value := v_slots[p_slot_index];
  v_slots[p_slot_index] := v_item_id;

  if v_slots[v_other_slot_index] = v_item_id then
    v_slots[v_other_slot_index] := v_previous_slot_value;
  end if;

  v_slots := public.shop_normalized_equipped_block_skins(
    v_slots,
    v_row.owned_block_skins,
    v_item_id
  );

  update public.user_shop_data
     set owned_block_skins = public.shop_normalized_owned_block_skins(v_row.owned_block_skins),
         equipped_block_skins = v_slots,
         equipped_block_skin = v_slots[1]
   where id = v_row.id
  returning * into v_row;

  return public.shop_state_json(
    v_row.coins,
    v_row.owned_icons,
    v_row.owned_block_skins,
    v_row.equipped_icon,
    v_row.equipped_block_skin,
    v_row.equipped_block_skins
  );
end;
$$;

revoke all on function public.shop_equip_block_skin_slot(text, int, text) from public;
grant execute on function public.shop_equip_block_skin_slot(text, int, text) to authenticated;

notify pgrst, 'reload schema';
