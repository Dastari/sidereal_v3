# Procedural Planet Shaders

Deterministic procedural planet generation shaders for Bevy, supporting a wide variety of celestial body types with extensive customization.

## Overview

This shader system provides real-time procedural generation of planets, moons, gas giants, and stars. All generation is deterministic based on a seed value, ensuring consistent results across sessions.

## Shaders

### `planet_core.wgsl`
Main planet rendering shader with full PBR support including:
- Surface color generation
- Emissive materials (lava, stars)
- Atmospheric effects
- Cloud layers
- Multiple planet type archetypes

### `planet_normal.wgsl`
Generates normal maps from the same procedural functions for proper bump/displacement mapping.

### `planet_atmosphere.wgsl`
Advanced atmospheric scattering with:
- Rayleigh and Mie scattering
- Aurora effects
- Night-side city lights
- Cloud shadows
- Accurate optical depth calculations

### `stellar_corona.wgsl`
Star corona and solar activity effects:
- Coronal streamers
- Solar prominences
- Flares and CMEs
- Magnetic field visualization
- Active regions

### `planetary_rings.wgsl`
Saturn-style ring systems:
- Multiple ring bands
- Gap structures (Cassini division)
- Density waves and spiral patterns
- Planet shadow casting
- Ice and dust composition

## Planet Types

The shader supports 7 distinct planet types (set via `planet_type` parameter):

| Type | ID | Description |
|------|----|----|
| Rocky | 0 | Earth-like planets with continents, oceans, mountains, craters |
| Desert | 1 | Arid worlds with sand dunes, minimal features |
| Lava | 2 | Volcanic worlds with glowing lava, active volcanism |
| Ice | 3 | Frozen worlds with ice formations |
| Gas Giant | 4 | Large planets with atmospheric bands and storms |
| Moon | 5 | Small, heavily cratered bodies |
| Star | 6 | Stars with corona effects, surface activity |

## Parameters

### Core Identity
- **`seed: u32`** - Deterministic seed for all randomness (0-4294967295)
- **`planet_type: u32`** - Type of celestial body (0-6, see table above)

### Surface Features (0.0 - 1.0)
- **`crater_density: f32`** - How many craters appear (0 = none, 1 = heavily cratered)
- **`crater_size: f32`** - Average crater size (0 = tiny, 1 = massive)
- **`continent_size: f32`** - Size of land masses (0 = small islands, 1 = supercontinents)
- **`ocean_level: f32`** - Water coverage threshold (0 = mostly water, 1 = mostly land)

### Terrain Detail
- **`mountain_height: f32`** - Maximum mountain elevation (0 = flat, 1 = extreme peaks)
- **`roughness: f32`** - Overall terrain ruggedness (0 = smooth, 1 = very rough)
- **`terrain_octaves: u32`** - Noise detail levels (1-8 recommended, more = more detail)
- **`terrain_lacunarity: f32`** - Noise frequency multiplier (1.5-3.0 typical)

### Atmospheric Effects
- **`cloud_coverage: f32`** - Amount of clouds (0 = clear, 1 = overcast)
- **`cloud_height: f32`** - Altitude of cloud layer (0 = surface, 1 = high atmosphere)
- **`atmosphere_thickness: f32`** - Atmospheric density/visibility (0 = none, 1 = thick)
- **`atmosphere_falloff: f32`** - Atmosphere edge sharpness (1-5 typical)

### Special Features
- **`volcano_density: f32`** - Number of volcanoes (lava planets)
- **`ice_cap_size: f32`** - Polar ice coverage (0 = none, 1 = full poles)
- **`storm_intensity: f32`** - Strength of storms (gas giants)
- **`city_lights: f32`** - City light intensity on night side (rocky planets)

### Star/Gas Giant Specific
- **`corona_intensity: f32`** - Star corona/flare intensity
- **`surface_activity: f32`** - Surface turbulence/prominences/sunspots
- **`bands_count: f32`** - Number of atmospheric bands (gas giants, 3-20 typical)
- **`spot_density: f32`** - Storm spot frequency (gas giants)

### Color Scheme
- **`color_primary: vec4<f32>`** - Base surface color (RGBA)
- **`color_secondary: vec4<f32>`** - Secondary/accent color
- **`color_tertiary: vec4<f32>`** - Tertiary color (oceans, etc.)
- **`color_atmosphere: vec4<f32>`** - Atmospheric tint color

### Animation
- **`rotation_speed: f32`** - Rotation rate (radians per time unit)
- **`time: f32`** - Current time for animations

### Technical
- **`detail_level: f32`** - Normal map detail (0.01-1.0 typical)
- **`normal_strength: f32`** - Bump map intensity (0.1-2.0 typical)

## Usage Example (Rust/Bevy)

