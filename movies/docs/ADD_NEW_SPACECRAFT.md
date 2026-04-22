# Add New Spacecraft Tutorial

This is the full step-by-step guide for adding a new spacecraft to the project. It covers:

- where to place the source model
- which source formats can be used
- how to convert the model into the runtime format
- which code files must be edited
- how the menu picks ships up
- how to make the new ship the default active craft
- how to test orientation, scale, and follow camera behavior

If you follow this document, the ship should load, appear in the menu, spawn correctly, and be ready for later movie work.

## What Formats Can Be Used

Source formats currently supported by the conversion pipeline:

- `glb` or `gltf`
- `obj`
- `3ds`

Runtime format expected by the engine:

- `model.obj`
- `model.mtl`
- local textures referenced with relative paths

The conversion helpers are:

- [`../../scripts/convert_spacecraft_glb.py`](../../scripts/convert_spacecraft_glb.py)
- [`../../scripts/convert_spacecraft_obj.py`](../../scripts/convert_spacecraft_obj.py)
- [`../../scripts/convert_spacecraft_3ds.py`](../../scripts/convert_spacecraft_3ds.py)

These Blender scripts import the source mesh, optionally decimate it, triangulate it, center it, normalize scale, and export an engine-ready OBJ.

## Where To Place The Files

Use this folder layout:

```text
assets/spacecraft/sources/<pack>/<ship>/...
assets/spacecraft/imported/<pack>/<ship>/model.obj
assets/spacecraft/imported/<pack>/<ship>/model.mtl
assets/spacecraft/imported/<pack>/<ship>/textures...
assets/spacecraft/imported/<pack>/<ship>/README.md
```

Current pack names used in the repo:

- `real`
- `trek`

Rules:

- keep one ship per folder
- keep texture paths relative
- do not point OBJ or MTL files at absolute host paths
- do not put spacecraft content under `assets/planets/`

## Which Files You Need To Edit

Required:

- `assets/spacecraft/sources/<pack>/<ship>/...`
  - raw download or source bundle
- `assets/spacecraft/imported/<pack>/<ship>/...`
  - runtime OBJ, MTL, textures, README
- [`../../src/spacecraft/spacecraft_catalog.f90`](../../src/spacecraft/spacecraft_catalog.f90)
  - add the ship to the drivable catalog

Optional:

- [`../../src/main.f90`](../../src/main.f90)
  - only if you want a brand-new franchise submenu beyond the existing `NASA` and `Star Trek` groups
- `build/config.toml`
  - only if you want the ship to become the default active craft during testing
- [`../../src/render/demo.f90`](../../src/render/demo.f90)
  - only if you want the ship used by scripted movie shots

Files you usually do not need to edit:

- [`../../src/spacecraft/spacecraft_system.f90`](../../src/spacecraft/spacecraft_system.f90)
  - it seeds runtime craft state directly from the catalog
- the generic spacecraft selection actions in [`../../src/main.f90`](../../src/main.f90)
  - they already work for any catalog index

## Step 1: Place The Raw Source Model

Example:

```text
assets/spacecraft/sources/trek/bird_of_prey/source.glb
```

If the source download contains multiple files, keep the bundle together in that source folder.

## Step 2: Convert The Model Into Runtime OBJ

### GLB Or glTF Source

```bash
blender -b -P scripts/convert_spacecraft_glb.py -- \
  --input assets/spacecraft/sources/trek/bird_of_prey/source.glb \
  --output assets/spacecraft/imported/trek/bird_of_prey/model.obj \
  --target-extent 2.0 \
  --decimate-ratio 0.35
```

### OBJ Source

```bash
blender -b -P scripts/convert_spacecraft_obj.py -- \
  --input assets/spacecraft/sources/trek/bird_of_prey/source.obj \
  --output assets/spacecraft/imported/trek/bird_of_prey/model.obj \
  --target-extent 2.0
```

### 3DS Source

