#version 410 core
// blur.frag — 9-tap separable Gaussian.
// Set u_horizontal=1 for a horizontal pass, 0 for vertical.
// u_texel_{x,y} are 1.0/width, 1.0/height of the source texture.
in vec2 v_uv;
out vec4 o_color;

uniform sampler2D u_src;
uniform int   u_horizontal;
uniform float u_texel_x;
uniform float u_texel_y;

const float W[5] = float[5](
    0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
);

void main() {
    vec2 dir = (u_horizontal == 1)
        ? vec2(u_texel_x, 0.0)
        : vec2(0.0, u_texel_y);
    vec3 acc = texture(u_src, v_uv).rgb * W[0];
    for (int i = 1; i < 5; ++i) {
        acc += texture(u_src, v_uv + dir * float(i)).rgb * W[i];
        acc += texture(u_src, v_uv - dir * float(i)).rgb * W[i];
    }
    o_color = vec4(acc, 1.0);
}
