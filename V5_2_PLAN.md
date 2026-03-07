# v5.2 Plan (Draft) — Delta Only

This document describes **v5.2 deltas only**. It MUST NOT restate v5.0/v5.1 contracts.
All v5.0/v5.1 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.2)

1) Multi-axis retention evaluation (poll_count + logical_time)
2) Deterministic axis composition (strictest-wins resolution)
3) Backward-compatible single-axis evaluation

## Multi-Axis Retention — Delta

### New concepts (v5.2)

- **Retention Axis**
  v5.0/v5.1 supported `poll_count` only.
  v5.2 adds `logical_time` as a second axis.

- **Multi-axis evaluation**
  A job MAY have retention policies on multiple axes.
  Each axis is evaluated independently against its threshold.

- **Strictest-wins resolution**
  When multiple axes are defined, the axis that expires first
  (lowest threshold among expired axes) is the effective axis.

### Evaluation contract

Input:
```json
{
  "policies": [
    {"axis": "poll_count", "threshold": 5, "ttlSeconds": 120},
    {"axis": "logical_time", "threshold": 100, "ttlSeconds": 300}
  ],
  "currentPollCount": 6,
  "currentLogicalTime": 50
}
```

Output:
```json
{
  "jobVersion": "5.2",
  "axes": [
    {"axis": "poll_count", "threshold": 5, "current": 6, "expired": true},
    {"axis": "logical_time", "threshold": 100, "current": 50, "expired": false}
  ],
  "effectiveAxis": "poll_count",
  "effectiveThreshold": 5,
  "expired": true,
  "resolutionRule": "strictest_wins",
  "postExpiryVisibility": {
    "results": "hidden",
    "metadata": "retained"
  }
}
```

### Locked decisions (v5.2)

- Resolution rule: `strictest_wins`
- Post-expiry visibility: `results: hidden`, `metadata: retained` (inherited from v5.1)
- Wall-clock timestamps: FORBIDDEN
- Axes: `poll_count`, `logical_time` (no event-count in v5.2)

### API endpoints (v5.2)

- `GET /v5.2/retention/evaluate/multi-axis` (body: evaluation input JSON)

## Non-Goals (v5.2)

- event-count axis (candidate for v5.3)
- Store integration (v5.2 is evaluation-only)
- Changing v5.0/v5.1 retention behavior
- Wall-clock timestamps

## Frozen Contracts (v5.2)

- Evaluation fixtures: `fixtures/v5_2/retention/case_*.response.json`
- Evaluation package: `retention_v5_2/evaluate_test.mbt`
- API tests: `api_v5/api_test.mbt` (v5.2 retention tests)

## Deliverables (v5.2)

- Package: `retention_v5_2/` (types, evaluate, tests)
- Fixtures: `fixtures/v5_2/retention/` (6 golden outputs)
- API surface: `/v5.2/retention/evaluate/multi-axis`
