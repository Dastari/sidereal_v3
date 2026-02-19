// Planet Core Shader - Procedural Planet Generation for Bevy
// Deterministic generation based on seed with extensive customization
// Supports: rocky planets, gas giants, desert worlds, lava worlds, ice worlds, moons, stars
//
// References:
// - Noise functions adapted from https://gist.github.com/munrocket/236ed5ba7e409b8bdf1ff6eca5dcdc39
// - Procedural planet techniques inspired by shadertoy.com community
// - MIT License where applicable

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput
#import bevy_pbr::pbr_types::StandardMaterial

// Planet generation parameters
struct PlanetParams {
    // Core identity
    seed: u32,
    planet_type: u32,  // 0=rocky, 1=desert, 2=lava, 3=ice, 4=gas_giant, 5=moon, 6=star
    
    // Surface features (0.0 - 1.0 range)
    crater_density: f32,
    crater_size: f32,
    continent_size: f32,
    ocean_level: f32,
    
    // Terrain detail
    mountain_height: f32,
    roughness: f32,
    terrain_octaves: u32,
    terrain_lacunarity: f32,
    
    // Atmospheric
    cloud_coverage: f32,
    cloud_height: f32,
    atmosphere_thickness: f32,
    atmosphere_falloff: f32,
    
    // Special features
    volcano_density: f32,
    ice_cap_size: f32,
    storm_intensity: f32,
    city_lights: f32,
    
    // Star/gas specific
    corona_intensity: f32,
    surface_activity: f32,  // prominence/turbulence
    bands_count: f32,       // gas giant bands
    spot_density: f32,      // gas giant storms/sun spots
    
    // Color scheme (base colors)
    color_primary: vec4<f32>,
    color_secondary: vec4<f32>,
    color_tertiary: vec4<f32>,
    color_atmosphere: vec4<f32>,
    
    // Animation
    rotation_speed: f32,
    time: f32,
    
    // Technical
    detail_level: f32,
    normal_strength: f32,
}

@group(2) @binding(0) var<uniform> params: PlanetParams;

// ============================================================================
// HASH FUNCTIONS - For deterministic randomness
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

fn hash11(n: u32) -> f32 {
    return f32(pcg(n)) / f32(0xffffffffu);
}

fn hash21(p: vec2<f32>) -> f32 {
    let pi = vec2<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y));
    return f32(pcg2d(pi).x) / f32(0xffffffffu);
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

// ============================================================================
// NOISE FUNCTIONS
// ============================================================================

fn mod289_3(x: vec3<f32>) -> vec3<f32> {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

fn permute3(x: vec3<f32>) -> vec3<f32> {
    return mod289_3(((x * 34.0) + 1.0) * x);
}

// Simplex noise 2D
fn simplexNoise2(v: vec2<f32>) -> f32 {
    let C = vec4<f32>(
        0.211324865405187,
        0.366025403784439,
        -0.577350269189626,
        0.024390243902439
    );
    
    var i = floor(v + dot(v, C.yy));
    let x0 = v - i + dot(i, C.xx);
    
    var i1 = select(vec2<f32>(0.0, 1.0), vec2<f32>(1.0, 0.0), x0.x > x0.y);
    
    var x12 = x0.xyxy + C.xxzz;
    x12 = vec4<f32>(x12.x - i1.x, x12.y - i1.y, x12.z, x12.w);
    
    i = i - floor(i * (1.0 / 289.0)) * 289.0;
    
    var p = permute3(permute3(i.y + vec3<f32>(0.0, i1.y, 1.0)) + i.x + vec3<f32>(0.0, i1.x, 1.0));
    var m = max(vec3<f32>(0.5) - vec3<f32>(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), vec3<f32>(0.0));
    m = m * m;
    m = m * m;
    
    let x = 2.0 * fract(p * C.www) - 1.0;
    let h = abs(x) - 0.5;
    let ox = floor(x + 0.5);
    let a0 = x - ox;
    
    m = m * (1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h));
    
    let g = vec3<f32>(a0.x * x0.x + h.x * x0.y, a0.y * x12.x + h.y * x12.y, a0.z * x12.z + h.z * x12.w);
    return 130.0 * dot(m, g);
}

