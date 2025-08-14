shader_type spatial;

render_mode unshaded;

uniform sampler2D viewport: source_color, filter_linear;


void fragment() {
    ALBEDO = texture(viewport, UV).rgb;
    vec2 p = UV * 2.0 - 1.0;
    ALPHA = step(sqrt(p.x * p.x + p.y * p.y), 1.0);
}
