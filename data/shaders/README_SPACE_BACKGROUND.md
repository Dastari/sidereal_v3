# Space Background Shader System

Procedural space environment generator for different star systems with nebulas, stars, galaxies, lightning, and atmospheric effects.

## Overview

This shader creates immersive space backgrounds that emit light to affect the scene. Each star system can have a unique appearance from bleak and empty to vibrant and chaotic. All generation is deterministic based on seed.

## Features

- **Multi-layered Nebulas**: Up to 4 color blending with domain warping
- **Multiple Star Types**: Distant points, medium field, bright glowing stars
- **Distant Galaxies**: Spiral galaxy hints in the background
- **Nebula Lightning**: Electrical discharges through gas clouds
- **Dust & Wisps**: Subtle detail layers
- **Emission Output**: Primary colors can light the scene
- **Performance Tiers**: Adjustable detail levels

## Rendering Setup

### Option 1: Skybox (Recommended for 3D)
Render on a large sphere or cube around the scene. View direction determines sampling.

### Option 2: Background Plane
Render on a far plane behind all game objects. Use UV coordinates for sampling.

### Option 3: Sky Shader
Use Bevy's sky system with custom shader material.

## Parameters Reference

### Identity & Environment
```rust
seed: u32                  // Deterministic generation seed
environment_type: u32      // 0=bleak, 1=moderate, 2=vibrant, 3=chaotic
```

### Nebula Settings
```rust
nebula_density: f32        // 0.0-1.0, overall nebula presence
nebula_scale: f32          // 0.5-3.0, size of nebula features (1.0 typical)
nebula_detail: u32         // 3-8, noise octaves (5-6 typical)
nebula_sharpness: f32      // 0.5-2.0, contrast (1.0 typical)
nebula_flow: f32           // 0.0-1.0, swirling motion strength
```

### Nebula Colors
```rust
nebula_color1: vec4<f32>   // Primary nebula color (RGBA)
nebula_color2: vec4<f32>   // Secondary color
nebula_color3: vec4<f32>   // Tertiary color
nebula_color4: vec4<f32>   // Quaternary color
nebula_color_mix: vec4<f32> // Weights (x,y,z,w) for each color
```

### Star Field Settings
```rust
star_density: f32          // 0.0-1.0, density of medium stars
star_brightness: f32       // 0.5-3.0, overall star brightness
star_size_variation: f32   // 0.0-1.0, size variety
star_twinkle: f32          // 0.0-1.0, twinkling animation strength
star_color_variation: f32  // 0.0-1.0, color diversity (0=white, 1=varied)
```

### Distant Objects
```rust
distant_star_density: f32  // 0.0-1.0, background star layer
distant_star_size: f32     // 0.5-2.0, size multiplier
galaxy_density: f32        // 0.0-1.0, distant galaxy frequency
galaxy_brightness: f32     // 0.5-2.0, galaxy intensity
```

### Lightning Effects
```rust
lightning_frequency: f32   // 0.0-1.0, how often lightning appears
lightning_intensity: f32   // 0.5-3.0, brightness
lightning_color: vec3<f32> // RGB color (usually electric blue/white)
lightning_thickness: f32   // 0.5-2.0, bolt width
lightning_branches: f32    // 0.0-1.0, branching complexity
```

### Dust & Wisps
```rust
dust_density: f32          // 0.0-1.0, fine dust particles
dust_brightness: f32       // 0.5-2.0, dust visibility
wisp_density: f32          // 0.0-1.0, flowing wispy structures
wisp_flow: f32             // 0.0-2.0, flow animation speed
```

### Emission & Lighting
```rust
emission_strength: f32     // 0.5-3.0, overall scene emission (1.0 typical)
ambient_color: vec3<f32>   // RGB base space color
ambient_intensity: f32     // 0.0-1.0, deep space brightness
```

### Animation
```rust
time: f32                  // Current time in seconds (auto-updated)
time_scale: f32            // 0.1-2.0, animation speed multiplier
```

### Camera (Optional)
```rust
camera_position: vec3<f32> // Camera world position
parallax_strength: f32     // 0.0-0.1, subtle parallax (usually 0.0)
```

## Preset Environments

