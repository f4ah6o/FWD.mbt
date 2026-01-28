# FWD (Functional Work Design) - GitHub Copilot Instructions

## Project Overview

FWD is a meta-architecture framework for functional work design, implementing Domain-Driven Design (DDD) concepts through state machines. The project is written in **MoonBit**, a functional programming language that targets both Web (JS/Wasm) and native platforms.

### Core Concepts
- **State machines** as the core business model representation
- **DMMF (Domain Modeling Made Functional)** principles
- **Self-describing meta-framework**: FWD schema is defined using FWD itself (L0/L1 bootstrap)
- **Type-safe state transitions** with explicit reasons for failures
- **HATEOAS** for REST API design

## Build and Test Commands

### Essential Commands
```bash
# Check code without running tests
moon check

# Run all tests
moon test

# Run CLI with validation
moon run cli -- validate schema/fwd_schema.yaml

# Compile schema to IR
moon run cli -- schema/fwd_schema.yaml output.json

# Run full CI pipeline
bash scripts/ci.sh

# Or use justfile
just ci
just bootstrap
```

### CLI Usage
```bash
# Validate a schema
moon run cli -- validate <schema.yaml>

# Validate with JSON output
moon run cli -- validate <schema.yaml> --json

# Validate with baseline (breaking change detection)
moon run cli -- validate <schema.yaml> --baseline <baseline.yaml> --json

# Compile schema to IR
moon run cli -- <schema.yaml> [output.json]

# List available presets
moon run cli -- presets
```

## Project Structure

```
/
├── .github/           # GitHub workflows and configuration
├── cli/               # CLI application (main.mbt, app.mbt)
├── compiler/          # Schema compiler (parse, resolve, validate, emit)
├── core/              # Core FWD primitives (L0 layer)
├── ir/                # Intermediate Representation definitions
├── schema/            # Schema definitions and examples
│   ├── fwd_schema.yaml     # L1 meta-schema (self-describing)
│   └── fwd_schema.ir.json  # Golden IR artifact
├── examples/          # Example schemas and test cases
├── scripts/           # Build and CI scripts
├── justfile           # Just task runner configuration
└── moon.mod.json      # MoonBit module configuration
```

## Coding Standards

### MoonBit-Specific Guidelines

1. **Functional Programming**: Prioritize pure functions and immutability
2. **Type Safety**: Leverage MoonBit's type system; avoid escape hatches
3. **Pattern Matching**: Use exhaustive pattern matching for enums/ADTs
4. **Error Handling**: Use `Result<T, E>` types, not exceptions
5. **Naming Conventions**:
   - Functions: `snake_case`
   - Types: `PascalCase`
   - Constants: `UPPER_SNAKE_CASE`
   - Private functions: prefix with underscore if needed

### Testing

- Tests are located in files ending with `_test.mbt`
- Follow existing test patterns in `compiler/compiler_test.mbt` and `cli/app_test.mbt`
- Ensure all new features have corresponding tests
- Run `moon test` before committing

### Code Organization

- **Core (L0)**: Primitive types and foundational logic (frozen, minimal changes)
- **Compiler**: Schema parsing, validation, and IR generation
- **CLI**: User-facing command-line interface
- **IR**: Intermediate representation for compiled schemas

## Schema Design Principles

### FWD Schema Components (SEFRTB)

1. **State**: Current position in business workflow
2. **Entity**: Business data subject (with type `Entity<S>`)
3. **Function**: What happens during transition (Command + Effect)
4. **Rule**: Conditions for transitions (returns `Result<_, Reason>`)
5. **Transition**: State change operation
6. **Boundary**: Role/actor who can execute transitions

### Validation Rules (Builtin Presets)

Reserved rule names (cannot be redefined in schemas):
- `hasAtLeastOneState`
- `hasAtLeastOneTransition`
- `allReferencesResolved`
- `noBreakingChanges`
- `noBreakingChangesOrMigrationDefined`

### Breaking Changes (v1 scope)

- State removal
- Transition removal
- Transition modification (from/to changes)
- Requires migration effects when detected

## Git Workflow

### Branch Strategy
- Work on feature branches
- CI runs on all pushes and pull requests
- All tests and validations must pass

### CI Validation
The CI pipeline (`scripts/ci.sh`) ensures:
1. Code compiles (`moon check`)
2. Tests pass (`moon test`)
3. Schema validates (`validate schema/fwd_schema.yaml`)
4. Golden IR matches (diff check against `schema/fwd_schema.ir.json`)

### Golden Artifact
- `schema/fwd_schema.ir.json` is the **golden IR artifact**
- Changes to this file must be intentional and reviewed
- Any schema change must result in identical IR regeneration
- Update via: `moon run cli -- schema/fwd_schema.yaml schema/fwd_schema.ir.json`

## Important Constraints

### DO NOT:
- Modify L0 core primitives without understanding bootstrap implications
- Change builtin preset rule names (reserved keywords)
- Break the golden IR check (diff must pass)
- Add dependencies without justification (keep dependencies minimal)
- Introduce exceptions or impure code in core logic
- Change schema validation logic without corresponding test updates

### DO:
- Follow functional programming principles
- Write pure functions with explicit error handling
- Add tests for all new functionality
- Update documentation when changing behavior
- Validate schemas before committing
- Use `Result<T, Reason>` for operations that can fail
- Leverage MoonBit's type system for correctness

## File Conventions

### Schema Files (YAML)
```yaml
fwdVersion: "1.0"
schemaVersion: "1.0"

states:
  - Draft
  - Released

transitions:
  - name: submit
    from: Draft
    to: Released
    rules:
      - hasAtLeastOneState
```

### Test Files
- Must end with `_test.mbt`
- Use descriptive test names
- Follow existing test structure
- Test both success and failure cases

## Dependencies

- **moonbitlang/x**: Version 0.4.38 (core dependency)
- MoonBit toolchain: Required for build
- Just: Optional task runner (alternative to direct moon commands)

## Special Considerations

### Self-Description (Bootstrap)
FWD's schema is defined using FWD itself:
- L0 (Core): Primitive types and semantics (frozen)
- L1 (Meta-schema): `schema/fwd_schema.yaml` describes FWD's own schema
- L2 (User schemas): Domain models defined by users

### Versioning
- `fwdVersion`: L0 framework version
- `schemaVersion`: Schema format version
- Both must be declared in schema YAML files

### JSON Output Mode
When using `--json` flag with validation:
- **stdout**: JSON only (no human-readable text)
- **stderr**: Empty on expected failures (only for runtime errors)
- Exit code: 0 for success, 1 for validation failure

## Documentation Philosophy

- Code should be self-documenting through clear names and types
- Comments for complex business logic or non-obvious decisions
- Keep documentation in sync with code
- Refer to `CONCEPT.md` and `FWD-META-ARCHITECTURE.md` for architectural decisions

## Language and Internationalization

- Primary documentation: Mix of Japanese (concept) and English (technical)
- Code: English names and comments
- Error messages: English for v1
- User-facing text: Consider i18n in future versions

## When in Doubt

1. Check existing code patterns in the same module
2. Review `CONCEPT.md` for design philosophy
3. Review `FWD-META-ARCHITECTURE.md` for technical architecture
4. Run `moon check` and `moon test` frequently
5. Ensure golden IR check passes (`just bootstrap`)
