// Space Background Shader - Nebulas, Stars, Galaxies, and Lightning
// Deterministic procedural space environment for different star systems
// Renders on a skybox or background plane
//
// Features:
// - Multiple nebula layers with color mixing
// - Various star types (points, glowing, clusters)
// - Distant galaxies
// - Nebula lightning/electrical discharges
// - Dust clouds and wisps
// - Emissive color output for scene lighting
//
// Based on techniques from:
// - Shadertoy nebula shaders
// - Volume rendering approaches
// - Perlin/Simplex noise FBM

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput

struct SpaceParams {
    // Environment seed and identity
    seed: u32,
    environment_type: u32,  // 0=bleak, 1=moderate, 2=vibrant, 3=chaotic
    
    // Nebula settings
    nebula_density: f32,
    nebula_scale: f32,
    nebula_detail: u32,           // Octaves (3-8)
    nebula_sharpness: f32,        // Contrast
    nebula_flow: f32,             // Swirling motion strength
    
    // Nebula colors (can blend up to 4 colors)
    nebula_color1: vec4<f32>,
    nebula_color2: vec4<f32>,
    nebula_color3: vec4<f32>,
    nebula_color4: vec4<f32>,
    nebula_color_mix: vec4<f32>,  // Weight of each color
    
    // Star field settings
    star_density: f32,
    star_brightness: f32,
    star_size_variation: f32,
    star_twinkle: f32,
    star_color_variation: f32,
    
    // Distant stars/galaxies
    distant_star_density: f32,
    distant_star_size: f32,
    galaxy_density: f32,
    galaxy_brightness: f32,
    
    // Lightning/electrical effects
    lightning_frequency: f32,
    lightning_intensity: f32,
    lightning_color: vec3<f32>,
    lightning_thickness: f32,
    lightning_branches: f32,
    
    // Dust and wisps
    dust_density: f32,
    dust_brightness: f32,
    wisp_density: f32,
    wisp_flow: f32,
    
    // Global lighting emission
    emission_strength: f32,
    ambient_color: vec3<f32>,
    ambient_intensity: f32,
    
    // Animation
    time: f32,
    time_scale: f32,
    
    // Camera (for parallax effects if desired)
    camera_position: vec3<f32>,
    parallax_strength: f32,
}

@group(2) @binding(0) var<uniform> params: SpaceParams;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

// ============================================================================
// HASH AND NOISE FUNCTIONS
// ============================================================================

fn pcg(n: u32) -> u32 {
    var h = n * 747796405u + 2891336453u;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
    return (h >> 22u) ^ h;
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

fn hash31(p: vec3<f32>) -> f32 {
    let pi = vec3<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y), bitcast<u32>(p.z));
    return f32(pcg3d(pi).x) / f32(0xffffffffu);
}

fn hash33(p: vec3<f32>) -> vec3<f32> {
    let pi = vec3<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y), bitcast<u32>(p.z));
    let h = pcg3d(pi);
    return vec3<f32>(h) / f32(0xffffffffu);
}

// 3D noise
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

// Fractal Brownian Motion
fn fbm(p: vec3<f32>, octaves: u32, lacunarity: f32, gain: f32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var pos = p;
    
    for (var i = 0u; i < octaves; i = i + 1u) {
        value += amplitude * noise3d(pos * frequency);
        frequency *= lacunarity;
        amplitude *= gain;
    }
    
    return value;
}

