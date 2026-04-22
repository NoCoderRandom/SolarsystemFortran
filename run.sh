#!/usr/bin/env bash
#
# run.sh — launch solarsim from the project root.
#
# The binary expects to run from the build/ directory so that relative asset
# paths (assets/planets/*, shaders/*, screenshots/*) resolve correctly — the
# CMake build copies those into build/ at configure/build time. If the binary
# is missing or older than the project sources, this script rebuilds first.
#
# Usage:
#   ./run.sh                      # interactive
#   ./run.sh --screenshot         # headless overview shot, then exit
#   ./run.sh --screenshot-earth   # Earth close-up
#   ./run.sh --screenshot-saturn  # Saturn + rings close-up
#   ./run.sh --demo               # 40-second automatic showcase
#   ./run.sh --demo-record DIR    # render PNG frames into DIR
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT_DIR/build/solarsim"
BUILD_SCRIPT="$ROOT_DIR/build.sh"

needs_rebuild() {
    if [ ! -x "$BIN" ]; then
        return 0
    fi

    if [ "$ROOT_DIR/CMakeLists.txt" -nt "$BIN" ]; then
        return 0
    fi

    if find "$ROOT_DIR/src" "$ROOT_DIR/shaders" "$ROOT_DIR/assets/spacecraft" \
        -type f -newer "$BIN" -print -quit | grep -q .; then
        return 0
    fi

    return 1
}

if needs_rebuild; then
    echo "run.sh: build is missing or stale; rebuilding first"
    "$BUILD_SCRIPT"
fi

if [ ! -x "$BIN" ]; then
    echo "ERROR: $BIN not found. Run ./install.sh first." >&2
    exit 1
fi

cd "$ROOT_DIR/build"
exec "$BIN" "$@"
