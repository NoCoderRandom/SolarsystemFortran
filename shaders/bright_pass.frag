#version 410 core
// bright_pass.frag — isolate HDR pixels brighter than u_threshold.
// Uses Rec. 709 luminance. Soft knee smooths the cutoff so transitions
// don't flicker when a pixel hovers around the threshold.
in vec2 v_uv;
out vec4 o_color;

uniform sampler2D u_src;
uniform float u_threshold;

void main() {
    vec3 c = texture(u_src, v_uv).rgb;
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float knee = 0.5;
    float soft = clamp((lum - u_threshold + knee) / (2.0 * knee), 0.0, 1.0);
    soft = soft * soft * (3.0 - 2.0 * soft);
    float w = max(max(lum - u_threshold, 0.0), soft * (lum - u_threshold + knee));
    w = w / max(lum, 1e-4);
    o_color = vec4(c * w, 1.0);
}
