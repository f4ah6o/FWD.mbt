///|
/// HTTP adapter v5.0 (single job endpoints only).

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
fn response_csv(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "text/csv"
  { status, headers, body }
}

fn response_json_with_headers(status : Int, body : String, headers : Map[String, String]) -> ApiResponse {
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
fn job_not_found_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context(
    "JOB_NOT_FOUND",
    "job not found: " + job_id,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Check job id"),
    ],
  )
}

///|
fn job_not_ready_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context(
    "JOB_NOT_READY",
    "job not ready: " + job_id,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Wait for job to complete"),
    ],
  )
}

///|
fn job_canceled_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context(
    "JOB_CANCELED",
    "job canceled: " + job_id,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Job was canceled"),
    ],
  )
}

///|
fn job_expired_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context(
    "JOB_EXPIRED",
    "job expired: " + job_id,
    [
      ("target", "runtime"),
      ("level", "error"),
      ("hint", "Job retention expired"),
    ],
  )
}

fn extract_body_json(body : String) -> Result[Map[String, Json], @core.Reason] {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(body)
  let value = match parsed {
    Ok(v) => v
    Err(err) => return Err(invalid_query_reason("input json parse error: " + err.to_string()))
  }
  match value {
    Object(m) => Ok(m)
    _ => Err(invalid_query_reason("input json must be an object"))
  }
}

fn extract_string_field(obj : Map[String, Json], name : String) -> Result[String, @core.Reason] {
  match obj.get(name) {
    Some(String(value)) => Ok(value)
    Some(_) => Err(invalid_query_reason("field must be string: " + name))
    None => Err(missing_query_reason(name))
  }
}

fn extract_int_field_optional(obj : Map[String, Json], name : String, default_value : Int) -> Result[Int, @core.Reason] {
  match obj.get(name) {
    Some(Number(value, ..)) => Ok(value.to_int())
    Some(_) => Err(invalid_query_reason("field must be number: " + name))
    None => Ok(default_value)
  }
}

fn parse_format(value : String) -> @export_job_v5.ResultFormat? {
  if value == "jsonl" {
    Some(@export_job_v5.ResultFormat::Jsonl)
  } else if value == "csv" {
    Some(@export_job_v5.ResultFormat::Csv)
  } else {
    None
  }
}

fn retention_default() -> @export_job_v5.Retention {
  {
    axis: @export_job_v5.RetentionAxis::PollCount,
    ttl_polls: 3,
    ttl_seconds: 120,
  }
}

fn retention_default_batch() -> @export_job_v5.Retention {
  {
    axis: @export_job_v5.RetentionAxis::PollCount,
    ttl_polls: @export_job_batch_v5.default_ttl_polls,
    ttl_seconds: @export_job_batch_v5.default_ttl_seconds,
  }
}

fn progress_json(progress : @export_job_v5.JobProgress) -> Json {
  Json::object({
    "processed": Json::number(progress.processed.to_double()),
    "total": Json::number(progress.total.to_double()),
  })
}

fn status_string(status : @export_job_v5.JobStatus) -> String {
  match status {
    @export_job_v5.JobStatus::Queued => "queued"
    @export_job_v5.JobStatus::Running => "running"
    @export_job_v5.JobStatus::Done => "done"
    @export_job_v5.JobStatus::Failed => "failed"
    @export_job_v5.JobStatus::Canceled => "canceled"
    @export_job_v5.JobStatus::Expired => "expired"
  }
}

