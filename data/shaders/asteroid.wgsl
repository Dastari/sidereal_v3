// Asteroid Shader - Procedural Mineral-Rich Space Rocks
// Designed for irregular meshes with triplanar projection
// Supports mineral seams, surface detail, and fracture consistency
//
// Features:
// - Triplanar projection (works on any mesh shape)
// - Multiple mineral types (coal, iron, copper, titanium, gems)
// - 3D mineral veins that persist through fractures
// - Surface craters and roughness
// - Glowing gem deposits
// - PBR materials per mineral type
// - Deterministic from seed (same asteroid always looks the same)

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput
#import bevy_pbr::pbr_types::StandardMaterial

struct AsteroidParams {
    // Identity
    seed: u32,
    asteroid_type: u32,  // 0=rocky, 1=metallic, 2=carbonaceous, 3=gem-rich, 4=ice
    
    // Base material properties
    base_color: vec4<f32>,
    base_roughness: f32,
    base_metallic: f32,
    
    // Surface detail
    crater_density: f32,
    crater_size: f32,
    surface_roughness: f32,
    surface_scale: f32,
    detail_octaves: u32,
    
    // Mineral deposits (0.0 = none, 1.0 = abundant)
    coal_density: f32,
    iron_density: f32,
    copper_density: f32,
    titanium_density: f32,
    
    // Gem deposits (glowing)
    ruby_density: f32,       // Red
    topaz_density: f32,      // Yellow
    emerald_density: f32,    // Green
    sapphire_density: f32,   // Blue
    diamond_density: f32,    // White/clear
    
    // Mineral vein properties
    vein_scale: f32,
    vein_thickness: f32,
    vein_contrast: f32,
    
    // Gem glow
    gem_glow_strength: f32,
    gem_glow_radius: f32,
    
    // Surface variation
    color_variation: f32,
    wear_amount: f32,        // Weathering/pitting
    
    // Technical
    triplanar_sharpness: f32,
    normal_strength: f32,
    
    // Fragment tracking (for consistent minerals across pieces)
    fragment_id: u32,        // Unique per fragment after break
    parent_seed: u32,        // Original asteroid seed
}

@group(2) @binding(0) var<uniform> params: AsteroidParams;

const PI: f32 = 3.14159265359;

// ============================================================================
// HASH AND NOISE FUNCTIONS
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

fn fbm(p: vec3<f32>, octaves: u32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    
    for (var i = 0u; i < octaves; i = i + 1u) {
        value += amplitude * noise3d(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// Voronoi-based cell pattern for mineral veins
fn voronoi(p: vec3<f32>) -> vec2<f32> {
    let cell = floor(p);
    let local = fract(p);
    
    var min_dist = 8.0;
    var second_min = 8.0;
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let point = hash33(cell_id + vec3<f32>(f32(params.parent_seed)));
                let to_point = offset + point - local;
                let dist = length(to_point);
                
                if dist < min_dist {
                    second_min = min_dist;
                    min_dist = dist;
                } else if dist < second_min {
                    second_min = dist;
                }
            }
        }
    }
    
    return vec2<f32>(min_dist, second_min);
}

// ============================================================================
// TRIPLANAR PROJECTION
// ============================================================================

struct TriplanarWeights {
    x: f32,
    y: f32,
    z: f32,
}

fn calculate_triplanar_weights(normal: vec3<f32>, sharpness: f32) -> TriplanarWeights {
    var weights: TriplanarWeights;
    
    // Calculate blend weights based on normal
    let blend = abs(normal);
    let blend_pow = pow(blend, vec3<f32>(sharpness));
    let blend_sum = blend_pow.x + blend_pow.y + blend_pow.z;
    
    weights.x = blend_pow.x / blend_sum;
    weights.y = blend_pow.y / blend_sum;
    weights.z = blend_pow.z / blend_sum;
    
    return weights;
}

fn sample_triplanar(pos: vec3<f32>, normal: vec3<f32>, scale: f32) -> f32 {
    let weights = calculate_triplanar_weights(normal, params.triplanar_sharpness);
    
    let sample_x = fbm(pos.yzx * scale, params.detail_octaves);
    let sample_y = fbm(pos.xzy * scale, params.detail_octaves);
    let sample_z = fbm(pos.xyz * scale, params.detail_octaves);
    
    return sample_x * weights.x + sample_y * weights.y + sample_z * weights.z;
}

