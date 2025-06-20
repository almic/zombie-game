@tool
class_name DynamicDay extends WorldEnvironment


@export var Sun: DirectionalLight3D
@export var Moon: DirectionalLight3D
## Local time of day, where 0.25 is morning, 0.5 is midday, and 1 & 0 are midnight
@export_range(0.0, 1.0, 0.00001) var local_time: float = 0.345:
    set(value):
        local_time = value
        _local_time[1] = value
var _local_time: PackedFloat64Array = [0, 0]

## If time passage happens in-game
@export var time_enabled: bool = true

## Rate of time passage relative to real time.
@export_range(1.0, 200.0, 0.001, 'or_greater')
var time_scale: float = 100

## Enable this to play the local time value in the editor.
@export var editor_realtime: bool = false

## Click this to reset local time changes resulting from editor real-time changes.
@export var reset_realtime: bool = false:
    set(value):
        reset_realtime = false
        _local_time = [0, 0]
        local_time = local_time
        _moon_time = [0, 0]
        _moon_orbit = [0, 0]

## Reload sky shaders
@export var reload_shaders: bool = false:
    set(value):
        reload_shaders = false
        if not value:
            return
        if not sky_compute:
            return
        sky_compute.reload_shaders()

@export_category("Planet Attributes")

## The direction of north. This is a "rise east, set west" model.
@export_range(-180.0, 180.0, 0.00001) var north: float:
    set(value):
        north = value
        _north_rad = deg_to_rad(north) - (PI / 2)
var _north_rad: float

## Latitude of the viewer, affects how high the sun rises at midday. Depending
## on the tilt, the Sun may always (or never) be visible.
@export_range(-90.0, 90.0, 0.00001) var latitude: float:
    set(value):
        latitude = value
        _latitude_rad = (PI / 2) - deg_to_rad(latitude)
var _latitude_rad: float

## Planet axial tilt in the direction of the sun. Earth's tilt is about 23.44 degrees.
@export_range(0.0, 180.0, 0.00001) var planet_tilt: float = 23.44:
    set(value):
        planet_tilt = value
        _tilt_rad = deg_to_rad(planet_tilt)
var _tilt_rad: float

## Hours in a day, this is NOT the rate at which time passes. See "Time Scale".
## Because of the orbit, Earth's days are not exactly 24 hours.
@export_range(1.0, 100.0, 0.00001, 'or_greater')
var day_length: float = 23.93:
    set(value):
        day_length = value
        _inv_day_length[0] = 1.0 / (day_length * 3600)
var _inv_day_length: PackedFloat64Array = [0]

@export_category("Sun Attributes")

## Angular diameter of the sun in degrees
@export_range(0.0, 3.0, 0.0001, 'or_greater')
var sun_angular_diameter: float = 0.542:
    set(value):
        sun_angular_diameter = value
        _sun_radians = deg_to_rad(sun_angular_diameter) * 0.5
var _sun_radians: float


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

## Angular diameter of the moon in degrees
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
        _inv_moon_periods[0] = 1.0 / (moon_day_length * 3600)

## The time taken to orbit around the Earth. The Moon takes about 720.73 hours,
## which is the same as its rotational period (a lunar day).
@export_range(0.0, 2400.0, 0.0001, 'or_greater')
var moon_orbital_period: float = 720.73:
    set(value):
        moon_orbital_period = value
        _inv_moon_periods[1] = 1.0 / (moon_orbital_period * 3600)

## When "Use Moon Render Angle" is enabled, this controls the apparent distance
## to the moon from the viewer.
@export_range(100.0, 500000.0, 0.01, 'or_greater')
var moon_distance: float = 384400:
    set(value):
        moon_distance = value
        if moon_view:
            moon_view.moon_distance = moon_distance

## Day, orbit
var _inv_moon_periods: PackedFloat64Array = [0, 0]

## Time
var _moon_time: PackedFloat64Array = [0, 0]

## Orbit
var _moon_orbit: PackedFloat64Array = [0, 0]

@export_group("Orbital Parameters", "moon")

## The inclination of the moon's orbit to the ecliptic plane, in degrees. This
## is applied as if the Moon was between the Earth and Sun, towards earth. It
## also affects the orbital motion, in prograde for values 0-90, and retrograde
## from 90-180. See "Inclination Phase" to spin the orbital nodes.
## The Moon's inclination is about 5.145 degrees.
@export_range(0.0, 180.0, 0.00001) var moon_inclination: float = 5.145:
    set(value):
        moon_inclination = value
        _moon_incl_rad = deg_to_rad(moon_inclination)
var _moon_incl_rad: float

## Moon axial tilt from its orbital plane, in degrees. The Moon's tilt is about
## 6.688 degrees.
@export_range(0.0, 180.0, 0.00001) var moon_tilt: float = 6.688:
    set(value):
        moon_tilt = value
        _moon_tilt_rad = deg_to_rad(moon_tilt)
