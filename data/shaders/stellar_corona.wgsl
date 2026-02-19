// Stellar Corona Shader
// Advanced corona, flares, and prominence effects for stars
// Render as additive transparent layer around star sphere
//
// Creates dynamic stellar atmospheres with:
// - Solar prominences
// - Coronal mass ejections
// - Solar flares
// - Chromospheric activity
// - Magnetic field visualization

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput

struct CoronaParams {
    // Star properties
    star_radius: f32,
    corona_radius: f32,
    star_center: vec3<f32>,
    star_temperature: f32,  // 2000-50000 K typical
    
    // Corona properties
    corona_intensity: f32,
    corona_turbulence: f32,
    corona_streamers: f32,
    
    // Prominence settings
    prominence_count: f32,
    prominence_height: f32,
    prominence_width: f32,
    prominence_intensity: f32,
    
    // Flare settings
    flare_probability: f32,
    flare_intensity: f32,
    flare_duration: f32,
    
    // Magnetic field
    magnetic_complexity: f32,
    field_line_intensity: f32,
    
    // Activity regions
    active_region_count: f32,
    spot_density: f32,
    
    // Colors
    corona_base_color: vec3<f32>,
    prominence_color: vec3<f32>,
    flare_color: vec3<f32>,
    
    // Animation
    time: f32,
    rotation_speed: f32,
    activity_speed: f32,
    
    // Technical
    seed: u32,
    detail_level: f32,
}

@group(2) @binding(0) var<uniform> params: CoronaParams;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

// ============================================================================
// NOISE AND HASH FUNCTIONS
// ============================================================================

fn pcg3d(p: vec3<u32>) -> vec3<u32> {
    var v = p * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v = v ^ (v >> vec3<u32>(16u));
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

fn hash31(p: vec3<f32>) -> f32 {
    let pi = vec3<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y), bitcast<u32>(p.z));
    return f32(pcg3d(pi).x) / f32(0xffffffffu);
}

fn hash33(p: vec3<f32>) -> vec3<f32> {
    let pi = vec3<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y), bitcast<u32>(p.z));
    let h = pcg3d(pi);
    return vec3<f32>(h) / f32(0xffffffffu);
}

fn noise3d(p: vec3<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    
    let n000 = hash31(i);
    let n100 = hash31(i + vec3<f32>(1.0, 0.0, 0.0));
    let n010 = hash31(i + vec3<f32>(0.0, 1.0, 0.0));
    let n110 = hash31(i + vec3<f32>(1.0, 1.0, 0.0));
    let n001 = hash31(i + vec3<f32>(0.0, 0.0, 1.0));
    let n101 = hash31(i + vec3<f32>(1.0, 0.0, 1.0));
    let n011 = hash31(i + vec3<f32>(0.0, 1.0, 1.0));
    let n111 = hash31(i + vec3<f32>(1.0, 1.0, 1.0));
    
    return mix(
        mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
        mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
        u.z
    );
}

