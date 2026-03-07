///|
/// v5.6 job timeline MX HTML projection (paginated, mx-get pager).

///|
fn job_timeline_pager_node_v5_6_mx(
  base_url : String,
  page : @job_timeline_v5_5.JobTimelinePage,
) -> @tmpx.Node {
  let next_offset = page.offset + page.limit
  let url = base_url +
    "?format=mx&limit=" +
    page.limit.to_string() +
    "&cursor=offset:" +
    next_offset.to_string()
  @tmpx.div(
    [@tmpx.class_("fwd-job-timeline-pager")],
    [@tmpx.button([@tmpx.mx_get(url)], [@tmpx.text("Next")])],
  )
}

///|
pub fn render_job_timeline_html_v5_6_mx(view : JobTimelinePageView) -> String {
  let nodes : Array[@tmpx.Node] = []
  for event in view.page.events {
    nodes.push(job_timeline_event_node_v5_6(event))
  }
  if view.page.has_more {
    nodes.push(job_timeline_pager_node_v5_6_mx(view.base_url, view.page))
  }
  let root = @tmpx.div(
    [
      @tmpx.class_("fwd-job-timeline"),
      @tmpx.mx_target(".fwd-job-timeline"),
      @tmpx.mx_swap(@tmpx.MxSwap::OuterHTML),
    ],
    nodes,
  )
  @tmpx.render(root)
}
