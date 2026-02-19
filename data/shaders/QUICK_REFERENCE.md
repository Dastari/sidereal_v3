# Planet Shader System - Quick Reference

## Shader Files

| Shader | Purpose | Performance | Render Pass |
|--------|---------|-------------|-------------|
| `planet_core.wgsl` | Main planet surface | Medium | Opaque |
| `planet_normal.wgsl` | Normal/bump mapping | Fast | Texture generation |
| `planet_atmosphere.wgsl` | Atmospheric scattering, aurora, clouds | Heavy | Transparent |
| `stellar_corona.wgsl` | Star corona, flares, prominences | Medium | Additive transparent |

## Rendering Stack

### For Rocky/Desert/Lava/Ice Planets:
1. **Base sphere** → `planet_core.wgsl` (opaque)
2. **Optional: Atmosphere sphere** (1.05-1.1x radius) → `planet_atmosphere.wgsl` (transparent)
3. **Optional: Normal map** → Generated from `planet_normal.wgsl`

### For Gas Giants:
1. **Base sphere** → `planet_core.wgsl` with `planet_type = 4` (opaque)
2. **Atmosphere sphere** (1.02-1.05x radius) → `planet_atmosphere.wgsl` (transparent)

### For Moons:
1. **Base sphere** → `planet_core.wgsl` with `planet_type = 5` (opaque)
2. **No atmosphere** (typically)

### For Stars:
1. **Core sphere** → `planet_core.wgsl` with `planet_type = 6` (emissive)
2. **Corona sphere** (1.2-2.0x radius) → `stellar_corona.wgsl` (additive transparent)

## Parameter Presets

### Earth-like Planet
```rust
// planet_core.wgsl
seed: 1234,
planet_type: 0,  // Rocky
crater_density: 0.15,
crater_size: 0.25,
continent_size: 0.6,
ocean_level: 0.4,
mountain_height: 0.45,
roughness: 0.35,
terrain_octaves: 6,
terrain_lacunarity: 2.2,
cloud_coverage: 0.5,
ice_cap_size: 0.2,
city_lights: 0.3,
color_primary: (0.3, 0.6, 0.3, 1.0),      // Green land
color_secondary: (0.6, 0.5, 0.4, 1.0),    // Mountains
color_tertiary: (0.1, 0.3, 0.6, 1.0),     // Ocean
color_atmosphere: (0.5, 0.7, 1.0, 1.0),   // Blue sky

// planet_atmosphere.wgsl
planet_radius: 1.0,
atmosphere_radius: 1.08,
rayleigh_coefficient: (0.0058, 0.0135, 0.0331),  // Blue scatter
mie_coefficient: 0.0021,
rayleigh_scale_height: 0.08,
mie_scale_height: 0.012,
sun_intensity: 20.0,
mie_g: 0.76,
city_lights_intensity: 0.5
```

### Mars-like Desert
```rust
seed: 5678,
planet_type: 1,  // Desert
crater_density: 0.45,
crater_size: 0.4,
roughness: 0.6,
mountain_height: 0.3,
terrain_octaves: 5,
cloud_coverage: 0.0,
atmosphere_thickness: 0.05,
color_primary: (0.8, 0.4, 0.3, 1.0),      // Red sand
color_secondary: (0.7, 0.5, 0.4, 1.0),    // Light sand
color_atmosphere: (0.9, 0.7, 0.6, 0.5),   // Dusty pink

// Thin atmosphere
atmosphere_radius: 1.03,
rayleigh_coefficient: (0.002, 0.001, 0.0005),  // Red scatter
sun_intensity: 15.0
```

