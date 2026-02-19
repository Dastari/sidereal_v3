use bevy::prelude::*;
use lightyear::prelude::NetworkTarget;
use std::collections::HashMap;

use sidereal_net::WorldStateDelta;

/// Registry tracking authenticated client sessions and their player entity IDs
#[derive(Resource, Default)]
pub struct ClientVisibilityRegistry {
    /// Maps lightyear client entities to their authenticated player_entity_id
    /// (e.g., "player:550e8400-e29b-41d4-a716-446655440000")
    pub player_entity_id_by_client: HashMap<Entity, String>,
}

impl ClientVisibilityRegistry {
    pub fn register_client(&mut self, client_entity: Entity, player_entity_id: String) {
        self.player_entity_id_by_client
            .insert(client_entity, player_entity_id);
    }

    #[allow(dead_code)]
    pub fn unregister_client(&mut self, client_entity: Entity) {
        self.player_entity_id_by_client.remove(&client_entity);
    }

    pub fn get_player_id(&self, client_entity: Entity) -> Option<&str> {
        self.player_entity_id_by_client
            .get(&client_entity)
            .map(|s| s.as_str())
    }
}

/// Visibility scope for a client session
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VisibilityScope {
    /// Full visibility: client sees all entities/components they own
    Authenticated,
    /// No visibility: env var override for testing visibility denial
    None,
}

/// Session-specific visibility context used during filtering
#[derive(Debug, Clone)]
pub struct VisibilityContext {
    pub scope: VisibilityScope,
    /// The authenticated player_entity_id for this session (if authenticated)
    pub player_entity_id: Option<String>,
}

impl VisibilityContext {
    /// Create context for authenticated client
    pub fn authenticated(player_entity_id: String) -> Self {
        Self {
            scope: VisibilityScope::Authenticated,
            player_entity_id: Some(player_entity_id),
        }
    }

    /// Create context with no visibility (testing/admin override)
    pub fn none() -> Self {
        Self {
            scope: VisibilityScope::None,
            player_entity_id: None,
        }
    }
}

/// Components that are always safe to send (render-only, no gameplay secrets)
const ALWAYS_VISIBLE_PROPERTIES: &[&str] = &[
    "entity_id",
    "position_m",
    "velocity_mps",
    "display_name",
    "ship_tag",
    "module_tag",
    "mounted_on_entity_id",
    "parent_entity_id",
    "size_m",
    "collision_aabb_m",
    "mass_kg",
    "asset_id",
    "starfield_shader_asset_id",
];

/// Properties that require ownership to view (gameplay-sensitive)
#[allow(dead_code)]
const OWNER_ONLY_PROPERTIES: &[&str] = &[
    "health",
    "owner_entity_id",
    "shard_assignment",
    "fuel",
    "thrust_mps2",
    "turn_rad_per_sec",
    "hardpoint_id",
];

/// Build visibility context for a client session
pub fn visibility_context_for_client(
    client_entity: Entity,
    registry: &ClientVisibilityRegistry,
) -> VisibilityContext {
    // Check for test override
    if std::env::var("REPLICATION_VISIBILITY_MODE")
        .is_ok_and(|mode| mode.eq_ignore_ascii_case("none"))
    {
        return VisibilityContext::none();
    }

    // Normal authenticated path
    if let Some(player_id) = registry.get_player_id(client_entity) {
        VisibilityContext::authenticated(player_id.to_string())
    } else {
        // Client connected but not authenticated yet - no visibility
        VisibilityContext::none()
    }
}

/// Apply visibility filtering to world state delta
pub fn apply_visibility_filter(
    world: &WorldStateDelta,
    ctx: &VisibilityContext,
) -> Option<WorldStateDelta> {
    match ctx.scope {
        VisibilityScope::None => None,
        VisibilityScope::Authenticated => {
            let player_id = ctx.player_entity_id.as_ref()?;
            Some(filter_world_by_ownership(world, player_id))
        }
    }
}

