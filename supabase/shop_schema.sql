-- ============================================================
-- Link Your Area - Shop Schema
-- Apply in Supabase SQL Editor
-- 재실행 안전: IF NOT EXISTS / DROP IF EXISTS 사용
-- ============================================================

-- ============================================================
-- 0) TABLE: user_shop_data
-- 유저별 상점 데이터 (코인, 보유 아이템, 장착 아이템)
-- game_key 로 link_your_area 전용 데이터 분리
-- ============================================================

create table if not exists public.user_shop_data (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null,
  game_key    text not null default 'link_your_area',
  coins       int  not null default 140,
  owned_icons      text[] not null default array['default_face']::text[],
  owned_block_skins text[] not null default array['red', 'blue']::text[],
  equipped_icon    text not null default 'default_face',
  equipped_block_skin text not null default 'red',
  equipped_block_skins text[] not null default array['red', 'blue']::text[],
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(user_id, game_key)
);

alter table public.user_shop_data
  add column if not exists equipped_block_skins text[] not null default array['red', 'blue']::text[];

-- ============================================================
-- 1) INDEXES
-- ============================================================

create index if not exists idx_user_shop_data_user_game
  on public.user_shop_data(user_id, game_key);

-- ============================================================
-- 2) TRIGGERS: updated_at 자동 갱신
-- ============================================================

-- set_updated_at 함수가 이미 multiplayer_mvp.sql에서 생성되어 있으므로
-- 트리거만 추가

drop trigger if exists trg_user_shop_data_updated_at on public.user_shop_data;
create trigger trg_user_shop_data_updated_at
before update on public.user_shop_data
for each row execute function public.set_updated_at();

-- ============================================================
-- 3) RLS POLICIES
-- ============================================================

alter table public.user_shop_data enable row level security;

-- 기존 정책 정리 (재실행 안전)
drop policy if exists "shop_select_own" on public.user_shop_data;
drop policy if exists "shop_insert_own" on public.user_shop_data;
drop policy if exists "shop_update_own" on public.user_shop_data;
drop policy if exists "shop_delete_own" on public.user_shop_data;

-- SELECT: 자기 자신의 상점 데이터만 조회 가능
create policy "shop_select_own"
on public.user_shop_data
for select
using (
  auth.uid() = user_id
  and game_key = 'link_your_area'
);

-- DELETE: 자기 자신의 상점 데이터만 삭제 가능 (회원 탈퇴 등)
create policy "shop_delete_own"
on public.user_shop_data
for delete
using (
  auth.uid() = user_id
  and game_key = 'link_your_area'
);

-- INSERT / UPDATE 는 직접 허용하지 않음.
-- 모든 상점 변경은 아래 SECURITY DEFINER RPC 를 통해서만 처리한다.

-- ============================================================
-- 4) HELPER FUNCTIONS
-- ============================================================

create or replace function public.shop_icon_price(p_item_id text)
returns int
language sql
immutable
as $$
  select case p_item_id
    when 'default_face' then 0
    when 'rocket' then 35
    when 'bolt' then 45
    when 'diamond' then 60
    when 'military' then 80
    else null
  end
$$;

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

create or replace function public.shop_reward_amount(
  p_mode text,
  p_won boolean
)
returns int
language plpgsql
immutable
as $$
begin
  case lower(coalesce(p_mode, ''))
    when 'ranked' then
      if p_won is true then
        return 24;
      elsif p_won is false then
        return 10;
      else
        return 16;
      end if;
    when 'friendly' then
      if p_won is true then
        return 18;
      elsif p_won is false then
        return 8;
      else
        return 12;
      end if;
    else
      return null;
  end case;
end;
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

-- ============================================================
-- 5) RPC: SERVER-AUTHORIZED SHOP MUTATIONS
-- ============================================================

create or replace function public.shop_ensure_user_data(
  p_game_key text default 'link_your_area'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  insert into public.user_shop_data (user_id, game_key)
  values (v_user_id, p_game_key)
  on conflict (user_id, game_key) do nothing;
end;
$$;

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
    v_row.equipped_block_skins
  );
