///|
/// Hypermedia resource projection (v2) for input-first forms.

///|
pub(all) struct ResourceTransitionV2 {
  id : String
  to : String
  input_schema : String?
  payload : Json?
  errors : Array[@core.Reason]
  can_execute : Bool
}

///|
pub(all) struct ResourceV2 {
  state : String
  transitions : Array[ResourceTransitionV2]
}

///|
fn compare_string_v2(a : String, b : String) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
pub fn resource_v2_from_ir(ir : @ir.FwdIR, state : String) -> ResourceV2 {
  let state_tag = @core.StateTag::new(state)
  let names : Array[String] = []
  for entry in ir.transitions.to_array() {
    names.push(entry.0)
  }
  names.sort_by(compare_string_v2)
  let transitions : Array[ResourceTransitionV2] = []
  for name in names {
    let tr = ir.transitions[name]
    if tr.from != state_tag {
      continue
    }
    transitions.push({
      id: tr.name,
      to: tr.to.value(),
      input_schema: tr.input_schema,
      payload: None,
      errors: [],
      can_execute: false,
    })
  }
  { state, transitions }
}

///|
pub fn resource_v2_validation(
  state : String,
  transition_id : String,
  to : String,
  input_schema : String?,
  payload : Json?,
  errors : Array[@core.Reason],
) -> ResourceV2 {
  let can_execute = errors.length() == 0
  {
    state,
    transitions: [
      {
        id: transition_id,
        to,
        input_schema,
        payload,
        errors,
        can_execute,
      },
    ],
  }
}