// ============================================================================
// MINERAL VEIN GENERATION
// ============================================================================

struct MineralData {
    mineral_type: u32,  // 0=none, 1=coal, 2=iron, 3=copper, 4=titanium, 5-9=gems
    intensity: f32,
    is_gem: bool,
}

fn sample_mineral_vein(p: vec3<f32>, mineral_scale: f32, density: f32, mineral_id: u32) -> f32 {
    if density < 0.01 {
        return 0.0;
    }
    
    // 3D vein structure using voronoi cells
    let scaled_p = p * mineral_scale * params.vein_scale;
    let vor = voronoi(scaled_p + vec3<f32>(f32(mineral_id) * 100.0));
    
    // Vein pattern (edge between voronoi cells)
    let vein = abs(vor.y - vor.x);
    let vein_mask = smoothstep(params.vein_thickness * 0.8, params.vein_thickness * 0.2, vein);
    
    // Add noise variation to veins
    let noise_var = fbm(scaled_p * 2.0, 3u) * 0.5 + 0.5;
    
    // Density gates which areas have veins
    let density_noise = hash31(floor(scaled_p) + vec3<f32>(f32(mineral_id) * 73.0));
    let density_mask = step(1.0 - density, density_noise);
    
    return vein_mask * noise_var * density_mask;
}

fn get_dominant_mineral(p: vec3<f32>) -> MineralData {
    var mineral: MineralData;
    mineral.mineral_type = 0u;
    mineral.intensity = 0.0;
    mineral.is_gem = false;
    
    var max_intensity = 0.0;
    
    // Check each mineral type
    // Coal (1)
    let coal = sample_mineral_vein(p, 3.0, params.coal_density, 1u);
    if coal > max_intensity {
        max_intensity = coal;
        mineral.mineral_type = 1u;
        mineral.intensity = coal;
    }
    
    // Iron (2)
    let iron = sample_mineral_vein(p, 4.0, params.iron_density, 2u);
    if iron > max_intensity {
        max_intensity = iron;
        mineral.mineral_type = 2u;
        mineral.intensity = iron;
    }
    
    // Copper (3)
    let copper = sample_mineral_vein(p, 5.0, params.copper_density, 3u);
    if copper > max_intensity {
        max_intensity = copper;
        mineral.mineral_type = 3u;
        mineral.intensity = copper;
    }
    
    // Titanium (4)
    let titanium = sample_mineral_vein(p, 6.0, params.titanium_density, 4u);
    if titanium > max_intensity {
        max_intensity = titanium;
        mineral.mineral_type = 4u;
        mineral.intensity = titanium;
    }
    
    // Gems (rarer, smaller veins)
    // Ruby (5) - Red
    let ruby = sample_mineral_vein(p, 8.0, params.ruby_density, 5u) * 
               smoothstep(0.3, 0.5, fbm(p * 10.0, 2u));
    if ruby > max_intensity {
        max_intensity = ruby;
        mineral.mineral_type = 5u;
        mineral.intensity = ruby;
        mineral.is_gem = true;
    }
    
    // Topaz (6) - Yellow
    let topaz = sample_mineral_vein(p, 8.0, params.topaz_density, 6u) * 
                smoothstep(0.3, 0.5, fbm(p * 10.0 + vec3<f32>(50.0), 2u));
    if topaz > max_intensity {
        max_intensity = topaz;
        mineral.mineral_type = 6u;
        mineral.intensity = topaz;
        mineral.is_gem = true;
    }
    
    // Emerald (7) - Green
    let emerald = sample_mineral_vein(p, 8.0, params.emerald_density, 7u) * 
                  smoothstep(0.3, 0.5, fbm(p * 10.0 + vec3<f32>(100.0), 2u));
    if emerald > max_intensity {
        max_intensity = emerald;
        mineral.mineral_type = 7u;
        mineral.intensity = emerald;
        mineral.is_gem = true;
    }
    
    // Sapphire (8) - Blue
    let sapphire = sample_mineral_vein(p, 8.0, params.sapphire_density, 8u) * 
                   smoothstep(0.3, 0.5, fbm(p * 10.0 + vec3<f32>(150.0), 2u));
    if sapphire > max_intensity {
        max_intensity = sapphire;
        mineral.mineral_type = 8u;
        mineral.intensity = sapphire;
        mineral.is_gem = true;
    }
    
    // Diamond (9) - White/Clear
    let diamond = sample_mineral_vein(p, 8.0, params.diamond_density, 9u) * 
                  smoothstep(0.3, 0.5, fbm(p * 10.0 + vec3<f32>(200.0), 2u));
    if diamond > max_intensity {
        max_intensity = diamond;
        mineral.mineral_type = 9u;
        mineral.intensity = diamond;
        mineral.is_gem = true;
    }
    
    // Apply contrast
    mineral.intensity = pow(mineral.intensity, 1.0 / max(params.vein_contrast, 0.1));
    
    return mineral;
}