end;
$$;

create or replace function public.shop_get_room_equipped_icons(
  p_room_id uuid,
  p_game_key text default 'link_your_area'
)
returns table (
  user_id uuid,
  equipped_icon text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if not exists (
    select 1
      from public.multiplayer_room_players p
     where p.room_id = p_room_id
       and p.user_id = v_user_id
  ) then
    raise exception '같은 방 참가자만 조회할 수 있습니다.';
  end if;

  return query
  select p.user_id,
         coalesce(s.equipped_icon, 'default_face') as equipped_icon
    from public.multiplayer_room_players p
    left join public.user_shop_data s
      on s.user_id = p.user_id
     and s.game_key = p_game_key
   where p.room_id = p_room_id;
end;
$$;

create or replace function public.shop_purchase_icon(
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
  v_price int;
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_price := public.shop_icon_price(p_item_id);
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

  if array_position(v_row.owned_icons, p_item_id) is not null then
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
         owned_icons = array_append(v_row.owned_icons, p_item_id)
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

create or replace function public.shop_equip_icon(
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

  if public.shop_icon_price(p_item_id) is null then
    raise exception '아이템을 찾지 못했습니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  if array_position(v_row.owned_icons, p_item_id) is null then
    raise exception '구매한 아이템만 장착할 수 있습니다.';
  end if;

  if v_row.equipped_icon <> p_item_id then
    update public.user_shop_data
       set equipped_icon = p_item_id
     where id = v_row.id
    returning * into v_row;
  end if;

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

  if public.shop_normalize_block_skin_id(v_row.equipped_block_skin) <> v_item_id then
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
  end if;

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

create or replace function public.shop_award_match_coins(
  p_mode text,
  p_won boolean,
  p_game_key text default 'link_your_area'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_reward int;
  v_row public.user_shop_data%rowtype;
begin
  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_reward := public.shop_reward_amount(p_mode, p_won);
  if v_reward is null then
    raise exception '잘못된 경기 모드입니다.';
  end if;

  perform public.shop_ensure_user_data(p_game_key);

  select *
    into v_row
    from public.user_shop_data
   where user_id = v_user_id
     and game_key = p_game_key
   for update;

  update public.user_shop_data
     set coins = v_row.coins + v_reward
   where id = v_row.id
  returning * into v_row;

  return jsonb_build_object(
    'awarded_coins', v_reward,
    'state', public.shop_state_json(
      v_row.coins,
      v_row.owned_icons,
      v_row.owned_block_skins,
      v_row.equipped_icon,
      v_row.equipped_block_skin,
      v_row.equipped_block_skins
    )
  );
end;
$$;

revoke all on function public.shop_get_state(text) from public;
revoke all on function public.shop_get_room_equipped_icons(uuid, text) from public;
revoke all on function public.shop_purchase_icon(text, text) from public;
revoke all on function public.shop_purchase_block_skin(text, text) from public;
revoke all on function public.shop_equip_icon(text, text) from public;
revoke all on function public.shop_equip_block_skin(text, text) from public;
revoke all on function public.shop_equip_block_skin_slot(text, int, text) from public;
revoke all on function public.shop_award_match_coins(text, boolean, text) from public;

grant execute on function public.shop_get_state(text) to authenticated;
grant execute on function public.shop_get_room_equipped_icons(uuid, text) to authenticated;
grant execute on function public.shop_purchase_icon(text, text) to authenticated;
grant execute on function public.shop_purchase_block_skin(text, text) to authenticated;
grant execute on function public.shop_equip_icon(text, text) to authenticated;
grant execute on function public.shop_equip_block_skin(text, text) to authenticated;
grant execute on function public.shop_equip_block_skin_slot(text, int, text) to authenticated;
grant execute on function public.shop_award_match_coins(text, boolean, text) to authenticated;

-- PostgREST schema cache reload
notify pgrst, 'reload schema';
