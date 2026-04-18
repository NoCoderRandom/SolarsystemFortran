/*
 * GLAD header — OpenGL 4.1 Core (upgraded from 3.3 in Phase 6 for
 * HDR framebuffers, RGBA16F textures, and explicit sRGB/ACES pipeline
 * support required by the post-processing passes).
 */

#ifndef __glad_h_
#define __glad_h_

#include <KHR/khrplatform.h>

#ifdef __cplusplus
extern "C" {
#endif

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

/* ---- Constants (subset we use) ---- */
#define GL_COLOR_BUFFER_BIT       0x00004000
#define GL_DEPTH_BUFFER_BIT       0x00000100
#define GL_ARRAY_BUFFER           0x8892
#define GL_ELEMENT_ARRAY_BUFFER   0x8893
#define GL_STATIC_DRAW            0x88E4
#define GL_DYNAMIC_DRAW           0x88E8
#define GL_STREAM_DRAW            0x88E0
#define GL_FLOAT                  0x1406
#define GL_UNSIGNED_BYTE          0x1401
#define GL_UNSIGNED_INT           0x1405
#define GL_FALSE                  0
#define GL_TRUE                   1
#define GL_TRIANGLES              0x0004
#define GL_VERTEX_SHADER          0x8B31
#define GL_FRAGMENT_SHADER        0x8B30
#define GL_COMPILE_STATUS         0x8B81
#define GL_LINK_STATUS            0x8B82
#define GL_INFO_LOG_LENGTH        0x8B84
#define GL_DEPTH_TEST             0x0B71
#define GL_CULL_FACE              0x0B44
#define GL_BACK                   0x0405
#define GL_CCW                    0x0900
#define GL_FRONT_FACE             0x0B46
#define GL_NO_ERROR               0x0500

/* Framebuffers / renderbuffers / textures */
#define GL_FRAMEBUFFER            0x8D40
#define GL_DRAW_FRAMEBUFFER       0x8CA9
#define GL_READ_FRAMEBUFFER       0x8CA8
#define GL_RENDERBUFFER           0x8D41
#define GL_COLOR_ATTACHMENT0      0x8CE0
#define GL_DEPTH_ATTACHMENT       0x8D00
#define GL_DEPTH_COMPONENT24      0x81A6
#define GL_FRAMEBUFFER_COMPLETE   0x8CD5
#define GL_TEXTURE_2D             0x0DE1
#define GL_TEXTURE_MIN_FILTER     0x2801
#define GL_TEXTURE_MAG_FILTER     0x2800
#define GL_TEXTURE_WRAP_S         0x2802
#define GL_TEXTURE_WRAP_T         0x2803
#define GL_LINEAR                 0x2601
#define GL_NEAREST                0x2600
#define GL_CLAMP_TO_EDGE          0x812F
#define GL_REPEAT                 0x2901
#define GL_TEXTURE0               0x84C0
#define GL_TEXTURE1               0x84C1
#define GL_TEXTURE2               0x84C2
#define GL_RGBA                   0x1908
#define GL_RGB                    0x1907
#define GL_RGBA16F                0x881A
#define GL_RGBA32F                0x8814
#define GL_RGB16F                 0x881B
#define GL_RGB8                   0x8051
#define GL_RGBA8                  0x8058

/* Blending / rendering */
#define GL_BLEND                  0x0BE2
#define GL_SRC_ALPHA              0x0302
#define GL_ONE                    0x0001
#define GL_ONE_MINUS_SRC_ALPHA    0x0303
#define GL_ZERO                   0x0000
#define GL_LINE_STRIP             0x0003

/* ---- Function pointer typedefs (shared 3.3 + 4.1 subset) ---- */
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
typedef void (APIENTRYP PFNGLUNIFORM2FPROC)(GLint location, GLfloat v0, GLfloat v1);
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
typedef void (APIENTRYP PFNGLLINEWIDTHPROC)(GLfloat width);
typedef void (APIENTRYP PFNGLDEPTHMASKPROC)(GLboolean flag);
typedef void (APIENTRYP PFNGLBLENDFUNCPROC)(GLenum sfactor, GLenum dfactor);

/* Textures / FBOs (4.1 core subset) */
typedef void (APIENTRYP PFNGLGENTEXTURESPROC)(GLsizei n, GLuint *textures);
typedef void (APIENTRYP PFNGLBINDTEXTUREPROC)(GLenum target, GLuint texture);
typedef void (APIENTRYP PFNGLDELETETEXTURESPROC)(GLsizei n, const GLuint *textures);
typedef void (APIENTRYP PFNGLTEXIMAGE2DPROC)(GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels);
typedef void (APIENTRYP PFNGLTEXPARAMETERIPROC)(GLenum target, GLenum pname, GLint param);
typedef void (APIENTRYP PFNGLACTIVETEXTUREPROC)(GLenum texture);
typedef void (APIENTRYP PFNGLGENFRAMEBUFFERSPROC)(GLsizei n, GLuint *framebuffers);
typedef void (APIENTRYP PFNGLBINDFRAMEBUFFERPROC)(GLenum target, GLuint framebuffer);
typedef void (APIENTRYP PFNGLDELETEFRAMEBUFFERSPROC)(GLsizei n, const GLuint *framebuffers);
typedef void (APIENTRYP PFNGLFRAMEBUFFERTEXTURE2DPROC)(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
typedef GLenum (APIENTRYP PFNGLCHECKFRAMEBUFFERSTATUSPROC)(GLenum target);
typedef void (APIENTRYP PFNGLGENRENDERBUFFERSPROC)(GLsizei n, GLuint *renderbuffers);
typedef void (APIENTRYP PFNGLBINDRENDERBUFFERPROC)(GLenum target, GLuint renderbuffer);
typedef void (APIENTRYP PFNGLDELETERENDERBUFFERSPROC)(GLsizei n, const GLuint *renderbuffers);
typedef void (APIENTRYP PFNGLRENDERBUFFERSTORAGEPROC)(GLenum target, GLenum internalFormat, GLsizei width, GLsizei height);
typedef void (APIENTRYP PFNGLFRAMEBUFFERRENDERBUFFERPROC)(GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer);
typedef void (APIENTRYP PFNGLREADPIXELSPROC)(GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void *pixels);
typedef void (APIENTRYP PFNGLGENERATEMIPMAPPROC)(GLenum target);
typedef void (APIENTRYP PFNGLGETFLOATVPROC)(GLenum pname, GLfloat *data);

/* ---- Function pointer variables ---- */
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
GLAPI PFNGLUNIFORM2FPROC glad_glUniform2f;
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
GLAPI PFNGLLINEWIDTHPROC glad_glLineWidth;
GLAPI PFNGLDEPTHMASKPROC glad_glDepthMask;
GLAPI PFNGLBLENDFUNCPROC glad_glBlendFunc;
GLAPI PFNGLGENTEXTURESPROC glad_glGenTextures;
GLAPI PFNGLBINDTEXTUREPROC glad_glBindTexture;
GLAPI PFNGLDELETETEXTURESPROC glad_glDeleteTextures;
GLAPI PFNGLTEXIMAGE2DPROC glad_glTexImage2D;
GLAPI PFNGLTEXPARAMETERIPROC glad_glTexParameteri;
GLAPI PFNGLACTIVETEXTUREPROC glad_glActiveTexture;
GLAPI PFNGLGENFRAMEBUFFERSPROC glad_glGenFramebuffers;
GLAPI PFNGLBINDFRAMEBUFFERPROC glad_glBindFramebuffer;
GLAPI PFNGLDELETEFRAMEBUFFERSPROC glad_glDeleteFramebuffers;
GLAPI PFNGLFRAMEBUFFERTEXTURE2DPROC glad_glFramebufferTexture2D;
GLAPI PFNGLCHECKFRAMEBUFFERSTATUSPROC glad_glCheckFramebufferStatus;
GLAPI PFNGLGENRENDERBUFFERSPROC glad_glGenRenderbuffers;
GLAPI PFNGLBINDRENDERBUFFERPROC glad_glBindRenderbuffer;
GLAPI PFNGLDELETERENDERBUFFERSPROC glad_glDeleteRenderbuffers;
GLAPI PFNGLRENDERBUFFERSTORAGEPROC glad_glRenderbufferStorage;
GLAPI PFNGLFRAMEBUFFERRENDERBUFFERPROC glad_glFramebufferRenderbuffer;
GLAPI PFNGLREADPIXELSPROC glad_glReadPixels;
GLAPI PFNGLGENERATEMIPMAPPROC glad_glGenerateMipmap;
GLAPI PFNGLGETFLOATVPROC glad_glGetFloatv;

/* ---- GLAD loader ---- */
typedef void* (*GLADloadproc)(const char *name);
GLAPI int gladLoadGL(void);
GLAPI int gladLoadGLLoader(GLADloadproc loader);

/* ---- Fortran-callable wrappers (ss_* = Solar System) ---- */
GLAPI void   ss_glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
GLAPI void   ss_glClear(GLbitfield mask);
GLAPI void   ss_glViewport(GLint x, GLint y, GLsizei w, GLsizei h);
GLAPI GLenum ss_glGetError(void);
GLAPI void   ss_glEnable(GLenum cap);
GLAPI void   ss_glDisable(GLenum cap);
GLAPI void   ss_glLineWidth(GLfloat width);
GLAPI void   ss_glDepthMask(GLboolean flag);
GLAPI void   ss_glBlendFunc(GLenum sfactor, GLenum dfactor);
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
GLAPI void   ss_glUniform2f(GLint location, GLfloat v0, GLfloat v1);
GLAPI void   ss_glUniform1f(GLint location, GLfloat v0);
GLAPI void   ss_glUniform1i(GLint location, GLint v0);
GLAPI void   ss_glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices);
GLAPI void   ss_glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instancecount);
GLAPI void   ss_glDrawArrays(GLenum mode, GLint first, GLsizei count);
GLAPI void   ss_glGenTextures(GLsizei n, GLuint *out);
GLAPI void   ss_glBindTexture(GLenum target, GLuint tex);
GLAPI void   ss_glDeleteTextures(GLsizei n, const GLuint *tex);
GLAPI void   ss_glTexImage2D(GLenum target, GLint level, GLint internalFormat, GLsizei w, GLsizei h, GLint border, GLenum format, GLenum type, const void *pixels);
GLAPI void   ss_glTexParameteri(GLenum target, GLenum pname, GLint param);
GLAPI void   ss_glActiveTexture(GLenum unit);
GLAPI void   ss_glGenFramebuffers(GLsizei n, GLuint *out);
GLAPI void   ss_glBindFramebuffer(GLenum target, GLuint fb);
GLAPI void   ss_glDeleteFramebuffers(GLsizei n, const GLuint *fb);
GLAPI void   ss_glFramebufferTexture2D(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
GLAPI GLenum ss_glCheckFramebufferStatus(GLenum target);
GLAPI void   ss_glGenRenderbuffers(GLsizei n, GLuint *out);
GLAPI void   ss_glBindRenderbuffer(GLenum target, GLuint rb);
GLAPI void   ss_glDeleteRenderbuffers(GLsizei n, const GLuint *rb);
GLAPI void   ss_glRenderbufferStorage(GLenum target, GLenum internalFormat, GLsizei w, GLsizei h);
GLAPI void   ss_glFramebufferRenderbuffer(GLenum target, GLenum attachment, GLenum rbtarget, GLuint rb);
GLAPI void   ss_glReadPixels(GLint x, GLint y, GLsizei w, GLsizei h, GLenum format, GLenum type, void *pixels);
GLAPI void   ss_glGenerateMipmap(GLenum target);
GLAPI void   ss_glGetFloatv(GLenum pname, GLfloat *v);

/* Screenshot helper: write RGB8 pixel data as an uncompressed PNG. */
GLAPI int    ss_write_png(const char *path, int w, int h, const unsigned char *rgb);

#ifdef __cplusplus
}
#endif

#endif /* __glad_h_ */