/// Filter world delta to only include entities/components this player can see
///
/// Ownership is determined by the `OwnerId` ECS component (component_kind="owner_id").
/// This is a proper Bevy component, not a property in the JSON blob.
///
/// Design invariant: We use stable entity_id (UUIDs/strings), not Bevy Entity IDs,
/// because Entity IDs don't persist across database hydration cycles.
fn filter_world_by_ownership(world: &WorldStateDelta, player_entity_id: &str) -> WorldStateDelta {
    let mut filtered_updates = Vec::new();

    for update in &world.updates {
        if update.removed {
            // Always propagate removals (client needs to know entities despawned)
            filtered_updates.push(update.clone());
            continue;
        }

        // Check if this entity is owned by the player via OwnerId component
        // OwnerId is serialized as a component with component_kind="owner_id"
        // and its value stored in the component's properties field
        let is_owned = update.components.iter().any(|comp| {
            comp.component_kind == "owner_id"
                && comp
                    .properties
                    .as_str()
                    .map(|s| s == player_entity_id)
                    .unwrap_or(false)
        });

        if is_owned {
            // Player owns this entity - include with full properties and components
            filtered_updates.push(update.clone());
        } else {
            // Not owned - include only safe render properties, drop all components
            let mut redacted = update.clone();
            if let Some(obj) = redacted.properties.as_object_mut() {
                obj.retain(|key, _| is_property_always_visible(key));
            }
            // Drop all components for non-owned entities
            redacted.components.clear();

            // Only include if there are still visible properties
            if let Some(obj) = redacted.properties.as_object()
                && !obj.is_empty()
            {
                filtered_updates.push(redacted);
            }
        }
    }

    WorldStateDelta {
        updates: filtered_updates,
    }
}

/// Check if property is always visible (render-safe)
fn is_property_always_visible(property_name: &str) -> bool {
    ALWAYS_VISIBLE_PROPERTIES.contains(&property_name)
}

/// Determine network target for filtered state
pub fn delivery_target_for_session(
    ctx: &VisibilityContext,
    peer_id: lightyear::prelude::PeerId,
) -> NetworkTarget {
    match ctx.scope {
        VisibilityScope::Authenticated => NetworkTarget::Single(peer_id),
        VisibilityScope::None => NetworkTarget::None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sidereal_net::{WorldComponentDelta, WorldDeltaEntity};

    fn make_test_entity(
        entity_id: &str,
        owner_id: Option<&str>,
        has_health: bool,
    ) -> WorldDeltaEntity {
        let mut properties = serde_json::json!({
            "entity_id": entity_id,
            "position_m": [100.0, 200.0, 0.0],
        });

        if has_health {
            properties["health"] = serde_json::json!(1000.0);
        }

        let mut components = vec![];

        // OwnerId is a proper ECS component, not a property
        if let Some(owner) = owner_id {
            components.push(WorldComponentDelta {
                component_id: format!("{}:owner_id", entity_id),
                component_kind: "owner_id".to_string(),
                properties: serde_json::json!(owner),
            });
        }

        WorldDeltaEntity {
            entity_id: entity_id.to_string(),
            labels: vec!["Entity".to_string()],
            properties,
            components,
            removed: false,
        }
    }

    #[test]
    fn authenticated_client_sees_owned_entities_fully() {
        let world = WorldStateDelta {
            updates: vec![
                make_test_entity("ship:1", Some("player:alice"), true),
                make_test_entity("ship:2", Some("player:bob"), true),
            ],
        };

        let ctx = VisibilityContext::authenticated("player:alice".to_string());
        let filtered = apply_visibility_filter(&world, &ctx).unwrap();

        // Should see own ship fully
        let own_ship = filtered
            .updates
            .iter()
            .find(|e| e.entity_id == "ship:1")
            .unwrap();
        assert!(own_ship.properties.get("health").is_some());

        // Should see other ship with only safe properties
        let other_ship = filtered
            .updates
            .iter()
            .find(|e| e.entity_id == "ship:2")
            .unwrap();
        assert!(other_ship.properties.get("position_m").is_some());
        assert!(other_ship.properties.get("health").is_none());
    }

    #[test]
    fn unauthenticated_context_returns_none() {
        let world = WorldStateDelta {
            updates: vec![make_test_entity("ship:1", Some("player:alice"), true)],
        };

        let ctx = VisibilityContext::none();
        let filtered = apply_visibility_filter(&world, &ctx);

        assert!(filtered.is_none());
    }

    #[test]
    fn registry_tracks_client_player_mapping() {
        let mut registry = ClientVisibilityRegistry::default();
        let client = Entity::from_bits(42);

        registry.register_client(client, "player:alice".to_string());
        assert_eq!(registry.get_player_id(client), Some("player:alice"));

        registry.unregister_client(client);
        assert_eq!(registry.get_player_id(client), None);
    }

    #[test]
    fn always_visible_properties_are_recognized() {
        assert!(is_property_always_visible("entity_id"));
        assert!(is_property_always_visible("position_m"));
        assert!(is_property_always_visible("display_name"));
        assert!(!is_property_always_visible("health"));
        assert!(!is_property_always_visible("fuel"));
    }

    #[test]
    fn visibility_scope_types_exist() {
        let auth = VisibilityContext::authenticated("player:test".to_string());
        assert_eq!(auth.scope, VisibilityScope::Authenticated);

        let none = VisibilityContext::none();
        assert_eq!(none.scope, VisibilityScope::None);
    }
}
