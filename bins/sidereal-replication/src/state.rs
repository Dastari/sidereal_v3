use sidereal_net::{NetEnvelope, WorldDeltaEntity, WorldStateDelta};
use sidereal_persistence::{GraphPersistence, PersistenceError};
use std::collections::{HashMap, HashSet};

pub fn hydrate_known_entity_ids(
    persistence: &mut GraphPersistence,
) -> std::result::Result<HashSet<String>, PersistenceError> {
    let records = persistence.load_graph_records()?;
    Ok(records
        .into_iter()
        .map(|record| record.entity_id)
        .collect::<HashSet<_>>())
}

pub fn ingest_world_delta(
    known_entities: &mut HashSet<String>,
    pending_updates: &mut HashMap<String, WorldDeltaEntity>,
    delta: WorldStateDelta,
) -> bool {
    let mut has_removals = false;
    for update in delta.updates {
        if update.removed {
            known_entities.remove(&update.entity_id);
            has_removals = true;
        } else {
            known_entities.insert(update.entity_id.clone());
        }
        pending_updates.insert(update.entity_id.clone(), update);
    }
    has_removals
}

pub fn ingest_world_envelope(
    known_entities: &mut HashSet<String>,
    pending_updates: &mut HashMap<String, WorldDeltaEntity>,
    envelope: NetEnvelope<WorldStateDelta>,
) -> bool {
    ingest_world_delta(known_entities, pending_updates, envelope.payload)
}

pub fn flush_pending_updates(
    persistence: &mut GraphPersistence,
    pending_updates: &mut HashMap<String, WorldDeltaEntity>,
    tick: u64,
) -> std::result::Result<usize, PersistenceError> {
    if pending_updates.is_empty() {
        return Ok(0);
    }
    let batch = pending_updates
        .drain()
        .map(|(_, update)| update)
        .collect::<Vec<_>>();
    let count = batch.len();
    persistence.persist_world_delta(&batch, tick)?;
    Ok(count)
}
