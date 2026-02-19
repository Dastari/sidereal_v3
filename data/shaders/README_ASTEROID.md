# Asteroid Shader System

Procedural mineral-rich asteroid shader designed for irregular meshes with support for fracturing and mineral vein consistency.

## Overview

This shader generates realistic asteroids with mineral deposits, surface detail, and glowing gems. It uses **triplanar projection** to work seamlessly on any mesh shape, and maintains **deterministic mineral patterns** that persist across fragments when asteroids break apart.

## Key Features

✅ **Triplanar Projection** - Works on any irregular mesh shape  
✅ **3D Mineral Veins** - Consistent through fractures  
✅ **9 Mineral Types** - Coal, iron, copper, titanium, 5 gem types  
✅ **Glowing Gems** - Emissive rubies, topaz, emeralds, sapphires, diamonds  
✅ **Surface Detail** - Craters, weathering, roughness  
✅ **PBR Materials** - Proper metallic/roughness per mineral  
✅ **Fracture Support** - Same asteroid split multiple ways looks consistent  
✅ **Performance Optimized** - Adjustable detail levels  

## Asteroid Types

| Type | ID | Description |
|------|----|----|
| Rocky | 0 | Common silicate rock, gray-brown, moderate minerals |
| Metallic | 1 | Iron-nickel core, high metal content, shiny |
| Carbonaceous | 2 | Carbon-rich, very dark, coal deposits |
| Gem-Rich | 3 | Rare, high gem concentration, colorful |
| Ice | 4 | Frozen volatiles, white-blue, low minerals |

## Parameters

### Identity
```rust
seed: u32                  // Asteroid instance seed
asteroid_type: u32         // 0-4 (see table above)
parent_seed: u32           // Original asteroid seed (same for all fragments)
fragment_id: u32           // Unique per fragment after break
```

### Base Material
```rust
base_color: vec4<f32>      // Rock color (RGB + unused alpha)
base_roughness: f32        // 0.0-1.0, surface roughness (0.7 typical)
base_metallic: f32         // 0.0-1.0, metallic property (0.0-0.2 for rock)
```

### Surface Detail
```rust
crater_density: f32        // 0.0-1.0, impact crater frequency
crater_size: f32           // 0.1-2.0, crater scale
surface_roughness: f32     // 0.0-1.0, micro-surface variation
surface_scale: f32         // 0.5-3.0, detail texture scale (1.0 typical)
detail_octaves: u32        // 2-6, noise detail (4 typical)
```

### Mineral Deposits (0.0 = none, 1.0 = abundant)
```rust
// Common minerals
coal_density: f32          // Black, non-metallic
iron_density: f32          // Gray, metallic
copper_density: f32        // Orange-brown, metallic
titanium_density: f32      // Light gray, highly metallic

// Rare gems (glowing)
ruby_density: f32          // Red gem
topaz_density: f32         // Yellow gem
emerald_density: f32       // Green gem
sapphire_density: f32      // Blue gem
diamond_density: f32       // White/clear gem
```

### Mineral Vein Properties
```rust
vein_scale: f32            // 0.5-2.0, size of vein structures (1.0 typical)
vein_thickness: f32        // 0.05-0.3, vein width (0.15 typical)
vein_contrast: f32         // 0.5-2.0, vein visibility (1.0 typical)
```

### Gem Glow
```rust
gem_glow_strength: f32     // 0.5-3.0, emission intensity (1.5 typical)
gem_glow_radius: f32       // 0.0-1.0, glow spread (0.3 typical)
```

### Surface Variation
```rust
color_variation: f32       // 0.0-1.0, color diversity (0.3 typical)
wear_amount: f32           // 0.0-1.0, weathering/pitting (0.5 typical)
```

### Technical
```rust
triplanar_sharpness: f32   // 1.0-10.0, blend sharpness (4.0 typical)
normal_strength: f32       // 0.0-2.0, bump map intensity (0.5 typical)
```

## Preset Asteroids

