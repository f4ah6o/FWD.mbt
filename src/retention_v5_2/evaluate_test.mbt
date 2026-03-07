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
test "v5.2 multi-axis poll wins" {
  let input : MultiAxisEvalInput = {
    policies: [
      {
        axis: RetentionAxisV52::PollCount,
        threshold: 5,
        ttl_seconds: 120,
      },
      {
        axis: RetentionAxisV52::LogicalTime,
        threshold: 100,
        ttl_seconds: 300,
      },
    ],
    current_poll_count: 6,
    current_logical_time: 50,
  }
  let result = evaluate_multi_axis(input)
  let actual = eval_result_json(result)
  let expected = parse_expected_body(
    "fixtures/v5_2/retention/case_multi_axis_poll_wins.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.2 multi-axis logical time wins" {
  let input : MultiAxisEvalInput = {
    policies: [
      {
        axis: RetentionAxisV52::PollCount,
        threshold: 10,
        ttl_seconds: 240,
      },
      {
        axis: RetentionAxisV52::LogicalTime,
        threshold: 50,
        ttl_seconds: 150,
      },
    ],
    current_poll_count: 3,
    current_logical_time: 55,
  }
  let result = evaluate_multi_axis(input)
  let actual = eval_result_json(result)
  let expected = parse_expected_body(
    "fixtures/v5_2/retention/case_multi_axis_logical_time_wins.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.2 multi-axis both expired" {
  let input : MultiAxisEvalInput = {
    policies: [
      {
        axis: RetentionAxisV52::PollCount,
        threshold: 3,
        ttl_seconds: 60,
      },
      {
        axis: RetentionAxisV52::LogicalTime,
        threshold: 20,
        ttl_seconds: 60,
      },
    ],
    current_poll_count: 5,
    current_logical_time: 25,
  }
  let result = evaluate_multi_axis(input)
  let actual = eval_result_json(result)
  let expected = parse_expected_body(
    "fixtures/v5_2/retention/case_multi_axis_both_expired.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.2 multi-axis none expired" {
  let input : MultiAxisEvalInput = {
    policies: [
      {
        axis: RetentionAxisV52::PollCount,
        threshold: 10,
        ttl_seconds: 240,
      },
      {
        axis: RetentionAxisV52::LogicalTime,
        threshold: 100,
        ttl_seconds: 300,
      },
    ],
    current_poll_count: 2,
    current_logical_time: 30,
  }
  let result = evaluate_multi_axis(input)
  let actual = eval_result_json(result)
  let expected = parse_expected_body(
    "fixtures/v5_2/retention/case_multi_axis_none_expired.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.2 single axis poll count" {
  let input : MultiAxisEvalInput = {
    policies: [
      {
        axis: RetentionAxisV52::PollCount,
        threshold: 5,
        ttl_seconds: 120,
      },
    ],
    current_poll_count: 7,
    current_logical_time: 0,
  }
  let result = evaluate_multi_axis(input)
  let actual = eval_result_json(result)
  let expected = parse_expected_body(
    "fixtures/v5_2/retention/case_single_axis_poll_count.response.json",
  )
  inspect(actual, content=expected)
}

///|
test "v5.2 single axis logical time" {
  let input : MultiAxisEvalInput = {
    policies: [
      {
        axis: RetentionAxisV52::LogicalTime,
        threshold: 50,
        ttl_seconds: 150,
      },
    ],
    current_poll_count: 0,
    current_logical_time: 60,
  }
  let result = evaluate_multi_axis(input)
  let actual = eval_result_json(result)
  let expected = parse_expected_body(
    "fixtures/v5_2/retention/case_single_axis_logical_time.response.json",
  )
  inspect(actual, content=expected)
}
