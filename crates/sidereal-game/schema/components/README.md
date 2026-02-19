# Component Schema Scaffolding

This directory is the source-of-truth scaffolding for gameplay component schema inputs.

Planned flow:

1. Define/extend component schema files here by family.
2. Generate Rust ECS component + registry code into `src/generated/components.rs`.
3. Use generated metadata (`component_kind`, type path) for replication and graph persistence mapping.

Runtime-only non-persisted components (for example Avian internals) should not be declared as persistable schemas here.
