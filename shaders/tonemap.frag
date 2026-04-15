#version 410 core
// tonemap.frag — composite HDR scene + bloom, ACES tonemap, gamma 2.2.
// u_bloom_on=0 skips the bloom add so toggling is a uniform, not a rebuild.
in vec2 v_uv;
out vec4 o_color;

uniform sampler2D u_scene;
uniform sampler2D u_bloom;
uniform float u_exposure;
uniform float u_bloom_intensity;
uniform float u_bloom_on;

// Narkowicz 2015 ACES fit.
vec3 aces(vec3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 hdr = texture(u_scene, v_uv).rgb;
    vec3 bl  = texture(u_bloom, v_uv).rgb * u_bloom_on * u_bloom_intensity;
    vec3 mapped = aces((hdr + bl) * u_exposure);
    mapped = pow(mapped, vec3(1.0 / 2.2));
    o_color = vec4(mapped, 1.0);
}
