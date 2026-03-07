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
test "v5.4 normal lifecycle timeline" {
  reset_for_test()
  let job_id = "job-1"
  // queued → queued (creation)
  record_status_change(job_id, 0, "queued", "queued", [])
  // queued → running (step 1)
  record_status_change(job_id, 1, "queued", "running", [])
  // running → done (step 2)
  record_status_change(job_id, 2, "running", "done", [])
  let events = get_timeline(job_id)
  let actual = timeline_json(job_id, events)
  let expected = parse_expected_body(
    "fixtures/v5_4/timeline/case_normal_lifecycle.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.4 canceled timeline" {
  reset_for_test()
  let job_id = "job-1"
  // queued → queued (creation)
  record_status_change(job_id, 0, "queued", "queued", [])
  // queued → running (step 1)
  record_status_change(job_id, 1, "queued", "running", [])
  // running → canceled (cancel at same logical_time)
  let cancel_reasons : Array[@export_job_v5.ReasonV1] = [
    {
      code: @export_job_v5.ReasonCode::JobCanceled,
      level: @export_job_v5.ReasonLevel::Error,
      target: "runtime",
      message: "job canceled: job-1",
      hint: Some("Job was canceled"),
    },
  ]
  record_status_change(job_id, 1, "running", "canceled", cancel_reasons)
  let events = get_timeline(job_id)
  let actual = timeline_json(job_id, events)
  let expected = parse_expected_body(
    "fixtures/v5_4/timeline/case_canceled.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.4 expired timeline" {
  reset_for_test()
  let job_id = "job-1"
  // queued → queued (creation)
  record_status_change(job_id, 0, "queued", "queued", [])
  // queued → running (step 1)
  record_status_change(job_id, 1, "queued", "running", [])
  // running → expired (step 2, retention expired)
  let expired_reasons : Array[@export_job_v5.ReasonV1] = [
    {
      code: @export_job_v5.ReasonCode::JobExpired,
      level: @export_job_v5.ReasonLevel::Error,
      target: "runtime",
      message: "job expired: job-1",
      hint: Some("Job retention expired"),
    },
  ]
  record_status_change(job_id, 2, "running", "expired", expired_reasons)
  let events = get_timeline(job_id)
  let actual = timeline_json(job_id, events)
  let expected = parse_expected_body(
    "fixtures/v5_4/timeline/case_expired.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.4 batch timeline" {
  reset_for_test()
  let batch_id = "job-1"
  // Child job-2
  record_status_change("job-2", 0, "queued", "queued", [])
  record_status_change("job-2", 1, "queued", "running", [])
  record_status_change("job-2", 2, "running", "done", [])
  // Child job-3
  record_status_change("job-3", 0, "queued", "queued", [])
  record_status_change("job-3", 1, "queued", "running", [])
  record_status_change("job-3", 2, "running", "done", [])
  let child_ids = ["job-2", "job-3"]
  let events = get_batch_timeline(child_ids)
  let actual = batch_timeline_json(batch_id, events)
  let expected = parse_expected_body(
    "fixtures/v5_4/timeline/case_batch_timeline.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.4 empty timeline" {
  reset_for_test()
  let events = get_timeline("job-nonexistent")
  let actual = timeline_json("job-nonexistent", events)
  let expected =
    #|{
    #|  "jobVersion": "5.4",
    #|  "jobId": "job-nonexistent",
    #|  "events": []
    #|}
  inspect(actual, content=expected)
}