### Jupiter-like Gas Giant
```rust
seed: 9012,
planet_type: 4,  // Gas giant
bands_count: 14.0,
storm_intensity: 0.85,
spot_density: 0.35,
cloud_coverage: 1.0,
atmosphere_thickness: 0.5,
color_primary: (0.85, 0.65, 0.45, 1.0),   // Tan bands
color_secondary: (0.95, 0.85, 0.75, 1.0), // Light bands  
color_tertiary: (0.9, 0.5, 0.4, 1.0),     // Red spot

// Thick atmosphere
atmosphere_radius: 1.05,
rayleigh_coefficient: (0.008, 0.006, 0.004),
mie_coefficient: 0.005,
sun_intensity: 25.0
```

### Lava Planet
```rust
seed: 3456,
planet_type: 2,  // Lava
volcano_density: 0.75,
roughness: 0.85,
mountain_height: 0.6,
terrain_octaves: 5,
atmosphere_thickness: 0.15,
color_primary: (0.2, 0.1, 0.1, 1.0),      // Dark rock
color_secondary: (1.0, 0.3, 0.0, 1.0),    // Lava glow (emissive)
color_atmosphere: (0.8, 0.4, 0.2, 0.3),   // Volcanic haze

// Hot atmosphere
atmosphere_radius: 1.04,
rayleigh_coefficient: (0.005, 0.003, 0.001),  // Red/orange scatter
```

### Ice Planet (Hoth-style)
```rust
seed: 7890,
planet_type: 3,  // Ice
crater_density: 0.25,
mountain_height: 0.35,
roughness: 0.25,
ice_cap_size: 0.95,
cloud_coverage: 0.4,
terrain_octaves: 5,
color_primary: (0.9, 0.95, 1.0, 1.0),     // White ice
color_secondary: (0.7, 0.85, 0.95, 1.0),  // Blue ice
color_atmosphere: (0.8, 0.9, 1.0, 0.2),   // Pale blue

// Clear cold atmosphere
atmosphere_radius: 1.06,
rayleigh_coefficient: (0.004, 0.008, 0.012),  // Blue scatter
```

### Barren Moon
```rust
seed: 2345,
planet_type: 5,  // Moon
crater_density: 0.85,
crater_size: 0.6,
roughness: 0.9,
terrain_octaves: 4,
atmosphere_thickness: 0.0,  // No atmosphere
color_primary: (0.4, 0.4, 0.4, 1.0),      // Gray
color_secondary: (0.35, 0.35, 0.35, 1.0), // Dark gray
```

### Sun-like Star
```rust
// planet_core.wgsl
seed: 6789,
planet_type: 6,  // Star
corona_intensity: 0.85,
surface_activity: 0.6,
color_primary: (1.0, 0.95, 0.7, 1.0),     // Yellow-white
color_secondary: (1.0, 0.8, 0.4, 1.0),    // Orange (sunspots)

// stellar_corona.wgsl
star_radius: 1.0,
corona_radius: 1.5,
star_temperature: 5778.0,  // K (Sun)
corona_intensity: 0.8,
corona_turbulence: 0.7,
corona_streamers: 0.6,
prominence_count: 0.5,
prominence_height: 0.3,
prominence_intensity: 0.8,
flare_probability: 0.3,
flare_intensity: 1.2,
magnetic_complexity: 0.6,
field_line_intensity: 0.4,
corona_base_color: (1.0, 0.98, 0.9),
prominence_color: (1.0, 0.6, 0.4),
flare_color: (1.0, 0.9, 0.8)
```

### Red Dwarf Star
```rust
seed: 4567,
planet_type: 6,  // Star
corona_intensity: 0.5,
surface_activity: 0.8,  // High activity for red dwarfs
color_primary: (1.0, 0.4, 0.2, 1.0),      // Red
color_secondary: (0.8, 0.3, 0.1, 1.0),    // Dark red spots

// stellar_corona.wgsl
star_temperature: 3500.0,  // K
corona_intensity: 0.5,
prominence_count: 0.7,  // Frequent prominences
flare_probability: 0.6,  // Frequent flares
corona_base_color: (1.0, 0.5, 0.3)
```

