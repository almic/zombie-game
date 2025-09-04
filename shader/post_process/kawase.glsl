#[compute]
#version 450

#define SIZE 8

layout(local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout(push_constant, std430) uniform Params
{

    vec2 inv_resolution; // 0, 4
    float offset;        // 8
    float pos_mult;      // 12

} params;

layout(set = 0, binding = 0) uniform sampler2D source;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D destination;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(pos) + 0.5) * params.inv_resolution;
    vec2 offset = vec2(params.offset) * params.pos_mult * params.inv_resolution;

    // vec4 color = textureLod(source, uv, 0.0);

    const float lod = 1.5;
    vec4 color  = textureLod(source, uv + offset, lod);
         color += textureLod(source, uv - offset, lod);
         color += textureLod(source, uv + vec2(-offset.x,  offset.y), lod);
         color += textureLod(source, uv + vec2( offset.x, -offset.y), lod);

    imageStore(destination, pos, color / 4.0);
}

