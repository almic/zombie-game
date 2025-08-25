vec3 F0(float metallic, float specular, vec3 albedo) {
    float dielectric = 0.04 * specular * specular;
    return mix(vec3(dielectric), albedo, vec3(metallic));
}

float D_GGX(float cos_theta_m, float alpha) {
    float a = cos_theta_m * alpha;
    float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
    return k * k * (1.0 / PI);
}

float V_GGX(float NdotL, float NdotV, float alpha) {
    return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

float SchlickFresnel(float u) {
    float m = 1.0 - u;
    float m2 = m * m;
    return m2 * m2 * m; // pow(m,5)
}

void compute_light(
        inout vec3 diffuse_light,
        inout vec3 specular_light,
        vec3 N,
        vec3 L,
        vec3 V,
        float attenuation,
        float roughness,
        float metallic,
        float specular_amount,
        vec3 light_color,
        vec3 backlight,
        vec3 albedo,
)
{

    // Much of this code is purely copied from Godot 4.4's shader:
    // https://github.com/godotengine/godot/blob/4.4/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl

    const float specular = 0.5;

    vec3 f0 = F0(metallic, specular, albedo);

    const float A = 0.0001;

    float NdotL = min(A + dot(N, L), 1.0);
    float cNdotV = max(dot(N, V), 1e-4);
    float cNdotL = max(NdotL, 0.0);

    vec3 H = normalize(V + L);
    float cLdotH = clamp(A + dot(L, H), 0.0, 1.0);

    if (metallic < 1.0) {
        float diffuse_brdf_NL; // BRDF times N.L for calculating diffuse radiance

        {
            float FD90_minus_1 = 2.0 * cLdotH * cLdotH * roughness - 0.5;
            float FdV = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotV);
            float FdL = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotL);
            diffuse_brdf_NL = (1.0 / PI) * FdV * FdL * cNdotL;
        }

        diffuse_light += light_color * diffuse_brdf_NL * attenuation;
        diffuse_light += light_color * (vec3(1.0 / PI) - diffuse_brdf_NL) * backlight * attenuation;
    }

    if (roughness > 0.0) {
        float cNdotH = clamp(A + dot(N, H), 0.0, 1.0);

        float alpha_ggx = roughness * roughness;

        float D = D_GGX(cNdotH, alpha_ggx);
        float G = V_GGX(cNdotL, cNdotV, alpha_ggx);

        float cLdotH5 = SchlickFresnel(cLdotH);

        // Calculate Fresnel using cheap approximate specular occlusion term from Filament:
        // https://google.github.io/filament/Filament.html#lighting/occlusion/specularocclusion
        float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), metallic, 1.0);
        vec3 F = f0 + (f90 - f0) * cLdotH5;
        vec3 specular_brdf_NL = cNdotL * D * F * G;
        specular_light += specular_brdf_NL * light_color * attenuation * specular_amount;
    }

}