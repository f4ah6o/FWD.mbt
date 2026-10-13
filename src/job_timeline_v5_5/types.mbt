///|
/// Query parameters for paginated timeline retrieval (v5.5).
pub(all) struct JobTimelineQuery {
  job_id : String
  from_logical_time : Int32?
  to_logical_time : Int32?
  limit : Int32
  cursor : String?
}

///|
/// Decoded cursor for offset-based pagination.
pub(all) struct JobTimelineCursor {
  offset : Int32
}

///|
/// Result of a paginated timeline query.
pub(all) struct JobTimelinePage {
  events : Array[@job_timeline_v5_4.JobTimelineEvent]
  offset : Int32
  limit : Int32
  has_more : Bool
}
