///|
fn read_text_export_v4_3(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected_export_v4_3(path : String) -> String raise {
  match read_text_export_v4_3(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn build_snapshot_v4_3() -> @metrics_v3_6.MetricsSnapshot {
  {
    window: {
      entity_id: "order-1",
      from_logical_time: Some(10),
      to_logical_time: Some(12),
    },
    total: {
      ok: 1,
      failed: 1,
      blocked: 0,
      denied: 1,
    },
    by_kind: [
      {
        kind: @metrics_v3_6.MetricKind::Transition,
        counts: { ok: 1, failed: 0, blocked: 0, denied: 0 },
      },
      {
        kind: @metrics_v3_6.MetricKind::Policy,
        counts: { ok: 0, failed: 0, blocked: 0, denied: 1 },
      },
      {
        kind: @metrics_v3_6.MetricKind::Effect,
        counts: { ok: 0, failed: 1, blocked: 0, denied: 0 },
      },
    ],
  }
}

///|
test "metrics export v4.3 jsonl" {
  let expected = load_expected_export_v4_3("examples/v4_3/metrics_export/expected.jsonl")
  let mut output = export_jsonl(build_snapshot_v4_3())
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "metrics export v4.3 csv" {
  let expected = load_expected_export_v4_3("examples/v4_3/metrics_export/expected.csv")
  let mut output = export_csv(build_snapshot_v4_3())
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
