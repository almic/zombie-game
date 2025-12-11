#[compute]
#version 450


layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


layout(rgba16f, set = 0, binding = 0) uniform image2D screen;
layout(set = 0, binding = 1) uniform sampler2D auto_exposure;


layout(push_constant, std430) uniform Params
{

    uvec2 size;           // 0, 4
    float white;          // 8
    float exposure_scale; // 12
    vec3 night_vision_color; // 16
    float light_curve;       // 28
    vec3 night_sensitivity;  // 32
    float reserved;          // 44

} params;


float curve(float l, float o)
{
    return o / (o + l);
}

// Copied from Godot's effects shaders

// Based on Reinhard's extended formula, see equation 4 in https://doi.org/cjbgrt
vec3 tonemap(vec3 color, float p_white) {
    float white_squared = p_white * p_white;
    vec3 white_squared_color = white_squared * color;
    return (white_squared_color + color * color) / (white_squared_color + white_squared);
}

void main()
{
    if (gl_GlobalInvocationID.x > params.size.x || gl_GlobalInvocationID.y > params.size.y) {
        return;
    }

    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec4 color = imageLoad(screen, uv);

    // Debug shaders/ materials which output negative pixel values
    if (max(color, vec4(0)) != color) {
        color.rgb = vec3(1.0, 0.0, 1.0);
    }

    vec2 auto_values = texelFetch(auto_exposure, ivec2(0), 0).rg;
    float exposure = params.exposure_scale / auto_values.r;
    float color_luminance = max(color.r, max(color.g, color.b));

    // Apply exposure before blending night vision, that way it has the correct luminance
    color.rgb *= mix(exposure, 1.0, isinf(exposure));

    vec3 v = params.night_sensitivity;
    float night_luminance = v.r * color.r + v.g * color.g + v.b * color.b;
    vec3 night_color = params.night_vision_color * auto_values.g * night_luminance;
    float night_curve = curve(auto_values.r + color_luminance, params.light_curve);
    color.rgb = mix(color.rgb, night_color, night_curve * night_curve);

    color.rgb = tonemap(color.rgb, params.white);

    imageStore(screen, uv, color);
}
