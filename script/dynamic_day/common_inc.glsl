
// This shader uses the collective work of various people, culminating in the
// shader published as part of a Master's thesis on shadertoy.com, which has
// been modified for Godot and simplified slightly by me.
// https://www.shadertoy.com/view/msXXDS


#define AEROSOL_TYPE 1


const float PI = 3.14159265358979323846;
const float INV_PI = 0.31830988618379067154;
const float INV_4PI = 0.25 * INV_PI;
const float PHASE_ISOTROPIC = INV_4PI;
const float RAYLEIGH_PHASE_SCALE = (3.0 / 16.0) * INV_PI;

// This is the direction of Mie scattering, 0.8 is a good value. -1.0 to 1.0
const float g = 0.8;
const float gg = g*g;

// These could be put into a uniform for crazy effects, but for most
// uses they stay constant.
const float EYE_ALTITUDE = 0.35;
const float EARTH_RADIUS = 6371.0;
const float ATMOSPHERE_THICKNESS = 100.0;
const float ATMOSPHERE_RADIUS = EARTH_RADIUS + ATMOSPHERE_THICKNESS;
const float EYE_DISTANCE_TO_EARTH_CENTER = EARTH_RADIUS + EYE_ALTITUDE;
const vec4 GROUND_ALBEDO = vec4(0.3);

// These are real values for sun irradiance, rayleigh scattering, and ozone
// absorption, sampled at wavelengths 630, 560, 490, 430 nanometers.
// These produce very accurate lighting results.

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

// In the source material, the author varies ozone concentrations. This value is the
// average of those values.
const float ozone_concentration = 300.0;

// Scattering/ Mie constants.

#if   AEROSOL_TYPE == 0 // Background
const float aerosol_turbidity = 0.004;
const vec4 aerosol_absorption_cross_section = vec4(4.5517e-19, 5.9269e-19, 6.9143e-19, 8.5228e-19);
const vec4 aerosol_scattering_cross_section = vec4(1.8921e-26, 1.6951e-26, 1.7436e-26, 2.1158e-26);
const float aerosol_base_density = 2.584e17;
const float aerosol_background_density = 2e6;
#elif AEROSOL_TYPE == 1 // Desert Dust
const float aerosol_turbidity = 0.000016;
const vec4 aerosol_absorption_cross_section = vec4(4.6758e-16, 4.4654e-16, 4.1989e-16, 4.1493e-16);
const vec4 aerosol_scattering_cross_section = vec4(2.9144e-16, 3.1463e-16, 3.3902e-16, 3.4298e-16);
const float aerosol_base_density = 1.8662e18;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 2.0;
#elif AEROSOL_TYPE == 2 // Maritime Clean

const float aerosol_turbidity = 0.3;
const vec4 aerosol_absorption_cross_section = vec4(2.2722e-19, 4.4168e-19, 5.4706e-19, 7.3578e-19);
const vec4 aerosol_scattering_cross_section = vec4(4.6539e-26, 2.721e-26, 4.1104e-26, 5.6249e-26);
const float aerosol_base_density = 2.0266e17;
const float aerosol_background_density = 0.0;
const float aerosol_height_scale = 2.0;

#elif AEROSOL_TYPE == 3 // Maritime Mineral
const float aerosol_turbidity = 0.06;
const vec4 aerosol_absorption_cross_section = vec4(6.9365e-19, 7.5951e-19, 8.2423e-19, 8.9101e-19);
const vec4 aerosol_scattering_cross_section = vec4(2.3699e-19, 2.2439e-19, 2.2126e-19, 2.021e-19);
const float aerosol_base_density = 2.0266e17;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 2.0;
#elif AEROSOL_TYPE == 4 // Polar Antarctic
const float aerosol_turbidity = 0.003;
const vec4 aerosol_absorption_cross_section = vec4(1.3399e-16, 1.3178e-16, 1.2909e-16, 1.3006e-16);
const vec4 aerosol_scattering_cross_section = vec4(1.5506e-19, 1.809e-19, 2.3069e-19, 2.5804e-19);
const float aerosol_base_density = 2.3864e16;
const float aerosol_background_density = 2e1;
const float aerosol_height_scale = 5.0;
#elif AEROSOL_TYPE == 5 // Polar Arctic
const float aerosol_turbidity = 0.0008;
const vec4 aerosol_absorption_cross_section = vec4(1.0364e-16, 1.0609e-16, 1.0193e-16, 1.0092e-16);
const vec4 aerosol_scattering_cross_section = vec4(2.1609e-17, 2.2759e-17, 2.5089e-17, 2.6323e-17);
const float aerosol_base_density = 2.3864e16;
const float aerosol_background_density = 2e2;
const float aerosol_height_scale = 2.0;
#elif AEROSOL_TYPE == 6 // Remote Continental
const float aerosol_turbidity = 0.0005;
const vec4 aerosol_absorption_cross_section = vec4(4.5307e-18, 5.0662e-18, 4.4877e-18, 3.7917e-18);
const vec4 aerosol_scattering_cross_section = vec4(1.8764e-18, 1.746e-18, 1.6902e-18, 1.479e-18);
const float aerosol_base_density = 6.103e18;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 0.73;
#elif AEROSOL_TYPE == 7 // Rural
const float aerosol_turbidity = 1.0;
const vec4 aerosol_absorption_cross_section = vec4(5.0393e-23, 8.0765e-23, 1.3823e-22, 2.3383e-22);
const vec4 aerosol_scattering_cross_section = vec4(2.6004e-22, 2.4844e-22, 2.8362e-22, 2.7494e-22);
const float aerosol_base_density = 8.544e18;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 0.73;
#elif AEROSOL_TYPE == 8 // Urban
const float aerosol_turbidity = 0.8;
const vec4 aerosol_absorption_cross_section = vec4(2.8722e-24, 4.6168e-24, 7.9706e-24, 1.3578e-23);
const vec4 aerosol_scattering_cross_section = vec4(1.5908e-22, 1.7711e-22, 2.0942e-22, 2.4033e-22);
const float aerosol_base_density = 1.3681e20;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 0.73;
#endif

