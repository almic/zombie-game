shader_type canvas_item;

const float ports = 6.0;

uniform float rotation = 0.0;

uniform float port_radius = 0.28125;
uniform float port_distance = 0.625;

void fragment() {
    // NOTE: Determine if 6 cos + 6 sin is more performant than 1 sqrt + 1 atan
    vec2 uv = UV;
    uv.x -= 0.5;
    uv.y = -uv.y + 0.5;

    //float w = rotation + 0.0 * (PI / 6.0);
    //uv = mat2(
            //vec2(cos(w), -sin(w)),
            //vec2(sin(w),  cos(w))
    //) * uv;

    vec2 polar = vec2(sqrt(uv.x * uv.x + uv.y * uv.y), atan(uv.y, uv.x) + PI);

    polar.y *= ports;
    int count = int(polar.y / TAU);
    // NOTE: Add 2 and mod 3, puts 0 in the right place.
    //       Why add 2? Honestly, i have no clue why 2 is the number here.
    count = (count + 2) % 3;
    polar.y = mod(polar.y, TAU) / ports;
    polar.y -= PI / ports;

    vec2 car = vec2(
            polar.x * cos(polar.y),
            polar.x * sin(polar.y)
    );

    car.x -= port_distance * 0.5;

    float w = 1.0 * rotation + 1.0 * float(count) * (PI / 6.0);
    car = mat2(
            vec2(cos(w), -sin(w)),
            vec2(sin(w),  cos(w))
    ) * car;

    car = trunc(car / TEXTURE_PIXEL_SIZE) * TEXTURE_PIXEL_SIZE;

    float alpha = 1.0 - step(port_radius * 0.5, sqrt(car.x * car.x + car.y * car.y));
    COLOR.a -= alpha;

}
