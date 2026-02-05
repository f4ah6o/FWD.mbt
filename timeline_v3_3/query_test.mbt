///|
fn read_text_query(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_query(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
test "timeline cursor fixture" {
  let expected = load_expected("examples/v3_3/timeline_query/expected_cursor.json")
  let query : TimelineQuery = {
    entity_id: "order-1",
    from_logical_time: Some(10),
    to_logical_time: Some(20),
    kind: Some("policy"),
    limit: 2,
    cursor: None,
  }
  let cursor = cursor_from_query(query, 2)
  let mut output = cursor_json(cursor).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
