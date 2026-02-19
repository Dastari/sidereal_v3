#[cfg(not(target_arch = "wasm32"))]
mod auth_ui;

#[cfg(not(target_arch = "wasm32"))]
mod prediction;

use avian3d::prelude::*;
use bevy::prelude::*;
use bevy::render::RenderPlugin;
use bevy::render::settings::{Backends, RenderCreation, WgpuSettings};
#[cfg(not(target_arch = "wasm32"))]
use bevy::state::state_scoped::DespawnOnExit;

#[cfg(not(target_arch = "wasm32"))]
use bevy_remote::RemotePlugin;
#[cfg(not(target_arch = "wasm32"))]
use bevy_remote::http::RemoteHttpPlugin;
#[cfg(not(target_arch = "wasm32"))]
use lightyear::prelude::client::ClientPlugins;
#[cfg(not(target_arch = "wasm32"))]
use lightyear::prelude::client::{Client, Connect, Connected, RawClient};
#[cfg(not(target_arch = "wasm32"))]
use lightyear::prelude::{
    ChannelRegistry, LocalAddr, MessageManager, MessageReceiver, MessageSender, PeerAddr,
    Transport, UdpIo,
};
#[cfg(not(target_arch = "wasm32"))]
use sidereal_core::remote_inspect::RemoteInspectConfig;
#[cfg(not(target_arch = "wasm32"))]
use sidereal_net::{
    ClientInputMessage, InputChannel, ReplicationStateMessage, StateChannel,
    register_lightyear_protocol,
};
#[cfg(not(target_arch = "wasm32"))]
use std::net::SocketAddr;

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Resource, Clone)]
#[allow(dead_code)]
struct BrpAuthToken(String);

#[cfg(not(target_arch = "wasm32"))]
#[derive(States, Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
enum ClientAppState {
    #[default]
    Auth,
    InWorld,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AuthAction {
    Login,
    Register,
    ForgotRequest,
    ForgotConfirm,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum FocusField {
    Email,
    Password,
    ResetToken,
    NewPassword,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Resource)]
struct ClientSession {
    gateway_url: String,
    selected_action: AuthAction,
    focus: FocusField,
    email: String,
    password: String,
    reset_token: String,
    new_password: String,
    access_token: Option<String>,
    refresh_token: Option<String>,
    status: String,
    world_snapshot: Option<WorldMeResponse>,
    ui_dirty: bool,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Resource, Default)]
struct ClientNetworkTick(u64);

