///|
fn dslx_decode_error(message : String) -> DecodeError {
  DecodeError::new(message)
}

///|
fn dslx_child(
  tree : @dslx.Tree,
  index : Int,
  ctx : String,
) -> @dslx.Tree raise DecodeError {
  if index < tree.kids.length() {
    tree.kids[index]
  } else {
    raise dslx_decode_error("missing dslx child " + ctx)
  }
}

///|
fn dslx_expect_kind(
  tree : @dslx.Tree,
  kind : String,
  ctx : String,
) -> Unit raise DecodeError {
  if tree.kind != kind {
    raise dslx_decode_error("expected " + kind + " for " + ctx)
  }
}

///|
fn dslx_ref_payload(
  tree : @dslx.Tree,
  rule : String,
  ctx : String,
) -> @dslx.Tree raise DecodeError {
  dslx_expect_kind(tree, "refx:" + rule, ctx)
  dslx_child(tree, 0, ctx + "." + rule)
}

///|
fn dslx_name(tree : @dslx.Tree, ctx : String) -> String raise DecodeError {
  let node = dslx_ref_payload(tree, "name", ctx)
  if node.text.length() == 0 {
    raise dslx_decode_error("empty name for " + ctx)
  }
  node.text
}

///|
fn dslx_type_ref(tree : @dslx.Tree, ctx : String) -> String raise DecodeError {
  let typx = dslx_ref_payload(tree, "typx", ctx)
  dslx_expect_kind(typx, "altx", ctx)
  let lit = dslx_child(typx, 0, ctx + ".type")
  match lit.text {
    "text" => "String"
    "int" => "Int"
    "bool" => "Bool"
    other => raise dslx_decode_error("unsupported type " + other)
  }
}

///|
fn dslx_decode_field(
  tree : @dslx.Tree,
) -> @schema.AttributeDefinition raise DecodeError {
  let seq = dslx_ref_payload(tree, "fldx", "field")
  dslx_expect_kind(seq, "seqx", "field")
  {
    name: dslx_name(dslx_child(seq, 0, "field.name"), "field.name"),
    type_ref: dslx_type_ref(dslx_child(seq, 2, "field.type"), "field.type"),
    optional: false,
  }
}

///|
fn dslx_decode_state(
  tree : @dslx.Tree,
) -> @schema.StateDefinition raise DecodeError {
  let seq = dslx_ref_payload(tree, "stat", "state")
  dslx_expect_kind(seq, "seqx", "state")
  { name: dslx_name(dslx_child(seq, 1, "state.name"), "state.name") }
}

///|
fn dslx_decode_entity(
  tree : @dslx.Tree,
  initial_state : String,
) -> @schema.EntityDefinition raise DecodeError {
  let seq = dslx_ref_payload(tree, "enty", "entity")
  dslx_expect_kind(seq, "seqx", "entity")
  let attrs : Array[@schema.AttributeDefinition] = []
  let fields = dslx_child(seq, 3, "entity.fields")
  dslx_expect_kind(fields, "many", "entity.fields")
  for field in fields.kids {
    attrs.push(dslx_decode_field(field))
  }
  {
    name: dslx_name(dslx_child(seq, 1, "entity.name"), "entity.name"),
    initial_state,
    attributes: attrs,
  }
}

///|
fn dslx_decode_tref(
  tree : @dslx.Tree,
  rules : Array[@schema.RuleExpression],
  effects : Array[String],
) -> Unit raise DecodeError {
  let seq = dslx_ref_payload(tree, "tref", "transition.ref")
  dslx_expect_kind(seq, "altx", "transition.ref")
  let body = dslx_child(seq, 0, "transition.ref.body")
  dslx_expect_kind(body, "seqx", "transition.ref.body")
  let kind = dslx_child(body, 0, "transition.ref.kind").text
  let name = dslx_name(
    dslx_child(body, 1, "transition.ref.name"),
    "transition.ref.name",
  )
  if kind == "rule" {
    rules.push(@schema.RuleExpression::Preset(name))
  } else if kind == "effect" {
    effects.push(name)
  } else {
    raise dslx_decode_error("unknown transition ref " + kind)
  }
}

