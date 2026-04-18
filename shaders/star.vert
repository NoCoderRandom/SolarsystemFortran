#version 410 core

// Star points live on a unit sphere and follow the camera (view with
// translation zeroed). The fragment shader paints a soft disc modulated by a
// per-star twinkle phase and the star magnitude (brighter = bigger + brighter).

layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec3 a_color;
layout(location = 2) in float a_mag;     // magnitude multiplier (0..1, higher = brighter)
layout(location = 3) in float a_phase;   // random phase for twinkle

uniform mat4 u_view;     // camera view with translation already stripped (CPU-side)
uniform mat4 u_proj;
uniform float u_time;
uniform float u_intensity;

out vec3  v_color;
out float v_brightness;

void main() {
    // Push points to the far plane at z=-1 so depth write/comparison still sorts.
    vec4 clip = u_proj * u_view * vec4(a_pos, 1.0);
    // Force to far plane (1.0 in NDC after w-divide) so scene geometry always occludes.
    clip.z = clip.w * 0.9999;
    gl_Position = clip;

    // Twinkle: 0.7..1.0 range driven by time + per-star phase.
    float tw = 0.85 + 0.15 * sin(u_time * 2.5 + a_phase * 6.2831);

    // Point size in pixels — brighter stars = larger disc
    gl_PointSize = mix(1.2, 5.0, a_mag) * tw;

    v_color = a_color;
    v_brightness = a_mag * tw * u_intensity;
}
