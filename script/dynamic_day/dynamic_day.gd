@tool
class_name DynamicDay extends WorldEnvironment


@export var Sun: DirectionalLight3D
@export var Moon: DirectionalLight3D


## Initial time of day for the viewer, where 0.25 is morning, 0.5 is midday,
## and 1.0 & 0.0 are midnight. This value is not updated during gameplay. Use
## either 'clock_time' or 'local_hour' to obtain a value synchronized to the
## position of the Sun.
@export_range(0.0, 1.0, 0.00001)
var initial_time: float = 0.345

## Readout of local time to 24hr clock time, modifying this does nothing.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var clock_time: String = '00:00:00'

## If time passage happens in-game
@export var time_enabled: bool = true

## Rate of time passage, relative to real time.
@export_range(1.0, 200.0, 0.001, 'or_greater')
var time_scale: float = 100


@export_group("Editor-Only Options")

## Enable this to play the local time value in the editor.
@export var editor_realtime: bool = false

## Click this to reset local time changes resulting from editor real-time changes.
@export var reset_realtime: bool = false:
    set(value):
        reset_realtime = false
        planet_orbit = 0
        planet_rotation = 0
        moon_rotation = 0
        moon_orbit = 0
        local_hour = initial_time
        apply_time_changes()

## Reload sky shaders (broken?)
@export var reload_shaders: bool = false:
    set(value):
        reload_shaders = false
        if not value:
            return
        if not sky_compute:
            return
        sky_compute.reload_shaders()


@export_category("Viewer Attributes")

## The direction of north, with zero being aligned with the negative Z axis.
## This is a "rise east, set west" model, so sunrise would happen at positive X,
## and sunset would happen at negative X, with everything being default.
@export_range(-180.0, 180.0, 0.0001, 'radians_as_degrees')
var north: float = 0.0

## Latitude of the viewer, affects how high the sun rises at noon, and to an
## extent, the time of sunrise and sunset. Together with planet tilt and orbital
## phase, the Sun may stay above (or below) the horizon for much longer than
## the length of a day.
@export_range(-90.0, 90.0, 0.0001, 'radians_as_degrees')
var latitude: float = 0.0

## Longitude of the viewer, affects the local hour of the viewer. This could be
## changed slowly to simulate the effect of traveling large distances on the
## planet, extending or shortening the percieved length of a day, at least
## temporarily. You should leave this at zero and only change it during gameplay.
@export_range(-180.0, 180.0, 0.0001, 'radians_as_degrees')
var longitude: float = 0.0:
    set(value):
        longitude_dirty = not is_equal(longitude, value)
        longitude = value


@export_category("Planet Attributes")

## Hours in a day, or how long it takes for the planet to complete a full 360
## degree rotation, if time scale was 1.0. This is known as the Sidereal Day.
## This is different from a Solar Day, which is typically longer due to the
## orbit of the planet around the host star.
## Earth's sidereal day is approximately 23 hours and 56 minutes.
@export_range(1.0, 100.0, 0.0001, 'or_greater')
var day_length: float = 23.9345:
    set(value):
        day_length = value
        update_periods()

## Planet orbital period, in sidereal days. This is the sidereal year, the time
## it takes for the planet to return to the same position in its orbit.
## Earth's sidereal year is approximately 365 siderial days + 6 hours.
@export_range(0.00001, 1000.0, 0.00001, 'or_greater')
var year_length: float = 365.25636:
    set(value):
        year_length = value
        update_periods()


@export_group("Orbital Parameters", "planet")

## Planet axial tilt relative to its orbital plane. This is applied in the
## direction of the host star, and defines the maximum elevation of the star at
## the north pole during the summer soltice.
## Earth's tilt is about 23.44 degrees.
@export_range(-180.0, 180.0, 0.0001, 'radians_as_degrees')
var planet_tilt: float = deg_to_rad(23.44)

## Planet tilt phase, in N-pi radians. This is a friendly parameter to set the
## initial time of year by rotating the axis of tilt. Leaving at 0.0 makes the
## simulation start at the Summer soltice (for the northern hemisphere), setting
## to 1.0 makes it the Winter soltice, with the usual seasons in between.
@export_range(0.0, 2.0, 0.0001)
var planet_tilt_phase: float = 0.0


@export_category("Sun Attributes")

