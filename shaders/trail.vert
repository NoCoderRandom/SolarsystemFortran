#version 330 core
// trail.vert — orbit trail vertex shader
//
// Each body owns a ring buffer of N positions. trails_render walks that
// ring in oldest-to-newest order (one or two draws per body) and passes
// u_seq_offset so gl_VertexID + u_seq_offset gives the vertex's index in
// the full oldest→newest sequence.

layout(location = 0) in vec3 a_pos;

uniform mat4  u_view;
uniform mat4  u_proj;
uniform int   u_count;        // total vertices being drawn for this body
uniform int   u_max_slots;    // ring capacity (fade denominator)
uniform int   u_seq_offset;   // offset into the oldest→newest sequence
uniform vec3  u_color;
uniform float u_gamma;

out vec3  v_color;
out float v_fade;

void main() {
    int seq   = gl_VertexID + u_seq_offset;       // 0 = oldest
    int age   = (u_count - 1) - seq;              // 0 at newest
    float den = float(max(u_max_slots - 1, 1));
    float t   = 1.0 - float(age) / den;
    t = clamp(t, 0.0, 1.0);
    v_fade  = pow(t, u_gamma);
    v_color = u_color;
    gl_Position = u_proj * u_view * vec4(a_pos, 1.0);
}