### Bleak System (Empty Space)
```rust
SpaceParams {
    seed: 1234,
    environment_type: 0,  // Bleak
    
    // Minimal nebula
    nebula_density: 0.1,
    nebula_scale: 2.0,
    nebula_detail: 3,
    nebula_sharpness: 0.8,
    nebula_flow: 0.2,
    
    // Dark blue-gray nebula
    nebula_color1: vec4(0.1, 0.12, 0.15, 1.0),
    nebula_color2: vec4(0.08, 0.1, 0.13, 1.0),
    nebula_color3: vec4(0.0, 0.0, 0.0, 0.0),
    nebula_color4: vec4(0.0, 0.0, 0.0, 0.0),
    nebula_color_mix: vec4(0.6, 0.4, 0.0, 0.0),
    
    // Sparse stars
    star_density: 0.3,
    star_brightness: 0.8,
    star_size_variation: 0.4,
    star_twinkle: 0.2,
    star_color_variation: 0.3,
    
    distant_star_density: 0.5,
    distant_star_size: 0.8,
    galaxy_density: 0.1,
    galaxy_brightness: 0.5,
    
    // No lightning
    lightning_frequency: 0.0,
    lightning_intensity: 0.0,
    lightning_color: vec3(0.0),
    lightning_thickness: 0.0,
    lightning_branches: 0.0,
    
    // Minimal dust
    dust_density: 0.1,
    dust_brightness: 0.5,
    wisp_density: 0.0,
    wisp_flow: 0.0,
    
    // Dark ambient
    emission_strength: 0.8,
    ambient_color: vec3(0.05, 0.05, 0.08),
    ambient_intensity: 0.3,
    
    time: 0.0,
    time_scale: 0.5,
    camera_position: vec3(0.0),
    parallax_strength: 0.0,
}
```

### Moderate System (Standard Space)
```rust
SpaceParams {
    seed: 5678,
    environment_type: 1,  // Moderate
    
    // Moderate nebula
    nebula_density: 0.4,
    nebula_scale: 1.5,
    nebula_detail: 5,
    nebula_sharpness: 1.2,
    nebula_flow: 0.5,
    
    // Blue and purple nebula
    nebula_color1: vec4(0.3, 0.4, 0.8, 1.0),   // Blue
    nebula_color2: vec4(0.6, 0.3, 0.7, 1.0),   // Purple
    nebula_color3: vec4(0.2, 0.5, 0.6, 1.0),   // Cyan
    nebula_color4: vec4(0.0, 0.0, 0.0, 0.0),
    nebula_color_mix: vec4(0.4, 0.35, 0.25, 0.0),
    
    // Good star field
    star_density: 0.6,
    star_brightness: 1.2,
    star_size_variation: 0.6,
    star_twinkle: 0.4,
    star_color_variation: 0.5,
    
    distant_star_density: 0.7,
    distant_star_size: 1.0,
    galaxy_density: 0.3,
    galaxy_brightness: 0.8,
    
    // Occasional lightning
    lightning_frequency: 0.2,
    lightning_intensity: 1.5,
    lightning_color: vec3(0.8, 0.9, 1.0),
    lightning_thickness: 1.0,
    lightning_branches: 0.3,
    
    // Moderate dust
    dust_density: 0.3,
    dust_brightness: 1.0,
    wisp_density: 0.2,
    wisp_flow: 0.5,
    
    // Balanced emission
    emission_strength: 1.2,
    ambient_color: vec3(0.15, 0.18, 0.25),
    ambient_intensity: 0.5,
    
    time: 0.0,
    time_scale: 1.0,
    camera_position: vec3(0.0),
    parallax_strength: 0.0,
}
```

