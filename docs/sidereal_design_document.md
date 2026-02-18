# Sidereal 2: Unified Build Specification (Authoritative Single-File Blueprint)

Status: Draft build spec for rebuilding Sidereal from scratch with the refactored network architecture.
Date: 2026-02-18
Audience: engineering agents and maintainers implementing the full project without any other reference files.

## 1. Product Vision and Scope

Sidereal is a multiplayer top-down 3D space RPG with server-authoritative simulation, persistent world state, and capability-driven ECS gameplay.

Core game loop:

- Authenticate and enter a persistent universe.
- Pilot controllable ships via module-based systems (engines, fuel, flight computer, hardpoints).
- Observe and interact with entities under strict server-authorized visibility rules.
- Persist world evolution through authoritative shard simulation and durability pipelines.

Primary near-term target:

- stable realtime multiplayer with robust client prediction/reconciliation,
- scalable architecture for multi-shard and future MMO operation,
- content extensibility foundations (missions, scripting, procedural content, minimap/intel streams, asset streaming).

Technology baseline (target):

- Rust 2024 edition
- Bevy 0.18
- Avian3D compatible with Bevy 0.18
- Lightyear 0.26.x target for client-facing replication/prediction layer
- PostgreSQL with Apache AGE extension
- `serde` + `bincode` support for internal protocol encoding paths

## 2. Hard Invariants (Non-Negotiable)

1. Authority direction is one-way: `client input -> shard simulation -> replication/distribution -> persistence graph`.
2. Clients send intent/input only; clients never authoritatively set transforms.
3. Cross-boundary identity is UUID/entity_id only; Bevy `Entity` is runtime-local and never persisted/transmitted.
4. Runtime shard memory is authoritative live state; DB is durability + startup hydration only.
5. Visibility and field-level data permissions are server-enforced before serialization.
6. Domain labels (`Ship`, `Asteroid`, etc.) classify entities; behavior is capability/component driven.
7. Registration creates starter world entities exactly once; login is auth-only.

## 3. Target Runtime Architecture (Refactor-Baked)

### 3.1 Service Topology

Control plane:

- `sidereal-orchestrator`: shard leases, split/merge policy, failover coordination.
- `sidereal-bg-sim`: low-fidelity economy/NPC progression and event generation.
- PostgreSQL + AGE: durable graph and auth/session persistence.

Data plane:

- `sidereal-shard` (N instances): authoritative ECS + Avian simulation at fixed tick.
- `sidereal-replication`: client-facing replication server, visibility filtering, fan-out, durability staging, input routing to shard ownership.
- `sidereal-shard` and `sidereal-replication` expose `bevy_remote` protocol endpoints for authenticated runtime world inspection.

Entry/auth plane:

- `sidereal-gateway`: auth API, token lifecycle, account/session domain, registration flow.

Client plane:

- `sidereal-client` (native Rust/Bevy target): realtime client with prediction/rollback/interpolation.
- `sidereal-client` enables `bevy_remote` protocol for local/remote inspection tooling parity with server runtimes.
- `sidereal-client-web` (WASM/browser target) is a maintained build target and must stay CI-green with shared gameplay/runtime code where platform constraints allow.

### 3.2 Networking Strategy

Primary direction:

- Native client uses low-latency transport and a replication framework layer (Lightyear-targeted design) for prediction/interpolation/rollback primitives.
- Replication transport layer is multi-protocol by design: native-first transport plus browser-capable transport path(s) for WASM clients.
- Browser/WASM direction prioritizes WebRTC data channels; WebSocket is allowed only as compatibility/fallback path due prior overhead observations.
- Shard<->Replication and control-plane contracts remain explicit `sidereal-net` messages (do not leak internal ECS types across services).

Migration rule:

- keep protocol boundaries explicit even when using framework plugins;
- avoid big-bang replacement of every channel at once.
- keep transport adapters thin so simulation/gameplay/prediction code is shared across native and WASM clients.

