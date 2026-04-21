# Spacecraft Asset Conventions

Purpose: keep spacecraft assets separate from planet assets and make imports mechanical.

## Folder Layout

- `assets/spacecraft/<pack>/<ship>/model.obj`
- `assets/spacecraft/<pack>/<ship>/model.mtl`
- `assets/spacecraft/<pack>/<ship>/textures/`
- `assets/spacecraft/<pack>/<ship>/README.md`

Use one folder per spacecraft. Keep converted engine-ready files beside their local textures and notes.

## Required Files

- `model.obj`: triangulated OBJ preferred
- `model.mtl`: material file if the OBJ uses external textures
- `README.md`: source URL, license, author, conversion notes, scale notes

## Texture Conventions

- Diffuse/albedo texture: `map_Kd` in `model.mtl`
- Optional normal map: `map_Bump`, `bump`, or `norm` in `model.mtl`
- Relative texture paths should stay inside the same spacecraft folder

## Import Rules

- Keep spacecraft assets out of `assets/planets/`
- Prefer triangulated meshes before import
- Normalize orientation and scale during conversion, then record what changed
- Do not rely on absolute paths in OBJ or MTL files

## Framework Sample

- `assets/spacecraft/framework/test_probe/` is a small local pipeline-check asset
- It exists only to verify OBJ + MTL + diffuse texture loading
- Real spacecraft content belongs in later prompts
