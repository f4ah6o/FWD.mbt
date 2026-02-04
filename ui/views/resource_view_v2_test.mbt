///|
fn read_text_v2_view(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_resource_v2(state : String) -> @hypermedia.ResourceV2 raise {
  let schema_text = match read_text_v2_view(
    "examples/api_v2/input_form/model.yaml",
    "model",
  ) {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
  let ir = match @compiler.compile_yaml(schema_text) {
    Ok(value) => value
    Err(err) => fail(@compiler.describe_error(err))
  }
  @hypermedia.resource_v2_from_ir(ir, state)
}

///|
test "resource v2 html fixture" {
  let expected = match read_text_v2_view(
    "examples/resource_v2/expected.html",
    "expected",
  ) {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
  let resource = load_resource_v2("Draft")
  let mut output = render_resource_html_v2(resource)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "resource v2 mx fixture" {
  let expected = match read_text_v2_view(
    "examples/resource_v2/expected_mx.html",
    "expected",
  ) {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
  let resource = load_resource_v2("Draft")
  let mut output = render_resource_html_v2_mx(resource)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
