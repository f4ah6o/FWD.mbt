///|
fn read_text_workbench_view(
  path : String,
  label : String,
) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected_workbench_view(path : String) -> String raise {
  match read_text_workbench_view(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
fn assert_workbench_html(output : String, expected : String) -> Unit raise {
  let mut body = output
  if expected.has_suffix("\n") {
    body = body + "\n"
  }
  inspect(body, content=expected)
}

///|
fn invalid_builder() -> @wb.BuilderState {
  {
    entity_name: "Request",
    initial_state: "Draft",
    states: ["Draft", "", ""],
    transitions: [
      { name: "approve", from: "Draft", to: "Approved" },
      { name: "", from: "", to: "" },
      { name: "", from: "", to: "" },
    ],
  }
}

///|
test "workbench html fixture" {
  let expected = load_expected_workbench_view(
    "examples/workbench_v6/expected.html",
  )
  let output = render_workbench_html(
    @wb.evaluate_builder(@wb.default_builder()),
  )
  assert_workbench_html(output, expected)
}

///|
test "workbench mx html fixture" {
  let expected = load_expected_workbench_view(
    "examples/workbench_v6/expected_mx.html",
  )
  let output = render_workbench_html_mx(
    @wb.evaluate_builder(@wb.default_builder()),
  )
  assert_workbench_html(output, expected)
}

///|
test "workbench invalid html fixture" {
  let expected = load_expected_workbench_view(
    "examples/workbench_v6/expected_invalid.html",
  )
  let output = render_workbench_html(@wb.evaluate_builder(invalid_builder()))
  assert_workbench_html(output, expected)
}

///|
test "workbench purchase request fixture" {
  let expected = load_expected_workbench_view(
    "examples/workbench_v6/purchase_request_expected.html",
  )
  let output = render_workbench_html(
    @wb.evaluate_builder(@wb.purchase_request_builder()),
  )
  assert_workbench_html(output, expected)
}
