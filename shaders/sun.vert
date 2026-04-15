#version 410 core
// sun.vert — simple model/view/proj pass-through with object-space position
// forwarded for the fragment shader's procedural noise.
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec2 a_uv;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_proj;

out vec3 v_obj_pos;
out vec3 v_world_pos;
out vec3 v_normal;

void main() {
    v_obj_pos   = a_pos;
    vec4 wp     = u_model * vec4(a_pos, 1.0);
    v_world_pos = wp.xyz;
    v_normal    = normalize(mat3(u_model) * a_pos);
    gl_Position = u_proj * u_view * wp;
}
