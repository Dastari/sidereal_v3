use sidereal_sim_core::InputSnapshot;

#[derive(Debug, Clone, Copy, Default)]
pub struct RawInputState {
    pub up: bool,
    pub down: bool,
    pub left: bool,
    pub right: bool,
}

pub fn map_raw_input(raw: RawInputState) -> InputSnapshot {
    InputSnapshot {
        thrust_forward: raw.up,
        thrust_reverse: raw.down,
        yaw_left: raw.left,
        yaw_right: raw.right,
    }
}
