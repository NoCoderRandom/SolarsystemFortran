/*
 * GLAD loader for Phase 3 — OpenGL 3.3 Core.
 */
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <stdio.h>
#include <stdlib.h>
#include <glad/glad.h>

/* ---- Function pointer variables ---- */
PFNGLGENBUFFERSPROC              glad_glGenBuffers              = NULL;
PFNGLBINDBUFFERPROC              glad_glBindBuffer              = NULL;
PFNGLBUFFERDATAPROC              glad_glBufferData              = NULL;
PFNGLBUFFERSUBDATAPROC          glad_glBufferSubData           = NULL;
PFNGLDELETEBUFFERSPROC           glad_glDeleteBuffers           = NULL;
PFNGLGENVERTEXARRAYSPROC         glad_glGenVertexArrays         = NULL;
PFNGLBINDVERTEXARRAYPROC         glad_glBindVertexArray         = NULL;
PFNGLDELETEVERTEXARRAYSPROC      glad_glDeleteVertexArrays      = NULL;
PFNGLENABLEVERTEXATTRIBARRAYPROC glad_glEnableVertexAttribArray = NULL;
PFNGLVERTEXATTRIBPOINTERPROC     glad_glVertexAttribPointer     = NULL;
PFNGLVERTEXATTRIBDIVISORPROC     glad_glVertexAttribDivisor     = NULL;
PFNGLCREATESHADERPROC2           glad_glCreateShader            = NULL;
PFNGLSHADERSOURCEPROC            glad_glShaderSource            = NULL;
PFNGLCOMPILESHADERPROC           glad_glCompileShader           = NULL;
PFNGLGETSHADERIVPROC             glad_glGetShaderiv             = NULL;
PFNGLGETSHADERINFOLOGPROC        glad_glGetShaderInfoLog        = NULL;
PFNGLDELETESHADERPROC            glad_glDeleteShader            = NULL;
PFNGLCREATEPROGRAMPROC           glad_glCreateProgram           = NULL;
PFNGLATTACHSHADERPROC            glad_glAttachShader            = NULL;
PFNGLLINKPROGRAMPROC             glad_glLinkProgram             = NULL;
PFNGLGETPROGRAMIVPROC            glad_glGetProgramiv            = NULL;
PFNGLGETPROGRAMINFOLOGPROC       glad_glGetProgramInfoLog       = NULL;
PFNGLDELETEPROGRAMPROC           glad_glDeleteProgram           = NULL;
PFNGLUSEPROGRAMPROC              glad_glUseProgram              = NULL;
PFNGLGETUNIFORMLOCATIONPROC      glad_glGetUniformLocation      = NULL;
PFNGLUNIFORMMATRIX4FVPROC        glad_glUniformMatrix4fv        = NULL;
PFNGLUNIFORM3FPROC               glad_glUniform3f               = NULL;
PFNGLUNIFORM1FPROC               glad_glUniform1f               = NULL;
PFNGLUNIFORM1IPROC               glad_glUniform1i               = NULL;
PFNGLDRAWARRAYSPROC              glad_glDrawArrays              = NULL;
PFNGLDRAWELEMENTSPROC            glad_glDrawElements            = NULL;
PFNGLDRAWARRAYSINSTANCEDPROC     glad_glDrawArraysInstanced     = NULL;
PFNGLDRAWELEMENTSINSTANCEDPROC   glad_glDrawElementsInstanced   = NULL;
PFNGLENABLEPROC                  glad_glEnable                  = NULL;
PFNGLDISABLEPROC                 glad_glDisable                 = NULL;
PFNGLCULLFACEPROC                glad_glCullFace                = NULL;
PFNGLFRONTFACEPROC               glad_glFrontFace               = NULL;
PFNGLVIEWPORTPROC                glad_glViewport                = NULL;
PFNGLCLEARCOLORPROC              glad_glClearColor              = NULL;
PFNGLCLEARPROC                   glad_glClear                   = NULL;
PFNGLGETERRORPROC                glad_glGetError                = NULL;
PFNGLLINEWIDTHPROC               glad_glLineWidth               = NULL;
PFNGLDEPTHMASKPROC               glad_glDepthMask               = NULL;
PFNGLBLENDFUNCPROC               glad_glBlendFunc               = NULL;

static void* glad_gl_get_proc(const char *name) {
    return (void*)glfwGetProcAddress(name);
}