#[cfg(not(target_arch = "wasm32"))]
impl Default for ClientSession {
    fn default() -> Self {
        Self {
            gateway_url: std::env::var("GATEWAY_URL")
                .unwrap_or_else(|_| "http://127.0.0.1:8080".to_string()),
            selected_action: AuthAction::Login,
            focus: FocusField::Email,
            email: "pilot@example.com".to_string(),
            password: "very-strong-password".to_string(),
            reset_token: String::new(),
            new_password: "new-very-strong-password".to_string(),
            access_token: None,
            refresh_token: None,
            status: "Ready. F1 Login, F2 Register, F3 Forgot Request, F4 Forgot Confirm."
                .to_string(),
            world_snapshot: None,
            ui_dirty: true,
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct RegisterRequest {
    email: String,
    password: String,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct LoginRequest {
    email: String,
    password: String,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct ForgotRequest {
    email: String,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct ForgotConfirmRequest {
    reset_token: String,
    new_password: String,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct AuthTokens {
    access_token: String,
    refresh_token: String,
    token_type: String,
    expires_in_s: u64,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct ForgotResponse {
    accepted: bool,
    reset_token: Option<String>,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct ForgotConfirmResponse {
    accepted: bool,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct StreamAssetDescriptor {
    asset_id: String,
    relative_cache_path: String,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct WorldMeResponse {
    player_entity_id: String,
    ship_entity_id: String,
    ship_name: String,
    position_m: [f32; 3],
    velocity_mps: [f32; 3],
    heading_rad: f32,
    health: f32,
    max_health: f32,
    model_asset_id: String,
    starfield_shader_asset_id: String,
    assets: Vec<StreamAssetDescriptor>,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Component)]
struct WorldEntity;
#[cfg(not(target_arch = "wasm32"))]
#[derive(Component)]
struct HudText;

#[cfg(not(target_arch = "wasm32"))]
#[derive(Component)]
struct ControlledShip {
    velocity_mps: Vec3,
    heading_rad: f32,
    health: f32,
    max_health: f32,
}

#[cfg(not(target_arch = "wasm32"))]
#[derive(Component)]
struct StarfieldDrift;

#[cfg(not(target_arch = "wasm32"))]
fn main() {
    let headless_transport = std::env::var("SIDEREAL_CLIENT_HEADLESS")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);
    let remote_cfg = match RemoteInspectConfig::from_env("CLIENT", 15714) {
        Ok(cfg) => cfg,
        Err(err) => {
            eprintln!("invalid CLIENT BRP config: {err}");
            std::process::exit(2);
        }
    };

    let mut app = App::new();
    if headless_transport {
        app.add_plugins(MinimalPlugins);
        app.add_plugins(bevy::log::LogPlugin::default());
    } else {
        app.add_plugins(
            DefaultPlugins
                .set(bevy::asset::AssetPlugin {
                    file_path: ".".to_string(),
                    ..Default::default()
                })
                .set(RenderPlugin {
                    render_creation: RenderCreation::Automatic(WgpuSettings {
                        backends: Some(preferred_backends()),
                        ..Default::default()
                    }),
                    ..Default::default()
                }),
        );
    }

    // Add Avian physics for client prediction (matches shard setup)
    app.add_plugins(PhysicsPlugins::default().with_length_unit(1.0));
    app.insert_resource(Gravity(Vec3::ZERO)); // No gravity in space
    app.add_plugins(ClientPlugins::default());
    register_lightyear_protocol(&mut app);
    configure_remote(&mut app, &remote_cfg);
    app.insert_resource(ClientSession::default());
    app.insert_resource(ClientNetworkTick::default());
    app.add_observer(log_native_client_connected);
    app.add_systems(Startup, start_lightyear_client_transport);
    if headless_transport {
        app.add_systems(
            Update,
            (
                ensure_client_transport_channels,
                send_lightyear_input_messages,
                receive_lightyear_replication_messages,
            ),
        );
        app.add_systems(Startup, || {
            println!("sidereal-client headless transport mode");
        });
    } else {
        app.init_state::<ClientAppState>();
        auth_ui::register_auth_ui(&mut app);
        app.add_systems(OnEnter(ClientAppState::InWorld), spawn_world_scene);
        app.add_systems(
            Update,
            (
                ensure_client_transport_channels,
                send_lightyear_input_messages,
                receive_lightyear_replication_messages,
            ),
        );
        app.add_systems(
            Update,
            (
                ship_control_system,
                update_hud_system,
                logout_to_auth_system,
                animate_starfield_system,
            )
                .run_if(in_state(ClientAppState::InWorld)),
        );
    }
    app.run();
}

#[cfg(target_arch = "wasm32")]
fn main() {
    let mut app = App::new();
    app.add_plugins(DefaultPlugins.set(RenderPlugin {
        render_creation: RenderCreation::Automatic(WgpuSettings {
            backends: Some(preferred_backends()),
            ..Default::default()
        }),
        ..Default::default()
    }));
    app.add_systems(Startup, || {
        info!("sidereal-client wasm scaffold booted (WebGPU-capable)");
    });
    app.run();
}

#[cfg(not(target_arch = "wasm32"))]
fn configure_remote(app: &mut App, cfg: &RemoteInspectConfig) {
    if !cfg.enabled {
        return;
    }

    app.add_plugins(RemotePlugin::default());
    app.add_plugins(
        RemoteHttpPlugin::default()
            .with_address(cfg.bind_addr)
            .with_port(cfg.port),
    );
    app.insert_resource(BrpAuthToken(
        cfg.auth_token.clone().expect("validated token"),
    ));
}

#[cfg(not(target_arch = "wasm32"))]
fn start_lightyear_client_transport(mut commands: Commands<'_, '_>) {
    let local_addr = std::env::var("CLIENT_UDP_BIND")
        .unwrap_or_else(|_| "127.0.0.1:7003".to_string())
        .parse::<SocketAddr>();
    let local_addr = match local_addr {
        Ok(v) => v,
        Err(err) => {
            eprintln!("invalid CLIENT_UDP_BIND: {err}");
            return;
        }
    };
    let remote_addr = std::env::var("REPLICATION_UDP_ADDR")
        .unwrap_or_else(|_| "127.0.0.1:7001".to_string())
        .parse::<SocketAddr>();
    let remote_addr = match remote_addr {
        Ok(v) => v,
        Err(err) => {
            eprintln!("invalid REPLICATION_UDP_ADDR: {err}");
            return;
        }
    };

    let client = commands
        .spawn((
            Name::new("native-client-lightyear"),
            RawClient,
            UdpIo::default(),
            MessageManager::default(),
            LocalAddr(local_addr),
            PeerAddr(remote_addr),
        ))
        .id();
    commands.trigger(Connect { entity: client });
    println!("native client lightyear UDP connecting {local_addr} -> {remote_addr}");
}

#[cfg(not(target_arch = "wasm32"))]
fn submit_auth_request(session: &mut ClientSession, next_state: &mut NextState<ClientAppState>) {
    let client = reqwest::blocking::Client::new();
    let gateway_url = session.gateway_url.clone();
    let result = match session.selected_action {
        AuthAction::Login => client
            .post(format!("{gateway_url}/auth/login"))
            .json(&LoginRequest {
                email: session.email.clone(),
                password: session.password.clone(),
            })
            .send()
            .and_then(reqwest::blocking::Response::error_for_status)
            .and_then(reqwest::blocking::Response::json::<AuthTokens>)
            .map(|tokens| {
                session.status = "Login succeeded. Fetching world snapshot...".to_string();
                (Some(tokens), None::<String>)
            })
            .map_err(|err| err.to_string()),
        AuthAction::Register => client
            .post(format!("{gateway_url}/auth/register"))
            .json(&RegisterRequest {
                email: session.email.clone(),
                password: session.password.clone(),
            })
            .send()
            .and_then(reqwest::blocking::Response::error_for_status)
            .and_then(reqwest::blocking::Response::json::<AuthTokens>)
            .map(|tokens| {
                session.status = "Registration succeeded. Fetching world snapshot...".to_string();
                (Some(tokens), None::<String>)
            })
            .map_err(|err| err.to_string()),
        AuthAction::ForgotRequest => client
            .post(format!("{gateway_url}/auth/password-reset/request"))
            .json(&ForgotRequest {
                email: session.email.clone(),
            })
            .send()
            .and_then(reqwest::blocking::Response::error_for_status)
            .and_then(reqwest::blocking::Response::json::<ForgotResponse>)
            .map(|resp| {
                if let Some(token) = resp.reset_token {
                    session.reset_token = token;
                }
                session.status =
                    "Password reset token requested. Use F4 to confirm reset.".to_string();
                (None, None::<String>)
            })
            .map_err(|err| err.to_string()),
        AuthAction::ForgotConfirm => client
            .post(format!("{gateway_url}/auth/password-reset/confirm"))
            .json(&ForgotConfirmRequest {
                reset_token: session.reset_token.clone(),
                new_password: session.new_password.clone(),
            })
            .send()
            .and_then(reqwest::blocking::Response::error_for_status)
            .and_then(reqwest::blocking::Response::json::<ForgotConfirmResponse>)
            .map(|_| {
                session.status = "Password reset confirmed. Switch to Login (F1).".to_string();
                (None, None::<String>)
            })
            .map_err(|err| err.to_string()),
    };

    match result {
        Ok((Some(tokens), _)) => {
            session.access_token = Some(tokens.access_token.clone());
            session.refresh_token = Some(tokens.refresh_token);
            match fetch_world_and_stream_assets(&client, &gateway_url, &tokens.access_token) {
                Ok(world) => {
                    session.world_snapshot = Some(world);
                    session.status = "World loaded. WASD thrust/turn, ESC logout.".to_string();
                    next_state.set(ClientAppState::InWorld);
                }
                Err(err) => {
                    session.status = format!("Auth OK but world load failed: {err}");
                }
            }
        }
        Ok((None, _)) => {}
        Err(err) => {
            session.status = format!("Request failed: {err}");
        }
    }
    session.ui_dirty = true;
}

#[cfg(not(target_arch = "wasm32"))]
fn fetch_world_and_stream_assets(
    client: &reqwest::blocking::Client,
    gateway_url: &str,
    access_token: &str,
) -> Result<WorldMeResponse, String> {
    let world = client
        .get(format!("{gateway_url}/world/me"))
        .bearer_auth(access_token)
        .send()
        .map_err(|err| err.to_string())?
        .error_for_status()
        .map_err(|err| err.to_string())?
        .json::<WorldMeResponse>()
        .map_err(|err| err.to_string())?;

    for asset in &world.assets {
        let bytes = client
            .get(format!("{gateway_url}/assets/stream/{}", asset.asset_id))
            .bearer_auth(access_token)
            .send()
            .map_err(|err| err.to_string())?
            .error_for_status()
            .map_err(|err| err.to_string())?
            .bytes()
            .map_err(|err| err.to_string())?;

        let target = std::path::PathBuf::from("data/cache_stream").join(&asset.relative_cache_path);
        if let Some(parent) = target.parent() {
            std::fs::create_dir_all(parent).map_err(|err| err.to_string())?;
        }
        std::fs::write(&target, &bytes).map_err(|err| err.to_string())?;
    }

    Ok(world)
}

#[cfg(not(target_arch = "wasm32"))]
fn spawn_world_scene(
    mut commands: Commands<'_, '_>,
    asset_server: Res<'_, AssetServer>,
    mut meshes: ResMut<'_, Assets<Mesh>>,
    mut materials: ResMut<'_, Assets<StandardMaterial>>,
    mut session: ResMut<'_, ClientSession>,
) {
    let Some(world) = session.world_snapshot.clone() else {
        session.status = "No world snapshot available for scene spawn.".to_string();
        return;
    };

    commands.spawn((
        Camera3d::default(),
        Transform::from_xyz(0.0, 45.0, 0.1).looking_at(Vec3::ZERO, Vec3::Z),
        WorldEntity,
        DespawnOnExit(ClientAppState::InWorld),
    ));
    commands.spawn((
        DirectionalLight {
            illuminance: 20_000.0,
            ..default()
        },
        Transform::from_xyz(0.0, 30.0, 0.0).looking_at(Vec3::ZERO, Vec3::Z),
        WorldEntity,
        DespawnOnExit(ClientAppState::InWorld),
    ));

    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            left: px(12),
            top: px(12),
            ..default()
        },
        Text::new(""),
        TextFont {
            font_size: 18.0,
            ..default()
        },
        TextColor(Color::srgb(0.8, 0.95, 0.9)),
        HudText,
        WorldEntity,
        DespawnOnExit(ClientAppState::InWorld),
    ));

    let mut rng = rand::rng();
    for _ in 0..300 {
        let x = rand::Rng::random_range(&mut rng, -800.0..800.0);
        let y = rand::Rng::random_range(&mut rng, -800.0..800.0);
        let z = rand::Rng::random_range(&mut rng, 90.0..300.0);
        commands.spawn((
            Mesh3d(meshes.add(Sphere::new(0.35).mesh().uv(12, 8))),
            MeshMaterial3d(materials.add(StandardMaterial {
                emissive: LinearRgba::rgb(0.7, 0.8, 1.0),
                unlit: true,
                ..default()
            })),
            Transform::from_xyz(x, y, z),
            StarfieldDrift,
            WorldEntity,
            DespawnOnExit(ClientAppState::InWorld),
        ));
    }

    let ship_position = Vec3::new(
        world.position_m[0],
        world.position_m[1],
        world.position_m[2],
    );
    let ship_velocity = Vec3::new(
        world.velocity_mps[0],
        world.velocity_mps[1],
        world.velocity_mps[2],
    );

    let ship = commands
        .spawn((
            Name::new(world.ship_name.clone()),
            Transform::from_translation(ship_position),
            ControlledShip {
                velocity_mps: ship_velocity,
                heading_rad: world.heading_rad,
                health: world.health,
                max_health: world.max_health,
            },
            WorldEntity,
            DespawnOnExit(ClientAppState::InWorld),
        ))
        .id();

    let streamed_scene_path = "data/cache_stream/models/corvette_01/corvette_01.gltf";
    let scene_handle =
        asset_server.load(bevy::gltf::GltfAssetLabel::Scene(0).from_asset(streamed_scene_path));
    commands.entity(ship).with_children(|child| {
        child.spawn((
            SceneRoot(scene_handle.clone()),
            Transform::from_scale(Vec3::splat(2.5)),
        ));
        child.spawn((
            Mesh3d(meshes.add(Capsule3d::new(0.8, 2.0))),
            MeshMaterial3d(materials.add(StandardMaterial {
                base_color: Color::srgb(0.3, 0.6, 0.95),
                emissive: LinearRgba::rgb(0.03, 0.05, 0.08),
                ..default()
            })),
            Transform::from_xyz(0.0, 0.0, 0.0),
        ));
    });
}

#[cfg(not(target_arch = "wasm32"))]
fn ship_control_system(
    input: Res<'_, ButtonInput<KeyCode>>,
    time: Res<'_, Time>,
    mut query: Query<'_, '_, (&mut Transform, &mut ControlledShip)>,
) {
    let Ok((mut transform, mut ship)) = query.single_mut() else {
        return;
    };

    let thrust = if input.pressed(KeyCode::KeyW) {
        1.0
    } else if input.pressed(KeyCode::KeyS) {
        -0.7
    } else {
        0.0
    };
    let turn = if input.pressed(KeyCode::KeyA) {
        1.0
    } else if input.pressed(KeyCode::KeyD) {
        -1.0
    } else {
        0.0
    };

    let dt = time.delta_secs();
    ship.heading_rad += turn * 1.8 * dt;
    let forward = Vec3::new(ship.heading_rad.sin(), ship.heading_rad.cos(), 0.0);
    ship.velocity_mps += forward * (thrust * 14.0 * dt);
    ship.velocity_mps *= 1.0 - 0.4 * dt;

    transform.translation += ship.velocity_mps * dt;
    transform.rotation = Quat::from_rotation_z(-ship.heading_rad);
}

#[cfg(not(target_arch = "wasm32"))]
fn send_lightyear_input_messages(
    input: Option<Res<'_, ButtonInput<KeyCode>>>,
    app_state: Option<Res<'_, State<ClientAppState>>>,
    session: Res<'_, ClientSession>,
    mut tick: ResMut<'_, ClientNetworkTick>,
    mut senders: Query<
        '_,
        '_,
        &mut MessageSender<ClientInputMessage>,
        (With<Client>, With<Connected>),
    >,
) {
    tick.0 = tick.0.saturating_add(1);
    if senders.is_empty() {
        if tick.0.is_multiple_of(120) {
            println!("native client waiting for connected Lightyear transport");
        }
        return;
    }

    let in_world_state = app_state
        .as_ref()
        .is_some_and(|state| **state == ClientAppState::InWorld);

    let (player_entity_id, thrust, turn) = if in_world_state {
        let Some(world) = &session.world_snapshot else {
            return;
        };
        let thrust = if input
            .as_ref()
            .is_some_and(|keys| keys.pressed(KeyCode::KeyW))
        {
            1.0
        } else if input
            .as_ref()
            .is_some_and(|keys| keys.pressed(KeyCode::KeyS))
        {
            -0.7
        } else {
            0.0
        };
        let turn = if input
            .as_ref()
            .is_some_and(|keys| keys.pressed(KeyCode::KeyA))
        {
            1.0
        } else if input
            .as_ref()
            .is_some_and(|keys| keys.pressed(KeyCode::KeyD))
        {
            -1.0
        } else {
            0.0
        };
        (world.player_entity_id.clone(), thrust, turn)
    } else {
        if !tick.0.is_multiple_of(30) {
            return;
        }
        ("transport:probe".to_string(), 0.0, 0.0)
    };

    let message = ClientInputMessage::from_axis_inputs(player_entity_id, tick.0, thrust, turn);
    for mut sender in &mut senders {
        sender.send::<InputChannel>(message.clone());
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn log_native_client_connected(
    trigger: On<Add, Connected>,
    clients: Query<'_, '_, (), With<Client>>,
) {
    if clients.get(trigger.entity).is_ok() {
        println!("native client lightyear transport connected");
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn receive_lightyear_replication_messages(
    mut receivers: Query<
        '_,
        '_,
        &mut MessageReceiver<ReplicationStateMessage>,
        (With<Client>, With<Connected>),
    >,
    mut session: ResMut<'_, ClientSession>,
) {
    for mut receiver in &mut receivers {
        for message in receiver.receive() {
            let updates = message
                .decode_world()
                .map(|world| world.updates.len())
                .unwrap_or_else(|err| {
                    eprintln!(
                        "native client failed decoding replication state tick={} from Lightyear: {err}",
                        message.tick
                    );
                    0
                });
            session.status = format!(
                "Replication stream active. tick={} updates={}",
                message.tick, updates
            );
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn ensure_client_transport_channels(
    mut transports: Query<'_, '_, &mut Transport, With<Client>>,
    registry: Res<'_, ChannelRegistry>,
) {
    for mut transport in &mut transports {
        if !transport.has_sender::<InputChannel>() {
            transport.add_sender_from_registry::<InputChannel>(&registry);
        }
        if !transport.has_receiver::<StateChannel>() {
            transport.add_receiver_from_registry::<StateChannel>(&registry);
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn update_hud_system(
    ship_query: Query<'_, '_, (&Transform, &ControlledShip)>,
    mut hud_query: Query<'_, '_, &mut Text, With<HudText>>,
) {
    let Ok((transform, ship)) = ship_query.single() else {
        return;
    };
    let Ok(mut text) = hud_query.single_mut() else {
        return;
    };

    let pos = transform.translation;
    let vel = ship.velocity_mps;
    let content = format!(
        "SIDEREAL FLIGHT\nCoords: [{:.2}, {:.2}, {:.2}]\nVelocity m/s: [{:.2}, {:.2}, {:.2}] | speed {:.2}\nHeading(rad): {:.2}\nHealth: {:.1}/{:.1}\nControls: W/S thrust, A/D turn, ESC logout",
        pos.x,
        pos.y,
        pos.z,
        vel.x,
        vel.y,
        vel.z,
        vel.length(),
        ship.heading_rad,
        ship.health,
        ship.max_health
    );
    content.clone_into(&mut **text);
}

#[cfg(not(target_arch = "wasm32"))]
fn logout_to_auth_system(
    input: Res<'_, ButtonInput<KeyCode>>,
    mut next_state: ResMut<'_, NextState<ClientAppState>>,
    mut session: ResMut<'_, ClientSession>,
) {
    if !input.just_pressed(KeyCode::Escape) {
        return;
    }
    next_state.set(ClientAppState::Auth);
    session.world_snapshot = None;
    session.access_token = None;
    session.refresh_token = None;
    session.status = "Logged out. Back on auth screen.".to_string();
    session.ui_dirty = true;
}

#[cfg(not(target_arch = "wasm32"))]
fn animate_starfield_system(
    time: Res<'_, Time>,
    mut stars: Query<'_, '_, &mut Transform, With<StarfieldDrift>>,
) {
    let dt = time.delta_secs();
    for mut transform in &mut stars {
        transform.translation.z -= 8.0 * dt;
        if transform.translation.z < 40.0 {
            transform.translation.z += 260.0;
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn active_field_mut(session: &mut ClientSession) -> &mut String {
    match session.focus {
        FocusField::Email => &mut session.email,
        FocusField::Password => &mut session.password,
        FocusField::ResetToken => &mut session.reset_token,
        FocusField::NewPassword => &mut session.new_password,
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn mask(value: &str) -> String {
    if value.is_empty() {
        return "".to_string();
    }
    "*".repeat(value.chars().count())
}

#[cfg(not(target_arch = "wasm32"))]
fn is_printable_char(chr: char) -> bool {
    let is_in_private_use_area = ('\u{e000}'..='\u{f8ff}').contains(&chr)
        || ('\u{f0000}'..='\u{ffffd}').contains(&chr)
        || ('\u{100000}'..='\u{10fffd}').contains(&chr);
    !is_in_private_use_area && !chr.is_ascii_control()
}

#[cfg(target_arch = "wasm32")]
fn preferred_backends() -> Backends {
    Backends::BROWSER_WEBGPU | Backends::GL
}

#[cfg(not(target_arch = "wasm32"))]
fn preferred_backends() -> Backends {
    Backends::VULKAN | Backends::GL
}

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::*;
    use std::net::{IpAddr, Ipv4Addr};

    #[test]
    fn remote_endpoint_registers_when_enabled() {
        let cfg = RemoteInspectConfig {
            enabled: true,
            bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
            port: 15714,
            auth_token: Some("0123456789abcdef".to_string()),
        };
        let mut app = App::new();
        app.add_plugins(MinimalPlugins);
        configure_remote(&mut app, &cfg);

        assert!(
            app.world()
                .contains_resource::<bevy_remote::http::HostPort>()
        );
        assert!(app.world().contains_resource::<BrpAuthToken>());
    }
}
