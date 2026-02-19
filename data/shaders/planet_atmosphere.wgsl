// Planet Atmosphere Shader
// Advanced atmospheric scattering and effects for planets
// Can be rendered as a separate transparent pass around the planet
//
// Based on atmospheric scattering approximations
// References:
// - Sean O'Neil's atmospheric scattering
// - GPU Gems 2 - Accurate Atmospheric Scattering

#import bevy_pbr::mesh_vertex_output::MeshVertexOutput

struct AtmosphereParams {
    // Planet properties
    planet_radius: f32,
    atmosphere_radius: f32,
    planet_center: vec3<f32>,
    
    // Scattering coefficients
    rayleigh_coefficient: vec3<f32>,  // Wavelength-dependent (blue scatters more)
    mie_coefficient: f32,              // Aerosol scattering
    rayleigh_scale_height: f32,        // Atmosphere density falloff
    mie_scale_height: f32,
    
    // Visual properties
    sun_direction: vec3<f32>,
    sun_intensity: f32,
    mie_g: f32,  // Mie phase function parameter (-0.999 to 0.999)
    
    // Advanced effects
    ozone_absorption: vec3<f32>,
    ozone_layer_height: f32,
    ground_albedo: vec3<f32>,
    
    // Night side effects
    city_lights_color: vec3<f32>,
    city_lights_intensity: f32,
    
    // Animation
    time: f32,
    
    // Technical
    sample_count: u32,  // Ray marching samples (8-32 typical)
    optical_depth_samples: u32,  // Samples for optical depth (4-8 typical)
}

@group(2) @binding(0) var<uniform> params: AtmosphereParams;

const PI: f32 = 3.14159265359;

