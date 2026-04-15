#version 410 core
// fullscreen.vert — gl_VertexID triangle trick.
// Emits a single oversized triangle covering the clip-space viewport.
// No VBO needed; bind any VAO and draw 3 vertices.
out vec2 v_uv;
void main() {
    vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    v_uv = p;
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
