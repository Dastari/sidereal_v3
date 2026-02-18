#[derive(Debug, Clone, Copy, Default)]
pub struct InputSnapshot {
    pub thrust_forward: bool,
    pub thrust_reverse: bool,
    pub yaw_left: bool,
    pub yaw_right: bool,
}

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
