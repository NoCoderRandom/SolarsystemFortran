/*
 * GLAD header for Phase 3 — OpenGL 3.3 Core.
 * Contains functions for buffers, shaders, VAOs, uniforms, instanced draw,
 * enable/disable, viewport, clear, swap.
 * Replace with full generated version from https://gen.glad.sh/ later.
 */

#ifndef __glad_h_
#define __glad_h_

#include <KHR/khrplatform.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- GLAD macros ---- */
#ifndef GLAPI
#define GLAPI extern
#endif
#ifndef APIENTRY
#define APIENTRY
#endif
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

/* ---- Types ---- */
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
typedef char          GLchar;
typedef ptrdiff_t     GLintptr;
typedef ptrdiff_t     GLsizeiptr;

/* ---- Constants ---- */
#define GL_COLOR_BUFFER_BIT       0x00004000
#define GL_DEPTH_BUFFER_BIT       0x00000100
#define GL_ARRAY_BUFFER           0x8892
#define GL_ELEMENT_ARRAY_BUFFER   0x8893
#define GL_STATIC_DRAW            0x88E4
#define GL_DYNAMIC_DRAW           0x88E8
#define GL_STREAM_DRAW            0x88E0
#define GL_FLOAT                  0x1406
#define GL_FALSE                  0
#define GL_TRUE                   1
#define GL_TRIANGLES              0x0004
#define GL_VERTEX_SHADER          0x8B31
#define GL_FRAGMENT_SHADER        0x8B30
#define GL_COMPILE_STATUS         0x8B81
#define GL_LINK_STATUS            0x8B82
#define GL_INFO_LOG_LENGTH        0x8B84
#define GL_VERTEX_ATTRIB_ARRAY_ENABLED        0x8622
#define GL_VERTEX_ATTRIB_ARRAY_SIZE           0x8623
#define GL_VERTEX_ATTRIB_ARRAY_STRIDE         0x8624
#define GL_VERTEX_ATTRIB_ARRAY_TYPE           0x8625
#define GL_VERTEX_ATTRIB_ARRAY_POINTER        0x8645
#define GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING 0x889F
#define GL_VERTEX_ATTRIB_ARRAY_DIVISOR        0x88FE
#define GL_DEPTH_TEST             0x0B71
#define GL_CULL_FACE              0x0B44
#define GL_BACK                   0x0405
#define GL_CCW                    0x0900
#define GL_FRONT_FACE             0x0B46
#define GL_NO_ERROR               0x0500

