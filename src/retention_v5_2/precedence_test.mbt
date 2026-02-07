///|
fn policy_poll(limit : Int) -> @export_job_v5_2.RetentionPolicyV52 {
  {
    combine: @export_job_v5_2.RetentionCombineV52::All,
    axes: [@export_job_v5_2.RetentionAxisConditionV52::PollCountMax(limit)],
  }
}

///|
test "precedence v5.2 selects job over batch and system" {
  let resolved = resolve_retention_policy_v52(
    Some(policy_poll(9)),
    Some(policy_poll(5)),
    Some(policy_poll(1)),
  )
  inspect(resolved.selected_scope, content="job")
}

///|
test "precedence v5.2 selects batch over system when no job policy" {
  let resolved = resolve_retention_policy_v52(
    None,
    Some(policy_poll(5)),
    Some(policy_poll(1)),
  )
  inspect(resolved.selected_scope, content="batch")
}

///|
test "precedence v5.2 selects system when only system policy exists" {
  let resolved = resolve_retention_policy_v52(
    None,
    None,
    Some(policy_poll(1)),
  )
  inspect(resolved.selected_scope, content="system")
}