// Turbulent FBM (absolute values for more dramatic effect)
fn turbulence(p: vec3<f32>, octaves: u32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    
    for (var i = 0u; i < octaves; i = i + 1u) {
        value += amplitude * abs(noise3d(p * frequency) * 2.0 - 1.0);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// Domain warping for organic flow
fn domain_warp(p: vec3<f32>, strength: f32) -> vec3<f32> {
    let q = vec3<f32>(
        fbm(p + vec3<f32>(0.0, 0.0, 0.0), 4u, 2.0, 0.5),
        fbm(p + vec3<f32>(5.2, 1.3, 0.0), 4u, 2.0, 0.5),
        fbm(p + vec3<f32>(0.0, 0.0, 8.3), 4u, 2.0, 0.5)
    );
    
    let r = vec3<f32>(
        fbm(p + 4.0 * q + vec3<f32>(1.7, 9.2, 0.0), 4u, 2.0, 0.5),
        fbm(p + 4.0 * q + vec3<f32>(8.3, 2.8, 0.0), 4u, 2.0, 0.5),
        fbm(p + 4.0 * q + vec3<f32>(0.0, 0.0, 5.1), 4u, 2.0, 0.5)
    );
    
    return p + r * strength;
}

// ============================================================================
// STAR GENERATION
// ============================================================================

struct StarData {
    brightness: f32,
    color: vec3<f32>,
    glow_radius: f32,
}

// Point stars (distant)
fn generate_stars(uv: vec3<f32>, density: f32, size_var: f32) -> StarData {
    var star: StarData;
    star.brightness = 0.0;
    star.color = vec3<f32>(1.0);
    star.glow_radius = 0.0;
    
    if density < 0.01 {
        return star;
    }
    
    let scale = 20.0 / density;
    let cell = floor(uv * scale);
    let local = fract(uv * scale);
    
    var total_brightness = 0.0;
    var total_color = vec3<f32>(0.0);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed)));
                
                if h > (1.0 - density * 0.15) {
                    let star_pos = hash33(cell_id * 1.3 + vec3<f32>(f32(params.seed)));
                    let to_star = local - offset - (star_pos - 0.5);
                    let dist = length(to_star);
                    
                    let star_size = mix(0.002, 0.015, hash31(cell_id * 2.1) * size_var);
                    
                    if dist < star_size {
                        let intensity = smoothstep(star_size, 0.0, dist);
                        
                        // Star temperature variation (blue = hot, red = cool)
                        let temp = hash31(cell_id * 3.7);
                        var color: vec3<f32>;
                        if temp < 0.2 {
                            color = vec3<f32>(0.7, 0.8, 1.0);  // Blue
                        } else if temp < 0.5 {
                            color = vec3<f32>(1.0, 1.0, 1.0);  // White
                        } else if temp < 0.8 {
                            color = vec3<f32>(1.0, 0.9, 0.7);  // Yellow
                        } else {
                            color = vec3<f32>(1.0, 0.6, 0.4);  // Orange-red
                        }
                        
                        // Color variation
                        color = mix(color, vec3<f32>(1.0), 1.0 - params.star_color_variation);
                        
                        // Twinkle effect
                        let twinkle = 1.0;
                        if params.star_twinkle > 0.01 {
                            let twinkle_speed = hash31(cell_id * 4.3) * 3.0 + 1.0;
                            let twinkle_phase = params.time * twinkle_speed + hash31(cell_id * 5.1) * TAU;
                            let twinkle_amount = sin(twinkle_phase) * 0.5 + 0.5;
                            total_brightness += intensity * mix(1.0, twinkle_amount, params.star_twinkle);
                        } else {
                            total_brightness += intensity;
                        }
                        
                        total_color += color * intensity;
                    }
                }
            }
        }
    }
    
    if total_brightness > 0.0 {
        star.brightness = total_brightness * params.star_brightness;
        star.color = total_color / max(total_brightness, 0.001);
    }
    
    return star;
}

// Glowing bright stars (closer)
fn generate_bright_stars(uv: vec3<f32>) -> StarData {
    var star: StarData;
    star.brightness = 0.0;
    star.color = vec3<f32>(1.0);
    star.glow_radius = 0.0;
    
    let scale = 5.0;
    let cell = floor(uv * scale);
    let local = fract(uv * scale);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed) * 7.3));
                
                if h > 0.98 {  // Rare bright stars
                    let star_pos = hash33(cell_id * 2.7);
                    let to_star = local - offset - (star_pos - 0.5);
                    let dist = length(to_star);
                    
                    let core_radius = 0.01;
                    let glow_radius = 0.08;
                    
                    if dist < glow_radius {
                        // Core brightness
                        let core = smoothstep(core_radius, 0.0, dist);
                        
                        // Glow
                        let glow = smoothstep(glow_radius, core_radius, dist) * 0.3;
                        
                        // Cross flare
                        let angle = atan2(to_star.y, to_star.x);
                        let flare1 = pow(abs(sin(angle * 2.0)), 20.0) * smoothstep(glow_radius * 0.8, 0.0, dist);
                        let flare2 = pow(abs(cos(angle * 2.0)), 20.0) * smoothstep(glow_radius * 0.8, 0.0, dist);
                        
                        star.brightness += (core + glow + flare1 * 0.3 + flare2 * 0.3) * params.star_brightness;
                        
                        // Temperature-based color
                        let temp = hash31(cell_id * 4.9);
                        if temp < 0.3 {
                            star.color = vec3<f32>(0.7, 0.85, 1.0);
                        } else if temp < 0.7 {
                            star.color = vec3<f32>(1.0, 0.95, 0.85);
                        } else {
                            star.color = vec3<f32>(1.0, 0.7, 0.5);
                        }
                    }
                }
            }
        }
    }
    
    return star;
}

