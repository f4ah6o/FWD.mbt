///|
/// Job timeline event kind (v5.4).
pub(all) enum JobTimelineKind {
  StatusChange
  PolicyDecision
  RetentionCheck
}

///|
/// A single timeline event recording a job state transition.
/// Ordering: (job_id, logical_time, sequence) — deterministic, append-only.
pub(all) struct JobTimelineEvent {
  job_id : String
  logical_time : Int
  sequence : Int
  kind : JobTimelineKind
  from_status : String
  to_status : String
  reasons : Array[@export_job_v5.ReasonV1]
}