### Blue Giant Star
```rust
seed: 8901,
planet_type: 6,  // Star
corona_intensity: 1.0,
surface_activity: 0.3,  // Less active than smaller stars
color_primary: (0.8, 0.9, 1.0, 1.0),      // Blue-white
color_secondary: (0.9, 0.95, 1.0, 1.0),

// stellar_corona.wgsl
star_temperature: 15000.0,  // K
corona_intensity: 1.0,
corona_streamers: 0.8,
prominence_count: 0.2,  // Less frequent but massive
prominence_height: 0.5,
flare_probability: 0.15,
corona_base_color: (0.9, 0.95, 1.0)
```

## Performance Tips

1. **Terrain Octaves**: Most expensive parameter. Use 3-4 for distant planets, 6-8 for hero planets.

2. **Atmosphere Samples**: 
   - Fast mode: `sample_count = 8, optical_depth_samples = 4`
   - Quality mode: `sample_count = 16, optical_depth_samples = 6`
   - Ultra mode: `sample_count = 32, optical_depth_samples = 8`

3. **Corona Effects**: Disable off-screen or for very distant stars.

4. **LOD Strategy**:
   - Near (<100 units): Full detail, all effects
   - Medium (100-500): Reduce octaves, simplified atmosphere
   - Far (>500): Billboard with pre-baked gradient

5. **Crater Density**: Keep below 0.5 for real-time performance. Higher values = more cell iterations.

## Bevy Integration Example

```rust
use bevy::prelude::*;
use bevy::render::render_resource::*;

fn setup_planet(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    // Create planet sphere
    let sphere = meshes.add(Sphere::new(10.0).mesh().ico(5).unwrap());
    
    // Setup planet material with custom shader
    let planet_material = materials.add(StandardMaterial {
        base_color: Color::WHITE,
        // ... bind custom planet shader here
        ..default()
    });
    
    commands.spawn(PbrBundle {
        mesh: sphere.clone(),
        material: planet_material,
        transform: Transform::from_xyz(0.0, 0.0, 0.0),
        ..default()
    });
    
    // Add atmosphere layer (optional)
    let atmosphere_sphere = meshes.add(Sphere::new(10.8).mesh().ico(4).unwrap());
    // Setup atmosphere material...
}
```

## Common Gotchas

1. **Normal Direction**: Ensure mesh normals point outward from planet center.

2. **Sphere Quality**: Use ico-sphere with at least 4-5 subdivisions for smooth appearance.

3. **Radius Matching**: Atmosphere/corona radius must be larger than planet radius.

4. **Seed Consistency**: Use the same seed across all shaders for a single planet.

5. **Time Sync**: Pass the same time value to all animated layers.

6. **Additive Blending**: Corona shader requires additive blend mode, not alpha blend.

7. **Color Space**: Colors are in linear space. Gamma correction handled by Bevy.

## Animation System

All shaders support time-based animation. Update the `time` parameter each frame:

```rust
fn update_planet_time(
    time: Res<Time>,
    mut query: Query<&mut PlanetMaterial>,
) {
    for mut material in query.iter_mut() {
        material.params.time = time.elapsed_seconds();
    }
}
```

Rotation is handled via `rotation_speed` parameter (radians per second).

## Space Background Presets

### Bleak Empty Space
```rust
environment_type: 0,
nebula_density: 0.1,
nebula_color1: (0.1, 0.12, 0.15, 1.0),  // Dark blue-gray
star_density: 0.3,
lightning_frequency: 0.0,
emission_strength: 0.8,
```

### Standard Blue Nebula
```rust
environment_type: 1,
nebula_density: 0.4,
nebula_color1: (0.3, 0.4, 0.8, 1.0),    // Blue
nebula_color2: (0.6, 0.3, 0.7, 1.0),    // Purple
nebula_color_mix: (0.6, 0.4, 0.0, 0.0),
star_density: 0.6,
lightning_frequency: 0.2,
emission_strength: 1.2,
```