// 3D simplex noise
fn simplexNoise3(p: vec3<f32>) -> f32 {
    let s = vec3<f32>(7.0, 157.0, 113.0);
    var ip = floor(p);
    var fp = fract(p);
    fp = fp * fp * (3.0 - 2.0 * fp);
    
    var h = dot(ip, s);
    let n000 = hash11(u32(h));
    let n100 = hash11(u32(h + s.x));
    let n010 = hash11(u32(h + s.y));
    let n110 = hash11(u32(h + s.x + s.y));
    let n001 = hash11(u32(h + s.z));
    let n101 = hash11(u32(h + s.x + s.z));
    let n011 = hash11(u32(h + s.y + s.z));
    let n111 = hash11(u32(h + s.x + s.y + s.z));
    
    let n00 = mix(n000, n100, fp.x);
    let n01 = mix(n001, n101, fp.x);
    let n10 = mix(n010, n110, fp.x);
    let n11 = mix(n011, n111, fp.x);
    
    let n0 = mix(n00, n10, fp.y);
    let n1 = mix(n01, n11, fp.y);
    
    return mix(n0, n1, fp.z);
}

// Fractal Brownian Motion
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

// ============================================================================
// PLANET FEATURE FUNCTIONS
// ============================================================================

// Crater generation
fn craters(p: vec3<f32>, density: f32, size: f32) -> f32 {
    if density < 0.01 {
        return 0.0;
    }
    
    var crater_effect = 0.0;
    let scales = array<f32, 3>(1.0, 2.3, 4.7);
    
    for (var i = 0; i < 3; i = i + 1) {
        let scale = scales[i] * 5.0 / size;
        let scaled_p = p * scale;
        let cell = floor(scaled_p);
        let local = fract(scaled_p);
        
        for (var x = -1; x <= 1; x = x + 1) {
            for (var y = -1; y <= 1; y = y + 1) {
                for (var z = -1; z <= 1; z = z + 1) {
                    let offset = vec3<f32>(f32(x), f32(y), f32(z));
                    let cell_id = cell + offset;
                    let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                    
                    if h > (1.0 - density * 0.2) {
                        let crater_pos = hash33(cell_id * 1.3 + vec3<f32>(f32(params.seed)));
                        let to_crater = local - offset - (crater_pos - 0.5);
                        let dist = length(to_crater);
                        let crater_radius = 0.3 + 0.2 * hash31(cell_id * 2.7);
                        
                        if dist < crater_radius {
                            let depth = smoothstep(crater_radius, crater_radius * 0.3, dist);
                            let rim = smoothstep(crater_radius * 0.9, crater_radius * 0.7, dist) * 
                                     smoothstep(crater_radius * 0.5, crater_radius * 0.6, dist);
                            crater_effect += (depth * -0.4 + rim * 0.2) * (1.0 / f32(i + 1));
                        }
                    }
                }
            }
        }
    }
    
    return crater_effect;
}

// Continent generation
fn continents(p: vec3<f32>, continent_size: f32, ocean_level: f32) -> f32 {
    let scale = mix(0.8, 3.0, 1.0 - continent_size);
    let base = fbm(p * scale, 4u, 2.1, 0.5);
    let detail = fbm(p * scale * 3.0, 3u, 2.3, 0.4);
    
    let height = base * 0.7 + detail * 0.3;
    return smoothstep(ocean_level - 0.1, ocean_level + 0.1, height);
}

// Mountain ranges
fn mountains(p: vec3<f32>, height: f32, roughness: f32) -> f32 {
    if height < 0.01 {
        return 0.0;
    }
    
    let ridged = abs(fbm(p * 2.0, 5u, 2.2, 0.5));
    let peaks = fbm(p * 1.0, 3u, 2.0, 0.6);
    
    return (1.0 - ridged) * peaks * height * (1.0 + roughness);
}

// Volcanic activity
fn volcanoes(p: vec3<f32>, density: f32) -> vec2<f32> {
    if density < 0.01 {
        return vec2<f32>(0.0);
    }
    
    var height = 0.0;
    var glow = 0.0;
    
    let scale = 4.0;
    let scaled_p = p * scale;
    let cell = floor(scaled_p);
    let local = fract(scaled_p);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - density * 0.15) {
                    let volcano_pos = hash33(cell_id * 1.7);
                    let to_volcano = local - offset - (volcano_pos - 0.5);
                    let dist = length(to_volcano);
                    
                    if dist < 0.4 {
                        let cone = smoothstep(0.4, 0.1, dist) * 0.3;
                        let caldera = smoothstep(0.15, 0.1, dist) * -0.1;
                        height += cone + caldera;
                        
                        let activity = hash31(cell_id * 3.1);
                        glow += smoothstep(0.2, 0.0, dist) * activity;
                    }
                }
            }
        }
    }
    
    return vec2<f32>(height, glow);
}

