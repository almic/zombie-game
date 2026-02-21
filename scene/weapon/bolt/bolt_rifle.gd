class_name BoltWeaponScene extends WeaponScene


@onready var scope_camera_target: Marker3D = %ScopeCameraTarget
@onready var scope_camera: Camera3D = %ScopeCamera


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


# NOTE: There is no reason to unload the bolt rifle, so it is disabled
func goto_unload() -> bool:
    return false

func goto_unload_continue() -> bool:
    return false

func can_aim() -> bool:
    return (
           is_idle()
        or state == FIRE
        or state == CHARGE
    )
