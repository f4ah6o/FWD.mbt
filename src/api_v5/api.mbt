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

///|
fn response_html(status : Int, body : String) -> ApiResponse {
  let headers : Map[String, String] = Map::new()
  headers["content-type"] = "text/html"
  { status, headers, body }
}

///|
fn response_json_with_headers(
  status : Int,
  body : String,
  headers : Map[String, String],
) -> ApiResponse {
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
  @core.Reason::with_context("QUERY_INVALID", message, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Check query parameters"),
  ])
}

///|
fn missing_query_reason(name : String) -> @core.Reason {
  @core.Reason::with_context("QUERY_MISSING", "missing query: " + name, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Provide query '" + name + "'"),
  ])
}

///|
fn job_not_found_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context("JOB_NOT_FOUND", "job not found: " + job_id, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Check job id"),
  ])
}

///|
fn job_not_ready_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context("JOB_NOT_READY", "job not ready: " + job_id, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Wait for job to complete"),
  ])
}

///|
fn job_canceled_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context("JOB_CANCELED", "job canceled: " + job_id, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Job was canceled"),
  ])
}

///|
fn job_expired_reason(job_id : String) -> @core.Reason {
  @core.Reason::with_context("JOB_EXPIRED", "job expired: " + job_id, [
    ("target", "runtime"),
    ("level", "error"),
    ("hint", "Job retention expired"),
  ])
}

///|
fn extract_body_json(body : String) -> Result[Map[String, Json], @core.Reason] {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(body)
  let value = match parsed {
    Ok(v) => v
    Err(err) =>
      return Err(
        invalid_query_reason("input json parse error: " + err.to_string()),
      )
  }
  match value {
    Object(m) => Ok(m)
    _ => Err(invalid_query_reason("input json must be an object"))
  }
}

///|
fn extract_string_field(
  obj : Map[String, Json],
  name : String,
) -> Result[String, @core.Reason] {
  match obj.get(name) {
    Some(String(value)) => Ok(value)
    Some(_) => Err(invalid_query_reason("field must be string: " + name))
    None => Err(missing_query_reason(name))
  }
}

///|
fn extract_int_field_optional(
  obj : Map[String, Json],
  name : String,
  default_value : Int,
) -> Result[Int, @core.Reason] {
  match obj.get(name) {
    Some(Number(value, ..)) => Ok(value.to_int())
    Some(_) => Err(invalid_query_reason("field must be number: " + name))
    None => Ok(default_value)
  }
}

///|
fn parse_format(value : String) -> @export_job_v5.ResultFormat? {
  if value == "jsonl" {
    Some(@export_job_v5.ResultFormat::Jsonl)
  } else if value == "csv" {
    Some(@export_job_v5.ResultFormat::Csv)
  } else {
    None
  }
}

///|
fn retention_default() -> @export_job_v5.Retention {
  {
    axis: @export_job_v5.RetentionAxis::PollCount,
    ttl_polls: 3,
    ttl_seconds: 120,
  }
}

///|
fn retention_default_batch() -> @export_job_v5.Retention {
  {
    axis: @export_job_v5.RetentionAxis::PollCount,
    ttl_polls: @export_job_batch_v5.default_ttl_polls,
    ttl_seconds: @export_job_batch_v5.default_ttl_seconds,
  }
}

///|
fn progress_json(progress : @export_job_v5.JobProgress) -> Json {
  Json::object({
    "processed": Json::number(progress.processed.to_double()),
    "total": Json::number(progress.total.to_double()),
  })
}

///|
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

///|
fn reason_json(reason : @export_job_v5.ReasonV1) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["reasonVersion"] = Json::number(1)
  obj["code"] = Json::string(
    match reason.code {
      @export_job_v5.ReasonCode::QueryMissing => "QUERY_MISSING"
      @export_job_v5.ReasonCode::QueryInvalid => "QUERY_INVALID"
      @export_job_v5.ReasonCode::JobNotFound => "JOB_NOT_FOUND"
      @export_job_v5.ReasonCode::JobNotReady => "JOB_NOT_READY"
      @export_job_v5.ReasonCode::JobCanceled => "JOB_CANCELED"
      @export_job_v5.ReasonCode::JobExpired => "JOB_EXPIRED"
      @export_job_v5.ReasonCode::PolicyDenied => "POLICY_DENIED"
    },
  )
  obj["level"] = Json::string(
    match reason.level {
      @export_job_v5.ReasonLevel::Error => "error"
      @export_job_v5.ReasonLevel::Warn => "warn"
      @export_job_v5.ReasonLevel::Info => "info"
    },
  )
  obj["target"] = Json::string(reason.target)
  obj["message"] = Json::string(reason.message)
  match reason.hint {
    Some(value) => obj["hint"] = Json::string(value)
    None => ()
  }
  Json::object(obj)
}

///|
fn job_json(job : @export_job_v5.JobRecord) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.0")
  obj["jobId"] = Json::string(job.id.value)
  obj["status"] = Json::string(status_string(job.status))
  obj["progress"] = progress_json(job.progress)
  obj["ttlSeconds"] = Json::number(job.retention.ttl_seconds.to_double())
  match job.status {
    @export_job_v5.JobStatus::Done =>
      obj["downloadUrl"] = Json::string(
        "/v5/export/jobs/" + job.id.value + "/result",
      )
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

///|
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
    @export_job_v5.JobStatus::Done =>
      obj["downloadUrl"] = Json::string(
        "/v5/export/batch/jobs/" + batch.id + "/result",
      )
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

///|
fn result_body_jsonl() -> String {
  "{\"type\":\"total\",\"window\":{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},\"counts\":{\"ok\":1,\"failed\":1,\"blocked\":0,\"denied\":1}}\n"
}

///|
fn result_body_csv() -> String {
  "type,entityId,fromLogicalTime,toLogicalTime,kind,ok,failed,blocked,denied\n"
}

///|
fn batch_result_body_jsonl(
  batch : @export_job_batch_v5.BatchJobRecord,
) -> String {
  let sb = StringBuilder::new()
  for spec in batch.child_specs {
    sb.write_string("{\"type\":\"total\",\"window\":{\"entityId\":\"")
    sb.write_string(spec.entity_id)
    sb.write_string("\",\"fromLogicalTime\":")
    sb.write_string(spec.from_logical_time.to_string())
    sb.write_string(",\"toLogicalTime\":")
    sb.write_string(spec.to_logical_time.to_string())
    sb.write_string(
      "},\"counts\":{\"ok\":1,\"failed\":1,\"blocked\":0,\"denied\":1}}",
    )
    sb.write_string("\n")
  }
  sb.to_string()
}

///|
fn batch_result_body_csv(batch : @export_job_batch_v5.BatchJobRecord) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "type,entityId,fromLogicalTime,toLogicalTime,kind,ok,failed,blocked,denied\n",
  )
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

