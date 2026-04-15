#version 410 core
// bloom_combine.frag — sample a blurred mip and scale by u_weight.
// The host additively blends multiple invocations into the combine target.
in vec2 v_uv;
out vec4 o_color;

uniform sampler2D u_src;
uniform float u_weight;

void main() {
    vec3 c = texture(u_src, v_uv).rgb;
    o_color = vec4(c * u_weight, 1.0);
}
