///|
/// Export job contract (v4.7).

///|
pub(all) enum JobKind {
  Metrics
  Timeline
}

///|
pub(all) enum JobStatus {
  Queued
  Running
  Done
  Failed
}

///|
pub(all) struct JobProgress {
  processed : Int32
  total : Int32
}

///|
pub(all) struct MetricsJobInput {
  entity_id : String
  from_logical_time : Int32?
  to_logical_time : Int32?
  format : String
}

///|
pub(all) struct TimelineJobInput {
  entity_id : String
  from_logical_time : Int32?
  to_logical_time : Int32?
  limit : Int32
  cursor : String?
  format : String
}

///|
pub(all) enum JobInput {
  Metrics(MetricsJobInput)
  Timeline(TimelineJobInput)
}

///|
pub(all) struct JobRecord {
  id : String
  kind : JobKind
  status : JobStatus
  input : JobInput
  progress : JobProgress
  ttl_seconds : Int32
  reasons : Array[@core.Reason]
  poll_count : Int32
}

///|
fn status_string(status : JobStatus) -> String {
  match status {
    JobStatus::Queued => "queued"
    JobStatus::Running => "running"
    JobStatus::Done => "done"
    JobStatus::Failed => "failed"
  }
}

///|
fn kind_string(kind : JobKind) -> String {
  match kind {
    JobKind::Metrics => "metrics"
    JobKind::Timeline => "timeline"
  }
}

///|
fn reasons_json(reasons : Array[@core.Reason]) -> Json {
  let items : Array[Json] = []
  for reason in reasons {
    items.push(@compiler.reason_json(reason))
  }
  Json::array(items)
}

///|
pub fn job_json(job : JobRecord, download_url : String?) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("4.7")
  obj["jobId"] = Json::string(job.id)
  obj["kind"] = Json::string(kind_string(job.kind))
  obj["status"] = Json::string(status_string(job.status))
  obj["progress"] = Json::object({
    "processed": Json::number(job.progress.processed.to_double()),
    "total": Json::number(job.progress.total.to_double()),
  })
  obj["ttlSeconds"] = Json::number(job.ttl_seconds.to_double())
  match download_url {
    Some(value) => obj["downloadUrl"] = Json::string(value)
    None => ()
  }
  if job.reasons.length() > 0 {
    obj["reasons"] = reasons_json(job.reasons)
  }
  Json::object(obj).stringify(indent=2)
}
