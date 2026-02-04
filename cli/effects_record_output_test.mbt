///|
fn read_text_record(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_record_fixture(path : String) -> String raise {
  match read_text_record(path, "fixture") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
fn fake_send(_req : @effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason] {
  Ok({ status: 200, body: "{\"ok\":true}" })
}

///|
test "effects record fixture" {
  let plan_text = load_record_fixture("examples/effects_v2_2/record_cli/plan.json")
  let expected_cassette = load_record_fixture("examples/effects_v2_2/record_cli/expected_cassette.json")
  let expected_execution = load_record_fixture("examples/effects_v2_2/record_cli/expected_execution.json")
  let plan = match @effects_v2_2.parse_plan_json(plan_text) {
    Ok(value) => value
    Err(reason) => fail(reason.message())
  }
  let (result, cassette) = @effects_exec_rr_v2_2.record_execute_plan(
    plan,
    ["https://allowed.example/"],
    fake_send,
  )
  let mut cassette_output = @effects_exec_rr_v2_2.cassette_json(cassette).stringify(indent=2)
  if expected_cassette.has_suffix("\n") {
    cassette_output = cassette_output + "\n"
  }
  inspect(cassette_output, content=expected_cassette)
  let mut exec_output = @effects_v2_2.execution_result_json(result).stringify(indent=2)
  if expected_execution.has_suffix("\n") {
    exec_output = exec_output + "\n"
  }
  inspect(exec_output, content=expected_execution)
}