## 4. Tick, Time, and Input Model

### 4.1 Simulation Timing

- Shard authoritative simulation tick: 30 Hz fixed timestep.
- Client render target: 60 Hz.
- Input pipeline is tick-indexed (not wall-clock approximated).

### 4.2 Authoritative Tick Metadata

All authoritative envelopes include:

- protocol version,
- shard/source,
- lease epoch,
- sequence number,
- authoritative tick.

Reference shape:

```rust
struct NetEnvelope<T> {
    protocol_version: u16,
    channel: ChannelClass,
    source_shard_id: i32,
    lease_epoch: u64,
    seq: u64,
    tick: u64,
    payload: T,
}
```

### 4.3 Input Contract

Use full per-tick input snapshots for deterministic replay and packet-loss self-healing.

Reference intent model:

```rust
struct PlayerInput {
    tick: u64,
    thrust_forward: bool,
    thrust_reverse: bool,
    yaw_left: bool,
    yaw_right: bool,
    actions: Vec<OneTimeAction>,
}
```

Server apply rule:

- input for tick N is consumed while simulating tick N,
- late window and early window enforcement are explicit,
- acked input tick is returned for pruning/replay.

## 5. Prediction, Reconciliation, Interpolation, Extrapolation

### 5.1 Controlled Entity

- Client predicts only controlled entity.
- Server state remains authoritative.
- On state receipt:
  1. compare against historical prediction at authoritative tick,
  2. rollback to authoritative state on divergence,
  3. replay unacked inputs forward,
  4. apply correction smoothing policy (no blind hard snap for normal error ranges).

Correction policy requirements:

- hard snap only for large divergence/teleport threshold,
- short-window blend for small/moderate divergence,
- velocity-adaptive thresholds and blend rates are allowed and expected.

### 5.2 Remote Entities

- no prediction for non-controlled entities,
- use snapshot buffer interpolation, not lerp-to-latest-target.

Required structure:

```rust
struct SnapshotBuffer {
    snapshots: VecDeque<(u64, Vec3, Quat)>, // (server_time_or_tick, pos, rot)
}
```

Render rule:

- render at `now - interpolation_delay` (for example ~100ms),
- find two bracketing snapshots and interpolate by exact ratio,
- if newest snapshot is slightly behind render time, allow bounded extrapolation cap.

### 5.3 Physics Parity Rule

- Shared deterministic movement/control math lives in `sidereal-sim-core`.
- Client/server step semantics must match (turn/thrust ordering, damping, timestep assumptions).
- Full client Avian prediction for controlled entity is a phased upgrade after baseline parity and stability metrics are acceptable.

## 6. Visibility and Data Permissions (Security-Critical)

Three-scope model:

1. World truth scope: full authoritative state (server only).
2. Authorization scope: what this player may know (ownership, attachments, scan grants).
3. Delivery scope: what this active client session receives now (focus radius/hysteresis/stream tier).

Rules:

- Owned entities and owned attachments: full detail for control UI.
- Non-owned authorized entities: redacted by field policy.
- Unauthorized entities: never serialized; explicit removal if previously visible.

Sensitive-data rule:

- cargo internals, hidden loadouts, subsystem internals, private transfer details remain omitted unless explicit gameplay grants allow exposure.

Multi-entity ownership rule:

- authorization aggregates across all owned entities, not only currently controlled ship.

Server-only invariant:

- client cannot self-upgrade visibility by local inference.

## 7. Scan Intel and Multi-Stream Model (Ground-Level Support)

### 7.1 Scan Intel Grants

Server-managed temporary grants keyed by:

- observer player,
- target entity,
- field scope,
- source,
- grant/expiry times.

Example field scopes:

- `physical_public`
- `combat_profile`
- `cargo_summary`
- `cargo_manifest`
- `systems_detail`

### 7.2 Stream Tiers

Support from ground level:

