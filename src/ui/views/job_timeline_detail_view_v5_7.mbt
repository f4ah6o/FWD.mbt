///|
/// v5.7 job timeline detail HTML projection (prev/next navigation).

///|
pub(all) struct JobTimelineDetailView {
  event_id : String
  base_url : String
  detail : @job_timeline_v5_7.JobTimelineDetail
}

///|
fn job_timeline_detail_event_node_v5_7(
  event : @job_timeline_v5_4.JobTimelineEvent,
) -> @tmpx.Node {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(
    @tmpx.p(
      [],
      [@tmpx.text("logicalTime: " + event.logical_time.to_string())],
    ),
  )
  nodes.push(
    @tmpx.p(
      [],
      [
        @tmpx.text(
          "kind: " + job_timeline_kind_string_v5_6(event.kind),
        ),
      ],
    ),
  )
  nodes.push(@tmpx.p([], [@tmpx.text("from: " + event.from_status)]))
  nodes.push(@tmpx.p([], [@tmpx.text("to: " + event.to_status)]))
  for reason in event.reasons {
    nodes.push(
      @tmpx.p([], [@tmpx.text(job_timeline_reason_message_v5_6(reason))]),
    )
  }
  @tmpx.div(
    [
      @tmpx.class_("fwd-job-timeline-event"),
      @tmpx.data_attr("event-id", job_timeline_event_id_v5_6(event)),
    ],
    nodes,
  )
}

///|
fn job_timeline_detail_pager_node_v5_7(label : String) -> @tmpx.Node {
  @tmpx.button([], [@tmpx.text(label)])
}

///|
fn detail_nodes_v5_7(view : JobTimelineDetailView) -> Array[@tmpx.Node] {
  let nodes : Array[@tmpx.Node] = []
  nodes.push(
    job_timeline_detail_event_node_v5_7(view.detail.event),
  )
  let pager : Array[@tmpx.Node] = []
  match view.detail.prev_event {
    Some(_) => pager.push(job_timeline_detail_pager_node_v5_7("Prev"))
    None => ()
  }
  match view.detail.next_event {
    Some(_) => pager.push(job_timeline_detail_pager_node_v5_7("Next"))
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
pub fn render_job_timeline_detail_html_v5_7(
  view : JobTimelineDetailView,
) -> String {
  let nodes = detail_nodes_v5_7(view)
  let root = @tmpx.div(
    [@tmpx.class_("fwd-job-timeline-detail")],
    nodes,
  )
  @tmpx.render(root)
}
