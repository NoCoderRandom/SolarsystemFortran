# Solar System Simulation (Fortran + OpenGL)

A real-time solar system simulation with realistic gravitational physics
and modern OpenGL rendering. Built with Fortran 2018 and OpenGL 3.3 Core.

## Phase 2 — Headless Physics Core

N-body gravity engine with Velocity Verlet integrator, J2000 initial
conditions for 9 bodies (Sun + 8 planets), and conservation verification.

### Run Physics Test

```bash
cd build
./test_physics
```

Expected output — all criteria PASS:
- Energy drift < 0.1% (actual: ~10⁻⁹%)
- Angular momentum drift < 0.01% (actual: ~10⁻¹⁴%)
- Earth orbital period error < 1 day (actual: ~0.35 days)

### Previous: Phase 1 — Foundation

Project skeleton with working toolchain: window, logging, GLAD, GLFW, CMake.

### Prerequisites (WSL2 Ubuntu)

```bash
sudo apt update
sudo apt install -y \
    gfortran \
    cmake \
    make \
    libglfw3-dev \
    build-essential
```

- **gfortran** ≥ 9 (for `-std=f2018` support)
- **cmake** ≥ 3.18
- **libglfw3-dev** ≥ 3.3
- **build-essential** (gcc, make, etc.)

### Build

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build .
```

For a release build:

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

### Run

```bash
./solarsim
```

Expected behavior:
- Opens a 1600×900 window titled "Solar System" on WSLg
- Solid dark blue-black background (`#05070d`)
- FPS logged to terminal once per second
- Press **ESC** or click the window close button to exit

### Clean

```bash
rm -rf build/
```

## Directory Layout

```
SolarsystemFortran/
├── CMakeLists.txt           # Main build config
├── README.md                # This file
├── src/
│   ├── core/
│   │   └── logging.f90      # Colored, timestamped logging
│   ├── physics/             # (Phase 2+: bodies, integrators)
│   ├── render/
│   │   ├── gl_bindings.f90  # Fortran–C interop for GLFW/GL
│   │   └── window.f90       # Window management
│   └── main.f90             # Entry point + main loop
├── shaders/                 # (Phase 3+: GLSL shaders)
├── assets/                  # (Phase 4+: textures, data)
├── external/
│   └── glad/
│       ├── include/         # GLAD headers (minimal Phase 1 set)
│       └── src/glad.c       # GLAD loader source
└── tests/                   # (Phase 2+: unit tests)
```

## Tech Stack

| Component        | Choice                          |
|------------------|---------------------------------|
| Language         | Fortran 2018                    |
| Graphics API     | OpenGL 3.3+ Core Profile        |
| Windowing        | GLFW 3.3+                       |
| GL Loader        | GLAD (minimal, extendable)      |
| Build System     | CMake 3.18+                     |
| Compiler         | gfortran (Wall, Wextra, f2018)  |
| Target Platform  | WSL2 Ubuntu + WSLg + NVIDIA GPU |

## Build Flags

| Configuration | Fortran Flags                    | C Flags          |
|---------------|----------------------------------|------------------|
| Debug         | `-Wall -Wextra -std=f2018 -Werror -g -O0` | `-Wall -Wextra -g -O0` |
| Release       | `-Wall -Wextra -std=f2018 -O3 -DNDEBUG`   | `-Wall -Wextra -O3 -DNDEBUG` |

## Next Phases

| Phase | Scope                                  |
|-------|----------------------------------------|
| 1     | Foundation: window, logging, CMake     |
| 2     | Physics: bodies, J2000, Verlet engine   |
| 3     | Integrator: RK4, adaptive dt           |
| 4     | Renderer: point sprites, shaders       |
| 5     | Camera: orbit camera, zoom             |
| 6     | Trails: line rendering, fading         |
| 7     | Textures: planet surfaces, bloom       |
| 8     | Polish: UI, config files, optimization |
