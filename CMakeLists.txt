cmake_minimum_required(VERSION 3.18)
project(solarsim
    VERSION 0.1.0
    DESCRIPTION "Solar System Simulation"
    LANGUAGES C Fortran
)

# ---------------------------------------------------------------------------
# Build-type defaults
# ---------------------------------------------------------------------------
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

# ---------------------------------------------------------------------------
# Compiler flags: gfortran with -Wall -Wextra -std=f2018
# ---------------------------------------------------------------------------
set(CMAKE_Fortran_FLAGS_COMMON "-Wall -Wextra -std=f2018")
set(CMAKE_Fortran_FLAGS_DEBUG   "${CMAKE_Fortran_FLAGS_COMMON} -Werror -g -O0")
set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_COMMON} -O3 -DNDEBUG")

set(CMAKE_C_FLAGS_DEBUG   "-Wall -Wextra -g -O0")
set(CMAKE_C_FLAGS_RELEASE "-Wall -Wextra -O3 -DNDEBUG")

# ---------------------------------------------------------------------------
# Find GLFW3
# ---------------------------------------------------------------------------
find_package(glfw3 3.3 REQUIRED)

# ---------------------------------------------------------------------------
# GLAD
# ---------------------------------------------------------------------------
set(GLAD_SOURCES    external/glad/src/glad.c)
set(GLAD_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/external/glad/include)

# ---------------------------------------------------------------------------
# Shared sources (used by both solarsim and test_physics)
# ---------------------------------------------------------------------------
set(CORE_SOURCES
    src/core/logging.f90
    src/core/constants.f90
    src/core/vector3d.f90
    src/core/input.f90
    src/core/config.f90
    src/core/date_utils.f90
)

# ---------------------------------------------------------------------------
# Physics sources
# ---------------------------------------------------------------------------
set(PHYSICS_SOURCES
    src/physics/body.f90
    src/physics/ephemerides.f90
    src/physics/integrator.f90
    src/physics/simulation.f90
)

# ---------------------------------------------------------------------------
# Render sources (Phase 3+)
# ---------------------------------------------------------------------------
set(RENDER_SOURCES
    src/render/gl_bindings.f90
    src/render/mat4.f90
    src/render/mesh.f90
    src/render/shader.f90
    src/render/camera.f90
    src/render/renderer.f90
    src/render/window.f90
    src/render/hud_text.f90
)

# ---------------------------------------------------------------------------
# Target: solarsim
# ---------------------------------------------------------------------------
add_executable(solarsim
    src/main.f90
    ${CORE_SOURCES}
    ${PHYSICS_SOURCES}
    ${RENDER_SOURCES}
    ${GLAD_SOURCES}
)

target_include_directories(solarsim PRIVATE
    ${GLAD_INCLUDE_DIR}
)

target_link_libraries(solarsim PRIVATE
    glfw
    ${CMAKE_DL_LIBS}
)

set_target_properties(solarsim PROPERTIES
    C_STANDARD 11
    Fortran_STANDARD 2018
)

# ---------------------------------------------------------------------------
# Target: test_physics (Phase 2, headless — no render/window deps)
# ---------------------------------------------------------------------------
add_executable(test_physics
    tests/test_physics.f90
    src/core/logging.f90
    src/core/constants.f90
    src/core/vector3d.f90
    src/physics/body.f90
    src/physics/ephemerides.f90
    src/physics/integrator.f90
    src/physics/simulation.f90
)

set_target_properties(test_physics PROPERTIES
    Fortran_STANDARD 2018
)

# ---------------------------------------------------------------------------
# Target: test_date_utils (Phase 4, headless)
# ---------------------------------------------------------------------------
add_executable(test_date_utils
    tests/test_date_utils.f90
    src/core/constants.f90
    src/core/date_utils.f90
)

set_target_properties(test_date_utils PROPERTIES
    Fortran_STANDARD 2018
)

# ---------------------------------------------------------------------------
# Copy assets/shaders into build tree for runtime loading
# ---------------------------------------------------------------------------
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/shaders
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/assets
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)

# ---------------------------------------------------------------------------
# CTest
# ---------------------------------------------------------------------------
enable_testing()
add_test(NAME test_physics COMMAND test_physics)
add_test(NAME test_date_utils COMMAND test_date_utils)

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Fortran compiler: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
message(STATUS "C compiler:       ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
