# Troubleshooting Guide

![Model orientation stack](assets/model_orientation_stack.svg)

This guide covers the failure modes that matter for this side project: render-path problems, ffmpeg pipeline issues, missing assets, and spacecraft that do not look nose-first in motion.

## Quick Symptom Map

| Symptom | Likely cause | First fix |
| --- | --- | --- |
| The batch render launches but the wrong GPU path is used | WSL2 or Mesa fell back from the intended D3D12 path | Run through `movies/render_one.sh` or `movies/render_movies.sh`, which already set `GALLIUM_DRIVER=d3d12` and `MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA` |
| The simulator cannot find output paths or assets during recording | The binary runs from `build/`, so relative paths can surprise wrappers | Prefer `./run.sh` or the side-project scripts instead of calling `build/solarsim` from an arbitrary directory |
| A wrapper script hangs while logging output | `tee` or another pipe may still own stdin | Keep the capture subshell detached from stdin with `</dev/null` like the shipped render scripts |
| A ship flies sideways | Mesh axes need correction or the shot skipped path-derived heading | Tune `model_pitch` and `model_yaw`, and use `stage_ship_from_path(...)` for cinematic overlays |
| A ship looks too tiny or too huge | `visual_scale` or shot `scale_mul` is off | Tune the catalog scale first, then use shot-specific `scale_mul` only for composition |
| Textures are missing | OBJ or MTL references are not portable | Keep texture paths relative inside the imported asset folder and re-export if needed |

## Render Path Notes

The shipped side-project scripts already contain the stable render path:

- [`../render_movies.sh`](../render_movies.sh)
- [`../render_one.sh`](../render_one.sh)

Important details:

- both scripts copy [`../config/cinematic_720p.toml`](../config/cinematic_720p.toml) into `build/config.toml` for the render
- both scripts set `GALLIUM_DRIVER=d3d12`
- both scripts set `MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA`
- both scripts restore the previous runtime config on exit

If you bypass those scripts, you are responsible for reproducing the same environment.

## Why `run.sh` Matters

[`../../run.sh`](../../run.sh) changes into `build/` before launching the binary. That matters because shader paths, asset paths, and screenshot paths are all resolved relative to the binary's runtime directory.

Practical rule:

- use `./run.sh ...` for direct runs
- use `bash movies/render_one.sh ...` or `bash movies/render_movies.sh ...` for repeatable capture
- avoid calling `./build/solarsim` from an unrelated working directory unless you know the asset path assumptions

## Relative Output Paths

The movie scripts normalize relative output directories against the repo root before capture or reel assembly. That keeps commands such as this predictable:

```bash
bash movies/render_one.sh earth_convoy movies/output/smoke
bash movies/compile_best_of.sh movies/output/trek_batch movies/trek_reel_plan.tsv best_of_1min.mp4
```

If you write a new helper script, copy that same pattern instead of assuming the current shell directory.

## ffmpeg And `tee` Interaction

The render scripts pipe simulator output through `tee` so each shot gets its own log file. The important implementation detail is that the capture subshell is detached from stdin before the pipe:

```bash
(
    cd "$ROOT_DIR"
    GALLIUM_DRIVER=d3d12 \
    MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
    ./run.sh --demo-record-shot "$slug" "$clip" "$frames"
) </dev/null 2>&1 | tee "$log"
```

If you omit `</dev/null` in a custom wrapper, ffmpeg or another process in the chain can end up behaving as if it owns interactive input.

## Nose-First Debugging

There are two separate orientation layers in this project:

1. motion heading
   - for cinematic overlays, `stage_ship_from_path(...)` computes heading from `next_pos_au - world_pos_au`
2. mesh correction
   - the catalog applies static `model_pitch` and `model_yaw` to compensate for each asset's local axes

That means the correct fix depends on the symptom:

- if the ship turns correctly in one shot but not another, inspect the shot path logic
- if the ship is wrong in every shot and in free flight, tune the catalog entry

Files to inspect:

- [`../../src/render/demo.f90`](../../src/render/demo.f90)
- [`../../src/spacecraft/spacecraft_catalog.f90`](../../src/spacecraft/spacecraft_catalog.f90)
- [`../../src/render/spacecraft_renderer.f90`](../../src/render/spacecraft_renderer.f90)

## Fast Smoke Tests

Build and render one known-good shot:

```bash
cmake --build build -j 4
bash movies/render_one.sh enterprise_blue movies/output/smoke
```

For a new asset:

1. add the catalog entry
2. make that ship the selected default in `build/config.toml`
3. run interactively with follow camera
4. render one single-shot smoke clip
5. only then add it to a larger manifest

## When A Planet Looks Too Small

This is usually not a renderer bug. It is a framing problem.

Better fixes:

- move the camera farther away from the planet
- let the ship carry the foreground and use the planet as context
- show curvature, atmosphere glow, or color mass instead of coastline-level detail
- vary the eye path rather than pushing in closer

That is the pattern used by the shipped Trek clips and the Voyager story shots.

## Related Guides

- [Shot authoring guide](SHOT_AUTHORING.md)
- [Importing new models](IMPORT_NEW_MODELS.md)
- [Model integration and orientation paper](../papers/MODEL_INTEGRATION_AND_ORIENTATION.md)
