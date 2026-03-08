///|
/// Root div with conditional MX attributes.
/// When ctx.enable_mx is true, adds mx-target=".<root_class>" and mx-swap="outerHTML".
pub fn root_node(ctx : ViewContext, children : Array[@tmpx.Node]) -> @tmpx.Node {
  let attrs : Array[@tmpx.Attr] = [@tmpx.class_(ctx.root_class)]
  if ctx.enable_mx {
    attrs.push(@tmpx.mx_target("." + ctx.root_class))
    attrs.push(@tmpx.mx_swap(@tmpx.MxSwap::OuterHTML))
  }
  @tmpx.div(attrs, children)
}

///|
/// Render root node to HTML string.
pub fn render_root(ctx : ViewContext, children : Array[@tmpx.Node]) -> String {
  @tmpx.render(root_node(ctx, children))
}
