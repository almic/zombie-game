@tool

extends WeaponScene


@onready var scope_camera_target: Marker3D = %ScopeCameraTarget
@onready var scope_camera: Camera3D = %ScopeCamera


func _process(_delta: float) -> void:
    scope_camera.global_transform = scope_camera_target.global_transform