## Angular diameter of the sun, in degrees
@export_range(0.0, 3.0, 0.0001, 'or_greater')
var sun_angular_diameter: float = 0.542:
    set(value):
        sun_angular_diameter = value
        _sun_radians = deg_to_rad(sun_angular_diameter) * 0.5
var _sun_radians: float

## Minimum Sun illuminance when fully eclipsed by the Moon. This influences the
## amount of scattered light in the sky, and the energy of the Sun light.
## Currently, eclipses are partially supported by the shader, glow is unaffected
## by elipses.
@export_range(0.0, 1.0, 0.0001)
var eclipse_min: float = 0.03


@export_category("Moon Attributes")

## If the set angular diameter should be replaced with the computed angular
## diameter from the render model camera. This should be enabled if you plan to
## significantly change the apparant distance to the moon.
@export var use_moon_render_angle: bool = true:
    set(value):
        use_moon_render_angle = value
        if moon_camera:
            if value:
                moon_view.orthographic_mode = false
                _moon_radians = deg_to_rad(moon_camera.fov) * 0.5
            else:
                moon_view.orthographic_mode = true
                # Reset to slider value
                moon_angular_diameter = moon_angular_diameter

## Angular diameter of the moon, in degrees
@export_range(0.0, 3.0, 0.0001, 'or_greater')
var moon_angular_diameter: float = 0.568:
    set(value):
        moon_angular_diameter = value
        if not use_moon_render_angle:
            _moon_radians = deg_to_rad(moon_angular_diameter) * 0.5
var _moon_radians: float

## Length of a day on the moon. For the Moon, and most natural satellites, this
## is equal to it's orbital period. The Moon's synodic ("day") period is about
## 720.73 hours, the same as its orbital period.
@export_range(0.0, 2400.0, 0.0001, 'or_greater')
var moon_day_length: float = 720.73:
    set(value):
        moon_day_length = value
        update_periods()

## The time taken to orbit around the Earth. The Moon takes about 720.73 hours,
## which is the same as its rotational period (a lunar day).
@export_range(0.0, 2400.0, 0.0001, 'or_greater')
var moon_orbital_period: float = 720.73:
    set(value):
        moon_orbital_period = value
        update_periods()

## Apparent distance to the moon from the viewer, in kilometers. Only effective
## when "Use Moon Render Angle" is enabled and the moon view scene supports it.
## This effect breaks when the distance is too low for low resolution textures.
## So if you plan to smash the moon into the planet, plan accordingly.
@export_range(100.0, 500000.0, 0.01, 'or_greater')
var moon_distance: float = 384400:
    set(value):
        moon_distance = value
        if moon_view:
            moon_view.moon_distance = moon_distance


@export_group("Orbital Parameters", "moon")

## The inclination of the moon's orbit to the ecliptic plane. This is applied
## as if looking in-line with the orbital plane, with the main planet between
## the host star and the moon.
##
## Simple diagram for reference: O  --P-- m
##
## This affects the orbital motion, in prograde for values 0-90, and retrograde
## from 90-180. See "Inclination Phase" to spin the orbital nodes.
## The Moon's inclination is about 5.145 degrees.
@export_range(0.0, 180.0, 0.00001, 'radians_as_degrees')
var moon_inclination: float = deg_to_rad(5.145)

## Moon axial tilt from its orbital plane. The Moon's tilt is about 6.688 degrees.
@export_range(0.0, 180.0, 0.00001, 'radians_as_degrees')
var moon_tilt: float = deg_to_rad(6.688)

## Spin of the moon's inclination, in N-pi radians. The Moon's orbit precesses,
## relative to Earth's equator, with a period of 18.3 years. However, due to the
## orbit of the Earth around the Sun, the orbital nodes align with the Sun about
## every 173.3 days, resulting in Lunar and Solar eclipses. To create eclipses,
## modify this phase to be near 0.5 or 1.5. See "Tilt Phase" and offset it by 1.0
## to remain physically accurate.
@export_range(0.0, 2.0, 0.00001)
var moon_inclination_phase: float = 0.0

## Spin of the moon's tilt, in N-pi radians. The Moon's tilt is perfectly out
## of phase with the orbit (1.0), so it stays at a tilt of 1.543 to the ecliptic
## plane at all times. To have the tilt change orientation, modify this phase.
@export_range(0.0, 2.0, 0.00001)
var moon_tilt_phase: float = 1.0


