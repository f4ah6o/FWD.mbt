# v5.2 Fixtures (Planning Scaffold)

This folder is for v5.2 candidate fixtures and draft contracts.
It does not define frozen semantics yet.

## Baseline
- v5.1.0 remains the immutable semantic baseline.
- v5.0/v5.1 fixtures are not modified by v5.2 planning.

## Current status
- Planning state: `open`
- Freeze status: `not started`
- Scope status: `candidate collection`

## Suggested layout
```
fixtures/v5_2/
  candidates/
    streaming/
    scheduling/
    retention_axis/
    lifecycle/
    policy_integration/
```

## Rules
- Add candidate fixtures as explicit v5.2 artifacts only.
- Keep cases deterministic (no wall-clock/random/environment coupling).
- Do not treat candidate fixtures as canonical until v5.2 freeze.
