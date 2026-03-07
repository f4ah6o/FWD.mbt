///|
/// v5.3 retention axis types (three-axis extension).

///|
/// Retention evaluation axis. v5.3 adds EventCount alongside PollCount and LogicalTime.
pub(all) enum RetentionAxisV53 {
  PollCount
  LogicalTime
  EventCount
}

///|
/// A single retention policy on one axis.
pub(all) struct RetentionPolicyV53 {
  axis : RetentionAxisV53
  /// Expiry threshold: ttl_polls for PollCount, max_logical_time for LogicalTime, max_events for EventCount.
  threshold : Int
  /// Informational TTL (MUST NOT be interpreted as wall-clock seconds).
  ttl_seconds : Int
}

///|
/// Input to multi-axis retention evaluation.
pub(all) struct MultiAxisEvalInput {
  policies : Array[RetentionPolicyV53]
  current_poll_count : Int
  current_logical_time : Int
  current_event_count : Int
}

///|
/// Per-axis evaluation result.
pub(all) struct AxisEvalResult {
  axis : RetentionAxisV53
  threshold : Int
  current : Int
  expired : Bool
}

///|
/// Full multi-axis evaluation result.
pub(all) struct RetentionEvalResult {
  axes : Array[AxisEvalResult]
  effective_axis : String
  effective_threshold : Int
  expired : Bool
}
