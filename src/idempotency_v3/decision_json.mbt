///|
/// JSON projection for idempotency decisions (v3).

fn decision_kind_string(kind : DecisionKind) -> String {
  match kind {
    DecisionKind::Reserved => "reserved"
    DecisionKind::Conflict => "conflict"
    DecisionKind::Done => "done"
    DecisionKind::AlreadyDone => "already_done"
  }
}

///|
pub fn decision_json(decision : Decision) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["key"] = Json::string(decision.key)
  obj["kind"] = Json::string(decision_kind_string(decision.kind))
  obj["logicalTime"] = Json::number(decision.logical_time.to_double())
  obj["reservedAt"] = Json::number(decision.reserved_at.to_double())
  if decision.result_ref != "" {
    obj["resultRef"] = Json::string(decision.result_ref)
  }
  Json::object(obj)
}
