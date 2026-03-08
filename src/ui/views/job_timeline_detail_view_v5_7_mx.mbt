///|
/// v5.7 job timeline detail MX HTML projection (mx-get pager).

///|
fn job_timeline_detail_pager_node_v5_7_mx(
  label : String,
  base_url : String,
  event_id : String,
) -> @tmpx.Node {
  let url = base_url + "/" + event_id + "?format=mx"
  @tmpx.button([@tmpx.mx_get(url)], [@tmpx.text(label)])
}

///|
fn detail_nodes_v5_7_mx(view : JobTimelineDetailView) -> Array[@tmpx.Node] {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(
    job_timeline_detail_event_node_v5_7(view.detail.event),
  )
  let pager : Array[@tmpx.Node] = []
  match view.detail.prev_event {
    Some(prev) =>
      pager.push(
        job_timeline_detail_pager_node_v5_7_mx(
          "Prev",
          view.base_url,
          job_timeline_event_id_v5_6(prev),
        ),
      )
    None => ()
  }
  match view.detail.next_event {
    Some(next) =>
      pager.push(
        job_timeline_detail_pager_node_v5_7_mx(
          "Next",
          view.base_url,
          job_timeline_event_id_v5_6(next),
        ),
      )
    None => ()
  }
  if pager.length() > 0 {
    nodes.push(
      @tmpx.div([@tmpx.class_("fwd-job-timeline-pager")], pager),
    )
  }
  nodes
}

///|
pub fn render_job_timeline_detail_html_v5_7_mx(
  view : JobTimelineDetailView,
) -> String {
  let root = @tmpx.div(
    [
      @tmpx.class_("fwd-job-timeline-detail"),
      @tmpx.mx_target(".fwd-job-timeline-detail"),
      @tmpx.mx_swap(@tmpx.MxSwap::OuterHTML),
    ],
    detail_nodes_v5_7_mx(view),
  )
  @tmpx.render(root)
}
