///|
/// Metrics contract (v3.6).

///|
pub(all) enum MetricKind {
  Transition
  Effect
  Policy
}

///|
pub(all) struct MetricWindow {
  entity_id : String
  from_logical_time : Int32?
  to_logical_time : Int32?
}

///|
pub(all) struct MetricCounts {
  ok : Int32
  failed : Int32
  blocked : Int32
  denied : Int32
}

///|
pub(all) struct MetricsByKind {
  kind : MetricKind
  counts : MetricCounts
}

///|
pub(all) struct MetricsSnapshot {
  window : MetricWindow
  total : MetricCounts
  by_kind : Array[MetricsByKind]
}
