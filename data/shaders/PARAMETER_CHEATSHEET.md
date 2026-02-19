# Planet Shader Parameter Cheat Sheet

Quick reference for all parameters across the planet shader system.

## planet_core.wgsl Parameters

### Identity & Type
```
seed:              0 to 4294967295  (any u32)
planet_type:       0=Rocky, 1=Desert, 2=Lava, 3=Ice, 4=Gas, 5=Moon, 6=Star
```

### Surface Features (0.0 - 1.0)
```
crater_density:    0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   none              heavily cratered

crater_size:       0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   tiny              massive

continent_size:    0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   islands           supercontinents

ocean_level:       0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   water world       dry land
```

### Terrain Detail
```
mountain_height:   0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   flat              peaks

roughness:         0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   smooth            very rough

terrain_octaves:   1 ━━━━━━━━━━━━━━━━━━━━━━ 8
                   simple            detailed
                   (3-4 typical, 6-8 for hero objects)

terrain_lacunarity: 1.5 ━━━━━━━━━━━━━━━━━━ 3.0
                    (2.0-2.2 typical)
```

### Atmospheric
```
cloud_coverage:    0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   clear             overcast

cloud_height:      0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   low               high

atmosphere_thickness: 0.0 ━━━━━━━━━━━━━━━━ 1.0
                      none            thick

atmosphere_falloff: 1.0 ━━━━━━━━━━━━━━━━━━ 5.0
                    soft            sharp
                    (3.0 typical)
```

### Special Features
```
volcano_density:   0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   none              many

ice_cap_size:      0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   none              poles covered

storm_intensity:   0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   calm              violent (gas giants)

city_lights:       0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   none              bright (rocky planets)
```

### Star/Gas Specific
```
corona_intensity:  0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   faint             bright

surface_activity:  0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   calm              turbulent

bands_count:       3.0 ━━━━━━━━━━━━━━━━━━━━ 20.0
                   few               many (gas giants)

spot_density:      0.0 ━━━━━━━━━━━━━━━━━━━━ 1.0
                   rare              frequent storms
```

### Colors (vec4, RGBA 0.0-1.0)
```
color_primary:     Base surface color
color_secondary:   Accent/variation
color_tertiary:    Oceans/special features
color_atmosphere:  Atmospheric tint
```

### Animation
```
rotation_speed:    -1.0 ━━━━━━━━━━━━━━━━━━━ 1.0
                   reverse    still    forward
                   (0.1-0.3 typical)

time:              Current time in seconds (auto-updated)
```

### Technical
```
detail_level:      0.01 ━━━━━━━━━━━━━━━━━━━ 1.0
                   coarse            fine (normal maps)

normal_strength:   0.1 ━━━━━━━━━━━━━━━━━━━━ 2.0
                   subtle            extreme
                   (0.5 typical)
```

---

## planet_atmosphere.wgsl Parameters

### Geometry
```
planet_radius:       Radius of solid planet (1.0 typical)
atmosphere_radius:   Outer atmosphere (1.05-1.1 typical)
planet_center:       vec3 world position
```

### Scattering Coefficients
```
rayleigh_coefficient:  vec3 wavelength scatter
                       Earth: (0.0058, 0.0135, 0.0331)
                       Mars:  (0.002, 0.001, 0.0005)

mie_coefficient:       0.0005 ━━━━━━━━━━━━━ 0.005
                       clear          hazy
                       (0.0021 for Earth)

rayleigh_scale_height: 0.05 ━━━━━━━━━━━━━━━ 0.15
                       thin           thick
                       (0.08 for Earth)

mie_scale_height:      0.005 ━━━━━━━━━━━━━━ 0.03
                       (0.012 for Earth)
```

### Lighting
```
sun_direction:     vec3 normalized direction to sun
sun_intensity:     10.0 ━━━━━━━━━━━━━━━━━━━ 30.0
                   dim              bright
                   (20.0 typical)

mie_g:             -0.9 ━━━━━━━━━━━━━━━━━━━ 0.9
                   back scatter     forward
                   (0.76 typical)
```

