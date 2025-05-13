shader_type spatial;

render_mode cull_disabled;

uniform bool Emmisive = false;
uniform float Energy = 0.0;

void fragment() {
    ALBEDO *= COLOR.rgb;
    ALPHA = COLOR.a;
    
    ALPHA *= smoothstep(
        0.0, 1.0,
        2.0 * (0.5 - sqrt(pow(UV.x - 0.5, 2.0) + pow(UV.y - 0.5, 2.0)))
    );
    
    if (Emmisive)
    {
        EMISSION = Energy * ALBEDO;
    }
}
