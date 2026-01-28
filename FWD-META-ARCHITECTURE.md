# FWD メタアーキテクチャ：自己記述とコンパイルパイプライン（再レビュー反映・v1確定）

## 設計原則（不変）

FWD は **自己言及可能なメタフレームワーク**として設計される。

- FWD のスキーマ定義自体が **FWD の状態機械（L0）で記述**される
- 具体ドメインモデルは FWD 定義から **コンパイル（導出）**される
- フレームワーク自身の進化も **型安全・Reason付き**で管理される


---

## レイヤ構造（L0 / L1 / L2）

┌─────────────────────────────────────────────┐
│  L0: FWD Core（プリミティブ・固定点）      │
└─────────────────────────────────────────────┘
                    ↓ bootstrap
┌─────────────────────────────────────────────┐
│  L1: FWD Schema（メタモデル・自己記述）    │
└─────────────────────────────────────────────┘
                    ↓ compile
┌─────────────────────────────────────────────┐
│  L2: Domain Model（ユーザー定義）           │
└─────────────────────────────────────────────┘


---

## 1. L0 / L1 境界の明示（確定）

| 概念 | L0（プリミティブ） | L1（メタモデル） |
|---|---|---|
| State | `StateTag`（識別子型） | `StateDefinition` |
| Entity | `Entity<S>` 型コンストラクタ | `EntityDefinition` |
| Transition | 関数シグネチャ | `TransitionDefinition` |
| Rule | `(E, I) -> Result<void, Reason>` | `RuleDefinition + RuleExpression` |
| Reason | `{ code, message, context }` | `ReasonDefinition（コード体系）` |
| Boundary | Role / Actor 型 | `BoundaryDefinition` |

- **L0 は意味論のみ**を提供（凍結・自己記述しない）
- **L1 は構造と制約**を定義（自己記述対象）
- この分離により無限後退を回避する


---

## 2. RuleExpression の定義（v1確定）

v1 では **二層構え**とする。

### 2.1 宣言的プリセット（標準）

- あらかじめ定義された Rule 群を参照
- 検証可能・可視化可能・移植可能

```yaml
rules:
  - type: hasAtLeastOneState
  - type: allReferencesResolved
  - type: noBreakingChanges
```

対応する L0 実装は **純粋関数**。
v1 の `noBreakingChanges` は **state / transition の削除検出のみ**を対象とし、from/to 変更や rename 判定は v1.2+ に繰り越す。
`noBreakingChangesOrMigrationDefined` は v1 では **breaking が検出された場合の migrate 指定**のみを要求する。
- transition modified: 該当 transition に `effects: [migrate]`
- transition removed / state removed: グローバル `effects: [migrate]`

### 2.2 Escape Hatch（実装関数）

- 宣言的ルールで表現不能な場合のみ使用
- v1 では **MoonBit 関数参照**に限定
- スキーマ上は「不透明な Rule」として扱う

```yaml
rules:
  - type: custom
    impl: schemaRules::checkMigrationCompleteness
```

#### 設計判断
- v1で汎用式言語（CEL等）は導入しない
- 表現力と実装コストのバランスを優先
- v2以降で DSL / 式言語を検討可能


---

## 3. L1: FWD Schema の状態機械（自己記述の実体）

### SchemaState

```yaml
states:
  - Draft
  - Reviewing
  - Released
  - Deprecated
```

### Schema Transitions（確定例）

```yaml
transitions:
  - name: submitForReview
    from: Draft
    to: Reviewing
    rules:
      - hasAtLeastOneState
      - hasAtLeastOneTransition
      - allReferencesResolved

  - name: approve
    from: Reviewing
    to: Released
    rules:
      - noBreakingChangesOrMigrationDefined

  - name: deprecate
    from: Released
    to: Deprecated
    effects:
      - notifyDependentSchemas
```

- **L1 自身が FWD の管理対象**
- スキーマ変更はすべて Transition として記録される


---

## 4. コンパイルパイプライン（v1）

### ステージ

1. Parse  
2. Resolve  
3. Validate（L1準拠・Reason付き）
4. Normalize  
5. Infer（任意）
6. Emit  
7. Package  

