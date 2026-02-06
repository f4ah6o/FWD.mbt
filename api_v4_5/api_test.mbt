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
test "api v4.5 metrics export jsonl" {
  let expected = load_expected("examples/api_v4_5/metrics_export/expected.jsonl")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/metrics/export.jsonl",
    query: query_map([("entityId", "order-1"), ("fromLogicalTime", "10"), ("toLogicalTime", "12")]),
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
test "api v4.5 metrics export csv" {
  let expected = load_expected("examples/api_v4_5/metrics_export/expected.csv")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/metrics/export.csv",
    query: query_map([("entityId", "order-1"), ("fromLogicalTime", "10"), ("toLogicalTime", "12")]),
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
test "api v4.5 metrics export invalid query" {
  let expected = load_expected("examples/api_v4_5/metrics_export/expected_invalid_query.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/metrics/export.jsonl",
    query: query_map([]),
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
test "api v4.5 timeline export page1 jsonl" {
  let expected = load_expected("examples/api_v4_5/timeline_export/expected_page1.jsonl")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/timeline/export.jsonl",
    query: query_map([("entityId", "order-1"), ("limit", "2")]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
  inspect(res.headers.get("x-next-cursor"), content="Some(\"offset:2\")")
}

///|
test "api v4.5 timeline export page2 jsonl" {
  let expected = load_expected("examples/api_v4_5/timeline_export/expected_page2.jsonl")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/timeline/export.jsonl",
    query: query_map([("entityId", "order-1"), ("limit", "2"), ("cursor", "offset:2")]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
  inspect(res.headers.get("x-next-cursor"), content="None")
}

///|
test "api v4.5 timeline export invalid cursor" {
  let expected = load_expected("examples/api_v4_5/timeline_export/expected_invalid_cursor.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/timeline/export.jsonl",
    query: query_map([("entityId", "order-1"), ("cursor", "bad")]),
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
test "api v4.5 timeline export invalid query" {
  let expected = load_expected("examples/api_v4_5/timeline_export/expected_invalid_query.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4.5/timeline/export.jsonl",
    query: query_map([]),
    body: None,
  }
  let res = handle_request(req)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
