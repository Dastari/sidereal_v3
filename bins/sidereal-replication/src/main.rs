mod visibility;

use avian3d::prelude::*;
use bevy::asset::{AssetApp, AssetPlugin};
use bevy::log::LogPlugin;
use bevy::prelude::*;
use bevy::scene::ScenePlugin;
use bevy_remote::RemotePlugin;
use bevy_remote::http::RemoteHttpPlugin;
use lightyear::prelude::client::Connected;
use lightyear::prelude::server::ServerPlugins;
use lightyear::prelude::server::{ClientOf, RawServer, Start};
use lightyear::prelude::server::{ServerUdpIo, Stopped};
use lightyear::prelude::{
    ChannelRegistry, LocalAddr, MessageReceiver, RemoteId, Server, ServerMultiMessageSender,
    Transport,
};
use sidereal_core::remote_inspect::RemoteInspectConfig;
use sidereal_game::{
    ActionCapabilities, ActionQueue, Engine, EntityAction, EntityGuid, FlightComputer, FuelTank,
    HealthPool, MountedOn, OwnerId, PositionM, SiderealGamePlugin, VelocityMps,
};
use sidereal_net::{
    ClientInputMessage, InputChannel, ReplicationStateMessage, StateChannel, WorldComponentDelta,
    WorldDeltaEntity, WorldStateDelta, register_lightyear_protocol,
};
use sidereal_persistence::GraphPersistence;
use sidereal_replication::bootstrap::{BootstrapProcessor, PostgresBootstrapStore};
use sidereal_replication::state::{
    flush_pending_updates, hydrate_known_entity_ids, ingest_world_delta,
};
use std::collections::{HashMap, HashSet};
use std::net::SocketAddr;
use std::net::UdpSocket;

use std::thread;
use std::time::{Duration, Instant};
use visibility::{
    ClientVisibilityRegistry, apply_visibility_filter, delivery_target_for_session,
    visibility_context_for_client,
};

#[derive(Debug, Resource, Clone)]
#[allow(dead_code)]
struct BrpAuthToken(String);

#[derive(Debug, Resource, Clone, Copy)]
#[allow(dead_code)]
struct HydratedEntityCount(usize);

#[derive(Debug, Component)]
#[allow(dead_code)]
struct HydratedGraphEntity {
    entity_id: String,
    labels: Vec<String>,
    component_count: usize,
}

#[derive(Resource, Default)]
struct ReplicationOutboundQueue {
    messages: Vec<QueuedReplicationDelta>,
}

#[derive(Debug, Clone)]
struct QueuedReplicationDelta {
    tick: u64,
    world: WorldStateDelta,
}

struct ReplicationRuntime {
    persistence: sidereal_persistence::GraphPersistence,
    known_entities: HashSet<String>,
    pending_updates: HashMap<String, WorldDeltaEntity>,
    last_tick: u64,
    persist_interval: Duration,
    snapshot_interval: Duration,
    last_persist_at: Instant,
    last_snapshot_at: Instant,
}

#[derive(Resource, Default)]
struct PlayerShipMap {
    by_player_entity_id: HashMap<String, Entity>,
}

#[derive(Debug, Component)]
struct SimulatedShip {
    entity_id: String,
    player_entity_id: String,
}

type ConnectedClientFilter = (With<ClientOf>, With<Connected>);

fn main() {
    let remote_cfg = match RemoteInspectConfig::from_env("REPLICATION", 15713) {
        Ok(cfg) => cfg,
        Err(err) => {
            eprintln!("invalid REPLICATION BRP config: {err}");
            std::process::exit(2);
        }
    };

    let mut app = App::new();
    app.add_plugins(MinimalPlugins);
    app.add_plugins(AssetPlugin::default());
    app.add_plugins(ScenePlugin);
    app.add_plugins(LogPlugin::default());
    app.add_plugins(SiderealGamePlugin);
    app.add_plugins(PhysicsPlugins::default().with_length_unit(1.0));
    app.add_message::<bevy::asset::AssetEvent<Mesh>>();
    app.init_asset::<Mesh>();
    app.insert_resource(Gravity(Vec3::ZERO));
    app.insert_resource(Time::<Fixed>::from_hz(30.0));
    app.add_plugins(ServerPlugins::default());
    register_lightyear_protocol(&mut app);
    configure_remote(&mut app, &remote_cfg);
    app.add_systems(
        Startup,
        (
            init_replication_runtime,
            hydrate_replication_world,
            hydrate_simulation_ships,
            start_lightyear_server,
        )
            .chain(),
    );
    app.add_systems(Startup, start_replication_control_listener);
    app.add_observer(log_replication_client_connected);
    app.insert_resource(ReplicationOutboundQueue::default());
    app.insert_resource(ClientVisibilityRegistry::default());
    app.insert_resource(PlayerShipMap::default());
    app.add_systems(
        Update,
        (
            ensure_server_transport_channels,
            receive_client_inputs,
            sync_simulated_ship_components,
            collect_local_simulation_state,
            flush_replication_persistence,
            broadcast_replication_state,
        ),
    );
    app.add_systems(Startup, || {
        println!("sidereal-replication scaffold");
    });
    app.run();
}

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

