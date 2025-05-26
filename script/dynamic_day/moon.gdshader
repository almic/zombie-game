shader_type spatial;
render_mode unshaded, skip_vertex_transform;

uniform sampler2D moon_texture: source_color, filter_linear, repeat_enable;
uniform sampler2D moon_normal: hint_normal, filter_linear, repeat_enable;

uniform vec3 sun_direction;

// To apply rotations on the model according to orbital motion
uniform mat3 moon_orbit_basis;

// To compute light direction accurately
uniform mat3 moon_basis;

/*

    Here is the concept:

    1. The sky box uses the moon basis to draw the render on the sky. This has
       an effect of apparently rotating the moon body in space with the moon
       light direction, which is undesirable. The moon light should only place
       the moon in the sky (orbital position), not apparently rotate the body.

    2. To correct this, we must rotate the model according to the orientation of
       the moon position, giving us a simple directional placement from the light
       forward direction. This is done via the vertex function, so that we now
       rotate the moon mesh directly to rotate the body in the sky, and the moon
       light direction only places the object in the sky.

    3. The sun position is now apparently correct only when the moon position is
       at the default position in the sky. To correct this, we can simply apply
       the moon sky transform onto the sun direction.

    Finally, a simple solution.
    This is the bare minimum number of moving parts and calculations.

*/

void vertex()
{
    mat4 model_view = VIEW_MATRIX * (inverse(mat4(moon_orbit_basis)) * MODEL_MATRIX);
    VERTEX = (model_view * vec4(VERTEX, 1.0)).xyz;
    NORMAL = normalize((model_view * vec4(NORMAL, 0.0)).xyz);
    BINORMAL = normalize((model_view * vec4(BINORMAL, 0.0)).xyz);
    TANGENT = normalize((model_view * vec4(TANGENT, 0.0)).xyz);
}

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

    vec3 light_angle = inverse(moon_basis) * sun_direction;
    float light = max(0.0, min(1.0, dot(normal, light_angle) * 2.0));

    ALBEDO = texture(moon_texture, UV).rgb * light;
}
