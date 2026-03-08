///|
/// JSON projection for event detail (v5.7).

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
fn event_detail_json(
  event : @job_timeline_v5_4.JobTimelineEvent,
) -> Json {
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
/// Produce JSON for an event detail response.
pub fn detail_json(detail : JobTimelineDetail) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.7")
  obj["eventId"] = Json::string(event_id(detail.event))
  obj["event"] = event_detail_json(detail.event)
  match detail.prev_event {
    Some(prev) => obj["prevEventId"] = Json::string(event_id(prev))
    None => ()
  }
  match detail.next_event {
    Some(next) => obj["nextEventId"] = Json::string(event_id(next))
    None => ()
  }
  Json::object(obj).stringify(indent=2)
}
