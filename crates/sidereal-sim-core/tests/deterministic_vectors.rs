use sidereal_sim_core::{InputSnapshot, integrate_forward_velocity_mps};

fn assert_near(actual: f32, expected: f32, epsilon: f32) {
    let diff = (actual - expected).abs();
    assert!(
        diff <= epsilon,
        "actual={actual} expected={expected} diff={diff} epsilon={epsilon}"
    );
}

#[test]
fn golden_vector_forward_thrust_one_tick() {
    let input = InputSnapshot {
        thrust_forward: true,
        ..Default::default()
    };

    let v = integrate_forward_velocity_mps(0.0, input, 1.0 / 30.0, 18.0, 0.25);
    assert_near(v, 0.595, 1e-6);
}

#[test]
fn golden_vector_reverse_thrust_one_tick() {
    let input = InputSnapshot {
        thrust_reverse: true,
        ..Default::default()
    };

    let v = integrate_forward_velocity_mps(0.0, input, 1.0 / 30.0, 18.0, 0.25);
    assert_near(v, -0.595, 1e-6);
}

#[test]
fn deterministic_over_sequence_matches_expected() {
    let dt = 1.0 / 30.0;
    let thrust = 18.0;
    let drag = 0.25;

    let mut v = 0.0;
    for _ in 0..4 {
        v = integrate_forward_velocity_mps(
            v,
            InputSnapshot {
                thrust_forward: true,
                ..Default::default()
            },
            dt,
            thrust,
            drag,
        );
    }
    for _ in 0..2 {
        v = integrate_forward_velocity_mps(v, InputSnapshot::default(), dt, thrust, drag);
    }

    assert_near(v, 2.311405, 1e-5);
}
