# v5.3 Plan (Draft) — Delta Only

This document describes **v5.3 deltas only**. It MUST NOT restate v5.0/v5.1/v5.2 contracts.
All v5.0/v5.1/v5.2 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.3)

1) Event-count retention axis (third axis)
2) Three-axis deterministic composition (strictest-wins resolution)
3) Backward-compatible single-axis and two-axis evaluation

## Event-Count Retention Axis — Delta

### New concepts (v5.3)

- **Event Count Axis**
  v5.0/v5.1 supported `poll_count` only.
  v5.2 added `logical_time` as a second axis.
  v5.3 adds `event_count` as a third axis.

- **Event count semantics**
  `event_count` tracks the number of discrete events a job has processed.
  Unlike `poll_count` (incremented per status poll) or `logical_time`
  (monotonic logical clock), `event_count` reflects workload volume.

- **Three-axis evaluation**
  A job MAY have retention policies on one, two, or three axes.
  Each axis is evaluated independently against its threshold.

- **Strictest-wins resolution (unchanged)**
  When multiple axes are defined, the axis that expires first
  (lowest threshold among expired axes) is the effective axis.
  This rule is inherited from v5.2 and remains unchanged.

### Evaluation contract

Input:
```json
{
  "policies": [
    {"axis": "poll_count", "threshold": 5, "ttlSeconds": 120},
    {"axis": "logical_time", "threshold": 100, "ttlSeconds": 300},
    {"axis": "event_count", "threshold": 1000, "ttlSeconds": 600}
  ],
  "currentPollCount": 6,
  "currentLogicalTime": 50,
  "currentEventCount": 1200
}
```

Output:
```json
{
  "jobVersion": "5.3",
  "axes": [
    {"axis": "poll_count", "threshold": 5, "current": 6, "expired": true},
    {"axis": "logical_time", "threshold": 100, "current": 50, "expired": false},
    {"axis": "event_count", "threshold": 1000, "current": 1200, "expired": true}
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

### Locked decisions (v5.3)

- Resolution rule: `strictest_wins`
- Post-expiry visibility: `results: hidden`, `metadata: retained` (inherited from v5.1)
- Wall-clock timestamps: FORBIDDEN
- Axes: `poll_count`, `logical_time`, `event_count`

### API endpoints (v5.3)

- `GET /v5.3/retention/evaluate/multi-axis` (body: evaluation input JSON)

## Non-Goals (v5.3)

- Store integration (v5.3 is evaluation-only)
- Changing v5.0/v5.1/v5.2 retention behavior
- Wall-clock timestamps
- New resolution rules beyond `strictest_wins`
- Weighted or priority-based axis composition

## Frozen Contracts (v5.3)

- Evaluation fixtures: `fixtures/v5_3/retention/case_*.response.json`
- Evaluation package: `retention_v5_3/evaluate_test.mbt`
- API tests: `api_v5/api_test.mbt` (v5.3 retention tests)

## Deliverables (v5.3)

- Package: `retention_v5_3/` (types, evaluate, tests)
- Fixtures: `fixtures/v5_3/retention/` (golden outputs)
- API surface: `/v5.3/retention/evaluate/multi-axis`
