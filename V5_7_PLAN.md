# v5.7 Plan (Draft) — Delta Only

This document describes **v5.7 deltas only**. It MUST NOT restate v5.0–v5.6 contracts.
All v5.0–v5.6 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.7)

1) Event detail drill-down with prev/next navigation (JSON + HTML + MX)
2) Kind filter parameter on timeline list endpoints

## Event Detail — Delta

### Event ID format

Reuses v5.5 JSONL event ID: `job_id:logicalTime:sequence:kind`

Example: `job-1:1:1:status_change`

### Detail response contract (JSON)

```json
{
  "jobVersion": "5.7",
  "eventId": "job-1:1:1:status_change",
  "event": {
    "logicalTime": 1,
    "sequence": 1,
    "kind": "status_change",
    "fromStatus": "queued",
    "toStatus": "running",
    "reasons": []
  },
  "prevEventId": "job-1:0:1:status_change",
  "nextEventId": "job-1:2:1:status_change"
}
```

When no prev/next exists, the field is omitted.

### Detail HTML rendering

CSS class prefix: `fwd-job-timeline-detail` (extends v5.6 `fwd-job-timeline-*` prefix).

Plain HTML pager shows plain Prev/Next buttons. MX pager uses `mx-get` buttons.

### API endpoints (v5.7)

- `GET /v5.7/export/jobs/{id}/timeline/event/{eventId}` (query: format)
- `GET /v5.7/export/batch/jobs/{id}/timeline/event/{eventId}` (query: format)

Format options: `json` (default), `html`, `mx`.

## Kind Filter — Delta

### Query parameter

Existing v5.5 timeline endpoints accept `kind` query parameter:

- `kind=status_change` → filter by StatusChange kind
- No `kind` → no filtering (existing behavior, unchanged)
- Invalid `kind` → 400 error

### Endpoints affected

- `GET /v5.5/export/jobs/{id}/timeline` (+ `?kind=status_change`)
- `GET /v5.5/export/batch/jobs/{id}/timeline` (+ `?kind=status_change`)

Export endpoints (`/timeline/export`) are NOT affected.

### Locked decisions (v5.7)

- Event ID format: `job_id:logicalTime:sequence:kind` (same as v5.5 JSONL)
- Detail CSS class: `fwd-job-timeline-detail`
- MX pager: `mx-get` button with `format=mx` (not form)
- Kind filter applies before pagination
- Kind string mapping: `StatusChange` → `"status_change"`

## Non-Goals (v5.7)

- New event kinds (only StatusChange exists currently)
- Kind filter on export endpoints
- Changing v5.0–v5.6 behavior
- Wall-clock timestamps

## Frozen Contracts (v5.7)

- Package tests: `job_timeline_v5_7/query_test.mbt`
- View fixtures: `fixtures/v5_7/timeline/*.html`
- API detail fixture: `fixtures/v5_7/timeline/case_detail.response.json`
- API tests: `api_v5/api_test.mbt` (v5.7 tests)

## Deliverables (v5.7)

- Package: `job_timeline_v5_7/` (types, query, detail lookup, JSON projection, tests)
- Views: `src/ui/views/job_timeline_detail_view_v5_7[_mx].mbt`
- Fixtures: `fixtures/v5_7/timeline/` (golden outputs)
- API surfaces: `/v5.7/export/jobs/{id}/timeline/event/{eventId}`, kind filter on v5.5 timeline
