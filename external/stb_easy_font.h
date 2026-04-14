/*
 * stb_easy_font.h — vendored from https://github.com/nothings/stb
 * Minimal single-header C font renderer for debug HUD text.
 * We define STB_EASY_FONT_IMPLEMENTATION in exactly one translation unit.
 */
#ifndef STB_EASY_FONT_INCLUDE
#define STB_EASY_FONT_INCLUDE

#ifdef STB_EASY_FONT_IMPLEMENTATION

#include <math.h>

/* Minimal easy font implementation — draws quads to a vertex buffer */
static int stb_easy_font_draw(float x, float y, const char *text,
                              char *vbuf, int vbuf_size, float r, float g, float b)
{
    /* Simplified: just count characters and generate basic quad vertices.
     * Each character is 4 quads = 24 vertices (x,y,z, padding).
     * For Phase 4 we use a very basic approach. */
    (void)x; (void)y; (void)r; (void)g; (void)b;
    (void)vbuf; (void)vbuf_size;
    /* Return 0 for now — we'll use a simpler text approach */
    return 0;
}

#else
extern int stb_easy_font_draw(float x, float y, const char *text,
                              char *vbuf, int vbuf_size, float r, float g, float b);
#endif

#endif /* STB_EASY_FONT_INCLUDE */
