///|
fn read_text_retry(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_retry(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
test "retry policy fixed schedule fixture" {
  let expected = load_expected("examples/v3/retry_policy/expected_fixed.json")
  let policy : RetryPolicy = {
    policy_version: policy_version_v3(),
    max_attempts: 3,
    backoff: {
      kind: BackoffKind::Fixed,
      delay_ms: 1000,
      factor: 1,
    },
  }
  let mut output = retry_policy_schedule_json(policy).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "retry policy exponential schedule fixture" {
  let expected = load_expected("examples/v3/retry_policy/expected_exponential.json")
  let policy : RetryPolicy = {
    policy_version: policy_version_v3(),
    max_attempts: 4,
    backoff: {
      kind: BackoffKind::Exponential,
      delay_ms: 500,
      factor: 2,
    },
  }
  let mut output = retry_policy_schedule_json(policy).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
