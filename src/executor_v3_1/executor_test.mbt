///|
fn read_text_exec(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = try? @fs.read_file_to_string(path)
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}

///|
fn load_expected(path : String) -> String raise {
  match read_text_exec(path, "expected") {
    Ok(text) => text
    Err(msg) => fail(msg)
  }
}

fn reason(code : String, message : String, target : String) -> @core.Reason {
  @core.Reason::with_context(
    code,
    message,
    [("target", target)],
  )
}

fn retry_policy_fixed() -> @retry_policy_v3.RetryPolicy {
  {
    policy_version: @retry_policy_v3.policy_version_v3(),
    max_attempts: 3,
    backoff: {
      kind: @retry_policy_v3.BackoffKind::Fixed,
      delay_ms: 1000,
      factor: 1,
    },
  }
}

fn plan_with_url() -> @effects_v2_2.EffectsPlan {
  let payload_obj : Map[String, Json] = Map::new()
  payload_obj["url"] = Json::string("https://api.example.com/notify")
  let payload = Json::object(payload_obj)
  {
    plan_version: @effects_v2_2.plan_version_v2_2(),
    entity_id: "order-1",
    transition_id: "submit",
    status: @effects_v2_2.PlanStatus::Planned,
    items: [
      {
        effect_id: "notify",
        kind: @core.EffectKind::Async,
        payload,
        idempotency_key: "order-1:submit:notify",
      },
    ],
    reasons: [],
  }
}

fn audit_executed(entity : String, transition : String, logical_time : Int) -> @execution_audit_v3.AuditEvent {
  {
    entity_id: entity,
    transition_id: transition,
    logical_time,
    sequence: 1,
    status: @execution_audit_v3.AuditStatus::Executed,
    items: [],
    reasons: [],
  }
}

fn audit_failed(entity : String, transition : String, logical_time : Int, reason : @core.Reason) -> @execution_audit_v3.AuditEvent {
  {
    entity_id: entity,
    transition_id: transition,
    logical_time,
    sequence: 1,
    status: @execution_audit_v3.AuditStatus::Failed,
    items: [
      {
        effect_id: "http:notify",
        status: @execution_audit_v3.ItemStatus::Failed,
        duration_ms: 120,
        reason: Some(reason),
      },
    ],
    reasons: [],
  }
}

///|
test "executor executed fixture" {
  let expected = load_expected("examples/v3_1/executor/expected_executed.json")
  let plan = plan_with_url()
  let allowlist : Array[String] = ["https://api.example.com/"]
  fn send(_req : @effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason] {
    Ok({ status: 200, body: "" })
  }
  let detail : ExecutionDetail = {
    execution_version: execution_version_v3_1(),
    entity_id: "order-1",
    transition_id: "submit",
    status: ExecutionStatus::Executed,
    attempts: [
      {
        attempt: 1,
        logical_time: 10,
        sequence: 1,
        status: AttemptStatus::Executed,
        delay_ms: 0,
        reason: None,
      },
    ],
    idempotency: {
      key: "order-1:submit",
      kind: @idempotency_v3.DecisionKind::Done,
      logical_time: 10,
      reserved_at: 10,
      result_ref: "exec-1",
    },
    retry_policy: retry_policy_fixed(),
    audit_event: audit_executed("order-1", "submit", 10),
  }
  let result = execute_plan_detail(
    plan,
    detail.idempotency,
    detail.retry_policy,
    10,
    allowlist,
    send,
  )
  let mut output = execution_detail_json(result).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "executor retry then success fixture" {
  let expected = load_expected("examples/v3_1/executor/expected_retry_then_success.json")
  let plan = plan_with_url()
  let allowlist : Array[String] = ["https://api.example.com/"]
  let mut calls = 0
  fn send(_req : @effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason] {
    calls = calls + 1
    if calls == 1 {
      Err(reason("EFFECT_HTTP_FAILED", "HTTP request failed", "effect"))
    } else {
      Ok({ status: 200, body: "" })
    }
  }
  let detail : ExecutionDetail = {
    execution_version: execution_version_v3_1(),
    entity_id: "order-1",
    transition_id: "submit",
    status: ExecutionStatus::Executed,
    attempts: [
      {
        attempt: 1,
        logical_time: 20,
        sequence: 1,
        status: AttemptStatus::Failed,
        delay_ms: 0,
        reason: Some(reason("EFFECT_HTTP_FAILED", "HTTP request failed", "effect")),
      },
      {
        attempt: 2,
        logical_time: 21,
        sequence: 1,
        status: AttemptStatus::Executed,
        delay_ms: 1000,
        reason: None,
      },
    ],
    idempotency: {
      key: "order-1:submit",
      kind: @idempotency_v3.DecisionKind::Done,
      logical_time: 21,
      reserved_at: 20,
      result_ref: "exec-2",
    },
    retry_policy: retry_policy_fixed(),
    audit_event: audit_executed("order-1", "submit", 21),
  }
  let result = execute_plan_detail(
    plan,
    detail.idempotency,
    detail.retry_policy,
    20,
    allowlist,
    send,
  )
  let mut output = execution_detail_json(result).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}

///|
test "executor idempotent duplicate fixture" {
  let expected = load_expected("examples/v3_1/executor/expected_idempotent_duplicate.json")
  let plan = plan_with_url()
  let allowlist : Array[String] = ["https://api.example.com/"]
  fn send(_req : @effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason] {
    Ok({ status: 200, body: "" })
  }
  let detail : ExecutionDetail = {
    execution_version: execution_version_v3_1(),
    entity_id: "order-1",
    transition_id: "submit",
    status: ExecutionStatus::Skipped,
    attempts: [],
    idempotency: {
      key: "order-1:submit",
      kind: @idempotency_v3.DecisionKind::AlreadyDone,
      logical_time: 30,
      reserved_at: 10,
      result_ref: "exec-1",
    },
    retry_policy: retry_policy_fixed(),
    audit_event: audit_failed(
      "order-1",
      "submit",
      30,
      reason("IDEMPOTENCY_DUPLICATE", "Already executed", "runtime"),
    ),
  }
  let result = execute_plan_detail(
    plan,
    detail.idempotency,
    detail.retry_policy,
    30,
    allowlist,
    send,
  )
  let mut output = execution_detail_json(result).stringify(indent=2)
  if expected.has_suffix("\n") {
    output = output + "\n"
  }
  inspect(output, content=expected)
}
