///|
fn setup_v5_7_test_events() -> Unit {
  @job_timeline_v5_4.reset_for_test()
  @job_timeline_v5_4.record_status_change(
    "job-1", 0, "queued", "queued", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-1", 1, "queued", "running", [],
  )
  @job_timeline_v5_4.record_status_change(
    "job-1", 2, "running", "done", [],
  )
}

///|
test "v5.7 parse_kind status_change" {
  inspect(parse_kind("status_change") is None, content="false")
}

///|
test "v5.7 parse_kind invalid" {
  inspect(parse_kind("unknown") is None, content="true")
}

///|
test "v5.7 parse_event_id valid" {
  let result = parse_event_id("job-1:1:1:status_change")
  match result {
    Some(q) => {
      inspect(q.job_id, content="job-1")
      inspect(q.logical_time, content="1")
      inspect(q.sequence, content="1")
      inspect(kind_string(q.kind), content="status_change")
    }
    None => fail("expected Some")
  }
}

///|
test "v5.7 parse_event_id invalid format" {
  inspect(parse_event_id("bad") is None, content="true")
  inspect(
    parse_event_id("job-1:abc:1:status_change") is None,
    content="true",
  )
  inspect(
    parse_event_id("job-1:1:1:unknown_kind") is None,
    content="true",
  )
}

///|
test "v5.7 find_event middle" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  let detail = find_event(
    events,
    1,
    1,
    @job_timeline_v5_4.JobTimelineKind::StatusChange,
  )
  match detail {
    Some(d) => {
      inspect(d.event.logical_time, content="1")
      inspect(d.prev_event is None, content="false")
      inspect(d.next_event is None, content="false")
    }
    None => fail("expected Some")
  }
}

///|
test "v5.7 find_event first" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  let detail = find_event(
    events,
    0,
    1,
    @job_timeline_v5_4.JobTimelineKind::StatusChange,
  )
  match detail {
    Some(d) => {
      inspect(d.event.logical_time, content="0")
      inspect(d.prev_event is None, content="true")
      inspect(d.next_event is None, content="false")
    }
    None => fail("expected Some")
  }
}

///|
test "v5.7 find_event last" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  let detail = find_event(
    events,
    2,
    1,
    @job_timeline_v5_4.JobTimelineKind::StatusChange,
  )
  match detail {
    Some(d) => {
      inspect(d.event.logical_time, content="2")
      inspect(d.prev_event is None, content="false")
      inspect(d.next_event is None, content="true")
    }
    None => fail("expected Some")
  }
}

///|
test "v5.7 find_event not found" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  let detail = find_event(
    events,
    99,
    1,
    @job_timeline_v5_4.JobTimelineKind::StatusChange,
  )
  inspect(detail is None, content="true")
}

///|
test "v5.7 filter_events_by_kind with StatusChange" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  let filtered = filter_events_by_kind(
    events,
    Some(@job_timeline_v5_4.JobTimelineKind::StatusChange),
  )
  inspect(filtered.length(), content="3")
}

///|
test "v5.7 filter_events_by_kind with None" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  let filtered = filter_events_by_kind(events, None)
  inspect(filtered.length(), content="3")
}

///|
test "v5.7 event_id format" {
  setup_v5_7_test_events()
  let events = @job_timeline_v5_4.get_timeline("job-1")
  inspect(event_id(events[0]), content="job-1:0:1:status_change")
  inspect(event_id(events[1]), content="job-1:1:1:status_change")
}

///|
test "v5.7 lookup_event_detail" {
  setup_v5_7_test_events()
  let query : JobTimelineDetailQuery = {
    job_id: "job-1",
    logical_time: 1,
    sequence: 1,
    kind: @job_timeline_v5_4.JobTimelineKind::StatusChange,
  }
  let detail = lookup_event_detail(query)
  match detail {
    Some(d) => {
      inspect(d.event.from_status, content="queued")
      inspect(d.event.to_status, content="running")
    }
    None => fail("expected Some")
  }
}
