///|
fn read_text_api_v6(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected_api_v6(path : String) -> String raise {
  match read_text_api_v6(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
fn assert_api_v6_body(output : String, expected : String) -> Unit raise {
  let mut body = output
  if expected.has_suffix("\n") {
    body = body + "\n"
  }
  inspect(body, content=expected)
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
fn valid_preview_body() -> String {
  "entity_name=Request&initial_state=Draft&state_0=Draft&state_1=Approved&state_2=Rejected&transition_0_name=approve&transition_0_from=Draft&transition_0_to=Approved&transition_1_name=reject&transition_1_from=Draft&transition_1_to=Rejected&transition_2_name=&transition_2_from=&transition_2_to="
}

///|
fn invalid_preview_body() -> String {
  "entity_name=Request&initial_state=Draft&state_0=Draft&state_1=&state_2=&transition_0_name=approve&transition_0_from=Draft&transition_0_to=Approved&transition_1_name=&transition_1_from=&transition_1_to=&transition_2_name=&transition_2_from=&transition_2_to="
}

///|
test "api v6 workbench html" {
  let expected = load_expected_api_v6("examples/workbench_v6/expected.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v6/workbench",
    query: Map::new(),
    body: None,
  }
  let resp = handle_request(req)
  inspect(resp.status, content="200")
  assert_api_v6_body(resp.body, expected)
}

///|
test "api v6 workbench mx" {
  let expected = load_expected_api_v6("examples/workbench_v6/expected_mx.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v6/workbench",
    query: make_query([("format", "mx")]),
    body: None,
  }
  let resp = handle_request(req)
  inspect(resp.status, content="200")
  assert_api_v6_body(resp.body, expected)
}

///|
test "api v6 preview valid form body" {
  let expected = load_expected_api_v6("examples/workbench_v6/expected.html")
  let req : ApiRequest = {
    http_method: "POST",
    path: "/v6/workbench/preview",
    query: Map::new(),
    body: Some(valid_preview_body()),
  }
  let resp = handle_request(req)
  inspect(resp.status, content="200")
  assert_api_v6_body(resp.body, expected)
}

///|
test "api v6 preview invalid builder" {
  let expected = load_expected_api_v6(
    "examples/workbench_v6/expected_invalid.html",
  )
  let req : ApiRequest = {
    http_method: "POST",
    path: "/v6/workbench/preview",
    query: Map::new(),
    body: Some(invalid_preview_body()),
  }
  let resp = handle_request(req)
  inspect(resp.status, content="200")
  assert_api_v6_body(resp.body, expected)
}
