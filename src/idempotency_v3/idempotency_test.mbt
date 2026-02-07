///|
fn read_text_idempotency(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_idempotency(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
test "idempotency reserve fixture" {
  let expected = load_expected("examples/v3/idempotency/expected_reserved.json")
  let store = new_store()
  let decision = reserve(store, "k1", 10)
  let mut output = decision_json(decision).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "idempotency conflict fixture" {
  let expected = load_expected("examples/v3/idempotency/expected_duplicate.json")
  let store = new_store()
  ignore(reserve(store, "k1", 10))
  let decision = reserve(store, "k1", 11)
  let mut output = decision_json(decision).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "idempotency done fixture" {
  let expected = load_expected("examples/v3/idempotency/expected_done.json")
  let store = new_store()
  ignore(reserve(store, "k1", 10))
  let decision = mark_done(store, "k1", "exec-1", 12)
  let mut output = decision_json(decision).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