### Effects
```
city_lights_color:     vec3 RGB (usually warm: 1.0, 0.8, 0.5)
city_lights_intensity: 0.0 ━━━━━━━━━━━━━━━━ 1.0
```

### Quality
```
sample_count:          8 ━━━━━━━━━━━━━━━━━━ 32
                       fast            quality
                       (16 typical)

optical_depth_samples: 4 ━━━━━━━━━━━━━━━━━━ 8
                       (6 typical)
```

---

## stellar_corona.wgsl Parameters

### Geometry
```
star_radius:     Base star radius (1.0)
corona_radius:   Outer corona (1.2-2.0 typical)
star_center:     vec3 world position
```

### Temperature
```
star_temperature:  2000.0 ━━━━━━━━━━━━━━━━━ 50000.0 K
                   red dwarf    O-type
                   Sun: 5778 K
```

### Corona Properties
```
corona_intensity:   0.0 ━━━━━━━━━━━━━━━━━━━ 1.0
corona_turbulence:  0.0 ━━━━━━━━━━━━━━━━━━━ 1.0
corona_streamers:   0.0 ━━━━━━━━━━━━━━━━━━━ 1.0
                    none              many
```

### Prominences
```
prominence_count:     0.0 ━━━━━━━━━━━━━━━━━ 1.0
prominence_height:    0.1 ━━━━━━━━━━━━━━━━━ 1.0
prominence_width:     0.01 ━━━━━━━━━━━━━━━━ 0.2
prominence_intensity: 0.0 ━━━━━━━━━━━━━━━━━ 1.0
```

### Flares
```
flare_probability:  0.0 ━━━━━━━━━━━━━━━━━━━ 1.0
                    rare              frequent

flare_intensity:    0.5 ━━━━━━━━━━━━━━━━━━━ 2.0
                    weak              intense

flare_duration:     0.01 ━━━━━━━━━━━━━━━━━━ 0.3
                    quick flash        long burst
```

### Magnetic Field
```
magnetic_complexity:  0.0 ━━━━━━━━━━━━━━━━━ 1.0
                      simple            complex

field_line_intensity: 0.0 ━━━━━━━━━━━━━━━━━ 1.0
                      invisible         visible
```

### Activity
```
active_region_count: 0.0 ━━━━━━━━━━━━━━━━━━ 1.0
spot_density:        0.0 ━━━━━━━━━━━━━━━━━━ 1.0
```

### Colors
```
corona_base_color:  vec3 RGB
prominence_color:   vec3 RGB (usually orange-red)
flare_color:        vec3 RGB (usually white-yellow)
```

### Animation
```
rotation_speed:   -0.5 ━━━━━━━━━━━━━━━━━━━━ 0.5
activity_speed:    0.5 ━━━━━━━━━━━━━━━━━━━━ 2.0
                   slow              fast
time:              Current time (auto-updated)
```

---

## planetary_rings.wgsl Parameters

### Geometry
```
inner_radius:    Planet radius * 1.2 (typical)
outer_radius:    Planet radius * 2.4 (typical)
planet_radius:   Solid planet radius
planet_center:   vec3 world position
```

### Structure
```
band_count:      1 ━━━━━━━━━━━━━━━━━━━━━━━━ 10
                 simple            complex
                 (5 for Saturn-like)

gap_count:       0 ━━━━━━━━━━━━━━━━━━━━━━━━ 5
                 none              many divisions

gap_width:       0.01 ━━━━━━━━━━━━━━━━━━━━━ 0.15
                 narrow            wide
                 (0.05 typical)
```

### Particles
```
particle_size_variation: 0.0 ━━━━━━━━━━━━━━ 1.0
                         uniform         varied

particle_density:        0.3 ━━━━━━━━━━━━━━ 1.0
                         sparse          dense

dust_density:           0.0 ━━━━━━━━━━━━━━━ 1.0
                        chunks          dust

ice_content:            0.0 ━━━━━━━━━━━━━━━ 1.0
                        rock            ice
```