// ============================================================================
// MATERIAL PROPERTIES
// ============================================================================

struct MaterialProps {
    color: vec3<f32>,
    roughness: f32,
    metallic: f32,
    emissive: vec3<f32>,
}

fn get_mineral_properties(mineral_type: u32) -> MaterialProps {
    var props: MaterialProps;
    props.emissive = vec3<f32>(0.0);
    
    if mineral_type == 0u {
        // Base rock
        props.color = params.base_color.rgb;
        props.roughness = params.base_roughness;
        props.metallic = params.base_metallic;
    } else if mineral_type == 1u {
        // Coal - black, rough, non-metallic
        props.color = vec3<f32>(0.1, 0.1, 0.12);
        props.roughness = 0.9;
        props.metallic = 0.0;
    } else if mineral_type == 2u {
        // Iron - dark gray, metallic
        props.color = vec3<f32>(0.4, 0.4, 0.45);
        props.roughness = 0.6;
        props.metallic = 0.8;
    } else if mineral_type == 3u {
        // Copper - orange-brown, metallic
        props.color = vec3<f32>(0.8, 0.5, 0.3);
        props.roughness = 0.4;
        props.metallic = 0.9;
    } else if mineral_type == 4u {
        // Titanium - light gray, metallic
        props.color = vec3<f32>(0.6, 0.65, 0.7);
        props.roughness = 0.3;
        props.metallic = 0.95;
    } else if mineral_type == 5u {
        // Ruby - red gem
        props.color = vec3<f32>(0.8, 0.1, 0.15);
        props.roughness = 0.1;
        props.metallic = 0.0;
        props.emissive = vec3<f32>(0.5, 0.05, 0.05) * params.gem_glow_strength;
    } else if mineral_type == 6u {
        // Topaz - yellow gem
        props.color = vec3<f32>(1.0, 0.8, 0.2);
        props.roughness = 0.1;
        props.metallic = 0.0;
        props.emissive = vec3<f32>(0.5, 0.4, 0.05) * params.gem_glow_strength;
    } else if mineral_type == 7u {
        // Emerald - green gem
        props.color = vec3<f32>(0.1, 0.8, 0.2);
        props.roughness = 0.1;
        props.metallic = 0.0;
        props.emissive = vec3<f32>(0.05, 0.5, 0.1) * params.gem_glow_strength;
    } else if mineral_type == 8u {
        // Sapphire - blue gem
        props.color = vec3<f32>(0.1, 0.3, 0.9);
        props.roughness = 0.1;
        props.metallic = 0.0;
        props.emissive = vec3<f32>(0.05, 0.15, 0.5) * params.gem_glow_strength;
    } else if mineral_type == 9u {
        // Diamond - white/clear gem
        props.color = vec3<f32>(0.95, 0.95, 1.0);
        props.roughness = 0.05;
        props.metallic = 0.0;
        props.emissive = vec3<f32>(0.4, 0.4, 0.5) * params.gem_glow_strength;
    } else {
        // Fallback
        props.color = params.base_color.rgb;
        props.roughness = params.base_roughness;
        props.metallic = params.base_metallic;
    }
    
    return props;
}

// ============================================================================
// SURFACE DETAIL
// ============================================================================

fn surface_craters(p: vec3<f32>, normal: vec3<f32>) -> f32 {
    if params.crater_density < 0.01 {
        return 0.0;
    }
    
    var crater_effect = 0.0;
    let scale = 5.0 / max(params.crater_size, 0.1);
    let scaled_p = p * scale;
    let cell = floor(scaled_p);
    let local = fract(scaled_p);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - params.crater_density * 0.3) {
                    let crater_pos = hash33(cell_id * 1.3);
                    let to_crater = local - offset - (crater_pos - 0.5);
                    let dist = length(to_crater);
                    let crater_radius = 0.2 + hash31(cell_id * 2.7) * 0.15;
                    
                    if dist < crater_radius {
                        let depth = smoothstep(crater_radius, crater_radius * 0.4, dist);
                        crater_effect = max(crater_effect, depth * 0.3);
                    }
                }
            }
        }
    }
    
    return crater_effect;
}

