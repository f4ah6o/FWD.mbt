///|
/// v5.0 Policy gate (deterministic, Reason v1 only).

///|
pub(all) enum ReasonLevel {
  Error
  Warn
  Info
}

///|
pub(all) enum ReasonCode {
  QueryMissing
  QueryInvalid
  PolicyDenied
}

///|
pub(all) struct ReasonV1 {
  code : ReasonCode
  level : ReasonLevel
  target : String
  message : String
  hint : String?
}

///|
pub(all) struct PolicyCheckResult {
  status : Int
  reasons : Array[ReasonV1]
}

fn reason_json(reason : ReasonV1) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["reasonVersion"] = Json::number(1)
  obj["code"] = Json::string(match reason.code {
    QueryMissing => "QUERY_MISSING"
    QueryInvalid => "QUERY_INVALID"
    PolicyDenied => "POLICY_DENIED"
  })
  obj["level"] = Json::string(match reason.level {
    Error => "error"
    Warn => "warn"
    Info => "info"
  })
  obj["target"] = Json::string(reason.target)
  obj["message"] = Json::string(reason.message)
  match reason.hint {
    Some(value) => obj["hint"] = Json::string(value)
    None => ()
  }
  Json::object(obj)
}

///|
pub fn response_json(result : PolicyCheckResult) -> String {
  let reasons : Array[Json] = []
  for reason in result.reasons {
    reasons.push(reason_json(reason))
  }
  let obj : Map[String, Json] = Map::new()
  obj["reasons"] = Json::array(reasons)
  Json::object(obj).stringify(indent=2)
}

fn invalid_reason(message : String) -> ReasonV1 {
  {
    code: QueryInvalid,
    level: Error,
    target: "policy",
    message,
    hint: Some("Check policy request"),
  }
}

fn missing_reason(name : String) -> ReasonV1 {
  {
    code: QueryMissing,
    level: Error,
    target: "policy",
    message: "missing field: " + name,
    hint: Some("Provide field '" + name + "'"),
  }
}

fn denied_reason(action : String) -> ReasonV1 {
  {
    code: PolicyDenied,
    level: Error,
    target: "policy",
    message: "policy denied: action=" + action,
    hint: Some("Action not permitted"),
  }
}

fn extract_action(obj : Map[String, Json]) -> Result[String, ReasonV1] {
  match obj.get("action") {
    Some(String(value)) => Ok(value)
    Some(_) => Err(invalid_reason("field must be string: action"))
    None => Err(missing_reason("action"))
  }
}

///|
pub fn check_policy(body : String?) -> PolicyCheckResult {
  let text = match body {
    Some(value) => value
    None => return { status: 400, reasons: [invalid_reason("missing body")] }
  }
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(text)
  let value = match parsed {
    Ok(v) => v
    Err(err) => return { status: 400, reasons: [invalid_reason("input json parse error: " + err.to_string())] }
  }
  let obj = match value {
    Object(m) => m
    _ => return { status: 400, reasons: [invalid_reason("input json must be an object")] }
  }
  let action = match extract_action(obj) {
    Ok(value) => value
    Err(reason) => return { status: 400, reasons: [reason] }
  }
  if action == "export" {
    { status: 200, reasons: [] }
  } else {
    { status: 403, reasons: [denied_reason(action)] }
  }
}
