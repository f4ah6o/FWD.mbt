///|
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

fn read_text_api(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

fn load_expected(path : String) -> String raise {
  match read_text_api(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn same_json(actual : Json, expected : Json) -> Bool {
  match (actual, expected) {
    (Object(a), Object(b)) => {
      if a.length() != b.length() {
        return false
      }
      for pair in b {
        match a.get(pair.0) {
          Some(av) => if !same_json(av, pair.1) { return false }
          None => return false
        }
      }
      true
    }
    (Array(a), Array(b)) => {
      if a.length() != b.length() {
        return false
      }
      for i in 0..<a.length() {
        if !same_json(a[i], b[i]) {
          return false
        }
      }
      true
    }
    (_, _) => actual.to_string() == expected.to_string()
  }
}

fn expect_shape_matches_fixture(res : ApiResponse, fixture_path : String) -> Unit raise {
  let expected_text = load_expected(fixture_path)
  let expected_json = parse_json_or_fail(expected_text, fixture_path)
  let expected_obj = match expected_json {
    Object(obj) => obj
    _ => fail("expected object fixture: " + fixture_path)
  }
  let expected_status = match expected_obj.get("status") {
    Some(Number(value, ..)) => value.to_int()
    _ => fail("missing status in fixture: " + fixture_path)
  }
  inspect(res.status, content=expected_status.to_string())
  let expected_headers = match expected_obj.get("headers") {
    Some(Object(obj)) => obj
    _ => fail("missing headers in fixture: " + fixture_path)
  }
  inspect(res.headers.length(), content=expected_headers.length().to_string())
  for pair in expected_headers {
    let key = pair.0
    let value = match pair.1 {
      String(v) => v
      _ => fail("header value must be string in fixture: " + fixture_path + ": " + key)
    }
    inspect(res.headers.get(key).to_string(), content="Some(" + value + ")")
  }
  let expected_body = match expected_obj.get("body") {
    Some(value) => value
    None => fail("missing body in fixture: " + fixture_path)
  }
  let actual_body = parse_json_or_fail(res.body, "actual body")
  let matches = same_json(actual_body, expected_body)
  if !matches {
    inspect(actual_body.stringify(indent=2), content=expected_body.stringify(indent=2))
  }
  inspect(matches, content="true")
}

fn precedence_fixture_response(
  job_policy : @export_job_v5_2.RetentionPolicyV52?,
  batch_policy : @export_job_v5_2.RetentionPolicyV52?,
  system_policy : @export_job_v5_2.RetentionPolicyV52?,
) -> ApiResponse {
  let resolved = @retention_v5_2.resolve_retention_policy_v52(job_policy, batch_policy, system_policy)
  let body = Json::object({
    "scopeOrder": Json::array([Json::string("job"), Json::string("batch"), Json::string("system")]),
    "candidates": Json::object({
      "job": policy_label(job_policy),
      "batch": policy_label(batch_policy),
      "system": policy_label(system_policy),
    }),
    "selectedScope": Json::string(resolved.selected_scope),
  }).stringify(indent=2)
  {
    status: 200,
    headers: { "content-type": "application/json" },
    body,
  }
}

fn policy_label(policy : @export_job_v5_2.RetentionPolicyV52?) -> Json {
  match policy {
    Some(value) => {
      match value.axes[0] {
        @export_job_v5_2.RetentionAxisConditionV52::PollCountMax(limit) => Json::string("poll_count_max:" + limit.to_string())
        @export_job_v5_2.RetentionAxisConditionV52::GenerationMin(minimum) => Json::string("generation_min:" + minimum.to_string())
      }
    }
    None => Json::null()
  }
}

fn policy_poll(limit : Int) -> @export_job_v5_2.RetentionPolicyV52 {
  {
    combine: @export_job_v5_2.RetentionCombineV52::All,
    axes: [@export_job_v5_2.RetentionAxisConditionV52::PollCountMax(limit)],
  }
}

fn expect_hidden_shape(
  res : ApiResponse,
  label : String,
  expected_axes : Array[String],
  endpoint : String?,
) -> Unit raise {
  inspect(res.status, content="404")
  let body = parse_json_or_fail(res.body, label)
  let obj = match body {
    Object(v) => v
    _ => fail("expected object")
  }
  let err = match obj.get("error") {
    Some(Object(v)) => v
    _ => fail("missing error")
  }
  inspect(err.get("reasonVersion").to_string(), content="Some(Number(1))")
  inspect(err.get("code").to_string(), content="Some(String(\"JOB_EXPIRED\"))")
  let details = match obj.get("retentionDetails") {
    Some(Object(v)) => v
    _ => fail("missing retentionDetails")
  }
  inspect(details.get("visibility").to_string(), content="Some(String(\"hidden\"))")
  inspect(details.get("combine").to_string(), content="Some(String(\"all\"))")
  let failed_axes = match details.get("failedAxes") {
    Some(Array(v)) => v
    _ => fail("missing failedAxes")
  }
  inspect(failed_axes.length(), content=expected_axes.length().to_string())
  for i in 0..<expected_axes.length() {
    let entry = match failed_axes[i] {
      Object(v) => v
      _ => fail("failed axis item not object")
    }
    inspect(entry.get("axis").to_string(), content="Some(String(\"" + expected_axes[i] + "\"))")
  }
  match endpoint {
    Some(name) => inspect(details.get("endpoint").to_string(), content="Some(String(\"" + name + "\"))")
    None => inspect(details.get("endpoint").to_string(), content="None")
  }
}

///|
test "api v5.2 get visible all pass omits retentionDetails" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":3},{\"type\":\"generation_min\",\"value\":1}]}}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  inspect(res.status, content="200")
  let body = parse_json_or_fail(res.body, "visible body")
  let obj = match body {
    Object(v) => v
    _ => fail("expected object")
  }
  inspect(obj.get("retentionDetails").to_string(), content="None")
  inspect(obj.get("status").to_string(), content="Some(String(\"queued\"))")
}

///|
test "api v5.2 get hidden multi fail returns failedAxes in policy order" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":0},{\"type\":\"generation_min\",\"value\":2}]}}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs/job-1/step",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_hidden_shape(res, "hidden body", ["poll_count", "generation"], None)
}

///|
test "api v5.2 get hidden poll only shape" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":0}]}}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs/job-1/step",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_hidden_shape(res, "hidden poll only", ["poll_count"], None)
}

