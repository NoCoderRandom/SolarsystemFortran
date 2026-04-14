#version 330 core
// trail.vert — Vertex shader for orbit trail line strips
//
// Each body stores positions in a ring buffer VBO. The shader computes
// a fade factor from the slot index relative to the head.

layout(location = 0) in vec3 a_pos;

uniform mat4 u_view;
uniform mat4 u_proj;
uniform int u_head;
uniform int u_max_slots;
uniform vec3 u_color;
uniform float u_gamma;

out vec3 v_color;
out float v_fade;

void main() {
    int slot = gl_VertexID;
    int age = (u_head - slot + u_max_slots) % u_max_slots;
    float t = 1.0 - float(age) / float(u_max_slots - 1);
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;
    v_fade = pow(t, u_gamma);
    v_color = u_color;
    gl_Position = u_proj * u_view * vec4(a_pos, 1.0);
}
