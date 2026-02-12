///|
/// Keep test-only dependency references visible to the package compiler.
fn _keep_canonical_v4_references() -> Unit {
  let _ = @canonical_v4.validate_resource
  let _ = @canonical_v4.validate_timeline_list
  let _ = @canonical_v4.validate_timeline_detail
}