var _moon_tilt_rad: float

## Spin of the moon's inclination, in N-pi radians. The Moon's orbit precesses,
## relative to Earth's equator, with a period of 18.3 years. However, due to the
## orbit of the Earth around the Sun, the orbital nodes align with the Sun about
## every 173.3 days, resulting in Lunar and Solar eclipses. To create eclipses,
## modify this phase to be near 0.5 or 1.5. See "Tilt Phase" and offset it by 1.0
## to remain physically accurate.
@export_range(0.0, 2.0, 0.00001) var moon_inclination_phase: float = 0.0

## Spin of the moon's tilt, in N-pi radians. The Moon's tilt is perfectly out
## of phase with the orbit (1.0), so it stays at a tilt of 1.543 to the ecliptic
## plane at all times. To have the tilt change orientation, modify this phase.
@export_range(0.0, 2.0, 0.00001) var moon_tilt_phase: float = 1.0


@export_group("Orbit & Time Offsets", "moon")

## Offset applied to the Moon's orbit, use this to progress the moon through
## its orbit. For convenience, this is added to the time progress as well.
@export_range(0.0, 1.0, 0.00001) var moon_orbit_offset: float = 0.0

## Offset applied to the Moon's local time, use this to change the local time on
## the Moon. Even for custom moon configurations, you should leave this at zero.
@export_range(0.0, 1.0, 0.00001) var moon_time_offset: float = 0.0


@export_group("Moon Renderer", "moon")

## SubViewport scene that contains a mesh uniquely named "Moon" so that it can
## be rotated accordingly.
@export var moon_renderer: PackedScene


var sky: ShaderMaterial
var sky_texture: Texture2DRD
var sky_compute: PhysicalSkyCompute
var moon_view: MoonView
var moon_mesh: MeshInstance3D
var moon_camera: Camera3D
var moon_view_shader: ShaderMaterial
var moon_orbit_basis: Basis
var moon_shadowing_min: float = 0.03

func _init() -> void:
    # force cached calculations
    local_time = local_time
    north = north
    latitude = latitude
    planet_tilt = planet_tilt
    day_length = day_length

    moon_day_length = moon_day_length
    moon_orbital_period = moon_orbital_period
    moon_inclination = moon_inclination
    moon_tilt = moon_tilt

    moon_angular_diameter = moon_angular_diameter
    sun_angular_diameter = sun_angular_diameter

func _ready() -> void:
    init_shader()

func _process(delta: float) -> void:
    if not Engine.is_editor_hint():
        return

    if editor_realtime:
        update_time(delta)

    update_lights(true)

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if time_enabled:
        update_time(delta)

    update_lights()

func update_time(delta: float) -> void:
    var rate: float = delta * time_scale

    # Sun time
    _local_time[1] = _local_time[1] + (rate * _inv_day_length[0])
    if _local_time[1] >= 1.0:
        _local_time[1] = _local_time[1] - 1.0

    # Moon time
    _moon_time[1] = _moon_time[1] + (rate * _inv_moon_periods[0])
    if _moon_time[1] >= 1.0:
        _moon_time[1] = _moon_time[1] - 1.0

    # Moon orbit
    _moon_orbit[1] = _moon_orbit[1] + (rate * _inv_moon_periods[1])
    if _moon_orbit[1] >= 1.0:
        _moon_orbit[1] = _moon_orbit[1] - 1.0

func update_lights(force: bool = false) -> void:
    var updated: bool = false
    if force or not is_equal_approx(_local_time[0], _local_time[1]):
        update_sun()
        updated = true

    if force \
            or not is_equal_approx(_moon_time[0], _moon_time[1]) \
            or not is_equal_approx(_moon_orbit[0], _moon_orbit[1]):
        update_moon()
        updated = true

    if not updated:
        return

    update_shader()

    _local_time[0] = _local_time[1]
    _moon_time[0] = _moon_time[1]
    _moon_orbit[0] = _moon_orbit[1]

func update_sun() -> void:
    if not Sun:
        return

    var hour_angle: float = (_local_time[1] - 0.5) * TAU - (PI / 2)

    Sun.basis = Basis.IDENTITY

    # Place viewer on Earth first
    Sun.rotate_z(_latitude_rad)

    # Earth rotates counter-clockwise
    Sun.rotate_object_local(Vector3.DOWN, hour_angle)

    # Tilt towards Sun
    Sun.rotate_object_local(Vector3.LEFT, _tilt_rad)

    # Spin viewer to face north
    Sun.rotate_y(_north_rad)