### Common Rocky Asteroid
```rust
AsteroidParams {
    seed: random_seed(),
    asteroid_type: 0,  // Rocky
    parent_seed: seed,
    fragment_id: 0,
    
    // Gray-brown rock
    base_color: vec4(0.4, 0.35, 0.3, 1.0),
    base_roughness: 0.8,
    base_metallic: 0.05,
    
    // Moderate surface detail
    crater_density: 0.4,
    crater_size: 0.5,
    surface_roughness: 0.3,
    surface_scale: 1.0,
    detail_octaves: 4,
    
    // Some metals, no gems
    coal_density: 0.1,
    iron_density: 0.2,
    copper_density: 0.1,
    titanium_density: 0.05,
    ruby_density: 0.0,
    topaz_density: 0.0,
    emerald_density: 0.0,
    sapphire_density: 0.0,
    diamond_density: 0.0,
    
    // Standard veins
    vein_scale: 1.0,
    vein_thickness: 0.15,
    vein_contrast: 1.0,
    
    // Minimal glow (no gems)
    gem_glow_strength: 0.0,
    gem_glow_radius: 0.0,
    
    // Weathered
    color_variation: 0.3,
    wear_amount: 0.5,
    
    triplanar_sharpness: 4.0,
    normal_strength: 0.5,
}
```

### Metallic (Iron-Rich) Asteroid
```rust
AsteroidParams {
    seed: random_seed(),
    asteroid_type: 1,  // Metallic
    parent_seed: seed,
    fragment_id: 0,
    
    // Dark gray metallic
    base_color: vec4(0.3, 0.3, 0.35, 1.0),
    base_roughness: 0.5,
    base_metallic: 0.6,
    
    // Less cratered (harder surface)
    crater_density: 0.2,
    crater_size: 0.4,
    surface_roughness: 0.2,
    surface_scale: 1.2,
    detail_octaves: 5,
    
    // High metal content
    coal_density: 0.0,
    iron_density: 0.7,
    copper_density: 0.3,
    titanium_density: 0.4,
    
    // No gems
    ruby_density: 0.0,
    topaz_density: 0.0,
    emerald_density: 0.0,
    sapphire_density: 0.0,
    diamond_density: 0.0,
    
    // Prominent veins
    vein_scale: 0.8,
    vein_thickness: 0.2,
    vein_contrast: 1.5,
    
    gem_glow_strength: 0.0,
    gem_glow_radius: 0.0,
    
    color_variation: 0.2,
    wear_amount: 0.3,
    
    triplanar_sharpness: 5.0,
    normal_strength: 0.4,
}
```

### Carbonaceous (Coal-Rich) Asteroid
```rust
AsteroidParams {
    seed: random_seed(),
    asteroid_type: 2,  // Carbonaceous
    parent_seed: seed,
    fragment_id: 0,
    
    // Very dark
    base_color: vec4(0.15, 0.15, 0.18, 1.0),
    base_roughness: 0.95,
    base_metallic: 0.0,
    
    // Heavily cratered
    crater_density: 0.6,
    crater_size: 0.6,
    surface_roughness: 0.5,
    surface_scale: 1.0,
    detail_octaves: 4,
    
    // Mostly coal
    coal_density: 0.8,
    iron_density: 0.1,
    copper_density: 0.05,
    titanium_density: 0.0,
    
    // No gems
    ruby_density: 0.0,
    topaz_density: 0.0,
    emerald_density: 0.0,
    sapphire_density: 0.0,
    diamond_density: 0.0,
    
    vein_scale: 1.2,
    vein_thickness: 0.1,
    vein_contrast: 0.8,
    
    gem_glow_strength: 0.0,
    gem_glow_radius: 0.0,
    
    color_variation: 0.15,
    wear_amount: 0.7,
    
    triplanar_sharpness: 4.0,
    normal_strength: 0.6,
}
```

### Gem-Rich Asteroid (Rare)
```rust
AsteroidParams {
    seed: random_seed(),
    asteroid_type: 3,  // Gem-rich
    parent_seed: seed,
    fragment_id: 0,
    
    // Light tan rock
    base_color: vec4(0.6, 0.55, 0.5, 1.0),
    base_roughness: 0.7,
    base_metallic: 0.1,
    
    // Moderate craters
    crater_density: 0.3,
    crater_size: 0.5,
    surface_roughness: 0.25,
    surface_scale: 1.0,
    detail_octaves: 5,
    
    // Some metals
    coal_density: 0.0,
    iron_density: 0.15,
    copper_density: 0.2,
    titanium_density: 0.3,
    
    // High gem concentration (still rare in absolute terms)
    ruby_density: 0.3,
    topaz_density: 0.25,
    emerald_density: 0.35,
    sapphire_density: 0.3,
    diamond_density: 0.15,
    
    // Fine veins
    vein_scale: 1.5,
    vein_thickness: 0.08,
    vein_contrast: 2.0,
    
    // Strong gem glow
    gem_glow_strength: 2.0,
    gem_glow_radius: 0.4,
    
    color_variation: 0.4,
    wear_amount: 0.4,
    
    triplanar_sharpness: 4.0,
    normal_strength: 0.5,
}
```

