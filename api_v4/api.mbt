///|
/// HTTP adapter v4 (pure request/response routing).

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

fn parse_format(value : String) -> String? {
  if value == "json" || value == "html" || value == "mx" {
    Some(value)
  } else {
    None
  }
}

fn resource_view() -> @views.V4ResourceView {
  {
    entity: { id: "order-1", state: "Draft", logical_time: 12 },
    draft_reason: "Need approval",
    field_errors: [
      {
        path: "/reason",
        reason: { message: "reason is required", hint: Some("Provide a non-empty reason") },
      },
    ],
    policy: {
      decision: "deny",
      reasons: [{ message: "Policy denied execution", hint: None }],
    },
    effects: {
      plan_status: "planned",
      execution_status: "skipped",
      reasons: [{ message: "Rule not satisfied", hint: Some("Provide rule result true for this transition") }],
    },
    timeline: {
      cursor: "offset:0",
      events: [
        {
          event_id: "order-1:11:1:policy",
          kind: "policy",
          ref_id: "policy:submit",
          status: "deny",
          reasons: [{ message: "Policy denied execution", hint: None }],
        },
      ],
    },
  }
}

fn resource_json() -> String {
  let obj : Map[String, Json] = Map::new()
  obj["resourceVersion"] = Json::string("4.0")
  let entity : Map[String, Json] = Map::new()
  entity["id"] = Json::string("order-1")
  entity["state"] = Json::string("Draft")
  entity["logicalTime"] = Json::number(12)
  obj["entity"] = Json::object(entity)
  let input : Map[String, Json] = Map::new()
  let schema : Map[String, Json] = Map::new()
  schema["type"] = Json::string("object")
  let props : Map[String, Json] = Map::new()
  props["reason"] = Json::object({ "type": Json::string("string") })
  schema["properties"] = Json::object(props)
  schema["required"] = Json::array([Json::string("reason")])
  input["schema"] = Json::object(schema)
  input["draft"] = Json::object({ "reason": Json::string("Need approval") })
  let field_errors : Array[Json] = []
  let fe : Map[String, Json] = Map::new()
  fe["path"] = Json::string("/reason")
  fe["reason"] = Json::object({
    "reasonVersion": Json::number(1),
    "code": Json::string("INPUT_REQUIRED"),
    "level": Json::string("error"),
    "target": Json::string("runtime"),
    "message": Json::string("reason is required"),
    "hint": Json::string("Provide a non-empty reason"),
  })
  field_errors.push(Json::object(fe))
  input["fieldErrors"] = Json::array(field_errors)
  obj["input"] = Json::object(input)
  let policy : Map[String, Json] = Map::new()
  policy["decision"] = Json::string("deny")
  policy["reasons"] = Json::array([
    Json::object({
      "reasonVersion": Json::number(1),
      "code": Json::string("POLICY_DENY"),
      "level": Json::string("error"),
      "target": Json::string("transition"),
      "message": Json::string("Policy denied execution"),
    }),
  ])
  obj["policy"] = Json::object(policy)
  let effects : Map[String, Json] = Map::new()
  let plan : Map[String, Json] = Map::new()
  plan["planVersion"] = Json::string("2.2")
  plan["entityId"] = Json::string("order-1")
  plan["transitionId"] = Json::string("submit")
  plan["status"] = Json::string("planned")
  plan["items"] = Json::array([
    Json::object({
      "effectId": Json::string("notify"),
      "kind": Json::string("async"),
      "payload": Json::object(Map::new()),
      "idempotencyKey": Json::string("order-1:submit:notify"),
    }),
  ])
  plan["reasons"] = Json::array([])
  effects["planPreview"] = Json::object(plan)
  let execution : Map[String, Json] = Map::new()
  execution["status"] = Json::string("skipped")
  execution["reasons"] = Json::array([
    Json::object({
      "reasonVersion": Json::number(1),
      "code": Json::string("RULE_NOT_SATISFIED"),
      "level": Json::string("info"),
      "target": Json::string("rule"),
      "message": Json::string("Rule not satisfied"),
      "hint": Json::string("Provide rule result true for this transition"),
    }),
  ])
  effects["execution"] = Json::object(execution)
  obj["effects"] = Json::object(effects)
  let timeline : Map[String, Json] = Map::new()
  timeline["cursor"] = Json::string("offset:0")
  timeline["events"] = Json::array([
    Json::object({
      "eventId": Json::string("order-1:11:1:policy"),
      "entityId": Json::string("order-1"),
      "logicalTime": Json::number(11),
      "sequence": Json::number(1),
      "kind": Json::string("policy"),
      "refId": Json::string("policy:submit"),
      "status": Json::string("deny"),
      "reasons": Json::array([
        Json::object({
          "reasonVersion": Json::number(1),
          "code": Json::string("POLICY_DENY"),
          "level": Json::string("error"),
          "target": Json::string("transition"),
          "message": Json::string("Policy denied execution"),
        }),
      ]),
    }),
  ])
  obj["timeline"] = Json::object(timeline)
  Json::object(obj).stringify(indent=2)
}

