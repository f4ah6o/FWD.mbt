///|
fn read_text_view_v6(
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
fn load_expected_v6(path : String) -> String raise {
  match read_text_view_v6(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

///|
fn make_test_page_v6(
  has_more : Bool,
) -> @job_timeline_v5_5.JobTimelinePage {
  let events : Array[@job_timeline_v5_4.JobTimelineEvent] = [
    {
      job_id: "job-1",
      logical_time: 0,
      sequence: 1,
      kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
      from_status: "queued",
      to_status: "queued",
      reasons: [],
    },
    {
      job_id: "job-1",
      logical_time: 1,
      sequence: 1,
      kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
      from_status: "queued",
      to_status: "running",
      reasons: [],
    },
  ]
  { events, offset: 0, limit: 2, has_more }
}

///|
fn make_test_page2_v6() -> @job_timeline_v5_5.JobTimelinePage {
  let events : Array[@job_timeline_v5_4.JobTimelineEvent] = [
    {
      job_id: "job-1",
      logical_time: 2,
      sequence: 1,
      kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
      from_status: "running",
      to_status: "done",
      reasons: [],
    },
  ]
  { events, offset: 2, limit: 2, has_more: false }
}

///|
test "v6 job timeline page1 html fixture" {
  let expected = load_expected_v6(
    "fixtures/v5_6/timeline/page1_expected.html",
  )
  let view : JobTimelinePageView = {
    job_id: "job-1",
    base_url: "/v5.5/export/jobs/job-1/timeline",
    page: make_test_page_v6(true),
  }
  let mut output = render_job_timeline_html_v6(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "v6 job timeline page1 mx html fixture" {
  let expected = load_expected_v6(
    "fixtures/v5_6/timeline/page1_mx_expected.html",
  )
  let view : JobTimelinePageView = {
    job_id: "job-1",
    base_url: "/v5.5/export/jobs/job-1/timeline",
    page: make_test_page_v6(true),
  }
  let mut output = render_job_timeline_html_v6_mx(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "v6 job timeline page2 html fixture" {
  let expected = load_expected_v6(
    "fixtures/v5_6/timeline/page2_expected.html",
  )
  let view : JobTimelinePageView = {
    job_id: "job-1",
    base_url: "/v5.5/export/jobs/job-1/timeline",
    page: make_test_page2_v6(),
  }
  let mut output = render_job_timeline_html_v6(view)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
