/*
 * GLAD loader — OpenGL 4.1 Core (upgraded in Phase 6 for HDR pipeline).
 */
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <glad/glad.h>

#define DECL(name) PFN##name##PROC glad_##name = NULL

PFNGLGENBUFFERSPROC              glad_glGenBuffers              = NULL;
PFNGLBINDBUFFERPROC              glad_glBindBuffer              = NULL;
PFNGLBUFFERDATAPROC              glad_glBufferData              = NULL;
PFNGLBUFFERSUBDATAPROC           glad_glBufferSubData           = NULL;
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
PFNGLUNIFORM2FPROC               glad_glUniform2f               = NULL;
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
PFNGLGENTEXTURESPROC             glad_glGenTextures             = NULL;
PFNGLBINDTEXTUREPROC             glad_glBindTexture             = NULL;
PFNGLDELETETEXTURESPROC          glad_glDeleteTextures          = NULL;
PFNGLTEXIMAGE2DPROC              glad_glTexImage2D              = NULL;
PFNGLTEXPARAMETERIPROC           glad_glTexParameteri           = NULL;
PFNGLACTIVETEXTUREPROC           glad_glActiveTexture           = NULL;
PFNGLGENFRAMEBUFFERSPROC         glad_glGenFramebuffers         = NULL;
PFNGLBINDFRAMEBUFFERPROC         glad_glBindFramebuffer         = NULL;
PFNGLDELETEFRAMEBUFFERSPROC      glad_glDeleteFramebuffers      = NULL;
PFNGLFRAMEBUFFERTEXTURE2DPROC    glad_glFramebufferTexture2D    = NULL;
PFNGLCHECKFRAMEBUFFERSTATUSPROC  glad_glCheckFramebufferStatus  = NULL;
PFNGLGENRENDERBUFFERSPROC        glad_glGenRenderbuffers        = NULL;
PFNGLBINDRENDERBUFFERPROC        glad_glBindRenderbuffer        = NULL;
PFNGLDELETERENDERBUFFERSPROC     glad_glDeleteRenderbuffers     = NULL;
PFNGLRENDERBUFFERSTORAGEPROC     glad_glRenderbufferStorage     = NULL;
PFNGLFRAMEBUFFERRENDERBUFFERPROC glad_glFramebufferRenderbuffer = NULL;
PFNGLREADPIXELSPROC              glad_glReadPixels              = NULL;
PFNGLGENERATEMIPMAPPROC          glad_glGenerateMipmap          = NULL;
PFNGLGETFLOATVPROC               glad_glGetFloatv               = NULL;

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
    L(glUniform2f, PFNGLUNIFORM2FPROC);
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
    L(glGenTextures, PFNGLGENTEXTURESPROC);
    L(glBindTexture, PFNGLBINDTEXTUREPROC);
    L(glDeleteTextures, PFNGLDELETETEXTURESPROC);
    L(glTexImage2D, PFNGLTEXIMAGE2DPROC);
    L(glTexParameteri, PFNGLTEXPARAMETERIPROC);
    L(glActiveTexture, PFNGLACTIVETEXTUREPROC);
    L(glGenFramebuffers, PFNGLGENFRAMEBUFFERSPROC);
    L(glBindFramebuffer, PFNGLBINDFRAMEBUFFERPROC);
    L(glDeleteFramebuffers, PFNGLDELETEFRAMEBUFFERSPROC);
    L(glFramebufferTexture2D, PFNGLFRAMEBUFFERTEXTURE2DPROC);
    L(glCheckFramebufferStatus, PFNGLCHECKFRAMEBUFFERSTATUSPROC);
    L(glGenRenderbuffers, PFNGLGENRENDERBUFFERSPROC);
    L(glBindRenderbuffer, PFNGLBINDRENDERBUFFERPROC);
    L(glDeleteRenderbuffers, PFNGLDELETERENDERBUFFERSPROC);
    L(glRenderbufferStorage, PFNGLRENDERBUFFERSTORAGEPROC);
    L(glFramebufferRenderbuffer, PFNGLFRAMEBUFFERRENDERBUFFERPROC);
    L(glReadPixels, PFNGLREADPIXELSPROC);
    L(glGenerateMipmap, PFNGLGENERATEMIPMAPPROC);
    L(glGetFloatv, PFNGLGETFLOATVPROC);
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
void ss_glUniform2f(GLint location, GLfloat v0, GLfloat v1) { glad_glUniform2f(location, v0, v1); }
void ss_glUniform1f(GLint location, GLfloat v0) { glad_glUniform1f(location, v0); }
void ss_glUniform1i(GLint location, GLint v0) { glad_glUniform1i(location, v0); }
void ss_glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices) { glad_glDrawElements(mode, count, type, indices); }
void ss_glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instancecount) { glad_glDrawElementsInstanced(mode, count, type, indices, instancecount); }
void ss_glDrawArrays(GLenum mode, GLint first, GLsizei count) { glad_glDrawArrays(mode, first, count); }
void ss_glGenTextures(GLsizei n, GLuint *out) { glad_glGenTextures(n, out); }
void ss_glBindTexture(GLenum target, GLuint tex) { glad_glBindTexture(target, tex); }
void ss_glDeleteTextures(GLsizei n, const GLuint *tex) { glad_glDeleteTextures(n, tex); }
void ss_glTexImage2D(GLenum target, GLint level, GLint internalFormat, GLsizei w, GLsizei h, GLint border, GLenum format, GLenum type, const void *pixels) { glad_glTexImage2D(target, level, internalFormat, w, h, border, format, type, pixels); }
void ss_glTexParameteri(GLenum target, GLenum pname, GLint param) { glad_glTexParameteri(target, pname, param); }
void ss_glActiveTexture(GLenum unit) { glad_glActiveTexture(unit); }
void ss_glGenerateMipmap(GLenum target) { glad_glGenerateMipmap(target); }
void ss_glGetFloatv(GLenum pname, GLfloat *v) { glad_glGetFloatv(pname, v); }
void ss_glGenFramebuffers(GLsizei n, GLuint *out) { glad_glGenFramebuffers(n, out); }
void ss_glBindFramebuffer(GLenum target, GLuint fb) { glad_glBindFramebuffer(target, fb); }
void ss_glDeleteFramebuffers(GLsizei n, const GLuint *fb) { glad_glDeleteFramebuffers(n, fb); }
void ss_glFramebufferTexture2D(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level) { glad_glFramebufferTexture2D(target, attachment, textarget, texture, level); }
GLenum ss_glCheckFramebufferStatus(GLenum target) { return glad_glCheckFramebufferStatus(target); }
void ss_glGenRenderbuffers(GLsizei n, GLuint *out) { glad_glGenRenderbuffers(n, out); }
void ss_glBindRenderbuffer(GLenum target, GLuint rb) { glad_glBindRenderbuffer(target, rb); }
void ss_glDeleteRenderbuffers(GLsizei n, const GLuint *rb) { glad_glDeleteRenderbuffers(n, rb); }
void ss_glRenderbufferStorage(GLenum target, GLenum internalFormat, GLsizei w, GLsizei h) { glad_glRenderbufferStorage(target, internalFormat, w, h); }
void ss_glFramebufferRenderbuffer(GLenum target, GLenum attachment, GLenum rbtarget, GLuint rb) { glad_glFramebufferRenderbuffer(target, attachment, rbtarget, rb); }
void ss_glReadPixels(GLint x, GLint y, GLsizei w, GLsizei h, GLenum format, GLenum type, void *pixels) { glad_glReadPixels(x, y, w, h, format, type, pixels); }

