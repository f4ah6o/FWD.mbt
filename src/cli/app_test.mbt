///|
test "run validate" {
  inspect(run(["validate", "examples/schema_v1.yaml"]), content="0")
}

///|
fn read_text_cli(path : String, label : String) -> String raise {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => text
    Err(err) => fail("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn write_text_cli(path : String, text : String, label : String) -> Unit raise {
  let result : Result[Unit, @fs.IOError] = try? @fs.write_string_to_file(
    path, text,
  )
  match result {
    Ok(_) => ()
    Err(err) => fail("write failed: " + label + ": " + err.to_string())
  }
}

///|
fn remove_file_cli(path : String) -> Unit {
  let result : Result[Unit, @fs.IOError] = try? @fs.remove_file(path)
  ignore(result)
}

///|
fn dslx_example_ir_json_cli() -> String raise {
  let input = read_text_cli("examples/schema.dsl", "dslx example")
  match @compiler.compile_dslx_l1(input) {
    Ok(ir) => @compiler.ir_to_json(ir).stringify(indent=2)
    Err(err) => fail(@compiler.describe_error(err))
  }
}

///|
test "run compile dslx writes ir json" {
  let output_path = ".mooncakes/dslx_cli_app_test_output.json"
  remove_file_cli(output_path)
  inspect(
    run(["compile-dslx", "examples/schema.dsl", output_path]),
    content="0",
  )
  let output = read_text_cli(output_path, "dslx cli output")
  inspect(output, content=dslx_example_ir_json_cli())
  remove_file_cli(output_path)
}

///|
test "run validate dslx" {
  inspect(run(["validate-dslx", "examples/schema.dsl"]), content="0")
}

///|
test "run validate dslx json output" {
  let ok_json = @compiler.validation_json_string(true, [])
  inspect(run(["validate-dslx", "examples/schema.dsl", "--json"]), content="0")
  assert_true(ok_json.contains("\"ok\": true"))
}

///|
test "run validate dslx failure" {
  let input_path = ".mooncakes/dslx_cli_app_test_invalid.dsl"
  remove_file_cli(input_path)
  write_text_cli(
    input_path,
    (
      #|schema Schema
      #|state Draft
      #|state Released
      #|entity Schema { title:text }
      #|transition submit: Draft -> Released { effect notify }
    ),
    "invalid dslx",
  )
  inspect(run(["validate-dslx", input_path]), content="1")
  remove_file_cli(input_path)
}

///|
test "run validate examples" {
  inspect(
    run(["validate", "examples/fwd_schema_change_valid.yaml"]),
    content="0",
  )
  inspect(run(["validate", "examples/effects_v1.yaml"]), content="0")
  inspect(
    run(["validate", "examples/fwd_schema_change_invalid.yaml"]),
    content="1",
  )
  inspect(run(["validate", "examples/conflicting_rule.yaml"]), content="1")
  inspect(
    run(["validate", "examples/fwd_schema_change_valid.yaml", "--json"]),
    content="0",
  )
}

///|
test "run validate baseline" {
  inspect(
    run([
      "validate", "examples/remove-state.yaml", "--baseline", "examples/fwd_schema_change_valid.yaml",
    ]),
    content="1",
  )
  inspect(
    run([
      "validate", "examples/remove-transition.yaml", "--baseline", "examples/fwd_schema_change_valid.yaml",
    ]),
    content="1",
  )
  inspect(
    run([
      "validate", "examples/remove-transition-with-migration.yaml", "--baseline",
      "examples/fwd_schema_change_valid.yaml",
    ]),
    content="1",
  )
  inspect(
    run([
      "validate", "examples/remove-state-with-migration.yaml", "--baseline", "examples/fwd_schema_change_valid.yaml",
    ]),
    content="1",
  )
  inspect(
    run([
      "validate", "examples/modify-transition.yaml", "--baseline", "examples/fwd_schema_change_valid.yaml",
      "--format", "json",
    ]),
    content="1",
  )
  inspect(
    run([
      "validate", "examples/modify-transition-with-migration.yaml", "--baseline",
      "examples/fwd_schema_change_valid.yaml",
    ]),
    content="1",
  )
}

///|
test "run validate json output" {
  let ok_json = @compiler.validation_json_string(true, [])
  inspect(run(["validate", "examples/schema_v1.yaml", "--json"]), content="0")
  assert_true(ok_json.contains("\"ok\": true"))
  let reasons : Array[@core.Reason] = []
  reasons.push(
    @core.Reason::new("ValidationFailure", "states must not be empty"),
  )
  let err_json = @compiler.validation_json_string(false, reasons)
  inspect(run(["validate", "examples/invalid_min.yaml", "--json"]), content="1")
  assert_true(err_json.contains("\"ok\": false"))
  assert_true(err_json.contains("\"errorCount\": 1"))
  assert_true(err_json.contains("\"reasonVersion\": 1"))
  assert_true(err_json.contains("\"code\": \"VALIDATION_FAILURE\""))
  assert_true(err_json.contains("\"level\": \"error\""))
  assert_true(err_json.contains("\"target\": \"schema\""))
}

///|
test "run presets" {
  inspect(run(["presets"]), content="0")
}

///|
test "run runtime invalid input" {
  inspect(
    run([
      "runtime", "available", "examples/runtime_available/model.yaml", "--state",
      "Draft", "--input", "true",
    ]),
    content="2",
  )
}

///|
test "run runtime execute" {
  inspect(
    run([
      "runtime", "execute", "examples/runtime_execute/model.yaml", "--state", "Draft",
      "--transition", "approve", "--input", "{\"rules\": {\"canApprove\": true, \"canReject\": false}}",
    ]),
    content="0",
  )
}

///|
test "run runtime execute invalid input" {
  inspect(
    run([
      "runtime", "execute", "examples/runtime_execute/model.yaml", "--state", "Draft",
      "--transition", "approve", "--input", "true",
    ]),
    content="2",
  )
}

///|
test "run runtime execute not found" {
  inspect(
    run([
      "runtime", "execute", "examples/runtime_execute/model.yaml", "--state", "Draft",
      "--transition", "missing", "--input", "{\"rules\": {\"canApprove\": true, \"canReject\": false}}",
    ]),
    content="1",
  )
}

///|
test "run runtime execute not available" {
  inspect(
    run([
      "runtime", "execute", "examples/runtime_execute/model.yaml", "--state", "Approved",
      "--transition", "reject", "--input", "{\"rules\": {\"canApprove\": true, \"canReject\": false}}",
    ]),
    content="1",
  )
}

///|
test "run hypermedia show fixture" {
  inspect(
    run([
      "hypermedia", "show", "examples/hypermedia_show/model.yaml", "--state", "Draft",
      "--input", "{\"rules\": {\"canApprove\": true, \"canReject\": false}}",
    ]),
    content="0",
  )
}

///|
test "run hypermedia invalid input" {
  inspect(
    run([
      "hypermedia", "show", "examples/hypermedia_show/model.yaml", "--state", "Draft",
      "--input", "true",
    ]),
    content="2",
  )
}

///|
test "run effects plan planned" {
  inspect(
    run([
      "effects", "plan", "examples/effects_v2_2/model.yaml", "--entity", "order-1",
      "--state", "Draft", "--transition", "submit", "--input", "{\"rules\": {\"canSubmit\": true}}",
    ]),
    content="0",
  )
}

///|
test "run effects plan skipped" {
  inspect(
    run([
      "effects", "plan", "examples/effects_v2_2/model.yaml", "--entity", "order-1",
      "--state", "Draft", "--transition", "submit", "--input", "{\"rules\": {\"canSubmit\": false}}",
    ]),
    content="0",
  )
}

///|
test "run effects plan invalid input" {
  inspect(
    run([
      "effects", "plan", "examples/effects_v2_2/model.yaml", "--entity", "order-1",
      "--state", "Draft", "--transition", "submit", "--input", "true",
    ]),
    content="2",
  )
}

///|
test "run effects plan not found" {
  inspect(
    run([
      "effects", "plan", "examples/effects_v2_2/model.yaml", "--entity", "order-1",
      "--state", "Draft", "--transition", "missing", "--input", "{\"rules\": {\"canSubmit\": true}}",
    ]),
    content="1",
  )
}

///|
test "run effects execute executed" {
  let plan = read_text_cli(
    "examples/effects_v2_2/execute/plan_planned.json", "plan",
  )
  inspect(run(["effects", "execute", "--plan", plan]), content="0")
}

///|
test "run effects execute skipped" {
  let plan = read_text_cli(
    "examples/effects_v2_2/execute/plan_skipped.json", "plan",
  )
  inspect(run(["effects", "execute", "--plan", plan]), content="0")
}

///|
test "run effects execute invalid input" {
  inspect(run(["effects", "execute", "--plan", "true"]), content="2")
}

///|
test "run effects run with cassette" {
  inspect(
    run([
      "effects", "run", "--plan", "examples/effects_v2_2/record_cli/plan.json", "--config",
      "examples/effects_v2_2/real_runner/config.json", "--cassette", "examples/effects_v2_2/record_cli/expected_cassette.json",
    ]),
    content="0",
  )
}
