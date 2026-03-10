///|
test "builder_to_schema compacts blank slots" {
  let builder : BuilderState = {
    entity_name: "Request",
    initial_state: "Draft",
    states: ["Draft", "Approved", ""],
    transitions: [
      { name: "approve", from: "Draft", to: "Approved" },
      { name: "", from: "", to: "" },
    ],
  }
  let schema = builder_to_schema(builder)
  inspect(schema.states.length(), content="2")
  inspect(schema.transitions.length(), content="1")
}

///|
test "evaluate_builder valid default preview" {
  let model = evaluate_builder(default_builder())
  match model.validation_reason {
    None => ()
    Some(reason) => fail("unexpected validation error: " + reason.code())
  }
  inspect(model.previews.length(), content="3")
  let draft = model.previews[0]
  inspect(draft.state, content="Draft")
  inspect(draft.available.length(), content="2")
  inspect(draft.available[0].id, content="reject")
  inspect(draft.available[1].id, content="approve")
}

///|
test "evaluate_builder invalid transition target" {
  let builder : BuilderState = {
    entity_name: "Request",
    initial_state: "Draft",
    states: ["Draft"],
    transitions: [{ name: "approve", from: "Draft", to: "Approved" }],
  }
  let model = evaluate_builder(builder)
  match model.validation_reason {
    Some(reason) => inspect(reason.code(), content="unknown_state")
    None => fail("expected validation error")
  }
  inspect(model.previews.length(), content="0")
}
