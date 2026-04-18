#version 330 core
// ring.frag — sample radial alpha texture + soft shadow from Saturn.

in vec3 v_world_pos;
in vec2 v_uv;
out vec4 frag_color;

uniform sampler2D u_alpha;
uniform vec3  u_light_pos;     // Sun (world-space)
uniform vec3  u_planet_pos;    // Saturn center (world-space)
uniform float u_planet_radius; // world-space radius (AU-scaled)
uniform vec3  u_tint;

void main() {
    // Sample radial strip: Solar System Scope ring texture is arranged with
    // radial variation along U. V gets a constant mid-row.
    vec4 samp = texture(u_alpha, vec2(v_uv.x, 0.5));
    // The SSS file stores density in RGB (often grayscale) with alpha in A.
    // Use alpha if non-zero, else luminance.
    float a = samp.a;
    if (a < 0.001) a = max(max(samp.r, samp.g), samp.b);
    vec3  col = samp.rgb;
    if (dot(col, vec3(1.0)) < 0.01) col = vec3(a);
    col *= u_tint;

    // Saturn shadow: ray from fragment towards Sun — does it hit Saturn?
    vec3 L = normalize(u_light_pos - v_world_pos);
    vec3 oc = v_world_pos - u_planet_pos;
    float b = dot(oc, L);
    float c = dot(oc, oc) - u_planet_radius * u_planet_radius;
    float disc = b * b - c;
    // Shadow when ray toward Sun intersects sphere in the +L direction.
    float shadow = 1.0;
    if (disc > 0.0 && -b + sqrt(disc) > 0.0) {
        // Soft falloff near the limb
        float edge = clamp(disc / (u_planet_radius * u_planet_radius), 0.0, 1.0);
        shadow = 1.0 - 0.85 * smoothstep(0.0, 0.3, edge);
    }

    frag_color = vec4(col * shadow, a);
}
