shader_type spatial;
render_mode unshaded;

uniform sampler2D moon_texture: source_color, filter_linear, repeat_enable;
uniform sampler2D moon_normal: hint_normal, filter_linear, repeat_enable;

uniform vec3 sun_direction;

void fragment() {
    NORMAL_MAP_DEPTH = 0.3;

    vec3 normal = texture(moon_normal, UV).xyz;
    normal.xy = normal.xy * 2.0 - 1.0;
    normal.z = sqrt(max(0.0, 1.0 - dot(normal.xy, normal.xy)));
    normal = normalize(mix(
        NORMAL,
        TANGENT * -normal.x + BINORMAL * normal.y + NORMAL * normal.z,
        NORMAL_MAP_DEPTH
    ));

    normal = (INV_VIEW_MATRIX * vec4(normal, 0.0)).xyz;

    float light = max(0.0, min(1.0, dot(normal, sun_direction)));

    ALBEDO = texture(moon_texture, UV).rgb * light;
}
