# AI Coder Workflows

![Enterprise blue shot](assets/enterprise_blue.png)

This side project works well with AI coding agents because it exposes simple, reviewable files instead of hiding behavior behind a GUI-only tool. In practice, the "integration" is a workflow fit, not an official vendor SDK.

## What Integration Means Here

- The shot list is plain TSV.
- Capture settings are plain TOML.
- Rendering is plain shell.
- Caption timing is plain TSV.
- Output review can be done with still-frame extraction and lightweight MP4 files.

An agent can therefore propose, edit, render, sample, and document movie changes end to end.

## Fit By Agent Family

### OpenAI Codex

Strong fit for:

- editing Fortran demo logic
- tuning shell scripts and manifests
- writing technical documentation beside code
- iterating on end-to-end repo tasks that include build, render, and packaging

### Claude Code

Strong fit for:

- long-form planning and editorial direction
- documentation-heavy updates
- turning rough creative requests into shot lists and caption drafts
- high-level review of batch render outputs and repo structure

### Qwen-Coder Style Agents

Strong fit for:

- quick script iteration
- manifest rewriting
- format conversion helpers
- repeated small shot and config experiments

## Why This Repo Is Friendly To Agents

- The side-project workspace is mostly self-contained under `movies/`.
- Reels are derived from existing clips, so agents can re-edit without re-rendering everything.
- Output MP4s are small enough to keep in the repo and discuss directly.
- Engine hooks are explicit in [`../../src/main.f90`](../../src/main.f90) and [`../../src/render/demo.f90`](../../src/render/demo.f90).

## Recommended Human Plus Agent Loop

1. Ask the agent for a concept, story arc, or target reel.
2. Have the agent draft or refine a TSV manifest.
3. Render one shot first, not the whole batch.
4. Extract 2 to 4 stills from the result.
5. Adjust camera, ship spacing, or timing.
6. Batch-render the final set.
7. Recut from masters before deciding to change engine code.
8. Add educational captions only after the picture edit works.

## Useful Prompt Patterns

Shot-planning prompt:

```text
Use movies/shot_plan.tsv as a template. Create six cinematic shots that stay far enough from planets to preserve believable scale, vary camera movement, and include at least two formation-flight moments.
```

Educational prompt:

```text
Use movies/captions/voyager_story.tsv as a template. Keep each caption short, factual, and timed to the major visual beats of the Voyager journey clip.
```

Director prompt:

```text
Rebuild the 1-minute reel from existing master clips only. Prefer stronger ship visibility over strict use of every rendered shot.
```

Model-tuning prompt:

```text
Add a new spacecraft catalog entry, tune visual scale and follow-camera offsets, then render one smoke test clip to verify the ship reads nose-first in motion.
```

## Review Checklist For Agent Work

- Are the ships visible enough to read as subjects?
- Are the planets far enough away to avoid obvious scale collapse?
- Does the reel use motion variety instead of repeating the same orbit shot?
- Are captions factual, short, and timed to actual scene changes?
- Are file paths and manifests reusable for the next batch?

## Practical Limitations

- An agent can reason about shots, but final quality still needs human visual review.
- Mesh local axes differ, so "nose-first" sometimes needs per-ship tuning.
- Educational claims should be backed by research notes, not memory alone.

For the Voyager story film, the factual source notes live in [../research/voyager1_mission_notes.md](../research/voyager1_mission_notes.md).
