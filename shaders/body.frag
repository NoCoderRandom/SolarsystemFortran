#version 330 core
// body.frag — flat fragment shader for solar system bodies
//
// Passes the per-instance color directly to the framebuffer.
// No lighting, no shading — flat colored spheres.

in vec3 v_color;
out vec4 frag_color;

void main() {
    frag_color = vec4(v_color, 1.0);
}
