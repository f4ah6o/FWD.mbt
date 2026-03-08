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

///|
fn query_map(pairs : Array[(String, String)]) -> Map[String, String] {
  let map : Map[String, String] = Map::new()
  for pair in pairs {
    map[pair.0] = pair.1
  }
  map
}

///|
fn parse_json_or_fail(text : String, label : String) -> Json raise {
  @json.parse(text) catch {
    err => fail("parse failed: " + label + ": " + err.to_string())
  }
}

///|
fn expect_response_json(
  res : ApiResponse,
  expected_path : String,
) -> Unit raise {
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
      String(text) =>
        inspect(res.headers.get(key), content="Some(\"" + text + "\")")
      _ => fail("expected header must be string: " + key)
    }
  }
  let expected_body = match expected_obj.get("body") {
    Some(value) => value
    None => fail("missing body: " + expected_path)
  }
  let actual_body_json = parse_json_or_fail(res.body, "response body")
  inspect(
    actual_body_json.stringify(indent=2),
    content=expected_body.stringify(indent=2),
  )
}

///|
fn expect_audit_no_sensitive_fields(
  res : ApiResponse,
  expected_path : String,
) -> Unit raise {
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
    if entry_obj.get("query") != None ||
      entry_obj.get("payload") != None ||
      entry_obj.get("request") != None ||
      entry_obj.get("childSpecs") != None {
      fail("audit entry contains forbidden fields")
    }
  }
}

///|
fn expect_response_text(
  res : ApiResponse,
  expected_path : String,
) -> Unit raise {
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
    body: Some(
      "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
    ),
  }
  let res = handle_request(req)
  expect_response_json(res, "fixtures/v5/jobs/create/case_001.response.json")
}

///|
test "api v5 get job queued" {
  @job_store_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/jobs/get/case_no_wall_clock.response.json",
  )
}

///|
test "api v5 cancel job" {
  @job_store_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"csv\"}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs/job-1/cancel",
      query: query_map([]),
      body: None,
    }),
  )
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/jobs/result/case_canceled.response.json",
  )
}

///|
test "api v5 result expired" {
  @job_store_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  ignore(@job_store_v5.step_job("job-1"))
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/jobs/result/case_expired.response.json",
  )
}

///|
test "api v5 get expired" {
  @job_store_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/jobs",
      query: query_map([]),
      body: Some(
        "{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12,\"format\":\"jsonl\"}",
      ),
    }),
  )
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
  expect_response_json(
    res, "fixtures/v5/jobs/create/case_invalid.response.json",
  )
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
  expect_response_json(
    res, "fixtures/v5/jobs/create/case_missing_entity.response.json",
  )
}

///|
test "api v5 shared counter batch then single" {
  @job_store_v5.reset_for_test()
  @export_job_batch_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
  let res = handle_request({
    http_method: "POST",
    path: "/v5/export/jobs",
    query: query_map([]),
    body: Some(
      "{\"entityId\":\"order-3\",\"fromLogicalTime\":30,\"toLogicalTime\":33,\"format\":\"jsonl\"}",
    ),
  })
  expect_response_json(
    res, "fixtures/v5/jobs/create/case_shared_counter.response.json",
  )
}

///|
test "api v5 batch create queued" {
  @export_job_batch_v5.reset_for_test()
  let req : ApiRequest = {
    http_method: "POST",
    path: "/v5/export/batch/jobs",
    query: query_map([]),
    body: Some(
      "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
    ),
  }
  let res = handle_request(req)
  expect_response_json(res, "fixtures/v5/batch/create/case_001.response.json")
}

///|
test "api v5 batch get queued" {
  @export_job_batch_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"csv\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs/job-1/cancel",
      query: query_map([]),
      body: None,
    }),
  )
  let res = handle_request({
    http_method: "GET",
    path: "/v5/export/batch/jobs/job-1/result",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/batch/result/case_canceled.response.json",
  )
}

///|
test "api v5 batch result expired" {
  @export_job_batch_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  expect_response_json(
    res, "fixtures/v5/batch/result/case_expired.response.json",
  )
}

///|
test "api v5 batch get expired" {
  @export_job_batch_v5.reset_for_test()
  ignore(
    handle_request({
      http_method: "POST",
      path: "/v5/export/batch/jobs",
      query: query_map([]),
      body: Some(
        "{\"format\":\"jsonl\",\"jobs\":[{\"entityId\":\"order-1\",\"fromLogicalTime\":10,\"toLogicalTime\":12},{\"entityId\":\"order-2\",\"fromLogicalTime\":20,\"toLogicalTime\":22}]}",
      ),
    }),
  )
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
  expect_response_json(
    res, "fixtures/v5/batch/get/case_not_found.response.json",
  )
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
  expect_response_json(
    res, "fixtures/v5/batch/result/case_not_found.response.json",
  )
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
  expect_response_json(
    res, "fixtures/v5/batch/create/case_invalid.response.json",
  )
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
  expect_response_json(
    res, "fixtures/v5/batch/create/case_missing_jobs.response.json",
  )
}