/* Copy GL_VERSION / GL_RENDERER into a caller-provided buffer.
   `name` is the GL enum (e.g. 0x1F02 for GL_RENDERER). Returns the number
   of bytes written (excluding null). Safe if the pointer is NULL. */
/* glGetString isn't in the generated glad subset. Resolve it via GLFW's
   proc-address loader (already used by gladLoadGLLoader at init). */
typedef const GLubyte *(*ss_getstring_pfn)(GLenum);
int ss_glGetStringCopy(GLenum name, char *out, int max_len) {
    static ss_getstring_pfn pfn = 0;
    if (!pfn) pfn = (ss_getstring_pfn)glfwGetProcAddress("glGetString");
    if (!pfn || max_len <= 0) {
        if (out && max_len > 0) out[0] = '\0';
        return 0;
    }
    const GLubyte *s = pfn(name);
    if (!s || max_len <= 0) {
        if (out && max_len > 0) out[0] = '\0';
        return 0;
    }
    int i = 0;
    while (s[i] && i < max_len - 1) { out[i] = (char)s[i]; i++; }
    out[i] = '\0';
    return i;
}

/* ---- Minimal uncompressed PNG writer (no external zlib) ---- */
static uint32_t ss_crc_table[256];
static int      ss_crc_init = 0;
static void ss_make_crc_table(void) {
    for (int n = 0; n < 256; n++) {
        uint32_t c = (uint32_t)n;
        for (int k = 0; k < 8; k++) c = (c >> 1) ^ (c & 1 ? 0xedb88320u : 0u);
        ss_crc_table[n] = c;
    }
    ss_crc_init = 1;
}
static uint32_t ss_crc32(const unsigned char *buf, size_t len) {
    if (!ss_crc_init) ss_make_crc_table();
    uint32_t c = 0xffffffffu;
    for (size_t i = 0; i < len; i++) c = ss_crc_table[(c ^ buf[i]) & 0xff] ^ (c >> 8);
    return c ^ 0xffffffffu;
}
static uint32_t ss_adler32(const unsigned char *data, size_t len) {
    uint32_t a = 1, b = 0;
    for (size_t i = 0; i < len; i++) { a = (a + data[i]) % 65521u; b = (b + a) % 65521u; }
    return (b << 16) | a;
}
static void ss_put_be32(unsigned char *out, uint32_t v) {
    out[0] = (unsigned char)(v >> 24);
    out[1] = (unsigned char)(v >> 16);
    out[2] = (unsigned char)(v >> 8);
    out[3] = (unsigned char)v;
}
static int ss_write_chunk(FILE *f, const char *type, const unsigned char *data, uint32_t len) {
    unsigned char hdr[8];
    ss_put_be32(hdr, len);
    hdr[4] = (unsigned char)type[0]; hdr[5] = (unsigned char)type[1];
    hdr[6] = (unsigned char)type[2]; hdr[7] = (unsigned char)type[3];
    fwrite(hdr, 1, 8, f);
    if (len) fwrite(data, 1, len, f);
    unsigned char *crcbuf = (unsigned char*)malloc(len + 4);
    memcpy(crcbuf, hdr + 4, 4);
    if (len) memcpy(crcbuf + 4, data, len);
    uint32_t c = ss_crc32(crcbuf, len + 4);
    free(crcbuf);
    unsigned char crc[4];
    ss_put_be32(crc, c);
    fwrite(crc, 1, 4, f);
    return 1;
}

