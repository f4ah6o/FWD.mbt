///|
/// HTTP adapter v3 (pure request/response routing).

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
fn response_html(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "text/html"
  { status, headers, body }
}

///|
fn invalid_body_reason(message : String) -> @core.Reason {
  @core.Reason::with_context(
    "INPUT_JSON_INVALID",
    message,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Provide a JSON object body"),
    ],
  )
}

///|
fn missing_field_reason(name : String) -> @core.Reason {
  @core.Reason::with_context(
    "INPUT_MISSING",
    "missing field: " + name,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Provide field '" + name + "' in JSON body"),
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
fn error_envelope_json(reason : @core.Reason) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["error"] = @compiler.reason_json(reason)
  Json::object(obj).stringify(indent=2)
}

///|
fn reason_from_compile_error(err : @compiler.CompileError) -> @core.Reason {
  match err {
    @compiler.CompileError::ParseFailure(msg) =>
      @core.Reason::new("ParseFailure", msg)
    @compiler.CompileError::ResolveFailure(msg) =>
      if msg.has_prefix("rule name conflicts with builtin: ") {
        @core.Reason::with_context(
          "RESERVED_WORD_CONFLICT",
          msg,
          [
            ("target", "rule"),
            ("hint", "Builtin rule names are reserved"),
          ],
        )
      } else {
        @core.Reason::new("ResolveFailure", msg)
      }
    @compiler.CompileError::ValidationFailure(reason) => reason
  }
}

///|
fn extract_body_json(body : String) -> Result[Map[String, Json], @core.Reason] {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(body)
  let value = match parsed {
    Ok(v) => v
    Err(err) =>
      return Err(
        invalid_body_reason("input json parse error: " + err.to_string()),
      )
  }
  match value {
    Object(m) => Ok(m)
    _ => Err(invalid_body_reason("input json must be an object"))
  }
}

///|
fn extract_string_field(
  obj : Map[String, Json],
  name : String,
) -> Result[String, @core.Reason] {
  match obj.get(name) {
    Some(String(value)) => Ok(value)
    Some(_) => Err(invalid_body_reason("field must be string: " + name))
    None => Err(missing_field_reason(name))
  }
}

///|
fn extract_int_field(
  obj : Map[String, Json],
  name : String,
) -> Result[Int, @core.Reason] {
  match obj.get(name) {
    Some(Number(value, ..)) => Ok(value.to_int())
    Some(_) => Err(invalid_body_reason("field must be number: " + name))
    None => Err(missing_field_reason(name))
  }
}

///|
fn extract_input_field(obj : Map[String, Json]) -> Result[Map[String, Bool], @core.Reason] {
  match obj.get("input") {
    None => Ok(Map::new())
    Some(value) => @hypermedia.parse_rule_results(value.stringify())
  }
}

///|
fn render_resource_v3(
  resource : @hypermedia.ResourceV3,
  format : String,
) -> ApiResponse {
  if format == "v3-html" || format == "html" {
    return response_html(200, @views.render_resource_html_v3(resource))
  }
  if format == "v3-mx" || format == "mx" {
    return response_html(200, @views.render_resource_html_v3_mx(resource))
  }
  response_json(200, @hypermedia.resource_v3_json(resource).stringify(indent=2))
}

///|
fn handle_resource(schema_text : String, req : ApiRequest) -> ApiResponse {
  let state = match req.query.get("state") {
    Some(value) => value
    None =>
      return response_json(
        400,
        error_envelope_json(missing_query_reason("state")),
      )
  }
  let ir = match @compiler.compile_yaml(schema_text) {
    Ok(value) => value
    Err(err) =>
      return response_json(
        400,
        error_envelope_json(reason_from_compile_error(err)),
      )
  }
  let format = match req.query.get("format") {
    Some(value) => value
    None => "v3-json"
  }
  let resource = @hypermedia.resource_v3_from_ir(ir, state)
  render_resource_v3(resource, format)
}

///|
fn handle_effects(schema_text : String, req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_field_reason("body")))
  }
  let obj = match extract_body_json(body) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let entity = match extract_string_field(obj, "entity") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let state = match extract_string_field(obj, "state") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let transition = match extract_string_field(obj, "transition") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let input = match extract_input_field(obj) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let ir = match @compiler.compile_yaml(schema_text) {
    Ok(value) => value
    Err(err) =>
      return response_json(
        400,
        error_envelope_json(reason_from_compile_error(err)),
      )
  }
  let outcome = match @runtime.execute_transition(ir, state, transition, input) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let plan = @effects_v2_2.plan_from_execution(entity, outcome)
  response_json(200, @effects_v2_2.effect_plan_json(plan).stringify(indent=2))
}

///|
fn handle_execute(schema_text : String, req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(value) => value
    None => return response_json(400, error_envelope_json(missing_field_reason("body")))
  }
  let obj = match extract_body_json(body) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let entity = match extract_string_field(obj, "entity") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let state = match extract_string_field(obj, "state") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let transition = match extract_string_field(obj, "transition") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let logical_time = match extract_int_field(obj, "logicalTime") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let sequence = match extract_int_field(obj, "sequence") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let input = match extract_input_field(obj) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let ir = match @compiler.compile_yaml(schema_text) {
    Ok(value) => value
    Err(err) =>
      return response_json(
        400,
        error_envelope_json(reason_from_compile_error(err)),
      )
  }
  let outcome = match @runtime.execute_transition(ir, state, transition, input) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let event : @execution_audit_v3.AuditEvent = match outcome {
    @runtime.ExecutionOutcome::Executed(value) => {
      let items : Array[@execution_audit_v3.AuditItem] = []
      for eff in value.effects {
        items.push({
          effect_id: eff.name,
          status: @execution_audit_v3.ItemStatus::Executed,
          duration_ms: 0,
          reason: None,
        })
      }
      let reasons : Array[@core.Reason] = []
      {
        entity_id: entity,
        transition_id: value.id,
        logical_time,
        sequence,
        status: @execution_audit_v3.AuditStatus::Executed,
        items,
        reasons,
      }
    }
    @runtime.ExecutionOutcome::Blocked(value) => {
      let items : Array[@execution_audit_v3.AuditItem] = []
      {
        entity_id: entity,
        transition_id: value.id,
        logical_time,
        sequence,
        status: @execution_audit_v3.AuditStatus::Blocked,
        items,
        reasons: value.reasons,
      }
    }
  }
  response_json(200, @execution_audit_v3.audit_event_json(event).stringify(indent=2))
}

///|
fn handle_timeline(req : ApiRequest) -> ApiResponse {
  let entity = match req.query.get("entity") {
    Some(value) => value
    None =>
      return response_json(
        400,
        error_envelope_json(missing_query_reason("entity")),
      )
  }
  let events : Array[@timeline_v3.TimelineEvent] = [
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
  ]
  response_json(200, @timeline_v3.timeline_json(events).stringify(indent=2))
}

///|
pub fn handle_request(schema_text : String, req : ApiRequest) -> ApiResponse {
  if req.http_method == "GET" && req.path == "/v3/resource" {
    return handle_resource(schema_text, req)
  }
  if req.http_method == "POST" && req.path == "/v3/effects" {
    return handle_effects(schema_text, req)
  }
  if req.http_method == "POST" && req.path == "/v3/execute" {
    return handle_execute(schema_text, req)
  }
  if req.http_method == "GET" && req.path == "/v3/timeline" {
    return handle_timeline(req)
  }
  response_json(
    404,
    error_envelope_json(@core.Reason::with_context(
      "ROUTE_NOT_FOUND",
      "route not found",
      [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Use /v3/*"),
      ],
    )),
  )
}
