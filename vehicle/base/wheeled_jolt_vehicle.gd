class_name WheeledJoltVehicle extends JoltVehicle


@export var exit_position: Marker3D
@export var camera_target: Marker3D


@export_group("Controls")

@export_subgroup("Steer By Wheel", 'steer')

## Make steering inputs turn a virtual wheel, instead of instantly applying a
## turning value directly.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, 'checkbox_only')
var steer_by_wheel: bool = false

## Steering curve, lower values approach input quicker. For instance, steering
## right at 1.0 for 0.2 seconds will result in a final steer of ~0.544 with a
## curve of 1. The constant rate of change is `(right * e) / curve`.
@export_range(0.01, 2.0, 0.01, 'or_greater')
var steer_wheel_curve: float = 1.0

## Makes steering more realistic by having steered wheels apply turning back to
## the virtual steering wheel.
@export var steer_enable_integrated: bool = false

## How much feedback to apply to the virtual wheel from the wheels.
@export_range(0.01, 1.2, 0.01, 'or_greater')
var steer_integrated_feedback: float = 1.2


@export_group("Debug", "dbg")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, 'checkbox_only')
var dbg_enable: bool = false

## When accelerating while stationary (sleeping), start a timer which ends once
## the vehicle exceeds 60mph and print the timer
@export var dbg_print_zero_sixty: bool = false

@export var dbg_show_wheel_slip: bool = false

@export var dbg_print_gear_changes: bool = false


var _forward: float = 0
var _right: float = 0
var _brake: float = 0
var _handbrake: float = 0

var _zero_sixty_timer: float = -1.0

var _last_gear: int = 0

var _virtual_right: float = 0
var _right_impulse: float = 0

var _flip_timer: float = 0.0
var _do_flip: bool = false


func _ready() -> void:
    if dbg_enable and dbg_show_wheel_slip:
        # Make all wheel materials unique copies
        for w in wheel_nodes:
            var mesh_instance: MeshInstance3D = w as MeshInstance3D
            if not mesh_instance:
                continue
            var mesh: PrimitiveMesh = mesh_instance.mesh as PrimitiveMesh
            if not mesh:
                continue
            mesh = mesh.duplicate()
            mesh.material = mesh.material.duplicate()
            mesh_instance.mesh = mesh

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

func get_gear() -> int:
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController
    if not controller:
        return 0
    return controller.get_current_gear()

func get_kmh() -> float:
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController
    if not controller:
        return 0
    return controller.get_speed_kmh()

func get_mph() -> float:
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController
    if not controller:
        return 0
    return controller.get_speed_mph()

func _reset() -> void:
    _forward = 0
    _right = 0
    _brake = 0
    _handbrake = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if not (steer_by_wheel and steer_enable_integrated):
        return

    update_right_one(state)
    # update_right_two(state)

func update_right_one(state: PhysicsDirectBodyState3D) -> void:
    var vehicle_turn: float = -state.transform.basis.tdoty(state.angular_velocity)
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController

    var avg_steer: float = 0.0
    var steer_count: int = 0
    var i: int = -1
    for w in controller.get_wheel_info():
        i += 1
        if not w.has_contact:
            continue
        var w_setting: WheelSettings = settings.wheels[i] as WheelSettings
        if w_setting.max_steer_angle == 0.0:
            continue
        avg_steer += w.steer_angle
        steer_count += 1

    if steer_count < 1:
        _right_impulse = 0
        return

    avg_steer /= steer_count
    if abs(avg_steer) < 1e-6:
        _right_impulse = 0
        return

    if signf(vehicle_turn) == signf(avg_steer):
        avg_steer = -avg_steer

    vehicle_turn = abs(vehicle_turn) * state.step
    _right_impulse = clampf(
        vehicle_turn / avg_steer,
        -vehicle_turn, vehicle_turn
    )