```bash
blender -b -P scripts/convert_spacecraft_3ds.py -- \
  --input assets/spacecraft/sources/trek/bird_of_prey/source.3ds \
  --output assets/spacecraft/imported/trek/bird_of_prey/model.obj \
  --target-extent 2.0
```

After conversion, the imported folder should contain at least:

```text
assets/spacecraft/imported/trek/bird_of_prey/
  model.obj
  model.mtl
  README.md
  textures...
```

Textures can either sit beside `model.obj` or in a local subfolder such as `textures/`, as long as the `model.mtl` paths stay relative.

## Step 3: Add A README Beside The Imported Ship

Every imported ship should have a local `README.md`.

Use [`../../assets/spacecraft/imported/real/voyager1/README.md`](../../assets/spacecraft/imported/real/voyager1/README.md) as a pattern.

Include:

- source URL
- author or origin
- license direction
- original source filename
- conversion tool and command
- decimation notes
- scale notes
- orientation notes

## Step 4: Register The Ship In The Drivable Catalog

Edit [`../../src/spacecraft/spacecraft_catalog.f90`](../../src/spacecraft/spacecraft_catalog.f90).

You must:

1. increase `SPACECRAFT_CATALOG_COUNT`
2. add one more `spacecraft_catalog_init_entry(...)` call inside `spacecraft_catalog_default(...)`

Example:

```fortran
integer, parameter :: SPACECRAFT_CATALOG_COUNT = 4
```

Then add the new ship:

```fortran
call spacecraft_catalog_init_entry(entries(4), "bird_of_prey", "Klingon Bird of Prey", &
                                   "Star Trek", "starship", &
                                   "assets/spacecraft/imported/trek/bird_of_prey/model.obj", &
                                   "assets/spacecraft/imported/trek/bird_of_prey/README.md", &
                                   "earth", 1.90_real32, 0.18_real32, 0.04_real32, &
                                   -1.570796_real32, 0.6_real32)
```

### What Each Catalog Field Means

- `id`
  - stable machine-readable identifier used by config
- `display_name`
  - label shown in the UI
- `franchise`
  - menu grouping key
- `category`
  - descriptive type such as `probe` or `starship`
- `model_path`
  - runtime OBJ path
- `license_path`
  - path to the ship README
- `spawn_preset`
  - `earth`, `sun`, or `focus`
- `visual_scale`
  - on-screen draw scale
- `follow_distance`
  - follow-camera distance
- `follow_height`
  - follow-camera height offset
- `model_pitch`
  - static mesh correction in pitch
- `model_yaw`
  - static mesh correction in yaw

## Step 5: Understand How The Menu Picks Ships Up

Current behavior:

- if `franchise = "NASA"`, the ship appears automatically under the `Real` submenu
- if `franchise = "Star Trek"`, the ship appears automatically under the `Trek` submenu
- if you use any other franchise string, the ship will exist in the catalog, but it will not get its own submenu automatically

Why:

- [`../../src/main.f90`](../../src/main.f90) currently builds only two franchise submenus in `build_menu(...)`
- it loops over `NASA` ships for `Real`
- it loops over `Star Trek` ships for `Trek`

So the easiest path is:

- use `NASA` for real spacecraft
- use `Star Trek` for Trek ships

If you do that, no extra menu code is needed.

## Step 6: Add A New Franchise Submenu Only If You Need One

If you want a new submenu such as `Custom`, edit [`../../src/main.f90`](../../src/main.f90).

You need to:

1. add a submenu index variable near the `build_menu(...)` locals
2. count the new franchise with `spacecraft_count_by_franchise(...)`
3. add `menu_add_submenu(...)`
4. add a loop that inserts `Select: <ship>` items for that franchise

Pattern:

