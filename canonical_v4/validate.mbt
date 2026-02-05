///|
/// v4 canonical JSON validation helpers (fixture-first).

fn expect_object(json : Json, label : String) -> Map[String, Json] raise {
  let result : Result[Map[String, Json], @json.JsonDecodeError] = try? @json.from_json(json)
  match result {
    Ok(obj) => obj
    Err(err) => fail(label + ": expected object: " + err.to_string())
  }
}

fn expect_string(json : Json, label : String) -> String raise {
  let result : Result[String, @json.JsonDecodeError] = try? @json.from_json(json)
  match result {
    Ok(value) => value
    Err(err) => fail(label + ": expected string: " + err.to_string())
  }
}

fn expect_array(json : Json, label : String) -> Array[Json] raise {
  let result : Result[Array[Json], @json.JsonDecodeError] = try? @json.from_json(json)
  match result {
    Ok(value) => value
    Err(err) => fail(label + ": expected array: " + err.to_string())
  }
}

fn require_keys(obj : Map[String, Json], keys : Array[String], label : String) -> Unit raise {
  for key in keys {
    if !obj.contains(key) {
      fail(label + ": missing key " + key)
    }
  }
}

///|
pub fn validate_resource(json : Json) -> Unit raise {
  let obj = expect_object(json, "resource")
  require_keys(obj, ["resourceVersion", "entity", "input", "policy", "effects", "timeline"], "resource")
  ignore(expect_string(obj["resourceVersion"], "resourceVersion"))
  let entity = expect_object(obj["entity"], "entity")
  require_keys(entity, ["id", "state", "logicalTime"], "entity")
  ignore(expect_string(entity["id"], "entity.id"))
  ignore(expect_string(entity["state"], "entity.state"))
  let input = expect_object(obj["input"], "input")
  require_keys(input, ["schema", "draft", "fieldErrors"], "input")
  let field_errors = expect_array(input["fieldErrors"], "input.fieldErrors")
  ignore(field_errors)
  let timeline = expect_object(obj["timeline"], "timeline")
  require_keys(timeline, ["cursor", "events"], "timeline")
  ignore(expect_string(timeline["cursor"], "timeline.cursor"))
}

///|
pub fn validate_timeline_list(json : Json) -> Unit raise {
  let obj = expect_object(json, "timeline.list")
  require_keys(obj, ["timelineVersion", "query", "events", "nextCursor"], "timeline.list")
  ignore(expect_string(obj["timelineVersion"], "timelineVersion"))
  let query = expect_object(obj["query"], "timeline.query")
  require_keys(query, ["entityId", "limit", "cursor"], "timeline.query")
  ignore(expect_string(query["entityId"], "timeline.query.entityId"))
  ignore(expect_string(query["cursor"], "timeline.query.cursor"))
  ignore(expect_string(obj["nextCursor"], "timeline.nextCursor"))
}

///|
pub fn validate_timeline_detail(json : Json) -> Unit raise {
  let obj = expect_object(json, "timeline.detail")
  require_keys(obj, ["timelineVersion", "event", "prevEventId", "nextEventId"], "timeline.detail")
  ignore(expect_string(obj["timelineVersion"], "timelineVersion"))
  let event = expect_object(obj["event"], "timeline.event")
  require_keys(event, ["eventId", "entityId", "logicalTime", "sequence", "kind", "refId", "status", "reasons"], "timeline.event")
  ignore(expect_string(event["eventId"], "timeline.event.eventId"))
}

///|
pub fn validate_effects_execute(json : Json) -> Unit raise {
  let obj = expect_object(json, "effects")
  require_keys(obj, ["effectsVersion", "plan", "execution", "audit"], "effects")
  ignore(expect_string(obj["effectsVersion"], "effectsVersion"))
  let plan = expect_object(obj["plan"], "effects.plan")
  require_keys(plan, ["planVersion", "entityId", "transitionId", "status", "items", "reasons"], "effects.plan")
  ignore(expect_string(plan["planVersion"], "effects.plan.planVersion"))
}
