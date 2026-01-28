## アイデア

一言で言うと：

- **FWD = Domain Modeling Made Functional の GUI 化 + 実行基盤**
- あるいは  
  **FWD = 関数型 DDD を業務担当者が触れる形にしたもの**

---

## FWD（Functional Work Design）の位置づけ

### 目的

FWD は思想文ではなく、  
**既に確立した強力な概念を接続し、実装可能なフレームワークとして成立させること**を目的とする。

---

## 実装言語

- **MoonBit**
  - Web（js / wasm）とネイティブを同一言語で扱える点を重視
  - FWD では以下を同一言語で実装する必要がある：
    - 業務モデルの検証・コンパイル
    - HATEOAS レスポンス生成
    - ブラウザ上で動作する検証・プレビュー
  - Rust は候補に近いが、FPじゃない、システムプログラミング寄りで UI / UX 側が弱い
  - **Gleam / Grain は Before LLM**
  - **MoonBit は After LLM**
    - coding agent（LLM）との相性を優先し、MoonBit を採用する

---

## REST の制約（思想的前提）

- Make Illegal States Unrepresentable
- DMMF と HATEOAS
- ハイパーメディアとドメイン駆動のインターフェース

---

## HATEOAS 実装（HDA / mhx + tmpx）

- **HATEOAS を実現する HDA ライブラリを作成中**
- **FWD で利用することも目的の一つ**
- 構成（現時点の方向性）
  - **mhx runtime（JS/Wasm）**
  - **mhx-spec（pure MoonBit）**
  - **tmpx（all targets）**

---

## レイヤー定義

- **L0: 前提**  
  FP（関数型プログラミング）

- **L1: 思想**  
  DMMF（Domain Model Made Functional）

- **L2: フレームワーク**  
  FWD

- **L3: 動作**  
  CLI / コード

- **L4: GUI**

- **L5: マジカ化**  
  業務を「触れるもの」にする  
  https://www.magicaland.org  
  - マジカは「カードで業務定義（洗い出し・改善）を行う」ツール
  - 内部的には **業務フローチャートを作ることと同値**
  - よって FWD では、Workflow の入力 UI（カードUI）として統合可能

---

## 基本方針

1. **非プログラマの業務担当者が、仕事を表すモデルを作る**
2. **モデルはコンパイルすることで実行可能になる**
3. **UI（統一インターフェース）はモデルから生成される**
   - HATEOAS により「今できる操作」を自己記述的に提示する
   - UI / API / 自動化で状態判定ロジックを共有する

---

## 業務モデルの中核：状態機械

FWD における業務モデルの中核は **状態機械**である。

### 状態機械の構成要素（FWD文脈）

- **State**
  - 業務の現在位置
  - 同時に 1 つのみ
  - Entity の属性として保持される

- **Transition**
  - State A → State B への状態遷移
  - FWD では **1 操作 = 1 Transition** として定義
  - UI 操作・API エンドポイントと 1:1 対応

- **Rule（Guard）**
  - 遷移を実行してよいかを判定する条件
  - 入力：
    - Entity のスナップショット（State + 属性）
    - 遷移時 Input / Payload
  - 出力：true / false
  - 純関数・副作用なし

- **Boundary（Role）**
  - 遷移の実行主体
  - BPMN のレーンと対応
  - UI 上で「どの操作を出すか」を決定する根拠

- **Function（Action / Effect）**
  - 遷移確定後に実行される処理
  - 同期処理（DB 更新等）は状態遷移と同一トランザクション
  - 非同期処理（通知・外部 API）は Outbox / Saga 等で分離可能

---

## 業務担当者が扱う最小概念セット（SEFRTB）

FWD では、業務担当者が直接扱う概念を **SEFRTB** に限定する。

| 概念 | 意味 |
|------|------|
| **State** | 今どこか |
| **Entity** | 何を扱うか |
| **Function** | 何が起こるか |
| **Rule** | できるか |
| **Transition** | 何をするか |
| **Boundary** | 誰がするか |

---

## Workflow（可視化と逆変換）

### 位置づけ
- **Workflow（全体フロー）は直接扱わせない**
- ただし Workflow は **全体像の可視化・合意形成・レビュー**に必須
- よって Workflow は：
  - **コンパイル結果として生成され**
  - **BPMN 風（レーン付き）で可視化される**

### 可視化の方針
- レーン（Lane）を含む図として提示する
- 「レーン付きフローチャート」でもよい（BPMN準拠である必要はない）

### 逆変換（重要）
- 可視化された Workflow（図）から、
  - **State**
  - **Transition**
  - **Boundary（= Lane/Role）**
  を **逆変換**できるようにする

---

## Workflow（可視化と逆変換）

- Workflow は **内部正規形**
- State + Transition から自動生成される
- BPMN 風、またはレーン付きフローチャートとして可視化

### 逆変換
- 図から以下を抽出可能にする：
  - State
  - Transition
  - Boundary（Lane）
- 既存業務図・マジカとの統合を可能にする

---

## HATEOAS レスポンス（最小返却要素）

HATEOAS レスポンスは **主に UI 向け**に設計されるが、  
同一情報を **API 契約の補助情報としても利用可能**とする。

- **Entity**
- **State**
- **Actions（実行可能な Transition 群）**
  - name
  - href / method
  - role
  - inputSchema
  - uiHints（optional）

※ 固定 API（OpenAPI 等）と併存させる

---

## L5: マジカとの統合

- マジカはカードで業務を洗い出すツール
- 内部的には業務フローチャートと同値
- FWD では：
  - Workflow 入力 UI の一形態として位置づける
  - カード → 図 → SEFRTB → コンパイル
  の流れを作る

---

## FWD の設計要点まとめ

- 業務モデルの中心は **状態機械**
- 業務担当者には **SEFRTB のみを見せる**
- Workflow は **考えさせないが、可視化はする**
- Make Illegal States Unrepresentable を
  - モデル構造
  - コンパイル
  - UI/HATEOAS
  の三層で保証する
