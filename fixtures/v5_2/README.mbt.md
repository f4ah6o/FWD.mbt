# v5.2 Fixtures (Freeze Verification Workspace)

This folder contains v5.2 candidate fixtures and canonical retention fixtures used during freeze verification.

## Baseline
- v5.1.0 remains the immutable semantic baseline.
- v5.0/v5.1 fixtures are not modified by v5.2 planning.

## Current status
- Planning state: `freeze_started`
- Freeze status: `started`
- Scope status: `closed`

## Suggested layout
```
fixtures/v5_2/
  candidates/
    streaming/
    scheduling/
    retention_axis/
    lifecycle/
    policy_integration/
  retention/
    README.mbt.md
    batch1/
      *.response.json
    batch2/
      *.response.json
```

## Rules
- Add candidate fixtures as explicit v5.2 artifacts only.
- Keep cases deterministic (no wall-clock/random/environment coupling).
- Candidate folders remain non-authoritative until explicitly promoted.
- Canonical retention files use `*.response.json` for freeze verification authority.