### Vibrant Orion-style
```rust
environment_type: 2,
nebula_density: 0.7,
nebula_color1: (1.0, 0.3, 0.4, 1.0),    // Pink
nebula_color2: (0.4, 0.6, 1.0, 1.0),    // Blue
nebula_color3: (0.9, 0.7, 0.3, 1.0),    // Orange
nebula_color_mix: (0.4, 0.3, 0.3, 0.0),
star_density: 0.8,
lightning_frequency: 0.3,
emission_strength: 1.5,
```

### Chaotic Red Nebula
```rust
environment_type: 3,
nebula_density: 0.9,
nebula_color1: (1.0, 0.2, 0.3, 1.0),    // Red
nebula_color2: (1.0, 0.5, 0.0, 1.0),    // Orange
nebula_color3: (0.8, 0.1, 0.9, 1.0),    // Magenta
nebula_color_mix: (0.4, 0.35, 0.25, 0.0),
star_density: 0.9,
lightning_frequency: 0.7,
lightning_intensity: 2.5,
emission_strength: 2.0,
```

### Green Toxic Nebula
```rust
environment_type: 2,
nebula_density: 0.6,
nebula_color1: (0.2, 0.8, 0.3, 1.0),    // Bright green
nebula_color2: (0.4, 0.9, 0.5, 1.0),    // Light green
nebula_color3: (0.1, 0.4, 0.2, 1.0),    // Dark green
nebula_color_mix: (0.5, 0.3, 0.2, 0.0),
lightning_color: (0.5, 1.0, 0.6),
emission_strength: 1.4,
```

### Gold Nebula
```rust
environment_type: 2,
nebula_density: 0.65,
nebula_color1: (1.0, 0.8, 0.3, 1.0),    // Gold
nebula_color2: (1.0, 0.9, 0.5, 1.0),    // Light gold
nebula_color3: (0.8, 0.6, 0.2, 1.0),    // Dark gold
nebula_color_mix: (0.45, 0.35, 0.2, 0.0),
star_density: 0.7,
emission_strength: 1.6,
```

### Purple Crystal Nebula
```rust
environment_type: 2,
nebula_density: 0.55,
nebula_color1: (0.6, 0.3, 0.9, 1.0),    // Purple
nebula_color2: (0.8, 0.5, 1.0, 1.0),    // Light purple
nebula_color3: (0.3, 0.1, 0.6, 1.0),    // Dark purple
nebula_color4: (0.9, 0.7, 1.0, 1.0),    // Pink
nebula_color_mix: (0.35, 0.3, 0.25, 0.1),
lightning_color: (0.9, 0.7, 1.0),
emission_strength: 1.3,
```

## Rendering Stack - Space Backgrounds

### Method 1: Skybox (Recommended)
```
1. Large sphere mesh (radius >> scene size)
2. Inside-out rendering (scale -1 or inward normals)
3. space_background.wgsl material
4. Render early (before transparent objects)
```

### Method 2: Background Plane
```
1. Large plane mesh at far distance
2. space_background.wgsl material
3. Z-depth ensures behind everything
4. UV-based sampling
```

### Method 3: Procedural Sky
```
1. Use Bevy's sky system
2. Custom space_background.wgsl shader
3. View-direction based sampling
```

## Performance - Space Background

### Ultra Quality (1-2 hero systems)
- nebula_detail: 7-8
- star_density: 0.8-1.0
- lightning enabled with branches
- All dust/wisp effects

### High Quality (important systems)
- nebula_detail: 5-6
- star_density: 0.6-0.8
- Lightning moderate
- Selective effects

### Medium Quality (standard systems)
- nebula_detail: 4-5
- star_density: 0.4-0.6
- Minimal lightning
- Light dust only

### Low Quality (many distant systems)
- nebula_detail: 3
- star_density: 0.3
- No lightning
- No dust/wisps