int gladLoadGLLoader(GLADloadproc loader) {
    int loaded = 0;
#define L(name, typedef_name) do { \
    typedef_name p = (typedef_name)loader(#name); \
    if (p) { loaded++; } \
    glad_##name = p; \
} while(0)

    L(glGenBuffers, PFNGLGENBUFFERSPROC);
    L(glBindBuffer, PFNGLBINDBUFFERPROC);
    L(glBufferData, PFNGLBUFFERDATAPROC);
    L(glBufferSubData, PFNGLBUFFERSUBDATAPROC);
    L(glDeleteBuffers, PFNGLDELETEBUFFERSPROC);
    L(glGenVertexArrays, PFNGLGENVERTEXARRAYSPROC);
    L(glBindVertexArray, PFNGLBINDVERTEXARRAYPROC);
    L(glDeleteVertexArrays, PFNGLDELETEVERTEXARRAYSPROC);
    L(glEnableVertexAttribArray, PFNGLENABLEVERTEXATTRIBARRAYPROC);
    L(glVertexAttribPointer, PFNGLVERTEXATTRIBPOINTERPROC);
    L(glVertexAttribDivisor, PFNGLVERTEXATTRIBDIVISORPROC);
    L(glCreateShader, PFNGLCREATESHADERPROC2);
    L(glShaderSource, PFNGLSHADERSOURCEPROC);
    L(glCompileShader, PFNGLCOMPILESHADERPROC);
    L(glGetShaderiv, PFNGLGETSHADERIVPROC);
    L(glGetShaderInfoLog, PFNGLGETSHADERINFOLOGPROC);
    L(glDeleteShader, PFNGLDELETESHADERPROC);
    L(glCreateProgram, PFNGLCREATEPROGRAMPROC);
    L(glAttachShader, PFNGLATTACHSHADERPROC);
    L(glLinkProgram, PFNGLLINKPROGRAMPROC);
    L(glGetProgramiv, PFNGLGETPROGRAMIVPROC);
    L(glGetProgramInfoLog, PFNGLGETPROGRAMINFOLOGPROC);
    L(glDeleteProgram, PFNGLDELETEPROGRAMPROC);
    L(glUseProgram, PFNGLUSEPROGRAMPROC);
    L(glGetUniformLocation, PFNGLGETUNIFORMLOCATIONPROC);
    L(glUniformMatrix4fv, PFNGLUNIFORMMATRIX4FVPROC);
    L(glUniform3f, PFNGLUNIFORM3FPROC);
    L(glUniform1f, PFNGLUNIFORM1FPROC);
    L(glUniform1i, PFNGLUNIFORM1IPROC);
    L(glDrawArrays, PFNGLDRAWARRAYSPROC);
    L(glDrawElements, PFNGLDRAWELEMENTSPROC);
    L(glDrawArraysInstanced, PFNGLDRAWARRAYSINSTANCEDPROC);
    L(glDrawElementsInstanced, PFNGLDRAWELEMENTSINSTANCEDPROC);
    L(glEnable, PFNGLENABLEPROC);
    L(glDisable, PFNGLDISABLEPROC);
    L(glCullFace, PFNGLCULLFACEPROC);
    L(glFrontFace, PFNGLFRONTFACEPROC);
    L(glViewport, PFNGLVIEWPORTPROC);
    L(glClearColor, PFNGLCLEARCOLORPROC);
    L(glClear, PFNGLCLEARPROC);
    L(glGetError, PFNGLGETERRORPROC);
    L(glLineWidth, PFNGLLINEWIDTHPROC);
    L(glDepthMask, PFNGLDEPTHMASKPROC);
    L(glBlendFunc, PFNGLBLENDFUNCPROC);
#undef L
    return loaded;
}

int gladLoadGL(void) {
    return gladLoadGLLoader((GLADloadproc)glad_gl_get_proc);
}

