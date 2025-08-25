shader_type sky;

#define MOON_MIE 1
#define ACES 0
#define GAMMA_CORRECT 0

uniform sampler2D sky_texture : filter_linear, repeat_enable;
uniform sampler2D lut_texture : filter_linear, repeat_disable;
uniform sampler2D moon_texture : filter_linear, repeat_disable;

uniform vec3 sun_direction;
uniform float sun_angular_diameter;

uniform mat3 moon_basis;
uniform float moon_angular_diameter;

// Ground illumination when sun is overhead
const float ZENITH_ILLUMINANCE = 100000.0;

// Spectral stuff copied from common_inc.glsl
// Sun spectral brightness (color), can be changed
const vec4 SUN_SPECTRAL = vec4(1.679, 1.828, 1.986, 1.307);
// precomputed ground irradiance at zenith
const vec4 ZENITH_IRRADIANCE =
        // Scale to illuminance scale factor
        (ZENITH_ILLUMINANCE / 100000.0)
        * SUN_SPECTRAL;
// Spectral to RGB matrix, don't touch this!
const mat4 M = mat4(
    vec4(137.672389239975,     -8.632904716299537,  -1.7181567391931372, 0.0),
    vec4( 32.549094028629234,  91.29801417199785,  -12.005406444382531,  0.0),
    vec4(-38.91428392614275,   34.31665471469816,   29.89044807197628,   0.0),
    vec4(  8.572844237945445, -11.103384660054624, 117.47585277566478,   0.0)
);
vec3 linear_srgb_from_spectral_samples(vec4 L)
{
    return (M * L).xyz;
}

highp vec4 transmittance_from_lut(float cos_theta, float normalized_altitude)
{
    highp float u = clamp(cos_theta * 0.5 + 0.5, 0.0, 1.0);
    highp float v = clamp(normalized_altitude, 0.0, 1.0);
    highp vec2 uv;
    uv.x = u;
    uv.y = v;
    return texture(lut_texture, uv);
}

#if ACES
/*
 * ACES tonemapping fit for the sRGB color space
 * https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
 */
// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
const mat3 aces_input_mat = mat3(
    vec3(0.59719, 0.07600, 0.02840),
    vec3(0.35458, 0.90834, 0.13383),
    vec3(0.04823, 0.01566, 0.83777)
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 aces_output_mat = mat3(
    vec3(1.60475, -0.10208, -0.00327),
    vec3(-0.53108,  1.10813, -0.07276),
    vec3(-0.07367, -0.00605,  1.07602)
);

vec3 rrt_and_odt_fit(vec3 v)
{
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 aces_fitted(vec3 color)
{
    color = aces_input_mat * color;
    color = rrt_and_odt_fit(color);
    color = aces_output_mat * color;
    return clamp(color, 0.0, 1.0);
}
#endif

#if GAMMA_CORRECT
vec3 gamma_correct(vec3 linear_srgb)
{
    vec3 a = 12.92 * linear_srgb;
    vec3 b = 1.055 * pow(linear_srgb, vec3(1.0 / 2.4)) - 0.055;
    vec3 c = step(vec3(0.0031308), linear_srgb);
    return mix(a, b, c);
}
#endif

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
    float azi = atan(ray_dir.y, ray_dir.x);
    azi = azi / PI * 0.5 + 0.5;

    // vertical direction
    float ele = asin(ray_dir.z);
    // map to non-linear vertical (higher detail horizon pixels)
    ele = sqrt(abs(ele) / (PI * 0.5)) * sign(ele) * 0.5 + 0.5;

    // TODO: when GODOT allows x/y split repeating, use X repeat only and remove this clamp()
    return texture(sky_texture, vec2(azi, clamp(ele, 0.001946, 0.99806))).rgb;
}

#if MOON_MIE
vec3 moon_mie(vec3 eye_dir, vec3 moon_dir, vec3 sun_dir)
{
    const float aerosol_turbidity = 0.018;
    const float aerosol_density = 1.25e3;
    const vec3 aerosol_color = vec3(0.69, 0.67, 0.74);

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
#endif

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
        moon_color.a *= smooth_disk(moon_angle, moon_diameter_radians, 0.98);
    }

    return moon_color;
}

vec4 get_sun_color(vec3 eye_dir, float moon_mask)
{
    // Sun disk smoothing
    const float factor = 0.96;

    // Sun spectral color
    vec4 zenith_transmittance = transmittance_from_lut(1.0, 0.0);
    vec4 space_irradiance = ZENITH_IRRADIANCE / zenith_transmittance;
    float xy = dot(eye_dir, vec3(0.0, 1.0, 0.0));
    vec4 transmittance = transmittance_from_lut(xy, xy);

    float sun_diameter_radians = sun_angular_diameter * PI / 180.0;
    vec4 sun_color = vec4(0.0);

    // Bloom effect
    float min_sun_cos_theta = cos(sun_diameter_radians * factor);
    float cos_theta = dot(eye_dir, sun_direction);
    if (cos_theta < min_sun_cos_theta)
    {
        float offset = min_sun_cos_theta - cos_theta;

        float gaussian = exp(-offset * 50000.0) * 0.5;
        float inv_bloom = 1.0 / (0.02 + offset * 300.0) * 0.01;

        float bloom = gaussian + inv_bloom;
        // Reduce greatly at the horizon
        sun_color += transmittance * space_irradiance * smoothstep(0.002, 1.0, bloom);
    }

    float sun_angle = length(eye_dir - sun_direction);
    if (sun_angle < sun_diameter_radians)
    { // Sun disk adding
        vec4 sun_disk = (PI / 2.0) * space_irradiance * moon_mask;
        sun_color = mix(
                sun_color,
                sun_disk,
                smooth_disk(sun_angle, sun_diameter_radians, factor)
        );
    }

    return vec4(
            linear_srgb_from_spectral_samples(sun_color * transmittance),
            1.0
    );
}

void sky() {

    vec3 color;

    // Sample sky
    color = eye_to_sky(EYEDIR);

#if MOON_MIE
    // Moon has special single-sample mie scattering, mostly to look like haze
    if (!AT_CUBEMAP_PASS)
    {
        color += moon_mie(EYEDIR, moon_basis[2], sun_direction);
    }
#endif

    // Obtain moon info early so we can cut the Sun disk if needed

    // We have to translate EYEDIR into "moon-space" so there's no distortions.
    // Must double the diameter to be correct
    vec4 moon_color = get_moon_color(EYEDIR);
    color += (moon_color.rgb * TAU) * moon_color.a;

    // Drawing the Sun disk
    vec4 sun_color = get_sun_color(EYEDIR, 1.0 - moon_color.a);

    // After a bit of testing, I found this blending to look the most
    // accurate. Screen may be correct, but I can't solve the artifacting problem.
    color = max(color, color + (sun_color.rgb * sun_color.a));

#if ACES
    color = color * exp2(-5.0);
    color = aces_fitted(color);
#else
    const float k = 0.065;
    color = 1.0 - exp(-k * color);
#endif

#if GAMMA_CORRECT
    color = clamp(gamma_correct(color), 0.0, 1.0);
#endif

    COLOR = color;
}
