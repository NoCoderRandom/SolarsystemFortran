#version 330 core

layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec2 a_uv;
layout(location = 7) in vec3 a_normal;
layout(location = 8) in vec3 a_tangent;
layout(location = 9) in vec3 a_bitangent;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_proj;

out vec3 v_world_pos;
out vec2 v_uv;
out vec3 v_normal;
out vec3 v_tangent;
out vec3 v_bitangent;

void main() {
    vec4 world = u_model * vec4(a_pos, 1.0);
    mat3 m3 = mat3(u_model);

    v_world_pos = world.xyz;
    v_uv = a_uv;
    v_normal = normalize(m3 * a_normal);
    v_tangent = normalize(m3 * a_tangent);
    v_bitangent = normalize(m3 * a_bitangent);

    gl_Position = u_proj * u_view * world;
}
