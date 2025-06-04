@tool
extends StaticBody3D


@export var size: Vector3 = Vector3(1.0, 1.0, 1.0)
var last_size: Vector3

@onready var shape: CollisionPolygon3D = %CollisionPolygon3D


func _ready() -> void:
    update_shape()

func _process(_delta: float) -> void:
    if not Engine.is_editor_hint():
        return

    if size == last_size:
        return

    update_shape()
    last_size = size

func update_shape() -> void:
    shape.polygon = PackedVector2Array([
            Vector2(size.x, 0.0),
            Vector2(0.0, 0.0),
            Vector2(0.0, size.y)
    ])
    shape.depth = size.z