fn hydrate_replication_world(mut commands: Commands<'_, '_>) {
    let database_url = std::env::var("REPLICATION_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://sidereal:sidereal@127.0.0.1:5432/sidereal".to_string());

    let mut persistence = match GraphPersistence::connect(&database_url) {
        Ok(v) => v,
        Err(err) => {
            eprintln!("replication hydration skipped; connect failed: {err}");
            return;
        }
    };
    if let Err(err) = persistence.ensure_schema() {
        eprintln!("replication hydration skipped; schema ensure failed: {err}");
        return;
    }

    let records = match persistence.load_graph_records() {
        Ok(v) => v,
        Err(err) => {
            eprintln!("replication hydration skipped; graph load failed: {err}");
            return;
        }
    };

    for record in &records {
        commands.spawn(HydratedGraphEntity {
            entity_id: record.entity_id.clone(),
            labels: record.labels.clone(),
            component_count: record.components.len(),
        });
    }
    commands.insert_resource(HydratedEntityCount(records.len()));
    println!(
        "replication hydrated {} graph entities into Bevy world",
        records.len()
    );
}

fn hydrate_simulation_ships(
    mut commands: Commands<'_, '_>,
    mut ship_map: ResMut<'_, PlayerShipMap>,
) {
    let database_url = std::env::var("REPLICATION_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://sidereal:sidereal@127.0.0.1:5432/sidereal".to_string());

    let mut persistence = match GraphPersistence::connect(&database_url) {
        Ok(v) => v,
        Err(err) => {
            eprintln!("replication simulation hydration skipped; connect failed: {err}");
            return;
        }
    };
    if let Err(err) = persistence.ensure_schema() {
        eprintln!("replication simulation hydration skipped; schema ensure failed: {err}");
        return;
    }
    let records = match persistence.load_graph_records() {
        Ok(v) => v,
        Err(err) => {
            eprintln!("replication simulation hydration skipped; graph load failed: {err}");
            return;
        }
    };

    let mut hydrated = 0usize;
    for record in records {
        if !record.labels.iter().any(|label| label == "Ship") {
            continue;
        }
        let Some(player_entity_id) = record
            .properties
            .get("player_entity_id")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
        else {
            continue;
        };

        let position = record
            .properties
            .get("position_m")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let velocity = record
            .properties
            .get("velocity_mps")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let pos = if position.len() == 3 {
            Vec3::new(
                position[0].as_f64().unwrap_or_default() as f32,
                position[1].as_f64().unwrap_or_default() as f32,
                position[2].as_f64().unwrap_or_default() as f32,
            )
        } else {
            Vec3::ZERO
        };
        let vel = if velocity.len() == 3 {
            Vec3::new(
                velocity[0].as_f64().unwrap_or_default() as f32,
                velocity[1].as_f64().unwrap_or_default() as f32,
                velocity[2].as_f64().unwrap_or_default() as f32,
            )
        } else {
            Vec3::ZERO
        };

        let ship_guid =
            parse_guid_from_entity_id(&record.entity_id).unwrap_or_else(uuid::Uuid::new_v4);
        let health = record
            .properties
            .get("health")
            .and_then(|v| v.as_f64())
            .unwrap_or(100.0) as f32;
        let max_health = record
            .properties
            .get("max_health")
            .and_then(|v| v.as_f64())
            .unwrap_or(100.0) as f32;

        let entity = commands
            .spawn((
                Name::new(record.entity_id.clone()),
                SimulatedShip {
                    entity_id: record.entity_id.clone(),
                    player_entity_id: player_entity_id.clone(),
                },
                EntityGuid(ship_guid),
                OwnerId(player_entity_id.clone()),
                ActionQueue::default(),
                ActionCapabilities {
                    supported: vec![
                        EntityAction::ThrustForward,
                        EntityAction::ThrustReverse,
                        EntityAction::ThrustNeutral,
                        EntityAction::YawLeft,
                        EntityAction::YawRight,
                        EntityAction::YawNeutral,
                    ],
                },
                FlightComputer {
                    profile: "basic_fly_by_wire".to_string(),
                    throttle: 0.0,
                    yaw_input: 0.0,
                    turn_rate_deg_s: 90.0,
                },
                HealthPool {
                    current: health,
                    maximum: max_health,
                },
                PositionM(pos),
                VelocityMps(vel),
                Transform::from_translation(pos),
            ))
            .insert((
                RigidBody::Dynamic,
                Collider::cuboid(6.0, 3.0, 2.0),
                Position(pos),
                Rotation::default(),
                LinearVelocity(vel),
                AngularVelocity::default(),
                LinearDamping(0.12),
                AngularDamping(0.35),
            ))
            .id();
        ship_map
            .by_player_entity_id
            .insert(player_entity_id.clone(), entity);

        let engine_guid = uuid::Uuid::new_v4();
        commands.spawn((
            Name::new(format!("{}:engine", record.entity_id)),
            EntityGuid(engine_guid),
            MountedOn {
                parent_entity_id: ship_guid,
                hardpoint_id: "engine_main".to_string(),
            },
            Engine {
                thrust_n: 140_000.0,
                burn_rate_kg_s: 0.4,
                thrust_dir: Vec3::Y,
            },
            FuelTank { fuel_kg: 1000.0 },
            OwnerId(player_entity_id),
        ));
        hydrated = hydrated.saturating_add(1);
    }

    println!("replication simulation hydrated {hydrated} ship entities");
}

