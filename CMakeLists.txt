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
# stb_image (single-header, vendored)
# ---------------------------------------------------------------------------
set(STB_SOURCES      external/stb/stb_impl.c)
set(STB_INCLUDE_DIR  ${CMAKE_CURRENT_SOURCE_DIR}/external/stb)

# ---------------------------------------------------------------------------
# Shared sources (used by both solarsim and test_physics)
# ---------------------------------------------------------------------------
set(CORE_SOURCES
    src/core/logging.f90
    src/core/constants.f90
    src/core/vector3d.f90
    src/core/input.f90
    src/core/config.f90
    src/core/config_toml.f90
    src/core/perf.f90
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
    src/render/framebuffer.f90
    src/render/camera.f90
    src/render/display_scale.f90
    src/render/texture.f90
    src/render/material.f90
    src/render/rings.f90
    src/render/renderer.f90
    src/render/window.f90
    src/render/hud_text.f90
    src/render/trails.f90
    src/render/sun.f90
    src/render/starfield.f90
    src/render/asteroids.f90
    src/render/post.f90
    src/render/demo.f90
)

# ---------------------------------------------------------------------------
# UI sources (top-bar menu + dropdowns)
# ---------------------------------------------------------------------------
set(UI_SOURCES
    src/ui/menu.f90
)

# ---------------------------------------------------------------------------
# Spacecraft sources (framework seam; disabled by config by default)
# ---------------------------------------------------------------------------
set(SPACECRAFT_SOURCES
    src/render/spacecraft_renderer.f90
    src/spacecraft/spacecraft_catalog.f90
    src/spacecraft/spacecraft_camera.f90
    src/spacecraft/spacecraft_types.f90
    src/spacecraft/spacecraft_materials.f90
    src/spacecraft/spacecraft_assets.f90
    src/spacecraft/spacecraft_system.f90
)

# ---------------------------------------------------------------------------
# Target: solarsim
# ---------------------------------------------------------------------------
add_executable(solarsim
    src/main.f90
    ${CORE_SOURCES}
    ${PHYSICS_SOURCES}
    ${RENDER_SOURCES}
    ${UI_SOURCES}
    ${SPACECRAFT_SOURCES}
    ${GLAD_SOURCES}
    ${STB_SOURCES}
)

target_include_directories(solarsim PRIVATE
    ${GLAD_INCLUDE_DIR}
    ${STB_INCLUDE_DIR}
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
# Headless test targets — guarded so a GitHub clone without tests/
# (see .gitignore) still configures and builds cleanly. Tests are kept
# local-only; the main binary never depends on them.
# ---------------------------------------------------------------------------
set(SOLARSIM_HAS_TESTS FALSE)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_physics.f90")
    set(SOLARSIM_HAS_TESTS TRUE)
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
    set_target_properties(test_physics PROPERTIES Fortran_STANDARD 2018)
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_date_utils.f90")
    set(SOLARSIM_HAS_TESTS TRUE)
    add_executable(test_date_utils
        tests/test_date_utils.f90
        src/core/constants.f90
        src/core/date_utils.f90
    )
    set_target_properties(test_date_utils PROPERTIES Fortran_STANDARD 2018)
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_spacecraft_controls.f90")
    set(SOLARSIM_HAS_TESTS TRUE)
    add_executable(test_spacecraft_controls
        tests/test_spacecraft_controls.f90
        src/core/logging.f90
        src/core/constants.f90
        src/core/vector3d.f90
        src/core/input.f90
        src/core/config.f90
        src/core/config_toml.f90
        src/physics/body.f90
        src/render/gl_bindings.f90
        src/render/mat4.f90
        src/render/mesh.f90
        src/render/shader.f90
        src/render/texture.f90
        src/render/material.f90
        src/render/camera.f90
        src/render/spacecraft_renderer.f90
        src/spacecraft/spacecraft_catalog.f90
        src/spacecraft/spacecraft_types.f90
        src/spacecraft/spacecraft_materials.f90
        src/spacecraft/spacecraft_assets.f90
        src/spacecraft/spacecraft_system.f90
        ${GLAD_SOURCES}
        ${STB_SOURCES}
    )
    target_include_directories(test_spacecraft_controls PRIVATE
        ${GLAD_INCLUDE_DIR}
        ${STB_INCLUDE_DIR}
    )
    target_link_libraries(test_spacecraft_controls PRIVATE
        glfw
        ${CMAKE_DL_LIBS}
    )
    set_target_properties(test_spacecraft_controls PROPERTIES
        C_STANDARD 11
        Fortran_STANDARD 2018
    )
endif()

# ---------------------------------------------------------------------------
# Copy shaders into build tree on every build so edits take effect immediately
# ---------------------------------------------------------------------------
file(GLOB_RECURSE _SHADER_FILES
     ${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.vert
     ${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.frag
)
add_custom_target(copy_shaders ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_CURRENT_SOURCE_DIR}/shaders
            ${CMAKE_CURRENT_BINARY_DIR}/shaders
    DEPENDS ${_SHADER_FILES}
    COMMENT "Syncing shaders → build/shaders/"
)
add_dependencies(solarsim copy_shaders)

# ---------------------------------------------------------------------------
# Copy assets into build tree (configure-time only — large, rarely changes)
# ---------------------------------------------------------------------------
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/assets
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)

# Ensure screenshots/ exists in the build tree (F2 writes here at runtime).
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/screenshots)

# ---------------------------------------------------------------------------
# CTest (only registered when the local tests/ directory is present)
# ---------------------------------------------------------------------------
enable_testing()
if(SOLARSIM_HAS_TESTS)
    if(TARGET test_physics)
        add_test(NAME test_physics COMMAND test_physics)
    endif()
    if(TARGET test_date_utils)
        add_test(NAME test_date_utils COMMAND test_date_utils)
    endif()
    if(TARGET test_spacecraft_controls)
        add_test(NAME test_spacecraft_controls COMMAND test_spacecraft_controls)
    endif()
endif()

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Fortran compiler: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
message(STATUS "C compiler:       ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