- `focus_stream`: high rate, local tactical detail.
- `strategic_stream`: lower-rate minimap contacts/coarse kinematics.
- `intel_stream`: event-driven grant results and revocations.

### 7.3 Spatial Indexing

Visibility query engine must support sublinear candidate lookup:

- phase-1 acceptable: uniform spatial hash grid,
- future: adaptive grid/quadtree for hotspot density.

Metrics required:

- candidate count per client frame,
- included entity count,
- query time budget.

## 8. ECS and Gameplay Composition Model

### 8.1 Philosophy

- Composition over inheritance.
- Capability components drive behavior.
- Domain tags classify archetypes only.

### 8.2 Current Baseline Components

Core implemented/required families:

- Identity: `EntityGuid`, `DisplayName`
- Kinematics: `PositionM`, `VelocityMps`
- Physical properties: `MassKg`, `SizeM`, `CollisionAabbM`
- Authority: `ShardAssignment`
- Topology/modularity: `Hardpoint`, `MountedOn`
- Flight: `Engine`, `FuelTank`, `FlightComputer`
- Ownership/combat: `OwnerKind`, `OwnerId`, `InstigatorEntityId`, `HealthPool`
- Derived mass pipeline: `BaseMassKg`, `CargoMassKg`, `ModuleMassKg`, `TotalMassKg`, `MassDirty`

### 8.3 Avian Sync Contract

- Avian `Position`/`Rotation` is simulation-authoritative.
- Mirror into Bevy `Transform`/`GlobalTransform` each fixed tick.
- Mirror to network/persistence-facing kinematic components consistently.

### 8.4 Capability Rules

Any entity with:

- `HealthPool` can be damaged/destroyed,
- `Engine + FuelTank` can accelerate/run out of fuel,
- scanner/beacon components can expand visibility,
- hardpoints can mount detachable modules/cargo.

## 9. Shared Simulation Core (`sidereal-sim-core`)

Purpose:

- prevent client/server drift by centralizing deterministic rule math reused by shard and client prediction.

Must contain only pure deterministic logic:

- input normalization/state transitions,
- control integration helpers,
- fuel/power gating math,
- deterministic step helpers.

Must not contain:

- ECS queries/resources,
- Avian world/contacts,
- transport/persistence/auth code,
- authority decisions.

Current migrated examples:

- signed axis mapping,
- input edge/state transitions,
- planar integration helpers,
- yaw-rate helpers,
- stop/reset semantics,
- shared network-input mapping adapter crate.

Parity policy:

- maintain golden-vector tests for deterministic behavior.

## 10. Persistence and Graph Model

### 10.1 Storage Domains

Relational domain:

- `accounts`, `refresh_tokens`, `password_reset_tokens`, operational metadata.

Graph domain (AGE graph `sidereal`):

- world entities/components/hardpoints/ownership/inventory relationships.

Snapshot markers:

- periodic checkpoint metadata for recovery workflows.

### 10.2 Postgres + AGE Boot Requirements

Database container requirements:

- run PostgreSQL image with Apache AGE support,
- ensure `age` extension exists,
- load AGE and ensure graph `sidereal` exists at startup.

Runtime init requirements (service startup):

- `CREATE EXTENSION IF NOT EXISTS age;`
- `LOAD 'age';`
- `SET search_path = ag_catalog, "$user", public;`
- ensure graph exists (`ag_catalog.create_graph('sidereal')` if missing),
- reset search_path to `public` afterward.

### 10.3 Graph Identity Rules

- one logical entity_id => one graph node.
- labels are additive on same node.
- component ids are stable (for example `<entity_id>::<component_kind>`).

### 10.4 Canonical Graph Shape

Labels:

- `Entity`, `Ship`, `Component`, `Hardpoint`, `InventorySlot`, `Item`, `Faction`, `Player`

Edges:

