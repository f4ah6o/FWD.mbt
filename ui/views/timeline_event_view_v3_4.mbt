///|
/// v3.4 timeline event detail HTML projection.

fn timeline_kind_label_v3_4(kind : @timeline_v3.TimelineKind) -> String {
  match kind {
    @timeline_v3.TimelineKind::Transition => "Transition"
    @timeline_v3.TimelineKind::Effect => "Effect"
    @timeline_v3.TimelineKind::Policy => "Policy"
  }
}

fn timeline_reason_nodes_v3_4(reason : @core.Reason) -> Array[@tmpx.Node] {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(@tmpx.p([], [@tmpx.text(reason.message())]))
  for pair in reason.context() {
    if pair.0 == "hint" {
      nodes.push(@tmpx.p([], [@tmpx.text(pair.1)]))
    }
  }
  nodes
}

fn event_node_v3_4(detail : @timeline_event_v3_4.TimelineEventDetail) -> @tmpx.Node {
  let event = detail.event
  let kind_text = timeline_kind_label_v3_4(event.kind)
  let children : Array[@tmpx.Node] = []
  children.push(@tmpx.p([], [@tmpx.text("kind: " + kind_text)]))
  children.push(@tmpx.p([], [@tmpx.text("ref: " + event.ref_id)]))
  children.push(@tmpx.p([], [@tmpx.text("status: " + event.status)]))
  for reason in event.reasons {
    for node in timeline_reason_nodes_v3_4(reason) {
      children.push(node)
    }
  }
  @tmpx.div([
    @tmpx.class_("fwd-timeline-event"),
    @tmpx.data_attr("event-id", detail.event_id),
    @tmpx.data_attr("logical-time", event.logical_time.to_string()),
    @tmpx.data_attr("sequence", event.sequence.to_string()),
    @tmpx.data_attr("kind", kind_text),
  ], children)
}

///|
pub fn render_timeline_event_html_v3_4(detail : @timeline_event_v3_4.TimelineEventDetail) -> String {
  @tmpx.render(event_node_v3_4(detail))
}
