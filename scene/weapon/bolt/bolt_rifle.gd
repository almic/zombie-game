@tool

class_name ScopeRifle extends WeaponScene


@onready var scope_camera_target: Marker3D = %ScopeCameraTarget
@onready var scope_camera: Camera3D = %ScopeCamera
@onready var sub_viewport: SubViewport = %SubViewport


## Scope FOV
@export var fov: float = 5.0


func _ready() -> void:
    super._ready()

    scope_camera.fov = fov


func _process(_delta: float) -> void:
    scope_camera.global_transform = scope_camera_target.global_transform


func apply_camera_attributes(camera_attributes: CameraAttributes) -> void:
    scope_camera.attributes = camera_attributes.duplicate()

    # Disable auto exposure on the camera
    scope_camera.attributes.auto_exposure_enabled = false
    scope_camera.fov = fov


func can_aim() -> bool:
    var state: StringName = anim_state.get_current_node()
    return (
           state == IDLE
        or state == FIRE
        or state == CHARGE
    )
