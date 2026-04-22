#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-}"
MANIFEST="${2:-$ROOT_DIR/movies/shot_plan.tsv}"
FINAL_NAME="${3:-best_of_1min.mp4}"
case "$OUT_DIR" in
    "" ) ;;
    /*) ;;
    *) OUT_DIR="$ROOT_DIR/$OUT_DIR" ;;
esac
case "$MANIFEST" in
    /*) ;;
    *) MANIFEST="$ROOT_DIR/$MANIFEST" ;;
esac

if [ "${1:-}" = "--help" ]; then
    echo "Usage: bash movies/compile_best_of.sh movies/output/<timestamp> [manifest.tsv] [final-name.mp4]"
    exit 0
fi

if [ -z "$OUT_DIR" ]; then
    echo "Usage: bash movies/compile_best_of.sh movies/output/<timestamp> [manifest.tsv] [final-name.mp4]" >&2
    exit 1
fi

CLIP_DIR="$OUT_DIR/clips"
FINAL_VIDEO="$OUT_DIR/$FINAL_NAME"

if [ ! -d "$CLIP_DIR" ]; then
    echo "Missing clips directory: $CLIP_DIR" >&2
    exit 1
fi

if [ ! -f "$MANIFEST" ]; then
    echo "Missing manifest: $MANIFEST" >&2
    exit 1
fi

inputs=()
filter=""
concat_inputs=""
idx=0

while IFS=$'\t' read -r order slug trim_start trim_duration; do
    [ -z "${order:-}" ] && continue
    case "$order" in
        \#*) continue ;;
    esac

    clip="$CLIP_DIR/${order}_${slug}.mp4"
    if [ ! -f "$clip" ]; then
        echo "Missing clip: $clip" >&2
        exit 1
    fi

    trim_end=$((trim_start + trim_duration))
    inputs+=(-i "$clip")
    filter+="[$idx:v]trim=start=${trim_start}:end=${trim_end},setpts=PTS-STARTPTS[v$idx];"
    concat_inputs+="[v$idx]"
    idx=$((idx + 1))
done < "$MANIFEST"

if [ "$idx" -eq 0 ]; then
    echo "No shots found in $MANIFEST" >&2
    exit 1
fi

filter+="${concat_inputs}concat=n=${idx}:v=1:a=0[vout]"

ffmpeg -y "${inputs[@]}" \
    -filter_complex "$filter" \
    -map "[vout]" \
    -c:v libx265 -preset medium -crf 24 -pix_fmt yuv420p \
    -tag:v hvc1 -movflags +faststart \
    "$FINAL_VIDEO"

echo "Best-of film: $FINAL_VIDEO"
