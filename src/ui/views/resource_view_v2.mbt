///|
/// v2 HTML projection from ResourceV2.

///|
fn reason_nodes_v2(reason : @core.Reason) -> Array[@tmpx.Node] {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(@tmpx.p([], [@tmpx.text(reason.message())]))
  for pair in reason.context() {
    if pair.0 == "hint" {
      nodes.push(@tmpx.p([], [@tmpx.text(pair.1)]))
    }
  }
  nodes
}

///|
fn payload_textarea(payload : Json?) -> @tmpx.Node {
  let text = match payload {
    Some(value) => value.stringify(indent=2)
    None => ""
  }
  @tmpx.textarea([
    @tmpx.name_("payload"),
  ], [@tmpx.text(text)])
}

///|
fn transition_node_v2(
  state : String,
  tr : @hypermedia.ResourceTransitionV2,
) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.input_([
    @tmpx.type_("hidden"),
    @tmpx.name_("state"),
    @tmpx.value_(state),
  ]))
  children.push(@tmpx.input_([
    @tmpx.type_("hidden"),
    @tmpx.name_("transition"),
    @tmpx.value_(tr.id),
  ]))
  match tr.input_schema {
    Some(schema_name) => {
      children.push(@tmpx.p([], [@tmpx.text("inputSchema: " + schema_name)]))
      children.push(payload_textarea(tr.payload))
    }
    None => ()
  }
  for reason in tr.errors {
    for node in reason_nodes_v2(reason) {
      children.push(node)
    }
  }
  children.push(@tmpx.button([], [@tmpx.text("Validate")]))
  let form_node = @tmpx.form([
    @tmpx.data_attr("transition", tr.id),
    @tmpx.mx_post("/v2/resource/validate"),
    @tmpx.mx_target(".fwd-resource"),
    @tmpx.mx_swap(@tmpx.MxSwap::OuterHTML),
    @tmpx.mx_trigger_submit(),
  ], children)
  if tr.can_execute {
    let payload_json = match tr.payload {
      Some(value) => value.stringify()
      None => "{}"
    }
    let exec_vals =
      "{\"state\":\"" + state + "\",\"transition\":\"" + tr.id +
      "\",\"input\":" + payload_json + "}"
    let exec_button = @tmpx.button([
      @tmpx.data_attr("transition", tr.id),
      @tmpx.mx_post("/v2/transition/execute"),
      @tmpx.mx_target(".fwd-resource"),
      @tmpx.mx_swap(@tmpx.MxSwap::OuterHTML),
      @tmpx.mx_vals(exec_vals),
      @tmpx.mx_encoding("application/json"),
      @tmpx.mx_trigger_click(),
    ], [@tmpx.text("Execute")])
    return @tmpx.div([], [form_node, exec_button])
  }
  form_node
}

///|
pub fn render_resource_html_v2(resource : @hypermedia.ResourceV2) -> String {
  let nodes : Array[@tmpx.Node] = []
  for tr in resource.transitions {
    nodes.push(transition_node_v2(resource.state, tr))
  }
  let root = @tmpx.div(
    [@tmpx.class_("fwd-resource")],
    [
      @tmpx.section([
        @tmpx.data_attr("section", "available"),
      ], nodes),
      @tmpx.section([
        @tmpx.data_attr("section", "blocked"),
      ], []),
    ],
  )
  @tmpx.render(root)
}

///|
pub fn render_resource_html_v2_mx(resource : @hypermedia.ResourceV2) -> String {
  render_resource_html_v2(resource)
}
