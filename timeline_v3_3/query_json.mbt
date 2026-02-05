///|
/// JSON projection for timeline query/cursor (v3.3).

fn option_number(value : Int?) -> Json {
  match value {
    Some(v) => Json::number(v.to_double())
    None => Json::null()
  }
}

fn option_string(value : String?) -> Json {
  match value {
    Some(v) => Json::string(v)
    None => Json::null()
  }
}

///|
pub fn cursor_from_query(query : TimelineQuery, offset : Int) -> TimelineCursor {
  {
    entity_id: query.entity_id,
    offset,
    limit: query.limit,
    from_logical_time: query.from_logical_time,
    to_logical_time: query.to_logical_time,
    kind: query.kind,
  }
}

///|
pub fn cursor_json(cursor : TimelineCursor) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["entityId"] = Json::string(cursor.entity_id)
  obj["offset"] = Json::number(cursor.offset.to_double())
  obj["limit"] = Json::number(cursor.limit.to_double())
  obj["fromLogicalTime"] = option_number(cursor.from_logical_time)
  obj["toLogicalTime"] = option_number(cursor.to_logical_time)
  obj["kind"] = option_string(cursor.kind)
  Json::object(obj)
}

///|
pub fn encode_cursor(cursor : TimelineCursor) -> String {
  "offset:" + cursor.offset.to_string()
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
pub fn decode_cursor(value : String) -> Int? {
  if value.has_prefix("offset:") {
    parse_uint_from(value, 7)
  } else {
    None
  }
}
