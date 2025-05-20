shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Instance uniforms
/**
 * Time used to animate the effect. This is modulated through code.
 */
instance uniform float time: hint_range(0.0, 1.0, 0.0001) = 0.0;

/**
 * Instance noise offset. This should be modulated through code.
 */
instance uniform vec2 noise_offset = vec2(0.0, 0.0);

/**
 * If this is a front-view flash, using a circular shape and radial noise.
 * When this is enabled, X-Axis scaling sets the radius and skew is ignored.
 */
instance uniform bool is_front = false;


group_uniforms Parameters;

/**
 * Affects the flame fade curve, values above 1.0 make the flame linger.
 */
uniform float fade_speed: hint_range(1.0, 15.0, 0.0001) = 4.0;


group_uniforms Shape;

/**
 * X-Axis scale multiplier.
 */
uniform float scale_x = 2.0;

/**
 * Y-Axis scale multiplier.
 */
uniform float scale_y = 1.0;

/**
 * Flame skewness multiplier. Be careful with values outside [-1.0, 1.0] range.
 */
uniform float skew: hint_range(-1.41, 1.41, 0.001) = 1.0;


group_uniforms Color;

/**
 * Affects the opacity gradient of the flame. White is opaque and black is tranparent.
 */
uniform sampler2D shaping_gradient: source_color, repeat_disable, filter_linear;

/**
 * Coloring of the flame from the center
 */
uniform sampler2D flame_gradient: source_color, repeat_disable, filter_linear;

/**
 * "Smokey-ness" of the flame over time, alpha controls overall opacity and gray controls smoke-flame mixing.
 * Real muzzle flashes start with smoke, then mix a flame that fades over time.
 */
uniform sampler2D smoke_mix: source_color, repeat_disable, filter_linear;


group_uniforms Noise;

/**
 * Intended for viewing the shape and fade effect. Leave enabled.
 */
uniform bool noise_enabled = true;

/**
 * Influence of the noise. You should stay in the [0.0, 1.0] range.
 */
uniform float noise_power: hint_range(0.0, 2.0, 0.0001) = 0.5;

/**
 * The noise texture. Seamless should be enabled.
 */
uniform sampler2D noise_texture: source_color, repeat_enable, filter_linear;

group_uniforms;


float fresnel(float power, vec3 normal, vec3 view)
{
    return pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), power);
}

void fragment() {
    if (time < 1e-4)
    {
        discard;
    }

    const float radius = 0.5;

    // Shaping
    vec2 shape_uv = UV;
    float top = min(fade_speed * time, 1.0);
    float bottom = clamp(fade_speed * time - fade_speed + 1.0, 0.0, 1.0);

    // first, scale x over time
    float x_t = scale_x / (top - bottom);
    shape_uv.x *= x_t;
    shape_uv.x -= (x_t - 1.0) * 0.5;

    if (is_front)
    {
        shape_uv.y *= x_t;
        shape_uv.y -= (x_t - 1.0) * 0.5;
    }
    else
    {
        shape_uv.y *= scale_y;
        shape_uv.y = mix(shape_uv.y, atan(shape_uv.y, 0.64), skew);

        // Grow and shrink on y axis
        shape_uv.y = (shape_uv.y - bottom) / (top - bottom);
    }

    vec2 flame_uv = shape_uv;

    vec2 noise_uv = UV;
    if (noise_enabled)
    {
        if (is_front)
        {
            // Map to polar coordinates
            noise_uv -= 0.5;
            float r = length(noise_uv);
            float t = atan(noise_uv.x, noise_uv.y) / TAU;

            noise_uv.x = t;
            if (noise_uv.x < 0.0)
            {
                noise_uv.x = 1.0 + noise_uv.x;
            }

            noise_uv.y = sqrt(r);
            noise_uv.y -= time * 4.0;
        }
        else
        {
            noise_uv.y -= time * 2.0;
        }
        flame_uv.x += noise_power * (texture(noise_texture, noise_uv.xy + 0.25 - noise_offset.x).x - 0.5);
        flame_uv.y += noise_power * (texture(noise_texture, noise_uv.xy - 0.25 - noise_offset.y).y - 0.5);
    }

    flame_uv.xy -= radius;

    vec4 color = vec4(0.0);
    vec4 shape = vec4(0.0);
    float x = sqrt(radius * radius - dot(flame_uv, flame_uv));
    if (x > 0.0)
    {
        // Gradient base UVs
        vec2 uv = vec2((radius - x) / radius, 0.0);

        // Shape to black with fade (+bottom)
        vec2 shape_uv = uv;
        shape_uv.x += bottom;
        shape = texture(shaping_gradient, shape_uv);

        // Modulate color with smoke.
        vec2 color_uv = uv;
        vec4 smoke = texture(smoke_mix, vec2(time, 0.0));

        // Red is the mix, which pulls down the flame color.
        color_uv.x = color_uv.x + (1.0 - smoke.r);

        // Additionally, transparency must pull down the color, too, so there's
        // no transparent flames
        color_uv.x = color_uv.x + (1.0 - smoke.a);

        color = texture(flame_gradient, color_uv);

        // Shape red is base alpha
        color.a = shape.r;

        // Smoke alpha is overall opacity.
        color.a *= smoke.a;

        EMISSION = max(color.rgb * color.a, 0.0) * 300000.0;
    }

    ALBEDO = color.rgb;
    ALPHA = clamp(
            clamp(color.a, 0.0, 1.0) - fresnel(2.0, NORMAL, VIEW),
            0.0, 1.0
    );
}
