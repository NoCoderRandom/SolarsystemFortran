/* Single-translation-unit stb_image implementation + Fortran wrappers.
 * Exposes ss_load_image / ss_free_image / ss_image_info so Fortran
 * never has to know stb's header or pointer semantics.
 */
#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#include "stb_image.h"

#include <stdlib.h>
#include <string.h>

/* Load an image as 8-bit RGBA. Caller passes pointers to receive
 * width, height, channels (always 4 on success), and the pixel buffer
 * pointer. Returns 1 on success, 0 on failure. Caller must call
 * ss_free_image to release the buffer.
 *
 * We force 4 channels so Fortran does not have to branch on layout;
 * the GL upload always uses GL_RGBA, GL_UNSIGNED_BYTE.
 */
int ss_load_image(const char *path,
                  int *out_w, int *out_h, int *out_channels,
                  unsigned char **out_pixels,
                  int flip_vertically) {
    stbi_set_flip_vertically_on_load(flip_vertically ? 1 : 0);
    int w, h, ch;
    unsigned char *data = stbi_load(path, &w, &h, &ch, 4);
    if (!data) {
        *out_w = 0; *out_h = 0; *out_channels = 0; *out_pixels = NULL;
        return 0;
    }
    *out_w = w;
    *out_h = h;
    *out_channels = 4;
    *out_pixels = data;
    return 1;
}

void ss_free_image(unsigned char *pixels) {
    if (pixels) stbi_image_free(pixels);
}