fn parse_guid_from_entity_id(entity_id: &str) -> Option<uuid::Uuid> {
    entity_id
        .split(':')
        .nth(1)
        .and_then(|raw| uuid::Uuid::parse_str(raw).ok())
}

fn start_replication_control_listener() {
    let bind_addr = std::env::var("REPLICATION_CONTROL_UDP_BIND")
        .unwrap_or_else(|_| "127.0.0.1:9004".to_string());
    let database_url = std::env::var("REPLICATION_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://sidereal:sidereal@127.0.0.1:5432/sidereal".to_string());

    let socket = match UdpSocket::bind(&bind_addr) {
        Ok(socket) => socket,
        Err(err) => {
            eprintln!("failed to bind replication control UDP listener on {bind_addr}: {err}");
            return;
        }
    };
    let store = match PostgresBootstrapStore::connect(&database_url) {
        Ok(store) => store,
        Err(err) => {
            eprintln!("failed to connect replication bootstrap store: {err}");
            return;
        }
    };
    let mut processor = match BootstrapProcessor::new(store) {
        Ok(processor) => processor,
        Err(err) => {
            eprintln!("failed to initialize replication bootstrap processor: {err}");
            return;
        }
    };

    println!("replication control UDP listening on {bind_addr}");
    thread::spawn(move || {
        loop {
            let mut buf = vec![0_u8; 8192];
            let (size, from) = match socket.recv_from(&mut buf) {
                Ok(v) => v,
                Err(err) => {
                    eprintln!("replication control recv error: {err}");
                    continue;
                }
            };
            let payload = &buf[..size];
            match processor.handle_payload(payload) {
                Ok(result) => {
                    println!(
                        "replication bootstrap processed from {from}: account_id={}, player_entity_id={}, applied={}",
                        result.account_id, result.player_entity_id, result.applied
                    );
                    if result.applied
                        && let Err(err) = bootstrap_starter_ship(
                            &database_url,
                            result.account_id,
                            &result.player_entity_id,
                        )
                    {
                        eprintln!(
                            "replication bootstrap world-init failed for account {}: {err}",
                            result.account_id
                        );
                    }
                }
                Err(err) => {
                    eprintln!("replication control message rejected from {from}: {err}");
                }
            }
        }
    });
}

