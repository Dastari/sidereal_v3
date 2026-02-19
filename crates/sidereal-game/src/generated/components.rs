use bevy::prelude::*;
use bevy::reflect::Reflect;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(
    Debug, Clone, Copy, Default, Component, Reflect, Serialize, Deserialize, PartialEq, Eq, Hash,
)]
#[reflect(Component, Serialize, Deserialize)]
pub struct EntityGuid(pub Uuid);

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq, Eq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct DisplayName(pub String);

#[derive(Debug, Clone, Copy, Default, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct PositionM(pub Vec3);

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid, PositionM)]
pub struct VelocityMps(pub Vec3);

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq, Eq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct ShardAssignment(pub i32);

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct Hardpoint {
    pub hardpoint_id: String,
    pub offset_m: Vec3,
}

#[derive(Debug, Clone, Default, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct MountedOn {
    pub parent_entity_id: Uuid,
    pub hardpoint_id: String,
}

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid, MountedOn)]
pub struct Engine {
    pub thrust_n: f32,
    pub burn_rate_kg_s: f32,
    pub thrust_dir: Vec3,
}

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct FuelTank {
    pub fuel_kg: f32,
}

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct FlightComputer {
    /// Control profile (e.g., "basic_fly_by_wire", "combat_agile", "missile_guidance")
    pub profile: String,
    /// Current throttle setting (-1.0 to 1.0)
    pub throttle: f32,
    /// Current yaw input (-1.0 to 1.0)
    pub yaw_input: f32,
    /// Turn rate in degrees per second
    pub turn_rate_deg_s: f32,
}

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct HealthPool {
    pub current: f32,
    pub maximum: f32,
}

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct MassKg(pub f32);

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct SizeM {
    pub length: f32,
    pub width: f32,
    pub height: f32,
}

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct CollisionAabbM {
    pub half_extents: Vec3,
}

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq, Eq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct ShipTag;

#[derive(Debug, Clone, Copy, Component, Reflect, Serialize, Deserialize, PartialEq, Eq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct ModuleTag;

#[derive(Debug, Clone, Copy, Reflect, Serialize, Deserialize, PartialEq, Eq)]
#[reflect(Serialize, Deserialize)]
pub enum OwnerKind {
    Player,
    Faction,
    World,
    Unowned,
}

#[derive(Debug, Clone, Component, Reflect, Serialize, Deserialize, PartialEq, Eq)]
#[reflect(Component, Serialize, Deserialize)]
#[require(EntityGuid)]
pub struct OwnerId(pub String);

impl Default for OwnerKind {
    fn default() -> Self {
        OwnerKind::Unowned
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ComponentRegistryEntry {
    pub component_kind: &'static str,
    pub type_path: &'static str,
}

#[derive(Debug, Resource, Clone)]
pub struct GeneratedComponentRegistry {
    pub entries: Vec<ComponentRegistryEntry>,
}

pub fn register_generated_components(app: &mut App) {
    app.register_type::<EntityGuid>()
        .register_type::<DisplayName>()
        .register_type::<PositionM>()
        .register_type::<VelocityMps>()
        .register_type::<ShardAssignment>()
        .register_type::<Hardpoint>()
        .register_type::<MountedOn>()
        .register_type::<Engine>()
        .register_type::<FuelTank>()
        .register_type::<FlightComputer>()
        .register_type::<HealthPool>()
        .register_type::<MassKg>()
        .register_type::<SizeM>()
        .register_type::<CollisionAabbM>()
        .register_type::<ShipTag>()
        .register_type::<ModuleTag>()
        .register_type::<OwnerKind>()
        .register_type::<OwnerId>()
        .insert_resource(GeneratedComponentRegistry {
            entries: generated_component_registry(),
        });
}

pub fn generated_component_registry() -> Vec<ComponentRegistryEntry> {
    vec![
        entry::<EntityGuid>("entity_guid"),
        entry::<DisplayName>("display_name"),
        entry::<PositionM>("position_m"),
        entry::<VelocityMps>("velocity_mps"),
        entry::<ShardAssignment>("shard_assignment"),
        entry::<Hardpoint>("hardpoint"),
        entry::<MountedOn>("mounted_on"),
        entry::<Engine>("engine"),
        entry::<FuelTank>("fuel_tank"),
        entry::<FlightComputer>("flight_computer"),
        entry::<HealthPool>("health_pool"),
        entry::<MassKg>("mass_kg"),
        entry::<SizeM>("size_m"),
        entry::<CollisionAabbM>("collision_aabb_m"),
        entry::<ShipTag>("ship_tag"),
        entry::<ModuleTag>("module_tag"),
        entry::<OwnerId>("owner_id"),
    ]
}

fn entry<T>(component_kind: &'static str) -> ComponentRegistryEntry {
    ComponentRegistryEntry {
        component_kind,
        type_path: std::any::type_name::<T>(),
    }
}