///|
test "api v5 observability metrics summary" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/metrics/summary",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/observability/metrics_summary/case_001.response.json",
  )
}

///|
test "api v5 observability export audit" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/export/audit",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/observability/export_audit/case_001.response.json",
  )
}

///|
test "api v5 observability export audit excludes query payload" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/export/audit",
    query: query_map([]),
    body: None,
  })
  expect_audit_no_sensitive_fields(
    res, "fixtures/v5/observability/export_audit/case_forbidden_fields.response.json",
  )
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
  expect_response_json(
    res, "fixtures/v5/policy/check/case_missing_action.response.json",
  )
}

///|
test "api v5 policy invalid action type" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: Some("{\"action\":1}"),
  })
  expect_response_json(
    res, "fixtures/v5/policy/check/case_invalid_action.response.json",
  )
}

///|
test "api v5 policy missing body" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5/policy/check",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5/policy/check/case_missing_body.response.json",
  )
}

///|
test "api v5.1 retry clean start" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5.1/export/jobs/job-7/retry",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/retry_resume/case_retry_clean_start.response.json",
  )
}

///|
test "api v5.1 resume from cursor" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5.1/export/jobs/job-8/resume",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/retry_resume/case_resume_from_cursor.response.json",
  )
}

///|
test "api v5.1 partial resume" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5.1/export/jobs/job-9/resume/partial",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/retry_resume/case_partial_resume.response.json",
  )
}

///|
test "api v5.1 rollback metadata only" {
  let res = handle_request({
    http_method: "POST",
    path: "/v5.1/export/batch/jobs/batch-3/rollback",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/rollback/case_rollback_metadata_only.response.json",
  )
}

///|
test "api v5.1 retention hierarchy" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.1/retention/evaluate/hierarchy",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5_1/retention/case_hierarchy.response.json")
}

///|
test "api v5.1 retention precedence" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.1/retention/evaluate/precedence",
    query: query_map([]),
    body: None,
  })
  expect_response_json(res, "fixtures/v5_1/retention/case_precedence.response.json")
}

///|
test "api v5.1 retention post expiry visibility" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.1/retention/evaluate/post-expiry-visibility",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/retention/case_post_expiry_visibility.response.json",
  )
}

///|
test "api v5.1 observability job view" {
  let job : @export_job_v5.JobRecord = {
    id: { value: "job-11" },
    status: @export_job_v5.JobStatus::Queued,
    progress: { processed: 0, total: 3 },
    retention: {
      axis: @export_job_v5.RetentionAxis::PollCount,
      ttl_polls: 3,
      ttl_seconds: 120,
    },
    format: @export_job_v5.ResultFormat::Jsonl,
    reasons: [],
    poll_count: 0,
  }
  @job_store_v5.seed_for_test(12, [job])
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/views/job/job-11",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/views_optional/case_job_view.response.json",
  )
}

///|
test "api v5.1 observability batch view" {
  let batch : @export_job_batch_v5.BatchJobRecord = {
    id: "batch-11",
    child_ids: ["job-111", "job-112"],
    child_specs: [],
    status: @export_job_v5.JobStatus::Queued,
    progress: { processed: 0, total: 2 },
    retention: {
      axis: @export_job_v5.RetentionAxis::PollCount,
      ttl_polls: 6,
      ttl_seconds: 240,
    },
    format: @export_job_v5.ResultFormat::Jsonl,
    reasons: [],
    poll_count: 0,
    next_child_index: 0,
  }
  @export_job_batch_v5.seed_for_test(12, [batch])
  let res = handle_request({
    http_method: "GET",
    path: "/v5/observability/views/batch/batch-11",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res, "fixtures/v5_1/views_optional/case_batch_view.response.json",
  )
}

///|
test "api v5.2 retention multi-axis poll wins" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":5,\"ttlSeconds\":120},{\"axis\":\"logical_time\",\"threshold\":100,\"ttlSeconds\":300}],\"currentPollCount\":6,\"currentLogicalTime\":50}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_2/retention/case_multi_axis_poll_wins.response.json",
  )
}