v1 実装では **Parse → Validate → Emit** から開始可能。


---

## 5. FWD-IR 定義（具体化）

### DirectedGraph（自前定義）

```ts
type DirectedGraph<N, E> = {
  nodes: Set<N>
  edges: Map<N, Map<N, E>>  // from -> to -> edge
}
```

### FWD-IR（v1）

```ts
type FwdIR = {
  version: string          // IR version
  fwdVersion: string       // L0 dependency

  stateGraph: DirectedGraph<StateTag, TransitionRef>

  entities: Map<string, NormalizedEntity>
  transitions: Map<string, NormalizedTransition>
  rules: Map<string, CompiledRule>
  reasons: Map<string, ReasonSpec>
  effects: Map<string, EffectSpec>
}
```

- IR は **後方互換前提**
- 正規形 Transition:

```
(Entity<S>, Input) -> Result<Entity<T>, Reason>
```


---

## 6. バージョニング戦略（確定）

### L0（Core）
- SemVer
- 破壊的変更はメジャーのみ

### L1 / L2
- スキーマ先頭で依存宣言必須

```yaml
fwdVersion: "1.0"
schemaVersion: "1.2"
```

- L0 破壊的変更時は **Migration Transition** を L1 に定義


---

## 7. Effect の v1 スコープ（確定）

| Effect種別 | v1対応 | 実装方式 |
|---|---|---|
| 同期Effect | ○ | Transition後に即時実行 |
| 非同期Effect | △ | Outbox + ポーリング |
| Saga | × | v2以降 |

- Effect 失敗でも **状態はロールバックしない**


---

## 8. 結論（表現調整）

FWD は

> **業務モデル・スキーマ・その進化を  
> 同一の状態機械原理で扱うための基盤**

である。

具体的には：

- **スキーマ変更のレビュー・承認**が Transition
- **互換性違反**が Reason として可視化
- **移行手順**が Effect として分離される

この構造により、  
フレームワーク自身と業務ドメインの進化が  
**同じ型・同じ検証原理で管理可能**になる。

---
## 9. Bootstrap Strategy (v1)

本章は、FWD の自己記述（L1 を L0 上で運用し、以後の進化を型安全に管理する）を成立させるための **root of trust** と **初回コンパイル手順**、および **以後の変更正当化ルール**を明文化する。

### 目的

- 「最初の L1 スキーマ YAML は誰が/どう信頼するか」を明確化する
- 「その YAML をどう検証・固定するか（golden IR の扱い）」を定義する
- 「以後の変更をどう正当化するか（Transition とルール運用）」を規定する

---

### 9.1 Seed Artifact（Root of Trust）

#### Seed の定義

- `schema/fwd_schema.yaml` を **手書きの Seed Artifact** として用意する
- Seed は **L1 スキーマそのもの**（FWD の書き方）を表現する最初の入力である

#### Root of Trust

- Seed の信頼は、以下の2点により成立する：
  1. **L0 実装（固定点）**が提供する validator によって検証されること
  2. Seed がリポジトリにコミットされ、レビュー・署名（運用）により保護されること

> v1 では Seed は「自己記述で生成される」のではなく、自己記述を開始するための **初期値**として扱う。

---

### 9.2 Seed Validation（初回検証）

Seed は CLI で検証される。

- 実行：`moon run cli -- validate schema/fwd_schema.yaml`
- 成功：`ok`（exit code 0）
- 失敗：`parse/resolve/validation error ...` を表示し、exit code 1

#### Validation Rules（v1 実装準拠）
L0 実装の `validate_schema` で、以下を最低保証する：

- `fwdVersion` / `schemaVersion` が空でない
- `states` / `transitions` が空でない
- `state/transition/entity/effect/rule/reason/boundary` の **名称が空でない**かつ**重複しない**
- `entity.initialState` が空でなく、`states` に存在する
- `transition.from/to` が `states` に存在する
- `transition.rules` が **解決可能**（preset 名が存在、custom の impl 名が空でない）
- `transition.effects` が `effects` に存在する

#### Resolve Rules（v1 実装準拠）
`resolve_schema` で、以下を保証する：

