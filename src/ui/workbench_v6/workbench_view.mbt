///|
fn hint_text(reason : @core.Reason) -> String? {
  for pair in reason.context() {
    if pair.0 == "hint" {
      return Some(pair.1)
    }
  }
  None
}

///|
fn state_value(builder : @wb.BuilderState, index : Int) -> String {
  if index < builder.states.length() {
    builder.states[index]
  } else {
    ""
  }
}

///|
fn transition_value(
  builder : @wb.BuilderState,
  index : Int,
) -> @wb.BuilderTransition {
  if index < builder.transitions.length() {
    builder.transitions[index]
  } else {
    { name: "", from: "", to: "" }
  }
}

///|
fn form_attrs(ctx : @view_components.ViewContext) -> Array[@tmpx.Attr] {
  let attrs : Array[@tmpx.Attr] = []
  if ctx.enable_mx {
    attrs.push(@tmpx.mx_post("/v6/workbench/preview?format=mx"))
    attrs.push(@tmpx.mx_target(".fwd-workbench"))
    attrs.push(@tmpx.mx_swap(@tmpx.MxSwap::OuterHTML))
    attrs.push(@tmpx.mx_trigger_submit())
  }
  attrs
}

///|
fn summary_section(model : @wb.WorkbenchModel) -> @tmpx.Node {
  let schema = @wb.builder_to_schema(model.builder)
  @tmpx.section([@tmpx.data_attr("section", "summary")], [
    @tmpx.p([], [@tmpx.text("entityName: " + model.builder.entity_name)]),
    @tmpx.p([], [@tmpx.text("initialState: " + model.builder.initial_state)]),
    @tmpx.p([], [@tmpx.text("schemaStatus: " + model.builder.schema_status)]),
    @tmpx.p([], [@tmpx.text("rolloutMode: " + model.builder.rollout_mode)]),
    @tmpx.p([], [
      @tmpx.text("stateCount: " + schema.states.length().to_string()),
    ]),
    @tmpx.p([], [
      @tmpx.text("transitionCount: " + schema.transitions.length().to_string()),
    ]),
  ])
}

///|
fn builder_form_section(
  model : @wb.WorkbenchModel,
  ctx : @view_components.ViewContext,
) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.p([], [@tmpx.text("builder")]))
  children.push(@tmpx.p([], [@tmpx.text("entity name")]))
  children.push(
    @tmpx.input_([
      @tmpx.name_("entity_name"),
      @tmpx.value_(model.builder.entity_name),
    ]),
  )
  children.push(@tmpx.p([], [@tmpx.text("initial state")]))
  children.push(
    @tmpx.input_([
      @tmpx.name_("initial_state"),
      @tmpx.value_(model.builder.initial_state),
    ]),
  )
  children.push(@tmpx.p([], [@tmpx.text("schema status")]))
  children.push(
    @tmpx.input_([
      @tmpx.name_("schema_status"),
      @tmpx.value_(model.builder.schema_status),
    ]),
  )
  children.push(
    @tmpx.p([], [
      @tmpx.text(
        "valid schema status: Draft | Reviewing | Released | Deprecated",
      ),
    ]),
  )
  children.push(@tmpx.p([], [@tmpx.text("rollout mode")]))
  children.push(
    @tmpx.input_([
      @tmpx.name_("rollout_mode"),
      @tmpx.value_(model.builder.rollout_mode),
    ]),
  )
  children.push(
    @tmpx.p([], [
      @tmpx.text(
        "valid rollout mode: simulation | shadow | assisted | enforced",
      ),
    ]),
  )
  children.push(
    @tmpx.input_([
      @tmpx.type_("hidden"),
      @tmpx.name_("state_slots"),
      @tmpx.value_(@wb.state_slot_count(model.builder).to_string()),
    ]),
  )
  children.push(
    @tmpx.input_([
      @tmpx.type_("hidden"),
      @tmpx.name_("transition_slots"),
      @tmpx.value_(@wb.transition_slot_count(model.builder).to_string()),
    ]),
  )
  for i in 0..<@wb.state_slot_count(model.builder) {
    children.push(
      @tmpx.div(
        [
          @tmpx.class_("fwd-workbench-state-slot"),
          @tmpx.data_attr("slot", i.to_string()),
        ],
        [
          @tmpx.p([], [@tmpx.text("state " + (i + 1).to_string())]),
          @tmpx.input_([
            @tmpx.name_("state_" + i.to_string()),
            @tmpx.value_(state_value(model.builder, i)),
          ]),
        ],
      ),
    )
  }
  for i in 0..<@wb.transition_slot_count(model.builder) {
    let transition = transition_value(model.builder, i)
    children.push(
      @tmpx.div(
        [
          @tmpx.class_("fwd-workbench-transition-slot"),
          @tmpx.data_attr("slot", i.to_string()),
        ],
        [
          @tmpx.p([], [@tmpx.text("transition " + (i + 1).to_string())]),
          @tmpx.input_([
            @tmpx.name_("transition_" + i.to_string() + "_name"),
            @tmpx.value_(transition.name),
          ]),
          @tmpx.input_([
            @tmpx.name_("transition_" + i.to_string() + "_from"),
            @tmpx.value_(transition.from),
          ]),
          @tmpx.input_([
            @tmpx.name_("transition_" + i.to_string() + "_to"),
            @tmpx.value_(transition.to),
          ]),
        ],
      ),
    )
  }
  children.push(@tmpx.button([], [@tmpx.text("Validate & Preview")]))
  @tmpx.section([@tmpx.data_attr("section", "builder")], [
    @tmpx.form(form_attrs(ctx), children),
  ])
}

