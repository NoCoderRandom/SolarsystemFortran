#!/usr/bin/env bash
# Build solarsim via CMake.
#   ./build.sh              # Debug (default)
#   ./build.sh release      # Release
#   ./build.sh clean        # wipe build/ first
#   ./build.sh --run-args   # extra args after `--` are ignored by build.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="build"
BUILD_TYPE="Debug"
SEEN_DOUBLE_DASH=0

for arg in "$@"; do
    if [ "$SEEN_DOUBLE_DASH" -eq 1 ]; then
        continue
    fi
    case "$arg" in
        release|Release|RELEASE) BUILD_TYPE="Release" ;;
        debug|Debug|DEBUG)       BUILD_TYPE="Debug"   ;;
        clean) rm -rf "$BUILD_DIR" ;;
        --) SEEN_DOUBLE_DASH=1 ;;
        *) echo "Unknown arg: $arg (expected: release | debug | clean)"; exit 1 ;;
    esac
done

cmake -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo
echo "Built $BUILD_TYPE → $BUILD_DIR/solarsim"
