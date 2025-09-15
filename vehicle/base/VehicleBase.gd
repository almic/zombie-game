@tool
class_name VehicleBase extends RigidBody3D


@onready var camera_target: Marker3D = %CameraTarget
@onready var exit_point: Marker3D = %ExitPoint


## Acceleration in centimeters per second squared.
@export_range(10.0, 500.0, 0.1, 'or_greater', 'or_less', 'suffix:cm/s²')
var acceleration: float = 100.0

## Deceleration applied by braking in millimeters per second squared.
@export_range(10.0, 200.0, 0.1, 'or_greater', 'or_less', 'suffix:mm/s²')
var braking: float = 100.0

## Acceleration when reversing in centimeters per second squared.
@export_range(10.0, 200.0, 0.1, 'or_greater', 'or_less', 'suffix:cm/s²')
var reversing: float = 70.0


@export_group("Steering", "steering")

## Steer turn rate, in degrees per second
@export_range(1.0, 45.0, 0.1, 'or_less', 'or_greater', 'radians_as_degrees', 'suffix:°/s')
var steering_speed: float = deg_to_rad(90.0)

## Maximum steer of the wheels
@export_range(0.0, 90.0, 0.001, 'or_greater', 'radians_as_degrees')
var steering_maximum: float = deg_to_rad(40.0)

## Steering limit at high speed
@export_range(0.0, 90.0, 0.001, 'or_greater', 'radians_as_degrees')
var steering_high_speed_limit: float = deg_to_rad(5.0)

## The lower and upper boundaries for the steering curve, in meters per second
@export_custom(PROPERTY_HINT_RANGE, '0.0,100.0,0.01,or_greater,suffix:m/s')
var steering_curve_boundry: Vector2 = Vector2(0.0, 100.0):
    set(value):
        if not is_equal_approx(steering_curve_boundry.x, value.x):
            steering_curve_boundry = value
            if steering_curve_boundry.x > steering_curve_boundry.y:
                steering_curve_boundry.y = steering_curve_boundry.x
        elif not is_equal_approx(steering_curve_boundry.y, value.y):
            steering_curve_boundry = value
            if steering_curve_boundry.y < steering_curve_boundry.x:
                steering_curve_boundry.x = steering_curve_boundry.y

## Curve for steering as vehicle speed increases
@export_exp_easing('attenuation')
var steering_falloff_curve: float = 1.0


# Flags for vehicle actions
var _flag_accelerate: bool = false
var _flag_brake: bool = false
var _flag_reverse: bool = false
var _steer_target: float = 0.0


func _physics_process(delta: float) -> void:
    engine_force = 0.0
    brake = 0.0

    if _flag_accelerate:
        engine_force = acceleration * 0.01 * mass
        _flag_accelerate = false

    if _flag_brake:
        brake = braking * 0.001 * mass
        _flag_brake = false

    if _flag_reverse:
        engine_force -= reversing * 0.01 * mass
        _flag_reverse = false

    var steer_range: float = steering_curve_boundry.y - steering_curve_boundry.x
    var steer_reduction: float = 0.0
    if steer_range > 0.01:
        var speed: float = linear_velocity.length()
        steer_reduction = clampf((speed - steering_curve_boundry.x) / steer_range, 0.0, 1.0)

    var steer_curve: float = ease(steer_reduction, steering_falloff_curve)
    var steer_max: float = lerpf(abs(_steer_target), steering_high_speed_limit, steer_curve)

    _steer_target = minf(abs(_steer_target), steer_max) * signf(_steer_target)

    steering = move_toward(steering, _steer_target, delta * steering_speed)
    _steer_target = 0.0


## Apply positive acceleration
func do_accelerate() -> void:
    _flag_accelerate = true

## Apply braking force
func do_brake() -> void:
    _flag_brake = true

## Apply negative acceleration
func do_reverse() -> void:
    _flag_reverse = true

## Steer wheels to target angle
func do_steer(target: float) -> void:
    _steer_target = target

## Get the exit position
func get_exit_position() -> Vector3:
    return exit_point.global_position + Vector3.UP