### Lighting
```
sun_direction:    vec3 normalized
ambient_light:    0.0 ━━━━━━━━━━━━━━━━━━━━━ 0.3
                  dark            bright
                  (0.1 typical)

shadow_softness:  0.0 ━━━━━━━━━━━━━━━━━━━━━ 0.3
                  sharp           soft
```

### Colors
```
color_inner:    vec4 RGBA (innermost ring band)
color_middle:   vec4 RGBA (middle bands)
color_outer:    vec4 RGBA (outermost bands)
shadow_color:   vec3 RGB (usually blue-gray)
```

### Detail
```
detail_scale:    0.5 ━━━━━━━━━━━━━━━━━━━━━━ 2.0
                 large clumps      fine grain

detail_strength: 0.0 ━━━━━━━━━━━━━━━━━━━━━━ 1.0
                 uniform           varied

radial_waves:    0.0 ━━━━━━━━━━━━━━━━━━━━━━ 1.0
                 none              strong

spiral_arms:     0.0 ━━━━━━━━━━━━━━━━━━━━━━ 1.0
                 none              prominent
```

### Animation & Rendering
```
rotation_speed:  -0.2 ━━━━━━━━━━━━━━━━━━━━━ 0.2
                 reverse    still    forward

opacity:         0.3 ━━━━━━━━━━━━━━━━━━━━━━ 1.0
                 transparent        opaque
                 (0.6-0.85 typical)

time:            Current time (auto-updated)
seed:            u32 for deterministic patterns
```

---

## Performance Impact (Relative Cost)

```
Parameter             Impact    Notes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
terrain_octaves       ★★★★★     Most expensive
crater_density        ★★★★☆     Expensive if > 0.5
sample_count          ★★★★☆     (atmosphere only)
prominence_count      ★★★☆☆     (corona only)
detail_strength       ★★☆☆☆     (rings only)
cloud_coverage        ★☆☆☆☆     Cheap
colors               ☆☆☆☆☆     No cost
rotation_speed       ☆☆☆☆☆     No cost
```

---

## Typical Presets by Distance

### Hero Object (< 100 units)
```
terrain_octaves: 6-8
sample_count: 16-32
all effects enabled
```

### Medium Distance (100-500 units)
```
terrain_octaves: 4-5
sample_count: 8-16
selective effects
```

### Far Distance (> 500 units)
```
terrain_octaves: 2-3
sample_count: 4-8
minimal effects or billboard
```

---

## Quick Color Palettes

### Earth-like
```
primary:    (0.3, 0.6, 0.3)  green land
secondary:  (0.6, 0.5, 0.4)  brown mountains
tertiary:   (0.1, 0.3, 0.6)  blue ocean
atmosphere: (0.5, 0.7, 1.0)  blue sky
```

### Mars-like
```
primary:    (0.8, 0.4, 0.3)  red soil
secondary:  (0.7, 0.5, 0.4)  tan dust
atmosphere: (0.9, 0.7, 0.6)  dusty pink
```

### Jupiter-like
```
primary:    (0.85, 0.65, 0.45)  tan bands
secondary:  (0.95, 0.85, 0.75)  light bands
tertiary:   (0.9, 0.5, 0.4)     red spot
```

### Ice World
```
primary:    (0.9, 0.95, 1.0)   white ice
secondary:  (0.7, 0.85, 0.95)  blue ice
atmosphere: (0.8, 0.9, 1.0)    pale blue
```

### Lava World
```
primary:    (0.2, 0.1, 0.1)    dark rock
secondary:  (1.0, 0.3, 0.0)    lava (emissive!)
atmosphere: (0.8, 0.4, 0.2)    volcanic
```

### Sun
```
primary:    (1.0, 0.95, 0.7)   yellow-white
secondary:  (1.0, 0.8, 0.4)    orange spots
corona:     (1.0, 0.98, 0.9)   white-yellow
prominence: (1.0, 0.6, 0.4)    orange-red
```

---

Print this cheat sheet for quick reference while tuning planets!
