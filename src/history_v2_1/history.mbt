///|
/// Append-only history store (v2.1).

///|
pub(all) enum HistoryResult {
  Executed
  Blocked
  NotFound
  NotAvailable
}

///|
pub(all) struct HistoryEvent {
  event_id : Int
  transition : String
  from_state : String
  to_state : String
  payload : Json
  result : HistoryResult
  reasons : Array[@core.Reason]
}

///|
pub fn HistoryEvent::new(
  event_id : Int,
  transition : String,
  from_state : String,
  to_state : String,
  payload : Json,
  result : HistoryResult,
  reasons : Array[@core.Reason],
) -> HistoryEvent {
  { event_id, transition, from_state, to_state, payload, result, reasons }
}

///|
pub(all) struct HistoryStore {
  mut entries : Map[String, Array[HistoryEvent]]
  mut next_event_id : Int
}

///|
pub fn HistoryStore::new() -> HistoryStore {
  { entries: Map::new(), next_event_id: 1 }
}

///|
pub fn HistoryStore::append(
  self : HistoryStore,
  entity_id : String,
  transition : String,
  from_state : String,
  to_state : String,
  payload : Json,
  result : HistoryResult,
  reasons : Array[@core.Reason],
) -> HistoryEvent {
  let event = HistoryEvent::new(
    self.next_event_id,
    transition,
    from_state,
    to_state,
    payload,
    result,
    reasons,
  )
  self.next_event_id = self.next_event_id + 1
  let list = match self.entries.get(entity_id) {
    Some(value) => value
    None => []
  }
  list.push(event)
  self.entries[entity_id] = list
  event
}

///|
fn compare_event_id(a : HistoryEvent, b : HistoryEvent) -> Int {
  if a.event_id < b.event_id {
    -1
  } else if a.event_id > b.event_id {
    1
  } else {
    0
  }
}

///|
pub fn HistoryStore::get(self : HistoryStore, entity_id : String) -> Array[HistoryEvent] {
  let list = match self.entries.get(entity_id) {
    Some(value) => value
    None => []
  }
  let result : Array[HistoryEvent] = []
  for entry in list {
    result.push(entry)
  }
  result.sort_by(compare_event_id)
  result
}
