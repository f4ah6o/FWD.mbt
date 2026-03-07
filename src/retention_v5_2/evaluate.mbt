///|
/// v5.2 multi-axis retention evaluation (deterministic, no wall-clock).
/// Resolution rule: strictest-wins (the axis that expires first is effective).

///|
fn axis_string(axis : RetentionAxisV52) -> String {
  match axis {
    RetentionAxisV52::PollCount => "poll_count"
    RetentionAxisV52::LogicalTime => "logical_time"
  }
}

///|
fn current_for_axis(
  axis : RetentionAxisV52,
  input : MultiAxisEvalInput,
) -> Int {
  match axis {
    RetentionAxisV52::PollCount => input.current_poll_count
    RetentionAxisV52::LogicalTime => input.current_logical_time
  }
}

///|
fn eval_single_axis(
  policy : RetentionPolicyV52,
  input : MultiAxisEvalInput,
) -> AxisEvalResult {
  let current = current_for_axis(policy.axis, input)
  let expired = current >= policy.threshold
  { axis: policy.axis, threshold: policy.threshold, current, expired }
}

///|
/// Evaluate multi-axis retention policies.
/// Strictest-wins: the first expired axis is effective.
/// If multiple axes are expired, the one with the lowest threshold wins.
/// If none are expired, effective_axis is "none".
pub fn evaluate_multi_axis(input : MultiAxisEvalInput) -> RetentionEvalResult {
  let axes : Array[AxisEvalResult] = []
  for policy in input.policies {
    axes.push(eval_single_axis(policy, input))
  }
  // Find effective axis: strictest-wins among expired axes
  let mut effective_axis = "none"
  let mut effective_threshold = 0
  let mut any_expired = false
  let mut best_threshold = 2147483647 // max int sentinel
  for result in axes {
    if result.expired && result.threshold < best_threshold {
      best_threshold = result.threshold
      effective_axis = axis_string(result.axis)
      effective_threshold = result.threshold
      any_expired = true
    }
  }
  { axes, effective_axis, effective_threshold, expired: any_expired }
}

///|
fn axis_eval_json(result : AxisEvalResult) -> Json {
  Json::object({
    "axis": Json::string(axis_string(result.axis)),
    "threshold": Json::number(result.threshold.to_double()),
    "current": Json::number(result.current.to_double()),
    "expired": Json::boolean(result.expired),
  })
}

///|
/// Serialize evaluation result to deterministic JSON.
pub fn eval_result_json(result : RetentionEvalResult) -> String {
  let axes_json : Array[Json] = []
  for axis_result in result.axes {
    axes_json.push(axis_eval_json(axis_result))
  }
  let obj : Map[String, Json] = Map::new()
  obj["jobVersion"] = Json::string("5.2")
  obj["axes"] = Json::array(axes_json)
  obj["effectiveAxis"] = Json::string(result.effective_axis)
  obj["effectiveThreshold"] = Json::number(
    result.effective_threshold.to_double(),
  )
  obj["expired"] = Json::boolean(result.expired)
  obj["resolutionRule"] = Json::string("strictest_wins")
  obj["postExpiryVisibility"] = Json::object({
    "results": Json::string("hidden"),
    "metadata": Json::string("retained"),
  })
  Json::object(obj).stringify(indent=2)
}
