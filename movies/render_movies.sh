#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_MANIFEST="$ROOT_DIR/movies/shot_plan.tsv"
CAPTURE_CONFIG="$ROOT_DIR/movies/config/cinematic_720p.toml"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${1:-$ROOT_DIR/movies/output/$STAMP}"
MANIFEST="${2:-$DEFAULT_MANIFEST}"
FINAL_NAME="${3:-best_of_1min.mp4}"
case "$OUT_DIR" in
    /*) ;;
    *) OUT_DIR="$ROOT_DIR/$OUT_DIR" ;;
esac
case "$MANIFEST" in
    /*) ;;
    *) MANIFEST="$ROOT_DIR/$MANIFEST" ;;
esac
CLIP_DIR="$OUT_DIR/clips"
WORK_DIR="$OUT_DIR/work"
LOG_DIR="$OUT_DIR/logs"
BUILD_CONFIG="$ROOT_DIR/build/config.toml"
BACKUP_CONFIG="$(mktemp)"

if [ "${1:-}" = "--help" ]; then
    echo "Usage: bash movies/render_movies.sh [movies/output/<timestamp>] [manifest.tsv] [final-name.mp4]"
    exit 0
fi

cleanup() {
    if [ -f "$BACKUP_CONFIG" ]; then
        cp "$BACKUP_CONFIG" "$BUILD_CONFIG"
        rm -f "$BACKUP_CONFIG"
    fi
}
trap cleanup EXIT INT TERM

mkdir -p "$CLIP_DIR" "$WORK_DIR" "$LOG_DIR"
cp "$BUILD_CONFIG" "$BACKUP_CONFIG"
cp "$CAPTURE_CONFIG" "$BUILD_CONFIG"

if [ ! -f "$MANIFEST" ]; then
    echo "Missing manifest: $MANIFEST" >&2
    exit 1
fi

cmake --build "$ROOT_DIR/build" -j 4

while IFS=$'\t' read -r order slug trim_start trim_duration; do
    [ -z "${order:-}" ] && continue
    case "$order" in
        \#*) continue ;;
    esac

    clip="$CLIP_DIR/${order}_${slug}.mp4"
    frames="$WORK_DIR/${order}_${slug}_frames"
    log="$LOG_DIR/${order}_${slug}.log"

    echo "Rendering $order $slug"
    (
        cd "$ROOT_DIR"
        GALLIUM_DRIVER=d3d12 \
        MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
        ./run.sh --demo-record-shot "$slug" "$clip" "$frames"
    ) </dev/null 2>&1 | tee "$log"
done < "$MANIFEST"

bash "$ROOT_DIR/movies/compile_best_of.sh" "$OUT_DIR" "$MANIFEST" "$FINAL_NAME"

echo "Clips: $CLIP_DIR"
echo "Best-of: $OUT_DIR/$FINAL_NAME"