fn fbm(p: vec3<f32>, octaves: i32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var pos = p;
    
    for (var i = 0; i < octaves; i = i + 1) {
        value += amplitude * noise3d(pos * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// Turbulent noise (absolute values)
fn turbulence(p: vec3<f32>, octaves: i32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var pos = p;
    
    for (var i = 0; i < octaves; i = i + 1) {
        value += amplitude * abs(noise3d(pos * frequency));
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// ============================================================================
// STELLAR EFFECTS
// ============================================================================

// Coronal streamers (plasma flows along magnetic field lines)
fn coronal_streamers(pos: vec3<f32>, normal: vec3<f32>, time: f32) -> f32 {
    if params.corona_streamers < 0.01 {
        return 0.0;
    }
    
    // Magnetic field-like patterns
    let magnetic_angle = atan2(pos.z, pos.x);
    let latitude = asin(normal.y);
    
    // Multiple streamer sources at different longitudes
    var streamer_intensity = 0.0;
    let num_streamers = max(3.0, params.corona_streamers * 12.0);
    
    for (var i = 0.0; i < num_streamers; i += 1.0) {
        let streamer_angle = (i / num_streamers) * TAU + time * 0.1 * params.rotation_speed;
        let angle_diff = abs(magnetic_angle - streamer_angle);
        let angular_proximity = 1.0 - smoothstep(0.0, 0.3, min(angle_diff, TAU - angle_diff));
        
        // Flow outward with turbulence
        let height = length(pos - params.star_center) - params.star_radius;
        let flow = sin(height * 5.0 - time * 2.0 * params.activity_speed) * 0.5 + 0.5;
        
        // Latitudinal concentration (streamers follow magnetic equator)
        let lat_concentration = 1.0 - abs(latitude) / (PI * 0.5);
        
        streamer_intensity += angular_proximity * flow * lat_concentration;
    }
    
    return streamer_intensity * params.corona_streamers;
}

// Solar prominences (loops of plasma)
fn prominences(pos: vec3<f32>, normal: vec3<f32>, time: f32) -> vec3<f32> {
    if params.prominence_count < 0.01 {
        return vec3<f32>(0.0);
    }
    
    var prominence_color = vec3<f32>(0.0);
    let height = length(pos - params.star_center) - params.star_radius;
    
    // Only render prominences at certain heights
    if height < 0.0 || height > params.prominence_height * 2.0 {
        return vec3<f32>(0.0);
    }
    
    let scale = 5.0;
    let scaled_pos = pos * scale;
    let cell = floor(scaled_pos);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - params.prominence_count * 0.3) {
                    let prom_pos = hash33(cell_id * 1.7 + vec3<f32>(f32(params.seed)));
                    let local = fract(scaled_pos) - offset - (prom_pos - 0.5);
                    
                    // Arc shape
                    let arc_dist = length(local.xz);
                    let arc_height = 1.0 - arc_dist * arc_dist;
                    let vertical_dist = abs(local.y - arc_height * params.prominence_height);
                    
                    let prom_width = params.prominence_width * 0.5;
                    if arc_dist < 0.5 && vertical_dist < prom_width {
                        let intensity = (1.0 - vertical_dist / prom_width) * 
                                       (1.0 - arc_dist * 2.0);
                        
                        // Turbulent inner structure
                        let turbulent = turbulence(pos * 10.0 + vec3<f32>(time * 0.5), 3);
                        
                        // Pulsating
                        let pulse = sin(time * 2.0 + h * TAU) * 0.5 + 0.5;
                        
                        prominence_color += params.prominence_color * 
                                          intensity * 
                                          params.prominence_intensity * 
                                          (0.7 + turbulent * 0.3) *
                                          (0.8 + pulse * 0.2);
                    }
                }
            }
        }
    }
    
    return prominence_color;
}

// Solar flares (bright bursts)
fn solar_flares(pos: vec3<f32>, normal: vec3<f32>, time: f32) -> vec3<f32> {
    if params.flare_probability < 0.01 {
        return vec3<f32>(0.0);
    }
    
    var flare_color = vec3<f32>(0.0);
    
    // Flare locations (tied to active regions)
    let scale = 3.0;
    let scaled_pos = pos * scale;
    let cell = floor(scaled_pos);
    let local = fract(scaled_pos);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - params.flare_probability * 0.1) {
                    let flare_seed = hash31(cell_id * 2.3);
                    
                    // Flare timing
                    let flare_period = 10.0 + flare_seed * 20.0;
                    let flare_phase = fract(time / flare_period);
                    
                    // Flare envelope (quick rise, slow decay)
                    var flare_envelope = 0.0;
                    if flare_phase < params.flare_duration {
                        let rise = flare_phase / (params.flare_duration * 0.2);
                        let decay = (params.flare_duration - flare_phase) / (params.flare_duration * 0.8);
                        flare_envelope = min(rise, decay);
                    }
                    
                    if flare_envelope > 0.0 {
                        let flare_pos = hash33(cell_id * 3.1);
                        let to_flare = local - offset - (flare_pos - 0.5);
                        let dist = length(to_flare);
                        
                        let flare_size = 0.2 + flare_seed * 0.1;
                        let intensity = smoothstep(flare_size, 0.0, dist) * flare_envelope;
                        
                        // Flare colors are very hot (white-blue)
                        let hot_flare = mix(params.flare_color, vec3<f32>(1.0, 1.0, 1.0), intensity);
                        flare_color += hot_flare * intensity * params.flare_intensity * 2.0;
                    }
                }
            }
        }
    }
    
    return flare_color;
}

// Magnetic field visualization
fn magnetic_field_lines(pos: vec3<f32>, normal: vec3<f32>, time: f32) -> f32 {
    if params.field_line_intensity < 0.01 {
        return 0.0;
    }
    
    // Simplified dipole-like field
    let height = length(pos - params.star_center) - params.star_radius;
    let magnetic_pos = pos * (3.0 + params.magnetic_complexity * 5.0);
    
    // Field lines follow sin/cos patterns
    let field_pattern = abs(sin(magnetic_pos.y * 3.0 + time * 0.2) * 
                           sin(magnetic_pos.x * 2.0) * 
                           sin(magnetic_pos.z * 2.5));
    
    // Only visible at certain heights
    let height_mask = smoothstep(0.0, params.star_radius * 0.1, height) * 
                     smoothstep(params.corona_radius * 0.5, params.corona_radius * 0.3, height);
    
    return pow(field_pattern, 5.0) * params.field_line_intensity * height_mask;
}