@export_group("Orbit & Time Offsets", "moon")

## Offset applied to the Moon's orbit, use this to progress the moon through
## its orbit. For convenience, time progress adds this value so the initial
## offset is relative to line between the observer and moon.
@export_range(-0.5, 0.5, 0.00001)
var moon_orbit_offset: float = 0.0

## Offset applied to the Moon's local time, use this to change the local time on
## the Moon. Even for custom moon configurations, you should leave this at zero.
@export_range(0.0, 1.0, 0.00001)
var moon_time_offset: float = 0.0


@export_group("Moon Renderer", "moon")

## SubViewport scene that contains a mesh uniquely named "Moon" so that it can
## be rotated accordingly.
@export var moon_renderer: PackedScene


## Quantity of day progress per simulation second
var inv_day_length: float = 0.0

## Quantity of year progress per simulation second
var inv_year_length: float = 0.0

## Quantity of day progress on the moon per simulation second
var inv_moon_day_length: float = 0.0

## Quantity of orbital progress for the moon per simulation second
var inv_moon_orbit_length: float = 0.0


## Local hour of the observer, equivalent to the position of the Sun in the sky.
## 1.0 & 0.0 are 00:00, 0.25 is 06:00, 0.5 is 12:00, and 0.75 is 18:00. Setting
## this value in-game while 'time_enabled' is true will progress time forward to
## the given hour, so not to break the consistency of any simulation parameters.
## Otherwise, the planet is effectively rotated instantly to the given value.
## Because of latitude, planet tilt, and time of year, this cannot be used to
## progress the sun to a particular elevation in the sky. Another function will
## be written to query the approximate time of day for a normalized altitude,
## making it possible to set the time precisely in relation to the Sun, such as
## setting the time to exactly 1 hour before sunrise.
var local_hour: float:
    set = set_local_hour, get = get_local_hour


## Internal progress values for planet and moon.
## The working value is the first in each pair, and the true value is after.
## This enables time updates in-editor to match the in-game initial conditions,
## without deviations building up in-editor that displace the sky.
var _time_data: PackedFloat64Array = [
        0.0, 0.0, # planet_rotation
        0.0, 0.0, # planet_orbit
        0.0, 0.0, # moon_rotation
        0.0, 0.0, # moon_orbit
]

## Planet rotation, not to be confused with the local time.
var planet_rotation: float:
    set(value):   _time_data[0] = value
    get(): return _time_data[1]

## Planet orbital progress
var planet_orbit: float:
    set(value):   _time_data[2] = value
    get(): return _time_data[3]

## Moon rotation, not to be confused with the moon's local time.
var moon_rotation: float:
    set(value):   _time_data[4] = value
    get(): return _time_data[5]

## Moon orbital progress
var moon_orbit: float:
    set(value):   _time_data[6] = value
    get(): return _time_data[7]

## If the longitude has changed, and thus the sky must be updated
var longitude_dirty: bool = false

var sky: Sky = Sky.new()
var sky_material: ShaderMaterial = ShaderMaterial.new()
var sky_shader: Shader = preload('res://script/dynamic_day/dynamic_day.gdshader')
var sky_compute: PhysicalSkyCompute

var planet_basis: Basis
var viewer_basis: Basis
var planet_viewer_basis: Basis

