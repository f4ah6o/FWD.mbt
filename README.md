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
  - Web（js/wasm）を含む **マルチランタイム**を前提にできる言語の不在を埋める存在
  - Rust は候補に近いが、システムプログラミング寄りで UI / UX 側が弱い

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

---

## 基本方針

1. **非プログラマの業務担当者が、仕事を表すモデルを作る**
2. **モデルはコンパイルすることで実行可能になる**
3. **UI（統一インターフェース）はモデルから生成される**
   - HATEOAS により「次にできる操作」を自己記述的に提示する
   - 実装基盤として HDA（mhx/tmpx）を利用する

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

※ **Workflow（全体フロー）は直接扱わせない**  
→ State + Transition の集合として **コンパイル時に内部生成**される。

---

## 内部正規形（コンパイル後モデル）

- **Workflow**
  - State と Transition の集合から生成される状態遷移グラフ
  - 検証用途：
    - 到達不能 State
    - 未使用 Transition
    - 権限不整合
- 業務担当者には見せないが、実行基盤・可視化・最適化に利用する

---

## L4: GUI に持ち込む BPMN の概念

- レーン → Boundary
- アクティビティ → Transition
- フロー → 状態遷移
- イベント → 遷移トリガ（UI 操作）

---

## FWD の設計要点まとめ

- 業務モデルの中心は **状態機械**
- 業務担当者には **SEFRTB のみを見せる**
- Workflow は **考えさせないが、内部では最重要**
- Make Illegal States Unrepresentable を
  - モデル構造
  - コンパイル
  - UI/HATEOAS
  の三層で保証する

---

## 現時点で未決定（意図的に保留）

- コンパイル成果物の具体形式
  - 状態機械ランタイム
  - API 定義
  - UI スキーマ
  - それらの組み合わせ
