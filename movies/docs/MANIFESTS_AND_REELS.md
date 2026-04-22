# Manifests And Reel Editing

![Voyager Saturn story frame](assets/voyager_saturn_story.png)

The movie system is built around small TSV files that define what to render and how to cut it. This makes the project easy to edit by hand, script, or AI agent.

## Master Shot Manifest Format

Render manifests use this shape:

```text
order<TAB>slug<TAB>trim_start<TAB>trim_duration
```

Example:

```tsv
# order	slug	trim_start	trim_duration
01	earth_convoy	8	10
02	voyager_survey	9	10
03	enterprise_blue	10	10
```

Fields:

- `order`
  - output ordering and clip filename prefix
- `slug`
  - demo identifier resolved by the engine
- `trim_start`
  - start second used when building a final reel
- `trim_duration`
  - duration in seconds used in the final reel

## Current Manifests

- [`../shot_plan.tsv`](../shot_plan.tsv)
  - Trek master render list
- [`../trek_reel_plan.tsv`](../trek_reel_plan.tsv)
  - curated final-cut timings for the Trek reel
- [`../real_plan.tsv`](../real_plan.tsv)
  - real-space render list
- [`../captions/voyager_story.tsv`](../captions/voyager_story.tsv)
  - timed educational text overlays

## How The Scripts Use Them

[`../render_movies.sh`](../render_movies.sh):

- reads a render manifest
- records every listed shot
- writes clips to `output/<stamp>/clips/`
- assembles a reel at the end

[`../compile_best_of.sh`](../compile_best_of.sh):

- reads a reel manifest
- trims existing clips
- concatenates them into a final x265 MP4

[`../annotate_with_captions.sh`](../annotate_with_captions.sh):

- reads a caption TSV
- burns timed text into the chosen MP4

## Typical Editing Patterns

### Recut Without Re-rendering

If the clip content is good but the final reel is weak, edit the reel manifest only:

```bash
bash movies/compile_best_of.sh movies/output/20260422_trek movies/trek_reel_plan.tsv best_of_1min.mp4
```

### Build A New Educational Film

1. render or reuse a master clip
2. write `captions/<name>.tsv`
3. burn the text in

```bash
bash movies/annotate_with_captions.sh \
  movies/output/20260422_real/clips/02_voyager_journey.mp4 \
  movies/captions/voyager_story.tsv \
  movies/output/20260422_real/voyager_journey_story.mp4
```

### Add A New Batch

Create a new TSV and call:

```bash
bash movies/render_movies.sh movies/output/my_batch movies/my_plan.tsv my_reel.mp4
```

## Director Rules That Worked Well Here

- stay far enough from planets that size mismatch does not dominate
- vary camera language between orbit, convoy, close follow, and wide reveal
- keep at least one ship readable in frame most of the time
- prefer recutting from strong masters over rewriting engine logic too early
- use captions only after the picture edit is already working

## Good AI Tasks For Manifest Work

- drafting six new shots that do not repeat one another
- proposing stronger trim windows from existing masters
- converting a fun reel into an educational reel with captions
- making a shorter social cut from an existing 60-second package
