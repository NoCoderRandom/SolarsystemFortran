#!/usr/bin/env bash
#
# run.sh — launch solarsim from the project root.
#
# The binary expects to run from the build/ directory so that relative asset
# paths (assets/planets/*, shaders/*, screenshots/*) resolve correctly — the
# CMake build copies those into build/ at configure/build time.
#
# Usage:
#   ./run.sh                      # interactive
#   ./run.sh --screenshot         # headless overview shot, then exit
#   ./run.sh --screenshot-earth   # Earth close-up
#   ./run.sh --screenshot-saturn  # Saturn + rings close-up
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT_DIR/build/solarsim"

if [ ! -x "$BIN" ]; then
    echo "ERROR: $BIN not found. Run ./install.sh first." >&2
    exit 1
fi

cd "$ROOT_DIR/build"
exec "$BIN" "$@"
