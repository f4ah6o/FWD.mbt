# v5.2 Retention Fixtures (Canonical)

These files are the canonical fixture authority set for v5.2 freeze verification.

## Batch 1 (visibility + reasons)
- case_visible_all_pass.response.json
- case_hidden_poll_only.response.json
- case_hidden_generation_only.response.json
- case_hidden_multi_fail.response.json
- case_result_endpoint_hidden.response.json
- case_compat_legacy_expired_read.response.json

## Batch 2 (precedence)
- case_precedence_job_over_batch_over_system.response.json
- case_precedence_batch_over_system.response.json
- case_precedence_system_only.response.json

## Notes
- Hidden API shape uses 404 with `ReasonV1` and `retentionDetails` for hidden cases.
- Scope precedence and failed-axis ordering are deterministic and test-covered in v5.2.
