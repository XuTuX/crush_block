-- ============================================================
-- Crush Block - Store Purchase Schema
-- 코인 충전은 App Store / Google Play 인앱결제로 처리한다.
-- 앱은 구매를 시작만 하고, 영수증 검증과 코인 적립은 서버만 수행한다.
-- ============================================================

create table if not exists public.user_store_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  game_key text not null default 'crush_block',
  store text not null check (store in ('app_store', 'google_play')),
  product_id text not null,
  purchase_id text,
  purchase_token text not null,
  transaction_date timestamptz,
  coin_amount int not null,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(store, purchase_token)
);

create index if not exists idx_user_store_purchases_user_game_created
  on public.user_store_purchases(user_id, game_key, created_at desc);

alter table public.user_store_purchases enable row level security;

drop policy if exists "store_purchases_select_own" on public.user_store_purchases;
create policy "store_purchases_select_own"
on public.user_store_purchases
for select
using (
  auth.uid() = user_id
  and game_key = 'crush_block'
);

create or replace function public.shop_store_product_coin_amount(p_product_id text)
returns int
language sql
immutable
as $$
  select case p_product_id
    when '500_coin' then 500
    when '1200_coin' then 1200
    when '2500_coin' then 2500
    else null
  end
$$;

create or replace function public.shop_grant_store_purchase(
  p_user_id uuid,
  p_store text,
  p_product_id text,
  p_purchase_token text,
  p_purchase_id text default null,
  p_transaction_date timestamptz default null,
  p_game_key text default 'crush_block',
  p_raw_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_coin_amount int;
  v_existing public.user_store_purchases%rowtype;
  v_shop public.user_shop_data%rowtype;
  v_purchase_exists boolean := false;
begin
  if p_user_id is null then
    raise exception 'user_id 가 필요합니다.';
  end if;

  if p_store not in ('app_store', 'google_play') then
    raise exception '지원하지 않는 스토어입니다.';
  end if;

  if nullif(trim(coalesce(p_purchase_token, '')), '') is null then
    raise exception 'purchase_token 이 필요합니다.';
  end if;

  v_coin_amount := public.shop_store_product_coin_amount(p_product_id);
  if v_coin_amount is null then
    raise exception '등록되지 않은 코인 상품입니다.';
  end if;

  insert into public.user_shop_data (user_id, game_key)
  values (p_user_id, p_game_key)
  on conflict (user_id, game_key) do nothing;

  select *
    into v_existing
    from public.user_store_purchases
   where store = p_store
     and purchase_token = p_purchase_token
   for update;
  v_purchase_exists := found;

  select *
    into v_shop
    from public.user_shop_data
   where user_id = p_user_id
     and game_key = p_game_key
   for update;

  if v_purchase_exists and v_existing.user_id <> p_user_id then
    raise exception '이미 다른 계정에 적립된 결제입니다.';
  end if;

  if v_purchase_exists and v_existing.id is not null then
    return jsonb_build_object(
      'purchase_id', v_existing.purchase_id,
      'awarded_coins', 0,
      'state', public.shop_state_json(
        v_shop.coins,
        v_shop.owned_icons,
        v_shop.owned_block_skins,
        v_shop.equipped_icon,
        v_shop.equipped_block_skin,
        v_shop.equipped_block_skins
      )
    );
  end if;

  insert into public.user_store_purchases (
    user_id,
    game_key,
    store,
    product_id,
    purchase_id,
    purchase_token,
    transaction_date,
    coin_amount,
    raw_payload
  )
  values (
    p_user_id,
    p_game_key,
    p_store,
    p_product_id,
    p_purchase_id,
    p_purchase_token,
    p_transaction_date,
    v_coin_amount,
    coalesce(p_raw_payload, '{}'::jsonb)
  );

  update public.user_shop_data
     set coins = v_shop.coins + v_coin_amount
   where id = v_shop.id
  returning * into v_shop;

  return jsonb_build_object(
    'purchase_id', p_purchase_id,
    'awarded_coins', v_coin_amount,
    'state', public.shop_state_json(
      v_shop.coins,
      v_shop.owned_icons,
      v_shop.owned_block_skins,
      v_shop.equipped_icon,
      v_shop.equipped_block_skin,
      v_shop.equipped_block_skins
    )
  );
end;
$$;

revoke all on function public.shop_grant_store_purchase(uuid, text, text, text, text, timestamptz, text, jsonb) from public;
grant execute on function public.shop_grant_store_purchase(uuid, text, text, text, text, timestamptz, text, jsonb) to service_role;