```rust
use bevy::prelude::*;

#[derive(AsBindGroup, TypePath, Asset, Clone)]
struct PlanetMaterial {
    #[uniform(0)]
    params: PlanetParams,
}

#[derive(Clone, Copy, ShaderType)]
struct PlanetParams {
    seed: u32,
    planet_type: u32,
    crater_density: f32,
    crater_size: f32,
    // ... all other parameters
}

// Create a rocky Earth-like planet
let earth_params = PlanetParams {
    seed: 42,
    planet_type: 0, // Rocky
    
    // Surface features
    crater_density: 0.2,
    crater_size: 0.3,
    continent_size: 0.6,
    ocean_level: 0.4,
    
    // Terrain
    mountain_height: 0.5,
    roughness: 0.4,
    terrain_octaves: 6,
    terrain_lacunarity: 2.2,
    
    // Atmosphere
    cloud_coverage: 0.5,
    cloud_height: 0.1,
    atmosphere_thickness: 0.3,
    atmosphere_falloff: 3.0,
    
    // Special
    volcano_density: 0.1,
    ice_cap_size: 0.2,
    storm_intensity: 0.0,
    city_lights: 0.3,
    
    // Colors (Earth-like)
    color_primary: Vec4::new(0.3, 0.6, 0.3, 1.0),   // Green land
    color_secondary: Vec4::new(0.6, 0.5, 0.4, 1.0), // Brown mountains
    color_tertiary: Vec4::new(0.1, 0.3, 0.6, 1.0),  // Blue ocean
    color_atmosphere: Vec4::new(0.5, 0.7, 1.0, 1.0), // Blue atmosphere
    
    // Animation
    rotation_speed: 0.1,
    time: 0.0,
    
    // Technical
    detail_level: 0.1,
    normal_strength: 0.5,
    
    ..default()
};

// Create a lava planet
let lava_params = PlanetParams {
    seed: 123,
    planet_type: 2, // Lava
    
    volcano_density: 0.7,
    roughness: 0.8,
    
    color_primary: Vec4::new(0.2, 0.1, 0.1, 1.0),      // Dark rock
    color_secondary: Vec4::new(1.0, 0.3, 0.0, 1.0),    // Lava glow
    atmosphere_thickness: 0.1,
    
    ..default()
};

// Create a gas giant
let jupiter_params = PlanetParams {
    seed: 456,
    planet_type: 4, // Gas Giant
    
    bands_count: 12.0,
    storm_intensity: 0.8,
    spot_density: 0.3,
    
    color_primary: Vec4::new(0.8, 0.6, 0.4, 1.0),      // Tan bands
    color_secondary: Vec4::new(0.9, 0.8, 0.7, 1.0),    // Light bands
    color_tertiary: Vec4::new(0.9, 0.5, 0.4, 1.0),     // Red spot
    
    atmosphere_thickness: 0.4,
    
    ..default()
};

// Create a star
let star_params = PlanetParams {
    seed: 789,
    planet_type: 6, // Star
    
    corona_intensity: 0.8,
    surface_activity: 0.6,
    
    color_primary: Vec4::new(1.0, 0.9, 0.6, 1.0),      // Yellow star
    color_secondary: Vec4::new(1.0, 0.8, 0.4, 1.0),    // Orange activity
    
    ..default()
};
```

## Preset Recipes

### Earth-like Rocky Planet
```
seed: random
planet_type: 0
crater_density: 0.15, crater_size: 0.3
continent_size: 0.6, ocean_level: 0.4
mountain_height: 0.4, roughness: 0.4
cloud_coverage: 0.5, atmosphere_thickness: 0.3
ice_cap_size: 0.2, city_lights: 0.3
colors: green land, brown mountains, blue ocean
```

### Mars-like Desert
```
seed: random
planet_type: 1
crater_density: 0.4, crater_size: 0.4
roughness: 0.6
cloud_coverage: 0.0, atmosphere_thickness: 0.05
colors: red/orange tones
```

### Volcanic Hell World
```
seed: random
planet_type: 2
volcano_density: 0.8, roughness: 0.9
atmosphere_thickness: 0.2
colors: dark rock with orange/yellow lava glow
```

### Ice Planet (Hoth-style)
```
seed: random
planet_type: 3
crater_density: 0.2, mountain_height: 0.3
roughness: 0.3, ice_cap_size: 0.9
cloud_coverage: 0.3
colors: white/light blue with darker blue accents
```

### Gas Giant (Jupiter-style)
```
seed: random
planet_type: 4
bands_count: 12, storm_intensity: 0.7
spot_density: 0.3
atmosphere_thickness: 0.4
colors: tan, cream, orange with red spot
```

### Barren Moon
```
seed: random
planet_type: 5
crater_density: 0.8, crater_size: 0.5
roughness: 0.9, atmosphere_thickness: 0.0
colors: gray with subtle variations
```

### Yellow Star (Sun-like)
```
seed: random
planet_type: 6
corona_intensity: 0.8, surface_activity: 0.5
colors: yellow-white with orange activity zones
```

### Red Dwarf Star
```
seed: random
planet_type: 6
corona_intensity: 0.4, surface_activity: 0.7
colors: red-orange with darker red spots
```

## Performance Considerations

