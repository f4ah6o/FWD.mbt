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

## 次の実装ステップ（推奨）

1. **L0 Core の最小実装（MoonBit）**
2. **L1 スキーマを YAML / MoonBit 定義で記述**
3. **最小コンパイラ（Parse → Validate → Emit）**
4. 「FWD が FWD を処理できる」ことを実証

→ ここまでで **自己記述が実際に動く**。
