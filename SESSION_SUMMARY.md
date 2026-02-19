# Session Summary: Architecture Simplification

**Date:** 2026-02-19
**Status:** Ready for next session

## What Was Accomplished

### 1. Architecture Decision: Removed Separate Shard Servers

**Rationale:** Simplify for faster iteration. Consolidate simulation into replication server.

**Old Architecture:**
```
Client → Gateway (auth) + Replication (routing) → Multiple Shards (simulation)
```

**New Architecture:**
```
Client → Gateway (auth HTTP) + Replication (simulation + transport)
```

### 2. Protocol Cleanup

**Removed Messages:**
- `ShardRegisterMessage`
- `EntityAssignmentMessage`  
- `ShardStateMessage`
- `RoutedInputMessage`

**Kept Messages:**
- `ClientInputMessage` - Updated to use `Vec<EntityAction>` instead of `thrust`/`turn`
- `ReplicationStateMessage` - Unchanged

### 3. Documentation Updates

**Updated Files:**
- `docs/sidereal_implementation_checklist.md` - Complete rewrite of Phase 3 & 4
- `bins/sidereal-shard/README.md` - Documented as future use
- `crates/sidereal-net/src/lightyear_protocol.rs` - Cleaned protocol

**Key Sections:**
- Architecture flow diagrams
- Step-by-step implementation guide  
- Breaking changes documented
- Clear next steps outlined

### 4. Dependencies Added

- `avian3d` to `bins/sidereal-replication/Cargo.toml`
- `sidereal-game` to `bins/sidereal-replication/Cargo.toml`

## What's Left (Next Session)

### Critical Path to Playable Loop

**Replication Server (Priority 1):**
1. Fix compilation errors:
   - Remove `ShardStateMessage` imports
   - Remove `receive_shard_state` system
2. Add Avian physics:
   - `app.add_plugins(PhysicsPlugins::default().with_length_unit(1.0))`
   - `app.insert_resource(Gravity(Vec3::ZERO))`
3. Add gameplay:
   - `app.add_plugins(SiderealGamePlugin)` (brings action systems)
4. Hydrate entities from database on startup
5. Route `ClientInputMessage` to entity `ActionQueue`
6. Broadcast state via `ReplicationStateMessage`

**Client (Priority 2):**
1. Capture keyboard → `EntityAction`
2. Send `ClientInputMessage` to replication
3. Receive `ReplicationStateMessage` → spawn/update entities
4. Render HUD (position, velocity, health)

**Optional (Priority 3):**
- Client-side prediction with Avian
- Reconciliation/rollback

## Current State

**✅ Working:**
- Action routing system (`EntityAction` → `ActionQueue` → `FlightComputer` → `Engine` → Avian `Forces`)
- Avian physics tested in isolation
- Protocol messages defined
- Visibility filtering
- Database bootstrap

**⚠️ Broken (Compilation Errors):**
- Replication server (uses old `ShardStateMessage`)
- Shard server (deprecated, can ignore)
- Client (uses old `ClientInputMessage` fields)

**Estimated Fix Time:** ~30 minutes to fix compilation + add physics to replication

## Files Modified This Session

- `crates/sidereal-net/src/lightyear_protocol.rs` - Protocol cleanup
- `crates/sidereal-net/Cargo.toml` - Added `sidereal-game` dependency
- `bins/sidereal-replication/Cargo.toml` - Added `avian3d`, `sidereal-game`
- `bins/sidereal-shard/README.md` - Documented future use
- `docs/sidereal_implementation_checklist.md` - Major update

## Next Session Checklist

- [ ] Fix compilation errors in replication/client
- [ ] Add physics to replication server
- [ ] Implement entity hydration from database  
- [ ] Implement input routing to ActionQueue
- [ ] Implement state broadcast
- [ ] Test: Register → Login → Move ship → See movement
