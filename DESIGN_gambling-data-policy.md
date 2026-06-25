# DESIGN: 計測データ方針（gambling-data-policy）

着順管理アプリ（chakujun-kanri）における「利用状況の計測」に関する設計方針。
賭博性とは明示的に距離を取る全体方針（公開文書・UIの中立化）と整合させ、
**計測も最小限・非公開・非PII**で行う。

## 背景・原則
- 上位目的は収益化ではなく「**他人の利用数が伸びるのを計測して見る**」こと。
- 賭博距離の方針上、過剰な行動トラッキングはしない。**最小計測**を原則とする。
- 個人を特定するデータ（メール等）は指標として扱わない・表示しない・返さない。

## Phase A（今回実装）= 最小計測
- **指標**: 登録累計（Supabase `auth.users` を `created_at` で日次集計した新規数→累計）。
- **表示**: 登録累計の折れ線 ＋ ゴールライン（達成/未達が一目で分かる）。
  - ゴールは配列管理（フロント `METRIC_GOALS`）。初期は 20人（ゴール①）。
  - **達成後に第2ゴールを足せる構造**にしておく（例: 50人=ゴール②を配列に追記するだけ）。
- **閲覧面**: auth-gate 必須。**オーナー本人のみ**閲覧可。素のURLで公開しない。
  - フロント: `OWNER_EMAIL` 一致時のみ「指標」ボタン表示。
  - サーバ: RPC `registration_daily()`（SECURITY DEFINER）内で `auth.jwt()->>'email'` の
    一致を強制。EXECUTE 権限は `authenticated` のみ（anon=未ログインは不可）。
  - → publishable key が露出していても、オーナー以外は件数すら取得できない。

## スコープ外（Phase B で後置・今回作らない）
- DAU / WAU / MAU
- 継続率（リテンション）
- 7日移動平均などの平滑化指標

これらを入れる場合は**別RPC・別ビューを追加**し、`registration_daily()` は変更しない。

## 実装参照
- フロント: `index.html`
  - `OWNER_EMAIL` / `METRIC_GOALS` / `openMetrics()` / `renderMetrics()`（SVGで自前描画、外部ライブラリなし）
  - ホームヘッダの `#metrics-btn`（オーナー時のみ表示）→ `#metrics-view`
- サーバ: `metrics_registration.sql`（Supabase SQL Editor で一度だけ Run）
  - `public.registration_daily() returns table(day date, cnt int)`

## 関連
- 賭博性の方針（公開文書・UI中立化）と一体。UI中立化は 2026-06-25 完了済み。
