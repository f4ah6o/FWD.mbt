///|
/// v5.0 Observability surfaces (read-only, deterministic).

///|
pub fn metrics_summary_json() -> String {
  let obj : Map[String, Json] = Map::new()
  obj["scope"] = Json::string("global")
  obj["jobs"] = Json::object({
    "queued": Json::number(1),
    "running": Json::number(0),
    "done": Json::number(1),
    "failed": Json::number(0),
    "canceled": Json::number(0),
    "expired": Json::number(0),
  })
  obj["exports"] = Json::object({
    "jsonl": Json::number(1),
    "csv": Json::number(1),
  })
  Json::object(obj).stringify(indent=2)
}

///|
pub fn export_audit_json() -> String {
  let entries : Array[Json] = []
  entries.push(Json::object({
    "jobId": Json::string("job-1"),
    "kind": Json::string("single"),
    "status": Json::string("done"),
    "format": Json::string("jsonl"),
    "ttlSeconds": Json::number(120),
  }))
  entries.push(Json::object({
    "jobId": Json::string("job-2"),
    "kind": Json::string("batch"),
    "status": Json::string("running"),
    "format": Json::string("csv"),
    "ttlSeconds": Json::number(240),
  }))
  let obj : Map[String, Json] = Map::new()
  obj["entries"] = Json::array(entries)
  Json::object(obj).stringify(indent=2)
}