fn timeline_list_view() -> @views.V4TimelineListView {
  {
    cursor: "offset:0",
    next_cursor: Some("offset:2"),
    events: [
      {
        event_id: "order-1:10:1:transition",
        kind: "transition",
        ref_id: "submit",
        status: "executed",
        reasons: [],
      },
      {
        event_id: "order-1:11:1:policy",
        kind: "policy",
        ref_id: "policy:submit",
        status: "deny",
        reasons: ["Policy denied execution"],
      },
    ],
  }
}

fn timeline_list_json() -> String {
  let obj : Map[String, Json] = Map::new()
  obj["timelineVersion"] = Json::string("4.0")
  let query : Map[String, Json] = Map::new()
  query["entityId"] = Json::string("order-1")
  query["fromLogicalTime"] = Json::number(10)
  query["toLogicalTime"] = Json::number(12)
  query["limit"] = Json::number(2)
  query["cursor"] = Json::string("offset:0")
  obj["query"] = Json::object(query)
  obj["events"] = Json::array([
    Json::object({
      "eventId": Json::string("order-1:10:1:transition"),
      "entityId": Json::string("order-1"),
      "logicalTime": Json::number(10),
      "sequence": Json::number(1),
      "kind": Json::string("transition"),
      "refId": Json::string("submit"),
      "status": Json::string("executed"),
      "reasons": Json::array([]),
    }),
    Json::object({
      "eventId": Json::string("order-1:11:1:policy"),
      "entityId": Json::string("order-1"),
      "logicalTime": Json::number(11),
      "sequence": Json::number(1),
      "kind": Json::string("policy"),
      "refId": Json::string("policy:submit"),
      "status": Json::string("deny"),
      "reasons": Json::array([
        Json::object({
          "reasonVersion": Json::number(1),
          "code": Json::string("POLICY_DENY"),
          "level": Json::string("error"),
          "target": Json::string("transition"),
          "message": Json::string("Policy denied execution"),
        }),
      ]),
    }),
  ])
  obj["nextCursor"] = Json::string("offset:2")
  Json::object(obj).stringify(indent=2)
}

fn timeline_detail_view() -> @views.V4TimelineDetailView {
  {
    event_id: "order-1:11:1:policy",
    kind: "policy",
    ref_id: "policy:submit",
    status: "deny",
    reasons: ["Policy denied execution"],
    prev_event_id: Some("order-1:10:1:transition"),
    next_event_id: Some("order-1:12:1:effect"),
  }
}

fn timeline_detail_json() -> String {
  let obj : Map[String, Json] = Map::new()
  obj["timelineVersion"] = Json::string("4.0")
  obj["event"] = Json::object({
    "eventId": Json::string("order-1:11:1:policy"),
    "entityId": Json::string("order-1"),
    "logicalTime": Json::number(11),
    "sequence": Json::number(1),
    "kind": Json::string("policy"),
    "refId": Json::string("policy:submit"),
    "status": Json::string("deny"),
    "reasons": Json::array([
      Json::object({
        "reasonVersion": Json::number(1),
        "code": Json::string("POLICY_DENY"),
        "level": Json::string("error"),
        "target": Json::string("transition"),
        "message": Json::string("Policy denied execution"),
      }),
    ]),
  })
  obj["prevEventId"] = Json::string("order-1:10:1:transition")
  obj["nextEventId"] = Json::string("order-1:12:1:effect")
  Json::object(obj).stringify(indent=2)
}

