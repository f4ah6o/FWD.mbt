///|
/// v3.3 timeline HTML projection with filter/paging UI.

fn timeline_kind_label(kind : @timeline_v3.TimelineKind) -> String {
  match kind {
    @timeline_v3.TimelineKind::Transition => "Transition"
    @timeline_v3.TimelineKind::Effect => "Effect"
    @timeline_v3.TimelineKind::Policy => "Policy"
  }
}

fn timeline_reason_nodes_v3_3(reason : @core.Reason) -> Array[@tmpx.Node] {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(@tmpx.p([], [@tmpx.text(reason.message())]))
  for pair in reason.context() {
    if pair.0 == "hint" {
      nodes.push(@tmpx.p([], [@tmpx.text(pair.1)]))
    }
  }
  nodes
}

fn event_node_v3_3(event : @timeline_v3.TimelineEvent) -> @tmpx.Node {
  let kind_text = timeline_kind_label(event.kind)
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.p([], [@tmpx.text("kind: " + kind_text)]))
  children.push(@tmpx.p([], [@tmpx.text("ref: " + event.ref_id)]))
  children.push(@tmpx.p([], [@tmpx.text("status: " + event.status)]))
  for reason in event.reasons {
    for node in timeline_reason_nodes_v3_3(reason) {
      children.push(node)
    }
  }
  @tmpx.div([
    @tmpx.data_attr("logical-time", event.logical_time.to_string()),
    @tmpx.data_attr("sequence", event.sequence.to_string()),
    @tmpx.data_attr("kind", kind_text),
  ], children)
}

fn filter_form(entity_id : String, kind : String?, limit : Int, cursor : String?) -> @tmpx.Node {
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.input_([
    @tmpx.type_("hidden"),
    @tmpx.name_("entityId"),
    @tmpx.value_(entity_id),
  ]))
  match kind {
    Some(value) => children.push(@tmpx.input_([
      @tmpx.type_("hidden"),
      @tmpx.name_("kind"),
      @tmpx.value_(value),
    ]))
    None => ()
  }
  children.push(@tmpx.input_([
    @tmpx.type_("hidden"),
    @tmpx.name_("limit"),
    @tmpx.value_(limit.to_string()),
  ]))
  match cursor {
    Some(value) => children.push(@tmpx.input_([
      @tmpx.type_("hidden"),
      @tmpx.name_("cursor"),
      @tmpx.value_(value),
    ]))
    None => ()
  }
  children.push(@tmpx.button([], [@tmpx.text("Apply")]))
  @tmpx.form([
    @tmpx.mx_get("/v3.3/timeline"),
    @tmpx.mx_target(".fwd-timeline"),
    @tmpx.mx_swap(@tmpx.MxSwap::OuterHTML),
  ], children)
}

///|
pub fn render_timeline_html_v3_3(
  entity_id : String,
  events : Array[@timeline_v3.TimelineEvent],
  kind : String?,
  limit : Int,
  next_cursor : String?,
) -> String {
  let nodes : Array[@tmpx.Node] = []
  for event in events {
    nodes.push(event_node_v3_3(event))
  }
  let form_nodes : Array[@tmpx.Node] = []
  form_nodes.push(filter_form(entity_id, kind, limit, next_cursor))
  if next_cursor is Some(_) {
    form_nodes.push(@tmpx.p([], [@tmpx.text("next cursor available")]))
  }
  let all_nodes : Array[@tmpx.Node] = []
  for node in form_nodes {
    all_nodes.push(node)
  }
  for node in nodes {
    all_nodes.push(node)
  }
  let root = @tmpx.div(
    [@tmpx.class_("fwd-timeline")],
    all_nodes,
  )
  @tmpx.render(root)
}
