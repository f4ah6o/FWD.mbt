///|
/// Retention policy precedence resolver for v5.2 draft.
/// Order: job > batch > system.

///|
pub(all) struct PolicyResolutionV52 {
  selected_scope : String
  policy : @export_job_v5_2.RetentionPolicyV52
}

///|
pub fn resolve_retention_policy_v52(
  job_policy : @export_job_v5_2.RetentionPolicyV52?,
  batch_policy : @export_job_v5_2.RetentionPolicyV52?,
  system_policy : @export_job_v5_2.RetentionPolicyV52?,
) -> PolicyResolutionV52 {
  match job_policy {
    Some(policy) => { selected_scope: "job", policy }
    None => match batch_policy {
      Some(policy) => { selected_scope: "batch", policy }
      None => match system_policy {
        Some(policy) => { selected_scope: "system", policy }
        None => {
          selected_scope: "system",
          policy: {
            combine: @export_job_v5_2.RetentionCombineV52::All,
            axes: [@export_job_v5_2.RetentionAxisConditionV52::PollCountMax(3)],
          },
        }
      }
    }
  }
}
