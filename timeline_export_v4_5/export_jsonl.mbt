///|
/// JSONL projection for timeline export (v4.5).

fn kind_string(kind : @timeline_v3.TimelineKind) -> String {
  match kind {
    @timeline_v3.TimelineKind::Transition => "transition"
    @timeline_v3.TimelineKind::Effect => "effect"
    @timeline_v3.TimelineKind::Policy => "policy"
  }
}

fn compare_string(a : String, b : String) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

fn compare_event(a : @timeline_v3.TimelineEvent, b : @timeline_v3.TimelineEvent) -> Int {
  let by_entity = compare_string(a.entity_id, b.entity_id)
  if by_entity != 0 {
    return by_entity
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

fn event_id(event : @timeline_v3.TimelineEvent) -> String {
  event.entity_id + ":" + event.logical_time.to_string() + ":" + event.sequence.to_string() + ":" + kind_string(event.kind)
}

fn line_json(event : @timeline_v3.TimelineEvent) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["eventId"] = Json::string(event_id(event))
  obj["entityId"] = Json::string(event.entity_id)
  obj["logicalTime"] = Json::number(event.logical_time.to_double())
  obj["sequence"] = Json::number(event.sequence.to_double())
  obj["kind"] = Json::string(kind_string(event.kind))
  obj["refId"] = Json::string(event.ref_id)
  obj["status"] = Json::string(event.status)
  let reasons : Array[Json] = []
  for reason in event.reasons {
    reasons.push(@compiler.reason_json(reason))
  }
  obj["reasons"] = Json::array(reasons)
  Json::object(obj)
}

///|
pub fn export_jsonl(events : Array[@timeline_v3.TimelineEvent]) -> String {
  let sorted : Array[@timeline_v3.TimelineEvent] = []
  for event in events {
    sorted.push(event)
  }
  sorted.sort_by(compare_event)
  let sb = StringBuilder::new()
  for i in 0..<sorted.length() {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_view(line_json(sorted[i]).stringify())
  }
  sb.to_string()
}
