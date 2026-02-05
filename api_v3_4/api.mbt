///|
/// HTTP adapter v3.4 (pure request/response routing).

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
fn response_html(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "text/html"
  { status, headers, body }
}

///|
fn response_json(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "application/json"
  { status, headers, body }
}

///|
fn error_envelope_json(reason : @core.Reason) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["error"] = @compiler.reason_json(reason)
  Json::object(obj).stringify(indent=2)
}

///|
fn invalid_event_id_reason(message : String) -> @core.Reason {
  @core.Reason::with_context(
    "EVENT_ID_INVALID",
    message,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Use event id in the form entity:logical:sequence:kind"),
    ],
  )
}

///|
fn event_not_found_reason(event_id : String) -> @core.Reason {
  @core.Reason::with_context(
    "EVENT_NOT_FOUND",
    "event not found: " + event_id,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Provide a valid event id"),
    ],
  )
}

fn parse_format(value : String) -> String? {
  if value == "json" || value == "html" {
    Some(value)
  } else {
    None
  }
}

fn substring_from(value : String, start : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<value.length() {
    let ch = value[i].to_int()
    sb.write_char(Int::unsafe_to_char(ch))
  }
  sb.to_string()
}

fn events_for_entity(entity : String) -> Array[@timeline_v3.TimelineEvent] {
  [
    {
      entity_id: entity,
      logical_time: 10,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Transition,
      ref_id: "submit",
      status: "executed",
      reasons: [],
    },
    {
      entity_id: entity,
      logical_time: 11,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Policy,
      ref_id: "policy:submit",
      status: "deny",
      reasons: [
        @core.Reason::with_context(
          "POLICY_DENY",
          "Policy denied execution",
          [("target", "transition")],
        ),
      ],
    },
    {
      entity_id: entity,
      logical_time: 12,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Effect,
      ref_id: "http:archive",
      status: "failed",
      reasons: [
        @core.Reason::with_context(
          "EFFECT_HTTP_FAILED",
          "HTTP request failed",
          [("target", "effect")],
        ),
      ],
    },
  ]
}

fn find_event_by_id(event_id : String) -> @timeline_v3.TimelineEvent? {
  let parts = @timeline_event_v3_4.parse_event_id(event_id)
  match parts {
    None => None
    Some(info) => {
      let events = events_for_entity(info.entity_id)
      for event in events {
        if @timeline_event_v3_4.event_id(event) == event_id {
          return Some(event)
        }
      }
      None
    }
  }
}

///|
fn handle_event(req : ApiRequest, event_id : String) -> ApiResponse {
  let format = match req.query.get("format") {
    None => "html"
    Some(value) => match parse_format(value) {
      Some(kind) => kind
      None => return response_json(400, error_envelope_json(invalid_event_id_reason("invalid format")))
    }
  }
  let event = match find_event_by_id(event_id) {
    Some(value) => value
    None => {
      if @timeline_event_v3_4.parse_event_id(event_id) is None {
        return response_json(400, error_envelope_json(invalid_event_id_reason("invalid event id")))
      }
      return response_json(404, error_envelope_json(event_not_found_reason(event_id)))
    }
  }
  let detail = @timeline_event_v3_4.detail_from_event(event)
  if format == "json" {
    return response_json(200, @timeline_event_v3_4.detail_json(detail).stringify(indent=2))
  }
  response_html(200, @views.render_timeline_event_html_v3_4(detail))
}

///|
pub fn handle_request(req : ApiRequest) -> ApiResponse {
  let prefix = "/v3.4/timeline/event/"
  if req.http_method == "GET" && req.path.has_prefix(prefix) {
    let event_id = substring_from(req.path, prefix.length())
    if event_id.length() == 0 {
      return response_json(400, error_envelope_json(invalid_event_id_reason("missing event id")))
    }
    return handle_event(req, event_id)
  }
  response_json(
    404,
    error_envelope_json(@core.Reason::with_context(
      "ROUTE_NOT_FOUND",
      "route not found",
      [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Use /v3.4/timeline/event/:id"),
      ],
    )),
  )
}
