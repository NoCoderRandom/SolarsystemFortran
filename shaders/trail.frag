#version 330 core
// trail.frag — Fragment shader for orbit trail lines
//
// Outputs colored trail with fade-based alpha for additive blending.

in vec3 v_color;
in float v_fade;
out vec4 frag_color;

void main() {
    // Discard fully transparent fragments
    if (v_fade < 0.001) discard;

    // Color with fade as alpha — additive blending makes overlapping trails glow
    frag_color = vec4(v_color * v_fade, v_fade);
}