```fortran
integer :: d_spacecraft_real, d_spacecraft_trek, d_spacecraft_custom
integer :: real_count, trek_count, custom_count

custom_count = spacecraft_count_by_franchise("Custom")
if (custom_count > 0) call menu_add_submenu(menu, d_spacecraft, "Custom", custom_count, d_spacecraft_custom)
do i = 1, spacecraft_count(spacecraft)
    if (trim(spacecraft_franchise_at(spacecraft, i)) /= "Custom") cycle
    it = blank_item()
    it%kind = ITEM_BUTTON
    it%label = "Select: " // trim(spacecraft_name_at(spacecraft, i))
    it%action_id = ACTION_SPACECRAFT_SELECT_BASE + (i - 1)
    call menu_add_item(menu, d_spacecraft_custom, it)
end do
```

The existing generic action dispatch already supports any catalog index, so selection logic does not need a second custom branch.

## Step 7: Build The Project

```bash
./build.sh
```

or:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j 4
```

## Step 8: Run And Test The New Ship

```bash
./run.sh
```

In the app:

- open `Spacecraft`
- enable spacecraft
- select the new ship
- spawn it at Earth, Sun, or current focus
- switch to follow camera

Useful controls:

- `M` next ship
- `N` previous ship
- `C` toggle inspect orbit camera
- `W` and `S` thrust
- `A` and `D` yaw
- `Up` and `Down` pitch
- `Q` and `E` roll
- `F` auto-stabilize

## Step 9: Make The Ship The Default Active Craft

Optional, but useful during tuning.

Use this config block:

```toml
[spacecraft]
enabled = T
camera_mode = 1
auto_stabilize = T
default_id = "bird_of_prey"
spawn_preset = "earth"
```

The important detail is that `default_id` must exactly match the `id` you used in `spacecraft_catalog.f90`.

These settings map to the spacecraft config fields in:

- [`../../src/core/config.f90`](../../src/core/config.f90)
- [`../../src/core/config_toml.f90`](../../src/core/config_toml.f90)

## Step 10: Tune Scale And Orientation

Most imported ships need one tuning pass.

Start with:

- `visual_scale`
- `follow_distance`
- `follow_height`
- `model_pitch`
- `model_yaw`

Recommended order:

1. make the ship readable in follow camera
2. fix `model_pitch` until top and bottom read correctly
3. fix `model_yaw` until thrust reads nose-first
4. rerun and verify

If the ship looks wrong in all contexts, fix the catalog entry first. Do not start by changing movie-shot code.

## Step 11: Smoke Test Before Using The Ship In Movies

Build:

```bash
cmake --build build -j 4
```

Then run:

```bash
./run.sh
```

If the ship behaves correctly, it is ready for later cinematic work. If you want to place it in scripted demo shots, the next guide is:

- [Shot authoring guide](SHOT_AUTHORING.md)

## Exact Checklist

1. put the raw model in `assets/spacecraft/sources/<pack>/<ship>/`
2. convert it into `assets/spacecraft/imported/<pack>/<ship>/model.obj`
3. make sure `model.mtl` and textures use relative paths
4. add `README.md` beside the imported model
5. add one catalog entry in `src/spacecraft/spacecraft_catalog.f90`
6. build the app
7. test the ship through the `Spacecraft` menu
8. tune scale and orientation
9. optionally set `default_id` in config
10. only after that, use it in demos or movie manifests

## Common Mistakes

- placing the ship only in `sources/` and forgetting the runtime `imported/` version
- using absolute texture paths in `model.mtl`
- forgetting to increase `SPACECRAFT_CATALOG_COUNT`
- using a custom `franchise` string and expecting the current menu to create a submenu automatically
- setting `default_id` to a string that does not exactly match the catalog `id`
- trying to fix a bad imported mesh in movie-shot code instead of fixing `model_pitch` and `model_yaw`

## Related Documents

- [Importing new models](IMPORT_NEW_MODELS.md)
- [Drive and capture guide](DRIVE_AND_CAPTURE.md)
- [Troubleshooting guide](TROUBLESHOOTING.md)
- [Model integration and orientation paper](../papers/MODEL_INTEGRATION_AND_ORIENTATION.md)
