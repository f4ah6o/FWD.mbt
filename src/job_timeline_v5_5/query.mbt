///|
/// Cursor encode/decode and pagination logic (v5.5).

///|
/// Encode cursor as "offset:N".
pub fn encode_cursor(offset : Int) -> String {
  "offset:" + offset.to_string()
}

///|
/// Decode cursor from "offset:N" format. Returns None for invalid format.
pub fn decode_cursor(s : String) -> JobTimelineCursor? {
  let prefix = "offset:"
  if s.has_prefix(prefix) == false {
    return None
  }
  let start = prefix.length()
  if start >= s.length() {
    return None
  }
  let mut value = 0
  let mut valid = true
  for i = start; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      value = value * 10 + (c.to_int() - '0'.to_int())
    } else {
      valid = false
      break
    }
  }
  if valid {
    Some({ offset: value })
  } else {
    None
  }
}

///|
/// Filter events by logical time range.
pub fn filter_events(
  events : Array[@job_timeline_v5_4.JobTimelineEvent],
  from_logical_time : Int?,
  to_logical_time : Int?,
) -> Array[@job_timeline_v5_4.JobTimelineEvent] {
  let filtered : Array[@job_timeline_v5_4.JobTimelineEvent] = []
  for event in events {
    let pass_from = match from_logical_time {
      Some(from) => event.logical_time >= from
      None => true
    }
    let pass_to = match to_logical_time {
      Some(to) => event.logical_time <= to
      None => true
    }
    if pass_from && pass_to {
      filtered.push(event)
    }
  }
  filtered
}

///|
/// Apply pagination to a filtered event list.
pub fn paginate(
  events : Array[@job_timeline_v5_4.JobTimelineEvent],
  offset : Int,
  limit : Int,
) -> JobTimelinePage {
  let page : Array[@job_timeline_v5_4.JobTimelineEvent] = []
  let total = events.length()
  let mut idx = 0
  for event in events {
    if idx >= offset && page.length() < limit {
      page.push(event)
    }
    idx = idx + 1
  }
  let has_more = offset + limit < total
  { events: page, offset, limit, has_more }
}

///|
/// Execute a full query: get events, filter, paginate.
pub fn query_timeline(
  query : JobTimelineQuery,
) -> Result[JobTimelinePage, String] {
  let offset = match query.cursor {
    Some(cursor_str) =>
      match decode_cursor(cursor_str) {
        Some(cursor) => cursor.offset
        None => return Err("invalid cursor format")
      }
    None => 0
  }
  let events = @job_timeline_v5_4.get_timeline(query.job_id)
  let filtered = filter_events(
    events,
    query.from_logical_time,
    query.to_logical_time,
  )
  Ok(paginate(filtered, offset, query.limit))
}

///|
/// Execute a batch query: get batch events, filter, paginate.
pub fn query_batch_timeline(
  child_ids : Array[String],
  from_logical_time : Int?,
  to_logical_time : Int?,
  limit : Int,
  cursor : String?,
) -> Result[JobTimelinePage, String] {
  let offset = match cursor {
    Some(cursor_str) =>
      match decode_cursor(cursor_str) {
        Some(c) => c.offset
        None => return Err("invalid cursor format")
      }
    None => 0
  }
  let events = @job_timeline_v5_4.get_batch_timeline(child_ids)
  let filtered = filter_events(events, from_logical_time, to_logical_time)
  Ok(paginate(filtered, offset, limit))
}
