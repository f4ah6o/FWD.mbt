///|
pub(all) struct BuilderTransition {
  name : String
  from : String
  to : String
}

///|
pub(all) struct BuilderState {
  entity_name : String
  initial_state : String
  schema_status : String
  rollout_mode : String
  states : Array[String]
  transitions : Array[BuilderTransition]
}

///|
pub(all) struct PreviewTransition {
  id : String
  to : String
}

///|
pub(all) struct PreviewBlockedTransition {
  id : String
  reasons : Array[@core.Reason]
}

///|
pub(all) struct StatePreview {
  state : String
  available : Array[PreviewTransition]
  blocked : Array[PreviewBlockedTransition]
}

///|
pub(all) struct RolloutPlan {
  schema_status : String
  rollout_mode : String
  readiness : String
  headline : String
  gates : Array[String]
  actions : Array[String]
  surfaces : Array[String]
}

///|
pub(all) struct WorkbenchModel {
  builder : BuilderState
  validation_reason : @core.Reason?
  previews : Array[StatePreview]
  rollout : RolloutPlan
}
