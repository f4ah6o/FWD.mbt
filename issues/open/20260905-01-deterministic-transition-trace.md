# FWD-01: 既存runtimeの判断を入力付きのtraceとして記録する

- Status: Open
- Date: 2026-09-05 (Asia/Tokyo)
- Priority: P1
- Baseline: `a8c1e02c2d49a0aa4259d1105dee469ad0dec77c` (`main`)
- Depends on: なし
- Next: [FWD-02](20260905-02-trace-replay-and-diff.md), [FWD-03](20260905-03-workbench-execution-explanation.md)

## 目的と現在の不足

`src/runtime/execute.mbt` に純粋な `execute_transition`、`history_v2_1` に追記型の履歴がある。
ただし履歴契約には実行時の定義snapshotとrule結果の完全な再現契約がない。
新しいtraceを既存runtimeの外側に追加し、「どの入力で、なぜ止まり、いつ状態が変わったか」を説明する。

最初の実証はDraft→Submitted→Approvedの1申請1承認に限定する。
既存のpurchase-request presetを置換したり、多段承認や新しい評価エンジンを作ったりしない。

## 最初に読むファイル

- `src/runtime/execute.mbt`, `runtime.mbt`, `reasons.mbt`。
- `src/compiler/compiler.mbt`: `compile_yaml`。
- `src/compiler/reason_json.mbt`: Reason v1の投影。
- `src/history_v2_1/history.mbt`: 既存契約との違いを確認するためだけに読む。
- `examples/schema_v1.yaml`, `src/runtime/runtime_test.mbt`, `moon.mod.json`。

## 変更範囲

新規 `src/execution_trace_v1/{moon.pkg,types.mbt,record.mbt,trace_json.mbt,trace_test.mbt}` と
`examples/execution_trace_v1/`。production依存はcore/compiler/ir/runtimeと標準ライブラリだけ。
既存runtime・Reason v1・CLI出力・history_v2_1・api_v2〜api_v5の契約とfixtureを変更しない。

## 決定済みの契約

- `TraceRequest`: transition IDと `Map[String, Bool]` のrule結果。
- `TraceDocument`: `traceVersion=1`, `schemaFormat="yaml-v1"`, `schemaSource`, `initialState`, `steps`。
  schemaSourceは実行に使った元のYAML全文を保持する。version文字列だけで同一定義と見なさない。
- 各step: 1開始のseq、要求transition、stateBefore、stateAfter、attemptedTo（不明ならnull）、
  inputRules、ruleChecks、result（executed/blocked/invalid）、reasons、plannedEffects。
- inputRulesは入力された全ruleを名前順の `{name,value}` arrayにコピーする。
- ruleChecksはruntimeが実際にrule判定まで進んだ場合だけ、遷移のrule_refs順に
  `{name,value}` を出す。欠損はnull、falseはfalse。invalidの場合は空配列。
- reasonsはruntimeのReasonを `@compiler.reason_json` でそのまま投影する。
- plannedEffectsはruntimeが返したeffectの記述。外部処理を実行した証拠という意味を持たせない。

## 実装手順

1. `record_trace(schema_source, initial_state, requests)` を追加。compile_yamlは最初に1回だけ呼ぶ。
   parse/resolve/validateの失敗は既存CompileErrorで返し、成功したtraceを偽造しない。
2. 1stepのpure helperで `@runtime.execute_transition` を1回呼び、outcomeを記録する。
   ExecutedだけstateAfterを遷移先へ進め、Blocked/Errでは元の状態を保持する。
   ErrはinvalidとしてReasonを記録する。次stepは実際のstateAfterから計算する。
3. `inputRules` は参照を保持せずコピーする。入力Mapの挿入順でtraceが変わらないようにする。
   ruleChecksを作るためにルールを再評価しない。渡されたbool/nullという事実を写すだけにする。
4. trace専用のJSON serializerを用意。キー順を固定し、文字列を正しくJSON escapeする。
   `@compiler.ir_to_json` の未ソートstateGraph.nodesをそのままfingerprintに使わない。
   このissueではhashや暗号署名を導入しない。
5. `examples/execution_trace_v1/approval.yaml` にDraft/Submitted/Approved、submit、approve、
   カスタムrule `canApprove` を持つ最小定義を追加する。rule定義は次の対応に固定する。
   `rules` の定義: `{name: canApprove, type: custom, impl: canApprove}`。
   approve遷移のrulesは文字列 `canApprove` への参照とする（YAMLでは既存fixture同様のblock記法を使う）。
6. 要求列を固定する: submit → approve(false) → approve(true)。
   期待結果はDraft→Submitted、Submittedのまま、Submitted→Approved。
   その完全なJSONを `expected_approval.json` としてfixtureにする。

## 必須の受け入れテスト

- `approval trace records blocked then executed`: 上記3step、2step目のReasonはRULE_NOT_SATISFIED。
- `missing and false rule inputs remain distinct`: どちらもblockedだがruleChecksのnull/falseが区別される。
- `invalid requests preserve state`: stateなし、transitionなし、from不一致でstateAfterが変わらず、元Reasonを保持する。
- `trace is independent of input map insertion order`: 等しい入力Mapから同じJSON bytes。
- `trace snapshots do not alias caller input`: 呼出後に入力Mapを変更しても記録が変化しない。
- `planned effects are never executed`: effectありの定義でも外部I/Oなしで記述だけが返る。
- 日本語・改行・引用符を含むschemaSourceがJSON往復で壊れない。

## 検証と完了条件

```sh
moon check --target all src/execution_trace_v1
moon test src/execution_trace_v1
just ci
git diff --check
```

本issue単独で実装・検証する。既存のfixtureは新しい動作に合わせて書き換えない。
完了記録には追加API、fixture、実行結果を記載する。
日時・乱数・ネットワーク・DB・外部rule評価・既存APIのversion upは対象外。
