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

// Functions copied from Godot's effects shaders

// This expects 0-1 range input.
vec3 linear_to_srgb(vec3 color) {
    // Approximation from http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
    return max(vec3(1.055) * pow(color, vec3(0.416666667)) - vec3(0.055), vec3(0.0));
}

// This expects 0-1 range input, outside that range it behaves poorly.
vec3 srgb_to_linear(vec3 color) {
    // Approximation from http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
    return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
}

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

    vec2 auto_values = texelFetch(auto_exposure, ivec2(0), 0).rg;
    float exposure = params.exposure_scale / auto_values.r;
    // Apply exposure before blending night vision, that way it has the correct luminance
    color.rgb *= mix(exposure, 1.0, isinf(exposure));

    vec3 v = params.night_sensitivity;
    float night_luminance = v.r * color.r + v.g * color.g + v.b * color.b;
    vec3 night_color = params.night_vision_color * auto_values.g * night_luminance;
    color.rgb = mix(color.rgb, night_color, curve(auto_values.r, params.light_curve));

    // color.rgb = srgb_to_linear(color.rgb);
    color.rgb = tonemap(color.rgb, params.white);
    // color.rgb = linear_to_srgb(color.rgb);

    imageStore(screen, uv, color);
}
