///|
/// Event detail lookup and kind filter logic (v5.7).

///|
/// Map kind string to enum. Returns None for unrecognized kinds.
pub fn parse_kind(s : String) -> @job_timeline_v5_4.JobTimelineKind? {
  if s == "status_change" {
    Some(@job_timeline_v5_4.JobTimelineKind::StatusChange)
  } else {
    None
  }
}

///|
/// Map kind enum to string.
pub fn kind_string(kind : @job_timeline_v5_4.JobTimelineKind) -> String {
  match kind {
    @job_timeline_v5_4.JobTimelineKind::StatusChange => "status_change"
  }
}

///|
/// Filter events by kind. When kind is None, returns all events unchanged.
pub fn filter_events_by_kind(
  events : Array[@job_timeline_v5_4.JobTimelineEvent],
  kind : @job_timeline_v5_4.JobTimelineKind?,
) -> Array[@job_timeline_v5_4.JobTimelineEvent] {
  match kind {
    None => events
    Some(k) => {
      let target = kind_string(k)
      let result : Array[@job_timeline_v5_4.JobTimelineEvent] = []
      for event in events {
        if kind_string(event.kind) == target {
          result.push(event)
        }
      }
      result
    }
  }
}

///|
/// Build event ID string from event fields.
pub fn event_id(event : @job_timeline_v5_4.JobTimelineEvent) -> String {
  event.job_id +
  ":" +
  event.logical_time.to_string() +
  ":" +
  event.sequence.to_string() +
  ":" +
  kind_string(event.kind)
}

///|
/// Parse event ID string "job_id:logicalTime:sequence:kind" into query.
/// Returns None for invalid format.
pub fn parse_event_id(s : String) -> JobTimelineDetailQuery? {
  // Split by ':' — collect colon positions
  let colon_positions : Array[Int] = []
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == ':' {
      colon_positions.push(i)
    }
  }
  // Need at least 3 colons: job_id:logicalTime:sequence:kind
  if colon_positions.length() < 3 {
    return None
  }
  // Last colon separates sequence from kind
  let last_colon = colon_positions[colon_positions.length() - 1]
  // Second-to-last separates logicalTime from sequence
  let seq_colon = colon_positions[colon_positions.length() - 2]
  // Third-to-last separates job_id from logicalTime
  let lt_colon = colon_positions[colon_positions.length() - 3]
  let kind_str = substring_from(s, last_colon + 1)
  let kind = match parse_kind(kind_str) {
    Some(k) => k
    None => return None
  }
  let seq_str = substring_range(s, seq_colon + 1, last_colon)
  let sequence = match parse_int_string(seq_str) {
    Some(n) => n
    None => return None
  }
  let lt_str = substring_range(s, lt_colon + 1, seq_colon)
  let logical_time = match parse_int_string(lt_str) {
    Some(n) => n
    None => return None
  }
  let job_id = substring_range(s, 0, lt_colon)
  if job_id.length() == 0 {
    return None
  }
  Some({ job_id, logical_time, sequence, kind })
}

///|
fn parse_int_string(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut value = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      value = value * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(value)
}

///|
fn substring_from(value : String, start : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<value.length() {
    let ch = value[i].to_int()
    sb.write_char(Int::unsafe_to_char(ch))
  }
  sb.to_string()
}

///|
fn substring_range(value : String, start : Int, end_ : Int) -> String {
  let sb = StringBuilder::new()
  let limit = if end_ < value.length() { end_ } else { value.length() }
  for i in start..<limit {
    let ch = value[i].to_int()
    sb.write_char(Int::unsafe_to_char(ch))
  }
  sb.to_string()
}

///|
/// Find an event and its adjacent prev/next events in a timeline.
/// Returns None if the event is not found.
pub fn find_event(
  events : Array[@job_timeline_v5_4.JobTimelineEvent],
  logical_time : Int,
  sequence : Int,
  kind : @job_timeline_v5_4.JobTimelineKind,
) -> JobTimelineDetail? {
  let target_kind = kind_string(kind)
  for i, event in events {
    if event.logical_time == logical_time &&
      event.sequence == sequence &&
      kind_string(event.kind) == target_kind {
      let prev = if i > 0 { Some(events[i - 1]) } else { None }
      let next = if i + 1 < events.length() {
        Some(events[i + 1])
      } else {
        None
      }
      return Some({ event, prev_event: prev, next_event: next })
    }
  }
  None
}

///|
/// Look up a single event detail from the store.
pub fn lookup_event_detail(
  query : JobTimelineDetailQuery,
) -> JobTimelineDetail? {
  let events = @job_timeline_v5_4.get_timeline(query.job_id)
  find_event(events, query.logical_time, query.sequence, query.kind)
}

///|
/// Look up a single event detail from batch timeline.
pub fn lookup_batch_event_detail(
  child_ids : Array[String],
  query : JobTimelineDetailQuery,
) -> JobTimelineDetail? {
  let events = @job_timeline_v5_4.get_batch_timeline(child_ids)
  find_event(events, query.logical_time, query.sequence, query.kind)
}
