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

///|
test "api v3.3 timeline filtered html" {
  let expected = load_expected("examples/api_v3_3/timeline/expected_filtered.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v3.3/timeline",
    query: query_map([("entityId", "order-1"), ("kind", "policy"), ("limit", "2")]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v3.3 timeline page1 html" {
  let expected = load_expected("examples/api_v3_3/timeline/expected_page1.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v3.3/timeline",
    query: query_map([("entityId", "order-1"), ("limit", "2")]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v3.3 timeline page2 html" {
  let expected = load_expected("examples/api_v3_3/timeline/expected_page2.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v3.3/timeline",
    query: query_map([("entityId", "order-1"), ("limit", "2"), ("cursor", "offset:2")]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v3.3 timeline invalid query" {
  let expected = load_expected("examples/api_v3_3/timeline/expected_invalid_query.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v3.3/timeline",
    query: query_map([("entityId", "order-1"), ("kind", "invalid")]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
