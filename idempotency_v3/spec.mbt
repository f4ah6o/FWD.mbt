///|
/// Idempotency store spec (v3).

///|
pub(all) enum RecordStatus {
  Reserved
  Done
}

///|
pub(all) struct Record {
  key : String
  status : RecordStatus
  reserved_at : Int
  done_at : Int
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
  logical_time : Int
  reserved_at : Int
  result_ref : String
}