func update_right_two(_state: PhysicsDirectBodyState3D) -> void:
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController

    var avg_steer_diff: float = 0.0
    var steer_count: int = 0
    var i: int = -1
    for w in controller.get_wheel_info():
        i += 1
        if not w.has_contact:
            continue
        var w_setting: WheelSettings = settings.wheels[i] as WheelSettings
        if w_setting.max_steer_angle == 0.0:
            continue
        # print('%d : %.2f %.2f' % [i, w.lambda_long, w.lambda_lat])
        var diff: float = (
                (w.slip_lat - (w_setting.toe * signf(w_setting.position.x)))
                * signf(w.lambda_lat) * tanh(abs(w.lambda_long))
        )
        # print('%d : %f' % [i, diff])
        avg_steer_diff += diff
        steer_count += 1

    if steer_count < 1:
        _right_impulse = 0
        return

    _right_impulse = -avg_steer_diff / steer_count


func _physics_process(delta: float) -> void:
    if _flip_timer > 0.0:
        _flip_timer = maxf(_flip_timer - delta, 0.0)

    if _do_flip:
        apply_central_impulse(Vector3.UP * 5.0 * mass)
        # TODO: figure out if on left or right of the truck. I'm too dumb.
        var side_dir: float = signf(global_basis.x.y)
        if absf(global_basis.x.y) < 0.1:
            side_dir = 2.0
        apply_torque_impulse(global_basis.z * -side_dir * inertia.z * 1.2)
        _do_flip = false

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

        if dbg_print_zero_sixty:
            var mph: float = linear_velocity.length() * 3.6 / 1.609344
            if _zero_sixty_timer != -1.0:
                _zero_sixty_timer += delta
                if _forward < 0.0 or _brake > 0.0:
                    GlobalWorld.print("0-%.1f: %.3fs" % [mph, _zero_sixty_timer])
                    _zero_sixty_timer = -1.0
                elif mph >= 60.0:
                    GlobalWorld.print("0-60: %.3fs" % _zero_sixty_timer)
                    _zero_sixty_timer = -1.0

        if dbg_print_gear_changes:
            var gear: int = controller.get_current_gear()
            if _last_gear != gear:
                GlobalWorld.print('Gear: %d -> %d' % [_last_gear, gear])
                _last_gear = gear

    if steer_by_wheel:
        update_virtual_steer(delta)
        _right = _virtual_right
        # print('vr: %.4f' % _virtual_right)

    if not (
            is_zero_approx(_forward)
        and is_zero_approx(_right)
        and is_zero_approx(_brake)
        and is_zero_approx(_handbrake)
    ):
        if (
                    dbg_enable
                and dbg_print_zero_sixty
                and sleeping
                and _forward > 0.0
                and _zero_sixty_timer == -1.0
        ):
            _zero_sixty_timer = 0.0
        # Wake up when input is received
        sleeping = false


    controller.set_driver_input(
            _forward,
            _right,
            _brake,
            _handbrake
    )

    #if not is_zero_approx(_forward) and controller.is_any_driven_wheel_slipping():
        #print('slipping!')
    #if not is_zero_approx(input_forward):
        #print(controller.get_current_gear())
        #print(controller.get_current_rpm())

    _reset()

func update_virtual_steer(delta: float) -> void:
    _virtual_right = clampf(
        _virtual_right + (_right_impulse * steer_integrated_feedback),
        -1.0, 1.0
    )

    if _virtual_right == _right:
        return

    const E = exp(1)
    var offset: float = clampf(_right - _virtual_right, -1.0, 1.0)
    _virtual_right += (offset * E * delta) / steer_wheel_curve
    if (
            is_equal_approx(_virtual_right, _right)
            or (offset > 0 and _virtual_right > _right)
            or (offset < 0 and _virtual_right < _right)
    ):
        _virtual_right = _right

func flip(from: Vector3) -> void:
    if _flip_timer != 0.0:
        return

    _do_flip = true
    _flip_timer = 1.0
