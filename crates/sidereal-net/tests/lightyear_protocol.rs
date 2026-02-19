#![cfg(feature = "lightyear_protocol")]

use bevy::prelude::App;
use lightyear::prelude::AppMessageExt;
use lightyear::prelude::server::ServerPlugins;
use sidereal_net::{ClientInputMessage, ReplicationStateMessage, register_lightyear_protocol};

#[test]
fn lightyear_protocol_registration_registers_messages() {
    let mut app = App::new();
    app.add_plugins(ServerPlugins::default());
    register_lightyear_protocol(&mut app);

    assert!(app.is_message_registered::<ClientInputMessage>());
    assert!(app.is_message_registered::<ReplicationStateMessage>());
}
