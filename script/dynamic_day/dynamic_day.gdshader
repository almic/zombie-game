shader_type sky;

uniform sampler2D sky_texture : filter_linear, repeat_enable;
uniform sampler2D lut_texture : filter_nearest, repeat_disable;
uniform sampler2D moon_texture : filter_linear, repeat_disable;

uniform ivec2 lut_size;
//uniform ivec2 sky_size;

uniform vec3 sun_direction;
uniform float sun_angular_diameter;

uniform mat3 moon_basis;
uniform float moon_angular_diameter;

// Spectral stuff copied from common_inc.glsl
// Sun spectral brightness (color), can be changed
const vec4 SUN_SPECTRAL = vec4(1.679, 1.828, 1.986, 1.307);
// Spectral to RGB matrix, don't touch this!
// > Seriously, this is correct! I double-checked August 26, 2025!
const highp mat4 M = mat4(
    vec4(137.672389239975,     -8.632904716299537,  -1.7181567391931372, 0.0),
    vec4( 32.549094028629234,  91.29801417199785,  -12.005406444382531,  0.0),
    vec4(-38.91428392614275,   34.31665471469816,   29.89044807197628,   0.0),
    vec4(  8.572844237945445, -11.103384660054624, 117.47585277566478,   0.0)
);
highp vec3 linear_srgb_from_spectral_samples(highp vec4 L)
{
    return (M * L).rgb;
}

vec4 bicubic(sampler2D tex, vec2 uv, ivec2 size)
{
    vec2 coord = uv * vec2(size);
    vec2 cell = floor(coord - 0.5);
    vec2 offset = (coord - 0.5) - cell;

    // Collect pixel values for interpolation
    vec4 pixels[16];

    for (int y = 0; y < 4; ++y)
    {
        for (int x = 0; x < 4; ++x)
        {
            pixels[x + (y * 4)] = clamp(texelFetch(
                    tex,
                    ivec2(
                        clamp(int(cell.x) + x - 1, 0, size.x - 1),
                        clamp(int(cell.y) + y - 1, 0, size.y - 1)
                    ),
                    0
            ), 0.0, 1.0);
        }
    }

    vec2 t = offset;
    vec2 t2 = t * t;
    vec2 t3 = t * t2;

    vec2 q1 = 0.5 * (-t3 + 2.0 * t2 - t);
    vec2 q2 = 0.5 * (3.0 * t3 - 5.0 * t2 + 2.0);
    vec2 q3 = 0.5 * (-3.0 * t3 + 4.0 * t2 + t);
    vec2 q4 = 0.5 * (t3 - t2);

    // Row interpolation
    for (int i = 0; i < 4; ++i)
    {
        int u = i * 4;
        pixels[u] = pixels[u] * q1.x + pixels[u + 1] * q2.x + pixels[u + 2] * q3.x + pixels[u + 3] * q4.x;
    }

    // Final interpolation
    return pixels[0] * q1.y + pixels[4] * q2.y + pixels[8] * q3.y + pixels[12] * q4.y;
}

vec4 transmittance_from_lut(highp float cos_theta, highp float normalized_altitude)
{
    vec2 uv = vec2(
        clamp(cos_theta * 0.5 + 0.5, 0.0, 1.0),
        clamp(normalized_altitude, 0.0, 1.0)
    );

    return bicubic(lut_texture, uv, lut_size);
}

/**
 * Smooths the edge of astro-disks
 */
float smooth_disk(float dist, float radius, float power)
{
    return smoothstep(1.0, power, dist / radius);
}

vec3 eye_to_sky(vec3 eye_dir)
{
    // TODO: update sky shader to use Godot's coordinate system so we don't
    //       have to do any swizzle or negating. Sky mapping will stay.
    vec3 ray_dir = eye_dir.xzy; // swap y and z

    // horizontal direction
    highp float azi = atan(ray_dir.y, ray_dir.x);
    azi = azi / PI * 0.5 + 0.5;

    // vertical direction
    highp float ele = asin(ray_dir.z);
    // map to non-linear vertical (higher detail horizon pixels)
    ele = sqrt((2.0 * abs(ele) / PI)) * sign(ele) * 0.5 + 0.5;

    // TODO: when GODOT allows x/y split repeating, use X repeat only and remove this clamp()
    return texture(sky_texture, vec2(azi, clamp(ele, 0.001946, 0.99806))).rgb;
    //return bicubic(sky_texture, vec2(azi, ele), sky_size).rgb;
}

vec3 moon_mie(vec3 eye_dir, vec3 moon_dir, vec3 sun_dir)
{
    const float aerosol_turbidity = 0.007;
    const float aerosol_density = 1.25e2;
    const vec3 aerosol_color = vec3(0.72, 0.74, 0.76);

    const float g = 0.8;
    const float gg = g * g;
    const float INV_4PI = 1.0 / (4.0 * PI);
    const float RAD_DEG = 180.0 / PI;
    const vec3 UP = vec3(0.0, 1.0, 0.0);

    float zenith = max(0.0, dot(eye_dir, UP));
    float zenith_angle = dot(moon_dir, UP);
    float cos_theta = dot(eye_dir, moon_dir);

    // Godot's Mie scattering, modified to reduce horizon glare
    float optical_mass = 1.0 / (zenith + 4.0 * PI * pow(RAD_DEG * zenith, -1.253));

    vec3 mie_beta = aerosol_color * aerosol_turbidity * 2.7e-5;
    float mie_scatter = aerosol_density * optical_mass;

    vec3 extinction = exp(-(mie_beta * mie_scatter));

    float mie_phase = 1.0 + gg - 2.0 * g * cos_theta;
    mie_phase = INV_4PI * (1.0 - gg) / (mie_phase * sqrt(mie_phase));
    vec3 mie_m = mie_beta * mie_phase;

    vec3 light = pow((mie_m / mie_beta) * (1.0 - extinction), vec3(1.5));

    // This step gathers the light closer to the source
    light *= mix(vec3(1.0), pow((mie_m) / (mie_beta) * extinction, vec3(0.5)), clamp(pow(1.0 - zenith_angle, 5.0), 0.0, 1.0));

    return light;
}