// Ice caps (polar regions)
fn ice_caps(p: vec3<f32>, size: f32) -> f32 {
    let polar = abs(p.y);
    let threshold = 1.0 - size;
    let ice = smoothstep(threshold, threshold + 0.2, polar);
    let noise_variation = simplexNoise3(p * 5.0) * 0.1;
    return clamp(ice + noise_variation, 0.0, 1.0);
}

// Gas giant bands
fn gas_bands(p: vec3<f32>, band_count: f32) -> f32 {
    let latitude = p.y;
    let bands = sin(latitude * band_count * 3.14159 * 2.0);
    let turbulence = fbm(vec3<f32>(p.x, p.y * 2.0, p.z) * 3.0, 4u, 2.2, 0.5);
    return bands * 0.5 + 0.5 + turbulence * 0.3;
}

// Storms (for gas giants or atmospheric effects)
fn storms(p: vec3<f32>, intensity: f32, spot_density: f32) -> f32 {
    if intensity < 0.01 {
        return 0.0;
    }
    
    var storm_value = 0.0;
    let scale = 3.0;
    let scaled_p = p * scale;
    let cell = floor(scaled_p);
    let local = fract(scaled_p);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - spot_density * 0.2) {
                    let storm_pos = hash33(cell_id * 2.3);
                    let to_storm = local - offset - (storm_pos - 0.5);
                    let dist = length(to_storm);
                    
                    let storm_size = 0.2 + 0.15 * hash31(cell_id * 1.9);
                    if dist < storm_size {
                        let swirl = simplexNoise3(p * 8.0 + vec3<f32>(params.time * 0.1));
                        storm_value += smoothstep(storm_size, storm_size * 0.3, dist) * (0.5 + swirl * 0.5);
                    }
                }
            }
        }
    }
    
    return storm_value * intensity;
}

// Star corona effect
fn corona(p: vec3<f32>, normal: vec3<f32>, intensity: f32) -> f32 {
    if intensity < 0.01 {
        return 0.0;
    }
    
    let turbulence = fbm(p * 2.0 + vec3<f32>(params.time * 0.2), 5u, 2.3, 0.5);
    let prominences = fbm(p * 5.0 + vec3<f32>(params.time * 0.3), 3u, 2.0, 0.6);
    
    return (turbulence * 0.7 + prominences * 0.3) * intensity;
}

// Sun spots / surface activity
fn surface_activity(p: vec3<f32>, activity: f32) -> f32 {
    if activity < 0.01 {
        return 0.0;
    }
    
    let spots = fbm(p * 4.0, 3u, 2.1, 0.5);
    let granulation = simplexNoise3(p * 20.0) * 0.1;
    
    return (spots * 0.9 + granulation) * activity;
}

// ============================================================================
// PLANET TYPE GENERATORS
// ============================================================================

struct SurfaceData {
    height: f32,
    roughness: f32,
    color: vec3<f32>,
    metallic: f32,
    emissive: vec3<f32>,
}

fn generate_rocky_planet(p: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Base terrain
    let terrain = fbm(p * 2.0, params.terrain_octaves, params.terrain_lacunarity, 0.5);
    let land = continents(p, params.continent_size, params.ocean_level);
    let mountain = mountains(p, params.mountain_height, params.roughness) * land;
    let crater = craters(p, params.crater_density, params.crater_size);
    
    data.height = terrain * 0.3 + mountain * 0.5 + crater * 0.2;
    data.roughness = 0.7 + params.roughness * 0.3;
    
    // Color variation based on height
    let rock_color = mix(params.color_primary.rgb, params.color_secondary.rgb, clamp(data.height + 0.5, 0.0, 1.0));
    let ocean_color = params.color_tertiary.rgb;
    
    data.color = mix(ocean_color, rock_color, land);
    data.metallic = 0.0;
    data.emissive = vec3<f32>(0.0);
    
    return data;
}

fn generate_desert_planet(p: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Sand dunes
    let dunes = fbm(p * 3.0, 5u, 2.0, 0.6);
    let fine_detail = simplexNoise3(p * 10.0) * 0.1;
    let crater = craters(p, params.crater_density, params.crater_size);
    
    data.height = dunes * 0.6 + fine_detail + crater * 0.3;
    data.roughness = 0.5 + params.roughness * 0.3;
    
    // Desert color variations
    let sand_variation = simplexNoise3(p * 5.0) * 0.5 + 0.5;
    data.color = mix(params.color_primary.rgb, params.color_secondary.rgb, sand_variation);
    
    data.metallic = 0.0;
    data.emissive = vec3<f32>(0.0);
    
    return data;
}

