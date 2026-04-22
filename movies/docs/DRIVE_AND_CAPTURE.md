# Drive And Capture Guide

This guide is for people who want to use the spacecraft interactively, drive a ship around the solar system, or capture one-off movie shots without touching the batch manifests first.

## Start The App

Normal interactive run:

```bash
./run.sh
```

Open a single cinematic shot without recording:

```bash
./run.sh --demo-shot earth_convoy
```

Record one cinematic shot to frames plus MP4:

```bash
./run.sh --demo-record-shot earth_convoy /tmp/earth_convoy.mp4 /tmp/earth_convoy_frames
```

## Useful Config Snippet

The batch movie config lives in [`../config/cinematic_720p.toml`](../config/cinematic_720p.toml). A minimal spacecraft section looks like this:

```toml
[spacecraft]
enabled = T
camera_mode = 0
auto_stabilize = T
default_id = "voyager1"
spawn_preset = "earth"
```

Camera modes:

- `0` = system camera
- `1` = follow camera

Spawn presets:

- `"earth"`
- `"sun"`
- `"focus"`

## Current Drivable Ships

The current runtime catalog is defined in [`../../src/spacecraft/spacecraft_catalog.f90`](../../src/spacecraft/spacecraft_catalog.f90).

Today that catalog exposes:

- Voyager 1
- USS Voyager
- USS Enterprise NCC-1701

More imported assets exist under [`../../assets/spacecraft/imported`](../../assets/spacecraft/imported), but they are not drivable until they are added to the catalog.

## Interactive Controls

Selection and camera:

- `M` = next spacecraft
- `N` = previous spacecraft
- `C` = toggle inspect orbit camera when follow camera is active

Flight:

- `W` = thrust forward
- `S` = thrust back
- `A` / `D` = yaw
- `Up` / `Down` = pitch
- `Q` / `E` = roll
- `F` = toggle auto-stabilize

Menu-first workflow:

- enable spacecraft from the in-app menu
- select a ship from the spacecraft menu
- spawn at Earth, Sun, or current focus
- switch between system and follow camera

## Follow Camera Behavior

The follow and inspect camera behavior is implemented in [`../../src/spacecraft/spacecraft_camera.f90`](../../src/spacecraft/spacecraft_camera.f90).

The default follow camera:

- sits behind the ship
- uses per-model follow distance and height tuning
- can switch into an inspect orbit mode for hero framing

## Fast Capture Commands

Render one predefined shot through the side-project script:

```bash
bash movies/render_one.sh enterprise_blue movies/output/singles
```

Render a whole batch:

```bash
bash movies/render_movies.sh movies/output/trek_batch
```

Rebuild a final reel from existing clips:

```bash
bash movies/compile_best_of.sh movies/output/trek_batch movies/trek_reel_plan.tsv best_of_1min.mp4
```

## Good Manual Test Cases

- Spawn Voyager 1 at Earth and verify it reads clearly in follow camera.
- Switch to USS Voyager and check whether the nose points correctly in forward thrust.
- Use inspect camera around Earth or Mars to tune hero framing before writing a demo shot.
- Build a single-shot clip before changing a whole manifest.