- `(:Entity)-[:HAS_COMPONENT]->(:Component)`
- `(:Component)-[:MOUNTED_ON]->(:Hardpoint)`
- `(:Entity)-[:HAS_HARDPOINT]->(:Hardpoint)`
- `(:Entity)-[:OWNS]->(:Entity|:Item|:InventorySlot)`
- `(:InventorySlot)-[:CONTAINS]->(:Item)`

### 10.5 Persistence Write Flow

1. Shard emits authoritative world deltas.
2. Replication ingests and persists at configured cadence.
3. Snapshot markers written periodically.
4. Critical events are durability candidates for replay semantics.

### 10.6 Recovery/Hydration

- startup hydration only,
- no periodic DB overwrite into live shard entities,
- runtime remains shard-authoritative.

## 11. Auth and Identity at the Core

### 11.1 Auth Principles

- Email/password login only.
- Access token: JWT HS256.
- Refresh/reset tokens: opaque random values stored hashed.
- Password hashing: Argon2.

### 11.2 Auth API Surface

Gateway endpoints:

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/password-reset/request`
- `POST /auth/password-reset/confirm`
- `GET /auth/me`
- Asset bootstrap metadata is delivered on the authenticated replication/control channel (not HTTP asset file endpoints).

### 11.3 Registration and Starter Ship Bootstrap

Required lifecycle:

1. gateway creates account record and `player_entity_id` (`player:<account_uuid>`),
2. gateway requests replication bootstrap command,
3. replication performs world bootstrap in graph if player owns none,
4. login does not create gameplay entities.

This keeps auth as entry authority and world bootstrap in replication-owned world pipeline.

### 11.4 Session to Gameplay Identity

- all gameplay routing derives from authenticated `player_entity_id` claim,
- entitlement/ownership loading is graph-based,
- controlled entity selection must remain ownership-authorized.

## 12. Asset Delivery and Streaming (Ground Support)

Presentation/data split:

- gameplay packets carry `asset_id` and physical dimensions,
- actual bytes are streamed from backend to client over authenticated game channels (not served as standalone HTTP files).

Required behavior:

- placeholder-first rendering,
- async swap on asset resolution,
- soft-fail (missing asset never crashes gameplay),
- cache + refcount + TTL + LRU + memory budget.
- disk cache on client with checksum/version validation and stale-asset replacement.
- client cache format is a single local PAK data file plus companion index/metadata file (MMO-style launcher/runtime cache model).

Asset manager defaults and scope:

- default asset root is `./data`,
- existing GLTF models in `./data/models` are first-class managed assets,
- manager covers models, textures, audio, shaders, scripting logic bundles, and other content blobs,
- client connection requirements stay minimal: connect/authenticate, then receive required assets and scripted logic streams from backend.

Stream protocol requirements:

- server emits asset catalog/version metadata on session bootstrap,
- client requests missing or stale `asset_id`s by checksum/version,
- backend streams assets in chunked frames with resumable offsets,
- each asset includes `asset_version` + `sha256` and optional parent version for delta/chunk reuse.
- server-side cache generation scripts are not part of runtime behavior; cache assembly is performed client-side from streamed chunks.

Versioning and invalidation requirements:

- authoritative invalidation is content-hash driven (`sha256`) and versioned (`asset_version`),
- backend asset updates must trigger client refresh on next sync window or explicit push invalidation,
- client keeps an on-disk cache index keyed by `asset_id` -> `{asset_version, sha256, size, pak_offset, pak_length, last_used_at}`.

Do not leak gameplay internals through asset metadata.

## 13. Procedural Asteroids (Ground Support)

Current universe baseline:

- seeded asteroid field with varied size/mass/health and collision dimensions.

Ground-level support requirements:

- stable asteroid identity->seed mapping,
- authoritative size/collision remains server truth,
- visuals can be generated/procedural on client without altering gameplay authority,
- asset pipeline must allow procedural registration/caching/LOD.

Recommended direction:

- CPU deterministic base mesh generation + optional GPU detail materials.

## 14. Scripting and Modding (Ground Support)

Scope policy:

- scripting for content-level systems (missions, dialogue, high-level AI behavior, event composition),
- core authority systems remain Rust/ECS only.

Not scriptable:

- authoritative physics,
- networking/replication protocol internals,
- client prediction core,
- trust/security enforcement.

Recommended engine integration:

- Lua scripting bridge (`bevy_mod_scripting`) with sandboxing and explicit API surface.

Architecture:

- script runtime calls controlled Rust APIs that operate on ECS data,
- scripts never bypass authority or permission boundaries.

## 15. Multi-Shard and Handoff Design

Shard responsibilities:

- own bounded regions,
- simulate entities in region,
- prepare/commit handoff at boundaries.

Handoff primitives (must exist as explicit contracts):

- `HandoffPrepare`
- `HandoffAck`
- `HandoffCommit`
- epoch/lease validation on transfer.

Replication responsibilities in multi-shard:

- aggregate world state for client views,
- route client inputs to owning shard,
- compute visibility across shard boundaries,
- hide shard ownership details from clients.

## 16. Crate and Folder Structure (Authoritative Plan)

Workspace crates:

- `crates/sidereal-core`: IDs, shared constants/types, zero DB/network runtime logic.
- `crates/sidereal-sim-core`: deterministic shared simulation math.
- `crates/sidereal-input-map`: mapping network input models into sim-core controls.
- `crates/sidereal-net`: envelopes/messages/serialization contracts.
- `crates/sidereal-game`: ECS components/systems/gameplay logic.
- `crates/sidereal-persistence`: schema init, graph/relational persistence, hydration, replay utilities.

Binaries:

- `bins/sidereal-shard`
- `bins/sidereal-replication`
- `bins/sidereal-gateway`
- `bins/sidereal-orchestrator`
- `bins/sidereal-bg-sim`
- `bins/sidereal-client` (primary refactor target)
- `bins/sidereal-client-web` (WASM/browser target)
- `bins/sidereal-tools`

Folder layout guidance:

- `docs/`: design/ADRs/protocol/runtime defaults.
- `docker/` + `docker-compose.yaml`: local infra.
- `data/`: dev asset and DB data mounts.
- `scripts/`: repeatable local orchestration/dev flows.

## 17. Coding and Engineering Standards

### 17.1 Dependency and Workspace Discipline

- dependency versions align in root `[workspace.dependencies]`.
- avoid per-crate version drift.

### 17.2 Naming and Units

- explicit unit suffixes (`_m`, `_kg`, `_hz`, `_ms`, `_tick`),
- metric units only,
- snake_case modules/functions, PascalCase types.

### 17.3 Code Splitting Standard

- target module/file size around <=300 lines where practical,
- split by domain responsibility,
- no god modules combining protocol + ECS + persistence,
- wire DTOs, ECS components, and persistence models stay in separate crates/modules.

### 17.4 Boundary Rules

- no persistence/network code in core gameplay components unless via explicit boundary adapters,
- no Bevy `Entity` crossing service boundaries,
- protocol changes require synchronized updates to spec docs and tests.
- client platform/network adapters (native vs browser) must not fork gameplay/sim logic; keep shared code in common crates.

### 17.5 Operational Discipline

- structured logs include shard/tick/entity context where relevant,
- critical retries are explicit and observable,
- no silent authority fallbacks.
- runtime inspection endpoints (`bevy_remote`) must be auth-gated and enabled for shard/replication/client from day 0 scaffolding.

## 18. Runtime Defaults and Config Surface

Core defaults:

- sim tick: 30 Hz,
- render target: 60 Hz,
- snapshot send baseline: 20 Hz,
- interpolation buffer: ~100 ms,
- replication persist interval: 15 s,
- snapshot marker interval: 15 s.

Current notable env vars:

- `SIM_TICK_HZ`
- `REPLICATION_SEND_HZ`
- `SIDEREAL_UDP_CODEC` (`json` or `bincode`)
- `REPLICATION_PERSIST_INTERVAL_S`
- `SNAPSHOT_INTERVAL_S`
- `GATEWAY_*` visibility and delta thresholds
- `SIDEREAL_ASSET_ROOT` default: `./data`
- `SIDEREAL_ASSET_CACHE_DIR` default: `./client_cache/assets`
- `SIDEREAL_ASSET_CACHE_PAK_PATH` default: `./client_cache/assets/assets.pak`
- `SIDEREAL_ASSET_CACHE_INDEX_PATH` default: `./client_cache/assets/assets_index.bin`
- `SIDEREAL_ASSET_STREAM_CHUNK_BYTES`
- `SIDEREAL_CLIENT_TRANSPORT_NATIVE`
- `SIDEREAL_CLIENT_TRANSPORT_WEB` (target value direction: `webrtc` first, optional `websocket` fallback)
- `REPLICATION_CONTROL_UDP_BIND` / `REPLICATION_CONTROL_UDP_ADDR`

## 19. Local Development Setup (From Scratch)

### 19.1 Start PostgreSQL + AGE

```bash
docker compose up -d postgres
```

If `5432` is already in use:

```bash
SIDEREAL_PG_PORT=55432 docker compose up -d postgres
```

Container uses `apache/age:latest` and mounts:

- `./data/postgresql:/var/lib/postgresql`
- `./docker/init:/docker-entrypoint-initdb.d`

Reference compose shape:

```yaml
services:
  postgres:
    image: apache/age:latest
    environment:
      POSTGRES_DB: sidereal
      POSTGRES_USER: sidereal
      POSTGRES_PASSWORD: sidereal
    ports:
      - "${SIDEREAL_PG_PORT:-5432}:5432"
    volumes:
      - ./data/postgresql:/var/lib/postgresql
      - ./docker/init:/docker-entrypoint-initdb.d:ro
