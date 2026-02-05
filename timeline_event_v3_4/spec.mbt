///|
/// Timeline event detail contract (v3.4).

///|
pub(all) struct EventIdParts {
  entity_id : String
  logical_time : Int
  sequence : Int
  kind : String
}

///|
pub(all) struct TimelineEventDetail {
  event_id : String
  event : @timeline_v3.TimelineEvent
}

fn kind_string(kind : @timeline_v3.TimelineKind) -> String {
  match kind {
    @timeline_v3.TimelineKind::Transition => "transition"
    @timeline_v3.TimelineKind::Effect => "effect"
    @timeline_v3.TimelineKind::Policy => "policy"
  }
}

fn parse_kind(value : String) -> String? {
  if value == "transition" || value == "effect" || value == "policy" {
    Some(value)
  } else {
    None
  }
}

fn split_colon(value : String) -> Array[String] {
  let parts : Array[String] = []
  let mut sb = StringBuilder::new()
  for ch in value {
    if ch == ':' {
      parts.push(sb.to_string())
      sb = StringBuilder::new()
    } else {
      sb.write_char(ch)
    }
  }
  parts.push(sb.to_string())
  parts
}

fn parse_uint_from(value : String, start : Int) -> Int? {
  if start >= value.length() {
    return None
  }
  let mut acc = 0
  for i in start..<value.length() {
    let ch = value[i].to_int()
    if ch < 48 || ch > 57 {
      return None
    }
    acc = acc * 10 + (ch - 48)
  }
  Some(acc)
}

///|
pub fn event_id(event : @timeline_v3.TimelineEvent) -> String {
  event.entity_id + ":" + event.logical_time.to_string() + ":" + event.sequence.to_string() + ":" + kind_string(event.kind)
}

///|
pub fn parse_event_id(value : String) -> EventIdParts? {
  let parts = split_colon(value)
  if parts.length() != 4 {
    return None
  }
  let entity = parts[0]
  let logical_time = parse_uint_from(parts[1], 0)
  let sequence = parse_uint_from(parts[2], 0)
  let kind = parse_kind(parts[3])
  match (logical_time, sequence, kind) {
    (Some(time), Some(seq), Some(kind_value)) => Some({
      entity_id: entity,
      logical_time: time,
      sequence: seq,
      kind: kind_value,
    })
    _ => None
  }
}

///|
pub fn detail_from_event(event : @timeline_v3.TimelineEvent) -> TimelineEventDetail {
  {
    event_id: event_id(event),
    event,
  }
}
