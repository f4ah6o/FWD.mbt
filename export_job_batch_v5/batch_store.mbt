///|
/// Deterministic in-memory batch store (v5.0).
/// Batch is modeled as a job whose unit of work is child jobs.
/// Poll-count retention is consumed ONLY by `step_batch`.
let batch_store : Ref[Map[String, BatchJobRecord]] = @ref.new(Map::new())
let child_store : Ref[Map[String, @export_job_v5.JobRecord]] = @ref.new(Map::new())
let progress_total = 3

fn next_id() -> String {
  @export_job_v5.next_job_id().value
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

fn child_progress(status : @export_job_v5.JobStatus) -> @export_job_v5.JobProgress {
  match status {
    @export_job_v5.JobStatus::Queued => { processed: 0, total: progress_total }
    @export_job_v5.JobStatus::Running => { processed: 1, total: progress_total }
    @export_job_v5.JobStatus::Done => { processed: progress_total, total: progress_total }
    _ => { processed: 0, total: progress_total }
  }
}

fn advance_child(status : @export_job_v5.JobStatus) -> @export_job_v5.JobStatus {
  match status {
    @export_job_v5.JobStatus::Queued => @export_job_v5.JobStatus::Running
    @export_job_v5.JobStatus::Running => @export_job_v5.JobStatus::Done
    _ => status
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

fn should_expire(poll_count : Int, retention : @export_job_v5.Retention) -> Bool {
  poll_count >= retention.ttl_polls
}

fn child_record(id_value : String, format : @export_job_v5.ResultFormat, retention : @export_job_v5.Retention) -> @export_job_v5.JobRecord {
  {
    id: { value: id_value },
    status: @export_job_v5.JobStatus::Queued,
    progress: { processed: 0, total: progress_total },
    retention,
    format,
    reasons: [],
    poll_count: 0,
  }
}

fn update_child(id : String, status : @export_job_v5.JobStatus, reasons : Array[@export_job_v5.ReasonV1]) -> Unit {
  match child_store.val.get(id) {
    Some(child) => {
      let next : @export_job_v5.JobRecord = {
        id: child.id,
        status,
        progress: child_progress(status),
        retention: child.retention,
        format: child.format,
        reasons,
        poll_count: child.poll_count,
      }
      child_store.val[id] = next
    }
    None => ()
  }
}

fn step_child(id : String) -> Unit {
  match child_store.val.get(id) {
    Some(child) => {
      let next_status = if is_terminal(child.status) {
        child.status
      } else {
        advance_child(child.status)
      }
      let next : @export_job_v5.JobRecord = {
        id: child.id,
        status: next_status,
        progress: child_progress(next_status),
        retention: child.retention,
        format: child.format,
        reasons: child.reasons,
        poll_count: child.poll_count,
      }
      child_store.val[id] = next
    }
    None => ()
  }
}

fn cancel_child(id : String) -> Unit {
  match child_store.val.get(id) {
    Some(child) => {
      if is_terminal(child.status) {
        ()
      } else {
        let reason = cancel_reason(child.id.value)
        update_child(id, @export_job_v5.JobStatus::Canceled, [reason])
      }
    }
    None => ()
  }
}

fn expire_child(id : String) -> Unit {
  match child_store.val.get(id) {
    Some(child) => {
      if is_terminal(child.status) {
        ()
      } else {
        let reason = expired_reason(child.id.value)
        update_child(id, @export_job_v5.JobStatus::Expired, [reason])
      }
    }
    None => ()
  }
}

fn batch_progress(child_ids : Array[String]) -> @export_job_v5.JobProgress {
  let mut done_count = 0
  for child_id in child_ids {
    match child_store.val.get(child_id) {
      Some(child) => {
        match child.status {
          @export_job_v5.JobStatus::Done => done_count = done_count + 1
          _ => ()
        }
      }
      None => ()
    }
  }
  { processed: done_count, total: child_ids.length() }
}

fn derive_batch_status(batch : BatchJobRecord) -> @export_job_v5.JobStatus {
  let mut any_expired = false
  let mut any_canceled = false
  let mut any_failed = false
  let mut all_done = true
  for child_id in batch.child_ids {
    match child_store.val.get(child_id) {
      Some(child) => {
        match child.status {
          @export_job_v5.JobStatus::Expired => any_expired = true
          @export_job_v5.JobStatus::Canceled => any_canceled = true
          @export_job_v5.JobStatus::Failed => any_failed = true
          @export_job_v5.JobStatus::Done => ()
          _ => all_done = false
        }
      }
      None => all_done = false
    }
  }
  if any_expired {
    @export_job_v5.JobStatus::Expired
  } else if any_canceled {
    @export_job_v5.JobStatus::Canceled
  } else if any_failed {
    @export_job_v5.JobStatus::Failed
  } else if all_done {
    @export_job_v5.JobStatus::Done
  } else {
    @export_job_v5.JobStatus::Running
  }
}

///|
pub fn reset_for_test() -> Unit {
  @export_job_v5.reset_id_for_test()
  batch_store.val = Map::new()
  child_store.val = Map::new()
}

///|
/// Seed deterministic state for fixture-driven tests.
pub fn seed_for_test(next_id : Int, batches : Array[BatchJobRecord]) -> Unit {
  @export_job_v5.seed_id_for_test(next_id)
  let seeded : Map[String, BatchJobRecord] = Map::new()
  for batch in batches {
    seeded[batch.id] = batch
  }
  batch_store.val = seeded
}

///|
pub fn create_batch(format : @export_job_v5.ResultFormat, retention : @export_job_v5.Retention, child_specs : Array[BatchChildSpec]) -> BatchJobRecord {
  let batch_id_value = next_id()
  let child_ids : Array[String] = []
  for _spec in child_specs {
    let child_id = next_id()
    child_ids.push(child_id)
    child_store.val[child_id] = child_record(child_id, format, retention)
  }
  let batch : BatchJobRecord = {
    id: batch_id_value,
    child_ids,
    child_specs,
    status: @export_job_v5.JobStatus::Queued,
    progress: { processed: 0, total: child_specs.length() },
    retention,
    format,
    reasons: [],
    poll_count: 0,
    next_child_index: 0,
  }
  batch_store.val[batch_id_value] = batch
  batch
}

///|
pub fn get_batch(id : String) -> BatchJobRecord? {
  batch_store.val.get(id)
}

///|
/// Advances exactly one logical execution step, stepping one child in-order.
pub fn step_batch(id : String) -> BatchJobRecord? {
  match batch_store.val.get(id) {
    Some(batch) => {
      let next_poll = batch.poll_count + 1
      let expired = should_expire(next_poll, batch.retention)
      let child_count = batch.child_ids.length()
      let next_child_index = if expired || is_terminal(batch.status) || child_count == 0 {
        batch.next_child_index
      } else {
        let index = batch.next_child_index % child_count
        let child_id = batch.child_ids[index]
        step_child(child_id)
        (index + 1) % child_count
      }
      if expired {
        for child_id in batch.child_ids {
          expire_child(child_id)
        }
      }
      let derived_status = if expired {
        @export_job_v5.JobStatus::Expired
      } else if is_terminal(batch.status) {
        batch.status
      } else {
        derive_batch_status(batch)
      }
      let next_reasons = match derived_status {
        @export_job_v5.JobStatus::Expired => [expired_reason(batch.id)]
        _ => batch.reasons
      }
      let next : BatchJobRecord = {
        id: batch.id,
        child_ids: batch.child_ids,
        child_specs: batch.child_specs,
        status: derived_status,
        progress: batch_progress(batch.child_ids),
        retention: batch.retention,
        format: batch.format,
        reasons: next_reasons,
        poll_count: next_poll,
        next_child_index,
      }
      batch_store.val[id] = next
      Some(next)
    }
    None => None
  }
}

///|
/// Idempotent cancel: terminal batches remain unchanged; cancel cascades to children.
pub fn cancel_batch(id : String) -> BatchJobRecord? {
  match batch_store.val.get(id) {
    Some(batch) => {
      let next_status = match batch.status {
        @export_job_v5.JobStatus::Canceled => @export_job_v5.JobStatus::Canceled
        @export_job_v5.JobStatus::Expired => @export_job_v5.JobStatus::Expired
        @export_job_v5.JobStatus::Done => @export_job_v5.JobStatus::Done
        @export_job_v5.JobStatus::Failed => @export_job_v5.JobStatus::Failed
        _ => @export_job_v5.JobStatus::Canceled
      }
      match next_status {
        @export_job_v5.JobStatus::Canceled => {
          for child_id in batch.child_ids {
            cancel_child(child_id)
          }
        }
        _ => ()
      }
      let next_reasons = match next_status {
        @export_job_v5.JobStatus::Canceled => [cancel_reason(batch.id)]
        _ => batch.reasons
      }
      let next : BatchJobRecord = {
        id: batch.id,
        child_ids: batch.child_ids,
        child_specs: batch.child_specs,
        status: next_status,
        progress: batch.progress,
        retention: batch.retention,
        format: batch.format,
        reasons: next_reasons,
        poll_count: batch.poll_count,
        next_child_index: batch.next_child_index,
      }
      batch_store.val[id] = next
      Some(next)
    }
    None => None
  }
}

///|
pub fn expire_batch(id : String) -> BatchJobRecord? {
  match batch_store.val.get(id) {
    Some(batch) => {
      let next_status = if should_expire(batch.poll_count, batch.retention) {
        @export_job_v5.JobStatus::Expired
      } else {
        batch.status
      }
      let next_reasons = match next_status {
        @export_job_v5.JobStatus::Expired => [expired_reason(batch.id)]
        _ => batch.reasons
      }
      let next : BatchJobRecord = {
        id: batch.id,
        child_ids: batch.child_ids,
        child_specs: batch.child_specs,
        status: next_status,
        progress: batch.progress,
        retention: batch.retention,
        format: batch.format,
        reasons: next_reasons,
        poll_count: batch.poll_count,
        next_child_index: batch.next_child_index,
      }
      batch_store.val[id] = next
      Some(next)
    }
    None => None
  }
}