///|
test "api v5.2 retention multi-axis logical time wins" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":10,\"ttlSeconds\":240},{\"axis\":\"logical_time\",\"threshold\":50,\"ttlSeconds\":150}],\"currentPollCount\":3,\"currentLogicalTime\":55}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_2/retention/case_multi_axis_logical_time_wins.response.json",
  )
}

///|
test "api v5.2 retention multi-axis both expired" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":3,\"ttlSeconds\":60},{\"axis\":\"logical_time\",\"threshold\":20,\"ttlSeconds\":60}],\"currentPollCount\":5,\"currentLogicalTime\":25}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_2/retention/case_multi_axis_both_expired.response.json",
  )
}

///|
test "api v5.2 retention multi-axis none expired" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":10,\"ttlSeconds\":240},{\"axis\":\"logical_time\",\"threshold\":100,\"ttlSeconds\":300}],\"currentPollCount\":2,\"currentLogicalTime\":30}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_2/retention/case_multi_axis_none_expired.response.json",
  )
}

///|
test "api v5.2 retention single axis poll count" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":5,\"ttlSeconds\":120}],\"currentPollCount\":7,\"currentLogicalTime\":0}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_2/retention/case_single_axis_poll_count.response.json",
  )
}

///|
test "api v5.2 retention single axis logical time" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.2/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"logical_time\",\"threshold\":50,\"ttlSeconds\":150}],\"currentPollCount\":0,\"currentLogicalTime\":60}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_2/retention/case_single_axis_logical_time.response.json",
  )
}

///|
test "api v5.3 retention multi-axis poll wins" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":5,\"ttlSeconds\":120},{\"axis\":\"logical_time\",\"threshold\":100,\"ttlSeconds\":300},{\"axis\":\"event_count\",\"threshold\":1000,\"ttlSeconds\":600}],\"currentPollCount\":6,\"currentLogicalTime\":50,\"currentEventCount\":200}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_multi_axis_poll_wins.response.json",
  )
}

///|
test "api v5.3 retention multi-axis logical time wins" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":10,\"ttlSeconds\":240},{\"axis\":\"logical_time\",\"threshold\":50,\"ttlSeconds\":150},{\"axis\":\"event_count\",\"threshold\":1000,\"ttlSeconds\":600}],\"currentPollCount\":3,\"currentLogicalTime\":55,\"currentEventCount\":200}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_multi_axis_logical_time_wins.response.json",
  )
}

///|
test "api v5.3 retention multi-axis event count wins" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":10,\"ttlSeconds\":240},{\"axis\":\"logical_time\",\"threshold\":100,\"ttlSeconds\":300},{\"axis\":\"event_count\",\"threshold\":500,\"ttlSeconds\":600}],\"currentPollCount\":3,\"currentLogicalTime\":30,\"currentEventCount\":600}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_multi_axis_event_count_wins.response.json",
  )
}

///|
test "api v5.3 retention multi-axis all three expired" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":3,\"ttlSeconds\":60},{\"axis\":\"logical_time\",\"threshold\":20,\"ttlSeconds\":60},{\"axis\":\"event_count\",\"threshold\":10,\"ttlSeconds\":60}],\"currentPollCount\":5,\"currentLogicalTime\":25,\"currentEventCount\":15}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_multi_axis_all_three_expired.response.json",
  )
}

///|
test "api v5.3 retention multi-axis none expired" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":10,\"ttlSeconds\":240},{\"axis\":\"logical_time\",\"threshold\":100,\"ttlSeconds\":300},{\"axis\":\"event_count\",\"threshold\":1000,\"ttlSeconds\":600}],\"currentPollCount\":2,\"currentLogicalTime\":30,\"currentEventCount\":200}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_multi_axis_none_expired.response.json",
  )
}

///|
test "api v5.3 retention single axis poll count" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"poll_count\",\"threshold\":5,\"ttlSeconds\":120}],\"currentPollCount\":7,\"currentLogicalTime\":0,\"currentEventCount\":0}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_single_axis_poll_count.response.json",
  )
}

///|
test "api v5.3 retention single axis logical time" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"logical_time\",\"threshold\":50,\"ttlSeconds\":150}],\"currentPollCount\":0,\"currentLogicalTime\":60,\"currentEventCount\":0}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_single_axis_logical_time.response.json",
  )
}

///|
test "api v5.3 retention single axis event count" {
  let res = handle_request({
    http_method: "GET",
    path: "/v5.3/retention/evaluate/multi-axis",
    query: query_map([]),
    body: Some(
      "{\"policies\":[{\"axis\":\"event_count\",\"threshold\":500,\"ttlSeconds\":600}],\"currentPollCount\":0,\"currentLogicalTime\":0,\"currentEventCount\":600}",
    ),
  })
  expect_response_json(
    res,
    "fixtures/v5_3/retention/case_single_axis_event_count.response.json",
  )
}

