## Summary

- [ ] I described what changed and why.

## Validation

- [ ] `cargo fmt --all -- --check`
- [ ] `cargo clippy --workspace --all-targets -- -D warnings`
- [ ] `cargo check --workspace`
- [ ] If client code changed: `cargo check -p sidereal-client`
- [ ] If client code changed: `cargo check -p sidereal-client --target wasm32-unknown-unknown --features bevy/webgpu`

## Client + WASM Parity

- [ ] For client behavior/protocol/runtime changes, native and WASM were updated in the same PR.
- [ ] I documented native impact and WASM impact (or explicitly stated `no WASM impact`).
- [ ] WASM path was validated with WebGPU support enabled (`bevy/webgpu`).
