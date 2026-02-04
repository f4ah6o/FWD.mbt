///|
fn read_text_timeline(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_timeline(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn reason(code : String, message : String, target : String) -> @core.Reason {
  @core.Reason::with_context(
    code,
    message,
    [("target", target)],
  )
}

///|
test "timeline json fixture" {
  let expected = load_expected("examples/v3/timeline/expected.json")
  let events : Array[TimelineEvent] = [
    {
      entity_id: "order-1",
      logical_time: 12,
      sequence: 1,
      kind: TimelineKind::Effect,
      ref_id: "http:archive",
      status: "failed",
      reasons: [
        reason("EFFECT_HTTP_FAILED", "HTTP request failed", "effect"),
      ],
    },
    {
      entity_id: "order-1",
      logical_time: 10,
      sequence: 1,
      kind: TimelineKind::Transition,
      ref_id: "submit",
      status: "executed",
      reasons: [],
    },
    {
      entity_id: "order-1",
      logical_time: 11,
      sequence: 1,
      kind: TimelineKind::Policy,
      ref_id: "policy:submit",
      status: "deny",
      reasons: [
        reason("POLICY_DENY", "Policy denied execution", "transition"),
      ],
    },
  ]
  let mut output = timeline_json(events).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
