shader_type spatial;
render_mode unshaded;

//uniform float animation_progress;
uniform float time: hint_range(0.0, 1.0, 0.0001) = 0.0;

uniform float scale_x = 2.0;
uniform float scale_y = 1.0;
uniform float skew: hint_range(-1.41, 1.41, 0.001) = 1.0;

uniform sampler2D shaping_gradient: source_color, repeat_disable, filter_linear;
uniform sampler2D flame_gradient: source_color, repeat_disable, filter_linear;

uniform float noise_power: hint_range(0.0, 2.0, 0.0001) = 0.5;
uniform sampler2D noise_texture: source_color, repeat_enable, filter_linear;

vec4 flame(sampler2D shape_gradient, sampler2D color_gradient, vec2 uv)
{
    const float radius = 0.5;
    uv.xy -= 0.5;
    float x = sqrt(radius * radius - (uv.x * uv.x + uv.y * uv.y));

    if (x > 0.0)
    {
        uv = vec2((radius - x) / radius, 0.0);
        vec3 shape = texture(shape_gradient, uv).rgb;
        vec3 color = texture(color_gradient, uv).rgb;
        return vec4(shape * color, shape.r);
    }

    return vec4(0.0);
}

void fragment() {
    vec2 shape_uv = UV;
    shape_uv.x *= scale_x;
    shape_uv.x -= (scale_x - 1.0) * 0.5;

    shape_uv.y *= scale_y;
    shape_uv.y = mix(shape_uv.y, atan(shape_uv.y, 0.64), skew);

    vec2 noise_uv = UV;
    noise_uv.y -= time * 3.0;

    shape_uv.x += noise_power * (texture(noise_texture, noise_uv.xy + 0.25).x - 0.5);
    shape_uv.y += noise_power * (texture(noise_texture, noise_uv.xy - 0.25).y - 0.5);

    vec4 color = flame(
        shaping_gradient,
        flame_gradient,
        shape_uv
    );

    ALBEDO = color.rgb;
    ALPHA = color.a;
}
