///|
fn dslx_sample_yaml() -> String {
  let value : String =
    #|fwdVersion: "1.0"
    #|schemaVersion: "1.0"
    #|
    #|states:
    #|  - Draft
    #|  - Reviewing
    #|  - Released
    #|
    #|entities:
    #|  - name: Schema
    #|    initialState: Draft
    #|    attributes:
    #|      - name: title
    #|        type: String
    #|      - name: version
    #|        type: String
    #|
    #|reasons:
    #|  - code: ValidationFailure
    #|    message: Validation failed
    #|
    #|boundaries:
    #|  - name: Reviewer
    #|
    #|transitions:
    #|  - name: submitForReview
    #|    from: Draft
    #|    to: Reviewing
    #|    rules:
    #|      - hasAtLeastOneState
    #|      - hasAtLeastOneTransition
    #|
    #|  - name: approve
    #|    from: Reviewing
    #|    to: Released
    #|    rules:
    #|      - allReferencesResolved
    #|
    #|  - name: deprecate
    #|    from: Released
    #|    to: Released
    #|    effects:
    #|      - notifyDependentSchemas
    #|
    #|effects:
    #|  - name: notifyDependentSchemas
    #|    kind: async
    #|
  value
}

///|
fn dslx_yaml_missing_effect() -> String {
  let value : String =
    #|fwdVersion: "1.0"
    #|schemaVersion: "1.0"
    #|
    #|states:
    #|  - Draft
    #|  - Released
    #|
    #|transitions:
    #|  - name: submit
    #|    from: Draft
    #|    to: Released
    #|    effects:
    #|      - notify
    #|
  value
}

///|
fn dslx_yaml_conflicting_rule() -> String {
  let value : String =
    #|fwdVersion: "1.0"
    #|schemaVersion: "1.0"
    #|
    #|states:
    #|  - Draft
    #|  - Released
    #|
    #|rules:
    #|  - name: hasAtLeastOneState
    #|    type: preset
    #|
    #|transitions:
    #|  - name: submit
    #|    from: Draft
    #|    to: Released
    #|    rules:
    #|      - hasAtLeastOneState
    #|
  value
}

///|
fn dslx_ir_json(input : String) -> Result[String, String] {
  match dslx_compile_yaml_first_slice(input) {
    Ok(ir) => Ok(ir_to_json(ir).stringify(indent=2))
    Err(err) => Err(describe_error(err))
  }
}

///|
fn existing_ir_json(input : String) -> Result[String, String] {
  match parse_yaml(input) {
    Ok(schema) =>
      match resolve_schema(schema) {
        Ok(resolved) =>
          match validate_schema(resolved) {
            Ok(_) =>
              Ok(
                ir_to_json(emit_ir_from_schema(resolved.schema)).stringify(
                  indent=2,
                ),
              )
            Err(reason) => Err(describe_error(ValidationFailure(reason)))
          }
        Err(err) => Err(describe_error(err))
      }
    Err(err) => Err(describe_error(err))
  }
}

///|
test "dslx schema compiler spec describes first slice" {
  let spec = fwd_dslx_schema_compiler_spec()
  let project = fwd_dslx_schema_compiler_project()
  let files = @dslx.pack(project)
  inspect(@dslx.name(spec), content="Fwd")
  inspect(@dslx.vspc(spec).length(), content="0")
  inspect(@dslx.vprj(project).length(), content="0")
  inspect(files.length(), content="6")
  inspect(files[0].path, content="README.md")
  inspect(files[1].path, content="examples/schema.dsl")
  inspect(files[2].path, content="Fwd/astx.mbt")
  inspect(
    @dslx.runx(spec, "sche", "schema Schema title:text").done,
    content="true",
  )
}

///|
test "dslx compile slice matches existing compiler pipeline" {
  inspect(
    dslx_ir_json(dslx_sample_yaml()) == existing_ir_json(dslx_sample_yaml()),
    content="true",
  )
}

///|
test "dslx compile slice preserves validation failure behavior" {
  inspect(
    dslx_ir_json(dslx_yaml_missing_effect()),
    content=(
      #|Err(validation error: unknown_effect: transition effect is not defined)
    ),
  )
  inspect(
    dslx_ir_json(dslx_yaml_missing_effect()) ==
    existing_ir_json(dslx_yaml_missing_effect()),
    content="true",
  )
}

///|
test "dslx compile slice preserves resolve failure behavior" {
  inspect(
    dslx_ir_json(dslx_yaml_conflicting_rule()),
    content=(
      #|Err(resolve error: rule name conflicts with builtin: hasAtLeastOneState)
    ),
  )
  inspect(
    dslx_ir_json(dslx_yaml_conflicting_rule()) ==
    existing_ir_json(dslx_yaml_conflicting_rule()),
    content="true",
  )
}
