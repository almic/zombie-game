@tool
## All-in-one joy stick input mapper
class_name GUIDEModifierStick
extends GUIDEModifier


## Lower bound for input. Modified input starts to increase after raw input passes this value.
@export var deadzone_lower_threshold: float = 0.2:
    set(value):
        deadzone_lower_threshold = value
        emit_changed()

## Upper bound for input. Modified input reaches 1.0 when raw input exceeds this value.
@export var deadzone_upper_threshold: float = 0.9:
    set(value):
        deadzone_upper_threshold = value
        emit_changed()

## The power curve for the remapped input. Higher values give more fine control. 1.0 = linear.
@export_range(1.0, 5.0, 0.001, 'or_greater')
var curve: float = 3.0:
    set(value):
        curve = value
        emit_changed()

@export_range(0.0, 1.0, 0.001, 'or_greater', 'or_less', 'hide_control')
var scale: float = 1.0:
    set(value):
        scale = value
        emit_changed()


func is_same_as(other:GUIDEModifier) -> bool:
    if other is GUIDEModifierStick:
        return (
                is_equal_approx(deadzone_lower_threshold, other.deadzone_lower_threshold)
            and is_equal_approx(deadzone_upper_threshold, other.deadzone_upper_threshold)
            and is_equal_approx(curve, other.curve)
            and is_equal_approx(scale, other.scale)
        )
    return false

func _rescale(value: float) -> float:
    return pow(min(
            1.0,
            (max(0.0, abs(value) - deadzone_lower_threshold) / (deadzone_upper_threshold - deadzone_lower_threshold))
        ), curve) * sign(value) * scale

func _modify_input(input:Vector3, delta:float, value_type:GUIDEAction.GUIDEActionValueType) -> Vector3:
    if not input.is_finite():
        return Vector3.INF

    if deadzone_upper_threshold <= deadzone_lower_threshold:
        return input

    match value_type:
        GUIDEAction.GUIDEActionValueType.BOOL, GUIDEAction.GUIDEActionValueType.AXIS_1D:
            return Vector3(_rescale(input.x), input.y, input.z)

        GUIDEAction.GUIDEActionValueType.AXIS_2D:
            var v2d := Vector2(input.x, input.y)
            if v2d.is_zero_approx():
                return Vector3(0, 0, input.z)
            v2d = v2d.normalized() * _rescale(v2d.length())
            return Vector3(v2d.x, v2d.y, input.z)

        GUIDEAction.GUIDEActionValueType.AXIS_3D:
            if input.is_zero_approx():
                return Vector3.ZERO
            return input.normalized() * _rescale(input.length())
        _:
            push_error("Unsupported value type. This is a bug. Please report it.")
            return input


func _editor_name() -> String:
    return "Stick"


func _editor_description() -> String:
    return "All-in-one joy stick input mapper"
