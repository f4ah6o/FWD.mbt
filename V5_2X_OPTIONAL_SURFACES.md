# v5.2.x Optional Surfaces (Non-Binding)

This track is additive exploration for v5.2.x.
It is independent from global v5.2 freeze start.

## Scope Contract
- Non-binding planning and draft comparison only.
- Batch 1 and Batch 2 retention semantics are not changed.
- v5.1 baseline remains immutable.
- Fixture-first draft exploration is allowed for optional surfaces only.

## Purpose
- Explore implementation and UX/API representation without semantic pressure.
- Keep momentum while preserving the draft-frozen retention and precedence baseline.

## Initial Optional Candidates (Additive / Read-Only)
- Error response diagnostic helpers (for example, `debugHints`).
- UI-facing helper metadata (display labels, short descriptions, suggested actions).
- Read-only observability metadata for operators.
- Client UX hint structures for easier rendering and troubleshooting.

## Explicit Prohibitions
- New retention axis introduction.
- Any wall-clock or scheduling/background model.
- Re-interpretation of retention or precedence semantics.
- Edits to v5.1 artifacts.
- Edits to v5.2 Batch 1 / Batch 2 draft-frozen semantic surfaces.

## Working Method
- Keep proposals additive and optional.
- Capture draft fixtures under `fixtures/v5_2/` as non-authoritative when needed.
- Validate shape-level behavior before discussing any semantic promotion.

## Exit Paths
- Continue optional exploration without freeze.
- Or start global v5.2 freeze using `V5_2_FREEZE_CHECKLIST.md` at any time.
