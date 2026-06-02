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
  inspect(
    fwd_dslx_schema_compiler_spec(),
    content=(
      #|{name: fwd.schema.compiler.v1, nodes: [{name: Schema, fields: [{name: fwdVersion, typx: String, optional: false, aliases: [fwd_version]}, {name: schemaVersion, typx: String, optional: false, aliases: [schema_version]}, {name: states, typx: Array[StateDefinition], optional: false, aliases: []}, {name: entities, typx: Array[EntityDefinition], optional: true, aliases: []}, {name: transitions, typx: Array[TransitionDefinition], optional: false, aliases: []}, {name: rules, typx: Array[RuleDefinition], optional: true, aliases: []}, {name: reasons, typx: Array[ReasonDefinition], optional: true, aliases: []}, {name: boundaries, typx: Array[BoundaryDefinition], optional: true, aliases: []}, {name: effects, typx: Array[EffectDefinition], optional: true, aliases: []}]}, {name: StateDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}]}, {name: AttributeDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}, {name: type, typx: String, optional: false, aliases: [type_ref]}, {name: optional, typx: Bool, optional: true, aliases: []}]}, {name: EntityDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}, {name: initialState, typx: String, optional: false, aliases: [initial_state]}, {name: attributes, typx: Array[AttributeDefinition], optional: true, aliases: []}]}, {name: RuleExpression, fields: [{name: type, typx: String, optional: true, aliases: []}, {name: preset, typx: String, optional: true, aliases: []}, {name: impl, typx: String, optional: true, aliases: []}]}, {name: RuleDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}, {name: type, typx: String, optional: true, aliases: []}, {name: preset, typx: String, optional: true, aliases: []}, {name: impl, typx: String, optional: true, aliases: []}, {name: description, typx: String, optional: true, aliases: []}]}, {name: ReasonDefinition, fields: [{name: code, typx: String, optional: false, aliases: []}, {name: message, typx: String, optional: false, aliases: []}, {name: contextSchema, typx: String, optional: true, aliases: [context_schema]}]}, {name: BoundaryDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}]}, {name: EffectDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}, {name: kind, typx: sync|async, optional: true, aliases: []}]}, {name: TransitionDefinition, fields: [{name: name, typx: String, optional: false, aliases: []}, {name: from, typx: String, optional: false, aliases: []}, {name: to, typx: String, optional: false, aliases: []}, {name: rules, typx: Array[RuleExpression], optional: true, aliases: []}, {name: effects, typx: Array[String], optional: true, aliases: []}, {name: inputSchema, typx: String, optional: true, aliases: [input_schema]}]}], stages: [{name: parse_yaml, input: String, output: Schema}, {name: resolve_schema, input: Schema, output: ResolvedSchema}, {name: validate_schema, input: ResolvedSchema, output: Unit}, {name: emit_ir_from_schema, input: Schema, output: FwdIR}]}
    ),
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
