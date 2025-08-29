#version 450

#define SIZE 8

#VERSION_DEFINES

const float PI = 3.14159265358979323846;
//const float o = 0.1269873;
//const float o2 = o * o;
//const float s = 0.5 / sqrt(2.0 * PI * o2);

layout(local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout(push_constant, std430) uniform Params
{

    ivec2 size;            // 0, 4
    float max_luminance;   // 8
    float min_luminance;   // 12
    float exposure_adjust; // 16
    float reserved;        // 20

} params;


shared vec3 tmp_data[SIZE * SIZE];

#ifdef READ_TEXTURE

//use for main texture
layout(set = 0, binding = 0) uniform sampler2D source_texture;

#else

//use for intermediate textures
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D source_luminance;

#endif

layout(rgba32f, set = 1, binding = 0) uniform restrict writeonly image2D dest_luminance;

#ifdef INTERPOLATE_LUMINANCE
layout(set = 2, binding = 0) uniform sampler2D prev_luminance;
#endif


void main() {
    uint t = gl_LocalInvocationID.y * SIZE + gl_LocalInvocationID.x;
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);

    if (any(lessThan(pos, params.size))) {
#ifdef READ_TEXTURE
        tmp_data[t] = texelFetch(source_texture, pos, 0).rgb;
        //tmp_data[t] = max(v.r, max(v.g, v.b));
        //tmp_data[t] = 0.2126729 * v.r + 0.7151522 * v.g + 0.0721750 * v.b;

       // const float o = 0.1269873;
        float o2 = params.reserved * params.reserved;
        float s = 0.5 / sqrt(2.0 * PI * o2);

        vec2 uv = vec2(pos) / vec2(params.size);
        uv -= 0.5;
        uv.x *= params.size.x / params.size.y;

        tmp_data[t] *= s * sqrt(
                exp(-(uv.x * uv.x / (2.0 * o2)))
              * exp(-(uv.y * uv.x / (2.0 * o2)))
        );
#else
        tmp_data[t] = imageLoad(source_luminance, pos).rgb;
#endif
    } else {
        tmp_data[t] = vec3(0.0);
    }

    groupMemoryBarrier();
    barrier();

    uint size = (SIZE * SIZE) >> 1;

    do {
        if (t < size) {
            tmp_data[t] += tmp_data[t + size];
        }
        groupMemoryBarrier();
        barrier();

        size >>= 1;
    } while (size >= 1);

    if (t == 0) {
        //compute rect size
        ivec2 rect_size = min(params.size - pos, ivec2(SIZE));
        vec3 avg = tmp_data[0] / float(rect_size.x * rect_size.y);
        //float avg = tmp_data[0] / float(BLOCK_SIZE*BLOCK_SIZE);
        pos /= ivec2(SIZE);
#ifdef INTERPOLATE_LUMINANCE
        vec3 prev_lum = texelFetch(prev_luminance, ivec2(0, 0), 0).rgb;
        avg = clamp(
            prev_lum + (avg - prev_lum) * params.exposure_adjust,
            vec3(params.min_luminance),
            vec3(params.max_luminance)
        );
#endif
        imageStore(dest_luminance, pos, vec4(avg, 1.0));
    }
}

