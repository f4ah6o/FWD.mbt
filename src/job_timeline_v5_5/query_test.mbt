///|
fn read_fixture(path : String) -> String raise {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => text
    Err(err) => fail("read fixture: " + err.to_string())
  }
}

///|
fn parse_expected_body(path : String) -> String raise {
  let text = read_fixture(path)
  let json = @json.parse(text) catch {
    err => fail("parse fixture: " + err.to_string())
  }
  let obj = match json {
    Object(m) => m
    _ => fail("expected object: " + path)
  }
  let body = match obj.get("body") {
    Some(value) => value
    None => fail("missing body: " + path)
  }
  body.stringify(indent=2)
}

///|
fn setup_3_event_timeline() -> Unit {
  @job_timeline_v5_4.reset_for_test()
  let job_id = "job-1"
  @job_timeline_v5_4.record_status_change(job_id, 0, "queued", "queued", [])
  @job_timeline_v5_4.record_status_change(
    job_id, 1, "queued", "running", [],
  )
  @job_timeline_v5_4.record_status_change(
    job_id, 2, "running", "done", [],
  )
}

///|
test "v5.5 paginated page 1" {
  setup_3_event_timeline()
  let query : JobTimelineQuery = {
    job_id: "job-1",
    from_logical_time: None,
    to_logical_time: None,
    limit: 2,
    cursor: None,
  }
  let page = match query_timeline(query) {
    Ok(p) => p
    Err(msg) => fail(msg)
  }
  let actual = paginated_timeline_json("job-1", page)
  let expected = parse_expected_body(
    "fixtures/v5_5/timeline/case_page1.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.5 paginated page 2" {
  setup_3_event_timeline()
  let query : JobTimelineQuery = {
    job_id: "job-1",
    from_logical_time: None,
    to_logical_time: None,
    limit: 2,
    cursor: Some("offset:2"),
  }
  let page = match query_timeline(query) {
    Ok(p) => p
    Err(msg) => fail(msg)
  }
  let actual = paginated_timeline_json("job-1", page)
  let expected = parse_expected_body(
    "fixtures/v5_5/timeline/case_page2.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.5 filtered by logical time" {
  setup_3_event_timeline()
  let query : JobTimelineQuery = {
    job_id: "job-1",
    from_logical_time: Some(1),
    to_logical_time: Some(1),
    limit: 10,
    cursor: None,
  }
  let page = match query_timeline(query) {
    Ok(p) => p
    Err(msg) => fail(msg)
  }
  let actual = paginated_timeline_json("job-1", page)
  let expected = parse_expected_body(
    "fixtures/v5_5/timeline/case_filtered.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.5 JSONL export" {
  setup_3_event_timeline()
  let actual = export_job_jsonl("job-1", None, None)
  let expected = read_fixture(
    "fixtures/v5_5/timeline/case_export.response.jsonl",
  )
  inspect(actual, content=expected)
}

///|
test "v5.5 invalid cursor" {
  setup_3_event_timeline()
  let query : JobTimelineQuery = {
    job_id: "job-1",
    from_logical_time: None,
    to_logical_time: None,
    limit: 2,
    cursor: Some("bad-cursor"),
  }
  let result = query_timeline(query)
  match result {
    Err(msg) => inspect(msg, content="invalid cursor format")
    Ok(_) => fail("expected error for invalid cursor")
  }
}

///|
test "v5.5 cursor encode/decode roundtrip" {
  let encoded = encode_cursor(42)
  inspect(encoded, content="offset:42")
  let decoded = decode_cursor(encoded)
  match decoded {
    Some(cursor) => inspect(cursor.offset, content="42")
    None => fail("expected valid cursor")
  }
}

///|
test "v5.5 batch paginated page 1" {
  @job_timeline_v5_4.reset_for_test()
  @job_timeline_v5_4.record_status_change(
    "job-2", 0, "queued", "queued", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-2", 1, "queued", "running", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-2", 2, "running", "done", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-3", 0, "queued", "queued", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-3", 1, "queued", "running", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-3", 2, "running", "done", [],
  )
  let page = match query_batch_timeline(
    ["job-2", "job-3"],
    None,
    None,
    2,
    None,
  ) {
    Ok(p) => p
    Err(msg) => fail(msg)
  }
  let actual = paginated_batch_timeline_json("job-1", page)
  let expected = parse_expected_body(
    "fixtures/v5_5/timeline/case_batch_page1.response.json",
  )
  inspect(actual, content=expected)
}
