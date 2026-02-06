# v5 Fixtures (Contract)

## Philosophy
- Fixtures are the contract (golden outputs).
- Deterministic outputs only: no timestamps, no randomness, no environment dependence.
- Same inputs MUST yield identical outputs across processes.
- No inference in projection layers.

## Layout
```
fixtures/v5/
  jobs/
    create/
      case_001.request.json
      case_001.response.json
    step/
      case_001.step_1.response.json
      case_001.step_2.response.json
    get/
      case_001.response.json
    cancel/
      case_001.response.json
    result/
      case_001.response.jsonl
      case_001.response.csv
      case_001.status.json
  batch/
    create/
    step/
    get/
    result/
  observability/
    metrics_summary/
      case_001.response.json
    export_audit/
      case_001.response.json
  policy/
    check/
      case_001.request.json
      case_001.response.json
```

## Case schema (minimal, deterministic)
- `request.json`
  - `endpoint` (string)
  - `method` (string)
  - `body` (object | null)
  - `headers` (object, optional)
- `response.json`
  - `status` (int)
  - `headers` (object)
  - `body` (object | string | null)
- `response.jsonl` / `response.csv`
  - body only (canonical bytes)
  - if headers required, store them in adjacent `response.json`

## Canonical JSON rule
- Tests MUST compare canonicalized JSON (stable key order + stable whitespace or minified).
- CSV/JSONL compared as raw bytes with `\n` newlines only.
