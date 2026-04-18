#version 410 core
// corona.frag — restrained outer halo. The solar disc itself is already
// bright enough to feed bloom; this pass only adds a faint limb glow so
// the Sun reads less like a sprite with a soft-focus outline.
in vec2 v_local;
out vec4 o_color;

uniform float u_emissive_mul;
uniform float u_disc_ratio;

void main() {
    float r = length(v_local);
    if (r > 1.0) discard;

    float limb = smoothstep(u_disc_ratio - 0.03, u_disc_ratio + 0.02, r);
    float outer = 1.0 - smoothstep(u_disc_ratio + 0.01, 1.0, r);
    float halo = pow(max(limb * outer, 0.0), 1.8);

    // Very faint warm-white fringe. Most perceived glare should come from
    // tonemapped bloom off the photosphere, not from this overlay.
    vec3 col = vec3(0.95, 0.86, 0.70) * halo * u_emissive_mul * 0.18;
    float alpha = halo * 0.14;
    o_color = vec4(col, alpha);
}
