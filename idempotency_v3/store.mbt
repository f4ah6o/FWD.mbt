///|
/// Deterministic in-memory idempotency store (v3).

pub(all) struct Store {
  records : Map[String, Record]
}

///|
pub fn new_store() -> Store {
  { records: Map::new() }
}

fn reserved_decision(key : String, logical_time : Int) -> Decision {
  {
    key,
    kind: DecisionKind::Reserved,
    logical_time,
    reserved_at: logical_time,
    result_ref: "",
  }
}

fn conflict_decision(key : String, logical_time : Int, reserved_at : Int) -> Decision {
  {
    key,
    kind: DecisionKind::Conflict,
    logical_time,
    reserved_at,
    result_ref: "",
  }
}

fn done_decision(key : String, logical_time : Int, reserved_at : Int, result_ref : String) -> Decision {
  {
    key,
    kind: DecisionKind::Done,
    logical_time,
    reserved_at,
    result_ref,
  }
}

fn already_done_decision(key : String, logical_time : Int, reserved_at : Int, result_ref : String) -> Decision {
  {
    key,
    kind: DecisionKind::AlreadyDone,
    logical_time,
    reserved_at,
    result_ref,
  }
}

///|
pub fn reserve(store : Store, key : String, logical_time : Int) -> Decision {
  match store.records.get(key) {
    Some(record) => {
      match record.status {
        RecordStatus::Reserved => conflict_decision(key, logical_time, record.reserved_at)
        RecordStatus::Done => already_done_decision(key, logical_time, record.reserved_at, record.result_ref)
      }
    }
    None => {
      store.records.set(key, {
        key,
        status: RecordStatus::Reserved,
        reserved_at: logical_time,
        done_at: 0,
        result_ref: "",
      })
      reserved_decision(key, logical_time)
    }
  }
}

///|
pub fn mark_done(store : Store, key : String, result_ref : String, logical_time : Int) -> Decision {
  match store.records.get(key) {
    Some(record) => {
      match record.status {
        RecordStatus::Reserved => {
          let updated : Record = {
            key,
            status: RecordStatus::Done,
            reserved_at: record.reserved_at,
            done_at: logical_time,
            result_ref,
          }
          store.records.set(key, updated)
          done_decision(key, logical_time, record.reserved_at, result_ref)
        }
        RecordStatus::Done => {
          already_done_decision(key, logical_time, record.reserved_at, record.result_ref)
        }
      }
    }
    None => {
      store.records.set(key, {
        key,
        status: RecordStatus::Done,
        reserved_at: logical_time,
        done_at: logical_time,
        result_ref,
      })
      done_decision(key, logical_time, logical_time, result_ref)
    }
  }
}

///|
pub fn get(store : Store, key : String) -> Option[Record] {
  store.records.get(key)
}
