///|
/// v6.0 job timeline detail view — unified plain + MX rendering via ViewContext.
/// Produces identical HTML output to v5.7/v5.7_mx.

///|
pub fn render_job_timeline_detail_html_v6(
  view : JobTimelineDetailView,
) -> String {
  let ctx : @view_components.ViewContext = {
    enable_mx: false,
    root_class: "fwd-job-timeline-detail",
  }
  render_job_timeline_detail_with_ctx(view, ctx)
}

///|
pub fn render_job_timeline_detail_html_v6_mx(
  view : JobTimelineDetailView,
) -> String {
  let ctx : @view_components.ViewContext = {
    enable_mx: true,
    root_class: "fwd-job-timeline-detail",
  }
  render_job_timeline_detail_with_ctx(view, ctx)
}

///|
fn render_job_timeline_detail_with_ctx(
  view : JobTimelineDetailView,
  ctx : @view_components.ViewContext,
) -> String {
  let children : Array[@tmpx.Node] = []
  children.push(job_timeline_detail_event_node_v6(view.detail.event))
  let buttons : Array[(String, String)] = []
  match view.detail.prev_event {
    Some(prev) => {
      let url = view.base_url +
        "/" +
        job_timeline_event_id_v5_6(prev) +
        "?format=mx"
      buttons.push(("Prev", url))
    }
    None => ()
  }
  match view.detail.next_event {
    Some(next) => {
      let url = view.base_url +
        "/" +
        job_timeline_event_id_v5_6(next) +
        "?format=mx"
      buttons.push(("Next", url))
    }
    None => ()
  }
  if buttons.length() > 0 {
    children.push(@view_components.pager_node(ctx, buttons))
  }
  @view_components.render_root(ctx, children)
}

///|
fn job_timeline_detail_event_node_v6(
  event : @job_timeline_v5_4.JobTimelineEvent,
) -> @tmpx.Node {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(
    @view_components.field_node(
      "logicalTime",
      event.logical_time.to_string(),
    ),
  )
  nodes.push(
    @view_components.field_node(
      "kind",
      job_timeline_kind_string_v5_6(event.kind),
    ),
  )
  nodes.push(@view_components.field_node("from", event.from_status))
  nodes.push(@view_components.field_node("to", event.to_status))
  for reason in event.reasons {
    nodes.push(
      @tmpx.p([], [@tmpx.text(job_timeline_reason_message_v5_6(reason))]),
    )
  }
  @view_components.item_node(
    "fwd-job-timeline-event",
    "event-id",
    job_timeline_event_id_v5_6(event),
    nodes,
  )
}
