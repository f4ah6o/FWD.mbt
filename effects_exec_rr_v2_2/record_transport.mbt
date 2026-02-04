///|
/// Record transport that captures request/response pairs into a cassette.

///|
pub(all) struct Recorder {
  mut entries : Array[CassetteEntry]
}

///|
pub fn Recorder::new() -> Recorder {
  { entries: [] }
}

///|
pub fn Recorder::append(self : Recorder, entry : CassetteEntry) -> Unit {
  self.entries.push(entry)
}

///|
pub fn Recorder::to_cassette(self : Recorder, version : String) -> Cassette {
  { cassette_version: version, entries: self.entries }
}

///|
fn request_from_http(req : @effects_exec_adapters_v2_2.HttpRequest) -> CassetteRequest {
  { http_method: req.http_method, url: req.url, headers: req.headers, body: req.body }
}

///|
fn response_from_http(resp : @effects_exec_adapters_v2_2.HttpResponse) -> CassetteResponse {
  { status: resp.status, headers: Map::new(), body: resp.body }
}

///|
pub fn record_transport(
  recorder : Recorder,
  send : (@effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason],
) -> (@effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason] {
  fn transport(req : @effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason] {
    match send(req) {
      Ok(resp) => {
        recorder.append({
          request: request_from_http(req),
          response: response_from_http(resp),
        })
        Ok(resp)
      }
      Err(reason) => Err(reason)
    }
  }
  transport
}

///|
fn merge_reasons(items : Array[@effects_v2_2.ExecutionItem]) -> Array[@core.Reason] {
  let reasons : Array[@core.Reason] = []
  for item in items {
    match item.reason {
      Some(value) => reasons.push(value)
      None => ()
    }
  }
  reasons
}

///|
fn status_from_items(items : Array[@effects_v2_2.ExecutionItem]) -> @effects_v2_2.ExecutionStatus {
  for item in items {
    match item.status {
      @effects_v2_2.ExecutionStatus::Failed => return @effects_v2_2.ExecutionStatus::Failed
      _ => ()
    }
  }
  @effects_v2_2.ExecutionStatus::Executed
}

///|
pub fn record_execute_plan(
  plan : @effects_v2_2.EffectsPlan,
  allowlist : Array[String],
  send : (@effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason],
) -> (@effects_v2_2.ExecutionResult, Cassette) {
  let recorder = Recorder::new()
  let transport = record_transport(recorder, send)
  match plan.status {
    @effects_v2_2.PlanStatus::Skipped => {
      let result : @effects_v2_2.ExecutionResult = {
        result_version: @effects_v2_2.result_version_v2_2(),
        plan_version: plan.plan_version,
        entity_id: plan.entity_id,
        transition_id: plan.transition_id,
        status: @effects_v2_2.ExecutionStatus::Skipped,
        items: [],
        reasons: plan.reasons,
      }
      let cassette = recorder.to_cassette("2.2")
      (result, cassette)
    }
    @effects_v2_2.PlanStatus::Planned => {
      let items : Array[@effects_v2_2.ExecutionItem] = []
      for item in plan.items {
        match @effects_exec_adapters_v2_2.run_http_effect(allowlist, item, transport) {
          Ok(executed) => items.push(executed)
          Err(reason) => items.push({
            effect_id: item.effect_id,
            status: @effects_v2_2.ExecutionStatus::Failed,
            reason: Some(reason),
          })
        }
      }
      let result : @effects_v2_2.ExecutionResult = {
        result_version: @effects_v2_2.result_version_v2_2(),
        plan_version: plan.plan_version,
        entity_id: plan.entity_id,
        transition_id: plan.transition_id,
        status: status_from_items(items),
        items,
        reasons: merge_reasons(items),
      }
      let cassette = recorder.to_cassette("2.2")
      (result, cassette)
    }
  }
}
