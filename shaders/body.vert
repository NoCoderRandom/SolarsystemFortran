#version 330 core
// body.vert — instanced vertex shader for solar system bodies
//
// Per-vertex attribute (non-instanced):
//   layout(0) in vec3 a_pos    — unit sphere position
//   layout(1) in vec2 a_uv     — UV coords (unused this phase)
//
// Per-instance attributes:
//   layout(2..5) in mat4 a_model  — model matrix (4 columns)
//   layout(6)      in vec3 a_color — instance color (RGB)
//
// Uniforms:
//   uniform mat4 u_view  — view matrix
//   uniform mat4 u_proj   — projection matrix

layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec2 a_uv;

layout(location = 2) in vec4 a_model_col0;
layout(location = 3) in vec4 a_model_col1;
layout(location = 4) in vec4 a_model_col2;
layout(location = 5) in vec4 a_model_col3;
layout(location = 6) in vec3 a_color;

uniform mat4 u_view;
uniform mat4 u_proj;

out vec3 v_color;

void main() {
    mat4 model = mat4(a_model_col0, a_model_col1, a_model_col2, a_model_col3);
    vec4 world_pos = model * vec4(a_pos, 1.0);
    gl_Position = u_proj * u_view * world_pos;
    v_color = a_color;
}
