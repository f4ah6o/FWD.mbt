# v5.8 Plan (Draft) — Delta Only

This document describes **v5.8 deltas only**. It MUST NOT restate v5.0–v5.7 contracts.
All v5.0–v5.7 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.8)

1) New event kinds: `PolicyDecision`, `RetentionCheck`
2) Kind filter on JSONL export endpoints

## New Event Kinds — Delta

### JobTimelineKind extension

```
StatusChange     → "status_change"      (existing)
PolicyDecision   → "policy_decision"    (new)
RetentionCheck   → "retention_check"    (new)
```

### Field reuse convention

`from_status` / `to_status` fields are reused generically:

| Kind | from_status | to_status |
|------|------------|-----------|
| StatusChange | previous job status | new job status |
| PolicyDecision | `"pending"` | `"approved"` or `"denied"` |
| RetentionCheck | `"active"` | `"retained"` or `"expired"` |

### Recording helpers

- `record_policy_decision(job_id, logical_time, to_status, reasons)` — `from_status="pending"`
- `record_retention_check(job_id, logical_time, to_status, reasons)` — `from_status="active"`

## Export Kind Filter — Delta

### Query parameter

Existing v5.5 export endpoints accept `kind` query parameter:

- `kind=status_change` → filter by StatusChange
- `kind=policy_decision` → filter by PolicyDecision
- `kind=retention_check` → filter by RetentionCheck
- No `kind` → no filtering (existing behavior, unchanged)
- Invalid `kind` → 400 error

### Endpoints affected

- `GET /v5.5/export/jobs/{id}/timeline/export` (+ `?kind=status_change`)
- `GET /v5.5/export/batch/jobs/{id}/timeline/export` (+ `?kind=status_change`)

### Locked decisions (v5.8)

- Kind string mapping: see table above
- PolicyDecision from_status: always `"pending"`
- RetentionCheck from_status: always `"active"`
- Export kind filter reuses `filter_events_by_kind` from v5.7
- Export kind filter applies after time range filter

## Non-Goals (v5.8)

- Struct changes to JobTimelineEvent (from_status/to_status reused)
- New API endpoints (uses existing v5.5 endpoints)
- Changing v5.0–v5.7 behavior
- Wall-clock timestamps

## Frozen Contracts (v5.8)

- All existing v5.4–v5.7 tests pass unchanged
- API tests: `api_v5/api_test.mbt` (v5.8 export filter tests)

## Deliverables (v5.8)

- Enum extension: `JobTimelineKind` + 2 new variants
- Recording helpers: `record_policy_decision`, `record_retention_check`
- Kind filter on export endpoints
- Updated kind_string / parse_kind across all packages
