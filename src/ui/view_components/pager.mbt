///|
/// Plain button (no MX attributes).
pub fn pager_button(label : String) -> @tmpx.Node {
  @tmpx.button([], [@tmpx.text(label)])
}

///|
/// MX button with mx-get attribute.
pub fn pager_button_mx(label : String, url : String) -> @tmpx.Node {
  @tmpx.button([@tmpx.mx_get(url)], [@tmpx.text(label)])
}

///|
/// Pager div with conditional MX buttons.
/// When ctx.enable_mx is true, buttons get mx-get attributes using the url from each pair.
/// When ctx.enable_mx is false, buttons are plain (no MX attributes).
pub fn pager_node(
  ctx : ViewContext,
  buttons : Array[(String, String)],
) -> @tmpx.Node {
  let nodes : Array[@tmpx.Node] = []
  for pair in buttons {
    let (label, url) = pair
    if ctx.enable_mx {
      nodes.push(pager_button_mx(label, url))
    } else {
      nodes.push(pager_button(label))
    }
  }
  @tmpx.div([@tmpx.class_("fwd-job-timeline-pager")], nodes)
}
