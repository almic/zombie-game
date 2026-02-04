shader_type spatial;
render_mode depth_draw_never;
stencil_mode write, 0;

void fragment() {
    // Called for every pixel the material is visible on.
    ALPHA = 0.0;
}