fn bootstrap_starter_ship(
    database_url: &str,
    account_id: uuid::Uuid,
    player_entity_id: &str,
) -> sidereal_persistence::Result<()> {
    let mut persistence = GraphPersistence::connect(database_url)?;
    persistence.ensure_schema()?;

    let ship_entity_id = format!("ship:{account_id}");
    let account_id_s = account_id.to_string();
    let starter_world = vec![
        WorldDeltaEntity {
            entity_id: player_entity_id.to_string(),
            labels: vec!["Entity".to_string(), "Player".to_string()],
            properties: serde_json::json!({
                "owner_account_id": account_id_s,
                "player_entity_id": player_entity_id,
            }),
            components: vec![WorldComponentDelta {
                component_id: format!("{player_entity_id}:display_name"),
                component_kind: "display_name".to_string(),
                properties: serde_json::json!({"value": "Pilot"}),
            }],
            removed: false,
        },
        WorldDeltaEntity {
            entity_id: ship_entity_id.clone(),
            labels: vec!["Entity".to_string(), "Ship".to_string()],
            properties: serde_json::json!({
                "owner_account_id": account_id.to_string(),
                "player_entity_id": player_entity_id,
                "name": "Corvette",
                "asset_id": "corvette_01",
                "starfield_shader_asset_id": "starfield_wgsl",
                "position_m": [0.0, 0.0, 0.0],
                "velocity_mps": [0.0, 0.0, 0.0],
                "heading_rad": 0.0,
                "health": 100.0,
                "max_health": 100.0
            }),
            components: vec![
                WorldComponentDelta {
                    component_id: format!("{ship_entity_id}:display_name"),
                    component_kind: "display_name".to_string(),
                    properties: serde_json::json!({"value": "Corvette"}),
                },
                WorldComponentDelta {
                    component_id: format!("{ship_entity_id}:flight_computer"),
                    component_kind: "flight_computer".to_string(),
                    properties: serde_json::json!({"profile": "ManualAssist", "throttle": 0.0}),
                },
                WorldComponentDelta {
                    component_id: format!("{ship_entity_id}:health_pool"),
                    component_kind: "health_pool".to_string(),
                    properties: serde_json::json!({"hp": 100.0, "max_hp": 100.0}),
                },
            ],
            removed: false,
        },
    ];
    persistence.persist_world_delta(&starter_world, 0)?;
    Ok(())
}

fn init_replication_runtime(world: &mut World) {
    let database_url = std::env::var("REPLICATION_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://sidereal:sidereal@127.0.0.1:5432/sidereal".to_string());
    let persist_interval_s = std::env::var("REPLICATION_PERSIST_INTERVAL_S")
        .ok()
        .and_then(|v| v.parse::<f32>().ok())
        .filter(|v| *v > 0.0)
        .unwrap_or(15.0);
    let snapshot_interval_s = std::env::var("SNAPSHOT_INTERVAL_S")
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .filter(|v| *v > 0)
        .unwrap_or(15);

    let mut persistence = match GraphPersistence::connect(&database_url) {
        Ok(v) => v,
        Err(err) => {
            eprintln!("replication runtime init failed to connect persistence: {err}");
            return;
        }
    };
    if let Err(err) = persistence.ensure_schema() {
        eprintln!("replication runtime init failed to ensure schema: {err}");
        return;
    }
    let known_entities = match hydrate_known_entity_ids(&mut persistence) {
        Ok(entity_ids) => entity_ids,
        Err(err) => {
            eprintln!("replication runtime init failed initial graph load: {err}");
            HashSet::new()
        }
    };

    let persist_interval = Duration::from_secs_f32(persist_interval_s);
    let snapshot_interval = Duration::from_secs(snapshot_interval_s);
    world.insert_non_send_resource(ReplicationRuntime {
        persistence,
        known_entities,
        pending_updates: HashMap::new(),
        last_tick: 0,
        persist_interval,
        snapshot_interval,
        last_persist_at: Instant::now() - persist_interval,
        last_snapshot_at: Instant::now(),
    });
}