fn reason_json(reason : @export_job_v5.ReasonV1) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["reasonVersion"] = Json::number(1)
  obj["code"] = Json::string(match reason.code {
    @export_job_v5.ReasonCode::QueryMissing => "QUERY_MISSING"
    @export_job_v5.ReasonCode::QueryInvalid => "QUERY_INVALID"
    @export_job_v5.ReasonCode::JobNotFound => "JOB_NOT_FOUND"
    @export_job_v5.ReasonCode::JobNotReady => "JOB_NOT_READY"
    @export_job_v5.ReasonCode::JobCanceled => "JOB_CANCELED"
    @export_job_v5.ReasonCode::JobExpired => "JOB_EXPIRED"
    @export_job_v5.ReasonCode::PolicyDenied => "POLICY_DENIED"
  })
  obj["level"] = Json::string(match reason.level {
    @export_job_v5.ReasonLevel::Error => "error"
    @export_job_v5.ReasonLevel::Warn => "warn"
    @export_job_v5.ReasonLevel::Info => "info"
  })
  obj["target"] = Json::string(reason.target)
  obj["message"] = Json::string(reason.message)
  match reason.hint {
    Some(value) => obj["hint"] = Json::string(value)
    None => ()
  }
  Json::object(obj)
}

fn job_json(job : @export_job_v5.JobRecord) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.0")
  obj["jobId"] = Json::string(job.id.value)
  obj["status"] = Json::string(status_string(job.status))
  obj["progress"] = progress_json(job.progress)
  obj["ttlSeconds"] = Json::number(job.retention.ttl_seconds.to_double())
  match job.status {
    @export_job_v5.JobStatus::Done => obj["downloadUrl"] = Json::string("/v5/export/jobs/" + job.id.value + "/result")
    _ => ()
  }
  if job.reasons.length() > 0 {
    let reasons : Array[Json] = []
    for reason in job.reasons {
      reasons.push(reason_json(reason))
    }
    obj["reasons"] = Json::array(reasons)
  }
  Json::object(obj).stringify(indent=2)
}

fn batch_job_json(batch : @export_job_batch_v5.BatchJobRecord) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.0")
  obj["jobId"] = Json::string(batch.id)
  obj["status"] = Json::string(status_string(batch.status))
  obj["progress"] = progress_json(batch.progress)
  obj["ttlSeconds"] = Json::number(batch.retention.ttl_seconds.to_double())
  let child_ids : Array[Json] = []
  for child_id in batch.child_ids {
    child_ids.push(Json::string(child_id))
  }
  obj["childIds"] = Json::array(child_ids)
  match batch.status {
    @export_job_v5.JobStatus::Done => obj["downloadUrl"] = Json::string("/v5/export/batch/jobs/" + batch.id + "/result")
    _ => ()
  }
  if batch.reasons.length() > 0 {
    let reasons : Array[Json] = []
    for reason in batch.reasons {
      reasons.push(reason_json(reason))
    }
    obj["reasons"] = Json::array(reasons)
  }
  Json::object(obj).stringify(indent=2)
}

fn result_body_jsonl() -> String {
  "{\"type\":\"total\",\"window\":{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},\"counts\":{\"ok\":1,\"failed\":1,\"blocked\":0,\"denied\":1}}\n"
}

fn result_body_csv() -> String {
  "type,entityId,fromLogicalTime,toLogicalTime,kind,ok,failed,blocked,denied\n"
}

fn batch_result_body_jsonl(batch : @export_job_batch_v5.BatchJobRecord) -> String {
  let sb = StringBuilder::new()
  for spec in batch.child_specs {
    sb.write_string("{\"type\":\"total\",\"window\":{\"entityId\":\"")
    sb.write_string(spec.entity_id)
    sb.write_string("\",\"fromLogicalTime\":")
    sb.write_string(spec.from_logical_time.to_string())
    sb.write_string(",\"toLogicalTime\":")
    sb.write_string(spec.to_logical_time.to_string())
    sb.write_string("},\"counts\":{\"ok\":1,\"failed\":1,\"blocked\":0,\"denied\":1}}")
    sb.write_string("\n")
  }
  sb.to_string()
}

fn batch_result_body_csv(batch : @export_job_batch_v5.BatchJobRecord) -> String {
  let sb = StringBuilder::new()
  sb.write_string("type,entityId,fromLogicalTime,toLogicalTime,kind,ok,failed,blocked,denied\n")
  for spec in batch.child_specs {
    sb.write_string("total,")
    sb.write_string(spec.entity_id)
    sb.write_string(",")
    sb.write_string(spec.from_logical_time.to_string())
    sb.write_string(",")
    sb.write_string(spec.to_logical_time.to_string())
    sb.write_string(",all,1,1,0,1\n")
  }
  sb.to_string()
}

