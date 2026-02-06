///|
fn read_text_export_v4_5(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected_export_v4_5(path : String) -> String raise {
  match read_text_export_v4_5(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn build_snapshot_v4_5() -> @metrics_v3_6.MetricsSnapshot {
  @metrics_snapshot_v4_5.build_snapshot("order-1", Some(10), Some(12))
}

///|
test "metrics export v4.5 jsonl" {
  let expected = load_expected_export_v4_5("examples/v4_5/metrics_export/expected.jsonl")
  let mut output = export_jsonl(build_snapshot_v4_5())
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "metrics export v4.5 csv" {
  let expected = load_expected_export_v4_5("examples/v4_5/metrics_export/expected.csv")
  let mut output = export_csv(build_snapshot_v4_5())
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
