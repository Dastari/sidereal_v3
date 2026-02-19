use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;

#[cfg(feature = "lightyear_protocol")]
mod lightyear_protocol;
#[cfg(feature = "lightyear_protocol")]
pub use lightyear_protocol::*;

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum ChannelClass {
    Input,
    State,
    Control,
}

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

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WorldComponentDelta {
    pub component_id: String,
    pub component_kind: String,
    pub properties: JsonValue,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WorldDeltaEntity {
    pub entity_id: String,
    #[serde(default)]
    pub labels: Vec<String>,
    #[serde(default)]
    pub properties: JsonValue,
    #[serde(default)]
    pub components: Vec<WorldComponentDelta>,
    #[serde(default)]
    pub removed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
pub struct WorldStateDelta {
    #[serde(default)]
    pub updates: Vec<WorldDeltaEntity>,
}

pub fn encode_envelope_json<T: Serialize>(
    envelope: &NetEnvelope<T>,
) -> serde_json::Result<Vec<u8>> {
    serde_json::to_vec(envelope)
}

pub fn decode_envelope_json<T: DeserializeOwned>(
    bytes: &[u8],
) -> serde_json::Result<NetEnvelope<T>> {
    serde_json::from_slice(bytes)
}
