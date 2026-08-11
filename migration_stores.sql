-- ============================================================
-- stores マスタ化マイグレーション
-- 実行方法: Supabase ダッシュボード → SQL Editor に貼り付けて実行
-- 本番データを扱うため、実行前にバックアップ/スナップショットの取得を推奨
-- ============================================================

-- 1. stores テーブル作成
create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

-- 2. RLS 有効化 + ポリシー（select/insert/update/delete すべて qual と with_check を設定）
alter table public.stores enable row level security;

drop policy if exists stores_select on public.stores;
create policy stores_select on public.stores
  for select using (auth.uid() = user_id);

drop policy if exists stores_insert on public.stores;
create policy stores_insert on public.stores
  for insert with check (auth.uid() = user_id);

drop policy if exists stores_update on public.stores;
create policy stores_update on public.stores
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists stores_delete on public.stores;
create policy stores_delete on public.stores
  for delete using (auth.uid() = user_id);

-- 3. visits に store_id を追加（NOT NULL 制約はバックフィル確認後に別マイグレーションで付与）
alter table public.visits add column if not exists store_id uuid references public.stores(id);

-- 4. 既存データの移行
--    正規化ルール: 前後空白除去 + Unicode NFKC 正規化（全角英数字/記号/全角スペースを半角に統一）
--      NORMALIZE(x, NFKC) は PostgreSQL 13+ 標準搭載のためこの環境で利用可能
--    4-1. park_name から正規化した店舗名を distinct 抽出し stores に投入
insert into public.stores (user_id, name)
select distinct
  user_id,
  regexp_replace(normalize(trim(both from park_name), nfkc), '\s+', ' ', 'g') as norm_name
from public.visits
where park_name is not null and trim(park_name) <> ''
on conflict (user_id, name) do nothing;

--    4-2. 正規化後の名前で既存 visits に store_id をバックフィル
update public.visits v
set store_id = s.id
from public.stores s
where s.user_id = v.user_id
  and s.name = regexp_replace(normalize(trim(both from v.park_name), nfkc), '\s+', ' ', 'g')
  and v.store_id is null;

-- 5. 検証クエリ（結果をそのまま貼り付けて報告してください）
-- 5-1. バックフィル漏れがないか（unbackfilled が 0 であること）
select
  count(*) filter (where store_id is null) as unbackfilled,
  count(*) as total_visits_with_park_name
from public.visits
where park_name is not null and trim(park_name) <> '';

-- 5-2. RLS ポリシーの qual / with_check が両方埋まっているか確認
select schemaname, tablename, policyname, cmd, qual, with_check
from pg_policies
where tablename = 'stores';

-- ============================================================
-- 未実施（別途 名和 の判断待ち）:
--   - 旧 visits.park_name テキストカラムの削除可否
--   - store_id への NOT NULL 制約付与（バックフィル完全性確認後）
-- ============================================================
