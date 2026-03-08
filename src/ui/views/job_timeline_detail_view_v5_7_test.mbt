///|
fn read_text_view_v5_7(
  path : String,
  label : String,
) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected_v5_7(path : String) -> String raise {
  match read_text_view_v5_7(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
fn make_test_detail_middle_v5_7() -> @job_timeline_v5_7.JobTimelineDetail {
  let event : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 1,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "queued",
    to_status: "running",
    reasons: [],
  }
  let prev : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 0,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "queued",
    to_status: "queued",
    reasons: [],
  }
  let next : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 2,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "running",
    to_status: "done",
    reasons: [],
  }
  { event, prev_event: Some(prev), next_event: Some(next) }
}

///|
fn make_test_detail_first_v5_7() -> @job_timeline_v5_7.JobTimelineDetail {
  let event : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 0,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "queued",
    to_status: "queued",
    reasons: [],
  }
  let next : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 1,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "queued",
    to_status: "running",
    reasons: [],
  }
  { event, prev_event: None, next_event: Some(next) }
}

///|
fn make_test_detail_last_v5_7() -> @job_timeline_v5_7.JobTimelineDetail {
  let event : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 2,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "running",
    to_status: "done",
    reasons: [],
  }
  let prev : @job_timeline_v5_4.JobTimelineEvent = {
    job_id: "job-1",
    logical_time: 1,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
    from_status: "queued",
    to_status: "running",
    reasons: [],
  }
  { event, prev_event: Some(prev), next_event: None }
}

///|
test "v5.7 detail html fixture middle" {
  let expected = load_expected_v5_7(
    "fixtures/v5_7/timeline/detail_expected.html",
  )
  let view : JobTimelineDetailView = {
    event_id: "job-1:1:1:status_change",
    base_url: "/v5.7/export/jobs/job-1/timeline/event",
    detail: make_test_detail_middle_v5_7(),
  }
  let mut output = render_job_timeline_detail_html_v5_7(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "v5.7 detail mx html fixture middle" {
  let expected = load_expected_v5_7(
    "fixtures/v5_7/timeline/detail_mx_expected.html",
  )
  let view : JobTimelineDetailView = {
    event_id: "job-1:1:1:status_change",
    base_url: "/v5.7/export/jobs/job-1/timeline/event",
    detail: make_test_detail_middle_v5_7(),
  }
  let mut output = render_job_timeline_detail_html_v5_7_mx(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "v5.7 detail html fixture first" {
  let expected = load_expected_v5_7(
    "fixtures/v5_7/timeline/detail_first_expected.html",
  )
  let view : JobTimelineDetailView = {
    event_id: "job-1:0:1:status_change",
    base_url: "/v5.7/export/jobs/job-1/timeline/event",
    detail: make_test_detail_first_v5_7(),
  }
  let mut output = render_job_timeline_detail_html_v5_7(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "v5.7 detail html fixture last" {
  let expected = load_expected_v5_7(
    "fixtures/v5_7/timeline/detail_last_expected.html",
  )
  let view : JobTimelineDetailView = {
    event_id: "job-1:2:1:status_change",
    base_url: "/v5.7/export/jobs/job-1/timeline/event",
    detail: make_test_detail_last_v5_7(),
  }
  let mut output = render_job_timeline_detail_html_v5_7(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
