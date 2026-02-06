///|
fn read_text_export(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_export(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn sample_events() -> Array[@timeline_v3.TimelineEvent] {
  @timeline_source_v4_5.events_for_entity("order-1")
}

///|
test "timeline export v4.5 jsonl fixture" {
  let expected = load_expected("examples/v4_5/timeline_export/expected.jsonl")
  let mut output = export_jsonl(sample_events())
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