///|
test "api v5.4 timeline normal lifecycle" {
  @job_store_v5_4.reset_for_test()
  let policies : Array[@retention_v5_3.RetentionPolicyV53] = [
    {
      axis: @retention_v5_3.RetentionAxisV53::PollCount,
      threshold: 10,
      ttl_seconds: 120,
    },
  ]
  let job = @job_store_v5_4.create_job(@export_job_v5.ResultFormat::Jsonl, policies)
  // step: queued → running
  ignore(@job_store_v5_4.step_job(job.id.value))
  // step: running → done
  ignore(@job_store_v5_4.step_job(job.id.value))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.4/export/jobs/" + job.id.value + "/timeline",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_4/timeline/case_normal_lifecycle.response.json",
  )
}

///|
test "api v5.4 timeline canceled" {
  @job_store_v5_4.reset_for_test()
  let policies : Array[@retention_v5_3.RetentionPolicyV53] = [
    {
      axis: @retention_v5_3.RetentionAxisV53::PollCount,
      threshold: 10,
      ttl_seconds: 120,
    },
  ]
  let job = @job_store_v5_4.create_job(@export_job_v5.ResultFormat::Jsonl, policies)
  // step: queued → running
  ignore(@job_store_v5_4.step_job(job.id.value))
  // cancel: running → canceled
  ignore(@job_store_v5_4.cancel_job(job.id.value))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.4/export/jobs/" + job.id.value + "/timeline",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_4/timeline/case_canceled.response.json",
  )
}

///|
test "api v5.4 timeline expired" {
  @job_store_v5_4.reset_for_test()
  // Set low threshold so job expires quickly
  let policies : Array[@retention_v5_3.RetentionPolicyV53] = [
    {
      axis: @retention_v5_3.RetentionAxisV53::PollCount,
      threshold: 2,
      ttl_seconds: 60,
    },
  ]
  let job = @job_store_v5_4.create_job(@export_job_v5.ResultFormat::Jsonl, policies)
  // step: queued → running (poll_count=1 < threshold=2)
  ignore(@job_store_v5_4.step_job(job.id.value))
  // step: running → expired (poll_count=2 >= threshold=2)
  ignore(@job_store_v5_4.step_job(job.id.value))
  let res = handle_request({
    http_method: "GET",
    path: "/v5.4/export/jobs/" + job.id.value + "/timeline",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_4/timeline/case_expired.response.json",
  )
}

///|
test "api v5.4 timeline job not found" {
  @job_store_v5_4.reset_for_test()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.4/export/jobs/job-999/timeline",
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_4/timeline/case_job_not_found.response.json",
  )
}

///|
fn setup_v5_5_3_event_job() -> String {
  @job_store_v5_4.reset_for_test()
  let policies : Array[@retention_v5_3.RetentionPolicyV53] = [
    {
      axis: @retention_v5_3.RetentionAxisV53::PollCount,
      threshold: 10,
      ttl_seconds: 120,
    },
  ]
  let job = @job_store_v5_4.create_job(
    @export_job_v5.ResultFormat::Jsonl,
    policies,
  )
  // step: queued → running
  ignore(@job_store_v5_4.step_job(job.id.value))
  // step: running → done
  ignore(@job_store_v5_4.step_job(job.id.value))
  job.id.value
}

///|
test "api v5.5 paginated page 1" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("limit", "2")]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_5/timeline/case_page1.response.json",
  )
}

///|
test "api v5.5 paginated page 2" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("limit", "2"), ("cursor", "offset:2")]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_5/timeline/case_page2.response.json",
  )
}

///|
test "api v5.5 filtered by logical time" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("fromLogicalTime", "1"), ("toLogicalTime", "1")]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_5/timeline/case_filtered.response.json",
  )
}

///|
test "api v5.5 JSONL export" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline/export",
    query: query_map([]),
    body: None,
  })
  inspect(res.status, content="200")
  let expected = match read_text_api(
    "fixtures/v5_5/timeline/case_export.response.jsonl",
    "expected",
  ) {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
  inspect(res.body, content=expected)
}

///|
test "api v5.5 invalid cursor" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("cursor", "bad-cursor")]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_5/timeline/case_invalid_cursor.response.json",
  )
}

///|
fn expect_response_html(
  res : ApiResponse,
  expected_path : String,
) -> Unit raise {
  let expected = load_expected(expected_path)
  inspect(res.status, content="200")
  inspect(
    res.headers.get("content-type"),
    content="Some(\"text/html\")",
  )
  let mut body = res.body
  if expected.has_suffix("\n") {
    body = body + "\n"
  }
  inspect(body, content=expected)
}

