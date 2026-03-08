///|
/// Append-only timeline store (v5.4).
/// Events are indexed by job_id and ordered by (logical_time, sequence).
let timeline_store : Ref[Map[String, Array[JobTimelineEvent]]] = @ref.new(
  Map::new(),
)

///|
/// Sequence counter per job_id per logical_time.
let sequence_counters : Ref[Map[String, Int]] = @ref.new(Map::new())

///|
fn sequence_key(job_id : String, logical_time : Int) -> String {
  job_id + ":" + logical_time.to_string()
}

///|
fn next_sequence(job_id : String, logical_time : Int) -> Int {
  let key = sequence_key(job_id, logical_time)
  let current = match sequence_counters.val.get(key) {
    Some(n) => n
    None => 0
  }
  let next = current + 1
  sequence_counters.val[key] = next
  next
}

///|
/// Record a timeline event (append-only).
pub fn record_event(event : JobTimelineEvent) -> Unit {
  let events = match timeline_store.val.get(event.job_id) {
    Some(arr) => arr
    None => {
      let arr : Array[JobTimelineEvent] = []
      timeline_store.val[event.job_id] = arr
      arr
    }
  }
  events.push(event)
}

///|
/// Record a status change event with auto-sequencing.
pub fn record_status_change(
  job_id : String,
  logical_time : Int,
  from_status : String,
  to_status : String,
  reasons : Array[@export_job_v5.ReasonV1],
) -> Unit {
  let seq = next_sequence(job_id, logical_time)
  let event : JobTimelineEvent = {
    job_id,
    logical_time,
    sequence: seq,
    kind: JobTimelineKind::StatusChange,
    from_status,
    to_status,
    reasons,
  }
  record_event(event)
}

///|
/// Record a policy decision event with auto-sequencing.
pub fn record_policy_decision(
  job_id : String,
  logical_time : Int,
  to_status : String,
  reasons : Array[@export_job_v5.ReasonV1],
) -> Unit {
  let seq = next_sequence(job_id, logical_time)
  let event : JobTimelineEvent = {
    job_id,
    logical_time,
    sequence: seq,
    kind: JobTimelineKind::PolicyDecision,
    from_status: "pending",
    to_status,
    reasons,
  }
  record_event(event)
}

///|
/// Record a retention check event with auto-sequencing.
pub fn record_retention_check(
  job_id : String,
  logical_time : Int,
  to_status : String,
  reasons : Array[@export_job_v5.ReasonV1],
) -> Unit {
  let seq = next_sequence(job_id, logical_time)
  let event : JobTimelineEvent = {
    job_id,
    logical_time,
    sequence: seq,
    kind: JobTimelineKind::RetentionCheck,
    from_status: "active",
    to_status,
    reasons,
  }
  record_event(event)
}

///|
/// Get timeline for a single job, sorted by (logical_time, sequence).
pub fn get_timeline(job_id : String) -> Array[JobTimelineEvent] {
  match timeline_store.val.get(job_id) {
    Some(events) => {
      let sorted : Array[JobTimelineEvent] = []
      for event in events {
        sorted.push(event)
      }
      sorted.sort_by(compare_event)
      sorted
    }
    None => []
  }
}

///|
/// Get timeline for a batch (aggregate of child job timelines).
/// child_ids are the IDs of child jobs.
pub fn get_batch_timeline(
  child_ids : Array[String],
) -> Array[JobTimelineEvent] {
  let all_events : Array[JobTimelineEvent] = []
  for child_id in child_ids {
    match timeline_store.val.get(child_id) {
      Some(events) =>
        for event in events {
          all_events.push(event)
        }
      None => ()
    }
  }
  all_events.sort_by(compare_event)
  all_events
}

///|
fn compare_event(a : JobTimelineEvent, b : JobTimelineEvent) -> Int {
  let by_job = compare_string(a.job_id, b.job_id)
  if by_job != 0 {
    return by_job
  }
  if a.logical_time < b.logical_time {
    return -1
  } else if a.logical_time > b.logical_time {
    return 1
  }
  if a.sequence < b.sequence {
    return -1
  } else if a.sequence > b.sequence {
    return 1
  }
  0
}

///|
fn compare_string(a : String, b : String) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
pub fn reset_for_test() -> Unit {
  timeline_store.val = Map::new()
  sequence_counters.val = Map::new()
}