fn substring_from(value : String, start : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<value.length() {
    let ch = value[i].to_int()
    sb.write_char(Int::unsafe_to_char(ch))
  }
  sb.to_string()
}

///|
fn handle_resource(req : ApiRequest) -> ApiResponse {
  let _entity = match req.query.get("entityId") {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_query_reason("entityId")))
  }
  let format = match req.query.get("format") {
    None => "json"
    Some(value) => match parse_format(value) {
      Some(kind) => kind
      None => return response_json(400, error_envelope_json(invalid_query_reason("invalid format")))
    }
  }
  if format == "json" {
    return response_json(200, resource_json())
  }
  if format == "mx" {
    return response_html(200, @views.render_resource_html_v4_mx(resource_view()))
  }
  response_html(200, @views.render_resource_html_v4(resource_view()))
}

///|
fn handle_timeline(req : ApiRequest) -> ApiResponse {
  let _entity = match req.query.get("entityId") {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_query_reason("entityId")))
  }
  match req.query.get("cursor") {
    Some(value) => if value != "offset:0" { return response_json(400, error_envelope_json(invalid_query_reason("invalid cursor"))) }
    None => ()
  }
  let format = match req.query.get("format") {
    None => "json"
    Some(value) => match parse_format(value) {
      Some(kind) => kind
      None => return response_json(400, error_envelope_json(invalid_query_reason("invalid format")))
    }
  }
  if format == "json" {
    return response_json(200, timeline_list_json())
  }
  if format == "mx" {
    return response_html(200, @views.render_timeline_list_html_v4_mx(timeline_list_view()))
  }
  response_html(200, @views.render_timeline_list_html_v4(timeline_list_view()))
}

///|
fn handle_timeline_event(req : ApiRequest, event_id : String) -> ApiResponse {
  if @timeline_event_v3_4.parse_event_id(event_id) is None {
    return response_json(400, error_envelope_json(invalid_event_id_reason("invalid event id")))
  }
  let format = match req.query.get("format") {
    None => "json"
    Some(value) => match parse_format(value) {
      Some(kind) => kind
      None => return response_json(400, error_envelope_json(invalid_query_reason("invalid format")))
    }
  }
  if event_id != "order-1:11:1:policy" {
    return response_json(404, error_envelope_json(@core.Reason::with_context(
      "EVENT_NOT_FOUND",
      "event not found: " + event_id,
      [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Provide a valid event id"),
      ],
    )))
  }
  if format == "json" {
    return response_json(200, timeline_detail_json())
  }
  if format == "mx" {
    return response_html(200, @views.render_timeline_detail_html_v4_mx(timeline_detail_view()))
  }
  response_html(200, @views.render_timeline_detail_html_v4(timeline_detail_view()))
}

///|
pub fn handle_request(req : ApiRequest) -> ApiResponse {
  if req.http_method == "GET" && req.path == "/v4/resource" {
    return handle_resource(req)
  }
  if req.http_method == "GET" && req.path == "/v4/timeline" {
    return handle_timeline(req)
  }
  let prefix = "/v4/timeline/event/"
  if req.http_method == "GET" && req.path.has_prefix(prefix) {
    let event_id = substring_from(req.path, prefix.length())
    if event_id.length() == 0 {
      return response_json(400, error_envelope_json(invalid_event_id_reason("missing event id")))
    }
    return handle_timeline_event(req, event_id)
  }
  response_json(
    404,
    error_envelope_json(@core.Reason::with_context(
      "ROUTE_NOT_FOUND",
      "route not found",
      [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Use /v4/resource or /v4/timeline"),
      ],
    )),
  )
}
