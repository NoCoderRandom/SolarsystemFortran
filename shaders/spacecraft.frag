#version 330 core

in vec3 v_world_pos;
in vec2 v_uv;
in vec3 v_normal;
in vec3 v_tangent;
in vec3 v_bitangent;

out vec4 frag_color;

uniform sampler2D u_diffuse;
uniform sampler2D u_normal;
uniform int u_has_diffuse;
uniform int u_has_normal_map;
uniform vec3 u_light_pos;
uniform vec3 u_cam_pos;
uniform vec3 u_tint;

void main() {
    vec3 N = normalize(v_normal);
    vec3 L = normalize(u_light_pos - v_world_pos);
    vec3 V = normalize(u_cam_pos - v_world_pos);

    if (u_has_normal_map == 1) {
        vec3 nm = texture(u_normal, v_uv).xyz * 2.0 - 1.0;
        mat3 TBN = mat3(normalize(v_tangent), normalize(v_bitangent), normalize(v_normal));
        N = normalize(TBN * nm);
    }

    vec3 albedo = u_tint;
    if (u_has_diffuse == 1) {
        albedo *= texture(u_diffuse, v_uv).rgb;
    }

    float diffuse = max(dot(N, L), 0.0);
    vec3 H = normalize(L + V);
    float spec = pow(max(dot(N, H), 0.0), 32.0);

    vec3 color = albedo * (0.12 + 0.88 * diffuse) + vec3(0.25) * spec;
    frag_color = vec4(color, 1.0);
}
