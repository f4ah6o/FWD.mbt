# v5.4 Plan (Draft) — Delta Only

This document describes **v5.4 deltas only**. It MUST NOT restate v5.0/v5.1/v5.2/v5.3 contracts.
All v5.0/v5.1/v5.2/v5.3 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.4)

1) Job timeline — append-only state transition history
2) Single-job timeline query
3) Batch-job aggregated timeline query
4) Timeline is available even for expired jobs (history is retained)

## Job Timeline — Delta

### New concepts (v5.4)

- **Job Timeline Event**
  A record of a single state transition within a job's lifecycle.
  Each event captures `fromStatus`, `toStatus`, reasons, and ordering metadata.

- **Append-only recording**
  Timeline events are immutable once recorded.
  Recording occurs automatically during `create_job`, `step_job`, and `cancel_job`.

- **Deterministic ordering**
  Events are ordered by `(job_id, logical_time, sequence)`.
  Within the same `logical_time`, `sequence` is a monotonic counter starting at 1.

### Event contract

```json
{
  "logicalTime": 1,
  "sequence": 1,
  "kind": "status_change",
  "fromStatus": "queued",
  "toStatus": "running",
  "reasons": []
}
```

### Timeline response contract

Single job:
```json
{
  "jobVersion": "5.4",
  "jobId": "job-1",
  "events": [...]
}
```

Batch (aggregated child events):
```json
{
  "jobVersion": "5.4",
  "batchId": "job-1",
  "events": [
    {"jobId": "job-2", "logicalTime": 1, ...}
  ]
}
```

### API endpoints (v5.4)

- `GET /v5.4/export/jobs/{id}/timeline` — single job timeline
- `GET /v5.4/export/batch/jobs/{id}/timeline` — batch aggregated timeline

### Locked decisions (v5.4)

- Ordering: `(job_id, logical_time, sequence)`
- Event kind: `status_change` only (extensible in future versions)
- Timeline is available for expired jobs (history is retained)
- Wall-clock timestamps: FORBIDDEN
- Reasons use ReasonV1 format with `reasonVersion: 1`

## Non-Goals (v5.4)

- Timeline filtering or pagination (v5.5 candidate)
- Timeline JSONL export (v5.5 candidate)
- Timeline for entity-level transitions (covered by v3.x)
- Changing v5.0/v5.1/v5.2/v5.3 behavior
- Wall-clock timestamps

## Frozen Contracts (v5.4)

- Timeline fixtures: `fixtures/v5_4/timeline/case_*.response.json`
- Timeline package: `job_timeline_v5_4/timeline_test.mbt`
- Job store: `job_store_v5_4/` (timeline-integrated store)
- API tests: `api_v5/api_test.mbt` (v5.4 timeline tests)

## Deliverables (v5.4)

- Package: `job_timeline_v5_4/` (types, store, JSON projection, tests)
- Package: `job_store_v5_4/` (v5.3 store + timeline recording)
- Fixtures: `fixtures/v5_4/timeline/` (golden outputs)
- API surface: `/v5.4/export/jobs/{id}/timeline`, `/v5.4/export/batch/jobs/{id}/timeline`
