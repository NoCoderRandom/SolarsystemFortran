#version 410 core
// corona.vert — billboard quad centered at u_center in world space.
// Expands along camera right/up so the quad always faces the viewer.
// Attribute 0 carries local XY in [-1, 1].
layout(location = 0) in vec2 a_local;

uniform mat4  u_view;
uniform mat4  u_proj;
uniform vec3  u_center;
uniform float u_radius;

out vec2 v_local;

void main() {
    vec3 right = vec3(u_view[0][0], u_view[1][0], u_view[2][0]);
    vec3 up    = vec3(u_view[0][1], u_view[1][1], u_view[2][1]);
    vec3 wp    = u_center + (right * a_local.x + up * a_local.y) * u_radius;
    gl_Position = u_proj * u_view * vec4(wp, 1.0);
    v_local = a_local;
}