const float aerosol_background_divided_by_base_density = aerosol_background_density / aerosol_base_density;



/*
 * Helper function to obtain the transmittance to the top of the atmosphere
 * from Buffer A.
 */
vec4 transmittance_from_lut(sampler2D lut, float cos_theta, float normalized_altitude)
{
    float u = clamp(cos_theta * 0.5 + 0.5, 0.0, 1.0);
    float v = clamp(normalized_altitude, 0.0, 1.0);
    return texture(lut, vec2(u, v));
}

/*
 * Returns the distance between ro and the first intersection with the sphere
 * or -1.0 if there is no intersection. The sphere's origin is (0,0,0).
 * -1.0 is also returned if the ray is pointing away from the sphere.
 */
float ray_sphere_intersection(vec3 ro, vec3 rd, float radius)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - radius*radius;
    if (c > 0.0 && b > 0.0) return -1.0;
    float d = b*b - c;
    if (d < 0.0) return -1.0;
    if (d > b*b) return (-b+sqrt(d));
    return (-b-sqrt(d));
}

/*
 * Rayleigh phase function.
 */
float molecular_phase_function(float cos_theta)
{
    return RAYLEIGH_PHASE_SCALE * (1.0 + cos_theta*cos_theta);
}

/*
 * Henyey-Greenstein phase function.
 */
float aerosol_phase_function(float cos_theta)
{
    float den = 1.0 + gg + 2.0 * g * cos_theta;
    return INV_4PI * (1.0 - gg) / (den * sqrt(den));
}

vec4 get_multiple_scattering(sampler2D transmittance_lut, float cos_theta, float normalized_height, float d)
{
    // Solid angle subtended by the planet from a point at d distance
    // from the planet center.
    float omega = 2.0 * PI * (1.0 - sqrt(d*d - EARTH_RADIUS*EARTH_RADIUS) / d);

    vec4 T_to_ground = transmittance_from_lut(transmittance_lut, cos_theta, 0.0);

    vec4 T_ground_to_sample =
        transmittance_from_lut(transmittance_lut, 1.0, 0.0) /
        transmittance_from_lut(transmittance_lut, 1.0, normalized_height);

    // 2nd order scattering from the ground
    vec4 L_ground = PHASE_ISOTROPIC * omega * (GROUND_ALBEDO / PI) * T_to_ground * T_ground_to_sample * cos_theta;

    // Fit of Earth's multiple scattering coming from other points in the atmosphere
    vec4 L_ms = 0.02 * vec4(0.217, 0.347, 0.594, 1.0) * (1.0 / (1.0 + 5.0 * exp(-17.92 * cos_theta)));

    return L_ms + L_ground;
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
    return ozone_absorption_cross_section * ozone_concentration * density;
}

float get_aerosol_density(float h)
{
#if AEROSOL_TYPE == 0 // Only for the Background aerosol type, no dependency on height
    return aerosol_base_density * (1.0 + aerosol_background_divided_by_base_density);
#else
    return aerosol_base_density * (exp(-h / aerosol_height_scale)
        + aerosol_background_divided_by_base_density);
#endif
}

/*
 * Get the collision coefficients (scattering and absorption) of the
 * atmospheric medium for a given point at an altitude h.
 */
void get_atmosphere_collision_coefficients(in float h,
                                           out vec4 aerosol_absorption,
                                           out vec4 aerosol_scattering,
                                           out vec4 molecular_absorption,
                                           out vec4 molecular_scattering,
                                           out vec4 extinction)
{
    h = max(h, 0.0); // In case height is negative
    float aerosol_density = get_aerosol_density(h);
    aerosol_absorption = aerosol_absorption_cross_section * aerosol_density * aerosol_turbidity;
    aerosol_scattering = aerosol_scattering_cross_section * aerosol_density * aerosol_turbidity;
    molecular_absorption = get_molecular_absorption_coefficient(h);
    molecular_scattering = get_molecular_scattering_coefficient(h);
    extinction = aerosol_absorption + aerosol_scattering + molecular_absorption + molecular_scattering;
}

//-----------------------------------------------------------------------------
// Spectral rendering stuff

const mat4x3 M = mat4x3(
    137.672389239975, -8.632904716299537, -1.7181567391931372,
    32.549094028629234, 91.29801417199785, -12.005406444382531,
    -38.91428392614275, 34.31665471469816, 29.89044807197628,
    8.572844237945445, -11.103384660054624, 117.47585277566478
);

vec3 linear_srgb_from_spectral_samples(vec4 L)
{
    return M * L;
}

