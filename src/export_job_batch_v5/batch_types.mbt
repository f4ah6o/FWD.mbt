///|
/// Batch job contract types (v5.0).

///|
pub(all) struct BatchChildSpec {
  entity_id : String
  from_logical_time : Int32
  to_logical_time : Int32
}

///|
/// Default retention constants for batch jobs (v5.0).
pub let default_ttl_polls : Int32 = 6

///|
pub let default_ttl_seconds : Int32 = 240

///|
pub(all) struct BatchJobRecord {
  id : String
  child_ids : Array[String]
  child_specs : Array[BatchChildSpec]
  status : @export_job_v5.JobStatus
  progress : @export_job_v5.JobProgress
  retention : @export_job_v5.Retention
  format : @export_job_v5.ResultFormat
  reasons : Array[@export_job_v5.ReasonV1]
  poll_count : Int32
  next_child_index : Int32
}
