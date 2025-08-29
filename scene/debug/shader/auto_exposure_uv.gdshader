shader_type canvas_item;

uniform float o_factor = 0.1269873;

void fragment()
{
    float o2 = o_factor * o_factor;
    float s = 1.0 / sqrt(2.0 * PI * o2);

    float max_val = s * sqrt(
          exp(-(pow(0.0, 2.0) / (2.0 * o2)))
        * exp(-(pow(0.0, 2.0) / (2.0 * o2)))
    );

    vec2 uv = UV;
    uv -= 0.5;
    uv.x *= 1920.0 / 1080.0;

    float v = s * sqrt(
          exp(-(uv.x * uv.x / (2.0 * o2)))
        * exp(-(uv.y * uv.y / (2.0 * o2)))
    );

    COLOR = vec4(vec3(v / max_val), 1.0);
}