fn start_lightyear_server(mut commands: Commands<'_, '_>) {
    let bind_addr = std::env::var("REPLICATION_UDP_BIND")
        .unwrap_or_else(|_| "0.0.0.0:7001".to_string())
        .parse::<SocketAddr>();
    let bind_addr = match bind_addr {
        Ok(v) => v,
        Err(err) => {
            eprintln!("invalid REPLICATION_UDP_BIND: {err}");
            return;
        }
    };

    let server = commands
        .spawn((
            Name::new("replication-lightyear-server"),
            RawServer,
            ServerUdpIo::default(),
            LocalAddr(bind_addr),
            Stopped,
        ))
        .id();
    commands.trigger(Start { entity: server });
    println!("replication lightyear UDP server starting on {bind_addr}");
}

fn ensure_server_transport_channels(
    mut transports: Query<'_, '_, &mut Transport, With<ClientOf>>,
    registry: Res<'_, ChannelRegistry>,
) {
    for mut transport in &mut transports {
        if !transport.has_receiver::<StateChannel>() {
            transport.add_receiver_from_registry::<StateChannel>(&registry);
        }
        if !transport.has_receiver::<InputChannel>() {
            transport.add_receiver_from_registry::<InputChannel>(&registry);
        }
        if !transport.has_sender::<StateChannel>() {
            transport.add_sender_from_registry::<StateChannel>(&registry);
        }
    }
}

fn receive_client_inputs(
    mut receivers: Query<
        '_,
        '_,
        (Entity, &mut MessageReceiver<ClientInputMessage>),
        With<ClientOf>,
    >,
    mut visibility_registry: ResMut<'_, ClientVisibilityRegistry>,
    ship_map: Res<'_, PlayerShipMap>,
    mut actions: Query<'_, '_, &mut ActionQueue, With<SimulatedShip>>,
) {
    for (client_entity, mut receiver) in &mut receivers {
        for message in receiver.receive() {
            if message.player_entity_id.starts_with("player:") {
                visibility_registry
                    .register_client(client_entity, message.player_entity_id.clone());
            }
            if let Some(ship_entity) = ship_map.by_player_entity_id.get(&message.player_entity_id)
                && let Ok(mut queue) = actions.get_mut(*ship_entity)
            {
                for action in &message.actions {
                    queue.push(*action);
                }
            }
            println!(
                "replication received client input: player={} actions={} tick={}",
                message.player_entity_id,
                message.actions.len(),
                message.tick
            );
        }
    }
}

fn sync_simulated_ship_components(
    mut ships: Query<
        '_,
        '_,
        (
            &Position,
            &LinearVelocity,
            &mut Transform,
            &mut PositionM,
            &mut VelocityMps,
        ),
        With<SimulatedShip>,
    >,
) {
    for (position, velocity, mut transform, mut position_m, mut velocity_mps) in &mut ships {
        transform.translation = position.0;
        position_m.0 = position.0;
        velocity_mps.0 = velocity.0;
    }
}

