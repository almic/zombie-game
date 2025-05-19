shader_type spatial;

render_mode cull_disabled;

uniform float points = 6.0;
uniform float sharpness = 0.8;

uniform bool Emmisive = false;
uniform float Energy = 0.0;

void fragment() {
    ALBEDO *= COLOR.rgb;
    ALPHA = COLOR.a;
    
    vec2 p = vec2(UV.x - 0.5, UV.y - 0.5) * 2.0;
    
    float an = PI / points;
    float en = PI / ((points * 0.6 + 0.4) * sharpness);
    vec2 acs = vec2(cos(an), sin(an));
    vec2 ecs = vec2(cos(en), sin(en));
    
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = length(p) * vec2(cos(bn), abs(sin(bn)));
    p -= acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, acs.y / ecs.y);
    ALPHA *= smoothstep(0.0, 1.0,
        sign(p.x) < 0.0 ? length(p) * PI : 0.0
    );
    
    if (Emmisive)
    {
        EMISSION = Energy * ALBEDO;
    }
}

