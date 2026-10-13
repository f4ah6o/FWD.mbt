///|
/// Timeline event list contract (v3.8).

///|
pub(all) struct TimelineEventQuery {
  entity_id : String
  kind : String?
  from_logical_time : Int32?
  to_logical_time : Int32?
  limit : Int32
  cursor : String?
}

///|
pub(all) struct TimelineEventCursor {
  entity_id : String
  offset : Int32
  limit : Int32
  kind : String?
  from_logical_time : Int32?
  to_logical_time : Int32?
}
