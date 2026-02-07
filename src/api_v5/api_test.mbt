///|
fn read_text_api(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_api(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn query_map(pairs : Array[(String, String)]) -> Map[String, String] {
  let map : Map[String, String] = Map::new()
  for pair in pairs {
    map[pair.0] = pair.1
  }
  map
}

fn parse_json_or_fail(text : String, label : String) -> Json raise {
  try @json.parse(text) catch {
    err => fail("parse failed: " + label + ": " + err.to_string())
  }
}

fn expect_response_json(res : ApiResponse, expected_path : String) -> Unit raise {
  let expected_text = load_expected(expected_path)
  let expected_json = parse_json_or_fail(expected_text, expected_path)
  let expected_obj = match expected_json {
    Object(obj) => obj
    _ => fail("expected object: " + expected_path)
  }
  let status_value = match expected_obj.get("status") {
    Some(Number(value, ..)) => value.to_int().to_string()
    _ => fail("missing status: " + expected_path)
  }
  inspect(res.status.to_string(), content=status_value)
  let expected_headers = match expected_obj.get("headers") {
    Some(Object(obj)) => obj
    _ => fail("missing headers: " + expected_path)
  }
  for pair in expected_headers {
    let key = pair.0
    let value = pair.1
    match value {
      String(text) => inspect(res.headers.get(key), content="Some(\"" + text + "\")")
      _ => fail("expected header must be string: " + key)
    }
  }
  let expected_body = match expected_obj.get("body") {
    Some(value) => value
    None => fail("missing body: " + expected_path)
  }
  let actual_body_json = parse_json_or_fail(res.body, "response body")
  inspect(actual_body_json.stringify(indent=2), content=expected_body.stringify(indent=2))
}

fn expect_audit_no_sensitive_fields(res : ApiResponse, expected_path : String) -> Unit raise {
  expect_response_json(res, expected_path)
  let actual_body_json = parse_json_or_fail(res.body, "response body")
  let obj = match actual_body_json {
    Object(value) => value
    _ => fail("expected object body")
  }
  let entries = match obj.get("entries") {
    Some(Array(values)) => values
    _ => fail("expected entries array")
  }
  for entry in entries {
    let entry_obj = match entry {
      Object(value) => value
      _ => fail("expected entry object")
    }
    if entry_obj.get("query") != None || entry_obj.get("payload") != None || entry_obj.get("request") != None || entry_obj.get("childSpecs") != None {
      fail("audit entry contains forbidden fields")
    }
  }
}

fn expect_response_text(res : ApiResponse, expected_path : String) -> Unit raise {
  let expected = load_expected(expected_path)
  let mut output = res.body
  if expected.has_suffix("\n") && !output.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v5 create job queued" {
  @job_store_v5.reset_for_test()
  let req : ApiRequest = {
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }
  let res = handle_request(req)
  expect_response_json(res, "fixtures/v5/jobs/create/case_001.response.json")
}

///|
test "api v5 get job queued" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/get/case_001.response.json")
}

///|
test "api v5 get job running no wall-clock" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/get/case_no_wall_clock.response.json")
}

///|
test "api v5 cancel job" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/jobs/job-1/cancel",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/cancel/case_001.response.json")
}

///|
test "api v5 result not ready" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/result/case_001.status.json")
}

///|
test "api v5 result jsonl" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_text(res, "fixtures/v5/jobs/result/case_001.response.jsonl")
}

///|
test "api v5 result csv" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"csv\"}"),
  }))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_text(res, "fixtures/v5/jobs/result/case_001.response.csv")
}

///|
test "api v5 result canceled" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs/job-1/cancel",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/result/case_canceled.response.json")
}

///|
test "api v5 result expired" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/result/case_expired.response.json")
}

///|
test "api v5 get expired" {
  @job_store_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}"),
  }))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/get/case_expired.response.json")
}

///|
test "api v5 get not found" {
  @job_store_v5.reset_for_test()
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-999",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/jobs/get/case_not_found.response.json")
}