```

### 19.2 Verify AGE + Graph

```bash
docker exec sidereal-postgres psql -U sidereal -d sidereal -c "LOAD 'age'; SET search_path = ag_catalog, public; SELECT * FROM cypher('sidereal', \$\$ MATCH (n) RETURN count(n) \$\$) AS (count agtype);"
```

### 19.3 Run core services (example)

```bash
SIDEREAL_UDP_CODEC=bincode cargo run -p sidereal-replication
SIDEREAL_UDP_CODEC=bincode cargo run -p sidereal-shard
cargo run -p sidereal-gateway
```

### 19.4 Formatting/Lint/Compile baseline

```bash
cargo fmt --all
cargo clippy --workspace --all-targets -- -D warnings
cargo check --workspace
```

### 19.5 Asset Cache Runtime Behavior (Local Dev)

Expected behavior:

- user installs/runs small client binary,
- client authenticates and receives asset catalog/version metadata from backend,
- missing/stale assets are streamed and written into local `assets.pak` with index updates,
- subsequent launches reuse on-disk cache and only fetch invalidated/new assets.

## 20. Decision Register Carry-Forward (Relevant Locked Decisions)

Carry these as active constraints:

- DR-002 Canonical tick/time model.
- DR-003 Channel and protocol semantics with versioned envelopes.
- DR-004 visibility policy (authorization vs delivery scopes).
- DR-005 graph-native world persistence direction.
- DR-007 auth/session and trust boundary model.
- DR-013 one-way runtime authority direction.
- DR-014 UUID identity boundary.
- DR-015 register-only bootstrap behavior.
- DR-016 Avian->Transform sync contract.
- DR-017 staged prediction scope.
- DR-018 high-velocity reconciliation hardening direction.
- DR-019 staged UDP codec migration compatibility.

Open decisions to resolve early in a fresh rebuild:

- DR-001 handoff contract specifics,
- DR-006 recovery/failover semantics,
- DR-008 economy consistency model,
- DR-009 physics authority classing,
- DR-010 observability baseline,
- DR-011 final client scope freeze,
- DR-012 bootstrap/workspace operational boundaries.

## 21. Example Contracts and Snippets (Reference)

Network envelope:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetEnvelope<T> {
    pub protocol_version: u16,
    pub channel: ChannelClass,
    pub source_shard_id: i32,
    pub lease_epoch: u64,
    pub seq: u64,
    pub tick: u64,
    pub payload: T,
}
```

