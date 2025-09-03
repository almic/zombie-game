#version 450

#define SIZE 8

#VERSION_DEFINES

const float PI = 3.14159265358979323846;
const float o = 0.1269873;
const float o2 = o * o;
const float s = 0.5 / sqrt(2.0 * PI * o2);

layout(local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout(push_constant, std430) uniform Params
{

    ivec2 size;       // 0, 4
    float dark_time;  // 8
    float light_time; // 12
    vec3 color_sensitivity;  // 16
    float time_step;         // 28
    vec3 night_vision_color; // 32

} params;


#ifdef WRITE

layout(rgba16f, set = 0, binding = 0) uniform image2D screen;
layout(set = 0, binding = 1) uniform sampler2D vision_texture;

#else

shared float tmp_data[SIZE * SIZE];

#ifdef READ

//use for main texture
layout(set = 0, binding = 0) uniform sampler2D source_texture;

#else

//use for intermediate textures
layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D source_vision;

#endif // READ

layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D dest_vision;

#ifdef INTERPOLATE
layout(set = 2, binding = 0) uniform sampler2D prev_vision;
#endif

#endif // WRITE

float night_vision(float l)
{
    return 0.0004 / (0.0004 + l);
}

float sensitivity(vec3 color, vec3 sens)
{
    return color.r * sens.r + color.g * sens.g + color.b * sens.b;
}

void main() {
    uint t = gl_LocalInvocationID.y * SIZE + gl_LocalInvocationID.x;
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);

#ifdef WRITE
    vec4 color = imageLoad(screen, pos);
    float luminance = 0.2126729 * color.r + 0.7151522 * color.g + 0.0721750 * color.b;
    float darkness = night_vision(luminance);
    float night_luminance = pow(sensitivity(color.rgb, params.color_sensitivity), 1.0/1.8);
    vec3 night_color = params.night_vision_color * darkness * texelFetch(vision_texture, ivec2(0), 0).r;
    color.rgb = mix(
            color.rgb,
            night_color * night_luminance,
            step(max(color.r, max(color.g, color.b)), min(night_color.r, min(night_color.g, night_color.b)))
    );
    /*
    color.rgb = mix(
            params.night_vision_color * darkness * night_luminance * texelFetch(vision_texture, ivec2(0), 0).r,
            color.rgb,
            smoothstep(1e-5, 1e-4, max(color.r, max(color.g, color.b)))
    );
    */

    // color.rgb += texelFetch(vision_texture, ivec2(0, 0), 0).r;
    // color.rgb += params.time_step;
    // color.rgb = params.color_sensitivity;
    // color.rgb = params.night_vision_color;
    imageStore(screen, pos, color);
#else
    if (any(lessThan(pos, params.size))) {
#ifdef READ
        vec3 v = texelFetch(source_texture, pos, 0).rgb;

        tmp_data[t] = sensitivity(v, params.color_sensitivity);

        vec2 uv = vec2(pos) / vec2(params.size);
        uv -= 0.5;
        uv.x *= params.size.x / params.size.y;

        tmp_data[t] *= s * sqrt(
              exp(-(uv.x * uv.x / (2.0 * o2)))
            * exp(-(uv.y * uv.x / (2.0 * o2)))
        );

#else
        tmp_data[t] = imageLoad(source_vision, pos).r;
#endif
    } else {
        tmp_data[t] = 0.0;
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
        ivec2 rect_size = min(params.size - pos, ivec2(SIZE));
        float avg = tmp_data[0] / float(rect_size.x * rect_size.y);
        pos /= ivec2(SIZE);
#ifdef INTERPOLATE
        float prev = texelFetch(prev_vision, ivec2(0, 0), 0).r;
        float target = night_vision(avg);
        float time = params.light_time * (1.0 - target) + params.dark_time * target;
        avg = clamp(
            prev + (target - prev) * (1.0 - exp(-(params.time_step / time))),
            // prev + (target - prev) * (params.time_step),
            // target,
            0.0,
            1.0
        );
#endif
        imageStore(dest_vision, pos, vec4(avg));
    }
#endif // WRITE
}

