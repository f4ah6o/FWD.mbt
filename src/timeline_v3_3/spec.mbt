///|
/// Timeline query contract (v3.3).

///|
pub(all) struct TimelineQuery {
  entity_id : String
  from_logical_time : Int32?
  to_logical_time : Int32?
  kind : String?
  limit : Int32
  cursor : String?
}

///|
pub(all) struct TimelineCursor {
  entity_id : String
  offset : Int32
  limit : Int32
  from_logical_time : Int32?
  to_logical_time : Int32?
  kind : String?
}
