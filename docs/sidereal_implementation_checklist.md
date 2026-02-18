# Sidereal 2 Implementation Checklist

Status: Planned implementation guide
Date: 2026-02-18
Primary spec: `docs/sidereal_design_document.md`

## How to Use This Checklist

- Complete phases in order unless a dependency says otherwise.
- Every completed item must include:
  - code change,
  - unit tests for the touched system,
  - integration test updates where cross-service behavior is affected,
  - docs updates if protocol/runtime behavior changed.

## Phase 0: Repo Foundations

- [ ] Create/confirm workspace crate boundaries exactly as defined in `docs/sidereal_design_document.md`.
- [ ] Align dependencies under root `[workspace.dependencies]`.
- [ ] Enforce lint gates (`fmt`, `clippy -D warnings`, `check`) in CI.
- [ ] Add `bevy_remote` dependency and shared config scaffolding for `sidereal-shard`, `sidereal-replication`, and `sidereal-client`.
- [ ] Define auth model + bind defaults for runtime inspection endpoints (disabled unauthenticated access by default).
- [ ] Set up `crates/sidereal-client` as the single client workspace member with both a `[[bin]]` (native, `src/main.rs`) and a `[lib]` with `crate-type = ["cdylib", "rlib"]` (WASM, `src/lib.rs`). Do not create a separate `sidereal-client-web` crate. Platform branching is `cfg(target_arch = "wasm32")`; no cargo feature flag for WASM.
- [ ] Add both native and WASM build checks to CI from day 0: `cargo check -p sidereal-client` and `cargo check -p sidereal-client --target wasm32-unknown-unknown`. The WASM target must never be left broken between PRs.
- [ ] Define shared-code boundary rules so native and WASM clients reuse gameplay/prediction/sim crates and differ only at platform/network adapter layers.
- [ ] Add baseline test harness structure:
  - `crates/*/tests/` for crate unit/integration tests,
  - `tests/` for cross-service flow tests.

Unit tests required:

- [ ] `sidereal-core`: ID helpers, constant invariants.
- [ ] `sidereal-net`: envelope encode/decode and backward compatibility decode tests.
- [ ] `sidereal-sim-core`: deterministic golden-vector tests.

## Phase 1: Database + Persistence Base (Postgres + AGE)

- [ ] Bring up PostgreSQL with AGE via `docker compose`.
- [ ] Implement schema ensure for relational auth tables.
- [ ] Implement AGE bootstrap (`CREATE EXTENSION`, `LOAD 'age'`, graph ensure).
- [ ] Implement graph persist primitives (`persist_graph_records`, removals, load/hydrate records).
- [ ] Implement snapshot marker writes.

Unit tests required:

- [ ] SQL/query builder helpers (escaping, AGType parse, property serialization).
- [ ] Graph record transformation tests (world delta -> graph records).
- [ ] Hydration mapping tests for reflect envelope decode.

Integration tests required:

- [ ] Service boot ensures schema/graph on empty DB.
- [ ] Persist then hydrate roundtrip preserves IDs/components.

## Phase 2: Auth Core (`sidereal-gateway`)

- [ ] Implement register/login/refresh/reset/me endpoints.
- [ ] Implement Argon2 password hashing and JWT issuance.
- [ ] Implement hashed refresh token storage and rotation behavior.
- [ ] Implement account -> `player_entity_id` mapping.
- [ ] Implement registration bootstrap command handoff to replication (not direct ad-hoc world writes).

Unit tests required:

- [ ] Password hash/verify tests.
- [ ] JWT claim encode/decode and expiry tests.
- [ ] Refresh token hash/validation tests.
- [ ] Request validation tests (email/password constraints).

Integration tests required:

- [ ] register -> login -> refresh -> me happy path.
- [ ] login does not create gameplay entities.
- [ ] register creates starter world state once only.

## Phase 3: Shard Authoritative Simulation (`sidereal-shard`)

- [ ] Implement fixed-step 30 Hz sim loop.
- [ ] Implement ECS component baseline and spawning patterns.
- [ ] Integrate Avian authoritative physics.
- [ ] Mirror Avian `Position/Rotation` into Bevy `Transform` every fixed tick.
- [ ] Implement authoritative input application per tick.
- [ ] Emit authoritative state deltas and input acknowledgements.
- [ ] Expose shard ECS inspection via authenticated `bevy_remote` protocol endpoint.

