class_name WheeledJoltVehicle extends JoltVehicle


@export var exit_position: Marker3D
@export var camera_target: Marker3D


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
                    elif info['slip_long'] > 0.5:
                        mat.albedo_color = Color(1.0, 0.0, 0.0)
                    else:
                        mat.albedo_color = Color(remap(info['slip_long'], 0.0, 0.5, 0.0, 1.0), 1.0, 0.0)
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