### Vibrant System (Rich Nebula)
```rust
SpaceParams {
    seed: 9012,
    environment_type: 2,  // Vibrant
    
    // Dense nebula
    nebula_density: 0.7,
    nebula_scale: 1.2,
    nebula_detail: 6,
    nebula_sharpness: 1.5,
    nebula_flow: 0.7,
    
    // Multi-color nebula (Orion-like)
    nebula_color1: vec4(1.0, 0.3, 0.4, 1.0),   // Red-pink
    nebula_color2: vec4(0.4, 0.6, 1.0, 1.0),   // Blue
    nebula_color3: vec4(0.9, 0.7, 0.3, 1.0),   // Orange
    nebula_color4: vec4(0.5, 0.3, 0.8, 1.0),   // Purple
    nebula_color_mix: vec4(0.35, 0.25, 0.25, 0.15),
    
    // Dense star field
    star_density: 0.8,
    star_brightness: 1.5,
    star_size_variation: 0.8,
    star_twinkle: 0.5,
    star_color_variation: 0.7,
    
    distant_star_density: 0.9,
    distant_star_size: 1.2,
    galaxy_density: 0.5,
    galaxy_brightness: 1.2,
    
    // Moderate lightning
    lightning_frequency: 0.3,
    lightning_intensity: 2.0,
    lightning_color: vec3(1.0, 0.8, 0.9),
    lightning_thickness: 1.2,
    lightning_branches: 0.5,
    
    // Rich dust
    dust_density: 0.5,
    dust_brightness: 1.3,
    wisp_density: 0.4,
    wisp_flow: 0.8,
    
    // Bright emission
    emission_strength: 1.5,
    ambient_color: vec3(0.25, 0.22, 0.3),
    ambient_intensity: 0.7,
    
    time: 0.0,
    time_scale: 1.2,
    camera_position: vec3(0.0),
    parallax_strength: 0.0,
}
```

### Chaotic System (Violent Space)
```rust
SpaceParams {
    seed: 3456,
    environment_type: 3,  // Chaotic
    
    // Very dense, turbulent nebula
    nebula_density: 0.9,
    nebula_scale: 0.8,
    nebula_detail: 7,
    nebula_sharpness: 2.0,
    nebula_flow: 1.0,
    
    // Violent colors
    nebula_color1: vec4(1.0, 0.2, 0.3, 1.0),   // Red
    nebula_color2: vec4(1.0, 0.5, 0.0, 1.0),   // Orange
    nebula_color3: vec4(0.8, 0.1, 0.9, 1.0),   // Magenta
    nebula_color4: vec4(0.2, 0.9, 1.0, 1.0),   // Cyan
    nebula_color_mix: vec4(0.3, 0.3, 0.25, 0.15),
    
    // Many stars
    star_density: 0.9,
    star_brightness: 1.8,
    star_size_variation: 0.9,
    star_twinkle: 0.7,
    star_color_variation: 0.8,
    
    distant_star_density: 1.0,
    distant_star_size: 1.5,
    galaxy_density: 0.7,
    galaxy_brightness: 1.5,
    
    // Frequent lightning
    lightning_frequency: 0.7,
    lightning_intensity: 2.5,
    lightning_color: vec3(0.9, 0.95, 1.0),
    lightning_thickness: 1.5,
    lightning_branches: 0.8,
    
    // Heavy dust
    dust_density: 0.7,
    dust_brightness: 1.5,
    wisp_density: 0.6,
    wisp_flow: 1.5,
    
    // Intense emission
    emission_strength: 2.0,
    ambient_color: vec3(0.3, 0.25, 0.35),
    ambient_intensity: 0.9,
    
    time: 0.0,
    time_scale: 1.5,
    camera_position: vec3(0.0),
    parallax_strength: 0.0,
}
```

### Green Nebula System
```rust
// Toxic/mysterious green nebula
nebula_color1: vec4(0.2, 0.8, 0.3, 1.0),   // Bright green
nebula_color2: vec4(0.4, 0.9, 0.5, 1.0),   // Light green
nebula_color3: vec4(0.1, 0.4, 0.2, 1.0),   // Dark green
nebula_color4: vec4(0.0, 0.0, 0.0, 0.0),
nebula_color_mix: vec4(0.5, 0.3, 0.2, 0.0),
nebula_density: 0.6,
lightning_color: vec3(0.5, 1.0, 0.6),
```

