## 業務モデルの中核：状態機械（DMMF / FP 再整理）

FWD における業務モデルの中核は **状態機械**である。  
ただし本設計では、一般的な「手続き的状態遷移」ではなく、  
**Domain Modeling Made Functional（DMMF）に基づく関数型の状態機械**として定義する。

---

### 状態機械の構成要素（FWD 文脈・再定義）

- **State**
  - 業務の現在位置
  - 同時に 1 つのみ
  - UI からは単なる「状態名」として扱う
  - 内部的には **Entity の型的文脈（State Tag）**として解釈される

- **Transition**
  - State A → State B への状態遷移
  - FWD では **1 操作 = 1 Transition** として UI / API に露出する
  - 内部的には以下の純粋関数として表現される：
    - `(Entity<S>, Input) -> Result<Entity<T>, Reason>`
  - UI 操作や API 呼び出しは、Transition を起動する **コマンド**として扱う

- **Rule（Guard）**
  - 遷移が成立するかどうかを判定する条件
  - 入力：
    - Entity のスナップショット（State + 属性）
    - 遷移時 Input / Payload
  - 出力：
    - `Ok`（遷移可能）
    - `Err(Reason)`（遷移不可の理由）
  - 純関数・副作用なし
  - UI では「実行可否」および「不可理由」の説明に利用される

- **Boundary（Role）**
  - 遷移を実行できる主体（Actor / Role）
  - BPMN のレーンと対応
  - 遷移そのものの正当性ではなく、
    - **「どの Transition を候補として提示するか」**
    を決定するために用いられる
  - HATEOAS により UI / API に反映される

- **Function（Domain Update / Effect）**
  - Transition の結果として「何が起こるか」を表す
  - 内部的には以下を分離して扱う：
    - **Domain Update**
      - Entity の更新
      - 状態確定
      - 純粋関数として表現される
    - **Effect**
      - 通知・外部 API 呼び出し等の副作用
      - 非同期処理として分離可能（Outbox / Saga 等）
  - 状態遷移の正しさは Domain Update の時点で完結させる

---

## 業務担当者が扱う最小概念セット（SEFRTB）

FWD では、業務担当者が直接扱う概念を **SEFRTB** に限定する。

| 概念 | 意味（業務担当者視点） |
|------|------------------------|
| **State** | 今どこか |
| **Entity** | 何を扱うか |
| **Function** | この操作で何が起こるか |
| **Rule** | できるか（理由つき） |
| **Transition** | 何をするか |
| **Boundary** | 誰ができるか |

※ 業務担当者は「フロー全体」や「内部状態遷移構造」を定義しない  
※ 全体の状態遷移グラフ（Workflow）は、  
　State / Transition の定義から **コンパイル時に自動導出**される
