///|
/// v5.6 job timeline HTML projection (paginated, plain HTML).

///|
pub(all) struct JobTimelinePageView {
  job_id : String
  base_url : String
  page : @job_timeline_v5_5.JobTimelinePage
}

///|
fn job_timeline_kind_string_v5_6(
  kind : @job_timeline_v5_4.JobTimelineKind,
) -> String {
  match kind {
    @job_timeline_v5_4.JobTimelineKind::StatusChange => "status_change"
  }
}

///|
fn job_timeline_event_id_v5_6(
  event : @job_timeline_v5_4.JobTimelineEvent,
) -> String {
  event.job_id +
  ":" +
  event.logical_time.to_string() +
  ":" +
  event.sequence.to_string() +
  ":" +
  job_timeline_kind_string_v5_6(event.kind)
}

///|
fn job_timeline_reason_message_v5_6(
  reason : @export_job_v5.ReasonV1,
) -> String {
  reason.message
}

///|
fn job_timeline_event_node_v5_6(
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
      [@tmpx.text("kind: " + job_timeline_kind_string_v5_6(event.kind))],
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
fn job_timeline_pager_node_v5_6() -> @tmpx.Node {
  @tmpx.div(
    [@tmpx.class_("fwd-job-timeline-pager")],
    [@tmpx.button([], [@tmpx.text("Next")])],
  )
}

///|
pub fn render_job_timeline_html_v5_6(view : JobTimelinePageView) -> String {
  let nodes : Array[@tmpx.Node] = []
  for event in view.page.events {
    nodes.push(job_timeline_event_node_v5_6(event))
  }
  if view.page.has_more {
    nodes.push(job_timeline_pager_node_v5_6())
  }
  let root = @tmpx.div([@tmpx.class_("fwd-job-timeline")], nodes)
  @tmpx.render(root)
}
