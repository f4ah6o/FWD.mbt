///|
/// Private dslx-backed description of the first FWD schema/compiler slice.
///
/// This package still keeps production CLI/API/runtime behavior on the existing
/// compiler path. The dslx value below is a checked specification and a
/// dependency contract for future generated compiler work.

///|
fn fwd_dslx_schema_compiler_spec() -> @dslx.Dslx {
  @dslx.fwds()
}

///|
fn fwd_dslx_schema_compiler_example() -> @dslx.File {
  @dslx.file("examples/schema.dsl", "schema Schema title:text version:text\n")
}

///|
fn fwd_dslx_schema_compiler_project() -> @dslx.Proj {
  @dslx.proj("fwd-schema-compiler")
  .dslx(fwd_dslx_schema_compiler_spec())
  .file(@dslx.file("README.md", "# FWD schema compiler\n"))
  .exmp(fwd_dslx_schema_compiler_example())
}

///|
fn fwd_dslx_schema_compiler_example_diagnostics() -> Array[@dslx.Diag] {
  @dslx.chex(
    fwd_dslx_schema_compiler_project(),
    "Fwd",
    "sche",
    fwd_dslx_schema_compiler_example(),
  )
}

///|
fn dslx_compile_yaml_first_slice(
  input : String,
) -> Result[@ir.FwdIR, CompileError] {
  let _files = @dslx.pack(fwd_dslx_schema_compiler_project())
  match parse_yaml(input) {
    Ok(schema) =>
      match resolve_schema(schema) {
        Ok(resolved) =>
          match validate_schema(resolved) {
            Ok(_) => Ok(emit_ir_from_schema(resolved.schema))
            Err(reason) => Err(ValidationFailure(reason))
          }
        Err(err) => Err(err)
      }
    Err(err) => Err(err)
  }
}
