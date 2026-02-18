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
- Native and WASM clients are both maintained targets; WASM uses platform-specific network adapters only at the boundary.
- Browser transport direction is WebRTC-first; WebSocket is optional fallback only.
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
- Keep boundaries explicit between crates/services (no persistence/network leakage into gameplay core).

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

Run targeted tests for touched crates; run broader integration tests when flow boundaries are impacted.

## 7. Documentation Maintenance Rule (Enforceable)

When adding any new **critical or enforceable** behavior (security rule, protocol contract, transport rule, runtime default, operational requirement), you must:

1. Update the relevant docs under `docs/`.
2. Update this `AGENTS.md` if the new rule changes contributor/agent behavior or enforcement expectations.

Do not defer this to a later PR.