fn collect_local_simulation_state(
    ships: Query<
        '_,
        '_,
        (
            &SimulatedShip,
            &PositionM,
            &VelocityMps,
            &HealthPool,
            &FlightComputer,
            &OwnerId,
        ),
    >,
    runtime: Option<NonSendMut<'_, ReplicationRuntime>>,
    mut outbound: ResMut<'_, ReplicationOutboundQueue>,
) {
    let Some(mut runtime) = runtime else {
        return;
    };

    let mut updates = Vec::new();
    for (ship, position, velocity, health, flight, owner) in &ships {
        updates.push(WorldDeltaEntity {
            entity_id: ship.entity_id.clone(),
            labels: vec!["Entity".to_string(), "Ship".to_string()],
            properties: serde_json::json!({
                "entity_id": ship.entity_id.as_str(),
                "player_entity_id": ship.player_entity_id.as_str(),
                "position_m": [position.0.x, position.0.y, position.0.z],
                "velocity_mps": [velocity.0.x, velocity.0.y, velocity.0.z],
                "health": health.current,
                "max_health": health.maximum,
            }),
            components: vec![
                WorldComponentDelta {
                    component_id: format!("{}:owner_id", ship.entity_id),
                    component_kind: "owner_id".to_string(),
                    properties: serde_json::json!(owner.0),
                },
                WorldComponentDelta {
                    component_id: format!("{}:flight_computer", ship.entity_id),
                    component_kind: "flight_computer".to_string(),
                    properties: serde_json::json!({
                        "profile": flight.profile.as_str(),
                        "throttle": flight.throttle,
                        "yaw_input": flight.yaw_input,
                    }),
                },
                WorldComponentDelta {
                    component_id: format!("{}:health_pool", ship.entity_id),
                    component_kind: "health_pool".to_string(),
                    properties: serde_json::json!({
                        "current": health.current,
                        "maximum": health.maximum,
                    }),
                },
            ],
            removed: false,
        });
    }

    if updates.is_empty() {
        return;
    }

    let tick = runtime.last_tick.saturating_add(1);
    let world = WorldStateDelta { updates };
    let has_removals = {
        let ReplicationRuntime {
            known_entities,
            pending_updates,
            ..
        } = &mut *runtime;
        ingest_world_delta(known_entities, pending_updates, world.clone())
    };
    runtime.last_tick = tick;
    outbound
        .messages
        .push(QueuedReplicationDelta { tick, world });

    if has_removals && !runtime.pending_updates.is_empty() {
        let ReplicationRuntime {
            persistence,
            pending_updates,
            ..
        } = &mut *runtime;
        if let Err(err) = flush_pending_updates(persistence, pending_updates, tick) {
            eprintln!("replication failed persisting world delta after removals: {err}");
        } else {
            runtime.last_persist_at = Instant::now();
        }
    }
}

fn flush_replication_persistence(runtime: Option<NonSendMut<'_, ReplicationRuntime>>) {
    let Some(mut runtime) = runtime else {
        return;
    };

    let should_persist = runtime.last_persist_at.elapsed() >= runtime.persist_interval;
    if should_persist && !runtime.pending_updates.is_empty() {
        let last_tick = runtime.last_tick;
        let ReplicationRuntime {
            persistence,
            pending_updates,
            ..
        } = &mut *runtime;
        if let Err(err) = flush_pending_updates(persistence, pending_updates, last_tick) {
            eprintln!("replication failed persisting world delta: {err}");
        } else {
            runtime.last_persist_at = Instant::now();
        }
    }

    if runtime.last_snapshot_at.elapsed() >= runtime.snapshot_interval {
        let last_tick = runtime.last_tick;
        let entity_count = runtime.known_entities.len();
        if let Err(err) = runtime
            .persistence
            .persist_snapshot_marker(last_tick, entity_count)
        {
            eprintln!("replication failed persisting snapshot marker: {err}");
        } else {
            runtime.last_snapshot_at = Instant::now();
        }
    }
}

fn broadcast_replication_state(
    mut outbound: ResMut<'_, ReplicationOutboundQueue>,
    server_query: Query<'_, '_, &Server, With<RawServer>>,
    clients: Query<'_, '_, (Entity, &RemoteId), ConnectedClientFilter>,
    visibility_registry: Res<'_, ClientVisibilityRegistry>,
    mut sender: ServerMultiMessageSender<'_, '_, With<Connected>>,
) {
    if outbound.messages.is_empty() {
        return;
    }
    let Ok(server) = server_query.single() else {
        return;
    };
    for queued in outbound.messages.drain(..) {
        for (client_entity, remote_id) in &clients {
            let visibility_ctx = visibility_context_for_client(client_entity, &visibility_registry);
            let Some(filtered_world) = apply_visibility_filter(&queued.world, &visibility_ctx)
            else {
                continue;
            };
            let target = delivery_target_for_session(&visibility_ctx, remote_id.0);
            let message = match ReplicationStateMessage::from_world(queued.tick, &filtered_world) {
                Ok(message) => message,
                Err(err) => {
                    eprintln!(
                        "replication failed encoding outbound replication state tick={} for Lightyear: {err}",
                        queued.tick
                    );
                    continue;
                }
            };
            if let Err(err) =
                sender.send::<ReplicationStateMessage, StateChannel>(&message, server, &target)
            {
                eprintln!("replication failed broadcasting state message: {err}");
            }
        }
    }
}

