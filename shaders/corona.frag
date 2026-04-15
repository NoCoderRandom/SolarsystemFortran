#version 410 core
// corona.frag — radial HDR halo. Sharp bright core with a long soft
// exponential falloff. Additively blended by the host.
in vec2 v_local;
out vec4 o_color;

uniform float u_emissive_mul;

void main() {
    float r = length(v_local);
    if (r > 1.0) discard;
    float core = exp(-r * 3.5);
    float halo = exp(-r * 1.3) * 0.35;
    float i = core + halo;
    vec3 col = vec3(2.4, 2.0, 1.4) * i * u_emissive_mul;
    o_color = vec4(col, i);
}