### Ice Asteroid
```rust
AsteroidParams {
    seed: random_seed(),
    asteroid_type: 4,  // Ice
    parent_seed: seed,
    fragment_id: 0,
    
    // White-blue ice
    base_color: vec4(0.85, 0.9, 0.95, 1.0),
    base_roughness: 0.3,
    base_metallic: 0.0,
    
    // Minimal craters (soft surface)
    crater_density: 0.15,
    crater_size: 0.4,
    surface_roughness: 0.15,
    surface_scale: 0.8,
    detail_octaves: 4,
    
    // Almost no minerals (frozen volatiles)
    coal_density: 0.0,
    iron_density: 0.05,
    copper_density: 0.0,
    titanium_density: 0.0,
    
    // Maybe some embedded diamonds
    ruby_density: 0.0,
    topaz_density: 0.0,
    emerald_density: 0.0,
    sapphire_density: 0.0,
    diamond_density: 0.1,
    
    vein_scale: 2.0,
    vein_thickness: 0.2,
    vein_contrast: 0.6,
    
    gem_glow_strength: 1.0,
    gem_glow_radius: 0.2,
    
    color_variation: 0.2,
    wear_amount: 0.2,
    
    triplanar_sharpness: 3.0,
    normal_strength: 0.3,
}
```

## Procedural Mesh Generation

### Recommended Approach

Use **convex hull** or **icosphere subdivision** with noise displacement for irregular shapes:

```rust
use bevy::prelude::*;
use noise::{NoiseFn, Perlin, Fbm};

struct AsteroidMeshGenerator {
    seed: u32,
    noise: Fbm<Perlin>,
}

impl AsteroidMeshGenerator {
    pub fn new(seed: u32) -> Self {
        let perlin = Perlin::new(seed);
        let fbm = Fbm::new(perlin.seed(seed))
            .set_octaves(4)
            .set_frequency(2.0)
            .set_lacunarity(2.5)
            .set_persistence(0.5);
        
        Self { seed, noise: fbm }
    }
    
    /// Generate base asteroid mesh
    pub fn generate(&self, base_radius: f32, detail_level: u32) -> Mesh {
        // Start with icosphere
        let mut mesh = Sphere::new(base_radius).mesh().ico(detail_level).unwrap();
        
        // Get vertex positions
        let positions = mesh
            .attribute_mut(Mesh::ATTRIBUTE_POSITION)
            .unwrap()
            .as_float3_mut()
            .unwrap();
        
        // Displace vertices with noise
        for pos in positions.iter_mut() {
            let point = Vec3::from(*pos);
            let direction = point.normalize();
            
            // Sample noise at this point
            let noise_val = self.noise.get([
                point.x as f64, 
                point.y as f64, 
                point.z as f64
            ]) as f32;
            
            // Create irregular shape
            let displacement = 1.0 + noise_val * 0.4;
            let new_pos = direction * base_radius * displacement;
            
            *pos = new_pos.to_array();
        }
        
        // Recompute normals
        mesh.duplicate_vertices();
        mesh.compute_flat_normals();
        
        mesh
    }
    
    /// Generate fractured pieces (consistent with parent)
    pub fn generate_fragments(
        &self,
        parent_mesh: &Mesh,
        num_fragments: usize,
    ) -> Vec<(Mesh, Vec3)> {
        // Voronoi-based fracture
        // This is a simplified version - use proper 3D Voronoi for production
        
        let mut fragments = Vec::new();
        let bounds = calculate_bounds(parent_mesh);
        
        // Generate fracture points
        let mut fracture_points = Vec::new();
        for i in 0..num_fragments {
            let point = self.random_point_in_bounds(&bounds, i as u32);
            fracture_points.push(point);
        }
        
        // For each fracture point, extract mesh region
        // (Simplified - actual implementation would use proper mesh slicing)
        for (i, &center) in fracture_points.iter().enumerate() {
            let fragment_mesh = self.extract_fragment(
                parent_mesh,
                center,
                &fracture_points,
                i
            );
            fragments.push((fragment_mesh, center));
        }
        
        fragments
    }
    
    fn random_point_in_bounds(&self, bounds: &Aabb, salt: u32) -> Vec3 {
        let hash = |x: u32| -> f32 {
            let h = (x.wrapping_mul(747796405).wrapping_add(2891336453)) ^ self.seed;
            (h as f32) / (u32::MAX as f32)
        };
        
        Vec3::new(
            bounds.min.x + (bounds.max.x - bounds.min.x) * hash(salt),
            bounds.min.y + (bounds.max.y - bounds.min.y) * hash(salt + 1),
            bounds.min.z + (bounds.max.z - bounds.min.z) * hash(salt + 2),
        )
    }
}

fn calculate_bounds(mesh: &Mesh) -> Aabb {
    let positions = mesh
        .attribute(Mesh::ATTRIBUTE_POSITION)
        .unwrap()
        .as_float3()
        .unwrap();
    
    let mut min = Vec3::splat(f32::INFINITY);
    let mut max = Vec3::splat(f32::NEG_INFINITY);
    
    for &pos in positions {
        let v = Vec3::from(pos);
        min = min.min(v);
        max = max.max(v);
    }
    
    Aabb { min, max }
}
```

