///|
/// JSON projection for retry policy schedule (v3).

fn backoff_kind_string(kind : BackoffKind) -> String {
  match kind {
    BackoffKind::Fixed => "fixed"
    BackoffKind::Exponential => "exponential"
  }
}

fn backoff_json(backoff : BackoffPolicy) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["kind"] = Json::string(backoff_kind_string(backoff.kind))
  match backoff.kind {
    BackoffKind::Fixed => {
      obj["delayMs"] = Json::number(backoff.delay_ms.to_double())
    }
    BackoffKind::Exponential => {
      obj["baseDelayMs"] = Json::number(backoff.delay_ms.to_double())
      obj["factor"] = Json::number(backoff.factor.to_double())
    }
  }
  Json::object(obj)
}

///|
pub fn retry_policy_schedule_json(policy : RetryPolicy) -> Json {
  let obj : Map[String, Json] = Map::new()
  obj["policyVersion"] = Json::string(policy.policy_version)
  obj["maxAttempts"] = Json::number(policy.max_attempts.to_double())
  obj["backoff"] = backoff_json(policy.backoff)
  let schedule : Array[Json] = []
  for delay in retry_schedule(policy) {
    schedule.push(Json::number(delay.to_double()))
  }
  obj["scheduleMs"] = Json::array(schedule)
  Json::object(obj)
}
