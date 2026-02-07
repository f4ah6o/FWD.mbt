///|
/// Deterministic executor (v3.1) with injected transport.

fn reason_runtime(code : String, message : String) -> @core.Reason {
  @core.Reason::with_context(
    code,
    message,
    [("target", "runtime")],
  )
}

fn reason_effect_fallback() -> @core.Reason {
  @core.Reason::with_context(
    "EFFECT_EXECUTION_FAILED",
    "effect execution failed",
    [("target", "effect")],
  )
}

fn audit_executed(
  entity : String,
  transition : String,
  logical_time : Int,
) -> @execution_audit_v3.AuditEvent {
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

fn audit_blocked(
  entity : String,
  transition : String,
  logical_time : Int,
  reasons : Array[@core.Reason],
) -> @execution_audit_v3.AuditEvent {
  {
    entity_id: entity,
    transition_id: transition,
    logical_time,
    sequence: 1,
    status: @execution_audit_v3.AuditStatus::Blocked,
    items: [],
    reasons,
  }
}

fn audit_failed(
  entity : String,
  transition : String,
  logical_time : Int,
  reason : @core.Reason,
) -> @execution_audit_v3.AuditEvent {
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

fn attempt_failure_reason(
  allowlist : Array[String],
  effects : Array[@effects_v2_2.EffectItem],
  send : (@effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason],
) -> @core.Reason? {
  for effect in effects {
    match @effects_exec_adapters_v2_2.run_http_effect(allowlist, effect, send) {
      Ok(item) =>
        match item.status {
          @effects_v2_2.ExecutionStatus::Failed =>
            match item.reason {
              Some(reason) => return Some(reason)
              None => return Some(reason_effect_fallback())
            }
          @effects_v2_2.ExecutionStatus::Executed => ()
          @effects_v2_2.ExecutionStatus::Skipped => return Some(reason_effect_fallback())
        }
      Err(reason) => return Some(reason)
    }
  }
  None
}

///|
pub fn execute_plan_detail(
  plan : @effects_v2_2.EffectsPlan,
  idempotency : @idempotency_v3.Decision,
  retry_policy : @retry_policy_v3.RetryPolicy,
  logical_time_start : Int,
  allowlist : Array[String],
  send : (@effects_exec_adapters_v2_2.HttpRequest) -> Result[@effects_exec_adapters_v2_2.HttpResponse, @core.Reason],
) -> ExecutionDetail {
  let entity = plan.entity_id
  let transition = plan.transition_id
  match idempotency.kind {
    @idempotency_v3.DecisionKind::AlreadyDone => {
      let audit = audit_failed(
        entity,
        transition,
        logical_time_start,
        reason_runtime("IDEMPOTENCY_DUPLICATE", "Already executed"),
      )
      return {
        execution_version: execution_version_v3_1(),
        entity_id: entity,
        transition_id: transition,
        status: ExecutionStatus::Skipped,
        attempts: [],
        idempotency,
        retry_policy,
        audit_event: audit,
      }
    }
    @idempotency_v3.DecisionKind::Conflict => {
      let audit = audit_failed(
        entity,
        transition,
        logical_time_start,
        reason_runtime("IDEMPOTENCY_CONFLICT", "Execution in flight"),
      )
      return {
        execution_version: execution_version_v3_1(),
        entity_id: entity,
        transition_id: transition,
        status: ExecutionStatus::Failed,
        attempts: [],
        idempotency,
        retry_policy,
        audit_event: audit,
      }
    }
    _ => ()
  }
  match plan.status {
    @effects_v2_2.PlanStatus::Skipped => {
      let audit = audit_blocked(entity, transition, logical_time_start, plan.reasons)
      return {
        execution_version: execution_version_v3_1(),
        entity_id: entity,
        transition_id: transition,
        status: ExecutionStatus::Skipped,
        attempts: [],
        idempotency,
        retry_policy,
        audit_event: audit,
      }
    }
    @effects_v2_2.PlanStatus::Planned => ()
  }
  let schedule = @retry_policy_v3.retry_schedule(retry_policy)
  let attempts : Array[Attempt] = []
  let mut success = false
  let mut last_reason : @core.Reason? = None
  let mut last_logical_time = logical_time_start
  let mut attempt_index = 0
  for delay in schedule {
    attempt_index = attempt_index + 1
    let logical_time = logical_time_start + (attempt_index - 1)
    last_logical_time = logical_time
    match attempt_failure_reason(allowlist, plan.items, send) {
      None => {
        attempts.push({
          attempt: attempt_index,
          logical_time,
          sequence: 1,
          status: AttemptStatus::Executed,
          delay_ms: delay,
          reason: None,
        })
        success = true
        break
      }
      Some(reason) => {
        attempts.push({
          attempt: attempt_index,
          logical_time,
          sequence: 1,
          status: AttemptStatus::Failed,
          delay_ms: delay,
          reason: Some(reason),
        })
        last_reason = Some(reason)
      }
    }
  }
  if success {
    let audit = audit_executed(entity, transition, last_logical_time)
    return {
      execution_version: execution_version_v3_1(),
      entity_id: entity,
      transition_id: transition,
      status: ExecutionStatus::Executed,
      attempts,
      idempotency,
      retry_policy,
      audit_event: audit,
    }
  }
  let reason = match last_reason {
    Some(value) => value
    None => reason_effect_fallback()
  }
  let audit = audit_failed(entity, transition, last_logical_time, reason)
  {
    execution_version: execution_version_v3_1(),
    entity_id: entity,
    transition_id: transition,
    status: ExecutionStatus::Failed,
    attempts,
    idempotency,
    retry_policy,
    audit_event: audit,
  }
}
