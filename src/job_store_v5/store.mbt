///|
/// Deterministic in-memory job store (v5.0).
/// Poll-count retention is consumed ONLY by `step_job`.
let store : Ref[Map[String, @export_job_v5.JobRecord]] = @ref.new(Map::new())
let progress_total = 3

fn job_id_value(id : @export_job_v5.JobId) -> String {
  id.value
}

fn cancel_reason(job_id : String) -> @export_job_v5.ReasonV1 {
  {
    code: @export_job_v5.ReasonCode::JobCanceled,
    level: @export_job_v5.ReasonLevel::Error,
    target: "runtime",
    message: "job canceled: " + job_id,
    hint: Some("Job was canceled"),
  }
}

fn expired_reason(job_id : String) -> @export_job_v5.ReasonV1 {
  {
    code: @export_job_v5.ReasonCode::JobExpired,
    level: @export_job_v5.ReasonLevel::Error,
    target: "runtime",
    message: "job expired: " + job_id,
    hint: Some("Job retention expired"),
  }
}

fn advance_status(status : @export_job_v5.JobStatus) -> @export_job_v5.JobStatus {
  match status {
    @export_job_v5.JobStatus::Queued => @export_job_v5.JobStatus::Running
    @export_job_v5.JobStatus::Running => @export_job_v5.JobStatus::Done
    _ => status
  }
}

fn advance_progress(progress : @export_job_v5.JobProgress, status : @export_job_v5.JobStatus) -> @export_job_v5.JobProgress {
  match status {
    @export_job_v5.JobStatus::Queued => { processed: 0, total: progress.total }
    @export_job_v5.JobStatus::Running => { processed: 1, total: progress.total }
    @export_job_v5.JobStatus::Done => { processed: progress.total, total: progress.total }
    _ => progress
  }
}

fn is_terminal(status : @export_job_v5.JobStatus) -> Bool {
  match status {
    @export_job_v5.JobStatus::Done => true
    @export_job_v5.JobStatus::Failed => true
    @export_job_v5.JobStatus::Canceled => true
    @export_job_v5.JobStatus::Expired => true
    _ => false
  }
}

fn should_expire(job : @export_job_v5.JobRecord) -> Bool {
  job.poll_count >= job.retention.ttl_polls
}

///|
pub fn reset_for_test() -> Unit {
  @export_job_v5.reset_id_for_test()
  store.val = Map::new()
}

///|
/// Seed deterministic state for fixture-driven tests.
pub fn seed_for_test(next_id : Int, jobs : Array[@export_job_v5.JobRecord]) -> Unit {
  @export_job_v5.seed_id_for_test(next_id)
  let seeded : Map[String, @export_job_v5.JobRecord] = Map::new()
  for job in jobs {
    seeded[job.id.value] = job
  }
  store.val = seeded
}

///|
pub fn create_job(format : @export_job_v5.ResultFormat, retention : @export_job_v5.Retention) -> @export_job_v5.JobRecord {
  let id = @export_job_v5.next_job_id()
  let id_value = id.value
  let job : @export_job_v5.JobRecord = {
    id,
    status: @export_job_v5.JobStatus::Queued,
    progress: { processed: 0, total: progress_total },
    retention,
    format,
    reasons: [],
    poll_count: 0,
  }
  store.val[id_value] = job
  job
}

///|
pub fn get_job(id : String) -> @export_job_v5.JobRecord? {
  store.val.get(id)
}

///|
///|
/// Advances exactly one logical execution step and increments poll-count.
pub fn step_job(id : String) -> @export_job_v5.JobRecord? {
  match store.val.get(id) {
    Some(job) => {
      let next_poll = job.poll_count + 1
      let expired = should_expire({
        id: job.id,
        status: job.status,
        progress: job.progress,
        retention: job.retention,
        format: job.format,
        reasons: job.reasons,
        poll_count: next_poll,
      })
      let next_status = if expired {
        @export_job_v5.JobStatus::Expired
      } else if is_terminal(job.status) {
        job.status
      } else {
        advance_status(job.status)
      }
      let next_progress = advance_progress(job.progress, next_status)
      let next_reasons = match next_status {
        @export_job_v5.JobStatus::Expired => [expired_reason(job_id_value(job.id))]
        _ => job.reasons
      }
      let next : @export_job_v5.JobRecord = {
        id: job.id,
        status: next_status,
        progress: next_progress,
        retention: job.retention,
        format: job.format,
        reasons: next_reasons,
        poll_count: next_poll,
      }
      store.val[id] = next
      Some(next)
    }
    None => None
  }
}

///|
/// Idempotent cancel: terminal jobs remain unchanged.
pub fn cancel_job(id : String) -> @export_job_v5.JobRecord? {
  match store.val.get(id) {
    Some(job) => {
      let next_status = match job.status {
        @export_job_v5.JobStatus::Canceled => @export_job_v5.JobStatus::Canceled
        @export_job_v5.JobStatus::Expired => @export_job_v5.JobStatus::Expired
        @export_job_v5.JobStatus::Done => @export_job_v5.JobStatus::Done
        @export_job_v5.JobStatus::Failed => @export_job_v5.JobStatus::Failed
        _ => @export_job_v5.JobStatus::Canceled
      }
      let next_reasons = match next_status {
        @export_job_v5.JobStatus::Canceled => [cancel_reason(job_id_value(job.id))]
        _ => job.reasons
      }
      let next : @export_job_v5.JobRecord = {
        id: job.id,
        status: next_status,
        progress: job.progress,
        retention: job.retention,
        format: job.format,
        reasons: next_reasons,
        poll_count: job.poll_count,
      }
      store.val[id] = next
      Some(next)
    }
    None => None
  }
}

///|
/// Explicitly mark a job as failed (deterministic failure injection).
pub fn fail_job(id : String, reason : @export_job_v5.ReasonV1) -> @export_job_v5.JobRecord? {
  match store.val.get(id) {
    Some(job) => {
      let next_status = match job.status {
        @export_job_v5.JobStatus::Done => @export_job_v5.JobStatus::Done
        @export_job_v5.JobStatus::Expired => @export_job_v5.JobStatus::Expired
        @export_job_v5.JobStatus::Canceled => @export_job_v5.JobStatus::Canceled
        _ => @export_job_v5.JobStatus::Failed
      }
      let next_reasons = match next_status {
        @export_job_v5.JobStatus::Failed => [reason]
        _ => job.reasons
      }
      let next : @export_job_v5.JobRecord = {
        id: job.id,
        status: next_status,
        progress: job.progress,
        retention: job.retention,
        format: job.format,
        reasons: next_reasons,
        poll_count: job.poll_count,
      }
      store.val[id] = next
      Some(next)
    }
    None => None
  }
}

///|
pub fn expire_job(id : String) -> @export_job_v5.JobRecord? {
  match store.val.get(id) {
    Some(job) => {
      let next_status = if should_expire(job) {
        @export_job_v5.JobStatus::Expired
      } else {
        job.status
      }
      let next_reasons = match next_status {
        @export_job_v5.JobStatus::Expired => [expired_reason(job_id_value(job.id))]
        _ => job.reasons
      }
      let next : @export_job_v5.JobRecord = {
        id: job.id,
        status: next_status,
        progress: job.progress,
        retention: job.retention,
        format: job.format,
        reasons: next_reasons,
        poll_count: job.poll_count,
      }
      store.val[id] = next
      Some(next)
    }
    None => None
  }
}