fn log_replication_client_connected(
    trigger: On<Add, Connected>,
    clients: Query<'_, '_, (), With<ClientOf>>,
) {
    if clients.get(trigger.entity).is_ok() {
        println!(
            "replication lightyear client connected entity={:?}",
            trigger.entity
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sidereal_net::{WorldComponentDelta, WorldStateDelta};
    use std::net::{IpAddr, Ipv4Addr};

    #[test]
    fn remote_endpoint_registers_when_enabled() {
        let cfg = RemoteInspectConfig {
            enabled: true,
            bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
            port: 15713,
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

    #[test]
    fn ingest_world_delta_tracks_add_remove() {
        let mut cache = HashSet::<String>::new();
        let mut pending = HashMap::<String, WorldDeltaEntity>::new();
        let add = WorldDeltaEntity {
            entity_id: "ship:1".to_string(),
            labels: vec!["Entity".to_string()],
            properties: serde_json::json!({}),
            components: Vec::new(),
            removed: false,
        };
        let has_removals = ingest_world_delta(
            &mut cache,
            &mut pending,
            WorldStateDelta { updates: vec![add] },
        );
        assert!(!has_removals);
        assert!(cache.contains("ship:1"));
        assert!(pending.contains_key("ship:1"));

        let remove = WorldDeltaEntity {
            entity_id: "ship:1".to_string(),
            labels: Vec::new(),
            properties: serde_json::json!({}),
            components: Vec::new(),
            removed: true,
        };
        let has_removals = ingest_world_delta(
            &mut cache,
            &mut pending,
            WorldStateDelta {
                updates: vec![remove],
            },
        );
        assert!(has_removals);
        assert!(!cache.contains("ship:1"));
        assert!(pending.contains_key("ship:1"));
    }

    #[test]
    fn visibility_context_uses_registered_client_player_mapping() {
        let client = Entity::from_bits(42);
        let mut registry = ClientVisibilityRegistry::default();
        registry.register_client(client, "player:abc".to_string());

        let auth = visibility_context_for_client(client, &registry);
        assert_eq!(auth.scope, visibility::VisibilityScope::Authenticated);
        assert_eq!(auth.player_entity_id.as_deref(), Some("player:abc"));

        let unknown = visibility_context_for_client(Entity::from_bits(7), &registry);
        assert_eq!(unknown.scope, visibility::VisibilityScope::None);
        assert!(unknown.player_entity_id.is_none());
    }

    #[test]
    fn visibility_filter_enforces_ownership() {
        let world = WorldStateDelta {
            updates: vec![
                WorldDeltaEntity {
                    entity_id: "ship:1".to_string(),
                    labels: vec!["Entity".to_string()],
                    properties: serde_json::json!({
                        "entity_id": "ship:1",
                        "position_m": [100.0, 200.0, 0.0],
                        "health": 1000.0,
                    }),
                    components: vec![WorldComponentDelta {
                        component_id: "ship:1:owner_id".to_string(),
                        component_kind: "owner_id".to_string(),
                        properties: serde_json::json!("player:alice"),
                    }],
                    removed: false,
                },
                WorldDeltaEntity {
                    entity_id: "ship:2".to_string(),
                    labels: vec!["Entity".to_string()],
                    properties: serde_json::json!({
                        "entity_id": "ship:2",
                        "position_m": [500.0, 600.0, 0.0],
                        "health": 800.0,
                    }),
                    components: vec![WorldComponentDelta {
                        component_id: "ship:2:owner_id".to_string(),
                        component_kind: "owner_id".to_string(),
                        properties: serde_json::json!("player:bob"),
                    }],
                    removed: false,
                },
            ],
        };

        let ctx = visibility::VisibilityContext::authenticated("player:alice".to_string());
        let filtered = apply_visibility_filter(&world, &ctx).unwrap();

        // Should see own ship with all properties and components
        let own_ship = filtered
            .updates
            .iter()
            .find(|e| e.entity_id == "ship:1")
            .unwrap();
        assert!(own_ship.properties.get("health").is_some());
        assert_eq!(own_ship.components.len(), 1); // OwnerId component

        // Should see other ship with only safe properties and no components
        let other_ship = filtered
            .updates
            .iter()
            .find(|e| e.entity_id == "ship:2")
            .unwrap();
        assert!(other_ship.properties.get("position_m").is_some());
        assert!(other_ship.properties.get("health").is_none());
        assert_eq!(other_ship.components.len(), 0); // All components stripped
    }
}
