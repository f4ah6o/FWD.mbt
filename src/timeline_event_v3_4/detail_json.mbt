///|
/// JSON projection for timeline event detail (v3.4).

///|
pub fn detail_json(detail : TimelineEventDetail) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["eventId"] = Json::string(detail.event_id)
  obj["entityId"] = Json::string(detail.event.entity_id)
  obj["logicalTime"] = Json::number(detail.event.logical_time.to_double())
  obj["sequence"] = Json::number(detail.event.sequence.to_double())
  obj["kind"] = Json::string(kind_string(detail.event.kind))
  obj["refId"] = Json::string(detail.event.ref_id)
  obj["status"] = Json::string(detail.event.status)
  let reasons : Array[Json] = []
  for reason in detail.event.reasons {
    reasons.push(@compiler.reason_json(reason))
  }
  obj["reasons"] = Json::array(reasons)
  Json::object(obj)
}
