class_name WheeledJoltVehicle extends JoltVehicle


@export var exit_position: Marker3D
@export var camera_target: Marker3D


@export_group('Input')

@export_subgroup('Acceleration', 'forward')

@export_custom(PROPERTY_HINT_GROUP_ENABLE, 'checkbox_only')
var forward_accel_enabled: bool = true

## Rate that forward input accelerates to target input. The input range is -1.0
## to 1.0. Only applied when enabled.
@export_range(0.001, 2.0, 0.001, 'or_greater', 'suffix:u/s\u00B2')
var forward_accel_rate: float = 0.1

## Rate that forward input deccelerates when near the target input. Only applied
## when 'forward_stop_time' is positive.
@export_range(0.001, 2.0, 0.001, 'or_greater', 'suffix:u/s\u00B2')
var forward_deccel_rate: float = 1.0

## The maximum rate that forward input can change per second. Set to zero to
## disable the limit.
@export_range(0.0, 1.0, 0.001, 'or_greater', 'suffix:u/s')
var forward_max_rate: float = 0.001

## Time of decceleration when nearing the target input. Set to zero to disable
## decceleration.
@export_range(0.0, 1.0, 0.01, 'or_greater', 'suffix:s')
var forward_stop_time: float = 0.1


@export_subgroup('Steering', 'steer')

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var steer_accel_enabled: bool = true

## Rate that steering input accelerates to target input. The input range is -1.0
## to 1.0. Only applied when enabled.
@export_range(0.001, 2.0, 0.001, 'or_greater', 'suffix:u/s\u00B2')
var steer_accel_rate: float = 0.5

## Rate that steering input deccelerates when near the target input. Only applied
## when 'steer_stop_time' is positive.
@export_range(0.001, 2.0, 0.001, 'or_greater', 'suffix:u/s\u00B2')
var steer_deccel_rate: float = 1.0

## The maximum rate that steering input can change per second. Set to zero to
## disable the limit.
@export_range(0.0, 1.0, 0.001, 'or_greater', 'suffix:u/s')
var steer_max_rate: float = 0.2

## Time of decceleration when nearing the target input. Set to zero to disable
## decceleration.
@export_range(0.0, 1.0, 0.01, 'or_greater', 'suffix:s')
var steer_stop_time: float = 0.2


@export_group("Debug", "dbg")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var dbg_enable: bool = false

@export var dbg_show_wheel_slip: bool = false


var _forward: float = 0
var _right: float = 0
var _brake: float = 0
var _handbrake: float = 0

var _value_forward: float = 0
var _accel_forward: Accelerator = Accelerator.new(
    forward_accel_rate, forward_deccel_rate, forward_stop_time, forward_max_rate
)

var _value_right: float = 0
var _accel_right: Accelerator = Accelerator.new(
    steer_accel_rate, steer_deccel_rate, steer_stop_time, steer_max_rate
)


func forward(value: float) -> void:
    _forward = clampf(value, -1.0, 1.0)

func steer(right: float) -> void:
    _right = clampf(right, -1.0, 1.0)

func brake(amount: float) -> void:
    _brake = clampf(amount, 0.0, 1.0)

func handbrake(amount: float) -> void:
    _handbrake = clampf(amount, 0.0, 1.0)

func get_exit_position() -> Vector3:
    return exit_position.global_position + settings.up

func _reset() -> void:
    _forward = 0
    _right = 0
    _brake = 0
    _handbrake = 0

func _physics_process(delta: float) -> void:
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController
    if not controller:
        _reset()
        return

    if dbg_enable:
        if dbg_show_wheel_slip:
            var wheel_infos: Array[Dictionary] = controller.get_wheel_info()
            var i: int = 0
            for wheel in wheel_nodes:

                if wheel is MeshInstance3D:
                    var info: Dictionary = wheel_infos[i]
                    var mat: StandardMaterial3D = wheel.mesh.surface_get_material(0) as StandardMaterial3D
                    if not info['has_contact']:
                        mat.albedo_color = Color(0.0, 0.0, 1.0)
                    elif info['slip_long'] > 0.1:
                        mat.albedo_color = Color(1.0, 0.0, 0.0)
                    else:
                        mat.albedo_color = Color(remap(info['slip_long'], 0.0, 0.1, 0.0, 1.0), 1.0, 0.0)
                i += 1

    var input_forward = _forward
    var input_right = _right
    var input_brake = _brake
    var input_handbrake = _handbrake

    if forward_accel_enabled:
        var offset: float = _forward - _value_forward
        if not is_zero_approx(offset):
            _accel_forward.accel = forward_accel_rate
            _accel_forward.deccel = forward_deccel_rate
            _accel_forward.limit = forward_max_rate
            _accel_forward.stop_time = forward_stop_time

            _accel_forward.update(delta, offset)
            _value_forward = clampf(
                    _value_forward + _accel_forward.velocity,
                    -1.0, 1.0
            )

            # Check overshoot
            if signf(offset) > 0.0:
                _value_forward = minf(_value_forward, _forward)
            else:
                _value_forward = maxf(_value_forward, _forward)

            if is_equal_approx(_value_forward, _forward):
                _value_forward = _forward

        input_forward = _value_forward

    if steer_accel_enabled:
        var offset: float = _right - _value_right
        if not is_zero_approx(offset):
            _accel_right.accel = steer_accel_rate
            _accel_right.deccel = steer_deccel_rate
            _accel_right.limit = steer_max_rate
            _accel_right.stop_time = steer_stop_time

            _accel_right.update(delta, offset)
            _value_right = clampf(
                    _value_right + _accel_right.velocity,
                    -1.0, 1.0
            )

            # Check overshoot
            if signf(offset) > 0.0:
                _value_right = minf(_value_right, _right)
            else:
                _value_right = maxf(_value_right, _right)

            if is_equal_approx(_value_right, _right):
                _value_right = _right

        input_right = _value_right

    if not (
            is_zero_approx(_forward)
        and is_zero_approx(input_right)
        and is_zero_approx(_brake)
        and is_zero_approx(_handbrake)
    ):
        # Wake up when input is received
        sleeping = false

    controller.set_driver_input(
            input_forward,
            input_right,
            _brake,
            _handbrake
    )
    if not is_equal_approx(_forward, input_forward):
        print('Forward: %f' % input_forward)
    if not is_zero_approx(_forward) and controller.is_any_driven_wheel_slipping():
        print('slipping!')
    #if not is_zero_approx(input_forward):
        #print(controller.get_current_gear())
        #print(controller.get_current_rpm())
    _reset()
