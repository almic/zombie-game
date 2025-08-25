shader_type spatial;

#define ENABLED 1

#if ENABLED == 1

render_mode ambient_light_disabled;


global uniform samplerCube radiance_cubemap;
global uniform float max_roughness_layers;
global uniform float ibl_exposure_normalization;


uniform sampler2D ambient_texture: hint_roughness_gray, filter_linear;


#include "light_diffuse_specular.gdshaderinc"


void light() 
{
    if (LIGHT_IS_DIRECTIONAL && length(DIFFUSE_LIGHT) < 1e-6)
    {
        vec3 ambient_dir = (inverse(mat3(1.0)) * mat3(INV_VIEW_MATRIX)) * NORMAL;
        vec3 cubemap_ambient = textureLod(radiance_cubemap, ambient_dir, max_roughness_layers).rgb;
        cubemap_ambient *= ibl_exposure_normalization;
        cubemap_ambient *= texture(ambient_texture, UV).r;
        
        DIFFUSE_LIGHT += cubemap_ambient;
    }

    compute_light(
        DIFFUSE_LIGHT,
        SPECULAR_LIGHT,
        NORMAL,
        LIGHT,
        VIEW,
        ATTENUATION,
        ROUGHNESS,
        METALLIC,
        SPECULAR_AMOUNT,
        LIGHT_COLOR,
        BACKLIGHT,
        ALBEDO
    );
    
}
#endif