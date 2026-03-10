///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn default_schema_status() -> String {
  "Draft"
}

///|
pub fn default_rollout_mode() -> String {
  "simulation"
}

///|
pub fn default_builder() -> BuilderState {
  {
    entity_name: "Request",
    initial_state: "Draft",
    schema_status: default_schema_status(),
    rollout_mode: default_rollout_mode(),
    states: ["Draft", "Approved", "Rejected"],
    transitions: [
      { name: "approve", from: "Draft", to: "Approved" },
      { name: "reject", from: "Draft", to: "Rejected" },
      { name: "", from: "", to: "" },
    ],
  }
}

///|
pub fn purchase_request_builder() -> BuilderState {
  {
    entity_name: "PurchaseRequest",
    initial_state: "Draft",
    schema_status: "Released",
    rollout_mode: "shadow",
    states: [
      "Draft", "Submitted", "ManagerApproved", "FinanceApproved", "Ordered", "Rejected",
    ],
    transitions: [
      { name: "submit", from: "Draft", to: "Submitted" },
      { name: "manager_approve", from: "Submitted", to: "ManagerApproved" },
      { name: "manager_reject", from: "Submitted", to: "Rejected" },
      {
        name: "finance_approve",
        from: "ManagerApproved",
        to: "FinanceApproved",
      },
      { name: "finance_reject", from: "ManagerApproved", to: "Rejected" },
      { name: "place_order", from: "FinanceApproved", to: "Ordered" },
    ],
  }
}

///|
pub fn builder_for_case(case_id : String) -> BuilderState? {
  match case_id {
    "purchase-request" => Some(purchase_request_builder())
    _ => None
  }
}

///|
fn has_any_text(text : String) -> Bool {
  text.length() > 0
}

///|
fn has_valid_schema_status(value : String) -> Bool {
  match value {
    "Draft" | "Reviewing" | "Released" | "Deprecated" => true
    _ => false
  }
}

///|
fn has_valid_rollout_mode(value : String) -> Bool {
  match value {
    "simulation" | "shadow" | "assisted" | "enforced" => true
    _ => false
  }
}

///|
fn workbench_field_reason(
  field : String,
  value : String,
  allowed : String,
) -> @core.Reason {
  @core.Reason::with_context(
    "WORKBENCH_FIELD_INVALID",
    "unsupported " + field + ": " + value,
    [
      ("target", "workbench"),
      ("level", "error"),
      ("field", field),
      ("hint", "Use one of: " + allowed),
    ],
  )
}

