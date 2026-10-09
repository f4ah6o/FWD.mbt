# FWD-02: 保存したtraceを再現し、定義変更による最初の差分を示す

- Status: Open
- Date: 2026-09-05 (Asia/Tokyo)
- Priority: P1
- Baseline: `a8c1e02c2d49a0aa4259d1105dee469ad0dec77c` (`main`)
- Depends on: [FWD-01](20260905-01-deterministic-transition-trace.md)
- Next: [FWD-03](20260905-03-workbench-execution-explanation.md)

## 目的

保存された「結果」の表示に加え、保存した定義と入力から同じ結果を作り直して一致を確認する。
AIが定義を変更した場合も、同じ申請シナリオのどのstepが変わるかを見られるようにする。
再実行は純粋なruntime計算だけ。effectsや実際の申請を再送しない。

## 読む範囲・変更範囲

- FWD-01の `src/execution_trace_v1/`。
- `src/runtime/execute.mbt`, `src/compiler/compiler.mbt`, `src/compiler/reason_json.mbt`。
- 新規 `replay.mbt`, `trace_parse.mbt`, `replay_test.mbt`、必要なtypes/JSON投影の追加。
- 新規fixturesは `examples/execution_trace_v1/` 内だけに追加する。

## 決定済みのAPI

1. `parse_trace(json)` → typed TraceDocument またはtrace入力Reason。
2. `replay_trace(document)` → ReplayReport。
3. `compare_trace(document, candidate_schema_source)` → ComparisonReport。

ReplayReportは `matched`, `checkedSteps`, `firstMismatch`（なければnull）。
firstMismatchはseqと、保存されたexpected／再計算したactual、異なったフィールド名を持つ。
ComparisonReportは `definitionChanged`, `differences`。differencesはseq順で、
各要素にbaseline／candidateのstepと異なるフィールド名を入れる。

## 実装手順

1. parserはtraceVersion=1、schemaFormat、型、resultの値、seqが1から連続することを検証する。
   inputRulesの名前重複を拒否する。JSONは最大1MiB、stepsは最大256、1stepのrulesは最大128。
   不明versionや不正形状はtrace用Reason（例TRACE_INVALID_DOCUMENT）を返し、既存Reason v1を変更しない。
2. replayはschemaSourceをcompileし、initialStateからFWD-01の記録関数で全要求を計算し直す。
   保存済みのstateAfterを次stepの入力に使わない。Mapの並び順ではなく規定の順序で比較する。
3. 比較対象はseq、要求transition、stateBefore/After、attemptedTo、ruleChecks、result、reasons、plannedEffects。
   Reasonのコードだけに縮めず、既存Reason JSONの内容と配列順を比較する。
   最初の不一致で停止し、checkedStepsは不一致stepを含む確認済み件数とする。
4. compareは最初に元traceをreplayする。一致しない元traceから変更の影響を論じず、TRACE_BASELINE_MISMATCHを返す。
   一致したらcandidate定義をcompileし、同じ要求とrule入力をinitialStateから順番に再計算する。
   候補側も自分自身の直前stateAfterを使う。差分は全stepのseq順で返す。
5. 定義のschemaVersionが同じでも、schemaSourceのbytesが違えばdefinitionChanged=trueにする。
   コメントだけの変更ならdefinitionChanged=trueかつdifferences=[]でもよい。
   「不正改ざんを検出する署名」や「業務上正しいことの証明」とは説明しない。
6. candidate fixtureではapproveのcanApproveを残して必須rule canApproveV2を追加し、対応するrule定義も追加する。
   元の入力にはcanApproveV2がないので、元traceの3step目executedに対しcandidateはblockedとなることを固定する。

## 必須の受け入れテスト

- `saved approval trace replays exactly`: serialize→parse→replayで3/3一致する。
- `replay does not trust recorded state`: stateAfterだけ書き換えた記録はそのstepで不一致。
- `replay detects changed rule input`: falseをtrueへ変更し結果を据え置くと不一致になる。
- `replay rejects invalid sequence and unknown version`: 0開始、欠番、重複seq、不明versionを拒否する。
- `candidate same version can change behavior`: version文字列が同じでも上の追加ruleによる差分を表示する。
- `candidate replay carries its own state`: 分岐後の次要求でbaseline状態を候補へ流用しない。
- `comment-only definition change has no outcome differences`。
- inputRulesの並び替えは意味を変えず、範囲上限を超える入力は決定的に拒否する。

## 検証と完了条件

```sh
moon check --target all src/execution_trace_v1
moon test src/execution_trace_v1
just ci
git diff --check
```

元のtraceを書き換えてテストを通すことは禁止。不一致を検出できるfixtureを必ず残す。
完了記録に「一致」「保存結果の不一致」「同versionの定義変更」の3例を載せる。
既存compiler baseline-diffの再実装、永続ストア、マイグレーション適用、外部effects実行は対象外。

- 再確認: 2026-10-09、main `0b9404c` 時点 — `src/execution_trace_v1/` 未作成(FWD-01 未着手)のため引き続き Open。
