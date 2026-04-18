#!/usr/bin/env bash
#
# install.sh — one-shot setup + Release build for the Solar System Simulation.
#
# Tested on WSL2 Ubuntu 22.04 / 24.04. Should also work on native Debian-family
# distros. For other platforms install the equivalent packages manually and
# jump straight to the cmake section.
#
# Usage:
#   ./install.sh             # install deps, build Release, run tests
#   ./install.sh --no-apt    # skip apt-get step (deps already installed)
#   ./install.sh --debug     # build Debug instead of Release
#
set -euo pipefail

SKIP_APT=0
BUILD_TYPE="Release"

for arg in "$@"; do
    case "$arg" in
        --no-apt) SKIP_APT=1 ;;
        --debug)  BUILD_TYPE="Debug" ;;
        -h|--help)
            sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "==> Solar System Simulation — installer"
echo "    Root:        $ROOT_DIR"
echo "    Build type:  $BUILD_TYPE"

# ---------------------------------------------------------------------------
# Step 1 — system packages
# ---------------------------------------------------------------------------
if [ "$SKIP_APT" -eq 0 ] && command -v apt-get >/dev/null 2>&1; then
    echo "==> Installing system packages (requires sudo)"
    sudo apt-get update
    sudo apt-get install -y \
        gfortran \
        cmake \
        make \
        build-essential \
        libglfw3-dev \
        pkg-config
else
    echo "==> Skipping apt-get step"
fi

# ---------------------------------------------------------------------------
# Step 2 — sanity-check toolchain
# ---------------------------------------------------------------------------
for bin in gfortran cmake make; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ERROR: '$bin' not found on PATH. Install it and re-run." >&2
        exit 1
    fi
done

echo "==> Toolchain:"
gfortran --version | head -n 1
cmake --version   | head -n 1

# ---------------------------------------------------------------------------
# Step 3 — configure + build
# ---------------------------------------------------------------------------
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build . -- -j"$(nproc 2>/dev/null || echo 2)"

# ---------------------------------------------------------------------------
# Step 4 — tests (optional; tests/ is local-only and not shipped via git)
# ---------------------------------------------------------------------------
if [ -f "$ROOT_DIR/tests/test_physics.f90" ]; then
    echo "==> Running headless tests"
    ctest --output-on-failure
else
    echo "==> No tests/ directory present — skipping ctest"
fi

cd "$ROOT_DIR"

cat <<EOF

==> Build complete.

    Binary:        build/solarsim
    Run with:      ./run.sh
    Or directly:   cd build && ./solarsim

    First run writes build/config.toml — edit and re-run to tweak.
EOF
