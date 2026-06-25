-- ============================================================================
-- 着順管理アプリ — 最小計測（登録累計）用 RPC
-- 方針: DESIGN_gambling-data-policy.md の「最小計測」に準拠。
--   - 計測するのは登録累計のみ（DAU/WAU/継続率・移動平均は作らない＝Phase Bで後置）
--   - PII（メール等）は一切返さない。日次の新規登録「件数」だけを返す。
--   - 閲覧はオーナー(takahito.nawa@gmail.com)のみ。RPC内でメール一致を強制し、
--     EXECUTE 権限も authenticated だけに付与（anon=未ログインは呼べない）。
--   - データ源は auth.users（created_at＝登録日時）を SECURITY DEFINER で集計。
--
-- 適用方法: Supabase Dashboard → SQL Editor に貼り付けて Run（一度きり）。
-- 検証: SQL Editor 上（=サービスロール）では auth.jwt() が無くメールが NULL の
--       ため forbidden になる。実際の確認はアプリ（オーナーでログイン→「指標」）で行う。
-- ============================================================================

create or replace function public.registration_daily()
returns table (day date, cnt int)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- オーナー以外（および未ログイン）は弾く。素のURL/他ユーザーからは取得不可。
  if coalesce(auth.jwt() ->> 'email', '') <> 'takahito.nawa@gmail.com' then
    raise exception 'forbidden';
  end if;

  return query
    select date(u.created_at) as day, count(*)::int as cnt
    from auth.users u
    group by date(u.created_at)
    order by date(u.created_at);
end;
$$;

-- 権限: public/anon からは実行不可。authenticated のみ（さらに関数内でメール一致を強制）。
revoke all on function public.registration_daily() from public;
revoke all on function public.registration_daily() from anon;
grant execute on function public.registration_daily() to authenticated;

-- ----------------------------------------------------------------------------
-- 第2ゴール追加など指標拡張時もこの関数は不変（ゴールはフロント側 METRIC_GOALS で管理）。
-- Phase B（DAU等）を入れる場合は別関数を追加し、本関数は触らない方針。
-- ----------------------------------------------------------------------------