func update_moon() -> void:
    if not Moon:
        return

    # Local time, required for combination with Earth's rotation
    var hour_angle: float = (_local_time[1] - 0.5) * TAU - (PI / 2)

    # Orbit time
    var orbit_angle: float = (_moon_orbit[1] + moon_orbit_offset - 0.5) * TAU

    # Spin the moon mesh according to lunar time
    if moon_mesh:
        moon_mesh.basis = Basis.IDENTITY

        # Lunar time
        var orbit_time_offset: float = moon_time_offset + (moon_orbit_offset * moon_orbital_period / moon_day_length)
        var lunar_hour: float = (_moon_time[1] + orbit_time_offset - 0.5) * TAU

        # Moon is prograde with Earth, counter-clockwise rotation
        moon_mesh.rotate_y(lunar_hour)

        # Compute tilt axis. Don't want tilt to spin the whole model, so we rotate
        # the tilt axis by itself, then apply that tilt. We are rotating the Y-axis
        # about the X-axis (towards Z), so start with the Right (East) vector.
        var tilt_axis: Vector3 = Vector3.RIGHT
        tilt_axis = tilt_axis.rotated(Vector3.UP, moon_tilt_phase * PI)
        moon_mesh.rotate(tilt_axis, _moon_tilt_rad)

    # Compute the inclination axis. Same as tilt, we don't want it to spin the
    # orbital position, so rotate the inclination axis by itself.
    var incl_axis: Vector3 = Vector3.RIGHT
    incl_axis = incl_axis.rotated(Vector3.UP, moon_inclination_phase * PI)

    # The Moon's rotations apply after Earth's rotations

    # Earth + Viewer rotations
    var earth: Transform3D = Transform3D.IDENTITY
    earth = earth.rotated(Vector3.BACK, _latitude_rad)
    earth = earth.rotated_local(Vector3.DOWN, hour_angle)
    earth = earth.rotated_local(Vector3.LEFT, _tilt_rad)
    earth = earth.rotated(Vector3.UP, _north_rad)

    # Moon's orbital position
    Moon.basis = Basis.IDENTITY
    # The moon is prograde, the Sun appears to "chase" the Moon
    Moon.rotate_y(orbit_angle)
    # Apply orbital tilt
    Moon.rotate(incl_axis, _moon_incl_rad)

    # Stash for moon renderer
    moon_orbit_basis = Moon.basis

    # Combine
    Moon.basis = earth.basis * Moon.basis

func init_shader() -> void:
    sky = environment.sky.sky_material

    if not sky_compute:
        for effect in compositor.compositor_effects:
            if effect is PhysicalSkyCompute:
                sky_compute = effect
                break

    if Sun:
        sky_compute.sun_direction = -Sun.basis.z

    if Moon:
        sky_compute.moon_direction = -Moon.basis.z

    moon_view = moon_renderer.instantiate()
    add_child(moon_view) # Required to start viewport rendering
    moon_view.moon_distance = moon_distance
    moon_mesh = moon_view.get_node('%Moon')
    moon_camera = moon_view.get_node('%Camera3D')
    moon_view_shader = moon_mesh.mesh.surface_get_material(0)

    # Force cached angle calculation
    use_moon_render_angle = use_moon_render_angle

func update_shader() -> void:
    sky.set_shader_parameter("sun_direction", Sun.basis.z)
    moon_view_shader.set_shader_parameter("sun_direction", Sun.basis.z)
    sky_compute.sun_direction = -Sun.basis.z

    sky.set_shader_parameter("moon_basis", Moon.basis)
    moon_view_shader.set_shader_parameter("moon_orbit_basis", moon_orbit_basis)
    moon_view_shader.set_shader_parameter("moon_basis", Moon.basis)
    sky_compute.moon_direction = -Moon.basis.z

    # Moon shadowing calculation, uses a min value to account for corona/ atmosphere
    # Manually computing because built-in dot() is low precision and causes a ton of flickering
    var s: Vector3 = Sun.basis.z
    var m: Vector3 = Moon.basis.z
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
            moon_shadowing_min
    )

    # Sun light energy and temperature as it rises
    Sun.light_energy = sky_compute.moon_shadowing * light_horizon(s, _sun_radians)

    sky.set_shader_parameter("sun_angular_diameter", sun_angular_diameter)
    if use_moon_render_angle:
        sky.set_shader_parameter("moon_angular_diameter", moon_camera.fov)
    else:
        sky.set_shader_parameter("moon_angular_diameter", moon_angular_diameter)

    # This should not need to be necessary, but I keep having this issue where
    # sky_compute is regenerated, breaking the old texture. Doing this seems
    # to have no impact on FPS at all, and it fixes the purple/ black sky, so...
    sky.set_shader_parameter("sky_texture", sky_compute.sky_texture)
    sky.set_shader_parameter("lut_texture", sky_compute.lut_texture)
    sky.set_shader_parameter("moon_texture", moon_view.get_texture())

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
