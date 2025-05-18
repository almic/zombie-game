shader_type sky;

uniform sampler2D sky_texture;

// Even though this isn't used, it is here to force regular radiance updates,
// which affect scene brightness and fog colors. Godot might be stupid.
uniform vec3 sun_direction;

vec3 gamma_correct(vec3 linear_srgb)
{
    vec3 a = 12.92 * linear_srgb;
    vec3 b = 1.055 * pow(linear_srgb, vec3(1.0 / 2.4)) - 0.055;
    vec3 c = step(vec3(0.0031308), linear_srgb);
    return mix(a, b, c);
}

void sky() {
    vec3 ray_dir = sun_direction; // use hack
    ray_dir = EYEDIR.xzy;
    float phi = atan(-ray_dir.x, ray_dir.y);
    float theta = asin(ray_dir.z);

    float azi = phi / PI * 0.5 - 0.25;
    float ele = sqrt(abs(theta) / (PI * 0.5)) * sign(theta) * 0.5 + 0.5;

    vec3 color = texture(sky_texture, vec2(azi, ele)).rgb;
    color = 1.0 - exp(-0.05 * color);
    color = clamp(gamma_correct(color), 0.0, 1.0);

    COLOR = color;
}
