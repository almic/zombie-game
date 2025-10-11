@tool
extends Node3D


@export var input: DebugVector:
    set(value):
        if input and input.vector_changed.is_connected(vector_changed):
            input.vector_changed.disconnect(vector_changed)
        input = value
        input.vector_changed.connect(vector_changed)

@export var target: DebugVector:
    set(value):
        if target and target.vector_changed.is_connected(vector_changed):
            target.vector_changed.disconnect(vector_changed)
        target = value
        target.vector_changed.connect(vector_changed)

@export var output: DebugVector


@export_range(0, 180, 0.1, 'radians_as_degrees')
var angle: float = deg_to_rad(15):
    set(value):
        angle = value
        compute_output()

func vector_changed(_changed: DebugVector) -> void:
    compute_output()

func compute_output() -> void:
    var cos_theta: float = input.vector.dot(target.vector)
    var vec_angle: float = acos(cos_theta)

    if vec_angle <= angle:
        output.vector = input.vector
        return

    var rot_axis: Vector3 = target.vector.cross(input.vector)
    if rot_axis.is_zero_approx():
        output.vector = input.vector
        return

    rot_axis = rot_axis.normalized()
    output.vector = target.vector.rotated(rot_axis, angle)
