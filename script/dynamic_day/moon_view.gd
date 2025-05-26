@tool

## Simple class to handle camera perspective
class_name MoonView extends SubViewport

@onready var camera_3d: Camera3D = %Camera3D

@export var orthographic_mode: bool = false:
    set(value):
        orthographic_mode = value
        if is_node_ready():
            set_camera_perspective()

## Diameter of the moon in kilometers
@export var moon_diameter: float = 3474:
    set(value):
        moon_diameter = value
        if is_node_ready():
            set_camera_perspective()

## Distance to the moon in kilometers
@export var moon_distance: float = 384400:
    set(value):
        moon_distance = value
        if is_node_ready():
            set_camera_perspective()

func _ready() -> void:
    set_camera_perspective()

func set_camera_perspective() -> void:

    # Point fowards
    camera_3d.basis = Basis.IDENTITY
    camera_3d.rotate_y(PI)

    if orthographic_mode:
        # Near is clamped to 0.001 minimum
        camera_3d.position = Vector3(0.0, 0.0, -0.501)
        camera_3d.set_orthogonal(1.0, 0.001, 1.001)
        return

    # Translate the camera into position
    var distance: float = moon_distance / moon_diameter
    camera_3d.position = Vector3(0.0, 0.0, -distance)

    # Compute the angular size for the perspective
    var angle: float = 2.0 * asin(moon_diameter / (2.0 * moon_distance))
    angle *= 180 / PI

    # Set perspective
    camera_3d.set_perspective(angle, distance - 0.5, distance + 0.5)
