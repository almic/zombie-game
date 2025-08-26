#[compute]
#version 450


layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


layout(rgba16f, set = 0, binding = 0) uniform image2D screen;


layout(push_constant, std430) uniform Params
{

    uvec2 size;     // 0, 4
    float white;    // 8
    float reserved; // 12

} params;

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

    // color.rgb = srgb_to_linear(color.rgb);
    color.rgb = tonemap(color.rgb, params.white);
    // color.rgb = linear_to_srgb(color.rgb);

    imageStore(screen, uv, color);
}
