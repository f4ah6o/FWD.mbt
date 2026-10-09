# FWD-03: 1申請1承認の実行理由をWorkbenchで確認する

- Status: Open
- Date: 2026-09-05 (Asia/Tokyo)
- Priority: P2
- Baseline: `a8c1e02c2d49a0aa4259d1105dee469ad0dec77c` (`main`)
- Depends on: [FWD-01](20260905-01-deterministic-transition-trace.md), [FWD-02](20260905-02-trace-replay-and-diff.md)

## 目的と現在の不足

`workbench_v6.evaluate_builder` は各stateのavailable/blockedを表示するが、
連続した実行の結果や再現結果は表示しない。builderのrule/effect編集も現在の対象外である。
既存builderを広げず、固定した小さな承認シナリオの入力を変えて挙動を確認する追加画面を作る。

## 最初に読むファイル

- `src/api_v6/api.mbt`: pureなApiRequest/ApiResponse、parse_form_body、handle_request。
- `src/ui/workbench_v6/workbench_view.mbt`: tmpxとViewContextによるHTML/MX投影。
- `src/workbench_v6/workbench.mbt`, `types.mbt`。
- `src/workbench_shadow_ci/main.mbt`, `justfile`, `V6_0_PLAN.md`。
- FWD-01/02のtrace APIと承認fixture。

## 追加するsurface

- `GET /v6/workbench/explain`: デフォルトはcan_approve=false。
- `POST /v6/workbench/explain`: form field `can_approve=missing|false|true`、`compare=none|extra-rule`。
- 両方で `format=mx` をサポート。それ以外のformatやfield値は400と既存形式のReason envelope。
- このAPIは既存と同じpure adapterであり、HTTP listenerやDBはこのissueで新設しない。

GETの初期画面には「申請→承認が止まる→入力を変えて再確認」を説明する。
POSTは記録を永続化せず、毎回同じ初期状態からtraceを計算する。実際の承認処理やメール送信はしない。

## 実装手順

1. `src/workbench_v6/explanation.mbt` に専用ExplanationModelと評価関数を追加する。
   既存WorkbenchModelに必須fieldを増やさない。
   型は `src/execution_trace_v1` のTraceDocument/ReplayReport/ComparisonReportを利用する。
2. このデモが使う最小YAMLはFWD-01のapproval.yamlと同じ内容の定数を持つ。
   production実行時にfixtureファイルを読み込まない。テストで定数とfixtureの一致を検証して重複のずれを防ぐ。
3. 要求はsubmit→approve(選択値)の2stepに固定。missingでは入力にcanApproveキーを入れない。
   traceを作ってreplayし、compare=extra-ruleならFWD-02のcandidate定義でも比較する。
   入力のboolを外部の権限確認の実結果と呼ばず、画面に「シミュレーション用のルール結果」と表示する。
4. 新規 `src/ui/workbench_v6/explanation_view.mbt` でHTML/MXを投影する。
   表の列はstep、操作、変更前、変更後、結果。各stepの詳細でrule名・値（未提供/false/true）とReasonを示す。
   replayの一致件数と、候補定義を比較した場合の最初の変化を表示する。
   原因文章を推論せず、traceの値とReasonを表示する。
5. `src/api_v6/api.mbt` に上記2routeを追加し、既存form parser/response helperを使う。
   `format=mx` は `.fwd-workbench-explanation` にouterHTML swapする契約で固定する。
   フォーム選択値は再描画後も保持する。文字列はtmpx.text/attr helperでescapeする。
6. 新規JSON/HTML/MX fixturesを `examples/workbench_v6/explanation/` に追加する。
   README.mbt.mdとV6_0_PLAN.mdに追加routeと手順を記録する。
   既存 `/v6/workbench` の応答やpurchase-request presetは変えず、新画面に戻るリンクを付ける。

## 必須の受け入れテスト

- GET/POSTを `ApiRequest` で実行し、falseとmissingはSubmittedでblocked、trueはApprovedでexecuted。
- 未提供とfalseは別表示になり、両方に元のRULE_NOT_SATISFIEDが出る。
- すべての有効な選択で自分のtraceのreplayが2/2一致。
- extra-rule候補では、true入力でも候補がSubmittedに留まる理由canApproveV2=未提供を表示する。
- 不明値、不正format、POST bodyなしは400。HTTP/networkやeffects runnerは呼ばない。
- plainとMXの業務内容は同じで、異なるのは必要なmx属性だけ。
- テンプレートに渡した `<script>` 等がescapeされる。
- api_v2〜api_v5と既存v6のfixturesが無変更で通る。

## 検証と完了条件

```sh
moon check --target all src/execution_trace_v1 src/workbench_v6 src/ui/workbench_v6 src/api_v6
moon test src/execution_trace_v1
moon test src/workbench_v6
moon test src/ui/workbench_v6
moon test src/api_v6
just workbench-shadow-ci
git diff --check
```

all-target対象にJS専用 `src/ui/client` を混ぜない。JS smokeは既存just recipeで確認する。
新しい画面のHTMLを目視確認し、入力・blocked理由・再現結果・定義差分を辿れることを記録する。
本issueの完了を「実運用の承認システムが完成した」とは扱わない。
DB、kintone接続、BPMN、帳票、SQL、多段/並列承認、汎用rule editorは対象外。

- 再確認: 2026-10-09、main `0b9404c` 時点 — `src/workbench_v6/explanation.mbt`、`src/ui/workbench_v6/explanation_view.mbt`、`/v6/workbench/explain` ルートは未実装のため引き続き Open。
