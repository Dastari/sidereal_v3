// Planetary Ring System Shader
// For rendering rings around gas giants and other planets (Saturn-style)
// Supports multiple ring bands, gaps, particles, and shadows
//
// Render as a flat disk mesh with UV coordinates from center

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput

struct RingParams {
    // Ring geometry
    inner_radius: f32,
    outer_radius: f32,
    planet_radius: f32,
    planet_center: vec3<f32>,
    
    // Ring structure
    band_count: u32,        // Number of distinct bands (2-10 typical)
    gap_count: u32,         // Number of major gaps (Cassini division, etc.)
    gap_width: f32,         // Average gap size (0.01-0.1)
    
    // Particle properties
    particle_size_variation: f32,
    particle_density: f32,
    dust_density: f32,      // Fine dust vs chunks
    ice_content: f32,       // 0=rock, 1=ice
    
    // Lighting
    sun_direction: vec3<f32>,
    ambient_light: f32,
    shadow_softness: f32,
    
    // Colors
    color_inner: vec4<f32>,
    color_middle: vec4<f32>,
    color_outer: vec4<f32>,
    shadow_color: vec3<f32>,
    
    // Detail
    detail_scale: f32,
    detail_strength: f32,
    radial_waves: f32,      // Density waves
    spiral_arms: f32,       // Shepherd moon effects
    
    // Animation
    rotation_speed: f32,
    time: f32,
    
    // Technical
    seed: u32,
    opacity: f32,
}

@group(2) @binding(0) var<uniform> params: RingParams;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

// ============================================================================
// HASH AND NOISE
// ============================================================================

fn pcg(n: u32) -> u32 {
    var h = n * 747796405u + 2891336453u;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
    return (h >> 22u) ^ h;
}

fn pcg2d(p: vec2<u32>) -> vec2<u32> {
    var v = p * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> vec2<u32>(16u));
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> vec2<u32>(16u));
    return v;
}

fn hash11(n: u32) -> f32 {
    return f32(pcg(n)) / f32(0xffffffffu);
}

fn hash21(p: vec2<f32>) -> f32 {
    let pi = vec2<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y));
    return f32(pcg2d(pi).x) / f32(0xffffffffu);
}

