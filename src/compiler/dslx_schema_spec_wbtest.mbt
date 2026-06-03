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
    #|rules:
    #|  - name: hasReview
    #|    type: preset
    #|    preset: allReferencesResolved
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
    #|      - hasReview
    #|
    #|  - name: deprecate
    #|    from: Released
    #|    to: Released
    #|    effects:
    #|      - notifyDependentSchemas
    #|
    #|effects:
    #|  - name: notifyDependentSchemas
    #|    kind: sync
    #|
  value
}

///|
fn dslx_sample_text() -> String {
  (
    #|schema Schema
    #|state Draft
    #|state Reviewing
    #|state Released
    #|entity Schema { title:text version:text }
    #|effect notifyDependentSchemas
    #|rule hasReview: preset allReferencesResolved
    #|transition submitForReview: Draft -> Reviewing rule hasAtLeastOneState rule hasAtLeastOneTransition
    #|transition approve: Reviewing -> Released rule hasReview
    #|transition deprecate: Released -> Released effect notifyDependentSchemas
  )
}

///|
fn dslx_text_missing_effect() -> String {
  (
    #|schema Schema
    #|state Draft
    #|state Released
    #|entity Schema { title:text }
    #|transition submit: Draft -> Released effect notify
  )
}

///|
fn dslx_text_conflicting_rule() -> String {
  (
    #|schema Schema
    #|state Draft
    #|state Released
    #|entity Schema { title:text }
    #|rule hasAtLeastOneState: preset hasAtLeastOneState
    #|transition submit: Draft -> Released rule hasAtLeastOneState
    #|effect notify
  )
}

///|
fn dslx_text_unknown_type() -> String {
  (
    #|schema Schema
    #|state Draft
    #|state Released
    #|entity Schema { title:blob }
    #|transition submit: Draft -> Released
    #|effect notify
  )
}

///|
fn dslx_ir_json(input : String) -> Result[String, String] {
  match compile_dslx_l1(input) {
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
  inspect(@dslx.runx(spec, "sche", dslx_sample_text()).done, content="true")
}

///|
test "dslx schema compiler project checks examples through dslx" {
  let project = fwd_dslx_schema_compiler_project()
  let example = fwd_dslx_schema_compiler_example()
  match @dslx.fspc(project, "Fwd") {
    Some(spec) => inspect(@dslx.name(spec), content="Fwd")
    None => inspect("none", content="Fwd")
  }
  inspect(@dslx.fspc(project, "Missing") is None, content="true")
  inspect(@dslx.runp(project, "Fwd", "sche", example.text).done, content="true")
  inspect(fwd_dslx_schema_compiler_example_diagnostics().length(), content="0")
  let missing = @dslx.runp(project, "Missing", "sche", example.text)
  inspect(missing.done, content="false")
  inspect(missing.digs[0].text, content="unknown project spec")
  match missing.digs[0].hint {
    Some(value) => inspect(value, content="Missing")
    None => inspect("none", content="hint")
  }
  let invalid = @dslx.chex(
    project,
    "Fwd",
    "sche",
    @dslx.file("examples/invalid.dsl", "schema"),
  )
  inspect(invalid.length() > 0, content="true")
}

///|
test "dslx compile slice matches existing compiler pipeline" {
  inspect(
    dslx_ir_json(dslx_sample_text()) == existing_ir_json(dslx_sample_yaml()),
    content="true",
  )
}

///|
test "dslx compile slice preserves validation failure behavior" {
  inspect(
    dslx_ir_json(dslx_text_missing_effect()),
    content=(
      #|Err(validation error: unknown_effect: transition effect is not defined)
    ),
  )
}

///|
test "dslx compile slice preserves resolve failure behavior" {
  inspect(
    dslx_ir_json(dslx_text_conflicting_rule()),
    content=(
      #|Err(resolve error: rule name conflicts with builtin: hasAtLeastOneState)
    ),
  )
}

///|
test "dslx compile slice rejects unsupported type during parse" {
  inspect(
    dslx_ir_json(dslx_text_unknown_type()),
    content="Err(parse error: unexpected input)",
  )
}
