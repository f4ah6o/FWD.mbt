///|
fn read_text_metrics(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_metrics(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
test "metrics json fixture" {
  let expected = load_expected("examples/v3_6/metrics/expected.json")
  let snapshot : MetricsSnapshot = {
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
        kind: MetricKind::Transition,
        counts: { ok: 1, failed: 0, blocked: 0, denied: 0 },
      },
      {
        kind: MetricKind::Policy,
        counts: { ok: 0, failed: 0, blocked: 0, denied: 1 },
      },
      {
        kind: MetricKind::Effect,
        counts: { ok: 0, failed: 1, blocked: 0, denied: 0 },
      },
    ],
  }
  let mut output = metrics_json(snapshot).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
