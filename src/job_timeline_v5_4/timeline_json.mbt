///|
/// JSON projection for job timeline events (v5.4).

///|
fn kind_string(kind : JobTimelineKind) -> String {
  match kind {
    JobTimelineKind::StatusChange => "status_change"
    JobTimelineKind::PolicyDecision => "policy_decision"
    JobTimelineKind::RetentionCheck => "retention_check"
  }
}

///|
fn reason_code_string(code : @export_job_v5.ReasonCode) -> String {
  match code {
    @export_job_v5.ReasonCode::QueryMissing => "QUERY_MISSING"
    @export_job_v5.ReasonCode::QueryInvalid => "QUERY_INVALID"
    @export_job_v5.ReasonCode::JobNotFound => "JOB_NOT_FOUND"
    @export_job_v5.ReasonCode::JobNotReady => "JOB_NOT_READY"
    @export_job_v5.ReasonCode::JobCanceled => "JOB_CANCELED"
    @export_job_v5.ReasonCode::JobExpired => "JOB_EXPIRED"
    @export_job_v5.ReasonCode::PolicyDenied => "POLICY_DENIED"
  }
}

///|
fn reason_level_string(level : @export_job_v5.ReasonLevel) -> String {
  match level {
    @export_job_v5.ReasonLevel::Error => "error"
    @export_job_v5.ReasonLevel::Warn => "warn"
    @export_job_v5.ReasonLevel::Info => "info"
  }
}

///|
fn reason_v1_json(reason : @export_job_v5.ReasonV1) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["reasonVersion"] = Json::number(1)
  obj["code"] = Json::string(reason_code_string(reason.code))
  obj["level"] = Json::string(reason_level_string(reason.level))
  obj["target"] = Json::string(reason.target)
  obj["message"] = Json::string(reason.message)
  match reason.hint {
    Some(value) => obj["hint"] = Json::string(value)
    None => ()
  }
  Json::object(obj)
}

///|
fn event_json(event : JobTimelineEvent) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["logicalTime"] = Json::number(event.logical_time.to_double())
  obj["sequence"] = Json::number(event.sequence.to_double())
  obj["kind"] = Json::string(kind_string(event.kind))
  obj["fromStatus"] = Json::string(event.from_status)
  obj["toStatus"] = Json::string(event.to_status)
  let reasons_arr : Array[Json] = []
  for reason in event.reasons {
    reasons_arr.push(reason_v1_json(reason))
  }
  obj["reasons"] = Json::array(reasons_arr)
  Json::object(obj)
}

///|
fn batch_event_json(event : JobTimelineEvent) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["jobId"] = Json::string(event.job_id)
  obj["logicalTime"] = Json::number(event.logical_time.to_double())
  obj["sequence"] = Json::number(event.sequence.to_double())
  obj["kind"] = Json::string(kind_string(event.kind))
  obj["fromStatus"] = Json::string(event.from_status)
  obj["toStatus"] = Json::string(event.to_status)
  let reasons_arr : Array[Json] = []
  for reason in event.reasons {
    reasons_arr.push(reason_v1_json(reason))
  }
  obj["reasons"] = Json::array(reasons_arr)
  Json::object(obj)
}

///|
/// Produce the JSON string for a single job's timeline.
pub fn timeline_json(job_id : String, events : Array[JobTimelineEvent]) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.4")
  obj["jobId"] = Json::string(job_id)
  let events_arr : Array[Json] = []
  for event in events {
    events_arr.push(event_json(event))
  }
  obj["events"] = Json::array(events_arr)
  Json::object(obj).stringify(indent=2)
}

///|
/// Produce the JSON string for a batch job's aggregated timeline.
pub fn batch_timeline_json(
  batch_id : String,
  events : Array[JobTimelineEvent],
) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.4")
  obj["batchId"] = Json::string(batch_id)
  let events_arr : Array[Json] = []
  for event in events {
    events_arr.push(batch_event_json(event))
  }
  obj["events"] = Json::array(events_arr)
  Json::object(obj).stringify(indent=2)
}