///|
fn dslx_decode_transition(
  tree : @dslx.Tree,
) -> @schema.TransitionDefinition raise DecodeError {
  let seq = dslx_ref_payload(tree, "tran", "transition")
  dslx_expect_kind(seq, "seqx", "transition")
  let rules : Array[@schema.RuleExpression] = []
  let effects : Array[String] = []
  let refs = dslx_child(seq, 6, "transition.refs")
  let ref_block = match refs.kind {
    "seqx" => Some(refs)
    "optx" => None
    other =>
      raise dslx_decode_error("expected transition ref block, got " + other)
  }
  match ref_block {
    Some(block) => {
      let ref_items = dslx_child(block, 1, "transition.refs.items")
      dslx_expect_kind(ref_items, "many", "transition.refs.items")
      for item in ref_items.kids {
        dslx_decode_tref(item, rules, effects)
      }
    }
    None => ()
  }
  {
    name: dslx_name(dslx_child(seq, 1, "transition.name"), "transition.name"),
    from: dslx_name(dslx_child(seq, 3, "transition.from"), "transition.from"),
    to: dslx_name(dslx_child(seq, 5, "transition.to"), "transition.to"),
    rules,
    effects,
    input_schema: None,
  }
}

///|
fn dslx_decode_effect(
  tree : @dslx.Tree,
) -> @schema.EffectDefinition raise DecodeError {
  let seq = dslx_ref_payload(tree, "effx", "effect")
  dslx_expect_kind(seq, "seqx", "effect")
  {
    name: dslx_name(dslx_child(seq, 1, "effect.name"), "effect.name"),
    kind: @core.EffectKind::Sync,
  }
}

///|
fn dslx_decode_rule_kind(
  tree : @dslx.Tree,
) -> @schema.RuleExpression raise DecodeError {
  let rkind = dslx_ref_payload(tree, "rkind", "rule.kind")
  dslx_expect_kind(rkind, "altx", "rule.kind")
  let body = dslx_child(rkind, 0, "rule.kind.body")
  dslx_expect_kind(body, "seqx", "rule.kind.body")
  let kind = dslx_child(body, 0, "rule.kind.kind").text
  let name = dslx_name(dslx_child(body, 1, "rule.kind.name"), "rule.kind.name")
  if kind == "preset" {
    @schema.RuleExpression::Preset(name)
  } else if kind == "custom" {
    @schema.RuleExpression::Custom(name)
  } else {
    raise dslx_decode_error("unknown rule kind " + kind)
  }
}

///|
fn dslx_decode_rule(
  tree : @dslx.Tree,
) -> @schema.RuleDefinition raise DecodeError {
  let seq = dslx_ref_payload(tree, "rulx", "rule")
  dslx_expect_kind(seq, "seqx", "rule")
  {
    name: dslx_name(dslx_child(seq, 1, "rule.name"), "rule.name"),
    expr: dslx_decode_rule_kind(dslx_child(seq, 3, "rule.kind")),
    description: None,
  }
}

///|
fn dslx_decode_item(
  tree : @dslx.Tree,
  states : Array[@schema.StateDefinition],
  entities : Array[@schema.EntityDefinition],
  transitions : Array[@schema.TransitionDefinition],
  effects : Array[@schema.EffectDefinition],
  rules : Array[@schema.RuleDefinition],
) -> Unit raise DecodeError {
  let item = dslx_ref_payload(tree, "item", "item")
  dslx_expect_kind(item, "altx", "item")
  let body = dslx_child(item, 0, "item.body")
  match body.kind {
    "refx:stat" => states.push(dslx_decode_state(body))
    "refx:enty" => {
      if states.length() == 0 {
        raise dslx_decode_error("entity requires a preceding state")
      }
      let initial_state = states[0].name
      entities.push(dslx_decode_entity(body, initial_state))
    }
    "refx:tran" => transitions.push(dslx_decode_transition(body))
    "refx:effx" => effects.push(dslx_decode_effect(body))
    "refx:rulx" => rules.push(dslx_decode_rule(body))
    other => raise dslx_decode_error("unknown item " + other)
  }
}

///|
fn schema_from_dslx_l1_tree(
  tree : @dslx.Tree,
) -> @schema.Schema raise DecodeError {
  dslx_expect_kind(tree, "seqx", "schema")
  let states : Array[@schema.StateDefinition] = []
  let entities : Array[@schema.EntityDefinition] = []
  let transitions : Array[@schema.TransitionDefinition] = []
  let rules : Array[@schema.RuleDefinition] = []
  let effects : Array[@schema.EffectDefinition] = []
  let items = dslx_child(tree, 2, "schema.items")
  dslx_expect_kind(items, "many", "schema.items")
  for item in items.kids {
    dslx_decode_item(item, states, entities, transitions, effects, rules)
  }
  {
    fwd_version: "1.0",
    schema_version: "1.0",
    states,
    entities,
    transitions,
    rules,
    reasons: [],
    boundaries: [],
    effects,
  }
}

///|
fn format_dslx_diagnostics(digs : Array[@dslx.Diag]) -> String {
  if digs.length() == 0 {
    "dslx parse failed"
  } else {
    match digs[0].hint {
      Some(value) => digs[0].text + ": " + value
      None => digs[0].text
    }
  }
}