- Builtin preset 名の一覧をルールインデックスに登録
- スキーマ定義の `rules:` は **builtin 名と衝突禁止**
  - 衝突した場合は resolve error

---

### 9.3 First Compile（初回コンパイル）

初回検証に成功した Seed から、初回の IR を生成する。

- 入力：`schema/fwd_schema.yaml`
- 実行：`moon run cli -- schema/fwd_schema.yaml schema/fwd_schema.ir.json`
- 出力：`schema/fwd_schema.ir.json`

この IR は **Seed の機械可読な固定結果**であり、以後の golden として扱う。

---

### 9.4 Golden Check（固定と差分レビュー）

#### Golden Artifact

- `schema/fwd_schema.ir.json` を **Golden Artifact** としてリポジトリにコミットする

#### Golden Check の規則

- 以後の変更では、CI で常に以下を実行する：
  1. `moon run cli -- schema/fwd_schema.yaml schema/fwd_schema.ir.json` で IR を生成
  2. committed な `schema/fwd_schema.ir.json` と比較
  3. v1 は **同一テキスト比較**で検証する（`json.stringify(indent=2)` が安定）

- 差分があれば CI 失敗

#### 例外（Golden Update）

- `schema/fwd_schema.ir.json` の更新は許可されるが、必ず以下を満たす：
  - 差分が PR 上でレビュー可能な形で提示される
  - 変更理由が Change Policy（後述）により正当化されている

> v1 の golden は「正しさの証明」ではなく、**root of trust の固定点を破壊しないための検知装置**である。

---

### 9.5 Change Policy（正当化：Transition による変更管理）

L1 スキーマ変更は「編集」ではなく、**状態遷移（Transition）としてのみ正当化**される。

#### L1 SchemaState（運用状態）
```yaml
states:
  - Draft
  - Reviewing
  - Released
  - Deprecated
```

#### 許可される遷移
```yaml
transitions:
  - name: submitForReview
    from: Draft
    to: Reviewing
    rules:
      - hasAtLeastOneState
      - hasAtLeastOneTransition
      - allReferencesResolved

  - name: approve
    from: Reviewing
    to: Released
    rules:
      - noBreakingChangesOrMigrationDefined

  - name: deprecate
    from: Released
    to: Deprecated
    effects:
      - notifyDependentSchemas
```

#### 運用規則（v1）

- `Released` なスキーマは、直接編集しない
- 変更は必ず Draft として提案され、Reviewing を経て Released に至る
- レビューでは Rule/Reason により以下を判定する：
  - 参照整合性（Resolve/Validate）
  - 破壊的変更の有無
  - 移行手順（Migration/Effect）の提示有無

> 変更の正当化は「人の判断」ではなく、**Rule による判定と Reason による説明可能性**を前提とする。

---

### 9.6 まとめ（v1 の自己記述成立条件）

v1 における自己記述の成立は、次の条件で定義する：

| 条件 | 検証方法 |
|------|----------|
| Seed が存在する | `schema/fwd_schema.yaml` の存在 |
| Seed が検証可能 | `moon run cli -- validate schema/fwd_schema.yaml` が exit 0 |
| IR が生成可能 | `moon run cli -- schema/fwd_schema.yaml schema/fwd_schema.ir.json` が成功 |
| Golden が固定されている | CI での構造比較が一致 |
| 変更が正当化されている | Transition + Rule/Reason による判定 |

この時点で「FWD が FWD を処理できる」ための **bootstrap が完了**している。

---

## CLI Output Format: Validation JSON (v1.1)

`fwdc validate` は `--json` または `--format json` 指定時に、標準出力へ機械可読な JSON を出力する。
このとき human-readable なログは出力しない。

### Exit Codes

- `0`: ok
- `1`: validation failed (reasons returned)

### Success JSON

```json
{ "ok": true }
```

### Failure JSON

```json
{
  "ok": false,
  "errorCount": 3,
  "reasons": [
    {
      "code": "BreakingChange",
      "message": "transition modified",
      "context": {
        "kind": "transitionModified",
        "subject": "submit",
        "scope": "transition",
        "field": "from",
        "baseline": "Draft",
        "candidate": "Reviewing"
      }
    },
    {
      "code": "MigrationRequired",
      "message": "breaking change requires migration",
      "context": {
        "count": "1",
        "kinds": "transitionModified",
        "subjects": "submit",
        "scopes": "transition"
      }
    }
  ]
}
```

