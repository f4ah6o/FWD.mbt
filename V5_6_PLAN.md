# v5.6 Plan (Draft) — Delta Only

This document describes **v5.6 deltas only**. It MUST NOT restate v5.0–v5.5 contracts.
All v5.0–v5.5 fixtures, anchors, identities, and semantics remain immutable.

## Scope (v5.6)

1) HTML view for paginated job timeline (plain HTML)
2) MX view for paginated job timeline (mx-get pager, mx-target/mx-swap root)
3) Single-job and batch-job support for both formats
4) `?format=html|mx` query parameter on existing v5.5 timeline endpoints

## HTML View — Delta

### View struct

`JobTimelinePageView { job_id, base_url, page: JobTimelinePage }`

- `base_url`: controls link generation (single vs batch URL prefix)
- `page`: reuses v5.5 `JobTimelinePage` unchanged

### Event rendering

Each event renders as:

```html
<div class="fwd-job-timeline-event" data-event-id="{job_id}:{logicalTime}:{sequence}:{kind}">
  <p>logicalTime: {logicalTime}</p>
  <p>kind: {kind}</p>
  <p>from: {fromStatus}</p>
  <p>to: {toStatus}</p>
  <p>{reason.message}</p>  <!-- per reason -->
</div>
```

### Pager (plain HTML)

When `has_more` is true, a plain Next button (no mx attributes):

```html
<div class="fwd-job-timeline-pager">
  <button>Next</button>
</div>
```

### Pager (MX)

When `has_more` is true, an mx-get Next button:

```html
<div class="fwd-job-timeline-pager">
  <button mx-get="{base_url}?format=mx&amp;limit={limit}&amp;cursor=offset:{next_offset}">Next</button>
</div>
```

### Root element

Plain:
```html
<div class="fwd-job-timeline">...</div>
```

MX:
```html
<div class="fwd-job-timeline" mx-target=".fwd-job-timeline" mx-swap="outerHTML">...</div>
```

## API — Delta

### Format query parameter

Existing v5.5 timeline endpoints accept `format` query parameter:

- `format=html` → plain HTML response (content-type: text/html)
- `format=mx` → MX HTML response (content-type: text/html)
- No `format` or other value → JSON (existing v5.5 behavior, unchanged)

### Endpoints affected

- `GET /v5.5/export/jobs/{id}/timeline` (+ `?format=html|mx`)
- `GET /v5.5/export/batch/jobs/{id}/timeline` (+ `?format=html|mx`)

Export endpoints (`/timeline/export`) are NOT affected.

### Locked decisions (v5.6)

- CSS class prefix: `fwd-job-timeline`
- Event data-event-id format: `job_id:logicalTime:sequence:kind`
- MX pager: `mx-get` button (not form)
- MX root: `mx-target` + `mx-swap="outerHTML"`
- No new URL prefix; reuses v5.5 endpoints with `format` parameter

## Non-Goals (v5.6)

- Event detail drill-down views
- Kind filter UI
- Changing v5.0–v5.5 behavior
- Wall-clock timestamps

## Frozen Contracts (v5.6)

- View fixtures: `fixtures/v5_6/timeline/*.html`
- View tests: `src/ui/views/job_timeline_view_v5_6_test.mbt`
- API tests: `src/api_v5/api_test.mbt` (v5.6 timeline tests)

## Deliverables (v5.6)

- Views: `src/ui/views/job_timeline_view_v5_6.mbt`, `src/ui/views/job_timeline_view_v5_6_mx.mbt`
- Tests: `src/ui/views/job_timeline_view_v5_6_test.mbt`
- Fixtures: `fixtures/v5_6/timeline/` (golden HTML outputs)
- API surfaces: format dispatch on existing v5.5 timeline endpoints
