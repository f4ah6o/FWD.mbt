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

///|
test "purchase request case provides practical preview" {
  let builder = purchase_request_builder()
  inspect(state_slot_count(builder), content="6")
  inspect(transition_slot_count(builder), content="6")
  match builder_for_case("purchase-request") {
    Some(_) => ()
    None => fail("expected practical case builder")
  }
  let model = evaluate_builder(builder)
  match model.validation_reason {
    None => ()
    Some(reason) => fail("unexpected validation error: " + reason.code())
  }
  inspect(model.previews.length(), content="6")
  inspect(model.previews[1].state, content="Submitted")
  inspect(model.previews[1].available.length(), content="2")
  inspect(model.previews[1].available[0].id, content="manager_reject")
  inspect(model.previews[1].available[1].id, content="manager_approve")
  inspect(model.previews[2].available[0].id, content="finance_reject")
  inspect(model.previews[2].available[1].id, content="finance_approve")
  inspect(model.previews[3].available[0].id, content="place_order")
}
