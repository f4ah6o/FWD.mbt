///|
/// <p>label: value</p>
pub fn field_node(label : String, value : String) -> @tmpx.Node {
  @tmpx.p([], [@tmpx.text(label + ": " + value)])
}

///|
/// <div class="item_class" data-{id_attr}="id_value">children</div>
pub fn item_node(
  item_class : String,
  id_attr : String,
  id_value : String,
  children : Array[@tmpx.Node],
) -> @tmpx.Node {
  @tmpx.div(
    [@tmpx.class_(item_class), @tmpx.data_attr(id_attr, id_value)],
    children,
  )
}