/* ---- Function pointer typedefs ---- */
typedef void (APIENTRYP PFNGLGENBUFFERSPROC)(GLsizei n, GLuint *buffers);
typedef void (APIENTRYP PFNGLBINDBUFFERPROC)(GLenum target, GLuint buffer);
typedef void (APIENTRYP PFNGLBUFFERDATAPROC)(GLenum target, GLsizeiptr size, const void *data, GLenum usage);
typedef void (APIENTRYP PFNGLBUFFERSUBDATAPROC)(GLenum target, GLintptr offset, GLsizeiptr size, const void *data);
typedef void (APIENTRYP PFNGLDELETEBUFFERSPROC)(GLsizei n, const GLuint *buffers);
typedef void (APIENTRYP PFNGLGENVERTEXARRAYSPROC)(GLsizei n, GLuint *arrays);
typedef void (APIENTRYP PFNGLBINDVERTEXARRAYPROC)(GLuint array);
typedef void (APIENTRYP PFNGLDELETEVERTEXARRAYSPROC)(GLsizei n, const GLuint *arrays);
typedef void (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC)(GLuint index);
typedef void (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
typedef void (APIENTRYP PFNGLVERTEXATTRIBDIVISORPROC)(GLuint index, GLuint divisor);
typedef void (APIENTRYP PFNGLCREATESHADERPROC)(GLenum type) ;
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC2)(GLenum type);
typedef void (APIENTRYP PFNGLSHADERSOURCEPROC)(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
typedef void (APIENTRYP PFNGLCOMPILESHADERPROC)(GLuint shader);
typedef void (APIENTRYP PFNGLGETSHADERIVPROC)(GLuint shader, GLenum pname, GLint *params);
typedef void (APIENTRYP PFNGLGETSHADERINFOLOGPROC)(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
typedef void (APIENTRYP PFNGLDELETESHADERPROC)(GLuint shader);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC)(void);
typedef void (APIENTRYP PFNGLATTACHSHADERPROC)(GLuint program, GLuint shader);
typedef void (APIENTRYP PFNGLLINKPROGRAMPROC)(GLuint program);
typedef void (APIENTRYP PFNGLGETPROGRAMIVPROC)(GLuint program, GLenum pname, GLint *params);
typedef void (APIENTRYP PFNGLGETPROGRAMINFOLOGPROC)(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
typedef void (APIENTRYP PFNGLDELETEPROGRAMPROC)(GLuint program);
typedef void (APIENTRYP PFNGLUSEPROGRAMPROC)(GLuint program);
typedef GLint (APIENTRYP PFNGLGETUNIFORMLOCATIONPROC)(GLuint program, const GLchar *name);
typedef void (APIENTRYP PFNGLUNIFORMMATRIX4FVPROC)(GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
typedef void (APIENTRYP PFNGLUNIFORM3FPROC)(GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
typedef void (APIENTRYP PFNGLUNIFORM1FPROC)(GLint location, GLfloat v0);
typedef void (APIENTRYP PFNGLUNIFORM1IPROC)(GLint location, GLint v0);
typedef void (APIENTRYP PFNGLDRAWARRAYSPROC)(GLenum mode, GLint first, GLsizei count);
typedef void (APIENTRYP PFNGLDRAWELEMENTSPROC)(GLenum mode, GLsizei count, GLenum type, const void *indices);
typedef void (APIENTRYP PFNGLDRAWARRAYSINSTANCEDPROC)(GLenum mode, GLint first, GLsizei count, GLsizei instancecount);
typedef void (APIENTRYP PFNGLDRAWELEMENTSINSTANCEDPROC)(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instancecount);
typedef void (APIENTRYP PFNGLENABLEPROC)(GLenum cap);
typedef void (APIENTRYP PFNGLDISABLEPROC)(GLenum cap);
typedef void (APIENTRYP PFNGLCULLFACEPROC)(GLenum mode);
typedef void (APIENTRYP PFNGLFRONTFACEPROC)(GLenum mode);
typedef void (APIENTRYP PFNGLVIEWPORTPROC)(GLint x, GLint y, GLsizei w, GLsizei h);
typedef void (APIENTRYP PFNGLCLEARCOLORPROC)(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
typedef void (APIENTRYP PFNGLCLEARPROC)(GLbitfield mask);
typedef GLenum (APIENTRYP PFNGLGETERRORPROC)(void);

/* ---- GLAD function pointer variables ---- */
GLAPI PFNGLGENBUFFERSPROC glad_glGenBuffers;
GLAPI PFNGLBINDBUFFERPROC glad_glBindBuffer;
GLAPI PFNGLBUFFERDATAPROC glad_glBufferData;
GLAPI PFNGLBUFFERSUBDATAPROC glad_glBufferSubData;
GLAPI PFNGLDELETEBUFFERSPROC glad_glDeleteBuffers;
GLAPI PFNGLGENVERTEXARRAYSPROC glad_glGenVertexArrays;
GLAPI PFNGLBINDVERTEXARRAYPROC glad_glBindVertexArray;
GLAPI PFNGLDELETEVERTEXARRAYSPROC glad_glDeleteVertexArrays;
GLAPI PFNGLENABLEVERTEXATTRIBARRAYPROC glad_glEnableVertexAttribArray;
GLAPI PFNGLVERTEXATTRIBPOINTERPROC glad_glVertexAttribPointer;
GLAPI PFNGLVERTEXATTRIBDIVISORPROC glad_glVertexAttribDivisor;
GLAPI PFNGLCREATESHADERPROC2 glad_glCreateShader;
GLAPI PFNGLSHADERSOURCEPROC glad_glShaderSource;
GLAPI PFNGLCOMPILESHADERPROC glad_glCompileShader;
GLAPI PFNGLGETSHADERIVPROC glad_glGetShaderiv;
GLAPI PFNGLGETSHADERINFOLOGPROC glad_glGetShaderInfoLog;
GLAPI PFNGLDELETESHADERPROC glad_glDeleteShader;
GLAPI PFNGLCREATEPROGRAMPROC glad_glCreateProgram;
GLAPI PFNGLATTACHSHADERPROC glad_glAttachShader;
GLAPI PFNGLLINKPROGRAMPROC glad_glLinkProgram;
GLAPI PFNGLGETPROGRAMIVPROC glad_glGetProgramiv;
GLAPI PFNGLGETPROGRAMINFOLOGPROC glad_glGetProgramInfoLog;
GLAPI PFNGLDELETEPROGRAMPROC glad_glDeleteProgram;
GLAPI PFNGLUSEPROGRAMPROC glad_glUseProgram;
GLAPI PFNGLGETUNIFORMLOCATIONPROC glad_glGetUniformLocation;
GLAPI PFNGLUNIFORMMATRIX4FVPROC glad_glUniformMatrix4fv;
GLAPI PFNGLUNIFORM3FPROC glad_glUniform3f;
GLAPI PFNGLUNIFORM1FPROC glad_glUniform1f;
GLAPI PFNGLUNIFORM1IPROC glad_glUniform1i;
GLAPI PFNGLDRAWARRAYSPROC glad_glDrawArrays;
GLAPI PFNGLDRAWELEMENTSPROC glad_glDrawElements;
GLAPI PFNGLDRAWARRAYSINSTANCEDPROC glad_glDrawArraysInstanced;
GLAPI PFNGLDRAWELEMENTSINSTANCEDPROC glad_glDrawElementsInstanced;
GLAPI PFNGLENABLEPROC glad_glEnable;
GLAPI PFNGLDISABLEPROC glad_glDisable;
GLAPI PFNGLCULLFACEPROC glad_glCullFace;
GLAPI PFNGLFRONTFACEPROC glad_glFrontFace;
GLAPI PFNGLVIEWPORTPROC glad_glViewport;
GLAPI PFNGLCLEARCOLORPROC glad_glClearColor;
GLAPI PFNGLCLEARPROC glad_glClear;
GLAPI PFNGLGETERRORPROC glad_glGetError;

/* ---- Convenience macros ---- */
#define glGenBuffers              glad_glGenBuffers
#define glBindBuffer              glad_glBindBuffer
#define glBufferData              glad_glBufferData
#define glDeleteBuffers           glad_glDeleteBuffers
#define glGenVertexArrays         glad_glGenVertexArrays
#define glBindVertexArray         glad_glBindVertexArray
#define glDeleteVertexArrays      glad_glDeleteVertexArrays
#define glEnableVertexAttribArray glad_glEnableVertexAttribArray
#define glVertexAttribPointer     glad_glVertexAttribPointer
#define glVertexAttribDivisor     glad_glVertexAttribDivisor
#define glCreateShader            glad_glCreateShader
#define glShaderSource            glad_glShaderSource
#define glCompileShader           glad_glCompileShader
#define glGetShaderiv             glad_glGetShaderiv
#define glGetShaderInfoLog        glad_glGetShaderInfoLog
#define glDeleteShader            glad_glDeleteShader
#define glCreateProgram           glad_glCreateProgram
#define glAttachShader            glad_glAttachShader
#define glLinkProgram             glad_glLinkProgram
#define glGetProgramiv            glad_glGetProgramiv
#define glGetProgramInfoLog       glad_glGetProgramInfoLog
#define glDeleteProgram           glad_glDeleteProgram
#define glUseProgram              glad_glUseProgram
#define glGetUniformLocation      glad_glGetUniformLocation
#define glUniformMatrix4fv        glad_glUniformMatrix4fv
#define glUniform3f               glad_glUniform3f
#define glUniform1f               glad_glUniform1f
#define glUniform1i               glad_glUniform1i
#define glDrawArrays              glad_glDrawArrays
#define glDrawElements            glad_glDrawElements
#define glDrawArraysInstanced     glad_glDrawArraysInstanced
#define glDrawElementsInstanced   glad_glDrawElementsInstanced
#define glEnable                  glad_glEnable
#define glDisable                 glad_glDisable
#define glCullFace                glad_glCullFace
#define glFrontFace               glad_glFrontFace
#define glViewport                glad_glViewport
#define glClearColor              glad_glClearColor
#define glClear                   glad_glClear
#define glGetError                glad_glGetError

/* ---- GLAD loader ---- */
typedef void* (*GLADloadproc)(const char *name);
GLAPI int gladLoadGL(void);
GLAPI int gladLoadGLLoader(GLADloadproc loader);

/* ---- Fortran-callable wrappers ---- */
GLAPI void   ss_glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
GLAPI void   ss_glClear(GLbitfield mask);
GLAPI void   ss_glViewport(GLint x, GLint y, GLsizei w, GLsizei h);
GLAPI GLenum ss_glGetError(void);
GLAPI void   ss_glEnable(GLenum cap);
GLAPI void   ss_glDisable(GLenum cap);
GLAPI void   ss_glCullFace(GLenum mode);
GLAPI void   ss_glFrontFace(GLenum mode);
GLAPI void   ss_glGenBuffers(GLsizei n, GLuint *out);
GLAPI void   ss_glBindBuffer(GLenum target, GLuint buffer);
GLAPI void   ss_glBufferData(GLenum target, GLsizeiptr size, const void *data, GLenum usage);
GLAPI void   ss_glBufferSubData(GLenum target, GLintptr offset, GLsizeiptr size, const void *data);
GLAPI void   ss_glDeleteBuffers(GLsizei n, const GLuint *buffers);
GLAPI void   ss_glGenVertexArrays(GLsizei n, GLuint *out);
GLAPI void   ss_glBindVertexArray(GLuint array);
GLAPI void   ss_glDeleteVertexArrays(GLsizei n, const GLuint *arrays);
GLAPI void   ss_glEnableVertexAttribArray(GLuint index);
GLAPI void   ss_glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
GLAPI void   ss_glVertexAttribDivisor(GLuint index, GLuint divisor);
GLAPI GLuint ss_glCreateShader(GLenum type);
GLAPI void   ss_glShaderSource(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
GLAPI void   ss_glShaderSourceStr(GLuint shader, const GLchar *source, GLint length);
GLAPI void   ss_glCompileShader(GLuint shader);
GLAPI void   ss_glGetShaderiv(GLuint shader, GLenum pname, GLint *params);
GLAPI void   ss_glGetShaderInfoLog(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
GLAPI void   ss_glDeleteShader(GLuint shader);
GLAPI GLuint ss_glCreateProgram(void);
GLAPI void   ss_glAttachShader(GLuint program, GLuint shader);
GLAPI void   ss_glLinkProgram(GLuint program);
GLAPI void   ss_glGetProgramiv(GLuint program, GLenum pname, GLint *params);
GLAPI void   ss_glGetProgramInfoLog(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
GLAPI void   ss_glDeleteProgram(GLuint program);
GLAPI void   ss_glUseProgram(GLuint program);
GLAPI GLint  ss_glGetUniformLocation(GLuint program, const GLchar *name);
GLAPI void   ss_glUniformMatrix4fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
GLAPI void   ss_glUniform3f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
GLAPI void   ss_glUniform1f(GLint location, GLfloat v0);
GLAPI void   ss_glUniform1i(GLint location, GLint v0);
GLAPI void   ss_glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices);
GLAPI void   ss_glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instancecount);
GLAPI void   ss_glDrawArrays(GLenum mode, GLint first, GLsizei count);

#ifdef __cplusplus
}
#endif

#endif /* __glad_h_ */
