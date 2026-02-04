///|
/// JSON projection for history events (v2.1).

///|
fn result_string(result : HistoryResult) -> String {
  match result {
    HistoryResult::Executed => "executed"
    HistoryResult::Blocked => "blocked"
    HistoryResult::NotFound => "not_found"
    HistoryResult::NotAvailable => "not_available"
  }
}

///|
fn reason_json(reason : @core.Reason) -> Json {
  @compiler.reason_json(reason)
}

///|
pub fn history_event_json(event : HistoryEvent) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["eventId"] = Json::number(event.event_id.to_double())
  obj["transition"] = Json::string(event.transition)
  obj["from"] = Json::string(event.from_state)
  obj["to"] = Json::string(event.to_state)
  obj["payload"] = event.payload
  obj["result"] = Json::string(result_string(event.result))
  let reasons : Array[Json] = []
  for reason in event.reasons {
    reasons.push(reason_json(reason))
  }
  obj["reasons"] = Json::array(reasons)
  Json::object(obj)
}

///|
pub fn history_list_json(events : Array[HistoryEvent]) -> Json {
  let arr : Array[Json] = []
  for event in events {
    arr.push(history_event_json(event))
  }
  let obj : Map[String, Json] = Map::new()
  obj["events"] = Json::array(arr)
  Json::object(obj)
}
