///|
/// v4.5 timeline source (same event set as v4 timeline list).

///|
pub fn events_for_entity(entity_id : String) -> Array[@timeline_v3.TimelineEvent] {
  [
    {
      entity_id,
      logical_time: 10,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Transition,
      ref_id: "submit",
      status: "executed",
      reasons: [],
    },
    {
      entity_id,
      logical_time: 11,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Policy,
      ref_id: "policy:submit",
      status: "deny",
      reasons: [
        @core.Reason::with_context(
          "POLICY_DENY",
          "Policy denied execution",
          [("target", "transition")],
        ),
      ],
    },
    {
      entity_id,
      logical_time: 12,
      sequence: 1,
      kind: @timeline_v3.TimelineKind::Effect,
      ref_id: "http:archive",
      status: "failed",
      reasons: [
        @core.Reason::with_context(
          "EFFECT_HTTP_FAILED",
          "HTTP request failed",
          [("target", "effect")],
        ),
      ],
    },
  ]
}