/* ---- Fortran-callable wrappers ---- */
void ss_glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a) { glad_glClearColor(r, g, b, a); }
void ss_glClear(GLbitfield mask) { glad_glClear(mask); }
void ss_glViewport(GLint x, GLint y, GLsizei w, GLsizei h) { glad_glViewport(x, y, w, h); }
GLenum ss_glGetError(void) { return glad_glGetError(); }
void ss_glEnable(GLenum cap) { glad_glEnable(cap); }
void ss_glDisable(GLenum cap) { glad_glDisable(cap); }
void ss_glLineWidth(GLfloat width) { glad_glLineWidth(width); }
void ss_glDepthMask(GLboolean flag) { glad_glDepthMask(flag); }
void ss_glBlendFunc(GLenum sfactor, GLenum dfactor) { glad_glBlendFunc(sfactor, dfactor); }
void ss_glCullFace(GLenum mode) { glad_glCullFace(mode); }
void ss_glFrontFace(GLenum mode) { glad_glFrontFace(mode); }
void ss_glGenBuffers(GLsizei n, GLuint *out) { glad_glGenBuffers(n, out); }
void ss_glBindBuffer(GLenum target, GLuint buffer) { glad_glBindBuffer(target, buffer); }
void ss_glBufferData(GLenum target, GLsizeiptr size, const void *data, GLenum usage) { glad_glBufferData(target, size, data, usage); }
void ss_glBufferSubData(GLenum target, GLintptr offset, GLsizeiptr size, const void *data) { glad_glBufferSubData(target, offset, size, data); }
void ss_glDeleteBuffers(GLsizei n, const GLuint *buffers) { glad_glDeleteBuffers(n, buffers); }
void ss_glGenVertexArrays(GLsizei n, GLuint *out) { glad_glGenVertexArrays(n, out); }
void ss_glBindVertexArray(GLuint array) { glad_glBindVertexArray(array); }
void ss_glDeleteVertexArrays(GLsizei n, const GLuint *arrays) { glad_glDeleteVertexArrays(n, arrays); }
void ss_glEnableVertexAttribArray(GLuint index) { glad_glEnableVertexAttribArray(index); }
void ss_glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer) { glad_glVertexAttribPointer(index, size, type, normalized, stride, pointer); }
void ss_glVertexAttribDivisor(GLuint index, GLuint divisor) { glad_glVertexAttribDivisor(index, divisor); }
GLuint ss_glCreateShader(GLenum type) { return glad_glCreateShader(type); }
void ss_glShaderSource(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length) { glad_glShaderSource(shader, count, string, length); }

/* ---- Helper: compile shader from Fortran string ---- */
void ss_glShaderSourceStr(GLuint shader, const GLchar *source, GLint length) {
    glad_glShaderSource(shader, 1, &source, &length);
}
void ss_glCompileShader(GLuint shader) { glad_glCompileShader(shader); }
void ss_glGetShaderiv(GLuint shader, GLenum pname, GLint *params) { glad_glGetShaderiv(shader, pname, params); }
void ss_glGetShaderInfoLog(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog) { glad_glGetShaderInfoLog(shader, bufSize, length, infoLog); }
void ss_glDeleteShader(GLuint shader) { glad_glDeleteShader(shader); }
GLuint ss_glCreateProgram(void) { return glad_glCreateProgram(); }
void ss_glAttachShader(GLuint program, GLuint shader) { glad_glAttachShader(program, shader); }
void ss_glLinkProgram(GLuint program) { glad_glLinkProgram(program); }
void ss_glGetProgramiv(GLuint program, GLenum pname, GLint *params) { glad_glGetProgramiv(program, pname, params); }
void ss_glGetProgramInfoLog(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog) { glad_glGetProgramInfoLog(program, bufSize, length, infoLog); }
void ss_glDeleteProgram(GLuint program) { glad_glDeleteProgram(program); }
void ss_glUseProgram(GLuint program) { glad_glUseProgram(program); }
GLint ss_glGetUniformLocation(GLuint program, const GLchar *name) { return glad_glGetUniformLocation(program, name); }
void ss_glUniformMatrix4fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat *value) { glad_glUniformMatrix4fv(location, count, transpose, value); }
void ss_glUniform3f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2) { glad_glUniform3f(location, v0, v1, v2); }
void ss_glUniform1f(GLint location, GLfloat v0) { glad_glUniform1f(location, v0); }
void ss_glUniform1i(GLint location, GLint v0) { glad_glUniform1i(location, v0); }
void ss_glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices) { glad_glDrawElements(mode, count, type, indices); }
void ss_glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instancecount) { glad_glDrawElementsInstanced(mode, count, type, indices, instancecount); }
void ss_glDrawArrays(GLenum mode, GLint first, GLsizei count) { glad_glDrawArrays(mode, first, count); }
