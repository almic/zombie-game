#[compute]
#version 450

#include "common_inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D lut;

layout(rgba32f, set = 0, binding = 1) uniform restrict writeonly image2D sky;

layout(push_constant, std430) uniform Params 
{

    uvec2 size_steps; // 0, 4
    float shadowing;  // 8
    float reserved;   // 12

    vec3 sun_dir;     // 16, 20, 24
    // padded to 28 (32 bytes total)

} params;

vec4 compute_inscattering(
        vec3 ray_origin,
        vec3 ray_dir,
        float t_d,
        out vec4 transmittance)
{
    vec3 sun_dir = params.sun_dir;
    float shadowing = params.shadowing;

    float cos_theta = dot(-ray_dir, sun_dir);

    float molecular_phase = molecular_phase_function(cos_theta);
    float aerosol_phase = aerosol_phase_function(cos_theta);

    float dt = t_d / float(params.size_steps.y);

    vec4 L_inscattering = vec4(0.0);
    transmittance = vec4(1.0);

    for (int i = 0; i < params.size_steps.y; ++i) {
        float t = (float(i) + 0.5) * dt;
        vec3 x_t = ray_origin + ray_dir * t;

        float distance_to_earth_center = length(x_t);
        vec3 zenith_dir = x_t / distance_to_earth_center;
        float altitude = distance_to_earth_center - EARTH_RADIUS;
        float normalized_altitude = altitude / ATMOSPHERE_THICKNESS;

        float sample_cos_theta = dot(zenith_dir, sun_dir);

        vec4 aerosol_absorption, aerosol_scattering;
        vec4 molecular_absorption, molecular_scattering;
        vec4 extinction;
        get_atmosphere_collision_coefficients(
            altitude,
            aerosol_absorption, aerosol_scattering,
            molecular_absorption, molecular_scattering,
            extinction);

        vec4 transmittance_to_sun = transmittance_from_lut(
            lut, sample_cos_theta, normalized_altitude);

        vec4 ms = get_multiple_scattering(
            lut, sample_cos_theta, normalized_altitude,
            distance_to_earth_center);

        // Higher impact on mie from shadowing
        vec4 S = sun_spectral_irradiance * shadowing *
            (molecular_scattering * (molecular_phase * transmittance_to_sun + ms) +
             aerosol_scattering   * (aerosol_phase   * transmittance_to_sun + ms));

        vec4 step_transmittance = exp(-dt * extinction);

        // Energy-conserving analytical integration
        // "Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite"
        // by Sebastien Hillaire
        vec4 S_int = (S - S * step_transmittance) / max(extinction, 1e-7);
        L_inscattering += transmittance * S_int;
        transmittance *= step_transmittance;
    }

    return L_inscattering;
}

void main() 
{

    vec2 uv = vec2(gl_GlobalInvocationID.xy) / float(params.size_steps.x);

    float azimuth = 2.0 * PI * uv.x;

    // Apply a non-linear transformation to the elevation to dedicate more
    // texels to the horizon, where having more detail matters.
    float l = uv.y * 2.0 - 1.0;
    float elev = l*l * sign(l) * PI * 0.5; // [-pi/2, pi/2]

    vec3 ray_dir = vec3(cos(elev) * cos(azimuth),
                        cos(elev) * sin(azimuth),
                        sin(elev));

    vec3 ray_origin = vec3(0.0, 0.0, EYE_DISTANCE_TO_EARTH_CENTER);

    float atmos_dist  = ray_sphere_intersection(ray_origin, ray_dir, ATMOSPHERE_RADIUS);
    float ground_dist = ray_sphere_intersection(ray_origin, ray_dir, EARTH_RADIUS);
    float t_d;

    // We are inside the atmosphere
    if (ground_dist < 0.0) {
        // No ground collision, use the distance to the outer atmosphere
        t_d = atmos_dist;
    } else {
        // We have a collision with the ground, use the distance to it
        t_d = ground_dist;
    }

    vec4 transmittance;
    vec4 L = compute_inscattering(ray_origin, ray_dir, t_d, transmittance);

    L = vec4(linear_srgb_from_spectral_samples(L), 1.0);

    imageStore(sky, ivec2(gl_GlobalInvocationID.xy), L);

}

