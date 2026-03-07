///|
/// v5.3 job record with three-axis retention policies.
pub(all) struct JobRecordV53 {
  id : @export_job_v5.JobId
  status : @export_job_v5.JobStatus
  progress : @export_job_v5.JobProgress
  policies : Array[@retention_v5_3.RetentionPolicyV53]
  format : @export_job_v5.ResultFormat
  reasons : Array[@export_job_v5.ReasonV1]
  poll_count : Int
  logical_time : Int
  event_count : Int
}