### Key Principles for Fracturing

1. **Consistent Parent Seed**: All fragments must use the same `parent_seed`
2. **Unique Fragment IDs**: Each fragment gets a unique `fragment_id`
3. **3D Mineral Pattern**: Minerals are sampled in 3D world space, not UV space
4. **No UV Dependency**: Triplanar projection means minerals look the same regardless of how you cut the mesh

### Example Fragment Setup

```rust
// Original asteroid
let parent_seed = 12345;
let asteroid_material = AsteroidMaterial {
    params: AsteroidParams {
        seed: parent_seed,
        parent_seed: parent_seed,
        fragment_id: 0,
        // ... other params
    }
};

// After fracture into 5 pieces
let fragments = vec![
    (fragment_mesh_0, fragment_material_with_id_0),
    (fragment_mesh_1, fragment_material_with_id_1),
    (fragment_mesh_2, fragment_material_with_id_2),
    (fragment_mesh_3, fragment_material_with_id_3),
    (fragment_mesh_4, fragment_material_with_id_4),
];

// All fragments share same parent_seed
for (i, (mesh, material)) in fragments.iter().enumerate() {
    material.params.parent_seed = parent_seed;  // Same for all
    material.params.fragment_id = i as u32;     // Unique per fragment
    material.params.seed = parent_seed + i as u32;  // Slight variation
}
```

## Integration Example

```rust
use bevy::prelude::*;

#[derive(AsBindGroup, TypePath, Asset, Clone)]
pub struct AsteroidMaterial {
    #[uniform(0)]
    pub params: AsteroidParams,
}

impl Material for AsteroidMaterial {
    fn fragment_shader() -> ShaderRef {
        "shaders/asteroid.wgsl".into()
    }
    
    fn alpha_mode(&self) -> AlphaMode {
        AlphaMode::Opaque
    }
}

fn spawn_asteroid(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<AsteroidMaterial>>,
) {
    let seed = rand::random();
    let generator = AsteroidMeshGenerator::new(seed);
    
    // Generate mesh
    let mesh = generator.generate(5.0, 3);  // 5m radius, detail level 3
    let mesh_handle = meshes.add(mesh);
    
    // Create material
    let material = materials.add(AsteroidMaterial {
        params: common_rocky_preset(seed),
    });
    
    // Spawn entity
    commands.spawn(MaterialMeshBundle {
        mesh: mesh_handle,
        material,
        transform: Transform::from_xyz(0.0, 0.0, 0.0),
        ..default()
    });
}

fn fracture_asteroid(
    commands: &mut Commands,
    asteroid_entity: Entity,
    asteroid_mesh: &Mesh,
    asteroid_material: &AsteroidParams,
    impact_point: Vec3,
    num_fragments: usize,
) {
    let generator = AsteroidMeshGenerator::new(asteroid_material.parent_seed);
    let fragments = generator.generate_fragments(asteroid_mesh, num_fragments);
    
    // Remove original
    commands.entity(asteroid_entity).despawn();
    
    // Spawn fragments
    for (i, (fragment_mesh, center_offset)) in fragments.into_iter().enumerate() {
        let mut fragment_params = asteroid_material.clone();
        fragment_params.fragment_id = i as u32;
        fragment_params.seed = asteroid_material.parent_seed + i as u32;
        
        commands.spawn((
            MaterialMeshBundle {
                mesh: meshes.add(fragment_mesh),
                material: materials.add(AsteroidMaterial {
                    params: fragment_params
                }),
                transform: Transform::from_translation(center_offset),
                ..default()
            },
            // Add physics for fragments flying apart
            RigidBody::Dynamic,
            Velocity::linear((center_offset - impact_point).normalize() * 5.0),
        ));
    }
}
```

