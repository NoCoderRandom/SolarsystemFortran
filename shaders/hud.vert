#version 330 core
// hud.vert — Screen-space vertex shader for HUD text
// No depth, orthographic projection baked in.

layout(location = 0) in vec2 a_pos;   // screen-space pixel coords (0..width, 0..height)
layout(location = 1) in vec3 a_color; // RGB color

uniform vec2 u_resolution; // window resolution in pixels

out vec3 v_color;

void main() {
    // Convert pixel coords to NDC [-1, 1]
    vec2 ndc = a_pos / u_resolution;
    ndc = ndc * 2.0 - 1.0;
    ndc.y = -ndc.y; // Flip Y (screen space has Y-down, OpenGL has Y-up)
    gl_Position = vec4(ndc, 0.0, 1.0);
    v_color = a_color;
}
