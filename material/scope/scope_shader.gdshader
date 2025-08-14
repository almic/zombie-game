shader_type spatial;


uniform sampler2D viewport: source_color, filter_linear;


void fragment() {
    ALBEDO = texture(viewport, UV).rgb;
}
