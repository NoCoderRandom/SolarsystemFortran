#!/usr/bin/env bash
#
# install.sh — Linux / WSL2 bootstrapper for the Solar System Simulation.
#
# Tested on Ubuntu 22.04 / 24.04 under WSL2 and native Linux.
# On Debian-family systems it can install the required packages automatically.
# On other distros install the equivalent packages manually, then rerun with
# --no-apt.
#
# Usage:
#   ./install.sh             # install deps, build Release, run tests if present
#   ./install.sh --deps-only # install deps, skip CMake build
#   ./install.sh --no-apt    # skip apt-get step (deps already installed)
#   ./install.sh --debug     # build Debug instead of Release
#
set -euo pipefail

SKIP_APT=0
BUILD_TYPE="Release"
DEPS_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --no-apt) SKIP_APT=1 ;;
        --deps-only) DEPS_ONLY=1 ;;
        --debug)  BUILD_TYPE="Debug" ;;
        -h|--help)
            sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APT_REQUIREMENTS_FILE="$ROOT_DIR/requirements/ubuntu-apt.txt"

is_wsl2() {
    grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
}

read_apt_packages() {
    if [ ! -f "$APT_REQUIREMENTS_FILE" ]; then
        echo "ERROR: missing requirements file: $APT_REQUIREMENTS_FILE" >&2
        exit 1
    fi

    grep -Ev '^\s*($|#)' "$APT_REQUIREMENTS_FILE"
}

cd "$ROOT_DIR"

echo "==> Solar System Simulation — installer"
echo "    Root:        $ROOT_DIR"
echo "    Build type:  $BUILD_TYPE"

if is_wsl2; then
    echo "    Environment: WSL2"
else
    echo "    Environment: Linux"
fi

# ---------------------------------------------------------------------------
# Step 1 — system packages
# ---------------------------------------------------------------------------
if [ "$SKIP_APT" -eq 0 ] && command -v apt-get >/dev/null 2>&1; then
    echo "==> Installing system packages (requires sudo)"
    sudo apt-get update
    mapfile -t APT_PACKAGES < <(read_apt_packages)
    sudo apt-get install -y "${APT_PACKAGES[@]}"
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

if [ "$DEPS_ONLY" -eq 1 ]; then
    cat <<EOF

==> Dependencies installed.

    Next step:
      ./install.sh --no-apt
EOF
    exit 0
fi

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