vec4 get_moon_color(vec3 eye_dir)
{
    // Drawing the Moon from the texture.
    float moon_diameter_radians = moon_angular_diameter * PI / 180.0;

    vec3 moon_uv = (eye_dir * moon_basis) / (moon_diameter_radians * 2.0);
    if (moon_uv.z <= 0.0)
    {
        return vec4(0.0);
    }

    // Wrong but leaving here because the effect could be CRAZY cool
    //color = texture(moon_texture, moon_uv.xy).rgb;
    moon_uv.xy *= -1.0;
    moon_uv.xy += 0.5;
    vec4 moon_color = vec4(0.0);
    if (   moon_uv.x > 0.0 && moon_uv.x < 1.0
        && moon_uv.y > 0.0 && moon_uv.y < 1.0
    ) {
        float moon_angle = length(eye_dir - moon_basis[2]);
        moon_color = texture(moon_texture, moon_uv.xy);

        // Convert to grayscale and apply spectral color
        float luminance = 0.2126729 * moon_color.r + 0.7151522 * moon_color.g + 0.0721750 * moon_color.b;
        luminance *= 0.002;

        // Apply a little transmittance
        float xy = dot(eye_dir, vec3(0.0, 1.0, 0.0));
        vec4 transmittance = transmittance_from_lut(xy, xy);
        moon_color.rgb = linear_srgb_from_spectral_samples(
                mix(SUN_SPECTRAL, SUN_SPECTRAL * transmittance, 0.96)
            ) * luminance;

        moon_color.a *= smooth_disk(moon_angle, moon_diameter_radians, 0.98);
    }

    return moon_color;
}

vec4 get_sun_color(vec3 eye_dir, float moon_mask)
{
    // Sun disk smoothing
    const float factor = 0.96;

    float xy = dot(eye_dir, vec3(0.0, 1.0, 0.0));
    vec4 transmittance = transmittance_from_lut(xy, 0.5 * xy * xy);
    vec3 color = linear_srgb_from_spectral_samples(SUN_SPECTRAL * transmittance);

    float sun_diameter_radians = sun_angular_diameter * PI / 180.0;
    float alpha = 0.0;

    // Bloom outside disk
    float min_sun_cos_theta = cos(sun_diameter_radians * factor);
    float cos_theta = dot(eye_dir, sun_direction);
    if (cos_theta < min_sun_cos_theta)
    {
        float offset = min_sun_cos_theta - cos_theta;
        float inv_bloom = 1.0 / (0.02 + offset * 2000.0) * 0.004;

        float bloom = smoothstep(0.0, 1.0, inv_bloom);
        alpha += bloom;
    }

    float sun_angle = length(eye_dir - sun_direction);
    if (sun_angle < sun_diameter_radians)
    { // Sun disk adding
        alpha += max(0.0, smooth_disk(sun_angle, sun_diameter_radians, factor));
    }

    // Apply moon mask
    alpha = clamp(alpha, 0.0, 1.0) * moon_mask;

    return vec4(color, alpha);
}

vec3 gamma_func(vec3 color)
{
    float lum = 0.2126729 * color.r + 0.7151522 * color.g + 0.0721750 * color.b;
    //float lum = max(color.r, max(color.g, color.b));
    return mix(
        color * color,
        color,
        smoothstep(0.001, 0.18, lum)
    );
}

void sky() {

    vec3 color;

    // Sample sky
    color = eye_to_sky(EYEDIR);

    //const float k = 0.18;
    //color = 1.0 - exp(-k * color);
    color.rgb = gamma_func(color.rgb);

    // Moon has special single-sample mie scattering, mostly to look like haze
    if (!AT_CUBEMAP_PASS)
    {
        color += moon_mie(EYEDIR, moon_basis[2], sun_direction);

        // Obtain moon info early so we can cut the Sun disk if needed

        // We have to translate EYEDIR into "moon-space" so there's no distortions.
        // Must double the diameter to be correct
        vec4 moon_color = get_moon_color(EYEDIR);
        //moon_color.rgb = 1.0 - exp(-k * moon_color.rgb);
        color += moon_color.rgb * moon_color.a;

        // Drawing the Sun disk
        vec4 sun_color = get_sun_color(EYEDIR, 1.0 - moon_color.a);
        //sun_color.rgb = 1.0 - exp(-k * sun_color.rgb);

        color.rgb = mix(
                mix(color.rgb, sun_color.rgb, sun_color.a),
                mix(color.rgb, color.rgb * sun_color.rgb, sun_color.a),
                1.0 - clamp(dot(EYEDIR, vec3(0.0, 1.0, 0.0) * 2.8), 0.0, 1.0)
        );
        //color.rgb = vec3(sun_color.a);
    }

    COLOR = max(color, vec3(0.0));
}
