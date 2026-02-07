///|
/// v5.0 export job contract types (no behavior).

///|
/// JobId is a deterministic, monotonic identifier with representation `job-<n>`.
/// Ordering is numeric by the `<n>` suffix (not lexicographic).
pub(all) struct JobId {
  value : String
}

///|
/// Status transitions MUST be one of:
/// - queued -> running -> done
/// - queued -> running -> failed
/// - queued -> running -> canceled
/// - queued -> running -> expired
pub(all) enum JobStatus {
  Queued
  Running
  Done
  Failed
  Canceled
  Expired
}

///|
/// Progress MUST include `total`; percent is intentionally excluded.
pub(all) struct JobProgress {
  processed : Int
  total : Int
}

///|
/// Retention is poll-count only in v5.0.
pub(all) enum RetentionAxis {
  PollCount
}

///|
pub(all) struct Retention {
  axis : RetentionAxis
  ttl_polls : Int
  /// Logical TTL units for API compatibility (MUST NOT be interpreted as wall-clock seconds).
  ttl_seconds : Int
}

///|
/// Result formats; JSONL/CSV bodies MUST end with a single LF (`\\n`).
pub(all) enum ResultFormat {
  Jsonl
  Csv
}

///|
/// JobRecord is the canonical persisted state for v5.0 jobs.
pub(all) struct JobRecord {
  id : JobId
  status : JobStatus
  progress : JobProgress
  retention : Retention
  format : ResultFormat
  reasons : Array[ReasonV1]
  poll_count : Int
}