///|
test "api v5 create invalid format" {
  @job_store_v5.reset_for_test()
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"format\":\"bad\"}"),
  })
  expect_response_json(res, "fixtures/v5/jobs/create/case_invalid.response.json")
}

///|
test "api v5 create missing entity" {
  @job_store_v5.reset_for_test()
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\"}"),
  })
  expect_response_json(res, "fixtures/v5/jobs/create/case_missing_entity.response.json")
}

///|
test "api v5 shared counter batch then single" {
  @job_store_v5.reset_for_test()
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-3\",\"fromLogicalTime\":30,\"toLogicalTime\":33,\"format\":\"jsonl\"}"),
  })
  expect_response_json(res, "fixtures/v5/jobs/create/case_shared_counter.response.json")
}

///|
test "api v5 batch create queued" {
  @export_job_batch_v5.reset_for_test()
  let req : ApiRequest = {
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }
  let res = handle_request(req)
  expect_response_json(res, "fixtures/v5/batch/create/case_001.response.json")
}

///|
test "api v5 batch get queued" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/get/case_001.response.json")
}

///|
test "api v5 batch cancel" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs/job-1/cancel",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/cancel/case_001.response.json")
}

///|
test "api v5 batch result not ready" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/result/case_001.status.json")
}

///|
test "api v5 batch result jsonl" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_text(res, "fixtures/v5/batch/result/case_001.response.jsonl")
}

///|
test "api v5 batch result csv" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"csv\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_text(res, "fixtures/v5/batch/result/case_001.response.csv")
}

///|
test "api v5 batch result canceled" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs/job-1/cancel",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/result/case_canceled.response.json")
}

///|
test "api v5 batch result expired" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/result/case_expired.response.json")
}

///|
test "api v5 batch get expired" {
  @export_job_batch_v5.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}"),
  }))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  ignore(@export_job_batch_v5.step_batch("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/get/case_expired.response.json")
}

///|
test "api v5 batch get not found" {
  @export_job_batch_v5.reset_for_test()
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-999",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/get/case_not_found.response.json")
}

///|
test "api v5 batch result not found" {
  @export_job_batch_v5.reset_for_test()
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-999/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/batch/result/case_not_found.response.json")
}

///|
test "api v5 batch create invalid format" {
  @export_job_batch_v5.reset_for_test()
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"bad\",\"jobs\":[{\"entityId\":\"order-1\"}]}"),
  })
  expect_response_json(res, "fixtures/v5/batch/create/case_invalid.response.json")
}

///|
test "api v5 batch create missing jobs" {
  @export_job_batch_v5.reset_for_test()
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\"}"),
  })
  expect_response_json(res, "fixtures/v5/batch/create/case_missing_jobs.response.json")
}

///|
test "api v5 observability metrics summary" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/metrics/summary",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/observability/metrics_summary/case_001.response.json")
}

///|
test "api v5 observability export audit" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/export/audit",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/observability/export_audit/case_001.response.json")
}

///|
test "api v5 observability export audit excludes query payload" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/export/audit",
    query: query_map([]),
    body: None,
  })
  expect_audit_no_sensitive_fields(res, "fixtures/v5/observability/export_audit/case_forbidden_fields.response.json")
}

///|
test "api v5 policy allow" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: Some("{\"action\":\"export\"}"),
  })
  expect_response_json(res, "fixtures/v5/policy/check/case_allow.response.json")
}

///|
test "api v5 policy deny" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: Some("{\"action\":\"delete\"}"),
  })
  expect_response_json(res, "fixtures/v5/policy/check/case_deny.response.json")
}

///|
test "api v5 policy missing action" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: Some("{}"),
  })
  expect_response_json(res, "fixtures/v5/policy/check/case_missing_action.response.json")
}

///|
test "api v5 policy invalid action type" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: Some("{\"action\":1}"),
  })
  expect_response_json(res, "fixtures/v5/policy/check/case_invalid_action.response.json")
}

///|
test "api v5 policy missing body" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5/policy/check/case_missing_body.response.json")
}
