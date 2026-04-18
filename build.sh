#!/usr/bin/env bash
# Build solarsim via CMake.
#   ./build.sh              # Debug (default)
#   ./build.sh release      # Release
#   ./build.sh clean        # wipe build/ first
set -euo pipefail

cd "$(dirname "$0")"

BUILD_DIR="build"
BUILD_TYPE="Debug"

for arg in "$@"; do
    case "$arg" in
        release|Release|RELEASE) BUILD_TYPE="Release" ;;
        debug|Debug|DEBUG)       BUILD_TYPE="Debug"   ;;
        clean) rm -rf "$BUILD_DIR" ;;
        *) echo "Unknown arg: $arg (expected: release | debug | clean)"; exit 1 ;;
    esac
done

cmake -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo
echo "Built $BUILD_TYPE → $BUILD_DIR/solarsim"