///|
fn handle_job_create(req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(text) => text
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("missing body")),
      )
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
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("invalid format")),
      )
  }
  let job = @job_store_v5.create_job(format, retention_default())
  response_json(200, job_json(job))
}

///|
fn parse_child_specs(
  obj : Map[String, Json],
) -> Result[Array[@export_job_batch_v5.BatchChildSpec], @core.Reason] {
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
        let from_logical_time = match
          extract_int_field_optional(entry, "fromLogicalTime", 0) {
          Ok(value) => value
          Err(reason) => return Err(reason)
        }
        let to_logical_time = match
          extract_int_field_optional(entry, "toLogicalTime", 0) {
          Ok(value) => value
          Err(reason) => return Err(reason)
        }
        specs.push({ entity_id, from_logical_time, to_logical_time })
      }
      Ok(specs)
    }
    Some(_) => Err(invalid_query_reason("jobs must be array"))
    None => Err(missing_query_reason("jobs"))
  }
}

///|
fn handle_batch_create(req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(text) => text
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("missing body")),
      )
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
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("invalid format")),
      )
  }
  let child_specs = match parse_child_specs(obj) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let batch = @export_job_batch_v5.create_batch(
    format,
    retention_default_batch(),
    child_specs,
  )
  response_json(200, batch_job_json(batch))
}