- **Octaves**: Higher values (6-8) create more detail but cost performance. Use 3-4 for distant planets.
- **Detail Level**: Lower values (0.01-0.05) are faster for normal maps.
- **Planet Type**: Gas giants and stars are slightly cheaper than rocky planets due to simpler surface features.
- **Crater Density**: High values (>0.7) can impact performance due to cell iteration.

## Technical Notes

### Determinism
All randomness is based on PCG hash functions seeded with the `seed` parameter. The same seed will always produce the same planet, making this suitable for procedural universe generation.

### Coordinate System
The shader expects a normalized sphere mesh. Position vectors are normalized to unit sphere coordinates before processing.

### Normal Mapping
For best results, use `planet_normal.wgsl` to generate normal maps with matching parameters. The `normal_strength` parameter controls bump intensity.

### Shader Model
Written in WGSL (WebGPU Shading Language) for Bevy 0.18+. Compatible with both native and WASM targets.

## References

- Noise functions adapted from [munrocket's WGSL noise library](https://gist.github.com/munrocket/236ed5ba7e409b8bdf1ff6eca5dcdc39)
- Procedural techniques inspired by the Shadertoy community
- FBM (Fractal Brownian Motion) implementation based on Inigo Quilez's work

## License

MIT License where applicable. Noise function implementations retain their original MIT licenses from Stefan Gustavson, Ian McEwan, and contributors.

## Planetary Ring Systems

### Saturn-like Rings
```rust
// planetary_rings.wgsl
seed: 1357,
inner_radius: 12.0,  // Planet radius is 10.0
outer_radius: 24.0,
planet_radius: 10.0,
planet_center: (0.0, 0.0, 0.0),
band_count: 5,
gap_count: 2,  // Cassini division, etc.
gap_width: 0.05,
particle_size_variation: 0.6,
particle_density: 0.8,
dust_density: 0.6,
ice_content: 0.9,  // Mostly water ice
sun_direction: (0.7, 0.5, 0.3),
ambient_light: 0.1,
shadow_softness: 0.1,
color_inner: (0.8, 0.8, 0.75, 1.0),
color_middle: (0.85, 0.8, 0.7, 1.0),
color_outer: (0.7, 0.7, 0.65, 1.0),
shadow_color: (0.3, 0.35, 0.4),
detail_scale: 1.0,
detail_strength: 0.4,
radial_waves: 0.3,
spiral_arms: 0.2,
rotation_speed: 0.05,
opacity: 0.85
```

### Uranus-like Dark Rings
```rust
inner_radius: 10.5,
outer_radius: 13.0,  // Narrower
band_count: 11,  // Many narrow bands
gap_count: 3,
gap_width: 0.02,
particle_density: 0.4,
dust_density: 0.8,
ice_content: 0.95,
color_inner: (0.4, 0.45, 0.5, 0.8),
color_middle: (0.5, 0.55, 0.6, 0.8),
color_outer: (0.45, 0.5, 0.55, 0.8),
detail_strength: 0.6,
radial_waves: 0.5,
opacity: 0.6  // Fainter
```

### Dusty Debris Ring
```rust
inner_radius: 11.0,
outer_radius: 15.0,
band_count: 1,  // Single diffuse band
gap_count: 0,
particle_density: 0.3,
dust_density: 0.95,  // Mostly dust
ice_content: 0.3,
detail_strength: 0.8,
radial_waves: 0.6,
spiral_arms: 0.4,  // Recent perturbations
opacity: 0.4
```

## Ring Geometry Setup

Rings require a flat disk mesh centered on the planet:

```rust
use bevy::prelude::*;

fn create_ring_mesh(inner_radius: f32, outer_radius: f32, segments: u32) -> Mesh {
    let mut positions = Vec::new();
    let mut normals = Vec::new();
    let mut uvs = Vec::new();
    let mut indices = Vec::new();
    
    for i in 0..=segments {
        let angle = (i as f32 / segments as f32) * std::f32::consts::TAU;
        let cos_a = angle.cos();
        let sin_a = angle.sin();
        
        // Inner vertex
        positions.push([inner_radius * cos_a, 0.0, inner_radius * sin_a]);
        normals.push([0.0, 1.0, 0.0]);
        uvs.push([0.0, i as f32 / segments as f32]);
        
        // Outer vertex
        positions.push([outer_radius * cos_a, 0.0, outer_radius * sin_a]);
        normals.push([0.0, 1.0, 0.0]);
        uvs.push([1.0, i as f32 / segments as f32]);
        
        if i < segments {
            let base = i * 2;
            // Triangle 1
            indices.push(base);
            indices.push(base + 1);
            indices.push(base + 2);
            // Triangle 2
            indices.push(base + 1);
            indices.push(base + 3);
            indices.push(base + 2);
        }
    }
    
    // Create mesh with double-sided rendering
    Mesh::new(PrimitiveTopology::TriangleList)
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, positions)
        .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, normals)
        .with_inserted_attribute(Mesh::ATTRIBUTE_UV_0, uvs)
        .with_indices(Some(Indices::U32(indices)))
}
```

Render rings with transparent material and depth sorting enabled.
