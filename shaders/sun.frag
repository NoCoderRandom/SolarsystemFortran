#version 410 core
// sun.frag — procedural boiling surface: 3-octave fbm with a slow
// domain-warp to fake convection cells. Emits HDR colour (> 1.0) so
// the bloom pass picks it up. Subtle limb darkening on the edges.
in vec3 v_obj_pos;
in vec3 v_world_pos;
in vec3 v_normal;
out vec4 o_color;

uniform float u_time;
uniform float u_emissive_mul;
uniform vec3  u_eye;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash(i + vec3(0,0,0));
    float n100 = hash(i + vec3(1,0,0));
    float n010 = hash(i + vec3(0,1,0));
    float n110 = hash(i + vec3(1,1,0));
    float n001 = hash(i + vec3(0,0,1));
    float n101 = hash(i + vec3(1,0,1));
    float n011 = hash(i + vec3(0,1,1));
    float n111 = hash(i + vec3(1,1,1));
    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);
    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);
    return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 4; ++i) {
        s += a * vnoise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return s;
}

void main() {
    // Slow domain warp — moves convection pattern over time.
    vec3 p = v_obj_pos * 3.5;
    float t = u_time * 0.08;
    vec3 warp = vec3(
        fbm(p + vec3(t,      0.0,   1.7)),
        fbm(p + vec3(5.2,    t,     3.1)),
        fbm(p + vec3(0.9,    2.3,   t))
    ) * 0.8;
    float n = fbm(p + warp);

    // Granule contrast: sharpen mid-range.
    float conv = smoothstep(0.25, 0.85, n);

    // Hot core base × convection factor.
    vec3 hot  = vec3(2.8, 2.4, 1.8);
    vec3 cool = vec3(1.4, 0.7, 0.25);
    vec3 col  = mix(cool, hot, conv);

    // Limb darkening — surfaces facing away from camera dim slightly.
    vec3 V = normalize(u_eye - v_world_pos);
    float ndotv = clamp(dot(normalize(v_normal), V), 0.0, 1.0);
    float limb = 0.55 + 0.45 * pow(ndotv, 0.6);

    o_color = vec4(col * limb * u_emissive_mul, 1.0);
}
