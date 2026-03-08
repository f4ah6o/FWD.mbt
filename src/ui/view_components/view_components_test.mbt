///|
test "root_node plain has class only" {
  let ctx : ViewContext = { enable_mx: false, root_class: "test-root" }
  let html = render_root(ctx, [@tmpx.text("hello")])
  inspect(html, content="<div class=\"test-root\">hello</div>")
}

///|
test "root_node mx has mx-target and mx-swap" {
  let ctx : ViewContext = { enable_mx: true, root_class: "test-root" }
  let html = render_root(ctx, [@tmpx.text("hello")])
  inspect(
    html,
    content="<div class=\"test-root\" mx-target=\".test-root\" mx-swap=\"outerHTML\">hello</div>",
  )
}

///|
test "pager_node plain buttons have no mx-get" {
  let ctx : ViewContext = { enable_mx: false, root_class: "x" }
  let node = pager_node(ctx, [("Next", "/url")])
  let html = @tmpx.render(node)
  inspect(
    html,
    content="<div class=\"fwd-job-timeline-pager\"><button>Next</button></div>",
  )
}

///|
test "pager_node mx buttons have mx-get" {
  let ctx : ViewContext = { enable_mx: true, root_class: "x" }
  let node = pager_node(ctx, [("Next", "/url")])
  let html = @tmpx.render(node)
  inspect(
    html,
    content="<div class=\"fwd-job-timeline-pager\"><button mx-get=\"/url\">Next</button></div>",
  )
}

///|
test "pager_node mx multiple buttons" {
  let ctx : ViewContext = { enable_mx: true, root_class: "x" }
  let node = pager_node(ctx, [("Prev", "/prev"), ("Next", "/next")])
  let html = @tmpx.render(node)
  inspect(
    html,
    content="<div class=\"fwd-job-timeline-pager\"><button mx-get=\"/prev\">Prev</button><button mx-get=\"/next\">Next</button></div>",
  )
}

///|
test "field_node renders label and value" {
  let node = field_node("from", "queued")
  let html = @tmpx.render(node)
  inspect(html, content="<p>from: queued</p>")
}

///|
test "item_node renders class and data attribute" {
  let node = item_node(
    "fwd-item",
    "event-id",
    "abc",
    [@tmpx.text("content")],
  )
  let html = @tmpx.render(node)
  inspect(
    html,
    content="<div class=\"fwd-item\" data-event-id=\"abc\">content</div>",
  )
}
