# Technical notes

A reference for anyone reading the source to learn either modern Fortran
or real-time graphics fundamentals. Each section is short on purpose —
the code is the source of truth; this file explains *why* and *how*.

---

## Contents

1. [Fortran ↔ C interop](#1-fortran--c-interop)
2. [OpenGL bring-up in Fortran](#2-opengl-bring-up-in-fortran)
3. [Matrix convention (`mat4`)](#3-matrix-convention-mat4)
4. [Velocity Verlet integrator](#4-velocity-verlet-integrator)
5. [J2000 initial conditions](#5-j2000-initial-conditions)
6. [Timestep decoupling](#6-timestep-decoupling)
7. [HDR rendering pipeline](#7-hdr-rendering-pipeline)
8. [Planet shading](#8-planet-shading)
9. [Procedural Sun](#9-procedural-sun)
10. [Starfield and asteroid belt](#10-starfield-and-asteroid-belt)
11. [Orbit trails](#11-orbit-trails)
12. [Input and camera](#12-input-and-camera)
13. [Configuration loader](#13-configuration-loader)
14. [Performance instrumentation](#14-performance-instrumentation)

---

## 1. Fortran ↔ C interop

Everything off-language (GLFW, OpenGL, GLAD, stb_image) is reached through
the ISO-standard module `iso_c_binding`:

```fortran
use, intrinsic :: iso_c_binding, only: &
    c_int, c_float, c_double, c_char, &
    c_ptr, c_null_ptr, c_funptr, c_funloc, c_loc, c_associated
```

### Scalars and enums

C's `GLenum`, `GLint`, `GLuint` are all 32-bit signed in OpenGL. They map
cleanly to `integer(c_int)`. Enum constants are declared as parameters:

```fortran
integer(c_int), parameter, public :: GL_TRIANGLES = int(z'0004', c_int)
integer(c_int), parameter, public :: GL_FLOAT     = int(z'1406', c_int)
```

### Function prototypes

C signatures become Fortran `interface` blocks inside the body of a
wrapping procedure (or at module level):

```fortran
function glCreateShader(shader_type) result(id) &
        bind(c, name="glCreateShader")
    import :: c_int
    integer(c_int), value, intent(in) :: shader_type
    integer(c_int) :: id
end function glCreateShader
```

`value` is the key modifier — by default Fortran passes arguments by
reference. `value` switches to by-value, matching C calling convention.

### Pointers

Raw pointers land in Fortran as `type(c_ptr)`. To hand a Fortran array's
storage to OpenGL you use `c_loc`:

```fortran
real(c_float), allocatable, target :: verts(:)
! …populate verts…
call gl_buffer_data(GL_ARRAY_BUFFER, &
                    int(size(verts)*4, c_size_t), &
                    c_loc(verts(1)), GL_STATIC_DRAW)
```

The `target` attribute is **required** — without it `c_loc` is illegal.
The compiler can't safely pin the storage address of a non-target array.

### Callbacks

GLFW needs function pointers for key / mouse / framebuffer callbacks.
A Fortran procedure marked `bind(c)` has a C-compatible signature, and
`c_funloc` wraps it into a `c_funptr` you can hand to GLFW:

```fortran
subroutine key_callback(window, key, scancode, action, mods) bind(c)
    type(c_ptr), value, intent(in)     :: window
    integer(c_int), value, intent(in)  :: key, scancode, action, mods
    ! …
end subroutine
! ...
prev = glfwSetKeyCallback(window%ptr, c_funloc(key_callback))
```

### Strings

C strings are null-terminated `char*`; Fortran strings are not. For
`glShaderSource` and friends you append `char(0)`:

```fortran
character(len=:), allocatable, target :: src_c
src_c = shader_source // char(0)
call gl_shader_source(id, 1_c_int, c_loc(src_c), c_null_ptr)
```

### C source files

stb_image is compiled as a one-line C impl (`external/stb/stb_impl.c`)
that `#define`s `STB_IMAGE_IMPLEMENTATION` and includes the single
header. CMake builds it into the solarsim target; Fortran declares
`int stbi_load(...)` as a C interface and calls it.

---

## 2. OpenGL bring-up in Fortran

1. `glfwInit()` — initialises GLFW.
2. `glfwCreateWindow(w, h, "title", NULL, NULL)` — creates the window and
   an OpenGL context. We deliberately do **not** set
   `GLFW_CONTEXT_VERSION_MAJOR / MINOR` hints; the driver hands us its
   default profile, which on both Mesa and NVIDIA is ≥ 4.1 — plenty.
3. `glfwMakeContextCurrent(win)` — binds the GL context to the thread.
4. `gladLoadGL()` — walks GLAD's function table, resolving every
   `glSomething` symbol to a real function pointer. Until this runs, GL
   calls would segfault.
5. Query `GL_VENDOR` / `GL_RENDERER` / `GL_VERSION` and log them.
6. Install GLFW callbacks for input and framebuffer resize.

All of this lives in `src/render/window.f90`. From then on the program
calls GL like any other function.

---

## 3. Matrix convention (`mat4`)

`src/render/mat4.f90` uses **column-vector, column-major** storage to
match GLSL:

- `m%m(i, j)` is row `i`, column `j`.
- `mat4_to_array` flattens column-major: `arr(4*(j-1) + i) = m%m(i,j)`.
- A vertex is transformed as `gl_Position = u_proj * u_view * model * vec4(pos, 1)`.
- Basis vectors go in **rows** of `r%m`, translation goes in **col 4**
  (`r%m(1..3, 4)`).
- `mat4_mul_mat4(a, b)` computes `r[i,j] = Σ a[i,k] * b[k,j]`.

> **Note.** Phases 3–5 shipped with a mix of row-vector and column-vector
> conventions: `mat4_translate` wrote translation into row 4,
> `mat4_look_at`'s basis vectors were transposed, and `mat4_mul_*`
> computed `A^T * B` / `M^T * v`. Combined with a correct projection
> matrix, every vertex landed outside clip space and *nothing* rendered.
> `glGetError` was clean because no API call was illegal — the
> transforms were simply wrong. Fixed in Phase 6 (commit `6d7e585`).
> When adding any new matrix helper, preserve the invariant.

---

## 4. Velocity Verlet integrator

N-body gravity with `N = 9` (Sun + 8 planets) is a small problem, so we
use the simple `O(N²)` all-pairs Velocity Verlet:

```text
x(t+dt) = x(t) + v(t)·dt + ½ a(t)·dt²
a(t+dt) = force(x(t+dt)) / m
v(t+dt) = v(t) + ½ (a(t) + a(t+dt))·dt
```

Verlet is symplectic — it conserves a modified Hamiltonian exactly and
the real Hamiltonian on average, which is why energy drift over a
simulated year is ~10⁻⁹ % with a 1-hour timestep. Angular momentum
conservation is ~10⁻¹⁴ %, limited only by floating-point rounding.

**Softening.** Pairwise acceleration uses Plummer softening to avoid
the 1/r² singularity when close approaches happen numerically:

```
a_ij = G·m_j · (x_j - x_i) / (|x_j - x_i|² + ε²)^(3/2)
```

with `ε = 10⁶ m` — small enough to be invisible at planetary separations,
large enough to stay well-conditioned.

Tested by `tests/test_physics.f90`, which integrates for 365.25 days and
checks energy drift < 0.1 %, angular momentum drift < 0.01 %, and Earth's
orbital period error < 1 day. All three pass by orders of magnitude.

---

## 5. J2000 initial conditions

Body positions and velocities in `src/physics/ephemerides.f90` are taken
at the J2000.0 epoch (2000-01-01T12:00:00 TDB). Heliocentric coordinates
are read from standard ephemeris tables and converted to barycentric by
subtracting the barycentre velocity once at load time — otherwise the
whole system drifts linearly in the rendered frame.

`src/core/date_utils.f90` converts simulated seconds since J2000 into a
Gregorian `sim_date_t` for the HUD, handling leap years including the
non-leap century rule (2100 is not a leap year).

---

## 6. Timestep decoupling

Physics runs at a fixed 1-hour step (`PHYSICS_DT = 3600 s`). Rendering
runs at display refresh. The main loop uses the classic accumulator
pattern:

```fortran
accumulator = accumulator + frame_dt * cfg%time_scale
do while (accumulator >= PHYSICS_DT .and. step_count < MAX_STEPS_PER_FRAME)
    bodies_prev = sim%bodies
    call sim%step(PHYSICS_DT)
    accumulator = accumulator - PHYSICS_DT
    step_count = step_count + 1
end do
alpha = accumulator / PHYSICS_DT
call interpolate_bodies(bodies_interp, bodies_prev, sim%bodies, alpha)
```

`bodies_interp` is what the renderer uses — a linear interpolation
between the previous and current Verlet states. This gives smooth
rendering at any display rate without letting the physics timestep
depend on `frame_dt` (which would wreck conservation). `MAX_STEPS_PER_FRAME`
caps catch-up steps so a stall doesn't spiral.

---

## 7. HDR rendering pipeline

The entire Phase 6+ renderer is HDR. The scene is drawn into an
`RGBA16F` floating-point framebuffer, never into the default backbuffer.
After all geometry is submitted, a post-processing chain produces the
final SDR image.

```
[scene draw] → RGBA16F scene FBO
                    │
                    ├── bright pass (isolate pixels > threshold)
                    │       ↓
                    │   mip 0 → blur
                    │        → mip 1 → blur
                    │               → ... (cfg.bloom_mips levels)
                    │   ┌───────────┘
                    ↓   ↓
                 composite + ACES tonemap + gamma 2.2  → default FBO
```

**Bloom.** A dual-filter Kawase-like downsample/upsample blur over 5
mip levels. The bright pass isolates `luminance > cfg%bloom_threshold`
with a soft knee; successive downsample-then-blur passes spread the
highlights cheaply. Cost on an RTX-class GPU is <1 ms at 1600×900.

**Tonemap.** Narkowicz 2015 ACES fit:

```glsl
vec3 aces(vec3 x) {
    const float a=2.51, b=0.03, c=2.43, d=0.59, e=0.14;
    return clamp((x*(a*x+b)) / (x*(c*x+d)+e), 0.0, 1.0);
}
```

Then `pow(mapped, 1/2.2)` for display gamma. The scene FBO is cleared
to **linear black** — a non-zero clear would get lifted by the gamma
encode and leave the screen grey.

**Exposure** is a scalar multiplier before ACES, bound to `[` / `]`.

---

## 8. Planet shading

Per-body material (`material_t` in `src/render/material.f90`) carries:

- `albedo` — surface colour texture
- `normal` — tangent-space normal map (Earth only)
- `night`  — emissive city lights (Earth only)
- `specular` — grayscale mask, 1.0 over oceans (Earth only)
- `shininess`, `spec_scale`, `rim_power`, `rim_color`
- `kind` — enum: `GENERIC`, `EARTH`, `GAS_GIANT`

The `planet.frag` shader branches on `u_material_kind`:

- **Generic rocky** (Mercury, Mars): Lambert diffuse × albedo, very low
  Blinn–Phong specular.
- **Earth**: tangent-space normal-mapped Lambert + ocean-masked specular
  (shoreline glints), with night-side emission cross-faded by
  `smoothstep(dot(N, L), …)`, plus an atmospheric rim
  `pow(1 - dot(N, V), rim_power) * rim_color`.
- **Gas giant**: pure Lambert (no normal map), with a warm atmospheric
  rim — gives Jupiter/Saturn/Uranus/Neptune their characteristic soft
  limbs.

Light direction comes from the Sun's position uniform each frame; the
HDR Sun is also the light source for shading.

---

## 9. Procedural Sun

The Sun doesn't use any texture — `shaders/sun.frag` generates the
photosphere procedurally:

- Two octaves of 3D simplex-like noise sampled on a rotating sphere
  give the granulation pattern.
- Temperature is mapped to a black-body-ish ramp (white core → yellow
  → orange limbs).
- A `vec3` emissive output of ~3.5× multiplied by `sun_emissive_mul`
  pushes it above the bloom threshold so it lights up the pipeline.

A second pass (`corona.vert` / `corona.frag`) draws a billboarded
quad at the Sun's position with an exponential falloff — this is what
gives the soft outer halo you see in the overview shot.

---

## 10. Starfield and asteroid belt

Both are generated once at init from a seeded xorshift RNG so they're
reproducible across runs.

**Starfield** (`src/render/starfield.f90`): `cfg%starfield_count` stars,
uniformly sampled on a unit sphere, rendered as points far from the
camera with a depth-write-off pass (so everything else occludes them).
Each star gets a magnitude-biased radius and a colour drawn from a
B-V-to-RGB lookup so some are reddish, some bluish.

**Asteroid belt** (`src/render/asteroids.f90`): `cfg%asteroid_count`
objects distributed between `a_min` and `a_max` AU with:

- Semi-major axis `a` from a power-law PDF biased to the inner belt.
- Eccentricity `e ~ N(0, 0.05)` clamped to `[0, 0.3]`.
- Inclination `i ~ N(0, 3°)` — keeps the belt visibly flat.
- Mean anomaly `M` uniform on `[0, 2π]`.
- Orbital period from Kepler's third law: `T = 2π √(a³ / GM_sun)`.

Positions are computed each frame from `M(t) = M_0 + 2π · t / T`, solved
for eccentric anomaly via 5 Newton iterations on Kepler's equation,
then transformed into Cartesian space. All 15 000 asteroids are drawn
in **3 instanced `glDrawElementsInstanced` calls** over three icosahedron
meshes at LOD levels chosen by apparent size, to keep vertex count down.

---

## 11. Orbit trails

Each body owns a ring buffer of recent positions (`cfg%trail_length`
samples). Every frame each body pushes its interpolated position into
the buffer.

At draw time the buffer is uploaded as-is to a GPU-resident VBO; the
shader fades each segment by its **index** in the buffer
(`gl_VertexID`) — newest is fully opaque, oldest is transparent. This
avoids CPU-side recolouring.

Drawing uses `GL_LINE_STRIP` per body. The ring-buffer wrap is handled
by uploading the full buffer plus a `u_head` uniform; the shader
computes `t = (gl_VertexID - u_head + N) mod N / N` for the fade
coefficient.

---

## 12. Input and camera

`src/core/input.f90` captures GLFW key, mouse button, cursor position,
and scroll callbacks into a plain `input_state_t` struct: `key_held[]`,
`key_just_pressed[]`, `mouse_dx`, `mouse_dy`, `scroll_dy`. The main
loop calls `input_update` each frame to compute edges and clear per-
frame deltas.

`src/render/camera.f90` is an orbit camera with:

- **Spherical coords** `(azimuth, elevation, log_dist)` around a focus
  point.
- **Logarithmic zoom** — the slider is `log10(distance in AU)`, so one
  scroll tick is a multiplicative step regardless of scale. This is
  what lets you fly from Neptune to Earth in a few wheel clicks.
- **Smooth focus transition** — `focus_progress` ramps from 0 to 1 over
  ~0.5 s when you press a number key; the rendered focus lerps from
  old to new target.

View matrix is built from the spherical eye position and an up vector
via `mat4_look_at`; projection uses `mat4_perspective` at 60° FOV with
log-depth disabled (near/far are tight enough).

---

## 13. Configuration loader

`src/core/config_toml.f90` is a ~300-line TOML subset parser:

- **Sections** `[name]` are tracked in a state machine.
- **Key/value lines** `key = value` are split on the first `=`.
- **Comments** starting with `#` are stripped (quote-aware — `#` inside
  `"quoted strings"` is preserved).
- **Types** are inferred by `read(value, *, iostat=…)` into the target
  field; booleans accept `true / false / t / f / yes / no / on / off / 1 / 0`.
- Unknown `[section].key` pairs log a warning and continue — you can
  comment out obsolete keys safely.
- On first run, the missing file is written with current defaults via
  `config_toml_write_default`.

Strings map to fixed-width Fortran `character(len=…)` fields; trimming
and padding happen explicitly at every boundary, which is ugly but
safe.

---

## 14. Performance instrumentation

`src/core/perf.f90` provides named timing slots with
`perf_tic(name)` / `perf_toc(name)`. Internally each slot stores
sample count, summed ms, and peak ms. `perf_report` prints a formatted
table on shutdown:

```
physics              avg=  0.008 ms  peak=  0.027 ms  n=180
scene_render         avg= 97.779 ms  peak=192.283 ms  n=180
starfield            avg=  0.339 ms  peak=  4.418 ms  n=180
planets              avg=  2.530 ms  peak= 15.996 ms  n=180
asteroids            avg= 94.626 ms  peak=178.559 ms  n=180
trails_draw          avg=  0.052 ms  peak=  0.368 ms  n=180
bloom_tonemap        avg= 12.122 ms  peak=122.765 ms  n=180
```

Timings are wall-clock via `system_clock(count_rate=…)` — no frequency
calibration, no TSC tricks, just the Fortran intrinsic. On a real GPU
the asteroid pass is <1 ms; the numbers above are from an llvmpipe
software rasteriser and are therefore a worst case.

---

## References

- *Physically Based Rendering* (Pharr, Jakob, Humphreys) — ACES tonemap
  discussion and shading fundamentals.
- Narkowicz, K. *ACES Filmic Tone Mapping Curve* (2015) — the fit used
  in `tonemap.frag`.
- Hairer, Lubich, Wanner — *Geometric Numerical Integration* — why
  Verlet conserves energy.
- NASA JPL *HORIZONS* system — source of J2000 ephemerides.
- Meeus, *Astronomical Algorithms* — date / time conversions.
