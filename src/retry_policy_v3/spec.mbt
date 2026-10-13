///|
/// Retry/backoff policy spec (v3).

///|
pub(all) enum BackoffKind {
  Fixed
  Exponential
}

///|
pub(all) struct BackoffPolicy {
  kind : BackoffKind
  delay_ms : Int32
  factor : Int32
}

///|
pub(all) struct RetryPolicy {
  policy_version : String
  max_attempts : Int32
  backoff : BackoffPolicy
}

///|
pub fn policy_version_v3() -> String {
  "3"
}