fn surface_wear(p: vec3<f32>) -> f32 {
    if params.wear_amount < 0.01 {
        return 0.0;
    }
    
    // Weathering/pitting pattern
    let wear_pattern = fbm(p * 20.0, 4u);
    let pitting = smoothstep(0.4, 0.6, wear_pattern);
    
    return pitting * params.wear_amount * 0.2;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fragment(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    let world_pos = mesh.world_position.xyz;
    let world_normal = normalize(mesh.world_normal);
    
    // Seed the position with asteroid's parent seed for consistency across fragments
    let seeded_pos = world_pos + vec3<f32>(f32(params.parent_seed) * 0.001);
    
    // Base surface detail using triplanar projection
    let surface_detail = sample_triplanar(seeded_pos, world_normal, params.surface_scale);
    
    // Get dominant mineral at this location
    let mineral = get_dominant_mineral(seeded_pos);
    
    // Get material properties
    let base_props = get_mineral_properties(0u);
    let mineral_props = get_mineral_properties(mineral.mineral_type);
    
    // Blend base and mineral
    let blend_factor = mineral.intensity;
    var final_color = mix(base_props.color, mineral_props.color, blend_factor);
    var final_roughness = mix(base_props.roughness, mineral_props.roughness, blend_factor);
    var final_metallic = mix(base_props.metallic, mineral_props.metallic, blend_factor);
    var final_emissive = mineral_props.emissive * blend_factor;
    
    // Add surface detail variation to base color
    let detail_variation = (surface_detail - 0.5) * params.color_variation;
    final_color *= (1.0 + detail_variation);
    
    // Add craters (darken slightly)
    let craters = surface_craters(seeded_pos, world_normal);
    final_color *= (1.0 - craters * 0.5);
    final_roughness = mix(final_roughness, 1.0, craters);
    
    // Add wear
    let wear = surface_wear(seeded_pos);
    final_roughness += wear;
    
    // Enhance roughness variation
    final_roughness += (surface_detail - 0.5) * params.surface_roughness;
    final_roughness = clamp(final_roughness, 0.0, 1.0);
    
    // Gem glow affects nearby areas slightly
    if mineral.is_gem && params.gem_glow_radius > 0.01 {
        let glow_falloff = exp(-craters * 5.0);  // Less glow in craters
        final_emissive *= (1.0 + glow_falloff * params.gem_glow_radius);
    }
    
    // Output color with emissive
    let output_color = final_color + final_emissive;
    
    // Pack roughness and metallic into alpha channel for PBR (if needed)
    // For now, just output color
    return vec4<f32>(output_color, 1.0);
}

// ============================================================================
// OPTIONAL: Normal map generation support
// ============================================================================

@fragment
fn fragment_normal(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    let world_pos = mesh.world_position.xyz;
    let world_normal = normalize(mesh.world_normal);
    let seeded_pos = world_pos + vec3<f32>(f32(params.parent_seed) * 0.001);
    
    // Sample height at this point and nearby points
    let epsilon = 0.01;
    
    let h = sample_triplanar(seeded_pos, world_normal, params.surface_scale);
    let h_x = sample_triplanar(seeded_pos + vec3<f32>(epsilon, 0.0, 0.0), world_normal, params.surface_scale);
    let h_y = sample_triplanar(seeded_pos + vec3<f32>(0.0, epsilon, 0.0), world_normal, params.surface_scale);
    let h_z = sample_triplanar(seeded_pos + vec3<f32>(0.0, 0.0, epsilon), world_normal, params.surface_scale);
    
    // Compute gradient
    let dx = (h_x - h) / epsilon;
    let dy = (h_y - h) / epsilon;
    let dz = (h_z - h) / epsilon;
    
    // Create normal perturbation
    var perturbed_normal = normalize(world_normal - vec3<f32>(dx, dy, dz) * params.normal_strength);
    
    // Transform to [0, 1] range for storage
    perturbed_normal = perturbed_normal * 0.5 + 0.5;
    
    return vec4<f32>(perturbed_normal, 1.0);
}