fn noise2d(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn fbm2d(p: vec2<f32>, octaves: i32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    
    for (var i = 0; i < octaves; i = i + 1) {
        value += amplitude * noise2d(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// ============================================================================
// RING STRUCTURE
// ============================================================================

// Calculate base ring density at radius
fn ring_density_profile(radius: f32) -> f32 {
    let normalized_radius = (radius - params.inner_radius) / (params.outer_radius - params.inner_radius);
    
    if normalized_radius < 0.0 || normalized_radius > 1.0 {
        return 0.0;
    }
    
    // Base density falloff (outer rings are typically less dense)
    var density = 1.0 - pow(normalized_radius, 1.5) * 0.7;
    
    // Add distinct bands
    if params.band_count > 0u {
        let band_phase = fract(normalized_radius * f32(params.band_count));
        let band_variation = sin(band_phase * TAU) * 0.5 + 0.5;
        density *= 0.5 + band_variation * 0.5;
    }
    
    // Add gaps (Cassini division, Encke gap, etc.)
    if params.gap_count > 0u {
        for (var i = 0u; i < params.gap_count; i = i + 1u) {
            let gap_position = (f32(i) + 0.5) / f32(params.gap_count);
            let gap_center = params.inner_radius + gap_position * (params.outer_radius - params.inner_radius);
            let gap_dist = abs(radius - gap_center);
            let gap_half_width = params.gap_width * (params.outer_radius - params.inner_radius) * 0.5;
            
            let gap_factor = smoothstep(gap_half_width * 0.8, gap_half_width, gap_dist);
            density *= gap_factor;
        }
    }
    
    return density;
}

// Radial density waves (from orbital resonances)
fn density_waves(radius: f32, angle: f32) -> f32 {
    if params.radial_waves < 0.01 {
        return 1.0;
    }
    
    let wave_count = 8.0 + params.radial_waves * 20.0;
    let wave_freq = wave_count / (params.outer_radius - params.inner_radius);
    
    let wave = sin((radius - params.inner_radius) * wave_freq + angle * 3.0) * 0.5 + 0.5;
    let wave_strength = params.radial_waves;
    
    return 1.0 - wave * wave_strength * 0.5;
}

// Spiral density patterns (shepherd moon perturbations)
fn spiral_density(radius: f32, angle: f32, time: f32) -> f32 {
    if params.spiral_arms < 0.01 {
        return 1.0;
    }
    
    let arm_count = 2.0;
    let spiral_tightness = 3.0;
    
    var spiral_pattern = 0.0;
    for (var i = 0.0; i < arm_count; i += 1.0) {
        let arm_angle = TAU * i / arm_count;
        let spiral_angle = angle - arm_angle - (radius - params.inner_radius) * spiral_tightness + time * 0.1;
        let arm_dist = abs(sin(spiral_angle));
        spiral_pattern += smoothstep(0.8, 0.2, arm_dist);
    }
    
    return 1.0 + spiral_pattern * params.spiral_arms * 0.3;
}

// Particle clumping and detail
fn particle_detail(pos: vec2<f32>, radius: f32) -> f32 {
    let detail_pos = pos * params.detail_scale * 100.0;
    let detail_noise = fbm2d(detail_pos, 4);
    
    // Larger particles make clumpier patterns
    let clumping = 1.0 - params.particle_size_variation;
    let detail_strength = params.detail_strength * clumping;
    
    return mix(1.0, detail_noise, detail_strength);
}

// ============================================================================
// LIGHTING AND SHADOWS
// ============================================================================

// Planet shadow on rings
fn planet_shadow(world_pos: vec3<f32>) -> f32 {
    // Vector from planet center to ring position
    let to_ring = world_pos - params.planet_center;
    
    // Project sun direction onto ring plane
    let sun_dir_projected = normalize(vec3<f32>(params.sun_direction.x, 0.0, params.sun_direction.z));
    
    // Check if point is in planet's shadow
    let ring_distance_from_center = length(to_ring);
    let shadow_direction = -sun_dir_projected;
    
    // Ray from ring point toward sun
    let dot_prod = dot(normalize(to_ring), shadow_direction);
    
    if dot_prod > 0.0 {
        // This point is on the lit side
        return 1.0;
    }
    
    // Check if planet blocks the sun
    let ring_height = abs(to_ring.y);
    let distance_along_shadow = ring_distance_from_center * abs(dot_prod);
    
    if distance_along_shadow < params.planet_radius && ring_height < params.planet_radius {
        // In umbra (full shadow)
        let shadow_distance = params.planet_radius - distance_along_shadow;
        let softness = params.shadow_softness * params.planet_radius;
        return smoothstep(0.0, softness, shadow_distance);
    }
    
    return 1.0;
}

// Ring self-shadowing (density-based)
fn ring_self_shadow(radius: f32, density: f32) -> f32 {
    // Thicker parts cast more shadow
    let sun_elevation = params.sun_direction.y;
    let shadow_length = density * (1.0 - abs(sun_elevation));
    
    return 1.0 - shadow_length * 0.3;
}

// Lighting based on sun angle and surface normal
fn calculate_lighting(world_pos: vec3<f32>, density: f32) -> vec3<f32> {
    // Ring "normal" points up/down from ring plane
    let ring_normal = vec3<f32>(0.0, sign(world_pos.y - params.planet_center.y), 0.0);
    
    let n_dot_l = abs(dot(ring_normal, normalize(params.sun_direction)));
    let diffuse = max(n_dot_l, params.ambient_light);
    
    // Planet shadow
    let planet_shadow_factor = planet_shadow(world_pos);
    
    // Self-shadowing
    let self_shadow_factor = ring_self_shadow(length(world_pos.xy - params.planet_center.xy), density);
    
    let total_shadow = planet_shadow_factor * self_shadow_factor;
    
    // Shadow color
    let lit_color = vec3<f32>(1.0);
    let shadowed_color = params.shadow_color;
    
    return mix(shadowed_color, lit_color, total_shadow * diffuse);
}

// ============================================================================
// COLOR AND COMPOSITION
// ============================================================================

fn ring_color(radius: f32, density: f32) -> vec3<f32> {
    let normalized_radius = (radius - params.inner_radius) / (params.outer_radius - params.inner_radius);
    
    // Gradient from inner to outer rings
    var base_color: vec3<f32>;
    if normalized_radius < 0.5 {
        base_color = mix(params.color_inner.rgb, params.color_middle.rgb, normalized_radius * 2.0);
    } else {
        base_color = mix(params.color_middle.rgb, params.color_outer.rgb, (normalized_radius - 0.5) * 2.0);
    }
    
    // Ice vs rock composition affects color
    let ice_color = vec3<f32>(0.9, 0.95, 1.0);
    let rock_color = vec3<f32>(0.6, 0.5, 0.4);
    let composition_color = mix(rock_color, ice_color, params.ice_content);
    
    base_color = mix(base_color, composition_color, 0.3);
    
    // Dust makes things more uniform/bright
    let dust_effect = params.dust_density * 0.3;
    base_color = mix(base_color, vec3<f32>(0.8, 0.8, 0.75), dust_effect);
    
    return base_color;
}

// ============================================================================
// MAIN FRAGMENT
// ============================================================================

@fragment
fn fragment(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    let world_pos = mesh.world_position.xyz;
    let to_ring_pos = world_pos - params.planet_center;
    
    // Calculate radius and angle in ring plane
    let radius = length(to_ring_pos.xz);
    let angle = atan2(to_ring_pos.z, to_ring_pos.x) + params.time * params.rotation_speed;
    
    // Discard if outside ring bounds
    if radius < params.inner_radius || radius > params.outer_radius {
        discard;
    }
    
    // Calculate ring density at this location
    var density = ring_density_profile(radius);
    density *= density_waves(radius, angle);
    density *= spiral_density(radius, angle, params.time);
    density *= particle_detail(to_ring_pos.xz, radius);
    density *= params.particle_density;
    
    // Very low density = transparent
    if density < 0.01 {
        discard;
    }
    
    // Calculate color
    let base_color = ring_color(radius, density);
    
    // Calculate lighting
    let lighting = calculate_lighting(world_pos, density);
    
    // Final color
    let final_color = base_color * lighting;
    
    // Opacity based on density and viewing angle
    let view_dir = normalize(world_pos - mesh.world_position.xyz);
    let ring_normal = vec3<f32>(0.0, 1.0, 0.0);
    let viewing_angle = abs(dot(view_dir, ring_normal));
    
    // Rings are more transparent when viewed edge-on
    let angle_opacity = smoothstep(0.0, 0.3, viewing_angle);
    
    let final_opacity = density * params.opacity * angle_opacity;
    
    return vec4<f32>(final_color, clamp(final_opacity, 0.0, 1.0));
}
