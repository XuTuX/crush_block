-- ============================================================
-- Link Your Area - Shop RPC Fix
-- This drops the conflicting 6-arg shop_state_json function
-- and updates all shop RPCs to correctly call shop_get_state
-- to prevent resetting character/portrait data.
-- Apply in Supabase SQL Editor
-- ============================================================

-- 1) Drop overloaded shop_state_json functions
DROP FUNCTION IF EXISTS public.shop_state_json(int, text[], text[], text, text, text[]);
DROP FUNCTION IF EXISTS public.shop_state_json(int, text[], text[], text, text);

-- 2) Update shop_purchase_icon
CREATE OR REPLACE FUNCTION public.shop_purchase_icon(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_price int;
  v_row public.user_shop_data%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  v_price := public.shop_icon_price(p_item_id);
  IF v_price IS NULL THEN
    RAISE EXCEPTION '아이템을 찾지 못했습니다.';
  END IF;

  PERFORM public.shop_ensure_user_data(p_game_key);

  SELECT *
    INTO v_row
    FROM public.user_shop_data
   WHERE user_id = v_user_id
     AND game_key = p_game_key
   FOR UPDATE;

  IF array_position(v_row.owned_icons, p_item_id) IS NOT NULL THEN
    RETURN public.shop_get_state(p_game_key);
  END IF;

  IF v_row.coins < v_price THEN
    RAISE EXCEPTION '코인이 부족합니다.';
  END IF;

  UPDATE public.user_shop_data
     SET coins = v_row.coins - v_price,
         owned_icons = array_append(v_row.owned_icons, p_item_id)
   WHERE id = v_row.id;

  RETURN public.shop_get_state(p_game_key);
END;
$$;

-- 3) Update shop_purchase_block_skin
CREATE OR REPLACE FUNCTION public.shop_purchase_block_skin(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_item_id text;
  v_price int;
  v_row public.user_shop_data%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  v_item_id := public.shop_normalize_block_skin_id(p_item_id);
  v_price := public.shop_block_skin_price(v_item_id);
  IF v_price IS NULL THEN
    RAISE EXCEPTION '아이템을 찾지 못했습니다.';
  END IF;

  PERFORM public.shop_ensure_user_data(p_game_key);

  SELECT *
    INTO v_row
    FROM public.user_shop_data
   WHERE user_id = v_user_id
     AND game_key = p_game_key
   FOR UPDATE;

  IF array_position(public.shop_normalized_owned_block_skins(v_row.owned_block_skins), v_item_id) IS NOT NULL THEN
    RETURN public.shop_get_state(p_game_key);
  END IF;

  IF v_row.coins < v_price THEN
    RAISE EXCEPTION '코인이 부족합니다.';
  END IF;

  UPDATE public.user_shop_data
     SET coins = v_row.coins - v_price,
         owned_block_skins = public.shop_normalized_owned_block_skins(
           array_append(v_row.owned_block_skins, v_item_id)
         )
   WHERE id = v_row.id;

  RETURN public.shop_get_state(p_game_key);
END;
$$;

-- 4) Update shop_equip_icon
CREATE OR REPLACE FUNCTION public.shop_equip_icon(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.user_shop_data%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  IF public.shop_icon_price(p_item_id) IS NULL THEN
    RAISE EXCEPTION '아이템을 찾지 못했습니다.';
  END IF;

  PERFORM public.shop_ensure_user_data(p_game_key);

  SELECT *
    INTO v_row
    FROM public.user_shop_data
   WHERE user_id = v_user_id
     AND game_key = p_game_key
   FOR UPDATE;

  IF array_position(v_row.owned_icons, p_item_id) IS NULL THEN
    RAISE EXCEPTION '구매한 아이템만 장착할 수 있습니다.';
  END IF;

  IF v_row.equipped_icon <> p_item_id THEN
    UPDATE public.user_shop_data
       SET equipped_icon = p_item_id
     WHERE id = v_row.id;
  END IF;

  RETURN public.shop_get_state(p_game_key);
END;
$$;

-- 5) Update shop_equip_block_skin
CREATE OR REPLACE FUNCTION public.shop_equip_block_skin(
  p_item_id text,
  p_game_key text default 'link_your_area'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_item_id text;
  v_row public.user_shop_data%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  v_item_id := public.shop_normalize_block_skin_id(p_item_id);
  IF public.shop_block_skin_price(v_item_id) IS NULL THEN
    RAISE EXCEPTION '아이템을 찾지 못했습니다.';
  END IF;

  PERFORM public.shop_ensure_user_data(p_game_key);

  SELECT *
    INTO v_row
    FROM public.user_shop_data
   WHERE user_id = v_user_id
     AND game_key = p_game_key
   FOR UPDATE;

  IF array_position(public.shop_normalized_owned_block_skins(v_row.owned_block_skins), v_item_id) IS NULL THEN
    RAISE EXCEPTION '구매한 아이템만 장착할 수 있습니다.';
  END IF;

  UPDATE public.user_shop_data
     SET owned_block_skins = public.shop_normalized_owned_block_skins(v_row.owned_block_skins),
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
   WHERE id = v_row.id;

  RETURN public.shop_get_state(p_game_key);
END;
$$;

-- 6) Update shop_equip_block_skin_slot
CREATE OR REPLACE FUNCTION public.shop_equip_block_skin_slot(
  p_item_id text,
  p_slot_index int,
  p_game_key text default 'link_your_area'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_item_id text;
  v_row public.user_shop_data%rowtype;
  v_slots text[];
  v_other_slot_index int;
  v_previous_slot_value text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  IF p_slot_index NOT IN (1, 2) THEN
    RAISE EXCEPTION '잘못된 컬러 슬롯입니다.';
  END IF;

  v_item_id := public.shop_normalize_block_skin_id(p_item_id);
  IF public.shop_block_skin_price(v_item_id) IS NULL THEN
    RAISE EXCEPTION '아이템을 찾지 못했습니다.';
  END IF;

  PERFORM public.shop_ensure_user_data(p_game_key);

  SELECT *
    INTO v_row
    FROM public.user_shop_data
   WHERE user_id = v_user_id
     AND game_key = p_game_key
   FOR UPDATE;

  IF array_position(public.shop_normalized_owned_block_skins(v_row.owned_block_skins), v_item_id) IS NULL THEN
    RAISE EXCEPTION '구매한 아이템만 장착할 수 있습니다.';
  END IF;

  v_slots := public.shop_normalized_equipped_block_skins(
    coalesce(v_row.equipped_block_skins, array[v_row.equipped_block_skin]::text[]),
    v_row.owned_block_skins,
    v_row.equipped_block_skin
  );
  v_other_slot_index := CASE WHEN p_slot_index = 1 THEN 2 ELSE 1 END;
  v_previous_slot_value := v_slots[p_slot_index];
  v_slots[p_slot_index] := v_item_id;

  IF v_slots[v_other_slot_index] = v_item_id THEN
    v_slots[v_other_slot_index] := v_previous_slot_value;
  END IF;

  v_slots := public.shop_normalized_equipped_block_skins(
    v_slots,
    v_row.owned_block_skins,
    v_item_id
  );

  UPDATE public.user_shop_data
     SET owned_block_skins = public.shop_normalized_owned_block_skins(v_row.owned_block_skins),
         equipped_block_skins = v_slots,
         equipped_block_skin = v_slots[1]
   WHERE id = v_row.id;

  RETURN public.shop_get_state(p_game_key);
END;
$$;

-- 7) Update shop_award_match_coins
CREATE OR REPLACE FUNCTION public.shop_award_match_coins(
  p_mode text,
  p_won boolean,
  p_game_key text default 'link_your_area'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_reward int;
  v_row public.user_shop_data%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  v_reward := public.shop_reward_amount(p_mode, p_won);
  IF v_reward IS NULL THEN
    RAISE EXCEPTION '잘못된 경기 모드입니다.';
  END IF;

  PERFORM public.shop_ensure_user_data(p_game_key);

  SELECT *
    INTO v_row
    FROM public.user_shop_data
   WHERE user_id = v_user_id
     AND game_key = p_game_key
   FOR UPDATE;

  UPDATE public.user_shop_data
     SET coins = v_row.coins + v_reward
   WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'awarded_coins', v_reward,
    'state', public.shop_get_state(p_game_key)
  );
END;
$$;



-- 9) Insert ranked_rating game to games table
INSERT INTO public.games (id, name, created_at)
VALUES ('link_your_area_ranked_rating', 'Link Your Area (Ranked)', now())
ON CONFLICT (id) DO NOTHING;

-- Revoke & Grant permissions for updated functions
REVOKE ALL ON FUNCTION public.shop_purchase_icon(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shop_purchase_block_skin(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shop_equip_icon(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shop_equip_block_skin(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shop_equip_block_skin_slot(text, int, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shop_award_match_coins(text, boolean, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.shop_purchase_icon(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_purchase_block_skin(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_equip_icon(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_equip_block_skin(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_equip_block_skin_slot(text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_award_match_coins(text, boolean, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
