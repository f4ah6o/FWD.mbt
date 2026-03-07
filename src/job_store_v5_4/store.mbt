///|
/// Deterministic in-memory job store (v5.4).
/// Extends v5.3 with automatic timeline event recording.
let store : Ref[Map[String, JobRecordV54]] = @ref.new(Map::new())

///|
let progress_total = 3

///|
fn should_expire(job : JobRecordV54) -> Bool {
  let input : @retention_v5_3.MultiAxisEvalInput = {
    policies: job.policies,
    current_poll_count: job.poll_count,
    current_logical_time: job.logical_time,
    current_event_count: job.event_count,
  }
  @retention_v5_3.evaluate_multi_axis(input).expired
}

///|
fn is_terminal(status : @export_job_v5.JobStatus) -> Bool {
  match status {
    @export_job_v5.JobStatus::Done => true
    @export_job_v5.JobStatus::Failed => true
    @export_job_v5.JobStatus::Canceled => true
    @export_job_v5.JobStatus::Expired => true
    _ => false
  }
}

///|
fn advance_status(
  status : @export_job_v5.JobStatus,
) -> @export_job_v5.JobStatus {
  match status {
    @export_job_v5.JobStatus::Queued => @export_job_v5.JobStatus::Running
    @export_job_v5.JobStatus::Running => @export_job_v5.JobStatus::Done
    _ => status
  }
}

///|
fn advance_progress(
  progress : @export_job_v5.JobProgress,
  status : @export_job_v5.JobStatus,
) -> @export_job_v5.JobProgress {
  match status {
    @export_job_v5.JobStatus::Queued => { processed: 0, total: progress.total }
    @export_job_v5.JobStatus::Running => { processed: 1, total: progress.total }
    @export_job_v5.JobStatus::Done =>
      { processed: progress.total, total: progress.total }
    _ => progress
  }
}

///|
fn status_string(status : @export_job_v5.JobStatus) -> String {
  match status {
    @export_job_v5.JobStatus::Queued => "queued"
    @export_job_v5.JobStatus::Running => "running"
    @export_job_v5.JobStatus::Done => "done"
    @export_job_v5.JobStatus::Failed => "failed"
    @export_job_v5.JobStatus::Canceled => "canceled"
    @export_job_v5.JobStatus::Expired => "expired"
  }
}

///|
fn expired_reason(job_id : String) -> @export_job_v5.ReasonV1 {
  {
    code: @export_job_v5.ReasonCode::JobExpired,
    level: @export_job_v5.ReasonLevel::Error,
    target: "runtime",
    message: "job expired: " + job_id,
    hint: Some("Job retention expired"),
  }
}

///|
fn cancel_reason(job_id : String) -> @export_job_v5.ReasonV1 {
  {
    code: @export_job_v5.ReasonCode::JobCanceled,
    level: @export_job_v5.ReasonLevel::Error,
    target: "runtime",
    message: "job canceled: " + job_id,
    hint: Some("Job was canceled"),
  }
}

///|
pub fn reset_for_test() -> Unit {
  @export_job_v5.reset_id_for_test()
  store.val = Map::new()
  @job_timeline_v5_4.reset_for_test()
}

///|
pub fn create_job(
  format : @export_job_v5.ResultFormat,
  policies : Array[@retention_v5_3.RetentionPolicyV53],
) -> JobRecordV54 {
  let id = @export_job_v5.next_job_id()
  let job : JobRecordV54 = {
    id,
    status: @export_job_v5.JobStatus::Queued,
    progress: { processed: 0, total: progress_total },
    policies,
    format,
    reasons: [],
    poll_count: 0,
    logical_time: 0,
    event_count: 0,
  }
  store.val[id.value] = job
  // Record creation event
  @job_timeline_v5_4.record_status_change(
    id.value,
    0,
    status_string(@export_job_v5.JobStatus::Queued),
    status_string(@export_job_v5.JobStatus::Queued),
    [],
  )
  job
}

///|
pub fn get_job(id : String) -> JobRecordV54? {
  store.val.get(id)
}