///|
test "api v5.2 get hidden generation only shape" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"generation_min\",\"value\":2}]}}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_hidden_shape(res, "hidden generation only", ["generation"], None)
}

///|
test "api v5.2 result hidden includes endpoint marker" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":0}]}}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs/job-1/step",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_hidden_shape(res, "result hidden body", ["poll_count"], Some("result"))
}

///|
test "api v5.2 batch get hidden by generation" {
  @export_job_batch_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/batch/jobs",
    query: query_map([]),
    body: Some("{\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"generation_min\",\"value\":2}]},\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12}] }"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/batch/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  inspect(res.status, content="404")
}

///|
test "api v5.2 get legacy expired compatibility block" {
  @job_store_v5_2.reset_for_test()
  @job_store_v5_2.seed_for_test(1, [{
    id: { value: "job-1" },
    status: @export_job_v5_2.JobStatus::Expired,
    progress: { processed: 1, total: 3 },
    retention_policy: {
      combine: @export_job_v5_2.RetentionCombineV52::All,
      axes: [@export_job_v5_2.RetentionAxisConditionV52::PollCountMax(3)],
    },
    generation: 1,
    format: @export_job_v5_2.ResultFormat::Jsonl,
    reasons: [],
    poll_count: 5,
  }])
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  inspect(res.status, content="404")
  let body = parse_json_or_fail(res.body, "legacy expired body")
  let obj = match body {
    Object(v) => v
    _ => fail("expected object")
  }
  let compat = match obj.get("compatibility") {
    Some(Object(v)) => v
    _ => fail("missing compatibility")
  }
  inspect(compat.get("sourceStatus").to_string(), content="Some(String(\"expired\"))")
  inspect(compat.get("mode").to_string(), content="Some(String(\"legacy-read\"))")
}

///|
test "api v5.2 fixture canonical sync visible all pass" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":3},{\"type\":\"generation_min\",\"value\":1}]}}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch1/case_visible_all_pass.response.json")
}

///|
test "api v5.2 fixture canonical sync hidden poll only" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":0}]}}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs/job-1/step",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch1/case_hidden_poll_only.response.json")
}

///|
test "api v5.2 fixture canonical sync hidden generation only" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"generation_min\",\"value\":2}]}}"),
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch1/case_hidden_generation_only.response.json")
}

///|
test "api v5.2 fixture canonical sync hidden multi fail" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":0},{\"type\":\"generation_min\",\"value\":2}]}}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs/job-1/step",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch1/case_hidden_multi_fail.response.json")
}

///|
test "api v5.2 fixture canonical sync result hidden" {
  @job_store_v5_2.reset_for_test()
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs",
    query: query_map([]),
    body: Some("{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\",\"retentionPolicy\":{\"combine\":\"all\",\"axes\":[{\"type\":\"poll_count_max\",\"value\":0}]}}"),
  }))
  ignore(handle_request({
    http_method: "POST",
    path: "/v5.2/export/jobs/job-1/step",
    query: query_map([]),
    body: None,
  }))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch1/case_result_endpoint_hidden.response.json")
}

///|
test "api v5.2 fixture canonical sync compat legacy expired read" {
  @job_store_v5_2.reset_for_test()
  @job_store_v5_2.seed_for_test(1, [{
    id: { value: "job-1" },
    status: @export_job_v5_2.JobStatus::Expired,
    progress: { processed: 1, total: 3 },
    retention_policy: {
      combine: @export_job_v5_2.RetentionCombineV52::All,
      axes: [@export_job_v5_2.RetentionAxisConditionV52::PollCountMax(3)],
    },
    generation: 1,
    format: @export_job_v5_2.ResultFormat::Jsonl,
    reasons: [],
    poll_count: 5,
  }])
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch1/case_compat_legacy_expired_read.response.json")
}

///|
test "api v5.2 fixture canonical sync precedence job over batch over system" {
  let res = precedence_fixture_response(Some(policy_poll(9)), Some(policy_poll(5)), Some(policy_poll(1)))
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch2/case_precedence_job_over_batch_over_system.response.json")
}

///|
test "api v5.2 fixture canonical sync precedence batch over system" {
  let res = precedence_fixture_response(None, Some(policy_poll(5)), Some(policy_poll(1)))
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch2/case_precedence_batch_over_system.response.json")
}

///|
test "api v5.2 fixture canonical sync precedence system only" {
  let res = precedence_fixture_response(None, None, Some(policy_poll(1)))
  expect_shape_matches_fixture(res, "fixtures/v5_2/retention/batch2/case_precedence_system_only.response.json")
}
