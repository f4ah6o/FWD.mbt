///|
/// JSON projection for metrics (v3.6).

fn kind_string(kind : MetricKind) -> String {
  match kind {
    MetricKind::Transition => "transition"
    MetricKind::Effect => "effect"
    MetricKind::Policy => "policy"
  }
}

fn counts_json(counts : MetricCounts) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["ok"] = Json::number(counts.ok.to_double())
  obj["failed"] = Json::number(counts.failed.to_double())
  obj["blocked"] = Json::number(counts.blocked.to_double())
  obj["denied"] = Json::number(counts.denied.to_double())
  Json::object(obj)
}

fn option_number(value : Int?) -> Json {
  match value {
    Some(v) => Json::number(v.to_double())
    None => Json::null()
  }
}

fn window_json(window : MetricWindow) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["entityId"] = Json::string(window.entity_id)
  obj["fromLogicalTime"] = option_number(window.from_logical_time)
  obj["toLogicalTime"] = option_number(window.to_logical_time)
  Json::object(obj)
}

fn by_kind_json(item : MetricsByKind) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["kind"] = Json::string(kind_string(item.kind))
  obj["counts"] = counts_json(item.counts)
  Json::object(obj)
}

///|
pub fn metrics_json(snapshot : MetricsSnapshot) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["window"] = window_json(snapshot.window)
  obj["total"] = counts_json(snapshot.total)
  let arr : Array[Json] = []
  for item in snapshot.by_kind {
    arr.push(by_kind_json(item))
  }
  obj["byKind"] = Json::array(arr)
  Json::object(obj)
}
