///|
fn read_text_fixture(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_fixture(path : String) -> String raise {
  match read_text_fixture(path, "fixture") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn parse_json_or_fail(text : String, label : String) -> Json raise {
  try @json.parse(text) catch {
    err => fail(label + ": parse failed: " + err.to_string())
  }
}

///|
test "v4 canonical resource fixture" {
  let text = load_fixture("examples/v4/canonical/resource_expected.json")
  let json = parse_json_or_fail(text, "resource")
  validate_resource(json)
}

///|
test "v4 canonical timeline list fixture" {
  let text = load_fixture("examples/v4/canonical/timeline_list_expected.json")
  let json = parse_json_or_fail(text, "timeline list")
  validate_timeline_list(json)
}

///|
test "v4 canonical timeline detail fixture" {
  let text = load_fixture("examples/v4/canonical/timeline_detail_expected.json")
  let json = parse_json_or_fail(text, "timeline detail")
  validate_timeline_detail(json)
}

///|
test "v4 canonical effects execute fixture" {
  let text = load_fixture("examples/v4/canonical/effects_execute_expected.json")
  let json = parse_json_or_fail(text, "effects execute")
  validate_effects_execute(json)
}
