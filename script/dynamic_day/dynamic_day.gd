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

## Rate of time passage relative to real time.
@export_range(1.0, 200.0, 0.001, 'or_greater')
var time_scale: float = 100

## Enable this to play the local time value in the editor.
@export var editor_realtime: bool = false

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
        _latitude_rad = -deg_to_rad(latitude)
var _latitude_rad: float

## Planet axial tilt in the direction of the sun. Earth's tilt is about 23.44 degrees.
@export_range(0.0, 180.0, 0.00001) var planet_tilt: float = 23.44:
    set(value):
        planet_tilt = value
        _tilt_rad = -deg_to_rad(planet_tilt)
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
@export_range(0.0, 10.0, 0.0001, 'or_greater')
var sun_angular_diameter: float = 0.53


var sky: ShaderMaterial
var sky_texture: Texture2DRD
var sky_compute: PhysicalSkyCompute


func _init() -> void:
    # force cached calculations
    local_time = local_time
    north = north
    latitude = latitude
    planet_tilt = planet_tilt
    day_length = day_length

func _ready() -> void:
    init_shader()
    pass

func _process(delta: float) -> void:
    if not Engine.is_editor_hint():
        return

    if editor_realtime:
        update_time(delta)

    update_lights(true)

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    update_time(delta)
    update_lights()

func update_time(delta: float) -> void:
    _local_time[1] = _local_time[1] + (delta * time_scale * _inv_day_length[0])
    if _local_time[1] >= 1.0:
        _local_time[1] = _local_time[1] - 1.0

func update_lights(force: bool = false) -> void:
    if not force and _local_time[0] == _local_time[1]:
        return

    update_sun()
    update_moon()
    update_shader()

    _local_time[0] = local_time

func update_sun() -> void:
    if not Sun:
        return

    var hour_angle: float = (_local_time[1] - 0.5) * TAU - (PI / 2)

    Sun.basis = Basis.IDENTITY

    Sun.rotate_y(_tilt_rad)
    Sun.rotate_x(hour_angle)
    Sun.rotate_z(_latitude_rad)
    Sun.rotate_y(_north_rad)

func update_moon() -> void:
    pass

func init_shader() -> void:
    sky = environment.sky.sky_material

    if not sky_compute:
        for effect in compositor.compositor_effects:
            if effect is PhysicalSkyCompute:
                sky_compute = effect
                break

    sky_compute.sun_direction = -Sun.basis.z

func update_shader() -> void:
    sky.set_shader_parameter("sun_direction", Sun.basis.z)
    sky.set_shader_parameter("sun_angular_diameter", sun_angular_diameter)
    sky_compute.sun_direction = -Sun.basis.z

    # This should not need to be necessary, but I keep having this issue where
    # sky_compute is regenerated, breaking the old texture. Doing this seems
    # to have no impact on FPS at all, and it fixes the purple/ black sky, so...
    sky.set_shader_parameter("sky_texture", sky_compute.sky_texture)
    sky.set_shader_parameter("lut_texture", sky_compute.lut_texture)