// Active regions (bright spots on surface, seen through corona)
fn active_regions(pos: vec3<f32>, normal: vec3<f32>) -> f32 {
    if params.active_region_count < 0.01 {
        return 0.0;
    }
    
    var activity = 0.0;
    let scale = 4.0;
    let scaled_pos = pos * scale;
    let cell = floor(scaled_pos);
    let local = fract(scaled_pos);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - params.active_region_count * 0.2) {
                    let region_pos = hash33(cell_id * 1.9);
                    let to_region = local - offset - (region_pos - 0.5);
                    let dist = length(to_region);
                    
                    let region_size = 0.15 + hash31(cell_id * 2.7) * 0.1;
                    activity += smoothstep(region_size, region_size * 0.3, dist);
                }
            }
        }
    }
    
    return activity;
}

// Base corona turbulence
fn corona_turbulence(pos: vec3<f32>, time: f32) -> f32 {
    let anim_pos = pos + vec3<f32>(time * 0.1 * params.activity_speed);
    let turb = turbulence(anim_pos * 2.0, 4);
    let flow = fbm(anim_pos * 1.5 + vec3<f32>(time * 0.2), 3);
    
    return (turb * 0.6 + flow * 0.4) * params.corona_turbulence;
}

// Temperature-based color (black body radiation approximation)
fn temperature_color(temp: f32) -> vec3<f32> {
    // Simplified black body color
    if temp < 3500.0 {
        return vec3<f32>(1.0, 0.4, 0.2);  // Red
    } else if temp < 5500.0 {
        return vec3<f32>(1.0, 0.8, 0.5);  // Orange-yellow
    } else if temp < 7500.0 {
        return vec3<f32>(1.0, 1.0, 0.9);  // White-yellow
    } else if temp < 12000.0 {
        return vec3<f32>(0.9, 0.95, 1.0); // White-blue
    } else {
        return vec3<f32>(0.7, 0.8, 1.0);  // Blue
    }
}

// ============================================================================
// MAIN FRAGMENT
// ============================================================================

@fragment
fn fragment(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    let world_pos = mesh.world_position.xyz;
    let normal = normalize(mesh.world_normal);
    let pos_from_center = world_pos - params.star_center;
    let distance_from_center = length(pos_from_center);
    let height = distance_from_center - params.star_radius;
    
    // Only render in corona region
    if height < 0.0 || height > (params.corona_radius - params.star_radius) {
        discard;
    }
    
    let normalized_pos = normalize(pos_from_center);
    
    // Apply rotation
    let rotation_angle = params.time * params.rotation_speed;
    let cos_rot = cos(rotation_angle);
    let sin_rot = sin(rotation_angle);
    let rotated_pos = vec3<f32>(
        normalized_pos.x * cos_rot - normalized_pos.z * sin_rot,
        normalized_pos.y,
        normalized_pos.x * sin_rot + normalized_pos.z * cos_rot
    );
    
    // Base corona color (temperature-based)
    var corona_color = mix(
        params.corona_base_color,
        temperature_color(params.star_temperature),
        0.5
    );
    
    // Accumulate all effects
    let streamers = coronal_streamers(rotated_pos, normal, params.time);
    let prominences_contrib = prominences(world_pos, normal, params.time);
    let flares = solar_flares(rotated_pos, normal, params.time);
    let field_lines = magnetic_field_lines(rotated_pos, normal, params.time);
    let active = active_regions(rotated_pos, normal);
    let turbulent = corona_turbulence(rotated_pos, params.time);
    
    // Base corona intensity (decreases with height)
    let base_intensity = exp(-height / (params.star_radius * 0.2)) * params.corona_intensity;
    
    // Combine effects
    var final_color = corona_color * base_intensity * (1.0 + turbulent);
    final_color += corona_color * streamers * 0.5;
    final_color += prominences_contrib;
    final_color += flares;
    final_color += corona_color * field_lines;
    final_color += corona_color * active * 0.3;
    
    // Calculate alpha (transparency based on height and intensity)
    let alpha = base_intensity * (0.3 + streamers * 0.3 + active * 0.2);
    
    // Additive blending works best for corona
    return vec4<f32>(final_color, clamp(alpha, 0.0, 1.0));
}
