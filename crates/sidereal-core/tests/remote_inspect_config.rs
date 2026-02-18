use std::net::{IpAddr, Ipv4Addr};

use sidereal_core::remote_inspect::RemoteInspectConfig;

#[test]
fn disabled_by_default_config_can_omit_token() {
    let cfg = RemoteInspectConfig {
        enabled: false,
        bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
        port: 15702,
        auth_token: None,
    };
    assert!(cfg.validate().is_ok());
}

#[test]
fn enabled_config_requires_token() {
    let cfg = RemoteInspectConfig {
        enabled: true,
        bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
        port: 15702,
        auth_token: None,
    };
    assert!(cfg.validate().is_err());
}

#[test]
fn enabled_config_requires_reasonable_token_length() {
    let cfg = RemoteInspectConfig {
        enabled: true,
        bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
        port: 15702,
        auth_token: Some("short-token".to_string()),
    };
    assert!(cfg.validate().is_err());
}

#[test]
fn enabled_config_accepts_token() {
    let cfg = RemoteInspectConfig {
        enabled: true,
        bind_addr: IpAddr::V4(Ipv4Addr::LOCALHOST),
        port: 15702,
        auth_token: Some("0123456789abcdef".to_string()),
    };
    assert!(cfg.validate().is_ok());
}

#[test]
fn enabled_config_rejects_non_loopback_bind_in_day0_scaffold() {
    let cfg = RemoteInspectConfig {
        enabled: true,
        bind_addr: IpAddr::V4(Ipv4Addr::new(10, 0, 0, 8)),
        port: 15702,
        auth_token: Some("0123456789abcdef".to_string()),
    };
    assert!(cfg.validate().is_err());
}