// Hash for procedural features
fn hash31(p: vec3<f32>) -> f32 {
    var p3 = fract(p * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn hash33(p: vec3<f32>) -> vec3<f32> {
    var p3 = fract(p * vec3<f32>(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Rayleigh phase function
fn rayleigh_phase(cos_theta: f32) -> f32 {
    return (3.0 / (16.0 * PI)) * (1.0 + cos_theta * cos_theta);
}

// Mie phase function (Henyey-Greenstein approximation)
fn mie_phase(cos_theta: f32, g: f32) -> f32 {
    let g2 = g * g;
    let num = 1.0 - g2;
    let denom = pow(1.0 + g2 - 2.0 * g * cos_theta, 1.5);
    return (1.0 / (4.0 * PI)) * (num / denom);
}

// Calculate density at a given height
fn density(height: f32, scale_height: f32) -> f32 {
    return exp(-height / scale_height);
}

// Calculate optical depth (how much atmosphere light travels through)
fn optical_depth(ray_origin: vec3<f32>, ray_dir: vec3<f32>, ray_length: f32, scale_height: f32) -> f32 {
    let step_size = ray_length / f32(params.optical_depth_samples);
    var total_depth = 0.0;
    
    for (var i = 0u; i < params.optical_depth_samples; i = i + 1u) {
        let t = (f32(i) + 0.5) * step_size;
        let sample_pos = ray_origin + ray_dir * t;
        let height = length(sample_pos - params.planet_center) - params.planet_radius;
        total_depth += density(height, scale_height) * step_size;
    }
    
    return total_depth;
}

// Ray-sphere intersection
fn ray_sphere_intersection(ray_origin: vec3<f32>, ray_dir: vec3<f32>, sphere_center: vec3<f32>, sphere_radius: f32) -> vec2<f32> {
    let oc = ray_origin - sphere_center;
    let a = dot(ray_dir, ray_dir);
    let b = 2.0 * dot(oc, ray_dir);
    let c = dot(oc, oc) - sphere_radius * sphere_radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if discriminant < 0.0 {
        return vec2<f32>(-1.0, -1.0);
    }
    
    let sqrt_discriminant = sqrt(discriminant);
    let t1 = (-b - sqrt_discriminant) / (2.0 * a);
    let t2 = (-b + sqrt_discriminant) / (2.0 * a);
    
    return vec2<f32>(t1, t2);
}

// Calculate scattering along view ray
fn calculate_scattering(ray_origin: vec3<f32>, ray_dir: vec3<f32>, ray_length: f32, sun_dir: vec3<f32>) -> vec3<f32> {
    let step_size = ray_length / f32(params.sample_count);
    
    var total_rayleigh = vec3<f32>(0.0);
    var total_mie = vec3<f32>(0.0);
    
    var optical_depth_rayleigh = 0.0;
    var optical_depth_mie = 0.0;
    
    let cos_theta = dot(ray_dir, sun_dir);
    let phase_rayleigh = rayleigh_phase(cos_theta);
    let phase_mie = mie_phase(cos_theta, params.mie_g);
    
    for (var i = 0u; i < params.sample_count; i = i + 1u) {
        let t = (f32(i) + 0.5) * step_size;
        let sample_pos = ray_origin + ray_dir * t;
        let height = length(sample_pos - params.planet_center) - params.planet_radius;
        
        // Density at this sample point
        let density_rayleigh = density(height, params.rayleigh_scale_height);
        let density_mie = density(height, params.mie_scale_height);
        
        // Accumulate optical depth
        optical_depth_rayleigh += density_rayleigh * step_size;
        optical_depth_mie += density_mie * step_size;
        
        // Calculate optical depth from sample point to sun
        let sun_ray_length = ray_sphere_intersection(sample_pos, sun_dir, params.planet_center, params.atmosphere_radius).y;
        
        if sun_ray_length > 0.0 {
            let sun_optical_depth_rayleigh = optical_depth(sample_pos, sun_dir, sun_ray_length, params.rayleigh_scale_height);
            let sun_optical_depth_mie = optical_depth(sample_pos, sun_dir, sun_ray_length, params.mie_scale_height);
            
            // Beer's law for attenuation
            let attenuation = exp(-(
                params.rayleigh_coefficient * (optical_depth_rayleigh + sun_optical_depth_rayleigh) +
                params.mie_coefficient * (optical_depth_mie + sun_optical_depth_mie)
            ));
            
            total_rayleigh += density_rayleigh * attenuation * step_size;
            total_mie += density_mie * attenuation * step_size;
        }
    }
    
    // Apply phase functions and scattering coefficients
    let scattered_rayleigh = total_rayleigh * params.rayleigh_coefficient * phase_rayleigh;
    let scattered_mie = total_mie * params.mie_coefficient * phase_mie;
    
    return (scattered_rayleigh + scattered_mie) * params.sun_intensity;
}

// Simplified atmospheric glow (for performance)
fn fast_atmospheric_glow(normal: vec3<f32>, view_dir: vec3<f32>, sun_dir: vec3<f32>) -> vec3<f32> {
    // Fresnel-like rim lighting
    let fresnel = pow(1.0 - max(dot(normal, -view_dir), 0.0), 3.0);
    
    // Sun-side vs night-side
    let sun_influence = max(dot(normal, sun_dir), 0.0);
    
    // Day side glow (blue Rayleigh scattering)
    let day_glow = params.rayleigh_coefficient * fresnel * sun_influence * params.sun_intensity;
    
    // Sunset/sunrise band (orange/red)
    let horizon_band = pow(1.0 - abs(dot(normal, sun_dir)), 4.0);
    let sunset_color = vec3<f32>(1.0, 0.5, 0.2) * horizon_band * fresnel * 0.5;
    
    return day_glow + sunset_color;
}

// Aurora effect (polar regions)
fn aurora(pos: vec3<f32>, normal: vec3<f32>, time: f32) -> vec3<f32> {
    // Only near poles
    let latitude = abs(normal.y);
    if latitude < 0.7 {
        return vec3<f32>(0.0);
    }
    
    let polar_factor = smoothstep(0.7, 0.9, latitude);
    
    // Animated wavy patterns
    let wave1 = sin(pos.x * 10.0 + time * 2.0) * 0.5 + 0.5;
    let wave2 = sin(pos.z * 8.0 - time * 1.5) * 0.5 + 0.5;
    let pattern = wave1 * wave2;
    
    let noise = hash31(pos * 20.0 + vec3<f32>(time * 0.5));
    let intensity = pattern * noise * polar_factor;
    
    // Aurora colors (green/blue/purple)
    let aurora_color = mix(
        vec3<f32>(0.2, 1.0, 0.3),  // Green
        vec3<f32>(0.4, 0.3, 1.0),  // Purple
        noise
    );
    
    return aurora_color * intensity * 0.5;
}

// City lights on night side
fn night_side_lights(pos: vec3<f32>, normal: vec3<f32>, sun_dir: vec3<f32>) -> vec3<f32> {
    let n_dot_l = dot(normal, sun_dir);
    
    // Only on night side
    if n_dot_l > -0.2 {
        return vec3<f32>(0.0);
    }
    
    let night_factor = smoothstep(-0.2, -0.7, n_dot_l);
    
    // Procedural city patterns
    let city_grid = hash31(floor(pos * 50.0));
    let city_mask = step(0.85, city_grid);  // Sparse cities
    
    let twinkle = hash31(pos * 100.0 + vec3<f32>(time * 2.0));
    
    return params.city_lights_color * city_mask * night_factor * params.city_lights_intensity * twinkle;
}

// Cloud shadows cast on atmosphere
fn cloud_shadows(pos: vec3<f32>, time: f32) -> f32 {
    let cloud_scale = 5.0;
    let cloud_pos = pos * cloud_scale + vec3<f32>(time * 0.1, 0.0, 0.0);
    
    let noise1 = hash31(floor(cloud_pos));
    let noise2 = hash31(floor(cloud_pos * 2.0)) * 0.5;
    
    let clouds = smoothstep(0.4, 0.6, noise1 + noise2);
    
    return 1.0 - clouds * 0.3;  // Reduce brightness in cloud areas
}

@fragment
fn fragment(mesh: MeshVertexOutput) -> @location(0) vec4<f32> {
    let world_pos = mesh.world_position.xyz;
    let view_dir = normalize(world_pos - mesh.world_position.xyz);  // Camera assumed at origin
    let normal = normalize(mesh.world_normal);
    
    // Check if we're looking at atmosphere
    let ray_origin = mesh.world_position.xyz;  // Camera position
    let ray_dir = normalize(world_pos - ray_origin);
    
    // Find intersection with atmosphere sphere
    let atmo_intersection = ray_sphere_intersection(ray_origin, ray_dir, params.planet_center, params.atmosphere_radius);
    let planet_intersection = ray_sphere_intersection(ray_origin, ray_dir, params.planet_center, params.planet_radius);
    
    if atmo_intersection.x < 0.0 && atmo_intersection.y < 0.0 {
        discard;
    }
    
    // Determine ray segment through atmosphere
    var ray_start = max(atmo_intersection.x, 0.0);
    var ray_end = atmo_intersection.y;
    
    // If we hit the planet, stop there
    if planet_intersection.x > 0.0 {
        ray_end = min(ray_end, planet_intersection.x);
    }
    
    let ray_length = ray_end - ray_start;
    
    if ray_length <= 0.0 {
        discard;
    }
    
    let start_pos = ray_origin + ray_dir * ray_start;
    
    // Calculate atmospheric scattering (expensive)
    var atmosphere_color: vec3<f32>;
    
    if params.sample_count > 16u {
        // Full accurate scattering
        atmosphere_color = calculate_scattering(start_pos, ray_dir, ray_length, params.sun_direction);
    } else {
        // Fast approximation
        atmosphere_color = fast_atmospheric_glow(normal, view_dir, params.sun_direction);
    }
    
    // Add special effects
    let aurora_contrib = aurora(normalize(world_pos - params.planet_center), normal, params.time);
    let city_lights = night_side_lights(normalize(world_pos - params.planet_center), normal, params.sun_direction);
    
    // Cloud shadows (optional detail)
    let cloud_shadow = cloud_shadows(normalize(world_pos - params.planet_center), params.time);
    atmosphere_color *= cloud_shadow;
    
    // Combine all contributions
    let final_color = atmosphere_color + aurora_contrib + city_lights;
    
    // Calculate alpha based on atmospheric density
    let height = length(start_pos - params.planet_center) - params.planet_radius;
    let alpha = 1.0 - exp(-ray_length * density(height, params.rayleigh_scale_height) * 0.5);
    
    return vec4<f32>(final_color, alpha);
}
