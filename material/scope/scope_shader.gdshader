shader_type spatial;

render_mode unshaded;

uniform sampler2D viewport: source_color, filter_linear;

uniform sampler2D reticle: source_color, filter_linear;
uniform vec2 reticle_offset;


vec2 fisheye(vec2 uv)
{
    // Since middle will always be (0.5, 0.5), we can inline some values
    const float bind = 0.7071067811865476; // sqrt(dot(m, m))
    const vec2 m = vec2(0.5);
    const float power = (TAU / (2.0 * bind))
                      * 0.26; // amount of effect

    vec2 d = uv - m;//vector from center to current fragment
    float r = sqrt(dot(d, d)); // distance of pixel from center

    // Weird formula
    return m + normalize(d) * tan(r * power) * bind / tan( bind * power);
}

void fragment() {
    // Sample camera texture
    ALBEDO = texture(viewport, fisheye(UV)).rgb;

    // Sample reticle
    vec2 reticle_uv = UV + reticle_offset;
    reticle_uv = mix(fisheye(reticle_uv), reticle_uv, 0.8);


    vec4 reticle_color = texture(reticle, reticle_uv) * step(abs(dot(reticle_uv - 0.5, reticle_uv - 0.5)), 0.25);
    //reticle_color = vec4(step(abs(dot(reticle_uv - 0.5, reticle_uv - 0.5)), 0.25), 0.0, 0.0, 1.0);

    ALBEDO = reticle_color.rgb * reticle_color.a + ALBEDO * (1.0 - reticle_color.a);

    // Remove corners
    vec2 p = UV * 2.0 - 1.0;
    ALPHA = step(sqrt(p.x * p.x + p.y * p.y), 1.05);
}