fn generate_lava_planet(p: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Volcanic terrain
    let base_terrain = fbm(p * 2.0, 4u, 2.2, 0.5);
    let volcano_data = volcanoes(p, params.volcano_density);
    let cracks = abs(simplexNoise3(p * 8.0)) * 0.2;
    
    data.height = base_terrain * 0.5 + volcano_data.x;
    data.roughness = 0.8;
    
    // Lava glow in cracks and volcanoes
    let lava_intensity = volcano_data.y + (1.0 - cracks) * 0.5;
    let lava_pulse = sin(params.time * 2.0 + simplexNoise3(p * 5.0) * 6.28) * 0.5 + 0.5;
    
    data.color = mix(params.color_primary.rgb, vec3<f32>(0.1, 0.05, 0.0), cracks);
    data.metallic = 0.0;
    data.emissive = params.color_secondary.rgb * lava_intensity * (0.8 + lava_pulse * 0.2) * 3.0;
    
    return data;
}

fn generate_ice_planet(p: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Icy terrain
    let base = fbm(p * 2.5, 4u, 2.1, 0.5);
    let ice_formations = abs(simplexNoise3(p * 5.0)) * 0.3;
    let crater = craters(p, params.crater_density, params.crater_size);
    
    data.height = base * 0.4 + ice_formations + crater * 0.2;
    data.roughness = 0.2 + params.roughness * 0.3;
    
    // Ice color with blue tint
    let ice_variation = simplexNoise3(p * 8.0) * 0.5 + 0.5;
    data.color = mix(params.color_primary.rgb, params.color_secondary.rgb, ice_variation);
    
    data.metallic = 0.1;
    data.emissive = vec3<f32>(0.0);
    
    return data;
}

fn generate_gas_giant(p: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Atmospheric bands
    let bands = gas_bands(p, params.bands_count);
    let storm = storms(p, params.storm_intensity, params.spot_density);
    let turbulence = fbm(vec3<f32>(p.x + params.time * 0.05, p.y, p.z) * 3.0, 4u, 2.2, 0.5);
    
    data.height = (bands + storm) * 0.05;  // Very subtle height variation
    data.roughness = 0.3;
    
    // Band coloring
    let color_mix = bands + turbulence * 0.3;
    let band_color = mix(
        mix(params.color_primary.rgb, params.color_secondary.rgb, clamp(color_mix, 0.0, 1.0)),
        params.color_tertiary.rgb,
        storm
    );
    
    data.color = band_color;
    data.metallic = 0.0;
    data.emissive = storm * params.color_secondary.rgb * 0.5;
    
    return data;
}

fn generate_moon(p: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Heavily cratered with minimal other features
    let base = fbm(p * 1.5, 3u, 2.0, 0.5) * 0.2;
    let crater = craters(p, params.crater_density * 2.0, params.crater_size);
    let fine_detail = simplexNoise3(p * 15.0) * 0.05;
    
    data.height = base + crater + fine_detail;
    data.roughness = 0.9;
    
    // Monotone gray coloring
    let color_variation = simplexNoise3(p * 7.0) * 0.1 + 0.5;
    data.color = params.color_primary.rgb * color_variation;
    
    data.metallic = 0.0;
    data.emissive = vec3<f32>(0.0);
    
    return data;
}

fn generate_star(p: vec3<f32>, normal: vec3<f32>) -> SurfaceData {
    var data: SurfaceData;
    
    // Surface activity
    let activity = surface_activity(p, params.surface_activity);
    let corona_effect = corona(p, normal, params.corona_intensity);
    let granulation = simplexNoise3(p * 15.0 + vec3<f32>(params.time * 0.5)) * 0.5 + 0.5;
    
    data.height = activity * 0.1;
    data.roughness = 0.5;
    
    // Star color (temperature-based)
    let temp_variation = activity * 0.3;
    data.color = mix(params.color_primary.rgb, params.color_secondary.rgb, temp_variation);
    
    data.metallic = 0.0;
    
    // Strong emission
    let pulse = sin(params.time * 3.0 + granulation * 6.28) * 0.5 + 0.5;
    let emission_intensity = 1.0 + (1.0 - activity) * 0.5 + corona_effect * 2.0 + pulse * 0.3;
    data.emissive = data.color * emission_intensity * 5.0;
    
    return data;
}

