shader_type sky;

#define ACES 1

uniform sampler2D sky_texture : filter_linear, repeat_enable;
uniform sampler2D lut_texture : filter_linear, repeat_disable;

uniform vec3 sun_direction;
uniform float sun_angular_diameter;

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

vec3 gamma_correct(vec3 linear_srgb)
{
    vec3 a = 12.92 * linear_srgb;
    vec3 b = 1.055 * pow(linear_srgb, vec3(1.0 / 2.4)) - 0.055;
    vec3 c = step(vec3(0.0031308), linear_srgb);
    return mix(a, b, c);
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

    return texture(sky_texture, vec2(azi, ele)).rgb;
}

void sky() {

    vec3 color;

    // Sample sky
    color = eye_to_sky(EYEDIR);

    float sun_cos_theta = dot(EYEDIR, sun_direction);
    float sun_diameter_radians = (sun_angular_diameter * PI / 180.0);
    float sun_angle = sun_diameter_radians - acos(sun_cos_theta);
    if (sun_angle > 0.0)
    {
        vec4 zenith_transmittance = transmittance_from_lut(1.0, 0.0);
        vec4 space_irradiance = ZENITH_IRRADIANCE / zenith_transmittance;

        // Give the sun a smooth edge
        float x = smoothstep(1.0, 0.96, (sun_diameter_radians - sun_angle) / sun_diameter_radians);
        space_irradiance *= x;

        float xy = dot(EYEDIR, vec3(0.0, 1.0, 0.0));
        vec4 transmittance = transmittance_from_lut(xy, xy);
        vec3 sun_color = linear_srgb_from_spectral_samples(
                space_irradiance * transmittance
        );

        // After a bit of testing, I found this blending to look the most
        // accurate. Screen may be correct, but I can't solve the artifacting problem.
        color = max(color, color + sun_color);
    }

#if ACES
    color = color * exp2(-5.0);
    color = aces_fitted(color);
#else
    const float k = 0.05;
    color = 1.0 - exp(-k * color);
#endif
    color = clamp(gamma_correct(color), 0.0, 1.0);

    COLOR = color;
}
