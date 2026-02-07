///|
/// HTTP adapter v4.5 (export filters).

///|
pub(all) struct ApiRequest {
  http_method : String
  path : String
  query : Map[String, String]
  body : String?
}

///|
pub(all) struct ApiResponse {
  status : Int
  headers : Map[String, String]
  body : String
}

///|
fn response_json(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "application/json"
  { status, headers, body }
}

///|
fn response_jsonl(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "application/jsonl"
  { status, headers, body }
}

///|
fn response_jsonl_with_cursor(status : Int, body : String, next_cursor : String?) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "application/jsonl"
  match next_cursor {
    Some(value) => headers["x-next-cursor"] = value
    None => ()
  }
  { status, headers, body }
}

///|
fn response_csv(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "text/csv"
  { status, headers, body }
}

///|
fn error_envelope_json(reason : @core.Reason) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["error"] = @compiler.reason_json(reason)
  Json::object(obj).stringify(indent=2)
}

///|
fn invalid_query_reason(message : String) -> @core.Reason {
  @core.Reason::with_context(
    "QUERY_INVALID",
    message,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Check query parameters"),
    ],
  )
}

///|
fn missing_query_reason(name : String) -> @core.Reason {
  @core.Reason::with_context(
    "QUERY_MISSING",
    "missing query: " + name,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Provide query '" + name + "'"),
    ],
  )
}

fn parse_int(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut acc = 0
  for i in 0..<value.length() {
    let ch = value[i].to_int()
    if ch < 48 || ch > 57 {
      return None
    }
    acc = acc * 10 + (ch - 48)
  }
  Some(acc)
}

fn apply_time_filter(
  events : Array[@timeline_v3.TimelineEvent],
  from_time : Int?,
  to_time : Int?,
) -> Array[@timeline_v3.TimelineEvent] {
  let filtered : Array[@timeline_v3.TimelineEvent] = []
  for event in events {
    let ok_from = match from_time {
      Some(value) => event.logical_time >= value
      None => true
    }
    let ok_to = match to_time {
      Some(value) => event.logical_time <= value
      None => true
    }
    if ok_from && ok_to {
      filtered.push(event)
    }
  }
  filtered
}

fn parse_time_value(name : String, value : String) -> Result[Int, ApiResponse] {
  match parse_int(value) {
    Some(v) => Ok(v)
    None => Err(response_json(400, error_envelope_json(invalid_query_reason(name + " must be integer"))))
  }
}

fn parse_limit(value : String) -> Result[Int, ApiResponse] {
  match parse_int(value) {
    Some(v) => {
      if v <= 0 {
        Err(response_json(400, error_envelope_json(invalid_query_reason("limit must be positive"))))
      } else if v > 1000 {
        Err(response_json(400, error_envelope_json(invalid_query_reason("limit must be <= 1000"))))
      } else {
        Ok(v)
      }
    }
    None => Err(response_json(400, error_envelope_json(invalid_query_reason("limit must be integer"))))
  }
}

///|
fn handle_metrics_export_jsonl(req : ApiRequest) -> ApiResponse {
  let entity = match req.query.get("entityId") {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_query_reason("entityId")))
  }
  let from_time = match req.query.get("fromLogicalTime") {
    Some(value) => match parse_time_value("fromLogicalTime", value) {
      Ok(v) => Some(v)
      Err(res) => return res
    }
    None => None
  }
  let to_time = match req.query.get("toLogicalTime") {
    Some(value) => match parse_time_value("toLogicalTime", value) {
      Ok(v) => Some(v)
      Err(res) => return res
    }
    None => None
  }
  let snapshot = @metrics_snapshot_v4_5.build_snapshot(entity, from_time, to_time)
  response_jsonl(200, @metrics_export_v4_5.export_jsonl(snapshot))
}

///|
fn handle_metrics_export_csv(req : ApiRequest) -> ApiResponse {
  let entity = match req.query.get("entityId") {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_query_reason("entityId")))
  }
  let from_time = match req.query.get("fromLogicalTime") {
    Some(value) => match parse_time_value("fromLogicalTime", value) {
      Ok(v) => Some(v)
      Err(res) => return res
    }
    None => None
  }
  let to_time = match req.query.get("toLogicalTime") {
    Some(value) => match parse_time_value("toLogicalTime", value) {
      Ok(v) => Some(v)
      Err(res) => return res
    }
    None => None
  }
  let snapshot = @metrics_snapshot_v4_5.build_snapshot(entity, from_time, to_time)
  response_csv(200, @metrics_export_v4_5.export_csv(snapshot))
}

///|
fn handle_timeline_export(req : ApiRequest) -> ApiResponse {
  let entity = match req.query.get("entityId") {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_query_reason("entityId")))
  }
  let from_time = match req.query.get("fromLogicalTime") {
    Some(value) => match parse_time_value("fromLogicalTime", value) {
      Ok(v) => Some(v)
      Err(res) => return res
    }
    None => None
  }
  let to_time = match req.query.get("toLogicalTime") {
    Some(value) => match parse_time_value("toLogicalTime", value) {
      Ok(v) => Some(v)
      Err(res) => return res
    }
    None => None
  }
  let limit = match req.query.get("limit") {
    Some(value) => match parse_limit(value) {
      Ok(v) => v
      Err(res) => return res
    }
    None => 100
  }
  let cursor_offset = match req.query.get("cursor") {
    Some(value) => match @timeline_event_v3_8.decode_cursor(value) {
      Some(v) => v
      None => return response_json(400, error_envelope_json(invalid_query_reason("invalid cursor")))
    }
    None => 0
  }
  let events = @timeline_source_v4_5.events_for_entity(entity)
  let filtered = apply_time_filter(events, from_time, to_time)
  let page : Array[@timeline_v3.TimelineEvent] = []
  let mut idx = 0
  for event in filtered {
    if idx >= cursor_offset && page.length() < limit {
      page.push(event)
    }
    idx = idx + 1
  }
  let next_cursor = if cursor_offset + limit < filtered.length() {
    Some(@timeline_event_v3_8.encode_cursor(@timeline_event_v3_8.cursor_from_query({
      entity_id: entity,
      kind: None,
      from_logical_time: from_time,
      to_logical_time: to_time,
      limit,
      cursor: None,
    }, cursor_offset + limit)))
  } else {
    None
  }
  response_jsonl_with_cursor(200, @timeline_export_v4_5.export_jsonl(page), next_cursor)
}

///|
pub fn handle_request(req : ApiRequest) -> ApiResponse {
  if req.http_method == "GET" && req.path == "/v4.5/metrics/export.jsonl" {
    return handle_metrics_export_jsonl(req)
  }
  if req.http_method == "GET" && req.path == "/v4.5/metrics/export.csv" {
    return handle_metrics_export_csv(req)
  }
  if req.http_method == "GET" && req.path == "/v4.5/timeline/export.jsonl" {
    return handle_timeline_export(req)
  }
  response_json(
    404,
    error_envelope_json(@core.Reason::with_context(
      "ROUTE_NOT_FOUND",
      "route not found",
      [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Use /v4.5/metrics/export.jsonl"),
      ],
    )),
  )
}
