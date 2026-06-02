///|
/// Private dslx-style description of the first FWD schema/compiler slice.
///
/// The sibling dslx.mbt framework is still a local worktree rather than a
/// released dependency of this module. Keep this adapter package-private so the
/// production CLI/API/runtime surface keeps using the existing compiler path.

///|
struct DslxFieldSpec {
  name : String
  typx : String
  optional : Bool
  aliases : Array[String]
} derive(Show, Eq)

///|
struct DslxNodeSpec {
  name : String
  fields : Array[DslxFieldSpec]
} derive(Show, Eq)

///|
struct DslxCompilerStageSpec {
  name : String
  input : String
  output : String
} derive(Show, Eq)

///|
struct DslxSchemaCompilerSpec {
  name : String
  nodes : Array[DslxNodeSpec]
  stages : Array[DslxCompilerStageSpec]
} derive(Show, Eq)

///|
fn dslx_field(
  name : String,
  typx : String,
  optional? : Bool = false,
  aliases? : Array[String] = [],
) -> DslxFieldSpec {
  { name, typx, optional, aliases }
}

///|
fn dslx_node(name : String, fields : Array[DslxFieldSpec]) -> DslxNodeSpec {
  { name, fields }
}

///|
fn dslx_stage(
  name : String,
  input : String,
  output : String,
) -> DslxCompilerStageSpec {
  { name, input, output }
}

///|
fn fwd_dslx_schema_compiler_spec() -> DslxSchemaCompilerSpec {
  {
    name: "fwd.schema.compiler.v1",
    nodes: [
      dslx_node("Schema", [
        dslx_field("fwdVersion", "String", aliases=["fwd_version"]),
        dslx_field("schemaVersion", "String", aliases=["schema_version"]),
        dslx_field("states", "Array[StateDefinition]"),
        dslx_field("entities", "Array[EntityDefinition]", optional=true),
        dslx_field("transitions", "Array[TransitionDefinition]"),
        dslx_field("rules", "Array[RuleDefinition]", optional=true),
        dslx_field("reasons", "Array[ReasonDefinition]", optional=true),
        dslx_field("boundaries", "Array[BoundaryDefinition]", optional=true),
        dslx_field("effects", "Array[EffectDefinition]", optional=true),
      ]),
      dslx_node("StateDefinition", [dslx_field("name", "String")]),
      dslx_node("AttributeDefinition", [
        dslx_field("name", "String"),
        dslx_field("type", "String", aliases=["type_ref"]),
        dslx_field("optional", "Bool", optional=true),
      ]),
      dslx_node("EntityDefinition", [
        dslx_field("name", "String"),
        dslx_field("initialState", "String", aliases=["initial_state"]),
        dslx_field("attributes", "Array[AttributeDefinition]", optional=true),
      ]),
      dslx_node("RuleExpression", [
        dslx_field("type", "String", optional=true),
        dslx_field("preset", "String", optional=true),
        dslx_field("impl", "String", optional=true),
      ]),
      dslx_node("RuleDefinition", [
        dslx_field("name", "String"),
        dslx_field("type", "String", optional=true),
        dslx_field("preset", "String", optional=true),
        dslx_field("impl", "String", optional=true),
        dslx_field("description", "String", optional=true),
      ]),
      dslx_node("ReasonDefinition", [
        dslx_field("code", "String"),
        dslx_field("message", "String"),
        dslx_field("contextSchema", "String", optional=true, aliases=[
          "context_schema",
        ]),
      ]),
      dslx_node("BoundaryDefinition", [dslx_field("name", "String")]),
      dslx_node("EffectDefinition", [
        dslx_field("name", "String"),
        dslx_field("kind", "sync|async", optional=true),
      ]),
      dslx_node("TransitionDefinition", [
        dslx_field("name", "String"),
        dslx_field("from", "String"),
        dslx_field("to", "String"),
        dslx_field("rules", "Array[RuleExpression]", optional=true),
        dslx_field("effects", "Array[String]", optional=true),
        dslx_field("inputSchema", "String", optional=true, aliases=[
          "input_schema",
        ]),
      ]),
    ],
    stages: [
      dslx_stage("parse_yaml", "String", "Schema"),
      dslx_stage("resolve_schema", "Schema", "ResolvedSchema"),
      dslx_stage("validate_schema", "ResolvedSchema", "Unit"),
      dslx_stage("emit_ir_from_schema", "Schema", "FwdIR"),
    ],
  }
}

///|
fn dslx_compile_yaml_first_slice(
  input : String,
) -> Result[@ir.FwdIR, CompileError] {
  let _spec = fwd_dslx_schema_compiler_spec()
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