///|
fn validate_workbench_controls(builder : BuilderState) -> @core.Reason? {
  if !has_valid_schema_status(builder.schema_status) {
    return Some(
      workbench_field_reason(
        "schema_status",
        builder.schema_status,
        "Draft, Reviewing, Released, Deprecated",
      ),
    )
  }
  if !has_valid_rollout_mode(builder.rollout_mode) {
    return Some(
      workbench_field_reason(
        "rollout_mode",
        builder.rollout_mode,
        "simulation, shadow, assisted, enforced",
      ),
    )
  }
  None
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
fn rollout_plan(
  builder : BuilderState,
  validation_reason : @core.Reason?,
) -> RolloutPlan {
  let gates : Array[String] = []
  let actions : Array[String] = []
  let surfaces : Array[String] = ["v6 workbench"]
  if validation_reason is Some(reason) {
    gates.push("Fix validation first: " + reason.code())
    actions.push("Use Validate & Preview until the workbench model is clean")
    actions.push("Keep live decisions in the existing human/system flow")
    actions.push(
      "Only move to shadow, assisted, or enforced after validation is green",
    )
    surfaces.push("compiler/runtime preview")
    return {
      schema_status: builder.schema_status,
      rollout_mode: builder.rollout_mode,
      readiness: "blocked",
      headline: "Fix validation or rollout issues before starting operations.",
      gates,
      actions,
      surfaces,
    }
  }
  match builder.schema_status {
    "Draft" => {
      gates.push("Schema is Draft; do not attach live mutations yet")
      actions.push("Use validate + preview to close design gaps")
      actions.push("Review states and transitions with domain owners")
      actions.push("Promote to Reviewing before any shadow rollout")
      surfaces.push("compiler/runtime preview")
      {
        schema_status: builder.schema_status,
        rollout_mode: builder.rollout_mode,
        readiness: "simulation-only",
        headline: "Design in the workbench before touching live operations.",
        gates,
        actions,
        surfaces,
      }
    }
    "Reviewing" => {
      surfaces.push("compiler/runtime preview")
      surfaces.push("/v2.1 entities + history")
      surfaces.push("timeline / metrics / observability")
      match builder.rollout_mode {
        "shadow" => {
          gates.push(
            "Schema review is still open; keep the final decision outside FWD",
          )
          actions.push(
            "Mirror create/execute traffic into FWD as a side channel",
          )
          actions.push("Compare human outcomes with previewed transitions")
          actions.push("Promote to Released after drift is understood")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "ready-for-shadow",
            headline: "Run shadow operations while humans stay in control.",
            gates,
            actions,
            surfaces,
          }
        }
        _ => {
          gates.push(
            "Only simulation or shadow are appropriate while Reviewing",
          )
          actions.push(
            "Keep the rollout in simulation or shadow until review is complete",
          )
          actions.push(
            "Use review feedback to confirm boundaries, migration, and ownership",
          )
          actions.push("Switch to Released before assisted or enforced rollout")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "review-in-progress",
            headline: "Finish review before widening operational scope.",
            gates,
            actions,
            surfaces,
          }
        }
      }
    }
    "Released" => {
      surfaces.push("/v2.1 entities + history")
      surfaces.push("timeline / metrics / observability")
      match builder.rollout_mode {
        "simulation" => {
          gates.push("No live traffic is attached yet")
          actions.push(
            "Keep using preview while preparing an operational cutover",
          )
          actions.push(
            "Switch to shadow when you are ready to mirror production traffic",
          )
          actions.push("Use metrics and timeline expectations as rollout gates")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "simulation-only",
            headline: "Released schema is available, but rollout is still simulation-only.",
            gates,
            actions,
            surfaces,
          }
        }
        "shadow" => {
          gates.push("Human/system of record remains authoritative")
          actions.push(
            "Mirror live traffic without changing the source of truth",
          )
          actions.push("Watch timeline, metrics, and observability for drift")
          actions.push("Move to assisted once operators trust the suggestions")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "ready-for-shadow",
            headline: "Mirror live traffic without enforcing FWD decisions yet.",
            gates,
            actions,
            surfaces,
          }
        }
        "assisted" => {
          gates.push("Operators must confirm transitions before execution")
          actions.push("Use runtime suggestions to propose the next transition")
          actions.push(
            "Record accepted and rejected suggestions in history and timeline",
          )
          actions.push("Graduate to enforced only after acceptance is stable")
          surfaces.push("runtime execute")
          surfaces.push("v2.2 effects plan/execute")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "ready-for-assisted",
            headline: "Use FWD in production, but keep a human confirmation step.",
            gates,
            actions,
            surfaces,
          }
        }
        "enforced" => {
          gates.push("Keep fallback and migration paths ready for rollback")
          actions.push(
            "Route live mutations through runtime execute and persist history",
          )
          actions.push(
            "Treat timeline, metrics, and observability as release gates",
          )
          actions.push("Review diff and migration before every schema change")
          surfaces.push("runtime execute")
          surfaces.push("v2.2 effects plan/execute")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "ready-for-enforced",
            headline: "FWD can drive live transitions as the system of record.",
            gates,
            actions,
            surfaces,
          }
        }
        _ => {
          gates.push("Released schemas require an explicit rollout mode")
          actions.push("Choose simulation, shadow, assisted, or enforced")
          surfaces.push("compiler/runtime preview")
          {
            schema_status: builder.schema_status,
            rollout_mode: builder.rollout_mode,
            readiness: "blocked",
            headline: "Choose a rollout mode before going live.",
            gates,
            actions,
            surfaces,
          }
        }
      }
    }
    "Deprecated" => {
      gates.push("Do not start new live entities on a Deprecated schema")
      actions.push("Keep history readable while migration completes")
      actions.push("Move traffic to a newer Released schema")
      actions.push(
        "Expose migration notes and compatibility reasons to operators",
      )
      surfaces.push("/v2.1 history")
      surfaces.push("timeline / metrics / observability")
      {
        schema_status: builder.schema_status,
        rollout_mode: builder.rollout_mode,
        readiness: "read-only",
        headline: "Keep history readable and migrate away from this schema.",
        gates,
        actions,
        surfaces,
      }
    }
    _ => {
      gates.push("Schema status is not recognized")
      actions.push("Use Draft, Reviewing, Released, or Deprecated")
      surfaces.push("compiler/runtime preview")
      {
        schema_status: builder.schema_status,
        rollout_mode: builder.rollout_mode,
        readiness: "blocked",
        headline: "Fix rollout configuration before starting operations.",
        gates,
        actions,
        surfaces,
      }
    }
  }
}

///|
fn workbench_model(
  builder : BuilderState,
  validation_reason : @core.Reason?,
  previews : Array[StatePreview],
) -> WorkbenchModel {
  {
    builder,
    validation_reason,
    previews,
    rollout: rollout_plan(builder, validation_reason),
  }
}

///|
pub fn evaluate_builder(builder : BuilderState) -> WorkbenchModel {
  match validate_workbench_controls(builder) {
    Some(reason) => return workbench_model(builder, Some(reason), [])
    None => ()
  }
  let schema = builder_to_schema(builder)
  let resolved = match @compiler.resolve_schema(schema) {
    Ok(value) => value
    Err(err) =>
      return workbench_model(builder, Some(compile_error_reason(err)), [])
  }
  match @compiler.validate_schema(resolved) {
    Ok(_) => ()
    Err(reason) => return workbench_model(builder, Some(reason), [])
  }
  let ir = match @compiler.emit_ir(resolved.schema) {
    Ok(value) => value
    Err(err) =>
      return workbench_model(builder, Some(compile_error_reason(err)), [])
  }
  let previews : Array[StatePreview] = []
  for state in compact_states(builder) {
    match @runtime.compute_available_transitions(ir, state, Map::new()) {
      Ok(result) => previews.push(preview_from_runtime(state, result))
      Err(reason) => return workbench_model(builder, Some(reason), [])
    }
  }
  workbench_model(builder, None, previews)
}

///|
pub fn state_slot_count(builder : BuilderState) -> Int {
  max_int(3, builder.states.length())
}

///|
pub fn transition_slot_count(builder : BuilderState) -> Int {
  max_int(3, builder.transitions.length())
}