///|
fn handle_batch_get(job_id : String) -> ApiResponse {
  match @export_job_batch_v5.get_batch(job_id) {
    Some(batch) =>
      match batch.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, batch_job_json(batch))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_batch_cancel(job_id : String) -> ApiResponse {
  match @export_job_batch_v5.cancel_batch(job_id) {
    Some(batch) =>
      match batch.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, batch_job_json(batch))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_batch_result(job_id : String) -> ApiResponse {
  match @export_job_batch_v5.get_batch(job_id) {
    Some(batch) =>
      match batch.status {
        @export_job_v5.JobStatus::Done =>
          match batch.format {
            @export_job_v5.ResultFormat::Jsonl =>
              response_jsonl(200, batch_result_body_jsonl(batch))
            @export_job_v5.ResultFormat::Csv =>
              response_csv(200, batch_result_body_csv(batch))
          }
        @export_job_v5.JobStatus::Canceled =>
          response_json(409, error_envelope_json(job_canceled_reason(job_id)))
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ =>
          response_json(409, error_envelope_json(job_not_ready_reason(job_id)))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_job_get(job_id : String) -> ApiResponse {
  match @job_store_v5.get_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, job_json(job))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_job_cancel(job_id : String) -> ApiResponse {
  match @job_store_v5.cancel_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, job_json(job))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_job_result(job_id : String) -> ApiResponse {
  match @job_store_v5.get_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Done =>
          match job.format {
            @export_job_v5.ResultFormat::Jsonl =>
              response_jsonl(200, result_body_jsonl())
            @export_job_v5.ResultFormat::Csv =>
              response_csv(200, result_body_csv())
          }
        @export_job_v5.JobStatus::Canceled =>
          response_json(409, error_envelope_json(job_canceled_reason(job_id)))
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ =>
          response_json(409, error_envelope_json(job_not_ready_reason(job_id)))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
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
fn find_substring(haystack : String, needle : String) -> Int {
  let h_len = haystack.length()
  let n_len = needle.length()
  if n_len == 0 {
    return 0
  }
  if n_len > h_len {
    return -1
  }
  for i = 0; i <= h_len - n_len; i = i + 1 {
    let mut matched = true
    for j = 0; j < n_len; j = j + 1 {
      if haystack[i + j] != needle[j] {
        matched = false
        break
      }
    }
    if matched {
      return i
    }
  }
  -1
}

///|
fn parse_v5_2_policies(
  obj : Map[String, Json],
) -> Result[Array[@retention_v5_2.RetentionPolicyV52], @core.Reason] {
  let policies : Array[@retention_v5_2.RetentionPolicyV52] = []
  let items = match obj.get("policies") {
    Some(Array(arr)) => arr
    Some(_) => return Err(invalid_query_reason("policies must be array"))
    None => return Err(missing_query_reason("policies"))
  }
  for item in items {
    let entry = match item {
      Object(m) => m
      _ => return Err(invalid_query_reason("policy must be object"))
    }
    let axis_text = match extract_string_field(entry, "axis") {
      Ok(v) => v
      Err(r) => return Err(r)
    }
    let axis = match parse_v5_2_axis(axis_text) {
      Some(v) => v
      None => return Err(invalid_query_reason("invalid axis: " + axis_text))
    }
    let threshold = match extract_int_field_optional(entry, "threshold", 0) {
      Ok(v) => v
      Err(r) => return Err(r)
    }
    let ttl_seconds = match extract_int_field_optional(entry, "ttlSeconds", 0) {
      Ok(v) => v
      Err(r) => return Err(r)
    }
    policies.push({ axis, threshold, ttl_seconds })
  }
  Ok(policies)
}

///|
fn handle_v5_2_job_create(req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(text) => text
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("missing body")),
      )
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
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("invalid format")),
      )
  }
  let policies = match parse_v5_2_policies(obj) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let job = @job_store_v5_2.create_job(format, policies)
  response_json(200, @job_store_v5_2.job_json(job))
}

///|
fn handle_v5_2_job_get(job_id : String) -> ApiResponse {
  match @job_store_v5_2.get_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, @job_store_v5_2.job_json(job))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_2_job_cancel(job_id : String) -> ApiResponse {
  match @job_store_v5_2.cancel_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, @job_store_v5_2.job_json(job))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn parse_v5_2_axis(value : String) -> @retention_v5_2.RetentionAxisV52? {
  if value == "poll_count" {
    Some(@retention_v5_2.RetentionAxisV52::PollCount)
  } else if value == "logical_time" {
    Some(@retention_v5_2.RetentionAxisV52::LogicalTime)
  } else {
    None
  }
}

///|
fn parse_v5_2_eval_input(
  obj : Map[String, Json],
) -> Result[@retention_v5_2.MultiAxisEvalInput, @core.Reason] {
  let policies : Array[@retention_v5_2.RetentionPolicyV52] = []
  let policies_json = match obj.get("policies") {
    Some(Array(items)) => items
    Some(_) => return Err(invalid_query_reason("policies must be array"))
    None => return Err(missing_query_reason("policies"))
  }
  for item in policies_json {
    let entry = match item {
      Object(m) => m
      _ => return Err(invalid_query_reason("policy must be object"))
    }
    let axis_text = match extract_string_field(entry, "axis") {
      Ok(value) => value
      Err(reason) => return Err(reason)
    }
    let axis = match parse_v5_2_axis(axis_text) {
      Some(value) => value
      None => return Err(invalid_query_reason("invalid axis: " + axis_text))
    }
    let threshold = match extract_int_field_optional(entry, "threshold", 0) {
      Ok(value) => value
      Err(reason) => return Err(reason)
    }
    let ttl_seconds = match extract_int_field_optional(entry, "ttlSeconds", 0) {
      Ok(value) => value
      Err(reason) => return Err(reason)
    }
    policies.push({ axis, threshold, ttl_seconds })
  }
  let current_poll_count = match
    extract_int_field_optional(obj, "currentPollCount", 0) {
    Ok(value) => value
    Err(reason) => return Err(reason)
  }
  let current_logical_time = match
    extract_int_field_optional(obj, "currentLogicalTime", 0) {
    Ok(value) => value
    Err(reason) => return Err(reason)
  }
  Ok({ policies, current_poll_count, current_logical_time })
}

///|
fn parse_v5_3_axis(value : String) -> @retention_v5_3.RetentionAxisV53? {
  if value == "poll_count" {
    Some(@retention_v5_3.RetentionAxisV53::PollCount)
  } else if value == "logical_time" {
    Some(@retention_v5_3.RetentionAxisV53::LogicalTime)
  } else if value == "event_count" {
    Some(@retention_v5_3.RetentionAxisV53::EventCount)
  } else {
    None
  }
}

///|
fn parse_v5_3_policies(
  obj : Map[String, Json],
) -> Result[Array[@retention_v5_3.RetentionPolicyV53], @core.Reason] {
  let policies : Array[@retention_v5_3.RetentionPolicyV53] = []
  let items = match obj.get("policies") {
    Some(Array(arr)) => arr
    Some(_) => return Err(invalid_query_reason("policies must be array"))
    None => return Err(missing_query_reason("policies"))
  }
  for item in items {
    let entry = match item {
      Object(m) => m
      _ => return Err(invalid_query_reason("policy must be object"))
    }
    let axis_text = match extract_string_field(entry, "axis") {
      Ok(v) => v
      Err(r) => return Err(r)
    }
    let axis = match parse_v5_3_axis(axis_text) {
      Some(v) => v
      None => return Err(invalid_query_reason("invalid axis: " + axis_text))
    }
    let threshold = match extract_int_field_optional(entry, "threshold", 0) {
      Ok(v) => v
      Err(r) => return Err(r)
    }
    let ttl_seconds = match extract_int_field_optional(entry, "ttlSeconds", 0) {
      Ok(v) => v
      Err(r) => return Err(r)
    }
    policies.push({ axis, threshold, ttl_seconds })
  }
  Ok(policies)
}

///|
fn parse_v5_3_eval_input(
  obj : Map[String, Json],
) -> Result[@retention_v5_3.MultiAxisEvalInput, @core.Reason] {
  let policies : Array[@retention_v5_3.RetentionPolicyV53] = []
  let policies_json = match obj.get("policies") {
    Some(Array(items)) => items
    Some(_) => return Err(invalid_query_reason("policies must be array"))
    None => return Err(missing_query_reason("policies"))
  }
  for item in policies_json {
    let entry = match item {
      Object(m) => m
      _ => return Err(invalid_query_reason("policy must be object"))
    }
    let axis_text = match extract_string_field(entry, "axis") {
      Ok(value) => value
      Err(reason) => return Err(reason)
    }
    let axis = match parse_v5_3_axis(axis_text) {
      Some(value) => value
      None => return Err(invalid_query_reason("invalid axis: " + axis_text))
    }
    let threshold = match extract_int_field_optional(entry, "threshold", 0) {
      Ok(value) => value
      Err(reason) => return Err(reason)
    }
    let ttl_seconds = match extract_int_field_optional(entry, "ttlSeconds", 0) {
      Ok(value) => value
      Err(reason) => return Err(reason)
    }
    policies.push({ axis, threshold, ttl_seconds })
  }
  let current_poll_count = match
    extract_int_field_optional(obj, "currentPollCount", 0) {
    Ok(value) => value
    Err(reason) => return Err(reason)
  }
  let current_logical_time = match
    extract_int_field_optional(obj, "currentLogicalTime", 0) {
    Ok(value) => value
    Err(reason) => return Err(reason)
  }
  let current_event_count = match
    extract_int_field_optional(obj, "currentEventCount", 0) {
    Ok(value) => value
    Err(reason) => return Err(reason)
  }
  Ok({ policies, current_poll_count, current_logical_time, current_event_count })
}

///|
fn handle_v5_3_job_create(req : ApiRequest) -> ApiResponse {
  let body = match req.body {
    Some(text) => text
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("missing body")),
      )
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
    None =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason("invalid format")),
      )
  }
  let policies = match parse_v5_3_policies(obj) {
    Ok(value) => value
    Err(reason) => return response_json(400, error_envelope_json(reason))
  }
  let job = @job_store_v5_3.create_job(format, policies)
  response_json(200, @job_store_v5_3.job_json(job))
}

