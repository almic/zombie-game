shader_type spatial;
render_mode depth_draw_never, depth_test_inverted, cull_disabled, blend_mul, unshaded;
stencil_mode read, compare_equal, 1;

void fragment() {
    ALBEDO = vec3(2.0, 2.0, 2.0);
}
