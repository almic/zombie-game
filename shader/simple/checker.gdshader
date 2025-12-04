shader_type spatial;

uniform vec2 size = vec2(12, 6);

void fragment() {
    if ((int(UV.x * size.x) + int(UV.y * size.y)) % 2 == 0) {
        ALBEDO.rgb = vec3(0);
    } else {
        ALBEDO.rgb = vec3(1);
    }
}