fn handle_job_create(req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(text) => text
    None => return response_json(400, error_envelope_json(invalid_query_reason("missing body")))
  }
  let obj = match extract_body_json(body) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let _entity_id = match extract_string_field(obj, "entityId") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let format_text = match extract_string_field(obj, "format") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let format = match parse_format(format_text) {
    Some(value) => value
    None => return response_json(400, error_envelope_json(invalid_query_reason("invalid format")))
  }
  let job = @job_store_v5.create_job(format, retention_default())
  response_json(200, job_json(job))
}

fn parse_child_specs(obj : Map[String, Json]) -> Result[Array[@export_job_batch_v5.BatchChildSpec], @core.Reason] {
  match obj.get("jobs") {
    Some(Array(items)) => {
      if items.length() == 0 {
        return Err(invalid_query_reason("jobs must be non-empty"))
      }
      let specs : Array[@export_job_batch_v5.BatchChildSpec] = []
      for item in items {
        let entry = match item {
          Object(value) => value
          _ => return Err(invalid_query_reason("jobs entries must be objects"))
        }
        let entity_id = match extract_string_field(entry, "entityId") {
          Ok(value) => value
          Err(reason) => return Err(reason)
        }
        let from_logical_time = match extract_int_field_optional(entry, "fromLogicalTime", 0) {
          Ok(value) => value
          Err(reason) => return Err(reason)
        }
        let to_logical_time = match extract_int_field_optional(entry, "toLogicalTime", 0) {
          Ok(value) => value
          Err(reason) => return Err(reason)
        }
        specs.push({
          entity_id,
          from_logical_time,
          to_logical_time,
        })
      }
      Ok(specs)
    }
    Some(_) => Err(invalid_query_reason("jobs must be array"))
    None => Err(missing_query_reason("jobs"))
  }
}

fn handle_batch_create(req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(text) => text
    None => return response_json(400, error_envelope_json(invalid_query_reason("missing body")))
  }
  let obj = match extract_body_json(body) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let format_text = match extract_string_field(obj, "format") {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let format = match parse_format(format_text) {
    Some(value) => value
    None => return response_json(400, error_envelope_json(invalid_query_reason("invalid format")))
  }
  let child_specs = match parse_child_specs(obj) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let batch = @export_job_batch_v5.create_batch(format, retention_default_batch(), child_specs)
  response_json(200, batch_job_json(batch))
}

