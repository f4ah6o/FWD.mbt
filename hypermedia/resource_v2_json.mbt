///|
/// JSON projection for Hypermedia Resource (v2).

///|
fn reason_json_v2(reason : @core.Reason) -> Json {
  @compiler.reason_json(reason)
}

///|
pub fn resource_v2_json(resource : ResourceV2) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["state"] = Json::string(resource.state)
  let transitions : Array[Json] = []
  for tr in resource.transitions {
    let tr_obj : Map[String, Json] = Map::new()
    tr_obj["id"] = Json::string(tr.id)
    tr_obj["to"] = Json::string(tr.to)
    match tr.input_schema {
      Some(value) => tr_obj["inputSchema"] = Json::string(value)
      None => ()
    }
    match tr.payload {
      Some(value) => tr_obj["payload"] = value
      None => ()
    }
    let errors : Array[Json] = []
    for reason in tr.errors {
      errors.push(reason_json_v2(reason))
    }
    tr_obj["errors"] = Json::array(errors)
    tr_obj["canExecute"] = Json::boolean(tr.can_execute)
    transitions.push(Json::object(tr_obj))
  }
  obj["transitions"] = Json::array(transitions)
  Json::object(obj)
}
