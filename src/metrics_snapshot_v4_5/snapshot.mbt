///|
/// Metrics snapshot builder (v4.5).

///|
pub fn build_snapshot(
  entity_id : String,
  from_time : Int?,
  to_time : Int?,
) -> @metrics_v3_6.MetricsSnapshot {
  {
    window: {
      entity_id,
      from_logical_time: from_time,
      to_logical_time: to_time,
    },
    total: {
      ok: 1,
      failed: 1,
      blocked: 0,
      denied: 1,
    },
    by_kind: [
      {
        kind: @metrics_v3_6.MetricKind::Transition,
        counts: { ok: 1, failed: 0, blocked: 0, denied: 0 },
      },
      {
        kind: @metrics_v3_6.MetricKind::Policy,
        counts: { ok: 0, failed: 0, blocked: 0, denied: 1 },
      },
      {
        kind: @metrics_v3_6.MetricKind::Effect,
        counts: { ok: 0, failed: 1, blocked: 0, denied: 0 },
      },
    ],
  }
}
