///|
/// Reason v1 contract (v5.0, no behavior).

///|
pub(all) enum ReasonCode {
  QueryMissing
  QueryInvalid
  JobNotFound
  JobNotReady
  JobCanceled
  JobExpired
  /// Policy-only; job/batch APIs MUST NOT emit this code.
  PolicyDenied
}

///|
pub(all) enum ReasonLevel {
  Error
  Warn
  Info
}

///|
pub(all) struct ReasonV1 {
  code : ReasonCode
  level : ReasonLevel
  target : String
  message : String
  hint : String?
}