///|
fn validation_section(model : @wb.WorkbenchModel) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  match model.validation_reason {
    None => children.push(@tmpx.p([], [@tmpx.text("validation: ok")]))
    Some(reason) => {
      children.push(
        @tmpx.p([], [@tmpx.text("validation.code: " + reason.code())]),
      )
      children.push(
        @tmpx.p([], [@tmpx.text("validation.message: " + reason.message())]),
      )
      match hint_text(reason) {
        Some(hint) =>
          children.push(@tmpx.p([], [@tmpx.text("validation.hint: " + hint)]))
        None => ()
      }
    }
  }
  @tmpx.section([@tmpx.data_attr("section", "validation")], children)
}

///|
fn blocked_reason_node(reason : @core.Reason) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  children.push(
    @tmpx.p([], [@tmpx.text("blocked.message: " + reason.message())]),
  )
  match hint_text(reason) {
    Some(hint) =>
      children.push(@tmpx.p([], [@tmpx.text("blocked.hint: " + hint)]))
    None => ()
  }
  @tmpx.div([], children)
}

///|
fn preview_state_node(preview : @wb.StatePreview) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.p([], [@tmpx.text("state: " + preview.state)]))
  if preview.available.length() == 0 {
    children.push(@tmpx.p([], [@tmpx.text("available: none")]))
  } else {
    for transition in preview.available {
      children.push(
        @tmpx.p([], [
          @tmpx.text("available: " + transition.id + " -> " + transition.to),
        ]),
      )
    }
  }
  if preview.blocked.length() == 0 {
    children.push(@tmpx.p([], [@tmpx.text("blocked: none")]))
  } else {
    for transition in preview.blocked {
      children.push(@tmpx.p([], [@tmpx.text("blocked: " + transition.id)]))
      for reason in transition.reasons {
        children.push(blocked_reason_node(reason))
      }
    }
  }
  @tmpx.div(
    [
      @tmpx.class_("fwd-workbench-state-preview"),
      @tmpx.data_attr("state", preview.state),
    ],
    children,
  )
}

///|
fn preview_section(model : @wb.WorkbenchModel) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  if model.previews.length() == 0 {
    children.push(@tmpx.p([], [@tmpx.text("preview: unavailable")]))
  } else {
    for preview in model.previews {
      children.push(preview_state_node(preview))
    }
  }
  @tmpx.section([@tmpx.data_attr("section", "preview")], children)
}

///|
fn rollout_section(model : @wb.WorkbenchModel) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  children.push(
    @tmpx.p([], [@tmpx.text("schemaStatus: " + model.rollout.schema_status)]),
  )
  children.push(
    @tmpx.p([], [@tmpx.text("rolloutMode: " + model.rollout.rollout_mode)]),
  )
  children.push(
    @tmpx.p([], [@tmpx.text("readiness: " + model.rollout.readiness)]),
  )
  children.push(
    @tmpx.p([], [@tmpx.text("headline: " + model.rollout.headline)]),
  )
  for gate in model.rollout.gates {
    children.push(@tmpx.p([], [@tmpx.text("gate: " + gate)]))
  }
  for action in model.rollout.actions {
    children.push(@tmpx.p([], [@tmpx.text("action: " + action)]))
  }
  for surface in model.rollout.surfaces {
    children.push(@tmpx.p([], [@tmpx.text("surface: " + surface)]))
  }
  @tmpx.section([@tmpx.data_attr("section", "rollout")], children)
}

///|
fn render_workbench_with_ctx(
  model : @wb.WorkbenchModel,
  ctx : @view_components.ViewContext,
) -> String {
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.p([], [@tmpx.text("FWD Workbench v6")]))
  children.push(summary_section(model))
  children.push(builder_form_section(model, ctx))
  children.push(validation_section(model))
  children.push(preview_section(model))
  children.push(rollout_section(model))
  @view_components.render_root(ctx, children)
}

///|
pub fn render_workbench_html(model : @wb.WorkbenchModel) -> String {
  let ctx : @view_components.ViewContext = {
    enable_mx: false,
    root_class: "fwd-workbench",
  }
  render_workbench_with_ctx(model, ctx)
}

///|
pub fn render_workbench_html_mx(model : @wb.WorkbenchModel) -> String {
  let ctx : @view_components.ViewContext = {
    enable_mx: true,
    root_class: "fwd-workbench",
  }
  render_workbench_with_ctx(model, ctx)
}
