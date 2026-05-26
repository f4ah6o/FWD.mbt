///|
fn read_expected(path : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + path + ": " + err.to_string())
  }
}

///|
fn make_query(entries : Array[(String, String)]) -> Map[String, String] {
  let query : Map[String, String] = Map::new()
  for entry in entries {
    query[entry.0] = entry.1
  }
  query
}

///|
fn expected_body(text : String) -> String {
  if text.has_suffix("\n") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
fn snippet(text : String) -> String {
  if text.length() > 240 {
    text[:240].to_owned() + "...(truncated)"
  } else {
    text
  }
}

///|
fn check_equal(label : String, actual : String, expected : String) -> Bool {
  let expected_normalized = expected_body(expected)
  if actual == expected_normalized {
    true
  } else {
    println("mismatch: " + label)
    println("expected: " + snippet(expected_normalized))
    println("actual: " + snippet(actual))
    false
  }
}

///|
fn check_fixture(
  label : String,
  req : @api.ApiRequest,
  fixture_path : String,
) -> Bool {
  let expected = match read_expected(fixture_path) {
    Ok(text) => text
    Err(msg) => {
      println(msg)
      return false
    }
  }
  let resp = @api.handle_request(req)
  if resp.status != 200 {
    println(label + ": unexpected status " + resp.status.to_string())
    return false
  }
  check_equal(label, resp.body, expected)
}

///|
fn purchase_request_body() -> String {
  "entity_name=PurchaseRequest&initial_state=Draft&schema_status=Released&rollout_mode=shadow&state_slots=6&transition_slots=6&state_0=Draft&state_1=Submitted&state_2=ManagerApproved&state_3=FinanceApproved&state_4=Ordered&state_5=Rejected&transition_0_name=submit&transition_0_from=Draft&transition_0_to=Submitted&transition_1_name=manager_approve&transition_1_from=Submitted&transition_1_to=ManagerApproved&transition_2_name=manager_reject&transition_2_from=Submitted&transition_2_to=Rejected&transition_3_name=finance_approve&transition_3_from=ManagerApproved&transition_3_to=FinanceApproved&transition_4_name=finance_reject&transition_4_from=ManagerApproved&transition_4_to=Rejected&transition_5_name=place_order&transition_5_from=FinanceApproved&transition_5_to=Ordered"
}

///|
fn check_error(
  label : String,
  req : @api.ApiRequest,
  expected_status : Int,
  expected_code : String,
) -> Bool {
  let resp = @api.handle_request(req)
  if resp.status != expected_status {
    println(label + ": unexpected status " + resp.status.to_string())
    return false
  }
  if !resp.body.contains("\"code\": \"" + expected_code + "\"") {
    println(label + ": missing code " + expected_code)
    return false
  }
  true
}

///|
fn main {
  let mut ok = true
  ok = check_fixture(
      "default html",
      {
        http_method: "GET",
        path: "/v6/workbench",
        query: Map::new(),
        body: None,
      },
      "examples/workbench_v6/expected.html",
    ) &&
    ok
  ok = check_fixture(
      "purchase-request html",
      {
        http_method: "GET",
        path: "/v6/workbench",
        query: make_query([("case", "purchase-request")]),
        body: None,
      },
      "examples/workbench_v6/purchase_request_expected.html",
    ) &&
    ok
  ok = check_fixture(
      "purchase-request mx",
      {
        http_method: "GET",
        path: "/v6/workbench",
        query: make_query([("case", "purchase-request"), ("format", "mx")]),
        body: None,
      },
      "examples/workbench_v6/purchase_request_expected_mx.html",
    ) &&
    ok
  ok = check_fixture(
      "purchase-request preview mx",
      {
        http_method: "POST",
        path: "/v6/workbench/preview",
        query: make_query([("format", "mx")]),
        body: Some(purchase_request_body()),
      },
      "examples/workbench_v6/purchase_request_expected_mx.html",
    ) &&
    ok
  ok = check_error(
      "invalid case",
      {
        http_method: "GET",
        path: "/v6/workbench",
        query: make_query([("case", "unknown")]),
        body: None,
      },
      400,
      "CASE_INVALID",
    ) &&
    ok
  ok = check_error(
      "invalid format",
      {
        http_method: "GET",
        path: "/v6/workbench",
        query: make_query([("format", "json")]),
        body: None,
      },
      400,
      "QUERY_INVALID",
    ) &&
    ok
  if ok {
    println("workbench shadow smoke: ok")
    @sys.exit(0)
  } else {
    @sys.exit(1)
  }
}
