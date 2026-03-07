///|
/// v5.2 job record with multi-axis retention policies.
pub(all) struct JobRecordV52 {
  id : @export_job_v5.JobId
  status : @export_job_v5.JobStatus
  progress : @export_job_v5.JobProgress
  policies : Array[@retention_v5_2.RetentionPolicyV52]
  format : @export_job_v5.ResultFormat
  reasons : Array[@export_job_v5.ReasonV1]
  poll_count : Int
  logical_time : Int
}
