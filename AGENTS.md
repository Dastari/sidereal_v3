# AGENTS.md

Project operating contract for human and AI contributors working in this repository.

## 1. Scope and Intent

- This repo is rebuilding **Sidereal** from scratch as a server-authoritative multiplayer architecture.
- Work must follow the documented phased plan and invariants.
- Do not introduce ad-hoc architecture that conflicts with the design documents.

## 2. Source-of-Truth Documentation

- Primary architecture/spec: `docs/sidereal_design_document.md`
- Implementation sequencing/checklists: `docs/sidereal_implementation_checklist.md`
- Workspace test area guidance: `tests/README.md`
- Repo overview: `README.md`

If any code change conflicts with docs, update docs in the same change or stop and resolve ambiguity first.

## 3. Non-Negotiable Technical Rules

- Authority flow is one-way: `client input -> shard sim -> replication/distribution -> persistence`.
- Clients never authoritatively set world transforms/state.
- Keep identity crossing boundaries as UUID/entity IDs only (no raw Bevy `Entity` IDs over service boundaries).
- Keep shared simulation/prediction/gameplay logic in shared crates, not duplicated across client targets.
- Persistable gameplay ECS components must support `Reflect` + serde (`Serialize`/`Deserialize`) and be mappable to graph persistence with hydration roundtrip coverage.
- Gameplay component source-of-truth is core (`crates/sidereal-game`); new persistable component families must flow through the shared component registry/generation path rather than ad-hoc per-service definitions.
- Bevy hierarchy relationships (`Children`/parent-child) and modular mount relationships (for example hardpoints -> engines/shield generators/flight computers) must persist as graph relationships and hydrate back deterministically.
- Avian runtime-only transient internals are excluded from persistence; durable gameplay state must be mirrored into persistable components.
- Native and WASM client builds are co-maintained; WASM is never a deferred concern. Both must build and pass quality gates at every change, not just when "the WASM phase" arrives.
- Native may be the current delivery priority, but that never relaxes WASM parity requirements; client behavior and protocol changes must keep WASM in lockstep in the same change.
- The client is one workspace member (`crates/sidereal-client`) with a native `[[bin]]` target and a WASM `[lib]` target. There is no separate `sidereal-client-web` crate.
- Platform branching uses `cfg(target_arch = "wasm32")` only. Never use a cargo feature flag to gate native-vs-WASM code paths; `target_arch` is set automatically by the compiler and cannot be miscombined.
- WASM uses platform-specific network adapters only at the transport boundary. All gameplay, prediction, reconciliation, and ECS systems are shared and must compile for both targets without conditional compilation.
- Browser transport direction is WebRTC-first (unreliable/unordered data channels for game state, ordered/reliable channel for session control). WebSocket is allowed only as an explicit fallback. New WASM transport work must not default to WebSocket.
- Asset delivery is stream-based from backend to client; no standalone HTTP asset file serving.
- Client cache is MMO-style local cache: single `assets.pak` + companion index/metadata, with checksum/version invalidation.
- `bevy_remote` inspection endpoints for shard/replication/client must be auth-gated and follow project security defaults.

## 4. Implementation Workflow Requirements

- Implement in phase order from `docs/sidereal_implementation_checklist.md` unless dependency constraints require otherwise.
- For each feature change, include:
  - code updates,
  - unit tests in touched crates,
  - integration test updates if cross-service behavior changes,
  - doc updates for protocol/runtime/architecture changes.
- For new gameplay components, include persistence/hydration mapping updates (or explicit non-persisted runtime-only rationale) and tests in the same change.
- For scripting-connected components (for example `FlightComputer`), script APIs may emit intent only; scripts must not directly authoritatively mutate transforms/velocities/ownership or bypass Rust authority systems.
- Keep boundaries explicit between crates/services (no persistence/network leakage into gameplay core).
- When adding or changing client-side code: verify both native and WASM targets still build. If a change breaks the WASM target, fix it in the same PR before marking complete. Do not defer WASM build failures.
- WASM client validation must include WebGPU support in the build configuration (`bevy/webgpu`), not only default WASM feature sets.
- When changing client behavior, transport contracts, prediction/reconciliation flow, or client runtime defaults: update docs to note native impact and WASM impact (or explicitly state "no WASM impact").
- When adding a new client-side dependency: verify it is either WASM-compatible or correctly gated behind `cfg(not(target_arch = "wasm32"))` with a WASM-compatible alternative also provided.

## 5. Runtime and Environment Conventions

- Postgres + AGE local infra is defined in `docker-compose.yaml`.
- Initialization SQL for AGE/graph lives under `docker/init/`.
- Asset root default is `./data`.
- Follow runtime defaults and env vars listed in `docs/sidereal_design_document.md`.

## 6. Quality Gates (Minimum)

Before marking work complete, run:

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo check --workspace
```

If client code was touched, also verify the WASM target compiles:

```bash
cargo check -p sidereal-client --target wasm32-unknown-unknown --features bevy/webgpu
```

This requires the WASM target to be installed (`rustup target add wasm32-unknown-unknown`). If the WASM target is not installed in the local environment, note it in the change but do not skip the check in CI.

Run targeted tests for touched crates; run broader integration tests when flow boundaries are impacted.

## 7. Documentation Maintenance Rule (Enforceable)

When adding any new **critical or enforceable** behavior (security rule, protocol contract, transport rule, runtime default, operational requirement), you must:

1. Update the relevant docs under `docs/`.
2. Update this `AGENTS.md` if the new rule changes contributor/agent behavior or enforcement expectations.

Do not defer this to a later PR.