## Mining Integration

Extract mineral yield from visible minerals:

```rust
fn calculate_mineral_yield(
    asteroid_params: &AsteroidParams,
    asteroid_volume: f32,
) -> HashMap<MineralType, f32> {
    let mut yields = HashMap::new();
    
    // Sample volume to estimate mineral content
    let sample_density = 0.1;  // Sample every 10cm
    let samples = (asteroid_volume / (sample_density * sample_density * sample_density)) as usize;
    
    for _ in 0..samples {
        let random_point = random_point_in_volume();
        let mineral = sample_mineral_at_point(random_point, asteroid_params);
        
        if let Some(mineral_type) = mineral.mineral_type {
            *yields.entry(mineral_type).or_insert(0.0) += mineral.intensity;
        }
    }
    
    // Normalize by samples
    for yield_val in yields.values_mut() {
        *yield_val /= samples as f32;
        *yield_val *= asteroid_volume;  // Scale by total volume
    }
    
    yields
}
```

## Performance Considerations

### Optimization Tips

1. **Detail Octaves**: Biggest performance impact
   - Close asteroids: 5-6 octaves
   - Medium distance: 3-4 octaves
   - Far/many asteroids: 2-3 octaves

2. **Gem Density**: Keep low for performance
   - Gems are rare in reality anyway
   - Use 0.1-0.3 for gem-rich asteroids
   - Use 0.0-0.1 for common asteroids

3. **Triplanar Sharpness**: Higher = faster
   - 8-10 for hard edges (faster)
   - 3-5 for smooth blending (slower but prettier)

4. **Mesh Detail**: LOD system recommended
   - Near: ico(4-5) subdivision
   - Medium: ico(2-3)
   - Far: ico(1-2) or billboard

### Performance Budget
```
Operation              Cost      Notes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mineral sampling       ★★★★☆     Multiple voronoi calls
Triplanar projection   ★★★☆☆     3x texture samples
FBM detail            ★★★☆☆     Scales with octaves
Gem glow              ★★☆☆☆     Only when gems present
Crater calculation    ★★☆☆☆     Can be disabled
Surface wear          ★☆☆☆☆     Cheap
```

## Visual Mineral Identification

Players can identify minerals by:
- **Color**: Each mineral has distinct color
- **Shine**: Metallic minerals are shiny
- **Glow**: Only gems glow
- **Pattern**: Veins vs patches

## Best Practices

1. **Seed Management**: Use position hash for procedural belts
2. **Parent Seed**: Always set when creating fragments
3. **Mineral Balance**: Don't make everything gem-rich
4. **Visual Clarity**: High vein_contrast for gameplay clarity
5. **Performance**: Use LOD and lower octaves for distant asteroids

## Troubleshooting

### Minerals look stretched/distorted
- Check that mesh has proper normals
- Increase `triplanar_sharpness` (try 5-8)
- Ensure vertices aren't too irregular

### No minerals visible
- Increase density values (try 0.3-0.5)
- Decrease `vein_thickness` (try 0.1)
- Increase `vein_contrast` (try 1.5-2.0)

### Fragments don't match parent
- Verify `parent_seed` is same for all fragments
- Check that world positions are correct
- Don't use UVs - must use world position

### Gems not glowing
- Increase `gem_glow_strength` (try 2.0-3.0)
- Check that gem densities > 0
- Ensure HDR/bloom is enabled in renderer

### Performance issues
- Reduce `detail_octaves` to 3
- Lower gem densities
- Simplify mesh (fewer vertices)
- Use LOD system

## Future Enhancements

- **Crystal formations**: Protruding gem clusters
- **Lava tubes**: Empty voids through asteroids
- **Dust/regolith**: Surface particle layer
- **Dynamic fracturing**: Real-time break-apart
- **Temperature**: Hot/cold asteroids with visual effects

## License

Part of Sidereal project shader collection. Uses PCG hash and procedural noise techniques.
