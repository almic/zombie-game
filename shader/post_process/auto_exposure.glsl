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

    ivec2 size;          // 0, 4
    float max_luminance; // 8
    float min_luminance; // 12
    float time_step;     // 16
    float dark_time;     // 20
    float light_time;    // 24
    float light_curve;   // 28
    vec3 night_sensitivity; // 32
    float reserved;      // 44

} params;


shared vec2 tmp_data[SIZE * SIZE];

#ifdef READ

//use for main texture
layout(set = 0, binding = 0) uniform sampler2D screen;

#else

//use for intermediate textures
layout(rg32f, set = 0, binding = 0) uniform restrict readonly image2D source;

#endif

layout(rg32f, set = 1, binding = 0) uniform restrict writeonly image2D destination;

#ifdef INTERPOLATE
layout(set = 2, binding = 0) uniform sampler2D previous;

float curve(float l, float o)
{
    return o / (o + l);
}
#endif

void main() {
    uint t = gl_LocalInvocationID.y * SIZE + gl_LocalInvocationID.x;
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);

    if (any(lessThan(pos, params.size))) {
#ifdef READ
        vec3 n = params.night_sensitivity;
        vec3 v = texelFetch(screen, pos, 0).rgb;

        // tmp_data[t] = max(v.r, max(v.g, v.b));
        tmp_data[t] = vec2(
                0.2126729 * v.r + 0.7151522 * v.g + 0.0721750 * v.b,
                n.r * v.r + n.g * v.g + n.b * v.b
        );

        vec2 uv = vec2(pos) / vec2(params.size);
        uv -= 0.5;
        uv.x *= params.size.x / params.size.y;

        // Only apply to auto exposure, night vision reads full screen
        tmp_data[t].r *= s * sqrt(
                exp(-(uv.x * uv.x / (2.0 * o2)))
              * exp(-(uv.y * uv.x / (2.0 * o2)))
        );
#else
        tmp_data[t] = imageLoad(source, pos).rg;
#endif
    } else {
        tmp_data[t] = vec2(0.0);
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
        vec2 avg = tmp_data[0] / float(rect_size.x * rect_size.y);
        pos /= ivec2(SIZE);
#ifdef INTERPOLATE
        vec2 prev = texelFetch(previous, ivec2(0, 0), 0).rg;
        avg.g = curve(avg.g, params.light_curve);
        float m = curve(mix(prev.r, avg.r, step(prev.r, avg.r)), params.light_curve);
        float time = mix(params.light_time, params.dark_time, m);
        avg = clamp(
            prev + (avg - prev) * (1.0 - exp(-(params.time_step / time))),
            vec2(params.min_luminance, 0.0),
            vec2(params.max_luminance, 1.0)
        );
#endif
        imageStore(destination, pos, vec4(avg, 0.0, 0.0));
    }
}

