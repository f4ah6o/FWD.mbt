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
    err => fail(label + ": parse failed: " + err.to_string())
  }
}

///|
test "api v4 resource json" {
  let expected = load_expected("examples/api_v4/resource/expected.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/resource",
    query: query_map([("entityId", "order-1"), ("format", "json")]),
    body: None,
  }
  let res = handle_request(req)
  let json = parse_json_or_fail(res.body, "resource")
  @canonical_v4.validate_resource(json)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v4 resource html" {
  let expected = load_expected("examples/api_v4/resource/expected.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/resource",
    query: query_map([("entityId", "order-1"), ("format", "html")]),
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
test "api v4 resource mx" {
  let expected = load_expected("examples/api_v4/resource/expected_mx.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/resource",
    query: query_map([("entityId", "order-1"), ("format", "mx")]),
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
test "api v4 timeline list json" {
  let expected = load_expected("examples/api_v4/timeline/expected.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline",
    query: query_map([("entityId", "order-1"), ("format", "json")]),
    body: None,
  }
  let res = handle_request(req)
  let json = parse_json_or_fail(res.body, "timeline list")
  @canonical_v4.validate_timeline_list(json)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v4 timeline list html" {
  let expected = load_expected("examples/api_v4/timeline/expected.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline",
    query: query_map([("entityId", "order-1"), ("format", "html")]),
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
test "api v4 timeline list mx" {
  let expected = load_expected("examples/api_v4/timeline/expected_mx.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline",
    query: query_map([("entityId", "order-1"), ("format", "mx")]),
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
test "api v4 timeline detail json" {
  let expected = load_expected("examples/api_v4/timeline_event/expected.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline/event/order-1:11:1:policy",
    query: query_map([("format", "json")]),
    body: None,
  }
  let res = handle_request(req)
  let json = parse_json_or_fail(res.body, "timeline detail")
  @canonical_v4.validate_timeline_detail(json)
  let mut output = res.body
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "api v4 timeline detail html" {
  let expected = load_expected("examples/api_v4/timeline_event/expected.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline/event/order-1:11:1:policy",
    query: query_map([("format", "html")]),
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
test "api v4 timeline detail mx" {
  let expected = load_expected("examples/api_v4/timeline_event/expected_mx.html")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline/event/order-1:11:1:policy",
    query: query_map([("format", "mx")]),
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
test "api v4 resource missing entity" {
  let expected = load_expected("examples/api_v4/resource/expected_missing_entity.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/resource",
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
test "api v4 timeline invalid cursor" {
  let expected = load_expected("examples/api_v4/timeline/expected_invalid_cursor.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline",
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
test "api v4 timeline invalid event id" {
  let expected = load_expected("examples/api_v4/timeline_event/expected_invalid_id.json")
  let req : ApiRequest = {
    http_method: "GET",
    path: "/v4/timeline/event/invalid",
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
