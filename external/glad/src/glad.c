/*
 * Minimal GLAD loader for Phase 1 — OpenGL 3.3 Core.
 * Uses glfwGetProcAddress for loading (standard GLFW + GLAD pattern).
 * Replace with full generated version from https://gen.glad.sh/
 * when extending for later phases.
 */

/* Must define BEFORE including glfw3.h — prevents GLFW from pulling
 * in system GL headers that would conflict with our GLAD definitions. */
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include <stdio.h>
#include <stdlib.h>
#include <glad/glad.h>

/* ---- Static function pointer variables ---- */
PFNGLCLEARCOLORPROC glad_glClearColor = NULL;
PFNGLCLEARPROC      glad_glClear      = NULL;
PFNGLGETERRORPROC   glad_glGetError   = NULL;
PFNGLVIEWPORTPROC   glad_glViewport   = NULL;

/* ---- Internal loader using glfwGetProcAddress ---- */
static void* glad_gl_get_proc_address(const char *name) {
    GLFWglproc proc = glfwGetProcAddress(name);
    return (void*)proc;
}

int gladLoadGLLoader(GLADloadproc loader) {
    int loaded = 0;

    glad_glClearColor = (PFNGLCLEARCOLORPROC)loader("glClearColor");
    if (glad_glClearColor) loaded++;

    glad_glClear = (PFNGLCLEARPROC)loader("glClear");
    if (glad_glClear) loaded++;

    glad_glGetError = (PFNGLGETERRORPROC)loader("glGetError");
    if (glad_glGetError) loaded++;

    glad_glViewport = (PFNGLVIEWPORTPROC)loader("glViewport");
    if (glad_glViewport) loaded++;

    return loaded;
}

int gladLoadGL(void) {
    return gladLoadGLLoader((GLADloadproc)glad_gl_get_proc_address);
}

/* ---- Fortran-callable wrappers (GLAD uses function pointers) ---- */

void ss_glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a) {
    glad_glClearColor(r, g, b, a);
}

void ss_glClear(GLbitfield mask) {
    glad_glClear(mask);
}

void ss_glViewport(GLint x, GLint y, GLsizei w, GLsizei h) {
    glad_glViewport(x, y, w, h);
}

GLenum ss_glGetError(void) {
    return glad_glGetError();
}
