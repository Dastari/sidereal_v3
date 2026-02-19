# Workspace Integration Tests

This directory is reserved for cross-service integration tests as the service implementations are added.

Current lifecycle integration coverage is split by crate:

- `crates/sidereal-persistence/tests/lifecycle.rs`: graph persist -> hydrate -> mutate -> persist roundtrip for ship/hardpoint/engine component sets.
- `bins/sidereal-shard/tests/lifecycle.rs`: Avian-enabled world tick -> persist -> hydrate into new Bevy world -> tick -> persist verification.
- `bins/sidereal-replication/tests/lifecycle.rs`: replication envelope ingest -> pending cache -> graph persist -> hydrate/remove verification.

Database target for lifecycle tests:

- `SIDEREAL_TEST_DATABASE_URL` (preferred), else `REPLICATION_DATABASE_URL`, else default `postgres://sidereal:sidereal@127.0.0.1:5432/sidereal`.
- Each lifecycle test uses an isolated AGE graph name (`sidereal_*_<uuid>`) and drops it at the end.
