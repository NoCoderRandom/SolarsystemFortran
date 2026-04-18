#version 330 core
// ring.vert — Saturn rings (flat annulus in local XZ plane).

layout(location = 0) in vec3 a_pos;   // local ring-plane position
layout(location = 1) in vec2 a_uv;    // u = radial coord (0 inner .. 1 outer)

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_proj;

out vec3 v_world_pos;
out vec2 v_uv;

void main() {
    vec4 w = u_model * vec4(a_pos, 1.0);
    v_world_pos = w.xyz;
    v_uv = a_uv;
    gl_Position = u_proj * u_view * w;
}
