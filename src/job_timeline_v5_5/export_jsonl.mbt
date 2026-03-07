///|
/// JSONL export for job timeline events (v5.5).
/// Each line is a single JSON object with an eventId.

///|
fn event_id(event : @job_timeline_v5_4.JobTimelineEvent) -> String {
  event.job_id +
  ":" +
  event.logical_time.to_string() +
  ":" +
  event.sequence.to_string() +
  ":" +
  kind_string(event.kind)
}

///|
fn jsonl_line(event : @job_timeline_v5_4.JobTimelineEvent) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["eventId"] = Json::string(event_id(event))
  obj["jobId"] = Json::string(event.job_id)
  obj["logicalTime"] = Json::number(event.logical_time.to_double())
  obj["sequence"] = Json::number(event.sequence.to_double())
  obj["kind"] = Json::string(kind_string(event.kind))
  obj["fromStatus"] = Json::string(event.from_status)
  obj["toStatus"] = Json::string(event.to_status)
  let reasons_arr : Array[Json] = []
  for reason in event.reasons {
    let reason_obj : Map[String, Json] = Map::new()
    reason_obj["reasonVersion"] = Json::number(1)
    reason_obj["code"] = Json::string(reason_code_string(reason.code))
    reason_obj["level"] = Json::string(reason_level_string(reason.level))
    reason_obj["target"] = Json::string(reason.target)
    reason_obj["message"] = Json::string(reason.message)
    match reason.hint {
      Some(value) => reason_obj["hint"] = Json::string(value)
      None => ()
    }
    reasons_arr.push(Json::object(reason_obj))
  }
  obj["reasons"] = Json::array(reasons_arr)
  Json::object(obj).stringify()
}

///|
/// Export events as JSONL string. One JSON object per line, ending with LF.
pub fn export_jsonl(
  events : Array[@job_timeline_v5_4.JobTimelineEvent],
) -> String {
  let sb = StringBuilder::new()
  for event in events {
    sb.write_string(jsonl_line(event))
    sb.write_string("\n")
  }
  sb.to_string()
}

///|
/// Export filtered events as JSONL for a single job.
pub fn export_job_jsonl(
  job_id : String,
  from_logical_time : Int?,
  to_logical_time : Int?,
) -> String {
  let events = @job_timeline_v5_4.get_timeline(job_id)
  let filtered = filter_events(events, from_logical_time, to_logical_time)
  export_jsonl(filtered)
}

///|
/// Export filtered events as JSONL for a batch (aggregate child events).
pub fn export_batch_jsonl(
  child_ids : Array[String],
  from_logical_time : Int?,
  to_logical_time : Int?,
) -> String {
  let events = @job_timeline_v5_4.get_batch_timeline(child_ids)
  let filtered = filter_events(events, from_logical_time, to_logical_time)
  export_jsonl(filtered)
}
