///|
pub fn default_builder() -> BuilderState {
  {
    entity_name: "Request",
    initial_state: "Draft",
    states: ["Draft", "Approved", "Rejected"],
    transitions: [
      { name: "approve", from: "Draft", to: "Approved" },
      { name: "reject", from: "Draft", to: "Rejected" },
      { name: "", from: "", to: "" },
    ],
  }
}

///|
fn has_any_text(text : String) -> Bool {
  text.length() > 0
}

///|
fn transition_has_any_text(transition : BuilderTransition) -> Bool {
  has_any_text(transition.name) ||
  has_any_text(transition.from) ||
  has_any_text(transition.to)
}

///|
fn compact_states(builder : BuilderState) -> Array[String] {
  let states : Array[String] = []
  for state in builder.states {
    if has_any_text(state) {
      states.push(state)
    }
  }
  states
}

///|
fn compact_transitions(builder : BuilderState) -> Array[BuilderTransition] {
  let transitions : Array[BuilderTransition] = []
  for transition in builder.transitions {
    if transition_has_any_text(transition) {
      transitions.push(transition)
    }
  }
  transitions
}

///|
pub fn builder_to_schema(builder : BuilderState) -> @schema.Schema {
  let states : Array[@schema.StateDefinition] = []
  for state in compact_states(builder) {
    states.push({ name: state })
  }
  let transitions : Array[@schema.TransitionDefinition] = []
  for transition in compact_transitions(builder) {
    transitions.push({
      name: transition.name,
      from: transition.from,
      to: transition.to,
      rules: [],
      effects: [],
      input_schema: None,
    })
  }
  {
    fwd_version: "1.0",
    schema_version: "1.0",
    states,
    entities: [
      {
        name: builder.entity_name,
        initial_state: builder.initial_state,
        attributes: [],
      },
    ],
    transitions,
    rules: [],
    reasons: [],
    boundaries: [],
    effects: [],
  }
}

///|
fn compare_string(a : String, b : String) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn compile_error_reason(err : @compiler.CompileError) -> @core.Reason {
  match err {
    @compiler.CompileError::ParseFailure(msg) =>
      @core.Reason::with_context("PARSE_FAILURE", msg, [
        ("target", "schema"),
        ("hint", "Review the generated schema input"),
      ])
    @compiler.CompileError::ResolveFailure(msg) =>
      @core.Reason::with_context("RESOLVE_FAILURE", msg, [
        ("target", "schema"),
        ("hint", "Review transition rules and reserved names"),
      ])
    @compiler.CompileError::ValidationFailure(reason) => reason
  }
}

///|
fn preview_from_runtime(
  state : String,
  result : @runtime.RuntimeResult,
) -> StatePreview {
  let available : Array[PreviewTransition] = []
  for transition in result.available_transitions {
    available.push({ id: transition.id, to: transition.to })
  }
  let blocked : Array[PreviewBlockedTransition] = []
  for transition in result.blocked_transitions {
    blocked.push({ id: transition.id, reasons: transition.reasons })
  }
  available.sort_by((a, b) => compare_string(a.id, b.id))
  blocked.sort_by((a, b) => compare_string(a.id, b.id))
  { state, available, blocked }
}

///|
pub fn evaluate_builder(builder : BuilderState) -> WorkbenchModel {
  let schema = builder_to_schema(builder)
  let resolved = match @compiler.resolve_schema(schema) {
    Ok(value) => value
    Err(err) =>
      return {
        builder,
        validation_reason: Some(compile_error_reason(err)),
        previews: [],
      }
  }
  match @compiler.validate_schema(resolved) {
    Ok(_) => ()
    Err(reason) =>
      return { builder, validation_reason: Some(reason), previews: [] }
  }
  let ir = match @compiler.emit_ir(resolved.schema) {
    Ok(value) => value
    Err(err) =>
      return {
        builder,
        validation_reason: Some(compile_error_reason(err)),
        previews: [],
      }
  }
  let previews : Array[StatePreview] = []
  for state in compact_states(builder) {
    match @runtime.compute_available_transitions(ir, state, Map::new()) {
      Ok(result) => previews.push(preview_from_runtime(state, result))
      Err(reason) =>
        return { builder, validation_reason: Some(reason), previews: [] }
    }
  }
  { builder, validation_reason: None, previews }
}
