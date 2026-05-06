with ranked_duplicates as (
  select id
    from (
      select id,
             row_number() over (
               partition by user_id, game_id
               order by updated_at desc nulls last, id desc
             ) as row_num
        from public.scores
    ) ranked
   where ranked.row_num > 1
)
delete from public.scores
 where id in (select id from ranked_duplicates);

create unique index if not exists ux_scores_user_game
  on public.scores(user_id, game_id);

create or replace function public.shop_award_match_coins(
  p_mode text,
  p_won boolean,
  p_game_key text default 'crush_block'
)
returns jsonb
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

  perform public.shop_ensure_user_data(p_game_key);

  return jsonb_build_object(
    'awarded_coins', 0,
    'state', public.shop_get_state(p_game_key)
  );
end;
$$;

revoke all on function public.shop_award_match_coins(text, boolean, text) from public;
grant execute on function public.shop_award_match_coins(text, boolean, text) to authenticated;

notify pgrst, 'reload schema';
