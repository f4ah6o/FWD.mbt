///|
/// v5.2 retention axis types (multi-axis extension).

///|
/// Retention evaluation axis. v5.2 adds LogicalTime alongside PollCount.
pub(all) enum RetentionAxisV52 {
  PollCount
  LogicalTime
}

///|
/// A single retention policy on one axis.
pub(all) struct RetentionPolicyV52 {
  axis : RetentionAxisV52
  /// Expiry threshold: ttl_polls for PollCount, max_logical_time for LogicalTime.
  threshold : Int32
  /// Informational TTL (MUST NOT be interpreted as wall-clock seconds).
  ttl_seconds : Int32
}

///|
/// Input to multi-axis retention evaluation.
pub(all) struct MultiAxisEvalInput {
  policies : Array[RetentionPolicyV52]
  current_poll_count : Int32
  current_logical_time : Int32
}

///|
/// Per-axis evaluation result.
pub(all) struct AxisEvalResult {
  axis : RetentionAxisV52
  threshold : Int32
  current : Int32
  expired : Bool
}

///|
/// Full multi-axis evaluation result.
pub(all) struct RetentionEvalResult {
  axes : Array[AxisEvalResult]
  effective_axis : String
  effective_threshold : Int32
  expired : Bool
}
