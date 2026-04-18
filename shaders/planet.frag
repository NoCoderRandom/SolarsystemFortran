#version 330 core
// planet.frag — Lambert + Blinn-Phong + normal map + soft terminator
//               + optional Earth clouds / night lights / ocean specular / rim.

in vec3 v_world_pos;
in vec3 v_normal;
in vec3 v_tangent;
in vec3 v_bitangent;
in vec2 v_uv;
in vec3 v_tint;

out vec4 frag_color;

uniform sampler2D u_albedo;
uniform sampler2D u_normal;
uniform sampler2D u_night;
uniform sampler2D u_specular;
uniform sampler2D u_clouds;

uniform int  u_material_kind;   // 0 generic, 1 earth, 2 gas giant
uniform int  u_has_normal_map;  // 0/1
uniform int  u_has_clouds;      // 0/1
uniform vec3 u_light_pos;       // world-space light (Sun) position in AU
uniform vec3 u_cam_pos;         // world-space camera position in AU
uniform vec3 u_light_color;
uniform float u_ambient;
uniform float u_shininess;
uniform float u_spec_scale;
uniform float u_rim_power;      // 0 disables
uniform vec3  u_rim_color;

const int MAT_GENERIC   = 0;
const int MAT_EARTH     = 1;
const int MAT_GAS_GIANT = 2;

void main() {
    vec3 Ng = normalize(v_normal);                         // geometric normal
    vec3 L = normalize(u_light_pos - v_world_pos);
    vec3 V = normalize(u_cam_pos - v_world_pos);

    // Terminator gating uses the GEOMETRIC normal so the normal map can't
    // leak sun-side shading (specular, rim, bright day mix) onto patches
    // that are geometrically on the night side of the sphere.
    float geom_ndl = dot(Ng, L);
    float day = smoothstep(-0.02, 0.15, geom_ndl);

    // Shading normal: geometric, optionally perturbed by the tangent-space map.
    vec3 N = Ng;
    if (u_has_normal_map == 1) {
        vec3 nm = texture(u_normal, v_uv).xyz * 2.0 - 1.0;
        mat3 TBN = mat3(normalize(v_tangent), normalize(v_bitangent), Ng);
        N = normalize(TBN * nm);
    }

    vec3 albedo = texture(u_albedo, v_uv).rgb * v_tint;

    float ndl = dot(N, L);
    float diffuse = max(ndl, 0.0);
    vec3 color = albedo * (u_ambient + diffuse) * u_light_color;

    // Specular (Blinn-Phong). Gated by the geometric terminator so normal
    // map perturbations can't fire on the night hemisphere.
    if (u_spec_scale > 0.0 && geom_ndl > 0.0) {
        vec3 H = normalize(L + V);
        float spec = pow(max(dot(N, H), 0.0), u_shininess);
        float mask = 1.0;
        if (u_material_kind == MAT_EARTH) {
            // Solar System Scope specular map: white=land, dark=ocean.
            mask = 1.0 - texture(u_specular, v_uv).r;
        }
        color += u_light_color * spec * u_spec_scale * mask * day;
    }

    // Cloud layer — white sheet on top of day side, subtle shadow on night.
    if (u_has_clouds == 1 && u_material_kind == MAT_EARTH) {
        float cloud = texture(u_clouds, v_uv).r;
        vec3 cloud_lit = vec3(cloud) * u_light_color * (u_ambient + diffuse);
        color = mix(color, cloud_lit, cloud * day * 0.85);
    }

    // Earth night lights — visible where the geometric day factor is low.
    if (u_material_kind == MAT_EARTH) {
        vec3 night_tex = texture(u_night, v_uv).rgb;
        vec3 night = night_tex * vec3(1.5, 1.3, 0.9) * 2.2;
        // Subtle continent silhouette on the dark side: faint albedo
        // ambient so land/ocean shapes read even without city lights.
        vec3 dark_side = night + albedo * 0.015;
        color = mix(dark_side, color, day);
    } else {
        color *= mix(0.0, 1.0, day * 0.98 + 0.02);
    }

    // Atmospheric rim, gated by the geometric terminator so normal-mapped
    // patches on the night side can't fire it.
    if (u_rim_power > 0.0) {
        float fres = pow(1.0 - max(dot(Ng, V), 0.0), u_rim_power);
        fres *= smoothstep(-0.05, 0.4, geom_ndl);
        color += u_rim_color * fres;
    }

    frag_color = vec4(color, 1.0);
}