var moon_view: MoonView
var moon_phase_cos_theta: float
var moon_mesh: MeshInstance3D
var moon_camera: Camera3D
var moon_view_shader: ShaderMaterial
var moon_orbit_basis: Basis
var moon_light_energy: Interpolation = Interpolation.new(30.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


## Sun light color interpolation, changes as the sun moves through the sky
var sun_light_color: Interpolation = Interpolation.new(0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)

## Look-Up-Table for sky transmittance, used to compute Sun color
var lut_texture: Image


var initialize_ticks: int = 15

func _init() -> void:
    # force cached calculations
    moon_angular_diameter = moon_angular_diameter
    sun_angular_diameter = sun_angular_diameter

    update_periods()

    moon_light_energy.current = 0.0

func _notification(what:int) -> void:
    # NOTE: Prevent shader parameters from saving to disk.
    match what:
        NOTIFICATION_EDITOR_PRE_SAVE:
            environment.sky = null
        NOTIFICATION_EDITOR_POST_SAVE:
            environment.sky = sky

func _ready() -> void:
    init_shader()

func _process(delta: float) -> void:
    # NOTE: Editor preview runs in _process()
    if not Engine.is_editor_hint():
        return

    if editor_realtime:
        update_time(delta * time_scale, false)
    else:
        update_clock_time()

    update_sky(delta, true)

    tick_sky_lights(delta)

func _physics_process(delta: float) -> void:
    # NOTE: Application runs in _physics_process()
    if Engine.is_editor_hint():
        return

    if time_enabled:
        update_time(delta * time_scale)

    if initialize_ticks > 0:
        initialize_ticks -= 1
        update_sky(delta, true)
    else:
        update_sky(delta)

    tick_sky_lights(delta)

func update_periods() -> void:
    var seconds_per_day = day_length * 3600

    inv_day_length = 1.0 / seconds_per_day
    inv_year_length = 1.0 / (year_length * seconds_per_day)

    inv_moon_day_length = 1.0 / (moon_day_length * 3600)
    inv_moon_orbit_length = 1.0 / (moon_orbital_period * 3600)

func get_local_hour() -> float:
    return fposmod(planet_rotation + initial_time - planet_orbit - (longitude / TAU), 1.0)

func set_local_hour(hour: float) -> void:
    if Engine.is_editor_hint() or not time_enabled:
        # Simply teleport to the rotation needed for this time
        planet_rotation = fposmod(planet_rotation + (hour - get_local_hour()), 1.0)
        return

    # "Fast-forward" to the next occurance of this hour
    var seconds_to_target: float = fposmod(hour - get_local_hour(), 1.0)
    seconds_to_target *= day_length * 3600

    update_time(seconds_to_target)

func update_time(delta: float, do_orbit: bool = true) -> void:
    planet_rotation = fposmod(planet_rotation + (delta * inv_day_length), 1.0)

    if do_orbit:
        moon_rotation = fposmod(moon_rotation + (delta * inv_moon_day_length), 1.0)
        planet_orbit = fposmod(planet_orbit + (delta * inv_year_length), 1.0)
        moon_orbit = fposmod(moon_orbit + (delta * inv_moon_orbit_length), 1.0)

    update_clock_time()

func update_clock_time() -> void:
    var hour: float = local_hour * 24.0
    var minute: float = (hour - int(hour)) * 60.0
    var second: float = (minute - int(minute)) * 60.0

    clock_time = "%02d:%02d:%02d" % [hour, minute, second]

    # HACK: this should not be done like this
    get_tree().call_group('hud', 'update_time', clock_time)


static func is_equal(a: float, b: float, e: float = 0.00000000001) -> bool:
    return abs(a - b) < e

func time_changed() -> bool:
    return (
           longitude_dirty
        or not is_equal(_time_data[0], _time_data[1])
        or not is_equal(_time_data[2], _time_data[3])
        or not is_equal(_time_data[4], _time_data[5])
        or not is_equal(_time_data[6], _time_data[7])
    )

func apply_time_changes() -> void:
    # Move the working value to the true value
    _time_data[1] = _time_data[0]
    _time_data[3] = _time_data[2]
    _time_data[5] = _time_data[4]
    _time_data[7] = _time_data[6]

func update_sky(_delta: float, force: bool = false) -> void:
    var sky_changed: bool = time_changed()

    if force or sky_changed:
        update_planet_viewer()
        update_sun()
        update_moon()
    else:
        return

    # Cache true values for shader
    var sun_true: Vector3 = Sun.basis.z
    var moon_true: Basis = Moon.basis

    moon_phase_cos_theta = moon_true.z.dot(-sun_true)

    # Add refraction to apparant elevation of sky lights
    for light in [Sun, Moon] as Array[DirectionalLight3D]:
        var refraction_axis: Vector3 = light.basis.z.cross(Vector3.UP)
        if not refraction_axis.is_zero_approx():
            refraction_axis = refraction_axis.normalized()
            var refraction: float = compute_refraction(light.basis.z.y)
            # TODO: I'm too tired to figure out how to compute the proper vector
            #       so fuck it I'm just checking if the rotation made it point
            #       more up and if not I do the opposite
            if light.basis.z.rotated(refraction_axis, refraction).y < light.basis.z.y:
                refraction = -refraction
            light.rotate(refraction_axis, refraction)

    update_shader(
        sun_true,
        Sun.basis.z,
        moon_true,
        Moon.basis
    )

    apply_time_changes()

    # Sun light energy calculation
    Sun.light_energy = (
              sky_compute.moon_shadowing
            * light_horizon(Sun.basis.z, _sun_radians)
            # NOTE: better effect, make color more important to energy
            * sqrt(Sun.light_color.srgb_to_linear().get_luminance())
    )

    # Disable sun light when energy is too low
    Sun.visible = Sun.light_energy > 0.000001

    # Enable moon when fully above horizon
    Moon.visible = Moon.basis.z.y > 0.00275

    # Brightness of the Sun to enable Moon shadows, in LUX
    const sun_low_light_level = 1000

    if not Moon.visible:
        Moon.shadow_enabled = false
    else:
        if Sun.light_energy * Sun.light_intensity_lux < sun_low_light_level:
            if not Moon.shadow_enabled:
                Moon.shadow_enabled = true
                moon_light_energy.set_target_delta(1.0, 1.0, 0.0)
        elif not moon_light_energy.is_target_set or not is_zero_approx(moon_light_energy.target):
            Moon.shadow_enabled = false
            moon_light_energy.set_target_delta(0.0, -moon_light_energy.current)

    # BUG: Godot only updates textures in-game, wack
    if not Engine.is_editor_hint():
        # NOTE: Sun light color can change abruptly, and it's relatively cheap
        #       to check, so check constantly and update the target
        if sky_changed or force:
            #var time: int = Time.get_ticks_usec()
            var target: Color = compute_sun_color()
            #time = Time.get_ticks_usec() - time
            #print('Sun color time: ' + str(time) + 'us')

            # If this is our first set, apply the color immediately
            if not sun_light_color.is_target_set or not target.is_equal_approx(sun_light_color.current):
                if not sun_light_color.is_target_set:
                    sun_light_color.current = target
                sun_light_color.set_target_delta(target, target - sun_light_color.current)


func tick_sky_lights(delta: float) -> void:
    if Moon.visible:
        var sin_half_theta: float = sqrt((1.0 - moon_phase_cos_theta) / 2.0)
        Moon.light_energy = max(
            1.35 - 5.738 * sin_half_theta,
            pow(1.0 - sin_half_theta, 2.0)
        )
        if moon_light_energy.is_target_set and not moon_light_energy.is_done:
            # Moon light energy calculation
            # NOTE: the Moon is far brighter when at opposition with the Sun, so
            #       squaring the phase angle produces such an effect.
            Moon.light_energy *= moon_light_energy.update(delta)

    if not sun_light_color.is_done:
        Sun.light_color = sun_light_color.update(delta)

## Compute viewer + planet orientation
func update_planet_viewer() -> void:
    planet_basis = Basis.IDENTITY
    viewer_basis = Basis.IDENTITY

    var tilt_axis: Vector3 = planet_basis.x.rotated(planet_basis.y, planet_tilt_phase * PI)

    # Orbit effectively acts as a clockwise rotation
    planet_basis = planet_basis.rotated(planet_basis.y, -planet_orbit * TAU)

    # Tilt
    planet_basis = planet_basis.rotated(tilt_axis, planet_tilt)

    # Rotate counter-clockwise on axis
    planet_basis = planet_basis.rotated(planet_basis.y, (planet_rotation + initial_time - 0.5) * TAU)

    # Put viewer on planet
    viewer_basis = viewer_basis.rotated(viewer_basis.x, PI / 2)

    # Apply latitude and longitude rotations on the viewer.
    var longitude_axis: Vector3 = viewer_basis.z
    viewer_basis = viewer_basis.rotated(viewer_basis.x, -latitude)
    viewer_basis = viewer_basis.rotated(longitude_axis, longitude)

    # Apply north offset
    viewer_basis = viewer_basis.rotated(viewer_basis.y, north)

    planet_viewer_basis = (planet_basis * viewer_basis)

## Compute sun orientation
func update_sun() -> void:
    if not Sun:
        return

    # Sun is very simple, just the inverse of our planet viewer
    Sun.basis = planet_viewer_basis.inverse()

## Compute moon orientation
func update_moon() -> void:
    if not Moon:
        return

    # Moon is pretty simple, orbital goes on the light, local on the mesh
    Moon.basis = Basis.IDENTITY

    # Inclination
    Moon.basis = Moon.basis.rotated(
            Moon.basis.x.rotated(Moon.basis.y, moon_inclination_phase * PI),
            moon_inclination
    )

    # Orbit
    Moon.basis = Moon.basis.rotated(Moon.basis.y, (moon_orbit + moon_orbit_offset + 0.5) * TAU)

    # Stash for moon renderer
    moon_orbit_basis = Moon.basis

    # Apply planet+viewer perspective
    Moon.basis = planet_viewer_basis.inverse() * Moon.basis

    # Local rotations
    if not moon_mesh:
        return

    moon_mesh.basis = Basis.IDENTITY

    # Spin the tilt axis. Because we don't want this to spin the model, we use
    # a separate vector to spin
    var tilt_axis: Vector3 = Vector3.RIGHT
    tilt_axis = tilt_axis.rotated(Vector3.UP, moon_tilt_phase * PI)
    # Tilt towards the reference
    moon_mesh.basis = moon_mesh.basis.rotated(tilt_axis, -moon_tilt)

    # Spin is prograde with the planet, though tilt can be used to invert
    # the spin to appear retrograde. Add orbital offset as well, keeping the
    # body facing in the same direction after orbital perspective
    var orbit_rotation: float = 0.5 + moon_orbit_offset * moon_orbital_period / moon_day_length
    moon_mesh.basis = moon_mesh.basis.rotated(moon_mesh.basis.y, (moon_time_offset + moon_rotation + orbit_rotation) * TAU)

func init_shader() -> void:
    sky_shader.resource_local_to_scene = true

    sky_material.shader = sky_shader
    sky_material.resource_local_to_scene = true

    sky.sky_material = sky_material
    sky.process_mode = Sky.PROCESS_MODE_REALTIME
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    sky.resource_local_to_scene = true

    environment.sky = sky

    if not sky_compute:
        for effect in compositor.compositor_effects:
            if effect is PhysicalSkyCompute:
                sky_compute = effect
                break

    if Sun:
        sky_compute.sun_direction = -Sun.basis.z

    if Moon:
        sky_compute.moon_direction = -Moon.basis.z

    if not moon_view:
        moon_view = moon_renderer.instantiate()
        add_child(moon_view) # Required to start viewport rendering
        moon_view.moon_distance = moon_distance
        moon_mesh = moon_view.get_node('%Moon')
        moon_camera = moon_view.get_node('%Camera3D')
        moon_view_shader = moon_mesh.mesh.surface_get_material(0)

    # Force cached angle calculation
    use_moon_render_angle = use_moon_render_angle

func update_shader(
    sun_true: Vector3,
    sun_apparent: Vector3,
    moon_true: Basis,
    moon_apparent: Basis
) -> void:
    # Fix Godot unloading resources and not putting them back >:(
    if not environment.sky:
        environment.sky = sky

    sky_material.set_shader_parameter("sun_direction", sun_apparent)
    moon_view_shader.set_shader_parameter("sun_direction", sun_true)
    sky_compute.sun_direction = -sun_apparent

    sky_material.set_shader_parameter("moon_basis", moon_apparent)
    moon_view_shader.set_shader_parameter("moon_orbit_basis", moon_orbit_basis)
    moon_view_shader.set_shader_parameter("moon_basis", moon_true)
    sky_compute.moon_direction = -moon_apparent.z

    # Moon shadowing calculation, uses a min value to account for corona/ atmosphere
    # Manually computing because built-in dot() is low precision and causes a ton of flickering
    var s: Vector3 = sun_apparent
    var m: Vector3 = moon_apparent.z
    var cos_theta: float = (
        (s.x * m.x + s.y * m.y + s.z * m.z) /
        (
            sqrt(s.x * s.x + s.y * s.y + s.z * s.z) *
            sqrt(m.x * m.x + m.y * m.y + m.z * m.z)
        )
    )

    sky_compute.moon_shadowing = maxf(
            intersect_disks(
                _sun_radians,
                _moon_radians,
                cos_theta
            ),
            eclipse_min
    )

    sky_material.set_shader_parameter("sun_angular_diameter", sun_angular_diameter)
    if use_moon_render_angle:
        sky_material.set_shader_parameter("moon_angular_diameter", moon_camera.fov)
    else:
        sky_material.set_shader_parameter("moon_angular_diameter", moon_angular_diameter)

    # This should not need to be necessary, but I keep having this issue where
    # sky_compute is regenerated, breaking the old texture. Doing this seems
    # to have no impact on FPS at all, and it fixes the purple/ black sky, so...
    sky_material.set_shader_parameter("sky_texture", sky_compute.sky_texture)
    sky_material.set_shader_parameter("lut_texture", sky_compute.lut_texture)
    sky_material.set_shader_parameter("lut_size", Vector2i(sky_compute.lut_size, sky_compute.lut_size))
    #sky_material.set_shader_parameter("sky_size", Vector2i(sky_compute.sky_size, sky_compute.sky_size))
    sky_material.set_shader_parameter("moon_texture", moon_view.get_texture())


## Helper to compute area of intersection of circles A and B, returns the percent
## visible of circle A. This is used for eclipse shadowing calculations and
## assumes circle A is the Sun, and circle B is the Moon.
func intersect_disks(a_radius: float, b_radius: float, cos_theta: float) -> float:

    # Perfect overlap. Godot's `is_equal_approx()` epsilon is too large, don't use it
    if cos_theta >= 0.9999999:
        if b_radius >= a_radius:
            return 0.0

        var a: float = a_radius * a_radius
        var b: float = b_radius * b_radius

        return (a - b) / a

    var distance: float = 0.5 * acos(cos_theta)

    # No overlap at all
    if distance >= a_radius + b_radius:
        return 1.0

    # B is fully overlapping or contained in A
    if distance < abs(a_radius - b_radius):
        if b_radius >= a_radius:
            return 0.0

        var a: float = a_radius * a_radius
        var b: float = b_radius * b_radius

        return (a - b) / a

    # Partial intersection, need full formulas now
    var ar_2: float = a_radius * a_radius
    var br_2: float = b_radius * b_radius

    var a_d: float = (ar_2 - br_2 + distance * distance) / (2.0 * distance)
    var b_d: float = distance - a_d

    var sector_a: float = ar_2 * acos(a_d / a_radius)
    var sector_b: float = br_2 * acos(b_d / b_radius)

    var triangle_a: float = a_d * sqrt(ar_2 - a_d * a_d)
    var triangle_b: float = b_d * sqrt(br_2 - b_d * b_d)

    var area_overlap: float = (sector_a - triangle_a) + (sector_b - triangle_b)
    var area_a: float = PI * a_radius * a_radius

    return (area_a - area_overlap) / area_a

## Helper to compute light disks being obscurred by a distant horizon
func light_horizon(light: Vector3, radius: float) -> float:
    var angle = light.y; # asin(light.y), at small angles t ~= arcsin(t)

    if angle >= radius:
        return 1.0

    if angle < -radius:
        return 0.0

    var rho: float = -(angle / radius) + 1.0
    var beta: float = (PI * 0.5) * (cos(PI * rho * 0.5) + 1.0)
    var alpha: float = beta / PI
    return alpha

func compute_sun_color() -> Color:
    # If the Sun is not visible, keep the current color
    if not Sun.visible:
        # NOTE: for testing, may not be needed later if game has a sunset
        #       before the first sunrise
        if not Sun.light_color.is_equal_approx(Color.WHITE):
            return Sun.light_color

    # Test brightest portion for color, sync until we have data
    if not lut_texture:
        RenderingServer.force_sync()
        var image: Image = sky_compute.lut_texture.get_image()
        var coord: Vector2i = image.get_size()
        var sample: Color = image.get_pixel(coord.x - 1, coord.y - 1)
        if is_zero_approx(sample.r) \
                and is_zero_approx(sample.g) \
                and is_zero_approx(sample.b) \
                and is_zero_approx(sample.a):
            return Sun.light_color
        lut_texture = image


    const spectral: Color = Color(1.679, 1.828, 1.986, 1.307)
    var transmittance: Color = transmittance_from_lut(
            lut_texture,
            # NOTE: poll the top half of the sun disk for a better result
            Sun.basis.rotated(Sun.basis.x, _sun_radians * 0.5).z
    )
    var color: Color = spectral_to_rgb(spectral * transmittance)
    color = gamma_correct(color)

    # NOTE: make the colors less saturated by pulling them up in value
    color.r = sqrt(color.r)
    color.g = sqrt(color.g)
    color.b = sqrt(color.b)

    return color

static func transmittance_from_lut(lut: Image, direction: Vector3) -> Color:
    var uv: Vector2 = Vector2(maxf(0.0, direction.dot(Vector3.UP)), 0.0)
    uv.y = clampf(3.0 * uv.x * uv.x, 0.0, 1.0)
    uv.x = clampf(uv.x * 0.5 + 0.5, 0.0, 1.0)

    var size: Vector2i = lut.get_size()
    var coord: Vector2 = Vector2(size) * uv
    var cell: Vector2 = (coord - Vector2(0.5, 0.5)).floor()
    var offset: Vector2 = (coord - Vector2(0.5, 0.5)) - cell

    # Collect pixel values for interpolation
    var pixels: PackedFloat32Array
    pixels.resize(64)

    for y in range(4):
        for x in range(4):
            var color: Color = lut.get_pixel(
                    clampi(int(cell.x) + x - 1, 0, size.x - 1),
                    clampi(int(cell.y) + y - 1, 0, size.y - 1)
            )
            var i: int = ((x * 4) + (y * 16))
            pixels[i]     = color.r
            pixels[i + 1] = color.g
            pixels[i + 2] = color.b
            pixels[i + 3] = color.a

    var t := offset
    var t2 := t * t
    var t3 := t * t2

    var q1 := 0.5 * (-t3 + 2.0 * t2 - t)
    var q2 := 0.5 * (3.0 * t3 - 5.0 * t2 + Vector2(2.0, 2.0))
    var q3 := 0.5 * (-3.0 * t3 + 4.0 * t2 + t)
    var q4 := 0.5 * (t3 - t2)

    # Row interpolation
    for u in range(4):
        u *= 16
        pixels[u]     = pixels[u]     * q1.x + pixels[u + 4] * q2.x + pixels[u + 8]  * q3.x + pixels[u + 12] * q4.x
        pixels[u + 1] = pixels[u + 1] * q1.x + pixels[u + 5] * q2.x + pixels[u + 9]  * q3.x + pixels[u + 13] * q4.x
        pixels[u + 2] = pixels[u + 2] * q1.x + pixels[u + 6] * q2.x + pixels[u + 10] * q3.x + pixels[u + 14] * q4.x
        pixels[u + 3] = pixels[u + 3] * q1.x + pixels[u + 7] * q2.x + pixels[u + 11] * q3.x + pixels[u + 15] * q4.x

    # Final interpolation
    var result: Color = Color(
            pixels[0] * q1.y + pixels[16] * q2.y + pixels[32] * q3.y + pixels[48] * q4.y,
            pixels[1] * q1.y + pixels[17] * q2.y + pixels[33] * q3.y + pixels[49] * q4.y,
            pixels[2] * q1.y + pixels[18] * q2.y + pixels[34] * q3.y + pixels[50] * q4.y,
            pixels[3] * q1.y + pixels[19] * q2.y + pixels[35] * q3.y + pixels[51] * q4.y,
    )

    return result

static func spectral_to_rgb(s: Color) -> Color:
    var color := Color(
        137.672389239975     * s.r +  32.549094028629234 * s.g + -38.91428392614275 * s.b +   8.572844237945445 * s.a,
         -8.632904716299537  * s.r +  91.29801417199785  * s.g +  34.31665471469816 * s.b + -11.103384660054624 * s.a,
         -1.7181567391931372 * s.r + -12.005406444382531 * s.g +  29.89044807197628 * s.b + 117.47585277566478  * s.a
    )

    const k = 0.05
    color.r = 1.0 - exp(-k * color.r)
    color.g = 1.0 - exp(-k * color.g)
    color.b = 1.0 - exp(-k * color.b)

    return color

static func gamma_correct(color: Color) -> Color:
    const gamma = 12.92
    const theta = 1.0 / 2.4
    const lambda = 0.0031308

    var result: Color
    for i in range(3):
        var c: float = color[i]
        if c < lambda:
            result[i] = gamma * c
        else:
            result[i] = 1.055 * pow(c, theta) - 0.055

    return result.clamp()

## Computes an elevation offset due to atmospheric refraction.
## Returns angle difference in radians.
static func compute_refraction(sin_theta: float) -> float:
    var angle: float = rad_to_deg(asin(sin_theta))
    if angle < -5.0:
        return 0.0
    return deg_to_rad(1.02 / (60.0 * tan(deg_to_rad(angle + (10.3 / (angle + 5.11))))))
