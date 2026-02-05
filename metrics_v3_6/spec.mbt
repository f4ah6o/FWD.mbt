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
  from_logical_time : Int?
  to_logical_time : Int?
}

///|
pub(all) struct MetricCounts {
  ok : Int
  failed : Int
  blocked : Int
  denied : Int
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
