#version 410 core

// Asteroid instance shader.
// Each instance carries full Keplerian orbital elements; the position is solved
// analytically from time via Newton-Raphson so the belt animates without any
// CPU-side state. a_pos is a unit-sphere vertex (already noise-displaced by
// the CPU mesh generator) that we scale and tumble around its local axis.

layout(location = 0) in vec3 a_pos;      // unit-sphere vertex (pre-displaced)
layout(location = 2) in vec4 a_orbit1;   // a [AU], e, inc [rad], Omega [rad]
layout(location = 3) in vec4 a_orbit2;   // omega [rad], M0 [rad], n [rad/s], spin_rate [rad/s]
layout(location = 4) in vec4 a_inst;     // scale [AU], gray, rot_phase, axis_tilt

uniform mat4  u_view;
uniform mat4  u_proj;
uniform float u_time;          // simulated seconds since epoch

out vec3  v_world;
out float v_gray;

void main() {
    float a      = a_orbit1.x;
    float e      = a_orbit1.y;
    float inc    = a_orbit1.z;
    float Om     = a_orbit1.w;
    float om     = a_orbit2.x;
    float M0     = a_orbit2.y;
    float nmot   = a_orbit2.z;
    float spin   = a_orbit2.w;
    float scale  = a_inst.x;
    float gray   = a_inst.y;
    float phase  = a_inst.z;
    float tilt   = a_inst.w;

    // Mean anomaly at time.
    float M = M0 + nmot * u_time;

    // Newton-Raphson: solve E - e sin E = M. 3 iterations suffice for e < 0.3.
    float E = M;
    for (int i = 0; i < 3; ++i) {
        E -= (E - e * sin(E) - M) / (1.0 - e * cos(E));
    }
    float cosE = cos(E);
    float sinE = sin(E);
    float xp = a * (cosE - e);
    float yp = a * sqrt(max(0.0, 1.0 - e * e)) * sinE;

    // Rotate perifocal → ecliptic: R_z(Om) * R_x(inc) * R_z(om)
    float co = cos(om),  so = sin(om);
    float x1 =  co * xp - so * yp;
    float y1 =  so * xp + co * yp;

    float ci = cos(inc), si = sin(inc);
    float y2 =  ci * y1;
    float z2 =  si * y1;

    float cO = cos(Om),  sO = sin(Om);
    float x3 =  cO * x1 - sO * y2;
    float y3 =  sO * x1 + cO * y2;
    float z3 =  z2;

    vec3 orbit_pos = vec3(x3, y3, z3);

    // Local tumble: rotate the lumpy-sphere vertex around a tilted spin axis.
    float ang = phase + spin * u_time;
    float ca = cos(ang), sa = sin(ang);
    float ct = cos(tilt), st = sin(tilt);
    // Two-step rotation: tilt axis (around x), then spin (around z).
    vec3 p = a_pos;
    vec3 pt = vec3(p.x, ct * p.y - st * p.z, st * p.y + ct * p.z);
    vec3 ps = vec3(ca * pt.x - sa * pt.y, sa * pt.x + ca * pt.y, pt.z);

    vec3 world = orbit_pos + ps * scale;
    gl_Position = u_proj * u_view * vec4(world, 1.0);
    v_world = world;
    v_gray  = gray;
}
