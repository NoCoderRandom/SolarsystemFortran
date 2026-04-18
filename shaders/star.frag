#version 410 core

in vec3  v_color;
in float v_brightness;

out vec4 f_color;

void main() {
    // Soft circular sprite: 0 at edge, 1 at center.
    vec2 uv = gl_PointCoord * 2.0 - 1.0;
    float r2 = dot(uv, uv);
    if (r2 > 1.0) discard;
    float falloff = exp(-r2 * 3.0);

    // HDR output: bright stars exceed 1.0 so bloom picks them up.
    // Scale by v_brightness (0..~2.5 after twinkle/intensity) and a headroom factor.
    vec3 rgb = v_color * v_brightness * falloff * 1.4;
    f_color = vec4(rgb, falloff);
}
