//! Flight Control System
//!
//! Implements the action routing chain:
//! EntityAction → FlightComputer → Engine → fuel check → Forces.apply_force()
//!
//! Architecture:
//! 1. FlightComputer component on parent entity translates actions to control state (throttle, yaw)
//! 2. Engine modules mounted on parent read control state
//! 3. Engines check fuel availability via FuelTank
//! 4. If fuel available: compute force vector, apply via Avian's Forces query helper, drain fuel
//! 5. Avian's physics integrator handles the rest

use avian3d::prelude::*;
use bevy::prelude::*;
use std::collections::HashMap;
use uuid::Uuid;

use crate::actions::{ActionQueue, EntityAction};
use crate::generated::components::{Engine, EntityGuid, FlightComputer, FuelTank, MountedOn};

/// System that processes actions and updates FlightComputer state
pub fn process_flight_actions(
    mut query: Query<(&mut ActionQueue, &mut FlightComputer, Option<&MountedOn>)>,
) {
    for (mut queue, mut computer, mounted_on) in &mut query {
        if queue.pending.is_empty() {
            continue;
        }

        for action in queue.drain() {
            match action {
                EntityAction::ThrustForward => computer.throttle = 1.0,
                EntityAction::ThrustReverse => computer.throttle = -0.7, // Reverse is typically weaker
                EntityAction::ThrustNeutral => computer.throttle = 0.0,
                EntityAction::YawLeft => computer.yaw_input = -1.0,
                EntityAction::YawRight => computer.yaw_input = 1.0,
                EntityAction::YawNeutral => computer.yaw_input = 0.0,
                _ => {
                    // Flight computer doesn't handle this action
                    if mounted_on.is_some() {
                        debug!(action = ?action, "FlightComputer module ignoring non-flight action");
                    }
                }
            }
        }
    }
}

/// System that applies engine thrust based on FlightComputer state
/// Uses Avian's Forces query helper for proper force integration
pub fn apply_engine_thrust(
    time: Res<Time>,
    // Parent entities with flight computers (by GUID)
    computers: Query<(&EntityGuid, &FlightComputer, Option<&MountedOn>)>,
    // Parent entities that can receive forces (Avian Forces query helper)
    mut bodies: Query<(&EntityGuid, &Transform, Forces)>,
    // Engine modules
    mut engines: Query<(&MountedOn, &Engine, &mut FuelTank)>,
) {
    let dt = time.delta_secs();

    // Build map of control state by parent entity GUID
    let mut control_by_parent = HashMap::<Uuid, (f32, f32, f32)>::new();
    for (guid, computer, mounted_on) in &computers {
        let parent_guid = if let Some(mount) = mounted_on {
            // FlightComputer is a module, use parent GUID
            mount.parent_entity_id
        } else {
            // FlightComputer is built-in to the entity
            guid.0
        };

        control_by_parent.entry(parent_guid).or_insert((
            computer.throttle,
            computer.yaw_input,
            computer.turn_rate_deg_s,
        ));
    }

    // Aggregate forces from all engines by parent GUID
    let mut total_force_by_parent = HashMap::<Uuid, Vec3>::new();
    let mut fuel_exhausted_count = HashMap::<Uuid, usize>::new();

    for (mounted_on, engine, mut fuel_tank) in &mut engines {
        let Some((throttle, _, _)) = control_by_parent.get(&mounted_on.parent_entity_id) else {
            // No flight computer on this parent, engine idle
            continue;
        };

        if *throttle == 0.0 {
            continue;
        }

        // Check fuel availability
        if fuel_tank.fuel_kg <= 0.0 {
            *fuel_exhausted_count
                .entry(mounted_on.parent_entity_id)
                .or_insert(0) += 1;
            continue;
        }

        // Compute fuel burn
        let requested_burn_kg = engine.burn_rate_kg_s * throttle.abs() * dt;
        let actual_burn_kg = requested_burn_kg.min(fuel_tank.fuel_kg);
        let thrust_scale = if requested_burn_kg > 0.0 {
            actual_burn_kg / requested_burn_kg
        } else {
            1.0
        };

        fuel_tank.fuel_kg -= actual_burn_kg;

        // Compute thrust force in local space
        let thrust_n = engine.thrust_n * throttle * thrust_scale;
        let thrust_vec = engine.thrust_dir * thrust_n;

        total_force_by_parent
            .entry(mounted_on.parent_entity_id)
            .and_modify(|f| *f += thrust_vec)
            .or_insert(thrust_vec);
    }

    // Apply aggregated forces to parent bodies using Avian's Forces helper
    for (guid, transform, mut forces) in &mut bodies {
        // Apply thrust force
        if let Some(force_local) = total_force_by_parent.get(&guid.0) {
            // Rotate force from local space to world space
            let force_world = transform.rotation * *force_local;

            // Use Avian's proper force API
            forces.apply_force(force_world);
        } else {
            // Log if throttle was applied but no force resulted
            if let Some((throttle, _, _)) = control_by_parent.get(&guid.0) {
                if *throttle != 0.0 {
                    let exhausted = fuel_exhausted_count.get(&guid.0).copied().unwrap_or(0);
                    if exhausted > 0 {
                        debug!(
                            entity_guid = %guid.0,
                            exhausted_engines = exhausted,
                            "throttle applied but all engines out of fuel"
                        );
                    }
                }
            }
        }

        // Apply yaw torque using Avian's proper API
        if let Some((_, yaw_input, turn_rate_deg_s)) = control_by_parent.get(&guid.0) {
            if *yaw_input != 0.0 {
                let yaw_rate_rad_s = turn_rate_deg_s.to_radians() * yaw_input;
                // Z-axis rotation for top-down space
                // TODO: Proper torque calculation based on inertia tensor
                // For now, use a heuristic torque magnitude
                let torque = Vec3::new(0.0, 0.0, yaw_rate_rad_s * 10000.0);
                forces.apply_torque(torque);
            }
        }
    }
}
