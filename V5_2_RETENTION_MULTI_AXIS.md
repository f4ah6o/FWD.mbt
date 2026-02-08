# v5.2 Retention Multi-Axis Semantics (Frozen Reference)

Status: canonical freeze reference for v5.2 global freeze verification.

## Scope
- Retention visibility semantics (Batch 1)
- Retention policy precedence semantics (Batch 2)
- Deterministic evaluation only

## Batch 1 Frozen Semantics
Covered cases:
- `visible_all_pass`
- `hidden_poll_only`
- `hidden_generation_only`
- `hidden_multi_fail`
- `result_endpoint_hidden`
- `compat_legacy_expired_read`

Behavior:
- Retention filters visibility only and does not mutate state transitions.
- Hidden responses return `404` with `ReasonV1` and `retentionDetails`.
- Visible responses do not include `retentionDetails`.
- Failed axes are returned in policy declaration order.
- `combine=all` is used for v5.2 retention evaluation.

## Batch 2 Frozen Semantics
Covered precedence rule:
- `job > batch > system`

Behavior:
- Precedence resolves policy scope before retention evaluation.
- Resolver behavior is deterministic for identical inputs.

## Canonical Fixture Authority
Canonical truth is defined by:
- `fixtures/v5_2/retention/batch1/*.response.json`
- `fixtures/v5_2/retention/batch2/*.response.json`
- Fixture assertion tests in `src/api_v5_2/api_test.mbt`

## Compatibility
- `ReasonV1` compatibility is preserved.
- Legacy expired compatibility path remains:
  - `error.code=JOB_EXPIRED`
  - `compatibility.sourceStatus=expired`
  - `compatibility.mode=legacy-read`

## v5.2 Non-Goals (Re-asserted)
- No wall-clock retention axis.
- No scheduling/background worker model.
- No policy/job interpretation beyond existing boundary.
- No changes to v5.1 fixtures, anchors, or semantics.
