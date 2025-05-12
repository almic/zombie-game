@tool
class_name CrossHair extends Node2D

enum Shape {
    Circle
}

@export_group("Center Shape", "center")
@export var center_enabled: bool = false

## Center shape
@export var center_shape: Shape = Shape.Circle

## Center size
@export_range(0.001, 100.0, 0.001) var center_size: float = 1.0

## Color
@export var center_color: Color = Color(0.1, 0.9, 0.1)

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()

func _draw() -> void:
    if center_enabled:
        if center_shape == Shape.Circle:
            draw_circle(Vector2.ZERO, center_size, center_color, true, -1, true)
