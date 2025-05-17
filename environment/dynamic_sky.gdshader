shader_type sky;

// allows us to improve performance and model the multi-buffer approach
render_mode use_quarter_res_pass, use_half_res_pass, use_debanding;

// This shader uses the collective work of various people, cullminating in the
// shader published as part of a Master's thesis on shadertoy.com, which has
// been modified for Godot and simplified slightly by me.
// https://www.shadertoy.com/view/msXXDS

// The color of the light from the Sun
uniform vec3 sun_color: source_color = vec3(1.0);

// Direction of light from the sun
uniform vec3 sun_direction;

// Angular diameter of the sun in degrees
uniform float sun_angular_diameter = 0.5;

#define MAIN_STEPS 21
#define LIGHT_STEPS 7

const float INV_PI = 1.0 / PI;
const float INV_4PI = 0.25 * INV_PI;
const float RAYLEIGH_PHASE_SCALE = (3.0 / 16.0) * INV_PI;

// This is the direction of Mie scattering, 0.8 is a good value. -1.0 to 1.0
const float g = 0.8;
const float gg = g * g;

const float EARTH_RADIUS = 6371.0;
const float ATMOSPHERE_THICKNESS = 100.0;
const float ATMOSPHERE_RADIUS = EARTH_RADIUS + ATMOSPHERE_THICKNESS;

// Extraterrestial Solar Irradiance Spectra, units W * m^-2 * nm^-1
// https://www.nrel.gov/grid/solar-resource/spectra.html
const vec4 sun_spectral_irradiance = vec4(1.679, 1.828, 1.986, 1.307);
// Rayleigh scattering coefficient at sea level, units km^-1
// "Rayleigh-scattering calculations for the terrestrial atmosphere"
// by Anthony Bucholtz (1995).
const vec4 molecular_scattering_coefficient_base = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);
// Ozone absorption cross section, units m^2 / molecules
// "High spectral resolution ozone absorption cross-sections"
// by V. Gorshelev et al. (2014).
const vec4 ozone_absorption_cross_section = vec4(3.472e-21, 3.914e-21, 1.349e-21, 11.03e-23) * 1e-4f;
const float ozone_absorption = 337.0;

// Mie constants. This are the "Urban" values. Play with turbidity if you change
// them, only Urban works with 1.0, the rest need MUCH lower values (like 0.001 low)
const float aerosol_turbidity = 1.0;
const vec4 aerosol_absorption_cross_section = vec4(2.8722e-24, 4.6168e-24, 7.9706e-24, 1.3578e-23);
const vec4 aerosol_scattering_cross_section = vec4(1.5908e-22, 1.7711e-22, 2.0942e-22, 2.4033e-22);
const float aerosol_base_density = 1.3681e20;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 0.73;

const float aerosol_background_divided_by_base_density = aerosol_background_density / aerosol_base_density;


/*
 * Returns the distance between ro and the first intersection with the sphere
 * or -1.0 if there is no intersection. The sphere's origin is (0,0,0).
 * -1.0 is also returned if the ray is pointing away from the sphere.
 */
float ray_sphere_intersection(vec3 ro, vec3 rd, float radius)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - radius * radius;
    if (c > 0.0 && b > 0.0) return -1.0;
    float d = b * b - c;
    if (d < 0.0) return -1.0;
    if (d > b * b) return (-b + sqrt(d));
    return (-b - sqrt(d));
}

// Rayleigh scattering
float molecular_phase_function(float cos_theta)
{
    return RAYLEIGH_PHASE_SCALE * (1.0 + cos_theta * cos_theta);
}

// Mie scattering
float aerosol_phase_function(float cos_theta)
{
    float den = 1.0 + gg + 2.0 * g * cos_theta;
    return INV_4PI * (1.0 - gg) / (den * sqrt(den));
}

/*
 * Return the molecular volume scattering coefficient (km^-1) for a given altitude
 * in kilometers.
 */
vec4 get_molecular_scattering_coefficient(float h)
{
    return molecular_scattering_coefficient_base * exp(-0.07771971 * pow(h, 1.16364243));
}

/*
 * Return the molecular volume absorption coefficient (km^-1) for a given altitude
 * in kilometers.
 */
vec4 get_molecular_absorption_coefficient(float h)
{
    h += 1e-4; // Avoid division by 0
    float t = log(h) - 3.22261;
    float density = 3.78547397e20 * (1.0 / h) * exp(-t * t * 5.55555555);
    return ozone_absorption_cross_section * ozone_absorption * density;
}

void sky() {
    // First, place the disks
    float sun_radius = sun_angular_diameter * 0.5 * (PI / 180.0);
    if (acos(dot(EYEDIR, sun_direction)) <= sun_radius)
    {
        COLOR = sun_color;
    }
    // TODO: moon texture here
    else
    {
        //COLOR = EYEDIR;
    }
    
    // Buffer A stage
    if (AT_QUARTER_RES_PASS)
    {
        float sun_cos_theta = SCREEN_UV.x * 2.0 - 1.0;
        vec3 sun_dir = vec3(-sqrt(1.0 - sun_cos_theta * sun_cos_theta), 0.0, sun_cos_theta);
        
        float dist_to_earth_center = mix(EARTH_RADIUS, ATMOSPHERE_RADIUS, SCREEN_UV.y);
        vec3 ray_origin = vec3(0.0, 0.0, dist_to_earth_center);
        
        float t_d = ray_sphere_intersection(ray_origin, sun_dir, ATMOSPHERE_RADIUS);
        float dt = t_d / float(MAIN_STEPS);
        
        vec4 result = vec4(0.0);
        
        for (int i = 0; i < MAIN_STEPS; ++i)
        {
            float t = (float(i) + 0.5) * dt;
            vec3 x_t = ray_origin + sun_dir * t;
            
            float altitude = max(length(x_t) - EARTH_RADIUS, 0.0);
            
            float aerosol_density = aerosol_base_density * (
                    exp(-altitude / aerosol_height_scale)
                    + aerosol_background_divided_by_base_density
            );
            
            vec4 aerosol_aborption =
                    aerosol_absorption_cross_section * aerosol_density * aerosol_turbidity
            , aerosol_scattering =
                    aerosol_scattering_cross_section * aerosol_density * aerosol_turbidity
            
            , molecular_absorption = get_molecular_absorption_coefficient(altitude)
            , molecular_scattering = get_molecular_scattering_coefficient(altitude)
            ;

            vec4 extinction = aerosol_aborption + aerosol_scattering + molecular_absorption + molecular_scattering;
            
            result += extinction * dt;
        }
        
        result = exp(-result);
        COLOR = result.rgb;
        ALPHA = result.a;
    }
    else if (AT_HALF_RES_PASS)
    {
        COLOR = QUARTER_RES_COLOR.rgb;
        ALPHA = QUARTER_RES_COLOR.a;
    }
    else
    {
        COLOR = HALF_RES_COLOR.rgb;
    }
    
}
