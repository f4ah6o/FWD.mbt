///|
fn read_text_view_v3_3(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected_v3_3(path : String) -> String raise {
  match read_text_view_v3_3(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn timeline_reason_v3_3(code : String, message : String, target : String) -> @core.Reason {
  @core.Reason::with_context(
    code,
    message,
    [("target", target)],
  )
}

///|
test "timeline v3.3 html filtered fixture" {
  let expected = load_expected_v3_3("examples/api_v3_3/timeline/expected_filtered.html")
  let events : Array[@timeline_v3.TimelineEvent] = [
    {
      entity_id: "order-1",
      logical_time: 11,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Policy,
      ref_id: "policy:submit",
      status: "deny",
      reasons: [
        timeline_reason_v3_3("POLICY_DENY", "Policy denied execution", "transition"),
      ],
    },
  ]
  let mut output = render_timeline_html_v3_3(
    "order-1",
    events,
    Some("policy"),
    2,
    None,
  )
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
