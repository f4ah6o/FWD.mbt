# V6.0 Plan — View Layer Consolidation

## 概要

v5.x で timeline/retention/observability 機能が完成。view レイヤーは plain HTML + MX variant を
別関数で持つパターンが繰り返されている。v6.0 は view レイヤーを統合し、コンテキスト
パラメータ化されたジェネリックレンダラーで MX 重複を排除する。

## スコープ

1. **Generic view rendering framework** — `src/ui/view_components/`
2. **ViewContext による MX 自動切替** — `enable_mx: Bool` で plain/MX を1関数で処理
3. **Job timeline views の v6 化** — v5.6/v5.7 views を v6 ジェネリックレンダラーで書き直し
4. **既存 v4/v5 views は保持** — frozen contracts は壊さない

## 新パッケージ

- `src/ui/view_components/` — ViewContext, root/pager/field ヘルパー

## HTML 出力仕様

v5.6/v5.7 と完全同一の HTML 出力。v6 は内部実装の統合であり出力は変わらない。
