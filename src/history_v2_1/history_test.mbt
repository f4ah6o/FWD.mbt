///|
fn read_text_history(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn payload_with_note(note : String) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["note"] = Json::string(note)
  Json::object(obj)
}

///|
fn blocked_reason() -> @core.Reason {
  @core.Reason::with_context(
    "RULE_NOT_SATISFIED",
    "Rule not satisfied",
    [
      ("target", "rule"),
      ("level", "info"),
      ("hint", "Provide rule result true for this transition"),
    ],
  )
}

///|
test "history fixture" {
  let expected = match read_text_history(
    "examples/history_v2_1/expected_history.json",
    "expected history",
  ) {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
  let store = HistoryStore::new()
  ignore(store.append(
    "order-1",
    "submit",
    "Draft",
    "Approved",
    payload_with_note("ok"),
    HistoryResult::Executed,
    [],
  ))
  ignore(store.append(
    "order-1",
    "reject",
    "Approved",
    "Approved",
    payload_with_note("blocked"),
    HistoryResult::Blocked,
    [blocked_reason()],
  ))
  let events = store.get("order-1")
  let mut output = history_list_json(events).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "history empty fixture" {
  let expected = match read_text_history(
    "examples/history_v2_1/expected_empty.json",
    "expected empty",
  ) {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
  let store = HistoryStore::new()
  let events = store.get("missing")
  let mut output = history_list_json(events).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "history event ids are monotonic" {
  let store = HistoryStore::new()
  let first = store.append(
    "order-1",
    "submit",
    "Draft",
    "Approved",
    payload_with_note("ok"),
    HistoryResult::Executed,
    [],
  )
  let second = store.append(
    "order-1",
    "reject",
    "Approved",
    "Approved",
    payload_with_note("blocked"),
    HistoryResult::Blocked,
    [],
  )
  assert_true(second.event_id > first.event_id)
}
