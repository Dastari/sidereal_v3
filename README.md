# sidereal_v3

Sidereal rebuild workspace (server-authoritative architecture, Bevy 0.18, Lightyear transport, Postgres+AGE persistence).

## Quick Start

1. Start database:
```bash
make pg-up
```

2. Run core services:
```bash
make dev-stack
```

3. (Optional) Run native client too:
```bash
make dev-stack-client
```

## Useful Targets

```bash
make help
make pg-reset          # destructive: resets local postgres volume
make fmt
make clippy
make check
make wasm-check
make test
make register-demo     # quick register call against gateway
```

## Current Vertical Slice Status

- Native client auth UI scaffold exists (register/login/forgot).
- Gateway serves `/world/me` and streamed assets (`/assets/stream/{asset_id}`).
- Replication receives shard deltas via Lightyear and re-broadcasts to connected sessions.
- Starter ship bootstrap path is covered by integration tests.
- Transport e2e test (`replication + shard + headless client`) is in place.
