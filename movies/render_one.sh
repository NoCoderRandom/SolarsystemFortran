#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CAPTURE_CONFIG="$ROOT_DIR/movies/config/cinematic_720p.toml"
SHOT="${1:-}"
OUT_DIR="${2:-$ROOT_DIR/movies/output/singles}"
case "$OUT_DIR" in
    /*) ;;
    *) OUT_DIR="$ROOT_DIR/$OUT_DIR" ;;
esac
BUILD_CONFIG="$ROOT_DIR/build/config.toml"
BACKUP_CONFIG="$(mktemp)"

if [ "$SHOT" = "--help" ] || [ -z "$SHOT" ]; then
    echo "Usage: bash movies/render_one.sh <shot-slug> [output-dir]"
    exit 0
fi

cleanup() {
    if [ -f "$BACKUP_CONFIG" ]; then
        cp "$BACKUP_CONFIG" "$BUILD_CONFIG"
        rm -f "$BACKUP_CONFIG"
    fi
}
trap cleanup EXIT INT TERM

mkdir -p "$OUT_DIR/clips" "$OUT_DIR/work" "$OUT_DIR/logs"
cp "$BUILD_CONFIG" "$BACKUP_CONFIG"
cp "$CAPTURE_CONFIG" "$BUILD_CONFIG"

cmake --build "$ROOT_DIR/build" -j 4

clip="$OUT_DIR/clips/${SHOT}.mp4"
frames="$OUT_DIR/work/${SHOT}_frames"
log="$OUT_DIR/logs/${SHOT}.log"

(
    cd "$ROOT_DIR"
    GALLIUM_DRIVER=d3d12 \
    MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
    ./run.sh --demo-record-shot "$SHOT" "$clip" "$frames"
) </dev/null 2>&1 | tee "$log"

echo "Clip: $clip"
