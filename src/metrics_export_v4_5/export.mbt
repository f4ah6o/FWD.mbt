///|
/// Metrics export contract (v4.5).

fn kind_string(kind : @metrics_v3_6.MetricKind) -> String {
  match kind {
    @metrics_v3_6.MetricKind::Transition => "transition"
    @metrics_v3_6.MetricKind::Effect => "effect"
    @metrics_v3_6.MetricKind::Policy => "policy"
  }
}

fn counts_json(counts : @metrics_v3_6.MetricCounts) -> Json {
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

fn window_json(window : @metrics_v3_6.MetricWindow) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["entityId"] = Json::string(window.entity_id)
  obj["fromLogicalTime"] = option_number(window.from_logical_time)
  obj["toLogicalTime"] = option_number(window.to_logical_time)
  Json::object(obj)
}

fn line_json_total(snapshot : @metrics_v3_6.MetricsSnapshot) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["type"] = Json::string("total")
  obj["window"] = window_json(snapshot.window)
  obj["counts"] = counts_json(snapshot.total)
  Json::object(obj)
}

fn line_json_kind(item : @metrics_v3_6.MetricsByKind, window : @metrics_v3_6.MetricWindow) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["type"] = Json::string("kind")
  obj["window"] = window_json(window)
  obj["kind"] = Json::string(kind_string(item.kind))
  obj["counts"] = counts_json(item.counts)
  Json::object(obj)
}

///|
pub fn export_jsonl(snapshot : @metrics_v3_6.MetricsSnapshot) -> String {
  let sb = StringBuilder::new()
  sb.write_view(line_json_total(snapshot).stringify())
  for item in snapshot.by_kind {
    sb.write_char('\n')
    sb.write_view(line_json_kind(item, snapshot.window).stringify())
  }
  sb.to_string()
}

fn csv_cell(value : String) -> String {
  if value.contains(",") || value.contains("\n") || value.contains("\"") {
    let escaped = value.replace(old="\"", new="\"\"")
    "\"" + escaped + "\""
  } else {
    value
  }
}

fn option_to_string(value : Int?) -> String {
  match value {
    Some(v) => v.to_string()
    None => ""
  }
}

fn counts_row(counts : @metrics_v3_6.MetricCounts) -> Array[String] {
  [
    counts.ok.to_string(),
    counts.failed.to_string(),
    counts.blocked.to_string(),
    counts.denied.to_string(),
  ]
}

fn csv_line(fields : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<fields.length() {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_view(csv_cell(fields[i]))
  }
  sb.to_string()
}

fn append_all(target : Array[String], items : Array[String]) -> Unit {
  for item in items {
    target.push(item)
  }
}

///|
pub fn export_csv(snapshot : @metrics_v3_6.MetricsSnapshot) -> String {
  let sb = StringBuilder::new()
  sb.write_view("type,entityId,fromLogicalTime,toLogicalTime,kind,ok,failed,blocked,denied")
  sb.write_char('\n')
  let window = snapshot.window
  let total_row : Array[String] = []
  append_all(total_row, [
    "total",
    window.entity_id,
    option_to_string(window.from_logical_time),
    option_to_string(window.to_logical_time),
    "",
  ])
  append_all(total_row, counts_row(snapshot.total))
  sb.write_view(csv_line(total_row))
  for item in snapshot.by_kind {
    sb.write_char('\n')
    let row : Array[String] = []
    append_all(row, [
      "kind",
      window.entity_id,
      option_to_string(window.from_logical_time),
      option_to_string(window.to_logical_time),
      kind_string(item.kind),
    ])
    append_all(row, counts_row(item.counts))
    sb.write_view(csv_line(row))
  }
  sb.to_string()
}
