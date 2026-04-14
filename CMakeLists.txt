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
# Source files
# ---------------------------------------------------------------------------
set(FORTRAN_SOURCES
    src/core/logging.f90
    src/render/gl_bindings.f90
    src/render/window.f90
    src/main.f90
)

# ---------------------------------------------------------------------------
# Target: solarsim
# ---------------------------------------------------------------------------
add_executable(solarsim ${FORTRAN_SOURCES} ${GLAD_SOURCES})

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
# CTest (placeholder — extended in later phases)
# ---------------------------------------------------------------------------
enable_testing()

# Placeholder test — extended in later phases
# add_test(NAME unit_tests COMMAND tests_runner)

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Fortran compiler: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
message(STATUS "C compiler:       ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