Input snapshot (current protocol style):

```rust
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct InputSnapshot {
    pub thrust_forward: bool,
    pub thrust_reverse: bool,
    pub yaw_left: bool,
    pub yaw_right: bool,
    pub stop_requested: bool,
    pub reset_requested: bool,
}
```

Visibility pseudo-code:

```rust
fn compute_visibility(player: &PlayerState, entity: &EntityState) -> Visibility {
    if player.owns(entity.id) || player.owns_parent_of(entity.id) {
        return Visibility::Full;
    }
    if player.any_scanner_authorizes(entity.id) {
        return Visibility::Redacted;
    }
    Visibility::None
}
```

Startup AGE ensure pseudo-flow:

```rust
sqlx::query("CREATE EXTENSION IF NOT EXISTS age;").execute(conn).await?;
sqlx::query("LOAD 'age';").execute(conn).await?;
sqlx::query("SET search_path = ag_catalog, \"$user\", public;").execute(conn).await?;
// ensure graph sidereal exists
sqlx::query("SET search_path = public;").execute(conn).await?;
```

## 22. Implementation Sequence (Rebuild Order)

1. Bootstrap workspace + crates + strict boundaries.
2. Implement auth/session domain in gateway and relational schema.
3. Implement AGE schema init + graph persistence primitives.
4. Implement shard authoritative fixed-step sim and ECS baseline.
5. Implement replication ingest/persist and visibility filtering contracts.
6. Implement client with tick-indexed input, controlled prediction, remote interpolation buffer.
7. Implement scan grants + multi-stream visibility.
8. Add asset streaming manager with placeholder-first policy.
9. Add scripting bridge and procedural asteroid pipeline behind feature flags.
10. Implement orchestrator and multi-shard handoff semantics.

