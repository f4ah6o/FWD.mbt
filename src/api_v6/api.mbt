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
fn error_envelope_json(reason : @core.Reason) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["error"] = @compiler.reason_json(reason)
  Json::object(obj).stringify(indent=2)
}

///|
fn invalid_query_reason(message : String) -> @core.Reason {
  @core.Reason::with_context("QUERY_INVALID", message, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Use format=html or format=mx"),
  ])
}

///|
fn invalid_case_reason(case_id : String) -> @core.Reason {
  @core.Reason::with_context(
    "CASE_INVALID",
    "unsupported workbench case: " + case_id,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Use case=purchase-request"),
    ],
  )
}

///|
fn missing_body_reason() -> @core.Reason {
  @core.Reason::with_context("INPUT_MISSING", "missing form body", [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Submit the workbench builder form"),
  ])
}

///|
fn route_not_found_reason() -> @core.Reason {
  @core.Reason::with_context("ROUTE_NOT_FOUND", "route not found", [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Use /v6/workbench or /v6/workbench/preview"),
  ])
}

///|
fn parse_format(query : Map[String, String]) -> Result[Bool, @core.Reason] {
  match query.get("format") {
    None => Ok(false)
    Some("html") => Ok(false)
    Some("mx") => Ok(true)
    Some(value) => Err(invalid_query_reason("unsupported format: " + value))
  }
}

///|
fn parse_builder_case(
  query : Map[String, String],
) -> Result[@wb.BuilderState, @core.Reason] {
  match query.get("case") {
    None => Ok(@wb.default_builder())
    Some(case_id) =>
      match @wb.builder_for_case(case_id) {
        Some(builder) => Ok(builder)
        None => Err(invalid_case_reason(case_id))
      }
  }
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
fn substring_range(value : String, start : Int, end : Int) -> String {
  let sb = StringBuilder::new()
  let limit = if end < value.length() { end } else { value.length() }
  for i in start..<limit {
    let ch = value[i].to_int()
    sb.write_char(Int::unsafe_to_char(ch))
  }
  sb.to_string()
}

///|
fn find_char(value : String, target : Int) -> Int {
  for i in 0..<value.length() {
    if value[i].to_int() == target {
      return i
    }
  }
  -1
}

///|
fn hex_value(ch : Int) -> Int? {
  if ch >= '0'.to_int() && ch <= '9'.to_int() {
    Some(ch - '0'.to_int())
  } else if ch >= 'A'.to_int() && ch <= 'F'.to_int() {
    Some(ch - 'A'.to_int() + 10)
  } else if ch >= 'a'.to_int() && ch <= 'f'.to_int() {
    Some(ch - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn url_decode(value : String) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < value.length() {
    let ch = value[i].to_int()
    if ch == '+'.to_int() {
      sb.write_char(Int::unsafe_to_char(' '.to_int()))
      i = i + 1
      continue
    }
    if ch == '%'.to_int() && i + 2 < value.length() {
      let hi = hex_value(value[i + 1].to_int())
      let lo = hex_value(value[i + 2].to_int())
      match (hi, lo) {
        (Some(h), Some(l)) => {
          sb.write_char(Int::unsafe_to_char(h * 16 + l))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    sb.write_char(Int::unsafe_to_char(ch))
    i = i + 1
  }
  sb.to_string()
}

///|
fn parse_form_body(body : String) -> Map[String, String] {
  let fields : Map[String, String] = Map::new()
  if body.length() == 0 {
    return fields
  }
  for raw_view in body.split("&") {
    let raw_pair = raw_view.to_string()
    if raw_pair.length() == 0 {
      continue
    }
    let eq = find_char(raw_pair, '='.to_int())
    if eq < 0 {
      fields[url_decode(raw_pair)] = ""
      continue
    }
    let key = url_decode(substring_range(raw_pair, 0, eq))
    let value = url_decode(substring_from(raw_pair, eq + 1))
    fields[key] = value
  }
  fields
}

///|
fn field_or_empty(fields : Map[String, String], name : String) -> String {
  match fields.get(name) {
    Some(value) => value
    None => ""
  }
}

///|
fn decimal_value(ch : Int) -> Int? {
  if ch >= '0'.to_int() && ch <= '9'.to_int() {
    Some(ch - '0'.to_int())
  } else {
    None
  }
}

///|
fn parse_nonzero_int(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut result = 0
  for i in 0..<value.length() {
    let digit = match decimal_value(value[i].to_int()) {
      Some(value) => value
      None => return None
    }
    result = result * 10 + digit
  }
  if result > 0 {
    Some(result)
  } else {
    None
  }
}

///|
fn slot_count(fields : Map[String, String], field_name : String) -> Int {
  match fields.get(field_name) {
    Some(value) =>
      match parse_nonzero_int(value) {
        Some(count) => count
        None => 3
      }
    None => 3
  }
}

///|
fn builder_from_fields(fields : Map[String, String]) -> @wb.BuilderState {
  let states : Array[String] = []
  for i in 0..<slot_count(fields, "state_slots") {
    states.push(field_or_empty(fields, "state_" + i.to_string()))
  }
  let transitions : Array[@wb.BuilderTransition] = []
  for i in 0..<slot_count(fields, "transition_slots") {
    transitions.push({
      name: field_or_empty(fields, "transition_" + i.to_string() + "_name"),
      from: field_or_empty(fields, "transition_" + i.to_string() + "_from"),
      to: field_or_empty(fields, "transition_" + i.to_string() + "_to"),
    })
  }
  {
    entity_name: field_or_empty(fields, "entity_name"),
    initial_state: field_or_empty(fields, "initial_state"),
    states,
    transitions,
  }
}

///|
fn render_workbench(
  builder : @wb.BuilderState,
  enable_mx : Bool,
) -> ApiResponse {
  let model = @wb.evaluate_builder(builder)
  if enable_mx {
    return response_html(200, @workbench_view.render_workbench_html_mx(model))
  }
  response_html(200, @workbench_view.render_workbench_html(model))
}

///|
pub fn handle_request(req : ApiRequest) -> ApiResponse {
  if req.http_method == "GET" && req.path == "/v6/workbench" {
    let enable_mx = match parse_format(req.query) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    let builder = match parse_builder_case(req.query) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    return render_workbench(builder, enable_mx)
  }
  if req.http_method == "POST" && req.path == "/v6/workbench/preview" {
    let enable_mx = match parse_format(req.query) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    let body = match req.body {
      Some(value) => value
      None =>
        return response_json(400, error_envelope_json(missing_body_reason()))
    }
    let fields = parse_form_body(body)
    return render_workbench(builder_from_fields(fields), enable_mx)
  }
  response_json(404, error_envelope_json(route_not_found_reason()))
}
