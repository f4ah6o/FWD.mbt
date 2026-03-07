# v5.5 Plan (Draft) — Delta Only

This document describes **v5.5 deltas only**. It MUST NOT restate v5.0/v5.1/v5.2/v5.3/v5.4 contracts.
All v5.0/v5.1/v5.2/v5.3/v5.4 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.5)

1) Cursor-based pagination for job timeline (offset-based, v3.3 pattern)
2) Logical time range filtering (fromLogicalTime, toLogicalTime)
3) JSONL export for job timeline
4) Single-job and batch-job support for all above

## Pagination — Delta

### Cursor encoding

Cursor format: `"offset:N"` (same as v3.3 timeline cursor).

### Paginated response contract

```json
{
  "jobVersion": "5.5",
  "jobId": "job-1",
  "events": [...],
  "pagination": {
    "offset": 0,
    "limit": 2,
    "hasMore": true,
    "nextCursor": "offset:2"
  }
}
```

When `hasMore` is false, `nextCursor` is omitted.

### JSONL export contract

Each line is one JSON object with an `eventId` field:

```
{"eventId":"job-1:0:1:status_change","jobId":"job-1","logicalTime":0,...}
```

Event ID format: `job_id:logical_time:sequence:kind`

### API endpoints (v5.5)

- `GET /v5.5/export/jobs/{id}/timeline` (query: limit, cursor, fromLogicalTime, toLogicalTime)
- `GET /v5.5/export/jobs/{id}/timeline/export` (query: fromLogicalTime, toLogicalTime)
- `GET /v5.5/export/batch/jobs/{id}/timeline` (query: limit, cursor, fromLogicalTime, toLogicalTime)
- `GET /v5.5/export/batch/jobs/{id}/timeline/export` (query: fromLogicalTime, toLogicalTime)

### Locked decisions (v5.5)

- Cursor format: `offset:N`
- Default limit: 10
- Filtering: inclusive range on logicalTime
- JSONL: one JSON object per line, LF terminated
- Wall-clock timestamps: FORBIDDEN

## Non-Goals (v5.5)

- HTML/MX views (v5.6 candidate)
- Kind filter (only StatusChange exists currently)
- Changing v5.0/v5.1/v5.2/v5.3/v5.4 behavior
- Wall-clock timestamps

## Frozen Contracts (v5.5)

- Pagination fixtures: `fixtures/v5_5/timeline/case_page*.response.json`
- Filter fixture: `fixtures/v5_5/timeline/case_filtered.response.json`
- Export fixture: `fixtures/v5_5/timeline/case_export.response.jsonl`
- Batch fixture: `fixtures/v5_5/timeline/case_batch_page1.response.json`
- Error fixture: `fixtures/v5_5/timeline/case_invalid_cursor.response.json`
- Package tests: `job_timeline_v5_5/query_test.mbt`
- API tests: `api_v5/api_test.mbt` (v5.5 timeline tests)

## Deliverables (v5.5)

- Package: `job_timeline_v5_5/` (types, query, pagination, JSON projection, JSONL export, tests)
- Fixtures: `fixtures/v5_5/timeline/` (golden outputs)
- API surfaces: `/v5.5/export/jobs/{id}/timeline[/export]`, `/v5.5/export/batch/jobs/{id}/timeline[/export]`