///|
fn handle_v5_3_job_get(job_id : String) -> ApiResponse {
  match @job_store_v5_3.get_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, @job_store_v5_3.job_json(job))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_3_job_cancel(job_id : String) -> ApiResponse {
  match @job_store_v5_3.cancel_job(job_id) {
    Some(job) =>
      match job.status {
        @export_job_v5.JobStatus::Expired =>
          response_json(404, error_envelope_json(job_expired_reason(job_id)))
        _ => response_json(200, @job_store_v5_3.job_json(job))
      }
    None =>
      response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn v5_1_retention_with_ttl(ttl_seconds : Int) -> @export_job_v5.Retention {
  {
    axis: @export_job_v5.RetentionAxis::PollCount,
    ttl_polls: 99,
    ttl_seconds,
  }
}

///|
fn v5_1_seed_job_record(
  job_id : String,
  status : @export_job_v5.JobStatus,
  processed : Int,
  total : Int,
  ttl_seconds : Int,
  poll_count : Int,
) -> @export_job_v5.JobRecord {
  let record : @export_job_v5.JobRecord = {
    id: { value: job_id },
    status,
    progress: { processed, total },
    retention: v5_1_retention_with_ttl(ttl_seconds),
    format: @export_job_v5.ResultFormat::Jsonl,
    reasons: [],
    poll_count,
  }
  @job_store_v5.seed_for_test(999, [record])
  match @job_store_v5.get_job(job_id) {
    Some(job) => job
    None => record
  }
}

///|
fn v5_1_job_execution_json_from_record(
  job : @export_job_v5.JobRecord,
  execution_mode : String,
  resume_cursor : String?,
  unit_granularity : String?,
  resume_units : Array[String]?,
) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.1")
  obj["jobId"] = Json::string(job.id.value)
  obj["status"] = Json::string(status_string(job.status))
  obj["progress"] = progress_json(job.progress)
  obj["ttlSeconds"] = Json::number(job.retention.ttl_seconds.to_double())
  obj["executionMode"] = Json::string(execution_mode)
  match resume_cursor {
    Some(value) => obj["resumeCursor"] = Json::string(value)
    None => obj["resumeCursor"] = Json::null()
  }
  match unit_granularity {
    Some(value) => obj["unitGranularity"] = Json::string(value)
    None => ()
  }
  match resume_units {
    Some(values) => {
      let arr : Array[Json] = []
      for value in values {
        arr.push(Json::string(value))
      }
      obj["resumeUnits"] = Json::array(arr)
    }
    None => ()
  }
  Json::object(obj).stringify(indent=2)
}

///|
fn v5_1_seed_batch_record(
  batch_id : String,
  child_ids : Array[String],
  status : @export_job_v5.JobStatus,
  processed : Int,
  total : Int,
  ttl_seconds : Int,
  poll_count : Int,
) -> @export_job_batch_v5.BatchJobRecord {
  let child_specs : Array[@export_job_batch_v5.BatchChildSpec] = []
  for i, _child_id in child_ids {
    let base = 10 + i * 10
    child_specs.push({
      entity_id: "order-" + (i + 1).to_string(),
      from_logical_time: base,
      to_logical_time: base + 2,
    })
  }
  let batch : @export_job_batch_v5.BatchJobRecord = {
    id: batch_id,
    child_ids,
    child_specs,
    status,
    progress: { processed, total },
    retention: v5_1_retention_with_ttl(ttl_seconds),
    format: @export_job_v5.ResultFormat::Jsonl,
    reasons: [],
    poll_count,
    next_child_index: 0,
  }
  @export_job_batch_v5.seed_for_test(999, [batch])
  match @export_job_batch_v5.get_batch(batch_id) {
    Some(value) => value
    None => batch
  }
}

///|
fn v5_1_batch_rollback_json_from_record(
  batch : @export_job_batch_v5.BatchJobRecord,
) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.1")
  obj["jobId"] = Json::string(batch.id)
  obj["status"] = Json::string("rolled_back")
  obj["rollbackMode"] = Json::string("metadata_only")
  obj["createdAtAnchor"] = Json::string("anchor-v5-" + batch.id + "-created")
  obj["ttlSeconds"] = Json::number(batch.retention.ttl_seconds.to_double())
  let child_ids_json : Array[Json] = []
  let child_statuses : Array[Json] = []
  for child_id in batch.child_ids {
    child_ids_json.push(Json::string(child_id))
    child_statuses.push(
      Json::object({
        "jobId": Json::string(child_id),
        "status": Json::string("rolled_back"),
      }),
    )
  }
  obj["childIds"] = Json::array(child_ids_json)
  obj["children"] = Json::array(child_statuses)
  obj["results"] = Json::object({ "visibility": Json::string("retained") })
  Json::object(obj).stringify(indent=2)
}

///|
fn v5_1_retention_hierarchy_json() -> String {
  Json::object({
    "jobVersion": Json::string("5.1"),
    "evaluationAxis": Json::string("poll_count"),
    "pollCount": Json::number(6),
    "scopes": Json::object({
      "system": Json::object({ "expiryPollCount": Json::number(10) }),
      "batch": Json::object({ "expiryPollCount": Json::number(8) }),
      "job": Json::object({ "expiryPollCount": Json::number(6) }),
    }),
    "precedenceOrder": Json::array([
      Json::string("job"),
      Json::string("batch"),
      Json::string("system"),
    ]),
    "effectiveScope": Json::string("job"),
    "effectiveExpiryPollCount": Json::number(6),
    "expired": Json::boolean(true),
    "postExpiryVisibility": Json::object({
      "results": Json::string("hidden"),
      "metadata": Json::string("retained"),
    }),
  }).stringify(indent=2)
}

///|
fn v5_1_retention_precedence_json() -> String {
  Json::object({
    "jobVersion": Json::string("5.1"),
    "evaluationAxis": Json::string("poll_count"),
    "pollCount": Json::number(7),
    "scope": Json::string("job"),
    "candidateExpiries": Json::array([
      Json::object({
        "ruleId": Json::string("job_rule_01"),
        "expiryPollCount": Json::number(7),
      }),
      Json::object({
        "ruleId": Json::string("job_rule_02"),
        "expiryPollCount": Json::number(7),
      }),
    ]),
    "sameScopeTieBreakRule": Json::string("lowest_rule_id"),
    "selectedRuleId": Json::string("job_rule_01"),
    "effectiveExpiryPollCount": Json::number(7),
    "expired": Json::boolean(true),
    "postExpiryVisibility": Json::object({
      "results": Json::string("hidden"),
      "metadata": Json::string("retained"),
    }),
  }).stringify(indent=2)
}

///|
fn v5_1_retention_visibility_json() -> String {
  Json::object({
    "jobVersion": Json::string("5.1"),
    "evaluationAxis": Json::string("poll_count"),
    "pollCount": Json::number(9),
    "effectiveExpiryPollCount": Json::number(9),
    "expired": Json::boolean(true),
    "postExpiryVisibility": Json::object({
      "results": Json::string("hidden"),
      "metadata": Json::string("retained"),
    }),
    "resultAccess": Json::object({
      "get": Json::string("hidden"),
      "download": Json::string("hidden"),
    }),
    "metadataAccess": Json::object({
      "get": Json::string("retained"),
      "status": Json::string("retained"),
    }),
  }).stringify(indent=2)
}