///|
test "api v5.6 single job timeline html" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("limit", "2"), ("format", "html")]),
    body: None,
  })
  expect_response_html(
    res,
    "fixtures/v5_6/timeline/page1_expected.html",
  )
}

///|
test "api v5.6 single job timeline mx" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("limit", "2"), ("format", "mx")]),
    body: None,
  })
  inspect(res.status, content="200")
  inspect(
    res.headers.get("content-type"),
    content="Some(\"text/html\")",
  )
  // MX response should contain mx-target and mx-get
  inspect(res.body.contains("mx-target"), content="true")
  inspect(res.body.contains("mx-get"), content="true")
}

///|
test "api v5.6 single job timeline page2 html" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([
      ("limit", "2"),
      ("cursor", "offset:2"),
      ("format", "html"),
    ]),
    body: None,
  })
  expect_response_html(
    res,
    "fixtures/v5_6/timeline/page2_expected.html",
  )
}

///|
test "api v5.6 single job timeline filtered html" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([
      ("fromLogicalTime", "1"),
      ("toLogicalTime", "1"),
      ("format", "html"),
    ]),
    body: None,
  })
  expect_response_html(
    res,
    "fixtures/v5_6/timeline/filtered_expected.html",
  )
}

///|
test "api v5.6 no format falls back to json" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("limit", "2")]),
    body: None,
  })
  inspect(res.status, content="200")
  inspect(
    res.headers.get("content-type"),
    content="Some(\"application/json\")",
  )
}

///|
test "api v5.7 event detail json" {
  let job_id = setup_v5_5_3_event_job()
  let event_id = job_id + ":1:1:status_change"
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/" + event_id,
    query: query_map([]),
    body: None,
  })
  expect_response_json(
    res,
    "fixtures/v5_7/timeline/case_detail.response.json",
  )
}

///|
test "api v5.7 event detail html" {
  let job_id = setup_v5_5_3_event_job()
  let event_id = job_id + ":1:1:status_change"
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/" + event_id,
    query: query_map([("format", "html")]),
    body: None,
  })
  expect_response_html(
    res,
    "fixtures/v5_7/timeline/detail_expected.html",
  )
}

///|
test "api v5.7 event detail mx" {
  let job_id = setup_v5_5_3_event_job()
  let event_id = job_id + ":1:1:status_change"
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/" + event_id,
    query: query_map([("format", "mx")]),
    body: None,
  })
  inspect(res.status, content="200")
  inspect(
    res.headers.get("content-type"),
    content="Some(\"text/html\")",
  )
  inspect(res.body.contains("mx-target"), content="true")
  inspect(res.body.contains("mx-get"), content="true")
}

///|
test "api v5.7 event detail first event html" {
  let job_id = setup_v5_5_3_event_job()
  let event_id = job_id + ":0:1:status_change"
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/" + event_id,
    query: query_map([("format", "html")]),
    body: None,
  })
  expect_response_html(
    res,
    "fixtures/v5_7/timeline/detail_first_expected.html",
  )
}

///|
test "api v5.7 event detail last event html" {
  let job_id = setup_v5_5_3_event_job()
  let event_id = job_id + ":2:1:status_change"
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/" + event_id,
    query: query_map([("format", "html")]),
    body: None,
  })
  expect_response_html(
    res,
    "fixtures/v5_7/timeline/detail_last_expected.html",
  )
}

///|
test "api v5.7 event not found" {
  let job_id = setup_v5_5_3_event_job()
  let event_id = job_id + ":99:1:status_change"
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/" + event_id,
    query: query_map([]),
    body: None,
  })
  inspect(res.status, content="404")
}

///|
test "api v5.7 invalid event id" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.7/export/jobs/" + job_id + "/timeline/event/bad-id",
    query: query_map([]),
    body: None,
  })
  inspect(res.status, content="400")
}

///|
test "api v5.7 kind filter status_change" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("kind", "status_change"), ("limit", "10")]),
    body: None,
  })
  inspect(res.status, content="200")
  inspect(
    res.headers.get("content-type"),
    content="Some(\"application/json\")",
  )
}

///|
test "api v5.7 kind filter invalid" {
  let job_id = setup_v5_5_3_event_job()
  let res = handle_request({
    http_method: "GET",
    path: "/v5.5/export/jobs/" + job_id + "/timeline",
    query: query_map([("kind", "unknown_kind")]),
    body: None,
  })
  inspect(res.status, content="400")
}
