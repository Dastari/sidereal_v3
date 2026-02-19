// Planet Normal Map Generator
// Generates normal maps from the same procedural functions as planet_core.wgsl
// for proper bump/displacement mapping
//
// This shader should use identical noise and feature functions to planet_core.wgsl
// to ensure normal maps match the actual surface generation

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput

struct PlanetParams {
    seed: u32,
    planet_type: u32,
    
    crater_density: f32,
    crater_size: f32,
    continent_size: f32,
    ocean_level: f32,
    
    mountain_height: f32,
    roughness: f32,
    terrain_octaves: u32,
    terrain_lacunarity: f32,
    
    cloud_coverage: f32,
    cloud_height: f32,
    atmosphere_thickness: f32,
    atmosphere_falloff: f32,
    
    volcano_density: f32,
    ice_cap_size: f32,
    storm_intensity: f32,
    city_lights: f32,
    
    corona_intensity: f32,
    surface_activity: f32,
    bands_count: f32,
    spot_density: f32,
    
    color_primary: vec4<f32>,
    color_secondary: vec4<f32>,
    color_tertiary: vec4<f32>,
    color_atmosphere: vec4<f32>,
    
    rotation_speed: f32,
    time: f32,
    
    detail_level: f32,
    normal_strength: f32,
}

@group(2) @binding(0) var<uniform> params: PlanetParams;

// Include the same hash and noise functions
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

fn mod289_3(x: vec3<f32>) -> vec3<f32> {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

fn permute3(x: vec3<f32>) -> vec3<f32> {
    return mod289_3(((x * 34.0) + 1.0) * x);
}

fn simplexNoise3(p: vec3<f32>) -> f32 {
    let s = vec3<f32>(7.0, 157.0, 113.0);
    var ip = floor(p);
    var fp = fract(p);
    fp = fp * fp * (3.0 - 2.0 * fp);
    
    var h = dot(ip, s);
    let h_u = u32(h);
    let n000 = hash31(ip);
    let n100 = hash31(ip + vec3<f32>(1.0, 0.0, 0.0));
    let n010 = hash31(ip + vec3<f32>(0.0, 1.0, 0.0));
    let n110 = hash31(ip + vec3<f32>(1.0, 1.0, 0.0));
    let n001 = hash31(ip + vec3<f32>(0.0, 0.0, 1.0));
    let n101 = hash31(ip + vec3<f32>(1.0, 0.0, 1.0));
    let n011 = hash31(ip + vec3<f32>(0.0, 1.0, 1.0));
    let n111 = hash31(ip + vec3<f32>(1.0, 1.0, 1.0));
    
    let n00 = mix(n000, n100, fp.x);
    let n01 = mix(n001, n101, fp.x);
    let n10 = mix(n010, n110, fp.x);
    let n11 = mix(n011, n111, fp.x);
    
    let n0 = mix(n00, n10, fp.y);
    let n1 = mix(n01, n11, fp.y);
    
    return mix(n0, n1, fp.z);
}

fn fbm(p: vec3<f32>, octaves: u32, lacunarity: f32, gain: f32) -> f32 {
    var value = 0.0;
    var amplitude = 1.0;
    var frequency = 1.0;
    var pos = p;
    
    for (var i = 0u; i < octaves; i = i + 1u) {
        value += amplitude * simplexNoise3(pos * frequency);
        frequency *= lacunarity;
        amplitude *= gain;
    }
    
    return value;
}

// Height sampling function - must match planet_core.wgsl
fn sample_height(p: vec3<f32>) -> f32 {
    let seeded_p = p + vec3<f32>(f32(params.seed) * 0.001);
    
    // This should match the height calculation in planet_core.wgsl
    // Simplified version for demonstration
    var height = 0.0;
    
    if params.planet_type == 0u {  // Rocky
        let terrain = fbm(seeded_p * 2.0, params.terrain_octaves, params.terrain_lacunarity, 0.5);
        height = terrain * params.normal_strength;
    } else if params.planet_type == 1u {  // Desert
        let dunes = fbm(seeded_p * 3.0, 5u, 2.0, 0.6);
        height = dunes * params.normal_strength;
    } else if params.planet_type == 2u {  // Lava
        let terrain = fbm(seeded_p * 2.0, 4u, 2.2, 0.5);
        height = terrain * params.normal_strength;
    } else if params.planet_type == 5u {  // Moon
        let base = fbm(seeded_p * 1.5, 3u, 2.0, 0.5);
        height = base * params.normal_strength * 2.0;
    } else {
        let terrain = fbm(seeded_p * 2.0, 4u, 2.0, 0.5);
        height = terrain * params.normal_strength;
    }
    
    return height;
}

// Calculate normal from height field using finite differences
fn calculate_normal(p: vec3<f32>, epsilon: f32) -> vec3<f32> {
    let h = sample_height(p);
    
    // Sample nearby points
    let h_x = sample_height(p + vec3<f32>(epsilon, 0.0, 0.0));
    let h_y = sample_height(p + vec3<f32>(0.0, epsilon, 0.0));
    let h_z = sample_height(p + vec3<f32>(0.0, 0.0, epsilon));
    
    // Compute gradient
    let dx = (h_x - h) / epsilon;
    let dy = (h_y - h) / epsilon;
    let dz = (h_z - h) / epsilon;
    
    // Convert to normal (tangent space)
    let normal = normalize(vec3<f32>(-dx, -dy, -dz));
    
    return normal;
}

@fragment
fn fragment(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    // Get sphere-space position
    let world_pos = mesh.world_position.xyz;
    let p = normalize(world_pos);
    
    // Apply rotation
    let rotation_angle = params.time * params.rotation_speed;
    let cos_rot = cos(rotation_angle);
    let sin_rot = sin(rotation_angle);
    let rotated_p = vec3<f32>(
        p.x * cos_rot - p.z * sin_rot,
        p.y,
        p.x * sin_rot + p.z * cos_rot
    );
    
    // Calculate normal map
    let epsilon = 0.001 * params.detail_level;
    let calculated_normal = calculate_normal(rotated_p, epsilon);
    
    // Transform from [-1, 1] to [0, 1] for storage in texture
    let normal_color = calculated_normal * 0.5 + 0.5;
    
    return vec4<f32>(normal_color, 1.0);
}
