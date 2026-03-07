///|
/// Query parameters for paginated timeline retrieval (v5.5).
pub(all) struct JobTimelineQuery {
  job_id : String
  from_logical_time : Int?
  to_logical_time : Int?
  limit : Int
  cursor : String?
}

///|
/// Decoded cursor for offset-based pagination.
pub(all) struct JobTimelineCursor {
  offset : Int
}

///|
/// Result of a paginated timeline query.
pub(all) struct JobTimelinePage {
  events : Array[@job_timeline_v5_4.JobTimelineEvent]
  offset : Int
  limit : Int
  has_more : Bool
}
