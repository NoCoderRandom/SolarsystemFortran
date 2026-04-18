#version 410 core

// Flat-shaded asteroid fragment: derive per-triangle normal from the
// world-space position derivatives so the low-poly lumpiness reads clearly.

in vec3  v_world;
in float v_gray;

uniform vec3 u_light_pos;     // Sun position, world units
uniform vec3 u_light_color;
uniform float u_ambient;

out vec4 f_color;

void main() {
    vec3 dx = dFdx(v_world);
    vec3 dy = dFdy(v_world);
    vec3 N  = normalize(cross(dx, dy));

    vec3 L = normalize(u_light_pos - v_world);
    float lambert = max(dot(N, L), 0.0);

    vec3 base = vec3(v_gray);
    vec3 col = base * (u_ambient + lambert) * u_light_color;

    f_color = vec4(col, 1.0);
}