## 23. Acceptance Criteria for "Same Stage as Current, Refactor-Baked"

- Auth/register/login/refresh/reset flows operational.
- Registration creates playable starter ship world state through replication-owned bootstrap path.
- Single-shard authoritative movement with stable local control and no frequent correction snaps at high speed.
- Remote entities rendered via snapshot-buffer interpolation.
- Server-authorized redaction working (owned vs non-owned visibility differences).
- Graph persistence + startup hydration functioning with no periodic DB->live overwrite.
- Shared `sidereal-sim-core` used by shard and client prediction path.
- Asset IDs delivered with placeholder fallback and no gameplay impact from missing assets.
- Native and WASM clients both build in CI with shared gameplay code and transport-specific adapters only at boundary layers.
- Baseline docs/decisions/coding standards synchronized with implementation.

## 24. Compact Glossary

- `Authority`: the service that is allowed to decide final world state.
- `Shard`: authoritative simulation process for one or more regions.
- `Replication`: client-facing state distribution and durability staging service.
- `Lease Epoch`: monotonic ownership version used to prevent dual authority.
- `Prediction`: client local simulation ahead of confirmed server state.
- `Reconciliation`: correction process when authoritative state diverges from prediction.
- `Interpolation`: rendering entities between buffered snapshots from the past.
- `Extrapolation`: bounded forward estimate when no newer snapshot is available.
- `Authorization Scope`: data a player is allowed to know.
- `Delivery Scope`: subset of authorized data actively sent in a given stream.
- `Hydration`: loading durable graph state into runtime ECS state.
- `Reflect Envelope`: persisted component payload shape keyed by Rust type path.