### Notes

- `errorCount == reasons.length`（集約後）
- `context` は v1.1 では `Map[String,String]` 相当（JSONでは string→string object）
- JSON のキー順は実装で安定化させる（テスト・CIの再現性のため）

### JSON Mode Output Contract (v1.1)
When `--json` or `--format json` is specified:

- **stdout**: JSON only (no extra human-readable text)
- **stderr**: empty on expected validation failures (reserved for unexpected runtime errors)
- All failure modes (including file read/parse errors) are reported as JSON with `"ok": false`.

## v1.2 Normalize Stage

Normalize は、Parse/Resolve/Validate を前提に、IR を **実行・生成に適した正規形**として確定する段階である。  
v1.2 の目的は「新しい意味論の導入」ではなく、**同一入力に対して同一の正規形IRを生成できる**こと（安定性）と、以後の Runtime / Actions / Effects 実装で分岐が増えない土台を作ることにある。

### 目的（v1.2）

- IR の順序・表現を正規化し、golden/CI で差分が揺れないようにする
- Resolve で得た参照解決結果を IR に焼き込み、Emit を薄くする
- stateGraph などの派生情報を Normalize で確定し、後段で再計算しない

---

### 入出力

- Input: `ResolvedSchema`（resolve 済みの L1 Schema）
- Output: `NormalizedIR`（v1.2 正規形 IR）

パイプラインは以下とする：

- `parse → resolve → validate → normalize → emit`

---

### 正規化の内容（v1.2）

#### 1) 順序の安定化（辞書順）

次の要素は **辞書順（コードユニットのレキシカル）**で整列して IR に出力する：

- `states`
- `entities`
- `transitions`（key=transition.name）
- `rules`（key=rule.name）
- `effects`（key=effect.name）
- `reasons`（key=reason.code）

> 目的は「人間にとっての順序」ではなく「機械的な再現性」である。

#### 2) 参照の安定化（rule/effect refs）

Normalize は、transition が参照する rule/effect を、resolve 結果に基づいて **確定的に表現**する。

- rules:
  - builtin / schema-defined / custom の origin を保持
  - custom の場合は `impl` を保持
- effects:
  - 参照が存在することは validate 済み
  - Normalize では参照表現を安定化し、Emit はそのまま吐く

> v1.2 では rule/effect の「実行」は行わない（実行は v1.3+）。

#### 3) stateGraph の確定

Normalize は stateGraph を確定して IR に埋め込む。

- `nodes`: `states`（正規化済み順序）
- `edges`: transition 定義から導出（from → to → transitionRef）

Emit 段階では stateGraph を再計算しない。

---

### v1.2 で “しない” こと（スコープ外）

- Infer（最小属性推論、入力推論）
- ルール式 DSL の導入（CEL 等）
- Effect 実行モデル（outbox / saga 等）
- 最適化（到達不能除去等の高度な変換）
  - ※ 検出（warning/Reason）は v1.2+ で検討可

---

### テスト方針（v1.2）

- 同一 Schema 入力から生成される IR JSON が **安定**していることを snapshot/golden で保証する
- 順序の揺れによる差分が出ないことを CI で確認する
  - `schema/fwd_schema.yaml` → `schema/fwd_schema.ir.json` の golden diff
  - examples の IR snapshot

---

### 次フェーズへの接続（v1.3+）

Normalize により、後段は “正規形IR” を前提に実装できる：

- v1.3 Runtime: Transition 実行（Rule→DomainUpdate→EffectSpec）
- v1.4 Actions: Boundary から候補 Transition を列挙（HATEOAS）
- v1.5 Effects: Outbox 最小実装

Normalize はそれらの前提となる「分岐しない土台」である。

## 次の実装ステップ（推奨）

1. **L0 Core の最小実装（MoonBit）**
2. **L1 スキーマを YAML / MoonBit 定義で記述**
3. **最小コンパイラ（Parse → Validate → Emit）**
4. 「FWD が FWD を処理できる」ことを実証
