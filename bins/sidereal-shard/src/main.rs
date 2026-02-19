use bevy::prelude::*;
use bevy_remote::RemotePlugin;
use bevy_remote::http::RemoteHttpPlugin;
use sidereal_core::remote_inspect::RemoteInspectConfig;

#[derive(Debug, Resource, Clone)]
#[allow(dead_code)]
struct BrpAuthToken(String);

fn main() {
    let remote_cfg = match RemoteInspectConfig::from_env("SHARD", 15712) {
        Ok(cfg) => cfg,
        Err(err) => {
            eprintln!("invalid SHARD BRP config: {err}");
            std::process::exit(2);
        }
    };

    let mut app = App::new();
    app.add_plugins(MinimalPlugins);
    configure_remote(&mut app, &remote_cfg);
    app.add_systems(Startup, || {
        println!("sidereal-shard scaffold (reserved for future multi-shard mode)");
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::{IpAddr, Ipv4Addr};

    #[test]
    fn remote_endpoint_registers_when_enabled() {
        let cfg = RemoteInspectConfig {
            enabled: true,
            bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
            port: 15712,
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