// Distant galaxies (spiral pattern hints)
fn generate_galaxies(uv: vec3<f32>) -> vec3<f32> {
    if params.galaxy_density < 0.01 {
        return vec3<f32>(0.0);
    }
    
    var galaxy_color = vec3<f32>(0.0);
    
    let scale = 3.0;
    let cell = floor(uv * scale);
    let local = fract(uv * scale);
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed) * 11.7));
                
                if h > (1.0 - params.galaxy_density * 0.05) {
                    let galaxy_pos = hash33(cell_id * 3.9);
                    let to_galaxy = local - offset - (galaxy_pos - 0.5);
                    let dist = length(to_galaxy.xy);  // Flatten to 2D
                    let angle = atan2(to_galaxy.y, to_galaxy.x);
                    
                    let galaxy_size = 0.03 + hash31(cell_id * 5.3) * 0.02;
                    
                    if dist < galaxy_size {
                        // Spiral structure hint
                        let spiral_arms = 3.0;
                        let spiral = sin(angle * spiral_arms + dist * 20.0);
                        
                        let core = exp(-dist * 30.0);
                        let disk = exp(-dist * 10.0) * (0.5 + spiral * 0.5);
                        
                        let intensity = (core * 0.7 + disk * 0.3) * params.galaxy_brightness;
                        
                        // Galaxy color (usually yellowish)
                        let gal_color = vec3<f32>(1.0, 0.9, 0.7);
                        galaxy_color += gal_color * intensity * 0.3;
                    }
                }
            }
        }
    }
    
    return galaxy_color;
}

// ============================================================================
// NEBULA GENERATION
// ============================================================================

fn generate_nebula(p: vec3<f32>) -> vec4<f32> {
    if params.nebula_density < 0.01 {
        return vec4<f32>(0.0);
    }
    
    // Apply domain warping for organic flow
    let warped = domain_warp(p * params.nebula_scale, params.nebula_flow);
    
    // Multi-layered nebula density
    let density1 = fbm(warped, params.nebula_detail, 2.2, 0.5);
    let density2 = fbm(warped * 2.3 + vec3<f32>(100.0), max(params.nebula_detail - 1u, 2u), 2.1, 0.55);
    let density3 = turbulence(warped * 0.7, max(params.nebula_detail - 2u, 2u));
    
    // Combine layers
    var combined_density = density1 * 0.5 + density2 * 0.3 + density3 * 0.2;
    combined_density = pow(combined_density, 1.0 / max(params.nebula_sharpness, 0.1));
    combined_density *= params.nebula_density;
    
    // Apply threshold for interesting shapes
    combined_density = smoothstep(0.3, 0.7, combined_density);
    
    if combined_density < 0.01 {
        return vec4<f32>(0.0);
    }
    
    // Color mixing based on density variations
    let color_noise = fbm(warped * 0.5, 3u, 2.0, 0.5);
    
    // Blend colors based on weights and local variation
    var nebula_color = vec3<f32>(0.0);
    let total_weight = params.nebula_color_mix.x + params.nebula_color_mix.y + 
                      params.nebula_color_mix.z + params.nebula_color_mix.w;
    
    if total_weight > 0.0 {
        let normalized_weights = params.nebula_color_mix / total_weight;
        
        // Add spatial variation to color mixing
        let mix_var1 = density1;
        let mix_var2 = density2;
        let mix_var3 = color_noise;
        
        nebula_color += params.nebula_color1.rgb * normalized_weights.x * mix_var1;
        nebula_color += params.nebula_color2.rgb * normalized_weights.y * mix_var2;
        nebula_color += params.nebula_color3.rgb * normalized_weights.z * (1.0 - mix_var1);
        nebula_color += params.nebula_color4.rgb * normalized_weights.w * mix_var3;
        
        nebula_color = nebula_color / max(mix_var1 * normalized_weights.x + 
                                         mix_var2 * normalized_weights.y + 
                                         (1.0 - mix_var1) * normalized_weights.z + 
                                         mix_var3 * normalized_weights.w, 0.001);
    } else {
        nebula_color = params.nebula_color1.rgb;
    }
    
    // Add some internal variation/brightness spots
    let bright_spots = pow(density3, 3.0) * 1.5;
    nebula_color *= (1.0 + bright_spots);
    
    return vec4<f32>(nebula_color, combined_density);
}

