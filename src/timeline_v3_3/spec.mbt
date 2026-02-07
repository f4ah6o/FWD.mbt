///|
/// Timeline query contract (v3.3).

///|
pub(all) struct TimelineQuery {
  entity_id : String
  from_logical_time : Int?
  to_logical_time : Int?
  kind : String?
  limit : Int
  cursor : String?
}

///|
pub(all) struct TimelineCursor {
  entity_id : String
  offset : Int
  limit : Int
  from_logical_time : Int?
  to_logical_time : Int?
  kind : String?
}
