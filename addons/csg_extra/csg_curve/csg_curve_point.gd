@tool
class_name CSGCurvePoint3D extends Node3D

signal modified()

## Length of a straight section at this point, useful to ensure a clean
## connection to other curves, or just to have a straight part in the middle
## of some curve without having to add more points
@export_range(0, 0, 0.001, 'hide_slider', 'or_less', 'or_greater')
var straight_length: float = 1.0:
    set(value):
        straight_length = value
        update_gizmos()
        modified.emit()

## Length of the handle-in at this point
@export_range(0, 0, 0.001, 'hide_slider', 'or_less', 'or_greater')
var handle_in: float = 1.0:
    set(value):
        handle_in = value
        update_gizmos()
        modified.emit()

## Length of the handle-out at this point
@export_range(0, 0, 0.001, 'hide_slider', 'or_less', 'or_greater')
var handle_out: float = 1.0:
    set(value):
        handle_out = value
        update_gizmos()
        modified.emit()


## Set by the editor plugin when selected, a parent CGSCurve3D is selected, or
## a sibling CSGCurvePoint3D is selected and both share a parent CSGCurve3D
@warning_ignore('unused_private_class_variable')
var _show_gizmo: bool = false

# Tracks which gizmos to render, set by the parent
var _is_first: bool = false
var _is_last: bool = false


func _ready() -> void:
    set_notify_local_transform(true)
    editor_state_changed.connect(modified.emit)

func _notification(what: int) -> void:
    if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
        modified.emit()
