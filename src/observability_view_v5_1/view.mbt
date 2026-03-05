///|
/// v5.1 optional read-only views (per-job and per-batch).
/// These views expose only data already visible in the global view
/// and introduce no new information.

///|
fn status_string(status : @export_job_v5.JobStatus) -> String {
  match status {
    @export_job_v5.JobStatus::Queued => "queued"
    @export_job_v5.JobStatus::Running => "running"
    @export_job_v5.JobStatus::Done => "done"
    @export_job_v5.JobStatus::Failed => "failed"
    @export_job_v5.JobStatus::Canceled => "canceled"
    @export_job_v5.JobStatus::Expired => "expired"
  }
}

///|
fn progress_json(progress : @export_job_v5.JobProgress) -> Json {
  Json::object({
    "processed": Json::number(progress.processed.to_double()),
    "total": Json::number(progress.total.to_double()),
  })
}

///|
/// Per-job read-only view. Returns None if the job is not found.
pub fn job_view_json(job_id : String) -> String? {
  match @job_store_v5.get_job(job_id) {
    Some(job) => {
      let obj : Map[String, Json] = Map::new()
      obj["jobVersion"] = Json::string("5.1")
      obj["jobId"] = Json::string(job.id.value)
      obj["status"] = Json::string(status_string(job.status))
      obj["progress"] = progress_json(job.progress)
      obj["ttlSeconds"] = Json::number(job.retention.ttl_seconds.to_double())
      Some(Json::object(obj).stringify(indent=2))
    }
    None => None
  }
}

///|
/// Per-batch read-only view. Returns None if the batch is not found.
pub fn batch_view_json(batch_id : String) -> String? {
  match @export_job_batch_v5.get_batch(batch_id) {
    Some(batch) => {
      let obj : Map[String, Json] = Map::new()
      obj["jobVersion"] = Json::string("5.1")
      obj["jobId"] = Json::string(batch.id)
      obj["status"] = Json::string(status_string(batch.status))
      obj["progress"] = progress_json(batch.progress)
      obj["ttlSeconds"] = Json::number(batch.retention.ttl_seconds.to_double())
      let child_ids : Array[Json] = []
      for child_id in batch.child_ids {
        child_ids.push(Json::string(child_id))
      }
      obj["childIds"] = Json::array(child_ids)
      Some(Json::object(obj).stringify(indent=2))
    }
    None => None
  }
}