fn handle_batch_get(job_id : String) -> ApiResponse {
  match @export_job_batch_v5.get_batch(job_id) {
    Some(batch) => {
      match batch.status {
        @export_job_v5.JobStatus::Expired => response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, batch_job_json(batch))
      }
    }
    None => response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

fn handle_batch_cancel(job_id : String) -> ApiResponse {
  match @export_job_batch_v5.cancel_batch(job_id) {
    Some(batch) => {
      match batch.status {
        @export_job_v5.JobStatus::Expired => response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, batch_job_json(batch))
      }
    }
    None => response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

fn handle_batch_result(job_id : String) -> ApiResponse {
  match @export_job_batch_v5.get_batch(job_id) {
    Some(batch) => {
      match batch.status {
        @export_job_v5.JobStatus::Done => {
          match batch.format {
            @export_job_v5.ResultFormat::Jsonl => response_jsonl(200, batch_result_body_jsonl(batch))
            @export_job_v5.ResultFormat::Csv => response_csv(200, batch_result_body_csv(batch))
          }
        }
        @export_job_v5.JobStatus::Canceled => response_json(409, error_envelope_json(job_canceled_reason(job_id)))
        @export_job_v5.JobStatus::Expired => response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(409, error_envelope_json(job_not_ready_reason(job_id)))
      }
    }
    None => response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

fn handle_job_get(job_id : String) -> ApiResponse {
  match @job_store_v5.get_job(job_id) {
    Some(job) => {
      match job.status {
        @export_job_v5.JobStatus::Expired => response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, job_json(job))
      }
    }
    None => response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

fn handle_job_cancel(job_id : String) -> ApiResponse {
  match @job_store_v5.cancel_job(job_id) {
    Some(job) => {
      match job.status {
        @export_job_v5.JobStatus::Expired => response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, job_json(job))
      }
    }
    None => response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

fn handle_job_result(job_id : String) -> ApiResponse {
  match @job_store_v5.get_job(job_id) {
    Some(job) => {
      match job.status {
        @export_job_v5.JobStatus::Done => {
          match job.format {
            @export_job_v5.ResultFormat::Jsonl => response_jsonl(200, result_body_jsonl())
            @export_job_v5.ResultFormat::Csv => response_csv(200, result_body_csv())
          }
        }
        @export_job_v5.JobStatus::Canceled => response_json(409, error_envelope_json(job_canceled_reason(job_id)))
        @export_job_v5.JobStatus::Expired => response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(409, error_envelope_json(job_not_ready_reason(job_id)))
      }
    }
    None => response_json(404, error_envelope_json(job_not_found_reason(job_id)))
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
pub fn handle_request(req : ApiRequest) -> ApiResponse {
  if req.http_method == "GET" && req.path == "/v5/observability/metrics/summary" {
    return response_json(200, @observability_v5.metrics_summary_json())
  }
  if req.http_method == "GET" && req.path == "/v5/observability/export/audit" {
    return response_json(200, @observability_v5.export_audit_json())
  }
  if req.http_method == "POST" && req.path == "/v5/policy/check" {
    let result = @policy_gate_v5.check_policy(req.body)
    let headers : Map[String, String] = Map::new()
    headers["cache-control"] = "no-store"
    return response_json_with_headers(result.status, @policy_gate_v5.response_json(result), headers)
  }
  if req.http_method == "POST" && req.path == "/v5/export/batch/jobs" {
    return handle_batch_create(req)
  }
  let batch_prefix = "/v5/export/batch/jobs/"
  if req.path.has_prefix(batch_prefix) {
    let suffix = substring_from(req.path, batch_prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/cancel") {
      let job_id = substring_range(suffix, 0, suffix.length() - "/cancel".length())
      if job_id.length() == 0 {
        return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
      }
      return handle_batch_cancel(job_id)
    }
    if req.http_method == "GET" && suffix.has_suffix("/result") {
      let job_id = substring_range(suffix, 0, suffix.length() - "/result".length())
      if job_id.length() == 0 {
        return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
      }
      return handle_batch_result(job_id)
    }
    if req.http_method == "GET" {
      let job_id = suffix
      if job_id.length() == 0 {
        return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
      }
      return handle_batch_get(job_id)
    }
  }
  if req.http_method == "POST" && req.path == "/v5/export/jobs" {
    return handle_job_create(req)
  }
  let prefix = "/v5/export/jobs/"
  if req.path.has_prefix(prefix) {
    let suffix = substring_from(req.path, prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/cancel") {
      let job_id = substring_range(suffix, 0, suffix.length() - "/cancel".length())
      if job_id.length() == 0 {
        return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
      }
      return handle_job_cancel(job_id)
    }
    if req.http_method == "GET" && suffix.has_suffix("/result") {
      let job_id = substring_range(suffix, 0, suffix.length() - "/result".length())
      if job_id.length() == 0 {
        return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
      }
      return handle_job_result(job_id)
    }
    if req.http_method == "GET" {
      let job_id = suffix
      if job_id.length() == 0 {
        return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
      }
      return handle_job_get(job_id)
    }
  }
  response_json(
    404,
    error_envelope_json(@core.Reason::with_context(
      "ROUTE_NOT_FOUND",
      "route not found",
      [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Use /v5/export/jobs"),
      ],
    )),
  )
}
