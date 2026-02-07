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
  delay_ms : Int
  factor : Int
}

///|
pub(all) struct RetryPolicy {
  policy_version : String
  max_attempts : Int
  backoff : BackoffPolicy
}

///|
pub fn policy_version_v3() -> String {
  "3"
}
