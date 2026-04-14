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
# GLAD — C source (generated / placed in external/glad)
# ---------------------------------------------------------------------------
set(GLAD_SOURCES
    external/glad/src/glad.c
)
set(GLAD_INCLUDE_DIR
    ${CMAKE_CURRENT_SOURCE_DIR}/external/glad/include
)

# ---------------------------------------------------------------------------
# Source files — solarsim (Phase 1 executable)
# ---------------------------------------------------------------------------
set(SOLARSIM_SOURCES
    src/core/logging.f90
    src/render/gl_bindings.f90
    src/render/window.f90
    src/main.f90
)

# ---------------------------------------------------------------------------
# Target: solarsim
# ---------------------------------------------------------------------------
add_executable(solarsim ${SOLARSIM_SOURCES} ${GLAD_SOURCES})

target_include_directories(solarsim PRIVATE
    ${GLAD_INCLUDE_DIR}
)

target_link_libraries(solarsim PRIVATE
    glfw
    ${CMAKE_DL_LIBS}          # for dlopen / dlsym on Linux
)

# Require C11 and Fortran 2018 at the target level
set_target_properties(solarsim PROPERTIES
    C_STANDARD 11
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
# Physics core (Phase 2) — headless, used by test_physics and later solarsim
# ---------------------------------------------------------------------------
set(PHYSICS_SOURCES
    src/core/constants.f90
    src/core/vector3d.f90
    src/physics/body.f90
    src/physics/ephemerides.f90
    src/physics/integrator.f90
    src/physics/simulation.f90
)

# Physics test executable
add_executable(test_physics
    tests/test_physics.f90
    src/core/logging.f90
    ${PHYSICS_SOURCES}
)

set_target_properties(test_physics PROPERTIES
    Fortran_STANDARD 2018
)

# ---------------------------------------------------------------------------
# CTest
# ---------------------------------------------------------------------------
enable_testing()

add_test(NAME test_physics COMMAND test_physics)

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Fortran compiler: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
message(STATUS "C compiler:       ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
