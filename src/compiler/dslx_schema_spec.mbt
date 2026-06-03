///|
/// Private dslx-backed description of the first FWD schema/compiler slice.
///
/// FWD keeps the existing YAML compiler as the production CLI/API path. This
/// dslx spec is the first text DSL input path that compiles through the same
/// resolve, validation, and IR emit stages.

///|
fn fwd_dslx_schema_compiler_spec() -> @dslx.Dslx {
  @dslx.dslx("Fwd")
  .node(
    @dslx.node("Sche")
    .case(@dslx.case("Root").fldx(@dslx.fldx("name", "String")))
    .case(@dslx.case("State").fldx(@dslx.fldx("name", "String")))
    .case(
      @dslx.case("Field")
      .fldx(@dslx.fldx("name", "String"))
      .fldx(@dslx.fldx("typx", "String")),
    )
    .case(
      @dslx.case("Entity")
      .fldx(@dslx.fldx("name", "String"))
      .fldx(@dslx.fldx("fields", "Array[String]")),
    )
    .case(
      @dslx.case("Transition")
      .fldx(@dslx.fldx("name", "String"))
      .fldx(@dslx.fldx("from", "String"))
      .fldx(@dslx.fldx("upto", "String")),
    )
    .case(@dslx.case("Effect").fldx(@dslx.fldx("name", "String")))
    .case(
      @dslx.case("Rule")
      .fldx(@dslx.fldx("name", "String"))
      .fldx(@dslx.fldx("kind", "String"))
      .fldx(@dslx.fldx("body", "String")),
    ),
  )
  .rule(@dslx.rule("name").body(@dslx.rgxx("[a-zA-Z_][a-zA-Z0-9_]*")))
  .rule(
    @dslx.rule("typx").body(
      @dslx.altx([@dslx.litx("text"), @dslx.litx("int"), @dslx.litx("bool")]),
    ),
  )
  .rule(
    @dslx.rule("fldx").body(
      @dslx.seqx([@dslx.refx("name"), @dslx.litx(":"), @dslx.refx("typx")]),
    ),
  )
  .rule(
    @dslx.rule("stat").body(
      @dslx.seqx([@dslx.litx("state"), @dslx.refx("name")]),
    ),
  )
  .rule(
    @dslx.rule("enty").body(
      @dslx.seqx([
        @dslx.litx("entity"),
        @dslx.refx("name"),
        @dslx.litx("{"),
        @dslx.many(@dslx.refx("fldx")),
        @dslx.litx("}"),
      ]),
    ),
  )
  .rule(
    @dslx.rule("tref").body(
      @dslx.altx([
        @dslx.seqx([@dslx.litx("rule"), @dslx.refx("name")]),
        @dslx.seqx([@dslx.litx("effect"), @dslx.refx("name")]),
      ]),
    ),
  )
  .rule(
    @dslx.rule("tran").body(
      @dslx.seqx([
        @dslx.litx("transition"),
        @dslx.refx("name"),
        @dslx.litx(":"),
        @dslx.refx("name"),
        @dslx.litx("->"),
        @dslx.refx("name"),
        @dslx.many(@dslx.refx("tref")),
      ]),
    ),
  )
  .rule(
    @dslx.rule("effx").body(
      @dslx.seqx([@dslx.litx("effect"), @dslx.refx("name")]),
    ),
  )
  .rule(
    @dslx.rule("rkind").body(
      @dslx.altx([
        @dslx.seqx([@dslx.litx("preset"), @dslx.refx("name")]),
        @dslx.seqx([@dslx.litx("custom"), @dslx.refx("name")]),
      ]),
    ),
  )
  .rule(
    @dslx.rule("rulx").body(
      @dslx.seqx([
        @dslx.litx("rule"),
        @dslx.refx("name"),
        @dslx.litx(":"),
        @dslx.refx("rkind"),
      ]),
    ),
  )
  .rule(
    @dslx.rule("item").body(
      @dslx.altx([
        @dslx.refx("stat"),
        @dslx.refx("enty"),
        @dslx.refx("tran"),
        @dslx.refx("effx"),
        @dslx.refx("rulx"),
      ]),
    ),
  )
  .rule(
    @dslx.rule("sche").body(
      @dslx.seqx([
        @dslx.litx("schema"),
        @dslx.refx("name"),
        @dslx.many(@dslx.refx("item")),
      ]),
    ),
  )
}

///|
fn fwd_dslx_schema_compiler_example() -> @dslx.File {
  @dslx.file(
    "examples/schema.dsl", "schema Schema state Draft state Reviewing state Released entity Schema { title:text version:text } effect notifyDependentSchemas rule hasReview: preset allReferencesResolved transition submitForReview: Draft -> Reviewing rule hasAtLeastOneState rule hasAtLeastOneTransition transition approve: Reviewing -> Released rule hasReview transition deprecate: Released -> Released effect notifyDependentSchemas\n",
  )
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
pub fn compile_dslx_l1(input : String) -> Result[@ir.FwdIR, CompileError] {
  match @dslx.runx(fwd_dslx_schema_compiler_spec(), "sche", input) {
    { done: true, tree: Some(tree), .. } => {
      let schema_result : Result[@schema.Schema, DecodeError] = try? schema_from_dslx_l1_tree(
        tree,
      )
      match schema_result {
        Ok(schema) =>
          match resolve_schema(schema) {
            Ok(resolved) =>
              match validate_schema(resolved) {
                Ok(_) => Ok(emit_ir_from_schema(resolved.schema))
                Err(reason) => Err(ValidationFailure(reason))
              }
            Err(err) => Err(err)
          }
        Err(err) => Err(ParseFailure(err.to_string()))
      }
    }
    { digs, .. } => Err(ParseFailure(format_dslx_diagnostics(digs)))
  }
}