// ============================================================================
// ATMOSPHERIC EFFECTS
// ============================================================================

struct AtmosphereData {
    color: vec3<f32>,
    density: f32,
    clouds: f32,
}

fn calculate_atmosphere(p: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>) -> AtmosphereData {
    var atmo: AtmosphereData;
    
    if params.atmosphere_thickness < 0.01 {
        atmo.color = vec3<f32>(0.0);
        atmo.density = 0.0;
        atmo.clouds = 0.0;
        return atmo;
    }
    
    // Fresnel-like atmosphere
    let n_dot_v = max(dot(normal, -view_dir), 0.0);
    let fresnel = pow(1.0 - n_dot_v, params.atmosphere_falloff);
    
    atmo.density = fresnel * params.atmosphere_thickness;
    atmo.color = params.color_atmosphere.rgb;
    
    // Cloud layer
    if params.cloud_coverage > 0.01 {
        let cloud_pos = p * (1.0 + params.cloud_height * 0.1);
        let cloud_base = fbm(cloud_pos * 3.0 + vec3<f32>(params.time * 0.02, 0.0, 0.0), 4u, 2.2, 0.5);
        let cloud_detail = simplexNoise3(cloud_pos * 10.0 + vec3<f32>(params.time * 0.05));
        
        atmo.clouds = smoothstep(1.0 - params.cloud_coverage, 1.0, cloud_base + cloud_detail * 0.2);
    } else {
        atmo.clouds = 0.0;
    }
    
    return atmo;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fragment(
    mesh: MeshVertexOutput,
) -> @location(0) vec4<f32> {
    // Get sphere-space position (normalized)
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
    
    // Seed the noise with planet seed
    let seeded_p = rotated_p + vec3<f32>(f32(params.seed) * 0.001);
    
    // Generate surface based on planet type
    var surface: SurfaceData;
    
    if params.planet_type == 0u {
        surface = generate_rocky_planet(seeded_p);
    } else if params.planet_type == 1u {
        surface = generate_desert_planet(seeded_p);
    } else if params.planet_type == 2u {
        surface = generate_lava_planet(seeded_p);
    } else if params.planet_type == 3u {
        surface = generate_ice_planet(seeded_p);
    } else if params.planet_type == 4u {
        surface = generate_gas_giant(seeded_p);
    } else if params.planet_type == 5u {
        surface = generate_moon(seeded_p);
    } else if params.planet_type == 6u {
        surface = generate_star(seeded_p, mesh.world_normal);
    } else {
        surface = generate_rocky_planet(seeded_p);
    }
    
    // Calculate atmosphere and clouds (not for stars)
    var final_color = surface.color;
    var final_emissive = surface.emissive;
    
    if params.planet_type != 6u {
        let view_dir = normalize(world_pos - mesh.world_position.xyz);
        let atmo = calculate_atmosphere(seeded_p, mesh.world_normal, view_dir);
        
        // Blend clouds
        if atmo.clouds > 0.0 {
            let cloud_color = vec3<f32>(1.0, 1.0, 1.0);
            final_color = mix(final_color, cloud_color, atmo.clouds * 0.8);
        }
        
        // Add atmospheric glow
        final_color = mix(final_color, atmo.color, atmo.density * 0.3);
    }
    
    // Ice caps (for applicable planet types)
    if params.ice_cap_size > 0.01 && (params.planet_type == 0u || params.planet_type == 3u) {
        let ice = ice_caps(seeded_p, params.ice_cap_size);
        final_color = mix(final_color, vec3<f32>(0.9, 0.95, 1.0), ice);
    }
    
    // City lights on night side (for rocky planets)
    if params.city_lights > 0.01 && params.planet_type == 0u {
        let light_dir = normalize(vec3<f32>(1.0, 0.5, 0.3));  // Assumed sun direction
        let n_dot_l = dot(mesh.world_normal, light_dir);
        
        if n_dot_l < 0.0 {
            let cities = simplexNoise3(seeded_p * 20.0);
            let city_mask = step(0.7, cities);
            let city_glow = city_mask * params.city_lights * abs(n_dot_l);
            final_emissive += vec3<f32>(1.0, 0.8, 0.5) * city_glow * 0.5;
        }
    }
    
    // Combine everything
    let result = vec4<f32>(final_color + final_emissive, 1.0);
    
    return result;
}