int ss_write_png(const char *path, int w, int h, const unsigned char *rgb) {
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    static const unsigned char sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
    fwrite(sig, 1, 8, f);

    unsigned char ihdr[13];
    ss_put_be32(ihdr,     (uint32_t)w);
    ss_put_be32(ihdr + 4, (uint32_t)h);
    ihdr[8]  = 8;   /* bit depth */
    ihdr[9]  = 2;   /* color type RGB */
    ihdr[10] = 0;   /* compression */
    ihdr[11] = 0;   /* filter */
    ihdr[12] = 0;   /* interlace */
    ss_write_chunk(f, "IHDR", ihdr, 13);

    size_t row_len = (size_t)(3 * w + 1);
    size_t raw_len = row_len * (size_t)h;
    unsigned char *raw = (unsigned char*)malloc(raw_len);
    /* OpenGL glReadPixels returns rows bottom-up; PNG wants them top-down. */
    for (int y = 0; y < h; y++) {
        raw[y * row_len] = 0;
        memcpy(raw + y * row_len + 1,
               rgb + (size_t)(h - 1 - y) * 3 * w,
               (size_t)(3 * w));
    }

    size_t max_blocks = (raw_len + 65534) / 65535;
    if (max_blocks == 0) max_blocks = 1;
    size_t idat_cap = 2 + raw_len + max_blocks * 5 + 4;
    unsigned char *idat = (unsigned char*)malloc(idat_cap);
    size_t p = 0;
    idat[p++] = 0x78;
    idat[p++] = 0x01;
    size_t off = 0;
    while (off < raw_len || raw_len == 0) {
        size_t n = raw_len - off;
        if (n > 65535) n = 65535;
        int final = (off + n == raw_len) ? 1 : 0;
        idat[p++] = (unsigned char)final;
        idat[p++] = (unsigned char)(n & 0xff);
        idat[p++] = (unsigned char)((n >> 8) & 0xff);
        uint16_t nc = (uint16_t)(~n);
        idat[p++] = (unsigned char)(nc & 0xff);
        idat[p++] = (unsigned char)((nc >> 8) & 0xff);
        if (n) memcpy(idat + p, raw + off, n);
        p += n;
        off += n;
        if (final) break;
    }
    uint32_t ad = ss_adler32(raw, raw_len);
    ss_put_be32(idat + p, ad);
    p += 4;
    free(raw);
    ss_write_chunk(f, "IDAT", idat, (uint32_t)p);
    free(idat);

    ss_write_chunk(f, "IEND", NULL, 0);
    fclose(f);
    return 1;
}