### Red Nebula System  
```rust
// Angry red nebula (stellar nursery)
nebula_color1: vec4(1.0, 0.2, 0.2, 1.0),   // Red
nebula_color2: vec4(0.9, 0.5, 0.3, 1.0),   // Orange-red
nebula_color3: vec4(0.6, 0.1, 0.1, 1.0),   // Dark red
nebula_color4: vec4(1.0, 0.7, 0.3, 1.0),   // Yellow
nebula_color_mix: vec4(0.4, 0.3, 0.2, 0.1),
nebula_density: 0.75,
emission_strength: 1.8,
```

### Gold Nebula System
```rust
// Precious metal-like golden nebula
nebula_color1: vec4(1.0, 0.8, 0.3, 1.0),   // Gold
nebula_color2: vec4(1.0, 0.9, 0.5, 1.0),   // Light gold
nebula_color3: vec4(0.8, 0.6, 0.2, 1.0),   // Dark gold
nebula_color4: vec4(1.0, 0.95, 0.8, 1.0),  // Pale gold
nebula_color_mix: vec4(0.35, 0.3, 0.25, 0.1),
```

## Performance Guide

### Quality Tiers

**Ultra (Hero Systems)**
```rust
nebula_detail: 7-8
star_density: 0.8-1.0
lightning_frequency: 0.5-0.8
dust/wisp: enabled
```

**High (Important Systems)**
```rust
nebula_detail: 5-6
star_density: 0.6-0.8
lightning_frequency: 0.3-0.5
dust/wisp: moderate
```

**Medium (Standard Systems)**
```rust
nebula_detail: 4-5
star_density: 0.4-0.6
lightning_frequency: 0.2-0.3
dust/wisp: light
```

**Low (Distant/Background)**
```rust
nebula_detail: 3
star_density: 0.3
lightning_frequency: 0.0
dust/wisp: disabled
```

### Performance Impact
```
Feature                Cost     Notes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
nebula_detail          ★★★★★    Most expensive
lightning_branches     ★★★★☆    Expensive when high
domain warping         ★★★☆☆    (nebula_flow)
star layers            ★★☆☆☆    Reasonable
dust/wisps             ★☆☆☆☆    Cheap
color mixing           ☆☆☆☆☆    No cost
```

## Using Emission for Scene Lighting

The shader outputs emissive colors that can light your scene. Extract the dominant color:

```rust
fn extract_dominant_emission(params: &SpaceParams) -> Color {
    // Weight nebula colors by their mix values
    let total_weight = params.nebula_color_mix.x + 
                      params.nebula_color_mix.y + 
                      params.nebula_color_mix.z + 
                      params.nebula_color_mix.w;
    
    if total_weight > 0.0 {
        let weighted = 
            params.nebula_color1.truncate() * params.nebula_color_mix.x +
            params.nebula_color2.truncate() * params.nebula_color_mix.y +
            params.nebula_color3.truncate() * params.nebula_color_mix.z +
            params.nebula_color4.truncate() * params.nebula_color_mix.w;
        
        Color::rgb(
            weighted.x / total_weight * params.emission_strength,
            weighted.y / total_weight * params.emission_strength,
            weighted.z / total_weight * params.emission_strength
        )
    } else {
        Color::rgb(0.1, 0.1, 0.15)  // Default deep space
    }
}

// Use for ambient light
fn setup_ambient_from_space(
    mut commands: Commands,
    space_params: Res<SpaceParams>,
) {
    let ambient_color = extract_dominant_emission(&space_params);
    
    commands.insert_resource(AmbientLight {
        color: ambient_color,
        brightness: 0.3,
    });
}
```

## Integration Examples

### Skybox Setup
```rust
fn setup_space_skybox(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<SpaceMaterial>>,
) {
    // Large sphere around scene
    let skybox_mesh = meshes.add(Sphere::new(1000.0).mesh().ico(3).unwrap());
    
    let space_material = materials.add(SpaceMaterial {
        params: moderate_system_preset(),
    });
    
    commands.spawn(MaterialMeshBundle {
        mesh: skybox_mesh,
        material: space_material,
        // Render on inside of sphere
        transform: Transform::from_scale(Vec3::splat(-1.0)),
        ..default()
    });
}
```

