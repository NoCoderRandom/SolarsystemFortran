# Klingon Bird-of-Prey

- Source package: `TrekmeshesEU_WilliamBurningham_BirdofPrey_3DS.zip`
- Local source path: `assets/spacecraft/sources/trek/bird_of_prey_zip/`
- Author credit: William Burningham
- Rights note:
  - no separate readme was present in the extracted package
  - included here based on user-supplied TrekMeshes personal-use direction and repo credit policy

## Conversion Notes

- Extracted from local zip archive
- Converted from `bop.3ds` to `model.obj` with `assimp export`
- Copied the needed source TGA textures into this imported runtime folder
- Rewrote the exported `model.mtl` texture paths to local relative filenames so runtime loading does not depend on `/tmp`