///|
/// Advances one logical step. poll_count, logical_time, and event_count all increment by 1.
/// Records a timeline event when status changes.
pub fn step_job(id : String) -> JobRecordV54? {
  match store.val.get(id) {
    Some(job) => {
      let next_poll = job.poll_count + 1
      let next_logical = job.logical_time + 1
      let next_event = job.event_count + 1
      let check_job : JobRecordV54 = {
        id: job.id,
        status: job.status,
        progress: job.progress,
        policies: job.policies,
        format: job.format,
        reasons: job.reasons,
        poll_count: next_poll,
        logical_time: next_logical,
        event_count: next_event,
      }
      let expired = should_expire(check_job)
      let next_status = if expired {
        @export_job_v5.JobStatus::Expired
      } else if is_terminal(job.status) {
        job.status
      } else {
        advance_status(job.status)
      }
      let next_progress = advance_progress(job.progress, next_status)
      let next_reasons : Array[@export_job_v5.ReasonV1] = match next_status {
        @export_job_v5.JobStatus::Expired => [expired_reason(job.id.value)]
        _ => job.reasons
      }
      let next : JobRecordV54 = {
        id: job.id,
        status: next_status,
        progress: next_progress,
        policies: job.policies,
        format: job.format,
        reasons: next_reasons,
        poll_count: next_poll,
        logical_time: next_logical,
        event_count: next_event,
      }
      store.val[id] = next
      // Record timeline event if status changed
      if status_string(job.status) != status_string(next_status) {
        let event_reasons : Array[@export_job_v5.ReasonV1] = match next_status {
          @export_job_v5.JobStatus::Expired => [expired_reason(job.id.value)]
          _ => []
        }
        @job_timeline_v5_4.record_status_change(
          id,
          next_logical,
          status_string(job.status),
          status_string(next_status),
          event_reasons,
        )
      }
      Some(next)
    }
    None => None
  }
}

///|
pub fn cancel_job(id : String) -> JobRecordV54? {
  match store.val.get(id) {
    Some(job) => {
      let next_status = match job.status {
        @export_job_v5.JobStatus::Canceled => @export_job_v5.JobStatus::Canceled
        @export_job_v5.JobStatus::Expired => @export_job_v5.JobStatus::Expired
        @export_job_v5.JobStatus::Done => @export_job_v5.JobStatus::Done
        @export_job_v5.JobStatus::Failed => @export_job_v5.JobStatus::Failed
        _ => @export_job_v5.JobStatus::Canceled
      }
      let next_reasons : Array[@export_job_v5.ReasonV1] = match next_status {
        @export_job_v5.JobStatus::Canceled =>
          if status_string(job.status) != "canceled" {
            [cancel_reason(job.id.value)]
          } else {
            job.reasons
          }
        _ => job.reasons
      }
      let next : JobRecordV54 = {
        id: job.id,
        status: next_status,
        progress: job.progress,
        policies: job.policies,
        format: job.format,
        reasons: next_reasons,
        poll_count: job.poll_count,
        logical_time: job.logical_time,
        event_count: job.event_count,
      }
      store.val[id] = next
      // Record timeline event if status changed
      if status_string(job.status) != status_string(next_status) {
        @job_timeline_v5_4.record_status_change(
          id,
          job.logical_time,
          status_string(job.status),
          status_string(next_status),
          next_reasons,
        )
      }
      Some(next)
    }
    None => None
  }
}

///|
fn axis_string(axis : @retention_v5_3.RetentionAxisV53) -> String {
  match axis {
    @retention_v5_3.RetentionAxisV53::PollCount => "poll_count"
    @retention_v5_3.RetentionAxisV53::LogicalTime => "logical_time"
    @retention_v5_3.RetentionAxisV53::EventCount => "event_count"
  }
}

///|
pub fn job_json(job : JobRecordV54) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.4")
  obj["jobId"] = Json::string(job.id.value)
  obj["status"] = Json::string(status_string(job.status))
  obj["progress"] = Json::object({
    "processed": Json::number(job.progress.processed.to_double()),
    "total": Json::number(job.progress.total.to_double()),
  })
  let policies_json : Array[Json] = []
  for policy in job.policies {
    policies_json.push(
      Json::object({
        "axis": Json::string(axis_string(policy.axis)),
        "threshold": Json::number(policy.threshold.to_double()),
        "ttlSeconds": Json::number(policy.ttl_seconds.to_double()),
      }),
    )
  }
  obj["policies"] = Json::array(policies_json)
  obj["pollCount"] = Json::number(job.poll_count.to_double())
  obj["logicalTime"] = Json::number(job.logical_time.to_double())
  obj["eventCount"] = Json::number(job.event_count.to_double())
  Json::object(obj).stringify(indent=2)
}