### Background Plane Setup
```rust
fn setup_space_background(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<SpaceMaterial>>,
) {
    // Far background plane
    let plane_mesh = meshes.add(Plane3d::new(Vec3::Z, Vec2::splat(5000.0)));
    
    let space_material = materials.add(SpaceMaterial {
        params: vibrant_system_preset(),
    });
    
    commands.spawn(MaterialMeshBundle {
        mesh: plane_mesh,
        material: space_material,
        transform: Transform::from_xyz(0.0, 0.0, -1000.0),
        ..default()
    });
}
```

### Update Time Each Frame
```rust
fn update_space_time(
    time: Res<Time>,
    mut materials: ResMut<Assets<SpaceMaterial>>,
) {
    for (_, material) in materials.iter_mut() {
        material.params.time = time.elapsed_seconds();
    }
}
```

## Tips & Tricks

### Creating Variety
- Change `seed` for completely different patterns
- Adjust `environment_type` for mood shifts
- Mix 2-3 colors for realistic nebulas
- Use 4 colors for fantasy/alien environments

### Subtle vs Dramatic
- **Subtle**: Low density (0.2-0.4), high sharpness (1.5-2.0), muted colors
- **Dramatic**: High density (0.7-0.9), moderate sharpness (1.0-1.5), vibrant colors

### Lightning Timing
- Use `lightning_frequency` for density
- Lightning flashes every 2-5 seconds per cell
- Increase `time_scale` for more frequent flashes

### Color Harmony
- **Analogous**: Adjacent colors (blue→cyan→green)
- **Complementary**: Opposite colors (blue↔orange, red↔cyan)
- **Monochromatic**: Single hue, vary lightness

### Emission Balance
- For dramatic lighting: `emission_strength = 1.5-2.0`
- For subtle: `emission_strength = 0.8-1.2`
- Affects scene ambient light strength

## Troubleshooting

### Background too dark
- Increase `star_brightness`
- Increase `emission_strength`
- Increase `ambient_intensity`
- Check nebula colors aren't too dark

### Too busy/noisy
- Reduce `nebula_detail` to 3-4
- Reduce `star_density`
- Disable dust/wisps
- Increase `nebula_sharpness` for cleaner shapes

### Performance issues
- Reduce `nebula_detail` first (biggest impact)
- Disable lightning (`lightning_frequency = 0`)
- Reduce star layers
- Simplify color mixing (use 2 colors instead of 4)

### Lightning not visible
- Ensure `nebula_density > 0.1` (lightning needs nebula)
- Increase `lightning_intensity`
- Use brighter `lightning_color`
- Wait longer (flashes are intermittent)

### Colors look wrong
- Check `nebula_color_mix` weights sum to reasonable value
- Ensure RGB values are 0-1 range
- Try reducing saturation for more realistic look

## Best Practices

1. **Start Simple**: Begin with moderate preset, adjust from there
2. **Seed Strategy**: Hash system coordinates for deterministic variety
3. **Performance Budget**: Save complex backgrounds for key systems
4. **Color Consistency**: Match emission to gameplay (red = danger, blue = safe, etc.)
5. **Animation Speed**: Keep `time_scale` low (0.5-1.5) for subtle movement
6. **Test in Motion**: View while camera moves to check for artifacts

## Advanced Techniques

### Procedural System Generation
```rust
fn generate_system_background(system_coords: IVec2) -> SpaceParams {
    let seed = hash_coords(system_coords);
    let danger_level = calculate_danger(system_coords);
    
    // More dangerous = more chaotic
    let environment_type = if danger_level > 0.8 { 3 }
                          else if danger_level > 0.5 { 2 }
                          else if danger_level > 0.2 { 1 }
                          else { 0 };
    
    let mut params = default_for_type(environment_type);
    params.seed = seed;
    params
}
```

### Dynamic Events
```rust
// Increase lightning during battles
fn battle_space_effects(
    mut materials: ResMut<Assets<SpaceMaterial>>,
    battle_intensity: Res<BattleIntensity>,
) {
    for (_, material) in materials.iter_mut() {
        material.params.lightning_frequency = 
            battle_intensity.0 * 0.5;
        material.params.lightning_intensity = 
            1.0 + battle_intensity.0;
    }
}
```

## License

Uses procedural noise techniques from public domain and MIT-licensed sources. Original shader implementation follows project license.
