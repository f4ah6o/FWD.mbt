///|
/// Timeline contract (v3).

///|
pub(all) enum TimelineKind {
  Transition
  Effect
  Policy
}

///|
pub(all) struct TimelineEvent {
  entity_id : String
  logical_time : Int
  sequence : Int
  kind : TimelineKind
  ref_id : String
  status : String
  reasons : Array[@core.Reason]
}
