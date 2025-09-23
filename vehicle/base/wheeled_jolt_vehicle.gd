class_name WheeledJoltVehicle extends JoltVehicle


@export var exit_position: Marker3D
@export var camera_target: Marker3D


var _forward: float = 0
var _right: float = 0
var _brake: float = 0
var _handbrake: float = 0


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

func _physics_process(_delta: float) -> void:
    var controller: WheeledVehicleController = get_controller() as WheeledVehicleController
    if not controller:
        _reset()
        return

    if not (
            is_zero_approx(_forward)
        and is_zero_approx(_right)
        and is_zero_approx(_brake)
        and is_zero_approx(_handbrake)
    ):
        # Wake up when input is received
        sleeping = false
    controller.set_driver_input(_forward, _right, _brake, _handbrake)
    _reset()
