///|
/// Idempotency store spec (v3).
/// Key matching is exact (no normalization).
/// Duplicate means in-flight conflict; already_done returns the existing result reference.
/// TTL is a non-goal in v3 (no expiry).

///|
pub(all) enum RecordStatus {
  Reserved
  Done
}

///|
pub(all) struct Record {
  key : String
  status : RecordStatus
  reserved_at : Int32
  done_at : Int32
  result_ref : String
}

///|
pub(all) enum DecisionKind {
  Reserved
  Conflict
  Done
  AlreadyDone
}

///|
pub(all) struct Decision {
  key : String
  kind : DecisionKind
  logical_time : Int32
  reserved_at : Int32
  result_ref : String
}