Unit tests required:

- [ ] Input apply semantics by tick.
- [ ] Flight control integration ordering (turn/thrust/damping).
- [ ] Mass recomputation pipeline (`MassDirty` -> `TotalMassKg`).
- [ ] Transform mirror contract tests.
- [ ] `bevy_remote` auth gate and endpoint registration tests.

Integration tests required:

- [ ] Input stream drives expected motion on authoritative shard.
- [ ] Tick metadata monotonicity and lease epoch presence.

## Phase 4: Replication Service (`sidereal-replication`)

- [ ] Ingest authoritative shard deltas.
- [ ] Maintain read model suitable for client fan-out and visibility.
- [ ] Persist deltas/snapshots on configured cadence.
- [ ] Expose/control bootstrap command handling.
- [ ] Implement client-facing replication transport layer (Lightyear-targeted architecture).
- [ ] Expose replication read-model/world inspection via authenticated `bevy_remote` protocol endpoint.
- [ ] Implement transport abstraction that supports multiple client protocol adapters (native transport + browser path).
- [ ] Prioritize WebRTC path for browser/WASM clients; keep WebSocket only as optional fallback.

Unit tests required:

- [ ] Delta cache merge/prune behavior.
- [ ] Visibility filter primitives (authorization vs delivery stage separation).
- [ ] Redaction mask application tests.
- [ ] Control message decode/encode tests.
- [ ] `bevy_remote` auth gate and endpoint registration tests.

Integration tests required:

- [ ] shard -> replication -> persistence flow.
- [ ] replication bootstrap command roundtrip from gateway.

## Phase 5: Client Prediction and Rendering (`sidereal-client`)

- [ ] Implement native client transport and session handshake (UDP via Lightyear adapter).
- [ ] Implement WASM client WebRTC transport adapter in `sidereal-client` under `cfg(target_arch = "wasm32")`:
  - [ ] Signaling: open a JWT-authed WebSocket to `/rtc/signal` on the replication server.
  - [ ] Receive ICE server config (STUN/TURN URLs) from replication in first signaling message.
  - [ ] Exchange SDP offer/answer and ICE candidates over the signaling WebSocket.
  - [ ] Open named data channels (`ctrl`: ordered/reliable; `game`: unordered/unreliable) on the established peer connection.
  - [ ] Close the signaling WebSocket after data channels are open.
  - [ ] Implement the same `ClientTransport` trait as the native adapter; no gameplay code diverges.
- [ ] Implement controlled-entity prediction with input history.
- [ ] Implement rollback + reconciliation using server ack tick.
- [ ] Implement correction smoothing/error budget policy.
- [ ] Implement remote snapshot-buffer interpolation.
- [ ] Implement bounded extrapolation fallback.
- [ ] Expose client runtime world via `bevy_remote` protocol for tooling/inspection.

Unit tests required:

- [ ] Prediction replay queue pruning by ack tick.
- [ ] Correction thresholds/blend policy logic.
- [ ] Snapshot bracketing interpolation math.
- [ ] Extrapolation cap behavior tests.
- [ ] `bevy_remote` endpoint wiring and auth/config guard tests.

Integration tests required:

- [ ] local controlled movement remains stable under simulated latency/jitter.
- [ ] remote entities remain smooth and do not lerp-chase target jumps.

## Phase 6: Visibility, Permissions, and Scan Intel

- [ ] Implement three-scope model in runtime code paths.
- [ ] Enforce field-level redaction server-side before serialization.
- [ ] Implement temporary scan-intel grants and expiry/revocation.
- [ ] Add stream tiers (`focus`, `strategic`, `intel`) scaffolding.
- [ ] Add/optimize spatial indexing for visibility candidate queries.

Unit tests required:

- [ ] Ownership and attachment authorization rules.
- [ ] Grant scope merge/resolution logic.
- [ ] Redaction of sensitive fields by default.
- [ ] Revocation/expiry behavior.

Integration tests required:

- [ ] unauthorized observers never receive restricted fields.
- [ ] authorized scan grants temporarily expose only allowed scopes.

## Phase 7: Asset Streaming Foundation

- [ ] Deliver `asset_id` metadata with entity state where applicable.
- [ ] Implement client placeholder-first rendering.
- [ ] Implement backend->client asset stream bootstrap (no HTTP file serving).
- [ ] Set default asset root to `./data` and ingest existing GLTFs from `./data/models`.
- [ ] Stream all required content classes through asset manager (`models`, `textures`, `audio`, `shaders`, `scripting logic bundles`, misc blobs).
- [ ] Implement cache refcount + TTL + LRU budget eviction.
- [ ] Persist client cache on disk as single `assets.pak` + companion index with resumable downloads/chunks.
- [ ] Implement `asset_version` + `sha256` validation and stale-cache replacement on backend updates.
- [ ] Add failure dedupe and fallback visuals.
- [ ] Ensure runtime does not rely on server-side scripts to generate client cache artifacts; client assembles cache from streamed asset chunks.

Unit tests required:

- [ ] cache hit/miss/refcount accounting.
- [ ] eviction ordering and budget enforcement.
- [ ] checksum mismatch and version bump invalidation logic.
- [ ] chunk reassembly/resume correctness for interrupted transfers.
- [ ] pak index offset/length integrity and lookup correctness.
- [ ] missing asset fallback behavior.

Integration tests required:

- [ ] entity remains renderable with placeholder when asset fetch fails.
- [ ] asset swap-in works without gameplay state disruption.
- [ ] backend asset update causes client to receive refreshed bytes and pak/index update.

## Phase 8: Procedural Asteroids and Content Extensibility

- [ ] Implement deterministic asteroid seed mapping from entity identity.
- [ ] Implement procedural mesh/material pipeline hooks (feature-flagged).
- [ ] Keep collision/size authoritative on server data.

Unit tests required:

- [ ] seed determinism tests.
- [ ] generated mesh parameter validity tests (bounds/vertex counts).

Integration tests required:

- [ ] procedural visuals do not alter authoritative collision semantics.

## Phase 9: Scripting Bridge (Feature-Flagged)

- [ ] Introduce script runtime crate and safe API boundary.
- [ ] Expose content-level hooks (missions/dialogue/high-level AI).
- [ ] Keep core authority systems non-scriptable.
- [ ] Add sandboxing constraints and script error containment.

Unit tests required:

- [ ] API boundary permission tests.
- [ ] script execution timeout/error isolation tests.
- [ ] deterministic bridge behavior for key script callbacks.

Integration tests required:

- [ ] scripted mission flow interacts with ECS through approved API only.

## Phase 10: Multi-Shard and Orchestrator

- [ ] Implement lease model and epoch guards.
- [ ] Implement handoff prepare/ack/commit protocol.
- [ ] Implement replication routing for cross-shard visibility/input.
- [ ] Implement failover/recovery state transitions.

Unit tests required:

- [ ] lease epoch conflict handling.
- [ ] handoff state machine transitions.
- [ ] route selection by authority ownership.

Integration tests required:

- [ ] entity handoff continuity under movement across boundary.
- [ ] no dual-authority updates after handoff commit.

## Cross-Cutting Test Matrix (Must Exist)

- [ ] Unit tests in each crate touched by a feature.
- [ ] Deterministic fixture tests for all shared sim-core mechanics.
- [ ] Protocol compatibility tests for codec/version migration.
- [ ] Cross-service integration tests for auth->bootstrap->control->persist.
- [ ] Soak test scenario for high-speed flight jitter regression detection.

## Definition of Done (Per Feature PR)

- [ ] Implementation complete and behind correct service boundaries.
- [ ] Unit tests added/updated in each affected system.
- [ ] Integration tests updated where flow spans services.
- [ ] `cargo fmt --all -- --check` passes.
- [ ] `cargo clippy --workspace --all-targets -- -D warnings` passes.
- [ ] `cargo check --workspace` passes.
- [ ] Docs updated (`docs/sidereal_design_document.md`, protocol/design docs, runtime defaults, decision register if architectural).
