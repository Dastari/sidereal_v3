# Sidereal Shard Server (Future Use)

**STATUS: NOT CURRENTLY USED**

This binary is reserved for future multi-shard spatial partitioning architecture.

## Current Architecture (v3 Simplified)

The replication server (`bins/sidereal-replication`) handles:
- Client connections
- Avian physics simulation
- Action routing
- Visibility filtering  
- Persistence

## Future Architecture (Multi-Shard)

When scaling to massive worlds with spatial partitioning, this binary will be activated to:
- Own bounded spatial regions
- Simulate entities in assigned region
- Handoff entities at boundaries
- Communicate with replication server for aggregation

## Why Not Now?

- Simpler architecture for initial development
- Avoid premature optimization
- Get gameplay loop working first
- Add complexity only when needed for scale

## When to Activate

Consider enabling shards when:
- Single replication server can't handle physics load
- Need > 1000 concurrent simulated entities
- Want spatial load balancing
- Ready to implement handoff protocols

Until then, all simulation stays in `bins/sidereal-replication`.
