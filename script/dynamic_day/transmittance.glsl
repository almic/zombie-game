#[compute]
#version 450

#include "common_inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 0) uniform image2D lut;

layout(push_constant, std430) uniform Params
{

    uvec2 size_steps;

    uvec2 reserved;

} params;

void main()
{

    vec2 uv = gl_GlobalInvocationID.xy / params.size_steps.x;
    uint steps = params.size_steps.y;

    float sun_cos_theta = uv.x * 2.0 - 1.0;
    vec3 sun_dir = vec3(-sqrt(1.0 - sun_cos_theta*sun_cos_theta), 0.0, sun_cos_theta);

    float distance_to_earth_center = mix(EARTH_RADIUS, ATMOSPHERE_RADIUS, uv.y);
    vec3 ray_origin = vec3(0.0, 0.0, distance_to_earth_center);

    float t_d = ray_sphere_intersection(ray_origin, sun_dir, ATMOSPHERE_RADIUS);
    float dt = t_d / float(steps);

    vec4 result = vec4(0.0);

    for (int i = 0; i < steps; ++i) {
        float t = (float(i) + 0.5) * dt;
        vec3 x_t = ray_origin + sun_dir * t;

        float altitude = length(x_t) - EARTH_RADIUS;

        vec4 aerosol_absorption, aerosol_scattering;
        vec4 molecular_absorption, molecular_scattering;
        vec4 extinction;
        get_atmosphere_collision_coefficients(
            altitude,
            aerosol_absorption, aerosol_scattering,
            molecular_absorption, molecular_scattering,
            extinction);

        result += extinction * dt;
    }

    result = exp(-result);
    
    imageStore(lut, ivec2(gl_GlobalInvocationID.xy), result);

}