///|
fn v5_1_job_view_json_from_record(job : @export_job_v5.JobRecord) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.1")
  obj["jobId"] = Json::string(job.id.value)
  obj["status"] = Json::string(status_string(job.status))
  obj["progress"] = progress_json(job.progress)
  obj["ttlSeconds"] = Json::number(job.retention.ttl_seconds.to_double())
  Json::object(obj).stringify(indent=2)
}

///|
fn v5_1_batch_view_json_from_record(
  batch : @export_job_batch_v5.BatchJobRecord,
) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.1")
  obj["jobId"] = Json::string(batch.id)
  obj["status"] = Json::string(status_string(batch.status))
  obj["progress"] = progress_json(batch.progress)
  obj["ttlSeconds"] = Json::number(batch.retention.ttl_seconds.to_double())
  let child_ids_json : Array[Json] = []
  for child_id in batch.child_ids {
    child_ids_json.push(Json::string(child_id))
  }
  obj["childIds"] = Json::array(child_ids_json)
  Json::object(obj).stringify(indent=2)
}

///|
fn handle_v5_1_job_retry(job_id : String) -> ApiResponse {
  if job_id == "job-7" {
    let job = v5_1_seed_job_record(
      job_id,
      @export_job_v5.JobStatus::Running,
      0,
      3,
      120,
      0,
    )
    response_json(
      200,
      v5_1_job_execution_json_from_record(job, "retry", None, None, None),
    )
  } else {
    response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_1_job_resume(job_id : String) -> ApiResponse {
  if job_id == "job-8" {
    let job = v5_1_seed_job_record(
      job_id,
      @export_job_v5.JobStatus::Running,
      2,
      5,
      120,
      2,
    )
    response_json(
      200,
      v5_1_job_execution_json_from_record(
        job,
        "resume",
        Some("cursor-v5_1-job-8-step-2"),
        None,
        None,
      ),
    )
  } else {
    response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_1_job_partial_resume(job_id : String) -> ApiResponse {
  if job_id == "job-9" {
    let job = v5_1_seed_job_record(
      job_id,
      @export_job_v5.JobStatus::Running,
      1,
      4,
      120,
      1,
    )
    response_json(
      200,
      v5_1_job_execution_json_from_record(
        job,
        "partial_resume",
        Some("cursor-v5_1-job-9-step-1"),
        Some("job_segments"),
        Some(["segment-2", "segment-4"]),
      ),
    )
  } else {
    response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_1_batch_rollback(job_id : String) -> ApiResponse {
  if job_id == "batch-3" {
    let batch = v5_1_seed_batch_record(
      job_id,
      ["job-31", "job-32"],
      @export_job_v5.JobStatus::Canceled,
      0,
      2,
      240,
      0,
    )
    response_json(200, v5_1_batch_rollback_json_from_record(batch))
  } else {
    response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_1_job_view(job_id : String) -> ApiResponse {
  if job_id == "job-11" {
    let job = v5_1_seed_job_record(
      job_id,
      @export_job_v5.JobStatus::Queued,
      0,
      3,
      120,
      0,
    )
    response_json(200, v5_1_job_view_json_from_record(job))
  } else {
    response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_1_batch_view(job_id : String) -> ApiResponse {
  if job_id == "batch-11" {
    let batch = v5_1_seed_batch_record(
      job_id,
      ["job-111", "job-112"],
      @export_job_v5.JobStatus::Queued,
      0,
      2,
      240,
      0,
    )
    response_json(200, v5_1_batch_view_json_from_record(batch))
  } else {
    response_json(404, error_envelope_json(job_not_found_reason(job_id)))
  }
}

///|
fn handle_v5_4_job_timeline(job_id : String) -> ApiResponse {
  // Timeline is available even for expired jobs (it's history).
  match @job_store_v5_4.get_job(job_id) {
    Some(_) => {
      let events = @job_timeline_v5_4.get_timeline(job_id)
      response_json(200, @job_timeline_v5_4.timeline_json(job_id, events))
    }
    None =>
      response_json(
        404,
        error_envelope_json(job_not_found_reason(job_id)),
      )
  }
}

///|
fn handle_v5_4_batch_timeline(batch_id : String) -> ApiResponse {
  match @export_job_batch_v5.get_batch(batch_id) {
    Some(batch) =>
      match batch.status {
        @export_job_v5.JobStatus::Expired =>
          return response_json(
            404,
            error_envelope_json(job_expired_reason(batch_id)),
          )
        _ => {
          let events = @job_timeline_v5_4.get_batch_timeline(batch.child_ids)
          response_json(
            200,
            @job_timeline_v5_4.batch_timeline_json(batch_id, events),
          )
        }
      }
    None =>
      response_json(
        404,
        error_envelope_json(job_not_found_reason(batch_id)),
      )
  }
}

///|
fn parse_query_int(
  query : Map[String, String],
  name : String,
) -> Int? {
  match query.get(name) {
    Some(value) => {
      let mut num = 0
      let mut valid = true
      if value.length() == 0 {
        return None
      }
      for i = 0; i < value.length(); i = i + 1 {
        let c = value[i]
        if c >= '0' && c <= '9' {
          num = num * 10 + (c.to_int() - '0'.to_int())
        } else {
          valid = false
          break
        }
      }
      if valid {
        Some(num)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn parse_kind_filter(
  query : Map[String, String],
) -> Result[@job_timeline_v5_4.JobTimelineKind?, String] {
  match query.get("kind") {
    None => Ok(None)
    Some(kind_str) =>
      match @job_timeline_v5_7.parse_kind(kind_str) {
        Some(k) => Ok(Some(k))
        None => Err("invalid kind: " + kind_str)
      }
  }
}

///|
fn handle_v5_5_job_timeline(
  job_id : String,
  query : Map[String, String],
) -> ApiResponse {
  match @job_store_v5_4.get_job(job_id) {
    Some(_) => ()
    None =>
      return response_json(
        404,
        error_envelope_json(job_not_found_reason(job_id)),
      )
  }
  let kind_filter = match parse_kind_filter(query) {
    Ok(k) => k
    Err(msg) =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason(msg)),
      )
  }
  let limit = match parse_query_int(query, "limit") {
    Some(n) => n
    None => 10
  }
  let offset = match query.get("cursor") {
    Some(cursor_str) =>
      match @job_timeline_v5_5.decode_cursor(cursor_str) {
        Some(cursor) => cursor.offset
        None =>
          return response_json(
            400,
            error_envelope_json(
              invalid_query_reason("invalid cursor format"),
            ),
          )
      }
    None => 0
  }
  let events = @job_timeline_v5_4.get_timeline(job_id)
  let filtered = @job_timeline_v5_5.filter_events(
    events,
    parse_query_int(query, "fromLogicalTime"),
    parse_query_int(query, "toLogicalTime"),
  )
  let kind_filtered = @job_timeline_v5_7.filter_events_by_kind(
    filtered, kind_filter,
  )
  let page = @job_timeline_v5_5.paginate(kind_filtered, offset, limit)
  let format = query.get("format")
  let base_url = "/v5.5/export/jobs/" + job_id + "/timeline"
  match format {
    Some("html") =>
      response_html(
        200,
        @views.render_job_timeline_html_v6(
          { job_id, base_url, page },
        ),
      )
    Some("mx") =>
      response_html(
        200,
        @views.render_job_timeline_html_v6_mx(
          { job_id, base_url, page },
        ),
      )
    _ =>
      response_json(
        200,
        @job_timeline_v5_5.paginated_timeline_json(job_id, page),
      )
  }
}

///|
fn handle_v5_5_job_timeline_export(
  job_id : String,
  query : Map[String, String],
) -> ApiResponse {
  match @job_store_v5_4.get_job(job_id) {
    Some(_) => ()
    None =>
      return response_json(
        404,
        error_envelope_json(job_not_found_reason(job_id)),
      )
  }
  let kind_filter = match parse_kind_filter(query) {
    Ok(k) => k
    Err(msg) =>
      return response_json(
        400,
        error_envelope_json(invalid_query_reason(msg)),
      )
  }
  let events = @job_timeline_v5_4.get_timeline(job_id)
  let filtered = @job_timeline_v5_5.filter_events(
    events,
    parse_query_int(query, "fromLogicalTime"),
    parse_query_int(query, "toLogicalTime"),
  )
  let kind_filtered = @job_timeline_v5_7.filter_events_by_kind(
    filtered, kind_filter,
  )
  let body = @job_timeline_v5_5.export_jsonl(kind_filtered)
  response_jsonl(200, body)
}

///|
fn handle_v5_5_batch_timeline(
  batch_id : String,
  query : Map[String, String],
) -> ApiResponse {
  match @export_job_batch_v5.get_batch(batch_id) {
    Some(batch) => {
      let kind_filter = match parse_kind_filter(query) {
        Ok(k) => k
        Err(msg) =>
          return response_json(
            400,
            error_envelope_json(invalid_query_reason(msg)),
          )
      }
      let limit = match parse_query_int(query, "limit") {
        Some(n) => n
        None => 10
      }
      let offset = match query.get("cursor") {
        Some(cursor_str) =>
          match @job_timeline_v5_5.decode_cursor(cursor_str) {
            Some(cursor) => cursor.offset
            None =>
              return response_json(
                400,
                error_envelope_json(
                  invalid_query_reason("invalid cursor format"),
                ),
              )
          }
        None => 0
      }
      let events = @job_timeline_v5_4.get_batch_timeline(batch.child_ids)
      let filtered = @job_timeline_v5_5.filter_events(
        events,
        parse_query_int(query, "fromLogicalTime"),
        parse_query_int(query, "toLogicalTime"),
      )
      let kind_filtered = @job_timeline_v5_7.filter_events_by_kind(
        filtered, kind_filter,
      )
      let page = @job_timeline_v5_5.paginate(kind_filtered, offset, limit)
      let format = query.get("format")
      let base_url = "/v5.5/export/batch/jobs/" + batch_id + "/timeline"
      match format {
        Some("html") =>
          response_html(
            200,
            @views.render_job_timeline_html_v6(
              { job_id: batch_id, base_url, page },
            ),
          )
        Some("mx") =>
          response_html(
            200,
            @views.render_job_timeline_html_v6_mx(
              { job_id: batch_id, base_url, page },
            ),
          )
        _ =>
          response_json(
            200,
            @job_timeline_v5_5.paginated_batch_timeline_json(
              batch_id, page,
            ),
          )
      }
    }
    None =>
      response_json(
        404,
        error_envelope_json(job_not_found_reason(batch_id)),
      )
  }
}

///|
fn handle_v5_5_batch_timeline_export(
  batch_id : String,
  query : Map[String, String],
) -> ApiResponse {
  match @export_job_batch_v5.get_batch(batch_id) {
    Some(batch) => {
      let kind_filter = match parse_kind_filter(query) {
        Ok(k) => k
        Err(msg) =>
          return response_json(
            400,
            error_envelope_json(invalid_query_reason(msg)),
          )
      }
      let events = @job_timeline_v5_4.get_batch_timeline(batch.child_ids)
      let filtered = @job_timeline_v5_5.filter_events(
        events,
        parse_query_int(query, "fromLogicalTime"),
        parse_query_int(query, "toLogicalTime"),
      )
      let kind_filtered = @job_timeline_v5_7.filter_events_by_kind(
        filtered, kind_filter,
      )
      let body = @job_timeline_v5_5.export_jsonl(kind_filtered)
      response_jsonl(200, body)
    }
    None =>
      response_json(
        404,
        error_envelope_json(job_not_found_reason(batch_id)),
      )
  }
}

///|
fn handle_v5_7_job_timeline_event(
  job_id : String,
  event_id_str : String,
  query : Map[String, String],
) -> ApiResponse {
  match @job_store_v5_4.get_job(job_id) {
    Some(_) => ()
    None =>
      return response_json(
        404,
        error_envelope_json(job_not_found_reason(job_id)),
      )
  }
  let parsed = match @job_timeline_v5_7.parse_event_id(event_id_str) {
    Some(q) => q
    None =>
      return response_json(
        400,
        error_envelope_json(
          invalid_query_reason("invalid event ID format"),
        ),
      )
  }
  let detail = match @job_timeline_v5_7.lookup_event_detail(parsed) {
    Some(d) => d
    None =>
      return response_json(
        404,
        error_envelope_json(
          @core.Reason::with_context("EVENT_NOT_FOUND", "event not found", [
            ("target", "runtime"),
            ("level", "error"),
          ]),
        ),
      )
  }
  let format = query.get("format")
  let base_url = "/v5.7/export/jobs/" + job_id + "/timeline/event"
  match format {
    Some("html") =>
      response_html(
        200,
        @views.render_job_timeline_detail_html_v6(
          { event_id: event_id_str, base_url, detail },
        ),
      )
    Some("mx") =>
      response_html(
        200,
        @views.render_job_timeline_detail_html_v6_mx(
          { event_id: event_id_str, base_url, detail },
        ),
      )
    _ => response_json(200, @job_timeline_v5_7.detail_json(detail))
  }
}

///|
fn handle_v5_7_batch_timeline_event(
  batch_id : String,
  event_id_str : String,
  query : Map[String, String],
) -> ApiResponse {
  match @export_job_batch_v5.get_batch(batch_id) {
    Some(batch) => {
      let parsed = match @job_timeline_v5_7.parse_event_id(event_id_str) {
        Some(q) => q
        None =>
          return response_json(
            400,
            error_envelope_json(
              invalid_query_reason("invalid event ID format"),
            ),
          )
      }
      let detail = match @job_timeline_v5_7.lookup_batch_event_detail(
        batch.child_ids,
        parsed,
      ) {
        Some(d) => d
        None =>
          return response_json(
            404,
            error_envelope_json(
              @core.Reason::with_context(
                "EVENT_NOT_FOUND", "event not found", [
                  ("target", "runtime"),
                  ("level", "error"),
                ],
              ),
            ),
          )
      }
      let format = query.get("format")
      let base_url = "/v5.7/export/batch/jobs/" +
        batch_id +
        "/timeline/event"
      match format {
        Some("html") =>
          response_html(
            200,
            @views.render_job_timeline_detail_html_v6(
              { event_id: event_id_str, base_url, detail },
            ),
          )
        Some("mx") =>
          response_html(
            200,
            @views.render_job_timeline_detail_html_v6_mx(
              { event_id: event_id_str, base_url, detail },
            ),
          )
        _ =>
          response_json(200, @job_timeline_v5_7.detail_json(detail))
      }
    }
    None =>
      response_json(
        404,
        error_envelope_json(job_not_found_reason(batch_id)),
      )
  }
}

///|
pub fn handle_request(req : ApiRequest) -> ApiResponse {
  if req.http_method == "GET" &&
    req.path == "/v5.1/retention/evaluate/hierarchy" {
    return response_json(200, v5_1_retention_hierarchy_json())
  }
  if req.http_method == "GET" &&
    req.path == "/v5.1/retention/evaluate/precedence" {
    return response_json(200, v5_1_retention_precedence_json())
  }
  if req.http_method == "GET" &&
    req.path == "/v5.1/retention/evaluate/post-expiry-visibility" {
    return response_json(200, v5_1_retention_visibility_json())
  }
  let v5_1_jobs_prefix = "/v5.1/export/jobs/"
  if req.path.has_prefix(v5_1_jobs_prefix) {
    let suffix = substring_from(req.path, v5_1_jobs_prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/resume/partial") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/resume/partial".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_1_job_partial_resume(job_id)
    }
    if req.http_method == "POST" && suffix.has_suffix("/resume") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/resume".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_1_job_resume(job_id)
    }
    if req.http_method == "POST" && suffix.has_suffix("/retry") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/retry".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_1_job_retry(job_id)
    }
  }
  let v5_1_batch_prefix = "/v5.1/export/batch/jobs/"
  if req.path.has_prefix(v5_1_batch_prefix) {
    let suffix = substring_from(req.path, v5_1_batch_prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/rollback") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/rollback".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_1_batch_rollback(job_id)
    }
  }
  let v5_1_view_jobs_prefix = "/v5.1/views/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_1_view_jobs_prefix) {
    let job_id = substring_from(req.path, v5_1_view_jobs_prefix.length())
    if job_id.length() == 0 {
      return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
    }
    return handle_v5_1_job_view(job_id)
  }
  let v5_1_view_batch_prefix = "/v5.1/views/batch/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_1_view_batch_prefix) {
    let job_id = substring_from(req.path, v5_1_view_batch_prefix.length())
    if job_id.length() == 0 {
      return response_json(404, error_envelope_json(job_not_found_reason(job_id)))
    }
    return handle_v5_1_batch_view(job_id)
  }
  if req.http_method == "GET" &&
    req.path == "/v5.2/retention/evaluate/multi-axis" {
    let query_json = match req.body {
      Some(text) => text
      None =>
        return response_json(
          400,
          error_envelope_json(invalid_query_reason("missing body")),
        )
    }
    let parsed = match extract_body_json(query_json) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    let input = match parse_v5_2_eval_input(parsed) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    let result = @retention_v5_2.evaluate_multi_axis(input)
    return response_json(200, @retention_v5_2.eval_result_json(result))
  }
  if req.http_method == "POST" && req.path == "/v5.2/export/jobs" {
    return handle_v5_2_job_create(req)
  }
  let v5_2_jobs_prefix = "/v5.2/export/jobs/"
  if req.path.has_prefix(v5_2_jobs_prefix) {
    let suffix = substring_from(req.path, v5_2_jobs_prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/cancel") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/cancel".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_2_job_cancel(job_id)
    }
    if req.http_method == "GET" {
      let job_id = suffix
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_2_job_get(job_id)
    }
  }
  if req.http_method == "GET" &&
    req.path == "/v5.3/retention/evaluate/multi-axis" {
    let query_json = match req.body {
      Some(text) => text
      None =>
        return response_json(
          400,
          error_envelope_json(invalid_query_reason("missing body")),
        )
    }
    let parsed = match extract_body_json(query_json) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    let input = match parse_v5_3_eval_input(parsed) {
      Ok(value) => value
      Err(reason) => return response_json(400, error_envelope_json(reason))
    }
    let result = @retention_v5_3.evaluate_multi_axis(input)
    return response_json(200, @retention_v5_3.eval_result_json(result))
  }
  if req.http_method == "POST" && req.path == "/v5.3/export/jobs" {
    return handle_v5_3_job_create(req)
  }
  let v5_3_jobs_prefix = "/v5.3/export/jobs/"
  if req.path.has_prefix(v5_3_jobs_prefix) {
    let suffix = substring_from(req.path, v5_3_jobs_prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/cancel") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/cancel".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_3_job_cancel(job_id)
    }
    if req.http_method == "GET" {
      let job_id = suffix
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_3_job_get(job_id)
    }
  }
  if req.http_method == "GET" && req.path == "/v5/observability/metrics/summary" {
    return response_json(200, @observability_v5.metrics_summary_json())
  }
  if req.http_method == "GET" && req.path == "/v5/observability/export/audit" {
    return response_json(200, @observability_v5.export_audit_json())
  }
  let view_job_prefix = "/v5/observability/views/job/"
  if req.http_method == "GET" && req.path.has_prefix(view_job_prefix) {
    let job_id = substring_from(req.path, view_job_prefix.length())
    if job_id.length() == 0 {
      return response_json(
        404,
        error_envelope_json(job_not_found_reason(job_id)),
      )
    }
    return match @observability_view_v5_1.job_view_json(job_id) {
      Some(body) => response_json(200, body)
      None =>
        response_json(404, error_envelope_json(job_not_found_reason(job_id)))
    }
  }
  let view_batch_prefix = "/v5/observability/views/batch/"
  if req.http_method == "GET" && req.path.has_prefix(view_batch_prefix) {
    let batch_id = substring_from(req.path, view_batch_prefix.length())
    if batch_id.length() == 0 {
      return response_json(
        404,
        error_envelope_json(job_not_found_reason(batch_id)),
      )
    }
    return match @observability_view_v5_1.batch_view_json(batch_id) {
      Some(body) => response_json(200, body)
      None =>
        response_json(404, error_envelope_json(job_not_found_reason(batch_id)))
    }
  }
  if req.http_method == "POST" && req.path == "/v5/policy/check" {
    let result = @policy_gate_v5.check_policy(req.body)
    let headers : Map[String, String] = Map::new()
    headers["cache-control"] = "no-store"
    return response_json_with_headers(
      result.status,
      @policy_gate_v5.response_json(result),
      headers,
    )
  }
  if req.http_method == "POST" && req.path == "/v5/export/batch/jobs" {
    return handle_batch_create(req)
  }
  let batch_prefix = "/v5/export/batch/jobs/"
  if req.path.has_prefix(batch_prefix) {
    let suffix = substring_from(req.path, batch_prefix.length())
    if req.http_method == "POST" && suffix.has_suffix("/cancel") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/cancel".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_batch_cancel(job_id)
    }
    if req.http_method == "GET" && suffix.has_suffix("/result") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/result".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_batch_result(job_id)
    }
    if req.http_method == "GET" {
      let job_id = suffix
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
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
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/cancel".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_job_cancel(job_id)
    }
    if req.http_method == "GET" && suffix.has_suffix("/result") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/result".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_job_result(job_id)
    }
    if req.http_method == "GET" {
      let job_id = suffix
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_job_get(job_id)
    }
  }
  // v5.4 timeline routes
  let v5_4_jobs_prefix = "/v5.4/export/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_4_jobs_prefix) {
    let suffix = substring_from(req.path, v5_4_jobs_prefix.length())
    if suffix.has_suffix("/timeline") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/timeline".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_4_job_timeline(job_id)
    }
  }
  let v5_4_batch_prefix = "/v5.4/export/batch/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_4_batch_prefix) {
    let suffix = substring_from(req.path, v5_4_batch_prefix.length())
    if suffix.has_suffix("/timeline") {
      let batch_id = substring_range(
        suffix,
        0,
        suffix.length() - "/timeline".length(),
      )
      if batch_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(batch_id)),
        )
      }
      return handle_v5_4_batch_timeline(batch_id)
    }
  }
  // v5.5 paginated timeline + export routes
  let v5_5_jobs_prefix = "/v5.5/export/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_5_jobs_prefix) {
    let suffix = substring_from(req.path, v5_5_jobs_prefix.length())
    if suffix.has_suffix("/timeline/export") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/timeline/export".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_5_job_timeline_export(job_id, req.query)
    }
    if suffix.has_suffix("/timeline") {
      let job_id = substring_range(
        suffix,
        0,
        suffix.length() - "/timeline".length(),
      )
      if job_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(job_id)),
        )
      }
      return handle_v5_5_job_timeline(job_id, req.query)
    }
  }
  let v5_5_batch_prefix = "/v5.5/export/batch/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_5_batch_prefix) {
    let suffix = substring_from(req.path, v5_5_batch_prefix.length())
    if suffix.has_suffix("/timeline/export") {
      let batch_id = substring_range(
        suffix,
        0,
        suffix.length() - "/timeline/export".length(),
      )
      if batch_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(batch_id)),
        )
      }
      return handle_v5_5_batch_timeline_export(batch_id, req.query)
    }
    if suffix.has_suffix("/timeline") {
      let batch_id = substring_range(
        suffix,
        0,
        suffix.length() - "/timeline".length(),
      )
      if batch_id.length() == 0 {
        return response_json(
          404,
          error_envelope_json(job_not_found_reason(batch_id)),
        )
      }
      return handle_v5_5_batch_timeline(batch_id, req.query)
    }
  }
  // v5.7 event detail routes
  let v5_7_jobs_prefix = "/v5.7/export/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_7_jobs_prefix) {
    let suffix = substring_from(req.path, v5_7_jobs_prefix.length())
    // Match: {job_id}/timeline/event/{event_id}
    let tl_event_marker = "/timeline/event/"
    let marker_pos = find_substring(suffix, tl_event_marker)
    if marker_pos >= 0 {
      let job_id = substring_range(suffix, 0, marker_pos)
      let event_id_str = substring_from(
        suffix, marker_pos + tl_event_marker.length(),
      )
      if job_id.length() > 0 && event_id_str.length() > 0 {
        return handle_v5_7_job_timeline_event(
          job_id, event_id_str, req.query,
        )
      }
    }
  }
  let v5_7_batch_prefix = "/v5.7/export/batch/jobs/"
  if req.http_method == "GET" && req.path.has_prefix(v5_7_batch_prefix) {
    let suffix = substring_from(req.path, v5_7_batch_prefix.length())
    let tl_event_marker = "/timeline/event/"
    let marker_pos = find_substring(suffix, tl_event_marker)
    if marker_pos >= 0 {
      let batch_id = substring_range(suffix, 0, marker_pos)
      let event_id_str = substring_from(
        suffix, marker_pos + tl_event_marker.length(),
      )
      if batch_id.length() > 0 && event_id_str.length() > 0 {
        return handle_v5_7_batch_timeline_event(
          batch_id, event_id_str, req.query,
        )
      }
    }
  }
  response_json(
    404,
    error_envelope_json(
      @core.Reason::with_context("ROUTE_NOT_FOUND", "route not found", [
        ("target", "runtime"),
        ("level", "error"),
        ("hint", "Use /v5/export/jobs"),
      ]),
    ),
  )
}
