# V6.0 Plan — FWD Workbench (First Slice Implemented)

## 概要

v6.0 は単なる view consolidation ではなく、**業務設計者 / 非プログラマ向けの authoring-first workbench** として進める。

今回の first slice では、guided form builder から最小の業務モデルを作り、

1. validate する
2. runtime preview を見る

までを 1 つの pure surface にまとめた。

## 実装したもの

### 新パッケージ

- `src/workbench_v6/`
  - guided form builder の state
  - builder -> `@schema.Schema` 変換
  - validate / emit / runtime preview の pure evaluation
- `src/ui/workbench_v6/`
  - workbench HTML / MX renderer
  - `ViewContext` を使った plain / MX の統合
- `src/api_v6/`
  - `GET /v6/workbench`
  - `GET /v6/workbench?format=mx`
  - `POST /v6/workbench/preview`
  - `POST /v6/workbench/preview?format=mx`

### 新 fixture / tests

- `examples/workbench_v6/expected.html`
- `examples/workbench_v6/expected_mx.html`
- `examples/workbench_v6/expected_invalid.html`
- `examples/workbench_v6/purchase_request_expected.html`
- `src/workbench_v6/workbench_test.mbt`
- `src/ui/workbench_v6/view_test.mbt`
- `src/api_v6/api_test.mbt`

## first slice のスコープ

### In scope

- guided form builder
  - entity name
  - initial state
  - states
  - transitions
- builder から `@schema.Schema` を直接構築
- compiler / runtime を既存実装のまま再利用
- validation Reason をそのまま UI に表示
- state ごとの available transitions preview

## 実用ケース対応（追加）

- builder の slot 数を hidden field (`state_slots`, `transition_slots`) で保持し、
  state / transition を 3 件固定にせず可変で扱えるようにした
- `GET /v6/workbench?case=purchase-request` を追加し、
  **備品購入申請 / purchase request** を想定した practical preset を読み込めるようにした
- preset は次の流れをカバーする
  - `Draft -> Submitted`
  - `Submitted -> ManagerApproved | Rejected`
  - `ManagerApproved -> FinanceApproved | Rejected`
  - `FinanceApproved -> Ordered`

これにより、first slice のままでも「業務設計者が実務に近い承認フローをその場で validate / preview する」
という north-star demo を示せるようになった

### Out of scope

- graph / canvas editor
- entity attributes の高度編集
- rule / effect authoring UI
- persistence
- collaborative editing
- YAML export

## 設計判断

### canonical internal model

authoring artifact は guided form builder だが、内部 canonical は YAML 文字列ではなく
`src/schema/schema.mbt` の `@schema.Schema` を直接使う。

これにより:

- UI と compiler の責務を分離できる
- YAML を編集 UX の中心にしなくてよい
- export surface を後から追加しやすい

### compatibility

- `api_v2` 〜 `api_v5` の frozen contract は変更しない
- v6 は **新しい surface を追加**する形で入れる
- 既存の `src/ui/view_components/` と job timeline v6 renderer は enabler として維持する

## 次の候補

1. builder の入力概念を増やす
   - attributes
   - boundaries
   - simple preset rules
2. schema preview / export surface を加える
3. governance loop
   - diff
   - migration
   - release state
4. workbench 内で history / timeline / metrics 導線を束ねる
