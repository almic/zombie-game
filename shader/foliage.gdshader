shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

global uniform float world_time;
global uniform vec2 world_wind;

uniform bool back_face;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_roughness : hint_roughness_r, filter_nearest_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;

void vertex() {
    float t = TAU * world_time / 3600.0;
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 scaled_world_pos = world_pos / vec3(3.0, 7.0, 3.0);

    vec2 wind = (
            inverse(MODEL_MATRIX)
            * vec4(world_wind.x + NODE_POSITION_WORLD.x, 0.0, world_wind.y + NODE_POSITION_WORLD.z, 1.0)
    ).xz;
    vec2 so = sign(wind) * (scaled_world_pos.xz + scaled_world_pos.y);
    vec2 o = sign(wind) * (world_pos.xz + scaled_world_pos.y);

    VERTEX.xz += (
              (cos(t * 489.0 - (sign(wind) * (world_pos.xz / 20.0))) / 2.0 + 0.25) * 0.5
            + sqrt(cos(t * 1171.0 - so) / 2.0 + 0.5)
            + pow(cos(t * 3169.0 - so) / 2.0 + 0.5, vec2(2)) * 0.3
            + (cos(t * 5227.0 - o) / 2.0 + 0.5) * 0.09
    ) * wind;

    float y_offset = dot(world_pos.xz, wind);
    VERTEX.y += (
                cos(t * 1811.0 - scaled_world_pos.y - y_offset)
                + cos(t * 2633.0 - world_pos.y / 2.0 - y_offset) * 0.2
            ) * length(wind) * 0.3;

    UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
    if (back_face == FRONT_FACING) {
        discard;
    }

    vec2 base_uv = UV;

    vec4 albedo_tex = texture(texture_albedo, base_uv);
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    SPECULAR = specular;

    vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
    float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
    ROUGHNESS = roughness_tex * roughness;
    ALPHA *= albedo.a * albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}

void light()
{
    // Much of this code is purely copied from Godot 4.4's shader:
    // https://github.com/godotengine/godot/blob/4.4/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl

    const float A = 0.0001;

    // Clamp to -0.1 - 1.0 so some light always passes through leaves
    vec3 l_normal = normalize(mix(vec3(0.0, 1.0, 0.0), NORMAL, 0.5));
    float NdotL = clamp(A + dot(l_normal, LIGHT), -0.1, 1.0);

    if (METALLIC < 1.0) {
        float diffuse_brdf_NL; // BRDF times N.L for calculating diffuse radiance

        // Lambert Wrap
        {
            float op_roughness = 1.0 + ROUGHNESS;
            diffuse_brdf_NL = max(0.0, (NdotL + ROUGHNESS) / (op_roughness * op_roughness)) / PI;
        }

        DIFFUSE_LIGHT += LIGHT_COLOR * diffuse_brdf_NL * ATTENUATION;
        DIFFUSE_LIGHT += LIGHT_COLOR * (vec3(1.0 / PI) - diffuse_brdf_NL) * BACKLIGHT * ATTENUATION;
    }

    if (ROUGHNESS > 0.0) {
        vec3 R = normalize(-reflect(LIGHT, l_normal));
        float RdotV = dot(R, VIEW);
        float mid = 1.0 - ROUGHNESS;
        mid *= mid;
        float intensity = smoothstep(mid - ROUGHNESS * 0.5, mid + ROUGHNESS * 0.5, RdotV) * mid;
        DIFFUSE_LIGHT += LIGHT_COLOR * intensity * ATTENUATION * SPECULAR_AMOUNT;
    }
}
