# 実用化に向けた Implementation Plan (v1)

## 目的
- v1 プロトタイプを「現場で使える最小セット」へ引き上げる
- L1 スキーマの安定化と、検証・差分・IR 出力の再現性を担保する
- 以後の GUI / HATEOAS 実行基盤へ安全に接続できる土台を作る

## 目標スコープ (v1)
- CLI: validate / presets / IR emit が安定して動作し、JSON 出力が機械可読
- Schema: v1.0 を固定し、破壊的変更の検出と migration 要求を扱える
- IR: バージョン付き・決定的 (deterministic)・後方互換を前提とした JSON
- 参照解決・重複チェック・予約語衝突などの L1 ルールが網羅

## マイルストーン

### M0: 現状凍結とドキュメント整備
- v1 仕様 (schema/IR/rules) をドキュメントとして固定
- `schema/fwd_schema.yaml` と self-bootstrapping の期待動作を明記
- `just bootstrap` が常に通る状態に保つ

**DoD**
- 仕様の更新は必ず差分と理由を残す
- `just bootstrap` が CI で常時緑

### M1: Resolve/Validate の強化 (L1 準拠)
- 参照解決: states / transitions / rules / effects / boundaries / reasons
- `transitions.rules` が builtin / schema 定義のどちらかに必ず解決される
- 予約語衝突の検出 (builtin と同名ルール禁止)
- 状態・遷移の整合性 (from/to が state に存在) をチェック

**DoD**
- 代表的な不正入力に対する原因付きエラー (Reason) が返る
- 解決不能な参照は必ず ValidationFailure で落ちる

### M2: IR/Emit の安定化
- IR JSON のバージョンを固定し、出力順序を決定的にする
- normalize レイヤ (必要なら) を定義し、出力との差異を最小化
- golden test で YAML -> IR の差分検出を自動化

**DoD**
- 同一入力は必ず同一 IR JSON を出力
- 主要なサンプルが golden で固定

### M3: Baseline Diff / Migration ルール
- `noBreakingChanges` の範囲を v1 定義に合わせて実装
- `noBreakingChangesOrMigrationDefined` の migrate 判定を整理
- `--baseline` を使った差分検出が JSON 出力で完結する

**DoD**
- breaking がある場合の Reason が JSON で機械処理できる
- baseline 差分のユースケースが examples に存在

### M4: 実行基盤への最小接続 (HATEOAS / Runtime)
- IR から「現在可能な遷移」を計算する API を定義
- Reason を UI / API に返す最低限のフォーマットを固定
- CLI で IR + runtime の簡易検証が可能 (サンプル実装)

**DoD**
- 1 つのサンプルが CLI で遷移候補を列挙できる
- Reason が API 応答として整形可能

### M5: 配布・運用の最小整備
- CLI の usage / help を明確化
- 破壊的変更のルールを README に明記
- バージョン更新手順 (fwdVersion / schemaVersion) をドキュメント化

**DoD**
- 新規ユーザーが README だけで最小フローを実行可能

## クロスカット (常時実施)
- テスト: parse / resolve / validate / baseline のユニット + golden
- CI: `just ci` を品質ゲートにする
- ドキュメント: 仕様変更は必ず diff と理由を残す

## 直近 1-2 スプリントの具体タスク案
- Resolve/Validate 強化 (M1)
- IR JSON の決定性 + golden テスト (M2)
- baseline 差分の Reason 整備 (M3 の一部)

