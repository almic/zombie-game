shader_type canvas_item;

uniform vec2 size = vec2(12, 6);
uniform vec3 color_a: source_color = vec3(0);
uniform vec3 color_b: source_color = vec3(1);

void fragment() {
    if ((int(UV.x * size.x) + int(UV.y * size.y)) % 2 == 0) {
        COLOR.rgb = color_a;
    } else {
        COLOR.rgb = color_b;
    }
}
