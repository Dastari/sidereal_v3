/// Shared deterministic simulation core for client prediction and server authority.
///
/// All movement/control logic must be deterministic and match between client and server.
/// No ECS queries, resources, or side effects - pure functions only.
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq)]
pub struct InputSnapshot {
    pub thrust_forward: bool,
    pub thrust_reverse: bool,
    pub yaw_left: bool,
    pub yaw_right: bool,
}

impl InputSnapshot {
    pub fn is_neutral(&self) -> bool {
        !self.thrust_forward && !self.thrust_reverse && !self.yaw_left && !self.yaw_right
    }
}

/// Kinematic state for any controllable entity (ships, missiles, stations, asteroids, etc.)
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct EntityKinematics {
    pub position_m: [f32; 3],
    pub velocity_mps: [f32; 3],
    pub heading_rad: f32,
}

impl Default for EntityKinematics {
    fn default() -> Self {
        Self {
            position_m: [0.0, 0.0, 0.0],
            velocity_mps: [0.0, 0.0, 0.0],
            heading_rad: 0.0,
        }
    }
}

/// Control tuning parameters for any controllable entity
#[derive(Debug, Clone, Copy)]
pub struct ControlTuning {
    /// Thrust acceleration in m/s²
    pub thrust_accel_mps2: f32,
    /// Yaw rate in rad/s
    pub yaw_rate_rad_per_s: f32,
    /// Drag coefficient (0-1 fraction per second)
    pub drag_per_s: f32,
}

impl Default for ControlTuning {
    fn default() -> Self {
        Self {
            thrust_accel_mps2: 14.0,
            yaw_rate_rad_per_s: 1.8,
            drag_per_s: 0.4,
        }
    }
}

impl ControlTuning {
    /// Corvette-class control parameters
    pub fn corvette() -> Self {
        Self::default()
    }

    /// Asteroid with strapped engine (slow, heavy)
    pub fn asteroid_with_engine() -> Self {
        Self {
            thrust_accel_mps2: 2.0,
            yaw_rate_rad_per_s: 0.3,
            drag_per_s: 0.1,
        }
    }

    /// Missile (fast, agile)
    pub fn missile() -> Self {
        Self {
            thrust_accel_mps2: 50.0,
            yaw_rate_rad_per_s: 4.0,
            drag_per_s: 0.05,
        }
    }
}

/// Step entity kinematics forward by one timestep (deterministic)
pub fn step_entity_kinematics(
    state: &EntityKinematics,
    input: InputSnapshot,
    tuning: &ControlTuning,
    dt_s: f32,
) -> EntityKinematics {
    let mut next = *state;

    // 1. Apply yaw (turn)
    let yaw_delta = if input.yaw_left {
        tuning.yaw_rate_rad_per_s * dt_s
    } else if input.yaw_right {
        -tuning.yaw_rate_rad_per_s * dt_s
    } else {
        0.0
    };
    next.heading_rad += yaw_delta;

    // 2. Calculate forward direction
    let forward = [next.heading_rad.sin(), next.heading_rad.cos(), 0.0];

    // 3. Apply thrust acceleration
    let thrust_accel = if input.thrust_forward {
        tuning.thrust_accel_mps2
    } else if input.thrust_reverse {
        -tuning.thrust_accel_mps2 * 0.7 // Reverse is 70% power
    } else {
        0.0
    };

    // 4. Integrate velocity
    for (i, component) in forward.iter().enumerate() {
        next.velocity_mps[i] += component * thrust_accel * dt_s;
    }

    // 5. Apply drag
    let drag_factor = (1.0 - tuning.drag_per_s * dt_s).clamp(0.0, 1.0);
    for i in 0..3 {
        next.velocity_mps[i] *= drag_factor;
    }

    // 6. Integrate position
    for i in 0..3 {
        next.position_m[i] += next.velocity_mps[i] * dt_s;
    }

    next
}

/// Legacy single-axis velocity integration (kept for compatibility)
pub fn integrate_forward_velocity_mps(
    current_velocity_mps: f32,
    input: InputSnapshot,
    dt_s: f32,
    thrust_accel_mps2: f32,
    drag_per_s: f32,
) -> f32 {
    let mut accel = 0.0;
    if input.thrust_forward {
        accel += thrust_accel_mps2;
    }
    if input.thrust_reverse {
        accel -= thrust_accel_mps2;
    }

    let mut next = current_velocity_mps + accel * dt_s;
    let drag_factor = (1.0 - drag_per_s * dt_s).clamp(0.0, 1.0);
    next *= drag_factor;
    next
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn neutral_input_applies_only_drag() {
        let state = EntityKinematics {
            position_m: [0.0, 0.0, 0.0],
            velocity_mps: [10.0, 0.0, 0.0],
            heading_rad: 0.0,
        };
        let input = InputSnapshot::default();
        let tuning = ControlTuning::default();

        let next = step_entity_kinematics(&state, input, &tuning, 1.0);

        // Velocity should decay by drag (0.4 per second)
        assert!((next.velocity_mps[0] - 6.0).abs() < 0.01);
        // Position should integrate velocity
        assert!(next.position_m[0] > 0.0);
    }

    #[test]
    fn thrust_forward_accelerates() {
        let state = EntityKinematics::default();
        let input = InputSnapshot {
            thrust_forward: true,
            ..Default::default()
        };
        let tuning = ControlTuning::default();

        let next = step_entity_kinematics(&state, input, &tuning, 1.0);

        // Should have accelerated forward
        assert!(next.velocity_mps[1] > 0.0); // Forward is Y axis (heading=0)
    }

    #[test]
    fn yaw_changes_heading() {
        let state = EntityKinematics::default();
        let input = InputSnapshot {
            yaw_left: true,
            ..Default::default()
        };
        let tuning = ControlTuning::default();

        let next = step_entity_kinematics(&state, input, &tuning, 1.0);

        // Should have turned left (positive heading)
        assert!(next.heading_rad > 0.0);
        assert!((next.heading_rad - tuning.yaw_rate_rad_per_s).abs() < 0.01);
    }

    #[test]
    fn deterministic_replay_produces_same_result() {
        let state = EntityKinematics::default();
        let input = InputSnapshot {
            thrust_forward: true,
            yaw_left: true,
            ..Default::default()
        };
        let tuning = ControlTuning::default();

        let result1 = step_entity_kinematics(&state, input, &tuning, 0.016);
        let result2 = step_entity_kinematics(&state, input, &tuning, 0.016);

        assert_eq!(result1, result2);
    }

    #[test]
    fn control_tuning_presets_are_distinct() {
        let corvette = ControlTuning::corvette();
        let asteroid = ControlTuning::asteroid_with_engine();
        let missile = ControlTuning::missile();

        // Missile should be fastest
        assert!(missile.thrust_accel_mps2 > corvette.thrust_accel_mps2);
        assert!(missile.thrust_accel_mps2 > asteroid.thrust_accel_mps2);

        // Asteroid should be slowest to turn
        assert!(asteroid.yaw_rate_rad_per_s < corvette.yaw_rate_rad_per_s);
        assert!(asteroid.yaw_rate_rad_per_s < missile.yaw_rate_rad_per_s);
    }
}
