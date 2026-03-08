///|
/// Query parameters for event detail lookup (v5.7).
pub(all) struct JobTimelineDetailQuery {
  job_id : String
  logical_time : Int
  sequence : Int
  kind : @job_timeline_v5_4.JobTimelineKind
}

///|
/// Result of an event detail lookup with adjacent events.
pub(all) struct JobTimelineDetail {
  event : @job_timeline_v5_4.JobTimelineEvent
  prev_event : @job_timeline_v5_4.JobTimelineEvent?
  next_event : @job_timeline_v5_4.JobTimelineEvent?
}