// ============================================================================
// LIGHTNING/ELECTRICAL EFFECTS
// ============================================================================

fn generate_lightning(p: vec3<f32>, nebula_density: f32) -> vec3<f32> {
    if params.lightning_frequency < 0.01 || nebula_density < 0.1 {
        return vec3<f32>(0.0);
    }
    
    var lightning = vec3<f32>(0.0);
    
    // Lightning occurs in areas of nebula
    let lightning_scale = 2.0;
    let cell = floor(p * lightning_scale);
    let local = fract(p * lightning_scale);
    
    let time_factor = params.time * params.time_scale;
    
    for (var x = -1; x <= 1; x = x + 1) {
        for (var y = -1; y <= 1; y = y + 1) {
            for (var z = -1; z <= 1; z = z + 1) {
                let offset = vec3<f32>(f32(x), f32(y), f32(z));
                let cell_id = cell + offset;
                let h = hash31(cell_id + vec3<f32>(f32(params.seed) * 13.1));
                
                if h > (1.0 - params.lightning_frequency * 0.1) {
                    // Lightning timing (flashing)
                    let flash_period = 2.0 + hash31(cell_id * 7.1) * 3.0;
                    let flash_phase = fract(time_factor / flash_period + hash31(cell_id * 8.3));
                    
                    var flash_intensity = 0.0;
                    if flash_phase < 0.05 {
                        // Quick bright flash
                        flash_intensity = smoothstep(0.0, 0.02, flash_phase) * 
                                        smoothstep(0.05, 0.03, flash_phase);
                    }
                    
                    if flash_intensity > 0.0 {
                        // Lightning bolt path
                        let start_pos = hash33(cell_id * 2.9);
                        let end_pos = hash33(cell_id * 4.1);
                        
                        // Main bolt
                        let bolt_dir = normalize(end_pos - start_pos);
                        let to_start = local - offset - (start_pos - 0.5);
                        let along = dot(to_start, bolt_dir);
                        
                        if along > 0.0 && along < length(end_pos - start_pos) {
                            let perp_dist = length(to_start - bolt_dir * along);
                            
                            // Add noise to bolt path
                            let noise_offset = noise3d((cell_id + vec3<f32>(along * 10.0)) * 5.0) * 0.02;
                            let dist_to_bolt = perp_dist - noise_offset;
                            
                            let bolt_thickness = params.lightning_thickness * 0.01;
                            
                            if dist_to_bolt < bolt_thickness {
                                let bolt_intensity = smoothstep(bolt_thickness, 0.0, dist_to_bolt);
                                lightning += params.lightning_color * 
                                           bolt_intensity * 
                                           flash_intensity * 
                                           params.lightning_intensity;
                            }
                            
                            // Branches
                            if params.lightning_branches > 0.01 {
                                let branch_count = u32(params.lightning_branches * 3.0);
                                for (var b = 0u; b < branch_count; b = b + 1u) {
                                    let branch_pos = hash31(cell_id * f32(b + 1) * 6.7);
                                    if branch_pos > 0.7 {
                                        let branch_point = along * branch_pos;
                                        let branch_dir = normalize(hash33(cell_id * f32(b + 1) * 5.9) - 0.5);
                                        let branch_to = to_start - bolt_dir * branch_point;
                                        let branch_along = dot(branch_to, branch_dir);
                                        
                                        if branch_along > 0.0 && branch_along < 0.3 {
                                            let branch_perp = length(branch_to - branch_dir * branch_along);
                                            let branch_thick = bolt_thickness * 0.5;
                                            
                                            if branch_perp < branch_thick {
                                                let branch_int = smoothstep(branch_thick, 0.0, branch_perp);
                                                lightning += params.lightning_color * 
                                                           branch_int * 
                                                           flash_intensity * 
                                                           params.lightning_intensity * 
                                                           0.5;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    return lightning;
}

// ============================================================================
// DUST AND WISPS
// ============================================================================

fn generate_dust(p: vec3<f32>) -> f32 {
    if params.dust_density < 0.01 {
        return 0.0;
    }
    
    // Fine dust particles
    let dust_noise = fbm(p * 5.0, 4u, 2.3, 0.4);
    let dust = pow(dust_noise, 2.0) * params.dust_density * params.dust_brightness;
    
    return dust * 0.3;
}

fn generate_wisps(p: vec3<f32>) -> f32 {
    if params.wisp_density < 0.01 {
        return 0.0;
    }
    
    // Flowing wispy structures
    let time_offset = params.time * params.time_scale * 0.1;
    let flow_p = p + vec3<f32>(time_offset * params.wisp_flow, 0.0, 0.0);
    
    let wisp1 = abs(sin(flow_p.x * 3.0 + noise3d(flow_p * 2.0) * 2.0));
    let wisp2 = abs(sin(flow_p.z * 2.5 + noise3d(flow_p * 1.7) * 2.0));
    
    let wisp = pow(wisp1 * wisp2, 5.0) * params.wisp_density;
    
    return wisp * 0.5;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fragment(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    // Get view direction (for skybox rendering)
    // For a background plane, this would be UV-based
    let view_dir = normalize(mesh.world_position.xyz);
    
    // Apply very subtle parallax if desired (almost none for distant background)
    let parallax_offset = params.camera_position * params.parallax_strength * 0.001;
    let sample_pos = view_dir - parallax_offset;
    
    // Seed the coordinate system
    let seeded_pos = sample_pos + vec3<f32>(f32(params.seed) * 0.001);
    
    // Generate all layers
    let nebula = generate_nebula(seeded_pos);
    let distant_stars = generate_stars(seeded_pos, params.distant_star_density, 0.3);
    let medium_stars = generate_stars(seeded_pos * 1.3, params.star_density, params.star_size_variation);
    let bright_stars = generate_bright_stars(seeded_pos);
    let galaxies = generate_galaxies(seeded_pos);
    let dust = generate_dust(seeded_pos);
    let wisps = generate_wisps(seeded_pos);
    let lightning = generate_lightning(seeded_pos, nebula.a);
    
    // Combine all elements
    var final_color = vec3<f32>(0.0);
    
    // Base ambient color (deep space)
    final_color += params.ambient_color * params.ambient_intensity * 0.01;
    
    // Add distant stars (background layer)
    final_color += distant_stars.color * distant_stars.brightness * 0.5;
    
    // Add galaxies
    final_color += galaxies;
    
    // Add nebula
    let nebula_contribution = nebula.rgb * nebula.a;
    final_color = mix(final_color, nebula_contribution, nebula.a * 0.7);
    
    // Add dust and wisps (subtle enhancement)
    final_color += nebula.rgb * (dust + wisps) * nebula.a;
    
    // Add lightning (emissive)
    final_color += lightning;
    
    // Add medium stars
    final_color += medium_stars.color * medium_stars.brightness;
    
    // Add bright stars on top
    final_color += bright_stars.color * bright_stars.brightness;
    
    // Apply emission strength multiplier
    final_color *= params.emission_strength;
    
    // Subtle color grading based on environment type
    if params.environment_type == 0u {
        // Bleak - desaturate slightly
        let gray = dot(final_color, vec3<f32>(0.299, 0.587, 0.114));
        final_color = mix(final_color, vec3<f32>(gray), 0.3);
    } else if params.environment_type == 3u {
        // Chaotic - boost saturation
        let gray = dot(final_color, vec3<f32>(0.299, 0.587, 0.114));
        final_color = mix(vec3<f32>(gray), final_color, 1.3);
    }
    
    // HDR exposure (allow values > 1 for bloom)
    let exposure = 1.0;
    final_color *= exposure;
    
    return vec4<f32>(final_color, 1.0);
}
