///|
/// JSON projection for timeline events (v3).

fn kind_string(kind : TimelineKind) -> String {
  match kind {
    TimelineKind::Transition => "transition"
    TimelineKind::Effect => "effect"
    TimelineKind::Policy => "policy"
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

fn compare_event(a : TimelineEvent, b : TimelineEvent) -> Int {
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

fn event_json(event : TimelineEvent) -> Json {
  let obj : Map[String, Json] = Map::new()
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
pub fn timeline_json(events : Array[TimelineEvent]) -> Json {
  let sorted : Array[TimelineEvent] = []
  for event in events {
    sorted.push(event)
  }
  sorted.sort_by(compare_event)
  let arr : Array[Json] = []
  for event in sorted {
    arr.push(event_json(event))
  }
  let obj : Map[String, Json] = Map::new()
  obj["events"] = Json::array(arr)
  Json::object(obj)
}
