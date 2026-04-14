/*
 * Minimal GLAD header for Phase 1 — OpenGL 3.3 Core.
 * Contains only the functions/types used in Phase 1.
 * Replace with full generated version from https://gen.glad.sh/
 * when extending for later phases.
 */

#ifndef __glad_h_
#define __glad_h_

#include <KHR/khrplatform.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- GLAD macro definitions ---- */
#ifndef GLAPI
#define GLAPI extern
#endif
#ifndef APIENTRY
#define APIENTRY
#endif
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

/* ---- OpenGL 3.3 Core types (minimal set) ---- */
typedef void          GLvoid;
typedef unsigned int  GLenum;
typedef unsigned int  GLbitfield;
typedef unsigned int  GLuint;
typedef int           GLint;
typedef int           GLsizei;
typedef unsigned char GLboolean;
typedef unsigned char GLubyte;
typedef float         GLfloat;
typedef float         GLclampf;
typedef double        GLdouble;
typedef double        GLclampd;
typedef char          GLchar;
typedef ptrdiff_t     GLintptr;
typedef ptrdiff_t     GLsizeiptr;

/* ---- GL constants ---- */
#define GL_DEPTH_BUFFER_BIT   0x00000100
#define GL_STENCIL_BUFFER_BIT 0x00000400
#define GL_COLOR_BUFFER_BIT   0x00004000
#define GL_NO_ERROR           0x0500

/* ---- Function pointer typedefs ---- */
typedef void (APIENTRYP PFNGLCLEARCOLORPROC)(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
typedef void (APIENTRYP PFNGLCLEARPROC)(GLbitfield mask);
typedef GLenum (APIENTRYP PFNGLGETERRORPROC)(void);
typedef void (APIENTRYP PFNGLVIEWPORTPROC)(GLint x, GLint y, GLsizei w, GLsizei h);

/* ---- GLAD function pointers (exported) ---- */
GLAPI PFNGLCLEARCOLORPROC glad_glClearColor;
GLAPI PFNGLCLEARPROC glad_glClear;
GLAPI PFNGLGETERRORPROC glad_glGetError;
GLAPI PFNGLVIEWPORTPROC glad_glViewport;

/* ---- Convenience macros ---- */
#define glClearColor glad_glClearColor
#define glClear      glad_glClear
#define glGetError   glad_glGetError
#define glViewport   glad_glViewport

/* ---- Fortran-callable wrappers ---- */
GLAPI void ss_glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
GLAPI void ss_glClear(GLbitfield mask);
GLAPI void ss_glViewport(GLint x, GLint y, GLsizei w, GLsizei h);
GLAPI GLenum ss_glGetError(void);

/* ---- GLAD loader ---- */
typedef void* (*GLADloadproc)(const char *name);
GLAPI int gladLoadGL(void);
GLAPI int gladLoadGLLoader(GLADloadproc loader);

#ifdef __cplusplus
}
#endif

#endif /* __glad_h_ */
