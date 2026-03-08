///|
/// v6.0 job timeline list view — unified plain + MX rendering via ViewContext.
/// Produces identical HTML output to v5.6/v5.6_mx.

///|
pub fn render_job_timeline_html_v6(view : JobTimelinePageView) -> String {
  let ctx : @view_components.ViewContext = {
    enable_mx: false,
    root_class: "fwd-job-timeline",
  }
  render_job_timeline_with_ctx(view, ctx)
}

///|
pub fn render_job_timeline_html_v6_mx(view : JobTimelinePageView) -> String {
  let ctx : @view_components.ViewContext = {
    enable_mx: true,
    root_class: "fwd-job-timeline",
  }
  render_job_timeline_with_ctx(view, ctx)
}

///|
fn render_job_timeline_with_ctx(
  view : JobTimelinePageView,
  ctx : @view_components.ViewContext,
) -> String {
  let children : Array[@tmpx.Node] = []
  for event in view.page.events {
    children.push(job_timeline_event_node_v6(event))
  }
  if view.page.has_more {
    let next_offset = view.page.offset + view.page.limit
    let url = view.base_url +
      "?format=mx&limit=" +
      view.page.limit.to_string() +
      "&cursor=offset:" +
      next_offset.to_string()
    children.push(
      @view_components.pager_node(ctx, [("Next", url)]),
    )
  }
  @view_components.render_root(ctx, children)
}

///|
fn job_timeline_event_node_v6(
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
